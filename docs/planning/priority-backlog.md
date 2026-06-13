# Priority Backlog (P0/P1)

Last Audited: 2026-06-12
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
| PB-001 | P1 | Resolved (2026-06-10) | MCP compliance fallback audit | **Lua harness verification gap** (`tools/tests/run_all_tests.lua`, MCP `test_validate`/`process_run`): repository-wide Lua test harness cannot be verified end-to-end with current MCP surfaces because `test_validate(action=lua_run)` is file-scoped and `mcp_file-utils_process_run` blocks inline Python wrappers needed to execute `lua tools/tests/run_all_tests.lua` with bounded output. `est: 5m` | Provide an MCP-safe way to execute the aggregate Lua harness and return the real child-test exit status/output without shell fallback, or add a dedicated test-runner profile/action for BetterUI's standalone Lua suite. |
| PB-002 | P1 | Resolved (2026-06-12) | ESOUI comment (shadowcep, 04/11/26) | **Action-menu Mark as Junk breaks L1/R1 category triggers** (`Modules/Inventory`): after applying Mark as Junk from the Actions dialog on a single item (not bulk select, not the direct keybind), L1/R1 no longer page the category carousel — L1 opens currency/stats and R1 swaps the right pane (often "Locked"); user must exit and re-enter inventory. Direct Mark as Junk keybind and bulk-selection path behave correctly. `est: 5m` | After Actions-dialog junk on a single item, L1/R1 page categories exactly as before the action; no scene/keybind-strip leakage to currency/stats panes. **Fixed (MPR-2): deferred keybind restoration to the post-dialog OnFinish path + robust EnsureHeaderKeybindsActive; see completed-improvements.** |
| PB-003 | P1 | Resolved (2026-06-12) | ESOUI comment (Daeymon, 04/25/26) | **Tooltip enhancements toggle-off does not restore defaults in-session** (`Modules/CIM` tooltip styling): disabling tooltip enhancements leaves sizing/styling overrides applied — wrapped/spaced header line (item type / bound / count) above the tooltip title — until a full logout/login. Defaults only return after relog with the setting off. `est: 5m` | Toggling enhancements off immediately restores stock gamepad tooltip layout in the same session; toggling on/off repeatedly never accumulates style drift. **Fixed (MPR-2): gated the per-layout PostHook on the setting + total cleanup + immediate re-layout.** |
| PB-004 | P2 | Resolved (2026-06-12) | ESOUI comment (Daeymon, 04/25/26) | **Enhanced tooltips drop the set-collection "Collected/Uncollected" tag** (`Modules/CIM` tooltip styling): with tooltip enhancements enabled, set gear tooltips no longer show the collection status tag that stock gamepad tooltips display. `est: 5m` | Set-gear tooltips show the same Collected/Uncollected status with enhancements on as stock tooltips do. **Fixed (MPR-2): re-added the set-collection status segment to the enhanced status line.** |
| PB-005 | P2 | Resolved (2026-06-12) | ESOUI comment (shadowcep, 05/12/26) | **Gui Warning: control name truncated** (`Modules/Inventory/Lists/ItemListManager.lua` + `BETTERUI_GamepadItemSubEntryTemplateWithHeader` virtual template): pooled list controls like `BETTERUI_GamepadInventoryTopLevelMaskContainerItemsListScroll<template><n>SelectionIndicator` exceed the engine's max control-name length, spamming `interface.log` with truncation warnings and risking name collisions. `est: 5m` | Shorten the virtual template names (and/or list control names) so generated pooled child names stay under the engine limit; no truncation warnings in interface.log for BETTERUI controls. **Fixed (MPR-2): renamed TopLevel control to `BUI_GpInv` + category pool prefix; pooled names now under the 63-char limit.** |
| PB-006 | P2 | Resolved (2026-06-12) | ESOUI comment (shadowcep, 04/11/26; bortsmithson, 04/10/26) | **Stale primary action shown after container open** (`Modules/Inventory` keybind resolution): after opening a container (e.g. jubilee box), the single Mark as Junk primary action can appear on the next container instead of Use; users must read the key bar to know what will fire. Related: historical Use→Link-in-Chat swaps when items appear/disappear (partially fixed in v3.06). `est: 5m` | Primary action shown for the selected slot always matches the action that fires; container-open/junk transitions re-resolve the keybind for the reselected row. **Fixed (MPR-2): force primary-action re-resolution on in-place inventory updates for the selected slot.** |
| PB-007 | P3 | **Completed** | ESOUI comment (bortsmithson, 04/10/26) | **Furniture vault deposit needs multiple presses** (`Modules/Banking`): investigation (2026-06-10) found the deposit path issues `CallSecureProtected("RequestMoveItem", ...)` (`Modules/Banking/Actions/TransferActions.lua:212`) with no client-side rejection or debounce — the delay is the server round-trip confirming the vault move, matching the reporter's "click once and wait" observation. Remaining work is UX only. `est: 5m` | Track the in-flight deposit per slot (clear on `EVENT_INVENTORY_SINGLE_SLOT_UPDATE`) and show a busy/disabled keybind state so repeat presses are unnecessary. |

PB-001 resolution note (2026-06-10): the aggregate harness IS runnable end-to-end via MCP — `test_validate(action="lua_run", workDir=<repo root>, files=["tools/tests/run_all_tests.lua"])` executes all child tests with the correct cwd and returns the real exit status (verified green across 162 test files). The earlier failure mode was running with `workDir=tools/tests`, which breaks the tests' repo-root-relative `dofile("Modules/...")` paths.

## Execution Rhythm

- Weekly: select top 1-2 active items for implementation.
- After implementation: update status and acceptance notes immediately.
- Monthly: audit priority, remove stale entries, and demote non-critical work back to feature backlog.
