--[[
File: tools/tests/test_inventory_entry_formatting.lua
Purpose: Unit tests for pure helper functions in Inventory/Lists/InventoryEntryFormatting.lua.
         Tests run standalone with a Lua interpreter (no ESO environment).
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = { Inventory = { CONST = { LIST_ENTRY_BASE_FONT_SIZE = 28 } } }
function BETTERUI.Debug() end

function zo_clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- Constants from the module
local INLINE_STATUS_ICON_BASE_SIZE = 24
local INLINE_STATUS_ICON_MIN_SIZE = 14
local INLINE_STATUS_ICON_MAX_SIZE = 42

-- ============================================================================
-- FUNCTIONS UNDER TEST
-- ============================================================================

local function GetScaledInlineIconSize(fontSize, weightMultiplier)
    local baseFontSize = BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_FONT_SIZE
    local ratio = fontSize / baseFontSize
    local scaled = math.floor((INLINE_STATUS_ICON_BASE_SIZE * ratio * (weightMultiplier or 1.0)) + 0.5)
    return zo_clamp(scaled, INLINE_STATUS_ICON_MIN_SIZE, INLINE_STATUS_ICON_MAX_SIZE)
end

local function BuildInlineIconTag(texturePath, iconSize)
    return "|t" .. iconSize .. ":" .. iconSize .. ":" .. texturePath .. "|t"
end

local function GetIconToggleSetting(moduleSettings, key, defaultValue)
    if moduleSettings and moduleSettings[key] ~= nil then
        return moduleSettings[key]
    end
    return defaultValue
end

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
-- TESTS: GetScaledInlineIconSize
-- ============================================================================

print("\n=== GetScaledInlineIconSize Tests ===\n")

-- At base font size, icon = base size
assert_equal(24, GetScaledInlineIconSize(28, 1.0), "base font -> base icon (24)")

-- Larger font scales up
local icon = GetScaledInlineIconSize(56, 1.0)
assert_true(icon > 24, "double font -> larger icon")
assert_equal(42, icon, "double font -> clamped to max (42)")

-- Smaller font scales down
icon = GetScaledInlineIconSize(14, 1.0)
assert_equal(14, icon, "half font -> clamped to min (14)")

-- Weight multiplier scales
icon = GetScaledInlineIconSize(28, 1.5)
assert_equal(36, icon, "1.5x weight -> 36px icon")

-- Nil weight multiplier defaults to 1.0
icon = GetScaledInlineIconSize(28, nil)
assert_equal(24, icon, "nil weight -> default 1.0")

-- Very small font clamps to minimum
icon = GetScaledInlineIconSize(7, 1.0)
assert_equal(14, icon, "tiny font -> clamped to min")

-- ============================================================================
-- TESTS: BuildInlineIconTag
-- ============================================================================

print("\n=== BuildInlineIconTag Tests ===\n")

local tag = BuildInlineIconTag("EsoUI/Art/icon.dds", 24)
assert_equal("|t24:24:EsoUI/Art/icon.dds|t", tag, "basic icon tag")

tag = BuildInlineIconTag("path/to/texture.dds", 16)
assert_equal("|t16:16:path/to/texture.dds|t", tag, "smaller icon tag")

-- ============================================================================
-- TESTS: GetIconToggleSetting
-- ============================================================================

print("\n=== GetIconToggleSetting Tests ===\n")

local settings = { showBound = true, showStolen = false }

assert_equal(true, GetIconToggleSetting(settings, "showBound", false), "existing true key")
assert_equal(false, GetIconToggleSetting(settings, "showStolen", true), "existing false key")
assert_equal(true, GetIconToggleSetting(settings, "missing", true), "missing key -> true default")
assert_equal(false, GetIconToggleSetting(settings, "missing", false), "missing key -> false default")
assert_equal(true, GetIconToggleSetting(nil, "showBound", true), "nil settings -> default")

-- ============================================================================
-- SUMMARY
-- ============================================================================

print("\n=== SUMMARY ===")
print("  Passed: " .. tests_passed)
print("  Failed: " .. tests_failed)
print("")

if tests_failed > 0 then
    os.exit(1)
end
