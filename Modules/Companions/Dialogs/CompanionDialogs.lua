--[[
File: Modules/Companions/Dialogs/CompanionDialogs.lua
Purpose: Registers parametric dialogs for companion item actions and batch operations.
]]

if not BETTERUI.Companions then return end
local Companions = BETTERUI.Companions

local function SafeGetTargetData(list)
    if not list then return nil end
    if list.GetTargetData then
        return list:GetTargetData()
    end
    if list.GetSelectedData then
        return list:GetSelectedData()
    end
    return nil
end

-- ACTION DIALOG

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
                    local selected = dialog.entryList and SafeGetTargetData(dialog.entryList)
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

-- BATCH ACTION DIALOG

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

                -- Junk toggle
                if Companions.GetSetting("enableCompanionJunk") ~= false then
                    table.insert(parametricList,
                        BETTERUI.CIM.Dialogs.CreateParametricActionEntry(GetString(SI_ITEM_ACTION_MARK_AS_JUNK), "junk"))
                    table.insert(parametricList,
                        BETTERUI.CIM.Dialogs.CreateParametricActionEntry(GetString(SI_ITEM_ACTION_UNMARK_AS_JUNK), "unjunk"))
                end

                -- Lock toggle
                table.insert(parametricList,
                    BETTERUI.CIM.Dialogs.CreateParametricActionEntry(GetString(SI_ITEM_ACTION_MARK_AS_LOCKED), "lock"))
                table.insert(parametricList,
                    BETTERUI.CIM.Dialogs.CreateParametricActionEntry(GetString(SI_ITEM_ACTION_UNMARK_AS_LOCKED), "unlock"))

                -- Destroy
                if Companions.GetSetting("batchDestroy") ~= false then
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
                    local selected = dialog.entryList and SafeGetTargetData(dialog.entryList)
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
                    local delay = 0
                    for i, itemData in ipairs(items) do
                        local ds = itemData.dataSource or itemData
                        local bagId = ds.bagId
                        local slotIndex = ds.slotIndex
                        if bagId and slotIndex then
                            zo_callLater(function()
                                if actionId == "destroy" then
                                    if Companions.GetSetting("quickDestroy") == true then
                                        DestroyItem(bagId, slotIndex)
                                    else
                                        Companions.ShowCompanionDestroyDialog(bagId, slotIndex)
                                    end
                                elseif actionId == "lock" then
                                    if SetItemPlayerLocked then SetItemPlayerLocked(bagId, slotIndex, true) end
                                elseif actionId == "unlock" then
                                    if SetItemPlayerLocked then SetItemPlayerLocked(bagId, slotIndex, false) end
                                elseif actionId == "junk" then
                                    if SetItemIsJunk then SetItemIsJunk(bagId, slotIndex, true) end
                                elseif actionId == "unjunk" then
                                    if SetItemIsJunk then SetItemIsJunk(bagId, slotIndex, false) end
                                end
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
end
