# Builog Developer Guide

Developer standards for BetterUI's live diagnostics stream. Use this when changing
`BETTERUI.Log`, `/builog`, watch/inspect instrumentation, the host monitor, or any
feature code that emits diagnostics.

## Sources Of Truth

- Runtime formatter: `Modules/CIM/Core/Diagnostics/Log.lua`
- Domain-specific describers: `Modules/CIM/Core/Diagnostics/DomainLog.lua`
- Expectation watchdog: `Modules/CIM/Core/Diagnostics/Watchdog.lua`
- File transport: `Modules/CIM/Core/Diagnostics/InterfaceLog.lua`
- Slash commands: `Modules/CIM/Core/Diagnostics/BuilogCommands.lua`
- Watch/inspect enrichment: `Modules/CIM/Core/Diagnostics/WatchMode.lua`
- Screenshot correlation: `Modules/CIM/Core/Diagnostics/Screenshot.lua`
- Host parser contract: `docs/reference/logging-host-tail-parse.md`
- Operator workflow: `docs/reference/logging-playbook.md`
- Monitor tool: `tools/builog-monitor/monitor.sh` and `tools/builog-monitor/SKILL.md`
- Contract tests: `tools/tests/test_log_parse_contract.lua`, `test_builog_flow_source.lua`,
  `test_builog_monitor_source.lua`, `test_input_anchor.lua`, `test_watchdog.lua`,
  `test_resource_orbs_trace_source.lua`, `test_vendor_trace_source.lua`,
  `test_trading_house_trace_source.lua`, `test_writs_trace_source.lua`, `test_log.lua`,
  `test_interface_log.lua`, and `test_watchmode.lua`

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
| `chat on|off` | Compatibility commands. `chat on` reports that chat surfacing is unsupported and leaves builog file-only; `chat off` keeps chat sinks disabled. |
| `popups on|off` | Compatibility commands. Generated breadcrumb popups remain suppressed while builog is enabled; `popups off` tells the user to use `/builog off` to restore player-visible error popups. |
| `mark <text>` | Emit `STATE | mark: <text>` for host correlation. |
| `recent [n]` / `errors [n]` | Dump retained in-memory records to chat. |
| `capture [secs]` | Temporarily switch to `trace`, then revert. Default 5s, capped 1-60s. |
| `screenshot [label]` | Request a screenshot and emit request/saved markers. |
| `screenshot auto off|error|warn` | Persisted opt-in auto capture for current play-test windows. |
| `privacy on|off` | Persisted privacy mode. Default is off. When on, watch/inspect omit player, zone, addon names, item names, and absolute currency balances while keeping replay-safe ids, counts, and deltas. `lastAction` is capped at 48 characters in all modes. |
| `snapshot` | Emit one `STATE | snapshot` immediately. |
| `report` | Emit one `INFO STATE | event=session phase=report` record with file-sink counters, error counts, watchdog anomaly totals, unresolved flow count, and screenshot counters. Use this as the end anchor for host digests. |
| `check` / `test` | Emit diagnostic breadcrumbs; `test` is a compatibility alias. If logging was off, this command enables the session stream and leaves it on so the breadcrumbs reach `Interface.log`. |
| `status` | Print preset, payload, privacy state, active sink budget, counters, and screenshot state. |

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

Privacy mode is independent of presets and persists as `interfaceLogPrivacy`. It is restored
when `RuntimeSetup.Apply` reapplies interface-log settings. With privacy on, `WatchMode`
preambles omit `player` and `zone`, active-addons records expose only `count`,
`Log.DescribeItem` omits `name=`, and banking/vendor currency snapshots emit delta fields
rather than absolute balances. `lastAction` context is capped at 48 characters in all modes.

## API Selection

| API | Use For | Output Shape |
|---|---|---|
| `Log.Info/Debug/Trace(category, message, data)` | Human-readable milestones and state changes. | `<message> key=value ...` |
| `Log.Warn/Error(category, message, data)` | Actionable problems. These auto-add `caller` when absent and `src` when `DebugInfo` can capture it. | `<message> caller=... src=...` |
| `Log.TraceEvent(category, event, phase, data, level?)` | Machine-replay records that need stable tokens. | `event=<event> phase=<phase> traceVersion=1 eventName=<event> phaseName=<phase>` |
| `Log.FlowBegin(kind, category, message, data)` / `Log.FlowEnd(flow, ...)` | Multi-step user flows such as transfers, dialog confirmations, and category changes. | `[flow begin] flow=<kind>#<n>` / `[flow end] flow=<kind>#<n>` |
| `Watchdog.Expect(kind, key, timeoutMs, context)` / `Watchdog.Resolve(kind, key, outcome)` | Expected follow-ups that should surface as WARN anomalies if they do not arrive. `Resolve` records nothing; the normal outcome record remains the source of truth. | `WARN STATE | event=anomaly phase=detected kind=<kind> key=<key> ageMs=<ms> timeoutMs=<ms>` on timeout. |
| `Log.DebugLazy` / `Log.TraceLazy` | Expensive payload or message construction on hot paths. | Same as normal debug/trace after the exact gate passes. |
| `Watch.RegisterViewScene(prefix, sceneName)` / `Watch.ClearView(prefix)` | Namespaced watch `view=` labels that only apply inside their owning scene. Register every module prefix before calling `Watch.SetView(prefix .. ".<state>")`. | Prevents stale `view=` context from leaking across banking, inventory, vendor, trading-house, companion, or writ scenes. |

Never build an expensive payload before the gate. For hot paths use `Log.EnabledFor(level,
category)` or a lazy helper; `Log.IsActive()` is only the coarse active check.

`Watchdog.Expect` is also gated: do not create expectations for records that were dropped by
the exact log gate. Flow envelopes use the DEBUG/category gate before expecting `kind="flow"`.
Call-site expectations use stable keys (`bank.transfer`, `th.op`, `list.refresh`) and must
resolve every normal, failed, stale, cancelled, or coalesced terminal path so a module-level
WARN is not followed by a duplicate watchdog anomaly. Expectations are capped at 64 live
records; overflow emits `event=anomaly phase=overflow` and drops the oldest pending key.

## Event Schema

`Log.SCHEMA` versions the physical line shape. `Log.EVENT_SCHEMA` versions event names,
phase vocabulary, and category taxonomy. Watch/inspect preambles emit both `schema=` and
`eventSchema=`; host consumers should key event-token compatibility from the preamble.
`TraceEvent` also emits `traceVersion=<EVENT_SCHEMA>` for legacy consumers that inspect
individual event records.

Canonical phase tokens are:

`requested`, `begin`, `end`, `completed`, `confirmed`, `fired`, `settled`, `blocked`,
`failed`, `skipped`, `pending`, `changed`, `snapshot`, `queued`, `executed`, `expired`,
`detected`, `overflow`, `report`, `step`, and `abort`.

Migration map for old literals: `setup_before` -> `begin`, `setup_after` -> `end`,
`finish_before` -> `begin` on `*.finish`, `finish_after` -> `end` on `*.finish`,
`before_add`/`after_add` -> `begin`/`end` on `*.keybind_add`,
`before_remove`/`after_remove` -> `begin`/`end` on `*.keybind_remove`,
`request_failed` -> `failed`, `denied` -> `blocked`, and `start` -> `begin`.
The static lint still permits a bounded set of legacy phase literals such as
`before`, `after`, `confirm`, `refresh_decision`, `release_dialog`, and
`waiting_for_close`; those emit lint warnings and should migrate only with their owning
module's event-family contract.

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
`Names.FlattenText`, and `InterfaceLog.Flatten` normalize those values. Lines capped at
the file-sink byte limit carry `truncated=1` at the end. Meta-lines use `INFO LOG`;
budget summaries use `WARN LOG | dropped=<n> reason=rate_limit` or
`WARN LOG | dropped=<n> reason=priority_rate_limit`. Priority lines are WARN/ERROR or
the replay-critical `STATE`, `SCENE`, `LIFECYCLE`, `ACTION`, `TRANSFER`, `DIALOG`, and
`KEYBIND` categories; they get the expanded per-frame/per-second cap but can still be
dropped under sustained pressure, which is why the priority reason is distinct.

The monitor reports timed samples with new `[BUI]` count, level mix, real non-BUI errors,
dropped-record totals, parse-contract violations, BetterUI WARN/ERROR records,
screenshot markers, recent screenshot files, and a final clean/not-clean footer. For an
already-captured window, use `tools/builog-monitor/monitor.sh digest --last <n> [--jsonl]`
to group by `flow`/`opId`/`batchId`, surface unresolved timelines, and emit JSONL records
with `ts`, `gameMs`, `sid`, `seq`, `level`, `category`, `event`, `phase`, `kv`, and
`context`.

## Replay Coverage Expectations

Replay-grade flows should answer these questions from the log alone:

| Flow Area | Required Breadcrumbs |
|---|---|
| User input and keybinds | `event=input.keybind phase=fired` as the canonical cause anchor with `module`, `action`, `keybind`, `gamepad`, and optional `binding`; module-specific keybind records only add outcome/detail fields. |
| List and category refreshes | What changed, whether refresh was scheduled/refreshed/skipped, row/update counts, active view/category, and selected-row identity when available. |
| Dialogs | Show request, branch/choice, confirm/cancel/close, stale-target blockers, and restore/cleanup result. |
| GeneralInterface dialogs | Delete-dialog `requested`/`confirmed`/`skipped` records with bounded item identity and close/cleanup result. |
| Item/currency mutation | Requested operation, item/currency identity summary, amount/count, source/destination, server/protected-action blocker, completion/failure, and follow-up refresh. |
| Vendor / fence | `vendor.scene` begin/end, `vendor.mode` changed, user-fired `vendor.keybind` begin/end/skipped/failed, and buy/sell/repair outcomes with currency deltas in privacy mode. |
| Trading House | `th.mode` changed, search requested/completed with a shared operation id, and one aggregate `th.list` end count per Browse/Sell/Listings rebuild. |
| Writs | Coalesced `writs.state` changed records from refresh, show-for-craft-type, craft-complete refresh, and station-close paths; never per-objective spam. |
| Settings | Setting key, old/new/default or source where cheap, disabled-state evaluation, and panel/control registration failures. |
| Anomaly watchdog | `WARN STATE | event=anomaly phase=detected` or `phase=overflow` when expected flow/list/operation follow-ups do not resolve. |
| Combat/HUD state | Coalesced `resource_orbs.ultimate`, `resource_orbs.bar_swap`, `resource_orbs.cast`, and `resource_orbs.combat` transitions plus snapshot `resourceOrbs` fields; never per-frame spam. |
| Nameplates | Coalesced `nameplates.visibility` and `nameplates.refresh` records with rule/reason/counts plus snapshot active-rule counts. |
| Session report | `/builog report` emits `INFO STATE | event=session phase=report` with sink, error, watchdog, unresolved-flow, and screenshot counters for host digest closeout. |

## Adding Or Changing Builog Records

Use this checklist for every new instrumentation point:

1. Gate hot paths before building strings or payloads. Use `Log.IsActive()` for a cheap
   active check, `Log.EnabledFor(level, category)` for the exact gate, or
   `Log.DebugLazy` / `Log.TraceLazy` when payload construction is expensive.
2. Nil-guard production call sites that may load without diagnostics in standalone tests:
   `local L = BETTERUI.Log; if L then ... end`.
3. Choose an existing `Log.CATEGORY` unless a new category is unavoidable. Current common
   categories are `SCENE`, `LIST`, `NAV`, `KEYBIND`, `FOOTER`, `CATEGORY`, `SEARCH`,
   `SORT`, `BATCH`, `ACTION`, `TRANSFER`, `DIALOG`, `CURRENCY`, `LIFECYCLE`, `SAFE`, `SETTINGS`,
   `CONTROL`, `PERF`, `STATE`, `SCREENSHOT`, and `GENERAL`. Update docs and parse tests
   when the public category set changes.
4. Make the message self-describing without payloads. Prefer `"bank transfer blocked"`
   or `"category changed -> Weapons"`; avoid bare identifier messages such as
   `"transferBlocked"`.
5. Keep payloads small and scalar. Do not log full SavedVars, full item lists, account IDs,
   character IDs, guild IDs, raw item links, or unbounded free text. Use names/describers and
   bounded previews; summarize counts and identities instead of dumping tables.
   Honor privacy mode for new records: no player, zone, addon, item-name, or absolute-currency
   fields when `Log.GetPrivacyMode()` is true; prefer stable ids, counts, and deltas.
6. Use `Log.TraceEvent(category, event, phase, data, level)` for machine-replay records.
   Current output includes some legacy lowercase underscore event names such as
   `safe_execute` and `bank.list_refresh`; keep existing event tokens stable unless a
   migration updates source, docs, tests, and monitor expectations together. New event
   families should use dotted domains such as `bank.transfer` or `inventory.category`.
   Phases should use the `EVENT_SCHEMA` vocabulary above.
7. Use `Log.FlowBegin` / `Log.FlowEnd` for multi-step user flows. The flow id must appear
   in begin/end records and ride the watch context until the next user action.
8. Preserve replay-critical visibility. User actions, keybind outcomes, list refresh
   decisions, dialog confirmations, transfer/currency outcomes, and blocked reasons should
   remain visible in `watch`/`inspect`, usually at `ACTION`, `TRANSFER`, `STATE`, or `WARN`.
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
lua tools/tests/test_input_anchor.lua
lua tools/tests/test_watchdog.lua
lua tools/tests/test_resource_orbs_trace_source.lua
lua tools/tests/test_watchmode.lua
lua tools/tests/test_vendor_trace_source.lua
lua tools/tests/test_trading_house_trace_source.lua
lua tools/tests/test_writs_trace_source.lua
lua tools/lint/lint_log_messages.lua $(find Modules -name '*.lua')
```

Then run the normal repository checks from `docs/guides/testing-guide.md`. Any change to
`BetterUI.txt`, command names, parser regexes, preset behavior, monitor output, or screenshot
correlation needs a targeted test update plus a docs update in this guide and the playbook.
