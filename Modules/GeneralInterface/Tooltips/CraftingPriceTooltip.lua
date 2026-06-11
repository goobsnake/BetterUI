--[[
File: Modules/GeneralInterface/Tooltips/CraftingPriceTooltip.lua
Purpose: Show aggregated market price (TTC/MM/ATT) on gamepad crafting and
         improvement result tooltips. Reuses MarketIntegration.lua — no new
         data sources.
]]

if not BETTERUI.GeneralInterface then BETTERUI.GeneralInterface = {} end
if not BETTERUI.GeneralInterface.Tooltips then BETTERUI.GeneralInterface.Tooltips = {} end

local CraftingPriceTooltip = {}
BETTERUI.GeneralInterface.Tooltips.CraftingPriceTooltip = CraftingPriceTooltip

local MARKET_INTEGRATION = BETTERUI.CIM and BETTERUI.CIM.MarketIntegration

-- Hook installation state (idempotent)
local _hooksInstalled = false

---@return boolean
local function IsCraftingMarketPriceEnabled()
    if not BETTERUI.GetSetting then return false end
    return BETTERUI.GetSetting("GeneralInterface", "showCraftingMarketPrice", true) == true
end

--- Append the aggregated market price as a body section on a gamepad tooltip.
--- Receives the tooltip INSTANCE (resultTooltip.tip); ZO_Tooltip methods are
--- mixin-copied onto tooltip controls, so the instance carries AcquireSection,
--- GetStyle, and AddSection directly.
---@param tooltipControl table
---@param itemLink string
local function AppendPriceLine(tooltipControl, itemLink)
    if not tooltipControl or not itemLink or itemLink == "" then return end
    if not IsCraftingMarketPriceEnabled() then return end
    if not MARKET_INTEGRATION or type(MARKET_INTEGRATION.GetMarketPriceInfo) ~= "function" then
        return
    end
    -- Gamepad tooltips only: keyboard tooltip controls lack the section API.
    if type(tooltipControl.AcquireSection) ~= "function"
        or type(tooltipControl.GetStyle) ~= "function"
        or type(tooltipControl.AddSection) ~= "function" then
        return
    end

    local priceInfo = MARKET_INTEGRATION.GetMarketPriceInfo(itemLink, 1)
    if not priceInfo or not priceInfo.hasData or not priceInfo.price or priceInfo.price <= 0 then
        return
    end

    local coinIcon = BETTERUI.SafeIcon and BETTERUI.SafeIcon(GetCurrencyGamepadIcon(CURT_MONEY)) or ""
    local displayPrice
    if BETTERUI.DisplayNumber and BETTERUI.roundNumber then
        displayPrice = BETTERUI.DisplayNumber(BETTERUI.roundNumber(priceInfo.price, 2))
    else
        displayPrice = tostring(priceInfo.price)
    end
    local sourceLabel = priceInfo.sourceKey and zo_strformat(" (<<1>>)", priceInfo.sourceKey:upper()) or ""
    local marketLabel = GetString(rawget(_G, "SI_BETTERUI_CRAFTING_MARKET_LABEL"))
    if not marketLabel or marketLabel == "" then
        marketLabel = "Market"
    end

    local lineText = zo_strformat("<<1>>: |cFFFFFF<<2>>|r |t16:16:<<3>>|t<<4>>",
        marketLabel, displayPrice, coinIcon, sourceLabel)

    local section = tooltipControl:AcquireSection(tooltipControl:GetStyle("bodySection"))
    section:AddLine(lineText, tooltipControl:GetStyle("bodyDescription"))
    tooltipControl:AddSection(section)
end

-- Exposed for unit tests.
CraftingPriceTooltip.AppendPriceLine = AppendPriceLine

--- Post-hook for ZO_GamepadSmithingCreation:SetupResultTooltip.
local function OnCreationResultTooltip(smithingCreation, patternIndex, materialIndex, materialQuantity, styleId, traitIndex)
    if type(GetSmithingPatternResultLink) ~= "function" then return end
    local tip = smithingCreation and smithingCreation.resultTooltip and smithingCreation.resultTooltip.tip
    if not tip then return end

    local itemLink = GetSmithingPatternResultLink(patternIndex, materialIndex, materialQuantity, styleId, traitIndex)
    AppendPriceLine(tip, itemLink)
end

--- Post-hook for ZO_GamepadSmithingImprovement:SetupResultTooltip.
local function OnImprovementResultTooltip(smithingImprovement, itemToImproveBagId, itemToImproveSlotIndex, craftingSkillType)
    if type(GetSmithingImprovedItemLink) ~= "function" then return end
    local tip = smithingImprovement and smithingImprovement.resultTooltip and smithingImprovement.resultTooltip.tip
    if not tip then return end

    local itemLink = GetSmithingImprovedItemLink(itemToImproveBagId, itemToImproveSlotIndex, craftingSkillType)
    AppendPriceLine(tip, itemLink)
end

--- Install hooks once. Safe to call multiple times.
---
--- ZO_Tooltip layout methods (LayoutPendingSmithingItem etc.) are mixin-copied
--- onto every tooltip control when the base UI loads — before addons — so
--- post-hooking the ZO_Tooltip prototype can never reach live tooltip
--- instances. The gamepad smithing screen classes resolve methods through
--- their class metatables instead, which ZO_PostHook does intercept, and their
--- SetupResultTooltip hands us the exact result-tooltip instance plus the
--- crafting parameters needed to build the result item link.
function CraftingPriceTooltip.InstallHooks()
    if _hooksInstalled then return end
    if type(ZO_PostHook) ~= "function" then return end

    local hooked = false
    local creationClass = rawget(_G, "ZO_GamepadSmithingCreation")
    if creationClass and creationClass.SetupResultTooltip then
        ZO_PostHook(creationClass, "SetupResultTooltip", OnCreationResultTooltip)
        hooked = true
    end
    local improvementClass = rawget(_G, "ZO_GamepadSmithingImprovement")
    if improvementClass and improvementClass.SetupResultTooltip then
        ZO_PostHook(improvementClass, "SetupResultTooltip", OnImprovementResultTooltip)
        hooked = true
    end

    _hooksInstalled = hooked
end

--- Returns whether hooks are currently installed.
---@return boolean
function CraftingPriceTooltip.AreHooksInstalled()
    return _hooksInstalled
end

-- Install at load: the smithing classes are defined by the base UI well
-- before addons load, and AppendPriceLine no-ops when the setting is off or
-- no market source has data, so no deferred/retry installation is needed.
CraftingPriceTooltip.InstallHooks()
