# Feature Requests Backlog

Last Updated: 2026-06-19
Status: Active

This document tracks durable BetterUI feature gaps and parity opportunities discovered from ESO gamepad workflow audits.

> **Backlog drained to zero (2026-06-19).** Every previously-open request was either implemented as a
> first-cut (in-game validation pending) or discarded with recorded reasoning — see
> `completed-improvements.md`. The first-cut features awaiting the maintainer's in-game iteration pass are
> listed under **In-Game Validation Checkpoints** below.

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

## Banking and Economy

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|

## Trading and Crafting

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|

## Social and Guild

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|

## World and Group Systems

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|

## Accessibility and Platform

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|

## HUD and Frames

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|

## In-Game Validation Checkpoints

The 2026-06-19 backlog-drain shipped these as **first-cut** implementations (unit-tested + cross-model
reviewed; full Lua suite green). They are functionally complete in code but need the maintainer's in-game
gamepad validation/iteration before being considered final — when that pass is scheduled:

1. `PLT-003` Category-position persistence now restores by item uniqueId (GenericWindow → PositionManager). Verify Banking/Backpack cursor lands on the same item after reordering/refresh.
2. `PLT-006` Narration-broadening capability (footer-currency/mode/category/keybind providers + `NarrateActionKeybinds`) shipped in `NarrationHelper`; wire each scene's providers into its `RegisterListNarration` call and confirm with a screen reader (verbosity/timing).
3. `INV-003` Companion equipment item-preview action — confirm preview opens/exits cleanly and the keybind reads sensibly.
4. `TRC-002` Vendor buy keeps single-item default; `Vendor.ClampPurchaseQuantity` is ready — wire a quantity spinner/dialog and verify clamp to stack/affordability.
5. `TRC-003` Guild-store browse filter dialog (name/category/price/quality/level) — verify the name filter applies on first search (async gate added) and polish the dialog into dropdowns.
6. `TRC-004` Create-listing digit price entry (`ZO_CurrencySelector_Gamepad`) — verify activation/input/teardown for large prices.
7. `TRC-005` Stable active-mount icon + no-mount warning — confirm the icon resolves and the warning reads well.
