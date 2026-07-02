--[[
File: Modules/Inventory/Actions/ActionDialogHooks.lua
Purpose: Hooks the native "Y-Action" dialog (ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) to Inject
         custom behaviors like Quickslot Assignment and BetterUI's safer Destroy logic.
]]

-- DIALOG HOOKS (System Integration)

local function GetProtectionPolicy()
    local policy = BETTERUI and BETTERUI.CIM and BETTERUI.CIM.ProtectionPolicy or nil
    assert(type(policy) == "table",
        "BetterUI: CIM.ProtectionPolicy must load before inventory action dialog destroy checks")
    return policy
end

local function RequireDestroyPolicyMethod(methodName)
    local policy = GetProtectionPolicy()
    local method = policy and policy[methodName] or nil
    assert(type(method) == "function",
        string.format("BetterUI: CIM.ProtectionPolicy.%s must load before inventory action dialog destroy checks", tostring(methodName)))
    return method
end

local function CanDestroyTargetWithPolicyViaPolicy(bagId, slotIndex, slotType)
    return RequireDestroyPolicyMethod("CanDestroyItem")(bagId, slotIndex, slotType) == true
end

local function CanDestroyTargetWithPolicy(targetData)
    if not targetData then
        return false
    end
    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(targetData)
    if not bagId or not slotIndex then
        return false
    end

    local ds = targetData.dataSource or targetData
    local slotType = ds and ds.slotType or targetData.slotType
    if BETTERUI.Inventory and BETTERUI.Inventory.CanDestroyItemWithPolicy then
        return BETTERUI.Inventory.CanDestroyItemWithPolicy(bagId, slotIndex, slotType)
    end
    return CanDestroyTargetWithPolicyViaPolicy(bagId, slotIndex, slotType)
end

--- Hooks the native Y-button Action Dialog.
---
--- Purpose: Extends the `ZO_GAMEPAD_INVENTORY_ACTION_DIALOG`.
--- Mechanics:
--- - Captures the existing dialog definition before registering BetterUI's
---   extension so unsupported scenes can delegate back to the prior owner.
--- - Registers a **custom** dialog with the **same name** as the engine's dialog (`ZO_GAMEPAD_INVENTORY_ACTION_DIALOG`).
--- - Implements custom `setup` to handle:
---   - Quickslot Assignment (embedded).
---   - Safe "Destroy" (BetterUI replacement).
---   - "Link to Chat" (safety checks).
--- - Implements custom `buttons` (Select/Cancel) to route actions correctly.
--- Hooks the native Y-button Action Dialog.
---@return nil
function BETTERUI.Inventory.HookActionDialog()
    local function TraceInventoryActionDialog(event, phase, data)
        local L = BETTERUI.Log
        if not (L and L.TraceEvent) then return end
        L.TraceEvent(L.CATEGORY.ACTION, event, phase, data)
    end

    local existingActionDialogInfo = BETTERUI.CIM and BETTERUI.CIM.Dialogs
        and BETTERUI.CIM.Dialogs.GetCurrentInfo(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
        or nil
    if BETTERUI.Inventory._actionDialogHookInstalled
        or (existingActionDialogInfo and existingActionDialogInfo._betteruiInventoryActionDialogHook) then
        TraceInventoryActionDialog("inventory.action_dialog", "already_hooked", {
            installedFlag = BETTERUI.Inventory._actionDialogHookInstalled == true,
            dialogMarked = existingActionDialogInfo and existingActionDialogInfo._betteruiInventoryActionDialogHook == true,
        })
        BETTERUI.Inventory._actionDialogHookInstalled = true
        return
    end

    local function TraceInventoryDestroyAction(phase, targetData, data)
        local L = BETTERUI.Log
        if not (L and L.TraceEvent) then return end
        data = data or {}
        if targetData and type(ZO_Inventory_GetBagAndIndex) == "function" then
            local ok, bag, slot = pcall(ZO_Inventory_GetBagAndIndex, targetData)
            if ok then
                data.bagId = data.bagId or bag
                data.slotIndex = data.slotIndex or slot
            end
        end
        local ds = targetData and (targetData.dataSource or targetData) or nil
        data.slotType = data.slotType or (ds and ds.slotType) or (targetData and targetData.slotType)
        data.dialogName = data.dialogName or ZO_GAMEPAD_INVENTORY_ACTION_DIALOG
        data.feature = data.feature or "destroy"
        if L.DescribeItem and targetData and not data.target then
            data.target = L.DescribeItem(targetData, "target")
        end
        L.TraceEvent(L.CATEGORY.ACTION, "inventory.destroy", phase, data, L.LEVEL.INFO)
    end

    local function ActionsDialogSetup(dialog, data)
        local isCompanionSceneShowing = SCENE_MANAGER and SCENE_MANAGER.scenes and
            SCENE_MANAGER.scenes["companionEquipmentGamepad"] and
            SCENE_MANAGER.scenes["companionEquipmentGamepad"]:IsShowing()

        -- Guard against data.itemActions being nil (saw this in crash logs)
        if not data.itemActions then
            return
        end

        dialog.entryList:SetOnSelectedDataChangedCallback(function(list, selectedData)
            data.itemActions:SetSelectedAction(selectedData and selectedData.action)
        end)
        local parametricList = dialog.info.parametricList
        ZO_ClearNumericallyIndexedTable(parametricList)

        dialog.itemActions = data.itemActions
        local actions = data.itemActions:GetSlotActions()
        local numActions = actions:GetNumSlotActions()

        for i = 1, numActions do
            local action = actions:GetSlotAction(i)
            local actionName = actions:GetRawActionName(action)

            local entryData = ZO_GamepadEntryData:New(actionName)
            entryData:SetIconTintOnSelection(true)
            entryData.setup = ZO_SharedGamepadEntry_OnSetup
            -- Intercept Destroy to route through BetterUI confirm dialog
            local isDestroy = (actionName == GetString(SI_ITEM_ACTION_DESTROY))
            local inBankScene = BETTERUI.Utils.IsBankingSceneShowing()
            if not (isDestroy and inBankScene) then
                -- When in the companion equipment scene, hide the 'Link to Chat' action to avoid insecure SendChatMessage calls
                if actionName == GetString(rawget(_G, "SI_ITEM_ACTION_LINK_TO_CHAT")) and isCompanionSceneShowing then
                    -- skip adding this action entirely
                else
                    if isDestroy then
                        entryData.isBetterUIDestroy = true
                        entryData.action = nil -- prevent engine destroy from being selected/executed
                    else
                        entryData.action = action
                    end

                    local listItem = {
                        template = "ZO_GamepadItemEntryTemplate",
                        entryData = entryData,
                    }
                    table.insert(parametricList, listItem)
                end
            end
        end

        dialog.finishedCallback = data.finishedCallback

        dialog:setupFunc()
    end

    local function FindExistingButtonCallback(keybind)
        local buttons = existingActionDialogInfo and existingActionDialogInfo.buttons or nil
        if type(buttons) ~= "table" then return nil end
        for _, button in ipairs(buttons) do
            if type(button) == "table" and button.keybind == keybind and type(button.callback) == "function" then
                return button.callback
            end
        end
        return nil
    end

    local existingPrimaryCallback = FindExistingButtonCallback("DIALOG_PRIMARY")

    local function CallExistingActionDialogSetup(dialog, data)
        local setup = existingActionDialogInfo and existingActionDialogInfo.setup or nil
        if type(setup) == "function" then
            local ok, err = pcall(setup, dialog, data)
            if ok then
                return true
            end
            TraceInventoryActionDialog("inventory.action_dialog", "previous_setup_failed", {
                error = tostring(err),
                hasData = data ~= nil,
            })
        end
        ActionsDialogSetup(dialog, data)
        return false
    end

    local function CallExistingFinishedCallback(dialog)
        local callback = existingActionDialogInfo and existingActionDialogInfo.finishedCallback or nil
        if type(callback) ~= "function" then return false end
        local ok, err = pcall(callback, dialog)
        if not ok then
            TraceInventoryActionDialog("inventory.action_dialog", "previous_finish_failed", {
                error = tostring(err),
            })
        end
        return ok == true
    end

    local function CallExistingPrimaryCallback(dialog)
        if type(existingPrimaryCallback) ~= "function" then return false end
        local ok, err = pcall(existingPrimaryCallback, dialog)
        if not ok then
            TraceInventoryActionDialog("inventory.action_dialog", "previous_primary_failed", {
                error = tostring(err),
            })
        end
        return ok == true
    end

    BETTERUI.CIM.Dialogs.Register(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG, {
        _betteruiInventoryActionDialogHook = true,
        blockDirectionalInput = true,
        canQueue = true,
        --[[
            Setup function for the shared Y-menu action dialog.
            This is the SINGLE registration point for ZO_GAMEPAD_INVENTORY_ACTION_DIALOG
            and handles BOTH Inventory and Banking scenes.

            Flow:
            1. First checks for quickslot assignment mode (special case)
            2. Then checks scene to determine context:
               - gamepad_inventory_root → fires BETTERUI_EVENT_ACTION_DIALOG_SETUP for Inventory
               - gamepad_banking → fires BETTERUI_EVENT_ACTION_DIALOG_SETUP for Banking
               - Other scenes → delegates to the previously registered dialog setup

            BetterUI must not assume it is the only addon extending this shared
            dialog; unsupported scenes delegate back to the definition captured
            before this registration.
        ]]
        setup = function(dialog, data)
            -- Normal BetterUI override path when enabled/visible
            -- Check both Inventory and Banking scenes with proper nil guards
            local invShowing = BETTERUI.GetModuleEnabled("Inventory")
                and BETTERUI.Utils.IsInventorySceneShowing()
            local bankShowing = BETTERUI.GetModuleEnabled("Banking")
                and BETTERUI.Utils.IsBankingSceneShowing()

            if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.ACTION, "Y-Action Dialog setup fired", {invShowing = invShowing, bankShowing = bankShowing}) end
            TraceInventoryActionDialog("inventory.action_dialog", "setup_before", {
                invShowing = invShowing == true,
                bankShowing = bankShowing == true,
                managed = invShowing == true or bankShowing == true,
                hasData = data ~= nil,
            })

            if invShowing or bankShowing then
                dialog._betteruiManaged = true
                -- Fire callback for BetterUI modules to populate the dialog
                CALLBACK_MANAGER:FireCallbacks("BETTERUI_EVENT_ACTION_DIALOG_SETUP", dialog, data)
                TraceInventoryActionDialog("inventory.action_dialog", "setup_after", {
                    managed = true,
                    invShowing = invShowing == true,
                    bankShowing = bankShowing == true,
                    entryCount = dialog.info and dialog.info.parametricList and #dialog.info.parametricList or nil,
                    selected = BETTERUI.Log and BETTERUI.Log.DescribeListSelection and BETTERUI.Log.DescribeListSelection(dialog.entryList, "dialog") or nil,
                })
                return
            end
            dialog._betteruiManaged = false
            local delegated = CallExistingActionDialogSetup(dialog, data)
            TraceInventoryActionDialog("inventory.action_dialog", "setup_after", {
                managed = false,
                delegated = delegated == true,
                entryCount = dialog.info and dialog.info.parametricList and #dialog.info.parametricList or nil,
            })
        end,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        title = {
            text = function(dialog)
                return GetString(rawget(_G, "SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND"))
            end,
        },

        parametricList = {}, --we'll generate the entries on setup
        finishedCallback = function(dialog)
            local closeCause = dialog and dialog._betteruiCloseCause or "dismissed"
            if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.ACTION, "Y-Action Dialog finished", {managed = dialog and dialog._betteruiManaged, closeCause = closeCause}) end
            TraceInventoryActionDialog("inventory.action_dialog", "finish_before", {
                managed = dialog and dialog._betteruiManaged == true,
                closeCause = closeCause,
                selected = dialog and BETTERUI.Log and BETTERUI.Log.DescribeListSelection and BETTERUI.Log.DescribeListSelection(dialog.entryList, "dialog") or nil,
            })
            if dialog and dialog._betteruiManaged then
                CALLBACK_MANAGER:FireCallbacks("BETTERUI_EVENT_ACTION_DIALOG_FINISH", dialog)
                TraceInventoryActionDialog("inventory.action_dialog", "finish_after", { managed = true })
                dialog._betteruiManaged = nil
                dialog._betteruiCloseCause = nil
                return
            end
            local delegated = CallExistingFinishedCallback(dialog)
            dialog.itemActions = nil
            dialog._betteruiManaged = nil
            dialog._betteruiCloseCause = nil
            if not delegated and dialog.finishedCallback then
                dialog.finishedCallback()
            end
            dialog.finishedCallback = nil
        end,

        buttons = {
            {
                keybind = "DIALOG_NEGATIVE",
                text = GetString(rawget(_G, "SI_DIALOG_CANCEL")),
            },
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(rawget(_G, "SI_GAMEPAD_SELECT_OPTION")),
                callback = function(dialog)
                    if dialog then dialog._betteruiCloseCause = "primary" end
                    TraceInventoryActionDialog("inventory.action_dialog", "primary_callback", {
                        managed = dialog and dialog._betteruiManaged == true,
                        selected = dialog and BETTERUI.Log and BETTERUI.Log.DescribeListSelection and BETTERUI.Log.DescribeListSelection(dialog.entryList, "dialog") or nil,
                    })
                    if dialog and dialog._betteruiManaged then
                        CALLBACK_MANAGER:FireCallbacks("BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM", dialog)
                        TraceInventoryActionDialog("inventory.action_dialog", "primary_dispatched", { managed = true })
                        return
                    end

                    -- Handle BetterUI synthetic Destroy and Link to Chat explicitly even outside BetterUI override
                    -- Note: This is a bare function(dialog) callback — no 'self' in scope.
                    -- All item data must be resolved from the dialog or its attached data.
                    -- Resolve targetData from dialog-available sources (no inventory instance)
                    local function ResolveTargetDataFromDialog()
                        -- 1. Prefer dialog.data.target (companion scene, guild store, etc.)
                        if dialog.data and dialog.data.target then
                            return dialog.data.target
                        end
                        -- 2. Fall back to dialog's entry list selection
                        if dialog.entryList and dialog.entryList.GetTargetData then
                            return BETTERUI.Utils.SafeGetTargetData(dialog.entryList)
                        end
                        return nil
                    end

                    -- BetterUI Destroy rows carry no engine action (entryData.action = nil), so
                    -- itemActions.selectedAction is nil for them. Handle these rows BEFORE the
                    -- selectedAction-gated block below or they would be unreachable.
                    local selectedRow = dialog and dialog.entryList and
                        BETTERUI.Utils.SafeGetTargetData(dialog.entryList)
                    if selectedRow and selectedRow.isBetterUIDestroy then
                        local targetData = ResolveTargetDataFromDialog()
                        if not targetData then
                            TraceInventoryDestroyAction("blocked", nil, {
                                source = "fallback",
                                reason = "missingTarget",
                                dialogName = ZO_GAMEPAD_INVENTORY_ACTION_DIALOG,
                            })
                        else
                            local okSlot, bag, slot = pcall(ZO_Inventory_GetBagAndIndex, targetData)
                            if not okSlot or not bag or not slot then
                                TraceInventoryDestroyAction("blocked", targetData, {
                                    source = "fallback",
                                    reason = "invalidSlot",
                                    dialogName = ZO_GAMEPAD_INVENTORY_ACTION_DIALOG,
                                    error = okSlot and nil or tostring(bag),
                                })
                                return
                            end
                            if bag and slot then
                                local quick = BETTERUI.GetSetting("Inventory", "quickDestroy", false) == true
                                TraceInventoryDestroyAction("action_dialog_selected", targetData, {
                                    source = "fallback",
                                    quickDestroy = quick,
                                })
                                if not CanDestroyTargetWithPolicy(targetData) then
                                    TraceInventoryDestroyAction("blocked", targetData, {
                                        source = "fallback",
                                        reason = "protectionPolicy",
                                        quickDestroy = quick,
                                    })
                                    return
                                end
                                local released = ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                                local ds = targetData.dataSource or targetData
                                local slotType = ds and ds.slotType or targetData.slotType
                                local itemLink = GetItemLink(bag, slot)
                                TraceInventoryDestroyAction("action_dialog_released", targetData, {
                                    source = "fallback",
                                    quickDestroy = quick,
                                    releaseReturned = released ~= nil,
                                })
                                if quick then
                                    TraceInventoryDestroyAction("quick_requested", targetData, {
                                        source = "fallback",
                                        slotType = slotType,
                                    })
                                    BETTERUI.Inventory.TryDestroyItem(bag, slot, true, false, slotType)
                                else
                                    local expectedSlotIdentity =
                                        BETTERUI.Inventory.Utils.CaptureSlotIdentity(bag, slot, targetData)
                                    TraceInventoryDestroyAction("confirm_dialog_request", targetData, {
                                        source = "fallback",
                                        slotType = slotType,
                                        itemLink = itemLink,
                                        expectedSlotIdentity = expectedSlotIdentity,
                                        dialogName = "BETTERUI_CONFIRM_DESTROY_DIALOG",
                                    })
                                    local shownDialog = ZO_Dialogs_ShowDialog(
                                        "BETTERUI_CONFIRM_DESTROY_DIALOG",
                                        {
                                            bagId = bag,
                                            slotIndex = slot,
                                            slotType = slotType,
                                            itemLink = itemLink,
                                            expectedSlotIdentity = expectedSlotIdentity,
                                        },
                                        nil,
                                        true,
                                        true
                                    )
                                    TraceInventoryDestroyAction("confirm_dialog_show", targetData, {
                                        source = "fallback",
                                        slotType = slotType,
                                        itemLink = itemLink,
                                        expectedSlotIdentity = expectedSlotIdentity,
                                        dialogName = "BETTERUI_CONFIRM_DESTROY_DIALOG",
                                        showReturnedDialog = shownDialog ~= nil,
                                        showingAfter = ZO_Dialogs_IsShowing and ZO_Dialogs_IsShowing("BETTERUI_CONFIRM_DESTROY_DIALOG") == true or nil,
                                    })
                                end
                            end
                        end
                        return
                    end

                    if ZO_InventorySlotActions and dialog and dialog.itemActions and dialog.itemActions.selectedAction then
                        local selectedActionName = nil
                        do
                            local actionController = dialog.itemActions
                            if actionController and actionController.selectedAction then
                                selectedActionName = ZO_InventorySlotActions:GetRawActionName(actionController
                                    .selectedAction)
                            end
                        end
                        if selectedActionName == GetString(rawget(_G, "SI_ITEM_ACTION_LINK_TO_CHAT")) then
                            local targetData = ResolveTargetDataFromDialog()
                            if targetData then
                                local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
                                if bag and slot then
                                    local itemLink = GetItemLink(bag, slot, LINK_STYLE_BRACKETS)
                                    if itemLink and itemLink ~= "" then
                                        ZO_LinkHandler_InsertLink(zo_strformat(SI_TOOLTIP_ITEM_NAME, itemLink))
                                    end
                                end
                            end
                            return
                        end
                    end
                    if CallExistingPrimaryCallback(dialog) then
                        return
                    end

                    --original function
                    do
                        local actionController = dialog.itemActions
                        if actionController and actionController.DoSelectedAction then
                            actionController:DoSelectedAction()
                        end
                    end
                end,
            },
        },
    })
    BETTERUI.Inventory._actionDialogHookInstalled = true
end
