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

local function TraceFilters(event, phase, data)
    local L = BETTERUI and BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = "TradingHouse"
    data.feature = "browse-filters"
    data.scene = SCENE_MANAGER and SCENE_MANAGER.GetCurrentSceneName and SCENE_MANAGER:GetCurrentSceneName() or nil
    data.gamepad = IsInGamepadPreferredMode and IsInGamepadPreferredMode() or nil
    if L.SetLastAction then
        L.SetLastAction({ flow = event, message = tostring(event) .. ":" .. tostring(phase) })
    end
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.SEARCH or categories.ACTION, event, phase, data)
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

--- Build a name-hash filter table from a completed MatchTradingHouseItemNames
--- task id. Returns nil when there are no usable results.
---@param taskId number|nil
---@return table|nil filter {filterType, values}
function Filters.BuildNameHashFilter(taskId)
    if not taskId then return nil end
    if not GetNumMatchTradingHouseItemNamesResults then return nil end

    local numResults = GetNumMatchTradingHouseItemNamesResults(taskId)
    if not numResults or numResults <= 0 then return nil end

    local maxExactTerms = (GetMaxTradingHouseFilterExactTerms
        and GetMaxTradingHouseFilterExactTerms(TRADING_HOUSE_FILTER_TYPE_NAME_HASH))
        or numResults

    local hashes = {}
    for i = 1, math.min(numResults, maxExactTerms) do
        if GetMatchTradingHouseItemNamesResult then
            local _, hash = GetMatchTradingHouseItemNamesResult(taskId, i)
            if hash then
                table.insert(hashes, hash)
            end
        end
    end

    if #hashes == 0 then return nil end
    return {
        filterType = TRADING_HOUSE_FILTER_TYPE_NAME_HASH,
        values = hashes,
    }
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

local function GetBrowseFeatures()
    local browse = rawget(_G, "GAMEPAD_TRADING_HOUSE_BROWSE")
    return browse and browse.features
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
    local features = GetBrowseFeatures()
    if not features then
        TraceFilters("trading_house.filters", "set_skipped", {
            fn = "Filters.SetBrowseFilterSpec",
            reason = "missingBrowseFeatures",
        })
        BETTERUI.CIM.UserAlertText("TH:FiltersUnavailable",
            GetString(rawget(_G, "SI_BETTERUI_TH_FILTERS_UNAVAILABLE")) or "Browse filters are not available")
        return false
    end

    -- Name search is driven by the native feature so its async name match is
    -- handled correctly.
    if spec.nameText ~= nil
        and features.nameSearchFeature
        and features.nameSearchFeature.SetSearchText then
        features.nameSearchFeature:SetSearchText(spec.nameText)
        TraceFilters("trading_house.filters", "name_applied", { fn = "Filters.SetBrowseFilterSpec", nameText = spec.nameText })
    end

    -- Price range has a native feature on gamepad browse.
    if (spec.priceMin ~= nil or spec.priceMax ~= nil)
        and features.priceRangeFeature
        and features.priceRangeFeature.SetPriceRange then
        local priceFilter = Filters.BuildPriceRangeFilter(spec.priceMin, spec.priceMax)
        features.priceRangeFeature:SetPriceRange(priceFilter.min, priceFilter.max)
        TraceFilters("trading_house.filters", "price_applied", { fn = "Filters.SetBrowseFilterSpec", min = priceFilter.min, max = priceFilter.max, valid = priceFilter.valid })
    end

    -- Quality is a dropdown feature.
    if spec.qualityIndex ~= nil
        and features.qualityFeature
        and features.qualityFeature.SelectChoice then
        features.qualityFeature:SelectChoice(spec.qualityIndex)
        TraceFilters("trading_house.filters", "quality_applied", { fn = "Filters.SetBrowseFilterSpec", qualityIndex = spec.qualityIndex })
    end

    -- Category is a dropdown feature.
    if spec.categoryIndex ~= nil
        and features.searchCategoryFeature
        and features.searchCategoryFeature.SelectChoice then
        features.searchCategoryFeature:SelectChoice(spec.categoryIndex)
        TraceFilters("trading_house.filters", "category_applied", { fn = "Filters.SetBrowseFilterSpec", categoryIndex = spec.categoryIndex })
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

-- MINIMAL FILTER DIALOG -------------------------------------------------------

local FILTER_DIALOG_NAME = "BETTERUI_TRADING_HOUSE_FILTER_DIALOG"

local function L(stringIdName)
    return GetString(rawget(_G, stringIdName) or stringIdName)
end

local function ParseNumber(text)
    if not text or text == "" then return nil end
    return tonumber(text)
end

local function ParseBoolean(text)
    if not text then return nil end
    local lower = string.lower(tostring(text))
    if lower == "true" or lower == "1" or lower == "yes" then
        return true
    elseif lower == "false" or lower == "0" or lower == "no" then
        return false
    end
    return nil
end

local function ChainPriorDialogSetup(priorDialog, setup)
    return function(dialog, ...)
        if priorDialog and type(priorDialog.setup) == "function" then
            priorDialog.setup(dialog, ...)
        end
        return setup(dialog, ...)
    end
end

--- Registers and shows a first-cut filter-entry dialog. Numeric fields accept
--- plain numbers; quality/category are choice indices. The maintainer can
--- replace this with a polished gamepad UI later.
function Filters.ShowFilterDialog()
    if not (ZO_Dialogs_IsDialogRegistered and ZO_Dialogs_ShowGamepadDialog and ZO_Dialogs_RegisterCustomDialog) then
        TraceFilters("trading_house.filters_dialog", "show_skipped", { fn = "Filters.ShowFilterDialog", reason = "missingDialogApi" })
        return
    end

    local priorDialog = ESO_Dialogs and ESO_Dialogs[FILTER_DIALOG_NAME] or nil
    if not (priorDialog and priorDialog._betteruiTradingHouseFilterDialog) then
        local function AddTextField(labelKey, fieldKey, numeric)
            return {
                template = "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
                text = L(labelKey),
                templateData = {
                    setup = function(control, data, selected, reselectingDuringRebuild, enabled, active)
                        if control.highlight then
                            control.highlight:SetHidden(not selected)
                        end
                        if control.editBoxControl and control.editBoxControl.SetText then
                            local dialog = ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)
                            local value = dialog and dialog.data and dialog.data[fieldKey] or nil
                            control.editBoxControl:SetText(value ~= nil and tostring(value) or "")
                            TraceFilters("trading_house.filters_dialog", "field_setup", {
                                fn = "Filters.ShowFilterDialog",
                                field = fieldKey,
                                selected = selected == true,
                                restored = value ~= nil,
                            })
                        end
                    end,
                    textChangedCallback = function(control)
                        local dialog = ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)
                        if dialog and dialog.data then
                            local text = control:GetText()
                            if numeric then
                                dialog.data[fieldKey] = ParseNumber(text)
                            elseif fieldKey == "isChampionRank" then
                                dialog.data[fieldKey] = ParseBoolean(text)
                            else
                                dialog.data[fieldKey] = text
                            end
                        end
                    end,
                },
            }
        end

        local dialogInfo = {
            _betteruiTradingHouseFilterDialog = true,
            canQueue = true,
            gamepadInfo = {
                dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
            },
            title = {
                text = L("SI_BETTERUI_TH_FILTER_TITLE") or "Edit Search Filters",
            },
            setup = ChainPriorDialogSetup(priorDialog, function(dialog)
                dialog:setupFunc()
            end),
            parametricList = {
                AddTextField("SI_BETTERUI_TH_FILTER_NAME", "nameText", false),
                AddTextField("SI_BETTERUI_TH_FILTER_PRICE_MIN", "priceMin", true),
                AddTextField("SI_BETTERUI_TH_FILTER_PRICE_MAX", "priceMax", true),
                AddTextField("SI_BETTERUI_TH_FILTER_QUALITY", "qualityIndex", true),
                AddTextField("SI_BETTERUI_TH_FILTER_CATEGORY", "categoryIndex", true),
                AddTextField("SI_BETTERUI_TH_FILTER_LEVEL_MIN", "levelMin", true),
                AddTextField("SI_BETTERUI_TH_FILTER_LEVEL_MAX", "levelMax", true),
                AddTextField("SI_BETTERUI_TH_FILTER_IS_CP", "isChampionRank", false),
            },
            buttons = {
                {
                    text = SI_DIALOG_CONFIRM,
                    callback = function(dialog)
                        local data = dialog.data or {}
                        TraceFilters("trading_house.filters_dialog", "confirm", { fn = "Filters.ShowFilterDialog", data = data })
                        if Filters.SetBrowseFilterSpec(data) then
                            if TH.BrowseComponent then
                                TraceFilters("trading_house.filters_dialog", "execute_search", { fn = "Filters.ShowFilterDialog" })
                                TH.BrowseComponent:ExecuteSearch()
                            end
                        end
                    end,
                },
                {
                    text = SI_DIALOG_CANCEL,
                    callback = function()
                        TraceFilters("trading_house.filters_dialog", "cancel", { fn = "Filters.ShowFilterDialog" })
                    end,
                },
            },
        }
        ZO_Dialogs_RegisterCustomDialog(FILTER_DIALOG_NAME, dialogInfo)
    end

    TraceFilters("trading_house.filters_dialog", "shown", { fn = "Filters.ShowFilterDialog" })
    ZO_Dialogs_ShowGamepadDialog(FILTER_DIALOG_NAME, {})
end
