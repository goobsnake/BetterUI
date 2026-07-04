# Priority Backlog (P0/P1)

Last Audited: 2026-07-03
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

(Empty — no open P0/P1 items.)

PB-001–PB-017 were resolved and archived in `completed-improvements.md` (PB-002–PB-006 under MPR-2; PB-007 under the Comment Feedback plan; PB-001 + PB-008–PB-015 under the 2026-06-19 improvement-cycle drain; PB-016 — Banking module-scope refresh manager now cancelled in `BankingSceneLifecycle:OnSceneHidden` — under the 2026-06-19 improvement-cycle review remediation; PB-017 — vendor buy-list retry single owner — under the 2026-07-03 wave-1 backlog drain, commit `4e773a50`).

## Execution Rhythm

- Weekly: select top 1-2 active items for implementation.
- After implementation: migrate the accepted result to `completed-improvements.md` and remove the active row.
- Monthly: audit priority, remove stale entries, and demote non-critical work back to feature backlog.
