# Priority Backlog (P0/P1)

Last Audited: 2026-03-05
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
- Move closed items to `docs/planning/project-improvements.md` phase journal or changelog.

## Active Backlog

| ID | Priority | Status | Source | Item | Acceptance Criteria |
|---|---|---|---|---|---|
| `BUI-P1-001` | `P1` | Open | `project-improvements.md` | Complete multi-select anti-spam hardening rollout | Destination-slot resolution + re-entry guards + adaptive pacing are implemented and validated in-game without regressions. |
| `BUI-P1-002` | `P1` | Open | `feature-requests.md` (`ACC-001`) | Finish gamepad narration parity for BetterUI custom surfaces | Core custom screens register narration cleanly and interactive entries provide consistent spoken context. |
| `BUI-P1-003` | `P1` | In Review | `feature-requests.md` (`INV-003`) | Restore reliable `"New Item"` lifecycle and clear behavior in inventory flows | Newly acquired item indicator appears, persists correctly, and clears deterministically after expected interactions. |
| `BUI-P1-004` | `P1` | Open | `feature-requests.md` (`BNK-001`) | Define and begin guild-bank integration path for BetterUI Banking | Architecture and initial implementation path are documented, with permission-aware behavior scope locked. |

## Execution Rhythm

- Weekly: select top 1-2 active items for implementation.
- After implementation: update status and acceptance notes immediately.
- Monthly: audit priority, remove stale entries, and demote non-critical work back to feature backlog.
