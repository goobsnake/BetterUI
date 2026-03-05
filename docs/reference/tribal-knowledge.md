# BetterUI Tribal Knowledge

> This document captures patterns, gotchas, and lessons learned during development.
> Read this at session start. Update it when discovering new insights.

---

## Last Updated

**2026-02-07**: Added API constant rename compat pattern, `zo_mixin` hook pattern, `SetItemIsJunk` async quirk, and more.

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

### XML Template Constants
- ESO XML cannot reference Lua namespace syntax (`BETTERUI.CIM.CONST.*`)
- Global constants like `BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH` exist **only** for XML template support
- In **Lua code**: Always use `BETTERUI.CIM.CONST.LAYOUT.PANEL.WIDTH` (canonical)
- In **XML templates**: Use `BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH` (required)
- All XML-support globals are defined in `CIM/Constants.lua` and delegate to canonical paths

### Keybind Management
- Use ethereal keybinds for directional navigation instead of `ZO_DirectionalInput`
- Pre-define keybind descriptors during initialization, not in callbacks
- Use `zo_callLater` with `DIALOG_QUEUE_TIMEOUT_MS` (120ms) when opening dialogs from action menus

### Error Handling Patterns

**Use `BETTERUI.CIM.SafeExecute()`:**
- External API calls that may fail unpredictably (addon interop, ESO API edge cases)
- Event handlers where errors shouldn't crash the addon
- Operations with external dependencies (e.g., Master Merchant, TTC)

**Use Guard Clauses:**
- Input validation (nil checks, type checks)
- State preconditions (e.g., ensuring a window is open before operating on it)
- Flow control where failure is expected/normal behavior

**Never** use SafeExecute to mask bugs - always investigate root causes first.

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

### Quest Item API Gotchas
- `UseQuestTool()` and `UseQuestItem()` are **NOT** protected functions — `CallSecureProtected` silently fails on them
- Always call them directly: `UseQuestTool(questIndex, toolIndex)`, `UseQuestItem(questIndex, stepIndex, conditionIndex)`
- Do **NOT** call `SCENE_MANAGER:Hide()` before quest item APIs — the engine handles scene transitions automatically (book reader, world map, etc.) and keeps the source scene on the stack
- Reference implementation: `esoui/ingame/inventory/inventoryslot.lua:420` (`TryUseQuestItem`)

### Texture Path Validation
- `EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_quickslot_empty.dds` does **NOT** exist — using it renders a white box
- For empty quickslot slots, use `ZO_UTILITY_SLOT_EMPTY_TEXTURE` (ESO's own constant from `utilitywheel_shared.lua`)
- The valid quickslot *category* icon is `EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_quickslot.dds`

### Position Persistence Gap
- `SaveListPosition()` must update **both** `CIM.PositionManager` AND the local fields read by `SwitchActiveList`
- Fields: `savedInventoryCategoryKey`, `savedInventoryPositionsByKey`, `savedInventorySelectedItemUniqueByKey` (plus CraftBag equivalents)
- If these fields are nil/empty, `SwitchActiveList` defaults to category index 1 and item index 1

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
- Use `luac -p` for syntax validation

### SetItemIsJunk Is Asynchronous
- `SetItemIsJunk(bagId, slotIndex, isJunk)` does NOT update engine state synchronously
- `IsItemJunk(bagId, slotIndex)` returns **stale data** immediately after `SetItemIsJunk()`
- The engine processes the change asynchronously and fires `EVENT_INVENTORY_SINGLE_SLOT_UPDATE` when done
- At that point, `IsItemJunk()` returns the correct value and `SHARED_INVENTORY` cache is updated
- **Pattern**: Do not call `RefreshCategoryList` immediately after `SetItemIsJunk`; instead rely on the `SingleSlotInventoryUpdate` callback to schedule a coalesced refresh

### Currency API Constant Renames
- ZOS periodically renames currency constants (e.g., `CURT_EVENT_TICKETS` → `CURT_TRADE_BARS`, `CURT_ENDEAVOR_SEALS` → `CURT_SEALS`)
- The `addoncompatibilityaliases` file defines backwards-compat aliases, but **addons do not load this file** — only the game client uses it
- Always use `CURT_NEW_NAME or CURT_OLD_NAME` at file scope for constants that may have been renamed
- See `CurrencyManager.lua` lines 25-27 for the canonical pattern

### zo_mixin Copies Methods at Init Time
- `ZO_Tooltip:Initialize` uses `zo_mixin(control, ..., self)` which copies all methods from the class table onto the control instance
- Modifying `ZO_Tooltip.SomeMethod` AFTER tooltip controls are created has **no effect** — controls already have copies
- To hook tooltip methods, override them directly on each control instance (e.g., `tooltipControl.AddTopLinesToTopSection = ...`)
- Use `GAMEPAD_TOOLTIPS:GetTooltip(tooltipType)` to get the actual control object

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
- Quest items use `SLOT_TYPE_QUEST_ITEM` — they lack `meetsUsageRequirement` (only set by `GetItemInfo` for bag items)
- `sortPriorityName` must be pre-computed before `table.sort` in `RefreshItemList` for consistent sort order

### CIM (Common Interface Module)
- Central location for all shared code
- DeferredTaskManager handles async task cancellation
- SceneLifecycleManager standardizes scene callbacks

---

## UI Layout & Positioning

> [!IMPORTANT]
> This section documents the **final, validated values** for Banking and Inventory UI elements.
> When making adjustments, update this section to maintain accuracy.

### Quick Reference Tables

#### Banking Layout Values (`InterfaceLibrary.xml`)

| Element | Anchor | Property | Value | Notes |
|---------|--------|----------|-------|-------|
| **Header/Tab Bar** |
| Category Title | TOPLEFT | offsetX/Y | 45 / -4 | `BETTERUI_HeaderTitleAnchors` |
| Tab Bar DividerF | L→R anchored | RIGHT offsetY | 90 | First tab divider |
| Tab Bar DividerS | L→R anchored | RIGHT offsetY | 94 | Second tab divider (4px below) |
| Column Header Divider | L→R anchored | offsetX/Y | 20 / 125 | Below column headers (NAME/TYPE/etc.) |
| **Item List** |
| List TOPLEFT | HeaderHeader | offsetX/Y | -27 / 15 | Negative X shifts right |
| List BOTTOMRIGHT | FooterFooter | offsetX/Y | 0 / -8 | Negative Y shrinks list up |
| **Scroll Indicator** (`Banking.lua:162`) |
| offsetX | - | - | 25 | Distance from right edge |
| offsetTopY | - | - | -5 | Top margin (negative = up) |
| offsetBottomY | - | - | 1 | Bottom margin |
| **Footer Elements** |
| SelectBg (background) | CENTER | Dimensions | PANEL_WIDTH × 90 | Withdraw/Deposit background |
| DividerBottomT | TOPLEFT SelectBg | offsetX/Y | 45 / 0 | Top footer divider |
| DividerBottomB | TOPLEFT SelectBg | offsetX/Y | 45 / 4 | Bottom footer divider (4px gap) |
| Footer Divider Width | - | x dimension | 1325 | Hard-coded, slightly < panel |
| Deposit Icon | RIGHT | offsetX | -15 | Negative = left inset |

#### Inventory Layout Values

| Element | File | Property | Value | Notes |
|---------|------|----------|-------|-------|
| **Scroll Indicator** (`ItemListManager.lua:138`, `InventoryList.lua:608`) |
| offsetX | - | - | 5 | Much closer to edge than Banking |
| offsetTopY | - | - | -8 | Standard top margin |
| offsetBottomY | - | - | 6 | Standard bottom margin |

### Anchor Direction Reference

Understanding ESO anchor offsets:

```
                    ← offsetX negative    offsetX positive →
                    
                              ↑ offsetY negative
                              │
                              │
    offsetY positive →        ▼
```

| Direction | Anchor Point | Offset Sign |
|-----------|-------------|-------------|
| Move DOWN | Any | offsetY **positive** (+) |
| Move UP | Any | offsetY **negative** (-) |
| Move RIGHT | Any | offsetX **positive** (+) |
| Move LEFT | Any | offsetX **negative** (-) |
| Extend past RIGHT edge | RIGHT anchor | offsetX **positive** (+) |
| Inset from RIGHT edge | RIGHT anchor | offsetX **negative** (-) |

### Key Files for UI Adjustments

| File | Purpose | Key Elements |
|------|---------|--------------|
| `CIM/Templates/InterfaceLibrary.xml` | Banking UI structure | Header, list, footer, dividers |
| `CIM/Templates/GenericHeader.xml` | Inventory header | Column headers, dividers |
| `CIM/Constants.lua` | Shared constants | `BETTERUI_GAMEPAD_*` globals |
| `Banking/Banking.lua` | Banking scroll indicator | `ScrollIndicator.Initialize()` call |
| `Inventory/Lists/ItemListManager.lua` | Inventory scroll indicator | `ScrollIndicator.Initialize()` call |
| `Inventory/Lists/InventoryList.lua` | Inventory list scroll | `ScrollIndicator.Initialize()` call |

### ScrollIndicator.Initialize() Signature

```lua
BETTERUI.CIM.ScrollIndicator.Initialize(listControl, offsetX, offsetTopY, offsetBottomY, listObject)
```

| Parameter | Description | Banking | Inventory |
|-----------|-------------|---------|-----------|
| `offsetX` | Horizontal position from right | 25 | 5 |
| `offsetTopY` | Top margin (negative = up) | -5 | -8 |
| `offsetBottomY` | Bottom margin | 1 | 6 |

### Footer Divider Structure (Banking)

The Banking footer has **two horizontal dividers** with a gap between them:

```
┌────────────────────────────────────────────────────────────┐
│                                                            │
│                    [Item List Area]                        │
│                                                            │
├────────────────────────────────────────────────────────────┤  ← DividerBottomT (Y=0)
│                          4px gap                           │
├────────────────────────────────────────────────────────────┤  ← DividerBottomB (Y=4)
│     [Withdraw Icon]  WITHDRAW  │  DEPOSIT  [Deposit Icon]  │
│                    298/400     │     118/205               │
└────────────────────────────────────────────────────────────┘
```

### Adjustment Workflow

1. **Identify the element** in the appropriate XML file
2. **Note the current values** from the tables above
3. **Adjust incrementally** (5-10px at a time)
4. **Test with `/reloadui`** after each change
5. **Update this documentation** with new values
6. **Run deployment script**: `.\tools\helper_script.ps1`

### Common Adjustment Scenarios

| Issue | Element to Adjust | Direction |
|-------|-------------------|-----------|
| Item icons peeking at bottom | List BOTTOMRIGHT offsetY | Make more negative (-8 → -10) |
| List too close to header | List TOPLEFT offsetY | Increase positive value |
| Scroll bar too far from edge | ScrollIndicator offsetX | Decrease value |
| Dividers too short | Divider anchor RIGHT offsetX | Increase positive value |
| Footer divider gap too big | DividerBottomT/B offsetY | Reduce gap between values |

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

