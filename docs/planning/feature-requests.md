# Feature Requests Backlog

Last Updated: 2026-04-11
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

## Banking and Economy

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|

## Trading and Crafting

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|

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
| `PLAT-001` | 2026-04-11 | Tooling | Add a BetterUI-specific `test-runner` profile for Lua harnesses such as `tools/tests/test_vendor_tabs.lua` and syntax checks | High | Medium | `P2` | Open | MCP fallback used for vendor regression work because available `test-runner` profiles targeted an unrelated Node project; needed operation: focused Lua test execution, expected MCP action: BetterUI Lua unit profile, recovery attempted: `test_query(action=list_profiles)` only returned Node suites. Follow-up validation gap: `mcp_file-utils_process_run` now rejects Lua execution and points to `test_validate(action="lua_run")`, but that validation action is not exposed in the current tool surface, so direct `lua` execution remains the only available verification path for BetterUI harnesses. |

## Closed

| ID | Date | Area | Request | Impact | Effort | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|---|
| `INV-000` | 2026-02-08 | Inventory/Banking | Expose stack consolidation (`Stack All`) in keybind flows | High | Low | `Closed` | Closed | Implemented in Inventory and Banking keybind managers. |

## Recommended Implementation Order

1. `SOC-001` Guild roster enhancements.
2. `SOC-002` Social contacts improvements.
3. `SOC-003` Chat tooling.
4. `MAP-001` Map filter presets.
5. `GRP-001` Group Finder enhancements.
