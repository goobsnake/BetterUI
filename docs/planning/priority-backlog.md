# Priority Backlog (P0/P1)

Last Audited: 2026-06-19
Status: Active

## Purpose

This file is the short-horizon execution backlog for critical and high-priority BetterUI work.

Use this backlog for:
- Immediate reliability and regression-risk items.
- High-impact UX or compatibility gaps that should land ahead of broad feature expansion.

## Operating Rules

- Keep this list small and actionable (target: <= 10 active items).
- Promote only `P0` or `P1` items.
- Keep durable problem statements here, not per-session incident logs.
- This file holds only open/outstanding items. When an item is resolved, migrate a summary to `completed-improvements.md` and remove its row; never leave a row marked completed/resolved in place. Validate with `tools/tests/validate_planning.sh`.

## Active Backlog

| ID | Priority | Status | Source | Item | Acceptance Criteria |
|---|---|---|---|---|---|
| PB-016 | P3 | Open | Improvement-cycle drain residual (PB-014d, 2026-06-19) | **Banking refresh-manager not cancelled on teardown**: the PB-014d scene-cleanup teardown now cancels screen-attached refresh managers, but Banking holds its manager at module scope (`BETTERUI.Banking.RefreshManager`, `Modules/Banking/Core/RefreshIntegration.lua`), so it is not reached by the in-scope `SceneCleanup` step — an in-flight Banking coalesced refresh can still run after teardown. `est: 10m` | Attach the manager to the screen (`screen.refreshManager = BETTERUI.Banking.RefreshManager`) or call its `Cancel()` in `BankingSceneLifecycle` teardown; validate in-game (L4). |

PB-001–PB-015 were resolved and archived in `completed-improvements.md` (PB-002–PB-006 under MPR-2; PB-007 under the Comment Feedback plan; PB-001 + PB-008–PB-015 under the 2026-06-19 improvement-cycle drain).

## Execution Rhythm

- Weekly: select top 1-2 active items for implementation.
- After implementation: update status and acceptance notes immediately.
- Monthly: audit priority, remove stale entries, and demote non-critical work back to feature backlog.
