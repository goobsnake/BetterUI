--[[
File: Modules/CIM/Tooltips/Tooltips.lua
Purpose: Enriches item tooltips with useful information.
         Integrates market pricing, research status, and font scaling.
Last Modified: 2026-01-28

FEATURES:
1. Market Pricing: Integrates with Tamriel Trade Centre (TTC), Master Merchant (MM), and Arkadius Trade Tools (ATT).
2. Research Status: Indicates if an item's trait is researchable and where other copies are located.
3. Optimization: Uses caching (ResearchableTraitCache) to minimize performance impact during inventory scans.
]]

-- TODO(bug): gsErrorSuppress pollutes _G namespace and is written from EnhancementModule.lua without declaration; move into BETTERUI.CIM._gsErrorSuppress
_G.gsErrorSuppress = 0 -- Global flag for guild store error suppression

-------------------------------------------------------------------------------------------------
-- RESEARCH TRAIT CACHING
-------------------------------------------------------------------------------------------------
-- Performance optimization for trait research lookups. Building research info is expensive
-- (requires iterating all items in a bag), so we cache results and invalidate on changes.
--
-- OPTIMIZATION: Uses EVENT_INVENTORY_SINGLE_SLOT_UPDATE for targeted bag-specific invalidation
-- instead of clearing the entire cache. See OnInventorySlotUpdate handler at end of file.
--
-- NOTE (2026-01-28): BAG_VIRTUAL (craft bag) is fully supported via the generic bagId parameter.
-- SHARED_INVENTORY:GenerateFullSlotData handles virtual bag iteration transparently.
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
function BETTERUI.GeneralInterface.GetCachedResearchableTraitMatches(itemLink, bagId)
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
function BETTERUI.GeneralInterface.InvalidateResearchableTraitCache(bagId)
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

--- Generic helper to retrieve pricing from a specific trading addon.
---
--- Purpose: Eliminates boilerplate for MM, TTC, ATT, and future integrations.
--- Mechanics:
--- 1. Checks if addon exists and is enabled in settings.
--- 2. Executes getPriceFunc.
--- 3. Formats result with currency icon and stack calculations.
---
--- @param addonName string Friendly name of the addon (e.g., "TTC")
--- @param addonGlobal table|nil Reference to the addon's global object
--- @param getPriceFunc function Function that returns the average price for the item
--- @param settingKey string Settings key to check for enabling/disabling
--- @param itemLink string The item link
--- @param stackCount number The stack size
--- @param iconSize number The desired icon size
--- @return string|nil The formatted price string, or nil if data missing/addon disabled
local function GetAddonPriceDisplay(addonName, addonGlobal, getPriceFunc, settingKey, itemLink, stackCount, iconSize)
    if addonGlobal == nil or not BETTERUI.Settings.Modules["GeneralInterface"][settingKey] then
        return nil
    end

    local avgPrice = getPriceFunc(itemLink)
    if not avgPrice or avgPrice == 0 then
        return zo_strformat(GetString(SI_BETTERUI_MARKET_NO_PRICE_DATA), addonName)
    end

    if stackCount > 1 then
        local coinIcon = string.format("|t%d:%d:%s|t", iconSize, iconSize,
            BETTERUI.SafeIcon(GetCurrencyGamepadIcon(CURT_MONEY)))
        return zo_strformat(GetString(SI_BETTERUI_MARKET_PRICE_STACK),
            addonName,
            BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2)) .. " " .. coinIcon,
            stackCount,
            BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice * stackCount, 2)) .. " " .. coinIcon)
    else
        local coinIcon = string.format("|t%d:%d:%s|t", iconSize, iconSize,
            BETTERUI.SafeIcon(GetCurrencyGamepadIcon(CURT_MONEY)))
        return zo_strformat(GetString(SI_BETTERUI_MARKET_PRICE),
            addonName,
            BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2)) .. " " .. coinIcon)
    end
end

--- Gets trading addon price info strings (TTC, MM, ATT).
--- @return table: List of strings to display
function BETTERUI.GetInventoryPriceInfo(itemLink, bagId, slotIndex, storeStackCount)
    local lines = {}
    if itemLink then
        local stackCount = storeStackCount or GetSlotStackSize(bagId, slotIndex)
        local fontSize = BETTERUI.GetTooltipFontSize()
        local iconSize = math.floor(fontSize * 0.7)

        -- TTC Integration (custom format to show both Avg and Suggested prices)
        if TamrielTradeCentre and BETTERUI.Settings.Modules["GeneralInterface"].ttcIntegration then
            local itemInfo = TamrielTradeCentre_ItemInfo:New(itemLink)
            local priceInfo = TamrielTradeCentrePrice:GetPriceInfo(itemInfo)
            if priceInfo then
                local avgPrice = priceInfo.Avg
                local sugPrice = priceInfo.SuggestedPrice
                local coinIcon = BETTERUI.SafeIcon(GetCurrencyGamepadIcon(CURT_MONEY))
                local ttcLine

                if avgPrice and sugPrice then
                    -- Both prices available - show both
                    local coinIconStr = string.format("|t%d:%d:%s|t", iconSize, iconSize, coinIcon)
                    ttcLine = zo_strformat(GetString(SI_BETTERUI_MARKET_TTC_AVG_SUG),
                        BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2)),
                        BETTERUI.DisplayNumber(BETTERUI.roundNumber(sugPrice, 2))) .. " " .. coinIconStr
                elseif avgPrice then
                    -- Only Avg available
                    local coinIconStr = string.format("|t%d:%d:%s|t", iconSize, iconSize, coinIcon)
                    ttcLine = zo_strformat(GetString(SI_BETTERUI_MARKET_TTC_AVG),
                        BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2))) .. " " .. coinIconStr
                elseif sugPrice then
                    -- Only Suggested available
                    local coinIconStr = string.format("|t%d:%d:%s|t", iconSize, iconSize, coinIcon)
                    ttcLine = zo_strformat(GetString(SI_BETTERUI_MARKET_TTC_SUG),
                        BETTERUI.DisplayNumber(BETTERUI.roundNumber(sugPrice, 2))) .. " " .. coinIconStr
                else
                    ttcLine = zo_strformat(GetString(SI_BETTERUI_MARKET_NO_PRICE_DATA), "TTC")
                end

                if ttcLine then table.insert(lines, ttcLine) end
            else
                -- priceInfo is nil — TTC has no data for this item at all
                table.insert(lines, zo_strformat(GetString(SI_BETTERUI_MARKET_NO_PRICE_DATA), "TTC"))
            end
        end

        -- MM Integration
        local mmLine = GetAddonPriceDisplay("MM", MasterMerchant, function(link)
            local mmData = MasterMerchant:itemStats(link, false)
            return mmData and mmData.avgPrice
        end, "mmIntegration", itemLink, stackCount, iconSize)
        if mmLine then table.insert(lines, mmLine) end

        -- ATT Integration
        local attLine = GetAddonPriceDisplay("ATT", ArkadiusTradeTools, function(link)
            return ArkadiusTradeTools.Modules.Sales:GetAveragePricePerItem(link, nil, nil)
        end, "attIntegration", itemLink, stackCount, iconSize)
        if attLine then table.insert(lines, attLine) end
    end
    return lines
end

--- Gets style and research status info strings.
--- @return table: List of strings to display
function BETTERUI.GetInventoryTraitInfo(itemLink)
    local lines = {}
    if itemLink and BETTERUI.Settings.Modules["GeneralInterface"].showStyleTrait then
        local traitString
        local colors = BETTERUI.CIM.CONST.COLORS

        if (CanItemLinkBeTraitResearched(itemLink)) then
            -- Find owned items that can be researchable
            if (BETTERUI.GeneralInterface.GetCachedResearchableTraitMatches(itemLink, BAG_BACKPACK) > 0) then
                traitString = colors.RESEARCHABLE ..
                    "Researchable|r - " .. colors.FOUND_LOCATION .. "Found in Inventory|r"
            elseif (BETTERUI.GeneralInterface.GetCachedResearchableTraitMatches(itemLink, BAG_BANK) + BETTERUI.GeneralInterface.GetCachedResearchableTraitMatches(itemLink, BAG_SUBSCRIBER_BANK) > 0) then
                traitString = colors.RESEARCHABLE .. "Researchable|r - " .. colors.FOUND_LOCATION .. "Found in Bank|r"
            elseif (BETTERUI.CIM.Utils.GetHouseBankTraitMatches(itemLink) > 0) then
                traitString = colors.RESEARCHABLE ..
                    "Researchable|r - " .. colors.FOUND_LOCATION .. "Found in House Bank|r"
            elseif (BETTERUI.GeneralInterface.GetCachedResearchableTraitMatches(itemLink, BAG_WORN) > 0) then
                traitString = colors.RESEARCHABLE .. "Researchable|r - " .. colors.FOUND_LOCATION .. "Found Equipped|r"
            else
                traitString = colors.RESEARCHABLE .. "Researchable|r"
            end
        else
            return lines
        end

        local style = GetItemLinkItemStyle(itemLink)
        local itemStyle = string.upper(GetString("SI_ITEMSTYLE", style))

        table.insert(lines, zo_strformat("<<1>> Trait: <<2>>", itemStyle, traitString))

        if (itemStyle ~= ("NONE")) then
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
--- @param _tooltipType any Tooltip type constant (reserved for future use).
--- @param method string The method name to hook/override.
--- @param linkFunc function Function to retrieve item link.
--- @param method2 string Secondary method to hook (typically for bag/slot retrieval).
--- @param linkFunc2 function Secondary link function.
--- @param method3 string Tertiary method to hook (for store search).
--- @param linkFunc3 function Tertiary link function.
function BETTERUI.InventoryHook(tooltipControl, _tooltipType, method, linkFunc, method2, linkFunc2, method3, linkFunc3)
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
        -- Clear store-specific state when navigating to a bag item
        storeItemLink = nil
        storeStackCount = nil
        newMethod2(self, ...)
    end
    tooltipControl[method3] = function(self, ...)
        storeItemLink, storeStackCount = linkFunc3(...)
        -- Clear bag-specific state when navigating to a store item
        bagId = nil
        slotIndex = nil
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

        -- Clear consumed store state to prevent it persisting to the next item
        storeItemLink = nil
        storeStackCount = nil

        -- 1. Draw the standard tooltip first (other addon hooks fire within this call chain)
        newMethod(self, ...)

        -- 2. Get Settings
        local settings = BETTERUI.Settings.Modules["CIM"]
        local enhancementsEnabled = settings and settings.enableTooltipEnhancements ~= false

        local fontSize = BETTERUI.GetTooltipFontSize()
        local fontStr = "$(MEDIUM_FONT)|" .. fontSize .. "|soft-shadow-thick"

        -- 3. Scale Fonts immediately (this is safe to do now)
        for i = 1, self:GetNumChildren() do
            local child = self:GetChild(i)
            if child and child:GetType() == CT_LABEL then
                child:SetFont(fontStr)
            end
        end

        -- 4. Defer duplicate addon label cleanup to next frame
        -- Trading addons (TTC, MM, ATT) may hook LayoutItem AFTER BetterUI,
        -- meaning their labels are added after our wrapper returns. By deferring
        -- the cleanup scan, we ensure all addon hooks have finished.
        -- The scan must be RECURSIVE because addon labels added via
        -- ZO_Tooltip:AddLine() are nested inside section controls, not direct
        -- children of the tooltip.
        if enhancementsEnabled then
            local tooltipRef = self
            zo_callLater(function()
                if not tooltipRef or tooltipRef:IsHidden() then return end

                -- Recursive label scan: trading addon labels are nested inside
                -- ZO_TooltipSection controls (tooltip → contentsSection → subsection → label)
                local function ScanAndHideAddonLabels(control)
                    for i = 1, control:GetNumChildren() do
                        local child = control:GetChild(i)
                        if child then
                            if child:GetType() == CT_LABEL and not child:IsHidden() then
                                local text = child:GetText()
                                if text then
                                    -- Strip ESO color markup (|cXXXXXX ... |r) for matching,
                                    -- since addons may wrap their labels in color codes
                                    local plainText = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
                                    -- Match known addon label prefixes
                                    local isDuplicateAddonLine = (plainText:find("^TTC:") ~= nil)
                                        or (plainText:find("^Tamriel Trade Centre") ~= nil)
                                        or (plainText:find("^M%.M%.") ~= nil)
                                        or (plainText:find("^Master Merchant") ~= nil)
                                        or (plainText:find("^ATT:") ~= nil)
                                        or (plainText:find("^Arkadius' Trade Tools") ~= nil)
                                    if isDuplicateAddonLine then
                                        child:SetHidden(true)
                                        child:SetHeight(0)

                                        -- Also hide the preceding divider texture if present
                                        if i > 1 then
                                            local prevChild = control:GetChild(i - 1)
                                            if prevChild and prevChild:GetType() == CT_TEXTURE then
                                                prevChild:SetHidden(true)
                                                prevChild:SetHeight(0)
                                            end
                                        end
                                    end
                                end
                            end
                            -- Recurse into child controls (sections, containers)
                            if child:GetNumChildren() > 0 then
                                ScanAndHideAddonLabels(child)
                            end
                        end
                    end
                end

                ScanAndHideAddonLabels(tooltipRef)
            end, 1) -- 1ms delay = next frame
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

-------------------------------------------------------------------------------------------------
-- EVENT HANDLERS
-------------------------------------------------------------------------------------------------

--- Handles single slot updates to invalidate the research trait cache for the specific bag.
---
--- Purpose: targeted invalidation instead of clearing the entire cache.
--- @param eventCode number The event code
--- @param bagId number The bag ID of the updated slot
--- @param slotIndex number The slot index
--- @param isNewItem boolean Whether the item is new
--- @param itemSoundCategory number Sound category
--- @param updateReason number Reason for the update
--- @param stackCountChange number Change in stack count
local function OnInventorySlotUpdate(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, updateReason,
                                     stackCountChange)
    -- Only invalidate if item was added/removed/changed (not just equipped status on self, though trait research usually doesn't change on equip)
    -- Check for DEFAULT update reason which covers most inventory mutations
    if updateReason == INVENTORY_UPDATE_REASON_DEFAULT then
        BETTERUI.GeneralInterface.InvalidateResearchableTraitCache(bagId)
    end
end

BETTERUI.CIM.EventRegistry.Register("Tooltips", "BetterUI_TooltipCache", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
    OnInventorySlotUpdate)
