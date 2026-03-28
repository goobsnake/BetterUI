--[[
    BetterUI Tooltip Settings
    Description: Configuration options for BetterUI Tooltip enhancements.
    Part of the General Interface module.
    Last Modified: 2026-03-14

    Note: Helper functions (utility, reset, addon dependency) are in SettingsHelpers.lua.
]]

if BETTERUI == nil then BETTERUI = {} end
if BETTERUI.GeneralInterface == nil then BETTERUI.GeneralInterface = {} end

-- Import shared helpers from SettingsHelpers.lua
local H = BETTERUI.GeneralInterface._SettingsHelpers or {}
local ApplyTooltipVisualSettings = H.ApplyTooltipVisualSettings or function() end
local CleanupTooltipEnhancementArtifacts = H.CleanupTooltipEnhancementArtifacts or function() end
local RefreshInventoryAndBankingLists = H.RefreshInventoryAndBankingLists or function() end
local GetMetadataDefault = H.GetMetadataDefault or function(_, _, fallback) return fallback end
local BuildAddonDependencyTooltip = H.BuildAddonDependencyTooltip or function(id) return GetString(id) end
local GetModuleSettings = H.GetModuleSettings or function() return nil end
local EnsureModuleSettings = H.EnsureModuleSettings or function() return nil end
local IsCIMEnabled = H.IsCIMEnabled or function() return false end
local ParseIntegerInput = H.ParseIntegerInput or function(_, fallback) return fallback end
local ResetGeneralInterfaceGeneralSettings = H.ResetGeneralInterfaceGeneralSettings or function() end
local ResetMarketIntegrationSettings = H.ResetMarketIntegrationSettings or function() end
local ResetEnhancedTooltipSettings = H.ResetEnhancedTooltipSettings or function() end

--- Returns the table of LAM settings options for General Interface.
function BETTERUI.GeneralInterface.GetSettingsOptions()
    local styleTraitIcon = ""
    if BETTERUI and BETTERUI.CIM and BETTERUI.CIM.CONST and BETTERUI.CIM.CONST.ICONS and BETTERUI.CIM.CONST.ICONS.RESEARCHABLE_TRAIT then
        styleTraitIcon = zo_iconFormat(BETTERUI.CIM.CONST.ICONS.RESEARCHABLE_TRAIT, 24, 24) .. " "
    end
    local knowledgeStatusIcon = ""
    if BETTERUI and BETTERUI.CIM and BETTERUI.CIM.CONST and BETTERUI.CIM.CONST.ICONS and BETTERUI.CIM.CONST.ICONS.BOOK_UNKNOWN then
        knowledgeStatusIcon = zo_iconFormat(BETTERUI.CIM.CONST.ICONS.BOOK_UNKNOWN, 24, 24) .. " "
    end

    local marketPriorityChoices = {}
    local marketPriorityValues = {}
    if BETTERUI.CIM and BETTERUI.CIM.MarketIntegration and BETTERUI.CIM.MarketIntegration.GetPriorityChoices then
        marketPriorityChoices, marketPriorityValues = BETTERUI.CIM.MarketIntegration.GetPriorityChoices()
    end

    local tooltipGuildStoreError = BuildAddonDependencyTooltip(
        SI_BETTERUI_GS_ERROR_SUPPRESS_TOOLTIP,
        { "ArkadiusTradeTools", "MasterMerchant" },
        true
    )
    local tooltipATT = BuildAddonDependencyTooltip(
        SI_BETTERUI_ATT_INTEGRATION_TOOLTIP,
        { "ArkadiusTradeTools" },
        false
    )
    local tooltipMM = BuildAddonDependencyTooltip(
        SI_BETTERUI_MM_INTEGRATION_TOOLTIP,
        { "MasterMerchant" },
        false
    )
    local tooltipTTC = BuildAddonDependencyTooltip(
        SI_BETTERUI_TTC_INTEGRATION_TOOLTIP,
        { "TamrielTradeCentre" },
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
                if (ZO_ChatWindowTemplate1Buffer ~= nil) then
                    ZO_ChatWindowTemplate1Buffer:SetMaxHistoryLines(parsedValue)
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
                    settings.rhScrollSpeed = ParseIntegerInput(value, currentValue, 1, 1000)
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
            disabled = function() return ArkadiusTradeTools == nil and MasterMerchant == nil end,
            default = GetMetadataDefault("GeneralInterface", "guildStoreErrorSuppress", true),
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(rawget(_G, "SI_BETTERUI_ATT_INTEGRATION")),
            tooltip = tooltipATT,
            getFunc = function()
                if ArkadiusTradeTools == nil then
                    return false
                end

                local settings = GetModuleSettings("GeneralInterface")
                if not settings then
                    return true
                end

                local value = settings.attIntegration
                if value == nil then
                    return true
                end
                return value
            end,
            setFunc = function(value)
                local settings = EnsureModuleSettings("GeneralInterface")
                if settings then
                    settings.attIntegration = value
                end
            end,
            disabled = function() return ArkadiusTradeTools == nil end,
            default = GetMetadataDefault("GeneralInterface", "attIntegration", true),
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(rawget(_G, "SI_BETTERUI_MM_INTEGRATION")),
            tooltip = tooltipMM,
            getFunc = function()
                if MasterMerchant == nil then
                    return false
                end

                local settings = GetModuleSettings("GeneralInterface")
                if not settings then
                    return true
                end

                local value = settings.mmIntegration
                if value == nil then
                    return true
                end
                return value
            end,
            setFunc = function(value)
                local settings = EnsureModuleSettings("GeneralInterface")
                if settings then
                    settings.mmIntegration = value
                end
            end,
            disabled = function() return MasterMerchant == nil end,
            default = GetMetadataDefault("GeneralInterface", "mmIntegration", true),
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(rawget(_G, "SI_BETTERUI_TTC_INTEGRATION")),
            tooltip = tooltipTTC,
            getFunc = function()
                if TamrielTradeCentre == nil then
                    return false
                end

                local settings = GetModuleSettings("GeneralInterface")
                if not settings then
                    return true
                end

                local value = settings.ttcIntegration
                if value == nil then
                    return true
                end
                return value
            end,
            setFunc = function(value)
                local settings = EnsureModuleSettings("GeneralInterface")
                if settings then
                    settings.ttcIntegration = value
                end
            end,
            disabled = function() return TamrielTradeCentre == nil end,
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
                local settings = EnsureModuleSettings("CIM")
                if settings then
                    settings.enableTooltipEnhancements = value
                end
                if value then
                    ApplyTooltipVisualSettings()
                    local tooltipTypes = { GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP, GAMEPAD_MOVABLE_TOOLTIP }
                    for _, tooltipType in ipairs(tooltipTypes) do
                        if GAMEPAD_TOOLTIPS and GAMEPAD_TOOLTIPS.ClearTooltip then
                            GAMEPAD_TOOLTIPS:ClearTooltip(tooltipType)
                        end
                    end
                else
                    CleanupTooltipEnhancementArtifacts()
                    local tooltipTypes = { GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP, GAMEPAD_MOVABLE_TOOLTIP }
                    for _, tooltipType in ipairs(tooltipTypes) do
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

                if BETTERUI.CIM and BETTERUI.CIM.Font and BETTERUI.CIM.Font.GetSizeValue then
                    return BETTERUI.CIM.Font.GetSizeValue(val)
                end
                return val
            end,
            setFunc = function(value)
                local settings = EnsureModuleSettings("CIM")
                if settings then
                    settings.tooltipSize = value
                end
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
        name = GetString(rawget(_G, "SI_BETTERUI_MARKET_INTEGRATION_RESET")),
        tooltip = GetString(rawget(_G, "SI_BETTERUI_MARKET_INTEGRATION_RESET_TOOLTIP")),
        func = function()
            ResetMarketIntegrationSettings()
        end,
        width = "half",
    })

    if BETTERUI.CIM and BETTERUI.CIM.Settings and BETTERUI.CIM.Settings.SortSettingsAlphabetically then
        BETTERUI.CIM.Settings.SortSettingsAlphabetically(generalControls, false)
        BETTERUI.CIM.Settings.SortSettingsAlphabetically(marketIntegrationControls, false)
        BETTERUI.CIM.Settings.SortSettingsAlphabetically(enhancedTooltipControls, false)
    end

    table.insert(generalControls, {
        type = "submenu",
        name = GetString(rawget(_G, "SI_BETTERUI_MARKET_INTEGRATION_HEADER")),
        controls = marketIntegrationControls,
    })

    table.insert(generalControls, {
        type = "submenu",
        name = GetString(rawget(_G, "SI_BETTERUI_ENHANCED_TOOLTIPS_HEADER")),
        controls = enhancedTooltipControls,
    })

    return generalControls
end

--- Initializes General Interface default settings.
function BETTERUI.GeneralInterface.InitModule(m_options)
    m_options = m_options or {}
    if BETTERUI.Defaults and BETTERUI.Defaults.ApplyModuleDefaults then
        m_options = BETTERUI.Defaults.ApplyModuleDefaults("GeneralInterface", m_options)
    else
        if m_options["chatHistory"] == nil then m_options["chatHistory"] = 200 end
        if m_options["showMarketPrice"] == nil then m_options["showMarketPrice"] = true end
        if m_options["marketPricePriority"] == nil then m_options["marketPricePriority"] = "mm_att_ttc" end
        if m_options["showStyleTrait"] == nil then m_options["showStyleTrait"] = true end
        if m_options["showKnowledgeStatus"] == nil then m_options["showKnowledgeStatus"] = true end
        if m_options["removeDeleteDialog"] == nil then m_options["removeDeleteDialog"] = false end
        if m_options["guildStoreErrorSuppress"] == nil then m_options["guildStoreErrorSuppress"] = true end
        if m_options["attIntegration"] == nil then m_options["attIntegration"] = true end
        if m_options["mmIntegration"] == nil then m_options["mmIntegration"] = true end
        if m_options["ttcIntegration"] == nil then m_options["ttcIntegration"] = true end
    end
    return m_options
end
