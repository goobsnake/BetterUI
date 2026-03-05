# Feature Requests Backlog

Last Updated: 2026-03-05
Status: Active

This document tracks durable BetterUI feature gaps and parity opportunities discovered from ESO gamepad workflow audits.

## Intake Rules

- Log one durable request per row with a stable ID.
- Keep entries scoped to product capability gaps, not transient bugs or outages.
- Include clear impact, effort, and priority so sequencing is objective.
- Move items to `Closed` only after code, docs, and in-game validation are complete.

## Entry Template

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|

## Inventory and Companion

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `INV-001` | 2026-02-08 | Inventory | Item stat comparison parity across Inventory, Banking, and Companion item surfaces | Medium | Medium | `P2` | Partial | Inventory baseline exists; Banking and companion parity still open. |
| `INV-002` | 2026-02-08 | Inventory | Quickslot management hub (radial/list hybrid) with loadout maintenance | Medium | High | `P3` | Partial | Quickslot assignment exists, but no dedicated management scene. |
| `INV-003` | 2026-02-08 | Inventory | Restore reliable `"New Item"` lifecycle and visual clear behavior | Medium | Low | `P1` | In Review | Hooks exist but behavior is reported non-functional; verify and fix. |
| `INV-004` | 2026-02-08 | Companion | Companion equipment management workspace with comparison and slot views | Medium | Medium | `P3` | Partial | Companion compatibility exists without a dedicated companion UX surface. |

## Banking and Economy

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `BNK-001` | 2026-02-08 | Banking | Permission-aware guild bank mode with guild switching and contextual empty states | High | Medium | `P1` | Open | Extend current Banking architecture instead of stock fallback behavior. |
| `ECO-001` | 2026-02-08 | Loot | Enhanced gamepad loot window with BetterUI styling and market metadata | High | Medium | `P2` | Open | Candidate module: `Modules/Loot/`. |
| `ECO-002` | 2026-02-08 | Store | Vendor/store enhancements (sorting, price context, batch junk sell UX) | High | Medium | `P2` | Open | Reuse CIM sort/keybind patterns. |
| `MNT-001` | 2026-02-08 | Maintenance | Unified repair + soul-gem maintenance hub with urgency surfacing | Medium | Medium | `P3` | Open | Link from Inventory/Banking flows for fast maintenance actions. |

## Trading and Crafting

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `TH-001` | 2026-02-08 | Trading House | Guild store/trading house overhaul with stronger search, presets, and unit-price ergonomics | Very High | High | `P2` | Open | Highest effort and one of the highest player-impact targets. |
| `CFT-001` | 2026-02-08 | Crafting | Crafting station UI enhancements with research-aware and value-aware guidance | Medium | High | `P3` | Open | Expand beyond current writ integration. |
| `MAIL-001` | 2026-02-08 | Mail | Better mail inbox/attachments UX with bulk flows and clearer COD handling | Medium | Medium | `P3` | Open | Candidate module: `Modules/Mail/`. |
| `COL-001` | 2026-02-08 | Collections | Collections/outfit browser improvements with filtering, favorites, and progress clarity | Medium | High | `P3` | Open | Candidate module: `Modules/Collections/`. |

## Social and Guild

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `SOC-001` | 2026-02-08 | Guild | Guild roster and rank-management workspace with clearer moderation actions | Medium | High | `P3` | Open | Candidate module: `Modules/Guild/`. |
| `SOC-002` | 2026-02-08 | Social | Social contacts and notification hub improvements | Medium | Medium | `P3` | Open | Improve action clarity and list readability. |
| `SOC-003` | 2026-02-08 | Chat | Chat menu/channel tooling and faster context switching | Medium | Medium | `P3` | Open | Candidate module: `Modules/Chat/`. |

## World and Group Systems

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `MAP-001` | 2026-02-08 | Map | Map filter presets and quest-integration improvements | Medium | High | `P4` | Open | Long-horizon system with broad touch points. |
| `GRP-001` | 2026-02-08 | Group Finder | Group finder and role-selection UX enhancements | Medium | High | `P4` | Open | High-value for endgame users; larger integration surface. |

## Accessibility and Platform

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `ACC-001` | 2026-02-08 | Accessibility | Narration parity completion across custom BetterUI screens | High | Low | `P1` | Partial | Search narration exists; full list/entry/footer parity is incomplete. |
| `PLT-001` | 2026-02-08 | Platform | Console add-on support and mod-browser readiness track | High | High | `P2` | Open | Requires packaging, runtime-gating, and footprint policy work. |

## Closed

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `INV-000` | 2026-02-08 | Inventory/Banking | Expose stack consolidation (`Stack All`) in keybind flows | High | Low | `Closed` | Closed | Implemented in Inventory and Banking keybind managers. |

## Recommended Implementation Order

1. `ACC-001` Narration parity.
2. `INV-003` New-item lifecycle fix.
3. `BNK-001` Guild bank support.
4. `ECO-001` and `ECO-002` Loot + Store improvements.
5. `TH-001` Trading house overhaul.
6. `PLT-001` Console readiness track.
