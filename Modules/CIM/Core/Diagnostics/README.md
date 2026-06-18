# Diagnostics

Debugging, profiling, safety wrappers, real-time logging, and feature controls.

Files:
- `Log.lua` — `BETTERUI.Log` unified logging facade: levels
  (`TRACE<DEBUG<INFO<WARN<ERROR`), categories
  (`SCENE/LIST/NAV/KEYBIND/FOOTER/CATEGORY/SEARCH/SORT/BATCH/ACTION/LIFECYCLE/SAFE/SETTINGS/GENERAL`),
  and per-level file/chat sinks. Inert until enabled, so normal players pay
  nothing. Nil-guard every call site (`if BETTERUI.Log then ... end`); on hot
  paths also gate on `BETTERUI.Log.IsActive()`.
- `InterfaceLog.lua` — file sink. Streams lines to the game's
  `live/Logs/Interface.log` in real time by raising a deferred,
  popup-suppressed Lua error (the retail client has no API to write that file
  directly). Slash command: `/builog` (`on|off|test|chat on|off|popups on|off|level <lvl>`).
- `SafeExecute.lua` — `pcall` wrapper; caught errors route through
  `BETTERUI.Log.Error("SAFE", ...)`.
- `PerformanceProfiler.lua` — lightweight timing/profiling helpers.
- `DebugCommands.lua` — `/buidebug`, `/buiscene` developer trace commands.
- `DeveloperDebug.lua` — developer-only debug toggles.
- `FeatureFlags.lua` — runtime feature-flag system for safer rollouts.

`BETTERUI.Debug` / `BETTERUI.DebugError` / `BETTERUI.CIM.Debug.Log` are
back-compat wrappers that route through `BETTERUI.Log`. See
`docs/reference/tribal-knowledge.md` -> "Unified logging: BETTERUI.Log ->
Interface.log" for the mechanism, API, and routing details.
