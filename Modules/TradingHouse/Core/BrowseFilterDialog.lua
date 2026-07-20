--[[
File: Modules/TradingHouse/Core/BrowseFilterDialog.lua
Purpose: Native-parity progressive gamepad filter dialog and input lifecycle.
]]

local TH = BETTERUI.TradingHouse
local Filters = TH.BrowseFilters
local TryCall = Filters._TryCall
local SafeCall = Filters._SafeCall
local SafeString = Filters._SafeString
local GetBrowseFeatures = Filters._GetBrowseFeatures
local BuildCategoryChoices = Filters._BuildCategoryChoices

local TraceFilters = (BETTERUI.Log and BETTERUI.Log.MakeTracer)
    and BETTERUI.Log.MakeTracer{ module = "TradingHouse", feature = "browse-filters", category = BETTERUI.Log.CATEGORY.SEARCH }
    or function() end

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

        local function TrackDialogDropdown(dialog, dropdown)
            if not (dialog and dropdown) then return end
            dialog.data = dialog.data or {}
            dialog.data._activeDropdown = dropdown
            dialog.data._ownedDropdowns = dialog.data._ownedDropdowns or {}
            dialog.data._ownedDropdowns[dropdown] = true
        end

        local function ReleaseDropdown(dropdown)
            if not dropdown then return false end
            -- The menu is a shared top-level control. Deactivate releases its
            -- keybind layer, while HideDropdown guarantees the control itself
            -- cannot survive a dialog or scene transition.
            if dropdown.HideDropdown then
                TryCall(dropdown.HideDropdown, dropdown)
            end
            if dropdown.Deactivate then
                TryCall(dropdown.Deactivate, dropdown)
            end
            return true
        end

        local function RestoreTradingHouseFocus()
            local instance = TH.instance
            if not (instance and instance.IsSceneShowing and instance:IsSceneShowing()) then return end
            if instance.UpdateTabHeader then
                instance:UpdateTabHeader()
            end
            if instance.list and instance.list.Activate then
                TryCall(instance.list.Activate, instance.list)
            end
            if TH.RefreshCurrentTradingHouseKeybinds then
                TH.RefreshCurrentTradingHouseKeybinds(
                    "BrowseFilterDialog:finishedCallback", "filterDialogClosed", true)
            end
            TraceFilters("trading_house.filters_dialog", "focus_restored", {
                fn = "Filters.ShowFilterDialog",
                listActivated = instance.list and instance.list.Activate ~= nil,
                headerRefreshed = instance.UpdateTabHeader ~= nil,
            })
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
                            TrackDialogDropdown(dialog, dropdown)
                            TryCall(dropdown.Activate, dropdown)
                        end
                    end,
                    narrationText = rawget(_G, "ZO_GetDefaultParametricListDropdownNarrationText"),
                },
            }
        end

        local BuildFilterParametricList
        local usingNativeHierarchy = false

        local function SetDropdownFocusFont(dropdown, selected)
            local label = dropdown and dropdown.m_selectedItemText
            if not (label and label.SetFont) then return end
            local font = selected
                and (rawget(_G, "ZO_GAMEPAD_COMBO_BOX_HIGHLIGHTED_FONT") or "ZoFontGamepad36")
                or (rawget(_G, "ZO_GAMEPAD_COMBO_BOX_FONT") or "ZoFontGamepad27")
            TryCall(label.SetFont, label, font)
            if label.SetWidth and dropdown.m_container and dropdown.m_container.GetWidth then
                local width = dropdown.m_container:GetWidth()
                local ratio = selected and 1 or (dropdown.m_fontRatio or 1)
                TryCall(label.SetWidth, label, width * ratio)
            end
        end

        local function ScheduleFilterDialogRebuild(dialog)
            if not (dialog and dialog.data) or dialog.data._filterRebuildScheduled then return end
            dialog.data._filterRebuildScheduled = true
            local function Rebuild()
                if not (dialog and dialog.data) then return end
                dialog.data._filterRebuildScheduled = nil
                if ZO_Dialogs_IsShowingDialog
                    and not ZO_Dialogs_IsShowingDialog(FILTER_DIALOG_NAME) then
                    return
                end
                dialog.info.parametricList = BuildFilterParametricList()
                dialog:setupFunc()
                TraceFilters("trading_house.filters_dialog", "hierarchy_rebuilt", {
                    fn = "Filters.ShowFilterDialog",
                    entryCount = #dialog.info.parametricList,
                })
            end
            if type(zo_callLater) == "function" then
                zo_callLater(Rebuild, 0)
            else
                Rebuild()
            end
        end

        local function AddNativeDropdown(nativeData, header)
            return {
                template = "ZO_GamepadDropdownItem",
                headerTemplate = "ZO_GamepadMenuEntryFullWidthHeaderTemplate",
                header = header,
                templateData = {
                    setup = function(control, data, selected)
                        local dialog = data and data.dialog or GetDialog()
                        local dropdown = control and control.dropdown
                        if not dropdown then return end
                        TryCall(dropdown.SetSortsItems, dropdown, false)
                        if nativeData and nativeData.setupCallback then
                            TryCall(nativeData.setupCallback, dropdown)
                        end
                        SetDropdownFocusFont(dropdown, selected == true)
                        if dropdown.SetDeactivatedCallback then
                            dropdown:SetDeactivatedCallback(function()
                                if dialog and dialog.data then
                                    dialog.data._activeDropdown = nil
                                end
                                ScheduleFilterDialogRebuild(dialog)
                            end)
                        end
                        if SCREEN_NARRATION_MANAGER and SCREEN_NARRATION_MANAGER.RegisterDialogDropdown then
                            TryCall(SCREEN_NARRATION_MANAGER.RegisterDialogDropdown,
                                SCREEN_NARRATION_MANAGER, dialog, dropdown)
                        end
                    end,
                    callback = function(dialog)
                        local targetControl = dialog and dialog.entryList
                            and dialog.entryList.GetTargetControl
                            and dialog.entryList:GetTargetControl() or nil
                        local dropdown = targetControl and targetControl.dropdown
                        if dropdown and dropdown.Activate then
                            TrackDialogDropdown(dialog, dropdown)
                            TryCall(dropdown.Activate, dropdown)
                        end
                    end,
                    narrationText = nativeData and nativeData.narrationText
                        or rawget(_G, "ZO_GetDefaultParametricListDropdownNarrationText"),
                },
            }
        end

        local function AddNativeFeatureEntry(templateName, nativeData, header)
            if templateName == "ZO_GamepadGuildStoreBrowseDropdownTemplate" then
                return AddNativeDropdown(nativeData, header)
            end

            local setup
            if templateName == "ZO_GamepadGuildStoreBrowseSliderTemplate" then
                setup = function(control, data, selected)
                    data.onValueChangedCallback = function()
                        local dialog = data.dialog or GetDialog()
                        if SCREEN_NARRATION_MANAGER and SCREEN_NARRATION_MANAGER.QueueDialog then
                            TryCall(SCREEN_NARRATION_MANAGER.QueueDialog,
                                SCREEN_NARRATION_MANAGER, dialog)
                        end
                    end
                    if data.feature and data.feature.SetupSlider then
                        TryCall(data.feature.SetupSlider, data.feature, control, data, selected)
                    end
                end
            elseif templateName == "ZO_GamepadPriceSelectorTemplate" then
                setup = function(control, data, selected, reselecting, enabled, active)
                    if data.feature and data.feature.SetupPriceSelector then
                        TryCall(data.feature.SetupPriceSelector, data.feature, control, data,
                            selected, reselecting, enabled, active)
                    end
                end
            else
                return nil
            end

            local templateData = { setup = setup }
            if type(nativeData) == "table" then
                for key, value in pairs(nativeData) do
                    templateData[key] = value
                end
                templateData.setup = setup
            end
            return {
                template = templateName,
                headerTemplate = "ZO_GamepadMenuEntryFullWidthHeaderTemplate",
                header = header,
                templateData = templateData,
            }
        end

        local function CaptureNativeFeatureEntries(features)
            local captured = {}
            local adapter = {}
            function adapter:AddEntry(templateName, entryData)
                captured[#captured + 1] = {
                    template = templateName,
                    entryData = entryData,
                }
            end
            function adapter:AddEntryWithHeader(templateName, entryData)
                local header = entryData and entryData.GetHeader
                    and SafeCall(entryData.GetHeader, entryData) or entryData and entryData.header
                captured[#captured + 1] = {
                    template = templateName,
                    entryData = entryData,
                    header = header,
                }
            end

            local orderedFeatures = {
                features and features.searchCategoryFeature,
                features and features.priceRangeFeature,
                features and features.qualityFeature,
            }
            for _, feature in ipairs(orderedFeatures) do
                if feature and feature.AddEntries then
                    TryCall(feature.AddEntries, feature, adapter)
                end
            end
            return captured
        end

        local function AddRecentSearchesEntry()
            local label = L("SI_TRADING_HOUSE_SEARCH_HISTORY_TITLE", "Recent Searches")
            return {
                template = "ZO_GamepadMenuEntryTemplate",
                text = label,
                templateData = {
                    setup = function(control)
                        if control and control.label and control.label.SetText then
                            control.label:SetText(label)
                        end
                    end,
                    narrationText = function()
                        if SCREEN_NARRATION_MANAGER
                            and SCREEN_NARRATION_MANAGER.CreateNarratableObject then
                            return SCREEN_NARRATION_MANAGER:CreateNarratableObject(label)
                        end
                        return label
                    end,
                    callback = function(dialog)
                        if type(TH.OpenNativeSearchHistory) ~= "function" then
                            TraceFilters("trading_house.filters_dialog", "recent_searches_skipped", {
                                fn = "Filters.ShowFilterDialog",
                                reason = "missingNativeHistoryHandoff",
                            })
                            return
                        end
                        dialog.data = dialog.data or {}
                        dialog.data._handoffToNative = true
                        TraceFilters("trading_house.filters_dialog", "recent_searches", {
                            fn = "Filters.ShowFilterDialog",
                        })
                        if ZO_Dialogs_ReleaseDialogOnButtonPress then
                            ZO_Dialogs_ReleaseDialogOnButtonPress(FILTER_DIALOG_NAME)
                        end
                        local function OpenHistory()
                            if not TH.OpenNativeSearchHistory("editFiltersRecentSearches") then
                                RestoreTradingHouseFocus()
                            end
                        end
                        if type(zo_callLater) == "function" then
                            zo_callLater(OpenHistory, 0)
                        else
                            OpenHistory()
                        end
                    end,
                },
            }
        end

        BuildFilterParametricList = function()
            local rows = {
                AddRecentSearchesEntry(),
                AddTextField("SI_BETTERUI_TH_FILTER_NAME", "nameText", false),
            }
            local features = GetBrowseFeatures()
            local nativeEntries = CaptureNativeFeatureEntries(features)
            usingNativeHierarchy = #nativeEntries > 0
            for _, nativeEntry in ipairs(nativeEntries) do
                local row = AddNativeFeatureEntry(
                    nativeEntry.template, nativeEntry.entryData, nativeEntry.header)
                if row then rows[#rows + 1] = row end
            end

            -- Compatibility fallback for stripped test/runtime environments.
            if #nativeEntries == 0 then
                rows[#rows + 1] = AddDropdownField(
                    "SI_BETTERUI_TH_FILTER_CATEGORY", "categoryIndex", BuildCategoryChoices)
                rows[#rows + 1] = AddTextField(
                    "SI_BETTERUI_TH_FILTER_PRICE_MIN", "priceMin", true)
                rows[#rows + 1] = AddTextField(
                    "SI_BETTERUI_TH_FILTER_PRICE_MAX", "priceMax", true)
                rows[#rows + 1] = AddDropdownField(
                    "SI_BETTERUI_TH_FILTER_QUALITY", "qualityIndex", BuildQualityChoices)
            end
            return rows
        end

        local function SubmitDialog(dialog)
            local data = dialog and dialog.data or {}
            -- Blank price boxes must explicitly reset the native price feature;
            -- omitted nils would leave a previous range untouched.
            local spec = {
                nameText = data.nameText or "",
            }
            if not data._usingNativeHierarchy then
                -- Compatibility fallback fields are only applied when native
                -- feature rows were unavailable.
                spec.priceMin = data.priceMin or 0
                spec.priceMax = data.priceMax or 0
                spec.qualityIndex = data.qualityIndex or 1
                spec.categoryIndex = data.categoryIndex or 1
            end

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
                dialog.info.parametricList = BuildFilterParametricList()
                dialog.data._usingNativeHierarchy = usingNativeHierarchy
                dialog:setupFunc()
            end,
            finishedCallback = function(dialog)
                local data = dialog and dialog.data
                local handoffToNative = data and data._handoffToNative == true
                local activeDropdown = data and data._activeDropdown
                local releasedCount = 0
                if data and data._ownedDropdowns then
                    for dropdown in pairs(data._ownedDropdowns) do
                        if ReleaseDropdown(dropdown) then
                            releasedCount = releasedCount + 1
                        end
                    end
                elseif ReleaseDropdown(activeDropdown) then
                    releasedCount = 1
                end
                if data then
                    data._activeDropdown = nil
                    data._ownedDropdowns = nil
                    data._filterRebuildScheduled = nil
                    data._handoffToNative = nil
                end
                TraceFilters("trading_house.filters_dialog", "finished", {
                    fn = "Filters.ShowFilterDialog",
                    releasedInput = releasedCount > 0,
                    releasedCount = releasedCount,
                    handoffToNative = handoffToNative,
                })
                if not handoffToNative then
                    if type(zo_callLater) == "function" then
                        zo_callLater(RestoreTradingHouseFocus, 0)
                    else
                        RestoreTradingHouseFocus()
                    end
                end
            end,
            parametricList = {},
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
                        local features = GetBrowseFeatures()
                        if dialog.data._usingNativeHierarchy and features then
                            for _, feature in pairs(features) do
                                if feature and feature.ResetSearch then
                                    TryCall(feature.ResetSearch, feature)
                                end
                            end
                        end
                        TraceFilters("trading_house.filters_dialog", "reset", {
                            fn = "Filters.ShowFilterDialog",
                        })
                        dialog.info.parametricList = BuildFilterParametricList()
                        dialog.data._usingNativeHierarchy = usingNativeHierarchy
                        if dialog.setupFunc then
                            dialog:setupFunc()
                        end
                        if SCREEN_NARRATION_MANAGER and SCREEN_NARRATION_MANAGER.QueueDialog then
                            TryCall(SCREEN_NARRATION_MANAGER.QueueDialog,
                                SCREEN_NARRATION_MANAGER, dialog)
                        end
                    end,
                },
            },
        }
        if not (Dialogs and Dialogs.RegisterWithPriorChain
            and Dialogs.RegisterWithPriorChain(FILTER_DIALOG_NAME, dialogInfo)) then
            TraceFilters("trading_house.filters_dialog", "show_skipped", {
                fn = "Filters.ShowFilterDialog",
                reason = "registryRejected",
            })
            return
        end
    end

    TraceFilters("trading_house.filters_dialog", "shown", {
        fn = "Filters.ShowFilterDialog",
    })
    BETTERUI.CIM.Dialogs.ShowForOwner(TH.instance, FILTER_DIALOG_NAME, {})
end
