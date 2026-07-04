# Feature Requests Backlog

Last Updated: 2026-07-03
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

None open. The 2026-06-19 backlog-drain first-cut checkpoints (`PLT-003`, `PLT-006`, `INV-003`,
`TRC-002`, `TRC-003`, `TRC-004`, `TRC-005`) were all closed on 2026-07-03 via host code spot-checks
(fix applied for the TRC-004 price-selector input-capture leak; see `completed-improvements.md`).
