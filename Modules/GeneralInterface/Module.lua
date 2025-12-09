-- BetterUI General Interface Module
-- Settings panel for tooltips, chat history, nameplates, and third-party integrations

local _
local LAM = LibAddonMenu2

-- Initializes settings panel for General Interface options
--- @param mId string: Module ID
--- @param moduleName string: Display name
local function Init(mId, moduleName)
	local panelData = Init_ModulePanel(moduleName, "General Interface Settings")

	local optionsTable = {
		{
			type = "checkbox",
			name = "Guild Store Error Suppression",
			tooltip = "Removes guild store error messages caused by MM or ATT",
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
			name = "Arkadius Trade Tools",
			tooltip = "Hooks ATT Price info into the item tooltips",
			getFunc = function() return BETTERUI.Settings.Modules["Tooltips"].attIntegration end,
			setFunc = function(value) BETTERUI.Settings.Modules["Tooltips"].attIntegration = value
					end,
			disabled = function() return ArkadiusTradeTools == nil end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = "Master Merchant integration",
			tooltip = "Hooks Master Merchant into the item tooltips",
			getFunc = function() return BETTERUI.Settings.Modules["Tooltips"].mmIntegration end,
			setFunc = function(value) BETTERUI.Settings.Modules["Tooltips"].mmIntegration = value
					end,
			disabled = function() return MasterMerchant == nil end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = "Tamriel Trade Centre integration",
			tooltip = "Hooks TTC Price info into the item tooltips",
			getFunc = function() return BETTERUI.Settings.Modules["Tooltips"].ttcIntegration end,
			setFunc = function(value) BETTERUI.Settings.Modules["Tooltips"].ttcIntegration = value
					end,
			disabled = function() return TamrielTradeCentre == nil end,
			width = "full",
			requiresReload = true,
		},
		{
		type = "checkbox",
			name = "Display item style and trait knowledge",
			tooltip = "On items, displays the style of the item and whether the trait can be researched",
			getFunc = function() return BETTERUI.Settings.Modules["Tooltips"].showStyleTrait end,
			setFunc = function(value) BETTERUI.Settings.Modules["Tooltips"].showStyleTrait = value end,
			width = "full",
		},
		{
            type = "editbox",
            name = "Chat window history size",
            tooltip = "Alters how many lines to store in the chat buffer, default=200",
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
			name = "Remove confirmation screen when deleting mail",
			getFunc = function() return BETTERUI.Settings.Modules["Tooltips"].removeDeleteDialog end,
			setFunc = function(value)
						BETTERUI.Settings.Modules["Tooltips"].removeDeleteDialog = value
					end,
			width = "full",
			requiresReload = true,
		},
		{
            type = "editbox",
            name = "Mouse Scrolling speed on Left Hand tooltip",
            tooltip = "Change how quickly the menu skips when pressing the triggers.",
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
            name = "Number of lines to skip on trigger",
            tooltip = "Change how quickly the menu skips when pressing the triggers.",
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
            name = "Tooltip font size",
			tooltip = "Allows more or less item information to be displayed at once in tooltips",
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
				if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
					BETTERUI.ResourceOrbFrames.ApplySettings()
				end
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
				if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 1.15 end
				return BETTERUI.Settings.Modules["ResourceOrbFrames"].scale or 1.15
			end,
			setFunc = function(value)
				BETTERUI.Settings.Modules["ResourceOrbFrames"].scale = value
				if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
					BETTERUI.ResourceOrbFrames.ApplySettings()
				end
			end,
			disabled = function() return not BETTERUI.Settings.Modules["ResourceOrbFrames"].enabled end,
			default = 1.15,
		},
		{
			type = "slider",
			name = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_OFFSET),
			tooltip = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_OFFSET_TOOLTIP),
			min = -300,
			max = 300,
			step = 5,
			getFunc = function() 
				if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 40 end
				return BETTERUI.Settings.Modules["ResourceOrbFrames"].offsetY or 40
			end,
			setFunc = function(value)
				BETTERUI.Settings.Modules["ResourceOrbFrames"].offsetY = value
				if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
					BETTERUI.ResourceOrbFrames.ApplySettings()
				end
			end,
			disabled = function() return not BETTERUI.Settings.Modules["ResourceOrbFrames"].enabled end,
			default = 40,
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
        -- Cooldown text settings removed - now uses native ESO yellow styling
        {
            type = "button",
            name = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET),
            tooltip = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET_TOOLTIP),
            func = function()
                local defaults = BETTERUI.ResourceOrbFrames.InitModule({})
                local settings = BETTERUI.Settings.Modules["ResourceOrbFrames"]
                settings.scale = defaults.scale
                settings.offsetY = defaults.offsetY
                settings.useCustomTextures = defaults.useCustomTextures
                -- Cooldown settings removed

                if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                    BETTERUI.ResourceOrbFrames.ApplySettings()
                end
                ReloadUI()
            end,
            disabled = function() return not BETTERUI.Settings.Modules["ResourceOrbFrames"].enabled end,
            width = "half",
        },
        {
            type = "submenu",
            name = GetString(SI_BETTERUI_ORB_TEXT_SUBMENU),
            controls = {
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
                    name = "Enable Experience Bar",
                    tooltip = "Displays an experience/champion point bar above the top skill bar",
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
                    name = "XP Text Size",
                    tooltip = "Adjust the font size of the experience text",
                    min = 12,
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
                    name = "XP Text Color",
                    tooltip = "Adjust the color of the experience text",
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
                    name = "Enable Cast Bar",
                    tooltip = "Displays a casting bar above the Experience bar",
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
                    name = "Always Show Cast Bar",
                    tooltip = "When enabled, the cast bar frame is always visible. When disabled, the cast bar only appears during casting.",
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
                    name = "Cast Text Size",
                    tooltip = "Adjust the font size of the cast timer",
                    min = 12,
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
                    name = "Cast Text Color",
                    tooltip = "Adjust the color of the cast timer text",
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
                    name = "Enable Mount Stamina Bar",
                    tooltip = "Displays a mount stamina bar under the right ornament when mounted",
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
                    name = "Mount Stamina Text Size",
                    tooltip = "Adjust the font size of the mount stamina text",
                    min = 12,
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
                    name = "Mount Stamina Text Color",
                    tooltip = "Adjust the color of the mount stamina text",
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

-- Initializes ResourceOrbFrames default settings
--- @param m_options table: Options table
--- @return table: Initialized options
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
    return m_options
end

-- Initializes Nameplates default settings (preserves existing values)
--- @param m_options table: Options table
--- @return table: Initialized options
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

-- Initializes Tooltips default settings
--- @param m_options table: Options table
--- @return table: Initialized options
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

-- Sets up Tooltips module: registers hooks, event handlers, and scene callbacks
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
