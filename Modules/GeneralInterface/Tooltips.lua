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
local ResearchableTraitCache = {}

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
        if ResearchableTraitCache and ResearchableTraitCache[bagId] then
            ResearchableTraitCache[bagId] = nil
        end
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
-------------------------------------------------------------------------------------------------
-- HELPERS
-------------------------------------------------------------------------------------------------

--- Retrieves the user-configured tooltip font size.
--- @return number The font size (e.g., 24, 32).
-------------------------------------------------------------------------------------------------
-- HELPERS
-------------------------------------------------------------------------------------------------

--- Retrieves the user-configured tooltip font size.
--- @return number The font size (e.g., 24, 32).
function BETTERUI.GetTooltipFontSize()
    local size = BETTERUI.Settings.Modules["CIM"] and BETTERUI.Settings.Modules["CIM"].tooltipSize
    if not size then
        return BETTERUI.CONST.TOOLTIP.DEFAULT_FONT_SIZE
    end
    

    
    return size
end

--- Gets trading addon price info strings (TTC, MM, ATT).
--- @return table: List of strings to display
function BETTERUI.GetInventoryPriceInfo(itemLink, bagId, slotIndex, storeStackCount)
    local lines = {}
    if itemLink then
        local stackCount
        if storeStackCount then
            stackCount = storeStackCount
        else
            stackCount = GetSlotStackSize(bagId, slotIndex)
        end

        local fontSize = BETTERUI.GetTooltipFontSize()
        -- Use user font size for icons so they match text, slightly smaller for clean look
        local iconSize = math.floor(fontSize * 0.8) 

        if TamrielTradeCentre ~= nil and BETTERUI.Settings.Modules["Tooltips"].ttcIntegration then
            local itemInfo = TamrielTradeCentre_ItemInfo:New(itemLink)
            local priceInfo = TamrielTradeCentrePrice:GetPriceInfo(itemInfo)
            if(priceInfo == nil) then
                table.insert(lines, "TTC Price: No Data")
            else
                local avgPrice = priceInfo.SuggestedPrice or priceInfo.Avg
                if stackCount > 1 then 
                    table.insert(lines, zo_strformat("TTC Price: <<1>> |t<<2>>:<<2>>:<<3>>|t,   Stack(<<4>>): <<5>> |t<<2>>:<<2>>:<<3>>|t", 
                        BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2)), 
                        iconSize,
                        BETTERUI.SafeIcon(GetCurrencyGamepadIcon(CURT_MONEY)), 
                        stackCount, 
                        BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice * stackCount, 2))))
                else
                    table.insert(lines, zo_strformat("TTC Price: <<1>> |t<<2>>:<<2>>:<<3>>|t", 
                        BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2)), 
                        iconSize,
                        BETTERUI.SafeIcon(GetCurrencyGamepadIcon(CURT_MONEY))))
                end
            end
        end

    	if MasterMerchant ~= nil and BETTERUI.Settings.Modules["Tooltips"].mmIntegration then 
            local mmData = MasterMerchant:itemStats(itemLink, false)
            if(mmData.avgPrice == nil or mmData.avgPrice == 0) then
                table.insert(lines, "MM Price: No Data")
            else
                local avgPrice = mmData.avgPrice
                if stackCount > 1 then 
                    table.insert(lines, zo_strformat("MM Price: <<1>> |t<<2>>:<<2>>:<<3>>|t,   Stack(<<4>>): <<5>> |t<<2>>:<<2>>:<<3>>|t", 
                        BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2)), 
                        iconSize,
                        BETTERUI.SafeIcon(GetCurrencyGamepadIcon(CURT_MONEY)), 
                        stackCount, 
                        BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice * stackCount, 2))))
                else
                    table.insert(lines, zo_strformat("MM Price: <<1>> |t<<2>>:<<2>>:<<3>>|t", 
                        BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2)), 
                        iconSize,
                        BETTERUI.SafeIcon(GetCurrencyGamepadIcon(CURT_MONEY))))
                end
            end
    	end

        if ArkadiusTradeTools ~= nil and BETTERUI.Settings.Modules["Tooltips"].attIntegration then 
            local avgPrice = ArkadiusTradeTools.Modules.Sales:GetAveragePricePerItem(itemLink, nil, nil)
            if(avgPrice == nil or avgPrice == 0) then
                table.insert(lines, "ATT Price: No Data")
            else
                if stackCount > 1 then 
                    table.insert(lines, zo_strformat("ATT Price: <<1>> |t<<2>>:<<2>>:<<3>>|t,   Stack(<<4>>): <<5>> |t<<2>>:<<2>>:<<3>>|t", 
                        BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2)), 
                        iconSize,
                        BETTERUI.SafeIcon(GetCurrencyGamepadIcon(CURT_MONEY)), 
                        stackCount, 
                        BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice * stackCount, 2))))
                else
                    table.insert(lines, zo_strformat("ATT Price: <<1>> |t<<2>>:<<2>>:<<3>>|t", 
                        BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2)), 
                        iconSize,
                        BETTERUI.SafeIcon(GetCurrencyGamepadIcon(CURT_MONEY))))
                end
            end
        end
    end
    return lines
end

--- Gets style and research status info strings.
--- @return table: List of strings to display
function BETTERUI.GetInventoryTraitInfo(itemLink)
    local lines = {}
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
            return lines
        end    

        local style = GetItemLinkItemStyle(itemLink)
        local itemStyle = string.upper(GetString("SI_ITEMSTYLE", style))                    

        table.insert(lines, zo_strformat("<<1>> Trait: <<2>>", itemStyle, traitString))

        if(itemStyle ~= ("NONE")) then
            table.insert(lines, zo_strformat("<<1>>", itemStyle))
        end
    end
    return lines
end

--- Hooks tooltip layout methods to inject pricing and research info.
---
--- Purpose: Intercepts standard tooltip calls to add custom data.
--- Mechanics:
--- 1. Wraps standard methods (`method2`, `method3`, `method`) with closures.
--- 2. Captures arguments (bagId, itemLink, etc.) before calling original method.
--- 3. Calls AddLine after the original to append Price/Trait info at the bottom.
--- 4. Scales labels to user's font preference.
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
        
        -- Capture current item link for Status Hook/Inventory Update to read
        self._betterui_itemLink = itemLink
        self._betterui_bagId = bagId
        self._betterui_slotIndex = slotIndex
        self._betterui_storeStackCount = storeStackCount

        -- 1. Draw the standard tooltip first
        newMethod(self, ...)

        -- 2. Scale Fonts
        local fontSize = BETTERUI.GetTooltipFontSize()
        local fontStr = "EsoUI/Common/Fonts/Univers57.otf|" .. fontSize .. "|soft-shadow-thick"
        
        for i = 1, self:GetNumChildren() do
            local child = self:GetChild(i)
            if child and child:GetType() == CT_LABEL then
                child:SetFont(fontStr)
            end
        end
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