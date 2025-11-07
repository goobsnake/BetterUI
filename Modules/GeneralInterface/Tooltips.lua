_G.gsErrorSuppress = 0
local _

-- Cached researchable trait counters per bag to avoid re-scanning on every tooltip
local ResearchableTraitCache = {}

-- Internal: build the cache for a specific bag
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

--- Returns the number of researchable items in the bag that share the same trait as itemLink.
--- Uses a per-bag cache invalidated on inventory events for performance.
function BETTERUI.Tooltips.GetCachedResearchableTraitMatches(itemLink, bagId)
    if not itemLink or not bagId then return 0 end
    local traitType = GetItemLinkTraitInfo(itemLink)
    if not traitType or traitType == 0 then return 0 end
    if not ResearchableTraitCache[bagId] then
        BuildBagResearchCache(bagId)
    end
    return (ResearchableTraitCache[bagId] and ResearchableTraitCache[bagId][traitType]) or 0
end

--- Invalidates the researchable trait cache for a specific bag or all bags
--- @param bagId number|nil: The bag ID to invalidate, or nil to clear all
function BETTERUI.Tooltips.InvalidateResearchableTraitCache(bagId)
    if bagId then
        ResearchableTraitCache[bagId] = nil
    else
        ResearchableTraitCache = {}
    end
end

--- Adds pricing information from trading addons to the tooltip after the main item info
--- @param tooltip table: The tooltip control
--- @param itemLink string: The item link
--- @param bagId number: The bag ID
--- @param slotIndex number: The slot index
--- @param storeStackCount number: Stack count for store items
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

--- Adds style and trait research information to the tooltip before the main item info
--- @param tooltip table: The tooltip control
--- @param itemLink string: The item link
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

--- Hooks tooltip layout methods to inject custom information display. This allows BetterUI to add market prices, research status, and other custom data to tooltips by intercepting ESO's tooltip rendering.
--- @param tooltipControl table: The tooltip control to hook
--- @param method string: The primary layout method name
--- @param linkFunc function: Function to get item link for primary method
--- @param method2 string: Secondary layout method name
--- @param linkFunc2 function: Function to get bag/slot for secondary method
--- @param method3 string: Tertiary layout method name
--- @param linkFunc3 function: Function to get store data for tertiary method
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

--- Returns the item link as is
--- @param itemLink string: The item link
--- @return string: The item link
function BETTERUI.ReturnItemLink(itemLink)
    return itemLink
end

--- Returns the bag ID and slot index
--- @param bagId number: The bag ID
--- @param slotIndex number: The slot index
--- @return number, number: bagId, slotIndex
function BETTERUI.ReturnSelectedData(bagId, slotIndex)
    return bagId, slotIndex
end

--- Returns the store item link and stack count
--- @param storeItemLink string: The store item link
--- @param storeStackCount number: The stack count
--- @return string, number: storeItemLink, storeStackCount
function BETTERUI.ReturnStoreSearch(storeItemLink, storeStackCount)
    return storeItemLink, storeStackCount
end