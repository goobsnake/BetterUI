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

local function GetBrowseFeatures()
    local browse = rawget(_G, "GAMEPAD_TRADING_HOUSE_BROWSE")
    return browse and browse.features
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
    local features = GetBrowseFeatures()
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

-- MINIMAL FILTER DIALOG -------------------------------------------------------

local FILTER_DIALOG_NAME = "BETTERUI_TRADING_HOUSE_FILTER_DIALOG"

local function L(stringIdName, fallback)
    return SafeString(fallback or stringIdName, rawget(_G, stringIdName) or stringIdName)
end

local function ParseNumber(text)
    if not text or text == "" then return nil end
    return tonumber(text)
end

--- Registers and shows a first-cut filter-entry dialog. Numeric fields accept
--- plain numbers; quality/category use native gamepad dropdown rows.
function Filters.ShowFilterDialog()
    if not ZO_Dialogs_ShowGamepadDialog then
        TraceFilters("trading_house.filters_dialog", "show_skipped", { fn = "Filters.ShowFilterDialog", reason = "missingDialogApi" })
        return
    end

    local Dialogs = BETTERUI.CIM and BETTERUI.CIM.Dialogs
    local priorDialog = Dialogs and Dialogs.GetCurrentInfo and Dialogs.GetCurrentInfo(FILTER_DIALOG_NAME) or nil
    if not (priorDialog and priorDialog._betteruiTradingHouseFilterDialog) then
        local function GetDialog()
            if type(ZO_GenericGamepadDialog_GetControl) == "function" and GAMEPAD_DIALOGS then
                return SafeCall(ZO_GenericGamepadDialog_GetControl, GAMEPAD_DIALOGS.PARAMETRIC)
            end
            return nil
        end

        local function GetFeaturePriceRange(features)
            local priceFeature = features and features.priceRangeFeature
            if priceFeature and priceFeature.GetPriceRange then
                return SafeCall(priceFeature.GetPriceRange, priceFeature)
            end
            return nil, nil
        end

        local function GetSelectedQualityIndex(features)
            local qualityFeature = features and features.qualityFeature
            if qualityFeature and qualityFeature.GetSelectedChoiceIndex then
                return SafeCall(qualityFeature.GetSelectedChoiceIndex, qualityFeature) or 1
            end
            return qualityFeature and qualityFeature.selectedChoiceIndex or 1
        end

        local function GetSelectedCategoryIndex(features)
            local categoryFeature = features and features.searchCategoryFeature
            local selectedParams = categoryFeature and categoryFeature.GetCategoryParams
                and SafeCall(categoryFeature.GetCategoryParams, categoryFeature) or nil
            local selectedSubcategory = categoryFeature and categoryFeature.GetSubcategoryKey
                and SafeCall(categoryFeature.GetSubcategoryKey, categoryFeature) or nil
            local choices = BuildCategoryChoices()

            for index, choice in ipairs(choices) do
                if choice.categoryParams and choice.categoryParams == selectedParams then
                    if not selectedSubcategory or selectedSubcategory == choice.subcategoryKey then
                        return index
                    end
                elseif choice.categoryKey == "AllItems" and not selectedParams then
                    return index
                end
            end

            return 1
        end

        local function BuildQualityChoices(features)
            local choices = {}
            local qualityFeature = features and features.qualityFeature
            local params = qualityFeature and qualityFeature.featureParams
            if params and params.GetNumChoices and params.GetChoiceDisplayName then
                local numChoices = SafeCall(params.GetNumChoices, params) or 0
                for choiceIndex = 1, numChoices do
                    local displayName = SafeCall(params.GetChoiceDisplayName, params, choiceIndex)
                    if displayName and displayName ~= "" then
                        table.insert(choices, { displayName = displayName, choiceIndex = choiceIndex })
                    end
                end
            end

            if #choices == 0 then
                local anyText = SafeString("Any Quality", rawget(_G, "SI_TRADING_HOUSE_BROWSE_QUALITY_ANY") or "SI_TRADING_HOUSE_BROWSE_QUALITY_ANY")
                table.insert(choices, { displayName = anyText, choiceIndex = 1 })

                local qualityConstants = {
                    rawget(_G, "ITEM_DISPLAY_QUALITY_TRASH"),
                    rawget(_G, "ITEM_DISPLAY_QUALITY_NORMAL"),
                    rawget(_G, "ITEM_DISPLAY_QUALITY_MAGIC"),
                    rawget(_G, "ITEM_DISPLAY_QUALITY_ARCANE"),
                    rawget(_G, "ITEM_DISPLAY_QUALITY_ARTIFACT"),
                    rawget(_G, "ITEM_DISPLAY_QUALITY_LEGENDARY"),
                }
                for _, displayQuality in ipairs(qualityConstants) do
                    if displayQuality ~= nil then
                        local qualityText = SafeString(tostring(displayQuality), "SI_ITEMQUALITY", displayQuality)
                        local color = SafeCall(GetItemQualityColor, displayQuality)
                        if color and color.Colorize then
                            qualityText = SafeCall(color.Colorize, color, qualityText) or qualityText
                        end
                        table.insert(choices, { displayName = qualityText, choiceIndex = #choices + 1 })
                    end
                end
            end

            return choices
        end

        local function PopulateInitialDialogData(data)
            if data._betteruiInitialized then return end

            local features = GetBrowseFeatures()
            local nameFeature = features and features.nameSearchFeature
            if nameFeature and nameFeature.GetSearchText then
                data.nameText = SafeCall(nameFeature.GetSearchText, nameFeature) or ""
            else
                data.nameText = ""
            end

            data.priceMin, data.priceMax = GetFeaturePriceRange(features)
            data.qualityIndex = GetSelectedQualityIndex(features)
            data.categoryIndex = GetSelectedCategoryIndex(features)
            data._betteruiInitialized = true
        end

        local function ResetDialogData(data)
            data.nameText = ""
            data.priceMin = nil
            data.priceMax = nil
            data.qualityIndex = 1
            data.categoryIndex = 1
            data._betteruiInitialized = true
        end

        local function AddTextField(labelKey, fieldKey, numeric)
            return {
                template = "ZO_Gamepad_GenericDialog_Parametric_TextFieldItem",
                headerTemplate = "ZO_GamepadMenuEntryFullWidthHeaderTemplate",
                header = L(labelKey),
                text = L(labelKey),
                templateData = {
                    setup = function(control, data, selected, reselectingDuringRebuild, enabled, active)
                        if control.highlight then
                            control.highlight:SetHidden(not selected)
                        end
                        if control.editBoxControl and control.editBoxControl.SetText then
                            local dialog = data and data.dialog or GetDialog()
                            local value = dialog and dialog.data and dialog.data[fieldKey] or nil
                            control.editBoxControl.textChangedCallback = data.textChangedCallback
                            if control.editBoxControl.SetDefaultText then
                                control.editBoxControl:SetDefaultText(L(labelKey))
                            end
                            if numeric and control.editBoxControl.SetMaxInputChars then
                                control.editBoxControl:SetMaxInputChars(9)
                            end
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
                        local dialog = GetDialog()
                        if dialog and dialog.data then
                            local text = control:GetText()
                            if numeric then
                                dialog.data[fieldKey] = ParseNumber(text)
                            else
                                dialog.data[fieldKey] = text
                            end
                        end
                    end,
                    callback = function(dialog)
                        local targetControl = dialog and dialog.entryList and dialog.entryList.GetTargetControl
                            and dialog.entryList:GetTargetControl() or nil
                        local editBox = targetControl and targetControl.editBoxControl or nil
                        if editBox and editBox.TakeFocus then
                            editBox:TakeFocus()
                        end
                    end,
                    narrationText = rawget(_G, "ZO_GetDefaultParametricListEditBoxNarrationText"),
                },
            }
        end

        local function AddDropdownField(labelKey, fieldKey, buildChoices)
            return {
                template = "ZO_GamepadDropdownItem",
                headerTemplate = "ZO_GamepadMenuEntryFullWidthHeaderTemplate",
                header = L(labelKey),
                templateData = {
                    setup = function(control, data, selected)
                        local dialog = data and data.dialog or GetDialog()
                        local dialogData = dialog and dialog.data or {}
                        local dropdown = control and control.dropdown or nil
                        if not dropdown then return end

                        if ZO_GAMEPAD_COMPONENT_COLORS then
                            local unselectedColor = ZO_GAMEPAD_COMPONENT_COLORS.UNSELECTED_INACTIVE
                            local selectedColor = ZO_GAMEPAD_COMPONENT_COLORS.SELECTED_ACTIVE
                            if dropdown.SetNormalColor and unselectedColor and unselectedColor.UnpackRGB then
                                local ok, r, g, b = TryCall(unselectedColor.UnpackRGB, unselectedColor)
                                if ok then TryCall(dropdown.SetNormalColor, dropdown, r, g, b) end
                            end
                            if dropdown.SetHighlightedColor and selectedColor and selectedColor.UnpackRGB then
                                local ok, r, g, b = TryCall(selectedColor.UnpackRGB, selectedColor)
                                if ok then TryCall(dropdown.SetHighlightedColor, dropdown, r, g, b) end
                            end
                            TryCall(dropdown.SetSelectedItemTextColor, dropdown, selected)
                        end

                        TryCall(dropdown.SetSortsItems, dropdown, false)
                        TryCall(dropdown.ClearItems, dropdown)

                        local choices = buildChoices(GetBrowseFeatures())
                        local function OnChoiceSelected(comboBox, entryText, entry)
                            local activeDialog = GetDialog()
                            if activeDialog and activeDialog.data then
                                activeDialog.data[fieldKey] = entry.choiceIndex
                            end
                        end

                        local selectedIndex = tonumber(dialogData[fieldKey]) or 1
                        local entryToSelect = nil
                        for index, choice in ipairs(choices) do
                            local entry = SafeCall(dropdown.CreateItemEntry, dropdown, choice.displayName, OnChoiceSelected)
                            if entry then
                                entry.choiceIndex = choice.choiceIndex or index
                                TryCall(dropdown.AddItem, dropdown, entry)
                                if entry.choiceIndex == selectedIndex then
                                    entryToSelect = entry
                                end
                            end
                        end

                        TryCall(dropdown.UpdateItems, dropdown)
                        local IGNORE_CALLBACK = true
                        if entryToSelect and dropdown.TrySelectItemByData then
                            TryCall(dropdown.TrySelectItemByData, dropdown, entryToSelect, IGNORE_CALLBACK)
                        elseif dropdown.SelectItemByIndex then
                            TryCall(dropdown.SelectItemByIndex, dropdown, selectedIndex, IGNORE_CALLBACK)
                        elseif dropdown.SelectFirstItem then
                            TryCall(dropdown.SelectFirstItem, dropdown)
                        end

                        if SCREEN_NARRATION_MANAGER and SCREEN_NARRATION_MANAGER.RegisterDialogDropdown then
                            TryCall(SCREEN_NARRATION_MANAGER.RegisterDialogDropdown, SCREEN_NARRATION_MANAGER, dialog, dropdown)
                        end

                        TraceFilters("trading_house.filters_dialog", "field_setup", {
                            fn = "Filters.ShowFilterDialog",
                            field = fieldKey,
                            selected = selected == true,
                            restored = dialogData[fieldKey] ~= nil,
                            optionCount = #choices,
                        })
                    end,
                    callback = function(dialog)
                        local targetControl = dialog and dialog.entryList and dialog.entryList.GetTargetControl
                            and dialog.entryList:GetTargetControl() or nil
                        local dropdown = targetControl and targetControl.dropdown or nil
                        if dropdown and dropdown.Activate then
                            TryCall(dropdown.Activate, dropdown)
                        end
                    end,
                    narrationText = rawget(_G, "ZO_GetDefaultParametricListDropdownNarrationText"),
                },
            }
        end

        local function SubmitDialog(dialog)
            local data = dialog and dialog.data or {}
            -- Blank price boxes must explicitly reset the native price feature;
            -- omitted nils would leave a previous range untouched.
            local spec = {
                nameText = data.nameText or "",
                priceMin = data.priceMin or 0,
                priceMax = data.priceMax or 0,
                qualityIndex = data.qualityIndex or 1,
                categoryIndex = data.categoryIndex or 1,
            }

            TraceFilters("trading_house.filters_dialog", "confirm", { fn = "Filters.ShowFilterDialog", data = spec })
            if Filters.SetBrowseFilterSpec(spec) then
                if TH.BrowseComponent then
                    TraceFilters("trading_house.filters_dialog", "execute_search", { fn = "Filters.ShowFilterDialog" })
                    TH.BrowseComponent:ExecuteSearch()
                end
            end
            if ZO_Dialogs_ReleaseDialogOnButtonPress then
                ZO_Dialogs_ReleaseDialogOnButtonPress(FILTER_DIALOG_NAME)
            end
        end

        local dialogInfo = {
            _betteruiTradingHouseFilterDialog = true,
            canQueue = true,
            blockDialogReleaseOnPress = true,
            gamepadInfo = {
                dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
            },
            title = {
                text = L("SI_BETTERUI_TH_FILTER_TITLE", "Edit Search Filters"),
            },
            setup = function(dialog)
                dialog.data = dialog.data or {}
                PopulateInitialDialogData(dialog.data)
                dialog:setupFunc()
            end,
            parametricList = {
                AddTextField("SI_BETTERUI_TH_FILTER_NAME", "nameText", false),
                AddDropdownField("SI_BETTERUI_TH_FILTER_CATEGORY", "categoryIndex", BuildCategoryChoices),
                AddTextField("SI_BETTERUI_TH_FILTER_PRICE_MIN", "priceMin", true),
                AddTextField("SI_BETTERUI_TH_FILTER_PRICE_MAX", "priceMax", true),
                AddDropdownField("SI_BETTERUI_TH_FILTER_QUALITY", "qualityIndex", BuildQualityChoices),
            },
            buttons = {
                {
                    keybind = "DIALOG_PRIMARY",
                    text = SI_GAMEPAD_SELECT_OPTION,
                    visible = function(dialog)
                        local targetData = dialog and dialog.entryList and dialog.entryList.GetTargetData
                            and dialog.entryList:GetTargetData() or nil
                        return targetData and targetData.callback ~= nil
                    end,
                    enabled = function(dialog)
                        local targetData = dialog and dialog.entryList and dialog.entryList.GetTargetData
                            and dialog.entryList:GetTargetData() or nil
                        if targetData and targetData.enabled ~= nil then
                            if type(targetData.enabled) == "function" then
                                return targetData.enabled(dialog)
                            end
                            return targetData.enabled
                        end
                        return true
                    end,
                    callback = function(dialog)
                        local targetData = dialog and dialog.entryList and dialog.entryList.GetTargetData
                            and dialog.entryList:GetTargetData() or nil
                        if targetData and targetData.callback then
                            targetData.callback(dialog)
                        end
                    end,
                },
                {
                    keybind = "DIALOG_NEGATIVE",
                    text = SI_DIALOG_CANCEL,
                    callback = function()
                        TraceFilters("trading_house.filters_dialog", "cancel", { fn = "Filters.ShowFilterDialog" })
                        if ZO_Dialogs_ReleaseDialogOnButtonPress then
                            ZO_Dialogs_ReleaseDialogOnButtonPress(FILTER_DIALOG_NAME)
                        end
                    end,
                },
                {
                    keybind = "DIALOG_SECONDARY",
                    text = SI_DIALOG_CONFIRM,
                    callback = SubmitDialog,
                },
                {
                    keybind = "DIALOG_RESET",
                    text = L("SI_TRADING_HOUSE_RESET_SEARCH", "Reset"),
                    callback = function(dialog)
                        dialog.data = dialog.data or {}
                        ResetDialogData(dialog.data)
                        TraceFilters("trading_house.filters_dialog", "reset", { fn = "Filters.ShowFilterDialog" })
                        if dialog.setupFunc then
                            dialog:setupFunc()
                        end
                        if SCREEN_NARRATION_MANAGER and SCREEN_NARRATION_MANAGER.QueueDialog then
                            TryCall(SCREEN_NARRATION_MANAGER.QueueDialog, SCREEN_NARRATION_MANAGER, dialog)
                        end
                    end,
                },
            },
        }
        if not (Dialogs and Dialogs.RegisterWithPriorChain and Dialogs.RegisterWithPriorChain(FILTER_DIALOG_NAME, dialogInfo)) then
            TraceFilters("trading_house.filters_dialog", "show_skipped", {
                fn = "Filters.ShowFilterDialog",
                reason = "registryRejected",
            })
            return
        end
    end

    TraceFilters("trading_house.filters_dialog", "shown", { fn = "Filters.ShowFilterDialog" })
    ZO_Dialogs_ShowGamepadDialog(FILTER_DIALOG_NAME, {})
end
