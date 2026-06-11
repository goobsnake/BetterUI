--[[
File: tools/tests/test_crafting_price_tooltip.lua
Purpose: Unit tests for CraftingPriceTooltip hooks and formatting.
         Hooks target the gamepad smithing screen classes (metatable-resolved)
         because ZO_Tooltip methods are mixin-copied onto tooltip instances.
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
_G.GetString = function(id) return id or "" end
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
}

-- Mock the gamepad smithing screen classes (hook targets)
_G.ZO_GamepadSmithingCreation = { SetupResultTooltip = function() end }
_G.ZO_GamepadSmithingImprovement = { SetupResultTooltip = function() end }

-- Mock gamepad tooltip instance: AcquireSection/GetStyle/AddSection + section AddLine
local function NewMockTip()
    local tip = {
        sections = {},
        styles = {},
    }
    function tip:GetStyle(styleName)
        return { name = styleName }
    end
    function tip:AcquireSection(style)
        local section = { lines = {}, style = style }
        function section:AddLine(text, lineStyle)
            table.insert(self.lines, { text = text, style = lineStyle })
        end
        return section
    end
    function tip:AddSection(section)
        table.insert(self.sections, section)
    end
    return tip
end

-- Load the module under test
dofile("Modules/GeneralInterface/Tooltips/CraftingPriceTooltip.lua")

local CraftingPriceTooltip = BETTERUI.GeneralInterface.Tooltips.CraftingPriceTooltip

local function resetState()
    _G._testMarketPriceInfo = nil
    _G.BETTERUI._testSettings = {
        GeneralInterface = {
            showCraftingMarketPrice = true,
        }
    }
end

local function countLines(tip)
    local n = 0
    for _, section in ipairs(tip.sections) do
        n = n + #section.lines
    end
    return n
end

local function firstLineText(tip)
    local section = tip.sections[1]
    return section and section.lines[1] and section.lines[1].text or ""
end

-- Test 1: Hooks installed on the smithing screen classes at load
assertTrue(CraftingPriceTooltip.AreHooksInstalled(), "Hooks installed at load")
local creationHook = ZO_GamepadSmithingCreation._postHooks
    and ZO_GamepadSmithingCreation._postHooks.SetupResultTooltip
local improvementHook = ZO_GamepadSmithingImprovement._postHooks
    and ZO_GamepadSmithingImprovement._postHooks.SetupResultTooltip
assertTrue(type(creationHook) == "function", "Creation SetupResultTooltip hook exists")
assertTrue(type(improvementHook) == "function", "Improvement SetupResultTooltip hook exists")

-- Test 2: Price section appended for creation tooltip
resetState()
_G._testMarketPriceInfo = { price = 5000, unitPrice = 5000, sourceKey = "ttc", hasData = true }
_G.GetSmithingPatternResultLink = function() return "|H1:item:123:...|h|h" end

local creationScreen = { resultTooltip = { tip = NewMockTip() } }
creationHook(creationScreen, 1, 1, 1, 1, 1)
assertEqual(1, countLines(creationScreen.resultTooltip.tip), "Price line appended for creation")
assertTrue(firstLineText(creationScreen.resultTooltip.tip):find("5000") ~= nil, "Price value in line")
assertTrue(firstLineText(creationScreen.resultTooltip.tip):find("TTC") ~= nil, "Source label in line")

-- Test 3: Price section appended for improvement tooltip
resetState()
_G._testMarketPriceInfo = { price = 7500, unitPrice = 7500, sourceKey = "mm", hasData = true }
_G.GetSmithingImprovedItemLink = function() return "|H1:item:456:...|h|h" end

local improvementScreen = { resultTooltip = { tip = NewMockTip() } }
improvementHook(improvementScreen, 1, 1, 1)
assertEqual(1, countLines(improvementScreen.resultTooltip.tip), "Price line appended for improvement")
assertTrue(firstLineText(improvementScreen.resultTooltip.tip):find("7500") ~= nil, "Price value in improvement line")
assertTrue(firstLineText(improvementScreen.resultTooltip.tip):find("MM") ~= nil, "Source label in improvement line")

-- Test 4: No line when setting is disabled
resetState()
_G.BETTERUI._testSettings.GeneralInterface.showCraftingMarketPrice = false
_G._testMarketPriceInfo = { price = 5000, hasData = true }
_G.GetSmithingPatternResultLink = function() return "|H1:item:123:...|h|h" end

local disabledScreen = { resultTooltip = { tip = NewMockTip() } }
creationHook(disabledScreen, 1, 1, 1, 1, 1)
assertEqual(0, countLines(disabledScreen.resultTooltip.tip), "No line when setting disabled")

-- Test 5: No line when no price data
resetState()
_G._testMarketPriceInfo = { price = 0, hasData = false }
_G.GetSmithingPatternResultLink = function() return "|H1:item:123:...|h|h" end

local noDataScreen = { resultTooltip = { tip = NewMockTip() } }
creationHook(noDataScreen, 1, 1, 1, 1, 1)
assertEqual(0, countLines(noDataScreen.resultTooltip.tip), "No line when no price data")

-- Test 6: No line when item link is nil
resetState()
_G._testMarketPriceInfo = { price = 5000, hasData = true }
_G.GetSmithingPatternResultLink = function() return nil end

local nilLinkScreen = { resultTooltip = { tip = NewMockTip() } }
creationHook(nilLinkScreen, 1, 1, 1, 1, 1)
assertEqual(0, countLines(nilLinkScreen.resultTooltip.tip), "No line when item link is nil")

-- Test 7: No error when GetSmithingPatternResultLink is missing
resetState()
_G._testMarketPriceInfo = { price = 5000, hasData = true }
_G.GetSmithingPatternResultLink = nil

local noApiScreen = { resultTooltip = { tip = NewMockTip() } }
creationHook(noApiScreen, 1, 1, 1, 1, 1)
assertEqual(0, countLines(noApiScreen.resultTooltip.tip), "No line when API function missing")

-- Test 8: No error when the screen has no result tooltip
resetState()
_G._testMarketPriceInfo = { price = 5000, hasData = true }
_G.GetSmithingPatternResultLink = function() return "|H1:item:123:...|h|h" end
creationHook({}, 1, 1, 1, 1, 1)

-- Test 9: Keyboard-style tooltip controls (no section API) are skipped safely
resetState()
_G._testMarketPriceInfo = { price = 5000, hasData = true }
local keyboardTip = { AddLine = function() end }
CraftingPriceTooltip.AppendPriceLine(keyboardTip, "|H1:item:123:...|h|h")

print("test_crafting_price_tooltip.lua: ALL TESTS PASSED")
