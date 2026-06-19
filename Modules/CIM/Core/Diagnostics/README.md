# Diagnostics

Debugging, profiling, safety wrappers, real-time logging, and feature controls.

Files:
- `Log.lua` — `BETTERUI.Log` unified logging facade: levels
  (`TRACE<DEBUG<INFO<WARN<ERROR`), categories
  (`SCENE/LIST/NAV/KEYBIND/FOOTER/CATEGORY/SEARCH/SORT/BATCH/ACTION/LIFECYCLE/SAFE/SETTINGS/GENERAL`),
  and per-level file/chat sinks. Inert until enabled, so normal players pay
  nothing. Named presets via `Log.ApplyPreset("off"|"debug"|"verbose")` (also
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
  (`on|off|preset off|debug|verbose|chat on|off|popups on|off|level <lvl>|test|status`).
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
