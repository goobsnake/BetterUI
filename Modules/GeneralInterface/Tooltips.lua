_G.gsErrorSuppress = 0
local _
    
function BETTERUI.Tooltips.GetNumberOfMatchingItems(itemLink, BAG)

    -- Get bag size
    local bagSize = GetNumBagUsedSlots(BAG)
 
    -- Var to hold item matches
    local itemMatches = 0
 
    -- Iterate through BAG
    for i = 0, bagSize do

        -- Get current item
        local currentItem = GetItemLink(BAG, i)
 
        -- Check if current item is researchable
        if(CanItemLinkBeTraitResearched(currentItem)) then
 
            -- Check if current item trait equals item's trait we're checking
            if (GetItemLinkTraitInfo(currentItem) == GetItemLinkTraitInfo(itemLink)) then
                itemMatches = itemMatches + 1
            end
        end
    end
 
    -- return number of matches
    return itemMatches;
end

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
                    tooltip:AddLine(zo_strformat("TTC Price: <<1>> |t18:18:<<2>>|t,   Stack(<<3>>): <<4>> |t18:18:<<2>>|t ", BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2)), GetCurrencyGamepadIcon(CURT_MONEY), stackCount, BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice * stackCount, 2))), { fontSize = 24, fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1 }, tooltip:GetStyle("title"))
                else
                    tooltip:AddLine(zo_strformat("TTC Price: <<1>> |t18:18:<<2>>|t ", BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2)), GetCurrencyGamepadIcon(CURT_MONEY)), { fontSize = 24, fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1 }, tooltip:GetStyle("title"))
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
                    tooltip:AddLine(zo_strformat("MM Price: <<1>> |t18:18:<<2>>|t,   Stack(<<3>>): <<4>> |t18:18:<<2>>|t ", BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2)), GetCurrencyGamepadIcon(CURT_MONEY), stackCount, BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice * stackCount, 2))), { fontSize = 24, fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1 }, tooltip:GetStyle("title"))
                else
                    tooltip:AddLine(zo_strformat("MM Price: <<1>> |t18:18:<<2>>|t ", BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2)), GetCurrencyGamepadIcon(CURT_MONEY)), { fontSize = 24, fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1 }, tooltip:GetStyle("title"))
                end
            end
    	end

        if ArkadiusTradeTools ~= nil and BETTERUI.Settings.Modules["Tooltips"].attIntegration then 
            local avgPrice = ArkadiusTradeTools.Modules.Sales:GetAveragePricePerItem(itemLink, nil, nil)
            if(avgPrice == nil or avgPrice == 0) then
                tooltip:AddLine(string.format("ATT Price: NO LISTING DATA"), { fontSize = 24, fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1 }, tooltip:GetStyle("title"))
            else
                if stackCount > 1 then 
                    tooltip:AddLine(zo_strformat("ATT Price: <<1>> |t18:18:<<2>>|t,   Stack(<<3>>): <<4>> |t18:18:<<2>>|t ", BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2)), GetCurrencyGamepadIcon(CURT_MONEY), stackCount, BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice * stackCount, 2))), { fontSize = 24, fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1 }, tooltip:GetStyle("title"))
                else
                    tooltip:AddLine(zo_strformat("ATT Price: <<1>> |t18:18:<<2>>|t ", BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2)), GetCurrencyGamepadIcon(CURT_MONEY)), { fontSize = 24, fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1 }, tooltip:GetStyle("title"))
                end
            end
        end
        -- Whitespace buffer
        tooltip:AddLine(string.format(""), { fontSize = 12, fontColorField = GAMEPAD_TOOLTIP_COLOR_GENERAL_COLOR_1 }, tooltip:GetStyle("title"))
    end
end

local function AddInventoryPreInfo(tooltip, itemLink)
    if itemLink and BETTERUI.Settings.Modules["Tooltips"].showStyleTrait then
        local traitString
        if(CanItemLinkBeTraitResearched(itemLink))  then
            -- Find owned items that can be researchable
            if(BETTERUI.Tooltips.GetNumberOfMatchingItems(itemLink, BAG_BACKPACK) > 0) then
                traitString = "|c00FF00Researchable|r - |cFF9900Found in Inventory|r"
            elseif(BETTERUI.Tooltips.GetNumberOfMatchingItems(itemLink, BAG_BANK) + BETTERUI.Tooltips.GetNumberOfMatchingItems(itemLink, BAG_SUBSCRIBER_BANK) > 0) then
                traitString = "|c00FF00Researchable|r - |cFF9900Found in Bank|r"
            elseif(BETTERUI.Tooltips.GetNumberOfMatchingItems(itemLink, BAG_HOUSE_BANK_ONE) + BETTERUI.Tooltips.GetNumberOfMatchingItems(itemLink, BAG_HOUSE_BANK_TWO) + BETTERUI.Tooltips.GetNumberOfMatchingItems(itemLink, BAG_HOUSE_BANK_THREE) + BETTERUI.Tooltips.GetNumberOfMatchingItems(itemLink, BAG_HOUSE_BANK_FOUR) + BETTERUI.Tooltips.GetNumberOfMatchingItems(itemLink, BAG_HOUSE_BANK_FIVE) + BETTERUI.Tooltips.GetNumberOfMatchingItems(itemLink, BAG_HOUSE_BANK_SIX) + BETTERUI.Tooltips.GetNumberOfMatchingItems(itemLink, BAG_HOUSE_BANK_SEVEN) + BETTERUI.Tooltips.GetNumberOfMatchingItems(itemLink, BAG_HOUSE_BANK_EIGHT) + BETTERUI.Tooltips.GetNumberOfMatchingItems(itemLink, BAG_HOUSE_BANK_NINE) + BETTERUI.Tooltips.GetNumberOfMatchingItems(itemLink, BAG_HOUSE_BANK_TEN) > 0) then
                traitString = "|c00FF00Researchable|r - |cFF9900Found in House Bank|r"
            elseif(BETTERUI.Tooltips.GetNumberOfMatchingItems(itemLink, BAG_WORN) > 0) then
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

function BETTERUI.ReturnItemLink(itemLink)
    return itemLink
end

function BETTERUI.ReturnSelectedData(bagId, slotIndex)
    return bagId, slotIndex
end

function BETTERUI.ReturnStoreSearch(storeItemLink, storeStackCount)
    return storeItemLink, storeStackCount
end