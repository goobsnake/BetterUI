--[[
File: Modules/CIM/Core/Diagnostics/BuilogCommands.lua
Purpose: Slash-command surface for BetterUI Interface.log diagnostics.
]]

BETTERUI.CIM = BETTERUI.CIM or {}

local BuilogCommands = {}
BETTERUI.CIM.BuilogCommands = BuilogCommands

local InterfaceLog = BETTERUI.CIM.InterfaceLog
assert(type(InterfaceLog) == "table", "InterfaceLog.lua must load before BuilogCommands.lua")

local function G(name) return rawget(_G, name) end

local function Out(msg)
    local chat = G("d")
    if type(chat) == "function" then
        chat("|c0066ff[BetterUI]|r " .. msg)
    end
end

local function PrintStatus()
    local L = BETTERUI.Log
    Out(string.format("InterfaceLog: %s | popups: %s | path: %s",
        InterfaceLog.IsEnabled() and "|c00ff00ON|r" or "off",
        InterfaceLog.GetSuppressPopups() and "suppressed" or "visible",
        InterfaceLog.IsAvailable() and "ready" or "UNAVAILABLE"))
    if L then
        Out(string.format("Preset: %s | min level: %s | payloads: %s | privacy=%s",
            L.GetPreset and tostring(L.GetPreset()):upper() or "?",
            L.GetMinLevel and (({ "TRACE", "DEBUG", "INFO", "WARN", "ERROR" })[L.GetMinLevel()] or "?") or "?",
            (L.GetPayloadCapture and L.GetPayloadCapture()) and "on" or "off",
            InterfaceLog.GetPrivacyMode() and "on" or "off"))
        Out(string.format("Logger chat surface (ERROR) = %s", L.GetSink(L.LEVEL.ERROR, "chat") and "on" or "off"))
    end
    local s = InterfaceLog.GetStats()
    Out(string.format("Sink budget: frame=%s sec=%s pending=%s/%s | scheduled=%d dropped=%d suppressed=%d",
        s.maxPerFrame > 0 and tostring(s.maxPerFrame) or "inf",
        s.maxPerSecond > 0 and tostring(s.maxPerSecond) or "inf",
        tostring(s.pending or 0),
        s.maxPending > 0 and tostring(s.maxPending) or "inf",
        s.scheduled, s.dropped, s.suppressed or 0))
    local WD = BETTERUI.CIM and BETTERUI.CIM.Watchdog
    if WD and type(WD.GetStats) == "function" then
        local okWatchdog, wd = pcall(WD.GetStats)
        if okWatchdog and type(wd) == "table" then
            Out(string.format("Watchdog: pending=%s flows=%s detected=%s resolved=%s",
                tostring(wd.pending or 0), tostring(wd.pendingFlows or 0),
                tostring(wd.detected or 0), tostring(wd.resolved or 0)))
        end
    end
    local S = BETTERUI.CIM and BETTERUI.CIM.Screenshot
    if S and S.GetStatus then
        local okShot, shot = pcall(S.GetStatus)
        if okShot and type(shot) == "table" then
            Out(string.format("Screenshots: auto=%s | shots=%s/%s user=%s suppressed=%s pending=%s",
                tostring(shot.autoMode or "off"), tostring(shot.shots or 0),
                tostring(shot.sessionLimit or "?"), tostring(shot.userShots or 0),
                tostring(shot.suppressed or 0),
                tostring(shot.pending or 0)))
        end
    end
    Out("Real Lua errors always log to Interface.log; [BUI] lines are BetterUI's own stream.")
end

local function EmitSessionReport()
    local L = BETTERUI.Log
    if not (L and type(L.TraceEvent) == "function") then
        Out("Logger not loaded yet.")
        return
    end

    local sink = InterfaceLog.GetStats()
    local wd = {}
    local WD = BETTERUI.CIM and BETTERUI.CIM.Watchdog
    if WD and type(WD.GetStats) == "function" then
        local okWatchdog, watchdogStats = pcall(WD.GetStats)
        if okWatchdog and type(watchdogStats) == "table" then wd = watchdogStats end
    end

    local shot = {}
    local S = BETTERUI.CIM and BETTERUI.CIM.Screenshot
    if S and type(S.GetStatus) == "function" then
        local okShot, shotStats = pcall(S.GetStatus)
        if okShot and type(shotStats) == "table" then shot = shotStats end
    end

    local retainedErrors = 0
    if type(L.GetRecentErrors) == "function" then
        local okErrors, recentErrors = pcall(L.GetRecentErrors)
        if okErrors and type(recentErrors) == "table" then retainedErrors = #recentErrors end
    end

    local errorCount = 0
    if type(L.GetErrorCount) == "function" then
        local okCount, count = pcall(L.GetErrorCount)
        if okCount and type(count) == "number" then errorCount = count end
    end

    local payload = {
        scheduled = sink.scheduled or 0,
        dropped = sink.dropped or 0,
        suppressed = sink.suppressed or 0,
        pending = sink.pending or 0,
        maxPending = sink.maxPending or 0,
        errorCount = errorCount,
        retainedErrors = retainedErrors,
        watchdogPending = wd.pending or 0,
        unresolvedFlows = wd.pendingFlows or 0,
        anomalyDetected = wd.detected or 0,
        anomalyResolved = wd.resolved or 0,
        screenshots = shot.shots or 0,
        userScreenshots = shot.userShots or 0,
        screenshotSuppressed = shot.suppressed or 0,
        pendingScreenshots = shot.pending or 0,
        screenshotAuto = shot.autoMode or "off",
    }

    local categories = L.CATEGORY or {}
    local levels = L.LEVEL or {}
    pcall(L.TraceEvent, categories.STATE or "STATE", "session", "report", payload, levels.INFO)
    Out(InterfaceLog.IsEnabled() and "Session report emitted to Interface.log." or "Session report requested; enable /builog to persist it.")
end

local function PrintScreenshotStatus()
    local S = BETTERUI.CIM and BETTERUI.CIM.Screenshot
    if not (S and S.GetStatus) then Out("Screenshot service not loaded.") return end
    local ok, status = pcall(S.GetStatus)
    if not ok or type(status) ~= "table" then Out("Screenshot status unavailable.") return end
    Out(string.format("Screenshots: auto=%s | shots=%s/%s user=%s suppressed=%s pending=%s burst=%s/%s duplicate=%sms pendingTtl=%sms",
        tostring(status.autoMode or "off"), tostring(status.shots or 0),
        tostring(status.sessionLimit or "?"), tostring(status.userShots or 0),
        tostring(status.suppressed or 0),
        tostring(status.pending or 0), tostring(status.burst or 0),
        tostring(status.burstLimit or "?"), tostring(status.duplicateMs or "?"),
        tostring(status.pendingTtlMs or "?")))
end

local function HandleScreenshotCommand(raw)
    local S = BETTERUI.CIM and BETTERUI.CIM.Screenshot
    if not S then Out("Screenshot service not loaded.") return end
    local subRaw = raw:match("^[Ss][Cc][Rr][Ee][Ee][Nn][Ss][Hh][Oo][Tt]%s*(.*)$") or ""
    local sub = subRaw:lower():gsub("^%s+", ""):gsub("%s+$", "")

    if sub == "status" or sub == "auto status" then
        PrintScreenshotStatus()
        return
    end

    if sub == "auto" then
        Out("Usage: /builog screenshot auto off|error|warn")
        return
    end

    if sub:match("^auto%s+%a+$") then
        local mode = sub:match("^auto%s+(%a+)$")
        if InterfaceLog.SetScreenshotAutoMode then
            local ok, applied = InterfaceLog.SetScreenshotAutoMode(mode)
            if ok then
                Out("Screenshot auto capture = |c00ff00" .. tostring(applied):upper() .. "|r.")
                PrintScreenshotStatus()
            else
                Out("Unknown screenshot auto mode. Use off|error|warn.")
            end
        else
            Out("Screenshot auto mode unavailable.")
        end
        return
    end

    if S.RequestManual then
        local ok, reason = S.RequestManual(subRaw)
        if ok then
            Out("Screenshot requested" .. (subRaw ~= "" and (": " .. subRaw) or "") .. ".")
        else
            Out("Screenshot not taken: " .. tostring(reason or "unavailable") .. ".")
        end
    else
        Out("Screenshot capture unavailable.")
    end
end

local captureRevertId = nil
local captureGen = 0
local captureManualEnabledChangeGen = nil
local LOG_LEVEL_KEYS = { "TRACE", "DEBUG", "INFO", "WARN", "ERROR" }
local LOG_SINK_NAMES = { "file", "chat" }

local function MarkCaptureEnabledStateChanged()
    if captureRevertId then
        captureManualEnabledChangeGen = captureGen
    end
end

local function SnapshotCaptureSinks(L, preset)
    if preset ~= "custom" or type(L.GetSink) ~= "function" or type(L.LEVEL) ~= "table" then
        return nil
    end
    local sinks = {}
    for _, levelKey in ipairs(LOG_LEVEL_KEYS) do
        local level = L.LEVEL[levelKey]
        if type(level) == "number" then
            for _, sinkName in ipairs(LOG_SINK_NAMES) do
                local ok, value = pcall(L.GetSink, level, sinkName)
                if ok and type(value) == "boolean" then
                    sinks[#sinks + 1] = { level = level, name = sinkName, enabled = value }
                end
            end
        end
    end
    return #sinks > 0 and sinks or nil
end

local function RestoreCaptureSinks(L, snapshot)
    if type(snapshot.sinks) ~= "table" or type(L.SetSink) ~= "function" then
        return
    end
    for _, sink in ipairs(snapshot.sinks) do
        if type(sink) == "table" and type(sink.level) == "number" and type(sink.name) == "string" then
            pcall(L.SetSink, sink.level, sink.name, sink.enabled == true)
        end
    end
end

local function SnapshotCaptureState(L)
    local snapshot = { enabled = InterfaceLog.IsEnabled(), preset = "debug", minLevel = nil, payloadCapture = nil }
    if type(L.GetPreset) == "function" then
        local okP, preset = pcall(L.GetPreset)
        if okP and type(preset) == "string" then snapshot.preset = preset end
    end
    if type(L.GetMinLevel) == "function" then
        local okL, level = pcall(L.GetMinLevel)
        if okL and type(level) == "number" then snapshot.minLevel = level end
    end
    if type(L.GetPayloadCapture) == "function" then
        local okPayload, payload = pcall(L.GetPayloadCapture)
        if okPayload and type(payload) == "boolean" then snapshot.payloadCapture = payload end
    end
    snapshot.sinks = SnapshotCaptureSinks(L, snapshot.preset)
    return snapshot
end

local function RestoreCaptureState(L, snapshot, restoreEnabled)
    snapshot = type(snapshot) == "table" and snapshot or { enabled = false, preset = "debug" }
    local preset = type(snapshot.preset) == "string" and snapshot.preset or "debug"
    local restoredPreset = false
    if preset ~= "custom" then
        local pok, applied = pcall(L.ApplyPreset, preset)
        restoredPreset = pok and applied
        if not restoredPreset then pcall(L.ApplyPreset, "debug") end
    end
    local preservePreset = preset ~= "custom" and restoredPreset == true
    if type(snapshot.minLevel) == "number" and type(L.SetMinLevel) == "function" then
        local okCurrent, current = false, nil
        if type(L.GetMinLevel) == "function" then
            okCurrent, current = pcall(L.GetMinLevel)
        end
        if not okCurrent or current ~= snapshot.minLevel then
            pcall(L.SetMinLevel, snapshot.minLevel, preservePreset)
        end
    end
    if type(snapshot.payloadCapture) == "boolean" and type(L.SetPayloadCapture) == "function" then
        local okCurrent, current = false, nil
        if type(L.GetPayloadCapture) == "function" then
            okCurrent, current = pcall(L.GetPayloadCapture)
        end
        if not okCurrent or current ~= snapshot.payloadCapture then
            pcall(L.SetPayloadCapture, snapshot.payloadCapture, preservePreset)
        end
    end
    RestoreCaptureSinks(L, snapshot)
    if restoreEnabled ~= false then
        InterfaceLog.SetEnabled(snapshot.enabled == true)
    end
end

local function StartCapture(secs)
    local L = BETTERUI.Log
    if not (L and L.ApplyPreset and L.GetPreset) then Out("Logger not loaded.") return end
    local later = G("zo_callLater")
    if type(later) ~= "function" then Out("Capture unavailable (no timer); use /builog preset trace manually.") return end
    secs = (type(secs) == "number") and math.max(1, math.min(60, secs)) or 5

    local remove = G("zo_removeCallLater")
    if captureRevertId and type(remove) == "function" then pcall(remove, captureRevertId) end
    captureRevertId = nil
    captureGen = captureGen + 1
    local gen = captureGen
    captureManualEnabledChangeGen = nil

    local snapshot = SnapshotCaptureState(L)
    if not InterfaceLog.IsEnabled() then InterfaceLog.SetEnabled(true) end
    pcall(L.ApplyPreset, "trace")
    if L.Info then pcall(L.Info, L.CATEGORY.STATE, "capture window started (" .. secs .. "s, was " .. tostring(snapshot.preset) .. ")") end
    Out(string.format("Capturing at |c00ff00TRACE|r for %ds, then reverting to %s.", secs, tostring(snapshot.preset)))

    captureRevertId = later(function()
        if gen ~= captureGen then return end
        captureRevertId = nil
        local okP, preset = pcall(function() return L.GetPreset and L.GetPreset() or nil end)
        if okP and preset and preset ~= "trace" then return end
        local liveDisabledDuringCapture = snapshot.enabled == true and not InterfaceLog.IsEnabled()
        RestoreCaptureState(L, snapshot, captureManualEnabledChangeGen ~= gen and not liveDisabledDuringCapture)
        if L.Info then pcall(L.Info, L.CATEGORY.STATE, "capture window ended") end
    end, secs * 1000)
end

local function DumpRecords(getter, n, label)
    if type(getter) ~= "function" then Out("Logger not loaded.") return end
    local ok, records = pcall(getter, n)
    if not ok or type(records) ~= "table" or #records == 0 then
        Out("No " .. label .. " records captured (logging may be off).") return
    end
    Out(string.format("|c0066ff[BetterUI]|r last %d %s record(s):", #records, label))
    for i = 1, #records do
        local r = records[i]
        Out(string.format("  seq=%s %s %s | %s",
            tostring(r.seq), tostring(r.level), tostring(r.category), tostring(r.message)))
    end
end

local function HandleLayoutCommand(raw)
    local S = BETTERUI.CIM and BETTERUI.CIM.LayoutSnapshot
    if not (S and type(S.Snapshot) == "function") then Out("Layout snapshot service not loaded.") return end

    local name = raw:match("^[Ll][Aa][Yy][Oo][Uu][Tt]%s*(.*)$") or ""
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then name = nil end

    local ok, emitted, result = pcall(function()
        local success, snapshotResult = S.Snapshot(name)
        return success, snapshotResult
    end)
    if not ok then
        Out("Layout snapshot failed.")
        return
    end
    if emitted and type(result) == "table" then
        Out(string.format("Layout snapshot %s emitted (%d controls, %d skipped).",
            tostring(result.snapshot or name or "visible"), tonumber(result.emitted) or 0, tonumber(result.skipped) or 0))
        return
    end

    local available = (type(result) == "table" and result.available) or "inventory|vendor|tradinghouse|orbs"
    Out("Layout snapshot not emitted: " .. tostring(type(result) == "table" and result.reason or "unavailable") .. ". Use /builog layout [" .. tostring(available) .. "].")
end

local function HandleCommand(args)
    local raw = tostring(args or ""):gsub("^%s+", ""):gsub("%s+$", "")

    local markText = raw:match("^[Mm][Aa][Rr][Kk]%s+(.+)$")
    if markText then
        local L = BETTERUI.Log
        if L and L.Info then
            pcall(L.Info, L.CATEGORY.STATE, "mark: " .. markText)
            Out("Marked: " .. markText)
        else
            Out("Logger not loaded yet.")
        end
        return
    end

    args = raw:lower()

    if args == "on" then
        MarkCaptureEnabledStateChanged()
        InterfaceLog.SetLoggingEnabled(true, "slash command")
        InterfaceLog.Write("logging started -- breadcrumbs are tagged [BUI]; grep '[BUI]' for the clean stream. On disk each is engine-wrapped: <ISO-8601 ts> |cff0000Lua Error: [BUI] <gameMs> sid=<sid> seq=<seq> <LEVEL> <CATEGORY> | <event> <key=value ...> then a 'stack traceback:' block (ignore it for [BUI] lines). sid groups one UI-load session; seq is a monotonic order. Levels TRACE<DEBUG<INFO<WARN<ERROR. The ISO timestamp is authoritative wall-clock. 'Lua Error:' entries WITHOUT [BUI] are real game errors -- keep their traceback.")
        Out("InterfaceLog |c00ff00ENABLED|r -- [BUI] diagnostics stream to Interface.log. Tip: /builog preset watch for guided troubleshooting, or debug|trace for detail.")
    elseif args == "off" then
        MarkCaptureEnabledStateChanged()
        InterfaceLog.SetLoggingEnabled(false, "slash command")
        Out("InterfaceLog disabled; error popups restored.")
    elseif args:match("^preset%s+%a+$") then
        local name = args:match("^preset%s+(%a+)$")
        local L = BETTERUI.Log
        if L and L.ApplyPreset then
            local applied, presetName = InterfaceLog.ApplyLogPreset(name)
            if applied then
                Out("Log preset = |c00ff00" .. tostring(presetName):upper() .. "|r.")
                PrintStatus()
            else
                Out("Unknown preset. Use off|info|watch|debug|trace|inspect.")
            end
        else
            Out("Logger not loaded yet.")
        end
    elseif args == "check" or args == "test" then
        local wasEnabled = InterfaceLog.IsEnabled()
        if not wasEnabled then InterfaceLog.SetEnabled(true) end
        InterfaceLog.Write("diagnostic check breadcrumb A (direct Write)")
        BETTERUI.Debug("diagnostic check breadcrumb B (via BETTERUI.Debug)")
        if BETTERUI.Log and BETTERUI.Log.Error then BETTERUI.Log.Error("SAFE", "diagnostic check breadcrumb C (via Log.Error)") end
        Out("Wrote diagnostic breadcrumbs to Interface.log.")
        if not wasEnabled then Out("(Logging was off; left it ON. Use /builog off to stop.)") end
    elseif args == "popups on" then
        InterfaceLog.SetPopupSuppression(true)
        Out("BetterUI breadcrumbs stay file-only while builog is on.")
    elseif args == "popups off" then
        InterfaceLog.SetPopupSuppression(false)
        Out("Popups can only be restored by disabling /builog (use /builog off).")
    elseif args == "chat on" then
        InterfaceLog.SetChatSurface(true)
        Out("Chat surfacing is not supported; builog is file-only.")
    elseif args == "chat off" then
        InterfaceLog.SetChatSurface(false)
        Out("Chat surfacing OFF (file-only).")
    elseif args == "privacy on" or args == "privacy off" then
        local on = args == "privacy on"
        if InterfaceLog.SetPrivacyMode(on) then
            Out("Privacy mode " .. (on and "|c00ff00ON|r" or "off") .. ".")
            PrintStatus()
        else
            Out("Privacy mode unavailable; logger not loaded yet.")
        end
    elseif args:match("^level%s+%a+$") then
        local name = args:match("^level%s+(%a+)$")
        local ok, applied = InterfaceLog.SetMinLevelSetting(name)
        if ok then Out("Min log level set to " .. tostring(applied):upper() .. ".")
        else Out("Unknown level. Use trace|debug|info|warn|error.") end
    elseif args == "recent" or args:match("^recent%s+%d+$") then
        local L = BETTERUI.Log
        DumpRecords(L and L.GetRecent, tonumber(args:match("(%d+)")) or 20, "recent")
    elseif args == "errors" or args:match("^errors%s+%d+$") then
        local L = BETTERUI.Log
        DumpRecords(L and L.GetRecentErrors, tonumber(args:match("(%d+)")) or 20, "error")
    elseif args == "capture" or args:match("^capture%s+%d+$") then
        StartCapture(tonumber(args:match("(%d+)")))
    elseif args == "screenshot" or args:match("^screenshot%s+") then
        HandleScreenshotCommand(raw)
    elseif args == "layout" or args:match("^layout%s+") then
        HandleLayoutCommand(raw)
    elseif args == "report" then
        EmitSessionReport()
    elseif args == "status" then
        PrintStatus()
    elseif args == "mark" then
        Out("Usage: /builog mark <text>  -- annotates the live log with <text>.")
    elseif args == "snapshot" then
        local W = BETTERUI.CIM and BETTERUI.CIM.WatchMode
        if W and W.Snapshot then
            local ok = pcall(W.Snapshot)
            Out(ok and "Emitted a STATE snapshot to the log." or "Snapshot failed.")
        else Out("Watch mode not loaded.") end
    else
        PrintStatus()
        Out("Usage: /builog on|off | preset off|info|watch|debug|trace|inspect | chat on|off | popups on|off | privacy on|off | level <lvl> | mark <text> | recent [n] | errors [n] | capture [secs] | screenshot [label] | screenshot auto off|error|warn | layout [inventory|vendor|tradinghouse|orbs] | snapshot | report | check|test | status")
    end
end

local function HandleHealthCommand()
    local out = G("d")
    if type(out) ~= "function" then return end
    local ok, err = pcall(function()
        local L = BETTERUI.Log
        out("|c0066ff[BetterUI health]|r")
        if L then
            out(string.format("  preset=%s active=%s sid=%s schema=%s",
                tostring(L.GetPreset and L.GetPreset()),
                tostring(L.IsActive and L.IsActive()),
                tostring(L.GetSessionId and L.GetSessionId()),
                tostring(L.SCHEMA)))
            local errsT = L.GetRecentErrors and L.GetRecentErrors()
            local retained = (type(errsT) == "table") and #errsT or "?"
            out(string.format("  errors=%s (retained=%s) -- /builog errors to list",
                tostring(L.GetErrorCount and L.GetErrorCount()), tostring(retained)))
        else
            out("  logger not loaded")
        end
        local s = InterfaceLog.GetStats()
        out(string.format("  file: scheduled=%s pending=%s/%s dropped=%s budget=%s/frame %s/sec",
            tostring(s.scheduled), tostring(s.pending or 0),
            s.maxPending > 0 and tostring(s.maxPending) or "inf",
            tostring(s.dropped),
            s.maxPerFrame > 0 and tostring(s.maxPerFrame) or "inf",
            s.maxPerSecond > 0 and tostring(s.maxPerSecond) or "inf"))
        local SL = BETTERUI.CIM and BETTERUI.CIM.SceneLog
        local W = BETTERUI.CIM and BETTERUI.CIM.WatchMode
        local WD = BETTERUI.CIM and BETTERUI.CIM.Watchdog
        out(string.format("  sceneLog=%s watch=%s",
            tostring(SL and SL.IsRegistered and SL.IsRegistered()),
            tostring(W and W.IsActive and W.IsActive())))
        if WD and type(WD.GetStats) == "function" then
            local okWatchdog, wd = pcall(WD.GetStats)
            if okWatchdog and type(wd) == "table" then
                out(string.format("  watchdog: pending=%s flows=%s detected=%s resolved=%s",
                    tostring(wd.pending or 0), tostring(wd.pendingFlows or 0),
                    tostring(wd.detected or 0), tostring(wd.resolved or 0)))
            end
        end
    end)
    if not ok then out("  (health check error: " .. tostring(err) .. ")") end
end

local function Register()
    local commands = G("SLASH_COMMANDS")
    if type(commands) ~= "table" then return false end

    local registerSlash = BETTERUI.CIM and BETTERUI.CIM.Utils and BETTERUI.CIM.Utils.RegisterSlashCommand
    if type(registerSlash) == "function" then
        registerSlash("/builog", HandleCommand, { owner = "BuilogCommands" })
    elseif type(commands["/builog"]) ~= "function" then
        commands["/builog"] = HandleCommand
    end

    if type(registerSlash) == "function" then
        registerSlash("/buihealth", HandleHealthCommand, { owner = "BuilogCommands" })
    elseif type(commands["/buihealth"]) ~= "function" then
        commands["/buihealth"] = HandleHealthCommand
    end

    return true
end

BuilogCommands.Out = Out
BuilogCommands.PrintStatus = PrintStatus
BuilogCommands.EmitSessionReport = EmitSessionReport
BuilogCommands.HandleCommand = HandleCommand
BuilogCommands.HandleHealthCommand = HandleHealthCommand
BuilogCommands.Register = Register

Register()
