--[[
File: tools/tests/test_control_utils.lua
Purpose: Canonical ControlUtils suite covering lookup behavior, cache invalidation,
         and self-describing trace/warn payloads.

Usage:
  lua tools/tests/test_control_utils.lua
]]

BETTERUI = { CIM = {} }
_G = _G or {}

BETTERUI.CIM.Names = {
    Control = function(control, fallback)
        if type(control) == "table" and control.name then
            return control.name
        end
        return fallback or "<unnamed>"
    end,
}

local capturedExtraSkip = nil
BETTERUI.CIM.DebugInfo = {
    CaptureCallerFrame = function(_level, extraSkip)
        capturedExtraSkip = extraSkip
        return "Modules/CIM/Bank.lua:21:setupFooter"
    end,
}

local captured = { warns = {}, traces = {} }
BETTERUI.Log = {
    CATEGORY = { CONTROL = "CONTROL" },
    IsActive = function() return true end,
    Warn = function(cat, msg, data)
        captured.warns[#captured.warns + 1] = { cat = cat, msg = msg, data = data }
    end,
    Trace = function(cat, msg, data)
        captured.traces[#captured.traces + 1] = { cat = cat, msg = msg, data = data }
    end,
}

local function MockControl(name, children, parent)
    local control = {
        name = name,
        _children = children or {},
        _parent = parent,
    }
    function control:GetName() return self.name end
    function control:GetNamedChild(childName) return self._children[childName] end
    function control:GetParent() return self._parent end
    return control
end

dofile("Modules/CIM/Core/Window/ControlUtils.lua")
local CU = BETTERUI.ControlUtils

local passed, failed = 0, 0

local function check(condition, message, actual)
    if condition then
        passed = passed + 1
        print("  [OK] " .. message)
    else
        failed = failed + 1
        print("  [X] " .. message)
        if actual ~= nil then
            print("    Actual: " .. tostring(actual))
        end
    end
end

local function assert_equal(expected, actual, message)
    check(expected == actual, message, actual)
    if expected ~= actual then
        print("    Expected: " .. tostring(expected))
    end
end

print("\n=== ControlUtils Tests ===\n")

print("Test: FindControl returns nil for nil parent")
local nilParent = CU.FindControl(nil, "Child")
assert_equal(nil, nilParent, "Returns nil for nil parent")
captured.warns = {}
captured.traces = {}

print("\nTest: FindControl resolves direct children and caches the hit")
CU.InvalidateControlCache()
local child = MockControl("ChildCtrl")
local parent = MockControl("BUI_Bank", { Child = child, ChildList = child })
local directHit = CU.FindControl(parent, "Child", "BankSetup")
assert_equal(child, directHit, "FindControl resolves a direct child")
local resolvedTrace = captured.traces[#captured.traces]
check(resolvedTrace.data.via == "child" and resolvedTrace.data.control == "Child",
    "resolved trace records via=child + control name")
check(resolvedTrace.data.parent == "BUI_Bank", "resolved trace names the parent")
check(resolvedTrace.data.caller == "BankSetup", "resolved trace carries the caller label")
local traceCountBeforeCacheHit = #captured.traces
assert_equal(child, CU.FindControl(parent, "Child", "BankSetup"), "Cache hit returns the same child")
assert_equal(traceCountBeforeCacheHit, #captured.traces, "Cache hit does not emit another trace")

print("\nTest: InvalidateControlCache clears hit and miss dedupe state")
CU.InvalidateControlCache()
assert_equal(child, CU.FindControl(parent, "Child", "BankSetup"), "Still resolves after cache invalidation")
CU.FindControl(parent, "Missing", "FooterSetup")
assert_equal(1, #captured.warns, "First miss warns once")
CU.FindControl(parent, "Missing", "FooterSetup")
assert_equal(1, #captured.warns, "Repeated miss does not re-warn before invalidation")
CU.InvalidateControlCache()
CU.FindControl(parent, "Missing", "FooterSetup")
assert_equal(2, #captured.warns, "InvalidateControlCache lets the same miss warn again")

print("\nTest: Miss warnings remain self-describing")
local firstWarn = captured.warns[1]
assert_equal("CONTROL", firstWarn.cat, "Miss warning uses the CONTROL category")
check(firstWarn.msg:find("Missing", 1, true) ~= nil and firstWarn.msg:find("BUI_Bank", 1, true) ~= nil,
    "Miss warning message names the control + parent")
check(firstWarn.data.control == "Missing" and firstWarn.data.parent == "BUI_Bank",
    "Miss warning payload names control + parent")
assert_equal("FooterSetup", firstWarn.data.caller, "Miss warning payload carries the caller label")
assert_equal("Modules/CIM/Bank.lua:21:setupFooter", firstWarn.data.src,
    "Miss warning payload carries the captured source")
check(type(capturedExtraSkip) == "table" and tostring(capturedExtraSkip[1]):find("ControlUtils") ~= nil,
    "CaptureCallerFrame receives a ControlUtils skip-pattern")

print("\nTest: FindControl resolves ancestor-global and direct-global fallbacks")
CU.InvalidateControlCache()
local ancestorGlobal = MockControl("BUI_BankInfoBar")
_G["BUI_BankInfoBar"] = ancestorGlobal
assert_equal(ancestorGlobal, CU.FindControl(parent, "InfoBar", "BankSetup"),
    "FindControl resolves via ancestor-global name")
assert_equal("ancestorGlobal", captured.traces[#captured.traces].data.via,
    "Resolved trace records via=ancestorGlobal")
local directGlobal = MockControl("StandaloneCtrl")
_G["StandaloneCtrl"] = directGlobal
assert_equal(directGlobal, CU.FindControl(parent, "StandaloneCtrl", "BankSetup"),
    "FindControl resolves via direct global fallback")
assert_equal("global", captured.traces[#captured.traces].data.via,
    "Resolved trace records via=global")
_G["BUI_BankInfoBar"] = nil
_G["StandaloneCtrl"] = nil

print("\nTest: FindControl walks parent hierarchy and returns nil when nothing matches")
CU.InvalidateControlCache()
local deepCtrl = MockControl("DeepChild")
local grandparent = MockControl("GrandParent", {})
local midParent = MockControl("MidParent", {}, grandparent)
local bottomParent = MockControl("BottomParent", {}, midParent)
_G["GrandParentLabel"] = deepCtrl
assert_equal(deepCtrl, CU.FindControl(bottomParent, "Label", "HierarchySetup"),
    "FindControl walks parent hierarchy")
_G["GrandParentLabel"] = nil
local emptyParent = MockControl("Empty", {})
assert_equal(nil, CU.FindControl(emptyParent, "NonExistent", "HierarchySetup"),
    "FindControl returns nil when nothing is found")

print("\nTest: FindOptionalControl misses quietly")
CU.InvalidateControlCache()
local warnsBeforeOptional = #captured.warns
assert_equal(nil, CU.FindOptionalControl(parent, "OptionalAdornment", "SkinSetup"),
    "FindOptionalControl returns nil for a missing optional control")
assert_equal(warnsBeforeOptional, #captured.warns, "FindOptionalControl miss does not warn")

print("\nTest: nil-parent and unlabeled misses stay self-describing")
CU.FindControl(nil, "Orphan", "X")
local nilParentWarn = captured.warns[#captured.warns]
check(nilParentWarn.data.control == "Orphan" and nilParentWarn.data.parent == "<no-parent>",
    "Nil-parent miss names the control + <no-parent>")
CU.FindControl(parent, "MissingNoCaller")
assert_equal("<unspecified>", captured.warns[#captured.warns].data.caller,
    "Nil caller normalizes to <unspecified>")

print("\nTest: missing Log.Warn does not raise")
local realLog = BETTERUI.Log
BETTERUI.Log = { CATEGORY = { CONTROL = "CONTROL" }, IsActive = function() return false end }
check(pcall(CU.FindControl, parent, "MissingPartialLog", "X"), "Miss path does not raise when Log.Warn is absent")
BETTERUI.Log = realLog

print("\n=== Test Summary ===")
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))
if failed > 0 then
    os.exit(1)
else
    print("\nAll tests passed!")
    os.exit(0)
end
