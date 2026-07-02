# BetterUI logging playbook

How to capture, read, and diagnose with BetterUI's real-time logging. The whole point:
turn on logging, play, and have a human **or an AI** read the live stream out of the
game's `Interface.log` while you reproduce an issue — no `/reloadui`, no SavedVars export.

- Design: [logging-observability-strategy.md](logging-observability-strategy.md)
- Developer standards: [builog-developer-guide.md](builog-developer-guide.md)
- Host tail/parse contract: [logging-host-tail-parse.md](logging-host-tail-parse.md)
- AI live-monitor skill (timed back-and-forth play-test): [tools/builog-monitor/SKILL.md](../../tools/builog-monitor/SKILL.md), driven by [tools/builog-monitor/monitor.sh](../../tools/builog-monitor/monitor.sh)
- On-disk path of the live log: see the `interface-log-location` memory (it's outside the
  MCP file roots — read it with Bash `grep`/`tail`).

## Quick start

```
/builog on                  -- start streaming [BUI] breadcrumbs to Interface.log
/builog preset watch        -- the AI-enriched live stream (recommended while play-testing)
/builog privacy on          -- optional: redact player/zone/addon names, item names, and absolute balances
/builog screenshot auto warn -- optional: capture distinct visual context on WARN/ERROR
... reproduce the issue ...
/builog report              -- emit an end-of-session INFO STATE report anchor
/buihealth                  -- one-line health: preset, errors, file-sink budget, scene/watch state
/builog errors              -- dump the recent WARN/ERROR ring in chat
/builog off                 -- stop + restore error popups
```

Then tail the clean stream on the host:

```sh
grep -a '\[BUI\]' "<ESO live>/Logs/interface.log"
```

For a completed or long window, digest first and drill into raw lines second:

```sh
tools/builog-monitor/monitor.sh digest --last 2000 "<ESO live>/Logs/interface.log"
tools/builog-monitor/monitor.sh digest --last 2000 --jsonl "<ESO live>/Logs/interface.log"
```

The digest groups by `flow=`, then `opId=`, then `batchId=`, highlights unresolved
timelines, and separates anomalies, BUI WARN/ERROR records, real non-BUI Lua errors,
drop summaries, screenshot markers, preamble data, and `/builog report` anchors.

## Presets (`/builog preset <name>`)

Presets are min-level gates layered over the low-level knobs. Pick by intent:

| Preset | Level | Payloads | Budget (frame/sec) | Use |
|---|---|---|---|---|
| `off`   | —      | —   | 0      | stop logging, restore popups |
| `info`  | INFO+  | off | 8/100  | "is it working?" — milestones + problems. **FPS-safe for live play.** |
| `watch` | DEBUG+ | on  | 2000/40000 | the AI-enriched **live-AI** stream (preamble, per-line context, snapshots, flows) |
| `debug` | DEBUG+ | on  | 2000/40000 | "what is it doing?" — the everyday user-action flow |
| `trace` | TRACE+ | on  | 4000/80000 | every step; loosest budget (only guards against a runaway hot loop) |
| `inspect` | TRACE+ | on | 4000/80000 | **`watch` enrichment at `trace` depth** — every step PLUS per-line context, state snapshots, and preamble. The richest live-AI stream. |

`ai` is a deprecated alias for `watch`; `verbose` for `trace`. `inspect` is a DISTINCT preset
(not an alias — `GetPreset()` returns `inspect`): use it when `watch` (DEBUG+) isn't deep
enough and you want every TRACE step still wrapped in the watch context. Overflow past a budget
is dropped and coalesced into a `WARN LOG | dropped=N reason=rate_limit` line; replay-critical
priority lines use the same summary shape with `reason=priority_rate_limit`.

`/builog privacy on|off` is a persisted switch layered over every preset. It defaults off. When
on, watch/inspect preambles omit player and zone, active-addons records keep only the addon
count, item descriptions omit `name=`, banking/vendor currency records expose delta fields
instead of absolute balances. `lastAction` context/snapshots are capped at 48 characters in
all modes.

## Why `watch` (vs `debug` + a heartbeat)

`watch` is `debug` plus five things an AI tailing the log needs:

1. **Per-line context suffix** — every `watch` and `inspect` line self-anchors with
   `scene= view= flow= lastAction=".."`, so one line tells you where the player is and
   what they last did.
2. **Startup preamble** — a `STATE | diagnostic session started -- live Interface.log stream` record with schema/eventSchema/api/world/
   player/zone + the enabled-addon list, so an AI joining mid-stream can anchor. With privacy
   mode on, `player`, `zone`, and addon names are omitted; the addon count remains.
3. **Periodic state snapshot** — a `STATE | snapshot` heartbeat (~10s) of registered
   providers; built-ins include `visible=0/1`, inventory/banking rows, category, pending
   transfer, and keybind-group state. Hidden windows report compact `window=1 visible=0`
   so stale singleton state is not mistaken for the active UI. A long gap while the client
   is up suggests a freeze.
4. **Flow envelopes** — `[flow begin]` / `[flow end]` with `flow=<kind>#<n>` bracket one
   multi-step operation; everything sharing that id is correlated. Inventory/banking action flows also emit
   visible handoff lines such as `inventory primary action resolved`, `inventory primary action invoked`,
   `inventory dialog action confirmed`, `bank primary transfer invoked` (`TRANSFER`),
   `bank action dialog shown`, and `bank currency transfer completed/failed` (`TRANSFER`).
5. **Anomaly watchdog** — expected follow-ups that do not arrive emit
   `WARN STATE | event=anomaly phase=detected` with `kind`, `key`, `ageMs`, and `timeoutMs`.
   These records point to missing flow ends, unresolved bank transfers, Trading House
   operations, or list refreshes. `phase=overflow` means the 64-live-expectation cap was hit.
6. **Replay-grade category policy** — `watch` and `inspect` default to no muted
   categories, so sort/search/list/keybind/currency flows remain visible to an AI
   tailing the stream. Temporary mutes are still available in-client via
   `WatchMode.SetMutedCategories`; WARN/ERROR always pass.

## Flow landmarks to expect

When play-testing inventory or banking, the live stream should show the cause-and-effect chain, not just the
final error. These compact lines remain visible in `watch`/`inspect`; if the user temporarily mutes noisy
categories, `ACTION`, `TRANSFER`, and `STATE` landmarks should still preserve the flow:

| User-visible flow | Expected landmarks |
|---|---|
| Keybind strip did not update | `STATE | inventory keybind groups refreshed` or `STATE | bank keybind groups refreshed/removed` with mode/list context. |
| Deposit/withdraw item did not refresh list | `TRANSFER | bank primary transfer invoked`, a `TRANSFER` flow end, then `STATE | bank list refresh scheduled/refreshed` or `STATE | inventory category list refresh scheduled/refreshed updates=<n>`. |
| Junk toggle did not update category | `ACTION | inventory dialog action confirmed` or junk flow begin/end, then `STATE | inventory category list refresh scheduled/refreshed updates=<n>`. |
| Currency transfer failed or seemed ignored | `TRANSFER | bank currency transfer completed` or `TRANSFER | bank currency transfer failed` with `amount`, `currency`, and `reason`. |
| A setting/action looked enabled but did nothing | `ACTION` lines should show the resolved action and invocation; `WARN` lines should carry `caller`/`src` when a dependency or protected action blocks it. |
| Vendor action or mode looked wrong | Start with the canonical `KEYBIND | event=input.keybind phase=fired` cause anchor, then use `KEYBIND | event=vendor.keybind`, `SCENE | event=vendor.scene`, and `NAV | event=vendor.mode` for vendor-specific outcome, scene, and mode detail. |
| Trading House list/search looked stale | Search records should share an operation id, `NAV | event=th.mode` should show mode changes, and each Browse/Sell/Listings rebuild should end with one aggregate `LIST | event=th.list` count. |
| Writ panel looked stale | `STATE | event=writs.state` should appear after active-writ refresh, show-for-craft-type, immediate craft-complete refresh, and station close. |

If the user reports one of these flows and the corresponding landmark is absent near the marked `seq`, treat
that absence as an instrumentation or control-flow bug.

## All commands

`/builog`:

| Command | Does |
|---|---|
| `on` / `off` | start / stop streaming (off restores error popups); prefer named presets over plain `on` for bounded budgets |
| `preset <name>` | apply a preset (off\|info\|watch\|debug\|trace\|inspect) |
| `level <lvl>` | set just the min level (trace\|debug\|info\|warn\|error) |
| `chat on\|off` | compatibility commands; `chat on` reports unsupported and leaves builog file-only, while `chat off` keeps chat sinks disabled |
| `popups on\|off` | compatibility commands; generated breadcrumb popups remain suppressed while builog is enabled, and `popups off` points to `/builog off` for restoration |
| `mark <text>` | drop a `STATE | mark: <text>` annotation into the live stream |
| `recent [n]` | dump the last n records (any level) in chat |
| `errors [n]` | dump the last n WARN/ERROR records in chat |
| `capture [secs]` | raise to TRACE for a bounded window (default 5s, 1–60), then auto-revert |
| `screenshot [label]` | call ESO `TakeScreenshot()` and emit request/saved markers for host correlation |
| `screenshot auto off\|error\|warn` | persisted opt-in auto capture: off, ERROR only, or WARN+ERROR with duplicate-aware per-issue throttling |
| `privacy on\|off` | persisted privacy mode; on redacts player/zone/addon names, item names, and absolute currency balances; `lastAction` is capped at 48 chars in all modes |
| `snapshot` | emit one STATE snapshot now |
| `report` | emit one `INFO STATE | event=session phase=report` anchor with sink, error, watchdog, unresolved-flow, and screenshot counters |
| `check` / `test` | write diagnostic breadcrumbs; if logging was off, leaves the session stream on so the breadcrumbs reach `Interface.log` |
| `status` | print current preset, payload, privacy, sink budget, counters, and screenshot state |

`/buihealth` — one-shot health summary (preset, active, sid, schema, error count, file-sink
scheduled/pending/dropped/budget, sceneLog + watch state).

`/buiscene` — current scene + the recent scene-transition ring.

## Message contract (what a good log line looks like)

```
<area>: <what happened> [-> <named value>]
```

- **Self-describing in the MESSAGE.** Under `info` the payload table is dropped, so
  the message must stand alone: `"category change started -> index 3"`, not
  `"startCategoryChange"`. The static lint enforces this:

  ```sh
  lua tools/lint/lint_log_messages.lua $(find Modules -name '*.lua')
  ```

  It flags bare-identifier messages (function-name-style) and exits non-zero in CI.
- **Resolve names, not tokens.** Use `BETTERUI.CIM.Names` (Control/Parent/Scene/Category/
  Item/...) so a line carries `BUI_BankList`, not `table: 0x...`.
- **WARN/ERROR carry where.** A miss/fault names the control + parent and a `src=
  file:line:function` captured via the guarded `debug.traceback` path (DebugInfo).

## Adding instrumentation

```lua
-- cheap gate first on hot paths (builds nothing when off):
if BETTERUI.Log and BETTERUI.Log.IsActive() then
    BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIST, "list refreshed -> " .. n .. " rows", { rows = n })
end

-- exact gate when building a payload is expensive:
local L = BETTERUI.Log
if L and L.EnabledFor and L.EnabledFor(L.LEVEL.TRACE, L.CATEGORY.SEARCH) then ... end

-- time a hot span (inert when PERF logging is off):
local p = BETTERUI.CIM.Perf and BETTERUI.CIM.Perf.Begin("applyTextFilter")
... work ...
if p then BETTERUI.CIM.Perf.End(p, { rows = n }) end

-- correlate a multi-step operation:
local flow = BETTERUI.Log.FlowBegin("deposit", BETTERUI.Log.CATEGORY.TRANSFER, "deposit 50g")
... steps (their watch lines carry flow=deposit#N) ...
BETTERUI.Log.FlowEnd(flow, BETTERUI.Log.CATEGORY.TRANSFER, "deposit done")
```

Every logging call is pcall-guarded and inert when off — a log call must never raise and
never measurably cost a player with logging disabled.

## On-disk line shape (recap)

```
<ISO ts> |cff0000Lua Error: [BUI] <gameMs> sid=<sid> seq=<seq> <LEVEL> <CATEGORY> | <event> [k=v ...] [scene= view= flow= lastAction=".."]|r
```

Filter to `[BUI]`; order by `seq`; a `Lua Error:` line WITHOUT `[BUI]` is a real game error
(keep its traceback). A trailing `truncated=1` means the line was capped and later payload
fields may be incomplete. Full parse recipe in
[logging-host-tail-parse.md](logging-host-tail-parse.md).

## Screenshot correlation

`/builog screenshot [label]`, opt-in auto capture, and user/client screenshots observed
through ESO's saved event emit `INFO SCREENSHOT` records:

- `screenshot request ... status=pending|suppressed|unavailable`
- `screenshot requested ... status=requested|failed|expired`
- `screenshot saved ... directory=<dir> filename=<file> status=saved`

The saved marker is authoritative because ESO fires `EVENT_SCREENSHOT_SAVED(directory,
filename)`. BetterUI-requested markers carry a correlation `id`, `source="user"|"auto"`,
`requested=true`, and `correlation="fifo"` or `correlation="expired_fifo"` because ESO
does not provide a request id in the saved event. `expired_fifo` means the save arrived
after BetterUI's pending TTL, but close enough to preserve the recently expired request's
`source`/`trigger` instead of mislabeling it as a fresh external screenshot. Saves after
that short grace window are treated as external. While a
BetterUI request is pending, ESO's saved event cannot prove whether the next saved file
came from that request or a native screenshot key, so treat FIFO attribution as best
effort. Unrequested saved events with no pending or recently expired BetterUI request are
logged as `source="user" trigger="external" requested=false` so a later investigation can see
what happened around a player-initiated screenshot. If a host process joins late or misses the
saved marker, match the marker's ISO timestamp to the newest file mtime in the screenshots
folder. Local default:
`/mnt/steamstorage/SteamLibrary/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live/Screenshots`.
Remote default: `smb://goobers/elder%20scrolls%20online/live/Screenshots`. The bundled
monitor accepts an optional fourth argument or `BUILOG_SCREENSHOT_DIR` for that folder.
Remote screenshot access uses the same SMB/GVFS connection as the remote `interface.log`;
mount `smb://goobers/elder%20scrolls%20online` first, then use the mounted
`.../live/Screenshots` path if the `remote` alias cannot resolve it automatically.
Auto capture and user/client saved-event markers can include private UI/chat/account
context through the screenshot file itself; leave auto capture `off` except during the
current play-test window.
