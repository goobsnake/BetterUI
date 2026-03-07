--[[
File: tools/tests/test_settings_reset.lua
Purpose: Unit tests for full BetterUI settings reset helper.

Usage:
  lua tools/tests/test_settings_reset.lua
]]

local featureResetCount = 0
local updateCIMStateCount = 0
local nameplatesDisabledCount = 0
local lastNameplatesSuppressCleanupLog = nil

BETTERUI = {
    DefaultSettings = {
        firstInstall = true,
        useAccountWide = false,
        Modules = {},
    },
    Defaults = {},
    CIM = {
        Settings = {},
        FeatureFlags = {},
    },
    Inventory = {},
    Banking = {},
    Writs = {},
    GeneralInterface = {},
    Nameplates = {},
    ResourceOrbFrames = {},
}

function BETTERUI.Debug(_)
end

function BETTERUI.UpdateCIMState()
    updateCIMStateCount = updateCIMStateCount + 1
end

function BETTERUI.Defaults.ApplyFirstInstallDefaults(settings)
    settings.Modules.Inventory = settings.Modules.Inventory or {}
    settings.Modules.Inventory.m_enabled = true
    settings.Modules.Banking = settings.Modules.Banking or {}
    settings.Modules.Banking.m_enabled = true
    settings.Modules.Writs = settings.Modules.Writs or {}
    settings.Modules.Writs.m_enabled = false
end

function BETTERUI.CIM.FeatureFlags.ResetToDefaults()
    featureResetCount = featureResetCount + 1
    if BETTERUI.Settings then
        BETTERUI.Settings.FeatureFlags = {}
    end
end

function BETTERUI.CIM.InitModule(options)
    options.cimDefault = "cim"
    return options
end

function BETTERUI.Inventory.InitModule(options)
    options.inventoryDefault = "inventory"
    options.sharedTable = { source = "inventory" }
    return options
end

function BETTERUI.Banking.InitModule(options)
    options.bankingDefault = 42
    return options
end

function BETTERUI.Writs.InitModule(options)
    options.writsDefault = "writs"
    return options
end

function BETTERUI.GeneralInterface.InitModule(options)
    options.generalInterfaceDefault = true
    return options
end

function BETTERUI.Nameplates.InitModule(options)
    options.nameplatesDefault = 16
    return options
end

function BETTERUI.Nameplates.OnEnabledChanged(enabled, suppressCleanupLog)
    if enabled == false then
        nameplatesDisabledCount = nameplatesDisabledCount + 1
    end
    lastNameplatesSuppressCleanupLog = suppressCleanupLog
end

function BETTERUI.ResourceOrbFrames.InitModule(options)
    options.resourceOrbFramesDefault = {
        scale = 1,
    }
    return options
end

local function buildStore(useAccountWideValue)
    return {
        useAccountWide = useAccountWideValue,
        firstInstall = false,
        Modules = {
            Inventory = {
                staleInventoryValue = true,
            },
            Nameplates = {
                m_enabled = true,
                font = "stale-font",
                style = 99,
                size = 44,
            },
            LegacyModule = {
                staleModule = true,
            },
        },
        FeatureFlags = {
            TEST = true,
        },
        SortOptions = {
            Inventory = {
                sortType = 99,
            },
        },
        LegacyTopLevel = "stale",
    }
end

local function resetFixture()
    featureResetCount = 0
    updateCIMStateCount = 0
    nameplatesDisabledCount = 0
    lastNameplatesSuppressCleanupLog = nil

    BETTERUI.SavedVars = buildStore(true)
    BETTERUI.GlobalVars = buildStore(true)
    BETTERUI.Settings = BETTERUI.GlobalVars
end

local testsPassed = 0
local testsFailed = 0

local function assertEqual(expected, actual, message)
    if expected == actual then
        testsPassed = testsPassed + 1
        print("  [OK] " .. message)
    else
        testsFailed = testsFailed + 1
        print("  [X] " .. message)
        print("    Expected: " .. tostring(expected))
        print("    Actual:   " .. tostring(actual))
    end
end

local function assertTrue(value, message)
    assertEqual(true, value, message)
end

local function assertNil(value, message)
    assertEqual(nil, value, message)
end

print("\n=== Settings Reset Tests ===\n")

resetFixture()
dofile("Modules/CIM/Core/SettingsReset.lua")
BETTERUI.SavedVars.useAccountWide = false
BETTERUI.Settings = BETTERUI.SavedVars

print("Test: ResetAllSettingsToDefaults resets only character settings when global settings are disabled")
BETTERUI.CIM.Settings.ResetAllSettingsToDefaults()

assertEqual(false, BETTERUI.SavedVars.useAccountWide, "Character settings reset useAccountWide to default")
assertEqual(BETTERUI.SavedVars, BETTERUI.Settings, "Active settings switched to character defaults")
assertEqual("inventory", BETTERUI.SavedVars.Modules.Inventory.inventoryDefault, "Inventory defaults restored")
assertEqual(42, BETTERUI.SavedVars.Modules.Banking.bankingDefault, "Banking defaults restored")
assertEqual(true, BETTERUI.SavedVars.Modules.Inventory.m_enabled, "First-install enabled defaults re-applied")
assertEqual(false, BETTERUI.SavedVars.Modules.Writs.m_enabled, "First-install disabled defaults re-applied")
assertNil(BETTERUI.SavedVars.Modules.LegacyModule, "Legacy module settings cleared")
assertNil(BETTERUI.SavedVars.LegacyTopLevel, "Legacy top-level settings cleared")
assertTrue(next(BETTERUI.SavedVars.FeatureFlags) == nil, "Character feature flags cleared")
assertEqual(1, featureResetCount, "Feature flag caches reset once")
assertEqual(1, updateCIMStateCount, "CIM state refreshed once")
assertEqual(1, nameplatesDisabledCount, "Nameplates disable hook ran for character reset")
assertEqual(true, lastNameplatesSuppressCleanupLog, "Character reset suppresses nameplate cleanup chat")
assertEqual(true, BETTERUI.GlobalVars.useAccountWide, "Inactive global settings keep their prior scope flag")
assertEqual(true, BETTERUI.GlobalVars.Modules.Inventory.staleInventoryValue, "Inactive global settings remain untouched")
assertEqual(true, BETTERUI.GlobalVars.FeatureFlags.TEST, "Inactive global feature flags remain untouched")

print("\nTest: ResetAllSettingsToDefaults resets only account-wide settings when global settings are enabled")
resetFixture()
BETTERUI.SavedVars.useAccountWide = true
BETTERUI.Settings = BETTERUI.GlobalVars
BETTERUI.CIM.Settings.ResetAllSettingsToDefaults()

assertEqual(true, BETTERUI.SavedVars.useAccountWide, "Character scope keeps global-settings toggle enabled")
assertEqual(BETTERUI.GlobalVars, BETTERUI.Settings, "Active settings remain account-wide")
assertEqual("inventory", BETTERUI.GlobalVars.Modules.Inventory.inventoryDefault, "Global inventory defaults restored")
assertEqual(42, BETTERUI.GlobalVars.Modules.Banking.bankingDefault, "Global banking defaults restored")
assertEqual(true, BETTERUI.GlobalVars.Modules.Inventory.m_enabled, "Global first-install enabled defaults re-applied")
assertEqual(false, BETTERUI.GlobalVars.Modules.Writs.m_enabled, "Global first-install disabled defaults re-applied")
assertNil(BETTERUI.GlobalVars.Modules.LegacyModule, "Global legacy module settings cleared")
assertNil(BETTERUI.GlobalVars.LegacyTopLevel, "Global legacy top-level settings cleared")
assertTrue(next(BETTERUI.GlobalVars.FeatureFlags) == nil, "Global feature flags cleared")
assertEqual(true, BETTERUI.SavedVars.Modules.Inventory.staleInventoryValue, "Inactive character settings remain untouched")
assertEqual(true, BETTERUI.SavedVars.FeatureFlags.TEST, "Inactive character feature flags remain untouched")
assertEqual(1, featureResetCount, "Feature flag caches reset once for global reset")
assertEqual(1, updateCIMStateCount, "CIM state refreshed once for global reset")
assertEqual(1, nameplatesDisabledCount, "Nameplates disable hook ran for global reset")
assertEqual(true, lastNameplatesSuppressCleanupLog, "Global reset suppresses nameplate cleanup chat")

print("\n=== Test Summary ===")
print(string.format("Passed: %d", testsPassed))
print(string.format("Failed: %d", testsFailed))

if testsFailed > 0 then
    os.exit(1)
else
    print("\nAll tests passed!")
    os.exit(0)
end
