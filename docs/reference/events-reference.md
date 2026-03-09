# BetterUI Custom Events Documentation

This document lists all custom CALLBACK_MANAGER events used within BetterUI, including their publishers, consumers, and payload information.

## Event Naming Convention

All BetterUI custom events follow the pattern:
- `BETTERUI_EVENT_*` - General BetterUI events
- `BetterUI_*` - Legacy events (still functional, prefer new naming)

---

## Item Interaction Events

### BETTERUI_EVENT_ACTION_DIALOG_SETUP

**Purpose**: Fired when the Y-button action dialog is being initialized.

**Publisher**: `Inventory/Actions/ItemActionsDialog.lua`

**Consumers**:
- `Inventory/Keybinds/InventoryKeybinds.lua` - Registers dialog keybinds

**Payload**: `(inventorySlot)` - The slot data for the selected item

---

### BETTERUI_EVENT_ACTION_DIALOG_FINISH

**Purpose**: Fired when the action dialog is closing.

**Publisher**: `Inventory/Actions/ItemActionsDialog.lua`

**Consumers**:
- `Inventory/Keybinds/InventoryKeybinds.lua` - Removes dialog keybinds
- `Inventory/Inventory.lua` - Restores main keybinds

**Payload**: None

---

### BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM

**Purpose**: Fired when a user confirms an action in the dialog.

**Publisher**: `Inventory/Actions/ItemActionsDialog.lua`

**Consumers**:
- `Inventory/Inventory.lua` - Executes the selected action

**Payload**: `(actionIndex)` - The index of the selected action

---

## Layout Events

### BetterUI_ForceLayoutUpdate

**Purpose**: Forces an immediate layout refresh of orb frames.

**Publisher**: 
- `ResourceOrbFrames/ResourceOrbFrames.lua` (weapon swap)
- Settings panel (scale/offset changes)

**Consumers**:
- `ResourceOrbFrames/Core/OrbVisuals.lua` - Rebuilds orb positions

**Payload**: None

---

## Usage Example

```lua
-- Firing an event
CALLBACK_MANAGER:FireCallbacks("BETTERUI_EVENT_ACTION_DIALOG_FINISH")

-- Registering for an event
CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_FINISH", function()
    -- Handle the event
end)

-- Unregistering from an event
CALLBACK_MANAGER:UnregisterCallback("BETTERUI_EVENT_ACTION_DIALOG_FINISH", myCallbackFunction)
```

---

## Best Practices

1. **Always unregister** callbacks when the consuming scene/module is hidden
2. **Use descriptive event names** that indicate what happened, not what should happen
3. **Document payloads** clearly when adding new events
4. **Avoid circular event chains** - if A fires to B which fires back to A
