---------------------------------------------------------------------------------------------------
-- BetterUI - General Interface Module
--
-- This module acts as the central configuration hub for various General Interface enhancements.
-- It integrates with LibAddonMenu to provide settings for:
-- 1. Tooltips: Font size, MasterMerchant/TTC integration, and mail deletion confirmation.
-- 2. Nameplates: Enabling/disabling, font customization, and style adjustments.
-- 3. Resource Orb Frames: Configuration for the custom resource orb UI (Health/Magicka/Stamina).
--
-- ARCHITECTURE:
--   This file defines the settings panel structure using LAM (LibAddonMenu2).
--   Actual functionality is implemented in separate files:
--     - Tooltips.lua: Tooltip enhancement logic
--     - Nameplates.lua: Nameplate font customization
--     - ResourceOrbFrames.lua: Orb UI implementation
--
-- TODO(architecture): This file is 1100+ lines and hard to navigate. Consider splitting
--                     settings into separate files per feature (TooltipSettings, NameplateSettings, etc.)
-- TODO(refactor): Many setFunc callbacks duplicate the pattern of updating setting + calling ApplySettings.
--                 Extract to helper function like `createSettingSetter(settingsPath, callback)`
-- TODO(cleanup): Some settings check for module existence multiple times in get/set/disabled.
--                Could be consolidated into wrapper functions.
---------------------------------------------------------------------------------------------------

local _
local LAM = LibAddonMenu2

--- Initializes the settings panel for General Interface options.
---
--- Creates a LibAddonMenu panel with all configurable options for:
---   - Tooltip integrations (TTC, MM, ATT)
---   - Nameplate font customization
---   - Resource Orb Frames appearance and behavior
---   - Experience bar settings
---   - Food bar settings
---
--- @param mId string The Module ID (unused, for standardized module signature)
--- @param moduleName string The display name of the module for the settings panel
local function Init(mId, moduleName)
	local panelData = Init_ModulePanel(moduleName, "General Interface Settings")

	local optionsTable = {
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_GS_ERROR_SUPPRESS),
			tooltip = GetString(SI_BETTERUI_GS_ERROR_SUPPRESS_TOOLTIP),
			getFunc = function() 
				if not BETTERUI.Settings.Modules["Tooltips"] then return false end
				return BETTERUI.Settings.Modules["Tooltips"].guildStoreErrorSuppress 
			end,
			setFunc = function(value) BETTERUI.Settings.Modules["Tooltips"].guildStoreErrorSuppress = value
		            end,
            disabled = function() return ArkadiusTradeTools == nil and MasterMerchant == nil end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_ATT_INTEGRATION),
			tooltip = GetString(SI_BETTERUI_ATT_INTEGRATION_TOOLTIP),
			getFunc = function() return BETTERUI.Settings.Modules["Tooltips"].attIntegration end,
			setFunc = function(value) BETTERUI.Settings.Modules["Tooltips"].attIntegration = value
					end,
			disabled = function() return ArkadiusTradeTools == nil end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_MM_INTEGRATION),
			tooltip = GetString(SI_BETTERUI_MM_INTEGRATION_TOOLTIP),
			getFunc = function() return BETTERUI.Settings.Modules["Tooltips"].mmIntegration end,
			setFunc = function(value) BETTERUI.Settings.Modules["Tooltips"].mmIntegration = value
					end,
			disabled = function() return MasterMerchant == nil end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_TTC_INTEGRATION),
			tooltip = GetString(SI_BETTERUI_TTC_INTEGRATION_TOOLTIP),
			getFunc = function() return BETTERUI.Settings.Modules["Tooltips"].ttcIntegration end,
			setFunc = function(value) BETTERUI.Settings.Modules["Tooltips"].ttcIntegration = value
					end,
			disabled = function() return TamrielTradeCentre == nil end,
			width = "full",
			requiresReload = true,
		},
		{
		type = "checkbox",
			name = GetString(SI_BETTERUI_SHOW_STYLE_TRAIT),
			tooltip = GetString(SI_BETTERUI_SHOW_STYLE_TRAIT_TOOLTIP),
			getFunc = function() return BETTERUI.Settings.Modules["Tooltips"].showStyleTrait end,
			setFunc = function(value) BETTERUI.Settings.Modules["Tooltips"].showStyleTrait = value end,
			width = "full",
		},
		{
            type = "editbox",
            name = GetString(SI_BETTERUI_CHAT_HISTORY),
            tooltip = GetString(SI_BETTERUI_CHAT_HISTORY_TOOLTIP),
            getFunc = function() 
				if not BETTERUI.Settings.Modules["Tooltips"] then return 200 end
				return BETTERUI.Settings.Modules["Tooltips"].chatHistory or 200
			end,
            setFunc = function(value) BETTERUI.Settings.Modules["Tooltips"].chatHistory = tonumber(value)
            							if(ZO_ChatWindowTemplate1Buffer ~= nil) then ZO_ChatWindowTemplate1Buffer:SetMaxHistoryLines(BETTERUI.Settings.Modules["Tooltips"].chatHistory) end end,
            default=200,
            width = "full",
        },
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_REMOVE_DELETE_MAIL_CONFIRM),
			getFunc = function() return BETTERUI.Settings.Modules["Tooltips"].removeDeleteDialog end,
			setFunc = function(value)
						BETTERUI.Settings.Modules["Tooltips"].removeDeleteDialog = value
					end,
			width = "full",
			requiresReload = true,
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
            type = "slider",
            name = GetString(SI_BETTERUI_TOOLTIP_FONT_SIZE),
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
                if type(val) == "string" then
                    local legacyMap = { Small = 20, Default = 24, Medium = 28, Large = 32, XLarge = 36 }
                    return legacyMap[val] or 24
                end
                return val
            end,
            setFunc = function(value) BETTERUI.Settings.Modules["CIM"].tooltipSize = value end,
            disabled = function() return not BETTERUI.Settings.Modules["CIM"].m_enabled end,
            width = "full",
            requiresReload = true,
            default = 24,
        },
		-- ============================================================================
		-- ENHANCED NAMEPLATES SETTINGS
		-- ============================================================================
		{
			type = "header",
			name = GetString(SI_BETTERUI_NAMEPLATES_HEADER),
			width = "full",
		},
		{
			type = "description",
			text = GetString(SI_BETTERUI_NAMEPLATES_DESC),
			width = "full",
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_NAMEPLATES_ENABLED),
			tooltip = GetString(SI_BETTERUI_NAMEPLATES_ENABLED_TOOLTIP),
			default = false,
			getFunc = function()
				return (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].enabled) or false
			end,
			setFunc = function(value)
				if BETTERUI.Settings.Modules["Nameplates"] then
					BETTERUI.Settings.Modules["Nameplates"].enabled = value
					if BETTERUI.Nameplates and BETTERUI.Nameplates.OnEnabledChanged then
						BETTERUI.Nameplates.OnEnabledChanged(value)
					end
				end
			end,
			width = "full",
		},
		{
			type = "dropdown",
			name = GetString(SI_BETTERUI_NAMEPLATES_FONT),
			tooltip = GetString(SI_BETTERUI_NAMEPLATES_FONT_TOOLTIP),
			choices = BETTERUI.Nameplates and BETTERUI.Nameplates.FONT_CHOICES or {},
			choicesValues = BETTERUI.Nameplates and BETTERUI.Nameplates.FONT_VALUES or {},
			default = BETTERUI.Nameplates and BETTERUI.Nameplates.DEFAULTS.font,
			getFunc = function()
				local defaults = (BETTERUI.Nameplates and BETTERUI.Nameplates.DEFAULTS) or {font="EsoUI/Common/Fonts/Univers57.otf"}
				return (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].font) or defaults.font
			end,
			setFunc = function(value)
				if BETTERUI.Settings.Modules["Nameplates"] then
					BETTERUI.Settings.Modules["Nameplates"].font = value
					if BETTERUI.Nameplates and BETTERUI.Nameplates.ApplyCurrentSettings then
						BETTERUI.Nameplates.ApplyCurrentSettings()
					end
				end
			end,
			disabled = function()
				return not (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].enabled)
			end,
			width = "full",
			scrollable = true,
		},
		{
			type = "dropdown",
			name = GetString(SI_BETTERUI_NAMEPLATES_STYLE),
			tooltip = GetString(SI_BETTERUI_NAMEPLATES_STYLE_TOOLTIP),
			choices = BETTERUI.Nameplates and BETTERUI.Nameplates.FONTSTYLE_CHOICES or {},
			choicesValues = BETTERUI.Nameplates and BETTERUI.Nameplates.FONTSTYLE_VALUES or {},
			default = BETTERUI.Nameplates and BETTERUI.Nameplates.DEFAULTS.style,
			getFunc = function()
				local defaults = (BETTERUI.Nameplates and BETTERUI.Nameplates.DEFAULTS) or {style="outline"}
				return (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].style) or defaults.style
			end,
			setFunc = function(value)
				if BETTERUI.Settings.Modules["Nameplates"] then
					BETTERUI.Settings.Modules["Nameplates"].style = value
					if BETTERUI.Nameplates and BETTERUI.Nameplates.ApplyCurrentSettings then
						BETTERUI.Nameplates.ApplyCurrentSettings()
					end
				end
			end,
			disabled = function()
				return not (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].enabled)
			end,
			width = "full",
		},
		{
			type = "slider",
			name = GetString(SI_BETTERUI_NAMEPLATES_SIZE),
			tooltip = GetString(SI_BETTERUI_NAMEPLATES_SIZE_TOOLTIP),
			min = 8,
			max = 64,
			step = 1,
			default = BETTERUI.Nameplates and BETTERUI.Nameplates.DEFAULTS.size or 16,
			getFunc = function()
				return (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].size) or 16
			end,
			setFunc = function(value)
				if BETTERUI.Settings.Modules["Nameplates"] then
					BETTERUI.Settings.Modules["Nameplates"].size = value
					if BETTERUI.Nameplates and BETTERUI.Nameplates.ApplyCurrentSettings then
						BETTERUI.Nameplates.ApplyCurrentSettings()
					end
				end
			end,
			disabled = function()
				return not (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].enabled)
			end,
			width = "full",
		},
		{
			type = "button",
			name = GetString(SI_BETTERUI_NAMEPLATES_RESET),
			tooltip = GetString(SI_BETTERUI_NAMEPLATES_RESET_TOOLTIP),
			func = function()
				if BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Nameplates then
					local defaults = BETTERUI.Nameplates.DEFAULTS
					BETTERUI.Settings.Modules["Nameplates"].font = defaults.font
					BETTERUI.Settings.Modules["Nameplates"].style = defaults.style
					BETTERUI.Settings.Modules["Nameplates"].size = defaults.size
					if BETTERUI.Nameplates.ApplyCurrentSettings then
						BETTERUI.Nameplates.ApplyCurrentSettings()
					end
				end
			end,
			disabled = function()
				return not (BETTERUI.Settings.Modules["Nameplates"] and BETTERUI.Settings.Modules["Nameplates"].enabled)
			end,
			width = "half",
		},
		-- ============================================================================
		-- RESOURCE ORB FRAMES SETTINGS
		-- ============================================================================
		{
			type = "header",
			name = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_HEADER),
			width = "full",
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_ENABLED),
			tooltip = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_ENABLED_TOOLTIP),
			getFunc = function() 
				if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return false end
				return BETTERUI.Settings.Modules["ResourceOrbFrames"].enabled 
			end,
			setFunc = function(value)
				BETTERUI.Settings.Modules["ResourceOrbFrames"].enabled = value
			end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "slider",
			name = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_SCALE),
			tooltip = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_SCALE_TOOLTIP),
			min = 0.75,
			max = 1.75,
			step = 0.05,
			decimals = 2,
			getFunc = function() 
				if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 1 end
				return BETTERUI.Settings.Modules["ResourceOrbFrames"].scale or 1
			end,
			setFunc = function(value)
				BETTERUI.Settings.Modules["ResourceOrbFrames"].scale = value
				if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
					BETTERUI.ResourceOrbFrames.ApplySettings()
				end
			end,
			disabled = function() return not BETTERUI.Settings.Modules["ResourceOrbFrames"].enabled end,
			default = 1,
		},
		{
			type = "slider",
			name = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_OFFSET),
			tooltip = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_OFFSET_TOOLTIP),
			min = -300,
			max = 300,
			step = 5,
			getFunc = function() 
				if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 0 end
				return BETTERUI.Settings.Modules["ResourceOrbFrames"].offsetY or 0
			end,
			setFunc = function(value)
				BETTERUI.Settings.Modules["ResourceOrbFrames"].offsetY = value
				if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
					BETTERUI.ResourceOrbFrames.ApplySettings()
				end
			end,
			disabled = function() return not BETTERUI.Settings.Modules["ResourceOrbFrames"].enabled end,
			default = 0,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_USE_CUSTOM_TEXTURES),
			tooltip = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_USE_CUSTOM_TEXTURES_TOOLTIP),
			getFunc = function() 
				if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return false end
				return BETTERUI.Settings.Modules["ResourceOrbFrames"].useCustomTextures 
			end,
			setFunc = function(value)
				BETTERUI.Settings.Modules["ResourceOrbFrames"].useCustomTextures = value
				ReloadUI()
			end,
			width = "full",
			warning = "Requires Reload UI",
		},
        {
            type = "button",
            name = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET),
            tooltip = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET_TOOLTIP),
            func = function()
                local defaults = BETTERUI.ResourceOrbFrames.InitModule({})
                local settings = BETTERUI.Settings.Modules["ResourceOrbFrames"]
                settings.scale = 1
                settings.offsetY = 0
                settings.useCustomTextures = defaults.useCustomTextures
                settings.cooldownTextSize = 27
                settings.cooldownTextColor = {0.86, 0.84, 0.13, 1}
                settings.quickslotTextSize = 27
                settings.quickslotTextColor = {1, 1, 1, 1}
                settings.hideLeftOrnament = defaults.hideLeftOrnament
                settings.hideRightOrnament = defaults.hideRightOrnament

                if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                    BETTERUI.ResourceOrbFrames.ApplySettings()
                end
            end,
            disabled = function() return not BETTERUI.Settings.Modules["ResourceOrbFrames"].enabled end,
            width = "half",
        },
        {
            type = "submenu",
            name = GetString(SI_BETTERUI_SKILL_BARS_SUBMENU),
            controls = {
                {
                    type = "header",
                    name = GetString(SI_BETTERUI_SKILL_COOLDOWN_TIMER_HEADER),
                },
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_FONT_SCALE),
                    tooltip = GetString(SI_BETTERUI_SKILL_COOLDOWN_SCALE_TOOLTIP),
                    min = 12,
                    max = 48,
                    step = 1,
                    getFunc = function() 
                        if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 27 end
                        return BETTERUI.Settings.Modules["ResourceOrbFrames"].cooldownTextSize or 27 
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].cooldownTextSize = value
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_FONT_COLOR),
                    tooltip = GetString(SI_BETTERUI_SKILL_COOLDOWN_COLOR_TOOLTIP),
                    getFunc = function()
                        if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 0.86, 0.84, 0.13, 1 end
                        local color = BETTERUI.Settings.Modules["ResourceOrbFrames"].cooldownTextColor or {0.86, 0.84, 0.13, 1}
                        return color[1], color[2], color[3], color[4] or 1
                    end,
                    setFunc = function(r, g, b, a)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].cooldownTextColor = {r, g, b, a}
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    width = "full",
                },
                {
                    type = "header",
                    name = GetString(SI_BETTERUI_QUICKSLOTS_HEADER),
                },
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_FONT_SCALE),
                    tooltip = GetString(SI_BETTERUI_QUICKSLOT_SCALE_TOOLTIP),
                    min = 12,
                    max = 48,
                    step = 1,
                    getFunc = function() 
                        if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 27 end
                        return BETTERUI.Settings.Modules["ResourceOrbFrames"].quickslotTextSize or 27 
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].quickslotTextSize = value
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_FONT_COLOR),
                    tooltip = GetString(SI_BETTERUI_QUICKSLOT_COLOR_TOOLTIP),
                    getFunc = function()
                        if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 1, 1, 1, 1 end
                        local color = BETTERUI.Settings.Modules["ResourceOrbFrames"].quickslotTextColor or {1, 1, 1, 1}
                        return color[1], color[2], color[3], color[4] or 1
                    end,
                    setFunc = function(r, g, b, a)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].quickslotTextColor = {r, g, b, a}
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    width = "full",
                },
                {
                    type = "header",
                    name = GetString(SI_BETTERUI_BACK_BAR_HEADER),
                },
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_BACK_BAR_OPACITY),
                    tooltip = GetString(SI_BETTERUI_BACK_BAR_OPACITY_TOOLTIP),
                    min = 0.3,
                    max = 1.0,
                    step = 0.05,
                    decimals = 2,
                    getFunc = function() 
                        if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 0.5 end
                        return BETTERUI.Settings.Modules["ResourceOrbFrames"].backBarOpacity or 1 
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].backBarOpacity = value
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    width = "full",
                },
                {
                    type = "button",
                    name = GetString(SI_BETTERUI_RESET_SKILL_BAR),
                    func = function()
                        local defaults = BETTERUI.ResourceOrbFrames.InitModule({})
                        local settings = BETTERUI.Settings.Modules["ResourceOrbFrames"]
                        settings.cooldownTextSize = 27
                        settings.cooldownTextColor = {0.86, 0.84, 0.13, 1}
                        settings.quickslotTextSize = 27
                        settings.quickslotTextColor = {1, 1, 1, 1}
                        settings.backBarOpacity = 1

                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["ResourceOrbFrames"].enabled end,
                    width = "half",
                },
            },
        },
        {
            type = "submenu",
            name = GetString(SI_BETTERUI_ORB_TEXT_SUBMENU),
            controls = {
                -- Ornament Visibility Settings
                {
                    type = "checkbox",
                    name = GetString(SI_BETTERUI_HIDE_LEFT_ORNAMENT),
                    tooltip = GetString(SI_BETTERUI_HIDE_LEFT_ORNAMENT_TOOLTIP),
                    getFunc = function() 
                        if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return false end
                        return BETTERUI.Settings.Modules["ResourceOrbFrames"].hideLeftOrnament 
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].hideLeftOrnament = value
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["ResourceOrbFrames"].enabled end,
                    width = "full",
                },
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_LEFT_ORB_SIZE),
                    tooltip = GetString(SI_BETTERUI_LEFT_ORB_SIZE_TOOLTIP),
                    min = 1.0,
                    max = 1.2,
                    step = 0.1,
                    decimals = 1,
                    getFunc = function() 
                        if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 1.0 end
                        return BETTERUI.Settings.Modules["ResourceOrbFrames"].leftOrbSizeScale or 1.0 
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].leftOrbSizeScale = value
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    -- Only enabled when left ornament is hidden
                    disabled = function() 
                        local settings = BETTERUI.Settings.Modules["ResourceOrbFrames"]
                        return not settings.enabled or not settings.hideLeftOrnament 
                    end,
                    width = "full",
                },
                {
                    type = "checkbox",
                    name = GetString(SI_BETTERUI_HIDE_RIGHT_ORNAMENT),
                    tooltip = GetString(SI_BETTERUI_HIDE_RIGHT_ORNAMENT_TOOLTIP),
                    getFunc = function() 
                        if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return false end
                        return BETTERUI.Settings.Modules["ResourceOrbFrames"].hideRightOrnament 
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].hideRightOrnament = value
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["ResourceOrbFrames"].enabled end,
                    width = "full",
                },
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_RIGHT_ORB_SIZE),
                    tooltip = GetString(SI_BETTERUI_RIGHT_ORB_SIZE_TOOLTIP),
                    min = 1.0,
                    max = 1.2,
                    step = 0.1,
                    decimals = 1,
                    getFunc = function() 
                        if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 1.0 end
                        return BETTERUI.Settings.Modules["ResourceOrbFrames"].rightOrbSizeScale or 1.0 
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].rightOrbSizeScale = value
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    -- Only enabled when right ornament is hidden
                    disabled = function() 
                        local settings = BETTERUI.Settings.Modules["ResourceOrbFrames"]
                        return not settings.enabled or not settings.hideRightOrnament 
                    end,
                    width = "full",
                },
                -- Health Text Settings
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_ORB_TEXT_HEALTH_SIZE),
                    tooltip = GetString(SI_BETTERUI_ORB_TEXT_HEALTH_SIZE_TOOLTIP),
                    min = 12,
                    max = 48,
                    step = 1,
                    getFunc = function() 
						if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 20 end
						return BETTERUI.Settings.Modules["ResourceOrbFrames"].healthTextSize or 20 
					end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].healthTextSize = value
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_ORB_TEXT_HEALTH_COLOR),
                    tooltip = GetString(SI_BETTERUI_ORB_TEXT_HEALTH_COLOR_TOOLTIP),
                    getFunc = function()
						if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 1, 1, 1, 1 end
                        local color = BETTERUI.Settings.Modules["ResourceOrbFrames"].healthTextColor or {1, 1, 1, 1}
                        return color[1], color[2], color[3], color[4] or 1
                    end,
                    setFunc = function(r, g, b, a)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].healthTextColor = {r, g, b, a}
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    width = "full",
                },
                -- Magicka Text Settings
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_ORB_TEXT_MAGICKA_SIZE),
                    tooltip = GetString(SI_BETTERUI_ORB_TEXT_MAGICKA_SIZE_TOOLTIP),
                    min = 12,
                    max = 48,
                    step = 1,
                    getFunc = function() 
						if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 20 end
						return BETTERUI.Settings.Modules["ResourceOrbFrames"].magickaTextSize or 20 
					end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].magickaTextSize = value
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_ORB_TEXT_MAGICKA_COLOR),
                    tooltip = GetString(SI_BETTERUI_ORB_TEXT_MAGICKA_COLOR_TOOLTIP),
                    getFunc = function()
						if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 1, 1, 1, 1 end
                        local color = BETTERUI.Settings.Modules["ResourceOrbFrames"].magickaTextColor or {1, 1, 1, 1}
                        return color[1], color[2], color[3], color[4] or 1
                    end,
                    setFunc = function(r, g, b, a)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].magickaTextColor = {r, g, b, a}
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    width = "full",
                },
                -- Stamina Text Settings
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_ORB_TEXT_STAMINA_SIZE),
                    tooltip = GetString(SI_BETTERUI_ORB_TEXT_STAMINA_SIZE_TOOLTIP),
                    min = 12,
                    max = 48,
                    step = 1,
                    getFunc = function() 
						if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 20 end
						return BETTERUI.Settings.Modules["ResourceOrbFrames"].staminaTextSize or 20 
					end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].staminaTextSize = value
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_ORB_TEXT_STAMINA_COLOR),
                    tooltip = GetString(SI_BETTERUI_ORB_TEXT_STAMINA_COLOR_TOOLTIP),
                    getFunc = function()
						if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 1, 1, 1, 1 end
                        local color = BETTERUI.Settings.Modules["ResourceOrbFrames"].staminaTextColor or {1, 1, 1, 1}
                        return color[1], color[2], color[3], color[4] or 1
                    end,
                    setFunc = function(r, g, b, a)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].staminaTextColor = {r, g, b, a}
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    width = "full",
                },
                -- Shield Text Settings
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_ORB_TEXT_SHIELD_SIZE),
                    tooltip = GetString(SI_BETTERUI_ORB_TEXT_SHIELD_SIZE_TOOLTIP),
                    min = 12,
                    max = 48,
                    step = 1,
                    getFunc = function() 
						if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 20 end
						return BETTERUI.Settings.Modules["ResourceOrbFrames"].shieldTextSize or 20 
					end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].shieldTextSize = value
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_ORB_TEXT_SHIELD_COLOR),
                    tooltip = GetString(SI_BETTERUI_ORB_TEXT_SHIELD_COLOR_TOOLTIP),
                    getFunc = function()
						if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 0, 1, 1, 1 end
                        local color = BETTERUI.Settings.Modules["ResourceOrbFrames"].shieldTextColor or {0, 1, 1, 1}
                        return color[1], color[2], color[3], color[4] or 1
                    end,
                    setFunc = function(r, g, b, a)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].shieldTextColor = {r, g, b, a}
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    width = "full",
                },
                {
                    type = "button",
                    name = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET),
                    tooltip = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET_TOOLTIP),
                    func = function()
                        local defaults = BETTERUI.ResourceOrbFrames.InitModule({})
                        local settings = BETTERUI.Settings.Modules["ResourceOrbFrames"]
                        -- Ornament visibility and orb scaling
                        settings.hideLeftOrnament = defaults.hideLeftOrnament
                        settings.hideRightOrnament = defaults.hideRightOrnament
                        settings.leftOrbSizeScale = defaults.leftOrbSizeScale
                        settings.rightOrbSizeScale = defaults.rightOrbSizeScale
                        -- Text settings
                        settings.healthTextSize = defaults.healthTextSize
                        settings.healthTextColor = defaults.healthTextColor
                        settings.magickaTextSize = defaults.magickaTextSize
                        settings.magickaTextColor = defaults.magickaTextColor
                        settings.staminaTextSize = defaults.staminaTextSize
                        settings.staminaTextColor = defaults.staminaTextColor
                        settings.shieldTextSize = defaults.shieldTextSize
                        settings.shieldTextColor = defaults.shieldTextColor

                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["ResourceOrbFrames"].enabled end,
                    width = "half",
                },
            },
        },
        {
            type = "submenu",
            name = GetString(SI_BETTERUI_XP_BAR_SUBMENU),
            controls = {
                {
                    type = "checkbox",
                    name = GetString(SI_BETTERUI_XP_BAR_ENABLED),
                    tooltip = GetString(SI_BETTERUI_XP_BAR_ENABLED_TOOLTIP),
                    getFunc = function() 
						if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return false end
						return BETTERUI.Settings.Modules["ResourceOrbFrames"].xpBarEnabled 
					end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].xpBarEnabled = value
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    width = "full",
                },
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_XP_BAR_TEXT_SIZE),
                    tooltip = GetString(SI_BETTERUI_XP_BAR_TEXT_SIZE_TOOLTIP),
                    min = 5,
                    max = 32,
                    step = 1,
                    getFunc = function() 
						if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 16 end
						return BETTERUI.Settings.Modules["ResourceOrbFrames"].xpBarTextSize or 16 
					end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].xpBarTextSize = value
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["ResourceOrbFrames"].xpBarEnabled end,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_XP_BAR_TEXT_COLOR),
                    tooltip = GetString(SI_BETTERUI_XP_BAR_TEXT_COLOR_TOOLTIP),
                    getFunc = function()
						if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 1, 1, 1, 1 end
                        local color = BETTERUI.Settings.Modules["ResourceOrbFrames"].xpBarTextColor or {1, 1, 1, 1}
                        return color[1], color[2], color[3], color[4] or 1
                    end,
                    setFunc = function(r, g, b, a)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].xpBarTextColor = {r, g, b, a}
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["ResourceOrbFrames"].xpBarEnabled end,
                    width = "full",
                },
                {
                    type = "button",
                    name = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET),
                    tooltip = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET_TOOLTIP),
                    func = function()
                        local defaults = BETTERUI.ResourceOrbFrames.InitModule({})
                        local settings = BETTERUI.Settings.Modules["ResourceOrbFrames"]
                        settings.xpBarTextSize = defaults.xpBarTextSize
                        settings.xpBarTextColor = defaults.xpBarTextColor

                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    -- Check for both overall enabled and specific feature enabled
                    disabled = function() return not (BETTERUI.Settings.Modules["ResourceOrbFrames"].enabled and BETTERUI.Settings.Modules["ResourceOrbFrames"].xpBarEnabled) end,
                    width = "half",
                },
            },
        },
        {
            type = "submenu",
            name = GetString(SI_BETTERUI_CAST_BAR_SUBMENU),
            controls = {
                {
                    type = "checkbox",
                    name = GetString(SI_BETTERUI_CAST_BAR_ENABLED),
                    tooltip = GetString(SI_BETTERUI_CAST_BAR_ENABLED_TOOLTIP),
                    getFunc = function() 
						if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return false end
						return BETTERUI.Settings.Modules["ResourceOrbFrames"].castBarEnabled 
					end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].castBarEnabled = value
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    width = "full",
                },
                {
                    type = "checkbox",
                    name = GetString(SI_BETTERUI_CAST_BAR_ALWAYS_SHOW),
                    tooltip = GetString(SI_BETTERUI_CAST_BAR_ALWAYS_SHOW_TOOLTIP),
                    getFunc = function() 
						if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return false end
						return BETTERUI.Settings.Modules["ResourceOrbFrames"].castBarAlwaysShow 
					end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].castBarAlwaysShow = value
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["ResourceOrbFrames"].castBarEnabled end,
                    width = "full",
                },
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_CAST_BAR_TEXT_SIZE),
                    tooltip = GetString(SI_BETTERUI_CAST_BAR_TEXT_SIZE_TOOLTIP),
                    min = 5,
                    max = 32,
                    step = 1,
                    getFunc = function() 
						if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 16 end
						return BETTERUI.Settings.Modules["ResourceOrbFrames"].castBarTextSize or 16 
					end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].castBarTextSize = value
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["ResourceOrbFrames"].castBarEnabled end,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_CAST_BAR_TEXT_COLOR),
                    tooltip = GetString(SI_BETTERUI_CAST_BAR_TEXT_COLOR_TOOLTIP),
                    getFunc = function()
						if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 1, 1, 1, 1 end
                        local color = BETTERUI.Settings.Modules["ResourceOrbFrames"].castBarTextColor or {1, 1, 1, 1}
                        return color[1], color[2], color[3], color[4] or 1
                    end,
                    setFunc = function(r, g, b, a)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].castBarTextColor = {r, g, b, a}
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["ResourceOrbFrames"].castBarEnabled end,
                    width = "full",
                },
                {
                    type = "button",
                    name = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET),
                    tooltip = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET_TOOLTIP),
                    func = function()
                        local defaults = BETTERUI.ResourceOrbFrames.InitModule({})
                        local settings = BETTERUI.Settings.Modules["ResourceOrbFrames"]
                        settings.castBarTextSize = defaults.castBarTextSize
                        settings.castBarTextColor = defaults.castBarTextColor

                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    disabled = function() return not (BETTERUI.Settings.Modules["ResourceOrbFrames"].enabled and BETTERUI.Settings.Modules["ResourceOrbFrames"].castBarEnabled) end,
                    width = "half",
                },
            },
        },
        {
            type = "submenu",
            name = GetString(SI_BETTERUI_MOUNT_STAMINA_BAR_SUBMENU),
            controls = {
                {
                    type = "checkbox",
                    name = GetString(SI_BETTERUI_MOUNT_BAR_ENABLED),
                    tooltip = GetString(SI_BETTERUI_MOUNT_BAR_ENABLED_TOOLTIP),
                    getFunc = function() 
						if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return false end
						return BETTERUI.Settings.Modules["ResourceOrbFrames"].mountStaminaBarEnabled 
					end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].mountStaminaBarEnabled = value
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    width = "full",
                },
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_MOUNT_BAR_TEXT_SIZE),
                    tooltip = GetString(SI_BETTERUI_MOUNT_BAR_TEXT_SIZE_TOOLTIP),
                    min = 5,
                    max = 32,
                    step = 1,
                    getFunc = function() 
						if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 16 end
						return BETTERUI.Settings.Modules["ResourceOrbFrames"].mountStaminaBarTextSize or 16 
					end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].mountStaminaBarTextSize = value
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["ResourceOrbFrames"].mountStaminaBarEnabled end,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_MOUNT_BAR_TEXT_COLOR),
                    tooltip = GetString(SI_BETTERUI_MOUNT_BAR_TEXT_COLOR_TOOLTIP),
                    getFunc = function()
						if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 1, 1, 1, 1 end
                        local color = BETTERUI.Settings.Modules["ResourceOrbFrames"].mountStaminaBarTextColor or {1, 1, 1, 1}
                        return color[1], color[2], color[3], color[4] or 1
                    end,
                    setFunc = function(r, g, b, a)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].mountStaminaBarTextColor = {r, g, b, a}
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    disabled = function() return not BETTERUI.Settings.Modules["ResourceOrbFrames"].mountStaminaBarEnabled end,
                    width = "full",
                },
                {
                    type = "button",
                    name = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET),
                    tooltip = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET_TOOLTIP),
                    func = function()
                        local defaults = BETTERUI.ResourceOrbFrames.InitModule({})
                        local settings = BETTERUI.Settings.Modules["ResourceOrbFrames"]
                        settings.mountStaminaBarTextSize = defaults.mountStaminaBarTextSize
                        settings.mountStaminaBarTextColor = defaults.mountStaminaBarTextColor

                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    disabled = function() return not (BETTERUI.Settings.Modules["ResourceOrbFrames"].enabled and BETTERUI.Settings.Modules["ResourceOrbFrames"].mountStaminaBarEnabled) end,
                    width = "half",
                },
            },
        },
    }
	LAM:RegisterAddonPanel("BETTERUI_"..mId, panelData)
	LAM:RegisterOptionControls("BETTERUI_"..mId, optionsTable)
end

--- Initializes ResourceOrbFrames default settings.
--- Defines defaults for scale, offset, colors, and visibility of orb elements.
--- @param m_options table The options table to initialize.
--- @return table The initialized options table with defaults applied.
function BETTERUI.ResourceOrbFrames.InitModule(m_options)
    m_options = m_options or {}
    local defaults = {
        enabled = false,
        scale = 1.15,
        offsetY = 80,
        useCustomTextures = false,
        centerBarType = "XP",
        -- cooldownTextSize and cooldownTextColor removed - uses native styling
        healthTextSize = 20,
        healthTextColor = {1, 1, 1, 1},
        magickaTextSize = 20,
        magickaTextColor = {1, 1, 1, 1},
        staminaTextSize = 20,
        staminaTextColor = {1, 1, 1, 1},
        shieldTextSize = 20,
        shieldTextColor = {0, 1, 1, 1},
        xpBarEnabled = false,
        xpBarTextSize = 16,
        xpBarTextColor = {1, 1, 1, 1},
        castBarEnabled = false,
        castBarAlwaysShow = false,
        castBarTextSize = 16,
        castBarTextColor = {1, 1, 1, 1},
        mountStaminaBarEnabled = false,
        mountStaminaBarTextSize = 16,
        mountStaminaBarTextColor = {1, 1, 1, 1},
        backBarOpacity = 1, -- 0.0 to 1.0, lower = more dimmed
        hideLeftOrnament = false,
        hideRightOrnament = false,
        leftOrbSizeScale = 1.0,   -- 1.0, 1.1, or 1.2 (only used when ornament hidden)
        rightOrbSizeScale = 1.0,  -- 1.0, 1.1, or 1.2 (only used when ornament hidden)
    }
    -- Only set defaults if not already present
    if m_options.enabled == nil then m_options.enabled = defaults.enabled end
    if m_options.scale == nil then m_options.scale = defaults.scale end
    if m_options.offsetY == nil then m_options.offsetY = defaults.offsetY end
    if m_options.useCustomTextures == nil then m_options.useCustomTextures = defaults.useCustomTextures end
    if m_options.centerBarType == nil then m_options.centerBarType = defaults.centerBarType end
    -- cooldownTextSize and cooldownTextColor removed - uses native styling
    if m_options.healthTextSize == nil then m_options.healthTextSize = defaults.healthTextSize end
    if m_options.healthTextColor == nil then m_options.healthTextColor = defaults.healthTextColor end
    if m_options.magickaTextSize == nil then m_options.magickaTextSize = defaults.magickaTextSize end
    if m_options.magickaTextColor == nil then m_options.magickaTextColor = defaults.magickaTextColor end
    if m_options.staminaTextSize == nil then m_options.staminaTextSize = defaults.staminaTextSize end
    if m_options.staminaTextColor == nil then m_options.staminaTextColor = defaults.staminaTextColor end
    if m_options.shieldTextSize == nil then m_options.shieldTextSize = defaults.shieldTextSize end
    if m_options.shieldTextColor == nil then m_options.shieldTextColor = defaults.shieldTextColor end
    if m_options.xpBarEnabled == nil then m_options.xpBarEnabled = defaults.xpBarEnabled end
    if m_options.xpBarTextSize == nil then m_options.xpBarTextSize = defaults.xpBarTextSize end
    if m_options.xpBarTextColor == nil then m_options.xpBarTextColor = defaults.xpBarTextColor end
    if m_options.castBarEnabled == nil then m_options.castBarEnabled = defaults.castBarEnabled end
    if m_options.castBarAlwaysShow == nil then m_options.castBarAlwaysShow = defaults.castBarAlwaysShow end
    if m_options.castBarTextSize == nil then m_options.castBarTextSize = defaults.castBarTextSize end
    if m_options.castBarTextColor == nil then m_options.castBarTextColor = defaults.castBarTextColor end
    if m_options.mountStaminaBarEnabled == nil then m_options.mountStaminaBarEnabled = defaults.mountStaminaBarEnabled end
    if m_options.mountStaminaBarTextSize == nil then m_options.mountStaminaBarTextSize = defaults.mountStaminaBarTextSize end
    if m_options.mountStaminaBarTextColor == nil then m_options.mountStaminaBarTextColor = defaults.mountStaminaBarTextColor end
    if m_options.backBarOpacity == nil then m_options.backBarOpacity = defaults.backBarOpacity end
    if m_options.hideLeftOrnament == nil then m_options.hideLeftOrnament = defaults.hideLeftOrnament end
    if m_options.hideRightOrnament == nil then m_options.hideRightOrnament = defaults.hideRightOrnament end
    if m_options.leftOrbSizeScale == nil then m_options.leftOrbSizeScale = defaults.leftOrbSizeScale end
    if m_options.rightOrbSizeScale == nil then m_options.rightOrbSizeScale = defaults.rightOrbSizeScale end
    return m_options
end

--- Initializes Nameplates default settings.
--- Preserves existing values if they exist, otherwise fills in defaults for font, style, and size.
--- @param m_options table The options table to initialize.
--- @return table The initialized options table.
function BETTERUI.Nameplates.InitModule(m_options)
    m_options = m_options or {}
    local defaults = BETTERUI.Nameplates.DEFAULTS
    -- Only set defaults if not already present (preserve existing settings)
    if m_options.enabled == nil then m_options.enabled = defaults.enabled end
    if m_options.font == nil then m_options.font = defaults.font end
    if m_options.style == nil then m_options.style = defaults.style end
    if m_options.size == nil then m_options.size = defaults.size end
    return m_options
end

--- Initializes Tooltips default settings.
--- Sets defaults for chat history, trait visibility, mail handling, and integrations (MM, TTC, ATT).
--- @param m_options table The options table to initialize.
--- @return table The initialized options table.
function BETTERUI.Tooltips.InitModule(m_options)
    if m_options["chatHistory"] == nil then m_options["chatHistory"] = 200 end
    if m_options["showStyleTrait"] == nil then m_options["showStyleTrait"] = true end
    if m_options["removeDeleteDialog"] == nil then m_options["removeDeleteDialog"] = false end
    if m_options["guildStoreErrorSuppress"] == nil then m_options["guildStoreErrorSuppress"] = false end
    if m_options["attIntegration"] == nil then m_options["attIntegration"] = true end
    if m_options["mmIntegration"] == nil then m_options["mmIntegration"] = true end
    if m_options["ttcIntegration"] == nil then m_options["ttcIntegration"] = true end
    return m_options
end

--- Sets up the General Interface (Tooltips) module.
--- Registers hooks for inventory and tooltip layouts, sets up event handlers for error suppression,
--- and initializes keybind overrides for mail deletion.
function BETTERUI.Tooltips.Setup()

	Init("General", "General Interface")

	if IsPrivateFunction('IsInUI') then
		ZO_IsIngameUI = function()
			return SCRIBING_DATA_MANAGER ~= nil
		end
	end

	if BETTERUI.Settings.Modules["Tooltips"].removeDeleteDialog then
		BETTERUI.PostHook(ZO_MailInbox_Gamepad, 'InitializeKeybindDescriptors', function(self)
			self.mainKeybindDescriptor[3]["callback"] = function() self:Delete() end
		end)
	end

	BETTERUI.InventoryHook(GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP), "LayoutItem", BETTERUI.ReturnItemLink, "LayoutBagItem", BETTERUI.ReturnSelectedData, "LayoutGuildStoreSearchResult", BETTERUI.ReturnStoreSearch)
	BETTERUI.InventoryHook(GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_RIGHT_TOOLTIP), "LayoutItem", BETTERUI.ReturnItemLink, "LayoutBagItem", BETTERUI.ReturnSelectedData, "LayoutGuildStoreSearchResult", BETTERUI.ReturnStoreSearch)
	BETTERUI.InventoryHook(GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_MOVABLE_TOOLTIP), "LayoutItem", BETTERUI.ReturnItemLink, "LayoutBagItem", BETTERUI.ReturnSelectedData, "LayoutGuildStoreSearchResult", BETTERUI.ReturnStoreSearch)

	-- Move guild store error suppression to scene lifecycle to avoid frequent toggling during tooltip draws
	if BETTERUI.Settings.Modules["Tooltips"].guildStoreErrorSuppress then
		local scene = SCENE_MANAGER and SCENE_MANAGER.scenes and SCENE_MANAGER.scenes['gamepad_trading_house']
		if scene then
			scene:RegisterCallback("StateChange", function(oldState, newState)
				if newState == SCENE_SHOWING then
					EVENT_MANAGER:UnregisterForEvent("ErrorFrame", EVENT_LUA_ERROR)
					gsErrorSuppress = 1
				elseif newState == SCENE_HIDDEN then
					EVENT_MANAGER:RegisterForEvent("ErrorFrame", EVENT_LUA_ERROR)
					gsErrorSuppress = 0
				end
			end)
		end
	end

	-- Invalidate researchable trait cache on inventory changes
	local function invalidateCacheOnUpdate(_, bagId)
		if BETTERUI and BETTERUI.Tooltips and BETTERUI.Tooltips.InvalidateResearchableTraitCache then
			BETTERUI.Tooltips.InvalidateResearchableTraitCache(bagId)
		end
	end

	BETTERUI.EventManager:RegisterForEvent("BETTERUI_Tooltips_InvSingle", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, invalidateCacheOnUpdate)
	BETTERUI.EventManager:RegisterForEvent("BETTERUI_Tooltips_InvFull", EVENT_INVENTORY_FULL_UPDATE, invalidateCacheOnUpdate)

	if(ZO_ChatWindowTemplate1Buffer ~= nil) then ZO_ChatWindowTemplate1Buffer:SetMaxHistoryLines(BETTERUI.Settings.Modules["Tooltips"].chatHistory) end
end
