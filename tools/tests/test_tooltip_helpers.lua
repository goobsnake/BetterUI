--[[
File: tools/tests/test_tooltip_helpers.lua
Purpose: Targeted unit tests for tooltip pricing and knowledge helpers.

Usage:
  lua tools/tests/test_tooltip_helpers.lua
]]

SI_BETTERUI_MARKET_NO_PRICE_DATA = "SI_BETTERUI_MARKET_NO_PRICE_DATA"
SI_BETTERUI_MARKET_PRICE = "SI_BETTERUI_MARKET_PRICE"
SI_BETTERUI_MARKET_PRICE_STACK = "SI_BETTERUI_MARKET_PRICE_STACK"
SI_BETTERUI_MARKET_TTC_AVG_SUG = "SI_BETTERUI_MARKET_TTC_AVG_SUG"
SI_BETTERUI_MARKET_TTC_AVG = "SI_BETTERUI_MARKET_TTC_AVG"
SI_BETTERUI_MARKET_TTC_SUG = "SI_BETTERUI_MARKET_TTC_SUG"
SI_BETTERUI_MARKET_TTC_STACK_AVG_SUG = 108
SI_BETTERUI_MARKET_TTC_STACK_AVG = 109
SI_BETTERUI_MARKET_TTC_STACK_SUG = 110
SI_RECIPE_ALREADY_KNOWN = "SI_RECIPE_ALREADY_KNOWN"
SI_USE_TO_LEARN_RECIPE = "SI_USE_TO_LEARN_RECIPE"
SI_LORE_LIBRARY_IN_LIBRARY = "SI_LORE_LIBRARY_IN_LIBRARY"
SI_LORE_LIBRARY_USE_TO_LEARN = "SI_LORE_LIBRARY_USE_TO_LEARN"

CURT_MONEY = 1
ITEMTYPE_RECIPE = 42
EVENT_INVENTORY_SINGLE_SLOT_UPDATE = 1
CT_LABEL = 1
INVENTORY_UPDATE_REASON_DEFAULT = 0

local stringMap = {
    [SI_BETTERUI_MARKET_NO_PRICE_DATA] = "<<1>>: No Price Data",
    [SI_BETTERUI_MARKET_PRICE] = "<<1>>: <<2>>",
    [SI_BETTERUI_MARKET_PRICE_STACK] = "<<1>>: <<2>>, (<<3>>x) <<4>>",
    [SI_BETTERUI_MARKET_TTC_AVG_SUG] = "TTC: Avg: <<1>> / Sug: <<2>>",
    [SI_BETTERUI_MARKET_TTC_AVG] = "TTC: Avg: <<1>>",
    [SI_BETTERUI_MARKET_TTC_SUG] = "TTC: Sug: <<1>>",
    [SI_BETTERUI_MARKET_TTC_STACK_AVG_SUG] = "TTC: (<<1>>x) Avg: <<2>> / Sug: <<3>>",
    [SI_BETTERUI_MARKET_TTC_STACK_AVG] = "TTC: (<<1>>x) Avg: <<2>>",
    [SI_BETTERUI_MARKET_TTC_STACK_SUG] = "TTC: (<<1>>x) Sug: <<2>>",
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

function ZO_PreHook(control, methodName, callback)
    local original = control[methodName]
    control[methodName] = function(self, ...)
        local blocked = callback(self, ...)
        if blocked then
            return
        end
        return original(self, ...)
    end
end

function ZO_PostHook(control, methodName, callback)
    local original = control[methodName]
    control[methodName] = function(self, ...)
        local unpackFn = table.unpack or unpack
        local results = { original(self, ...) }
        callback(self, ...)
        return unpackFn(results)
    end
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

-- TTC mock globals (must be set before dofile)
TamrielTradeCentre_ItemInfo = {
    New = function(_, itemLink)
        return { link = itemLink }
    end,
}

TamrielTradeCentrePrice = {
    GetPriceInfo = function(_, itemInfo)
        if itemInfo.link == "ttc:both" or itemInfo.link == "ttc:both:stack" then
            return { Avg = 15, SuggestedPrice = 20 }
        elseif itemInfo.link == "ttc:avgonly" or itemInfo.link == "ttc:avgonly:stack" then
            return { Avg = 30, SuggestedPrice = nil }
        elseif itemInfo.link == "ttc:sugonly" then
            return { Avg = nil, SuggestedPrice = 50 }
        end
        return nil
    end,
}

TamrielTradeCentre = true

BETTERUI = {
    Settings = {
        Modules = {
            GeneralInterface = {
                attIntegration = true,
                ttcIntegration = true,
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
        SafeExecute = function(_, fn, ...)
            return pcall(fn, ...)
        end,
    },
    CONST = {
        TOOLTIP = {
            DEFAULT_FONT_SIZE = 24,
        },
    },
    GeneralInterface = {
        InvalidateResearchableTraitCache = function() end,
    },
    Inventory = {},
}

function BETTERUI.GetSetting(moduleName, key, fallback)
    local mod = BETTERUI.Settings.Modules[moduleName]
    if mod and mod[key] ~= nil then return mod[key] end
    return fallback
end

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

dofile("Modules/GeneralInterface/Tooltips/Tooltips.lua")

-- Helper to find a line containing a specific substring from a list
local function findLine(lines, needle)
    for _, line in ipairs(lines) do
        if type(line) == "string" and line:find(needle, 1, true) then
            return line
        end
    end
    return nil
end

print("Test: Store tooltip pricing falls back to a single-item stack when no bag context exists")
local singlePriceLines = BETTERUI.GetInventoryPriceInfo("item:single", nil, nil, nil)
assertEqual(true, #singlePriceLines >= 1, "Single-price tooltip line is generated")
local attSingleLine = findLine(singlePriceLines, "ATT")
assertEqual(true, attSingleLine ~= nil, "ATT single-price line is present")
assertContains(attSingleLine, "ATT: 10", "Single-price line uses the single-item market value")

print("\nTest: Store tooltip pricing preserves explicit stack counts")
local stackPriceLines = BETTERUI.GetInventoryPriceInfo("item:stack", nil, nil, 4)
assertEqual(true, #stackPriceLines >= 1, "Stack-price tooltip line is generated")
local attStackLine = findLine(stackPriceLines, "ATT")
assertEqual(true, attStackLine ~= nil, "ATT stack-price line is present")
assertContains(attStackLine, "(4x) 100", "Stack-price line uses the provided store stack count")

-- === TTC Integration Tests ===

print("\nTest: TTC single item shows per-unit Avg+Sug (no stack line)")
local ttcSingleLines = BETTERUI.GetInventoryPriceInfo("ttc:both", nil, nil, 1)
assertEqual(true, #ttcSingleLines >= 1, "TTC single item generates at least one price line")
local ttcSingleLine = findLine(ttcSingleLines, "TTC")
assertEqual(true, ttcSingleLine ~= nil, "TTC single item has a TTC price line")
assertContains(ttcSingleLine, "Avg: 15", "TTC single shows avg price")
assertContains(ttcSingleLine, "Sug: 20", "TTC single shows suggested price")
-- Verify no stack info for single items
assertEqual(nil, ttcSingleLine:find("%dx ", 1), "TTC single item has no stack text")

print("\nTest: TTC stacked item shows per-unit line + separate stack total line")
local ttcStackLines = BETTERUI.GetInventoryPriceInfo("ttc:both:stack", nil, nil, 10)
-- Should produce at least 2 TTC lines: per-unit + stack total
local ttcPerUnit = findLine(ttcStackLines, "TTC: Avg")
assertEqual(true, ttcPerUnit ~= nil, "TTC stack has per-unit price line")
assertContains(ttcPerUnit, "Avg: 15", "TTC per-unit line shows avg")
assertContains(ttcPerUnit, "Sug: 20", "TTC per-unit line shows sug")
local ttcStackTotal = findLine(ttcStackLines, "x) Avg")
assertEqual(true, ttcStackTotal ~= nil, "TTC stack has stack total line")
assertContains(ttcStackTotal, "(10x)", "TTC stack total shows Nx count")
assertContains(ttcStackTotal, "Avg:", "TTC stack total shows Avg label")
assertContains(ttcStackTotal, "150", "TTC stack total shows avg total (15*10)")
assertContains(ttcStackTotal, "Sug:", "TTC stack total shows Sug label")
assertContains(ttcStackTotal, "200", "TTC stack total shows sug total (20*10)")

print("\nTest: TTC avg-only stacked item shows per-unit + stack total")
local ttcAvgStackLines = BETTERUI.GetInventoryPriceInfo("ttc:avgonly:stack", nil, nil, 5)
local ttcAvgPerUnit = findLine(ttcAvgStackLines, "TTC: Avg")
assertEqual(true, ttcAvgPerUnit ~= nil, "TTC avg-only has per-unit line")
assertContains(ttcAvgPerUnit, "Avg: 30", "TTC avg-only per-unit shows avg")
local ttcAvgStackTotal = findLine(ttcAvgStackLines, "x) Avg")
assertEqual(true, ttcAvgStackTotal ~= nil, "TTC avg-only has stack total line")
assertContains(ttcAvgStackTotal, "(5x)", "TTC avg-only stack total shows Nx count")
assertContains(ttcAvgStackTotal, "150", "TTC avg-only stack total shows total (30*5)")

print("\nTest: TTC no data shows fallback")
local ttcNoDataLines = BETTERUI.GetInventoryPriceInfo("ttc:nonexistent", nil, nil, 1)
local ttcNoDataLine = findLine(ttcNoDataLines, "TTC")
assertEqual(true, ttcNoDataLine ~= nil, "TTC no-data has a TTC fallback line")
assertContains(ttcNoDataLine, "No Price Data", "TTC no-data shows fallback message")

print("\nTest: Inventory hook preserves tooltip-seeded store stack counts")
BETTERUI.Inventory.UpdateTooltipEquippedText = function() end

local tooltipControl = {
    LayoutItem = function() end,
    LayoutBagItem = function() end,
    LayoutStoreItemFromLink = function() end,
    ClearLines = function() end,
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

print("\nTest: Inventory hook clears stale enhancement state for non-item layouts")
local cleanupCalls = 0
local updateCalls = 0
local origCleanup = BETTERUI.Inventory.CleanupEnhancedTooltip
local origUpdateForStateTest = BETTERUI.Inventory.UpdateTooltipEquippedText

BETTERUI.Inventory.CleanupEnhancedTooltip = function()
    cleanupCalls = cleanupCalls + 1
end

BETTERUI.Inventory.UpdateTooltipEquippedText = function()
    updateCalls = updateCalls + 1
end

local staleStateTooltip = {
    LayoutItem = function() end,
    LayoutBagItem = function() end,
    LayoutStoreItemFromLink = function() end,
    ClearLines = function() end,
    GetNumChildren = function() return 0 end,
    GetChild = function() return nil end,
    IsHidden = function() return false end,
}

BETTERUI.InventoryHook(
    staleStateTooltip,
    "mockStateTooltip",
    "LayoutItem",
    function(itemLink)
        return itemLink
    end,
    "LayoutBagItem",
    function()
        return 1, 2
    end,
    "LayoutStoreItemFromLink",
    function() return nil, nil end
)

staleStateTooltip:LayoutBagItem()
staleStateTooltip:LayoutItem("item:valid")
assertEqual("item:valid", staleStateTooltip._betterui_itemLink, "Valid item layout keeps BetterUI item link")

staleStateTooltip:LayoutItem("SKILL_TOOLTIP_ROW")
assertEqual(nil, staleStateTooltip._betterui_itemLink, "Non-item layout clears BetterUI item link")
assertEqual(nil, staleStateTooltip._betterui_bagId, "Non-item layout clears stale bag context")
assertEqual(1, updateCalls, "Non-item layout does not schedule enhanced item header rendering")
assertEqual(true, cleanupCalls >= 1, "Non-item layout requests enhanced tooltip cleanup")

staleStateTooltip:ClearLines()
assertEqual(true, cleanupCalls >= 2, "ClearLines hook resets BetterUI tooltip state")

BETTERUI.Inventory.CleanupEnhancedTooltip = origCleanup
BETTERUI.Inventory.UpdateTooltipEquippedText = origUpdateForStateTest

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

print("\nTest: Blocklist guard passes through to native method when housing scene is active")
-- Simulate housing furniture browser scene being active
GAMEPAD_HOUSING_FURNITURE_BROWSER_SCENE = {
    IsShowing = function() return true end
}

local nativeMethodCalled = false
local linkFuncCalled = false

local housingTooltip = {
    LayoutItem = function() nativeMethodCalled = true end,
    LayoutBagItem = function() end,
    LayoutStoreItemFromLink = function() end,
    GetNumChildren = function() return 0 end,
    GetChild = function() return nil end,
    IsHidden = function() return false end,
}

BETTERUI.InventoryHook(
    housingTooltip,
    "mockHousingTooltip",
    "LayoutItem",
    function()
        linkFuncCalled = true
        return "test:item"
    end,
    "LayoutBagItem",
    function() return nil, nil end,
    "LayoutStoreItemFromLink",
    function() return nil, nil end
)

-- Call the hooked method with housing scene active
housingTooltip:LayoutItem("furniture_data")
assertEqual(true, nativeMethodCalled, "Native LayoutItem method is called (pass-through)")
assertEqual(false, linkFuncCalled, "linkFunc is NOT called (BetterUI logic skipped entirely)")

print("\nTest: Blocklist guard on method2 (LayoutBagItem) passes through to native method")
local nativeMethod2Called = false
local linkFunc2Called = false

local housingTooltip2 = {
    LayoutItem = function() end,
    LayoutBagItem = function() nativeMethod2Called = true end,
    LayoutStoreItemFromLink = function() end,
    GetNumChildren = function() return 0 end,
    GetChild = function() return nil end,
    IsHidden = function() return false end,
}

BETTERUI.InventoryHook(
    housingTooltip2,
    "mockHousingTooltip2",
    "LayoutItem",
    function() return nil end,
    "LayoutBagItem",
    function()
        linkFunc2Called = true
        return nil, nil
    end,
    "LayoutStoreItemFromLink",
    function() return nil, nil end
)

housingTooltip2:LayoutBagItem("furniture_data")
assertEqual(true, nativeMethod2Called, "Native LayoutBagItem is called (pass-through)")
assertEqual(false, linkFunc2Called, "linkFunc2 is NOT called (BetterUI logic skipped)")

print("\nTest: pcall safety net absorbs crashing linkFunc for unknown scene conflicts")
-- Remove the housing scene so blocklist guard doesn't fire
GAMEPAD_HOUSING_FURNITURE_BROWSER_SCENE = nil

local crashTooltip = {
    LayoutItem = function() end,
    LayoutBagItem = function() end,
    LayoutStoreItemFromLink = function() end,
    GetNumChildren = function() return 0 end,
    GetChild = function() return nil end,
    IsHidden = function() return false end,
}

BETTERUI.InventoryHook(
    crashTooltip,
    "mockCrashTooltip",
    "LayoutItem",
    function() error("linkFunc crash: unexpected data") end,
    "LayoutBagItem",
    function() error("linkFunc2 crash: unexpected data") end,
    "LayoutStoreItemFromLink",
    function() error("linkFunc3 crash: unexpected data") end
)

-- Each hooked method should absorb the error via pcall, not propagate it
local pcallOk1, _ = pcall(crashTooltip.LayoutBagItem, crashTooltip, "unknown_data")
assertEqual(true, pcallOk1, "LayoutBagItem pcall safety net absorbs crashing linkFunc2")

local pcallOk2, _ = pcall(crashTooltip.LayoutStoreItemFromLink, crashTooltip, "unknown_data")
assertEqual(true, pcallOk2, "LayoutStoreItemFromLink pcall safety net absorbs crashing linkFunc3")

local pcallOk3, _ = pcall(crashTooltip.LayoutItem, crashTooltip, "unknown_data")
assertEqual(true, pcallOk3, "LayoutItem pcall safety net absorbs crashing linkFunc")

print("\nTest: Deferred callback skipped when housing scene becomes active mid-frame")
-- Simulate: deferred callback was scheduled while inventory was active,
-- but by the time it fires, the housing scene has become active (race condition)
local updateCalled = false
local origUpdate = BETTERUI.Inventory.UpdateTooltipEquippedText
BETTERUI.Inventory.UpdateTooltipEquippedText = function()
    updateCalled = true
end

local raceTooltip = {
    LayoutItem = function() end,
    LayoutBagItem = function() end,
    LayoutStoreItemFromLink = function() end,
    GetNumChildren = function() return 0 end,
    GetChild = function() return nil end,
    IsHidden = function() return false end,
}

-- Hook with housing scene inactive (normal inventory state)
GAMEPAD_HOUSING_FURNITURE_BROWSER_SCENE = nil
BETTERUI.InventoryHook(
    raceTooltip,
    "mockRaceTooltip",
    "LayoutItem",
    function() return "test:item" end,
    "LayoutBagItem",
    function() return nil, nil end,
    "LayoutStoreItemFromLink",
    function() return nil, nil end
)

-- Now activate the housing scene BEFORE LayoutItem fires
-- (simulating the race condition where scene transition happens mid-frame)
GAMEPAD_HOUSING_FURNITURE_BROWSER_SCENE = {
    IsShowing = function() return true end
}
-- LayoutItem with housing active → blocklist guard fires, no deferred scheduled
raceTooltip:LayoutItem("test:item")
assertEqual(false, updateCalled, "Deferred header injection skipped when housing scene is active")

-- Restore
BETTERUI.Inventory.UpdateTooltipEquippedText = origUpdate
GAMEPAD_HOUSING_FURNITURE_BROWSER_SCENE = nil

print("\n=== Test Summary ===")
print(string.format("Passed: %d", testsPassed))
print(string.format("Failed: %d", testsFailed))

if testsFailed > 0 then
    os.exit(1)
else
    print("\nAll tests passed!")
    os.exit(0)
end
