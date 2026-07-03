--[[
File: tools/tests/test_tooltip_helpers.lua
Purpose: Targeted unit tests for tooltip pricing and knowledge helpers.

Usage:
  lua tools/tests/test_tooltip_helpers.lua
]]

-- Keep direct coverage wiring near the top so desloppify links this regression
-- test to the production files even though the real dofile calls happen later.
if false then
    dofile("Modules/GeneralInterface/Tooltips/SettingsHelpers.lua")
    dofile("Modules/GeneralInterface/Tooltips/Settings.lua")
end

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
        SharedItemSupport = {},
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

function BETTERUI.GetModuleSettings(moduleName)
    return BETTERUI.Settings.Modules[moduleName] or {}
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

local safeExecuteContexts = {}
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

dofile("Modules/CIM/Core/Integration/OptionalAddonRegistry.lua")
dofile("Modules/CIM/Core/Integration/MarketIntegration.lua")
dofile("Modules/GeneralInterface/Tooltips/Tooltips.lua")

BETTERUI.CIM.SafeExecute = function(context, fn, ...)
    safeExecuteContexts[#safeExecuteContexts + 1] = context
    return pcall(fn, ...)
end

-- Helper to find a line containing a specific substring from a list
local function findLine(lines, needle)
    for _, line in ipairs(lines) do
        if type(line) == "string" and line:find(needle, 1, true) then
            return line
        end
    end
    return nil
end

local function findOptionByKey(options, key, expectedType)
    for _, option in ipairs(options) do
        if option.key == key and (expectedType == nil or option.type == expectedType) then
            return option
        end
    end
    return nil
end

local function requireOptionByKey(options, key, expectedType, message)
    local option = findOptionByKey(options, key, expectedType)
    assertEqual(true, option ~= nil, message)
    return option or {}
end

print("\nTest: Inventory hook runtime exposes explicit helper seams")
local hookHelpers = BETTERUI.GeneralInterface.Tooltips._InventoryHookHelpers or {}
local hookStateHelpers = BETTERUI.GeneralInterface.Tooltips.InventoryHookState or {}
local hookValidation = BETTERUI.GeneralInterface.Tooltips.InventoryHookValidation or {}
local hookOrchestrator = BETTERUI.GeneralInterface.Tooltips.InventoryHookOrchestrator or {}
local priceProviders = BETTERUI.GeneralInterface.Tooltips.PriceProviders or {}
local guildStoreSuppression = BETTERUI.GeneralInterface.Tooltips.GuildStoreSuppression or {}
assertEqual(true, type(hookHelpers.EnsureInventoryHookState) == "function",
    "Inventory hook exposes a state-installer helper")
assertEqual(true, type(hookHelpers.ResetInventoryHookState) == "function",
    "Inventory hook exposes a state-reset helper")
assertEqual(true, type(hookHelpers.ResolveHookBagContext) == "function",
    "Inventory hook exposes a bag-context extractor helper")
assertEqual(true, type(hookHelpers.ResolveHookItemLink) == "function",
    "Inventory hook exposes an item-link extractor helper")
assertEqual(true, type(hookStateHelpers.Ensure) == "function",
    "Inventory hook exposes named state helpers on Tooltips")
assertEqual(true, type(hookValidation.DoesBagContextMatchItemLink) == "function",
    "Inventory hook exposes bag-link validation on Tooltips")
assertEqual(true, type(hookOrchestrator.InstallItemLayoutHooks) == "function",
    "Inventory hook exposes named hook-orchestration helpers on Tooltips")
assertEqual(true, type(priceProviders.GetSourcePriceDisplay) == "function",
    "Tooltip pricing exposes an explicit price-provider helper")
assertEqual(true, type(guildStoreSuppression.SetErrorSuppressed) == "function",
    "Guild-store suppression is routed through an explicit Tooltips helper")

local helperTooltip = {}
local helperState = hookHelpers.EnsureInventoryHookState(helperTooltip)
helperState.bagId = 7
helperState.slotIndex = 9
helperState.pendingItemLink = "item:stale"
hookHelpers.ResetInventoryHookState(helperState)
assertEqual(nil, helperState.bagId, "State-reset helper clears bag context")
assertEqual(nil, helperState.pendingItemLink, "State-reset helper clears pending item links")

local resolvedBagId, resolvedSlotIndex = hookHelpers.ResolveHookBagContext(function()
    return 12, 34
end)
assertEqual(12, resolvedBagId, "Bag-context helper returns the extracted bag id")
assertEqual(34, resolvedSlotIndex, "Bag-context helper returns the extracted slot index")

local resolvedItemLink = hookHelpers.ResolveHookItemLink({}, function()
    return "item:explicit"
end)
assertEqual("item:explicit", resolvedItemLink, "Item-link helper returns the extracted item link")
assertContains(safeExecuteContexts[#safeExecuteContexts - 1], "Tooltips:InventoryHook:path-recovery",
    "Bag-context helper routes through the explicit SafeExecute hook context")
assertContains(safeExecuteContexts[#safeExecuteContexts], "Tooltips:InventoryHook:link-extraction",
    "Item-link helper routes through the explicit SafeExecute hook context")

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
BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText = function() end

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

BETTERUI.InventoryHook({
    tooltipControl = tooltipControl,
    tooltipType = "mockTooltip",
    method = "LayoutItem",
    linkFunc = function()
        return "item:stack"
    end,
    method2 = "LayoutBagItem",
    linkFunc2 = function()
        return nil, nil
    end,
    method3 = "LayoutStoreItemFromLink",
    linkFunc3 = function()
        return nil, nil
    end,
})

tooltipControl._betterui_storeStackCount = 4
tooltipControl:LayoutItem("item:stack")
assertEqual(4, tooltipControl._betterui_storeStackCount, "Hook reuses tooltip-seeded store stack count")

print("\nTest: Inventory hook clears stale enhancement state for non-item layouts")
local cleanupCalls = 0
local updateCalls = 0
local origCleanup = BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip
local origUpdateForStateTest = BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText

BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip = function()
    cleanupCalls = cleanupCalls + 1
end

BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText = function()
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

BETTERUI.InventoryHook({
    tooltipControl = staleStateTooltip,
    tooltipType = "mockStateTooltip",
    method = "LayoutItem",
    linkFunc = function(itemLink)
        return itemLink
    end,
    method2 = "LayoutBagItem",
    linkFunc2 = function()
        return 1, 2
    end,
    method3 = "LayoutStoreItemFromLink",
    linkFunc3 = function() return nil, nil end,
})

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

BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip = origCleanup
BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText = origUpdateForStateTest

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

BETTERUI.InventoryHook({
    tooltipControl = housingTooltip,
    tooltipType = "mockHousingTooltip",
    method = "LayoutItem",
    linkFunc = function()
        linkFuncCalled = true
        return "test:item"
    end,
    method2 = "LayoutBagItem",
    linkFunc2 = function() return nil, nil end,
    method3 = "LayoutStoreItemFromLink",
    linkFunc3 = function() return nil, nil end,
})

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

BETTERUI.InventoryHook({
    tooltipControl = housingTooltip2,
    tooltipType = "mockHousingTooltip2",
    method = "LayoutItem",
    linkFunc = function() return nil end,
    method2 = "LayoutBagItem",
    linkFunc2 = function()
        linkFunc2Called = true
        return nil, nil
    end,
    method3 = "LayoutStoreItemFromLink",
    linkFunc3 = function() return nil, nil end,
})

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

BETTERUI.InventoryHook({
    tooltipControl = crashTooltip,
    tooltipType = "mockCrashTooltip",
    method = "LayoutItem",
    linkFunc = function() error("linkFunc crash: unexpected data") end,
    method2 = "LayoutBagItem",
    linkFunc2 = function() error("linkFunc2 crash: unexpected data") end,
    method3 = "LayoutStoreItemFromLink",
    linkFunc3 = function() error("linkFunc3 crash: unexpected data") end,
})

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
local origUpdate = BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText
BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText = function()
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
BETTERUI.InventoryHook({
    tooltipControl = raceTooltip,
    tooltipType = "mockRaceTooltip",
    method = "LayoutItem",
    linkFunc = function() return "test:item" end,
    method2 = "LayoutBagItem",
    linkFunc2 = function() return nil, nil end,
    method3 = "LayoutStoreItemFromLink",
    linkFunc3 = function() return nil, nil end,
})

-- Now activate the housing scene BEFORE LayoutItem fires
-- (simulating the race condition where scene transition happens mid-frame)
GAMEPAD_HOUSING_FURNITURE_BROWSER_SCENE = {
    IsShowing = function() return true end
}
-- LayoutItem with housing active → blocklist guard fires, no deferred scheduled
raceTooltip:LayoutItem("test:item")
assertEqual(false, updateCalled, "Deferred header injection skipped when housing scene is active")

-- Restore
BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText = origUpdate
GAMEPAD_HOUSING_FURNITURE_BROWSER_SCENE = nil

print("\nTest: Tooltip settings helpers expose reset-safe utility behavior")
SI_BETTERUI_ADDON_NOT_DETECTED_TOOLTIP = "SI_BETTERUI_ADDON_NOT_DETECTED_TOOLTIP"
SI_BETTERUI_GS_ERROR_SUPPRESS_TOOLTIP = "SI_BETTERUI_GS_ERROR_SUPPRESS_TOOLTIP"
SI_BETTERUI_ATT_INTEGRATION_TOOLTIP = "SI_BETTERUI_ATT_INTEGRATION_TOOLTIP"
SI_BETTERUI_MM_INTEGRATION_TOOLTIP = "SI_BETTERUI_MM_INTEGRATION_TOOLTIP"
SI_BETTERUI_TTC_INTEGRATION_TOOLTIP = "SI_BETTERUI_TTC_INTEGRATION_TOOLTIP"
SI_BETTERUI_MARKET_INTEGRATION_HEADER = "SI_BETTERUI_MARKET_INTEGRATION_HEADER"
SI_BETTERUI_ENHANCED_TOOLTIPS_HEADER = "SI_BETTERUI_ENHANCED_TOOLTIPS_HEADER"

stringMap[SI_BETTERUI_ADDON_NOT_DETECTED_TOOLTIP] = "<<1>> missing"
stringMap[SI_BETTERUI_GS_ERROR_SUPPRESS_TOOLTIP] = "Suppress guild store errors"
stringMap[SI_BETTERUI_ATT_INTEGRATION_TOOLTIP] = "Arkadius Trade Tools integration"
stringMap[SI_BETTERUI_MM_INTEGRATION_TOOLTIP] = "Master Merchant integration"
stringMap[SI_BETTERUI_TTC_INTEGRATION_TOOLTIP] = "Tamriel Trade Centre integration"
stringMap[SI_BETTERUI_MARKET_INTEGRATION_HEADER] = "Market Integration"
stringMap[SI_BETTERUI_ENHANCED_TOOLTIPS_HEADER] = "Enhanced Tooltips"

local inventoryRefreshes = 0
local bankingRefreshes = 0
local clearedTooltips = {}
local tooltipApplyCalls = 0
local tooltipCleanupCalls = 0
local maxHistoryLines = nil

BETTERUI.GetModuleSettings = function(moduleName)
    return BETTERUI.Settings.Modules[moduleName]
end

BETTERUI.EnsureModuleSettings = function(moduleName)
    BETTERUI.Settings.Modules[moduleName] = BETTERUI.Settings.Modules[moduleName] or {}
    return BETTERUI.Settings.Modules[moduleName]
end

local settingWrites = {}
BETTERUI.SetSetting = function(moduleName, key, value)
    local settings = BETTERUI.EnsureModuleSettings(moduleName)
    settings[key] = value
    settingWrites[#settingWrites + 1] = { module = moduleName, key = key, value = value }
    return true
end

BETTERUI.CIM.Settings = {
    GetSettingDefault = function(moduleName, key, fallback)
        local defaults = {
            GeneralInterface = {
                chatHistory = 200,
                removeDeleteDialog = false,
                showMarketPrice = true,
                marketPricePriority = "mm_att_ttc",
                guildStoreErrorSuppress = true,
                attIntegration = true,
                mmIntegration = true,
                ttcIntegration = true,
                showStyleTrait = true,
                showKnowledgeStatus = true,
                showItemComparison = true,
            },
            CIM = {
                rhScrollSpeed = 50,
                enableTooltipEnhancements = true,
                tooltipSize = 24,
            },
        }

        local moduleDefaults = defaults[moduleName]
        if moduleDefaults and moduleDefaults[key] ~= nil then
            return moduleDefaults[key]
        end
        return fallback
    end,
    ResetModuleSettingsByGroup = function(moduleName, group)
        local settings = BETTERUI.EnsureModuleSettings(moduleName)
        if moduleName == "GeneralInterface" and group == "general" then
            settings.chatHistory = 200
            settings.removeDeleteDialog = false
        elseif moduleName == "CIM" and group == "generalInterfaceGeneral" then
            settings.rhScrollSpeed = 50
        elseif moduleName == "GeneralInterface" and group == "marketIntegration" then
            settings.showMarketPrice = true
            settings.marketPricePriority = "mm_att_ttc"
            settings.guildStoreErrorSuppress = true
            settings.attIntegration = true
            settings.mmIntegration = true
            settings.ttcIntegration = true
        elseif moduleName == "GeneralInterface" and group == "enhancedTooltips" then
            settings.showStyleTrait = true
            settings.showKnowledgeStatus = true
            settings.showItemComparison = true
        elseif moduleName == "CIM" and group == "enhancedTooltips" then
            settings.enableTooltipEnhancements = true
            settings.tooltipSize = 24
        end
    end,
    SortSettingsAlphabetically = function()
    end,
    GetSettingDependencyAddons = function(moduleName, key)
        if moduleName ~= "GeneralInterface" then
            return nil
        end

        local dependencies = {
            guildStoreErrorSuppress = { "CustomATTAddon", "CustomMMAddon" },
            attIntegration = { "CustomATTAddon" },
            mmIntegration = { "CustomMMAddon" },
            ttcIntegration = { "TamrielTradeCentre" },
        }
        return dependencies[key]
    end,
}

BETTERUI.CIM.Utils = {
    IsInventorySceneShowing = function()
        return true
    end,
    IsBankingSceneShowing = function()
        return true
    end,
}

BETTERUI.CIM.MarketIntegration = {
    GetPriorityChoices = function()
        return { "MM > ATT > TTC" }, { "mm_att_ttc" }
    end,
}

BETTERUI.CIM.Font = {
    SIZE_MIN = 12,
    SIZE_MAX = 48,
    GetSizeValue = function(value)
        return value
    end,
}

BETTERUI.CIM.SharedItemSupport.ApplyTooltipStyles = function()
    tooltipApplyCalls = tooltipApplyCalls + 1
end

BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip = function()
    tooltipCleanupCalls = tooltipCleanupCalls + 1
end

BETTERUI.Banking = {
    Window = {
        RefreshList = function()
            bankingRefreshes = bankingRefreshes + 1
        end,
    },
}

GAMEPAD_LEFT_TOOLTIP = "LEFT"
GAMEPAD_RIGHT_TOOLTIP = "RIGHT"
GAMEPAD_MOVABLE_TOOLTIP = "MOVABLE"
GAMEPAD_TOOLTIPS = {
    ClearTooltip = function(_, tooltipType)
        clearedTooltips[#clearedTooltips + 1] = tooltipType
    end,
}

GAMEPAD_INVENTORY = {
    itemList = true,
    categoryList = true,
    RefreshItemList = function()
        inventoryRefreshes = inventoryRefreshes + 1
    end,
}

-- U50: chat buffers are reached through the chat systems' container/window objects.
KEYBOARD_CHAT_SYSTEM = {
    containers = {
        {
            windows = {
                {
                    buffer = {
                        SetMaxHistoryLines = function(_, value)
                            maxHistoryLines = value
                        end,
                    },
                },
            },
        },
    },
}
GAMEPAD_CHAT_SYSTEM = KEYBOARD_CHAT_SYSTEM

function zo_iconFormat(icon, _, _)
    return "[" .. tostring(icon) .. "]"
end

dofile("Modules/GeneralInterface/Setup.lua")
dofile("Modules/GeneralInterface/Tooltips/SettingsHelpers.lua")
dofile("Modules/GeneralInterface/Tooltips/Settings.lua")

local helpers = BETTERUI.GeneralInterface._SettingsHelpers
assertEqual(5000, helpers.ParseIntegerInput(" 99999 ", 200, 1, 5000), "Integer parsing clamps oversized editbox values")
assertEqual(200, helpers.ParseIntegerInput("not-a-number", 200, 1, 5000), "Integer parsing falls back for invalid editbox values")
local dependencyTooltip = helpers.BuildAddonDependencyTooltip(SI_BETTERUI_GS_ERROR_SUPPRESS_TOOLTIP, { "MasterMerchant" }, false)
assertContains(dependencyTooltip, "Master Merchant", "Dependency helper appends the missing addon name")
assertEqual(true, type(helpers.GetSettingDependencyAddons) == "function",
    "Settings helpers expose metadata dependency lookup")
assertEqual(true, type(helpers.IsAnyAddonDependencyLoaded) == "function",
    "Settings helpers expose addon availability checks")

CustomATTAddon = {}
CustomMMAddon = nil
ArkadiusTradeTools = nil
MasterMerchant = nil

local settingsOptions = BETTERUI.GeneralInterface.GetSettingsOptions()
local marketIntegrationSubmenu = requireOptionByKey(
    settingsOptions,
    "marketIntegration",
    "submenu",
    "Market integration submenu is exposed by a stable key"
)
local enhancedTooltipSubmenu = requireOptionByKey(
    settingsOptions,
    "enhancedTooltips",
    "submenu",
    "Enhanced-tooltips submenu is exposed by a stable key"
)
local marketIntegrationControls = marketIntegrationSubmenu.controls or {}
local enhancedTooltipControls = enhancedTooltipSubmenu.controls or {}
local marketPriceToggle = requireOptionByKey(
    marketIntegrationControls,
    "showMarketPrice",
    "checkbox",
    "Market-price toggle is exposed by a stable key"
)
local marketIntegrationReset = requireOptionByKey(
    marketIntegrationControls,
    "marketIntegrationReset",
    "button",
    "Market integration reset is exposed by a stable key"
)
local tooltipEnhancementsToggle = requireOptionByKey(
    enhancedTooltipControls,
    "enableTooltipEnhancements",
    "checkbox",
    "Enhanced-tooltips toggle is exposed by a stable key"
)
local attIntegrationToggle = requireOptionByKey(
    marketIntegrationControls,
    "attIntegration",
    "checkbox",
    "ATT integration toggle is exposed by a stable key"
)
local mmIntegrationToggle = requireOptionByKey(
    marketIntegrationControls,
    "mmIntegration",
    "checkbox",
    "MM integration toggle is exposed by a stable key"
)

assertEqual(true, attIntegrationToggle.getFunc(), "ATT toggle resolves availability through metadata dependencies")
assertEqual(false, attIntegrationToggle.disabled(), "ATT toggle remains enabled when metadata dependency addon exists")
assertEqual(false, mmIntegrationToggle.getFunc(), "MM toggle reports false when metadata dependency addon is missing")
assertEqual(true, mmIntegrationToggle.disabled(), "MM toggle disables when metadata dependency addon is missing")

settingsOptions[1].setFunc("6000")
assertEqual(5000, BETTERUI.Settings.Modules.GeneralInterface.chatHistory, "Chat history editbox clamps to the supported maximum")
assertEqual(5000, maxHistoryLines, "Chat history editbox updates the live chat buffer")

marketPriceToggle.setFunc(false)
assertEqual(false, BETTERUI.Settings.Modules.GeneralInterface.showMarketPrice, "Market-price toggle updates the stored setting")
assertEqual(1, inventoryRefreshes, "Market-price toggle refreshes the inventory list")
assertEqual(1, bankingRefreshes, "Market-price toggle refreshes the banking list")

marketIntegrationReset.func()
assertEqual(true, BETTERUI.Settings.Modules.GeneralInterface.showMarketPrice, "Market integration reset restores the default visibility setting")
assertEqual(2, inventoryRefreshes, "Market integration reset refreshes inventory again")
assertEqual(2, bankingRefreshes, "Market integration reset refreshes banking again")

tooltipEnhancementsToggle.setFunc(false)
assertEqual(false, BETTERUI.Settings.Modules.CIM.enableTooltipEnhancements, "Enhanced-tooltips toggle can disable live tooltip enhancements")
assertEqual("enableTooltipEnhancements", settingWrites[#settingWrites].key, "Enhanced-tooltips toggle writes through shared SetSetting")
assertEqual(false, settingWrites[#settingWrites].value, "Enhanced-tooltips shared setting write records disabled value")
assertEqual(3, tooltipCleanupCalls, "Disabling enhanced tooltips cleans up all tooltip surfaces")
assertEqual(3, #clearedTooltips, "Disabling enhanced tooltips clears each tooltip surface")

tooltipEnhancementsToggle.setFunc(true)
assertEqual(true, BETTERUI.Settings.Modules.CIM.enableTooltipEnhancements, "Enhanced-tooltips toggle can re-enable live tooltip enhancements")
assertEqual("enableTooltipEnhancements", settingWrites[#settingWrites].key, "Enhanced-tooltips re-enable writes through shared SetSetting")
assertEqual(true, settingWrites[#settingWrites].value, "Enhanced-tooltips shared setting write records enabled value")
assertEqual(1, tooltipApplyCalls, "Re-enabling enhanced tooltips reapplies live tooltip styles")
assertEqual(6, #clearedTooltips, "Re-enabling enhanced tooltips clears each tooltip surface again")

-- ===========================================================================
-- PB-003 / PB-004 regression coverage against the REAL tooltip enhancement code
-- ===========================================================================

-- Direct coverage wiring (mirrors the top-of-file pattern) so desloppify links
-- these regression tests to the production files even though the real dofile
-- calls happen below.
if false then
    dofile("Modules/Inventory/UI/TooltipUtils.lua")
    dofile("Modules/Inventory/UI/TooltipEquipped.lua")
end

-- --- Mock control factory -------------------------------------------------
-- Minimal ESO control emulation: tracks anchors, font, text, visibility, and
-- a child list so we can assert layout/font reversibility deterministically.
local function newMockControl(controlType)
    local control
    control = {
        _type = controlType or CT_LABEL,
        _children = {},
        _named = {},
        _anchors = {},
        _font = nil,
        _text = "",
        _hidden = false,
        _height = nil,
        _maxLineCount = nil,
        _wrapMode = nil,
        _horizontalAlignment = nil,
        _setFontCalls = 0,
        _mouseEnabled = false,
        _handlers = {},
        _verticalScroll = nil,
    }
    function control:GetType() return self._type end
    function control:GetNumChildren() return #self._children end
    function control:GetChild(i) return self._children[i] end
    function control:GetNamedChild(name) return self._named[name] end
    function control:SetFont(font) self._font = font; self._setFontCalls = self._setFontCalls + 1 end
    function control:GetFont() return self._font end
    function control:SetText(text) self._text = text end
    function control:GetText() return self._text end
    function control:SetHidden(hidden) self._hidden = hidden end
    function control:IsHidden() return self._hidden end
    function control:SetHeight(h) self._height = h end
    function control:SetMaxLineCount(value) self._maxLineCount = value end
    function control:SetWrapMode(value) self._wrapMode = value end
    function control:SetColor(...) end
    function control:SetHorizontalAlignment(value) self._horizontalAlignment = value end
    function control:SetMouseEnabled(enabled) self._mouseEnabled = enabled == true end
    function control:IsMouseEnabled() return self._mouseEnabled == true end
    function control:GetHandler(name) return self._handlers[name] end
    function control:SetHandler(name, handler) self._handlers[name] = handler end
    function control:SetVerticalScroll(value) self._verticalScroll = value end
    function control:ClearAnchors() self._anchors = {} end
    function control:SetAnchor(point, rel, relPoint, x, y)
        self._anchors[#self._anchors + 1] = { point = point, rel = rel, relPoint = relPoint, x = x, y = y }
    end
    function control:_addChild(child) self._children[#self._children + 1] = child; return child end
    function control:_addNamed(name, child) self._named[name] = child; return child end
    return control
end

-- Engine layout-anchor + control-type constants required by the real files.
CT_CONTROL = CT_CONTROL or 2
CT_TEXTURE = CT_TEXTURE or 3
TOPLEFT = TOPLEFT or 1
TOPRIGHT = TOPRIGHT or 2
BOTTOMLEFT = BOTTOMLEFT or 3
BOTTOMRIGHT = BOTTOMRIGHT or 4
ZO_GAMEPAD_CONTENT_HEADER_DIVIDER_OFFSET_Y = 75
TEXT_WRAP_MODE_ELLIPSIS = TEXT_WRAP_MODE_ELLIPSIS or 1
TEXT_ALIGN_LEFT = TEXT_ALIGN_LEFT or 0
GENERAL_COLOR_OFF_WHITE = GENERAL_COLOR_OFF_WHITE or 1
GENERAL_COLOR_WHITE = GENERAL_COLOR_WHITE or 2

-- Equipped/bind/trait constants exercised by UpdateTooltipEquippedText.
GAMEPLAY_ACTOR_CATEGORY_PLAYER = GAMEPLAY_ACTOR_CATEGORY_PLAYER or 0
EQUIP_SLOT_MAIN_HAND = 1
EQUIP_SLOT_BACKUP_MAIN = 2
EQUIP_SLOT_OFF_HAND = 3
EQUIP_SLOT_BACKUP_OFF = 4
BIND_TYPE_ON_EQUIP = 1
BIND_TYPE_ON_PICKUP = 2
BIND_TYPE_ON_PICKUP_BACKPACK = 3
ITEM_TRAIT_TYPE_ARMOR_ORNATE = 20
ITEM_TRAIT_TYPE_WEAPON_ORNATE = 21
ITEM_TRAIT_TYPE_JEWELRY_ORNATE = 22
ITEM_TRAIT_TYPE_ARMOR_INTRICATE = 23
ITEM_TRAIT_TYPE_WEAPON_INTRICATE = 24
ITEM_TRAIT_TYPE_JEWELRY_INTRICATE = 25
ITEMFILTERTYPE_JUNK = 99

-- Native set-collection string ids (verified via esoui-api: itemtooltips.lua
-- :199-211 renders these; constants 597/598/599).
SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_UNLOCKED = "SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_UNLOCKED"
SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_LOCKED = "SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_LOCKED"
SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_RECONSTRUCTED = "SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_RECONSTRUCTED"
SI_ITEM_FORMAT_STR_BOUND = "SI_ITEM_FORMAT_STR_BOUND"
SI_GAMEPAD_ITEM_STOLEN_LABEL = "SI_GAMEPAD_ITEM_STOLEN_LABEL"
SI_GAMEPAD_EQUIPPED_ITEM_HEADER = "SI_GAMEPAD_EQUIPPED_ITEM_HEADER"
SI_BETTERUI_BIND_FOR_COLLECTION = "SI_BETTERUI_BIND_FOR_COLLECTION"
stringMap[SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_UNLOCKED] = "Collected"
stringMap[SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_LOCKED] = "Uncollected"
stringMap[SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_RECONSTRUCTED] = "Reconstructed"
stringMap[SI_ITEM_FORMAT_STR_BOUND] = "Bound"
stringMap[SI_GAMEPAD_ITEM_STOLEN_LABEL] = "Stolen"
stringMap[SI_GAMEPAD_EQUIPPED_ITEM_HEADER] = "Equipped"
stringMap[SI_BETTERUI_BIND_FOR_COLLECTION] = "Bind for collection"

-- GetString already maps string ids; extend it to honour the ("ENUM", n) form
-- used by SI_BINDTYPE / SI_ITEMTRAITTYPE / SI_ITEMTYPE / SI_ITEMFILTERTYPE.
local baseGetString = GetString
function GetString(id, index)
    if index ~= nil then
        return tostring(id) .. tostring(index)
    end
    return baseGetString(id)
end

function zo_strupper(s) return string.upper(tostring(s)) end

-- Item-link driven engine stubs. Fixtures encode their state in the link string.
local setCollectionFixtures = {
    ["item:set-unlocked"] = { setPiece = true, unlocked = true, reconstructed = false },
    ["item:set-locked"] = { setPiece = true, unlocked = false, reconstructed = false },
    ["item:set-reconstructed"] = { setPiece = false, unlocked = false, reconstructed = true },
    ["item:non-set"] = { setPiece = false, unlocked = false, reconstructed = false },
}
local function fixtureFor(itemLink) return setCollectionFixtures[itemLink] or {} end

function IsItemLinkReconstructed(itemLink) return fixtureFor(itemLink).reconstructed == true end
function IsItemLinkSetCollectionPiece(itemLink) return fixtureFor(itemLink).setPiece == true end
function IsItemSetCollectionPieceUnlocked(itemId) return itemId == "unlocked" end
function GetItemLinkItemId(itemLink)
    if fixtureFor(itemLink).unlocked then return "unlocked" end
    return "locked"
end

function GetItemLinkTraitInfo(_) return 0 end
function GetItemLinkBindType(_) return 0 end
function GetItemLinkStacks(_) return 0, 0, 0 end
function IsItemPlayerLocked(_, _) return false end
function IsItemBound(_, _) return false end
function IsItemStolen(_, _) return false end
function IsItemLinkStolen(_) return false end
function IsItemJunk(_, _) return false end
function WouldEquipmentBeHidden(_, _) return false end
function ZO_InventoryUtils_UpdateTooltipEquippedIndicatorText(_, _) end

ZO_ColorDef = {
    New = function(_) return { UnpackRGBA = function() return 1, 1, 1, 1 end } end,
}

-- BETTERUI helper seams referenced by UpdateTooltipEquippedText.
BETTERUI.GeneralInterface = BETTERUI.GeneralInterface or {}
BETTERUI.GeneralInterface.Tooltips = BETTERUI.GeneralInterface.Tooltips or {}
BETTERUI.GeneralInterface.Tooltips.GetTooltipFontSize = function() return 24 end
BETTERUI.GetInventoryPriceInfo = function() return {} end
BETTERUI.GetInventoryTraitInfo = function() return {} end
BETTERUI.GetInventoryKnowledgeInfo = function() return {} end
BETTERUI.CIM.CONST.TOOLTIP_SCROLL_OFFSET_Y = -10
BETTERUI.CIM.CONST.LAYOUT = BETTERUI.CIM.CONST.LAYOUT or {}
BETTERUI.CIM.CONST.LAYOUT.TOOLTIP = {
    STATUS_LABEL_OFFSET_Y = 60,
    BODY_OFFSET_Y_ENHANCED = 120,
}

-- Build a fresh mock tooltip + container pair and register them with a mock
-- GAMEPAD_TOOLTIPS shared by both the cleanup and equipped-text code paths.
local pbControls = {}
local function buildMockTooltipSurface(tooltipType, labelCount)
    local container = newMockControl(CT_CONTROL)
    local tooltip = newMockControl(CT_CONTROL)
    -- Seed child labels on the tooltip body so font reset/apply is observable.
    for _ = 1, (labelCount or 3) do
        local label = tooltip:_addChild(newMockControl(CT_LABEL))
        label:SetFont("ZoFontGamepad34") -- stock starting font
    end
    -- Native scaffolding the real code looks up by name.
    local bottomRail = container:_addNamed("BottomRail", newMockControl(CT_CONTROL))
    local tip = container:_addNamed("Tip", newMockControl(CT_CONTROL))
    local scroll = tip:_addNamed("Scroll", newMockControl(CT_CONTROL))
    scroll:_addNamed("ScrollChild", newMockControl(CT_CONTROL))
    local statusLabelValue = container:_addNamed("StatusLabelValue", newMockControl(CT_LABEL))
    pbControls[tooltipType] = {
        container = container,
        tooltip = tooltip,
        bottomRail = bottomRail,
        tip = tip,
        statusLabelValue = statusLabelValue,
    }
    if GAMEPAD_TOOLTIPS then
        GAMEPAD_TOOLTIPS.tooltips = GAMEPAD_TOOLTIPS.tooltips or {}
        GAMEPAD_TOOLTIPS.tooltips[tooltipType] = {
            control = {
                container = container,
            },
        }
    end
    return pbControls[tooltipType]
end

WINDOW_MANAGER = {
    CreateControl = function(_, _, controlType)
        return newMockControl(controlType)
    end,
}

GAMEPAD_TOOLTIPS = {
    tooltips = {},
    GetTooltip = function(_, tooltipType)
        return pbControls[tooltipType] and pbControls[tooltipType].tooltip
    end,
    GetTooltipContainer = function(_, tooltipType)
        return pbControls[tooltipType] and pbControls[tooltipType].container
    end,
    ClearStatusLabel = function() end,
    SetStatusLabelText = function() end,
    ClearTooltip = function() end,
}

-- Load the REAL production code under test.
dofile("Modules/Inventory/UI/TooltipUtils.lua")
dofile("Modules/Inventory/UI/TooltipEquipped.lua")

-- Re-point the shared seam to the real implementations so the Tooltips.lua
-- hook code drives the production functions (not the earlier counter stubs).
BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip = BETTERUI.Inventory.CleanupEnhancedTooltip
BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText = BETTERUI.Inventory.UpdateTooltipEquippedText

print("\nTest: PB-003 tooltip mouse-wheel restore preserves native mouse flags and handler chaining")
local leftTooltipTip = newMockControl(CT_CONTROL)
local leftTooltipScroll = newMockControl(CT_CONTROL)
local originalWheelCalls = 0
local originalWheelDelta = nil
leftTooltipTip.scroll = leftTooltipScroll
leftTooltipTip:SetHandler("OnMouseWheel", function(_, delta)
    originalWheelCalls = originalWheelCalls + 1
    originalWheelDelta = delta
end)
ZO_GamepadTooltipTopLevelLeftTooltipContainerTip = leftTooltipTip
ZO_GamepadTooltipTopLevelLeftTooltipContainerTipScroll = leftTooltipScroll

BETTERUI.Inventory.EnableTooltipMouseWheel()
assertEqual(true, leftTooltipTip:IsMouseEnabled(), "PB-003: EnableTooltipMouseWheel enables mouse input on the tooltip body")
assertEqual(true, leftTooltipScroll:IsMouseEnabled(), "PB-003: EnableTooltipMouseWheel enables mouse input on the tooltip scroll")
local installedWheelHandler = leftTooltipTip:GetHandler("OnMouseWheel")
assertEqual(true, type(installedWheelHandler) == "function", "PB-003: EnableTooltipMouseWheel installs an OnMouseWheel handler when post-hooks are unavailable")
installedWheelHandler(leftTooltipTip, -1)
assertEqual(1, originalWheelCalls, "PB-003: fallback mouse-wheel handler preserves the prior OnMouseWheel callback")
assertEqual(-1, originalWheelDelta, "PB-003: prior OnMouseWheel callback receives the original delta")
assertEqual(20, leftTooltipTip.scrollValue, "PB-003: tooltip mouse-wheel handler stores the updated scroll value")
assertEqual(20, leftTooltipScroll._verticalScroll, "PB-003: tooltip mouse-wheel handler forwards the updated scroll value to the scroll control")

BETTERUI.Inventory.RestoreTooltipMouseWheel()
assertEqual(false, leftTooltipTip:IsMouseEnabled(), "PB-003: RestoreTooltipMouseWheel restores the tooltip body's native mouse-enabled state")
assertEqual(false, leftTooltipScroll:IsMouseEnabled(), "PB-003: RestoreTooltipMouseWheel restores the tooltip scroll's native mouse-enabled state")
local restoredWheelHandler = leftTooltipTip:GetHandler("OnMouseWheel")
assertEqual(true, restoredWheelHandler ~= nil and restoredWheelHandler ~= installedWheelHandler,
    "PB-003: RestoreTooltipMouseWheel reinstates the previous OnMouseWheel handler")
restoredWheelHandler(leftTooltipTip, 2)
assertEqual(2, originalWheelCalls, "PB-003: restored OnMouseWheel handler still receives events after teardown")
assertEqual(2, originalWheelDelta, "PB-003: restored OnMouseWheel handler receives the new delta after teardown")
BETTERUI.Inventory.EnableTooltipMouseWheel()
local reinstalledWheelHandler = leftTooltipTip:GetHandler("OnMouseWheel")
assertEqual(true, reinstalledWheelHandler ~= nil and reinstalledWheelHandler ~= restoredWheelHandler,
    "PB-003: re-enabling tooltip mouse wheel reinstalls the BetterUI wheel handler after restore")

-- --- PB-003: PostHook gating + total/idempotent cleanup ---------------------
print("\nTest: PB-003 LayoutItem PostHook does not re-apply enhanced fonts when enhancements are OFF")

local PB003_TYPE = "PB003"
buildMockTooltipSurface(PB003_TYPE, 3)
BETTERUI.Settings.Modules.CIM.enableTooltipEnhancements = false

-- Install the REAL item-layout hooks on a mock tooltip control.
local pbTooltips = BETTERUI.GeneralInterface.Tooltips
local pb003HookState = pbTooltips._InventoryHookHelpers.CreateInventoryHookState()
local pb003Tooltip = pbControls[PB003_TYPE].tooltip
pb003Tooltip.LayoutItem = function() end
pbTooltips.InventoryHookOrchestrator.InstallItemLayoutHooks(
    pb003Tooltip, "LayoutItem", pb003HookState, PB003_TYPE,
    function() return "item:non-set" end
)

-- Record enhanced-font SetFont calls on the body labels. ApplyTooltipLabelFonts
-- writes "$(MEDIUM_FONT)|<size>|soft-shadow-thick"; the stock-relayout path must
-- never produce that on a PostHook when enhancements are OFF.
local enhancedFontApplied = false
for i = 1, pb003Tooltip:GetNumChildren() do
    local child = pb003Tooltip:GetChild(i)
    local origSetFont = child.SetFont
    child.SetFont = function(self, font)
        if type(font) == "string" and font:find("soft%-shadow%-thick") then
            enhancedFontApplied = true
        end
        return origSetFont(self, font)
    end
end

pb003Tooltip:LayoutItem("item:non-set")
assertEqual(false, enhancedFontApplied,
    "PB-003: PostHook does NOT apply enhanced per-label fonts when enhancements are OFF")

print("\nTest: PB-003 CleanupEnhancedTooltip resets body anchor + clears status text + restores stock fonts")
local cleanupSurface = buildMockTooltipSurface("PB003_CLEANUP", 3)
-- Simulate enhanced state: custom status label + shifted body anchor + enhanced fonts.
local statusLabel = newMockControl(CT_LABEL)
statusLabel:SetText("ENHANCED STATUS TEXT")
statusLabel:SetHidden(false)
cleanupSurface.container._betterUiStatus = statusLabel
cleanupSurface.tooltip:ClearAnchors()
cleanupSurface.tooltip:SetAnchor(TOPLEFT, nil, TOPLEFT, 0, 120) -- enhanced body offset
for i = 1, cleanupSurface.tooltip:GetNumChildren() do
    cleanupSurface.tooltip:GetChild(i):SetFont("$(MEDIUM_FONT)|24|soft-shadow-thick")
end

BETTERUI.Inventory.CleanupEnhancedTooltip("PB003_CLEANUP")

assertEqual(false, leftTooltipTip:IsMouseEnabled(),
    "PB-003: CleanupEnhancedTooltip restores mouse input state captured before tooltip wheel enhancement")
assertEqual(false, leftTooltipScroll:IsMouseEnabled(),
    "PB-003: CleanupEnhancedTooltip restores scroll mouse input state captured before tooltip wheel enhancement")
assertEqual(true, leftTooltipTip:GetHandler("OnMouseWheel") == restoredWheelHandler,
    "PB-003: CleanupEnhancedTooltip restores the previous tooltip mouse-wheel handler")
assertEqual("", cleanupSurface.container._betterUiStatus:GetText(),
    "PB-003: CleanupEnhancedTooltip clears the _betterUiStatus text")
assertEqual(true, cleanupSurface.container._betterUiStatus:IsHidden(),
    "PB-003: CleanupEnhancedTooltip hides the _betterUiStatus label")
-- Body anchor reset to stock (offsetY 0).
local bodyAnchor = cleanupSurface.tooltip._anchors[1]
assertEqual(true, bodyAnchor ~= nil and bodyAnchor.y == 0,
    "PB-003: CleanupEnhancedTooltip resets the tooltip body anchor to stock (0 offset)")
local allStockFonts = true
for i = 1, cleanupSurface.tooltip:GetNumChildren() do
    if cleanupSurface.tooltip:GetChild(i):GetFont() ~= "ZoFontGamepad34" then
        allStockFonts = false
    end
end
assertEqual(true, allStockFonts,
    "PB-003: CleanupEnhancedTooltip restores the stock body font on every child label")

print("\nTest: PB-003 CleanupEnhancedTooltip restores fonts without BetterUI-owned layout")
local fontsOnlySurface = buildMockTooltipSurface("PB003_FONTS_ONLY", 2)
fontsOnlySurface.tooltip:ClearAnchors()
fontsOnlySurface.tooltip:SetAnchor(TOPLEFT, nil, TOPLEFT, 0, 44)
for i = 1, fontsOnlySurface.tooltip:GetNumChildren() do
    fontsOnlySurface.tooltip:GetChild(i):SetFont("$(MEDIUM_FONT)|24|soft-shadow-thick")
end

BETTERUI.Inventory.CleanupEnhancedTooltip("PB003_FONTS_ONLY")

local fontsOnlyRestored = true
for i = 1, fontsOnlySurface.tooltip:GetNumChildren() do
    if fontsOnlySurface.tooltip:GetChild(i):GetFont() ~= "ZoFontGamepad34" then
        fontsOnlyRestored = false
    end
end
assertEqual(true, fontsOnlyRestored,
    "PB-003: CleanupEnhancedTooltip restores stock body fonts even without BetterUI labels")
assertEqual(44, fontsOnlySurface.tooltip._anchors[1].y,
    "PB-003: fonts-only cleanup does not re-anchor native/default tooltip layout")

print("\nTest: PB-003 CleanupEnhancedTooltip preserves native status text in default tooltip mode")
local nativeStatusSurface = buildMockTooltipSurface("PB003_NATIVE_STATUS", 2)
nativeStatusSurface.container.statusLabel = newMockControl(CT_LABEL)
nativeStatusSurface.container.statusLabelValue = newMockControl(CT_LABEL)
nativeStatusSurface.container.statusLabelVisualLayer = newMockControl(CT_LABEL)
nativeStatusSurface.container.statusLabelValueForVisualLayer = newMockControl(CT_LABEL)
nativeStatusSurface.container.bottomRail = nativeStatusSurface.bottomRail
nativeStatusSurface.container.statusLabel:SetText("Equipped")
nativeStatusSurface.container.statusLabelValue:SetText("Main Hand")
nativeStatusSurface.container.statusLabel:SetHidden(false)
nativeStatusSurface.container.statusLabelValue:SetHidden(false)
nativeStatusSurface.bottomRail:SetHidden(false)
nativeStatusSurface.tooltip:ClearAnchors()
nativeStatusSurface.tooltip:SetAnchor(TOPLEFT, nil, TOPLEFT, 0, 44)

local nativeClearCalls = 0
local previousClearStatusLabel = GAMEPAD_TOOLTIPS.ClearStatusLabel
GAMEPAD_TOOLTIPS.ClearStatusLabel = function(_, tooltipType)
    nativeClearCalls = nativeClearCalls + 1
    local surface = pbControls[tooltipType]
    if surface and surface.container then
        surface.container.statusLabel:SetText("")
        surface.container.statusLabelValue:SetText("")
        surface.container.statusLabel:SetHidden(true)
        surface.container.statusLabelValue:SetHidden(true)
        surface.container.bottomRail:SetHidden(true)
    end
end

BETTERUI.Settings.Modules.CIM.enableTooltipEnhancements = false
BETTERUI.Inventory.CleanupEnhancedTooltip("PB003_NATIVE_STATUS")
GAMEPAD_TOOLTIPS.ClearStatusLabel = previousClearStatusLabel

assertEqual(0, nativeClearCalls,
    "PB-003: default tooltip cleanup does not call ESOUI ClearStatusLabel")
assertEqual("Equipped", nativeStatusSurface.container.statusLabel:GetText(),
    "PB-003: default tooltip cleanup preserves native status label text")
assertEqual("Main Hand", nativeStatusSurface.container.statusLabelValue:GetText(),
    "PB-003: default tooltip cleanup preserves native status value text")
assertEqual(false, nativeStatusSurface.container.statusLabel:IsHidden(),
    "PB-003: default tooltip cleanup leaves native status label visible")
assertEqual(false, nativeStatusSurface.bottomRail:IsHidden(),
    "PB-003: default tooltip cleanup leaves the native bottomRail visible")
assertEqual(44, nativeStatusSurface.tooltip._anchors[1].y,
    "PB-003: default tooltip cleanup does not re-anchor native body layout")

print("\nTest: PB-003 default UpdateTooltipEquippedText preserves native status text")
local nativeUpdateSurface = buildMockTooltipSurface("PB003_NATIVE_UPDATE", 2)
nativeUpdateSurface.container.statusLabel = newMockControl(CT_LABEL)
nativeUpdateSurface.container.statusLabelValue = newMockControl(CT_LABEL)
nativeUpdateSurface.container.statusLabelVisualLayer = newMockControl(CT_LABEL)
nativeUpdateSurface.container.statusLabelValueForVisualLayer = newMockControl(CT_LABEL)
nativeUpdateSurface.container.bottomRail = nativeUpdateSurface.bottomRail
nativeUpdateSurface.container.statusLabel:SetText("Equipped")
nativeUpdateSurface.container.statusLabelValue:SetText("Backup")
nativeUpdateSurface.container.statusLabel:SetHidden(false)
nativeUpdateSurface.container.statusLabelValue:SetHidden(false)

local nativeUpdateClearCalls = 0
local previousUpdateClearStatusLabel = GAMEPAD_TOOLTIPS.ClearStatusLabel
GAMEPAD_TOOLTIPS.ClearStatusLabel = function(_, tooltipType)
    nativeUpdateClearCalls = nativeUpdateClearCalls + 1
    local surface = pbControls[tooltipType]
    if surface and surface.container then
        surface.container.statusLabel:SetText("")
        surface.container.statusLabelValue:SetText("")
    end
end

BETTERUI.Settings.Modules.CIM.enableTooltipEnhancements = false
BETTERUI.Inventory.UpdateTooltipEquippedText("PB003_NATIVE_UPDATE", nil)
GAMEPAD_TOOLTIPS.ClearStatusLabel = previousUpdateClearStatusLabel

assertEqual(0, nativeUpdateClearCalls,
    "PB-003: default tooltip equipped updater does not call ESOUI ClearStatusLabel for non-equipped items")
assertEqual("Equipped", nativeUpdateSurface.container.statusLabel:GetText(),
    "PB-003: default tooltip equipped updater preserves native status label text")
assertEqual("Backup", nativeUpdateSurface.container.statusLabelValue:GetText(),
    "PB-003: default tooltip equipped updater preserves native status value text")

print("\nTest: PB-003 default equipped-to-non-equipped clears BetterUI-owned status")
local defaultOwnedSurface = buildMockTooltipSurface("PB003_DEFAULT_OWNED_STATUS", 2)
defaultOwnedSurface.container.statusLabel = newMockControl(CT_LABEL)
defaultOwnedSurface.container.statusLabelValue = defaultOwnedSurface.statusLabelValue
local defaultOwnedClearCalls = 0
local previousDefaultOwnedClearStatusLabel = GAMEPAD_TOOLTIPS.ClearStatusLabel
local previousDefaultOwnedSetStatusLabelText = GAMEPAD_TOOLTIPS.SetStatusLabelText
GAMEPAD_TOOLTIPS.ClearStatusLabel = function(_, tooltipType)
    defaultOwnedClearCalls = defaultOwnedClearCalls + 1
    local surface = pbControls[tooltipType]
    if surface and surface.container then
        surface.container.statusLabel:SetText("")
        surface.container.statusLabelValue:SetText("")
    end
end
GAMEPAD_TOOLTIPS.SetStatusLabelText = function(_, tooltipType, headerText, valueText)
    local surface = pbControls[tooltipType]
    if surface and surface.container then
        surface.container.statusLabel:SetText(headerText)
        surface.container.statusLabelValue:SetText(valueText)
    end
end

BETTERUI.Settings.Modules.CIM.enableTooltipEnhancements = false
BETTERUI.Inventory.UpdateTooltipEquippedText("PB003_DEFAULT_OWNED_STATUS", EQUIP_SLOT_MAIN_HAND)
assertEqual(true, defaultOwnedSurface.container._betterUiStatusOwned == true,
    "PB-003: default equipped updater records BetterUI native-status ownership")
BETTERUI.Inventory.UpdateTooltipEquippedText("PB003_DEFAULT_OWNED_STATUS", nil)
GAMEPAD_TOOLTIPS.ClearStatusLabel = previousDefaultOwnedClearStatusLabel
GAMEPAD_TOOLTIPS.SetStatusLabelText = previousDefaultOwnedSetStatusLabelText

assertEqual(1, defaultOwnedClearCalls,
    "PB-003: default non-equipped updater clears BetterUI-owned native status exactly once")
assertEqual("", defaultOwnedSurface.container.statusLabel:GetText(),
    "PB-003: default non-equipped updater clears stale BetterUI-owned status header")
assertEqual("", defaultOwnedSurface.container.statusLabelValue:GetText(),
    "PB-003: default non-equipped updater clears stale BetterUI-owned status value")
assertEqual(false, defaultOwnedSurface.container._betterUiStatusOwned == true,
    "PB-003: default non-equipped updater releases status ownership after clearing")

print("\nTest: PB-003 enhanced UpdateTooltipEquippedText clears stale BetterUI status when no status content remains")
BETTERUI.Settings.Modules.CIM.enableTooltipEnhancements = true
local enhancedStaleSurface = buildMockTooltipSurface("PB003_ENHANCED_STALE", 2)
enhancedStaleSurface.tooltip._betterui_itemLink = "item:set-unlocked"
BETTERUI.Inventory.UpdateTooltipEquippedText("PB003_ENHANCED_STALE", nil)
assertEqual(false, enhancedStaleSurface.container._betterUiStatus:IsHidden(),
    "PB-003: enhanced tooltip status is visible when BetterUI has status content")
assertContains(enhancedStaleSurface.container._betterUiStatus:GetText(), "Collected",
    "PB-003: enhanced tooltip status renders the BetterUI-owned set-collection line")
assertEqual(120, enhancedStaleSurface.tooltip._anchors[1].y,
    "PB-003: enhanced tooltip status shifts the body only while status content exists")

enhancedStaleSurface.tooltip._betterui_itemLink = nil
BETTERUI.Inventory.UpdateTooltipEquippedText("PB003_ENHANCED_STALE", nil)
assertEqual("", enhancedStaleSurface.container._betterUiStatus:GetText(),
    "PB-003: enhanced tooltip updater clears stale BetterUI status text")
assertEqual(true, enhancedStaleSurface.container._betterUiStatus:IsHidden(),
    "PB-003: enhanced tooltip updater hides empty BetterUI status labels")
assertEqual(0, enhancedStaleSurface.tooltip._anchors[1].y,
    "PB-003: enhanced tooltip updater restores body offset when BetterUI status content disappears")
assertEqual(false, enhancedStaleSurface.container._betterUiStatusOwned == true,
    "PB-003: enhanced tooltip updater releases BetterUI status ownership when content disappears")

print("\nTest: PB-003 enhanced equipped-to-non-equipped clears BetterUI-owned native status")
local enhancedOwnedClearCalls = 0
local previousOwnedClearStatusLabel = GAMEPAD_TOOLTIPS.ClearStatusLabel
local previousOwnedSetStatusLabelText = GAMEPAD_TOOLTIPS.SetStatusLabelText
local previousEquippedIndicator = ZO_InventoryUtils_UpdateTooltipEquippedIndicatorText
GAMEPAD_TOOLTIPS.ClearStatusLabel = function(_, tooltipType)
    enhancedOwnedClearCalls = enhancedOwnedClearCalls + 1
    local surface = pbControls[tooltipType]
    if surface and surface.container then
        local statusLabel = surface.container.statusLabel
        local statusLabelValue = surface.container.statusLabelValue or surface.statusLabelValue
        if statusLabel then
            statusLabel:SetText("")
            statusLabel:SetHidden(true)
        end
        if statusLabelValue then
            statusLabelValue:SetText("")
            statusLabelValue:SetHidden(true)
        end
    end
end
GAMEPAD_TOOLTIPS.SetStatusLabelText = function(_, tooltipType, headerText, valueText)
    local surface = pbControls[tooltipType]
    if surface and surface.container then
        surface.container.statusLabel = surface.container.statusLabel or newMockControl(CT_LABEL)
        surface.container.statusLabelValue = surface.container.statusLabelValue or surface.statusLabelValue or newMockControl(CT_LABEL)
        surface.container.statusLabel:SetText(headerText)
        surface.container.statusLabelValue:SetText(valueText)
        surface.container.statusLabel:SetHidden(false)
        surface.container.statusLabelValue:SetHidden(false)
    end
end
ZO_InventoryUtils_UpdateTooltipEquippedIndicatorText = function(tooltipType, _equipSlot)
    GAMEPAD_TOOLTIPS:SetStatusLabelText(tooltipType, "Equipped", "Main Hand")
end

local enhancedOwnedSurface = buildMockTooltipSurface("PB003_ENHANCED_OWNED_STATUS", 2)
enhancedOwnedSurface.container.statusLabel = newMockControl(CT_LABEL)
enhancedOwnedSurface.container.statusLabelValue = enhancedOwnedSurface.statusLabelValue
BETTERUI.Inventory.UpdateTooltipEquippedText("PB003_ENHANCED_OWNED_STATUS", EQUIP_SLOT_MAIN_HAND)
assertEqual(true, enhancedOwnedSurface.container._betterUiStatusOwned == true,
    "PB-003: enhanced equipped tooltip records BetterUI status ownership")

-- Simulate ESOUI repainting the native status after BetterUI has drawn the
-- enhanced header; the following non-equipped render must clear only because
-- BetterUI owns the previous status area.
GAMEPAD_TOOLTIPS:SetStatusLabelText("PB003_ENHANCED_OWNED_STATUS", "Equipped", "Main Hand")
BETTERUI.Inventory.UpdateTooltipEquippedText("PB003_ENHANCED_OWNED_STATUS", nil)
GAMEPAD_TOOLTIPS.ClearStatusLabel = previousOwnedClearStatusLabel
GAMEPAD_TOOLTIPS.SetStatusLabelText = previousOwnedSetStatusLabelText
ZO_InventoryUtils_UpdateTooltipEquippedIndicatorText = previousEquippedIndicator

assertEqual(2, enhancedOwnedClearCalls,
    "PB-003: enhanced equipped-to-non-equipped transition clears BetterUI-owned native status")
assertEqual("", enhancedOwnedSurface.container.statusLabel:GetText(),
    "PB-003: enhanced non-equipped updater clears stale native status header")
assertEqual("", enhancedOwnedSurface.container.statusLabelValue:GetText(),
    "PB-003: enhanced non-equipped updater clears stale native status value")
assertEqual(false, enhancedOwnedSurface.container._betterUiStatusOwned == true,
    "PB-003: enhanced non-equipped updater releases status ownership after clearing")

print("\nTest: PB-003 repeated enhancements on/off loop accumulates no drift")
local driftSurface = buildMockTooltipSurface("PB003_DRIFT", 3)
local driftStatus = newMockControl(CT_LABEL)
driftSurface.container._betterUiStatus = driftStatus
local driftOk = true
for _ = 1, 10 do
    -- "ON": re-apply enhanced state (status text + shifted anchor + enhanced fonts).
    driftStatus:SetText("ENHANCED")
    driftStatus:SetHidden(false)
    driftSurface.tooltip:ClearAnchors()
    driftSurface.tooltip:SetAnchor(TOPLEFT, nil, TOPLEFT, 0, 120)
    for i = 1, driftSurface.tooltip:GetNumChildren() do
        driftSurface.tooltip:GetChild(i):SetFont("$(MEDIUM_FONT)|24|soft-shadow-thick")
    end
    -- "OFF": cleanup must fully revert.
    BETTERUI.Inventory.CleanupEnhancedTooltip("PB003_DRIFT")
    if driftStatus:GetText() ~= "" or not driftStatus:IsHidden() then driftOk = false end
    if #driftSurface.tooltip._anchors ~= 1 or driftSurface.tooltip._anchors[1].y ~= 0 then driftOk = false end
    for i = 1, driftSurface.tooltip:GetNumChildren() do
        if driftSurface.tooltip:GetChild(i):GetFont() ~= "ZoFontGamepad34" then driftOk = false end
    end
end
assertEqual(true, driftOk, "PB-003: 10x on/off loop leaves status/anchor/font in a stable stock state (no drift)")

-- --- PB-004: set-collection Collected/Uncollected/Reconstructed tag ---------
print("\nTest: PB-004 enhanced tooltip emits exactly one set-collection status line")
BETTERUI.Settings.Modules.CIM.enableTooltipEnhancements = true

local function statusTextForFixture(itemLink)
    local surface = buildMockTooltipSurface("PB004", 1)
    surface.tooltip._betterui_itemLink = itemLink
    surface.tooltip._betterui_bagId = nil
    surface.tooltip._betterui_slotIndex = nil
    BETTERUI.Inventory.UpdateTooltipEquippedText("PB004", nil)
    return surface.container._betterUiStatus and surface.container._betterUiStatus:GetText() or ""
end

local function countOccurrences(haystack, needle)
    local count, pos = 0, 1
    while true do
        local s = haystack:find(needle, pos, true)
        if not s then break end
        count = count + 1
        pos = s + 1
    end
    return count
end

local unlockedText = statusTextForFixture("item:set-unlocked")
assertContains(unlockedText, "Collected", "PB-004: set-piece unlocked emits the UNLOCKED (Collected) tag")
assertEqual(1, countOccurrences(unlockedText, "Collected"), "PB-004: exactly one collection line for unlocked set piece")

local lockedText = statusTextForFixture("item:set-locked")
assertContains(lockedText, "Uncollected", "PB-004: set-piece locked emits the LOCKED (Uncollected) tag")
assertEqual(1, countOccurrences(lockedText, "Uncollected"), "PB-004: exactly one collection line for locked set piece")

local reconstructedText = statusTextForFixture("item:set-reconstructed")
assertContains(reconstructedText, "Reconstructed", "PB-004: reconstructed piece emits the RECONSTRUCTED tag")
assertEqual(1, countOccurrences(reconstructedText, "Reconstructed"), "PB-004: exactly one collection line for reconstructed piece")

local nonSetText = statusTextForFixture("item:non-set")
assertEqual(0, countOccurrences(nonSetText, "Collected"), "PB-004: non-set item emits no Collected tag")
assertEqual(0, countOccurrences(nonSetText, "Uncollected"), "PB-004: non-set item emits no Uncollected tag")
assertEqual(0, countOccurrences(nonSetText, "Reconstructed"), "PB-004: non-set item emits no Reconstructed tag")

-- Reconstructed must win over the set-piece branch (native precedence).
setCollectionFixtures["item:set-reconstructed"].setPiece = true
setCollectionFixtures["item:set-reconstructed"].unlocked = true
local reconPriorityText = statusTextForFixture("item:set-reconstructed")
assertEqual(1, countOccurrences(reconPriorityText, "Reconstructed"),
    "PB-004: reconstructed precedence wins (one Reconstructed line)")
assertEqual(0, countOccurrences(reconPriorityText, "Collected"),
    "PB-004: reconstructed item does not also emit the Collected tag")

print("\nTest: PB-015 equipped-status label constrains width and line count for shared inventory/banking tooltips")
local pb015Surface = buildMockTooltipSurface("PB015", 1)
pb015Surface.tooltip._betterui_itemLink = "item:set-unlocked"
BETTERUI.Inventory.UpdateTooltipEquippedText("PB015", nil)

local pb015Status = pb015Surface.container._betterUiStatus
local leftAnchor = pb015Status and pb015Status._anchors[1]
local rightAnchor = pb015Status and pb015Status._anchors[2]
assertEqual(true, pb015Status ~= nil, "PB-015: equipped-status label is created")
assertEqual(true, pb015Status ~= nil and pb015Status._maxLineCount ~= nil and pb015Status._maxLineCount > 0,
    "PB-015: equipped-status label uses a bounded line count")
assertEqual(true, leftAnchor ~= nil and leftAnchor.x ~= 0,
    "PB-015: equipped-status label keeps left-side padding")
assertEqual(true, rightAnchor ~= nil and rightAnchor.x ~= 0,
    "PB-015: equipped-status label keeps right-side padding")
assertEqual(TEXT_ALIGN_LEFT, pb015Status and pb015Status._horizontalAlignment,
    "PB-015: equipped-status label remains left aligned when wrapped")

-- --- Compat fix: AddTopLinesToTopSection suppression must be scene-gated ------
-- The shared GAMEPAD_TOOLTIPS AddTopLinesToTopSection PreHook (Setup.lua) may
-- only suppress native top-lines (return true) when BetterUI's enhancement will
-- actually render in this context. In an incompatible/foreign scene it MUST let
-- native + other addons' hooks run (return false/nil), otherwise native top
-- section content (set-collection Collected/Uncollected line, bound/stolen/stack
-- counts) vanishes and earlier-registered foreign PreHooks are blocked.
print("\nTest: AddTopLinesToTopSection suppression is gated on the rendering-side scene check")

local setupInstallers = BETTERUI.GeneralInterface._SetupInstallers or {}
assertEqual(true, type(setupInstallers.InstallTopLineSuppressionHooks) == "function",
    "Setup exposes InstallTopLineSuppressionHooks for the suppression-gate test")
assertEqual(true, type(BETTERUI.GeneralInterface.Tooltips.IsIncompatibleSceneActive) == "function",
    "Tooltips exposes the shared scene-gate predicate (single source of truth)")

-- Mock top-section: AcquireSection / AddSectionEvenIfEmpty for the BetterUI
-- subsection, plus AddLine on acquired subsections so the NATIVE path can emit
-- its set-collection line and we can observe whether native ran.
local function newMockTopSection()
    local section = { _sections = {}, _lines = {} }
    function section:AcquireSection(_)
        local sub = { _lines = section._lines }
        function sub:AddLine(text, _) section._lines[#section._lines + 1] = text end
        return sub
    end
    function section:AddSectionEvenIfEmpty(_) section._sectionsAdded = (section._sectionsAdded or 0) + 1 end
    return section
end

-- Native-equivalent AddTopLinesToTopSection: emits the set-collection line so we
-- can prove native top-section content survives when suppression is gated off.
-- Mirrors esoui/publicallingames/tooltip/itemtooltips.lua:168-229 (the real method
-- this PreHook fronts) for the set-collection branch.
local function nativeAddTopLines(self, topSection, itemLink, showPlayerLocked, tradeBoPData)
    local topSubsection = topSection:AcquireSection(self:GetStyle("topSubsectionItemDetails"))
    if IsItemLinkReconstructed(itemLink) then
        topSubsection:AddLine(GetString(SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_RECONSTRUCTED), "itemSetCollection")
    elseif IsItemLinkSetCollectionPiece(itemLink) then
        local itemId = GetItemLinkItemId(itemLink)
        if IsItemSetCollectionPieceUnlocked(itemId) then
            topSubsection:AddLine(GetString(SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_UNLOCKED), "itemSetCollection")
        else
            topSubsection:AddLine(GetString(SI_ITEM_FORMAT_STR_SET_COLLECTION_PIECE_LOCKED), "itemSetCollection")
        end
    end
    topSection:AddSectionEvenIfEmpty(topSubsection)
end

-- Build a fresh tooltip control wired with the native method, then install the
-- production suppression PreHook on it via the real Setup installer.
local topLineControls = {}
local function buildTopLineTooltip(tooltipType)
    local control = {
        _betterui_styles = {},
        AddTopLinesToTopSection = nativeAddTopLines,
    }
    function control:GetStyle(name) return name end
    topLineControls[tooltipType] = control
    return control
end

local topLineGetTooltip = function(_, tooltipType) return topLineControls[tooltipType] end
local prevGetTooltip = GAMEPAD_TOOLTIPS.GetTooltip
GAMEPAD_TOOLTIPS.GetTooltip = topLineGetTooltip
buildTopLineTooltip(GAMEPAD_LEFT_TOOLTIP)
buildTopLineTooltip(GAMEPAD_RIGHT_TOOLTIP)
buildTopLineTooltip(GAMEPAD_MOVABLE_TOOLTIP)

-- Install the REAL production suppression hook on these fresh controls.
setupInstallers.InstallTopLineSuppressionHooks()
GAMEPAD_TOOLTIPS.GetTooltip = prevGetTooltip

-- Drive a hooked control's AddTopLinesToTopSection. Returns:
--   sectionsAdded -> # of subsections injected (BetterUI inject + any native run)
--   collectionLine -> the set-collection text the NATIVE path emitted (nil if native skipped)
local function runTopLineHook(tooltipType, itemLink)
    local control = topLineControls[tooltipType]
    local topSection = newMockTopSection()
    control:AddTopLinesToTopSection(topSection, itemLink, false, nil)
    return topSection._sectionsAdded or 0, findLine(topSection._lines, "Collected") or findLine(topSection._lines, "Uncollected")
end

-- Stub the shared scene-gate so the suppression hook sees each context.
local realSceneGate = BETTERUI.GeneralInterface.Tooltips.IsIncompatibleSceneActive
local sceneIsIncompatible = false
BETTERUI.GeneralInterface.Tooltips.IsIncompatibleSceneActive = function() return sceneIsIncompatible end

-- (a) BetterUI-enhanced context: enhancements ON, scene compatible -> suppress
-- native (BetterUI renders), native set-collection line is NOT emitted by THIS
-- method (the PB-004 path emits it separately, already asserted above).
BETTERUI.Settings.Modules.CIM.enableTooltipEnhancements = true
sceneIsIncompatible = false
local enhSections, enhCollection = runTopLineHook(GAMEPAD_LEFT_TOOLTIP, "item:set-unlocked")
assertEqual(true, enhSections >= 1,
    "Compat: enhanced context injects the BetterUI top subsection")
assertEqual(nil, enhCollection,
    "Compat: enhanced context suppresses the native top-lines (PreHook returned true)")

-- PB-004 guard: the set-collection segment still appears inside BetterUI-enhanced
-- tooltips. The enhanced path renders it via UpdateTooltipEquippedText (the same
-- code the PB-004 cases above exercise) — confirm that path still emits it while
-- the suppression hook is active and gated to the enhanced context.
BETTERUI.Settings.Modules.CIM.enableTooltipEnhancements = true
sceneIsIncompatible = false
local pb004WithSuppression = statusTextForFixture("item:set-unlocked")
assertContains(pb004WithSuppression, "Collected",
    "PB-004 not regressed: enhanced tooltip still shows the set-collection Collected tag while suppression is active")

-- (b) Incompatible/foreign context: enhancements ON, scene incompatible -> do
-- NOT suppress; native top-lines run (set-collection line present) and other
-- addons' earlier PreHooks are not blocked.
sceneIsIncompatible = true
local incSections, incCollection = runTopLineHook(GAMEPAD_RIGHT_TOOLTIP, "item:set-unlocked")
assertEqual(1, incSections,
    "Compat: incompatible context lets ONLY the native top-section run (BetterUI did not inject)")
assertEqual(true, incCollection ~= nil,
    "Compat: incompatible context preserves the native set-collection line (PreHook returned false/nil)")

local incLockedSections, incLockedCollection = runTopLineHook(GAMEPAD_RIGHT_TOOLTIP, "item:set-locked")
assertEqual(1, incLockedSections,
    "Compat: incompatible context runs native for a locked set piece too")
assertContains(incLockedCollection or "", "Uncollected",
    "Compat: incompatible context preserves the native Uncollected line")

-- (c) Enhancements OFF: never suppress, regardless of scene (native + foreign run).
BETTERUI.Settings.Modules.CIM.enableTooltipEnhancements = false
sceneIsIncompatible = false
local offSections, offCollection = runTopLineHook(GAMEPAD_LEFT_TOOLTIP, "item:set-unlocked")
assertEqual(1, offSections,
    "Compat: enhancements OFF lets the native top-section run (no BetterUI injection)")
assertEqual(true, offCollection ~= nil,
    "Compat: enhancements OFF preserves the native set-collection line")

-- Restore shared state so any later code/tests see the real predicate + ON setting.
BETTERUI.GeneralInterface.Tooltips.IsIncompatibleSceneActive = realSceneGate
BETTERUI.Settings.Modules.CIM.enableTooltipEnhancements = true

print("\n=== Test Summary ===")
print(string.format("Passed: %d", testsPassed))
print(string.format("Failed: %d", testsFailed))

if testsFailed > 0 then
    os.exit(1)
else
    print("\nAll tests passed!")
    os.exit(0)
end
