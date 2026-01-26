--[[
File: Modules/Inventory/Actions/ActionDialogHooks.lua
Purpose: Hooks the native "Y-Action" dialog (ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) to Inject
         custom behaviors like Quickslot Assignment and BetterUI's safer Destroy logic.
]]

--------------------------------------------------------------------------------
-- DIALOG HOOKS (System Integration)
--------------------------------------------------------------------------------

--- Hooks the native Y-button Action Dialog.
---
--- Purpose: Replaces or extends the `ZO_GAMEPAD_INVENTORY_ACTION_DIALOG`.
--- Mechanics:
--- - Registers a **custom** dialog with the **same name** as the engine's dialog (`ZO_GAMEPAD_INVENTORY_ACTION_DIALOG`).
--- - This effectively overrides the native dialog definition.
--- - Implements custom `setup` to handle:
---   - Quickslot Assignment (embedded).
---   - Safe "Destroy" (BetterUI replacement).
---   - "Link to Chat" (safety checks).
--- - Implements custom `buttons` (Select/Cancel) to route actions correctly.
function BETTERUI.Inventory.HookActionDialog()
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
            -- Intercept Destroy/Delete to route through BetterUI confirm dialog
            local isDestroy = (actionName == GetString(SI_ITEM_ACTION_DESTROY))
                or (SI_ITEM_ACTION_DELETE and actionName == GetString(SI_ITEM_ACTION_DELETE))
            local inBankScene = SCENE_MANAGER
                and SCENE_MANAGER.scenes
                and SCENE_MANAGER.scenes["gamepad_banking"]
                and SCENE_MANAGER.scenes["gamepad_banking"]:IsShowing()
            if not (isDestroy and inBankScene) then
                -- When in the companion equipment scene, hide the 'Link to Chat' action to avoid insecure SendChatMessage calls
                if actionName == GetString(SI_ITEM_ACTION_LINK_TO_CHAT) and isCompanionSceneShowing then
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

    ZO_Dialogs_RegisterCustomDialog(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG, {
        blockDirectionalInput = true,
        canQueue = true,
        setup = function(dialog, data)
            -- Always handle our embedded quickslot mode here for robustness
            if data and data.quickslotAssign and data.target then
                -- Title provided via dialog's dynamic title function; avoid overriding here
                local parametricList = dialog.info.parametricList
                ZO_ClearNumericallyIndexedTable(parametricList)

                local target = data.target
                local hasUnassign = false
                local assignedIndex = nil
                if FindActionSlotMatchingItem then
                    assignedIndex =
                        FindActionSlotMatchingItem(target.bagId, target.slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
                    if assignedIndex then
                        hasUnassign = true
                        -- Ensure the Remove row text is visible; icon not required
                        local removeText = GetString(SI_ITEM_ACTION_REMOVE)
                        if not removeText or removeText == "" then
                            removeText = "Remove"
                        end
                        local unassignEntry = ZO_GamepadEntryData:New(removeText)
                        unassignEntry:SetIconTintOnSelection(true)
                        -- Ensure text is visible on dark background
                        local normalColor = ZO_NORMAL_TEXT or ZO_ColorDef:New(1, 1, 1, 1)
                        local selectedColor = ZO_SELECTED_TEXT or ZO_ColorDef:New(1, 1, 1, 1)
                        if unassignEntry.SetNameColors then
                            unassignEntry:SetNameColors(normalColor, selectedColor)
                        end
                        unassignEntry.isUnassign = true
                        unassignEntry.setup = ZO_SharedGamepadEntry_OnSetup
                        table.insert(
                            parametricList,
                            { template = "ZO_GamepadMenuEntryTemplate", entryData = unassignEntry }
                        )
                    end
                end

                local function slotLabel(idx)
                    if idx == 4 then
                        return GetString(SI_BETTERUI_DIR_NORTH)
                    elseif idx == 5 then
                        return GetString(SI_BETTERUI_DIR_NORTHWEST)
                    elseif idx == 6 then
                        return GetString(SI_BETTERUI_DIR_WEST)
                    elseif idx == 7 then
                        return GetString(SI_BETTERUI_DIR_SOUTHWEST)
                    elseif idx == 8 then
                        return GetString(SI_BETTERUI_DIR_SOUTH)
                    elseif idx == 1 then
                        return GetString(SI_BETTERUI_DIR_SOUTHEAST)
                    elseif idx == 2 then
                        return GetString(SI_BETTERUI_DIR_EAST)
                    elseif idx == 3 then
                        return GetString(SI_BETTERUI_DIR_NORTHEAST)
                    end
                    return tostring(idx)
                end

                -- Clockwise ordering starting at North: N, NE, E, SE, S, SW, W, NW
                local orderedSlots = { 4, 3, 2, 1, 8, 7, 6, 5 }
                for _, slotIndex in ipairs(orderedSlots) do
                    local icon = GetSlotTexture and GetSlotTexture(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) or nil
                    local lower = type(icon) == "string" and icon:lower() or nil
                    if not icon or icon == "" or (lower and string.find(lower, "quickslot_empty", 1, true)) then
                        icon = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_quickslot.dds"
                    end
                    local entryData = ZO_GamepadEntryData:New(slotLabel(slotIndex), icon)
                    if entryData.AddIcon and icon then
                        entryData:AddIcon(icon)
                    end
                    -- Flash all non-current slots; keep the currently assigned slot steady
                    local isCurrent = assignedIndex ~= nil and (slotIndex == assignedIndex)
                    local shouldFlash = not isCurrent
                    entryData.alphaChangeOnSelection = shouldFlash
                    entryData.showBarEvenWhenUnselected = shouldFlash
                    entryData:SetIconTintOnSelection(shouldFlash)
                    entryData.slotIndex = slotIndex
                    entryData.setup = ZO_SharedGamepadEntry_OnSetup
                    local templateName = isCurrent and "ZO_GamepadMenuEntryTemplate" or "ZO_GamepadItemEntryTemplate"
                    table.insert(parametricList, { template = templateName, entryData = entryData })
                end

                dialog.quickslotTarget = target
                dialog:setupFunc()
                if dialog.entryList and dialog.entryList.SetSelectedIndexWithoutAnimation then
                    local offset = hasUnassign and 1 or 0
                    if assignedIndex then
                        local indexMap = {}
                        for pos, idx in ipairs(orderedSlots) do
                            indexMap[idx] = pos
                        end
                        local listPos = (indexMap[assignedIndex] or 1) + offset
                        dialog.entryList:SetSelectedIndexWithoutAnimation(listPos, true, false)
                    else
                        dialog.entryList:SetSelectedIndexWithoutAnimation(hasUnassign and 2 or 1, true, false)
                    end
                end
                return
            end
            -- Debug: if the selected action is Equip and the companion scene is active, check if patch is present


            -- Normal BetterUI override path when enabled/visible
            -- Title provided via dialog's dynamic title function; avoid overriding here
            if
                (
                    BETTERUI.Settings.Modules["Inventory"].m_enabled
                    and SCENE_MANAGER.scenes["gamepad_inventory_root"]:IsShowing()
                )
                or (
                    BETTERUI.Settings.Modules["Banking"].m_enabled
                    and SCENE_MANAGER.scenes["gamepad_banking"]:IsShowing()
                )
            then
                CALLBACK_MANAGER:FireCallbacks("BETTERUI_EVENT_ACTION_DIALOG_SETUP", dialog, data)
                return
            end
            -- Original function
            ActionsDialogSetup(dialog, data)
        end,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        title = {
            text = function(dialog)
                if dialog and dialog.data and dialog.data.quickslotAssign then
                    return "Assign Quickslots"
                end
                return GetString(SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND)
            end,
        },
        parametricList = {}, --we'll generate the entries on setup
        finishedCallback = function(dialog)
            if
                (
                    BETTERUI.Settings.Modules["Inventory"].m_enabled
                    and SCENE_MANAGER.scenes["gamepad_inventory_root"]:IsShowing()
                )
                or (
                    BETTERUI.Settings.Modules["Banking"].m_enabled
                    and SCENE_MANAGER.scenes["gamepad_banking"]:IsShowing()
                )
            then
                CALLBACK_MANAGER:FireCallbacks("BETTERUI_EVENT_ACTION_DIALOG_FINISH", dialog)
                return
            end
            --original function
            dialog.itemActions = nil
            if dialog.finishedCallback then
                dialog.finishedCallback()
            end
            dialog.finishedCallback = nil
        end,

        buttons = {
            {
                keybind = "DIALOG_NEGATIVE",
                text = GetString(SI_DIALOG_CANCEL),
            },
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(SI_GAMEPAD_SELECT_OPTION),
                callback = function(dialog)
                    -- Handle embedded quickslot mode regardless of BetterUI override gating
                    if dialog and dialog.data and dialog.data.quickslotAssign and dialog.entryList then
                        local target = dialog.data.target or dialog.quickslotTarget
                        if target then
                            local quickslot_wheel = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
                            local selected = BETTERUI.Inventory.Utils.SafeGetTargetData(dialog.entryList)
                            if selected and selected.isUnassign then
                                local assigned = FindActionSlotMatchingItem
                                    and FindActionSlotMatchingItem(target.bagId, target.slotIndex, quickslot_wheel)
                                if assigned then
                                    CallSecureProtected("ClearSlot", assigned, quickslot_wheel)
                                    if SOUNDS and PlaySound then
                                        PlaySound(SOUNDS.GAMEPAD_MENU_BACK)
                                    end
                                end
                            else
                                local wheelSlotIndex = (selected and selected.slotIndex) or 4
                                CallSecureProtected(
                                    "SelectSlotItem",
                                    target.bagId,
                                    target.slotIndex,
                                    wheelSlotIndex,
                                    quickslot_wheel
                                )
                                if SOUNDS and PlaySound then
                                    PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)
                                end
                            end
                            ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                            zo_callLater(function()
                                if GAMEPAD_INVENTORY then
                                    GAMEPAD_INVENTORY:RefreshItemList()
                                end
                            end, 150)
                        end
                        return
                    end
                    if
                        (
                            BETTERUI.Settings.Modules["Inventory"].m_enabled
                            and SCENE_MANAGER.scenes["gamepad_inventory_root"]:IsShowing()
                        )
                        or (
                            BETTERUI.Settings.Modules["Banking"].m_enabled
                            and SCENE_MANAGER.scenes["gamepad_banking"]:IsShowing()
                        )
                    then
                        CALLBACK_MANAGER:FireCallbacks("BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM", dialog)
                        return
                    end
                    -- Handle BetterUI synthetic Destroy and Link to Chat explicitly even outside BetterUI override
                    if ZO_InventorySlotActions and dialog and dialog.itemActions and dialog.itemActions.selectedAction then
                        -- Check if the selected row is a BetterUI Destroy entry
                        local selectedRow = dialog.entryList and
                        BETTERUI.Inventory.Utils.SafeGetTargetData(dialog.entryList)
                        if selectedRow and selectedRow.isBetterUIDestroy then
                            local targetData
                            local actionMode = self.actionMode
                            if actionMode == ITEM_LIST_ACTION_MODE then
                                targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
                            elseif actionMode == CRAFT_BAG_ACTION_MODE then
                                targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList)
                            else
                                targetData = self:GenerateItemSlotData(BETTERUI.Inventory.Utils.SafeGetTargetData(self
                                .categoryList))
                            end
                            local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
                            if bag and slot then
                                ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                                local itemLink = GetItemLink(bag, slot)
                                local quick = BETTERUI
                                    and BETTERUI.Settings
                                    and BETTERUI.Settings.Modules
                                    and BETTERUI.Settings.Modules["Inventory"]
                                    and BETTERUI.Settings.Modules["Inventory"].quickDestroy == true
                                if quick then
                                    BETTERUI.Inventory.TryDestroyItem(bag, slot, true)
                                else
                                    ZO_Dialogs_ShowDialog(
                                        "BETTERUI_CONFIRM_DESTROY_DIALOG",
                                        { bagId = bag, slotIndex = slot, itemLink = itemLink },
                                        nil,
                                        true,
                                        true
                                    )
                                end
                            end
                            return
                        end
                        local selectedActionName = nil
                        do
                            local actionController = nil
                            if dialog and dialog.itemActions then
                                actionController = dialog.itemActions
                            elseif self and self.itemActions then
                                actionController = self.itemActions
                            end
                            if actionController and actionController.selectedAction then
                                selectedActionName = ZO_InventorySlotActions:GetRawActionName(actionController
                                    .selectedAction)
                            end
                        end
                        if selectedActionName == GetString(SI_ITEM_ACTION_LINK_TO_CHAT) then
                            local targetData
                            -- Prefer dialog-local target data when available (companion scene uses dialog-targets)
                            if dialog.data and dialog.data.target then
                                targetData = dialog.data.target
                            elseif dialog.entryList and dialog.entryList.GetTargetData then
                                targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(dialog.entryList)
                            else
                                local actionMode = self and self.actionMode or nil
                                if actionMode == ITEM_LIST_ACTION_MODE and self and self.itemList then
                                    targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
                                elseif actionMode == CRAFT_BAG_ACTION_MODE and self and self.craftBagList then
                                    targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList)
                                elseif self and self.categoryList then
                                    targetData = self:GenerateItemSlotData(BETTERUI.Inventory.Utils.SafeGetTargetData(
                                    self.categoryList))
                                end
                            end
                            local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
                            if bag and slot then
                                local itemLink = GetItemLink(bag, slot)
                                if itemLink then
                                    ZO_LinkHandler_InsertLink(zo_strformat("[<<2>>]", SI_TOOLTIP_ITEM_NAME, itemLink))
                                end
                            end
                            return
                        end
                    end
                    --original function
                    do
                        local actionController = nil
                        if dialog and dialog.itemActions then
                            actionController = dialog.itemActions
                        elseif self and self.itemActions then
                            actionController = self.itemActions
                        end
                        if actionController and actionController.DoSelectedAction then
                            actionController:DoSelectedAction()
                        end
                    end
                end,
            },
        },
    })
end
