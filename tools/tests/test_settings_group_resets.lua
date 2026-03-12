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
        },
    },
    CIM = {
        Settings = {},
    },
}

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

dofile("Modules/CIM/Core/SettingsFactory.lua")

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

assertEqual(true, BETTERUI.Settings.Modules.Banking.enableCarousel, "Banking enableCarousel reset")
assertEqual(false, BETTERUI.Settings.Modules.Banking.useTriggersForSkip, "Banking useTriggersForSkip reset")
assertEqual(10, BETTERUI.Settings.Modules.Banking.triggerSpeed, "Banking triggerSpeed reset")

print("\n=== Test Summary ===")
print(string.format("Passed: %d", testsPassed))
print(string.format("Failed: %d", testsFailed))

if testsFailed > 0 then
    os.exit(1)
else
    print("All tests passed.")
end
