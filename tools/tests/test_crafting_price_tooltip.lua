--[[
File: tools/tests/test_crafting_price_tooltip.lua
Purpose: Unit tests for CraftingPriceTooltip hooks and formatting.
]]

local function assertTrue(condition, message)
    if not condition then
        error("ASSERTION FAILED: " .. tostring(message), 2)
    end
end

local function assertEqual(expected, actual, message)
    assertTrue(expected == actual, string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)))
end

-- Mock globals
_G.ZO_PostHook = function(target, method, fn)
    if not target._postHooks then target._postHooks = {} end
    target._postHooks[method] = fn
end
_G.GetCurrencyGamepadIcon = function() return "gold_icon.dds" end
_G.zo_strformat = function(format, ...)
    local result = format
    for i = 1, select("#", ...) do
        result = result:gsub("<<" .. i .. ">>", tostring(select(i, ...)))
    end
    return result
end
_G.CURT_MONEY = 1

-- Mock BetterUI namespace
_G.BETTERUI = _G.BETTERUI or {}
_G.BETTERUI.GetModuleSettings = function(module)
    return _G.BETTERUI._testSettings and _G.BETTERUI._testSettings[module] or {}
end
_G.BETTERUI.GetSetting = function(module, key, default)
    local settings = _G.BETTERUI.GetModuleSettings(module)
    if settings[key] == nil then return default end
    return settings[key]
end
_G.BETTERUI.SafeIcon = function(icon) return icon end
_G.BETTERUI.DisplayNumber = function(n) return tostring(n) end
_G.BETTERUI.roundNumber = function(n) return math.floor(n + 0.5) end

-- Mock MarketIntegration
_G.BETTERUI.CIM = _G.BETTERUI.CIM or {}
_G.BETTERUI.CIM.MarketIntegration = {
    GetMarketPriceInfo = function(itemLink, stackCount)
        local info = _G._testMarketPriceInfo
        if info then
            return {
                price = info.price or 0,
                unitPrice = info.unitPrice or 0,
                sourceKey = info.sourceKey,
                hasData = info.hasData == true,
                isAverage = info.isAverage == true,
            }
        end
        return { price = 0, hasData = false }
    end,
    GetSourcePriceInfo = function(sourceKey, itemLink, stackCount, settings)
        local info = _G._testSourceAvailability and _G._testSourceAvailability[sourceKey]
        if info then
            return {
                enabled = info.enabled ~= false,
                available = info.available == true,
            }
        end
        return { enabled = false, available = false }
    end,
}

-- Mock tooltip control
-- Mock ZO_Tooltip proto
_G.ZO_Tooltip = _G.ZO_Tooltip or {}
_G.ZO_Tooltip.LayoutPendingSmithingItem = function() end
_G.ZO_Tooltip.LayoutImproveResultSmithingItem = function() end
local MockTooltip = {
    lines = {},
    padding = 0,
    AddVerticalPadding = function(self, amount)
        self.padding = self.padding + amount
    end,
    AddLine = function(self, text, font)
        table.insert(self.lines, { text = text, font = font })
    end,
    Clear = function(self)
        self.lines = {}
        self.padding = 0
    end,
}

-- Load the module under test
dofile("Modules/GeneralInterface/Tooltips/CraftingPriceTooltip.lua")

local CraftingPriceTooltip = BETTERUI.GeneralInterface.Tooltips.CraftingPriceTooltip

-- Reset state before each test
local function resetState()
    MockTooltip:Clear()
    _G._testMarketPriceInfo = nil
    _G._testSourceAvailability = nil
    _G.BETTERUI._testSettings = {
        GeneralInterface = {
            showCraftingMarketPrice = true,
        }
    }
end

-- Test 1: Hooks install when market source is available
resetState()
_G._testSourceAvailability = {
    ttc = { enabled = true, available = true },
}
CraftingPriceTooltip.InstallHooks()
assertTrue(CraftingPriceTooltip.AreHooksInstalled(), "Hooks install when TTC is available")

-- Test 2: Price line appends for creation tooltip
resetState()
_G._testMarketPriceInfo = { price = 5000, unitPrice = 5000, sourceKey = "ttc", hasData = true }
_G.GetSmithingPatternResultLink = function() return "|H1:item:123:...|h|h" end

-- Simulate the post-hook
local creationHook = ZO_Tooltip._postHooks and ZO_Tooltip._postHooks.LayoutPendingSmithingItem
assertTrue(type(creationHook) == "function", "LayoutPendingSmithingItem hook exists")

creationHook(MockTooltip, 1, 1, 1, 1, 1)
assertEqual(1, #MockTooltip.lines, "Price line appended for creation")
assertTrue(MockTooltip.lines[1].text:find("5000") ~= nil, "Price value in line")
assertTrue(MockTooltip.lines[1].text:find("TTC") ~= nil, "Source label in line")

-- Test 3: Price line appends for improvement tooltip
resetState()
_G._testMarketPriceInfo = { price = 7500, unitPrice = 7500, sourceKey = "mm", hasData = true }
_G.GetSmithingImprovedItemLink = function() return "|H1:item:456:...|h|h" end

local improvementHook = ZO_Tooltip._postHooks and ZO_Tooltip._postHooks.LayoutImproveResultSmithingItem
assertTrue(type(improvementHook) == "function", "LayoutImproveResultSmithingItem hook exists")

improvementHook(MockTooltip, 1, 1, 1)
assertEqual(1, #MockTooltip.lines, "Price line appended for improvement")
assertTrue(MockTooltip.lines[1].text:find("7500") ~= nil, "Price value in improvement line")
assertTrue(MockTooltip.lines[1].text:find("MM") ~= nil, "Source label in improvement line")

-- Test 4: No line when setting is disabled
resetState()
_G.BETTERUI._testSettings.GeneralInterface.showCraftingMarketPrice = false
_G._testMarketPriceInfo = { price = 5000, hasData = true }
_G.GetSmithingPatternResultLink = function() return "|H1:item:123:...|h|h" end

MockTooltip:Clear()
creationHook(MockTooltip, 1, 1, 1, 1, 1)
assertEqual(0, #MockTooltip.lines, "No line when setting disabled")

-- Test 5: No line when no price data
resetState()
_G._testMarketPriceInfo = { price = 0, hasData = false }
_G.GetSmithingPatternResultLink = function() return "|H1:item:123:...|h|h" end

MockTooltip:Clear()
creationHook(MockTooltip, 1, 1, 1, 1, 1)
assertEqual(0, #MockTooltip.lines, "No line when no price data")

-- Test 6: No line when item link is nil
resetState()
_G._testMarketPriceInfo = { price = 5000, hasData = true }
_G.GetSmithingPatternResultLink = function() return nil end

MockTooltip:Clear()
creationHook(MockTooltip, 1, 1, 1, 1, 1)
assertEqual(0, #MockTooltip.lines, "No line when item link is nil")

-- Test 7: No line when GetSmithingPatternResultLink is missing
resetState()
_G._testMarketPriceInfo = { price = 5000, hasData = true }
_G.GetSmithingPatternResultLink = nil

MockTooltip:Clear()
creationHook(MockTooltip, 1, 1, 1, 1, 1)
assertEqual(0, #MockTooltip.lines, "No line when API function missing")

print("test_crafting_price_tooltip.lua: ALL TESTS PASSED")
