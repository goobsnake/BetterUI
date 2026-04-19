-- Inventory action-dialog wiring.

function BETTERUI.Inventory.Class:InitializeItemActions()
    self.itemActions = BETTERUI.Inventory.SlotActions:New(KEYBIND_STRIP_ALIGN_LEFT)
    self.itemActions:SetUseKeybindStrip(false)
end

function BETTERUI.Inventory.Class:InitializeActionsDialog()
    local ActionHandlers = BETTERUI.Inventory.ActionHandlers

    CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_SETUP", function(dialog, data)
        ActionHandlers.OnSetup(self, dialog, data)
    end)

    CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_FINISH", function()
        ActionHandlers.OnFinish(self)
    end)

    CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM", function(dialog)
        ActionHandlers.OnConfirm(self, dialog)
    end)

    -- Ensure our secure companion equip override is applied (with retries if needed)
    if BETTERUI.Inventory.EnsureCompanionEquipPatched then
        BETTERUI.Inventory.EnsureCompanionEquipPatched()
    end
end
