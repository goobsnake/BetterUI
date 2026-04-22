-- Enriches item tooltips with market pricing, research status, and font scaling.
-- Integrates with TTC, Master Merchant, and Arkadius Trade Tools.

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.GeneralInterface = BETTERUI.GeneralInterface or {}
local GeneralInterface = BETTERUI.GeneralInterface
GeneralInterface.Tooltips = GeneralInterface.Tooltips or {}

local Tooltips = GeneralInterface.Tooltips
local TooltipRuntime = Tooltips._runtime or {}
Tooltips._runtime = TooltipRuntime

local function SetGuildStoreErrorSuppressed(isSuppressed)
    TooltipRuntime.guildStoreErrorSuppressed = isSuppressed == true
    BETTERUI.CIM._gsErrorSuppress = TooltipRuntime.guildStoreErrorSuppressed and 1 or 0
end

Tooltips.SetGuildStoreErrorSuppressed = SetGuildStoreErrorSuppressed
Tooltips.GuildStoreSuppression = {
    SetErrorSuppressed = SetGuildStoreErrorSuppressed,
}

function Tooltips.InitializeRuntime()
    if TooltipRuntime.initialized == true then
        return true
    end

    SetGuildStoreErrorSuppressed(TooltipRuntime.guildStoreErrorSuppressed == true)

    local cimUtils = BETTERUI.CIM and BETTERUI.CIM.Utils
    if cimUtils and type(cimUtils.RegisterResearchableTraitMatcher) == "function" then
        cimUtils.RegisterResearchableTraitMatcher(GeneralInterface.GetCachedResearchableTraitMatches)
    end

    TooltipRuntime.initialized = true
    return true
end

-- Trait research lookups iterate bag contents, so cache them per bag and
-- invalidate on targeted slot updates instead of rebuilding everything.
local ResearchableTraitCache = {}
local DEFAULT_FONT_SIZE = 24


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

function GeneralInterface.GetCachedResearchableTraitMatches(itemLink, bagId)
    if not itemLink or not bagId then return 0 end
    local traitType = GetItemLinkTraitInfo(itemLink)
    if not traitType or traitType == 0 then return 0 end
    if not ResearchableTraitCache[bagId] then
        BuildBagResearchCache(bagId)
    end
    return (ResearchableTraitCache[bagId] and ResearchableTraitCache[bagId][traitType]) or 0
end

function GeneralInterface.InvalidateResearchableTraitCache(bagId)
    if bagId then
        if ResearchableTraitCache and ResearchableTraitCache[bagId] then
            ResearchableTraitCache[bagId] = nil
        end
    else
        ResearchableTraitCache = {}
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
        local function GetSourceInfo(sourceKey)
            if not marketIntegration or type(marketIntegration.GetSourcePriceInfo) ~= "function" then
                return nil
            end
            return marketIntegration.GetSourcePriceInfo(sourceKey, itemLink, stackCount, generalInterfaceSettings)
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

                if ttcLine then table.insert(lines, ttcLine) end

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
                end
            else
                table.insert(lines, zo_strformat(GetString(rawget(_G, "SI_BETTERUI_MARKET_NO_PRICE_DATA")), "TTC"))
            end
        end

        -- MM Integration
        local mmLine = GetSourcePriceDisplay("MM", GetSourceInfo("mm"), stackCount, iconSize)
        if mmLine then table.insert(lines, mmLine) end

        -- ATT Integration
        local attLine = GetSourcePriceDisplay("ATT", GetSourceInfo("att"), stackCount, iconSize)
        if attLine then table.insert(lines, attLine) end
    end
    return lines
end

--- Gets style and research status info strings.
function BETTERUI.GetInventoryTraitInfo(itemLink)
    local lines = {}
    if itemLink and itemLink ~= "" and BETTERUI.GetSetting("GeneralInterface", "showStyleTrait", false) then
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
function BETTERUI.GetInventoryKnowledgeInfo(itemLink)
    local lines = {}
    if not itemLink or itemLink == "" then return lines end

    -- Respect the user's setting (default true when not set)
    if BETTERUI.GetSetting("GeneralInterface", "showKnowledgeStatus", true) == false then return lines end

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
            return lines
        end
        if IsItemLinkRecipeKnown(itemLink) then
            table.insert(lines, icon .. "|cAAAAAA" .. GetString(rawget(_G, "SI_RECIPE_ALREADY_KNOWN")) .. "|r")
        else
            table.insert(lines, icon .. "|c" .. colors.RESEARCHABLE .. GetString(rawget(_G, "SI_USE_TO_LEARN_RECIPE")) .. "|r")
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
            table.insert(lines, icon .. "|cAAAAAA" .. GetString(rawget(_G, "SI_LORE_LIBRARY_IN_LIBRARY")) .. "|r")
        else
            table.insert(lines, icon .. "|c" .. colors.RESEARCHABLE .. GetString(rawget(_G, "SI_LORE_LIBRARY_USE_TO_LEARN")) .. "|r")
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

local function IsLikelyItemLink(itemLink)
    if type(itemLink) ~= "string" or itemLink == "" then
        return false
    end
    return itemLink:find("|H", 1, true) ~= nil or itemLink:find("item:", 1, true) == 1
end

local function DoesBagContextMatchItemLink(bagId, slotIndex, itemLink)
    if bagId == nil or slotIndex == nil or itemLink == nil then
        return false
    end
    if type(GetItemLink) ~= "function" then
        return true
    end
    local ok, bagItemLink = pcall(GetItemLink, bagId, slotIndex)
    return ok and bagItemLink ~= nil and bagItemLink ~= "" and bagItemLink == itemLink
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
        if child and child:GetType() == CT_LABEL then
            child:SetFont(fontStr)
        end
    end
end

local function HideDuplicateAddonLabels(control)
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
                HideDuplicateAddonLabels(child)
            end
        end
    end
end

local function ScheduleTooltipEquippedRefresh(tooltipControl, itemLink, tooltipType)
    if not itemLink then
        return
    end

    local tooltipRef = tooltipControl
    local capturedItemLink = itemLink
    zo_callLater(function()
        if not tooltipRef or tooltipRef:IsHidden() then return end
        if tooltipRef._betterui_priceRendered then return end
        if IsIncompatibleSceneActive() then return end
        if tooltipRef._betterui_itemLink ~= capturedItemLink then return end

        if BETTERUI.CIM.SharedItemSupport and type(BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText) == "function" then
            BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText(tonumber(tooltipType) or 0, nil)
        end
    end, 1)
end

local function ScheduleDuplicateAddonCleanup(tooltipControl)
    local tooltipRef = tooltipControl
    zo_callLater(function()
        if not tooltipRef or tooltipRef:IsHidden() then return end
        if IsIncompatibleSceneActive() then return end
        HideDuplicateAddonLabels(tooltipRef)
    end, 2)
end

local function ClearTooltipEnhancementState(tooltipControl, tooltipType)
    if tooltipControl then
        tooltipControl._betterui_itemLink = nil
        tooltipControl._betterui_bagId = nil
        tooltipControl._betterui_slotIndex = nil
        tooltipControl._betterui_storeStackCount = nil
        tooltipControl._betterui_priceRendered = nil
    end

    if tooltipType and BETTERUI.CIM.SharedItemSupport and type(BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip) == "function" then
        BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip(tooltipType)
    end
end

local function InstallClearLinesHook(tooltipControl, state, tooltipType)
    if not tooltipControl.ClearLines or state.clearLinesHookInstalled then
        return
    end

    ZO_PostHook(tooltipControl, "ClearLines", function(self, ...)
        ClearTooltipEnhancementState(self, tooltipType)
        ResetInventoryHookState(state)
    end)
    state.clearLinesHookInstalled = true
end

local function InstallBagLayoutHook(tooltipControl, layoutBagName, state, tooltipType, layoutBagDataFn)
    ZO_PreHook(tooltipControl, layoutBagName, function(self, ...)
        if IsIncompatibleSceneActive() then
            state.skipEnhancementForLayout = true
            ClearTooltipEnhancementState(self, tooltipType)
            ResetInventoryHookState(state)
            return
        end

        CaptureBagLayoutState(state, layoutBagDataFn, ...)
    end)
end

local function InstallStoreLayoutHook(tooltipControl, layoutStoreName, state, tooltipType, layoutStoreDataFn)
    ZO_PreHook(tooltipControl, layoutStoreName, function(self, ...)
        if IsIncompatibleSceneActive() then
            state.skipEnhancementForLayout = true
            ClearTooltipEnhancementState(self, tooltipType)
            ResetInventoryHookState(state)
            return
        end

        CaptureStoreLayoutState(state, layoutStoreDataFn, ...)
    end)
end

local function InstallItemLayoutHooks(tooltipControl, layoutItemName, state, tooltipType, layoutItemDataFn)
    ZO_PreHook(tooltipControl, layoutItemName, function(self, ...)
        state.skipEnhancementForLayout = IsIncompatibleSceneActive()
        state.pendingItemLink = nil
        state.pendingTooltipType = nil

        if state.skipEnhancementForLayout then
            ClearTooltipEnhancementState(self, tooltipType)
            return
        end

        local itemLink = ResolveHookItemLink(state, layoutItemDataFn, ...)

        if state.bagId ~= nil and state.slotIndex ~= nil
            and not DoesBagContextMatchItemLink(state.bagId, state.slotIndex, itemLink) then
            state.bagId = nil
            state.slotIndex = nil
        end

        if not IsLikelyItemLink(itemLink) then
            state.skipEnhancementForLayout = true
            ClearTooltipEnhancementState(self, tooltipType)
            return
        end

        CaptureTooltipLayoutState(self, state, itemLink)
        state.storeItemLink = nil
        state.storeStackCount = nil
        state.pendingItemLink = itemLink
        state.pendingTooltipType = tooltipType
    end)

    ZO_PostHook(tooltipControl, layoutItemName, function(self, ...)
        local itemLink = state.pendingItemLink
        local capturedTooltipType = state.pendingTooltipType
        state.pendingItemLink = nil
        state.pendingTooltipType = nil

        if state.skipEnhancementForLayout then
            state.skipEnhancementForLayout = false
            return
        end

        local enhancementsEnabled = BETTERUI.GetSetting("CIM", "enableTooltipEnhancements", true) ~= false

        ApplyTooltipLabelFonts(self)
        ScheduleTooltipEquippedRefresh(self, itemLink, capturedTooltipType)

        if enhancementsEnabled then
            ScheduleDuplicateAddonCleanup(self)
        end
    end)
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
        return
    end

    if type(ZO_PreHook) ~= "function" or type(ZO_PostHook) ~= "function" then
        return
    end
    if not tooltipControl[layoutItemName] or not tooltipControl[layoutBagName] or not tooltipControl[layoutStoreName] then
        return
    end

    local stateHelpers = Tooltips.InventoryHookState
    local hookRuntime = Tooltips.InventoryHookOrchestrator
    local state = stateHelpers.Ensure(tooltipControl)
    local hookKey = string.format("%s|%s|%s|%s", tostring(layoutItemName), tostring(layoutBagName), tostring(layoutStoreName), tostring(tooltipType))
    if state.installedHooks[hookKey] then
        return
    end
    state.installedHooks[hookKey] = true

    hookRuntime.InstallClearLinesHook(tooltipControl, state, tooltipType)
    hookRuntime.InstallBagLayoutHook(tooltipControl, layoutBagName, state, tooltipType, layoutBagDataFn)
    hookRuntime.InstallStoreLayoutHook(tooltipControl, layoutStoreName, state, tooltipType, layoutStoreDataFn)
    hookRuntime.InstallItemLayoutHooks(tooltipControl, layoutItemName, state, tooltipType, layoutItemDataFn)
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
