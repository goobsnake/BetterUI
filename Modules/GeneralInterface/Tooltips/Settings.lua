if BETTERUI == nil then BETTERUI = {} end
if BETTERUI.GeneralInterface == nil then BETTERUI.GeneralInterface = {} end

-- Import shared helpers from SettingsHelpers.lua
local H = assert(BETTERUI.GeneralInterface._SettingsHelpers,
    "BetterUI: load GeneralInterface/Tooltips/SettingsHelpers.lua before Settings.lua")
local ApplyTooltipVisualSettings = H.ApplyTooltipVisualSettings
local RestoreTooltipVisualSettings = H.RestoreTooltipVisualSettings
local CleanupTooltipEnhancementArtifacts = H.CleanupTooltipEnhancementArtifacts
local RefreshInventoryAndBankingLists = H.RefreshInventoryAndBankingLists
local GetMetadataDefault = H.GetMetadataDefault
local GetSettingDependencyAddons = H.GetSettingDependencyAddons
local IsAnyAddonDependencyLoaded = H.IsAnyAddonDependencyLoaded
local BuildAddonDependencyTooltip = H.BuildAddonDependencyTooltip
local GetModuleSettings = H.GetModuleSettings
local EnsureModuleSettings = H.EnsureModuleSettings
local IsCIMEnabled = H.IsCIMEnabled
local ParseIntegerInput = H.ParseIntegerInput
local ResetGeneralInterfaceGeneralSettings = H.ResetGeneralInterfaceGeneralSettings
local ResetMarketIntegrationSettings = H.ResetMarketIntegrationSettings
local ResetEnhancedTooltipSettings = H.ResetEnhancedTooltipSettings

local function SetModuleSetting(moduleName, key, value)
    if type(BETTERUI.SetSetting) == "function" then
        return BETTERUI.SetSetting(moduleName, key, value)
    end

    local settings = EnsureModuleSettings(moduleName)
    if settings then
        settings[key] = value
        return true
    end
    return false
end

local function GetCurrentSceneName()
    if SCENE_MANAGER and type(SCENE_MANAGER.GetCurrentSceneName) == "function" then
        local ok, sceneName = pcall(function() return SCENE_MANAGER:GetCurrentSceneName() end)
        if ok then return sceneName end
    end
    return nil
end

local function TraceGeneralSetting(settingName, phase, data)
    local L = BETTERUI and BETTERUI.Log or nil
    if not L or type(L.TraceEvent) ~= "function" then return end
    local payload = data or {}
    payload.module = "GeneralInterface"
    payload.feature = "settings"
    payload.setting = settingName
    payload.scene = GetCurrentSceneName()
    payload.gamepad = IsInGamepadPreferredMode and IsInGamepadPreferredMode() or nil
    if type(L.SetLastAction) == "function" then
        L.SetLastAction("GeneralInterface.settings." .. tostring(settingName))
    end
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.SETTING or categories.GENERAL, "general_interface.setting", phase, payload)
end

local function ResolveSettingTraceName(control, groupKey)
    if type(control) ~= "table" then return groupKey or "unknown" end
    return control.key or control.reference or control.name or control.type or groupKey or "unknown"
end

local function CapturePcallResults(ok, ...)
    return { ok = ok, n = select("#", ...), ... }
end

local function WrapGeneralInterfaceSettingControls(controls, groupKey)
    if type(controls) ~= "table" then return end
    for index, control in ipairs(controls) do
        if type(control) == "table" then
            local settingName = ResolveSettingTraceName(control, groupKey)
            if type(control.setFunc) == "function" and not control._betteruiLogWrappedSetFunc then
                local originalSetFunc = control.setFunc
                control.setFunc = function(value, ...)
                    local oldValue = nil
                    if type(control.getFunc) == "function" then
                        local okOld, oldResult = pcall(control.getFunc)
                        if okOld then oldValue = oldResult end
                    end
                    TraceGeneralSetting(settingName, "set_begin", {
                        type = control.type,
                        group = groupKey,
                        index = index,
                        oldValue = oldValue,
                        newValue = value,
                    })
                    local results = CapturePcallResults(pcall(originalSetFunc, value, ...))
                    if not results.ok then
                        TraceGeneralSetting(settingName, "set_error", {
                            type = control.type,
                            group = groupKey,
                            index = index,
                            oldValue = oldValue,
                            newValue = value,
                            error = tostring(results[1]),
                        })
                        error(results[1], 2)
                    end
                    local appliedValue = value
                    if type(control.getFunc) == "function" then
                        local okApplied, appliedResult = pcall(control.getFunc)
                        if okApplied then appliedValue = appliedResult end
                    end
                    TraceGeneralSetting(settingName, "set_end", {
                        type = control.type,
                        group = groupKey,
                        index = index,
                        oldValue = oldValue,
                        newValue = value,
                        appliedValue = appliedValue,
                        changed = oldValue ~= appliedValue,
                    })
                    return unpack(results, 1, results.n)
                end
                control._betteruiLogWrappedSetFunc = true
            end
            if type(control.func) == "function" and not control._betteruiLogWrappedFunc then
                local originalFunc = control.func
                control.func = function(...)
                    TraceGeneralSetting(settingName, "button_begin", { type = control.type, group = groupKey, index = index })
                    local results = CapturePcallResults(pcall(originalFunc, ...))
                    if not results.ok then
                        TraceGeneralSetting(settingName, "button_error", { type = control.type, group = groupKey, index = index, error = tostring(results[1]) })
                        error(results[1], 2)
                    end
                    TraceGeneralSetting(settingName, "button_end", { type = control.type, group = groupKey, index = index })
                    return unpack(results, 1, results.n)
                end
                control._betteruiLogWrappedFunc = true
            end
            if type(control.controls) == "table" then
                WrapGeneralInterfaceSettingControls(control.controls, tostring(settingName))
            end
        end
    end
end

function BETTERUI.GeneralInterface.GetSettingsOptions()
    local styleTraitIcon = ""
    local icons = BETTERUI.CIM and BETTERUI.CIM.CONST and BETTERUI.CIM.CONST.ICONS
    local traitIcon = icons and icons.RESEARCHABLE_TRAIT
    if traitIcon then
        styleTraitIcon = zo_iconFormat(traitIcon, 24, 24) .. " "
    end
    local knowledgeStatusIcon = ""
    local bookIcon = icons and icons.BOOK_UNKNOWN
    if bookIcon then
        knowledgeStatusIcon = zo_iconFormat(bookIcon, 24, 24) .. " "
    end

    local marketPriorityChoices = {}
    local marketPriorityValues = {}
    if BETTERUI.CIM
        and BETTERUI.CIM.MarketIntegration
        and type(BETTERUI.CIM.MarketIntegration.GetPriorityChoices) == "function" then
        local choices, values = BETTERUI.CIM.MarketIntegration.GetPriorityChoices()
        marketPriorityChoices = choices
        marketPriorityValues = values
    end

    local function ResolveMarketAddonDependencies(settingKey)
        local dependencyAddons = GetSettingDependencyAddons("GeneralInterface", settingKey)
        if type(dependencyAddons) == "table" and #dependencyAddons > 0 then
            return dependencyAddons
        end
        return {}
    end

    local guildStoreAddonDeps = ResolveMarketAddonDependencies("guildStoreErrorSuppress")
    local attAddonDeps = ResolveMarketAddonDependencies("attIntegration")
    local mmAddonDeps = ResolveMarketAddonDependencies("mmIntegration")
    local ttcAddonDeps = ResolveMarketAddonDependencies("ttcIntegration")

    local function GetOptionalAddonToggleValue(settingKey, addonDeps)
        if not IsAnyAddonDependencyLoaded(addonDeps) then
            return false
        end

        local settings = GetModuleSettings("GeneralInterface")
        if not settings then
            return GetMetadataDefault("GeneralInterface", settingKey, true)
        end

        local value = settings[settingKey]
        if value == nil then
            return GetMetadataDefault("GeneralInterface", settingKey, true)
        end
        return value
    end

    local tooltipGuildStoreError = BuildAddonDependencyTooltip(
        SI_BETTERUI_GS_ERROR_SUPPRESS_TOOLTIP,
        guildStoreAddonDeps,
        true
    )
    local tooltipATT = BuildAddonDependencyTooltip(
        SI_BETTERUI_ATT_INTEGRATION_TOOLTIP,
        attAddonDeps,
        false
    )
    local tooltipMM = BuildAddonDependencyTooltip(
        SI_BETTERUI_MM_INTEGRATION_TOOLTIP,
        mmAddonDeps,
        false
    )
    local tooltipTTC = BuildAddonDependencyTooltip(
        SI_BETTERUI_TTC_INTEGRATION_TOOLTIP,
        ttcAddonDeps,
        false
    )

    local generalControls = {
        {
            type = "editbox",
            name = GetString(rawget(_G, "SI_BETTERUI_CHAT_HISTORY")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_CHAT_HISTORY_TOOLTIP")),
            getFunc = function()
                local settings = GetModuleSettings("GeneralInterface")
                local value = (settings and settings.chatHistory) or
                    GetMetadataDefault("GeneralInterface", "chatHistory", 200)
                return tostring(value)
            end,
            setFunc = function(value)
                local settings = EnsureModuleSettings("GeneralInterface")
                if not settings then
                    return
                end
                local defaultValue = GetMetadataDefault("GeneralInterface", "chatHistory", 200)
                local currentValue = tonumber(settings.chatHistory) or defaultValue
                local parsedValue = ParseIntegerInput(value, currentValue, 1, 5000)
                settings.chatHistory = parsedValue
                local generalInterface = BETTERUI.GeneralInterface
                if generalInterface and generalInterface.ApplyChatHistoryLimit then
                    generalInterface.ApplyChatHistoryLimit(parsedValue)
                end
            end,
            default = GetMetadataDefault("GeneralInterface", "chatHistory", 200),
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(rawget(_G, "SI_BETTERUI_REMOVE_DELETE_MAIL_CONFIRM")),
            warning = GetString(rawget(_G, "SI_BETTERUI_REMOVE_DELETE_WARNING")),
            getFunc = function()
                local settings = GetModuleSettings("GeneralInterface")
                if not settings or settings.removeDeleteDialog == nil then
                    return GetMetadataDefault("GeneralInterface", "removeDeleteDialog", false)
                end
                return settings.removeDeleteDialog
            end,
            setFunc = function(value)
                local settings = EnsureModuleSettings("GeneralInterface")
                if settings then
                    settings.removeDeleteDialog = value
                end
            end,
            default = GetMetadataDefault("GeneralInterface", "removeDeleteDialog", false),
            width = "full",
        },

        {
            type = "editbox",
            name = GetString(rawget(_G, "SI_BETTERUI_MOUSE_SCROLL_SPEED")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_MOUSE_SCROLL_SPEED_TOOLTIP")),
            getFunc = function()
                local settings = GetModuleSettings("CIM")
                local value = (settings and settings.rhScrollSpeed) or GetMetadataDefault("CIM", "rhScrollSpeed", 50)
                return tostring(value)
            end,
            setFunc = function(value)
                local settings = EnsureModuleSettings("CIM")
                if settings then
                    local defaultValue = GetMetadataDefault("CIM", "rhScrollSpeed", 50)
                    local currentValue = tonumber(settings.rhScrollSpeed) or defaultValue
                    SetModuleSetting("CIM", "rhScrollSpeed", ParseIntegerInput(value, currentValue, 1, 1000))
                end
            end,
            disabled = function() return not IsCIMEnabled() end,
            width = "full",
        },

        {
            type = "button",
            name = GetString(rawget(_G, "SI_BETTERUI_GENERAL_RESET")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_GENERAL_RESET_TOOLTIP")),
            func = function()
                ResetGeneralInterfaceGeneralSettings()
            end,
            width = "half",
        },
    }

    local marketIntegrationControls = {
        {
            type = "description",
            text = GetString(rawget(_G, "SI_BETTERUI_MARKET_INTEGRATION_DESC")),
            width = "full",
        },
        {
            type = "checkbox",
            key = "showMarketPrice",
            name = GetString(rawget(_G, "SI_BETTERUI_SHOW_MARKET_PRICE")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_SHOW_MARKET_PRICE_TOOLTIP")),
            getFunc = function()
                local settings = GetModuleSettings("GeneralInterface")
                if not settings then return true end
                if settings.showMarketPrice == nil then return true end
                return settings.showMarketPrice
            end,
            setFunc = function(value)
                local settings = EnsureModuleSettings("GeneralInterface")
                if settings then
                    settings.showMarketPrice = value
                end
                RefreshInventoryAndBankingLists()
            end,
            default = GetMetadataDefault("GeneralInterface", "showMarketPrice", true),
            width = "full",
        },
        {
            type = "dropdown",
            key = "marketPricePriority",
            name = GetString(rawget(_G, "SI_BETTERUI_MARKET_PRICE_PRIORITY")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_MARKET_PRICE_PRIORITY_TOOLTIP")),
            choices = marketPriorityChoices,
            choicesValues = marketPriorityValues,
            getFunc = function()
                local settings = GetModuleSettings("GeneralInterface")
                if not settings then
                    return GetMetadataDefault("GeneralInterface", "marketPricePriority", "mm_att_ttc")
                end
                return settings.marketPricePriority or
                    GetMetadataDefault("GeneralInterface", "marketPricePriority", "mm_att_ttc")
            end,
            setFunc = function(value)
                local settings = EnsureModuleSettings("GeneralInterface")
                if settings then
                    settings.marketPricePriority = value
                end
                RefreshInventoryAndBankingLists()
            end,
            default = GetMetadataDefault("GeneralInterface", "marketPricePriority", "mm_att_ttc"),
            width = "full",
            scrollable = true,
        },
        {
            type = "checkbox",
            key = "showCraftingMarketPrice",
            name = GetString(rawget(_G, "SI_BETTERUI_SHOW_CRAFTING_MARKET_PRICE")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_SHOW_CRAFTING_MARKET_PRICE_TOOLTIP")),
            getFunc = function()
                local settings = GetModuleSettings("GeneralInterface")
                if not settings then return true end
                if settings.showCraftingMarketPrice == nil then return true end
                return settings.showCraftingMarketPrice
            end,
            setFunc = function(value)
                local settings = EnsureModuleSettings("GeneralInterface")
                if settings then
                    settings.showCraftingMarketPrice = value
                end
            end,
            default = GetMetadataDefault("GeneralInterface", "showCraftingMarketPrice", true),
            width = "full",
        },
        {
            type = "checkbox",
            key = "guildStoreErrorSuppress",
            name = GetString(rawget(_G, "SI_BETTERUI_GS_ERROR_SUPPRESS")),
            tooltip = tooltipGuildStoreError,
            getFunc = function()
                local settings = GetModuleSettings("GeneralInterface")
                if not settings or settings.guildStoreErrorSuppress == nil then
                    return GetMetadataDefault("GeneralInterface", "guildStoreErrorSuppress", true)
                end
                return settings.guildStoreErrorSuppress
            end,
            setFunc = function(value)
                local settings = EnsureModuleSettings("GeneralInterface")
                if settings then
                    settings.guildStoreErrorSuppress = value
                end
            end,
            disabled = function() return not IsAnyAddonDependencyLoaded(guildStoreAddonDeps) end,
            default = GetMetadataDefault("GeneralInterface", "guildStoreErrorSuppress", true),
            width = "full",
        },
        {
            type = "checkbox",
            key = "attIntegration",
            name = GetString(rawget(_G, "SI_BETTERUI_ATT_INTEGRATION")),
            tooltip = tooltipATT,
            getFunc = function()
                return GetOptionalAddonToggleValue("attIntegration", attAddonDeps)
            end,
            setFunc = function(value)
                local settings = EnsureModuleSettings("GeneralInterface")
                if settings then
                    settings.attIntegration = value
                end
            end,
            disabled = function() return not IsAnyAddonDependencyLoaded(attAddonDeps) end,
            default = GetMetadataDefault("GeneralInterface", "attIntegration", true),
            width = "full",
        },
        {
            type = "checkbox",
            key = "mmIntegration",
            name = GetString(rawget(_G, "SI_BETTERUI_MM_INTEGRATION")),
            tooltip = tooltipMM,
            getFunc = function()
                return GetOptionalAddonToggleValue("mmIntegration", mmAddonDeps)
            end,
            setFunc = function(value)
                local settings = EnsureModuleSettings("GeneralInterface")
                if settings then
                    settings.mmIntegration = value
                end
            end,
            disabled = function() return not IsAnyAddonDependencyLoaded(mmAddonDeps) end,
            default = GetMetadataDefault("GeneralInterface", "mmIntegration", true),
            width = "full",
        },
        {
            type = "checkbox",
            key = "ttcIntegration",
            name = GetString(rawget(_G, "SI_BETTERUI_TTC_INTEGRATION")),
            tooltip = tooltipTTC,
            getFunc = function()
                return GetOptionalAddonToggleValue("ttcIntegration", ttcAddonDeps)
            end,
            setFunc = function(value)
                local settings = EnsureModuleSettings("GeneralInterface")
                if settings then
                    settings.ttcIntegration = value
                end
            end,
            disabled = function() return not IsAnyAddonDependencyLoaded(ttcAddonDeps) end,
            default = GetMetadataDefault("GeneralInterface", "ttcIntegration", true),
            width = "full",
        },
    }

    local enhancedTooltipControls = {
        {
            type = "description",
            text = GetString(rawget(_G, "SI_BETTERUI_ENHANCED_TOOLTIPS_DESC")),
            width = "full",
        },
        {
            type = "checkbox",
            key = "enableTooltipEnhancements",
            name = GetString(rawget(_G, "SI_BETTERUI_ENABLE_TOOLTIP_ENHANCEMENTS")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_ENABLE_TOOLTIP_ENHANCEMENTS_TOOLTIP")),
            sortAlwaysFirst = true,
            getFunc = function()
                local settings = GetModuleSettings("CIM")
                if not settings then
                    return GetMetadataDefault("CIM", "enableTooltipEnhancements", true)
                end
                if settings.enableTooltipEnhancements == nil then
                    return GetMetadataDefault("CIM", "enableTooltipEnhancements", true)
                end
                return settings.enableTooltipEnhancements
            end,
            setFunc = function(value)
                SetModuleSetting("CIM", "enableTooltipEnhancements", value)
                if value then
                    ApplyTooltipVisualSettings()
                    local tooltipTypes = { GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP, GAMEPAD_MOVABLE_TOOLTIP }
                    for _, tooltipType in ipairs(tooltipTypes) do
                        if GAMEPAD_TOOLTIPS and GAMEPAD_TOOLTIPS.ClearTooltip then
                            GAMEPAD_TOOLTIPS:ClearTooltip(tooltipType)
                        end
                    end
                else
                    RestoreTooltipVisualSettings()
                    CleanupTooltipEnhancementArtifacts()
                    local tooltipTypes = { GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP, GAMEPAD_MOVABLE_TOOLTIP }
                    -- PB-003: force any currently-showing tooltip to re-render in
                    -- stock mode so the visible item reverts immediately rather
                    -- than only on the next hover. Cleanup above already reversed
                    -- the enhanced control-instance state; this drives the native
                    -- stock layout branch on top of the stock state.
                    local sharedItemSupport = BETTERUI.CIM and BETTERUI.CIM.SharedItemSupport
                    for _, tooltipType in ipairs(tooltipTypes) do
                        if sharedItemSupport and type(sharedItemSupport.UpdateTooltipEquippedText) == "function" then
                            sharedItemSupport.UpdateTooltipEquippedText(tooltipType, nil)
                        end
                        if GAMEPAD_TOOLTIPS and GAMEPAD_TOOLTIPS.ClearTooltip then
                            GAMEPAD_TOOLTIPS:ClearTooltip(tooltipType)
                        end
                    end
                end
            end,
            width = "full",
            default = GetMetadataDefault("CIM", "enableTooltipEnhancements", true),
        },
        {
            type = "checkbox",
            name = styleTraitIcon .. GetString(rawget(_G, "SI_BETTERUI_SHOW_STYLE_TRAIT")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_SHOW_STYLE_TRAIT_TOOLTIP")),
            getFunc = function()
                local settings = GetModuleSettings("GeneralInterface")
                if not settings then
                    return GetMetadataDefault("GeneralInterface", "showStyleTrait", true)
                end
                local value = settings.showStyleTrait
                if value == nil then
                    return GetMetadataDefault("GeneralInterface", "showStyleTrait", true)
                end
                return value
            end,
            setFunc = function(value)
                local settings = EnsureModuleSettings("GeneralInterface")
                if settings then
                    settings.showStyleTrait = value
                end
            end,
            disabled = function()
                local cimSettings = GetModuleSettings("CIM")
                if not cimSettings then return true end
                if cimSettings.enableTooltipEnhancements == nil then return false end
                return cimSettings.enableTooltipEnhancements ~= true
            end,
            width = "full",
            default = GetMetadataDefault("GeneralInterface", "showStyleTrait", true),
        },
        {
            type = "checkbox",
            name = knowledgeStatusIcon .. GetString(rawget(_G, "SI_BETTERUI_SHOW_KNOWLEDGE_STATUS")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_SHOW_KNOWLEDGE_STATUS_TOOLTIP")),
            getFunc = function()
                local settings = GetModuleSettings("GeneralInterface")
                if not settings then
                    return GetMetadataDefault("GeneralInterface", "showKnowledgeStatus", true)
                end
                local value = settings.showKnowledgeStatus
                if value == nil then
                    return GetMetadataDefault("GeneralInterface", "showKnowledgeStatus", true)
                end
                return value
            end,
            setFunc = function(value)
                local settings = EnsureModuleSettings("GeneralInterface")
                if settings then
                    settings.showKnowledgeStatus = value
                end
            end,
            disabled = function()
                local cimSettings = GetModuleSettings("CIM")
                if not cimSettings then return true end
                if cimSettings.enableTooltipEnhancements == nil then return false end
                return cimSettings.enableTooltipEnhancements ~= true
            end,
            width = "full",
            default = GetMetadataDefault("GeneralInterface", "showKnowledgeStatus", true),
        },
        {
            type = "checkbox",
            name = GetString(rawget(_G, "SI_BETTERUI_SHOW_ITEM_COMPARISON")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_SHOW_ITEM_COMPARISON_TOOLTIP")),
            getFunc = function()
                local settings = GetModuleSettings("GeneralInterface")
                if not settings then
                    return GetMetadataDefault("GeneralInterface", "showItemComparison", true)
                end
                local value = settings.showItemComparison
                if value == nil then
                    return GetMetadataDefault("GeneralInterface", "showItemComparison", true)
                end
                return value
            end,
            setFunc = function(value)
                local settings = EnsureModuleSettings("GeneralInterface")
                if settings then
                    settings.showItemComparison = value
                end
            end,
            disabled = function()
                local cimSettings = GetModuleSettings("CIM")
                if not cimSettings then return true end
                if cimSettings.enableTooltipEnhancements == nil then return false end
                return cimSettings.enableTooltipEnhancements ~= true
            end,
            width = "full",
            default = GetMetadataDefault("GeneralInterface", "showItemComparison", true),
        },
        {
            type = "slider",
            name = GetString(rawget(_G, "SI_BETTERUI_TOOLTIP_FONT_SIZE")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_TOOLTIP_FONT_SIZE_TOOLTIP")),
            min = BETTERUI.CIM.Font.SIZE_MIN or 12,
            max = BETTERUI.CIM.Font.SIZE_MAX or 48,
            step = 1,
            getFunc = function()
                local settings = GetModuleSettings("CIM")
                local val = 24
                if settings then
                    val = settings.tooltipSize or val
                end

                if BETTERUI.CIM.Font and type(BETTERUI.CIM.Font.GetSizeValue) == "function" then
                    return BETTERUI.CIM.Font.GetSizeValue(val)
                end
                return val
            end,
            setFunc = function(value)
                SetModuleSetting("CIM", "tooltipSize", value)
                ApplyTooltipVisualSettings()
            end,
            disabled = function()
                local settings = GetModuleSettings("CIM")
                if not settings then return true end
                return settings.enableTooltipEnhancements ~= true
            end,
            width = "full",
            default = GetMetadataDefault("CIM", "tooltipSize", 24),
        },
        {
            type = "button",
            name = GetString(rawget(_G, "SI_BETTERUI_ENHANCED_TOOLTIPS_RESET")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_ENHANCED_TOOLTIPS_RESET_TOOLTIP")),
            func = function()
                ResetEnhancedTooltipSettings()
            end,
            width = "half",
        },
    }

    table.insert(marketIntegrationControls, {
        type = "button",
        key = "marketIntegrationReset",
        name = GetString(rawget(_G, "SI_BETTERUI_MARKET_INTEGRATION_RESET")),
        tooltip = GetString(rawget(_G, "SI_BETTERUI_MARKET_INTEGRATION_RESET_TOOLTIP")),
        func = function()
            ResetMarketIntegrationSettings()
        end,
        width = "half",
    })

    if BETTERUI.CIM.Settings and type(BETTERUI.CIM.Settings.SortSettingsAlphabetically) == "function" then
        BETTERUI.CIM.Settings.SortSettingsAlphabetically(generalControls, false)
        BETTERUI.CIM.Settings.SortSettingsAlphabetically(marketIntegrationControls, false)
        BETTERUI.CIM.Settings.SortSettingsAlphabetically(enhancedTooltipControls, false)
    end

    table.insert(generalControls, {
        type = "submenu",
        key = "marketIntegration",
        name = GetString(rawget(_G, "SI_BETTERUI_MARKET_INTEGRATION_HEADER")),
        controls = marketIntegrationControls,
    })

    table.insert(generalControls, {
        type = "submenu",
        key = "enhancedTooltips",
        name = GetString(rawget(_G, "SI_BETTERUI_ENHANCED_TOOLTIPS_HEADER")),
        controls = enhancedTooltipControls,
    })

    WrapGeneralInterfaceSettingControls(generalControls, "general")
    TraceGeneralSetting("settings_options", "built", {
        generalControls = #generalControls,
        marketIntegrationControls = #marketIntegrationControls,
        enhancedTooltipControls = #enhancedTooltipControls,
    })
    return generalControls
end
