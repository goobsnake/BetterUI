--[[
File: Modules/Inventory/Actions/ItemActionsDialog.lua
Purpose: Wires up the "Y-Action" menu (Action Dialog) for inventory items.
         Hooks the native ZO_GAMEPAD_INVENTORY_ACTION_DIALOG.
         Handler implementations live in ItemActionHandlers.lua (loaded before this file).
]]


-- SLOT ACTIONS HELPER

--- Initializes the action slot manager for item interactions.
---
--- Purpose: Creates the helper object for "Y" button actions.
--- Mechanics: Instantiates `BETTERUI.Inventory.SlotActions`.
--- Initializes the action slot manager for item interactions.
function BETTERUI.Inventory.Class:InitializeItemActions()
    self.itemActions = BETTERUI.Inventory.SlotActions:New(KEYBIND_STRIP_ALIGN_LEFT)
end

-- ACTION DIALOG INITIALIZATION (Wiring Only)

--- Initializes the actions dialog (Y-button menu).
---
--- Purpose: Registers BETTERUI_EVENT_ACTION_DIALOG_* callbacks using module-level
---          handlers from ItemActionHandlers.lua.
---
--- The three handlers (Setup, Finish, Confirm) were extracted to
--- ItemActionHandlers.lua to keep both files under 600 lines.
--- They receive `self` (the Inventory.Class instance) via closure capture here.
--- Initializes the actions dialog (Y-button menu).
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
