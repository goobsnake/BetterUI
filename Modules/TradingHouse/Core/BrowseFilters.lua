--[[
File: Modules/TradingHouse/Core/BrowseFilters.lua
Purpose: First-cut filter-editing helpers for the Trading House browse tab
        (TRC-003).

Pure helpers build and validate filter values; SetBrowseFilterSpec drives the
native search features when they are available. Filters that have no native
feature (e.g. level range on gamepad browse) are applied directly after
TRADING_HOUSE_SEARCH:ApplyFilters runs, via ApplyPendingFilters.
]]

local TH = BETTERUI.TradingHouse

TH.BrowseFilters = {}
local Filters = TH.BrowseFilters

-- Pending filter spec applied during the next ExecuteSearch.
Filters.pendingSpec = nil

local TraceFilters = (BETTERUI.Log and BETTERUI.Log.MakeTracer)
    and BETTERUI.Log.MakeTracer{ module = "TradingHouse", feature = "browse-filters", category = BETTERUI.Log.CATEGORY.SEARCH }
    or function() end

local function TryCall(fn, ...)
    if type(fn) ~= "function" then return false end

    local results = { pcall(fn, ...) }
    local ok = table.remove(results, 1)
    if ok then
        return true, unpack(results)
    end

    TraceFilters("trading_house.filters_dialog", "native_lookup_failed", {
        fn = "Filters.TryCall",
        error = tostring(results[1]),
    })
    return false
end

local function SafeCall(fn, ...)
    local ok, result1, result2, result3 = TryCall(fn, ...)
    if ok then
        return result1, result2, result3
    end
    return nil
end

local function SafeString(fallback, stringId, ...)
    local text = SafeCall(GetString, stringId, ...)
    if text and text ~= "" then
        return text
    end
    return fallback or ""
end

-- PURE HELPERS ----------------------------------------------------------------

--- Build a validated price-range filter table.
---@param minPrice number|nil
---@param maxPrice number|nil
---@return table filter {filterType, min, max, valid}
function Filters.BuildPriceRangeFilter(minPrice, maxPrice)
    local minTradingPrice = MIN_TRADING_HOUSE_POST_PRICE or 1
    local maxTradingPrice = MAX_PLAYER_CURRENCY or 999999999

    minPrice = tonumber(minPrice)
    maxPrice = tonumber(maxPrice)

    local hasMin = minPrice ~= nil and minPrice > 0
    local hasMax = maxPrice ~= nil and maxPrice > 0

    local result = {
        filterType = TRADING_HOUSE_FILTER_TYPE_PRICE,
        min = hasMin and zo_clamp(minPrice, minTradingPrice, maxTradingPrice) or nil,
        max = hasMax and zo_clamp(maxPrice, minTradingPrice, maxTradingPrice) or nil,
        valid = hasMin or hasMax,
    }

    if result.valid and result.min and result.max and result.min > result.max then
        result.min, result.max = result.max, result.min
    end

    return result
end

--- Normalize a level/CP range so min <= max and both are inside the engine
--- limits. Returns the normalized values and a CP flag.
---@param minLevel number|nil
---@param maxLevel number|nil
---@param isChampionRank boolean|nil
---@return number minLevel
---@return number maxLevel
---@return boolean isChampionRank
function Filters.NormalizeLevelFilter(minLevel, maxLevel, isChampionRank)
    local minLimit = 0
    local maxLimit
    if isChampionRank then
        maxLimit = (GetChampionPointsPlayerProgressionCap and GetChampionPointsPlayerProgressionCap()) or 3600
    else
        maxLimit = (GetMaxLevel and GetMaxLevel()) or 50
    end

    minLevel = tonumber(minLevel) or minLimit
    maxLevel = tonumber(maxLevel) or maxLimit

    minLevel = zo_clamp(minLevel, minLimit, maxLimit)
    maxLevel = zo_clamp(maxLevel, minLimit, maxLimit)

    if minLevel > maxLevel then
        minLevel, maxLevel = maxLevel, minLevel
    end

    return minLevel, maxLevel, isChampionRank == true
end

--- Apply a single filter table to a search object or directly to the engine.
--- Supports range filters, multi-value exact filters, and single-value filters.
---@param search table|nil TRADING_HOUSE_SEARCH or compatible object
---@param filterTable table {filterType, min?, max?, values?, value?}
---@return boolean applied
function Filters.ApplyFilterTable(search, filterTable)
    if not filterTable then return false end
    local filterType = filterTable.filterType
    if not filterType then return false end

    if filterTable.min ~= nil or filterTable.max ~= nil then
        local min = filterTable.min or 0
        local max = filterTable.max or 0
        if search and search.SetFilterRange then
            search:SetFilterRange(filterType, min, max)
            return true
        elseif SetTradingHouseFilterRange then
            SetTradingHouseFilterRange(filterType, min, max)
            return true
        end
    elseif filterTable.values ~= nil then
        if search and search.SetFilter then
            search:SetFilter(filterType, filterTable.values)
            return true
        elseif SetTradingHouseFilter then
            SetTradingHouseFilter(filterType, unpack(filterTable.values))
            return true
        end
    elseif filterTable.value ~= nil then
        if search and search.SetFilter then
            search:SetFilter(filterType, filterTable.value)
            return true
        elseif SetTradingHouseFilter then
            SetTradingHouseFilter(filterType, filterTable.value)
            return true
        end
    end

    return false
end

-- FEATURE ACCESS --------------------------------------------------------------

local standaloneBrowseFeatures

---@return table|nil
local function CreateStandaloneBrowseFeatures()
    if standaloneBrowseFeatures then return standaloneBrowseFeatures end
    if type(ZO_TradingHouse_CreateGamepadFeature) ~= "function" then return nil end

    local features = {
        nameSearchFeature = ZO_TradingHouse_CreateGamepadFeature("NameSearch"),
        searchCategoryFeature = ZO_TradingHouse_CreateGamepadFeature("SearchCategory"),
        priceRangeFeature = ZO_TradingHouse_CreateGamepadFeature("PriceRange"),
        qualityFeature = ZO_TradingHouse_CreateGamepadFeature("Quality"),
    }
    if not (features.nameSearchFeature and features.searchCategoryFeature
        and features.priceRangeFeature and features.qualityFeature) then
        return nil
    end

    for _, feature in pairs(features) do
        if feature.ResetSearch then
            TryCall(feature.ResetSearch, feature)
        end
    end
    standaloneBrowseFeatures = features

    local search = rawget(_G, "TRADING_HOUSE_SEARCH")
    if search and search.AssociateWithSearchFeatures then
        TryCall(search.AssociateWithSearchFeatures, search, features)
    end
    return standaloneBrowseFeatures
end

---@return table|nil
local function GetBrowseFeatures()
    local browse = rawget(_G, "GAMEPAD_TRADING_HOUSE_BROWSE")
    if browse and browse.GetFeatures then
        local features = SafeCall(browse.GetFeatures, browse)
        if features then return features end
    end
    if browse and browse.features then return browse.features end
    return CreateStandaloneBrowseFeatures()
end

---@return table|nil features
function Filters.AssociateSearchFeatures()
    local features = GetBrowseFeatures()
    local search = rawget(_G, "TRADING_HOUSE_SEARCH")
    if features and search and search.AssociateWithSearchFeatures then
        TryCall(search.AssociateWithSearchFeatures, search, features)
    end
    return features
end

---@return boolean reset
function Filters.ResetSearch()
    local features = Filters.AssociateSearchFeatures()
    if not features then
        return false
    end
    for _, feature in pairs(features) do
        if feature and feature.ResetSearch then
            TryCall(feature.ResetSearch, feature)
        end
    end
    Filters.pendingSpec = nil
    return true
end

local function GetFirstSubcategoryKey(categoryParams)
    if categoryParams and categoryParams.GetSubcategoryKey then
        return SafeCall(categoryParams.GetSubcategoryKey, categoryParams, 1)
    end
    return nil
end

local function BuildCategoryChoices()
    local choices = {}
    local categoryParamsList = rawget(_G, "ZO_TRADING_HOUSE_CATEGORY_PARAMS_LIST")
    if type(categoryParamsList) == "table" then
        for _, categoryParams in ipairs(categoryParamsList) do
            local categoryKey = categoryParams.GetKey and SafeCall(categoryParams.GetKey, categoryParams) or nil
            local displayName = categoryParams.GetFormattedName and SafeCall(categoryParams.GetFormattedName, categoryParams) or categoryKey
            if categoryKey and displayName and displayName ~= "" then
                table.insert(choices, {
                    displayName = displayName,
                    categoryKey = categoryKey,
                    categoryParams = categoryParams,
                    subcategoryKey = GetFirstSubcategoryKey(categoryParams),
                })
            end
        end
    end

    if #choices == 0 then
        table.insert(choices, {
            displayName = SafeString("All Items", rawget(_G, "SI_TRADING_HOUSE_BROWSE_ALL_ITEMS") or "SI_TRADING_HOUSE_BROWSE_ALL_ITEMS"),
            categoryKey = "AllItems",
            subcategoryKey = "AllSubcategories",
        })
    end

    return choices
end

local function SelectCategoryChoice(categoryFeature, categoryIndex)
    if not categoryFeature then return false end

    local choices = BuildCategoryChoices()
    local index = tonumber(categoryIndex) or 1
    local choice = choices[index] or choices[1]
    if not choice then return false end

    if choice.categoryParams and categoryFeature.SelectCategoryParams then
        return TryCall(categoryFeature.SelectCategoryParams, categoryFeature, choice.categoryParams, choice.subcategoryKey)
    elseif choice.categoryKey and categoryFeature.SelectCategory then
        return TryCall(categoryFeature.SelectCategory, categoryFeature, choice.categoryKey, choice.subcategoryKey)
    elseif categoryFeature.SelectChoice then
        -- Simple dropdown-style category features expose only
        -- SelectChoice(index); keep it as the compatibility path.
        return TryCall(categoryFeature.SelectChoice, categoryFeature, index)
    end

    return false
end

-- FILTER SPEC APPLICATION -----------------------------------------------------

--- Store a filter specification to be applied by the next ExecuteSearch.
--- Fields supported: nameText, priceMin, priceMax, qualityIndex,
--- categoryIndex, levelMin, levelMax, isChampionRank.
---@param spec table|nil
function Filters.SetBrowseFilterSpec(spec)
    spec = spec or {}
    TraceFilters("trading_house.filters", "set_begin", {
        fn = "Filters.SetBrowseFilterSpec",
        nameText = spec.nameText,
        priceMin = spec.priceMin,
        priceMax = spec.priceMax,
        qualityIndex = spec.qualityIndex,
        categoryIndex = spec.categoryIndex,
        levelMin = spec.levelMin,
        levelMax = spec.levelMax,
        isChampionRank = spec.isChampionRank,
    })
    local features = Filters.AssociateSearchFeatures()
    if not features then
        TraceFilters("trading_house.filters", "set_skipped", {
            fn = "Filters.SetBrowseFilterSpec",
            reason = "missingBrowseFeatures",
        })
        BETTERUI.CIM.UserAlertText("TH:FiltersUnavailable",
            SafeString("Browse filters are not available", rawget(_G, "SI_BETTERUI_TH_FILTERS_UNAVAILABLE") or "SI_BETTERUI_TH_FILTERS_UNAVAILABLE"))
        return false
    end

    -- Name search is driven by the native feature so its async name match is
    -- handled correctly.
    if spec.nameText ~= nil
        and features.nameSearchFeature
        and features.nameSearchFeature.SetSearchText then
        local nameApplied = TryCall(features.nameSearchFeature.SetSearchText, features.nameSearchFeature, spec.nameText)
        TraceFilters("trading_house.filters", "name_applied", { fn = "Filters.SetBrowseFilterSpec", nameText = spec.nameText, applied = nameApplied })
    end

    -- Price range has a native feature on gamepad browse.
    if (spec.priceMin ~= nil or spec.priceMax ~= nil)
        and features.priceRangeFeature
        and features.priceRangeFeature.SetPriceRange then
        local priceFilter = Filters.BuildPriceRangeFilter(spec.priceMin, spec.priceMax)
        local priceApplied = TryCall(features.priceRangeFeature.SetPriceRange, features.priceRangeFeature, priceFilter.min, priceFilter.max)
        TraceFilters("trading_house.filters", "price_applied", { fn = "Filters.SetBrowseFilterSpec", min = priceFilter.min, max = priceFilter.max, valid = priceFilter.valid, applied = priceApplied })
    end

    -- Quality is a dropdown feature.
    if spec.qualityIndex ~= nil
        and features.qualityFeature
        and features.qualityFeature.SelectChoice then
        local qualityApplied = TryCall(features.qualityFeature.SelectChoice, features.qualityFeature, spec.qualityIndex)
        TraceFilters("trading_house.filters", "quality_applied", { fn = "Filters.SetBrowseFilterSpec", qualityIndex = spec.qualityIndex, applied = qualityApplied })
    end

    -- Category uses native category params rather than the simpler dropdown
    -- SelectChoice API used by quality.
    if spec.categoryIndex ~= nil
        and features.searchCategoryFeature then
        local categoryApplied = SelectCategoryChoice(features.searchCategoryFeature, spec.categoryIndex)
        TraceFilters("trading_house.filters", "category_applied", { fn = "Filters.SetBrowseFilterSpec", categoryIndex = spec.categoryIndex, applied = categoryApplied })
    end

    -- Level range is not a default gamepad browse feature, so it is stored and
    -- applied directly after the native features run.
    if spec.levelMin ~= nil or spec.levelMax ~= nil or spec.isChampionRank ~= nil then
        Filters.pendingSpec = Filters.pendingSpec or {}
        Filters.pendingSpec.levelMin = spec.levelMin
        Filters.pendingSpec.levelMax = spec.levelMax
        Filters.pendingSpec.isChampionRank = spec.isChampionRank
        TraceFilters("trading_house.filters", "pending_level", { fn = "Filters.SetBrowseFilterSpec", levelMin = spec.levelMin, levelMax = spec.levelMax, isChampionRank = spec.isChampionRank })
    end

    TraceFilters("trading_house.filters", "set_complete", { fn = "Filters.SetBrowseFilterSpec", hasPendingSpec = Filters.pendingSpec ~= nil })
    return true
end

--- Apply any filters that must be set directly on TRADING_HOUSE_SEARCH after
--- the native features have applied theirs. Called from BrowseComponent:ExecuteSearch.
---@param search table|nil
---@return boolean applied
function Filters.ApplyPendingFilters(search)
    if not search then
        TraceFilters("trading_house.filters", "pending_skipped", { fn = "Filters.ApplyPendingFilters", reason = "missingSearch" })
        return false
    end
    local pending = Filters.pendingSpec
    if not pending then
        TraceFilters("trading_house.filters", "pending_skipped", { fn = "Filters.ApplyPendingFilters", reason = "none" })
        return false
    end

    local applied = false

    if pending.levelMin ~= nil or pending.levelMax ~= nil then
        local minLevel, maxLevel, isCP = Filters.NormalizeLevelFilter(
            pending.levelMin, pending.levelMax, pending.isChampionRank)
        local filterType = isCP and TRADING_HOUSE_FILTER_TYPE_CHAMPION_POINTS
            or TRADING_HOUSE_FILTER_TYPE_LEVEL
        applied = Filters.ApplyFilterTable(search, {
            filterType = filterType,
            min = minLevel,
            max = maxLevel,
        }) or applied
        TraceFilters("trading_house.filters", "pending_level_applied", { fn = "Filters.ApplyPendingFilters", minLevel = minLevel, maxLevel = maxLevel, isChampionRank = isCP, filterType = filterType, applied = applied })
    end

    Filters.pendingSpec = nil
    TraceFilters("trading_house.filters", "pending_cleared", { fn = "Filters.ApplyPendingFilters", applied = applied })
    return applied
end

-- Dialog implementation lives in BrowseFilterDialog.lua; expose only the
-- bounded helpers it needs so the pure filter/application module stays focused.
Filters._TryCall = TryCall
Filters._SafeCall = SafeCall
Filters._SafeString = SafeString
Filters._GetBrowseFeatures = GetBrowseFeatures
Filters._BuildCategoryChoices = BuildCategoryChoices
