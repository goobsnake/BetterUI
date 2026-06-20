# Feature Requests Backlog

Last Updated: 2026-06-19
Status: Active

This document tracks durable BetterUI feature gaps and parity opportunities discovered from ESO gamepad workflow audits.

## Intake Rules

- Log one durable request per row with a stable ID.
- Keep entries scoped to product capability gaps, not transient bugs or outages.
- Include clear impact, effort, and priority so sequencing is objective.
- This file holds only open/outstanding requests. Migrate completed items to `completed-improvements.md` and remove the row; delete discarded items (reason in the commit) — never leave a completed/discarded row here. Validate with `tools/tests/validate_planning.sh`.

## Status legend

`Open` = actionable; `Blocked (L4)` = valid but final acceptance needs in-game validation/iteration the host cannot run;
`Blocked (external)` = valid but gated on an external dependency (e.g. human translation);
`Partially done` = some work landed; the remaining (open) portion is noted in the row.

## Entry Template

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |

## Inventory and Companion

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `INV-002` | 2026-06-11 | Companions | Slot-centric companion category model (native parity): categories from `ZO_Character_EnumerateOrderedEquipSlots(BAG_COMPANION_WORN)`, selected-slot equip targeting, right-tooltip slot mirroring | Medium | High | P3 | Blocked (L4) | Companions deep review (2026-06-11). BetterUI deliberately uses inventory-style filter categories. Pass-2: KEEP-BLOCKED-L4 — large gamepad-interactive native-parity feature requiring in-game iteration; current filter-category model is an intentional design choice. Interim fixes already landed. |
| `INV-003` | 2026-06-11 | Companions | Gamepad item-preview integration for companion equipment (`PreviewInventoryItem`/`EndPreview`, gated by `CanInventoryItemBePreviewed`) | Low | Medium | P3 | Blocked (L4) | Companions deep review (2026-06-11). Pass-2: KEEP-BLOCKED-L4 — interactive preview surface needs in-game validation. |

## Banking and Economy

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|

## Trading and Crafting

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `TRC-002` | 2026-06-11 | Vendor buy flow | Quantity spinner for purchasing stacked store items (parity with native STORE_WINDOW_GAMEPAD spinner) | Medium | Medium | P3 | Blocked (L4) | Engineer review (MPR-1). `Modules/Vendor/Components/BuyComponent.lua` hard-codes quantity 1 for stacked items. Deep review (2026-06-11) extended scope to sell-side parity (sell/fence/launder/sell-vengeance). Pass-2: KEEP-BLOCKED-L4 — interactive vendor spinner UI needs in-game iteration. |
| `TRC-003` | 2026-06-11 | Guild store browse | Browse filter-editing UI: item-name search (`MatchTradingHouseItemNames` autocomplete), category, price-range, quality, and level filters | High | High | P2 | Blocked (L4) | TradingHouse deep review (2026-06-11). Search-feature association already wired (`AssociateSearchFeatures`). Pass-2: KEEP-BLOCKED-L4 — large interactive filter UI surface requiring in-game iteration. |
| `TRC-004` | 2026-06-11 | Guild store sell | Digit-entry price selector for create-listing (ZO_CurrencySelector-style) | Low | Medium | P3 | Blocked (L4) | TradingHouse deep review (2026-06-11). The price slider reaches exact prices for ranges ≤ 10000; large ranges keep a coarse step. Pass-2: KEEP-BLOCKED-L4 — interactive digit-entry selector needs in-game validation. |
| `TRC-005` | 2026-06-11 | Vendor stables | Stable parity polish: active-mount icon, no-mount-skin warning, train-button animation/narration | Low | Medium | P3 | Blocked (L4) | Vendor deep review (2026-06-11). `StableTrainingComponent.lua` uses a generic mount icon and calls `TrainRiding` directly. Pass-2: KEEP-BLOCKED-L4 — animated/narrated interactive UI needs in-game validation. |

## Social and Guild

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|

## World and Group Systems

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|

## Accessibility and Platform

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `PLT-002` | 2026-06-11 | Localization | Backfill non-EN locale files with missing string ids | Medium | Medium | P3 | Blocked (external) | Engineer review (MPR-1). MPR-2 measured **83 `SI_BETTERUI_*` ids** EN-only across all six non-EN locales; **cosmetic** (EN fallback at runtime). Pass-2: KEEP-BLOCKED-EXTERNAL — needs human translation of ~498 ESO-specific strings; machine translation risks unfit strings. Backfill via the preview-first `l10n_*` flow when translations are available. |
| `PLT-003` | 2026-06-11 | CIM persistence | Converge `GenericWindow` category-position persistence onto `BETTERUI.CIM.PositionManager` | Low | Medium | P3 | Blocked (L4) | Engineer review (MPR-1). Two persistence systems with divergent restore fidelity (`GenericWindow` index-only vs `PositionManager` uniqueId-aware). Pass-2: KEEP-BLOCKED-L4 — the convergence logic is code-only, but it changes user-visible saved category-position restore behavior, so final acceptance requires confirming positions restore correctly in-game (and a SavedVars migration check). |
| `PLT-004` | 2026-06-11 | CIM consolidation | Migrate the remaining medium/high-risk cross-module duplication clusters into shared CIM seams | Medium | High | P3 | Blocked (L4) | CIM consolidation discovery (2026-06-11); low-risk clusters already consolidated. Remaining clusters (search lifecycle wiring, list row setup, cross-module entry functions, deposit predicates, tooltip layout helpers, batch move-op factory, scene lifecycle latches) need behavioral care. Pass-2: KEEP-BLOCKED-L4 — high effort, each cluster needs in-game validation; pursue per-cluster, not as one sweep. |
| `PLT-006` | 2026-06-19 | Accessibility | Broaden gamepad narration coverage to footer currency, mode/category, and action/keybind labels | Medium | Medium | P3 | Blocked (L4) | Improvement-cycle a11y review (codex). The narration **hardening** half (pcall-wrapping `canNarrate`/`selectedNarrationFunction` + `test_narration_callbacks.lua`) shipped and is archived in `completed-improvements.md` (2026-06-19). Remaining: the coverage broadening adds narration to interactive surfaces best verified with a screen reader in-game. KEEP-BLOCKED-L4. |

## HUD and Frames

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|

## Recommended Implementation Order

Next actionable items are all `Blocked (L4)` — they need an in-game iteration pass. When that pass is scheduled:

1. `PLT-003` Converge category-position persistence (lowest risk; verify saved positions restore).
2. `TRC-002` Vendor quantity spinner (high user value, isolated component).
3. `TRC-003` Guild-store browse filter UI (highest value; largest surface).
