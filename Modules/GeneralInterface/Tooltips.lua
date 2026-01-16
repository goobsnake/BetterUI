---------------------------------------------------------------------------------------------------
-- BetterUI - Tooltip Enhancements
--
-- This module enriches item tooltips with useful information:
-- 1. Market Pricing: Integrates with Tamriel Trade Centre (TTC), Master Merchant (MM), and Arkadius Trade Tools (ATT).
-- 2. Research Status: Indicates if an item's trait is researchable and where other copies are located.
-- 3. Optimization: Uses caching (ResearchableTraitCache) to minimize performance impact during inventory scans.
---------------------------------------------------------------------------------------------------

_G.gsErrorSuppress = 0  -- Global flag for guild store error suppression
local _

-------------------------------------------------------------------------------------------------
-- RESEARCH TRAIT CACHING
-------------------------------------------------------------------------------------------------
-- Performance optimization for trait research lookups. Building research info is expensive
-- (requires iterating all items in a bag), so we cache results and invalidate on changes.
--
-- TODO(optimization): Consider using bag update events for targeted invalidation instead
--                     of clearing entire bag cache
-- TODO(enhancement): Add support for caching craft bag (BAG_VIRTUAL) traits
-------------------------------------------------------------------------------------------------

--- Builds the cache of researchable trait counts for a specific bag.
---
--- Purpose: Performance optimization to avoid iterating large bags repeatedly.
--- Mechanics:
--- - Uses `SHARED_INVENTORY:GenerateFullSlotData` to get populated slots.
--- - Checks items for researchability (`CanItemLinkBeTraitResearched`).
--- - Aggregates counts by trait type.
--- - Stores result in `ResearchableTraitCache[bagId]`.
---
--- References: Called by GetCachedResearchableTraitMatches.
---
--- @param bagId number The bag ID to cache
local function BuildBagResearchCache(bagId)
    local counts = {}
    -- Prefer SHARED_INVENTORY cache to iterate only used slots
    local items = SHARED_INVENTORY:GenerateFullSlotData(function() return true end, bagId)
    for i = 1, #items do
        local data = items[i]
        local link = GetItemLink(data.bagId, data.slotIndex)
        if link ~= nil and link ~= "" and CanItemLinkBeTraitResearched(link) then
            local traitType = GetItemLinkTraitInfo(link)
            if traitType and traitType ~= 0 then
                counts[traitType] = (counts[traitType] or 0) + 1
            end
        end
    end
    ResearchableTraitCache[bagId] = counts
end

--- Returns count of researchable items matching itemLink's trait in specified bag.
---
--- Purpose: checks if the player has other items with the same trait in a specific bag.
--- Mechanics:
--- - Checks if item has a valid trait.
--- - Rebuilds cache for bag if missing.
--- - Returns cached count.
---
--- References: Used by AddInventoryPreInfo to display where other copies are found.
---
--- @param itemLink string The item link to check.
--- @param bagId number The bag ID to check against.
--- @return number The count of matching researchable items.
function BETTERUI.Tooltips.GetCachedResearchableTraitMatches(itemLink, bagId)
    if not itemLink or not bagId then return 0 end
    local traitType = GetItemLinkTraitInfo(itemLink)
    if not traitType or traitType == 0 then return 0 end
    if not ResearchableTraitCache[bagId] then
        BuildBagResearchCache(bagId)
    end
    return (ResearchableTraitCache[bagId] and ResearchableTraitCache[bagId][traitType]) or 0
end

--- Invalidates the researchable trait cache for a specific bag or all bags.
---
--- Purpose: Ensures cache coherency after inventory updates.
--- Mechanics:
--- - If `bagId` provided: clears entry for that bag.
--- - If `bagId` nil: clears entire cache.
---
--- References: Called by Item/Inventory Update Event Handlers.
---
--- @param bagId number|nil: The bag ID to invalidate, or nil to clear all
function BETTERUI.Tooltips.InvalidateResearchableTraitCache(bagId)
    if bagId then
        ResearchableTraitCache[bagId] = nil
    else
        ResearchableTraitCache = {}
    end
end

-------------------------------------------------------------------------------------------------
-- TRADING ADDON INTEGRATION
-------------------------------------------------------------------------------------------------
-- This section integrates with popular trading addons to show market prices in tooltips:
--   - TTC (Tamriel Trade Centre): Most popular, uses web-scraped listing data
--   - MM (Master Merchant): Guild store sales history
--   - ATT (Arkadius Trade Tools): Alternative sales tracker
--
-- TODO(refactor): The three addon integrations are very similar - extract to reusable function
-- TODO(enhancement): Add support for additional trading addons (e.g., Pricey)
-- TODO(cleanup): Magic numbers (fontSize = 24) should be constants
-------------------------------------------------------------------------------------------------

--- Adds trading addon price info to tooltip (TTC, MM, ATT).
---
--- Purpose: Injects market pricing into the bottom of item tooltips.
--- Mechanics:
--- 1. Defines stack size (using store stack count or bag lookup).
--- 2. Checks enabled integrations (TTC, MM, ATT).
--- 3. Retrieves price from external addon APIs.
--- 4. Formats and adds line to tooltip with Gold Icon.
---
--- References: Called by the hooked Tooltip Layout methods.
---
--- @param tooltip Control The tooltip control
--- @param itemLink string The item link to price
--- @param bagId number|nil The bag ID (for stack count)
--- @param slotIndex number|nil The slot index (for stack count)
--- @param storeStackCount number|nil Stack count for store items (overrides bag lookup)
local function AddInventoryPostInfo(tooltip, itemLink, bagId, slotIndex, storeStackCount)
    if itemLink then
        local stackCount

        if storeStackCount then
            stackCount = storeStackCount
        else
            stackCount = GetSlotStackSize(bagId, slotIndex)
        end

        if TamrielTradeCentre ~= nil and BETTERUI.Settings.Modules["Tooltips"].ttcIntegration then
            local itemInfo = TamrielTradeCentre_ItemInfo:New(itemLink)
            local priceInfo = TamrielTradeCentrePrice:GetPriceInfo(itemInfo)
            if(priceInfo == nil) then
                tooltip:AddLine(string.format("TTC Price: NO LISTING DATA"), { fontSize = 24, fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1 }, tooltip:GetStyle("title"))
            else
                local avgPrice
                if priceInfo.SuggestedPrice then
                    avgPrice = priceInfo.SuggestedPrice
                else 
                    avgPrice = priceInfo.Avg
                end
                    if stackCount > 1 then 
                    tooltip:AddLine(zo_strformat("TTC Price: <<1>> |t18:18:<<2>>|t,   Stack(<<3>>): <<4>> |t18:18:<<2>>|t ", BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2)), BETTERUI.SafeIcon(GetCurrencyGamepadIcon(CURT_MONEY)), stackCount, BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice * stackCount, 2))), { fontSize = 24, fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1 }, tooltip:GetStyle("title"))
                else
                    tooltip:AddLine(zo_strformat("TTC Price: <<1>> |t18:18:<<2>>|t ", BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2)), BETTERUI.SafeIcon(GetCurrencyGamepadIcon(CURT_MONEY))), { fontSize = 24, fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1 }, tooltip:GetStyle("title"))
                end
            end
        end

    	if MasterMerchant ~= nil and BETTERUI.Settings.Modules["Tooltips"].mmIntegration then 

            local mmData = MasterMerchant:itemStats(itemLink, false)

            if(mmData.avgPrice == nil or mmData.avgPrice == 0) then
                tooltip:AddLine(string.format("MM Price: NO LISTING DATA"), { fontSize = 24, fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1 }, tooltip:GetStyle("title"))
            else
                local avgPrice = mmData.avgPrice
                if stackCount > 1 then 
                    tooltip:AddLine(zo_strformat("MM Price: <<1>> |t18:18:<<2>>|t,   Stack(<<3>>): <<4>> |t18:18:<<2>>|t ", BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2)), BETTERUI.SafeIcon(GetCurrencyGamepadIcon(CURT_MONEY)), stackCount, BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice * stackCount, 2))), { fontSize = 24, fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1 }, tooltip:GetStyle("title"))
                else
                    tooltip:AddLine(zo_strformat("MM Price: <<1>> |t18:18:<<2>>|t ", BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2)), BETTERUI.SafeIcon(GetCurrencyGamepadIcon(CURT_MONEY))), { fontSize = 24, fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1 }, tooltip:GetStyle("title"))
                end
            end
    	end

        if ArkadiusTradeTools ~= nil and BETTERUI.Settings.Modules["Tooltips"].attIntegration then 
            local avgPrice = ArkadiusTradeTools.Modules.Sales:GetAveragePricePerItem(itemLink, nil, nil)
            if(avgPrice == nil or avgPrice == 0) then
                tooltip:AddLine(string.format("ATT Price: NO LISTING DATA"), { fontSize = 24, fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1 }, tooltip:GetStyle("title"))
            else
                if stackCount > 1 then 
                    tooltip:AddLine(zo_strformat("ATT Price: <<1>> |t18:18:<<2>>|t,   Stack(<<3>>): <<4>> |t18:18:<<2>>|t ", BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2)), BETTERUI.SafeIcon(GetCurrencyGamepadIcon(CURT_MONEY)), stackCount, BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice * stackCount, 2))), { fontSize = 24, fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1 }, tooltip:GetStyle("title"))
                else
                    tooltip:AddLine(zo_strformat("ATT Price: <<1>> |t18:18:<<2>>|t ", BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2)), BETTERUI.SafeIcon(GetCurrencyGamepadIcon(CURT_MONEY))), { fontSize = 24, fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1 }, tooltip:GetStyle("title"))
                end
            end
        end
        -- Whitespace buffer
        tooltip:AddLine(string.format(""), { fontSize = 12, fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1 }, tooltip:GetStyle("title"))
    end
end

--- Adds item style and research status to tooltip.
---
--- Purpose: Injects style trait info at the top of item tooltips.
--- Mechanics:
--- 1. Checks `CanItemLinkBeTraitResearched`.
--- 2. Uses cached lookups to find if trait is known or present in other bags (Bank, House, Worn).
--- 3. Formats status string (e.g., "Found in Bank").
--- 4. Adds line to tooltip.
---
--- References: Called by the hooked Tooltip Layout methods.
---
--- @param tooltip object The tooltip control.
--- @param itemLink string The item link.
local function AddInventoryPreInfo(tooltip, itemLink)
    if itemLink and BETTERUI.Settings.Modules["Tooltips"].showStyleTrait then
        local traitString
        if(CanItemLinkBeTraitResearched(itemLink))  then
            -- Find owned items that can be researchable
            if(BETTERUI.Tooltips.GetCachedResearchableTraitMatches(itemLink, BAG_BACKPACK) > 0) then
                traitString = "|c00FF00Researchable|r - |cFF9900Found in Inventory|r"
            elseif(BETTERUI.Tooltips.GetCachedResearchableTraitMatches(itemLink, BAG_BANK) + BETTERUI.Tooltips.GetCachedResearchableTraitMatches(itemLink, BAG_SUBSCRIBER_BANK) > 0) then
                traitString = "|c00FF00Researchable|r - |cFF9900Found in Bank|r"
            elseif(BETTERUI.Tooltips.GetCachedResearchableTraitMatches(itemLink, BAG_HOUSE_BANK_ONE)
                + BETTERUI.Tooltips.GetCachedResearchableTraitMatches(itemLink, BAG_HOUSE_BANK_TWO)
                + BETTERUI.Tooltips.GetCachedResearchableTraitMatches(itemLink, BAG_HOUSE_BANK_THREE)
                + BETTERUI.Tooltips.GetCachedResearchableTraitMatches(itemLink, BAG_HOUSE_BANK_FOUR)
                + BETTERUI.Tooltips.GetCachedResearchableTraitMatches(itemLink, BAG_HOUSE_BANK_FIVE)
                + BETTERUI.Tooltips.GetCachedResearchableTraitMatches(itemLink, BAG_HOUSE_BANK_SIX)
                + BETTERUI.Tooltips.GetCachedResearchableTraitMatches(itemLink, BAG_HOUSE_BANK_SEVEN)
                + BETTERUI.Tooltips.GetCachedResearchableTraitMatches(itemLink, BAG_HOUSE_BANK_EIGHT)
                + BETTERUI.Tooltips.GetCachedResearchableTraitMatches(itemLink, BAG_HOUSE_BANK_NINE)
                + BETTERUI.Tooltips.GetCachedResearchableTraitMatches(itemLink, BAG_HOUSE_BANK_TEN) > 0) then
                traitString = "|c00FF00Researchable|r - |cFF9900Found in House Bank|r"
            elseif(BETTERUI.Tooltips.GetCachedResearchableTraitMatches(itemLink, BAG_WORN) > 0) then
                traitString = "|c00FF00Researchable|r - |cFF9900Found Equipped|r"
            else
                traitString = "|c00FF00Researchable|r"
            end
        else
            return
        end    

        local style = GetItemLinkItemStyle(itemLink)
        local itemStyle = string.upper(GetString("SI_ITEMSTYLE", style))                    

        tooltip:AddLine(zo_strformat("<<1>> Trait: <<2>>", itemStyle, traitString), { fontSize = 28, fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1 }, tooltip:GetStyle("title"))

        if(itemStyle ~= ("NONE")) then
            tooltip:AddLine(zo_strformat("<<1>>", itemStyle), { fontSize = 28, fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1 }, tooltip:GetStyle("title"))
        end
    else
        return
    end
end

--- Hooks tooltip layout methods to inject pricing and research info.
---
--- Purpose: Intercepts standard tooltip calls to add custom data.
--- Mechanics:
--- 1. Wraps standard methods (`method2`, `method3`, `method`) with closures.
--- 2. Captures arguments (bagId, itemLink, etc.) before calling original method.
--- 3. Calls `AddInventoryPreInfo` and `AddInventoryPostInfo` around the original implementation.
---
--- References: Called by Setup.
---
--- @param tooltipControl object The tooltip control to hook.
--- @param method string The method name to hook/override.
--- @param linkFunc function Function to retrieve item link.
--- @param method2 string Secondary method to hook (typically for bag/slot retrieval).
--- @param linkFunc2 function Secondary link function.
--- @param method3 string Tertiary method to hook (for store search).
--- @param linkFunc3 function Tertiary link function.
function BETTERUI.InventoryHook(tooltipControl, method, linkFunc, method2, linkFunc2, method3, linkFunc3)
    local newMethod = tooltipControl[method]
    local newMethod2 = tooltipControl[method2]
    local newMethod3 = tooltipControl[method3]
    local bagId
    local itemLink
    local slotIndex
    local storeItemLink
    local storeStackCount

    tooltipControl[method2] = function(self, ...)
        bagId, slotIndex = linkFunc2(...)
        newMethod2(self, ...)
    end
    tooltipControl[method3] = function(self, ...)
        storeItemLink, storeStackCount = linkFunc3(...)
        newMethod3(self, ...)
    end
    tooltipControl[method] = function(self, ...)
        if storeItemLink then
            itemLink = storeItemLink
        else
            itemLink = linkFunc(...)
        end
        AddInventoryPreInfo(self, itemLink)
        AddInventoryPostInfo(self, itemLink, bagId, slotIndex, storeStackCount)
        newMethod(self, ...)
    end
end

-- Passthrough helpers for tooltip hook data extraction
function BETTERUI.ReturnItemLink(itemLink)
    return itemLink
end

function BETTERUI.ReturnSelectedData(bagId, slotIndex)
    return bagId, slotIndex
end

function BETTERUI.ReturnStoreSearch(storeItemLink, storeStackCount)
    return storeItemLink, storeStackCount
end