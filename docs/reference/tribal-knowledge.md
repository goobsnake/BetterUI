# BetterUI Tribal Knowledge

> This document captures patterns, gotchas, and lessons learned during development.
> Read this at session start. Update it when discovering new insights.

---

## Last Updated

**2026-03-14**: Refreshed after codebase audit; corrected file references to match current module layout.
**2026-04-11**: Added full vendor directional-input incident guidance covering joystick lock-up, dimmed lists, and accelerated scrolling.
**2026-07-06**: Added inline buy-spinner scene-hide detach case + spinner-reuse checklist under the vendor directional-input incident (input-mode flags on polled/custom-handler widgets must clear on hide).
**2026-06-12**: Added slot-identity-in-CIM, gamepad dialog keybind Push/Pop, `GetSlotAbilityCost` argument order, symmetric tooltip-enhancement teardown, and `ProtectionPolicy.CanDestroyItem` slotType gotchas (v3.06 fix batch).
**2026-06-12** (MPR-3): Added `BETTERUI_TabBarScrollList` single-dispatch ownership, `SetSelectedIndexWithoutAnimation` `forceAnimation` mapping, modern `TransferCurrency` over deprecated deposit/withdraw aliases, and per-batch gold-cap re-check gotchas (ZO_-native drift review).
**2026-06-13** (MPR-4): Added per-frame HUD bar latching, scene-gated tooltip top-line suppression, `BETTERUI_`-prefixed event/update registrations, and the reload-gated native-takeover (no-runtime-teardown) model gotchas (performance / addon-compat / nil-hardening review).
**2026-06-17** (inventory shared-module migration repair): Added the deferred-init eager-load single-point-of-failure + nil `callbackParam` AddList contract, the double-`AddIcon` pulsing-icon gotcha, the `UnifiedFooter` `OnInitialized`-order `SetupFooter` gotcha, and the four header-sort keybind seams (build-strip-before-install, defer-enter-after-dialog, deactivate-list-during-sort, reset-integration-`isActive`-on-cleanup). See **Header Sort & Shared-View Gotchas**.
**2026-07-09**: Added the full **Vendor Keybind-Strip Ownership Saga** (three layers of native-store keybind eviction + one own keybind-state-stack leak, plus false leads and the live-log diagnostic procedure) under the Vendor section.

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
- Slot identity lives in CIM: use `BETTERUI.CIM.Utils.CaptureSlotIdentity` / `IsSlotIdentityCurrent` / `NormalizeIdentityValue` (`CIM/Core/Utilities.lua`). `BETTERUI.Inventory.Utils` delegates to these — do not duplicate the helpers per module (see **Slot Identity Belongs to CIM** below)

### XML Template Constants
- ESO XML cannot reference Lua namespace syntax (`BETTERUI.CIM.CONST.*`)
- Global constants like `BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH` exist **only** for XML template support
- In **Lua code**: Always use `BETTERUI.CIM.CONST.LAYOUT.PANEL.WIDTH` (canonical)
- In **XML templates**: Use `BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH` (required)
- All XML-support globals are defined in `CIM/Constants.lua` and `CIM/ConstantsUI.lua` and delegate to canonical paths

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

## Header Sort & Shared-View Gotchas (inventory CIM migration)

### Header-sort keybinds (CIM `HeaderSortIntegration`)
The shared header-sort owner contract has four independent ordering/state seams — all four must hold or the column-sort flow breaks:
1. **Build the keybind strip before installing the integration.** `HeaderSortIntegration.Install` snapshots `keybinds.mainDescriptor = instance.mainKeybindStripDescriptor` at install time. If `InitializeKeybindStrip` runs *after* `InitializeHeaderSortController`, the snapshot is nil and the exit-from-sort restore has nothing to re-add → inventory keybinds vanish on back-out. (See `Inventory.lua` `InitializeDeferredInventoryLists`.)
2. **Enter sort mode only after the action dialog releases its keybind state.** Sort is triggered from the item Actions dialog (`ItemActionHandlers.OnConfirm`, `isSortAction`). Calling `EnterHeaderSortMode` synchronously applies the keybind swap to the dialog's about-to-pop keybind state, so the sort keybinds are discarded on close and the strip falls back to the inventory keybinds. Defer with a poll on `ZO_Dialogs_IsShowingDialog()`.
3. **Deactivate the underlying list while in sort mode.** Inventory's install supplies no `navigation` contract, so only the tab bar is suspended. With the list still active, the first Sort press (`ToggleSort` → `RefreshItemList` → commit/reselect) re-establishes the list's native keybind context and clobbers the sort A/Back keybinds (leaving only Back/Clear-sort, and Back then falls through to the scene). Supply `callbacks.onEnterHeaderMode/onExitHeaderMode` that `Deactivate()`/`Activate()` the current list.
4. **Reset the integration's `isActive` on scene cleanup, not just the controller.** `SceneCleanup.CleanupInputState` cleared `screen.isInHeaderSortMode` and the controllers but not `screen._headerSortIntegration.isActive`; the next `EnterHeaderMode` then bails on `if integration.isActive then return false`, permanently dead-ending the sort action after one scene exit.

### Unified footer controller never initializes (currency / capacity blank)
`UnifiedFooter.xml`'s inner `$(parent)Footer` `OnInitialized` (which calls `controller:SetupFooter`) can run **before** the container `OnInitialized` creates the controller (the control tree builds child-first), so `parent.unifiedFooter` is nil and `SetupFooter` is silently skipped → the controller has no `footer`/`_initialized` and `Refresh()` is a no-op → footer values never populate. Fix is symmetric: the container `OnInitialized` must also call `SetupFooter(self.footer)` when the child already ran, and owners' `SetupUnifiedFooter` re-asserts it (and refreshes) as a safety net. Diagnosed via a one-line `FOOTDIAG` probe showing `ctl=true init=false footer=false`.

### Pooled `ZO_GamepadEntryData` icons animate when added twice
`CreateItemEntryData` seeds an icon via `ZO_GamepadEntryData:New(name, icon)`, then the shared `InitializeSharedItemVisualData` calls `row:AddIcon(...)` again. A multi-icon entry makes ESO cycle/animate the icons — with two identical icons this reads as a **pulsing item icon** (inventory/bank/vendor). Call `row:ClearIcons()` before `AddIcon` so there is exactly one static icon.

### Deferred-init eager-load is a single point of failure
`Module.lua` eagerly calls `PerformDeferredInitialize()` at addon load, and `OnDeferredInitialize` sets its done-flag at the top — so one failing `Initialize*` step silently aborts the rest of the wiring and is never retried on scene show. Root cause of the migration regression was `InitializeCraftBagList` passing `nil` as `AddList`'s `callbackParam`: native `CreateAndSetupList` routes a nil `callbackParam` to native `SetupList` (which calls `AddDataTemplate`, incompatible with BetterUI's list wrapper). Pass a no-op `function() end` to stay on the `callbackParam(list)` branch.

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

### Gamepad Dialogs Push/Pop the Keybind-Group State
- A gamepad action dialog **pushes** the keybind-group state on open and **pops** it on close
- Default-stateIndex keybind `Add`/`Remove` calls target the **base** state — i.e. the snapshot that Pop will restore
- Therefore **never** run synchronous keybind/list restoration while a dialog's pushed state is still active: it mutates the saved snapshot, so Pop restores corrupted state (symptom: LB/RB carousel paging dies after a single dialog action — PB-002)
- Defer restoration to the dialog's finish/`OnFinish` path, which runs **after** Pop
- Make header keybind re-activation robust to a stale `tabBar.active` (`EnsureHeaderKeybindsActive`)

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

### GetSlotAbilityCost Argument Order
- Signature: `GetSlotAbilityCost(actionSlotIndex, mechanicType, hotbarCategory)`
- `mechanicType` is **required** — for the ultimate slot pass `COMBAT_MECHANIC_FLAGS_ULTIMATE`
- Passing the hotbar category in the `mechanicType` position returns `0`, which silently breaks fill meters / insufficient-resource overlays
- See `ResourceOrbFrames/SkillBar/UltimateManager.lua` for the canonical ultimate-cost call

### `BETTERUI_TabBarScrollList` Selection-Dispatch Ownership
- The shared module-header tab bar (Inventory/Banking/Vendor/Companions) is a `BETTERUI_TabBarScrollList` over `ZO_ParametricScrollList`
- The carousel `UpdateAnchors` is the **single** owner of the selection-callback fire: it calls `onSelectedDataChangedCallback` directly when in carousel mode, and the `_zo_selectedDataChangedWrapper` covers the non-carousel path
- **Never** add extra direct `onSelectedDataChangedCallback` fires inside `SetSelectedIndex` — doing so caused the selection callback to dispatch **2×** in carousel mode and **3×** in non-carousel mode (duplicate refreshes per tab change)
- Suppression is routed to `UpdateAnchors`'s `blockSelectionChangedCallback`, not to extra guard flags in `SetSelectedIndex`

### `ZO_ParametricScrollList:SetSelectedIndexWithoutAnimation` Third Param Is `forceAnimation`
- Signature: `SetSelectedIndexWithoutAnimation(index, allowEvenIfDisabled, forceAnimation)` — the 3rd native param is **`forceAnimation`**, NOT callback-suppression
- Mis-mapping a suppression flag onto `forceAnimation` leaks a stray animation request on the without-animation path
- Always pass `forceAnimation=false` on this path, and route any callback suppression to `UpdateAnchors`'s `blockSelectionChangedCallback` instead

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

### Currency Transfer: Use Modern `TransferCurrency`, Not the Deposit/Withdraw Aliases
- Prefer `TransferCurrency(currencyType, amount, CURRENCY_LOCATION_x, CURRENCY_LOCATION_y)` over the deprecated `WithdrawCurrencyFromBank` / `DepositCurrencyIntoBank` aliases
- Those aliases live **only** in `addoncompatibilityaliases`, which ZOS could remove at any update; the modern call matches the guild-bank branch and current native
- Direction mapping: **Deposit** = `CURRENCY_LOCATION_CHARACTER` → `CURRENCY_LOCATION_BANK`; **Withdraw** = `CURRENCY_LOCATION_BANK` → `CURRENCY_LOCATION_CHARACTER`

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

### Per-Frame HUD Bars Must Latch (Static Style + Text)
- Any bar `Update` driven by `OnUpdate` (or `ZO_StatusBar_SmoothTransition`) runs every frame — `ExperienceBar`, `CastBar`, `MountStaminaBar` on the ResourceOrbFrames HUD loop
- **Never** call `SetFont` / `SetText` / `ClearAnchors`+`SetAnchor` / `SetDimensions` unconditionally per frame — each one re-allocates strings and mutates controls every tick (the XP bar was doing ~10 control mutations + a fresh `SetText` per frame)
- Latch **static style** (font, dimensions, anchors) once via an `ApplyStaticStyle`-style helper, and latch **value/label text** (cache `_lastLabelText`/last value, skip `SetText`/`UpdateVisuals` when unchanged). `CastBar` / `MountStaminaBar` / `ExperienceBar` are the reference; the orb numeric label (`OrbVisuals.lua RefreshLabel`) caches `_lastLabelText` so it only re-`SetText`s when the bucketed string changes during the 500ms smooth transition
- Smooth-transition animations (after a power change) keep firing `OnUpdate` for ~500ms even when the displayed bucketed value never changes — latching is what makes that quiet

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

### Vendor

- Multi-select batch sells must re-check the gold cap **per batch**. The per-step batch path (Sell / Sell-Vengeance) does not inherit the Sell component's `IsAtGoldCap()` pre-check, so a batch can otherwise fire N doomed `SellInventoryItem` calls that the server silently rejects once the cap is hit. Pre-gate the cap and stop the batch with feedback instead. (Fence and launder do not pay gold and are unaffected.)

#### Vendor Directional-Input Incident (2026-04-11)

This incident took multiple passes to resolve because it was not one bug. It was a stack of separate failures that presented as one broken vendor scene:

1. Joystick directional input sometimes locked after closing vendor.
2. The vendor item list sometimes appeared dimmed or out of focus.
3. The item list sometimes scrolled far too fast.
4. The vendor header/tab-bar could appear dimmed even when the list itself was active.

The final fix required separating those symptoms and treating them as different failure modes.

#### Symptoms And What They Actually Meant

- `Joystick lock after leaving vendor`: some object was still registered on the global `DIRECTIONAL_INPUT` stack after vendor closed.
- `Item list dimmed`: the list control was visually inactive. In ZOS gamepad lists, dimming is an activation-state issue, not just a directional-input owner issue.
- `Item list scrolls too fast`: the same BetterUI vendor list had been registered on `DIRECTIONAL_INPUT` more than once, so one stick/d-pad input was processed multiple times.
- `Header/LB/RB dimmed while list works`: vendor intentionally stripped header tab-bar input ownership to stop lockups, but also accidentally stripped its visual active state.

#### False Leads That Cost Time

These looked plausible during investigation but were not the final cause:

1. `GuiRoot` ownership by itself was not the end-state bug. Unknown `GuiRoot` owners did appear during earlier debugging, but once those were removed the vendor could still be broken.
2. Native scene aliasing was not enough to explain the final symptom. Aliasing `gamepad_store` to the BetterUI scene mattered, but it was not the complete explanation for dimmed lists or fast scrolling.
3. `ForceReleaseDirectionalInput()` was not the final culprit. It looked suspicious because it aggressively deactivated everything, but the real issue was whether later re-activation paths restored the correct state atomically.
4. Search/header focus leaks were real during the middle of the investigation, but they were not the final explanation once the item list was active again.

#### Actual Root Causes

There were four durable root causes.

##### 1. Premature Header Activation

- `tabBar:Activate()` registers the tab bar on `DIRECTIONAL_INPUT`.
- Vendor previously allowed header activation during scene transitions.
- If the scene was not fully showing, the tab bar could claim directional ownership too early and survive into later transitions.

Durable rule:

- Never activate a directional-input owner unless `scene:IsShowing()` is true.
- Banking already used this pattern and Vendor had to match it.

##### 2. Stale `confirmationMode`

- Spinner confirmation mode disables list input.
- If the scene hid while spinner/confirmation mode was active, `confirmationMode` could survive into the next vendor open.
- That left the list looking present but behaving like spinner mode was still active.

Durable rule:

- Every mode flag that changes input behavior must be cleared in shared scene cleanup.
- `confirmationMode` now belongs in `BETTERUI.CIM.SceneCleanup.CleanupInputState()`.

##### 3. List Activation And DI Enablement Diverged

- On `ZO_ParametricScrollList`, visual active state and DI ownership are related but not identical.
- `SetDirectionalInputEnabled(true)` changes directional-input registration.
- `Activate()` changes active state and, when directional input is enabled, also registers on `DIRECTIONAL_INPUT`.
- Calling only one of them, or calling them in the wrong order, can leave the list active-looking but unresponsive, or responsive but visually dimmed.

Durable rule:

- Treat list activation as one atomic state transition, not two unrelated method calls.
- Never enable DI on a parametric list without ensuring the list is also activated into the intended visual/input state.

##### 4. Duplicate BetterUI List Registrations Caused Fast Scrolling

- This was the final scroll-speed bug.
- For ZOS parametric lists, both `SetDirectionalInputEnabled(true)` and `Activate()` call `DIRECTIONAL_INPUT:Activate(self, self.control)`.
- Vendor was doing both during one inactive-list activation path.
- Result: the same BetterUI vendor list self-registered more than once, so a single movement input was processed multiple times.

Durable rule:

- For `ZO_ParametricScrollList`, do not call `SetDirectionalInputEnabled(true)` and then `Activate()` as if they were independent safe steps.
- If an inactive list is about to be activated, set `directionalInputEnabled` state for the upcoming activation and let `Activate()` perform the single real DI registration.
- Also dedupe stale registrations before re-activation if previous refreshes may have stacked them.

#### ESO Engine Behaviors That Matter Here

These behaviors must be remembered for future scenes:

1. `DIRECTIONAL_INPUT` is a global stack. Any orphaned owner can block every later scene.
2. `ZO_ParametricScrollList:SetDirectionalInputEnabled(true)` directly registers the list on `DIRECTIONAL_INPUT`.
3. `ZO_ParametricScrollList:Activate()` also registers the list when `directionalInputEnabled` is true.
4. `ZO_ParametricScrollList:Deactivate()` and some other ZOS deactivate paths rely on internal `active` flags. If those flags are already stale, a plain deactivate call may not actually release DI.
5. `Commit()` and `OnEffectivelyShown` can trigger activation side effects during list rebuilds.
6. Scene aliasing changes name lookups in `SCENE_MANAGER`, not every existing object callback bound to the original native scene object.
7. Deferred work such as `zo_callLater` or task-manager callbacks can reintroduce native or BetterUI input ownership after a close/hide unless guarded.

#### Final Fix Pattern We Kept

The final stable fix kept these pieces:

1. Scene-gated activation for list and header paths.
2. Shared cleanup that resets `confirmationMode` and other mode flags.
3. Native store DI release before BetterUI vendor activation work begins.
4. BetterUI vendor list deduplication before re-activation.
5. Single-registration parametric-list activation semantics in `EnsureListInputActive()`.
6. Header visual activation restored without giving the header tab bar DI ownership again.
7. Deferred vendor refresh guards using `_isClosing` and strict scene-state checks.

#### Debugging Procedure That Worked

When a future scene shows joystick lock, dimmed lists, or fast scrolling, use this exact process:

1. Run `/buidebug` while the bug is active.
2. Read the full `DIRECTIONAL_INPUT` stack, not just the top entry.
3. Look for duplicates of the same BetterUI object as well as foreign/native owners.
4. If the list is dimmed, assume an active-state problem first, not just a leaked owner.
5. If scrolling is too fast, count duplicate registrations of the same BetterUI list/control.
6. Compare item-list behavior separately from header/tab-bar behavior; they may be failing for different reasons.
7. If closing the scene causes the bug, inspect every deferred task that can re-run after hide.

Commands that proved useful:

- `/buidebug`: dumps the DI stack plus recent DI mutation trace.
- `/buiscene`: confirms scene-state transitions if activation/cleanup ordering is suspicious.
- `/buikeybinds`: useful when tab-bar/button groups are suspected.
- `/builist`: useful when the list exists but selection/active state is wrong.

#### Future Scene Checklist

Before shipping any new gamepad scene that uses BetterUI lists, headers, or scene aliasing, verify all of the following:

1. Every DI owner activates only when `scene:IsShowing()` is true.
2. Every scene has symmetric hide/hidden cleanup.
3. Every mode flag that affects focus or input is reset in shared cleanup.
4. No parametric list activation path performs a double DI registration.
5. Any deferred refresh task aborts when the scene is closing or no longer fully showing.
6. Header visuals and header DI ownership are treated separately if shoulder buttons are rerouted elsewhere.
7. `/buidebug` after rapid open/close cycles shows no duplicate BetterUI list registrations and no leaked native owners.

#### What Not To Remove Lightly

The following patterns looked redundant during the investigation but are intentionally retained because they guard different failure modes:

- Explicit native store DI release before BetterUI vendor activation.
- Forced BetterUI/vendor cleanup on hide and hidden transitions.
- Stale search/header focus detachment in Vendor even though Vendor does not intentionally expose full search today.
- Deferred normalization after list activation settles.

If any of these are revisited later, retest all of the original failure modes:

1. close-time joystick lock
2. dimmed item list
3. accelerated item scroll
4. dimmed header/tab bar

#### Inline Buy Spinner Scene-Hide Detach (2026-07-06)

The vendor inline buy-quantity spinner (`Modules/Vendor/Core/List/InlineBuySpinner.lua`) reproduced symptom (1) — joystick up/down dead in later scenes after leaving the vendor — **without registering a `DIRECTIONAL_INPUT` owner**. The spinner never calls `Activate()`/`AttachAndShowSpinner()` and only *polls* a `ZO_MovementController`, so it has no direct DI ownership. The leak was subtler and matches the durable rules above:

- The spinner routes the vendor list's per-frame directional input through a per-instance `ZO_ParametricScrollList:SetCustomDirectionInputHandler`. That handler is gated by an input-mode flag, `_attached`.
- `_attached` was set on every stackable-row selection but never cleared on scene-hide (logged **307 attach / 6 detach**). The vendor parametric list can itself linger on the global DI stack, so its `UpdateDirectionalInput` kept invoking the still-`_attached` handler in later scenes, which kept engaging the dial logic instead of bowing out.
- Fix: `InlineBuySpinner:Detach()` (idempotent — clears `_attached`, restores the borrowed Stat/Value cells, hides + un-anchors the overlay) is now called from **both** the vendor `onHiding` and `onHidden` cleanup blocks, right after the `CIM.SceneCleanup.*` calls. Confirmed in-game.

Durable takeaway: "clear every input-mode flag symmetrically on hide" (root cause #2) applies to **polled / custom-handler widgets too**, not just objects that call `DIRECTIONAL_INPUT:Activate`. A stuck flag gating a persisting list handler locks input just as effectively as an orphaned owner.

**Reusing the spinner in another scene (Banking withdraw/deposit, guild bank/store, inventory split):** `InlineBuySpinner` is deliberately generic (borrows any row's `Stat`/`Value` cells, no vendor-specific coupling), but its cleanup is NOT automatic. For **every** scene that attaches it you MUST:
1. Wire `BETTERUI.Vendor.InlineBuySpinner:Detach()` into that scene's `onHiding` **and** `onHidden` cleanup (or the shared `CIM.SceneCleanup` path), exactly as `VendorBootstrapRuntime` does — a scene that attaches the spinner but forgets the scene-hide detach will reproduce this exact global-stack lock.
2. Confirm attach/detach counts stay roughly balanced under `/builog` (the vendor bug showed 307 attach / 6 detach).
3. Only ever *poll* the movement controller; never `Activate()` the ZOS spinner or the controller (that would add a real DI owner AND, for the D-pad device, trip the protected `IsKeyDown` — see the IsKeyDown Security Error note).

#### Vendor Keybind-Strip Ownership Saga (2026-07-08 → 2026-07-09)

The vendor keybind strip (Buy / Back / Toggle List / Multi-Select + ethereal LB/RB category-cycle shoulders) repeatedly lost ownership across scene enter/exit, list navigation, and search. Like the 2026-04-11 DI incident, this was **not one bug** — it was a stack of native-store keybind re-registrations plus one of our own keybind-state leaks, each presenting as "keybinds collapse / B jumps to the far right / LB-RB stop cycling." Root diagnosis came from the live `[BUI]` `keybind_layer` breadcrumbs (`liveKeybinds="n=N[...]"`, `refresh_before`/`refresh_after`, reason codes) cross-referenced against esoui source.

**The engine invariant behind all of it:** the native gamepad store (`STORE_WINDOW_GAMEPAD`, a `ZO_Gamepad_ParametricList_BagsSearch_Screen`) registers keybind groups on the SAME `UI_SHORTCUT_*` keys as our vendor-core group. ZOS `HandleDuplicateAddKeybind` is **last-add-wins, no-restore**: a native re-add evicts our buttons and a subsequent cheap `UpdateKeybindButtonGroup` can NOT bring them back (it no-ops on an evicted button). Only a clean Remove+Add re-adds evicted buttons and makes us the last (winning) owner.

**Layer 1 — component re-adds on scene entry (fixed `07aea851`, 2026-07-08).** On the scene transition the native store re-registered its per-mode *component* descriptors, collapsing the strip to `[Back]` and shadowing LB/RB. Fix = `InstallNativeStoreKeybindSuppression` (`VendorNativeStoreBridge.lua`): a one-time `ZO_PreHook` on `KEYBIND_STRIP.AddKeybindButtonGroup` that returns `true` (skips the add) ONLY while our vendor scene is showing AND the descriptor is a native store *component* descriptor (`components[*].keybindStripDescriptor`/`confirmKeybindStripDescriptor`). Blocking the Add is complete because `UpdateKeybindButtonGroup` no-ops on an absent group. This let us delete the earlier ~1s "settle-sweep" polling bandaid.

**Layer 2 — text-search HEADER re-adds on scroll / LB-RB cycle / search-exit (fixed 2026-07-09).** After Layer 1, in-game verification surfaced a flicker: navigating the list or cycling categories momentarily dropped the strip to `n=2[A:Select;B:Back]` ("B moves right, other buttons vanish"), then our reactive refresh restored it. The log gave the tell: **zero `blocked` events**, yet every `refresh_before` snapshot was `n=2[A:Select;B:Back]`. That descriptor is NOT a component — it is the store screen's **text-search header keybind**, `STORE_WINDOW_GAMEPAD.textSearchKeybindStripDescriptor` = `[UI_SHORTCUT_PRIMARY:"Select", UI_SHORTCUT_NEGATIVE:"Back"]`, added by `ZO_GamepadStoreManager:OnEnterHeader()` **with no `IsShowing()` guard** whenever the store list re-enters its search header. Our `NativeStoreBridge.EnsureComponents → SetActiveComponents` (plus the native list's `OnHitBeginningOfListCallback → RequestEnterHeader`) triggered that on exactly those actions. The Layer-1 suppression only matched *component* descriptors, so this slipped straight through. Fix = extend `IsNativeStoreKeybindDescriptor` to ALSO identity-match `storeManager.textSearchKeybindStripDescriptor` (same scene-gated, `==`-identity-only philosophy).

**Layer 3 — our OWN search group leaking on a keybind-state mismatch (fixed 2026-07-09).** With Layer 2 done, one residual remained: exiting the search bar (or scrolling in/out of it) left `B:Back` stuck on the **far right** until a second back-press. This one was ours. `EnterSearchMode` adds our search group `[Select; Back]` — whose Back is `KEYBIND_STRIP_ALIGN_RIGHT` — at the **header-navigation keybind state**; focusing the edit box then **pushes a text-entry state** (`[Accept;Cancel]`) on top of the stack. On exit, `RestoreSearchFocus`'s `RemoveKeybindGroupIfPresent(search)` ran while that pushed state was still active — and both `EnsureKeybindGroupAdded`/`RemoveKeybindGroupIfPresent` operate on `GetActiveKeybindStateIndex()` only — so the removal targeted the wrong state and **no-op'd**. Our search group survived in the header-nav state, merely *shadowed* by the core reclaim's last-add, and its right-aligned Back re-surfaced. Fix = remove the search group **again after `RequestLeaveHeader`** has popped back to the state the group actually lives in, before the core reclaim (idempotent if the first removal took).

**False leads / dead ends (cost time; recorded so we don't repeat them):**
- "A shared inventory→vendor init warms the strip" — DISPROVEN; the vendor first-entry dead-LB/RB (after every `/reloadui`) was stale `_searchModeActive`/`_searchHeaderActive` flags gating LB/RB as "search active." Fix = make `IsVendorSearchInputActive` authoritative on the engine edit-box focus (`focus:GetEditBox():HasFocus()`), not on heuristic flags (`VendorKeybinds.lua`).
- "My keybind fix caused a heal-storm" — DISPROVEN by the log (`staleSearchFlagsShoulderHeal=0`).
- "Re-add unconditional force-reclaim on search exit" — REJECTED: an earlier attempt forced a Remove+Add mid-teardown and RACED the native re-registration (the 2026-07-08 search-exit toggle bug). Keep the displacement force-escalation **Back-only**; do not force on the ethereal LB/RB shoulders mid-teardown.
- Sibling fix from the same flow: canceling an Inventory delete/destroy dialog with **B** broke LB/RB category nav — dialogs deactivate the header tab bar. Fix = an `OnHiddenCallback → RestoreStateAfterDialog` on all three destroy dialogs (shared `BuildDialogRestoreOnHidden` helper), mirroring the split-stack dialog.

**Durable rules:**
1. **Suppress native-store keybinds by descriptor IDENTITY, scene-gated — and cover EVERY table.** The native store adds keybinds from at least two places: per-mode components AND the text-search header (`textSearchKeybindStripDescriptor`). `IsNativeStoreKeybindDescriptor` must match all of them by `==`, gated on `IsBetterUIVendorSceneShowing()`. Identity + scene-gate = zero false positives (our own descriptors are different tables; the native store still works when it legitimately owns the strip).
2. **ZOS keybind groups live in a STATE STACK; add/remove hit the ACTIVE state only.** A group added at state N and removed while state N+1 is active leaks silently. Remove in the SAME state the group was added — i.e. after any pushed (edit-box / dialog) state has popped.
3. **`HandleDuplicateAddKeybind` = last-add-wins-no-restore.** A cheap `Update` cannot restore an evicted button; only a Remove+Add restores it AND re-runs alignment layout.
4. **A `KEYBIND_STRIP_ALIGN_RIGHT` Back jumping to the far right is a visual signature** that a search / right-aligned group is lingering on the strip.

**Diagnostic procedure that cracked it (repeat for future keybind-ownership bugs):**
1. `/builog` on; reproduce; read the live `Interface.log` (outside MCP roots — use Bash `grep '\[BUI\]'`).
2. Read `refresh_before` `liveKeybinds` — it is the strip state BEFORE our refresh, so it reveals what evicted us (e.g. `n=2[A:Select;B:Back]`).
3. Count `native_store_keybind_suppression … phase=blocked` events. **Zero blocked while still being evicted = the offending descriptor is not in the match set** — find the real descriptor via esoui-api (`esoui_search` → read the store / parametric-list source), do not guess.
4. Distinguish OUR group from native by identity/alignment: our vendor-search Back is `ALIGN_RIGHT`; core Back is grouped `ALIGN_LEFT`.

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

## Edge Cases and Known Gotchas

### Callback Cleanup Patterns
- **Always unregister callbacks** in `SCENE_HIDDEN` that were registered in `SCENE_SHOWING` — unbalanced registration causes memory leaks and ghost handlers
- `SHARED_INVENTORY:RegisterCallback` / `UnregisterCallback` must use the exact same function reference for both calls; anonymous closures cannot be unregistered
- `zo_callLater` returns a timer name that must be tracked (e.g., `self.callLaterLeftToolTip`) and unregistered via `EVENT_MANAGER:UnregisterForUpdate(name)` on scene exit
- `ZO_InventorySlot_SetUpdateCallback(nil)` must be called in `SCENE_HIDING` to clear the inventory slot action callback

### ZOS Global Override Risks
- ESO XML templates can only consume `_G` globals — do NOT remove any `BETTERUI_GAMEPAD_*` or `BETTERUI_*` globals that are referenced in `.xml` files
- Modifying a ZOS object's methods (e.g., `ZO_Tooltip.SomeMethod`) after `zo_mixin` has run has no effect — see **zo_mixin Copies Methods at Init Time** above
- `SLASH_COMMANDS["/name"]` is a shared global table — avoid collisions with other addons by using a unique prefix (`/bui*`)
- Overwriting ZOS constants (e.g., `CURT_*` values) at file scope is safe, but wrapping with `or` (`CURT_NEW or CURT_OLD`) is the canonical compat pattern

### Scene Lifecycle Timing Issues
- `SCENE_MANAGER:WasSceneOnStack(name)` is only reliable during the `SCENE_SHOWING` transition — using it later may return stale/false results
- `GetFrameTimeSeconds()` returns `0` on first frame — always guard with `GetFrameTimeSeconds and GetFrameTimeSeconds() or 0`
- Scene state callbacks fire in order: `SCENE_SHOWING → SCENE_SHOWN → SCENE_HIDING → SCENE_HIDDEN` — input activation should happen in `SHOWING` and cleanup in `HIDDEN`, never the reverse
- Brief scene detours (container loot, enchanting) can cause rapid `HIDING → SHOWING` cycles — use time-based detection (`< 2.0s` threshold) to distinguish detours from fresh opens

### Batch Operation Gotchas
- `SetItemIsJunk` is async — `IsItemJunk` returns stale data until `EVENT_INVENTORY_SINGLE_SLOT_UPDATE` fires (see **SetItemIsJunk Is Asynchronous** above)
- Multi-select batch loops must check `isBatchProcessing` guard to prevent re-entrant pipelines
- `RequestMoveItem(fromBag, fromSlot, toBag, nil)` with nil destination slot uses engine auto-resolution which is unreliable under throttled batch processing — always resolve explicitly via `BETTERUI.CIM.Utils.ResolveMoveDestinationSlot`
- **Re-validate slot identity at execution time.** A throttled batch captures `slotIndex` values up front, but slots are reused as items leave bags during the batch (junk/move/sell). Before acting, re-check with `BETTERUI.CIM.Utils.IsSlotIdentityCurrent` so an item that slid into a freed `slotIndex` mid-batch is never acted on by mistake. Applies to junk/unjunk/lock/unlock (`CIM/Core/Batching/BatchActions.lua`, `MultiSelectManager.lua`) and vendor batch sell/fence/launder (`Vendor/Core/VendorBatchRuntime.lua`), matching the Inventory destroy path
- Skipped (no-op) batch steps must **not** count against the server rate-limit pacing — only steps that actually issue an engine call should advance the throttle

### Slot Identity Belongs to CIM
- Capture/compare with `BETTERUI.CIM.Utils.CaptureSlotIdentity` / `IsSlotIdentityCurrent` / `NormalizeIdentityValue` (`CIM/Core/Utilities.lua`); `BETTERUI.Inventory.Utils` delegates to them — do not re-implement per module
- Identity is `{ bagId, slotIndex, uniqueId (normalized), itemLink }`; `IsSlotIdentityCurrent` prefers `uniqueId`, falling back to `itemLink`
- **Standalone-test implication**: any test that `dofile`s `Inventory/Core/Utils.lua` must first load `CIM/Core/Utilities.lua` — Inventory delegates to CIM, so CIM must load before Inventory (CIM-before-Inventory)

### Tooltip Enhancement Teardown Must Be Symmetric
- Gate every per-layout re-application (fonts, anchors, labels, status tags) on the live `enableTooltipEnhancements` setting, and fully reverse fonts/anchors on cleanup
- If teardown is asymmetric, toggling enhancements **off** won't revert the layout until a relog/`/reloadui` (PB-003)
- After toggling, re-lay-out the currently visible tooltip immediately so the change is seen in-session

### ProtectionPolicy.CanDestroyItem is Fail-Closed
- `BETTERUI.CIM.ProtectionPolicy.CanDestroyItem` gates an irreversible destroy on the engine probe `ZO_InventorySlot_CanDestroyItem`, which only runs with a `slotType`. It fails **closed** (DENY) in both degraded cases rather than authorizing an unverified destroy: a nil `slotType` returns `DENY.NO_SLOT_TYPE` (the probe can't run), and an unavailable probe global returns `DENY.NO_DESTROY_PROBE`. In production the probe global is always present, so the second case only hardens the degraded/early-load/test path (`test_destroy_policy_contracts.lua` covers both).
- Callers acting on bag/companion items must tag `SLOT_TYPE_GAMEPAD_INVENTORY_ITEM` (Companion equipment rows do this in `Companions/Core/CompanionItemList.lua`) so the probe runs (defense-in-depth)

### Tooltip Top-Line Suppression Must Be Scene-Gated
- A `ZO_PreHook` on `AddTopLinesToTopSection` that `return true`s suppresses native **and** other addons' top-section content for the **shared** gamepad tooltip controls — game-wide, not just inside BetterUI's enhanced scenes
- If gated only on the enhancement *setting*, it strips third-party top lines (and the native set-collection tag) everywhere the setting is on; gate it to BetterUI-enhanced contexts using the **same** `IsIncompatibleSceneActive` predicate the rendering hooks use, so the suppression only fires where BetterUI actually renders its enhancement (`GeneralInterface/Setup.lua` PreHook + the predicate exposed from `Tooltips.lua`)
- Keep one shared source of truth for "is this a BetterUI-enhanced tooltip scene" — the suppression hook and the rendering hooks must agree (PB-004's in-enhancement set-collection tag is unaffected)

### Namespace-Prefix Every Event / Update Registration
- `RegisterForUpdate` / `RegisterForEvent` names share a **global** registration space — an unprefixed name (e.g. a plain `"OrbUpdate"`) can clobber another addon's registration of the same name, or be clobbered by it
- Prefix every registration name with `BETTERUI_` (ResourceOrbFrames update loops in `OrbEvents.lua` now match every other module). This is collision-safety, not cosmetics

### Native Scene/Method Takeovers Rely on the Reload-Gated Module Model
- Module enable/disable is `requiresReload = true`. The Vendor/TradingHouse/Banking/Companions scene + method takeovers installed in each module's `Setup()` are intentionally **not** torn down on disable — on reload-with-module-off, `Setup()` simply never runs and native stays pristine
- **Do not add a runtime/mid-session teardown path** to "restore native" — reversing live scene/method takeovers in-session is high-regression-risk and unnecessary given the reload gate
- Contrast: the DI-trace wrappers in `DebugCommands.lua` *do* replace `DIRECTIONAL_INPUT.Activate/Deactivate`, but they are installed only by the `/buidebug` / `/buiscene` debug commands and chain the original — opt-in and compat-safe

## Unified logging: BETTERUI.Log → Interface.log

BetterUI streams debug + caught errors to the game's `live/Logs/interface.log` in
real time so an external tool (or AI) can tail it while you play. The retail client
has **no** API to write arbitrary text to that file (`WriteToInterfaceLog` exists
only in ZOS-internal builds), so the file sink works by raising a deferred,
popup-suppressed throwaway Lua error — the engine logs every uncaught error to
Interface.log. Verified: suppression hides the dialog but the line still logs.

- **API** (`Modules/CIM/Core/Diagnostics/Log.lua`): `BETTERUI.Log.Trace/Debug/Info/Warn/Error(category, message, data?)`.
  `category` ∈ `BETTERUI.Log.CATEGORY.{SCENE,LIST,NAV,KEYBIND,FOOTER,CATEGORY,SEARCH,SORT,BATCH,ACTION,DIALOG,CURRENCY,LIFECYCLE,SAFE,SETTINGS,CONTROL,PERF,STATE,SCREENSHOT,GENERAL}`.
  `data` (optional) is the structured payload. Pass a **small table of scalar fields** —
  it renders logfmt-style as `key=value key=value` (values via `BETTERUI.Log.Summarize`,
  keys sorted, capped at 8 fields). Don't pre-`Summarize` a field value (the renderer does
  it; double-summarizing double-quotes). Arrays render as `[n]`; nested tables collapse to
  `{n:keys}` shape, so never pass a full item list.
- **Line format**: BetterUI emits `[BUI] <gameTimeMs> sid=<sessionId> seq=<n> <LEVEL> <CATEGORY> | <event> <key=value ...>`,
  but because breadcrumbs are raised as deferred errors the **engine wraps every line on disk** as:
  `<ISO-8601 ts±tz> |cff0000Lua Error: [BUI] <gameMs> sid=<sid> seq=<n> <LEVEL> <CAT> | <event> k=v ...` followed by a
  `stack traceback:` block. Parser rules: (1) entries start at the ISO timestamp; (2) strip `|cXXXXXX`/`|r`
  colour codes; (3) a message containing `[BUI]` is a BetterUI breadcrumb — parse the fields and **ignore
  its traceback**; (4) a `Lua Error:` message **without** `[BUI]` is a real game error — keep its traceback.
  Fastest clean stream: `grep '\[BUI\]' Interface.log`. The engine ISO timestamp is the authoritative
  wall-clock; `gameTimeMs` is a secondary session-relative counter; `seq` is the in-session ordering key.
  One record per line (newlines collapsed).
- **Default routing**: every level → file ON, chat OFF, popup OFF (suppressed by
  default). Inert unless logging is enabled, so normal players pay nothing.
- **Crash-safety convention**: every call site is nil-guarded `if BETTERUI.Log then ... end`
  (isolated unit tests don't load Log.lua). For HOT paths also gate on
  `BETTERUI.Log.IsActive()` — or `Log.EnabledFor(level, category)` (the exact sink-aware
  pre-check) / the lazy `Log.WriteLazy|DebugLazy|TraceLazy(.., dataFn)` builders — so no
  payload is constructed when the record would be dropped.
- **Presets** (`Log.ApplyPreset`, or `/builog preset`): `off` stops file logging and restores
  popups; `info` captures INFO+ milestones; `watch` captures DEBUG+ with AI context enrichment;
  `debug` captures DEBUG+ without enrichment; `trace` captures TRACE+; `inspect` captures TRACE+
  with watch enrichment. `verbose` remains an alias for `trace`; `ai` remains an alias for `watch`.
  Presets arm per-frame/second/pending file-sink budgets (`InterfaceLog.SetBudget`/`GetStats`) that
  drop + summarize overflow (`dropped=N reason=rate_limit`) so a hot-path burst cannot hitch a frame.
  `Log.SetPayloadCapture` toggles payload rendering; `Log.GetPreset()` reads back `custom` once a
  low-level setter diverges from a preset.
- **Surface toggles** (`/builog`): `on|off` (enable/disable), `preset off|info|watch|debug|trace|inspect`,
  `check|test`, `mark <text>`, `recent|errors [n]`, `capture [secs]`, `screenshot [label]`,
  `screenshot auto off|error|warn`, `snapshot`, `report`, `popups on|off` (breadcrumbs stay
  suppressed while builog is enabled; use `/builog off` to restore player-visible error popups),
  `level <lvl>`, `status` (frame/sec/pending budget + scheduled/dropped/suppressed counters),
  and `chat on|off` (chat surfacing is unsupported, so builog stays file-only).
- `BETTERUI.Debug` / `BETTERUI.DebugError` / `BETTERUI.CIM.Debug.Log` are back-compat
  wrappers that route through `BETTERUI.Log`. `SafeExecute` caught errors route through
  `Log.Error("SAFE", ...)` while builog is active, or ESO's native Lua error popup when it is off.
- Detailed standards for new instrumentation live in [builog-developer-guide.md](builog-developer-guide.md).
