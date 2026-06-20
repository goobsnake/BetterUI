--[[
File: tools/tests/test_scene_log.lua
Purpose: Unit tests for the framework-level scene-transition logger (SceneLog).
         Loads production code via dofile so tests track the live module API.

Usage:
  lua tools/tests/test_scene_log.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS (must exist BEFORE dofile)
-- ============================================================================

BETTERUI = { CIM = {} }

-- Scene-state constants (engine globals in-game).
SCENE_SHOWING = 1
SCENE_SHOWN   = 2
SCENE_HIDING  = 3
SCENE_HIDDEN  = 4

function GetGameTimeMilliseconds() return 4242 end

SLASH_COMMANDS = {}

-- Captured chat output for /buiscene.
local chatLines = {}
function d(msg) chatLines[#chatLines + 1] = msg end

-- Togglable logging facade stub.
local logActive = false
local infoCalls = {}
BETTERUI.Log = {
    CATEGORY = { SCENE = "SCENE", GENERAL = "GENERAL" },
    LEVEL = { TRACE = 1, DEBUG = 2, INFO = 3, WARN = 4, ERROR = 5 },
    IsActive = function() return logActive end,
    Info = function(category, message, data)
        infoCalls[#infoCalls + 1] = { category = category, message = message, data = data }
    end,
}

-- Fake SCENE_MANAGER that captures the registered callback.
local registrations = {}
local fakeSceneManager
fakeSceneManager = {
    currentScene = "hud",
    RegisterCallback = function(_, event, fn)
        registrations[#registrations + 1] = { event = event, fn = fn }
    end,
    GetCurrentSceneName = function(self) return self.currentScene end,
    GetPreviousSceneName = function() return "prev" end,
}
SCENE_MANAGER = fakeSceneManager

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

dofile("Modules/CIM/Core/Diagnostics/SceneLog.lua")
local SL = BETTERUI.CIM.SceneLog

-- ============================================================================
-- TEST HARNESS
-- ============================================================================

local tests_passed = 0
local tests_failed = 0

local function check(cond, message)
    if cond then
        tests_passed = tests_passed + 1
        print("  [OK] " .. message)
    else
        tests_failed = tests_failed + 1
        print("  [X] " .. message)
    end
end

local function lastInfo() return infoCalls[#infoCalls] end
local function contains(haystack, needle) return string.find(haystack, needle, 1, true) ~= nil end

print("\n=== SceneLog Tests ===\n")

-- (1) File-scope load registered exactly one "SceneStateChanged" callback.
check(#registrations == 1, "registers exactly one callback at load")
check(registrations[1] and registrations[1].event == "SceneStateChanged",
    "callback event name is 'SceneStateChanged'")
check(SL.IsRegistered() == true, "IsRegistered() true after load")

local handler = registrations[1] and registrations[1].fn

-- (2) Idempotency: EnsureRegistered() again does not double-register.
local again = SL.EnsureRegistered()
check(again == false, "EnsureRegistered() returns false when already registered")
check(#registrations == 1, "no duplicate callback on repeat EnsureRegistered()")

-- (3) Inert when logging is off: no emit, and scene name is NOT resolved (gate short-circuits).
logActive = false
local getNameCalls = 0
local probeScene = { GetName = function() getNameCalls = getNameCalls + 1; return "probe" end }
local infoBefore = #infoCalls
handler(probeScene, SCENE_HIDDEN, SCENE_SHOWING)
check(#infoCalls == infoBefore, "logging OFF -> no Info emitted")
check(getNameCalls == 0, "logging OFF -> scene name not resolved (gate short-circuits)")

-- (4) Active path: one INFO/SCENE record, name + verb in the message, wasPushed flagged.
logActive = true
local bankScene = { GetName = function() return "gamepad_banking" end }
handler(bankScene, SCENE_HIDDEN, SCENE_SHOWING)
local rec = lastInfo()
check(rec ~= nil and rec.category == "SCENE", "active -> emits at CATEGORY.SCENE")
check(rec ~= nil and contains(rec.message, "gamepad_banking"), "message carries the scene name")
check(rec ~= nil and contains(rec.message, "showing"), "message carries the state verb")
check(rec ~= nil and rec.data and rec.data.wasPushed == true, "wasPushed true when coming from HIDDEN")

-- (5) Full lifecycle SHOWING->SHOWN->HIDING->HIDDEN yields one record each, correct verbs.
infoCalls = {}
handler(bankScene, SCENE_HIDDEN,  SCENE_SHOWING)
handler(bankScene, SCENE_SHOWING, SCENE_SHOWN)
handler(bankScene, SCENE_SHOWN,   SCENE_HIDING)
handler(bankScene, SCENE_HIDING,  SCENE_HIDDEN)
check(#infoCalls == 4, "one record per state transition")
check(contains(infoCalls[1].message, "showing")
   and contains(infoCalls[2].message, "shown")
   and contains(infoCalls[3].message, "hiding")
   and contains(infoCalls[4].message, "hidden"), "verbs map showing/shown/hiding/hidden")

-- (6) Unknown state falls back to a readable token rather than erroring.
infoCalls = {}
handler(bankScene, SCENE_SHOWN, 999)
check(lastInfo() ~= nil and contains(lastInfo().message, "state(999)"), "unknown state -> state(<n>) fallback")

-- (7) Arg robustness: nil and string scene args degrade, never error.
infoCalls = {}
local okNil = pcall(handler, nil, SCENE_HIDDEN, SCENE_SHOWING)
check(okNil, "nil scene arg does not error")
check(lastInfo() ~= nil and contains(lastInfo().message, "<unknown>"), "nil scene -> '<unknown>'")
local okStr = pcall(handler, "somescene", SCENE_HIDDEN, SCENE_SHOWING)
check(okStr, "string scene arg does not error")
check(lastInfo() ~= nil and contains(lastInfo().message, "somescene"), "string scene -> used verbatim")

-- (8) Ring buffer caps at its fixed size (newest retained).
for i = 1, 40 do handler(bankScene, SCENE_SHOWING, SCENE_SHOWN) end
local ring = SL.GetRecent()
local ringCount = 0
for _ in pairs(ring) do ringCount = ringCount + 1 end
check(ringCount > 0 and ringCount <= 24, "recent-transition ring is bounded (<=24)")

-- (9) /buiscene slash command is registered and runs without error.
check(type(SLASH_COMMANDS["/buiscene"]) == "function", "/buiscene registered")
chatLines = {}
local okCmd = pcall(SLASH_COMMANDS["/buiscene"])
check(okCmd and #chatLines > 0, "/buiscene runs and prints")

-- (10) Nil-safety: loading with no SCENE_MANAGER must not error and must not register.
SCENE_MANAGER = nil
registrations = {}
local okLoad = pcall(dofile, "Modules/CIM/Core/Diagnostics/SceneLog.lua")
check(okLoad, "loads without error when SCENE_MANAGER is absent")
check(BETTERUI.CIM.SceneLog.IsRegistered() == false, "stays unregistered without SCENE_MANAGER")
check(#registrations == 0, "registers nothing without SCENE_MANAGER")

-- ============================================================================
-- SUMMARY
-- ============================================================================

print("\n=== Test Summary ===")
print(string.format("Passed: %d", tests_passed))
print(string.format("Failed: %d", tests_failed))

if tests_failed > 0 then
    os.exit(1)
else
    print("\nAll tests passed!")
    os.exit(0)
end
