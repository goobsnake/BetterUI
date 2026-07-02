# Diagnostics

Debugging, profiling, safety wrappers, real-time logging, and feature controls.

Files:
- `Log.lua` — `BETTERUI.Log` unified logging facade: levels
  (`TRACE<DEBUG<INFO<WARN<ERROR`), categories
  (`SCENE/LIST/NAV/KEYBIND/FOOTER/CATEGORY/SEARCH/SORT/BATCH/ACTION/TRANSFER/DIALOG/CURRENCY/LIFECYCLE/SAFE/SETTINGS/CONTROL/PERF/STATE/SCREENSHOT/GENERAL/LOG`),
  and per-level file/chat sinks. Inert until enabled, so normal players pay
  nothing. Named presets via `Log.ApplyPreset("off"|"info"|"watch"|"debug"|"trace"|"inspect")` (also
  `/builog preset`) layer over the low-level knobs; `Log.SetPayloadCapture`
  toggles whether `data` payloads render. Nil-guard every call site
  (`if BETTERUI.Log then ... end`); on hot paths gate on
  `BETTERUI.Log.IsActive()`, or use `Log.EnabledFor(level, category)` (the exact
  sink-aware pre-check) / the lazy `Log.WriteLazy|DebugLazy|TraceLazy(.., dataFn)`
  builders so no payload is constructed when the record would be dropped.
- `DomainLog.lua` — domain-specific diagnostics describers for items, keybind
  descriptors, list selections, and currency-location lookups. `Log.lua` exposes
  thin aliases for compatibility.
- `InterfaceLog.lua` — file sink and transport state. Streams lines to the game's
  `live/Logs/interface.log` in real time by raising a deferred,
  popup-suppressed Lua error (the retail client has no API to write that file
  directly). The sink is rate-limited (`SetBudget{maxPerFrame,maxPerSecond,maxPending}`
  / `GetStats`); overflow is dropped and summarized (`dropped=N reason=rate_limit`)
  so verbose logging can't hitch a frame. Slash-command handlers live in
  `BuilogCommands.lua`.
- `BuilogCommands.lua` — `/builog` and `/buihealth` command surface:
  `on|off|preset off|info|watch|debug|trace|inspect|chat on|off|popups on|off|privacy on|off|level <lvl>|mark|recent|errors|capture|snapshot|report|screenshot [label]|screenshot auto off|error|warn|check|test|status`.
- `Screenshot.lua` — wraps ESO `TakeScreenshot()` and `EVENT_SCREENSHOT_SAVED` with
  manual `/builog screenshot`, opt-in auto capture (`off|error|warn`), duplicate-aware
  per-issue throttling, and `SCREENSHOT` markers carrying `source="user"|"auto"`, request
  ids/status/filenames for host-side AI correlation. Saved markers cover both BetterUI
  requests (`requested=true correlation="fifo"|"expired_fifo"`) and user/client
  screenshots observed through ESO's saved event (`trigger="external" requested=false`).
- `Watchdog.lua` — expectation contracts for flows, bank transfers, Trading House
  operations, and list refreshes. Unresolved expectations emit
  `WARN STATE | event=anomaly phase=detected` while logging is active; overflow emits
  `phase=overflow` and drops the oldest pending expectation.
- `WatchMode.lua` — live-AI enrichment for `watch`/`inspect`: per-line scene/view/flow/
  lastAction context, startup preamble, and periodic `STATE` snapshots. Replay-grade
  sessions default to no muted categories; temporary overrides remain available through
  `WatchMode.SetMutedCategories`. Module snapshot providers keep inventory/banking
  visibility, rows, categories, pending transfers, and keybind state visible without
  raising high-volume trace detail.
- `SafeExecute.lua` — `pcall` wrapper; caught errors and missing-function faults
  route through `BETTERUI.Log.Error("SAFE", ...)`.
- `Perf.lua` — live lightweight performance markers gated by
  `Log.EnabledFor(DEBUG, PERF)`; use `Perf.Begin`/`Perf.End` or `Perf.Measure`
  when a play-test needs slow-operation landmarks in builog.
- `PerformanceProfiler.lua` — dormant legacy profiling helpers kept for future
  developer debugging; it has no active runtime consumers.
- `DebugCommands.lua` — `/buidebug`, `/buiscene` developer trace commands.
- `DeveloperDebug.lua` — developer-only debug toggles.
- `FeatureFlags.lua` — runtime feature-flag system for safer rollouts.

`BETTERUI.Debug` / `BETTERUI.DebugError` / `BETTERUI.CIM.Debug.Log` are
back-compat wrappers that route through `BETTERUI.Log`. See
`docs/reference/tribal-knowledge.md` -> "Unified logging: BETTERUI.Log ->
Interface.log" for the mechanism, API, and routing details, and
`docs/reference/builog-developer-guide.md` for instrumentation standards.

Privacy note: `watch` and `inspect` preambles include player/world/zone/addon metadata,
and screenshot markers include filenames/directories/provenance. Scrub logs before sharing
outside the project.
