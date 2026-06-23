# BetterUI logging playbook

How to capture, read, and diagnose with BetterUI's real-time logging. The whole point:
turn on logging, play, and have a human **or an AI** read the live stream out of the
game's `Interface.log` while you reproduce an issue — no `/reloadui`, no SavedVars export.

- Design: [logging-observability-strategy.md](logging-observability-strategy.md)
- Host tail/parse contract: [logging-host-tail-parse.md](logging-host-tail-parse.md)
- AI live-monitor skill (timed back-and-forth play-test): [tools/builog-monitor/SKILL.md](../../tools/builog-monitor/SKILL.md), driven by [tools/builog-monitor/monitor.sh](../../tools/builog-monitor/monitor.sh)
- On-disk path of the live log: see the `interface-log-location` memory (it's outside the
  MCP file roots — read it with Bash `grep`/`tail`).

## Quick start

```
/builog on                  -- start streaming [BUI] breadcrumbs to Interface.log
/builog preset watch        -- the curated live-AI stream (recommended while play-testing)
... reproduce the issue ...
/buihealth                  -- one-line health: preset, errors, file-sink budget, scene/watch state
/builog errors              -- dump the recent WARN/ERROR ring in chat
/builog off                 -- stop + restore error popups
```

Then tail the clean stream on the host:

```sh
grep -a '\[BUI\]' "<ESO live>/Logs/Interface.log"
```

## Presets (`/builog preset <name>`)

Presets are min-level gates layered over the low-level knobs. Pick by intent:

| Preset | Level | Payloads | Budget (frame/sec) | Use |
|---|---|---|---|---|
| `off`   | —      | —   | 0      | stop logging, restore popups |
| `info`  | INFO+  | off | 8/100  | "is it working?" — milestones + problems. **FPS-safe for live play.** |
| `watch` | DEBUG+ | on  | 300/6000 | the curated **live-AI** stream (preamble, per-line context, snapshots, flows) |
| `debug` | DEBUG+ | on  | 1000/20000 | "what is it doing?" — the everyday user-action flow |
| `trace` | TRACE+ | on  | 2000/40000 | every step; loosest budget (only guards against a runaway hot loop) |
| `inspect` | TRACE+ | on | 2000/40000 | **`watch` enrichment at `trace` depth** — every step PLUS per-line context, state snapshots, preamble, auto-mute. The richest live-AI stream. |

`ai` is a deprecated alias for `watch`; `verbose` for `trace`. `inspect` is a DISTINCT preset
(not an alias — `GetPreset()` returns `inspect`): use it when `watch` (DEBUG+) isn't deep
enough and you want every TRACE step still wrapped in the watch context. Overflow past a budget
is dropped and coalesced into a `WARN LOG | dropped=N reason=rate_limit` line.

## Why `watch` (vs `debug` + a heartbeat)

`watch` is `debug` plus five things an AI tailing the log needs:

1. **Per-line context suffix** — every line self-anchors with `scene= view= flow=
   lastAction=".."`, so one line tells you where the player is and what they last did.
2. **Startup preamble** — a `STATE | watch session started` record with schema/api/world/
   player/zone + the enabled-addon list, so an AI joining mid-stream can anchor.
3. **Periodic state snapshot** — a `STATE | snapshot` heartbeat (~10s) of registered
   providers; a long gap while the client is up suggests a freeze.
4. **Flow envelopes** — `[flow begin]` / `[flow end]` with `flow=<kind>#<n>` bracket one
   multi-step operation; everything sharing that id is correlated.
5. **Curated auto-mute** — categories that are noise for AI monitoring can be silenced in
   watch only (empty by default; calibrate in-client via `WatchMode.SetMutedCategories`).

## All commands

`/builog`:

| Command | Does |
|---|---|
| `on` / `off` | start / stop streaming (off restores error popups) |
| `preset <name>` | apply a preset (off\|info\|watch\|debug\|trace\|inspect) |
| `level <lvl>` | set just the min level (trace\|debug\|info\|warn\|error) |
| `chat on\|off` | also surface INFO/WARN/ERROR to chat (file logging unchanged) |
| `popups on\|off` | show / suppress the native Lua-error popup (errors still log) |
| `mark <text>` | drop a `STATE | mark: <text>` annotation into the live stream |
| `recent [n]` | dump the last n records (any level) in chat |
| `errors [n]` | dump the last n WARN/ERROR records in chat |
| `capture [secs]` | raise to TRACE for a bounded window (default 5s, 1–60), then auto-revert |
| `snapshot` | emit one STATE snapshot now |
| `test` / `status` | write test breadcrumbs / print current state |

`/buihealth` — one-shot health summary (preset, active, sid, schema, error count, file-sink
scheduled/dropped/budget, sceneLog + watch state).

`/buiscene` — current scene + the recent scene-transition ring.

## Message contract (what a good log line looks like)

```
<area>: <what happened> [-> <named value>]
```

- **Self-describing in the MESSAGE.** Under `debug`/`info` the payload table is dropped, so
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
local flow = BETTERUI.Log.FlowBegin("deposit", BETTERUI.Log.CATEGORY.ACTION, "deposit 50g")
... steps (their watch lines carry flow=deposit#N) ...
BETTERUI.Log.FlowEnd(flow, BETTERUI.Log.CATEGORY.ACTION, "deposit done")
```

Every logging call is pcall-guarded and inert when off — a log call must never raise and
never measurably cost a player with logging disabled.

## On-disk line shape (recap)

```
<ISO ts> |cff0000Lua Error: [BUI] <gameMs> sid=<sid> seq=<seq> <LEVEL> <CATEGORY> | <event> [k=v ...] [scene= view= flow= lastAction=".."]|r
```

Filter to `[BUI]`; order by `seq`; a `Lua Error:` line WITHOUT `[BUI]` is a real game error
(keep its traceback). Full parse recipe in
[logging-host-tail-parse.md](logging-host-tail-parse.md).
