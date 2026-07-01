# Builog Developer Guide

Developer standards for BetterUI's live diagnostics stream. Use this when changing
`BETTERUI.Log`, `/builog`, watch/inspect instrumentation, the host monitor, or any
feature code that emits diagnostics.

## Sources Of Truth

- Runtime formatter: `Modules/CIM/Core/Diagnostics/Log.lua`
- File transport and slash commands: `Modules/CIM/Core/Diagnostics/InterfaceLog.lua`
- Watch/inspect enrichment: `Modules/CIM/Core/Diagnostics/WatchMode.lua`
- Screenshot correlation: `Modules/CIM/Core/Diagnostics/Screenshot.lua`
- Host parser contract: `docs/reference/logging-host-tail-parse.md`
- Operator workflow: `docs/reference/logging-playbook.md`
- Monitor tool: `tools/builog-monitor/monitor.sh` and `tools/builog-monitor/SKILL.md`
- Contract tests: `tools/tests/test_log_parse_contract.lua`, `test_builog_flow_source.lua`,
  `test_builog_monitor_source.lua`, `test_log.lua`, `test_interface_log.lua`, and
  `test_watchmode.lua`

## How It Works

Retail ESO has no public API for arbitrary writes to `Interface.log`. BetterUI gets a
live host-readable stream by raising a tagged, deferred, popup-suppressed throwaway Lua
error for each breadcrumb. The engine writes the error text to `Interface.log`; BetterUI
suppresses the player-facing error frame and keeps real, untagged Lua errors distinct.

The pipeline is:

1. Feature code calls `BETTERUI.Log.<Level>(category, message, data)`, `Log.TraceEvent`,
   `Log.FlowBegin` / `Log.FlowEnd`, or a lazy helper.
2. `Log.lua` applies level/category/sink gates, renders one normalized line, adds `sid`
   and `seq`, keeps recent/error rings, and notifies screenshot auto-capture.
3. `InterfaceLog.WriteRaw` schedules the line through the suppressed-error file sink,
   applying per-frame, per-second, and pending-record budgets.
4. `WatchMode` adds `scene`, `view`, `flow`, and `lastAction` context for `watch` and
   `inspect`, emits a startup preamble, and schedules heartbeat snapshots.
5. A host process filters `[BUI]` lines from `Interface.log`, ignores their generated
   traceback blocks, and keeps untagged `Lua Error:` blocks as real errors.

## Command Surface

`/builog` supports:

| Command | Contract |
|---|---|
| `on` / `off` | Enable/disable the file stream. `off` restores the prior error-popup state. Prefer `preset <name>` over plain `on`; plain `on` preserves the current low-level logger knobs and persists an empty preset name. |
| `preset off|info|watch|debug|trace|inspect` | Apply the standard logging tiers. |
| `level trace|debug|info|warn|error` | Override only the minimum level; preset becomes `custom`. |
| `mark <text>` | Emit `STATE | mark: <text>` for host correlation. |
| `recent [n]` / `errors [n]` | Dump retained in-memory records to chat. |
| `capture [secs]` | Temporarily switch to `trace`, then revert. Default 5s, capped 1-60s. |
| `screenshot [label]` | Request a screenshot and emit request/saved markers. |
| `screenshot auto off|error|warn` | Persisted opt-in auto capture for current play-test windows. |
| `snapshot` | Emit one `STATE | snapshot` immediately. |
| `check` / `test` | Emit diagnostic breadcrumbs; `test` is a compatibility alias. If logging was off, this command enables the session stream and leaves it on so the breadcrumbs reach `Interface.log`. |
| `status` | Print preset, active sink budget, counters, and screenshot state. |

`/buihealth` reports a compact health summary. `/buiscene` reports scene state and recent
scene transitions.

## Presets

| Preset | Level | Payloads | Enrichment | Budget |
|---|---|---|---|---|
| `off` | none | off | none | unlimited/reset |
| `info` | INFO+ | off | none | 8/frame, 100/sec, 200 pending |
| `watch` | DEBUG+ | on | watch context + snapshots | 2000/frame, 40000/sec, 40000 pending |
| `debug` | DEBUG+ | on | none | 2000/frame, 40000/sec, 40000 pending |
| `trace` | TRACE+ | on | none | 4000/frame, 80000/sec, 80000 pending |
| `inspect` | TRACE+ | on | watch context + snapshots | 4000/frame, 80000/sec, 80000 pending |

`verbose` remains an alias for `trace`; `ai` remains an alias for `watch`. `inspect` is
not an alias: it keeps `trace` depth and enables watch enrichment. The `watch` and
`inspect` presets are the standard replay-grade modes for host-side diagnosis.

## API Selection

| API | Use For | Output Shape |
|---|---|---|
| `Log.Info/Debug/Trace(category, message, data)` | Human-readable milestones and state changes. | `<message> key=value ...` |
| `Log.Warn/Error(category, message, data)` | Actionable problems. These auto-add `caller` when absent and `src` when `DebugInfo` can capture it. | `<message> caller=... src=...` |
| `Log.TraceEvent(category, event, phase, data, level?)` | Machine-replay records that need stable tokens. | `event=<event> phase=<phase> traceVersion=1 eventName=<event> phaseName=<phase>` |
| `Log.FlowBegin(kind, category, message, data)` / `Log.FlowEnd(flow, ...)` | Multi-step user flows such as transfers, dialog confirmations, and category changes. | `[flow begin] flow=<kind>#<n>` / `[flow end] flow=<kind>#<n>` |
| `Log.DebugLazy` / `Log.TraceLazy` | Expensive payload or message construction on hot paths. | Same as normal debug/trace after the exact gate passes. |

Never build an expensive payload before the gate. For hot paths use `Log.EnabledFor(level,
category)` or a lazy helper; `Log.IsActive()` is only the coarse active check.

## Output Contract

The raw BetterUI line shape is:

```text
[BUI] <gameMs> sid=<sid> seq=<seq> <LEVEL> <CATEGORY> | <event> [key=value ...] [scene=... view=... flow=... lastAction="..."]
```

The on-disk ESO line is engine-wrapped:

```text
<ISO timestamp> |cff0000Lua Error: [BUI] <gameMs> sid=<sid> seq=<seq> <LEVEL> <CATEGORY> | <event> ...|r
<stack traceback block generated by the throwaway breadcrumb>
```

Host readers must filter `[BUI]`, strip color codes and trailing `|r`, order within a
session by `seq`, and ignore traceback blocks that follow `[BUI]` lines. A `Lua Error:`
line without `[BUI]` is a real game/addon error and its traceback must be retained.

Every line must contain exactly one parse boundary: the first ` | `. Messages, payload
values, and context suffixes must not introduce raw `|`, newlines, or tabs; `Log.lua`,
`Names.FlattenText`, and `InterfaceLog.Flatten` normalize those values. Meta-lines use
`INFO LOG`; budget summaries use `WARN LOG | dropped=<n> reason=rate_limit`.

The monitor reports samples with new `[BUI]` count, level mix, real non-BUI errors,
dropped-record totals, parse-contract violations, BetterUI WARN/ERROR records,
screenshot markers, recent screenshot files, and a final clean/not-clean footer.

## Replay Coverage Expectations

Replay-grade flows should answer these questions from the log alone:

| Flow Area | Required Breadcrumbs |
|---|---|
| User input and keybinds | Which keybind/action was shown, which callback ran, whether it was handled, and why it was blocked or skipped. |
| List and category refreshes | What changed, whether refresh was scheduled/refreshed/skipped, row/update counts, active view/category, and selected-row identity when available. |
| Dialogs | Show request, branch/choice, confirm/cancel/close, stale-target blockers, and restore/cleanup result. |
| Item/currency mutation | Requested operation, item/currency identity summary, amount/count, source/destination, server/protected-action blocker, completion/failure, and follow-up refresh. |
| Settings | Setting key, old/new/default or source where cheap, disabled-state evaluation, and panel/control registration failures. |
| Visual/HUD state | Coalesced threshold/visibility/state changes only; avoid per-frame spam unless TRACE is explicitly needed. |

## Adding Or Changing Builog Records

Use this checklist for every new instrumentation point:

1. Gate hot paths before building strings or payloads. Use `Log.IsActive()` for a cheap
   active check, `Log.EnabledFor(level, category)` for the exact gate, or
   `Log.DebugLazy` / `Log.TraceLazy` when payload construction is expensive.
2. Nil-guard production call sites that may load without diagnostics in standalone tests:
   `local L = BETTERUI.Log; if L then ... end`.
3. Choose an existing `Log.CATEGORY` unless a new category is unavoidable. Current common
   categories are `SCENE`, `LIST`, `NAV`, `KEYBIND`, `FOOTER`, `CATEGORY`, `SEARCH`,
   `SORT`, `BATCH`, `ACTION`, `DIALOG`, `CURRENCY`, `LIFECYCLE`, `SAFE`, `SETTINGS`,
   `CONTROL`, `PERF`, `STATE`, `SCREENSHOT`, and `GENERAL`. Update docs and parse tests
   when the public category set changes.
4. Make the message self-describing without payloads. Prefer `"bank transfer blocked"`
   or `"category changed -> Weapons"`; avoid bare identifier messages such as
   `"transferBlocked"`.
5. Keep payloads small and scalar. Do not log full SavedVars, full item lists, account IDs,
   character IDs, guild IDs, raw item links, or unbounded free text. Use names/describers and
   bounded previews; summarize counts and identities instead of dumping tables.
6. Use `Log.TraceEvent(category, event, phase, data, level)` for machine-replay records.
   Current output includes some legacy lowercase underscore event names such as
   `safe_execute` and `bank.list_refresh`; keep existing event tokens stable unless a
   migration updates source, docs, tests, and monitor expectations together. New event
   families should use dotted domains such as `bank.transfer` or `inventory.category`.
   Phases should be stable tokens such as `requested`, `blocked`, `completed`, or `failed`.
7. Use `Log.FlowBegin` / `Log.FlowEnd` for multi-step user flows. The flow id must appear
   in begin/end records and ride the watch context until the next user action.
8. Preserve replay-critical visibility. User actions, keybind outcomes, list refresh
   decisions, dialog confirmations, transfer/currency outcomes, and blocked reasons should
   remain visible in `watch`/`inspect`, usually at `ACTION`, `STATE`, or `WARN`.
9. Coalesce noisy hot-path records. If a loop can emit many rows per frame, log aggregate
   counts at DEBUG/STATE and reserve TRACE for detailed per-row data.
10. WARN/ERROR records must carry actionable context. Prefer explicit `caller` and let
    `Log.Warn` / `Log.Error` add `src` when possible.
11. Screenshot auto capture must stay opt-in. Do not enable it from regular feature code;
    emit `SCREENSHOT` markers only through `Screenshot.lua`.
12. Do not change the raw line shape unless you update `logging-host-tail-parse.md`, the
    monitor, and `test_log_parse_contract.lua` in the same change.

## Validation Before Commit

For builog changes, run the narrow contract suite first:

```sh
lua tools/tests/test_log.lua
lua tools/tests/test_interface_log.lua
lua tools/tests/test_log_parse_contract.lua
lua tools/tests/test_builog_flow_source.lua
lua tools/tests/test_builog_monitor_source.lua
lua tools/tests/test_watchmode.lua
lua tools/lint/lint_log_messages.lua $(find Modules -name '*.lua')
```

Then run the normal repository checks from `docs/guides/testing-guide.md`. Any change to
`BetterUI.txt`, command names, parser regexes, preset behavior, monitor output, or screenshot
correlation needs a targeted test update plus a docs update in this guide and the playbook.
