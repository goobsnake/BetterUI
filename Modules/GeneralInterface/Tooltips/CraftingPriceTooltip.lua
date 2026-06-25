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
local _hookInstallRetryCallId = nil
local _hookInstallRetryCount = 0
local MAX_HOOK_INSTALL_RETRIES = 5

local function GetCurrentSceneName()
    if SCENE_MANAGER and type(SCENE_MANAGER.GetCurrentSceneName) == "function" then
        local ok, sceneName = pcall(function() return SCENE_MANAGER:GetCurrentSceneName() end)
        if ok then return sceneName end
    end
    return nil
end

local function TraceCraftingPriceTooltip(event, phase, data)
    local L = BETTERUI and BETTERUI.Log or nil
    if not L or type(L.TraceEvent) ~= "function" then return end
    local payload = data or {}
    payload.module = "GeneralInterface"
    payload.feature = "crafting_price_tooltip"
    payload.scene = GetCurrentSceneName()
    payload.gamepad = IsInGamepadPreferredMode and IsInGamepadPreferredMode() or nil
    if type(L.SetLastAction) == "function" then
        L.SetLastAction({ flow = event, message = tostring(event) .. ":" .. tostring(phase) })
    end
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.GENERAL, event, phase, payload)
end

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
    if not tooltipControl or not itemLink or itemLink == "" then
        TraceCraftingPriceTooltip("general_interface.crafting_price_tooltip", "append_skipped", { fn = "AppendPriceLine", reason = "missingTooltipOrItem", itemLink = itemLink })
        return
    end
    if not IsCraftingMarketPriceEnabled() then
        TraceCraftingPriceTooltip("general_interface.crafting_price_tooltip", "append_skipped", { fn = "AppendPriceLine", reason = "settingDisabled", itemLink = itemLink })
        return
    end
    if not MARKET_INTEGRATION or type(MARKET_INTEGRATION.GetMarketPriceInfo) ~= "function" then
        TraceCraftingPriceTooltip("general_interface.crafting_price_tooltip", "append_skipped", { fn = "AppendPriceLine", reason = "missingMarketIntegration", itemLink = itemLink })
        return
    end
    -- Gamepad tooltips only: keyboard tooltip controls lack the section API.
    if type(tooltipControl.AcquireSection) ~= "function"
        or type(tooltipControl.GetStyle) ~= "function"
        or type(tooltipControl.AddSection) ~= "function" then
        TraceCraftingPriceTooltip("general_interface.crafting_price_tooltip", "append_skipped", { fn = "AppendPriceLine", reason = "unsupportedTooltipControl", itemLink = itemLink })
        return
    end

    local generalInterfaceSettings = type(BETTERUI.GetModuleSettings) == "function"
        and (BETTERUI.GetModuleSettings("GeneralInterface") or {}) or {}
    local stackCount = 1
    local ok, priceInfo = pcall(MARKET_INTEGRATION.GetMarketPriceInfo, itemLink, stackCount, generalInterfaceSettings)
    if not ok then
        TraceCraftingPriceTooltip("general_interface.crafting_price_tooltip", "append_skipped", { fn = "AppendPriceLine", reason = "marketApiError", itemLink = itemLink, error = tostring(priceInfo), priority = generalInterfaceSettings.marketPricePriority, stackCount = stackCount })
        return
    end
    if not priceInfo or not priceInfo.hasData or not priceInfo.price or priceInfo.price <= 0 then
        TraceCraftingPriceTooltip("general_interface.crafting_price_tooltip", "append_skipped", { fn = "AppendPriceLine", reason = "noMarketData", itemLink = itemLink, hasData = priceInfo and priceInfo.hasData or false, price = priceInfo and priceInfo.price or nil, sourceKey = priceInfo and priceInfo.sourceKey or nil, priority = generalInterfaceSettings.marketPricePriority, stackCount = stackCount })
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
    TraceCraftingPriceTooltip("general_interface.crafting_price_tooltip", "appended", { fn = "AppendPriceLine", itemLink = itemLink, price = priceInfo.price, sourceKey = priceInfo.sourceKey, priority = generalInterfaceSettings.marketPricePriority, stackCount = stackCount, displayPrice = displayPrice })
end

-- Exposed for unit tests.
CraftingPriceTooltip.AppendPriceLine = AppendPriceLine

--- Post-hook for ZO_GamepadSmithingCreation:SetupResultTooltip.
local function OnCreationResultTooltip(smithingCreation, patternIndex, materialIndex, materialQuantity, styleId, traitIndex)
    if type(GetSmithingPatternResultLink) ~= "function" then
        TraceCraftingPriceTooltip("general_interface.crafting_price_tooltip", "link_failed", { fn = "OnCreationResultTooltip", reason = "missingApi" })
        return
    end
    local tip = smithingCreation and smithingCreation.resultTooltip and smithingCreation.resultTooltip.tip
    if not tip then return end

    local ok, itemLink = pcall(GetSmithingPatternResultLink, patternIndex, materialIndex, materialQuantity, styleId, traitIndex)
    if not ok or not itemLink or itemLink == "" then
        TraceCraftingPriceTooltip("general_interface.crafting_price_tooltip", "link_failed", { fn = "OnCreationResultTooltip", reason = ok and "nilLink" or "apiError", error = ok and nil or tostring(itemLink), patternIndex = patternIndex, materialIndex = materialIndex, materialQuantity = materialQuantity, styleId = styleId, traitIndex = traitIndex })
        return
    end
    AppendPriceLine(tip, itemLink)
end

--- Post-hook for ZO_GamepadSmithingImprovement:SetupResultTooltip.
local function OnImprovementResultTooltip(smithingImprovement, itemToImproveBagId, itemToImproveSlotIndex, craftingSkillType)
    if type(GetSmithingImprovedItemLink) ~= "function" then
        TraceCraftingPriceTooltip("general_interface.crafting_price_tooltip", "link_failed", { fn = "OnImprovementResultTooltip", reason = "missingApi" })
        return
    end
    local tip = smithingImprovement and smithingImprovement.resultTooltip and smithingImprovement.resultTooltip.tip
    if not tip then return end

    local ok, itemLink = pcall(GetSmithingImprovedItemLink, itemToImproveBagId, itemToImproveSlotIndex, craftingSkillType)
    if not ok or not itemLink or itemLink == "" then
        TraceCraftingPriceTooltip("general_interface.crafting_price_tooltip", "link_failed", { fn = "OnImprovementResultTooltip", reason = ok and "nilLink" or "apiError", error = ok and nil or tostring(itemLink), bagId = itemToImproveBagId, slotIndex = itemToImproveSlotIndex, craftingSkillType = craftingSkillType })
        return
    end
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
        TraceCraftingPriceTooltip("general_interface.crafting_price_tooltip_hooks", "posthook_installed", { fn = "InstallHooks", class = "ZO_GamepadSmithingCreation", method = "SetupResultTooltip", target = type(creationClass) })
        hooked = true
    end
    local improvementClass = rawget(_G, "ZO_GamepadSmithingImprovement")
    if improvementClass and improvementClass.SetupResultTooltip then
        ZO_PostHook(improvementClass, "SetupResultTooltip", OnImprovementResultTooltip)
        TraceCraftingPriceTooltip("general_interface.crafting_price_tooltip_hooks", "posthook_installed", { fn = "InstallHooks", class = "ZO_GamepadSmithingImprovement", method = "SetupResultTooltip", target = type(improvementClass) })
        hooked = true
    end

    _hooksInstalled = hooked
    TraceCraftingPriceTooltip("general_interface.crafting_price_tooltip_hooks", "install_end", { fn = "InstallHooks", installed = hooked })
    if not hooked and type(zo_callLater) == "function" and not _hookInstallRetryCallId and _hookInstallRetryCount < MAX_HOOK_INSTALL_RETRIES then
        _hookInstallRetryCount = _hookInstallRetryCount + 1
        _hookInstallRetryCallId = zo_callLater(function()
            _hookInstallRetryCallId = nil
            CraftingPriceTooltip.InstallHooks()
        end, 1000)
        TraceCraftingPriceTooltip("general_interface.crafting_price_tooltip_hooks", "retry_scheduled", {
            fn = "InstallHooks",
            retry = _hookInstallRetryCount,
            delayMs = 1000,
        })
    elseif not hooked and _hookInstallRetryCount >= MAX_HOOK_INSTALL_RETRIES then
        TraceCraftingPriceTooltip("general_interface.crafting_price_tooltip_hooks", "retry_exhausted", {
            fn = "InstallHooks",
            retries = _hookInstallRetryCount,
        })
    end
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
