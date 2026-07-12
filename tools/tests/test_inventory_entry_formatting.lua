--[[
File: tools/tests/test_inventory_entry_formatting.lua
Purpose: Unit tests for exported entry-formatting behavior in
         Inventory/Lists/InventoryEntryFormatting.lua.
         Loads production code and verifies label text/icon composition.
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

local moduleSettings = {
    Inventory = {
        nameFontSize = 56,
        showIconUnboundItem = true,
    },
    GeneralInterface = {
        showMarketPrice = true,
    },
    Banking = {
        nameFontSize = 28,
    },
}

BETTERUI = {
    Inventory = {
        CONST = {
            ICON_SIZE_SMALL = 16,
            LIST_ENTRY_BASE_FONT_SIZE = 28,
        },
        GetNameFontDescriptor = function()
            return "InventoryFont"
        end,
    },
    Banking = {
        GetNameFontDescriptor = function()
            return "BankingFont"
        end,
    },
    Vendor = {
        GetNameFontDescriptor = function()
            return "VendorFont"
        end,
    },
    Companions = {
        GetNameFontDescriptor = function()
            return "CompanionsFont"
        end,
    },
    TradingHouse = {
        GetNameFontDescriptor = function()
            return "TradingHouseFont"
        end,
    },
    Utils = {
        IsBankingSceneShowing = function()
            return false
        end,
    },
    CIM = {
        CONST = {
            ICONS = {
                STOLEN = "stolen.dds",
                UNBOUND = "unbound.dds",
                ENCHANTED = "enchanted.dds",
                SET_ITEM = "set-item.dds",
                RESEARCHABLE_TRAIT = "trait.dds",
                RECIPE_UNKNOWN = "recipe.dds",
                BOOK_UNKNOWN = "book.dds",
            },
        },
        SharedItemSupport = {
            ResolveNameFontDescriptor = function(moduleName, fallbackModuleName)
                local target = BETTERUI[moduleName]
                if target and target.GetNameFontDescriptor then
                    return target.GetNameFontDescriptor()
                end
                local fallback = BETTERUI[fallbackModuleName]
                return fallback and fallback.GetNameFontDescriptor and fallback.GetNameFontDescriptor() or nil
            end,
        },
    },
}

function BETTERUI.Debug() end

function BETTERUI.GetModuleSettings(moduleName)
    return moduleSettings[moduleName] or {}
end

function zo_clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

function zo_strformat(formatString, value)
    return formatString:gsub("<<1>>", tostring(value))
end

function GetItemLinkSetInfo()
    return false
end

function GetItemLinkEnchantInfo()
    return false
end

function GetItemLinkItemType()
    return 0
end

function IsItemBound()
    return true
end

function GetItemLink()
    return "|H1:item:live-slot|h"
end

SCENE_MANAGER = {
    scenes = {},
    GetScene = function(self, sceneName)
        return self.scenes[sceneName]
    end,
}

ZO_GAMEPAD_UNSELECTED_COLOR = {
    UnpackRGBA = function()
        return 1, 1, 1, 1
    end,
}

ZO_GAMEPAD_LOCKED_ICON_32 = "locked.dds"
ZO_TRADE_BOP_ICON = "bop.dds"
ITEM_QUALITY_TRASH = -1

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

dofile("Modules/Inventory/Lists/InventoryEntryFormatting.lua")

local function makeColor(r, g, b, a)
    return {
        UnpackRGBA = function()
            return r, g, b, a
        end,
    }
end

local function makeLabel()
    local label = {
        text = nil,
        font = nil,
        color = nil,
        modifyTextType = nil,
    }

    function label:SetFont(font)
        self.font = font
    end

    function label:SetModifyTextType(modifyTextType)
        self.modifyTextType = modifyTextType
    end

    function label:SetText(text)
        self.text = text
    end

    function label:SetColor(r, g, b, a)
        self.color = { r, g, b, a }
    end

    return label
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

local function assert_contains(haystack, needle, message)
    assert_true(haystack:find(needle, 1, true) ~= nil, message)
end

local function assert_not_contains(haystack, needle, message)
    assert_true(haystack:find(needle, 1, true) == nil, message)
end

-- ============================================================================
-- TESTS
-- ============================================================================

print("\n=== Inventory Entry Formatting Tests ===\n")

print("Test: Non-item entry uses fallback label text and color")
local label = makeLabel()
local nonItemData = {
    text = "Currency Row",
    labelColor = makeColor(0.2, 0.3, 0.4, 1),
}
BETTERUI_SharedGamepadEntryLabelSetup(label, nonItemData, false)
assert_equal("Currency Row", label.text, "Non-item entry text preserved")
assert_equal("InventoryFont", label.font, "Inventory font used for non-item inventory entries")

print("\nTest: Item entry composes scaled inline icons from production logic")
label = makeLabel()
local itemData = {
    text = "Lockpick",
    stolen = true,
    stackCount = 2,
    quality = 1,
    cached_itemLink = "|H1:item:1|h",
    cached_isRecipeAndUnknown = false,
    cached_isBookAndUnknown = false,
    cached_isTraitResearchable = false,
    cached_isUnbound = true,
    meetsUsageRequirements = true,
    GetNameColor = function()
        return makeColor(1, 1, 1, 1)
    end,
    dataSource = {
        bagId = 1,
        slotIndex = 2,
    },
}
BETTERUI_SharedGamepadEntryLabelSetup(label, itemData, false)
assert_equal("InventoryFont", label.font, "Inventory font used for item entries")
assert_contains(label.text, "|t32:32:stolen.dds|t", "Stolen icon uses scaled production size")
assert_contains(label.text, "|t32:32:unbound.dds|t", "Unbound icon uses scaled production size")
assert_contains(label.text, "Lockpick", "Item name included in label")
assert_contains(label.text, "|cFFFFFF(2)|r", "Stack count appended to label")

print("\nTest: Empty cached link falls back to live slot metadata")
label = makeLabel()
local emptyCachedLinkData = {
    text = "Companion's Arm Cops",
    stolen = false,
    stackCount = 1,
    quality = 2,
    cached_itemLink = "",
    cached_isRecipeAndUnknown = false,
    cached_isBookAndUnknown = false,
    cached_isTraitResearchable = false,
    cached_isUnbound = true,
    meetsUsageRequirements = true,
    GetNameColor = function()
        return makeColor(1, 1, 1, 1)
    end,
    dataSource = {
        bagId = 3,
        slotIndex = 896,
        cached_itemLink = "",
    },
}
BETTERUI_SharedGamepadEntryLabelSetup(label, emptyCachedLinkData, false)
assert_contains(label.text, "unbound.dds",
    "Empty cached item link does not suppress guild-bank item status icons")

print("\nTest: Icon toggle settings suppress disabled inline icons")
moduleSettings.Inventory.showIconUnboundItem = false
label = makeLabel()
BETTERUI_SharedGamepadEntryLabelSetup(label, itemData, false)
assert_not_contains(label.text, "unbound.dds", "Disabled unbound icon is omitted")
moduleSettings.Inventory.showIconUnboundItem = true

print("\nTest: Banking scene switches font descriptor source")
BETTERUI.Utils.IsBankingSceneShowing = function()
    return true
end
moduleSettings.Banking.nameFontSize = 28
label = makeLabel()
BETTERUI_SharedGamepadEntryLabelSetup(label, itemData, false)
assert_equal("BankingFont", label.font, "Banking font descriptor used when banking scene is active")
BETTERUI.Utils.IsBankingSceneShowing = function()
    return false
end

print("\nTest: Explicit list module context overrides scene fallback")
BETTERUI.Utils.IsBankingSceneShowing = function()
    return true
end
label = makeLabel()
local vendorContextData = {
    text = "Vendor Item",
    stolen = false,
    stackCount = 1,
    quality = 1,
    cached_itemLink = "|H1:item:2|h",
    cached_isRecipeAndUnknown = false,
    cached_isBookAndUnknown = false,
    cached_isTraitResearchable = false,
    cached_isUnbound = false,
    listModuleName = "Vendor",
    meetsUsageRequirements = true,
    GetNameColor = function()
        return makeColor(1, 1, 1, 1)
    end,
    dataSource = {
        bagId = 1,
        slotIndex = 3,
        listModuleName = "Vendor",
    },
}
BETTERUI_SharedGamepadEntryLabelSetup(label, vendorContextData, false)
assert_equal("VendorFont", label.font, "Explicit row ownership is preferred over scene fallback")
BETTERUI.Utils.IsBankingSceneShowing = function()
    return false
end

print("\nTest: Market-price visibility only reads GeneralInterface settings")
moduleSettings.GeneralInterface.showMarketPrice = nil
moduleSettings.Inventory.showMarketPrice = false
assert_true(BETTERUI.Inventory._EntryFormatting.ShouldShowMarketPrice(),
    "Entry formatting ignores the migrated Inventory.showMarketPrice legacy key")
moduleSettings.GeneralInterface.showMarketPrice = true
moduleSettings.Inventory.showMarketPrice = nil

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
