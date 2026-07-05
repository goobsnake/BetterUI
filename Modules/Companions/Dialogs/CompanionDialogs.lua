if not BETTERUI.Companions then return end
local Companions = BETTERUI.Companions

local function IsCompanionSceneShowing()
    local sceneName = rawget(_G, "BETTERUI_COMPANION_EQUIP_SCENE_NAME") or "BETTERUI_CompanionEquipment"
    if SCENE_MANAGER and SCENE_MANAGER.GetScene then
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene and type(scene.IsShowing) == "function" then
            return scene:IsShowing() == true
        end
    end
    return true
end

local function IsCompanionActionDelaySafe()
    return BETTERUI and BETTERUI.Companions == Companions and IsCompanionSceneShowing()
end

local function GetDialogListTargetData(list)
    local getTargetData = BETTERUI.CIM and BETTERUI.CIM.Utils
        and (BETTERUI.CIM.Utils.GetListTargetData or BETTERUI.CIM.Utils.SafeGetTargetData)
    if type(getTargetData) ~= "function" then
        return nil
    end
    return getTargetData(list)
end

local function CountEligibleActionTargets(actionId, items)
    local eligibleCount = 0
    for _, itemData in ipairs(items or {}) do
        if Companions.CanExecuteAction and Companions.CanExecuteAction(actionId, itemData) then
            eligibleCount = eligibleCount + 1
        end
    end
    return eligibleCount
end

local function TraceCompanionDialog(dialogId, phase, data)
    local L = BETTERUI and BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = "Companions"
    data.scene = rawget(_G, "BETTERUI_COMPANION_EQUIP_SCENE_NAME") or "BETTERUI_CompanionEquipment"
    data.currentScene = SCENE_MANAGER and SCENE_MANAGER.GetCurrentSceneName and SCENE_MANAGER:GetCurrentSceneName() or nil
    data.feature = "companion-dialogs"
    data.dialogId = dialogId
    data.fn = data.fn or "Companions.Dialogs"
    if type(L.SetLastAction) == "function" then
        L.SetLastAction({ flow = "companions.dialog", message = tostring(dialogId) .. ":" .. tostring(phase) })
    end
    L.TraceEvent((L.CATEGORY or {}).DIALOG or (L.CATEGORY or {}).ACTION, "companions.dialog", phase, data)
end

local function WrapCompanionDialogKeybind(entry, action)
    local keybinds = BETTERUI.CIM and BETTERUI.CIM.Keybinds
    local anchor = keybinds and keybinds.InputAnchor
    if anchor and type(anchor.Wrap) == "function" then
        return anchor.Wrap(entry, { module = "Companions", action = action })
    end
    return entry
end

local COMPANION_BATCH_DESTROY_DIALOG = "BETTERUI_COMPANION_BATCH_DESTROY_DIALOG"
local COMPANION_ACTION_DIALOG = "BETTERUI_COMPANION_ACTION_DIALOG"
local COMPANION_BATCH_DIALOG = "BETTERUI_COMPANION_BATCH_DIALOG"

local function GetDialogRegistry()
    return BETTERUI.CIM and BETTERUI.CIM.Dialogs or nil
end

local function GetCurrentDialogInfo(dialogName)
    local dialogs = GetDialogRegistry()
    if dialogs and type(dialogs.GetCurrentInfo) == "function" then
        return dialogs.GetCurrentInfo(dialogName)
    end
    return nil
end

local function RegisterCompanionDialog(dialogName, dialogInfo)
    local dialogs = GetDialogRegistry()
    if not (dialogs and type(dialogs.Register) == "function") then
        TraceCompanionDialog(dialogName, "register_skipped", {
            reason = "missingDialogRegistry",
        })
        return false
    end
    return dialogs.Register(dialogName, dialogInfo, { overwrite = true })
end

--- Destroys the given slot descriptors via the quick path, staggered to avoid
--- flooding the server with destroy requests.
local function ExecuteBatchDestroy(destroyTargets)
    local batchId = string.format("companionDestroy:%s:%s",
        tostring(GetGameTimeMilliseconds and GetGameTimeMilliseconds() or 0),
        tostring(#(destroyTargets or {})))
    TraceCompanionDialog(COMPANION_BATCH_DESTROY_DIALOG, "batch_begin", {
        fn = "ExecuteBatchDestroy",
        batchId = batchId,
        targetCount = #(destroyTargets or {}),
    })
    local delay = 0
    for _, target in ipairs(destroyTargets or {}) do
        zo_callLater(function()
            if not IsCompanionActionDelaySafe() then
                TraceCompanionDialog(COMPANION_BATCH_DESTROY_DIALOG, "guard_exit", {
                    fn = "ExecuteBatchDestroy",
                    batchId = batchId,
                    reason = "actionDelayUnsafe",
                })
                return
            end
            Companions.QuickDestroyCompanionItem(target.bagId, target.slotIndex, target.slotType, target, batchId)
        end, delay)
        delay = delay + 80
    end
    zo_callLater(function()
        if not IsCompanionActionDelaySafe() then
            TraceCompanionDialog(COMPANION_BATCH_DESTROY_DIALOG, "guard_exit", {
                fn = "ExecuteBatchDestroy",
                batchId = batchId,
                reason = "actionDelayUnsafe",
            })
            return
        end
        TraceCompanionDialog(COMPANION_BATCH_DESTROY_DIALOG, "batch_end", {
            fn = "ExecuteBatchDestroy",
            batchId = batchId,
            targetCount = #(destroyTargets or {}),
        })
    end, delay)
end

--- Registers the single batch-destroy confirmation dialog. Confirming destroys
--- every selected item through the quick path instead of queueing one
--- confirmation dialog per item.
local function RegisterCompanionBatchDestroyDialog()
    if GetCurrentDialogInfo(COMPANION_BATCH_DESTROY_DIALOG) then
        return
    end

    RegisterCompanionDialog(COMPANION_BATCH_DESTROY_DIALOG, {
        canQueue = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.BASIC },
        title = {
            text = function()
                return GetString(rawget(_G, "SI_PROMPT_TITLE_DESTROY_ITEMS") or "SI_PROMPT_TITLE_DESTROY_ITEMS")
            end,
        },
        mainText = {
            text = function(dialog)
                local count = dialog and dialog.data and dialog.data.itemCount or 0
                local formatId = rawget(_G, "SI_BETTERUI_BATCH_DESTROY_CONFIRM_FORMAT")
                if formatId then
                    return zo_strformat(GetString(formatId), count)
                end
                return zo_strformat("Are you sure you want to destroy <<1>> selected items? This cannot be undone.",
                    count)
            end,
        },
        buttons = {
            WrapCompanionDialogKeybind({
                keybind = "DIALOG_NEGATIVE",
                text = GetString(rawget(_G, "SI_DIALOG_CANCEL") or "SI_DIALOG_CANCEL"),
                callback = function(dialog)
                    TraceCompanionDialog(COMPANION_BATCH_DESTROY_DIALOG, "cancel", {
                        fn = "RegisterCompanionBatchDestroyDialog",
                        itemCount = dialog and dialog.data and dialog.data.itemCount or nil,
                    })
                end,
            }, "batch_destroy_cancel"),
            WrapCompanionDialogKeybind({
                keybind = "DIALOG_PRIMARY",
                text = GetString(rawget(_G, "SI_GAMEPAD_SELECT_OPTION") or "SI_GAMEPAD_SELECT_OPTION"),
                callback = function(dialog)
                    local data = dialog and dialog.data
                    TraceCompanionDialog(COMPANION_BATCH_DESTROY_DIALOG, "confirm", {
                        fn = "RegisterCompanionBatchDestroyDialog",
                        itemCount = data and data.itemCount or nil,
                        hasTargets = data and data.destroyTargets ~= nil or false,
                    })
                    if data and data.destroyTargets then
                        ExecuteBatchDestroy(data.destroyTargets)
                    end
                end,
            }, "batch_destroy_confirm"),
        },
    })
end

--- Batch destroy entry point: collects eligible targets and shows ONE
--- confirmation, then destroys via the quick path. With quickDestroy enabled
--- the confirmation is skipped entirely.
function Companions.ShowBatchDestroyConfirmation(items)
    local destroyTargets = {}
    for _, itemData in ipairs(items or {}) do
        local ds = itemData.dataSource or itemData
        if ds.bagId and ds.slotIndex and Companions.CanExecuteAction("destroy", ds) then
            destroyTargets[#destroyTargets + 1] = {
                bagId = ds.bagId,
                slotIndex = ds.slotIndex,
                slotType = ds.slotType,
                -- Captured so the staggered destroy can re-validate that the
                -- slot still holds the confirmed item before destroying it.
                uniqueId = GetItemUniqueId and GetItemUniqueId(ds.bagId, ds.slotIndex) or nil,
                itemLink = GetItemLink and GetItemLink(ds.bagId, ds.slotIndex) or nil,
            }
        end
    end
    if #destroyTargets == 0 then
        TraceCompanionDialog(COMPANION_BATCH_DESTROY_DIALOG, "show_skipped", {
            fn = "Companions.ShowBatchDestroyConfirmation",
            reason = "noEligibleTargets",
            inputCount = #(items or {}),
        })
        return
    end

    if Companions.GetSetting("quickDestroy") == true then
        TraceCompanionDialog(COMPANION_BATCH_DESTROY_DIALOG, "quick_execute", {
            fn = "Companions.ShowBatchDestroyConfirmation",
            itemCount = #destroyTargets,
        })
        ExecuteBatchDestroy(destroyTargets)
        return
    end

    TraceCompanionDialog(COMPANION_BATCH_DESTROY_DIALOG, "shown", {
        fn = "Companions.ShowBatchDestroyConfirmation",
        itemCount = #destroyTargets,
    })
    ZO_Dialogs_ShowGamepadDialog(COMPANION_BATCH_DESTROY_DIALOG, {
        itemCount = #destroyTargets,
        destroyTargets = destroyTargets,
    })
end

local function RegisterCompanionActionDialog()
    if GetCurrentDialogInfo(COMPANION_ACTION_DIALOG) then
        return
    end

    RegisterCompanionDialog(COMPANION_ACTION_DIALOG, {
        canQueue = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        title = { text = SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND },
        parametricList = {},
        setup = function(dialog)
            local data = dialog.data
            local actions = Companions.BuildActionList(data and data.selectedData)
            local parametricList = dialog.info.parametricList
            ZO_ClearNumericallyIndexedTable(parametricList)
            TraceCompanionDialog(COMPANION_ACTION_DIALOG, "setup", {
                fn = "RegisterCompanionActionDialog",
                actionCount = #actions,
                hasSelectedData = data and data.selectedData ~= nil or false,
            })

            for _, action in ipairs(actions) do
                local entryData = ZO_GamepadEntryData:New(action.name)
                entryData:SetIconTintOnSelection(true)
                entryData.actionId = action.id
                entryData.setup = ZO_SharedGamepadEntry_OnSetup
                table.insert(parametricList, {
                    template = "ZO_GamepadItemEntryTemplate",
                    entryData = entryData,
                })
            end

            dialog:setupFunc()
        end,
        buttons = {
            WrapCompanionDialogKeybind({
                text = SI_DIALOG_CANCEL,
                keybind = "DIALOG_NEGATIVE",
                callback = function()
                    TraceCompanionDialog(COMPANION_ACTION_DIALOG, "cancel", { fn = "RegisterCompanionActionDialog" })
                end,
            }, "action_dialog_cancel"),
            WrapCompanionDialogKeybind({
                text = SI_GAMEPAD_SELECT_OPTION,
                keybind = "DIALOG_PRIMARY",
                callback = function(dialog)
                    local selected = dialog.entryList and GetDialogListTargetData(dialog.entryList) or nil
                    TraceCompanionDialog(COMPANION_ACTION_DIALOG, "confirm", {
                        fn = "RegisterCompanionActionDialog",
                        actionId = selected and selected.actionId or nil,
                        hasSelectedData = dialog.data and dialog.data.selectedData ~= nil or false,
                    })
                    if selected and selected.actionId then
                        local data = dialog.data
                        if data and data.selectedData then
                            Companions.ExecuteAction(selected.actionId, data.selectedData)
                        end
                    end
                end,
            }, "action_dialog_confirm"),
        },
    })
end

local function RegisterCompanionBatchDialog()
    if GetCurrentDialogInfo(COMPANION_BATCH_DIALOG) then
        return
    end

    RegisterCompanionDialog(COMPANION_BATCH_DIALOG, {
        canQueue = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        title = { text = SI_BETTERUI_INV_BATCH_ACTIONS or SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND },
            setup = function(dialog)
                local parametricList = dialog.info.parametricList
                ZO_ClearNumericallyIndexedTable(parametricList)

                local ms = Companions.multiSelectManager
                if ms then
                    local items = ms:GetSelectedItems()
                    local listCount = Companions.instance and Companions.instance.list and Companions.instance.list:GetNumItems() or 0
                    local allSelected = #items > 0 and ms:GetSelectedCount() == listCount
                    TraceCompanionDialog(COMPANION_BATCH_DIALOG, "setup", {
                        fn = "RegisterCompanionBatchDialog",
                        itemCount = #items,
                        selectedCount = ms:GetSelectedCount(),
                        listCount = listCount,
                        allSelected = allSelected,
                    })
                if not allSelected then
                    table.insert(parametricList,
                        BETTERUI.CIM.Dialogs.CreateParametricActionEntry(GetString(SI_BETTERUI_INV_MARK_ALL or "Mark All"), "selectAll"))
                end
                if ms:GetSelectedCount() > 0 then
                    table.insert(parametricList,
                        BETTERUI.CIM.Dialogs.CreateParametricActionEntry(GetString(SI_BETTERUI_INV_ACTION_DESELECT_ALL or "Deselect All"), "deselectAll"))
                end

                local junkCount = CountEligibleActionTargets("junk", items)
                local unjunkCount = CountEligibleActionTargets("unjunk", items)
                local lockCount = CountEligibleActionTargets("lock", items)
                local unlockCount = CountEligibleActionTargets("unlock", items)
                local destroyCount = CountEligibleActionTargets("destroy", items)

                if junkCount > 0 then
                    table.insert(parametricList,
                        BETTERUI.CIM.Dialogs.CreateParametricActionEntry(GetString(SI_ITEM_ACTION_MARK_AS_JUNK), "junk"))
                end
                if unjunkCount > 0 then
                    table.insert(parametricList,
                        BETTERUI.CIM.Dialogs.CreateParametricActionEntry(GetString(SI_ITEM_ACTION_UNMARK_AS_JUNK), "unjunk"))
                end

                if lockCount > 0 then
                    table.insert(parametricList,
                        BETTERUI.CIM.Dialogs.CreateParametricActionEntry(GetString(SI_ITEM_ACTION_MARK_AS_LOCKED), "lock"))
                end
                if unlockCount > 0 then
                    table.insert(parametricList,
                        BETTERUI.CIM.Dialogs.CreateParametricActionEntry(GetString(SI_ITEM_ACTION_UNMARK_AS_LOCKED), "unlock"))
                end

                if destroyCount > 0 and Companions.GetSetting("batchDestroy") == true then
                    table.insert(parametricList,
                        BETTERUI.CIM.Dialogs.CreateParametricActionEntry(GetString(SI_ITEM_ACTION_DESTROY), "destroy"))
                end
            end

            dialog:setupFunc()
        end,
        buttons = {
            WrapCompanionDialogKeybind({
                text = SI_DIALOG_CANCEL,
                keybind = "DIALOG_NEGATIVE",
                callback = function()
                    TraceCompanionDialog(COMPANION_BATCH_DIALOG, "cancel", { fn = "RegisterCompanionBatchDialog" })
                end,
            }, "batch_dialog_cancel"),
            WrapCompanionDialogKeybind({
                text = SI_GAMEPAD_SELECT_OPTION,
                keybind = "DIALOG_PRIMARY",
                callback = function(dialog)
                    local selected = dialog.entryList and GetDialogListTargetData(dialog.entryList) or nil
                    TraceCompanionDialog(COMPANION_BATCH_DIALOG, "confirm", {
                        fn = "RegisterCompanionBatchDialog",
                        actionId = selected and selected.actionId or nil,
                    })
                    if not selected or not selected.actionId then return end
                    local ms = Companions.multiSelectManager
                    if not ms then return end

                    local actionId = selected.actionId
                    if actionId == "selectAll" then
                        local beforeCount = ms:GetSelectedCount()
                        ms:SelectAll()
                        TraceCompanionDialog(COMPANION_BATCH_DIALOG, "select_all", {
                            fn = "RegisterCompanionBatchDialog",
                            selectedCountBefore = beforeCount,
                            selectedCountAfter = ms:GetSelectedCount(),
                        })
                        return
                    elseif actionId == "deselectAll" then
                        local beforeCount = ms:GetSelectedCount()
                        ms:ClearSelections()
                        TraceCompanionDialog(COMPANION_BATCH_DIALOG, "deselect_all", {
                            fn = "RegisterCompanionBatchDialog",
                            selectedCountBefore = beforeCount,
                            selectedCountAfter = ms:GetSelectedCount(),
                        })
                        return
                    end

                    local items = ms:GetSelectedItems()

                    -- Destroy gets one batch-level confirmation; running
                    -- ExecuteAction per item would queue N confirm dialogs
                    -- when quickDestroy is disabled.
                    if actionId == "destroy" then
                        Companions.ShowBatchDestroyConfirmation(items)
                        return
                    end

                    local delay = 0
                    for i, itemData in ipairs(items) do
                        local ds = itemData.dataSource or itemData
                        local bagId = ds.bagId
                        local slotIndex = ds.slotIndex
                        if bagId and slotIndex then
                            zo_callLater(function()
                                if not IsCompanionActionDelaySafe() then
                                    TraceCompanionDialog(COMPANION_BATCH_DIALOG, "guard_exit", {
                                        fn = "RegisterCompanionBatchDialog",
                                        actionId = actionId,
                                        reason = "actionDelayUnsafe",
                                    })
                                    return
                                end
                                Companions.ExecuteAction(actionId, itemData)
                            end, delay)
                            delay = delay + 80
                        end
                    end
                end,
            }, "batch_dialog_confirm"),
        },
    })
end

function Companions.RegisterDialogs()
    RegisterCompanionActionDialog()
    RegisterCompanionBatchDialog()
    RegisterCompanionBatchDestroyDialog()
end
