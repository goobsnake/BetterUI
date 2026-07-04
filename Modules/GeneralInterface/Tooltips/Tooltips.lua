-- Enriches item tooltips with market pricing, research status, and font scaling.
-- Integrates with TTC, Master Merchant, and Arkadius Trade Tools.

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.GeneralInterface = BETTERUI.GeneralInterface or {}
local GeneralInterface = BETTERUI.GeneralInterface
GeneralInterface.Tooltips = GeneralInterface.Tooltips or {}

local Tooltips = GeneralInterface.Tooltips
local TooltipRuntime = Tooltips._runtime or {}
Tooltips._runtime = TooltipRuntime

-- Tooltip tracer via the shared MakeTracer (BUI-CONS-002 / BUI-CONS-003):
-- module/feature/scene(CIM.Utils)/gamepad/last-action and the DEBUG preflight all
-- match the former copy; category defaults to GENERAL and honors a per-call override.
local TraceTooltip = (BETTERUI.Log and BETTERUI.Log.MakeTracer)
    and BETTERUI.Log.MakeTracer{
        module = "GeneralInterface",
        feature = "tooltips",
        category = (BETTERUI.Log.CATEGORY or {}).GENERAL or "GENERAL",
    }
    or function() end

local TOOLTIP_IMMEDIATE_CLEAR_MS = 200

local function TooltipNowMs()
    local fn = rawget(_G, "GetGameTimeMilliseconds")
    if type(fn) ~= "function" then return 0 end
    local ok, value = pcall(fn)
    return ok and tonumber(value) or 0
end

local function IsTooltipLogActive()
    local L = BETTERUI and BETTERUI.Log
    return L and type(L.IsActive) == "function" and L.IsActive() == true
end

local function MarkTooltipContentAppended(tooltipControl, section, appendedBy, tooltipType)
    if not (tooltipControl and IsTooltipLogActive()) then
        return
    end

    local appendedAtMs = TooltipNowMs()
    tooltipControl._betteruiTooltipContentLifecycle = {
        section = section,
        appendedBy = appendedBy,
        tooltipType = tooltipType,
        appendedAtMs = appendedAtMs,
    }
    local L = BETTERUI and BETTERUI.Log
    local traceLevel = L and L.LEVEL and L.LEVEL.TRACE
    TraceTooltip("general_interface.tooltip_content", "changed", {
        fn = "MarkTooltipContentAppended",
        action = "appended",
        section = section,
        by = appendedBy,
        tooltipType = tooltipType,
        atMs = appendedAtMs,
    }, nil, traceLevel)
end

local function TraceTooltipContentCleared(tooltipControl, tooltipType, clearedBy, preserveItemData)
    if not (tooltipControl and IsTooltipLogActive()) then
        return
    end

    local lifecycle = tooltipControl._betteruiTooltipContentLifecycle
    if not lifecycle then
        return
    end
    tooltipControl._betteruiTooltipContentLifecycle = nil

    local now = TooltipNowMs()
    local ageMs = now - (lifecycle.appendedAtMs or now)
    local L = BETTERUI and BETTERUI.Log
    local immediate = ageMs < TOOLTIP_IMMEDIATE_CLEAR_MS
    local level = immediate and (L and L.LEVEL and L.LEVEL.WARN) or (L and L.LEVEL and L.LEVEL.TRACE)
    TraceTooltip("general_interface.tooltip_content", immediate and "detected" or "changed", {
        fn = "TraceTooltipContentCleared",
        action = "cleared",
        section = lifecycle.section,
        appendedBy = lifecycle.appendedBy,
        clearedBy = clearedBy,
        tooltipType = tooltipType or lifecycle.tooltipType,
        ageMs = ageMs,
        immediate = immediate,
        preserveItemData = preserveItemData == true,
    }, nil, level)
end

local function SetGuildStoreErrorSuppressed(isSuppressed)
    TooltipRuntime.guildStoreErrorSuppressed = isSuppressed == true
    BETTERUI.CIM._gsErrorSuppress = TooltipRuntime.guildStoreErrorSuppressed and 1 or 0
    TraceTooltip("general_interface.guild_store_suppression", "flag_set", {
        fn = "Tooltips.SetGuildStoreErrorSuppressed",
        suppressed = TooltipRuntime.guildStoreErrorSuppressed,
    })
end

Tooltips.SetGuildStoreErrorSuppressed = SetGuildStoreErrorSuppressed
Tooltips.GuildStoreSuppression = {
    SetErrorSuppressed = SetGuildStoreErrorSuppressed,
}

function Tooltips.InitializeRuntime()
    if TooltipRuntime.initialized == true then
        TraceTooltip("general_interface.tooltip_runtime", "skipped", {
            fn = "Tooltips.InitializeRuntime",
            reason = "alreadyInitialized",
            guildStoreErrorSuppressed = TooltipRuntime.guildStoreErrorSuppressed == true,
        })
        return true
    end

    SetGuildStoreErrorSuppressed(TooltipRuntime.guildStoreErrorSuppressed == true)

    local cimUtils = BETTERUI.CIM and BETTERUI.CIM.Utils
    if cimUtils and type(cimUtils.RegisterResearchableTraitMatcher) == "function" then
        cimUtils.RegisterResearchableTraitMatcher(GeneralInterface.GetCachedResearchableTraitMatches)
    end

    TooltipRuntime.initialized = true
    TraceTooltip("general_interface.tooltip_runtime", "initialized", {
        fn = "Tooltips.InitializeRuntime",
        registeredResearchMatcher = cimUtils and type(cimUtils.RegisterResearchableTraitMatcher) == "function" or false,
        guildStoreErrorSuppressed = TooltipRuntime.guildStoreErrorSuppressed == true,
    })
    return true
end

-- Trait research lookups iterate bag contents, so cache them per bag and
-- invalidate on targeted slot updates instead of rebuilding everything.
local ResearchableTraitCache = {}
local DEFAULT_FONT_SIZE = 24
-- Stock gamepad tooltip body font; restored when enhancements are toggled off
-- so labels do not keep the enlarged enhanced font size (PB-003).
local STOCK_TOOLTIP_BODY_FONT = "ZoFontGamepad34"


local function BuildBagResearchCache(bagId)
    local counts = {}
    if not SHARED_INVENTORY or type(SHARED_INVENTORY.GenerateFullSlotData) ~= "function" then
        ResearchableTraitCache[bagId] = counts
        TraceTooltip("general_interface.tooltip_research_cache", "build_skipped", {
            fn = "BuildBagResearchCache",
            reason = "missingSharedInventory",
            bagId = bagId,
        })
        return
    end
    -- Prefer SHARED_INVENTORY cache to iterate only used slots
    local items = SHARED_INVENTORY:GenerateFullSlotData(function() return true end, bagId)
    local researchableCount = 0
    local traitTypeCount = 0
    for i = 1, #items do
        local data = items[i]
        local link = GetItemLink(data.bagId, data.slotIndex)
        if link ~= nil and link ~= "" and CanItemLinkBeTraitResearched(link) then
            local traitType = GetItemLinkTraitInfo(link)
            if traitType and traitType ~= 0 then
                if counts[traitType] == nil then
                    traitTypeCount = traitTypeCount + 1
                end
                counts[traitType] = (counts[traitType] or 0) + 1
                researchableCount = researchableCount + 1
            end
        end
    end
    ResearchableTraitCache[bagId] = counts
    TraceTooltip("general_interface.tooltip_research_cache", "built", {
        fn = "BuildBagResearchCache",
        bagId = bagId,
        scanned = #items,
        researchable = researchableCount,
        traitTypes = traitTypeCount,
    })
end

function GeneralInterface.GetCachedResearchableTraitMatches(itemLink, bagId)
    local itemId = GetItemLinkItemId and GetItemLinkItemId(itemLink) or nil
    if not itemLink or not bagId then
        TraceTooltip("general_interface.tooltip_research_cache", "lookup_skipped", {
            fn = "GetCachedResearchableTraitMatches",
            reason = not itemLink and "missingItemLink" or "missingBagId",
            bagId = bagId,
            itemLink = itemLink,
            itemId = itemId,
        })
        return 0
    end
    local traitType = GetItemLinkTraitInfo(itemLink)
    if not traitType or traitType == 0 then
        TraceTooltip("general_interface.tooltip_research_cache", "lookup_skipped", {
            fn = "GetCachedResearchableTraitMatches",
            reason = "missingTraitType",
            bagId = bagId,
            itemLink = itemLink,
            itemId = itemId,
        })
        return 0
    end
    local cacheBuilt = false
    if not ResearchableTraitCache[bagId] then
        BuildBagResearchCache(bagId)
        cacheBuilt = true
    end
    local matches = (ResearchableTraitCache[bagId] and ResearchableTraitCache[bagId][traitType]) or 0
    TraceTooltip("general_interface.tooltip_research_cache", "lookup", {
        fn = "GetCachedResearchableTraitMatches",
        bagId = bagId,
        traitType = traitType,
        matches = matches,
        itemLink = itemLink,
        itemId = itemId,
        cacheBuilt = cacheBuilt,
    })
    return matches
end

function GeneralInterface.InvalidateResearchableTraitCache(bagId)
    if bagId then
        if ResearchableTraitCache and ResearchableTraitCache[bagId] then
            ResearchableTraitCache[bagId] = nil
        end
        TraceTooltip("general_interface.tooltip_research_cache", "invalidated", {
            fn = "InvalidateResearchableTraitCache",
            bagId = bagId,
        })
    else
        ResearchableTraitCache = {}
        TraceTooltip("general_interface.tooltip_research_cache", "invalidated", {
            fn = "InvalidateResearchableTraitCache",
            scope = "all",
        })
    end
end

--- Retrieves the user-configured tooltip font size.
function Tooltips.GetTooltipFontSize()
    local size = BETTERUI.GetSetting("CIM", "tooltipSize", DEFAULT_FONT_SIZE)
    return size
end

BETTERUI.GetTooltipFontSize = Tooltips.GetTooltipFontSize

local function GetSourcePriceDisplay(addonName, sourceInfo, stackCount, iconSize)
    if not sourceInfo or not sourceInfo.enabled or not sourceInfo.available then
        return nil
    end

    local unitPrice = sourceInfo.unitPrice
    if not unitPrice or unitPrice == 0 then
        return zo_strformat(GetString(rawget(_G, "SI_BETTERUI_MARKET_NO_PRICE_DATA")), addonName)
    end

    if stackCount > 1 then
        local coinIcon = string.format("|t%d:%d:%s|t", iconSize, iconSize,
            BETTERUI.SafeIcon(GetCurrencyGamepadIcon(CURT_MONEY)))
        return zo_strformat(GetString(rawget(_G, "SI_BETTERUI_MARKET_PRICE_STACK")),
            addonName,
            BETTERUI.DisplayNumber(BETTERUI.roundNumber(unitPrice, 2)) .. " " .. coinIcon,
            stackCount,
            BETTERUI.DisplayNumber(BETTERUI.roundNumber(unitPrice * stackCount, 2)) .. " " .. coinIcon)
    else
        local coinIcon = string.format("|t%d:%d:%s|t", iconSize, iconSize,
            BETTERUI.SafeIcon(GetCurrencyGamepadIcon(CURT_MONEY)))
        return zo_strformat(GetString(rawget(_G, "SI_BETTERUI_MARKET_PRICE")),
            addonName,
            BETTERUI.DisplayNumber(BETTERUI.roundNumber(unitPrice, 2)) .. " " .. coinIcon)
    end
end

Tooltips.PriceProviders = {
    GetSourcePriceDisplay = GetSourcePriceDisplay,
}

--- Gets trading addon price info strings (TTC, MM, ATT).
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
        local fontSize = Tooltips.GetTooltipFontSize()
        local iconSize = math.floor(fontSize * 0.7)
        local marketIntegration = BETTERUI.CIM and BETTERUI.CIM.MarketIntegration
        local generalInterfaceSettings = {}
        if type(BETTERUI.GetModuleSettings) == "function" then
            generalInterfaceSettings = BETTERUI.GetModuleSettings("GeneralInterface") or {}
        elseif BETTERUI.Settings and BETTERUI.Settings.Modules then
            generalInterfaceSettings = BETTERUI.Settings.Modules.GeneralInterface or {}
        end
        local sourceSummary = {}
        local renderedSources = {}
        local function GetSourceInfo(sourceKey)
            if not marketIntegration then
                sourceSummary[sourceKey] = { enabled = false, available = false, reason = "missingMarketIntegration" }
                return nil
            end
            if type(marketIntegration.GetSourcePriceInfo) ~= "function" then
                sourceSummary[sourceKey] = { enabled = false, available = false, reason = "missingApi" }
                return nil
            end
            local ok, sourceInfo = pcall(function()
                return marketIntegration.GetSourcePriceInfo(sourceKey, itemLink, stackCount, generalInterfaceSettings)
            end)
            if not ok then
                sourceSummary[sourceKey] = { enabled = false, available = false, reason = "apiError", error = tostring(sourceInfo) }
                TraceTooltip("general_interface.tooltip_price", "source_failed", {
                    fn = "GetInventoryPriceInfo.GetSourceInfo",
                    sourceKey = sourceKey,
                    itemLink = itemLink,
                    itemId = GetItemLinkItemId and GetItemLinkItemId(itemLink) or nil,
                    error = tostring(sourceInfo),
                })
                return nil
            end
            sourceSummary[sourceKey] = {
                enabled = sourceInfo and sourceInfo.enabled == true or false,
                available = sourceInfo and sourceInfo.available == true or false,
                hasData = sourceInfo and sourceInfo.hasData == true or false,
                unitPrice = sourceInfo and sourceInfo.unitPrice or nil,
                reason = sourceInfo and sourceInfo.reason or (sourceInfo and sourceInfo.enabled == false and "disabled" or sourceInfo and sourceInfo.available == false and "unavailable" or sourceInfo and sourceInfo.hasData == false and "noData" or nil),
            }
            return sourceInfo
        end

        -- TTC Integration (custom format to show both Avg and Suggested prices)
        local ttcInfo = GetSourceInfo("ttc")
        if ttcInfo and ttcInfo.enabled and ttcInfo.available then
            if ttcInfo.hasData then
                local avgPrice = ttcInfo.averagePrice
                local sugPrice = ttcInfo.suggestedPrice
                local coinIcon = BETTERUI.SafeIcon(GetCurrencyGamepadIcon(CURT_MONEY))
                local coinIconStr = string.format("|t%d:%d:%s|t", iconSize, iconSize, coinIcon)
                local ttcLine

                if avgPrice and sugPrice then
                    -- Both prices available
                    ttcLine = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_MARKET_TTC_AVG_SUG")),
                        BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2)),
                        BETTERUI.DisplayNumber(BETTERUI.roundNumber(sugPrice, 2))) .. " " .. coinIconStr
                elseif avgPrice then
                    ttcLine = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_MARKET_TTC_AVG")),
                        BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice, 2))) .. " " .. coinIconStr
                elseif sugPrice then
                    ttcLine = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_MARKET_TTC_SUG")),
                        BETTERUI.DisplayNumber(BETTERUI.roundNumber(sugPrice, 2))) .. " " .. coinIconStr
                else
                    ttcLine = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_MARKET_NO_PRICE_DATA")), "TTC")
                end

                if ttcLine then table.insert(lines, ttcLine); table.insert(renderedSources, "ttc") end

                -- Stack total on a separate line for readability
                if stackCount > 1 and (avgPrice or sugPrice) then
                    local totalAvg = avgPrice and BETTERUI.DisplayNumber(BETTERUI.roundNumber(avgPrice * stackCount, 2)) or nil
                    local totalSug = sugPrice and BETTERUI.DisplayNumber(BETTERUI.roundNumber(sugPrice * stackCount, 2)) or nil
                    local stackLine
                    if totalAvg and totalSug then
                        stackLine = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_MARKET_TTC_STACK_AVG_SUG")),
                            stackCount, totalAvg, totalSug) .. " " .. coinIconStr
                    elseif totalAvg then
                        stackLine = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_MARKET_TTC_STACK_AVG")),
                            stackCount, totalAvg) .. " " .. coinIconStr
                    else
                        stackLine = zo_strformat(GetString(rawget(_G, "SI_BETTERUI_MARKET_TTC_STACK_SUG")),
                            stackCount, totalSug) .. " " .. coinIconStr
                    end
                    table.insert(lines, stackLine)
                    table.insert(renderedSources, "ttc_stack")
                end
            else
                table.insert(lines, zo_strformat(GetString(rawget(_G, "SI_BETTERUI_MARKET_NO_PRICE_DATA")), "TTC"))
                table.insert(renderedSources, "ttc_no_data")
            end
        end

        -- MM Integration
        local mmInfo = GetSourceInfo("mm")
        local mmLine = GetSourcePriceDisplay("MM", mmInfo, stackCount, iconSize)
        if mmLine then table.insert(lines, mmLine); table.insert(renderedSources, "mm") end

        -- ATT Integration
        local attInfo = GetSourceInfo("att")
        local attLine = GetSourcePriceDisplay("ATT", attInfo, stackCount, iconSize)
        if attLine then table.insert(lines, attLine); table.insert(renderedSources, "att") end
        TraceTooltip("general_interface.tooltip_price", "resolved", {
            fn = "GetInventoryPriceInfo",
            itemLink = itemLink,
            itemId = GetItemLinkItemId and GetItemLinkItemId(itemLink) or nil,
            bagId = bagId,
            slotIndex = slotIndex,
            stackCount = stackCount,
            storeStackCount = storeStackCount,
            lineCount = #lines,
            sources = sourceSummary,
            renderedSources = renderedSources,
        })
    else
        TraceTooltip("general_interface.tooltip_price", "skipped", {
            fn = "GetInventoryPriceInfo",
            reason = "missingItemLink",
            bagId = bagId,
            slotIndex = slotIndex,
        })
    end
    return lines
end

--- Resolves a BetterUI string id with an English fallback when the id has
--- not been declared in the loaded lang file.
---@param stringIdName string Global SI_BETTERUI_* identifier name
---@param fallback string English fallback text
---@return string text Localized text or fallback
local function GetLocalizedOrFallback(stringIdName, fallback)
    local stringId = rawget(_G, stringIdName)
    local text = stringId and GetString(stringId)
    if text and text ~= "" then
        return text
    end
    return fallback
end

--- Gets style and research status info strings.
function BETTERUI.GetInventoryTraitInfo(itemLink)
    local lines = {}
    if itemLink and itemLink ~= "" and BETTERUI.GetSetting("GeneralInterface", "showStyleTrait", false) then
        local traitString
        local colors = BETTERUI.CIM.CONST.COLORS
        local researchableText = GetLocalizedOrFallback("SI_BETTERUI_TOOLTIP_RESEARCHABLE", "Researchable")

        local function BuildFoundLine(foundStringIdName, foundFallback)
            return "|c" .. colors.RESEARCHABLE .. researchableText .. "|r - |c" .. colors.FOUND_LOCATION
                .. GetLocalizedOrFallback(foundStringIdName, foundFallback) .. "|r"
        end

        if (CanItemLinkBeTraitResearched(itemLink)) then
            local houseBankTraitMatches = BETTERUI.CIM and BETTERUI.CIM.Utils
                and BETTERUI.CIM.Utils.GetHouseBankTraitMatches or nil
            local houseBankMatches = 0
            if type(houseBankTraitMatches) == "function" then
                local ok, count = pcall(houseBankTraitMatches, itemLink)
                houseBankMatches = ok and tonumber(count) or 0
                if not ok then
                    TraceTooltip("general_interface.tooltip_trait", "house_bank_lookup_failed", {
                        fn = "GetInventoryTraitInfo",
                        itemLink = itemLink,
                        error = tostring(count),
                    })
                end
            end
            -- Find owned items that can be researchable
            if (BETTERUI.GeneralInterface.GetCachedResearchableTraitMatches(itemLink, BAG_BACKPACK) > 0) then
                traitString = BuildFoundLine("SI_BETTERUI_TOOLTIP_FOUND_IN_INVENTORY", "Found in Inventory")
            elseif (BETTERUI.GeneralInterface.GetCachedResearchableTraitMatches(itemLink, BAG_BANK) + BETTERUI.GeneralInterface.GetCachedResearchableTraitMatches(itemLink, BAG_SUBSCRIBER_BANK) > 0) then
                traitString = BuildFoundLine("SI_BETTERUI_TOOLTIP_FOUND_IN_BANK", "Found in Bank")
            elseif houseBankMatches > 0 then
                traitString = BuildFoundLine("SI_BETTERUI_TOOLTIP_FOUND_IN_HOUSE_BANK", "Found in House Bank")
            elseif (BETTERUI.GeneralInterface.GetCachedResearchableTraitMatches(itemLink, BAG_WORN) > 0) then
                traitString = BuildFoundLine("SI_BETTERUI_TOOLTIP_FOUND_EQUIPPED", "Found Equipped")
            else
                traitString = "|c" .. colors.RESEARCHABLE .. researchableText .. "|r"
            end
        else
            TraceTooltip("general_interface.tooltip_trait", "skipped", {
                fn = "GetInventoryTraitInfo",
                reason = "notResearchable",
            })
            return lines
        end

        local style = GetItemLinkItemStyle(itemLink)
        -- Locale-safe: compare the numeric style id against ITEMSTYLE_NONE
        -- instead of matching a localized "NONE" string.
        local hasStyle = style ~= nil and style ~= (ITEMSTYLE_NONE or 0)
        -- U50: per-style SI_ITEMSTYLE strings were removed; GetItemStyleName is
        -- the supported lookup.
        local itemStyle = hasStyle and string.upper(GetItemStyleName(style) or "") or nil
        local traitLabel = GetLocalizedOrFallback("SI_BETTERUI_TOOLTIP_TRAIT_LABEL", "Trait:")

        if itemStyle and itemStyle ~= "" then
            table.insert(lines, zo_strformat("<<1>> <<2>> <<3>>", itemStyle, traitLabel, traitString))
        else
            table.insert(lines, zo_strformat("<<1>> <<2>>", traitLabel, traitString))
        end
        TraceTooltip("general_interface.tooltip_trait", "resolved", {
            fn = "GetInventoryTraitInfo",
            lineCount = #lines,
            hasStyle = hasStyle,
            style = style,
            traitStringPresent = traitString ~= nil,
        })
    else
        TraceTooltip("general_interface.tooltip_trait", "skipped", {
            fn = "GetInventoryTraitInfo",
            reason = (not itemLink or itemLink == "") and "missingItemLink" or "settingDisabled",
        })
    end
    return lines
end

--- Gets knowledge status for learnable items (recipes, motifs/lore books).
--- Returns a single colored status line: "Not Known" (green) or "Already Known" (grey).
--- Covers ITEMTYPE_RECIPE (provisioning) and any lore book / motif chapter.
function BETTERUI.GetInventoryKnowledgeInfo(itemLink)
    local lines = {}
    if not itemLink or itemLink == "" then
        TraceTooltip("general_interface.tooltip_knowledge", "skipped", {
            fn = "GetInventoryKnowledgeInfo",
            reason = "missingItemLink",
        })
        return lines
    end

    -- Respect the user's setting (default true when not set)
    if BETTERUI.GetSetting("GeneralInterface", "showKnowledgeStatus", true) == false then
        TraceTooltip("general_interface.tooltip_knowledge", "skipped", {
            fn = "GetInventoryKnowledgeInfo",
            reason = "settingDisabled",
        })
        return lines
    end

    local colors = BETTERUI.CIM.CONST.COLORS
    local icons  = BETTERUI.CIM.CONST.ICONS
    local fontSize = Tooltips.GetTooltipFontSize()
    local iconSize = math.floor(fontSize * 1.0)
    local iconSizeFmt = iconSize .. ":" .. iconSize

    local itemType = GetItemLinkItemType(itemLink)

    -- A. Provisioning recipe
    if itemType == ITEMTYPE_RECIPE then
        local icon = icons.RECIPE_UNKNOWN and ("|t" .. iconSizeFmt .. ":" .. icons.RECIPE_UNKNOWN .. "|t ") or ""
        if not IsItemLinkRecipeKnown then
            -- API not available in this context; skip rather than show wrong state
            TraceTooltip("general_interface.tooltip_knowledge", "skipped", {
                fn = "GetInventoryKnowledgeInfo",
                reason = "missingRecipeKnownApi",
                itemType = itemType,
            })
            return lines
        end
        if IsItemLinkRecipeKnown(itemLink) then
            table.insert(lines, icon .. "|cAAAAAA" .. GetString(rawget(_G, "SI_RECIPE_ALREADY_KNOWN")) .. "|r")
        else
            table.insert(lines, icon .. "|c" .. colors.RESEARCHABLE .. GetString(rawget(_G, "SI_USE_TO_LEARN_RECIPE")) .. "|r")
        end
        TraceTooltip("general_interface.tooltip_knowledge", "resolved", {
            fn = "GetInventoryKnowledgeInfo",
            itemType = itemType,
            kind = "recipe",
            known = IsItemLinkRecipeKnown(itemLink) == true,
            lineCount = #lines,
        })
        return lines
    end

    -- B. Lore books and motif chapters (both use IsItemLinkBookKnown / IsItemLinkBookPartOfCollection)
    if IsItemLinkBookPartOfCollection and IsItemLinkBookPartOfCollection(itemLink) then
        local icon = icons.BOOK_UNKNOWN and ("|t" .. iconSizeFmt .. ":" .. icons.BOOK_UNKNOWN .. "|t ") or ""
        -- IsItemLinkBookKnown may not be available in all addon contexts
        if not IsItemLinkBookKnown then
            TraceTooltip("general_interface.tooltip_knowledge", "skipped", {
                fn = "GetInventoryKnowledgeInfo",
                reason = "missingBookKnownApi",
                itemType = itemType,
            })
            return lines
        end
        if IsItemLinkBookKnown(itemLink) then
            table.insert(lines, icon .. "|cAAAAAA" .. GetString(rawget(_G, "SI_LORE_LIBRARY_IN_LIBRARY")) .. "|r")
        else
            table.insert(lines, icon .. "|c" .. colors.RESEARCHABLE .. GetString(rawget(_G, "SI_LORE_LIBRARY_USE_TO_LEARN")) .. "|r")
        end
        TraceTooltip("general_interface.tooltip_knowledge", "resolved", {
            fn = "GetInventoryKnowledgeInfo",
            itemType = itemType,
            kind = "book",
            known = IsItemLinkBookKnown(itemLink) == true,
            lineCount = #lines,
        })
        return lines
    end

    TraceTooltip("general_interface.tooltip_knowledge", "skipped", {
        fn = "GetInventoryKnowledgeInfo",
        reason = "unsupportedItemType",
        itemType = itemType,
    })
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

--- Shared scene-gate accessor. The rendering side (LayoutItem / equipped-text
--- hooks) and the top-line suppression hook in Setup.lua MUST consult the same
--- predicate so suppression can never fire in a context where BetterUI's
--- enhancement does not render (which would strip native top-lines — e.g. the
--- set-collection Collected/Uncollected line — and block other addons' hooks).
Tooltips.IsIncompatibleSceneActive = IsIncompatibleSceneActive

local function IsLikelyItemLink(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then
        return false
    end
    return itemLink:find("|H", 1, true) ~= nil or itemLink:find("item:", 1, true) == 1
end

local function DoesBagContextMatchItemLink(bagId, slotIndex, itemLink)
    if bagId == nil or slotIndex == nil or itemLink == nil then
        return false, nil
    end
    if type(GetItemLink) ~= "function" then
        return true, nil
    end
    local ok, bagItemLink = pcall(GetItemLink, bagId, slotIndex)
    if not ok then
        TraceTooltip("general_interface.tooltip_context", "bag_link_failed", {
            fn = "DoesBagContextMatchItemLink",
            bagId = bagId,
            slotIndex = slotIndex,
            itemLink = itemLink,
            error = tostring(bagItemLink),
        })
    end
    return ok and bagItemLink ~= nil and bagItemLink ~= "" and bagItemLink == itemLink, ok and bagItemLink or nil
end

local function CreateInventoryHookState()
    return {
        installedHooks = {},
        bagId = nil,
        slotIndex = nil,
        storeItemLink = nil,
        storeStackCount = nil,
        skipEnhancementForLayout = false,
        pendingItemLink = nil,
        pendingTooltipType = nil,
        clearLinesHookInstalled = false,
    }
end

local function ResetInventoryHookState(state)
    state.bagId = nil
    state.slotIndex = nil
    state.storeItemLink = nil
    state.storeStackCount = nil
    state.pendingItemLink = nil
    state.pendingTooltipType = nil
end

local function EnsureInventoryHookState(tooltipControl)
    tooltipControl._betteruiInventoryHookState = tooltipControl._betteruiInventoryHookState or CreateInventoryHookState()
    return tooltipControl._betteruiInventoryHookState
end

local function ResolveHookBagContext(layoutBagDataFn, ...)
    if type(layoutBagDataFn) ~= "function" then
        return nil, nil
    end

    local ok, result = BETTERUI.CIM.SafeExecute("Tooltips:InventoryHook:path-recovery", function(...)
        return { layoutBagDataFn(...) }
    end, ...)
    if ok and result then
        return result[1], result[2]
    end
    TraceTooltip("general_interface.tooltip_context", "path_recovery_failed", {
        fn = "ResolveHookBagContext",
        path = "layoutBagDataFn",
        error = ok and "missingResult" or tostring(result),
    })
    return nil, nil
end

local function ResolveHookStoreContext(layoutStoreDataFn, ...)
    if type(layoutStoreDataFn) ~= "function" then
        return nil, nil
    end

    local ok, result = BETTERUI.CIM.SafeExecute("Tooltips:InventoryHook:store-link", function(...)
        return { layoutStoreDataFn(...) }
    end, ...)
    if ok and result then
        return result[1], result[2]
    end
    TraceTooltip("general_interface.tooltip_context", "path_recovery_failed", {
        fn = "ResolveHookStoreContext",
        path = "layoutStoreDataFn",
        error = ok and "missingResult" or tostring(result),
    })
    return nil, nil
end

local function ResolveHookItemLink(state, layoutItemDataFn, ...)
    if state.storeItemLink then
        return state.storeItemLink
    end
    if type(layoutItemDataFn) ~= "function" then
        return nil
    end

    local ok, result = BETTERUI.CIM.SafeExecute("Tooltips:InventoryHook:link-extraction", function(...)
        return layoutItemDataFn(...)
    end, ...)
    return ok and result or nil
end

local function CaptureBagLayoutState(state, layoutBagDataFn, ...)
    state.bagId, state.slotIndex = ResolveHookBagContext(layoutBagDataFn, ...)
    state.storeItemLink = nil
    state.storeStackCount = nil
end

local function CaptureStoreLayoutState(state, layoutStoreDataFn, ...)
    state.storeItemLink, state.storeStackCount = ResolveHookStoreContext(layoutStoreDataFn, ...)
    state.bagId = nil
    state.slotIndex = nil
end

local function CaptureTooltipLayoutState(tooltipControl, state, itemLink)
    local effectiveStoreStackCount = state.storeStackCount
    if effectiveStoreStackCount == nil and state.bagId == nil and state.slotIndex == nil then
        effectiveStoreStackCount = tooltipControl._betterui_storeStackCount
    end

    tooltipControl._betterui_itemLink = itemLink
    tooltipControl._betterui_bagId = state.bagId
    tooltipControl._betterui_slotIndex = state.slotIndex
    tooltipControl._betterui_storeStackCount = effectiveStoreStackCount
    tooltipControl._betterui_priceRendered = false
end

local function ApplyTooltipLabelFonts(tooltipControl)
    local fontSize = Tooltips.GetTooltipFontSize()
    local fontStr = "$(MEDIUM_FONT)|" .. fontSize .. "|soft-shadow-thick"
    for i = 1, tooltipControl:GetNumChildren() do
        local child = tooltipControl:GetChild(i)
        if child and child:GetType() == CT_LABEL and not child:IsHidden() then
            child:SetFont(fontStr)
        end
    end
end

local function RestoreTooltipLabelFonts(tooltipControl)
    for i = 1, tooltipControl:GetNumChildren() do
        local child = tooltipControl:GetChild(i)
        if child and child:GetType() == CT_LABEL and not child:IsHidden() then
            child:SetFont(STOCK_TOOLTIP_BODY_FONT)
        end
    end
end

--- Pattern checks memoized per label control: tooltip labels are pooled and
--- re-scanned on every layout, so only re-run the gsub/find work when the
--- label text actually changed since the last scan.
---@param label table Label control
---@param text string Current label text (non-nil)
---@return boolean isDuplicate Whether the text is a duplicate addon line
local function IsDuplicateAddonLabelText(label, text)
    if label._betterui_dupCheckText == text then
        return label._betterui_dupCheckResult
    end
    local plainText = text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
    local isDuplicateAddonLine = (plainText:find("^TTC:") ~= nil)
        or (plainText:find("^Tamriel Trade Centre") ~= nil)
        or (plainText:find("^M%.M%.") ~= nil)
        or (plainText:find("^Master Merchant") ~= nil)
        or (plainText:find("^ATT:") ~= nil)
        or (plainText:find("^Arkadius' Trade Tools") ~= nil)
    label._betterui_dupCheckText = text
    label._betterui_dupCheckResult = isDuplicateAddonLine
    return isDuplicateAddonLine
end

local function HideDuplicateAddonLabels(control)
    for i = 1, control:GetNumChildren() do
        local child = control:GetChild(i)
        if child then
            if child:GetType() == CT_LABEL and not child:IsHidden() then
                local text = child:GetText()
                if text then
                    if IsDuplicateAddonLabelText(child, text) then
                        child:SetHidden(true)
                        if i > 1 then
                            local prevChild = control:GetChild(i - 1)
                            if prevChild and prevChild:GetType() == CT_TEXTURE then
                                prevChild:SetHidden(true)
                            end
                        end
                    end
                end
            end
            if child:GetNumChildren() > 0 then
                HideDuplicateAddonLabels(child)
            end
        end
    end
end

local function ScheduleTooltipEquippedRefresh(tooltipControl, itemLink, tooltipType)
    if not itemLink then
        return
    end

    local normalizedTooltipType = tonumber(tooltipType) or tooltipType
    if normalizedTooltipType == nil then
        TraceTooltip("general_interface.tooltip_refresh", "skipped", {
            fn = "ScheduleTooltipEquippedRefresh",
            reason = "invalidTooltipType",
            itemLink = itemLink,
            tooltipType = tooltipType,
        })
        return
    end

    local tooltipRef = tooltipControl
    local capturedItemLink = itemLink
    if tooltipControl and tooltipControl._betteruiPendingEquippedRefreshId and zo_removeCallLater then
        zo_removeCallLater(tooltipControl._betteruiPendingEquippedRefreshId)
        TraceTooltip("general_interface.tooltip_refresh", "coalesced", {
            fn = "ScheduleTooltipEquippedRefresh",
            itemLink = itemLink,
            tooltipType = normalizedTooltipType,
        })
    end
    TraceTooltip("general_interface.tooltip_refresh", "scheduled", {
        fn = "ScheduleTooltipEquippedRefresh",
        itemLink = itemLink,
        tooltipType = normalizedTooltipType,
        delayMs = 1,
    })
    local callId = zo_callLater(function()
        if tooltipRef then tooltipRef._betteruiPendingEquippedRefreshId = nil end
        local visibleOk, hidden = tooltipRef and pcall(function() return tooltipRef:IsHidden() end)
        if not tooltipRef or not visibleOk or hidden then
            TraceTooltip("general_interface.tooltip_refresh", "aborted", {
                fn = "ScheduleTooltipEquippedRefresh.task",
                reason = (not tooltipRef or not visibleOk) and "controlInvalid" or "hidden",
                itemLink = capturedItemLink,
                tooltipType = normalizedTooltipType,
                error = visibleOk == false and tostring(hidden) or nil,
            })
            return
        end
        if tooltipRef._betterui_priceRendered then
            TraceTooltip("general_interface.tooltip_refresh", "aborted", {
                fn = "ScheduleTooltipEquippedRefresh.task",
                reason = "priceRendered",
                itemLink = capturedItemLink,
                tooltipType = normalizedTooltipType,
            })
            return
        end
        if IsIncompatibleSceneActive() then
            TraceTooltip("general_interface.tooltip_refresh", "aborted", {
                fn = "ScheduleTooltipEquippedRefresh.task",
                reason = "sceneIncompatible",
                itemLink = capturedItemLink,
                tooltipType = normalizedTooltipType,
            })
            return
        end
        if tooltipRef._betterui_itemLink ~= capturedItemLink then
            TraceTooltip("general_interface.tooltip_refresh", "aborted", {
                fn = "ScheduleTooltipEquippedRefresh.task",
                reason = "linkMismatch",
                itemLink = capturedItemLink,
                currentItemLink = tooltipRef._betterui_itemLink,
                tooltipType = normalizedTooltipType,
            })
            return
        end

        if BETTERUI.CIM.SharedItemSupport and type(BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText) == "function" then
            BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText(normalizedTooltipType, nil)
            MarkTooltipContentAppended(tooltipRef, "pricing/equipped", "ScheduleTooltipEquippedRefresh.task", normalizedTooltipType)
            TraceTooltip("general_interface.tooltip_refresh", "updated", {
                fn = "ScheduleTooltipEquippedRefresh.task",
                itemLink = capturedItemLink,
                tooltipType = normalizedTooltipType,
            })
        else
            TraceTooltip("general_interface.tooltip_refresh", "aborted", {
                fn = "ScheduleTooltipEquippedRefresh.task",
                reason = "missingSharedItemSupport",
                itemLink = capturedItemLink,
                tooltipType = normalizedTooltipType,
            })
        end
    end, 1)
    if tooltipControl then tooltipControl._betteruiPendingEquippedRefreshId = callId end
end

local function ScheduleDuplicateAddonCleanup(tooltipControl)
    local tooltipRef = tooltipControl
    if tooltipControl and tooltipControl._betteruiPendingDuplicateCleanupId and zo_removeCallLater then
        zo_removeCallLater(tooltipControl._betteruiPendingDuplicateCleanupId)
        TraceTooltip("general_interface.tooltip_cleanup", "coalesced", { fn = "ScheduleDuplicateAddonCleanup" })
    end
    TraceTooltip("general_interface.tooltip_cleanup", "scheduled", {
        fn = "ScheduleDuplicateAddonCleanup",
        delayMs = 2,
    })
    local callId = zo_callLater(function()
        if tooltipRef then tooltipRef._betteruiPendingDuplicateCleanupId = nil end
        local visibleOk, hidden = tooltipRef and pcall(function() return tooltipRef:IsHidden() end)
        if not tooltipRef or not visibleOk or hidden then
            TraceTooltip("general_interface.tooltip_cleanup", "aborted", {
                fn = "ScheduleDuplicateAddonCleanup.task",
                reason = (not tooltipRef or not visibleOk) and "controlInvalid" or "hidden",
                error = visibleOk == false and tostring(hidden) or nil,
            })
            return
        end
        if IsIncompatibleSceneActive() then
            TraceTooltip("general_interface.tooltip_cleanup", "aborted", {
                fn = "ScheduleDuplicateAddonCleanup.task",
                reason = "sceneIncompatible",
            })
            return
        end
        HideDuplicateAddonLabels(tooltipRef)
        TraceTooltip("general_interface.tooltip_cleanup", "complete", {
            fn = "ScheduleDuplicateAddonCleanup.task",
        })
    end, 2)
    if tooltipControl then tooltipControl._betteruiPendingDuplicateCleanupId = callId end
end

local function IsControlVisible(control)
    if not control then
        return false
    end
    if type(control.IsHidden) ~= "function" then
        return true
    end
    local ok, hidden = pcall(control.IsHidden, control)
    return ok and hidden == false
end

local function GetTooltipContainer(tooltipType)
    if not (tooltipType and GAMEPAD_TOOLTIPS and GAMEPAD_TOOLTIPS.GetTooltipContainer) then
        return nil
    end
    local ok, container = pcall(function()
        return GAMEPAD_TOOLTIPS:GetTooltipContainer(tooltipType)
    end)
    return ok and container or nil
end

local function HasEnhancedTooltipControls(tooltipType)
    local container = GetTooltipContainer(tooltipType)
    if not container then
        return false
    end
    return container._betterUiStatusOwned == true
        or IsControlVisible(container._betterUiStatus)
        or IsControlVisible(container._betterUiComparison)
end

local function ResolveEquippedTooltipSlot(itemLink, bagId, slotIndex)
    local wornBagId = rawget(_G, "BAG_WORN")
    if wornBagId == nil or slotIndex == nil then
        return nil
    end
    if bagId == wornBagId then
        return slotIndex
    end
    if itemLink and type(GetItemLink) == "function" then
        local ok, equippedLink = pcall(GetItemLink, wornBagId, slotIndex)
        if ok and equippedLink == itemLink then
            return slotIndex
        end
    end
    return nil
end

--- Applies BetterUI's stock-mode additions during the LayoutItem post-hook.
--- This keeps native tooltip content stable: no delayed task mutates a tooltip
--- that ESOUI has already made visible.
local function ApplyTooltipEquippedStockLayout(tooltipControl, tooltipType, itemLink, bagId, slotIndex, storeStackCount)
    local normalizedTooltipType = tonumber(tooltipType) or tooltipType
    if normalizedTooltipType == nil then
        TraceTooltip("general_interface.tooltip_stock_relayout", "skipped", {
            fn = "ApplyTooltipEquippedStockLayout",
            reason = "invalidTooltipType",
            tooltipType = tooltipType,
        })
        return
    end

    local tooltipRef = tooltipControl
    local visibleOk, hidden = tooltipRef and pcall(function() return tooltipRef:IsHidden() end)
    if not tooltipRef or not visibleOk or hidden then
        TraceTooltip("general_interface.tooltip_stock_relayout", "aborted", {
            fn = "ApplyTooltipEquippedStockLayout",
            reason = (not tooltipRef or not visibleOk) and "controlInvalid" or "hidden",
            tooltipType = normalizedTooltipType,
            error = visibleOk == false and tostring(hidden) or nil,
        })
        return
    end
    if IsIncompatibleSceneActive() then
        TraceTooltip("general_interface.tooltip_stock_relayout", "aborted", {
            fn = "ApplyTooltipEquippedStockLayout",
            reason = "sceneIncompatible",
            tooltipType = normalizedTooltipType,
        })
        return
    end

    if BETTERUI.CIM.SharedItemSupport then
        local cleaned = false
        local hasEnhancedControls = HasEnhancedTooltipControls(normalizedTooltipType)
        if type(BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip) == "function"
            and hasEnhancedControls
            and not (tooltipRef and tooltipRef._betteruiStockCleanupApplied) then
            TraceTooltipContentCleared(tooltipRef, tooltipType, "ApplyTooltipEquippedStockLayout", true)
            cleaned = BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip(tooltipType, true) == true
            if tooltipRef then
                tooltipRef._betteruiStockCleanupApplied = true
            end
        end
        if tooltipRef and itemLink then
            tooltipRef._betterui_itemLink = itemLink
            tooltipRef._betterui_bagId = bagId
            tooltipRef._betterui_slotIndex = slotIndex
            tooltipRef._betterui_storeStackCount = storeStackCount
            tooltipRef._betterui_priceRendered = false
        end

        local equipSlot = ResolveEquippedTooltipSlot(itemLink, bagId, slotIndex)
        local updated = type(BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText) == "function"
        if updated then
            BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText(normalizedTooltipType, equipSlot)
            MarkTooltipContentAppended(tooltipRef, "equipped-stock", "ApplyTooltipEquippedStockLayout", normalizedTooltipType)
        end
        TraceTooltip("general_interface.tooltip_stock_relayout", "updated", {
            fn = "ApplyTooltipEquippedStockLayout",
            tooltipType = normalizedTooltipType,
            cleaned = cleaned,
            hasEnhancedControls = hasEnhancedControls,
            equipSlot = equipSlot,
            nativeTopAreaPreserved = true,
            stockFallbackRefreshed = updated,
        })
    else
        TraceTooltip("general_interface.tooltip_stock_relayout", "aborted", {
            fn = "ApplyTooltipEquippedStockLayout",
            reason = "missingSharedItemSupport",
            tooltipType = normalizedTooltipType,
        })
    end
end

local function ClearTooltipEnhancementState(tooltipControl, tooltipType, preserveItemData, clearedBy)
    TraceTooltipContentCleared(tooltipControl, tooltipType, clearedBy or "ClearTooltipEnhancementState", preserveItemData)
    if tooltipControl and not preserveItemData then
        tooltipControl._betterui_itemLink = nil
        tooltipControl._betterui_bagId = nil
        tooltipControl._betterui_slotIndex = nil
        tooltipControl._betterui_storeStackCount = nil
        tooltipControl._betterui_priceRendered = nil
    end

    local enhancementsEnabled = BETTERUI.GetSetting("CIM", "enableTooltipEnhancements", true) ~= false
    local canCleanupSharedSupport = enhancementsEnabled or HasEnhancedTooltipControls(tooltipType)
    if canCleanupSharedSupport and tooltipType and BETTERUI.CIM.SharedItemSupport and type(BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip) == "function" then
        BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip(tooltipType, preserveItemData == true)
    end
    TraceTooltip("general_interface.tooltip_state", "cleared", {
        fn = "ClearTooltipEnhancementState",
        tooltipType = tooltipType,
        hasTooltipControl = tooltipControl ~= nil,
        cleanedSharedSupport = canCleanupSharedSupport and tooltipType and BETTERUI.CIM.SharedItemSupport and type(BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip) == "function" or false,
    })
end

local function InstallClearLinesHook(tooltipControl, state, tooltipType)
    if not tooltipControl.ClearLines or state.clearLinesHookInstalled then
        return
    end

    ZO_PostHook(tooltipControl, "ClearLines", function(self, ...)
        -- pendingItemLink is only a pre->post layout handoff (nil between
        -- layouts), so the periodic native ClearLines while IDLING on an item
        -- always saw nil and stripped stock content just to re-append it next
        -- layout (the clear-after-append WARN storm). The control's seeded
        -- _betterui_itemLink is the persistent displayed-item truth. Preserve
        -- that displayed-item metadata in both stock and enhanced layouts;
        -- non-item layouts clear it before their later ClearLines pass.
        local hasDisplayedItem = state.pendingItemLink ~= nil or self._betterui_itemLink ~= nil
        local preserveStockLayoutState = hasDisplayedItem
        ClearTooltipEnhancementState(self, tooltipType, preserveStockLayoutState, "ClearLines")
        if not preserveStockLayoutState then
            ResetInventoryHookState(state)
        end
        TraceTooltip("general_interface.tooltip_state", "clear_lines", {
            fn = "ClearLines",
            tooltipType = tooltipType,
        })
    end)
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "raw hook installed", { method = "ClearLines", target = type(tooltipControl) }) end
    state.clearLinesHookInstalled = true
end

local function InstallBagLayoutHook(tooltipControl, layoutBagName, state, tooltipType, layoutBagDataFn)
    ZO_PreHook(tooltipControl, layoutBagName, function(self, ...)
        if IsIncompatibleSceneActive() then
            state.skipEnhancementForLayout = true
            ClearTooltipEnhancementState(self, tooltipType, false, tostring(layoutBagName))
            ResetInventoryHookState(state)
            TraceTooltip("general_interface.tooltip_hook", "bag_layout_skipped", {
                fn = tostring(layoutBagName),
                reason = "sceneIncompatible",
                tooltipType = tooltipType,
            })
            return
        end

        CaptureBagLayoutState(state, layoutBagDataFn, ...)
        TraceTooltip("general_interface.tooltip_hook", "bag_layout_captured", {
            fn = tostring(layoutBagName),
            tooltipType = tooltipType,
            bagId = state.bagId,
            slotIndex = state.slotIndex,
        })
    end)
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "raw hook installed", { method = tostring(layoutBagName), target = type(tooltipControl) }) end
end

local function InstallStoreLayoutHook(tooltipControl, layoutStoreName, state, tooltipType, layoutStoreDataFn)
    ZO_PreHook(tooltipControl, layoutStoreName, function(self, ...)
        if IsIncompatibleSceneActive() then
            state.skipEnhancementForLayout = true
            ClearTooltipEnhancementState(self, tooltipType, false, tostring(layoutStoreName))
            ResetInventoryHookState(state)
            TraceTooltip("general_interface.tooltip_hook", "store_layout_skipped", {
                fn = tostring(layoutStoreName),
                reason = "sceneIncompatible",
                tooltipType = tooltipType,
            })
            return
        end

        CaptureStoreLayoutState(state, layoutStoreDataFn, ...)
        TraceTooltip("general_interface.tooltip_hook", "store_layout_captured", {
            fn = tostring(layoutStoreName),
            tooltipType = tooltipType,
            hasItemLink = state.storeItemLink ~= nil,
            storeStackCount = state.storeStackCount,
        })
    end)
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "raw hook installed", { method = tostring(layoutStoreName), target = type(tooltipControl) }) end
end

local function InstallItemLayoutHooks(tooltipControl, layoutItemName, state, tooltipType, layoutItemDataFn)
    ZO_PreHook(tooltipControl, layoutItemName, function(self, ...)
        TraceTooltip("general_interface.tooltip_hook", "item_layout_begin", {
            fn = tostring(layoutItemName),
            tooltipType = tooltipType,
            bagId = state.bagId,
            slotIndex = state.slotIndex,
            hasStoreItemLink = state.storeItemLink ~= nil,
            storeStackCount = state.storeStackCount,
        })
        state.skipEnhancementForLayout = IsIncompatibleSceneActive()
        state.pendingItemLink = nil
        state.pendingTooltipType = nil

        if state.skipEnhancementForLayout then
            ClearTooltipEnhancementState(self, tooltipType, false, tostring(layoutItemName))
            TraceTooltip("general_interface.tooltip_hook", "item_layout_skipped", {
                fn = tostring(layoutItemName),
                reason = "sceneIncompatible",
                tooltipType = tooltipType,
            })
            return
        end

        local itemLink = ResolveHookItemLink(state, layoutItemDataFn, ...)

        local bagContextMatches, bagItemLink = DoesBagContextMatchItemLink(state.bagId, state.slotIndex, itemLink)
        if state.bagId ~= nil and state.slotIndex ~= nil
            and not bagContextMatches then
            TraceTooltip("general_interface.tooltip_hook", "bag_context_cleared", {
                fn = tostring(layoutItemName),
                tooltipType = tooltipType,
                bagId = state.bagId,
                slotIndex = state.slotIndex,
                hasItemLink = itemLink ~= nil,
                itemLink = itemLink,
                bagItemLink = bagItemLink,
            })
            state.bagId = nil
            state.slotIndex = nil
        end

        if not IsLikelyItemLink(itemLink) then
            state.skipEnhancementForLayout = true
            ClearTooltipEnhancementState(self, tooltipType, false, tostring(layoutItemName))
            TraceTooltip("general_interface.tooltip_hook", "item_layout_skipped", {
                fn = tostring(layoutItemName),
                reason = "notItemLink",
                tooltipType = tooltipType,
                itemLinkType = type(itemLink),
            })
            return
        end

        CaptureTooltipLayoutState(self, state, itemLink)
        state.storeItemLink = nil
        state.storeStackCount = nil
        state.pendingItemLink = itemLink
        state.pendingTooltipType = tooltipType
        TraceTooltip("general_interface.tooltip_hook", "item_layout_captured", {
            fn = tostring(layoutItemName),
            tooltipType = tooltipType,
            bagId = state.bagId,
            slotIndex = state.slotIndex,
            hasItemLink = itemLink ~= nil,
            storeStackCount = tooltipControl._betterui_storeStackCount,
        })
    end)
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "raw hook installed", { method = tostring(layoutItemName), target = type(tooltipControl) }) end

    ZO_PostHook(tooltipControl, layoutItemName, function(self, ...)
        local itemLink = state.pendingItemLink
        local capturedTooltipType = state.pendingTooltipType
        state.pendingItemLink = nil
        state.pendingTooltipType = nil

        if state.skipEnhancementForLayout then
            state.skipEnhancementForLayout = false
            TraceTooltip("general_interface.tooltip_hook", "item_layout_end_skipped", {
                fn = tostring(layoutItemName),
                reason = "skipEnhancementForLayout",
                tooltipType = capturedTooltipType,
            })
            return
        end

        local enhancementsEnabled = BETTERUI.GetSetting("CIM", "enableTooltipEnhancements", true) ~= false

        -- Gate enhanced per-label fonts + equipped-header refresh on the setting.
        -- When enhancements are toggled OFF, re-applying enhanced fonts/anchors on
        -- the next layout would re-introduce the styling the user just disabled
        -- (PB-003). Stock-mode additions run synchronously here so the
        -- visible tooltip does not jitter after ESOUI lays it out.
        if enhancementsEnabled then
            self._betteruiStockCleanupApplied = nil
            ApplyTooltipLabelFonts(self)
            ScheduleTooltipEquippedRefresh(self, itemLink, capturedTooltipType)
            ScheduleDuplicateAddonCleanup(self)
            TraceTooltip("general_interface.tooltip_hook", "item_layout_end", {
                fn = tostring(layoutItemName),
                tooltipType = capturedTooltipType,
                hasItemLink = itemLink ~= nil,
                enhancementsEnabled = true,
                scheduledRefresh = true,
                scheduledCleanup = true,
            })
        else
            RestoreTooltipLabelFonts(self)
            ApplyTooltipEquippedStockLayout(
                self,
                capturedTooltipType,
                itemLink,
                state.bagId or self._betterui_bagId,
                state.slotIndex or self._betterui_slotIndex,
                state.storeStackCount or self._betterui_storeStackCount
            )
            TraceTooltip("general_interface.tooltip_hook", "item_layout_end", {
                fn = tostring(layoutItemName),
                tooltipType = capturedTooltipType,
                hasItemLink = itemLink ~= nil,
                enhancementsEnabled = false,
                appliedStockLayout = true,
            })
        end
    end)
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "raw hook installed", { method = tostring(layoutItemName), target = type(tooltipControl) }) end
end

Tooltips.InventoryHookValidation = {
    IsLikelyItemLink = IsLikelyItemLink,
    DoesBagContextMatchItemLink = DoesBagContextMatchItemLink,
}

Tooltips.InventoryHookState = {
    Create = CreateInventoryHookState,
    Ensure = EnsureInventoryHookState,
    Reset = ResetInventoryHookState,
    ClearTooltipEnhancementState = ClearTooltipEnhancementState,
}

Tooltips.InventoryHookContext = {
    ResolveHookBagContext = ResolveHookBagContext,
    ResolveHookStoreContext = ResolveHookStoreContext,
    ResolveHookItemLink = ResolveHookItemLink,
    CaptureBagLayoutState = CaptureBagLayoutState,
    CaptureStoreLayoutState = CaptureStoreLayoutState,
    CaptureTooltipLayoutState = CaptureTooltipLayoutState,
}

Tooltips.InventoryHookOrchestrator = {
    InstallClearLinesHook = InstallClearLinesHook,
    InstallBagLayoutHook = InstallBagLayoutHook,
    InstallStoreLayoutHook = InstallStoreLayoutHook,
    InstallItemLayoutHooks = InstallItemLayoutHooks,
}

Tooltips._InventoryHookHelpers = {
    CreateInventoryHookState = CreateInventoryHookState,
    EnsureInventoryHookState = EnsureInventoryHookState,
    ResetInventoryHookState = ResetInventoryHookState,
    ResolveHookBagContext = ResolveHookBagContext,
    ResolveHookStoreContext = ResolveHookStoreContext,
    ResolveHookItemLink = ResolveHookItemLink,
    CaptureBagLayoutState = CaptureBagLayoutState,
    CaptureStoreLayoutState = CaptureStoreLayoutState,
    CaptureTooltipLayoutState = CaptureTooltipLayoutState,
    ApplyTooltipLabelFonts = ApplyTooltipLabelFonts,
    HideDuplicateAddonLabels = HideDuplicateAddonLabels,
    ScheduleTooltipEquippedRefresh = ScheduleTooltipEquippedRefresh,
    ScheduleDuplicateAddonCleanup = ScheduleDuplicateAddonCleanup,
    InstallClearLinesHook = InstallClearLinesHook,
    InstallBagLayoutHook = InstallBagLayoutHook,
    InstallStoreLayoutHook = InstallStoreLayoutHook,
    InstallItemLayoutHooks = InstallItemLayoutHooks,
    ClearTooltipEnhancementState = ClearTooltipEnhancementState,
}


function Tooltips.CreateInventoryHookConfig(tooltipControl, tooltipType)
    return {
        tooltipControl = tooltipControl,
        tooltipType = tooltipType,
        method = "LayoutItem",
        linkFunc = Tooltips.ReturnItemLink,
        method2 = "LayoutBagItem",
        linkFunc2 = Tooltips.ReturnSelectedData,
        method3 = "LayoutGuildStoreSearchResult",
        linkFunc3 = Tooltips.ReturnStoreSearch,
    }
end

function Tooltips.InventoryHook(config)
    if type(config) ~= "table" or not config.tooltipControl then
        TraceTooltip("general_interface.tooltip_hook", "install_skipped", {
            fn = "Tooltips.InventoryHook",
            reason = type(config) ~= "table" and "invalidConfig" or "missingTooltipControl",
        })
        return
    end

    local tooltipControl = config.tooltipControl
    local tooltipType = config.tooltipType
    local layoutItemName = config.method or "LayoutItem"
    local layoutItemDataFn = config.linkFunc
    local layoutBagName = config.method2 or "LayoutBagItem"
    local layoutBagDataFn = config.linkFunc2
    local layoutStoreName = config.method3 or "LayoutGuildStoreSearchResult"
    local layoutStoreDataFn = config.linkFunc3

    if not (tooltipControl and (layoutItemName or layoutBagName or layoutStoreName)) then
        TraceTooltip("general_interface.tooltip_hook", "install_skipped", {
            fn = "Tooltips.InventoryHook",
            reason = "missingLayoutNames",
            tooltipType = tooltipType,
        })
        return
    end

    if type(ZO_PreHook) ~= "function" or type(ZO_PostHook) ~= "function" then
        TraceTooltip("general_interface.tooltip_hook", "install_skipped", {
            fn = "Tooltips.InventoryHook",
            reason = "missingHookApi",
            tooltipType = tooltipType,
            hasPreHook = type(ZO_PreHook) == "function",
            hasPostHook = type(ZO_PostHook) == "function",
        })
        return
    end
    local hasItemLayout = layoutItemName and tooltipControl[layoutItemName] ~= nil
    local hasBagLayout = layoutBagName and tooltipControl[layoutBagName] ~= nil
    local hasStoreLayout = layoutStoreName and tooltipControl[layoutStoreName] ~= nil
    if not (hasItemLayout or hasBagLayout or hasStoreLayout) then
        TraceTooltip("general_interface.tooltip_hook", "install_skipped", {
            fn = "Tooltips.InventoryHook",
            reason = "missingTooltipMethods",
            tooltipType = tooltipType,
            layoutItemName = layoutItemName,
            layoutBagName = layoutBagName,
            layoutStoreName = layoutStoreName,
        })
        return
    end

    local stateHelpers = Tooltips.InventoryHookState
    local hookRuntime = Tooltips.InventoryHookOrchestrator
    local state = stateHelpers.Ensure(tooltipControl)
    local hookKey = string.format("%s|%s|%s|%s",
        hasItemLayout and tostring(layoutItemName) or "-",
        hasBagLayout and tostring(layoutBagName) or "-",
        hasStoreLayout and tostring(layoutStoreName) or "-",
        tostring(tooltipType))
    if state.installedHooks[hookKey] then
        TraceTooltip("general_interface.tooltip_hook", "install_skipped", {
            fn = "Tooltips.InventoryHook",
            reason = "alreadyInstalled",
            tooltipType = tooltipType,
            hookKey = hookKey,
        })
        return
    end
    state.installedHooks[hookKey] = true

    hookRuntime.InstallClearLinesHook(tooltipControl, state, tooltipType)
    if hasBagLayout then
        hookRuntime.InstallBagLayoutHook(tooltipControl, layoutBagName, state, tooltipType, layoutBagDataFn)
    end
    if hasStoreLayout then
        hookRuntime.InstallStoreLayoutHook(tooltipControl, layoutStoreName, state, tooltipType, layoutStoreDataFn)
    end
    if hasItemLayout then
        hookRuntime.InstallItemLayoutHooks(tooltipControl, layoutItemName, state, tooltipType, layoutItemDataFn)
    end
    TraceTooltip("general_interface.tooltip_hook", "installed", {
        fn = "Tooltips.InventoryHook",
        tooltipType = tooltipType,
        hookKey = hookKey,
        hasItemLayout = hasItemLayout,
        hasBagLayout = hasBagLayout,
        hasStoreLayout = hasStoreLayout,
    })
end

-- Passthrough helpers for tooltip hook data extraction
function Tooltips.ReturnItemLink(itemLink)
    return itemLink
end

function Tooltips.ReturnSelectedData(bagId, slotIndex)
    return bagId, slotIndex
end

function Tooltips.ReturnStoreSearch(storeItemLink, storeStackCount)
    return storeItemLink, storeStackCount
end

BETTERUI.InventoryHook = Tooltips.InventoryHook
BETTERUI.ReturnItemLink = Tooltips.ReturnItemLink
BETTERUI.ReturnSelectedData = Tooltips.ReturnSelectedData
BETTERUI.ReturnStoreSearch = Tooltips.ReturnStoreSearch
