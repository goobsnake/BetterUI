--[[
File: tools/tests/test_control_utils.lua
Purpose: Unit tests for ControlUtils — FindControl and InvalidateControlCache.

Usage:
  lua tools/tests/test_control_utils.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = {}
_G = _G or {}

-- Mock control objects
local function MockControl(name, children, parent)
    local ctrl = {
        _name = name,
        _children = children or {},
        _parent = parent,
    }
    function ctrl:GetName() return self._name end
    function ctrl:GetNamedChild(childName)
        return self._children[childName]
    end
    function ctrl:GetParent() return self._parent end
    return ctrl
end

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

dofile("Modules/CIM/Core/Window/ControlUtils.lua")

-- ============================================================================
-- TEST HARNESS
-- ============================================================================

local tests_passed = 0
local tests_failed = 0

local function assert_equal(expected, actual, message)
    if expected == actual then
        tests_passed = tests_passed + 1
        print("  [OK] " .. message)
    else
        tests_failed = tests_failed + 1
        print("  [X] " .. message)
        print("    Expected: " .. tostring(expected))
        print("    Actual:   " .. tostring(actual))
    end
end

local function assert_nil(value, message)
    assert_equal(nil, value, message)
end

local function assert_not_nil(value, message)
    if value ~= nil then
        tests_passed = tests_passed + 1
        print("  [OK] " .. message)
    else
        tests_failed = tests_failed + 1
        print("  [X] " .. message .. " (got nil)")
    end
end

-- ============================================================================
-- TESTS
-- ============================================================================

print("\n=== ControlUtils Tests ===\n")

-- Test 1: FindControl returns nil for nil parent
print("Test: FindControl returns nil for nil parent")
local result1 = BETTERUI.ControlUtils.FindControl(nil, "Child")
assert_nil(result1, "Returns nil for nil parent")

-- Test 2: FindControl finds direct child
print("\nTest: FindControl finds direct child")
BETTERUI.ControlUtils.InvalidateControlCache()
local child = MockControl("ChildCtrl")
local parent = MockControl("ParentCtrl", { Child = child })
local result2 = BETTERUI.ControlUtils.FindControl(parent, "Child")
assert_equal(child, result2, "Finds direct child by name")

-- Test 3: FindControl caches results
print("\nTest: FindControl caches results")
-- Second call should use cache
local result3 = BETTERUI.ControlUtils.FindControl(parent, "Child")
assert_equal(child, result3, "Returns cached result")

-- Test 4: InvalidateControlCache clears cache
print("\nTest: InvalidateControlCache clears cache")
BETTERUI.ControlUtils.InvalidateControlCache()
-- After invalidation, it should still find via lookup
local result4 = BETTERUI.ControlUtils.FindControl(parent, "Child")
assert_equal(child, result4, "Still finds after cache clear")

-- Test 5: FindControl finds via global name using parent hierarchy
print("\nTest: FindControl finds via global name using parent hierarchy")
BETTERUI.ControlUtils.InvalidateControlCache()
local globalCtrl = MockControl("GlobalTarget")
local parentNoChild = MockControl("MyParent", {})
_G["MyParentTarget"] = globalCtrl
local result5 = BETTERUI.ControlUtils.FindControl(parentNoChild, "Target")
assert_equal(globalCtrl, result5, "Finds via global parent name concatenation")
_G["MyParentTarget"] = nil

-- Test 6: FindControl falls back to direct global name
print("\nTest: FindControl falls back to direct global name")
BETTERUI.ControlUtils.InvalidateControlCache()
local directGlobal = MockControl("DirectGlobal")
_G["DirectGlobal"] = directGlobal
local parentEmpty = MockControl("NoMatch", {})
local result6 = BETTERUI.ControlUtils.FindControl(parentEmpty, "DirectGlobal")
assert_equal(directGlobal, result6, "Finds via direct global name")
_G["DirectGlobal"] = nil

-- Test 7: FindControl returns nil when nothing found
print("\nTest: FindControl returns nil when nothing found")
BETTERUI.ControlUtils.InvalidateControlCache()
local emptyParent = MockControl("Empty", {})
local result7 = BETTERUI.ControlUtils.FindControl(emptyParent, "NonExistent")
assert_nil(result7, "Returns nil when control not found")

-- Test 8: FindControl walks parent hierarchy (up to 6 levels)
print("\nTest: FindControl walks parent hierarchy")
BETTERUI.ControlUtils.InvalidateControlCache()
local deepCtrl = MockControl("DeepChild")
local grandparent = MockControl("GrandParent", {})
local midParent = MockControl("MidParent", {}, grandparent)
local bottomParent = MockControl("BottomParent", {}, midParent)
_G["GrandParentLabel"] = deepCtrl
local result8 = BETTERUI.ControlUtils.FindControl(bottomParent, "Label")
assert_equal(deepCtrl, result8, "Finds via grandparent name concatenation")
_G["GrandParentLabel"] = nil

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
