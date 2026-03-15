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
| VND-002 | P1 | Open | ECO-002 Vendor phase 1 | **Stable integration**: Add Stable riding-training tab to BetterUI Vendor module (`ZO_MODE_STORE_STABLE`). Uses `STABLE_MANAGER` for stats/cost, distinct item template with progress bars, no interaction type needed (stable uses `INTERACTION_STABLE` via existing `STORE_INTERACTION`). | Stable tab visible when interacting with stable NPC; riding training (Speed, Stamina, Carry) displayed with progress bars; training triggers correctly via BetterUI scene. |
| VND-003 | P1 | Open | ECO-002 Vendor phase 1 | **SellVengeance integration**: Add Sell Vengeance bag tab (`ZO_MODE_STORE_SELL_VENGEANCE`) to BetterUI Vendor module. Requires `IsCurrentCampaignVengeanceRuleset() and ZO_VENGEANCE_BAG_SELL_ENABLED` guard; uses `BAG_VENGEANCE`. | SellVengeance tab appears when Vengeance ruleset is active and bag sell is enabled; items from `BAG_VENGEANCE` list and sell correctly. |

## Execution Rhythm

- Weekly: select top 1-2 active items for implementation.
- After implementation: update status and acceptance notes immediately.
- Monthly: audit priority, remove stale entries, and demote non-critical work back to feature backlog.
