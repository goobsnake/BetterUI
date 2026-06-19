--[[
File: tools/tests/test_settings_accessor.lua
Purpose: Tests for SettingsAccessor.lua — GetModuleSettings, GetSetting, SetSetting,
         CreateSettingAccessors, CreateColorSettingAccessors, and ClampInteger.
Usage: lua tools/tests/test_settings_accessor.lua
]]

-- ============================================================================
-- STUBS
-- ============================================================================

BETTERUI = {
    CIM = {
        Font = {
            CHOICES = {},
            VALUES = {},
            STYLE_CHOICES = {},
            STYLE_VALUES = {},
            DEFAULTS = {},
            CreateModuleDescriptors = function()
                return {
                    name = function() return "name-font" end,
                    column = function() return "column-font" end,
                }
            end,
        },
        Settings = {
            GetSettingDefault = function(moduleName, key)
                if moduleName == "Mod" and key == "missingViaMetadata" then
                    return 77
                end
                return nil
            end,
        },
    },
}
CALLBACK_MANAGER = {
    _fired = {},
    FireCallbacks = function(self, event, ...)
        self._fired[#self._fired + 1] = { event = event, args = {...} }
    end
}

-- Load the module under test
dofile("Modules/CIM/Core/Settings/SettingsAccessor.lua")

-- ============================================================================
-- TEST HELPERS
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

local function assert_true(value, message) assert_equal(true, value, message) end
local function assert_nil(value, message) assert_equal(nil, value, message) end

local function assert_not_nil(value, message)
    if value ~= nil then
        tests_passed = tests_passed + 1
        print("  [OK] " .. message)
    else
        tests_failed = tests_failed + 1
        print("  [X] " .. message .. " (got nil)")
    end
end

local function reset_settings()
    BETTERUI.Settings = { Modules = {} }
    CALLBACK_MANAGER._fired = {}
end

-- ============================================================================
-- GetModuleSettings
-- ============================================================================

print("\n=== GetModuleSettings ===\n")

do
    reset_settings()
    BETTERUI.Settings.Modules["CIM"] = { m_enabled = true, fontSize = 14 }
    local s = BETTERUI.GetModuleSettings("CIM")
    assert_true(s.m_enabled, "returns module settings when present")
    assert_equal(14, s.fontSize, "returns correct setting value")
end

do
    reset_settings()
    local s = BETTERUI.GetModuleSettings("Missing")
    assert_not_nil(s, "returns table when module missing")
    assert_nil(next(s), "returned table is empty")
end

do
    reset_settings()
    local defaults = { x = 42 }
    local s = BETTERUI.GetModuleSettings("Missing", defaults)
    assert_equal(42, s.x, "returns defaults when module missing")
end

do
    BETTERUI.Settings = nil
    local s = BETTERUI.GetModuleSettings("Anything")
    assert_not_nil(s, "returns table when Settings is nil")
end

-- ============================================================================
-- GetModuleSettingsLive
-- ============================================================================

print("\n=== GetModuleSettingsLive ===\n")

do
    reset_settings()
    local existing = { threshold = 3 }
    BETTERUI.Settings.Modules["Live"] = existing
    local live = BETTERUI.GetModuleSettingsLive("Live", { threshold = 99 })
    assert_true(live == existing, "returns existing live module table by reference")
    live.threshold = 9
    assert_equal(9, BETTERUI.Settings.Modules["Live"].threshold, "mutating live table writes through to persisted settings")
end

do
    reset_settings()
    local defaults = { enabled = true, nested = { alpha = 1 } }
    local live = BETTERUI.GetModuleSettingsLive("MissingLive", defaults)
    assert_true(live == BETTERUI.Settings.Modules["MissingLive"],
        "missing module fallback is persisted and returned as the live table")
    assert_equal(true, BETTERUI.Settings.Modules["MissingLive"].enabled, "persisted fallback copies scalar defaults")
    assert_equal(1, BETTERUI.Settings.Modules["MissingLive"].nested.alpha, "persisted fallback copies nested defaults")
    live.nested.alpha = 5
    assert_equal(1, defaults.nested.alpha, "persisted fallback deep-clones defaults instead of sharing references")
end

do
    BETTERUI.Settings = nil
    local live = BETTERUI.GetModuleSettingsLive("FreshLive")
    assert_true(live == BETTERUI.Settings.Modules["FreshLive"], "live accessor initializes and returns a persisted table when missing")
    assert_not_nil(BETTERUI.Settings.Modules["FreshLive"], "missing live module creates persisted module settings")
end

-- ============================================================================
-- GetSetting
-- ============================================================================

print("\n=== GetSetting ===\n")

do
    reset_settings()
    BETTERUI.Settings.Modules["Inv"] = { showPrice = false, count = 0 }
    assert_equal(false, BETTERUI.GetSetting("Inv", "showPrice", true), "returns existing value (false)")
    assert_equal(0, BETTERUI.GetSetting("Inv", "count", 99), "returns existing value (0)")
end

do
    reset_settings()
    assert_equal("default", BETTERUI.GetSetting("Missing", "key", "default"), "returns default for missing module")
end

do
    reset_settings()
    BETTERUI.Settings.Modules["Inv"] = {}
    assert_equal(42, BETTERUI.GetSetting("Inv", "missing", 42), "returns default for missing key")
end

do
    reset_settings()
    assert_equal(77, BETTERUI.GetSetting("Mod", "missingViaMetadata"), "generic getter reads metadata-backed default")
end

do
    reset_settings()
    BETTERUI.Settings.Modules["Mod"] = { options = { enabled = true, nested = { size = 4 } } }
    local value = BETTERUI.GetSetting("Mod", "options")
    value.enabled = false
    value.nested.size = 9
    assert_equal(true, BETTERUI.Settings.Modules["Mod"].options.enabled, "table setting getter returns detached top-level table")
    assert_equal(4, BETTERUI.Settings.Modules["Mod"].options.nested.size, "table setting getter returns detached nested table")
end

do
    reset_settings()
    local defaultOptions = { enabled = true, nested = { size = 4 } }
    local value = BETTERUI.GetSetting("Mod", "missingOptions", defaultOptions)
    value.enabled = false
    value.nested.size = 9
    assert_equal(true, defaultOptions.enabled, "table default getter returns detached top-level table")
    assert_equal(4, defaultOptions.nested.size, "table default getter returns detached nested table")
end

-- ============================================================================
-- SetSetting
-- ============================================================================

print("\n=== SetSetting ===\n")

do
    reset_settings()
    BETTERUI.Settings.Modules["CIM"] = {}
    BETTERUI.SetSetting("CIM", "fontSize", 18)
    assert_equal(18, BETTERUI.Settings.Modules["CIM"].fontSize, "sets value correctly")
end

do
    reset_settings()
    BETTERUI.SetSetting("NewMod", "key", "val")
    assert_equal("val", BETTERUI.Settings.Modules["NewMod"].key, "creates module table if missing")
end

do
    reset_settings()
    BETTERUI.SetSetting("CIM", nil, "val")
    tests_passed = tests_passed + 1
    print("  [OK] nil key does not crash")
end

do
    reset_settings()
    BETTERUI.Settings.Modules["CIM"] = {}
    BETTERUI.SetSetting("CIM", "x", 1)
    assert_equal(1, #CALLBACK_MANAGER._fired, "fires callback on set")
    assert_equal("BETTERUI_EVENT_SETTING_CHANGED", CALLBACK_MANAGER._fired[1].event, "correct callback event")
    assert_equal("CIM", CALLBACK_MANAGER._fired[1].args[1], "callback has module name")
    assert_equal("x", CALLBACK_MANAGER._fired[1].args[2], "callback has key")
    assert_equal(1, CALLBACK_MANAGER._fired[1].args[3], "callback has value")
end

do
    BETTERUI.Settings = nil
    local ok = BETTERUI.SetSetting("CIM", "x", 1)
    assert_equal(true, ok, "SetSetting reports success when creating root settings table")
    assert_equal(1, BETTERUI.Settings.Modules["CIM"].x, "nil Settings auto-creates settings tree")
end

-- ============================================================================
-- CreateSettingAccessors
-- ============================================================================

print("\n=== CreateSettingAccessors ===\n")

do
    reset_settings()
    BETTERUI.Settings.Modules["Mod"] = { fontSize = 16 }
    local factory = BETTERUI.CreateSettingAccessors("Mod")
    local getFunc, setFunc = factory("fontSize", 12)
    assert_equal(16, getFunc(), "getter returns stored value")
end

do
    reset_settings()
    BETTERUI.Settings.Modules["Mod"] = {}
    local factory = BETTERUI.CreateSettingAccessors("Mod")
    local getFunc, _ = factory("missing", 99)
    assert_equal(99, getFunc(), "getter returns default when key missing")
end

do
    reset_settings()
    BETTERUI.Settings.Modules["Mod"] = {}
    local callbackRan = false
    local factory = BETTERUI.CreateSettingAccessors("Mod", function() callbackRan = true end)
    local _, setFunc = factory("x", 0)
    setFunc(42)
    assert_equal(42, BETTERUI.Settings.Modules["Mod"].x, "setter writes value")
    assert_true(callbackRan, "setter runs callback")
end

do
    reset_settings()
    BETTERUI.Settings.Modules["Mod"] = { flag = false }
    local factory = BETTERUI.CreateSettingAccessors("Mod")
    local getFunc, _ = factory("flag", true)
    assert_equal(false, getFunc(), "getter returns false (not default)")
end

do
    BETTERUI.Settings = nil
    local factory = BETTERUI.CreateSettingAccessors("Mod")
    local getFunc, _ = factory("missing", 12)
    assert_equal(12, getFunc(), "getter returns default when settings tree is absent")
end

do
    reset_settings()
    BETTERUI.Mod = {}
    BETTERUI.CIM.RegisterModuleAccessors("Mod")
    assert_equal(BETTERUI.GetSetting("Mod", "missingViaMetadata"), BETTERUI.Mod.GetSetting("missingViaMetadata"),
        "module accessor mirrors generic getter metadata default semantics")
    assert_equal(BETTERUI.GetSetting("Mod", "noDefault"), BETTERUI.Mod.GetSetting("noDefault"),
        "module accessor mirrors generic getter nil-default semantics")
end

-- ============================================================================
-- CreateColorSettingAccessors
-- ============================================================================

print("\n=== CreateColorSettingAccessors ===\n")

do
    reset_settings()
    BETTERUI.Settings.Modules["Mod"] = { myColor = { 0.5, 0.6, 0.7, 0.8 } }
    local factory = BETTERUI.CreateColorSettingAccessors("Mod")
    local getFunc, setFunc = factory("myColor", { 1, 1, 1, 1 })
    local r, g, b, a = getFunc()
    assert_equal(0.5, r, "color getter returns r")
    assert_equal(0.6, g, "color getter returns g")
    assert_equal(0.7, b, "color getter returns b")
    assert_equal(0.8, a, "color getter returns a")
end

do
    reset_settings()
    BETTERUI.Settings.Modules["Mod"] = {}
    local factory = BETTERUI.CreateColorSettingAccessors("Mod")
    local getFunc, _ = factory("missing", { 0.1, 0.2, 0.3, 0.4 })
    local r, g, b, a = getFunc()
    assert_equal(0.1, r, "color getter returns default r")
    assert_equal(0.2, g, "color getter returns default g")
    assert_equal(0.3, b, "color getter returns default b")
    assert_equal(0.4, a, "color getter returns default a")
end

do
    reset_settings()
    BETTERUI.Settings.Modules["Mod"] = {}
    local factory = BETTERUI.CreateColorSettingAccessors("Mod")
    local _, setFunc = factory("myColor", { 1, 1, 1, 1 })
    setFunc(0.2, 0.3, 0.4, 0.9)
    local stored = BETTERUI.Settings.Modules["Mod"].myColor
    assert_equal(0.2, stored[1], "color setter stores r")
    assert_equal(0.3, stored[2], "color setter stores g")
    assert_equal(0.4, stored[3], "color setter stores b")
    assert_equal(0.9, stored[4], "color setter stores a")
end

do
    reset_settings()
    BETTERUI.Settings.Modules["Mod"] = { c = { 0.5, 0.6, 0.7 } }
    local factory = BETTERUI.CreateColorSettingAccessors("Mod")
    local getFunc, _ = factory("c", { 1, 1, 1, 1 })
    local _, _, _, a = getFunc()
    assert_equal(1, a, "color alpha defaults to 1 when missing")
end

-- ============================================================================
-- ClampInteger
-- ============================================================================

print("\n=== ClampInteger ===\n")

do
    assert_equal(5, BETTERUI.ClampInteger(5, 1, 10, 1), "value in range returned as-is")
    assert_equal(1, BETTERUI.ClampInteger(-3, 1, 10, 1), "below min returns min")
    assert_equal(10, BETTERUI.ClampInteger(15, 1, 10, 1), "above max returns max")
    assert_equal(7, BETTERUI.ClampInteger(7.4, 1, 10, 1), "rounds to nearest integer (down)")
    assert_equal(8, BETTERUI.ClampInteger(7.5, 1, 10, 1), "rounds to nearest integer (up)")
    assert_equal(99, BETTERUI.ClampInteger("abc", 1, 10, 99), "non-numeric returns fallback")
    assert_equal(99, BETTERUI.ClampInteger(nil, 1, 10, 99), "nil returns fallback")
    assert_equal(5, BETTERUI.ClampInteger("5", 1, 10, 99), "numeric string is coerced")
end

-- ============================================================================
-- SUMMARY
-- ============================================================================

print("\n=== Test Summary ===")
print(string.format("Passed: %d", tests_passed))
print(string.format("Failed: %d", tests_failed))

if tests_failed > 0 then
    print("\nFAILED")
    os.exit(1)
else
    print("\nAll tests passed")
    os.exit(0)
end
