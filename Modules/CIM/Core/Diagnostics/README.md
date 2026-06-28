# Diagnostics

Debugging, profiling, safety wrappers, real-time logging, and feature controls.

Files:
- `Log.lua` — `BETTERUI.Log` unified logging facade: levels
  (`TRACE<DEBUG<INFO<WARN<ERROR`), categories
  (`SCENE/LIST/NAV/KEYBIND/FOOTER/CATEGORY/SEARCH/SORT/BATCH/ACTION/LIFECYCLE/SAFE/SETTINGS/CONTROL/PERF/STATE/SCREENSHOT/GENERAL`),
  and per-level file/chat sinks. Inert until enabled, so normal players pay
  nothing. Named presets via `Log.ApplyPreset("off"|"info"|"watch"|"debug"|"trace"|"inspect")` (also
  `/builog preset`) layer over the low-level knobs; `Log.SetPayloadCapture`
  toggles whether `data` payloads render. Nil-guard every call site
  (`if BETTERUI.Log then ... end`); on hot paths gate on
  `BETTERUI.Log.IsActive()`, or use `Log.EnabledFor(level, category)` (the exact
  sink-aware pre-check) / the lazy `Log.WriteLazy|DebugLazy|TraceLazy(.., dataFn)`
  builders so no payload is constructed when the record would be dropped.
- `InterfaceLog.lua` — file sink. Streams lines to the game's
  `live/Logs/Interface.log` in real time by raising a deferred,
  popup-suppressed Lua error (the retail client has no API to write that file
  directly). The sink is rate-limited (`SetBudget{maxPerFrame,maxPerSecond,maxPending}`
  / `GetStats`); overflow is dropped and summarized (`dropped=N reason=rate_limit`)
  so verbose logging can't hitch a frame. Slash command: `/builog`
  (`on|off|preset off|info|watch|debug|trace|inspect|chat on|off|popups on|off|level <lvl>|mark|snapshot|screenshot [label]|screenshot auto off|error|warn|test|status`).
- `Screenshot.lua` — wraps ESO `TakeScreenshot()` and `EVENT_SCREENSHOT_SAVED` with
  manual `/builog screenshot`, opt-in auto capture (`off|error|warn`), duplicate-aware
  per-issue throttling, and `SCREENSHOT` markers carrying request ids/status/filenames
  for host-side AI correlation. Saved markers are emitted only for BetterUI-requested screenshots;
  unrelated user screenshots are ignored.
- `WatchMode.lua` — live-AI enrichment for `watch`/`inspect`: per-line scene/view/flow/
  lastAction context, startup preamble, periodic `STATE` snapshots, and default watch-only
  mutes for `LIST`, `SEARCH`, `SORT`, `BATCH`, `FOOTER`, and `KEYBIND`. Module snapshot
  providers keep inventory/banking visibility, rows, categories, pending transfers, and
  keybind state visible without raising high-volume trace detail.
- `SafeExecute.lua` — `pcall` wrapper; caught errors and missing-function faults
  route through `BETTERUI.Log.Error("SAFE", ...)`.
- `PerformanceProfiler.lua` — lightweight timing/profiling helpers.
- `DebugCommands.lua` — `/buidebug`, `/buiscene` developer trace commands.
- `DeveloperDebug.lua` — developer-only debug toggles.
- `FeatureFlags.lua` — runtime feature-flag system for safer rollouts.

`BETTERUI.Debug` / `BETTERUI.DebugError` / `BETTERUI.CIM.Debug.Log` are
back-compat wrappers that route through `BETTERUI.Log`. See
`docs/reference/tribal-knowledge.md` -> "Unified logging: BETTERUI.Log ->
Interface.log" for the mechanism, API, and routing details.
