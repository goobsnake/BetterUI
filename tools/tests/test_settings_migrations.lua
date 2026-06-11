--[[
File: tools/tests/test_settings_migrations.lua
Purpose: Tests for RuntimeSetup.RunSettingsMigrations — verifies each migration
         transforms SavedVariables correctly without ESO runtime dependencies.
Usage: lua tools/tests/test_settings_migrations.lua
]]

-- ============================================================================
-- STUBS: Minimal ESO API surface required by RuntimeSetup.lua at load time
-- ============================================================================

BETTERUI = { CIM = {} }
function BETTERUI.CIM.SafeExecute(label, fn, ...) return true, fn(...) end

-- ESO globals referenced by ApplyAPIPatches (needed at load time)
function zo_iconFormat() return "" end
function zo_iconFormatInheritColor() return "" end
function zo_iconTextFormat() return "" end
function zo_iconTextFormatAlignedRight() return "" end
function zo_iconTextFormatNoSpace() return "" end
function zo_iconTextFormatNoSpaceAlignedRight() return "" end
function ZO_LinkHandler_CreateLink() return "" end

-- GetCVar stub — default to English; tests can override
local cvar_language = "en"
function GetCVar(key)
    if key == "language.2" then return cvar_language end
    return nil
end

-- Load the module under test (FontLocalization provides the canonical
-- WESTERN_ONLY_FONTS set consumed by Migration 6)
dofile("Modules/CIM/Core/Presentation/FontLocalization.lua")
dofile("Modules/CIM/Core/Lifecycle/RuntimeSetup.lua")

local RunSettingsMigrations = BETTERUI.CIM.RuntimeSetup.RunSettingsMigrations

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
        print("  [X] " .. message)
        print("    Expected: non-nil")
        print("    Actual:   nil")
    end
end

--- Deep-copy a table to avoid mutation leaking between tests.
local function deepcopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do copy[deepcopy(k)] = deepcopy(v) end
    return copy
end

-- ============================================================================
-- M1: Tooltips → GeneralInterface rename
-- ============================================================================

print("\n=== Migration 1: Tooltips → GeneralInterface ===\n")

do
    local settings = { Modules = { Tooltips = { showMarketPrice = true, m_enabled = true } } }
    RunSettingsMigrations(settings)
    assert_not_nil(settings.Modules["GeneralInterface"], "M1: GeneralInterface created from Tooltips")
    assert_true(settings.Modules["GeneralInterface"].showMarketPrice, "M1: showMarketPrice migrated")
    assert_nil(settings.Modules["Tooltips"], "M1: Tooltips key removed")
end

do
    local settings = { Modules = { Tooltips = { x = 1 }, GeneralInterface = { y = 2 } } }
    RunSettingsMigrations(settings)
    assert_nil(settings.Modules["Tooltips"], "M1: Tooltips removed even when GeneralInterface exists")
    assert_equal(2, settings.Modules["GeneralInterface"].y, "M1: existing GeneralInterface not overwritten")
end

do
    local settings = { Modules = { CIM = {} } }
    RunSettingsMigrations(settings)
    assert_nil(settings.Modules["Tooltips"], "M1: no-op when Tooltips absent")
end

-- ============================================================================
-- M2: enabled → m_enabled standardization
-- ============================================================================

print("\n=== Migration 2: enabled → m_enabled ===\n")

do
    local settings = { Modules = { CIM = { enabled = true } } }
    RunSettingsMigrations(settings)
    assert_true(settings.Modules.CIM.m_enabled, "M2: m_enabled set from enabled")
    assert_nil(settings.Modules.CIM.enabled, "M2: enabled key removed")
end

do
    local settings = { Modules = { CIM = { enabled = false, m_enabled = true } } }
    RunSettingsMigrations(settings)
    assert_true(settings.Modules.CIM.m_enabled, "M2: existing m_enabled not overwritten")
end

do
    local settings = { Modules = { CIM = { m_enabled = false } } }
    RunSettingsMigrations(settings)
    assert_equal(false, settings.Modules.CIM.m_enabled, "M2: no-op when enabled absent")
end

-- ============================================================================
-- M3: market-price move from Inventory → GeneralInterface
-- ============================================================================

print("\n=== Migration 3: market-price move ===\n")

do
    local settings = { Modules = {
        GeneralInterface = {},
        Inventory = { showMarketPrice = false }
    } }
    RunSettingsMigrations(settings)
    assert_equal(false, settings.Modules.GeneralInterface.showMarketPrice, "M3: showMarketPrice moved to GI")
    assert_nil(settings.Modules.Inventory.showMarketPrice, "M3: showMarketPrice removed from Inventory")
end

do
    local settings = { Modules = {
        GeneralInterface = { showMarketPrice = true },
        Inventory = { showMarketPrice = false }
    } }
    RunSettingsMigrations(settings)
    assert_true(settings.Modules.GeneralInterface.showMarketPrice, "M3: existing GI showMarketPrice not overwritten")
    assert_nil(settings.Modules.Inventory.showMarketPrice, "M3: Inventory key still removed")
end

do
    local settings = { Modules = { GeneralInterface = {} } }
    RunSettingsMigrations(settings)
    assert_true(settings.Modules.GeneralInterface.showMarketPrice, "M3: defaults to true when no Inventory key")
end

-- ============================================================================
-- M4: market price priority init
-- ============================================================================

print("\n=== Migration 4: market price priority init ===\n")

do
    local settings = { Modules = { GeneralInterface = {} } }
    RunSettingsMigrations(settings)
    assert_equal("mm_att_ttc", settings.Modules.GeneralInterface.marketPricePriority, "M4: default priority set")
end

do
    local settings = { Modules = { GeneralInterface = { marketPricePriority = "ttc_mm" } } }
    RunSettingsMigrations(settings)
    assert_equal("ttc_mm", settings.Modules.GeneralInterface.marketPricePriority, "M4: existing priority not overwritten")
end

-- ============================================================================
-- M5: GeneralInterface guarantee + font/size/style migrations
-- ============================================================================

print("\n=== Migration 5: GeneralInterface guarantee + font legacy ===\n")

do
    local settings = { Modules = {} }
    RunSettingsMigrations(settings)
    assert_not_nil(settings.Modules["GeneralInterface"], "M5: GeneralInterface created when missing")
end

do
    local settings = { Modules = {
        CIM = { font = "MyFont.otf", skinSize = 18, fontStyle = 2 }
    } }
    RunSettingsMigrations(settings)
    assert_equal("MyFont.otf", settings.Modules.CIM.nameFont, "M5b: nameFont from font")
    assert_equal("MyFont.otf", settings.Modules.CIM.columnFont, "M5b: columnFont from font")
    assert_equal(18, settings.Modules.CIM.nameFontSize, "M5b: nameFontSize from skinSize")
    assert_equal(18, settings.Modules.CIM.columnFontSize, "M5b: columnFontSize from skinSize")
    assert_equal("thick-outline", settings.Modules.CIM.nameFontStyle, "M5b: nameFontStyle from numeric fontStyle")
    assert_equal("thick-outline", settings.Modules.CIM.columnFontStyle, "M5b: columnFontStyle from numeric fontStyle")
end

do
    local settings = { Modules = {
        CIM = { font = "X", nameFont = "Existing" }
    } }
    RunSettingsMigrations(settings)
    assert_equal("Existing", settings.Modules.CIM.nameFont, "M5b: existing nameFont not overwritten")
end

do
    local settings = { Modules = {
        CIM = { fontStyle = "shadow" }
    } }
    RunSettingsMigrations(settings)
    assert_equal("shadow", settings.Modules.CIM.nameFontStyle, "M5b: string fontStyle passed through")
end

-- ============================================================================
-- M6: Western-only fonts (non-English locale)
-- ============================================================================

print("\n=== Migration 6: Western-only font replacement ===\n")

do
    -- Switch locale to non-English
    cvar_language = "de"
    local settings = { Modules = {
        CIM = { nameFont = "EsoUI/Common/Fonts/Univers57.otf", columnFont = "EsoUI/Common/Fonts/consola.otf" }
    } }
    RunSettingsMigrations(settings)
    assert_equal("$(GAMEPAD_MEDIUM_FONT)", settings.Modules.CIM.nameFont, "M6: western nameFont replaced (de)")
    assert_equal("$(GAMEPAD_MEDIUM_FONT)", settings.Modules.CIM.columnFont, "M6: western columnFont replaced (de)")
    cvar_language = "en"
end

do
    -- English locale should not replace
    cvar_language = "en"
    local settings = { Modules = {
        CIM = { nameFont = "EsoUI/Common/Fonts/Univers57.otf" }
    } }
    RunSettingsMigrations(settings)
    assert_equal("EsoUI/Common/Fonts/Univers57.otf", settings.Modules.CIM.nameFont, "M6: western font kept for English locale")
end

do
    -- Non-western font should not be replaced
    cvar_language = "jp"
    local settings = { Modules = {
        CIM = { nameFont = "EsoUI/Common/Fonts/SomeJapaneseFont.otf" }
    } }
    RunSettingsMigrations(settings)
    assert_equal("EsoUI/Common/Fonts/SomeJapaneseFont.otf", settings.Modules.CIM.nameFont, "M6: non-western font not replaced")
    cvar_language = "en"
end

-- ============================================================================
-- M7: Currency rename (EventTickets → TradeBars)
-- ============================================================================

print("\n=== Migration 7: Currency rename ===\n")

do
    local settings = { Modules = {
        Banking = { showCurrencyEventTickets = true, orderCurrencyEventTickets = 5 }
    } }
    RunSettingsMigrations(settings)
    assert_true(settings.Modules.Banking.showCurrencyTradeBars, "M7: showCurrency renamed")
    assert_equal(5, settings.Modules.Banking.orderCurrencyTradeBars, "M7: orderCurrency renamed")
    assert_nil(settings.Modules.Banking.showCurrencyEventTickets, "M7: old showCurrency removed")
    assert_nil(settings.Modules.Banking.orderCurrencyEventTickets, "M7: old orderCurrency removed")
end

do
    local settings = { Modules = {
        Vendor = { currencyOrder = "gold,ap,tickets,writ" }
    } }
    RunSettingsMigrations(settings)
    assert_equal("gold,ap,tradebars,writ", settings.Modules.Vendor.currencyOrder, "M7: currencyOrder string migrated")
end

-- ============================================================================
-- EDGE CASES
-- ============================================================================

print("\n=== Edge Cases ===\n")

do
    RunSettingsMigrations(nil)
    tests_passed = tests_passed + 1
    print("  [OK] nil settings does not crash")
end

do
    RunSettingsMigrations({})
    tests_passed = tests_passed + 1
    print("  [OK] empty settings (no Modules) does not crash")
end

do
    RunSettingsMigrations({ Modules = {} })
    tests_passed = tests_passed + 1
    print("  [OK] empty Modules table does not crash")
end

do
    -- Idempotency: running twice produces same result
    local settings = { Modules = {
        Tooltips = { enabled = true, showCurrencyEventTickets = false },
        Inventory = { showMarketPrice = true }
    } }
    RunSettingsMigrations(settings)
    local snapshot = deepcopy(settings)
    RunSettingsMigrations(settings)

    -- Compare key fields
    assert_equal(snapshot.Modules.GeneralInterface.m_enabled, settings.Modules.GeneralInterface.m_enabled, "Idempotent: m_enabled unchanged")
    assert_equal(snapshot.Modules.GeneralInterface.showMarketPrice, settings.Modules.GeneralInterface.showMarketPrice, "Idempotent: showMarketPrice unchanged")
    assert_equal(snapshot.Modules.GeneralInterface.marketPricePriority, settings.Modules.GeneralInterface.marketPricePriority, "Idempotent: marketPricePriority unchanged")
    assert_nil(settings.Modules.Tooltips, "Idempotent: Tooltips still nil")
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
