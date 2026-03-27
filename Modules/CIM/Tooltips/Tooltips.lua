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

-- Guild store error suppression flag (namespaced to avoid _G pollution)
BETTERUI.CIM._gsErrorSuppress = 0

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
-- ─── Constants ───────────────────────────────────────────────────────────────
local ResearchableTraitCache = {}
local DEFAULT_FONT_SIZE = 24

-- ─── Private Helpers ────────────────────────────────────────────────────────

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
        return DEFAULT_FONT_SIZE
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
        local stackCount = storeStackCount
        if stackCount == nil and bagId ~= nil and slotIndex ~= nil then
            stackCount = GetSlotStackSize(bagId, slotIndex)
        end
        if stackCount == nil or stackCount < 1 then
            stackCount = 1
        end
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
                local coinIconStr = string.format("|t%d:%d:%s|t", iconSize, iconSize, coinIcon)
                local ttcLine

                if avgPrice and sugPrice then
                    -- Both prices available
                    ttcLine = zo_strformat(GetString(SI_BETTERUI_MARKET_TTC_AVG_SUG),
                        BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2)),
                        BETTERUI.DisplayNumber(BETTERUI.roundNumber(sugPrice, 2))) .. " " .. coinIconStr
                elseif avgPrice then
                    ttcLine = zo_strformat(GetString(SI_BETTERUI_MARKET_TTC_AVG),
                        BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2))) .. " " .. coinIconStr
                elseif sugPrice then
                    ttcLine = zo_strformat(GetString(SI_BETTERUI_MARKET_TTC_SUG),
                        BETTERUI.DisplayNumber(BETTERUI.roundNumber(sugPrice, 2))) .. " " .. coinIconStr
                else
                    ttcLine = zo_strformat(GetString(SI_BETTERUI_MARKET_NO_PRICE_DATA), "TTC")
                end

                if ttcLine then table.insert(lines, ttcLine) end

                -- Stack total on a separate line for readability
                if stackCount > 1 and (avgPrice or sugPrice) then
                    local totalAvg = avgPrice and BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice * stackCount, 2)) or nil
                    local totalSug = sugPrice and BETTERUI.DisplayNumber(BETTERUI.roundNumber(sugPrice * stackCount, 2)) or nil
                    local stackLine
                    if totalAvg and totalSug then
                        stackLine = zo_strformat(GetString(SI_BETTERUI_MARKET_TTC_STACK_AVG_SUG),
                            stackCount, totalAvg, totalSug) .. " " .. coinIconStr
                    elseif totalAvg then
                        stackLine = zo_strformat(GetString(SI_BETTERUI_MARKET_TTC_STACK_AVG),
                            stackCount, totalAvg) .. " " .. coinIconStr
                    else
                        stackLine = zo_strformat(GetString(SI_BETTERUI_MARKET_TTC_STACK_SUG),
                            stackCount, totalSug) .. " " .. coinIconStr
                    end
                    table.insert(lines, stackLine)
                end
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
    if itemLink and itemLink ~= "" and BETTERUI.Settings.Modules["GeneralInterface"].showStyleTrait then
        local traitString
        local colors = BETTERUI.CIM.CONST.COLORS

        if (CanItemLinkBeTraitResearched(itemLink)) then
            -- Find owned items that can be researchable
            if (BETTERUI.GeneralInterface.GetCachedResearchableTraitMatches(itemLink, BAG_BACKPACK) > 0) then
                traitString = "|c" .. colors.RESEARCHABLE ..
                    "Researchable|r - |c" .. colors.FOUND_LOCATION .. "Found in Inventory|r"
            elseif (BETTERUI.GeneralInterface.GetCachedResearchableTraitMatches(itemLink, BAG_BANK) + BETTERUI.GeneralInterface.GetCachedResearchableTraitMatches(itemLink, BAG_SUBSCRIBER_BANK) > 0) then
                traitString = "|c" .. colors.RESEARCHABLE .. "Researchable|r - |c" .. colors.FOUND_LOCATION .. "Found in Bank|r"
            elseif (BETTERUI.CIM.Utils.GetHouseBankTraitMatches(itemLink) > 0) then
                traitString = "|c" .. colors.RESEARCHABLE ..
                    "Researchable|r - |c" .. colors.FOUND_LOCATION .. "Found in House Bank|r"
            elseif (BETTERUI.GeneralInterface.GetCachedResearchableTraitMatches(itemLink, BAG_WORN) > 0) then
                traitString = "|c" .. colors.RESEARCHABLE .. "Researchable|r - |c" .. colors.FOUND_LOCATION .. "Found Equipped|r"
            else
                traitString = "|c" .. colors.RESEARCHABLE .. "Researchable|r"
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

--- Gets knowledge status for learnable items (recipes, motifs/lore books).
--- Returns a single colored status line: "Not Known" (green) or "Already Known" (grey).
--- Covers ITEMTYPE_RECIPE (provisioning) and any lore book / motif chapter.
--- @return table: List of strings to display (empty if item has no knowledge status)
function BETTERUI.GetInventoryKnowledgeInfo(itemLink)
    local lines = {}
    if not itemLink or itemLink == "" then return lines end

    -- Respect the user's setting (default true when not set)
    local giSettings = BETTERUI.Settings.Modules["GeneralInterface"]
    if giSettings and giSettings.showKnowledgeStatus == false then return lines end

    local colors = BETTERUI.CIM.CONST.COLORS
    local icons  = BETTERUI.CIM.CONST.ICONS
    local fontSize = BETTERUI.GetTooltipFontSize()
    local iconSize = math.floor(fontSize * 1.0)
    local iconSizeFmt = iconSize .. ":" .. iconSize

    local itemType = GetItemLinkItemType(itemLink)

    -- A. Provisioning recipe
    if itemType == ITEMTYPE_RECIPE then
        local icon = icons.RECIPE_UNKNOWN and ("|t" .. iconSizeFmt .. ":" .. icons.RECIPE_UNKNOWN .. "|t ") or ""
        if not IsItemLinkRecipeKnown then
            -- API not available in this context; skip rather than show wrong state
            return lines
        end
        if IsItemLinkRecipeKnown(itemLink) then
            table.insert(lines, icon .. "|cAAAAAA" .. GetString(SI_RECIPE_ALREADY_KNOWN) .. "|r")
        else
            table.insert(lines, icon .. "|c" .. colors.RESEARCHABLE .. GetString(SI_USE_TO_LEARN_RECIPE) .. "|r")
        end
        return lines
    end

    -- B. Lore books and motif chapters (both use IsItemLinkBookKnown / IsItemLinkBookPartOfCollection)
    if IsItemLinkBookPartOfCollection and IsItemLinkBookPartOfCollection(itemLink) then
        local icon = icons.BOOK_UNKNOWN and ("|t" .. iconSizeFmt .. ":" .. icons.BOOK_UNKNOWN .. "|t ") or ""
        -- IsItemLinkBookKnown may not be available in all addon contexts
        if not IsItemLinkBookKnown then
            return lines
        end
        if IsItemLinkBookKnown(itemLink) then
            table.insert(lines, icon .. "|cAAAAAA" .. GetString(SI_LORE_LIBRARY_IN_LIBRARY) .. "|r")
        else
            table.insert(lines, icon .. "|c" .. colors.RESEARCHABLE .. GetString(SI_LORE_LIBRARY_USE_TO_LEARN) .. "|r")
        end
        return lines
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
--- Returns true if a known-incompatible scene is currently active.
--- These are native ESO scenes that share gamepad tooltip controls with BetterUI
--- but pass non-inventory data (e.g., housing furniture) that BetterUI cannot handle.
---
--- When an incompatible scene is active, tooltip wrapper functions pass through
--- to the native ESO method and skip ALL BetterUI enhancement logic, leaving
--- the user in the native ESO tooltip state (not an error-suppressed unknown state).
---
--- This is a BLOCKLIST (not an allowlist) because BetterUI intentionally enhances
--- tooltips in many scenes (guild store, merchant, crafting, etc.) that are NOT
--- at risk — those scenes cannot be active while the housing editor is open.
local function IsIncompatibleSceneActive()
    -- Housing Furniture Browser: uses GAMEPAD_RIGHT_TOOLTIP as an instant-scene
    -- tooltip via AddTooltipInstantScene, passing furniture data that isn't
    -- standard inventory data. BetterUI hooks LayoutItem/LayoutBagItem on all
    -- three gamepad tooltip controls, so this tooltip call reaches our wrapper.
    if GAMEPAD_HOUSING_FURNITURE_BROWSER_SCENE
        and GAMEPAD_HOUSING_FURNITURE_BROWSER_SCENE:IsShowing() then
        return true
    end
    -- Add future incompatible scenes here as they are discovered.
    return false
end

--- @class InventoryHookConfig
--- @field tooltipControl userdata The tooltip control to hook.
--- @field tooltipType number Tooltip type constant (e.g. GAMEPAD_LEFT_TOOLTIP).
--- @field method string The method name to hook/override (e.g. "LayoutItem").
--- @field linkFunc function Function to retrieve item link for 'method'.
--- @field method2 string Secondary method to hook (e.g. "LayoutBagItem").
--- @field linkFunc2 function Function to retrieve bag/slot for 'method2'.
--- @field method3 string Tertiary method to hook (e.g. "LayoutGuildStoreSearchResult").
--- @field linkFunc3 function Function to retrieve store link for 'method3'.

--- @param config InventoryHookConfig|userdata If userdata, treats as legacy positional (tooltipControl).
function BETTERUI.InventoryHook(config, _tooltipType, method, linkFunc, method2, linkFunc2, method3, linkFunc3)
    local tooltipControl, tooltipType
    local layoutItemName, layoutItemDataFn
    local layoutBagName, layoutBagDataFn
    local layoutStoreName, layoutStoreDataFn

    if type(config) == "table" and config.tooltipControl then
        -- New table-based call
        tooltipControl = config.tooltipControl
        tooltipType = config.tooltipType
        layoutItemName = config.method or "LayoutItem"
        layoutItemDataFn = config.linkFunc
        layoutBagName = config.method2 or "LayoutBagItem"
        layoutBagDataFn = config.linkFunc2
        layoutStoreName = config.method3 or "LayoutGuildStoreSearchResult"
        layoutStoreDataFn = config.linkFunc3
    else
        -- Legacy positional call (backward compatibility)
        tooltipControl = config
        tooltipType = _tooltipType
        layoutItemName = method or "LayoutItem"
        layoutItemDataFn = linkFunc
        layoutBagName = method2 or "LayoutBagItem"
        layoutBagDataFn = linkFunc2
        layoutStoreName = method3 or "LayoutGuildStoreSearchResult"
        layoutStoreDataFn = linkFunc3
    end

    if not (tooltipControl and (layoutItemName or layoutBagName or layoutStoreName)) then
        return
    end

    local newMethod = tooltipControl[layoutItemName]
    local newMethod2 = tooltipControl[layoutBagName]
    local newMethod3 = tooltipControl[layoutStoreName]
    local bagId
    local itemLink
    local slotIndex
    local storeItemLink
    local storeStackCount

    if newMethod2 then
        tooltipControl[layoutBagName] = function(self, ...)
            -- Layer 1: Blocklist guard
            if IsIncompatibleSceneActive() then
                newMethod2(self, ...)
                return
            end
            -- Layer 2: SafeExecute safety net
            local ok, result = BETTERUI.CIM.SafeExecute("Tooltips:InventoryHook:path-recovery", function(...)
                return { layoutBagDataFn(...) }
            end, ...)
            if ok and result then
                bagId, slotIndex = result[1], result[2]
            else
                bagId, slotIndex = nil, nil
            end
            -- Clear store-specific state
            storeItemLink = nil
            storeStackCount = nil
            newMethod2(self, ...)
        end
    end

    if newMethod3 then
        tooltipControl[layoutStoreName] = function(self, ...)
            -- Layer 1: Blocklist guard
            if IsIncompatibleSceneActive() then
                newMethod3(self, ...)
                return
            end
            -- Layer 2: SafeExecute safety net
            local ok, result = BETTERUI.CIM.SafeExecute("Tooltips:InventoryHook:store-link", function(...)
                return { layoutStoreDataFn(...) }
            end, ...)
            if ok and result then
                storeItemLink, storeStackCount = result[1], result[2]
            else
                storeItemLink, storeStackCount = nil, nil
            end
            -- Clear bag-specific state
            bagId = nil
            slotIndex = nil
            newMethod3(self, ...)
        end
    end

    if newMethod then
        tooltipControl[layoutItemName] = function(self, ...)
            -- Layer 1: Blocklist guard
            if IsIncompatibleSceneActive() then
                newMethod(self, ...)
                return
            end

            if storeItemLink then
                itemLink = storeItemLink
            else
                -- Layer 2: SafeExecute safety net
                local ok, result = BETTERUI.CIM.SafeExecute("Tooltips:InventoryHook:link-extraction", function(...)
                    return layoutItemDataFn(...)
                end, ...)
                if ok then
                    itemLink = result
                else
                    itemLink = nil
                end
            end

            -- Capture current item link
            local effectiveStoreStackCount = storeStackCount
            if effectiveStoreStackCount == nil and bagId == nil and slotIndex == nil then
                effectiveStoreStackCount = self._betterui_storeStackCount
            end
            self._betterui_itemLink = itemLink
            self._betterui_bagId = bagId
            self._betterui_slotIndex = slotIndex
            self._betterui_storeStackCount = effectiveStoreStackCount

            -- Reset price-rendered flag
            self._betterui_priceRendered = false

            -- Clear consumed store state
            storeItemLink = nil
            storeStackCount = nil

            -- 1. Draw the standard tooltip first
            local layoutOk = BETTERUI.CIM.SafeExecute("Tooltip:LayoutItem", function(...) return newMethod(...) end, self, ...)
            if not layoutOk then
                return
            end

            -- 2. Get Settings
            local settings = BETTERUI.Settings.Modules["CIM"]
            local enhancementsEnabled = settings and settings.enableTooltipEnhancements ~= false

            local fontSize = BETTERUI.GetTooltipFontSize()
            local fontStr = "$(MEDIUM_FONT)|" .. fontSize .. "|soft-shadow-thick"

            -- 3. Scale Fonts
            for i = 1, self:GetNumChildren() do
                local child = self:GetChild(i)
                if child and child:GetType() == CT_LABEL then
                    child:SetFont(fontStr)
                end
            end

            -- 4. Universal enhanced tooltip header injection
            if itemLink then
                local tooltipRef = self
                local capturedTooltipType = tooltipType
                local capturedItemLink = itemLink

                zo_callLater(function()
                    if not tooltipRef or tooltipRef:IsHidden() then return end
                    if tooltipRef._betterui_priceRendered then return end
                    if IsIncompatibleSceneActive() then return end
                    if tooltipRef._betterui_itemLink ~= capturedItemLink then return end

                    -- Render full enhanced header (equipSlot=nil for non-equipped items)
                    BETTERUI.Inventory.UpdateTooltipEquippedText(tonumber(capturedTooltipType) or 0, nil)
                end, 1) -- 1ms = next frame, after Inventory/Banking has had a chance to claim priority
            end

            -- 5. Defer duplicate addon label cleanup
            if enhancementsEnabled then
                local tooltipRef = self
                zo_callLater(function()
                    if not tooltipRef or tooltipRef:IsHidden() then return end
                    if IsIncompatibleSceneActive() then return end

                    local function ScanAndHideAddonLabels(control)
                        for i = 1, control:GetNumChildren() do
                            local child = control:GetChild(i)
                            if child then
                                if child:GetType() == CT_LABEL and not child:IsHidden() then
                                    local text = child:GetText()
                                    if text then
                                        local plainText = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
                                        local isDuplicateAddonLine = (plainText:find("^TTC:") ~= nil)
                                            or (plainText:find("^Tamriel Trade Centre") ~= nil)
                                            or (plainText:find("^M%.M%.") ~= nil)
                                            or (plainText:find("^Master Merchant") ~= nil)
                                            or (plainText:find("^ATT:") ~= nil)
                                            or (plainText:find("^Arkadius' Trade Tools") ~= nil)
                                        if isDuplicateAddonLine then
                                            child:SetHidden(true)
                                            child:SetHeight(0)
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
                                if child:GetNumChildren() > 0 then
                                    ScanAndHideAddonLabels(child)
                                end
                            end
                        end
                    end
                    ScanAndHideAddonLabels(tooltipRef)
                end, 2)
            end
        end
    end
end

-- Passthrough helpers for tooltip hook data extraction
function BETTERUI.ReturnItemLink(itemLink)
    return itemLink
end

--- @param bagId number
--- @param slotIndex number
--- @return number
--- @return number
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
