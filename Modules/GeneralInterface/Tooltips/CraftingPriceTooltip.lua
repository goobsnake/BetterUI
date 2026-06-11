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

---@return boolean
local function IsAnyMarketSourceAvailable()
    if not MARKET_INTEGRATION or type(MARKET_INTEGRATION.GetMarketPriceInfo) ~= "function" then
        return false
    end
    local giSettings = BETTERUI.GetModuleSettings("GeneralInterface") or {}
    -- At least one source must be enabled and available
    for _, sourceKey in ipairs({"mm", "att", "ttc"}) do
        local info = MARKET_INTEGRATION.GetSourcePriceInfo(sourceKey, "", 1, giSettings)
        if info and info.enabled and info.available then
            return true
        end
    end
    return false
end

--- Append a single price line to the tooltip control.
---@param tooltipControl table
---@param itemLink string
local function AppendPriceLine(tooltipControl, itemLink)
    if not tooltipControl or not itemLink or itemLink == "" then return end
    if not IsCraftingMarketPriceEnabled() then return end
    if not MARKET_INTEGRATION or type(MARKET_INTEGRATION.GetMarketPriceInfo) ~= "function" then
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

    local lineText = zo_strformat("|cFFFFFFMarket: <<1>>|r|t16:16:<<2>>|t<<3>>",
        displayPrice, coinIcon, sourceLabel)

    tooltipControl:AddVerticalPadding(8)
    tooltipControl:AddLine(lineText, "ZoFontGamepad34")
end

--- Post-hook for creation result tooltips.
local function OnLayoutPendingSmithingItem(self, patternIndex, materialIndex, materialQuantity, styleIndex, traitIndex)
    if not IsCraftingMarketPriceEnabled() then return end
    if type(GetSmithingPatternResultLink) ~= "function" then return end

    local itemLink = GetSmithingPatternResultLink(patternIndex, materialIndex, materialQuantity, styleIndex, traitIndex)
    AppendPriceLine(self, itemLink)
end

--- Post-hook for improvement result tooltips.
local function OnLayoutImproveResultSmithingItem(self, itemToImproveBagId, itemToImproveSlotIndex, craftingSkillType)
    if not IsCraftingMarketPriceEnabled() then return end
    if type(GetSmithingImprovedItemLink) ~= "function" then return end

    local itemLink = GetSmithingImprovedItemLink(itemToImproveBagId, itemToImproveSlotIndex, craftingSkillType)
    AppendPriceLine(self, itemLink)
end

--- Install hooks once. Safe to call multiple times.
function CraftingPriceTooltip.InstallHooks()
    if _hooksInstalled then return end
    if type(ZO_PostHook) ~= "function" then return end
    if not MARKET_INTEGRATION then return end

    -- Guard: only install if at least one price source is present
    if not IsAnyMarketSourceAvailable() then
        return
    end

    local tooltipProto = ZO_Tooltip
    if tooltipProto and tooltipProto.LayoutPendingSmithingItem then
        ZO_PostHook(tooltipProto, "LayoutPendingSmithingItem", OnLayoutPendingSmithingItem)
    end
    if tooltipProto and tooltipProto.LayoutImproveResultSmithingItem then
        ZO_PostHook(tooltipProto, "LayoutImproveResultSmithingItem", OnLayoutImproveResultSmithingItem)
    end

    _hooksInstalled = true
end

--- Returns whether hooks are currently installed.
---@return boolean
function CraftingPriceTooltip.AreHooksInstalled()
    return _hooksInstalled
end

-- Retry hook installation on player activation so market addons that load
-- after BetterUI (e.g. via LibStub/dependency ordering) are still picked up.
local _retryHandle = nil
local function TryInstallHooks()
    CraftingPriceTooltip.InstallHooks()
    if _hooksInstalled and _retryHandle then
        EVENT_MANAGER:UnregisterForEvent("BetterUI_CraftingPriceTooltip_Retry", _retryHandle)
        _retryHandle = nil
    end
end

_retryHandle = EVENT_MANAGER:RegisterForEvent("BetterUI_CraftingPriceTooltip_Retry", EVENT_PLAYER_ACTIVATED, TryInstallHooks)

-- Auto-install on load if market sources are available
CraftingPriceTooltip.InstallHooks()
