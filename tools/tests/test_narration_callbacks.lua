--[[
File: tools/tests/test_narration_callbacks.lua
Purpose: Unit tests for PLT-006 – pcall-hardened narration callbacks in NarrationHelper.lua.
         Verifies that canNarrate and selectedNarrationFunction return safe defaults when
         SCENE_MANAGER, getTitleFn, or getSelectedDataFn throw.

Usage:
  lua tools/tests/test_narration_callbacks.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = { CIM = {} }
BETTERUI.CIM.SafeExecute = function(tag, fn) fn() end

SCREEN_NARRATION_MANAGER = {
    customObjectNarrationInfo = {},
    CreateNarratableObject = function(self, text) return { text = text } end,
    RegisterCustomObject = function(self, name, info)
        self.customObjectNarrationInfo[name] = info
    end,
    QueueCustomEntry = function(self, name, narrateHeader)
        local info = self.customObjectNarrationInfo[name]
        if not info then error("missing custom object") end
        self.lastQueued = { name = name, narrateHeader = narrateHeader, narrationType = info.narrationType }
    end,
}

SCENE_MANAGER = {
    GetCurrentSceneName = function(self) return "test_scene" end,
}

NARRATION_TYPE_UI_SCREEN = 1
ITEM_DISPLAY_QUALITY_TRASH = 1
ITEMFILTERTYPE_JUNK = 5

function GetString(id) return tostring(id) end
function zo_strformat(fmt, ...) return fmt end
function ZO_AppendNarration(t, n) if n then t[#t + 1] = n end end
function GetCurrencyName() return "gold" end

dofile("Modules/CIM/Core/Integration/NarrationHelper.lua")
local Narration = BETTERUI.CIM.Narration

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

print("\n=== NarrationHelper Callback Safety Tests (PLT-006) ===\n")

-- Helper: capture the narrationInfo table from a Register call
local captured = {}
SCREEN_NARRATION_MANAGER.RegisterCustomObject = function(self, name, info)
    captured[name] = info
    self.customObjectNarrationInfo[name] = info
end

-- ============================================================================
-- canNarrate: healthy path
-- ============================================================================

captured = {}
Narration.RegisterListNarration("test_scene", function() return nil end)
local info = captured["test_scene"]
check(info ~= nil, "RegisterListNarration registers a narration info object")
check(info.narrationType == NARRATION_TYPE_UI_SCREEN, "RegisterListNarration marks custom object as UI screen narration")

SCENE_MANAGER.GetCurrentSceneName = function(self) return "test_scene" end
check(info.canNarrate() == true, "canNarrate returns true when scene matches")

SCENE_MANAGER.GetCurrentSceneName = function(self) return "other_scene" end
check(info.canNarrate() == false, "canNarrate returns false when scene does not match")

-- ============================================================================
-- canNarrate: SCENE_MANAGER throws → must return false, not propagate
-- ============================================================================

SCENE_MANAGER.GetCurrentSceneName = function(self) error("scene manager exploded") end
local result = info.canNarrate()
check(result == false, "canNarrate returns false (not throws) when SCENE_MANAGER errors")

-- Restore SCENE_MANAGER for subsequent tests
SCENE_MANAGER.GetCurrentSceneName = function(self) return "test_scene" end

-- ============================================================================
-- selectedNarrationFunction: healthy path
-- ============================================================================

local titleCalled = false
local dataCalled  = false

captured = {}
Narration.RegisterListNarration(
    "healthy_scene",
    function()
        dataCalled = true
        return { name = "Iron Sword", quality = 0, stackCount = 1 }
    end,
    function()
        titleCalled = true
        return "Inventory"
    end
)
local healthyInfo = captured["healthy_scene"]

local narrations = healthyInfo.selectedNarrationFunction()
check(type(narrations) == "table", "selectedNarrationFunction returns a table on healthy path")
check(titleCalled, "getTitleFn is called on healthy path")
check(dataCalled, "getSelectedDataFn is called on healthy path")

-- ============================================================================
-- selectedNarrationFunction: getTitleFn throws → empty table, no propagation
-- ============================================================================

captured = {}
Narration.RegisterListNarration(
    "throw_title",
    function() return { name = "Axe" } end,
    function() error("title fn exploded") end
)
local throwTitleInfo = captured["throw_title"]
local r1 = throwTitleInfo.selectedNarrationFunction()
check(type(r1) == "table", "selectedNarrationFunction returns table when getTitleFn throws")
check(#r1 == 0, "selectedNarrationFunction returns empty table when getTitleFn throws")

-- ============================================================================
-- selectedNarrationFunction: getSelectedDataFn throws → empty table, no propagation
-- ============================================================================

captured = {}
Narration.RegisterListNarration(
    "throw_data",
    function() error("data fn exploded") end
)
local throwDataInfo = captured["throw_data"]
local r2 = throwDataInfo.selectedNarrationFunction()
check(type(r2) == "table", "selectedNarrationFunction returns table when getSelectedDataFn throws")
check(#r2 == 0, "selectedNarrationFunction returns empty table when getSelectedDataFn throws")

-- ============================================================================
-- selectedNarrationFunction: both throw simultaneously
-- ============================================================================

captured = {}
Narration.RegisterListNarration(
    "throw_both",
    function() error("data boom") end,
    function() error("title boom") end
)
local throwBothInfo = captured["throw_both"]
local r3 = throwBothInfo.selectedNarrationFunction()
check(type(r3) == "table" and #r3 == 0, "selectedNarrationFunction is safe when both fns throw")

-- ============================================================================
-- canNarrate: SCENE_MANAGER is nil → false, not crash
-- ============================================================================

local savedSM = SCENE_MANAGER
SCENE_MANAGER = nil
local nilResult = (function()
    -- Simulate the canNarrate closure with current environment
    -- Register a new narration with nil SCENE_MANAGER
    local nilCaptured = {}
    SCREEN_NARRATION_MANAGER.RegisterCustomObject = function(self, name, info)
        nilCaptured[name] = info
        self.customObjectNarrationInfo[name] = info
    end
    Narration.RegisterListNarration("nil_sm_scene", function() return nil end)
    local nilInfo = nilCaptured["nil_sm_scene"]
    if nilInfo then
        return nilInfo.canNarrate()
    end
    return false
end)()
SCENE_MANAGER = savedSM
check(nilResult == false, "canNarrate returns false when SCENE_MANAGER is nil")

-- ============================================================================
-- QueueSceneNarration: guarded custom-object queue call
-- ============================================================================

captured = {}
SCREEN_NARRATION_MANAGER.customObjectNarrationInfo = {}
SCREEN_NARRATION_MANAGER.lastQueued = nil
Narration.RegisterListNarration("queue_scene", function() return nil end)
local queued = Narration.QueueSceneNarration("queue_scene", true)
check(queued == true, "QueueSceneNarration calls QueueCustomEntry for a registered scene")
check(SCREEN_NARRATION_MANAGER.lastQueued and SCREEN_NARRATION_MANAGER.lastQueued.name == "queue_scene",
    "QueueSceneNarration passes the scene name to QueueCustomEntry")
check(SCREEN_NARRATION_MANAGER.lastQueued and SCREEN_NARRATION_MANAGER.lastQueued.narrateHeader == true,
    "QueueSceneNarration forwards the narrateHeader flag")
check(SCREEN_NARRATION_MANAGER.lastQueued and SCREEN_NARRATION_MANAGER.lastQueued.narrationType == NARRATION_TYPE_UI_SCREEN,
    "QueueSceneNarration queues a UI screen narration type")

SCREEN_NARRATION_MANAGER.lastQueued = nil
local missingQueued = Narration.QueueSceneNarration("not_registered")
check(missingQueued == false, "QueueSceneNarration does not throw for an unregistered scene")
check(SCREEN_NARRATION_MANAGER.lastQueued == nil, "QueueSceneNarration skips unregistered scenes")

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
