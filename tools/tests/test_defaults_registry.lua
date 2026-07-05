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
assert_true(BETTERUI.Defaults.FirstInstall.TradingHouse, "TradingHouse defaults to enabled")
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
assert_true(bank.enableGuildBank, "Banking.enableGuildBank defaults true")

print("\nTest: GeneralInterface defaults")
local gi = BETTERUI.Defaults.Modules.GeneralInterface
assert_true(gi.showMarketPrice, "GI.showMarketPrice defaults true")
assert_true(gi.showItemComparison, "GI.showItemComparison defaults true")
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
assert_true(rof.showQuickslotCooldown, "ROF.showQuickslotCooldown defaults true")
assert_true(rof.orbAnimFlow, "ROF.orbAnimFlow defaults true")
assert_equal(0.4, rof.shieldTextColor[1], "ROF.shieldTextColor red defaults to electric shield color")
assert_equal(0.9, rof.shieldTextColor[2], "ROF.shieldTextColor green defaults to electric shield color")

print("\nTest: Nameplates defaults")
local np = BETTERUI.Defaults.Modules.Nameplates
assert_false(np.m_enabled, "Nameplates.m_enabled defaults false")
assert_equal(16, np.size, "Nameplates.size defaults to 16")
assert_false(np.nameplatePositionsUnlocked, "Nameplates position movement defaults locked")
assert_false(np.moveCompassFrame, "Nameplates compass mover defaults disabled")
assert_equal(0, np.compassFrameOffsetX, "Nameplates compass X offset defaults zero")
assert_equal(0, np.compassFrameOffsetY, "Nameplates compass Y offset defaults zero")
assert_false(np.moveTargetBar, "Nameplates target/NPC bar mover defaults disabled")
assert_equal(0, np.targetBarOffsetX, "Nameplates target/NPC bar X offset defaults zero")
assert_equal(0, np.targetBarOffsetY, "Nameplates target/NPC bar Y offset defaults zero")
assert_false(np.movePlayerInteract, "Nameplates player-interact mover defaults disabled")
assert_equal(0, np.playerInteractOffsetX, "Nameplates player-interact X offset defaults zero")
assert_equal(0, np.playerInteractOffsetY, "Nameplates player-interact Y offset defaults zero")

print("\nTest: Vendor defaults")
local vendor = BETTERUI.Defaults.Modules.Vendor
assert_true(vendor.enableCarousel, "Vendor.enableCarousel defaults true")
assert_true(vendor.enableBatchJunkSell, "Vendor.enableBatchJunkSell defaults true")
assert_true(vendor.abbreviateVendorCurrency, "Vendor.abbreviateVendorCurrency defaults true")

print("\nTest: TradingHouse defaults")
local th = BETTERUI.Defaults.Modules.TradingHouse
assert_true(th.enableCarousel, "TradingHouse.enableCarousel defaults true")
assert_not_nil(th.searchPresets, "TradingHouse.searchPresets defaults table exists")
assert_nil(next(th.searchPresets), "TradingHouse.searchPresets starts empty")

print("\nTest: Companions defaults")
local comp = BETTERUI.Defaults.Modules.Companions
assert_true(comp.enableCompanionEquipment, "Companions.enableCompanionEquipment defaults true")
assert_false(comp.quickDestroy, "Companions.quickDestroy defaults false")
assert_true(comp.batchDestroy, "Companions.batchDestroy defaults true")
assert_true(comp.bindOnEquipProtection, "Companions.bindOnEquipProtection defaults true")
assert_true(comp.enableCompanionJunk, "Companions.enableCompanionJunk defaults true")

-- ============================================================================
-- TESTS: Utility Functions
-- ============================================================================
-- BUI-CLEAN-002: the dead IsDestructive/GetDefault accessors and the
-- write-only DestructiveSettings table were removed as production-dead.

print("\nTest: dead accessors stay removed")
assert_nil(BETTERUI.Defaults.IsDestructive, "IsDestructive stays removed")
assert_nil(BETTERUI.Defaults.GetDefault, "GetDefault stays removed")
assert_nil(BETTERUI.Defaults.DestructiveSettings, "DestructiveSettings table stays removed")

print("\nTest: GetModuleDefaults returns module table")
local invDefaults = BETTERUI.Defaults.GetModuleDefaults("Inventory")
assert_not_nil(invDefaults, "GetModuleDefaults returns table")
assert_true(invDefaults.enableCarousel, "Module defaults contain expected key")

print("\nTest: GetModuleDefaults clones nested table defaults")
local tradingDefaults = BETTERUI.Defaults.GetModuleDefaults("TradingHouse")
tradingDefaults.searchPresets.favorite = true
assert_nil(BETTERUI.Defaults.Modules.TradingHouse.searchPresets.favorite, "Registry search presets stay immutable")

print("\nTest: GetModuleDefaults returns empty table for unknown module")
local unknown = BETTERUI.Defaults.GetModuleDefaults("NonExistent")
assert_not_nil(unknown, "Returns table (not nil)")
assert_nil(next(unknown), "Table is empty")

print("\nTest: ApplyFirstInstallDefaults sets module enabled states")
local settings = { Modules = {} }
BETTERUI.Defaults.ApplyFirstInstallDefaults(settings)
assert_true(settings.Modules.Inventory.m_enabled, "Inventory enabled after first install")
assert_true(settings.Modules.Banking.m_enabled, "Banking enabled after first install")
assert_true(settings.Modules.TradingHouse.m_enabled, "TradingHouse enabled after first install")
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

print("\nTest: ApplyModuleDefaults clones table values when backfilling")
local tradingApplied = BETTERUI.Defaults.ApplyModuleDefaults("TradingHouse", {})
tradingApplied.searchPresets.favorite = true
assert_nil(BETTERUI.Defaults.Modules.TradingHouse.searchPresets.favorite, "Backfilled search presets use cloned tables")

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
