--[[
File: tools/tests/test_defaults_registry.lua
Purpose: Unit tests for DefaultsRegistry — BetterUI's single source of truth
         for settings defaults, first-install states, and destructive settings.

Usage:
  lua tools/tests/test_defaults_registry.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = { Defaults = {} }
FONT_STYLE_SOFT_SHADOW_THIN = 5

local debugOutput = {}
function BETTERUI.Debug(msg)
    table.insert(debugOutput, msg)
end

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

dofile("Modules/CIM/Core/Settings/DefaultsRegistry.lua")

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

local function assert_false(value, message)
    assert_equal(false, value, message)
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
-- TESTS: FirstInstall Defaults
-- ============================================================================

print("\n=== DefaultsRegistry Tests ===\n")

print("Test: FirstInstall module states defined")
assert_not_nil(BETTERUI.Defaults.FirstInstall, "FirstInstall table exists")
assert_true(BETTERUI.Defaults.FirstInstall.Inventory, "Inventory defaults to enabled")
assert_true(BETTERUI.Defaults.FirstInstall.Banking, "Banking defaults to enabled")
assert_true(BETTERUI.Defaults.FirstInstall.Vendor, "Vendor defaults to enabled")
assert_false(BETTERUI.Defaults.FirstInstall.TradingHouse, "TradingHouse defaults to disabled")
assert_true(BETTERUI.Defaults.FirstInstall.Companions, "Companions defaults to enabled")
assert_true(BETTERUI.Defaults.FirstInstall.GeneralInterface, "GeneralInterface defaults to enabled")
assert_true(BETTERUI.Defaults.FirstInstall.ResourceOrbFrames, "ResourceOrbFrames defaults to enabled")
assert_false(BETTERUI.Defaults.FirstInstall.Writs, "Writs defaults to disabled")
assert_false(BETTERUI.Defaults.FirstInstall.Nameplates, "Nameplates defaults to disabled")

-- ============================================================================
-- TESTS: Module Defaults Structure
-- ============================================================================

print("\nTest: All expected modules have defaults")
local expectedModules = {
    "Inventory", "Banking", "GeneralInterface", "CIM",
    "ResourceOrbFrames", "Nameplates", "Writs", "Vendor",
    "TradingHouse", "Companions"
}
for _, mod in ipairs(expectedModules) do
    assert_not_nil(BETTERUI.Defaults.Modules[mod], mod .. " has defaults table")
end

print("\nTest: Inventory defaults")
local inv = BETTERUI.Defaults.Modules.Inventory
assert_true(inv.enableCarousel, "Inventory.enableCarousel defaults true")
assert_true(inv.showIconEnchantment, "Inventory.showIconEnchantment defaults true")
assert_true(inv.bindOnEquipProtection, "Inventory.bindOnEquipProtection defaults true")
assert_false(inv.quickDestroy, "Inventory.quickDestroy defaults false (destructive)")
assert_false(inv.enableBatchDestroy, "Inventory.enableBatchDestroy defaults false (destructive)")

print("\nTest: Banking defaults")
local bank = BETTERUI.Defaults.Modules.Banking
assert_true(bank.enableCarousel, "Banking.enableCarousel defaults true")
assert_true(bank.showIconSetGear, "Banking.showIconSetGear defaults true")

print("\nTest: GeneralInterface defaults")
local gi = BETTERUI.Defaults.Modules.GeneralInterface
assert_true(gi.showMarketPrice, "GI.showMarketPrice defaults true")
assert_false(gi.removeDeleteDialog, "GI.removeDeleteDialog defaults false (destructive)")
assert_equal(200, gi.chatHistory, "GI.chatHistory defaults to 200")

print("\nTest: CIM defaults")
local cim = BETTERUI.Defaults.Modules.CIM
assert_equal(50, cim.rhScrollSpeed, "CIM.rhScrollSpeed defaults to 50")
assert_equal(24, cim.tooltipSize, "CIM.tooltipSize defaults to 24")
assert_true(cim.enableTooltipEnhancements, "CIM.enableTooltipEnhancements defaults true")

print("\nTest: ResourceOrbFrames defaults")
local rof = BETTERUI.Defaults.Modules.ResourceOrbFrames
assert_equal(1.0, rof.scale, "ROF.scale defaults to 1.0")
assert_true(rof.showUltimateNumber, "ROF.showUltimateNumber defaults true")
assert_true(rof.xpBarEnabled, "ROF.xpBarEnabled defaults true")

print("\nTest: Nameplates defaults")
local np = BETTERUI.Defaults.Modules.Nameplates
assert_false(np.m_enabled, "Nameplates.m_enabled defaults false")
assert_equal(16, np.size, "Nameplates.size defaults to 16")

print("\nTest: Vendor defaults")
local vendor = BETTERUI.Defaults.Modules.Vendor
assert_true(vendor.enableCarousel, "Vendor.enableCarousel defaults true")
assert_true(vendor.enableBatchJunkSell, "Vendor.enableBatchJunkSell defaults true")

print("\nTest: Companions defaults")
local comp = BETTERUI.Defaults.Modules.Companions
assert_true(comp.enableCompanionEquipment, "Companions.enableCompanionEquipment defaults true")

-- ============================================================================
-- TESTS: DestructiveSettings
-- ============================================================================

print("\nTest: DestructiveSettings identification")
assert_true(BETTERUI.Defaults.IsDestructive("Inventory", "quickDestroy"), "quickDestroy is destructive")
assert_true(BETTERUI.Defaults.IsDestructive("Inventory", "enableBatchDestroy"), "enableBatchDestroy is destructive")
assert_true(BETTERUI.Defaults.IsDestructive("GeneralInterface", "removeDeleteDialog"), "removeDeleteDialog is destructive")
assert_false(BETTERUI.Defaults.IsDestructive("Inventory", "enableCarousel"), "enableCarousel is NOT destructive")
assert_false(BETTERUI.Defaults.IsDestructive("NonExistent", "key"), "Unknown module is NOT destructive")

-- ============================================================================
-- TESTS: Utility Functions
-- ============================================================================

print("\nTest: GetDefault returns correct value")
assert_true(BETTERUI.Defaults.GetDefault("Inventory", "enableCarousel"), "GetDefault Inventory.enableCarousel")
assert_false(BETTERUI.Defaults.GetDefault("Inventory", "quickDestroy"), "GetDefault Inventory.quickDestroy")
assert_equal(50, BETTERUI.Defaults.GetDefault("CIM", "rhScrollSpeed"), "GetDefault CIM.rhScrollSpeed")
assert_nil(BETTERUI.Defaults.GetDefault("NonExistent", "key"), "GetDefault returns nil for unknown module")
assert_nil(BETTERUI.Defaults.GetDefault("Inventory", "nonExistentKey"), "GetDefault returns nil for unknown key")

print("\nTest: GetModuleDefaults returns module table")
local invDefaults = BETTERUI.Defaults.GetModuleDefaults("Inventory")
assert_not_nil(invDefaults, "GetModuleDefaults returns table")
assert_true(invDefaults.enableCarousel, "Module defaults contain expected key")

print("\nTest: GetModuleDefaults returns empty table for unknown module")
local unknown = BETTERUI.Defaults.GetModuleDefaults("NonExistent")
assert_not_nil(unknown, "Returns table (not nil)")
assert_nil(next(unknown), "Table is empty")

print("\nTest: ApplyFirstInstallDefaults sets module enabled states")
local settings = { Modules = {} }
BETTERUI.Defaults.ApplyFirstInstallDefaults(settings)
assert_true(settings.Modules.Inventory.m_enabled, "Inventory enabled after first install")
assert_true(settings.Modules.Banking.m_enabled, "Banking enabled after first install")
assert_false(settings.Modules.TradingHouse.m_enabled, "TradingHouse disabled after first install")
assert_false(settings.Modules.Writs.m_enabled, "Writs disabled after first install")

print("\nTest: ApplyFirstInstallDefaults handles nil safely")
BETTERUI.Defaults.ApplyFirstInstallDefaults(nil)
tests_passed = tests_passed + 1
print("  [OK] nil settings does not crash")

BETTERUI.Defaults.ApplyFirstInstallDefaults({})
tests_passed = tests_passed + 1
print("  [OK] missing Modules table does not crash")

print("\nTest: ApplyModuleDefaults fills missing values")
local opts = { enableCarousel = false }
local result = BETTERUI.Defaults.ApplyModuleDefaults("Inventory", opts)
assert_false(result.enableCarousel, "Existing value preserved")
assert_true(result.showIconEnchantment, "Missing value filled from defaults")
assert_true(result.bindOnEquipProtection, "Another missing value filled")

print("\nTest: ApplyModuleDefaults with nil options")
local result2 = BETTERUI.Defaults.ApplyModuleDefaults("Inventory", nil)
assert_not_nil(result2, "Returns table even for nil input")
assert_true(result2.enableCarousel, "Defaults applied to new table")

print("\nTest: ApplyModuleDefaults with unknown module")
local result3 = BETTERUI.Defaults.ApplyModuleDefaults("NonExistent", { x = 1 })
assert_equal(1, result3.x, "Original value preserved")

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
