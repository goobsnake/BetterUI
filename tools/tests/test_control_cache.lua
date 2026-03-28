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

-- Test 1: Create returns a callable function
print("Test: Create returns a callable function")
local parent1 = MockParent({ Icon = {} })
local lookup1 = BETTERUI.CIM.ControlCache.Create(parent1)
assert_equal("function", type(lookup1), "Create returns a function")

-- Test 2: Lookup returns the correct child
print("\nTest: Lookup returns the correct child")
local iconCtrl = { name = "icon" }
local parent2 = MockParent({ Icon = iconCtrl })
local lookup2 = BETTERUI.CIM.ControlCache.Create(parent2)
local result2 = lookup2("Icon")
assert_equal(iconCtrl, result2, "Returns correct child control")

-- Test 3: Second lookup uses cache (no repeat GetNamedChild call)
print("\nTest: Second lookup uses cache")
local labelCtrl = { name = "label" }
local parent3 = MockParent({ Label = labelCtrl })
local lookup3 = BETTERUI.CIM.ControlCache.Create(parent3)
lookup3("Label") -- first call
lookup3("Label") -- second call (cached)
assert_equal(1, parent3:GetLookupCount(), "GetNamedChild called only once for repeated lookups")

-- Test 4: Cache prevents repeated lookups (verified via count)
print("\nTest: Cache prevents repeated GetNamedChild calls")
local btnCtrl = { name = "btn" }
local parent4 = MockParent({ Button = btnCtrl })
local lookupCount4 = 0
parent4.GetNamedChild = function(self, name)
    lookupCount4 = lookupCount4 + 1
    return btnCtrl
end
local lookup4 = BETTERUI.CIM.ControlCache.Create(parent4)
lookup4("Button")
lookup4("Button")
lookup4("Button")
assert_equal(1, lookupCount4, "GetNamedChild called exactly once for repeated lookups")

-- Test 5: Different names each trigger one lookup
print("\nTest: Different names each trigger one lookup")
local lookupCount5 = 0
local children5 = { A = {}, B = {}, C = {} }
local parent5 = MockParent(children5)
parent5.GetNamedChild = function(self, name)
    lookupCount5 = lookupCount5 + 1
    return children5[name]
end
local lookup5 = BETTERUI.CIM.ControlCache.Create(parent5)
lookup5("A")
lookup5("B")
lookup5("C")
lookup5("A") -- cached
lookup5("B") -- cached
assert_equal(3, lookupCount5, "Three unique lookups, two cached hits")

-- Test 6: Nil child is returned (not cached as miss)
print("\nTest: Missing child returns nil")
local parent6 = MockParent({})
local lookup6 = BETTERUI.CIM.ControlCache.Create(parent6)
local result6 = lookup6("NonExistent")
assert_equal(nil, result6, "Returns nil for missing child")

-- Test 7: CacheChildren eagerly caches all names
print("\nTest: CacheChildren eagerly caches all listed names")
local childA = { name = "A" }
local childB = { name = "B" }
local parent7 = MockParent({ ChildA = childA, ChildB = childB })
local cache7 = BETTERUI.CIM.ControlCache.CacheChildren(parent7, { "ChildA", "ChildB" })
assert_equal(childA, cache7.ChildA, "ChildA cached correctly")
assert_equal(childB, cache7.ChildB, "ChildB cached correctly")

-- Test 8: CacheChildren handles missing children
print("\nTest: CacheChildren handles missing children gracefully")
local parent8 = MockParent({ OnlyThis = {} })
local cache8 = BETTERUI.CIM.ControlCache.CacheChildren(parent8, { "OnlyThis", "Missing" })
assert_true(cache8.OnlyThis ~= nil, "Existing child is cached")
assert_equal(nil, cache8.Missing, "Missing child is nil")

-- Test 9: CacheButtonChildren returns empty table for nil button
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
