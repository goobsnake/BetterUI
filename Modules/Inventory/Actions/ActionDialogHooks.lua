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
            local inBankScene = BETTERUI.CIM.Utils.IsBankingSceneShowing()
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

    BETTERUI.CIM.Dialogs.Register(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG, {
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
               - Other scenes → falls back to original ActionsDialogSetup

            IMPORTANT: Do NOT register another ESO_Dialogs[ZO_GAMEPAD_INVENTORY_ACTION_DIALOG]
            elsewhere as it will overwrite this registration and break scene detection.
        ]]
        setup = function(dialog, data)
            -- Normal BetterUI override path when enabled/visible
            -- Check both Inventory and Banking scenes with proper nil guards
            local invShowing = BETTERUI.Settings.Modules["Inventory"].m_enabled
                and BETTERUI.CIM.Utils.IsInventorySceneShowing()
            local bankShowing = BETTERUI.Settings.Modules["Banking"].m_enabled
                and BETTERUI.CIM.Utils.IsBankingSceneShowing()

            if invShowing or bankShowing then
                -- Fire callback for BetterUI modules to populate the dialog
                CALLBACK_MANAGER:FireCallbacks("BETTERUI_EVENT_ACTION_DIALOG_SETUP", dialog, data)
                return
            end
            -- Original function for unsupported scenes
            ActionsDialogSetup(dialog, data)
        end,
        gamepadInfo = { dialogType = GAMEPAD_DIALOGS.PARAMETRIC },
        title = {
            text = function(dialog)
                return GetString(SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND)
            end,
        },

        parametricList = {}, --we'll generate the entries on setup
        finishedCallback = function(dialog)
            if
                (
                    BETTERUI.Settings.Modules["Inventory"].m_enabled
                    and BETTERUI.CIM.Utils.IsInventorySceneShowing()
                )
                or (
                    BETTERUI.Settings.Modules["Banking"].m_enabled
                    and BETTERUI.CIM.Utils.IsBankingSceneShowing()
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
                    if
                        (
                            BETTERUI.Settings.Modules["Inventory"].m_enabled
                            and BETTERUI.CIM.Utils.IsInventorySceneShowing()
                        )
                        or (
                            BETTERUI.Settings.Modules["Banking"].m_enabled
                            and BETTERUI.CIM.Utils.IsBankingSceneShowing()
                        )
                    then
                        CALLBACK_MANAGER:FireCallbacks("BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM", dialog)
                        return
                    end

                    -- Handle BetterUI synthetic Destroy and Link to Chat explicitly even outside BetterUI override
                    -- TODO(bug): 'self' is not in scope here -- this is a bare function(dialog) callback, not a method. self.actionMode/self.itemList/self.craftBagList/self.categoryList all crash with "attempt to index a nil value" when triggered from non-BetterUI scenes
                    if ZO_InventorySlotActions and dialog and dialog.itemActions and dialog.itemActions.selectedAction then
                        -- Check if the selected row is a BetterUI Destroy entry
                        local selectedRow = dialog.entryList and
                            BETTERUI.Inventory.Utils.SafeGetTargetData(dialog.entryList)
                        if selectedRow and selectedRow.isBetterUIDestroy then
                            local targetData
                            local actionMode = self.actionMode
                            if actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
                                targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
                            elseif actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
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
                                if actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE and self and self.itemList then
                                    targetData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
                                elseif actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE and self and self.craftBagList then
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
