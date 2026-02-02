# BetterUI Tribal Knowledge

> This document captures patterns, gotchas, and lessons learned during development.
> Read this at session start. Update it when discovering new insights.

---

## Last Updated

**2026-02-01**: Initial creation during skill restructuring.

---

## Patterns That Work Well

### Scene Lifecycle Management
- Always call `DIRECTIONAL_INPUT:Deactivate(self)` in `OnSceneHiding` to prevent joystick lock-ups
- Use Scene-Gated Activation: never activate input listeners unless `scene:IsShowing()` is true
- Implement symmetric cleanup in `SCENE_HIDDEN` for all modules (Inventory, Banking)

### CIM Infrastructure
- Place shared code in `Modules/CIM/` - never create new "Shared" folders
- Use `BETTERUI.CIM.CONST` for shared constants
- DeferredTaskManager prevents ghost callbacks from `zo_callLater`

### Keybind Management
- Use ethereal keybinds for directional navigation instead of `ZO_DirectionalInput`
- Pre-define keybind descriptors during initialization, not in callbacks
- Use `zo_callLater` with `DIALOG_QUEUE_TIMEOUT_MS` (120ms) when opening dialogs from action menus

---

## Mistakes to Avoid

### The Double Initialization Bug
- `ZO_InitializingObject:Subclass()` automatically calls `Initialize` in `New()`
- Never call `Initialize` manually if using `ZO_InitializingObject`
- `ZO_Object` does NOT auto-call Initialize - you must call it manually

### Stale Reference Trap
- Don't capture dynamic globals at file load time (top-level upvalues)
- Access `BETTERUI.CIM.UnifiedFooter.MODE` inside functions, not at file scope
- Safe: capture parent table (`local CIM = BETTERUI.CIM`), access members dynamically

### Missing Parent Calls
- Always call base class `Initialize` at the start of subclass `Initialize`
- Check native `esoui/` source to ensure all required side-effect initializers are preserved

---

## ESO Engine Quirks

### IsKeyDown Security Error
- Addons cannot call `IsKeyDown` directly or through `ZO_DirectionalInput`
- Solution: Use ethereal keybinds with `UI_SHORTCUT_LEFT_STICK_*` constants

### Mouse Event Consumption
- Empty handlers on parent controls consume events, blocking children
- Set `SetMouseEnabled(true)` but avoid setting `OnMouseDown` handlers on parents

### Anchor Limits
- ESO controls support maximum 2 anchors
- Always call `ClearAnchors()` before `SetAnchor()` when modifying native controls

### Lua Version
- ESO uses Lua 5.1 - no bitwise operators or modern features
- Use `luac5.1 -p` for syntax validation

---

## Performance Learnings

### Timing Constants (Validated)
| Purpose | Delay (ms) | Constant |
|---------|-----------|----------|
| Keybind Refresh | 60 | `KEYBIND_REFRESH_DELAY_MS` |
| Keybind Activation | 40 | `KEYBIND_ACTIVATION_DELAY_MS` |
| Dialog Queueing | 120 | `DIALOG_QUEUE_TIMEOUT_MS` |
| Scene Handler Delay | 200 | `SCENE_HANDLER_DELAY_MS` |

### OnUpdate Optimization
- Avoid expensive operations in `OnUpdate` handlers
- Use `zo_callLater` for deferred work
- Reference constants from `BETTERUI.CIM.CONST.TIMING`

---

## Module-Specific Notes

### Banking
- Most aggressive cleanup of all modules (flushes `DIRECTIONAL_INPUT` stack)
- Must call `self.list:Activate()` on entry for explicit input acquisition
- Uses `PerformFullUpdateOnBagCache` after quantity dialogs

### Inventory
- Historically had weaker cleanup than Banking
- Now standardized with symmetric cleanup guards in `SCENE_HIDDEN`
- Uses `TargetDataChanged` callback for high-frequency keybind updates

### CIM (Common Interface Module)
- Central location for all shared code
- DeferredTaskManager handles async task cancellation
- SceneLifecycleManager standardizes scene callbacks

---

## Debugging Tips

### Joystick Lock-up
1. Use `/buidebug` to inspect `DIRECTIONAL_INPUT` stack
2. Check which module leaked an input listener
3. Verify `OnSceneHiding` deactivates directional input

### Load-Time Nil Errors
1. Check manifest ordering in `BetterUI.txt`
2. Verify base class is loaded before subclass
3. Look for "Silent Subclass Failure" - base class may be nil

### First-Frame Rendering Issues
1. Use XML `<FadeGradient>` instead of Lua `SetGradientColors` for initial load
2. Explicit anchoring with offsets may return 0 on first frame
3. Use parent container anchoring instead of calculated offsets

<!-- TODO(doc): Add section for "Edge Cases and Known Gotchas"
     Include: callback cleanup patterns, ZOS global override risks,
     and scene lifecycle timing issues discovered in sr_engineering_team_review.md -->

