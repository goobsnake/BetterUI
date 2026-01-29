--[[
    BetterUI Tooltip Settings
    Description: Configuration options for BetterUI Tooltip enhancements.
    Part of the General Interface module.
    Last Modified: 2026-01-28
]]

if BETTERUI == nil then BETTERUI = {} end
if BETTERUI.GeneralInterface == nil then BETTERUI.GeneralInterface = {} end

local LAM = LibAddonMenu2

--- Returns the table of LAM settings options for General Interface.
function BETTERUI.GeneralInterface.GetSettingsOptions()
    return {
        {
            type = "checkbox",
            name = GetString(SI_BETTERUI_GS_ERROR_SUPPRESS),
            tooltip = GetString(SI_BETTERUI_GS_ERROR_SUPPRESS_TOOLTIP),
            getFunc = function()
                if not BETTERUI.Settings.Modules["GeneralInterface"] then return false end
                return BETTERUI.Settings.Modules["GeneralInterface"].guildStoreErrorSuppress
            end,
            setFunc = function(value)
                BETTERUI.Settings.Modules["GeneralInterface"].guildStoreErrorSuppress = value
            end,
            disabled = function() return ArkadiusTradeTools == nil and MasterMerchant == nil end,
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(SI_BETTERUI_ATT_INTEGRATION),
            tooltip = GetString(SI_BETTERUI_ATT_INTEGRATION_TOOLTIP),
            getFunc = function() return BETTERUI.Settings.Modules["GeneralInterface"].attIntegration end,
            setFunc = function(value)
                BETTERUI.Settings.Modules["GeneralInterface"].attIntegration = value
            end,
            disabled = function() return ArkadiusTradeTools == nil end,
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(SI_BETTERUI_MM_INTEGRATION),
            tooltip = GetString(SI_BETTERUI_MM_INTEGRATION_TOOLTIP),
            getFunc = function() return BETTERUI.Settings.Modules["GeneralInterface"].mmIntegration end,
            setFunc = function(value)
                BETTERUI.Settings.Modules["GeneralInterface"].mmIntegration = value
            end,
            disabled = function() return MasterMerchant == nil end,
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(SI_BETTERUI_TTC_INTEGRATION),
            tooltip = GetString(SI_BETTERUI_TTC_INTEGRATION_TOOLTIP),
            getFunc = function() return BETTERUI.Settings.Modules["GeneralInterface"].ttcIntegration end,
            setFunc = function(value)
                BETTERUI.Settings.Modules["GeneralInterface"].ttcIntegration = value
            end,
            disabled = function() return TamrielTradeCentre == nil end,
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(SI_BETTERUI_SHOW_STYLE_TRAIT),
            tooltip = GetString(SI_BETTERUI_SHOW_STYLE_TRAIT_TOOLTIP),
            getFunc = function() return BETTERUI.Settings.Modules["GeneralInterface"].showStyleTrait end,
            setFunc = function(value) BETTERUI.Settings.Modules["GeneralInterface"].showStyleTrait = value end,
            width = "full",
        },
        {
            type = "editbox",
            name = GetString(SI_BETTERUI_CHAT_HISTORY),
            tooltip = GetString(SI_BETTERUI_CHAT_HISTORY_TOOLTIP),
            getFunc = function()
                if not BETTERUI.Settings.Modules["GeneralInterface"] then return 200 end
                return BETTERUI.Settings.Modules["GeneralInterface"].chatHistory or 200
            end,
            setFunc = function(value)
                BETTERUI.Settings.Modules["GeneralInterface"].chatHistory = tonumber(value)
                if (ZO_ChatWindowTemplate1Buffer ~= nil) then
                    ZO_ChatWindowTemplate1Buffer:SetMaxHistoryLines(BETTERUI
                        .Settings.Modules["GeneralInterface"].chatHistory)
                end
            end,
            default = 200,
            width = "full",
        },
        {
            type = "checkbox",
            name = GetString(SI_BETTERUI_REMOVE_DELETE_MAIL_CONFIRM),
            getFunc = function() return BETTERUI.Settings.Modules["GeneralInterface"].removeDeleteDialog end,
            setFunc = function(value)
                BETTERUI.Settings.Modules["GeneralInterface"].removeDeleteDialog = value
            end,
            width = "full",
        },

        {
            type = "editbox",
            name = GetString(SI_BETTERUI_MOUSE_SCROLL_SPEED),
            tooltip = GetString(SI_BETTERUI_MOUSE_SCROLL_SPEED_TOOLTIP),
            getFunc = function()
                if not BETTERUI.Settings.Modules["CIM"] then return 50 end
                return tostring(BETTERUI.Settings.Modules["CIM"].rhScrollSpeed)
            end,
            setFunc = function(value)
                if BETTERUI.Settings.Modules["CIM"] then
                    BETTERUI.Settings.Modules["CIM"].rhScrollSpeed = tonumber(value) or 50
                end
            end,
            disabled = function() return not (BETTERUI.Settings.Modules["CIM"] and BETTERUI.Settings.Modules["CIM"].m_enabled) end,
            width = "full",
        },
        {
            type = "editbox",
            name = GetString(SI_BETTERUI_TRIGGER_SKIP),
            tooltip = GetString(SI_BETTERUI_TRIGGER_SKIP_TOOLTIP),
            getFunc = function()
                if not BETTERUI.Settings.Modules["CIM"] then return 10 end
                return tostring(BETTERUI.Settings.Modules["CIM"].triggerSpeed)
            end,
            setFunc = function(value)
                if BETTERUI.Settings.Modules["CIM"] then
                    BETTERUI.Settings.Modules["CIM"].triggerSpeed = tonumber(value) or 10
                end
            end,
            disabled = function() return not (BETTERUI.Settings.Modules["CIM"] and BETTERUI.Settings.Modules["CIM"].m_enabled) end,
            width = "full",
        },
        {
            type = "checkbox",
            name = "Enable BetterUI Tooltip Enhancements",
            tooltip =
            "Enables custom improvements, font scaling, and additional info in the tooltip header. If disabled, reverts to native UI with only Market Price added.\n\nNOTE: Tooltip Font Scaling requires this to be ENABLED.",
            getFunc = function()
                local settings = BETTERUI.Settings.Modules["CIM"]
                if not settings then return false end
                if settings.enableTooltipEnhancements == nil then return true end
                return settings.enableTooltipEnhancements
            end,
            setFunc = function(value)
                BETTERUI.Settings.Modules["CIM"].enableTooltipEnhancements = value
            end,
            width = "full",
            default = true,
        },
        {
            type = "slider",
            name = "BetterUI Tooltip Font Size",
            tooltip = GetString(SI_BETTERUI_TOOLTIP_FONT_SIZE_TOOLTIP),
            min = 12,
            max = 48,
            step = 1,
            getFunc = function()
                local settings = BETTERUI.Settings.Modules["CIM"]
                local val = 24
                if settings then
                    val = settings.tooltipSize or val
                end

                return val
            end,
            setFunc = function(value) BETTERUI.Settings.Modules["CIM"].tooltipSize = value end,
            disabled = function()
                local settings = BETTERUI.Settings.Modules["CIM"]
                if not settings then return true end
                -- Disabled unless tooltip enhancements are enabled
                return settings.enableTooltipEnhancements ~= true
            end,
            width = "full",
            default = 24,
        },
    }
end

--- Initializes General Interface default settings.
function BETTERUI.GeneralInterface.InitModule(m_options)
    if m_options["chatHistory"] == nil then m_options["chatHistory"] = 200 end
    if m_options["showStyleTrait"] == nil then m_options["showStyleTrait"] = true end
    if m_options["removeDeleteDialog"] == nil then m_options["removeDeleteDialog"] = false end
    if m_options["guildStoreErrorSuppress"] == nil then m_options["guildStoreErrorSuppress"] = false end
    if m_options["attIntegration"] == nil then m_options["attIntegration"] = true end
    if m_options["mmIntegration"] == nil then m_options["mmIntegration"] = true end
    if m_options["ttcIntegration"] == nil then m_options["ttcIntegration"] = true end
    return m_options
end
