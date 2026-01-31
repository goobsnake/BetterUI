--[[
File: tools/tests/test_dependency_resolver.lua
Purpose: Unit tests for DependencyResolver utility.
         These tests run standalone with a Lua interpreter (no ESO environment).

Usage:
  lua tools/tests/test_dependency_resolver.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

-- Mock BETTERUI namespace
BETTERUI = { CIM = {} }

function BETTERUI.Debug(msg)
    -- Silent in tests
end

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

-- Inline DependencyResolver implementation for standalone testing
BETTERUI.CIM.DependencyResolver = {
    _modules = {},
}

function BETTERUI.CIM.DependencyResolver.Register(moduleName, dependencies, priority)
    BETTERUI.CIM.DependencyResolver._modules[moduleName] = {
        name = moduleName,
        dependencies = dependencies or {},
        priority = priority or 100,
    }
end

function BETTERUI.CIM.DependencyResolver.Validate()
    local modules = BETTERUI.CIM.DependencyResolver._modules
    local visited = {}
    local inStack = {}

    local function visit(name, path)
        if inStack[name] then
            return false, "Circular dependency: " .. table.concat(path, " -> ") .. " -> " .. name
        end
        if visited[name] then
            return true, nil
        end

        visited[name] = true
        inStack[name] = true
        table.insert(path, name)

        local mod = modules[name]
        if mod and mod.dependencies then
            for _, dep in ipairs(mod.dependencies) do
                local ok, err = visit(dep, path)
                if not ok then
                    return false, err
                end
            end
        end

        table.remove(path)
        inStack[name] = false
        return true, nil
    end

    for name, _ in pairs(modules) do
        local ok, err = visit(name, {})
        if not ok then
            return false, err
        end
    end

    return true, nil
end

function BETTERUI.CIM.DependencyResolver.Resolve()
    local ok, err = BETTERUI.CIM.DependencyResolver.Validate()
    if not ok then
        return nil, err
    end

    local modules = BETTERUI.CIM.DependencyResolver._modules
    local sorted = {}
    local visited = {}

    local function visit(name)
        if visited[name] then return end
        visited[name] = true

        local mod = modules[name]
        if mod and mod.dependencies then
            for _, dep in ipairs(mod.dependencies) do
                visit(dep)
            end
        end

        table.insert(sorted, name)
    end

    -- Sort by priority first
    local byPriority = {}
    for name, mod in pairs(modules) do
        table.insert(byPriority, { name = name, priority = mod.priority or 100 })
    end
    table.sort(byPriority, function(a, b)
        return a.priority < b.priority
    end)

    -- Then topological sort
    for _, entry in ipairs(byPriority) do
        visit(entry.name)
    end

    return sorted, nil
end

function BETTERUI.CIM.DependencyResolver.GetDependenciesFor(moduleName)
    local mod = BETTERUI.CIM.DependencyResolver._modules[moduleName]
    if mod then
        return mod.dependencies or {}
    end
    return {}
end

function BETTERUI.CIM.DependencyResolver.Clear()
    BETTERUI.CIM.DependencyResolver._modules = {}
end

-- ============================================================================
-- TEST HARNESS
-- ============================================================================

local tests_passed = 0
local tests_failed = 0

local function assert_equal(expected, actual, message)
    if expected == actual then
        tests_passed = tests_passed + 1
        print("  ✓ " .. message)
    else
        tests_failed = tests_failed + 1
        print("  ✗ " .. message)
        print("    Expected: " .. tostring(expected))
        print("    Actual:   " .. tostring(actual))
    end
end

local function assert_true(value, message)
    assert_equal(true, value, message)
end

local function assert_false(value, message)
    assert_equal(false, value, message)
end

local function assert_nil(value, message)
    assert_equal(nil, value, message)
end

local function assert_not_nil(value, message)
    if value ~= nil then
        tests_passed = tests_passed + 1
        print("  ✓ " .. message)
    else
        tests_failed = tests_failed + 1
        print("  ✗ " .. message)
        print("    Expected non-nil value")
    end
end

local function reset()
    BETTERUI.CIM.DependencyResolver.Clear()
end

-- ============================================================================
-- TESTS
-- ============================================================================

print("\n=== DependencyResolver Tests ===\n")

-- Test 1: Register adds module
print("Test: Register adds module")
reset()
BETTERUI.CIM.DependencyResolver.Register("ModuleA", {}, 50)
local deps = BETTERUI.CIM.DependencyResolver.GetDependenciesFor("ModuleA")
assert_not_nil(deps, "Module A is registered")
assert_equal(0, #deps, "Module A has no dependencies")

-- Test 2: Register with dependencies
print("\nTest: Register with dependencies")
reset()
BETTERUI.CIM.DependencyResolver.Register("ModuleB", { "ModuleA" }, 100)
BETTERUI.CIM.DependencyResolver.Register("ModuleA", {}, 50)
local depsB = BETTERUI.CIM.DependencyResolver.GetDependenciesFor("ModuleB")
assert_equal(1, #depsB, "Module B has 1 dependency")
assert_equal("ModuleA", depsB[1], "Module B depends on Module A")

-- Test 3: Validate passes with no circular deps
print("\nTest: Validate passes with no circular dependencies")
reset()
BETTERUI.CIM.DependencyResolver.Register("A", {})
BETTERUI.CIM.DependencyResolver.Register("B", { "A" })
BETTERUI.CIM.DependencyResolver.Register("C", { "B" })
local ok, err = BETTERUI.CIM.DependencyResolver.Validate()
assert_true(ok, "Validation passes for A -> B -> C chain")
assert_nil(err, "No error message")

-- Test 4: Validate fails with circular deps
print("\nTest: Validate fails with circular dependencies")
reset()
BETTERUI.CIM.DependencyResolver.Register("X", { "Z" })
BETTERUI.CIM.DependencyResolver.Register("Y", { "X" })
BETTERUI.CIM.DependencyResolver.Register("Z", { "Y" })
local ok2, err2 = BETTERUI.CIM.DependencyResolver.Validate()
assert_false(ok2, "Validation fails for X -> Y -> Z -> X cycle")
assert_not_nil(err2, "Error message provided")

-- Test 5: Resolve returns correct order
print("\nTest: Resolve returns correct load order")
reset()
BETTERUI.CIM.DependencyResolver.Register("Core", {}, 10)
BETTERUI.CIM.DependencyResolver.Register("Utils", { "Core" }, 20)
BETTERUI.CIM.DependencyResolver.Register("Feature", { "Utils" }, 30)
local order, resolveErr = BETTERUI.CIM.DependencyResolver.Resolve()
assert_not_nil(order, "Resolve returns order")
assert_nil(resolveErr, "No error")
assert_equal(3, #order, "All 3 modules in order")
-- Core must come before Utils, Utils before Feature
local coreIdx, utilsIdx, featureIdx
for i, name in ipairs(order) do
    if name == "Core" then coreIdx = i end
    if name == "Utils" then utilsIdx = i end
    if name == "Feature" then featureIdx = i end
end
assert_true(coreIdx < utilsIdx, "Core loads before Utils")
assert_true(utilsIdx < featureIdx, "Utils loads before Feature")

-- Test 6: GetDependenciesFor non-existent module
print("\nTest: GetDependenciesFor non-existent module")
reset()
local missing = BETTERUI.CIM.DependencyResolver.GetDependenciesFor("NonExistent")
assert_equal(0, #missing, "Returns empty table for non-existent module")

-- Test 7: Empty modules validates OK
print("\nTest: Empty modules validates OK")
reset()
local okEmpty, errEmpty = BETTERUI.CIM.DependencyResolver.Validate()
assert_true(okEmpty, "Empty registry is valid")

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
