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

**Publisher**: `Inventory/Actions/ActionDialogHooks.lua`

**Consumers**:
- `Inventory/Actions/ItemActionsDialog.lua` - Populates inventory dialog entries and keybinds
- `Banking/Actions/BankingActions.lua` - Registers banking dialog keybinds

**Payload**: `(dialog, data)` - The active ESO dialog object and the original setup payload.

---

### BETTERUI_EVENT_ACTION_DIALOG_FINISH

**Purpose**: Fired when the action dialog is closing.

**Publisher**: `Inventory/Actions/ActionDialogHooks.lua`

**Consumers**:
- `Inventory/Actions/ItemActionsDialog.lua` - Removes dialog keybinds
- `Banking/Actions/BankingActions.lua` - Removes banking dialog keybinds

**Payload**: `(dialog)` - The dialog being closed.

---

### BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM

**Purpose**: Fired when a user confirms an action in the dialog.

**Publisher**: `Inventory/Actions/ActionDialogHooks.lua`

**Consumers**:
- `Inventory/Actions/ItemActionsDialog.lua` - Executes the selected inventory action
- `Banking/Actions/BankingActions.lua` - Executes the selected banking action

**Payload**: `(dialog)` - The dialog whose selected entry should be confirmed.

---

## Layout Events

### BetterUI_ForceLayoutUpdate

**Purpose**: Forces an immediate layout refresh of orb frames.

**Publisher**:
- `ResourceOrbFrames/Core/OrbEvents.lua` (weapon swap/resource layout changes)
- `ResourceOrbFrames/Settings/SettingsSubmenus.lua` (scale/offset changes)

**Consumers**:
- `ResourceOrbFrames/ResourceOrbFrames.lua` - Rebuilds orb positions through the active visuals/layout pipeline

**Payload**: None

---

## Usage Example

```lua
-- Firing an event
CALLBACK_MANAGER:FireCallbacks("BETTERUI_EVENT_ACTION_DIALOG_FINISH", dialog)

-- Registering for an event
CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_FINISH", function(dialog)
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
