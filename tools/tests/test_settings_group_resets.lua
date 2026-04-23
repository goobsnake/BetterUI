--[[
File: tools/tests/test_settings_group_resets.lua
Purpose: Unit tests for grouped module setting resets driven by SettingsFactory metadata.

Usage:
  lua tools/tests/test_settings_group_resets.lua
]]

BETTERUI = {
    Settings = {
        Modules = {
            Inventory = {},
            Banking = {},
            Vendor = {},
            Companions = {},
            GeneralInterface = {},
        },
    },
    CIM = {
        Settings = {},
    },
}

function BETTERUI.GetModuleSettings(moduleName)
    BETTERUI.Settings.Modules[moduleName] = BETTERUI.Settings.Modules[moduleName] or {}
    return BETTERUI.Settings.Modules[moduleName]
end

function BETTERUI.EnsureModuleSettings(moduleName)
    BETTERUI.Settings.Modules[moduleName] = BETTERUI.Settings.Modules[moduleName] or {}
    return BETTERUI.Settings.Modules[moduleName]
end

function BETTERUI.CIM.TryResolve(_)
    return nil
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

print("\n=== Settings Group Reset Tests ===\n")

dofile("Modules/CIM/Core/Integration/OptionalAddonRegistry.lua")
dofile("Modules/CIM/Core/Settings/SettingsMetadata.lua")

print("Test: Inventory general reset restores trigger settings")
BETTERUI.Settings.Modules.Inventory = {
    quickDestroy = true,
    enableBatchDestroy = true,
    enableCarousel = false,
    useTriggersForSkip = true,
    triggerSpeed = 37,
    bindOnEquipProtection = false,
    enableCompanionJunk = true,
}

BETTERUI.CIM.Settings.ResetModuleSettingsByGroup("Inventory", "general")

assertEqual(false, BETTERUI.Settings.Modules.Inventory.quickDestroy, "Inventory quickDestroy reset")
assertEqual(false, BETTERUI.Settings.Modules.Inventory.enableBatchDestroy, "Inventory enableBatchDestroy reset")
assertEqual(true, BETTERUI.Settings.Modules.Inventory.enableCarousel, "Inventory enableCarousel reset")
assertEqual(false, BETTERUI.Settings.Modules.Inventory.useTriggersForSkip, "Inventory useTriggersForSkip reset")
assertEqual(10, BETTERUI.Settings.Modules.Inventory.triggerSpeed, "Inventory triggerSpeed reset")
assertEqual(true, BETTERUI.Settings.Modules.Inventory.bindOnEquipProtection, "Inventory bindOnEquipProtection reset")
assertEqual(false, BETTERUI.Settings.Modules.Inventory.enableCompanionJunk, "Inventory enableCompanionJunk reset")

print("\nTest: Banking general reset restores trigger settings")
BETTERUI.Settings.Modules.Banking = {
    enableCarousel = false,
    useTriggersForSkip = true,
    triggerSpeed = 52,
}

BETTERUI.CIM.Settings.ResetModuleSettingsByGroup("Banking", "general")

assertEqual(true, BETTERUI.Settings.Modules.Banking.enableGuildBank, "Banking enableGuildBank reset")
assertEqual(true, BETTERUI.Settings.Modules.Banking.enableCarousel, "Banking enableCarousel reset")
assertEqual(false, BETTERUI.Settings.Modules.Banking.useTriggersForSkip, "Banking useTriggersForSkip reset")
assertEqual(10, BETTERUI.Settings.Modules.Banking.triggerSpeed, "Banking triggerSpeed reset")

print("\nTest: Vendor general reset restores currency and sell settings")
BETTERUI.Settings.Modules.Vendor = {
    enableCarousel = false,
    enableBatchJunkSell = false,
    abbreviateVendorCurrency = false,
}

BETTERUI.CIM.Settings.ResetModuleSettingsByGroup("Vendor", "general")

assertEqual(true, BETTERUI.Settings.Modules.Vendor.enableCarousel, "Vendor enableCarousel reset")
assertEqual(true, BETTERUI.Settings.Modules.Vendor.enableBatchJunkSell, "Vendor enableBatchJunkSell reset")
assertEqual(true, BETTERUI.Settings.Modules.Vendor.abbreviateVendorCurrency, "Vendor abbreviateVendorCurrency reset")

print("\nTest: Companions general reset restores equipment safety settings")
BETTERUI.Settings.Modules.Companions = {
    enableCompanionEquipment = false,
    quickDestroy = true,
    batchDestroy = false,
    bindOnEquipProtection = false,
    enableCompanionJunk = false,
}

BETTERUI.CIM.Settings.ResetModuleSettingsByGroup("Companions", "general")

assertEqual(true, BETTERUI.Settings.Modules.Companions.enableCompanionEquipment, "Companions enableCompanionEquipment reset")
assertEqual(false, BETTERUI.Settings.Modules.Companions.quickDestroy, "Companions quickDestroy reset")
assertEqual(true, BETTERUI.Settings.Modules.Companions.batchDestroy, "Companions batchDestroy reset")
assertEqual(true, BETTERUI.Settings.Modules.Companions.bindOnEquipProtection, "Companions bindOnEquipProtection reset")
assertEqual(true, BETTERUI.Settings.Modules.Companions.enableCompanionJunk, "Companions enableCompanionJunk reset")

print("\nTest: GeneralInterface enhanced tooltip reset restores migrated tooltip defaults")
BETTERUI.Settings.Modules.GeneralInterface = {
    showStyleTrait = false,
    showKnowledgeStatus = false,
    showItemComparison = false,
}

BETTERUI.CIM.Settings.ResetModuleSettingsByGroup("GeneralInterface", "enhancedTooltips")

assertEqual(true, BETTERUI.Settings.Modules.GeneralInterface.showStyleTrait, "GeneralInterface showStyleTrait reset")
assertEqual(true, BETTERUI.Settings.Modules.GeneralInterface.showKnowledgeStatus,
    "GeneralInterface showKnowledgeStatus reset")
assertEqual(true, BETTERUI.Settings.Modules.GeneralInterface.showItemComparison,
    "GeneralInterface showItemComparison reset")

print("\n=== Test Summary ===")
print(string.format("Passed: %d", testsPassed))
print(string.format("Failed: %d", testsFailed))

if testsFailed > 0 then
    os.exit(1)
else
    print("All tests passed.")
end
