# Accessibility — Gamepad Screen-Narration Integration: Findings & Phased Plan

Created: 2026-07-06
Status: Active (source Phases 1-3 implemented 2026-07-06; Phase 5 Vendor/Banking/Inventory pass confirmed; Trading House/Companions acceptance pending; changelog added)
Initiative ID: `ACC-010`
Scope: Gamepad **screen narration** (ESO's `SCREEN_NARRATION_MANAGER`, the console/accessibility text-to-speech surface) for BetterUI's custom takeover screens.

> **Verdict: KEEP AND IMPROVE — do not remove.**
> The scaffolding is genuinely solid (centralized helper, correct `narrationInfo` shape, pcall-hardening, 7-language strings, unit tests for the builders). The integration fails on exactly **one narrow, fixable point**: the narration objects are *registered* but never *triggered* on list navigation. This is a last-mile wiring omission, not a rotten foundation. A removal plan is costed in Appendix A in case in-game validation (Phase 0) overturns the premise, but the recommended path is to wire up the missing trigger.

---

## 1. What exists today (file-by-file inventory)

All list-narration registration flows through one helper and five call sites:

| Screen | Registration call site | Scene name registered | Mechanism |
|---|---|---|---|
| Central helper | `Modules/CIM/Core/Integration/NarrationHelper.lua` (whole file; tag `ACC-001`) | — | `Narration.RegisterListNarration(...)` → `SCREEN_NARRATION_MANAGER:RegisterCustomObject(sceneName, narrationInfo)` (line ~248) |
| Inventory | `Modules/Inventory/Module.lua:478` (`TryRegisterInventoryNarration`) | `ZO_GAMEPAD_INVENTORY_SCENE_NAME` (`"gamepad_inventory_root"`) | custom object |
| Banking | `Modules/Banking/Banking.lua:723-731` | banking + guild-banking scenes | custom object |
| Vendor | `Modules/Vendor/Vendor.lua:1695` (`RegisterVendorNarration`, called at `:1725`) | vendor scene | custom object |
| Trading House | `Modules/TradingHouse/TradingHouse.lua:386` | trading-house scene | custom object |
| Companions | `Modules/Companions/Core/CompanionsRuntime.lua:214` (`RegisterCompanionNarration`, called at `:250`) | companion-equip scene | custom object |

Supporting assets:
- **Builders** in `NarrationHelper.lua`: `NarrateItemEntry` (name/quality/stack/category/equipped/junk/new), `NarrateSceneTitle`, `NarrateCategory`, `NarrateCurrency`, `NarrateBankingMode`, `NarrateActionKeybinds`. All pcall-guarded (`PLT-006`).
- **Strings**: `SI_BETTERUI_NARRATION_*` (STACK_COUNT_FORMAT, EQUIPPED, JUNK, ITEM_COUNT_FORMAT) present in all 7 `lang/*.lua`.
- **Tests**: `tools/tests/test_narration_helper.lua`, `test_narration_callbacks.lua`, `test_narration_providers.lua` — these verify the *builders* emit the right strings and that throwing providers are isolated. None assert that anything *queues* the narration at runtime.
- **Search-header narration**: `Modules/CIM/Core/Data/SearchManager.lua:93-160` registers via `SCREEN_NARRATION_MANAGER:RegisterTextSearchHeader(focusHandler, info)`.
- **Other wired spots**: Inventory quickslot-assign wheel (`Inventory/Module.lua:85` → `QueueCustomEntry(self.data.customNarrationObjectName)`); Trading House browse-filter dropdown/dialog (`TradingHouse/Core/BrowseFilters.lua:584,708` → `RegisterDialogDropdown` / `QueueDialog`).

---

## 2. The core defect — registered but never triggered

ESO's `SCREEN_NARRATION_MANAGER` exposes two distinct registration paths (verified against `esoui/libraries/screennarration/screennarrationmanager.lua`):

1. **`RegisterParametricList(list, narrationInfo)`** — the native path for gamepad list screens. It subscribes to the list's own `TargetDataChanged`, `ActivatedChanged`, and `MovementChanged` callbacks (`:509`, `:341`). Moving the selection **auto-queues** narration via `QueueParametricListEntry`. This is how every native gamepad list narrates.

2. **`RegisterCustomObject(objectName, narrationInfo)`** — for bespoke narration objects. It wires up **only** an `AllDialogsHidden` callback (`:499-505`). It does **not** subscribe to any selection/target change. A custom object narrates **only** when someone explicitly calls `SCREEN_NARRATION_MANAGER:QueueCustomEntry(objectName)`.

**BetterUI uses path 2 for all five screens, but nothing ever calls `QueueCustomEntry(sceneName)` on navigation.** A repo-wide search for `QueueCustomEntry` finds exactly two call sites, both in `Inventory/Module.lua:86`, and both pass `self.data.customNarrationObjectName` (the quickslot wheel) — never a screen name. Therefore:

- Scrolling any BetterUI list (Inventory, Banking, Vendor, Trading House, Companions) with the gamepad fires the list's `TargetDataChanged`, but the narration manager was never subscribed to it → **no speech is produced.**
- The custom objects can only ever narrate via their `AllDialogsHidden` re-narration hook — i.e. the instant a dialog closes over the screen — which is not navigation feedback.

Compounding evidence that path 1 was bypassed everywhere:
- `BETTERUI.Interface.Window` (`CIM/Core/Window/WindowClass.lua:32`, the base for Banking/Vendor/TH/Companions via `GenericWindow`) is a `ZO_Object` subclass, **not** a `ZO_Gamepad_ParametricList_Screen`. Its `InitializeList` (`:80`) builds the list directly and never registers it for narration.
- `BETTERUI.Inventory.Class:AddList` (`Inventory/Inventory.lua:566`) is an **override** of the native `ZO_Gamepad_ParametricList_Screen:AddList`. The native version calls `RegisterForScreenNarration` / `RegisterParametricListScreen` (`zo_gamepadparametricscrolllistscreen.lua:213-217`); the BetterUI override **omits that block**, so even the inventory list — which would otherwise inherit native narration from `ZO_GamepadInventory` — is not registered.
- Consequently, the per-entry `entry.narrationText = function() ... end` closures scattered through the components (Companions `CompanionItemList.lua:351`, Vendor `StableTrainingComponent.lua:264`, Trading House browse/sell/listings, etc.) are **also dead** — those are read only by `NarrateParametricListEntry` on the path-1 flow, which never runs.

**Net user-facing result:** a screen-reader user hears narration for the search box focus, some dialogs, and the quickslot wheel, but **silence while navigating the main list of every custom screen** — the single most important interaction.

---

## 3. Secondary findings

- **S1 — Dead narration key in search.** `SearchManager.lua` supplies `selectedItemNarrationFunction` in its text-search `narrationInfo` (`:117`). ESO's `NarrateTextSearchHeader` (`screennarrationmanager.lua:1242`) reads only `headerNarrationFunction` and `resultsNarrationFunction`. So the rich per-item search narration the author wrote is never spoken; only the header text and the empty-results text are. Low severity, but it means the "working" search path is thinner than intended.
- **S2 — No movement/VO gating on the custom path.** The native parametric path blocks narration during rapid scrolling (`SCREEN_NARRATION_BLOCKED_REASON_MOVEMENT`) and during interact voice-over. The custom-object path has neither; a naïve trigger must lean on the built-in `SCREEN_NARRATION_QUEUE_DELAY_MS` debounce + queue-overwrite (which does coalesce rapid scrolls to the settled entry — acceptable, but worth verifying in-game).
- **S3 — Keyboard mode is out of scope by design.** ESO screen narration is a gamepad/console accessibility feature; there is no equivalent keyboard-mode surface to hook, so "no narration in keyboard mode" is expected, not a defect.
- **S4 — Process gap that hid this.** The `PLT-006` narration checkpoint was closed on 2026-07-03 via "host code spot-checks" (see `feature-requests.md` → In-Game Validation Checkpoints). Source-shape tests confirm the *builders* return strings but cannot observe that **nothing calls them at runtime**. This class of defect requires in-game (or a runtime queue-observing) test to catch.

---

## 4. Recommended fix — two options

### Option A — Minimal trigger patch (RECOMMENDED for first ship)
Keep `RegisterCustomObject`; add the missing trigger. Introduce one shared helper, e.g. `Narration.QueueSceneNarration(sceneName)`, that calls `SCREEN_NARRATION_MANAGER:QueueCustomEntry(sceneName)` with manager/object existence checks. ESO keeps `IsScreenNarrationEnabled()` local inside `screennarrationmanager.lua`, so the addon helper must let `QueueCustomEntry` apply that engine-side setting gate. Invoke it from each screen's target-changed path:
- GenericWindow screens (Banking/Vendor/TH/Companions): register a `TargetDataChanged` callback on `self:GetList()` (or hook the existing selection path) that queues the scene narration.
- Inventory: queue from the BetterUI inventory list's selected-data callback (or an `OnTargetChanged` override if the native screen path is restored later).

Pros: reuses the entire tested builder stack (`NarrateItemEntry` + providers) with near-zero new logic; smallest diff; lowest regression risk. Cons: must confirm `QueueCustomEntry` behaves with a `nil` `narrationInfo.narrationType` — set `narrationType = NARRATION_TYPE_UI_SCREEN` on the registered `narrationInfo` to be safe. Does not get movement/VO gating for free (see S2).

### Option B — Native parametric-list registration (idiomatic; larger)
Register each screen's actual list via `RegisterParametricList(list, narrationInfo)` (and restore the narration block in the Inventory `AddList` override / use the list's `RegisterForScreenNarration`). Auto-wires target/activated/movement callbacks and gains movement + interact-VO gating for free. Cons: the parametric path narrates **per entry** via `entryData.narrationText` + `headerNarrationFunction`/`footerNarrationFunction` — it does **not** call `selectedNarrationFunction`. So the rich `NarrateItemEntry` output must move into per-entry `narrationText` closures (this would finally make the existing dead closures live) plus header/footer functions on the `narrationInfo`. Larger surface, more idiomatic, better long-term.

**Recommendation:** Ship Option A to make narration actually work with minimal risk, validate in-game, then optionally migrate to Option B for native-parity gating once the behavior is confirmed desirable.

---

## 5. Phased plan

> Non-ZFF repo: `npm run lint:planning --markers-only` applies (no per-item est cap). Every phase below ends at a host-owned validation gate; Phases 0 and 5 require an in-game gamepad session with narration enabled (Settings → Accessibility → Screen Narration / "Narrate…"), which is a legitimate human-in-the-loop blocker.

- **Phase 0 — Baseline the gap in-game (validation-first). (est: 1 in-game session)**
  Enable gamepad screen narration; open Inventory, Banking, Vendor, Trading House, Companions; scroll each list and confirm the *baseline* — no navigation narration today; note which peripheral paths (search focus, dialogs, quickslot) do speak. **Gate:** if navigation narration unexpectedly *does* fire, stop and re-scope — the source-level premise would be wrong. Record findings in this doc.
  - 2026-07-06 source baseline: confirmed pre-patch repo had `RegisterCustomObject` list registrations and no screen-name `QueueCustomEntry` trigger outside the quickslot wheel. In-game baseline remains pending.

- **Phase 1 — Wire the trigger (Option A). (est: ~45 min + host validation)**
  Add `Narration.QueueSceneNarration(sceneName)` to `NarrationHelper.lua`; set `narrationType = NARRATION_TYPE_UI_SCREEN` on the registered `narrationInfo`; invoke the queue from all five screens' target-changed paths. Solo slice (touches 5 module files + helper). Host runs full suite + `luac` + `test_lang_escape_hygiene` (strings untouched, but keep the gate).
  - 2026-07-06 source status: implemented via guarded `Narration.QueueSceneNarration`, current-scene Banking/Guild Banking handling, and selected-data change triggers for Inventory, Banking, Vendor, Trading House, and Companions.
  - 2026-07-06 inventory follow-up: user confirmed Inventory narrated only on initial load, not per item scroll. First follow-up queued from the live backpack and craft-bag item selection callbacks, then retest showed no Inventory narration after `/reloadui`. Root cause: Inventory registered/queued the obsolete custom object alias `gamepadInventory`, while ESO's actual gamepad inventory scene is `gamepad_inventory_root`; `RegisterListNarration` gates output through `SCENE_MANAGER:GetCurrentSceneName() == sceneName`. Source now registers and queues through `BETTERUI.Inventory.GetNarrationSceneName()` / `ZO_GAMEPAD_INVENTORY_SCENE_NAME`.

- **Phase 2 — Fix the search selected-item path (S1). (est: ~20 min + host validation)**
  Either drop the unused `selectedItemNarrationFunction` or fold the selected-item narration into `resultsNarrationFunction` (which ESO does read). Keep behavior identical for the header/empty-results narration.
  - 2026-07-06 source status: folded selected-item search details into `resultsNarrationFunction` and removed the unused `selectedItemNarrationFunction` key.

- **Phase 3 — Regression pins + tests. (est: ~40 min + host validation)**
  Add source-shape assertions that each of the five screens references `QueueSceneNarration`/`QueueCustomEntry` on a target-changed callback (mirrors the existing `test_*_source.lua` pin style), plus a runtime unit test that stubs `SCREEN_NARRATION_MANAGER:QueueCustomEntry` and asserts it fires when the target-changed callback runs. This closes the S4 process gap for the future.
  - 2026-07-06 source status: added `test_accessibility_narration_source.lua`; extended `test_narration_callbacks.lua` to cover UI-screen narration type, registered queue calls, and unregistered-scene safety. Runtime in-game acceptance still required.

- **Phase 4 (OPTIONAL, gated on Phase 0-3 + in-game pass) — Migrate to native parametric registration (Option B). (est: ~2-3 h + in-game check)**
  Move rich narration into per-entry `narrationText` + header/footer functions; register lists via `RegisterParametricList` / restore the Inventory `AddList` narration block; delete the now-redundant custom-object trigger. Gains movement/VO gating (S2) and revives the existing per-entry closures. Do **not** bundle with Phase 1.

- **Phase 5 — In-game acceptance + changelog. (est: 1 in-game session)**
  Full gamepad screen-reader pass across all five screens: navigate lists, change categories, toggle junk/equip, open dialogs, use search. Confirm each announces name + quality + stack + category + status + keybinds without spamming on fast scroll. Add a changelog entry (there is currently none for narration) and close the `ACC-010` checkpoint.
  - 2026-07-06 user validation: Vendor and Banking now narrate per item scrolled. Inventory narrated on initial load but failed per item scroll before the first follow-up; after `/reloadui`, Inventory stopped initiating narration entirely because of the scene-name mismatch above. Inventory now narrates per item scrolled after the scene-name fix.
  - 2026-07-06 user validation follow-up: Inventory now narrates after the scene-name fix. Changelog entry added in `docs/publishing/changelog.txt`. Trading House and Companions remain the only unconfirmed in-game acceptance checks.

---

## 6. Persona review notes (self-review)
- **Architect:** the seam is clean — one helper, five call sites; Option A changes the trigger only, Option B changes the registration model. No cross-module coupling beyond the existing `BETTERUI.CIM.Narration` namespace.
- **Accessibility:** the gap is the highest-impact one possible for a screen-reader user (list navigation silence). Search/dialog paths partially cover, but the primary flow is unusable today. Fixing it moves the addon from "advertises narration" to "narrates."
- **Reviewer/regression:** Option A is additive (new queue call on an existing callback); main risk is over-narration on fast scroll — mitigated by the queue delay + overwrite; verify in Phase 5.
- **Test-engineer:** current tests prove the builders, not the wiring — Phase 3 adds the missing runtime-trigger assertion so this can't silently regress again.

---

## Appendix A — Removal plan (fallback only, if Phase 0 overturns the premise)
If in-game validation shows the narration output is wrong/unwanted and the team decides not to invest, removal is small and self-contained:
1. Delete `Modules/CIM/Core/Integration/NarrationHelper.lua` and its manifest line in `BetterUI.txt:104`.
2. Remove the five `RegisterListNarration` call sites (Inventory `Module.lua:476`, Banking `Banking.lua:723-731`, Vendor `Vendor.lua:1695/1725`, TradingHouse `TradingHouse.lua:386`, Companions `CompanionsRuntime.lua:214/250`) and the `TryRegisterInventoryNarration` helper.
3. Remove `RegisterNarrationHandler` from `SearchManager.lua` (keep the search *keybind* logic).
4. Remove the `SI_BETTERUI_NARRATION_*` strings from all 7 `lang/*.lua` (via the l10n preview-first flow).
5. Delete `test_narration_helper.lua`, `test_narration_callbacks.lua`, `test_narration_providers.lua` and any narration source-pins.
6. Leave the quickslot-wheel (`customNarrationObjectName`) and Trading House dialog-dropdown narration in place — those are independently wired and working.

Estimated removal cost is lower than the improve path, but removal discards working scaffolding and 7-language strings — hence **improve is recommended** unless Phase 0 proves otherwise.
