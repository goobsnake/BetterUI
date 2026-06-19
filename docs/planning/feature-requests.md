# Feature Requests Backlog

Last Updated: 2026-06-19
Status: Active

This document tracks durable BetterUI feature gaps and parity opportunities discovered from ESO gamepad workflow audits.

## Intake Rules

- Log one durable request per row with a stable ID.
- Keep entries scoped to product capability gaps, not transient bugs or outages.
- Include clear impact, effort, and priority so sequencing is objective.
- Move items to `Closed` only after code, docs, and in-game validation are complete.

## Status legend

`Open` = actionable; `Completed`/`Closed` = done; `Discarded` = reviewed and not pursued (reason in Notes);
`Blocked (L4)` = valid but final acceptance needs in-game validation/iteration the host cannot run;
`Blocked (external)` = valid but gated on an external dependency (e.g. human translation).

## Entry Template

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |

## Inventory and Companion

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `INV-001` | 2026-06-11 | Inventory dialogs | Consolidate InventoryMultiSelect batch dialogs into `BETTERUI.CIM.Dialogs.Register` with a shared builder | Low | Low | P3 | **Completed (2026-06-19)** | Engineer review (MPR-1). Pass-2: consolidated both batch dialogs through `BETTERUI.CIM.Dialogs.Register` via a shared `BuildBatchDialogTemplate`; `ESO_Dialogs` is no longer written directly. +`test_inventory_multiselect_dialogs.lua`. |
| `INV-002` | 2026-06-11 | Companions | Slot-centric companion category model (native parity): categories from `ZO_Character_EnumerateOrderedEquipSlots(BAG_COMPANION_WORN)`, selected-slot equip targeting, right-tooltip slot mirroring | Medium | High | P3 | Blocked (L4) | Companions deep review (2026-06-11). BetterUI deliberately uses inventory-style filter categories. Pass-2: KEEP-BLOCKED-L4 — large gamepad-interactive native-parity feature requiring in-game iteration; current filter-category model is an intentional design choice. Interim fixes already landed. |
| `INV-003` | 2026-06-11 | Companions | Gamepad item-preview integration for companion equipment (`PreviewInventoryItem`/`EndPreview`, gated by `CanInventoryItemBePreviewed`) | Low | Medium | P3 | Blocked (L4) | Companions deep review (2026-06-11). Pass-2: KEEP-BLOCKED-L4 — interactive preview surface needs in-game validation. |

## Banking and Economy

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `ECO-001` | 2026-05-29 | Currency display | Add Archival Fortunes to the currency display options | Medium | Low | P2 | **Completed** | ESOUI comment (oddavi, 05/29/26). Infinite Archive currency (`CURT_ARCHIVAL_FORTUNES`); add to the currency rows/toggles wherever existing optional currencies (Tel Var, Transmute, etc.) are offered. |

## Trading and Crafting

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `TRC-001` | 2026-04-11 | Market integration | Show market price data on crafting and improvement pages (TTC 4.27 parity) | Medium | Medium | P2 | **Completed** | ESOUI comment (Edricson, 04/11/26). TTC 4.27 added price data to crafting/improvement screens; extend BUI market integration (ATT/MM/TTC via `MarketIntegration.lua`) to gamepad crafting/improvement panels. |
| `TRC-002` | 2026-06-11 | Vendor buy flow | Quantity spinner for purchasing stacked store items (parity with native STORE_WINDOW_GAMEPAD spinner) | Medium | Medium | P3 | Blocked (L4) | Engineer review (MPR-1). `Modules/Vendor/Components/BuyComponent.lua` hard-codes quantity 1 for stacked items. Deep review (2026-06-11) extended scope to sell-side parity (sell/fence/launder/sell-vengeance). Pass-2: KEEP-BLOCKED-L4 — interactive vendor spinner UI needs in-game iteration. |
| `TRC-003` | 2026-06-11 | Guild store browse | Browse filter-editing UI: item-name search (`MatchTradingHouseItemNames` autocomplete), category, price-range, quality, and level filters | High | High | P2 | Blocked (L4) | TradingHouse deep review (2026-06-11). Search-feature association already wired (`AssociateSearchFeatures`). Pass-2: KEEP-BLOCKED-L4 — large interactive filter UI surface requiring in-game iteration. |
| `TRC-004` | 2026-06-11 | Guild store sell | Digit-entry price selector for create-listing (ZO_CurrencySelector-style) | Low | Medium | P3 | Blocked (L4) | TradingHouse deep review (2026-06-11). The price slider reaches exact prices for ranges ≤ 10000; large ranges keep a coarse step. Pass-2: KEEP-BLOCKED-L4 — interactive digit-entry selector needs in-game validation. |
| `TRC-005` | 2026-06-11 | Vendor stables | Stable parity polish: active-mount icon, no-mount-skin warning, train-button animation/narration | Low | Medium | P3 | Blocked (L4) | Vendor deep review (2026-06-11). `StableTrainingComponent.lua` uses a generic mount icon and calls `TrainRiding` directly. Pass-2: KEEP-BLOCKED-L4 — animated/narrated interactive UI needs in-game validation. |
| `TRC-006` | 2026-06-12 | Guild store browse | Browse and purchase guild-specific store items (e.g. guild tabards) | Low | Medium | P3 | **Discarded (2026-06-19)** | Engineer review (MPR-3). No `GetGuildSpecificItemInfo` / `BuyGuildSpecificItem` path. Pass-2: DISCARD — intentional/niche scope gap; not pursuing. |

## Social and Guild

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|

## World and Group Systems

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|

## Accessibility and Platform

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `PLT-001` | 2026-06-11 | Code structure | Split files exceeding the 600-line standard by concern | Medium | High | P3 | **Discarded (2026-06-19)** | Engineer review (MPR-1); files listed (VendorClass ~1840, Vendor ~1390, BankingClass ~1067, etc.). Reviewed (MPR-2): high-regression-risk refactor with no functional benefit. Pass-2: DISCARD — these files are cohesive; the ~600-line guideline yields to cohesion here, and a blind split is net-negative. Reopen only if a concrete maintainability pain arises. |
| `PLT-002` | 2026-06-11 | Localization | Backfill non-EN locale files with missing string ids | Medium | Medium | P3 | Blocked (external) | Engineer review (MPR-1). MPR-2 measured **83 `SI_BETTERUI_*` ids** EN-only across all six non-EN locales; **cosmetic** (EN fallback at runtime). Pass-2: KEEP-BLOCKED-EXTERNAL — needs human translation of ~498 ESO-specific strings; machine translation risks unfit strings. Backfill via the preview-first `l10n_*` flow when translations are available. |
| `PLT-003` | 2026-06-11 | CIM persistence | Converge `GenericWindow` category-position persistence onto `BETTERUI.CIM.PositionManager` | Low | Medium | P3 | Blocked (L4) | Engineer review (MPR-1). Two persistence systems with divergent restore fidelity (`GenericWindow` index-only vs `PositionManager` uniqueId-aware). Pass-2: KEEP-BLOCKED-L4 — the convergence logic is code-only, but it changes user-visible saved category-position restore behavior, so final acceptance requires confirming positions restore correctly in-game (and a SavedVars migration check). |
| `PLT-004` | 2026-06-11 | CIM consolidation | Migrate the remaining medium/high-risk cross-module duplication clusters into shared CIM seams | Medium | High | P3 | Blocked (L4) | CIM consolidation discovery (2026-06-11); low-risk clusters already consolidated. Remaining clusters (search lifecycle wiring, list row setup, cross-module entry functions, deposit predicates, tooltip layout helpers, batch move-op factory, scene lifecycle latches) need behavioral care. Pass-2: KEEP-BLOCKED-L4 — high effort, each cluster needs in-game validation; pursue per-cluster, not as one sweep. |
| `PLT-005` | 2026-06-12 | Code structure | Optionally harden Banking/Inventory transfer batches to re-validate with `IsSlotIdentityCurrent` instead of `HasItemAtSlot` | Low | Low | P3 | **Discarded (2026-06-19)** | Engineer review (MPR-3). Pass-2: DISCARD — `HasItemAtSlot` is sufficient for non-destructive moves (a shifted slot is harmless); acceptable as-is, no demonstrated bug. |
| `PLT-006` | 2026-06-19 | Accessibility | Harden + broaden gamepad narration: wrap callback bodies so screen-reader invocations can't throw, and extend coverage to footer currency, mode/category, and action/keybind labels | Medium | Medium | P3 | Partially done (2026-06-19) | Improvement-cycle security/a11y review (codex). Pass-2: HARDENING DONE — `canNarrate`/`selectedNarrationFunction` callback bodies are now pcall-wrapped (return false / empty on error). +`test_narration_callbacks.lua`. Coverage broadening (footer currency / mode / category / keybind labels) remains Blocked (L4) — it adds narration to interactive surfaces best verified with a screen reader in-game. |
| `PLT-007` | 2026-06-19 | Diagnostics / logging | Optional batch-coalescing mode for `verbose` logging | Low | Medium | P3 | **Discarded (2026-06-19)** | Improvement-cycle logging review (codex). Pass-2: DISCARD — the v3.07 per-frame/second InterfaceLog budget already bounds the frame-hitch risk; batch-coalescing adds external-tail-parser format complexity for marginal IO gain. Reopen only if a real high-volume tail need arises. |

## HUD and Frames

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `HUD-001` | 2026-04-10 | Resource orbs / action bar | Allow moving resource orbs independently from the action bar (at minimum, independent orb offsets) | High | High | P2 | **Completed** | ESOUI comments (Loliam 04/10/26, Vo1se 05/10/26). Orbs and bars are currently anchored as one frame group (`Modules/ResourceOrbFrames`, `PositionManager.lua`); author previously replied "whole UI frames move together". Requested repeatedly. |
| `HUD-002` | 2026-06-11 | Resource orbs | Decide FoodBuffTracker: implement food-buff tracking or remove the stub | Low | Medium | P3 | **Completed** | Engineer review (MPR-1). `Core/OrbBarUpdates.lua` FoodBuffTracker always reports 0 and the FoodBar XML control ships placeholder values (`Templates/ResourceOrbFrames.xml`). Resolved (MPR-2, 2026-06-12): removed the dead FoodBuffTracker class/Update/factory and the FoodBar placeholder control. |
| `HUD-003` | 2026-06-11 | Nameplates fonts | Consume `FontLocalization.WESTERN_ONLY_FONTS` in Nameplates instead of its local duplicate list | Low | Low | P3 | **Completed** | Engineer review (MPR-1). CIM copies were deduplicated 2026-06-11. Resolved (MPR-2, 2026-06-12): `Modules/Nameplates/Nameplates.lua` now calls `BETTERUI.CIM.Font.Localization.IsFontWesternOnly`; private duplicate removed. |
| `HUD-004` | 2026-06-12 | Resource orbs / cooldowns | Filter the global cooldown by reading the `global` (3rd) return of `GetSlotCooldownInfo` instead of a 1500ms threshold | Low | Low | P3 | **Completed (2026-06-19)** | Engineer review (MPR-3). Pass-2: implemented — `CooldownUtils.ResolveCooldownWindow` now reads the `isGlobalCooldown` (3rd) return of `GetSlotCooldownInfo` and suppresses only the GCD, matching `FrontBarManager`. +`test_cooldown_utils.lua` coverage. (In-game L4 spot-check recommended: real 1000–1500ms non-GCD cooldowns still display.) |

_Open feature-request inventory cleared on 2026-04-16 per product decision. Historical closed items remain below._

## Closed

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `INV-000` | 2026-02-08 | Inventory/Banking | Expose stack consolidation (`Stack All`) in keybind flows | High | Low | `Closed` | Closed | Implemented in Inventory and Banking keybind managers. |

## Recommended Implementation Order

Next actionable items are all `Blocked (L4)` — they need an in-game iteration pass. When that pass is scheduled:

1. `PLT-003` Converge category-position persistence (lowest risk; verify saved positions restore).
2. `TRC-002` Vendor quantity spinner (high user value, isolated component).
3. `TRC-003` Guild-store browse filter UI (highest value; largest surface).
