if not BETTERUI.Companions then return end
local Companions = BETTERUI.Companions

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

--- Destroys the given slot descriptors via the quick path, staggered to avoid
--- flooding the server with destroy requests.
local function ExecuteBatchDestroy(destroyTargets)
    local delay = 0
    for _, target in ipairs(destroyTargets) do
        zo_callLater(function()
            Companions.QuickDestroyCompanionItem(target.bagId, target.slotIndex, target.slotType, target)
        end, delay)
        delay = delay + 80
    end
end

local COMPANION_BATCH_DESTROY_DIALOG = "BETTERUI_COMPANION_BATCH_DESTROY_DIALOG"

--- Registers the single batch-destroy confirmation dialog. Confirming destroys
--- every selected item through the quick path instead of queueing one
--- confirmation dialog per item.
local function RegisterCompanionBatchDestroyDialog()
    if ZO_Dialogs_IsDialogRegistered and ZO_Dialogs_IsDialogRegistered(COMPANION_BATCH_DESTROY_DIALOG) then
        return
    end

    ZO_Dialogs_RegisterCustomDialog(COMPANION_BATCH_DESTROY_DIALOG, {
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
            {
                keybind = "DIALOG_NEGATIVE",
                text = GetString(rawget(_G, "SI_DIALOG_CANCEL") or "SI_DIALOG_CANCEL"),
            },
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(rawget(_G, "SI_GAMEPAD_SELECT_OPTION") or "SI_GAMEPAD_SELECT_OPTION"),
                callback = function(dialog)
                    local data = dialog and dialog.data
                    if data and data.destroyTargets then
                        ExecuteBatchDestroy(data.destroyTargets)
                    end
                end,
            },
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
        return
    end

    if Companions.GetSetting("quickDestroy") == true then
        ExecuteBatchDestroy(destroyTargets)
        return
    end

    ZO_Dialogs_ShowGamepadDialog(COMPANION_BATCH_DESTROY_DIALOG, {
        itemCount = #destroyTargets,
        destroyTargets = destroyTargets,
    })
end

local function RegisterCompanionActionDialog()
    if ZO_Dialogs_IsDialogRegistered and ZO_Dialogs_IsDialogRegistered("BETTERUI_COMPANION_ACTION_DIALOG") then
        return
    end

    ZO_Dialogs_RegisterCustomDialog("BETTERUI_COMPANION_ACTION_DIALOG", {
        canQueue = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        title = { text = SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND },
        parametricList = {},
        setup = function(dialog)
            local data = dialog.data
            local actions = Companions.BuildActionList(data and data.selectedData)
            local parametricList = dialog.info.parametricList
            ZO_ClearNumericallyIndexedTable(parametricList)

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
            {
                text = SI_DIALOG_CANCEL,
                keybind = "DIALOG_NEGATIVE",
            },
            {
                text = SI_GAMEPAD_SELECT_OPTION,
                keybind = "DIALOG_PRIMARY",
                callback = function(dialog)
                    local selected = dialog.entryList and GetDialogListTargetData(dialog.entryList) or nil
                    if selected and selected.actionId then
                        local data = dialog.data
                        if data and data.selectedData then
                            Companions.ExecuteAction(selected.actionId, data.selectedData)
                        end
                    end
                end,
            },
        },
    })
end

local function RegisterCompanionBatchDialog()
    if ZO_Dialogs_IsDialogRegistered and ZO_Dialogs_IsDialogRegistered("BETTERUI_COMPANION_BATCH_DIALOG") then
        return
    end

    ZO_Dialogs_RegisterCustomDialog("BETTERUI_COMPANION_BATCH_DIALOG", {
        canQueue = true,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        title = { text = SI_BETTERUI_INV_BATCH_ACTIONS or SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND },
        setup = function(dialog)
            local parametricList = dialog.info.parametricList
            ZO_ClearNumericallyIndexedTable(parametricList)

            local ms = Companions.multiSelectManager
            if ms then
                local items = ms:GetSelectedItems()
                local allSelected = #items > 0 and ms:GetSelectedCount() == (Companions.instance.list and Companions.instance.list:GetNumItems() or 0)
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

                if destroyCount > 0 and Companions.GetSetting("batchDestroy") ~= false then
                    table.insert(parametricList,
                        BETTERUI.CIM.Dialogs.CreateParametricActionEntry(GetString(SI_ITEM_ACTION_DESTROY), "destroy"))
                end
            end

            dialog:setupFunc()
        end,
        buttons = {
            {
                text = SI_DIALOG_CANCEL,
                keybind = "DIALOG_NEGATIVE",
            },
            {
                text = SI_GAMEPAD_SELECT_OPTION,
                keybind = "DIALOG_PRIMARY",
                callback = function(dialog)
                    local selected = dialog.entryList and GetDialogListTargetData(dialog.entryList) or nil
                    if not selected or not selected.actionId then return end
                    local ms = Companions.multiSelectManager
                    if not ms then return end

                    local actionId = selected.actionId
                    if actionId == "selectAll" then
                        ms:SelectAll()
                        return
                    elseif actionId == "deselectAll" then
                        ms:ClearSelections()
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
                                Companions.ExecuteAction(actionId, itemData)
                            end, delay)
                            delay = delay + 80
                        end
                    end
                end,
            },
        },
    })
end

function Companions.RegisterDialogs()
    RegisterCompanionActionDialog()
    RegisterCompanionBatchDialog()
    RegisterCompanionBatchDestroyDialog()
end
