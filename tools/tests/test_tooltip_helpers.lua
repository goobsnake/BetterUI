--[[
File: tools/tests/test_tooltip_helpers.lua
Purpose: Targeted unit tests for tooltip pricing and knowledge helpers.

Usage:
  lua tools/tests/test_tooltip_helpers.lua
]]

SI_BETTERUI_MARKET_NO_PRICE_DATA = "SI_BETTERUI_MARKET_NO_PRICE_DATA"
SI_BETTERUI_MARKET_PRICE = "SI_BETTERUI_MARKET_PRICE"
SI_BETTERUI_MARKET_PRICE_STACK = "SI_BETTERUI_MARKET_PRICE_STACK"
SI_RECIPE_ALREADY_KNOWN = "SI_RECIPE_ALREADY_KNOWN"
SI_USE_TO_LEARN_RECIPE = "SI_USE_TO_LEARN_RECIPE"
SI_LORE_LIBRARY_IN_LIBRARY = "SI_LORE_LIBRARY_IN_LIBRARY"
SI_LORE_LIBRARY_USE_TO_LEARN = "SI_LORE_LIBRARY_USE_TO_LEARN"

CURT_MONEY = 1
ITEMTYPE_RECIPE = 42
EVENT_INVENTORY_SINGLE_SLOT_UPDATE = 1
CT_LABEL = 1

local stringMap = {
    [SI_BETTERUI_MARKET_NO_PRICE_DATA] = "<<1>>: No Price Data",
    [SI_BETTERUI_MARKET_PRICE] = "<<1>> Price: <<2>>",
    [SI_BETTERUI_MARKET_PRICE_STACK] = "<<1>> Price: <<2>>, Stack(<<3>>): <<4>>",
    [SI_RECIPE_ALREADY_KNOWN] = "Already Known",
    [SI_USE_TO_LEARN_RECIPE] = "Use to Learn",
    [SI_LORE_LIBRARY_IN_LIBRARY] = "In Library",
    [SI_LORE_LIBRARY_USE_TO_LEARN] = "Use to Learn",
}

function GetString(id)
    return stringMap[id] or tostring(id)
end

function zo_strformat(fmt, ...)
    local values = { ... }
    return (fmt:gsub("<<(%d+)>>", function(index)
        return tostring(values[tonumber(index)] or "")
    end))
end

function GetCurrencyGamepadIcon(_)
    return "coin.dds"
end

function zo_callLater(callback, _)
    callback()
end

function GetSlotStackSize(_, _)
    error("GetSlotStackSize should not be called without bag context")
end

function GetItemLinkItemType(itemLink)
    if itemLink == "recipe:unknown" or itemLink == "recipe:known" then
        return ITEMTYPE_RECIPE
    end
    return 0
end

function IsItemLinkRecipeKnown(itemLink)
    return itemLink == "recipe:known"
end

function IsItemLinkBookPartOfCollection(itemLink)
    return itemLink == "book:unknown" or itemLink == "book:known"
end

function IsItemLinkBookKnown(itemLink)
    return itemLink == "book:known"
end

BETTERUI = {
    Settings = {
        Modules = {
            GeneralInterface = {
                attIntegration = true,
                showKnowledgeStatus = true,
            },
            CIM = {
                tooltipSize = 24,
            },
        },
    },
    CIM = {
        CONST = {
            COLORS = {
                RESEARCHABLE = "00FF00",
            },
            ICONS = {
                RECIPE_UNKNOWN = "recipe.dds",
                BOOK_UNKNOWN = "book.dds",
            },
        },
        EventRegistry = {
            Register = function() end,
        },
    },
    CONST = {
        TOOLTIP = {
            DEFAULT_FONT_SIZE = 24,
        },
    },
    GeneralInterface = {},
    Inventory = {},
}

function BETTERUI.GetTooltipFontSize()
    return 24
end

function BETTERUI.SafeIcon(icon)
    return icon
end

function BETTERUI.DisplayNumber(value)
    return tostring(value)
end

function BETTERUI.roundNumber(value, _)
    return value
end

ArkadiusTradeTools = {
    Modules = {
        Sales = {
            GetAveragePricePerItem = function(_, link)
                if link == "item:stack" then
                    return 25
                end
                return 10
            end,
        },
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

local function assertContains(haystack, needle, message)
    local matched = type(haystack) == "string" and haystack:find(needle, 1, true) ~= nil
    assertEqual(true, matched, message)
end

print("\n=== Tooltip Helper Tests ===\n")

dofile("Modules/CIM/Tooltips/Tooltips.lua")

print("Test: Store tooltip pricing falls back to a single-item stack when no bag context exists")
local singlePriceLines = BETTERUI.GetInventoryPriceInfo("item:single", nil, nil, nil)
assertEqual(1, #singlePriceLines, "Single-price tooltip line is generated")
assertContains(singlePriceLines[1], "ATT Price: 10", "Single-price line uses the single-item market value")

print("\nTest: Store tooltip pricing preserves explicit stack counts")
local stackPriceLines = BETTERUI.GetInventoryPriceInfo("item:stack", nil, nil, 4)
assertEqual(1, #stackPriceLines, "Stack-price tooltip line is generated")
assertContains(stackPriceLines[1], "Stack(4): 100", "Stack-price line uses the provided store stack count")

print("\nTest: Inventory hook preserves tooltip-seeded store stack counts")
BETTERUI.Inventory.UpdateTooltipEquippedText = function() end

local tooltipControl = {
    LayoutItem = function() end,
    LayoutBagItem = function() end,
    LayoutStoreItemFromLink = function() end,
    GetNumChildren = function()
        return 0
    end,
    GetChild = function()
        return nil
    end,
    IsHidden = function()
        return false
    end,
}

BETTERUI.InventoryHook(
    tooltipControl,
    "mockTooltip",
    "LayoutItem",
    function()
        return "item:stack"
    end,
    "LayoutBagItem",
    function()
        return nil, nil
    end,
    "LayoutStoreItemFromLink",
    function()
        return nil, nil
    end
)

tooltipControl._betterui_storeStackCount = 4
tooltipControl:LayoutItem("item:stack")
assertEqual(4, tooltipControl._betterui_storeStackCount, "Hook reuses tooltip-seeded store stack count")

print("\nTest: Knowledge helper reports recipe state and respects setting toggle")
local unknownRecipeLines = BETTERUI.GetInventoryKnowledgeInfo("recipe:unknown")
assertEqual(1, #unknownRecipeLines, "Unknown recipe renders one knowledge line")
assertContains(unknownRecipeLines[1], "Use to Learn", "Unknown recipe line uses the learn prompt")

local knownBookLines = BETTERUI.GetInventoryKnowledgeInfo("book:known")
assertEqual(1, #knownBookLines, "Known book renders one knowledge line")
assertContains(knownBookLines[1], "In Library", "Known book line uses the library string")

BETTERUI.Settings.Modules.GeneralInterface.showKnowledgeStatus = false
local disabledLines = BETTERUI.GetInventoryKnowledgeInfo("recipe:known")
assertEqual(0, #disabledLines, "Knowledge lines are suppressed when the setting is disabled")

print("\n=== Test Summary ===")
print(string.format("Passed: %d", testsPassed))
print(string.format("Failed: %d", testsFailed))

if testsFailed > 0 then
    os.exit(1)
else
    print("\nAll tests passed!")
    os.exit(0)
end
