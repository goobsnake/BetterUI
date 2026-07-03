# Priority Backlog (P0/P1)

Last Audited: 2026-06-30
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

### PB-017 (P1): Vendor buy-list retry has two owners with conflicting limits

Found during the 2026-07-03 dead-code/redundancy review. `Modules/Vendor/Components/BuyComponent.lua:370-405` and `Modules/Vendor/Core/Lifecycle/VendorControllerRuntime.lua:~660-712` both schedule a deferred task named `"buyListRetry"` and share the same `instance._buyListRetryCount` counter, but with conflicting policies (limit 3 at 80ms×n vs limit 20 at 180ms). Whichever path runs second can cancel/starve or over-extend the other's retry budget, so an empty buy list can stop retrying earlier than either policy intends (or retry with mixed cadence).

- [ ] Task: Pick a single retry owner (VendorControllerRuntime is the lifecycle-scoped candidate), give it one limit/cadence, and delete or delegate the other path; add a regression test that both entry points converge on one counter and one task name. (est: 15 min)

PB-001–PB-016 were resolved and archived in `completed-improvements.md` (PB-002–PB-006 under MPR-2; PB-007 under the Comment Feedback plan; PB-001 + PB-008–PB-015 under the 2026-06-19 improvement-cycle drain; PB-016 — Banking module-scope refresh manager now cancelled in `BankingSceneLifecycle:OnSceneHidden` — under the 2026-06-19 improvement-cycle review remediation).

## Execution Rhythm

- Weekly: select top 1-2 active items for implementation.
- After implementation: migrate the accepted result to `completed-improvements.md` and remove the active row.
- Monthly: audit priority, remove stale entries, and demote non-critical work back to feature backlog.
