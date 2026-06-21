--[[
File: tools/tests/test_watchmode.lua
Purpose: Unit tests for WatchMode.lua — the watch-preset enrichment layer.
         Uses a fake BETTERUI.Log + fake SCENE_MANAGER/zo_callLater so the module is
         exercised in isolation.
Usage:   lua tools/tests/test_watchmode.lua
]]

BETTERUI = { CIM = {} }

-- Fake Names (resolves a {name=..} mock scene; userdata path covered by test_names).
BETTERUI.CIM.Names = {
    Scene = function(s)
        if type(s) == "table" and s.name then return s.name end
        return "<unknown>"
    end,
}
BETTERUI.Names = BETTERUI.CIM.Names

-- Fake SCENE_MANAGER returning a current scene.
local fakeScene = { name = "gamepad_banking" }
SCENE_MANAGER = { GetCurrentScene = function() return fakeScene end }

-- Fake zo_callLater: capture callbacks, do NOT auto-run (avoids infinite heartbeat).
local laters = {}
function zo_callLater(fn, ms) laters[#laters + 1] = { fn = fn, ms = ms }; return #laters end

-- Fake Log capturing emitted records + the registered context provider.
local cap = { lines = {}, provider = nil, lastAction = nil, mutes = {} }
BETTERUI.Log = {
    SCHEMA = 1,
    LEVEL = { TRACE = 1, DEBUG = 2, INFO = 3, WARN = 4, ERROR = 5 },
    CATEGORY = { STATE = "STATE", GENERAL = "GENERAL" },
    SetContextProvider = function(fn) cap.provider = fn end,
    GetContextProvider = function() return cap.provider end,
    GetLastAction = function() return cap.lastAction end,
    SetLastAction = function(m, f) cap.lastAction = { message = m, flow = f } end,
    GetSessionId = function() return "abcd1234" end,
    EnabledFor = function() return true end,
    SetCategoryEnabled = function(cat, on) cap.mutes[cat] = not on end,
    Info = function(cat, msg, data) cap.lines[#cap.lines + 1] = { lvl = "INFO", cat = cat, msg = msg, data = data } end,
    Debug = function(cat, msg, data) cap.lines[#cap.lines + 1] = { lvl = "DEBUG", cat = cat, msg = msg, data = data } end,
}

dofile("Modules/CIM/Core/Diagnostics/WatchMode.lua")
local Watch = BETTERUI.CIM.WatchMode

local passed, failed = 0, 0
local function check(cond, msg)
    if cond then passed = passed + 1; print("  [OK] " .. msg)
    else failed = failed + 1; print("  [X] " .. msg) end
end

print("\n=== WatchMode Tests ===\n")

-- Activate: registers a context provider, emits a preamble, schedules a snapshot.
Watch.Activate()
check(cap.provider ~= nil, "Activate registers a Log context provider")
check(#cap.lines >= 1, "Activate emits a startup preamble record")
check(cap.lines[1].cat == "STATE", "preamble is a STATE record")
check(#laters == 1, "Activate schedules a snapshot heartbeat via zo_callLater")
check(Watch.IsActive() == true, "IsActive true after Activate")

-- Context suffix carries scene + flow + lastAction.
cap.lastAction = { message = "pressed A", flow = "deposit#1" }
local suffix = cap.provider(2, "GENERAL")
check(suffix:find("scene=gamepad_banking", 1, true) ~= nil, "suffix carries scene")
check(suffix:find("flow=deposit#1", 1, true) ~= nil, "suffix carries flow")
check(suffix:find('lastAction="pressed A"', 1, true) ~= nil, "suffix carries quoted lastAction")

-- SetView injects view=, clears on nil.
Watch.SetView("DepositTab")
check(cap.provider(2, "GENERAL"):find("view=DepositTab", 1, true) ~= nil, "SetView injects view=")
Watch.SetView(nil)
check(cap.provider(2, "GENERAL"):find("view=", 1, true) == nil, "SetView(nil) clears view")

-- Snapshot registry: registered provider value appears in the STATE snapshot.
Watch.RegisterSnapshotProvider("bankSlots", function() return 42 end)
local before = #cap.lines
Watch.Snapshot()
check(#cap.lines > before, "Snapshot emits a record")
local snap = cap.lines[#cap.lines]
check(snap.cat == "STATE" and snap.msg == "snapshot", "Snapshot is a STATE 'snapshot' record")
check(snap.data and snap.data.bankSlots == 42, "Snapshot includes registered provider data")
check(snap.data and snap.data.scene == "gamepad_banking", "Snapshot includes current scene")

-- A provider that errors is pcall-guarded (does not break the snapshot).
Watch.RegisterSnapshotProvider("boom", function() error("nope") end)
local okCall = pcall(Watch.Snapshot)
check(okCall, "Snapshot survives an erroring provider")

-- Curated auto-mute applies via SetCategoryEnabled when active.
Watch.SetMutedCategories({ "PERF" })
check(cap.mutes["PERF"] == true, "SetMutedCategories mutes the category while active")

-- Idempotent re-Activate re-asserts the provider + mutes (ApplyPreset('watch') clears
-- the provider/categoryDisabled first), and does NOT schedule a second heartbeat.
local latersBefore = #laters
cap.provider = nil          -- simulate provider clear
cap.mutes["PERF"] = false   -- simulate categoryDisabled reset by ApplyPreset
Watch.Activate()
check(cap.provider ~= nil, "re-Activate re-registers the context provider")
check(cap.mutes["PERF"] == true, "re-Activate re-applies mutes after a preset reset")
check(#laters == latersBefore, "re-Activate does not schedule a second heartbeat")

-- Heartbeat: the scheduled callback emits a snapshot and reschedules itself while active.
local linesBefore = #cap.lines
laters[#laters].fn()
check(#cap.lines > linesBefore, "heartbeat callback emits a snapshot")
check(#laters == latersBefore + 1, "heartbeat reschedules itself while active")

-- Deactivate clears the provider + restores mutes + view; the heartbeat then self-stops.
Watch.Deactivate()
check(cap.provider == nil, "Deactivate clears the context provider")
check(cap.mutes["PERF"] == false, "Deactivate restores muted category")
check(Watch.IsActive() == false, "IsActive false after Deactivate")
local latersAfterDeact = #laters
laters[#laters].fn() -- run the pending heartbeat tick after Deactivate
check(#laters == latersAfterDeact, "heartbeat does not reschedule after Deactivate")

print("\n=== Test Summary ===")
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))
if failed > 0 then os.exit(1) else print("\nAll tests passed!"); os.exit(0) end
