--[[
File: tools/tests/test_control_cache.lua
Purpose: Unit tests for ControlCache lazy-caching factory.
         These tests run standalone with a Lua interpreter (no ESO environment).

Usage:
  lua tools/tests/test_control_cache.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = { CIM = {} }

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

dofile("Modules/CIM/Core/Window/ControlCache.lua")

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

local function assert_true(value, message)
    assert_equal(true, value, message)
end

-- ============================================================================
-- MOCK HELPER
-- ============================================================================

local function MockParent(children)
    local lookupCount = 0
    return {
        GetNamedChild = function(self, name)
            lookupCount = lookupCount + 1
            return children[name]
        end,
        GetLookupCount = function(self) return lookupCount end,
    }
end

-- ============================================================================
-- TESTS
-- ============================================================================

print("\n=== ControlCache Tests ===\n")

-- BUI-CLEAN-002: the generic Create/CacheChildren exports were removed as
-- production-dead; CacheButtonChildren is the live surface.
print("Test: dead generic exports stay removed")
assert_equal(nil, BETTERUI.CIM.ControlCache.Create, "Create stays removed")
assert_equal(nil, BETTERUI.CIM.ControlCache.CacheChildren, "CacheChildren stays removed")

-- Test: CacheButtonChildren returns empty table for nil button
print("\nTest: CacheButtonChildren returns empty table for nil button")
local cache9 = BETTERUI.CIM.ControlCache.CacheButtonChildren(nil)
local count9 = 0
for _ in pairs(cache9) do count9 = count9 + 1 end
assert_equal(0, count9, "Empty table for nil button")

-- Test 10: CacheButtonChildren populates standard children
print("\nTest: CacheButtonChildren populates standard children")
local iconMock = { name = "Icon" }
local cdMock = { name = "Cooldown" }
local button10 = MockParent({ Icon = iconMock, Cooldown = cdMock })
local cache10 = BETTERUI.CIM.ControlCache.CacheButtonChildren(button10)
assert_equal(iconMock, cache10.Icon, "Icon child cached")
assert_equal(cdMock, cache10.Cooldown, "Cooldown child cached")

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
