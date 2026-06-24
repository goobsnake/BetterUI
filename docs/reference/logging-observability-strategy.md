# BetterUI Logging & Observability Strategy

Status: **approved design, ready to implement.** Produced by a 4-model collaboration (Claude + GPT-5.5 +
Kimi + Gemini 3.1 Pro) across **four adversarial rounds** with ESOUI + BetterUI source evidence. Round
working notes: `docs/tmp/logging-observability-*` (safe to delete once this lands).

## 0. North star & the one mechanism
**Real-time capture during play-testing, monitored LIVE by an AI tailing `live/Logs/Interface.log`, is THE
requirement.** A developer plays the addon while an AI assistant reads the live `[BUI]` stream and explains
what the user did, what the addon did, scene/list/control context, perf warnings, and real Lua errors — and
proposes fixes, **without reading source and without `/reloadui`.**

**There is NO file/SavedVariables export.** The supported handoff is the **live `[BUI]` stream only**, plus
in-memory rings surfaced via slash commands. SavedVariables are excluded from the observability contract
because they only flush on `/reloadui`/logout, which breaks the live loop.

**Mechanism confirmed the only option (do not relitigate).** Retail ESO has no file I/O / socket / streaming
API; `WriteToInterfaceLog` is `nil` in retail (ZOS guards every call with `if WriteToInterfaceLog`,
`esoui/libraries/zo_scene/zo_scene.lua:379`); LibDebugLogger only stores to SavedVars/memory; ESOUI itself
states *"there is currently no way to get the real time."* So the deferred, popup-suppressed `error()` ->
`Interface.log` trick BetterUI already uses is the single viable real-time, externally-tailable path. Each
line costs one deferred error + an engine traceback block — the binding constraint on volume.

## 1. The contract (style guide — enforced over the sweep)
**Message shape:** `<area>: <what happened> [-> <named value>] [from <v>] [via <source>] [reason <r>]` — the
human identifier lives **in the message string** (survives payload-off); `data` keys are supplementary.
Never log a raw index/pointer/token/userdata as the primary id. Maximize information density. Targets:
normal <= ~160 chars, startup/snapshot <= 240, ERROR (with err/caller/src) <= 320.

**Levels:** INFO = milestones; DEBUG = user-action flow + immediate context (names, counts, changed value) +
live input breadcrumbs; TRACE = step-by-step internals (per-row, tokens, raw vars). WARN/ERROR bypass the
category gate -> low-volume, actionable, carry `caller`. Raw/per-row payloads stay TRACE.

**Live user-action breadcrumbs (DEBUG — the spine of the watch stream):**
```
user: pressed -> rightBumper action=categoryNext view=bank
scene: shown -> bank via=interaction flow=bankOpen#12
focus: changed -> "Rubedite Ingot" row=14 list=bank
category: changed -> "Weapons" from="Armor" via=rightBumper
```

**Categories:** keep the set; **add `CONTROL`, `PERF`, and `STATE`** (`STATE` = startup preamble, heartbeat,
periodic snapshots).

**Identifier resolution** (Phase-1 prerequisite — new `Diagnostics/Names.lua`): cheap `Control/Parent/Scene/
Category/Sort/Item/FlattenText/PreviewText`; only behind `EnabledFor` or in WARN/ERROR. Human names; on
failure `<unresolved:type:id>`, never `tostring(userdata)`. *(Must exist before the sweep.)*

**Caller + source location.** Two fields:
- `caller` = explicit cheap tag, **required on WARN/ERROR** (`caller=bank:listRefresh`). Friendly display.
- `src` = `file:line:function`, **auto-stamped on WARN/ERROR only** via `debug.traceback`.

`debug.traceback(message, level)` is **available AND addon-callable** — VALIDATED: BetterUI's own
`Modules/CIM/Core/Diagnostics/DebugCommands.lua:64,68` already guards `if debug and debug.traceback` and calls
`debug.traceback("", 4)` in production. (`debug.getinfo`/`getlocal` are NOT available — rejected.) **Must call
`debug.traceback` SYNCHRONOUSLY at the log call site, before the `zo_callLater` defer** (else the stack points
at the logger, not the caller). Guard it (`if debug and debug.traceback`) with fallback to `caller`-only.
Parse the first app frame outside `Log.lua`/`InterfaceLog.lua`/`DebugInfo.lua`/`zo_callLater`; format
`src=Modules/.../ControlUtils.lua:31:FindControl` (no spaces); cap 12 frames / 1200 chars; **never on
DEBUG/INFO/TRACE hot paths.** `caller`+`src` together = the user's "name the function, file, line."

**Canonical payload keys:** `item= qty= count= from= to= reason= result= caller= src= view= scene= rows=
matches= durationMs= thresholdMs= flow= lastAction=`.

**Before/after:** `WARN GENERAL | findControl miss <userdata>|Foo` -> `WARN CONTROL | control: findControl
missed -> "Foo" under "BUI_BankList" caller=bank:listRefresh src=.../ControlUtils.lua:80:FindControl
attempted=child,ancestorGlobal,global scene=bank view=bank flow=none lastAction="pressed A"`.

## 2. Presets + tier-aware budgets
| Preset | Min level | Payloads | Budget (frame/sec) | Purpose |
|---|---|---|---|---|
| `info` | INFO | off | 8 / 100 | "Is it working?" — FPS-safe live |
| `watch` | DEBUG | on | ~300 / 6000 (calibrated) | **Live AI monitoring** — curated stream (see section 3) |
| `debug` | DEBUG | on | 1000 / 20000 (loose) | broad developer stream, all categories |
| `trace` | TRACE | on | 2000 / 40000 (crash-guard) | "Every step" |
| `inspect` | TRACE | on | 2000 / 40000 (crash-guard) | `watch` enrichment at `trace` depth — richest live-AI stream |

`verbose` -> alias of `trace` (`ai` -> `watch` for one release with a deprecation notice). Maintainer's call:
**ship loose, calibrate in-client.** Safety valves: `/builog cat <CATEGORY> off|on` (WARN/ERROR always pass)
and `/builog capture` burst mode (temporary budget, auto-restore <=15s). `maxPending` is enforced as a hard
deferred-sink backlog cap and exposed in `/builog status`/`/buihealth` stats as `pending`.

## 3. Real-time AI monitoring (the only handoff)
**Live line schema** (logfmt, never JSON): `[BUI] <gameMs> sid=<sid> seq=<seq> <LEVEL> <CATEGORY> | <area>:
<event> [-> <primary>] [key=value ...] scene=<s> view=<v> flow=<f> lastAction=<a>`. `sid` per UI load; `seq`
monotonic in `Log.lua` dispatch; both mandatory when active. Parse boundary = first `|`; `[BUI]` is the
filter; tagged-error tracebacks are ignorable, untagged `Lua Error:` blocks are real.

**`/builog preset watch` — the curated AI stream. Five things make it genuinely ≠ `debug`+heartbeat:**
1. **Per-line context suffix** on EVERY line: `scene=<s> view=<v> flow=<f|none> lastAction=<a|none>` from
   cached logger state (cheap, no UI traversal) — the AI never lacks context. WARN/ERROR always get it.
2. **Startup context preamble** once per load (`INFO STATE | context: startup -> betterui=<v> api=<v>
   preset=watch scene=<s> addons=<n> settings=<summary>` + per-enabled-addon lines, cap 30 then a truncation
   line). The **active-addons list goes to the live stream** (taint/conflict sources) — replaces the old
   SavedVars env block.
3. **Rich periodic state snapshot** (`DEBUG STATE | snapshot scene=bank inventory="window=1 visible=1 ..."
   banking="window=1 visible=1 ..." flow=deposit#48 lastAction="pressed A"`) every ~10s.
   Hidden window providers emit compact `window=1 visible=0` instead of stale singleton state.
   Provider-based + capped; failing providers are pcall-guarded so one bad snapshot source cannot
   break the heartbeat.
4. **Flow envelopes**: `DEBUG ACTION | flow: begin -> deposit#48 kind=deposit item="Rubedite Ingot" qty=5` …
   `flow: end -> deposit#48 result=ok durationMs=42`. Errors inside a flow auto-carry `flow`+`lastAction`.
   Inventory/banking now publish compact watch-visible landmarks for user-action handoffs: primary action
   resolved/invoked, dialog action confirmed/restored/skipped, keybind-group refresh summaries, category/list
   refresh scheduled/refreshed with `updates=`, bank item transfer blocked with `reason=`, and bank currency
   transfer completed/failed.
5. **Curated auto-mute** (the main reason it's its own preset): at DEBUG, enable `STATE,LIFECYCLE,SCENE,NAV,
   CATEGORY,ACTION,CONTROL,SAFE,PERF,SETTINGS`; mute `LIST,SEARCH,SORT,BATCH,FOOTER,KEYBIND`. WARN/ERROR
   always pass; TRACE never passes in `watch`. Override from addon code via
   `WatchMode.SetMutedCategories`.

**Dev controls:** `/builog mark "<text>"` injects a marker (`INFO STATE | watch: mark -> "..."`) so you tell
the AI exactly where a bug hit. `Log.NewFlow(kind,name)` + `Log.SetLastAction(...)` feed flow/context.

**In-memory rings** (live, no file): recent-events ring + error ring; `/builog recent [n]`, `/builog errors
[n]`. **Host tail/parse contract (ship the spec):** filter `[BUI]`, drop tagged tracebacks, keep untagged
real errors, order by `sid`/`seq`, stitch by `flow`, flag schema violations (missing caller/src on WARN/ERROR,
raw userdata, uncapped text), emit a compact timeline — proves the stream is AI-ingestible. Provide a
reference `tail -f | filter` snippet in the playbook.

## 4. New diagnostic capabilities (all stream-only)
Structured **error ring** (route `SafeExecute` through it; `seq,scene,view,flow,lastAction,caller,src,err` +
guarded capped traceback at the protected-call boundary); never suppress *real* errors beyond the popup
policy. **Perf markers** (`Perf.lua`, behind `EnabledFor`, WARN on threshold). **Health `/buihealth`** (sink
availability, popup suppression wanted-vs-current, preset/level/payload/muted-cats, GetStats, scene
registration, ring counts). **Snapshot providers** emit bounded `STATE` lines to the stream (never staged for
file). **Capture mode** `/builog capture start|stop|dump` (bounded temporary preset+budget, auto-stop).

## 5. Phased roadmap (real-time first; file-level; host-validated each slice)
> **Status: phases 1–9 implemented + dual-model-reviewed.** Operator guide:
> [logging-playbook.md](logging-playbook.md). The terse-message sweep (phase 8) covered
> all ~400 sites across every module to zero, enforced by
> `tools/lint/lint_log_messages.lua`. New modules: `Names.lua`, `DebugInfo.lua`,
> `WatchMode.lua`, `Perf.lua` (+ `Log.lua`/`InterfaceLog.lua`/`SceneLog.lua`/`ControlUtils.lua`).

1. **Live schema foundation** — `Log.lua`: `CONTROL`/`PERF`/`STATE` cats; `sid`+`seq`; line format incl.
   context-suffix support; recent ring; `sinkDropped`; schema-version field. `InterfaceLog.lua`: help/status
   -> `off|info|watch|debug|trace|inspect` (inspect = trace verbosity + watch enrichment); budgets; enforced
   `maxPending` sink-backlog cap.
2. **Name + caller/src infra** — new `Names.lua`; `DebugInfo.lua` (`CaptureCallerFrame` via guarded sync
   `debug.traceback`, parse rules, caps); canonical keys; `Log.NewFlow`/`Log.SetLastAction`.
3. **`watch` preset** — curated auto-mute; per-line context suffix; startup preamble (incl. active addons);
   rich state snapshot (provider registry); flow envelopes; `/builog mark`; host tail/parse spec + reference
   snippet.
4. **`ControlUtils` repair** — `FindControl(parent,name,caller)` (back-compat 2-arg); miss WARN -> `CONTROL`
   with name+parent+caller+src+attempted; self-describing resolved/invalidate; once-per-generation.
5. **Scene + nav + input narrative** — `SceneLog` tiering (INFO milestones, DEBUG initiated w/ from->to+reason,
   TRACE full 4-state) + `from/to/reason/sid/seq`; `NavigationState` plain-language; DEBUG
   `category:`/`focus:`/`user:` breadcrumbs at the callers that know labels/input.
6. **Error + health + commands** — error ring; `SafeExecute` routing (+ boundary traceback); `/builog
   recent|errors`, `/buihealth`.
7. **Perf + capture** — `Perf.lua`; instrument hot paths; `/builog capture` + temporary budgets + auto-restore.
8. **Broad ~170-site sweep + enforcement** — WARN/ERROR first -> ACTION/SAFE -> SCENE/LIFECYCLE ->
   CATEGORY/NAV/SORT/SEARCH -> LIST/KEYBIND/FOOTER -> TRACE-only; static check (missing `-> value`, missing
   WARN/ERROR caller, raw `userdata`/`tostring(parent)`/`cacheKey=`).
9. **Docs/playbook** — `Diagnostics/README.md`, `docs/guides/logging-playbook.md` (watch workflow, host
   tail/parse, known limits), command help, close the planning task.

**Already shipped this cycle:** 3-tier `info/debug/trace` presets + tier budgets + reload persistence;
gamepad-safe per-emit popup suppression; global `SceneLog`; `/builog`,`/buiscene`; findControl flood fix.

## 6. Risks & guardrails
Deferred-error cost ceiling (gate hot paths with `EnabledFor`/`*Lazy`; `watch` auto-mutes noise; `src`
traceback only on WARN/ERROR); gamepad popup safety (per-emit suppression re-assert + health check; wrap raise
in pcall); **taint: additive `RegisterCallback`/`ZO_PreHook` only, never wrap `SCENE_MANAGER`/protected fns**;
inert-when-off (no resolver/payload/traceback work before gates except WARN/ERROR); privacy (no account/char/
guild ids, no full SavedVars, search -> 32-char preview + `searchLen`, item names ok / links no, free text
flattened + capped); `trace`/loose-budget crash-safety (hard rate limits + category mute + capture-burst;
WARN/ERROR never TRACE).

## 7. Open calibration (in-client)
Loose `watch`/`debug`/`trace` budgets ship per maintainer intent; one in-client play-test pass (with `/builog
mark` + an AI tailing the stream) sets the final frame/sec numbers vs the real crawl threshold. Round notes:
GPT-5.5 favored conservative (`trace` 80/1000); Kimi/GPT-5.5 proposed `watch` ~30/600.
