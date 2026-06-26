-- Inventory action-dialog wiring.

function BETTERUI.Inventory.Class:InitializeItemActions()
    self.itemActions = BETTERUI.Inventory.SlotActions:New(KEYBIND_STRIP_ALIGN_LEFT)
    self.itemActions:SetUseKeybindStrip(false)
end

function BETTERUI.Inventory.Class:InitializeActionsDialog()
    local ActionHandlers = BETTERUI.Inventory.ActionHandlers

    BETTERUI.Inventory._actionDialogOwner = self
    if not BETTERUI.Inventory._actionDialogCallbacksRegistered then
        CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_SETUP", function(dialog, data)
            local owner = BETTERUI.Inventory._actionDialogOwner
            if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.ACTION, "Action dialog setup callback fired", {entriesCount = data and data.entries and #data.entries}) end
            ActionHandlers.OnSetup(owner, dialog, data)
        end)

        CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_FINISH", function(dialog)
            local owner = BETTERUI.Inventory._actionDialogOwner
            ActionHandlers.OnFinish(owner, dialog)
        end)

        CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM", function(dialog)
            local owner = BETTERUI.Inventory._actionDialogOwner
            ActionHandlers.OnConfirm(owner, dialog)
        end)

        BETTERUI.Inventory._actionDialogCallbacksRegistered = true
    end

    -- Ensure our secure companion equip override is applied (with retries if needed)
    if BETTERUI.Inventory.EnsureCompanionEquipPatched then
        BETTERUI.Inventory.EnsureCompanionEquipPatched()
    end
end
