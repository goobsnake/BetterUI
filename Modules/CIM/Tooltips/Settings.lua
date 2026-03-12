--[[
    BetterUI Tooltip Settings
    Description: Configuration options for BetterUI Tooltip enhancements.
    Part of the General Interface module.
    Last Modified: 2026-02-08
]]

if BETTERUI == nil then BETTERUI = {} end
if BETTERUI.GeneralInterface == nil then BETTERUI.GeneralInterface = {} end

local LAM = LibAddonMenu2

local function ApplyTooltipVisualSettings()
    if BETTERUI.Inventory and BETTERUI.Inventory.ApplyTooltipStyles then
        BETTERUI.Inventory.ApplyTooltipStyles()
    end
end

local function CleanupTooltipEnhancementArtifacts()
    if not (BETTERUI.Inventory and BETTERUI.Inventory.CleanupEnhancedTooltip) then return end
    BETTERUI.Inventory.CleanupEnhancedTooltip(GAMEPAD_LEFT_TOOLTIP)
    BETTERUI.Inventory.CleanupEnhancedTooltip(GAMEPAD_RIGHT_TOOLTIP)
    BETTERUI.Inventory.CleanupEnhancedTooltip(GAMEPAD_MOVABLE_TOOLTIP)
end

local function RefreshInventoryAndBankingLists()
    local inventoryWindow = GAMEPAD_INVENTORY
    local inventorySceneShowing = true
    if BETTERUI.CIM and BETTERUI.CIM.Utils and BETTERUI.CIM.Utils.IsInventorySceneShowing then
        inventorySceneShowing = BETTERUI.CIM.Utils.IsInventorySceneShowing()
    end

    if inventorySceneShowing
        and inventoryWindow
        and inventoryWindow.RefreshItemList
        and inventoryWindow.itemList
        and inventoryWindow.categoryList then
        inventoryWindow:RefreshItemList()
    end

    local bankingWindow = BETTERUI.Banking and BETTERUI.Banking.Window
    local bankingSceneShowing = true
    if BETTERUI.CIM and BETTERUI.CIM.Utils and BETTERUI.CIM.Utils.IsBankingSceneShowing then
        bankingSceneShowing = BETTERUI.CIM.Utils.IsBankingSceneShowing()
    end

    if bankingSceneShowing and bankingWindow and bankingWindow.RefreshList then
        bankingWindow:RefreshList()
    end
end

local function GetMetadataDefault(moduleName, settingKey, fallback)
    if BETTERUI and BETTERUI.CIM and BETTERUI.CIM.Settings and BETTERUI.CIM.Settings.GetSettingDefault then
        return BETTERUI.CIM.Settings.GetSettingDefault(moduleName, settingKey, fallback)
    end
    return fallback
end

local function BuildAddonDependencyTooltip(baseStringId, addonGlobals, requireAny)
    local baseText = GetString(baseStringId)
    if type(addonGlobals) ~= "table" or #addonGlobals == 0 then
        return baseText
    end

    local addonDisplayNames = {
        ArkadiusTradeTools = "Arkadius Trade Tools",
        MasterMerchant = "Master Merchant",
        TamrielTradeCentre = "Tamriel Trade Centre",
    }

    local availableCount = 0
    for _, addonGlobal in ipairs(addonGlobals) do
        if _G[addonGlobal] ~= nil then
            availableCount = availableCount + 1
        end
    end

    local shouldShowReason = false
    if requireAny then
        shouldShowReason = availableCount == 0
    else
        shouldShowReason = availableCount < #addonGlobals
    end

    if not shouldShowReason then
        return baseText
    end

    local addonListParts = {}
    for _, addonGlobal in ipairs(addonGlobals) do
        addonListParts[#addonListParts + 1] = addonDisplayNames[addonGlobal] or addonGlobal
    end
    local addonList = table.concat(addonListParts, ", ")
    local reason = zo_strformat(GetString(SI_BETTERUI_ADDON_NOT_DETECTED_TOOLTIP), addonList)
    return baseText .. "\n\n" .. reason
end

local function GetModuleSettings(moduleName)
    local modules = BETTERUI and BETTERUI.Settings and BETTERUI.Settings.Modules
    if not modules then
        return nil
    end
    return modules[moduleName]
end

local function EnsureModuleSettings(moduleName)
    if not BETTERUI or not BETTERUI.Settings then
        return nil
    end
    BETTERUI.Settings.Modules = BETTERUI.Settings.Modules or {}
    if type(BETTERUI.Settings.Modules[moduleName]) ~= "table" then
        BETTERUI.Settings.Modules[moduleName] = {}
    end
    return BETTERUI.Settings.Modules[moduleName]
end

local function IsCIMEnabled()
    local cimSettings = GetModuleSettings("CIM")
    return cimSettings and cimSettings.m_enabled == true
end

local function ParseIntegerInput(value, fallback, minValue, maxValue)
    local textValue = tostring(value or "")
    textValue = textValue:gsub("^%s+", "")
    textValue = textValue:gsub("%s+$", "")
    if textValue == "" or not textValue:match("^%-?%d+$") then
        return fallback
    end

    local parsedValue = tonumber(textValue)
    if parsedValue == nil then
        return fallback
    end

    if minValue and parsedValue < minValue then
        parsedValue = minValue
    end
    if maxValue and parsedValue > maxValue then
        parsedValue = maxValue
    end
    return parsedValue
end

local function ResetGeneralInterfaceGeneralSettings()
    if BETTERUI.CIM and BETTERUI.CIM.Settings and BETTERUI.CIM.Settings.ResetModuleSettingsByGroup then
        BETTERUI.CIM.Settings.ResetModuleSettingsByGroup("GeneralInterface", "general")
        BETTERUI.CIM.Settings.ResetModuleSettingsByGroup("CIM", "generalInterfaceGeneral")
    else
        local generalInterfaceSettings = EnsureModuleSettings("GeneralInterface")
        local cimSettings = EnsureModuleSettings("CIM")
        if generalInterfaceSettings then
            generalInterfaceSettings.chatHistory = 200
            generalInterfaceSettings.removeDeleteDialog = false
        end
        if cimSettings then
            cimSettings.rhScrollSpeed = 50
        end
    end

    local generalInterfaceSettings = GetModuleSettings("GeneralInterface")
    if ZO_ChatWindowTemplate1Buffer ~= nil then
        ZO_ChatWindowTemplate1Buffer:SetMaxHistoryLines(
            (generalInterfaceSettings and generalInterfaceSettings.chatHistory) or 200
        )
    end
end

local function ResetMarketIntegrationSettings()
    if BETTERUI.CIM and BETTERUI.CIM.Settings and BETTERUI.CIM.Settings.ResetModuleSettingsByGroup then
        BETTERUI.CIM.Settings.ResetModuleSettingsByGroup("GeneralInterface", "marketIntegration")
    else
        local generalInterfaceSettings = EnsureModuleSettings("GeneralInterface")
        if generalInterfaceSettings then
            generalInterfaceSettings.showMarketPrice =
                GetMetadataDefault("GeneralInterface", "showMarketPrice", true)
            generalInterfaceSettings.marketPricePriority =
                GetMetadataDefault("GeneralInterface", "marketPricePriority", "mm_att_ttc")
            generalInterfaceSettings.guildStoreErrorSuppress =
                GetMetadataDefault("GeneralInterface", "guildStoreErrorSuppress", true)
            generalInterfaceSettings.attIntegration =
                GetMetadataDefault("GeneralInterface", "attIntegration", true)
            generalInterfaceSettings.mmIntegration =
                GetMetadataDefault("GeneralInterface", "mmIntegration", true)
            generalInterfaceSettings.ttcIntegration =
                GetMetadataDefault("GeneralInterface", "ttcIntegration", true)
        end
    end

    RefreshInventoryAndBankingLists()
end

local function ResetEnhancedTooltipSettings()
    if BETTERUI.CIM and BETTERUI.CIM.Settings and BETTERUI.CIM.Settings.ResetModuleSettingsByGroup then
        BETTERUI.CIM.Settings.ResetModuleSettingsByGroup("GeneralInterface", "enhancedTooltips")
        BETTERUI.CIM.Settings.ResetModuleSettingsByGroup("CIM", "enhancedTooltips")
    else
        local generalInterfaceSettings = EnsureModuleSettings("GeneralInterface")
        local cimSettings = EnsureModuleSettings("CIM")
        if generalInterfaceSettings then
            generalInterfaceSettings.showStyleTrait =
                GetMetadataDefault("GeneralInterface", "showStyleTrait", true)
        end
        if cimSettings then
            cimSettings.enableTooltipEnhancements =
                GetMetadataDefault("CIM", "enableTooltipEnhancements", true)
            cimSettings.tooltipSize =
                GetMetadataDefault("CIM", "tooltipSize", 24)
        end
    end

    local cimSettings = GetModuleSettings("CIM")
    if cimSettings and cimSettings.enableTooltipEnhancements == true then
        ApplyTooltipVisualSettings()
    else
        CleanupTooltipEnhancementArtifacts()
    end
    RefreshInventoryAndBankingLists()
end

--- Returns the table of LAM settings options for General Interface.
--- @return table options The list of settings control definitions
function BETTERUI.GeneralInterface.GetSettingsOptions()
    local styleTraitIcon = ""
    if BETTERUI and BETTERUI.CIM and BETTERUI.CIM.CONST and BETTERUI.CIM.CONST.ICONS and BETTERUI.CIM.CONST.ICONS.RESEARCHABLE_TRAIT then
        styleTraitIcon = zo_iconFormat(BETTERUI.CIM.CONST.ICONS.RESEARCHABLE_TRAIT, 24, 24) .. " "
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
            name = GetString(SI_BETTERUI_CHAT_HISTORY),
            tooltip = GetString(SI_BETTERUI_CHAT_HISTORY_TOOLTIP),
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
            name = GetString(SI_BETTERUI_REMOVE_DELETE_MAIL_CONFIRM),
            warning = GetString(SI_BETTERUI_REMOVE_DELETE_WARNING),
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
            name = GetString(SI_BETTERUI_MOUSE_SCROLL_SPEED),
            tooltip = GetString(SI_BETTERUI_MOUSE_SCROLL_SPEED_TOOLTIP),
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
            name = GetString(SI_BETTERUI_GENERAL_RESET),
            tooltip = GetString(SI_BETTERUI_GENERAL_RESET_TOOLTIP),
            func = function()
                ResetGeneralInterfaceGeneralSettings()
            end,
            width = "half",
        },
    }

    local marketIntegrationControls = {
        {
            type = "description",
            text = GetString(SI_BETTERUI_MARKET_INTEGRATION_DESC),
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(SI_BETTERUI_SHOW_MARKET_PRICE),
            tooltip = GetString(SI_BETTERUI_SHOW_MARKET_PRICE_TOOLTIP),
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
            name = GetString(SI_BETTERUI_MARKET_PRICE_PRIORITY),
            tooltip = GetString(SI_BETTERUI_MARKET_PRICE_PRIORITY_TOOLTIP),
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
            name = GetString(SI_BETTERUI_GS_ERROR_SUPPRESS),
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
            name = GetString(SI_BETTERUI_ATT_INTEGRATION),
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
            name = GetString(SI_BETTERUI_MM_INTEGRATION),
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
            name = GetString(SI_BETTERUI_TTC_INTEGRATION),
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
            text = GetString(SI_BETTERUI_ENHANCED_TOOLTIPS_DESC),
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(SI_BETTERUI_ENABLE_TOOLTIP_ENHANCEMENTS),
            tooltip = GetString(SI_BETTERUI_ENABLE_TOOLTIP_ENHANCEMENTS_TOOLTIP),
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
                    -- Clear all visible tooltips so stale addon labels from default mode
                    -- are removed. The tooltip will re-layout on next item selection.
                    local tooltipTypes = { GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP, GAMEPAD_MOVABLE_TOOLTIP }
                    for _, tooltipType in ipairs(tooltipTypes) do
                        if GAMEPAD_TOOLTIPS and GAMEPAD_TOOLTIPS.ClearTooltip then
                            GAMEPAD_TOOLTIPS:ClearTooltip(tooltipType)
                        end
                    end
                else
                    CleanupTooltipEnhancementArtifacts()
                    -- Also clear tooltips when disabling to remove BetterUI's enhanced labels
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
            name = styleTraitIcon .. GetString(SI_BETTERUI_SHOW_STYLE_TRAIT),
            tooltip = GetString(SI_BETTERUI_SHOW_STYLE_TRAIT_TOOLTIP),
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
            type = "slider",
            name = GetString(SI_BETTERUI_TOOLTIP_FONT_SIZE),
            tooltip = GetString(SI_BETTERUI_TOOLTIP_FONT_SIZE_TOOLTIP),
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
                -- Disabled unless tooltip enhancements are enabled
                return settings.enableTooltipEnhancements ~= true
            end,
            width = "full",
            default = GetMetadataDefault("CIM", "tooltipSize", 24),
        },
        {
            type = "button",
            name = GetString(SI_BETTERUI_ENHANCED_TOOLTIPS_RESET),
            tooltip = GetString(SI_BETTERUI_ENHANCED_TOOLTIPS_RESET_TOOLTIP),
            func = function()
                ResetEnhancedTooltipSettings()
            end,
            width = "half",
        },
    }

    table.insert(marketIntegrationControls, {
        type = "button",
        name = GetString(SI_BETTERUI_MARKET_INTEGRATION_RESET),
        tooltip = GetString(SI_BETTERUI_MARKET_INTEGRATION_RESET_TOOLTIP),
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
        name = GetString(SI_BETTERUI_MARKET_INTEGRATION_HEADER),
        controls = marketIntegrationControls,
    })

    table.insert(generalControls, {
        type = "submenu",
        name = GetString(SI_BETTERUI_ENHANCED_TOOLTIPS_HEADER),
        controls = enhancedTooltipControls,
    })

    return generalControls
end

--- Initializes General Interface default settings.
--- @param m_options table The raw settings table
--- @return table m_options The initialized settings table
function BETTERUI.GeneralInterface.InitModule(m_options)
    m_options = m_options or {}
    if BETTERUI.Defaults and BETTERUI.Defaults.ApplyModuleDefaults then
        m_options = BETTERUI.Defaults.ApplyModuleDefaults("GeneralInterface", m_options)
    else
        if m_options["chatHistory"] == nil then m_options["chatHistory"] = 200 end
        if m_options["showMarketPrice"] == nil then m_options["showMarketPrice"] = true end
        if m_options["marketPricePriority"] == nil then m_options["marketPricePriority"] = "mm_att_ttc" end
        if m_options["showStyleTrait"] == nil then m_options["showStyleTrait"] = true end
        if m_options["removeDeleteDialog"] == nil then m_options["removeDeleteDialog"] = false end
        if m_options["guildStoreErrorSuppress"] == nil then m_options["guildStoreErrorSuppress"] = true end
        if m_options["attIntegration"] == nil then m_options["attIntegration"] = true end
        if m_options["mmIntegration"] == nil then m_options["mmIntegration"] = true end
        if m_options["ttcIntegration"] == nil then m_options["ttcIntegration"] = true end
    end
    return m_options
end
