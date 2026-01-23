--[[
File: Modules/ResourceOrbFrames/Module.lua
Purpose: Configuration module for Resource Orb Frames.
         Manages LibAddonMenu settings panel and default values.
Author: BetterUI Team
Last Modified: 2026-01-21
]]

local _
local LAM = LibAddonMenu2

--- Initializes the settings panel for Resource Orb Frames.
---
--- Purpose: Creates a LibAddonMenu panel with all configurable options.
--- Attributes:
--- - Settings for scale, offset, and textures.
--- - Toggle options for ornaments, skill bar features, and overlays.
--- - Customization for fonts (size/color) on all elements.
---
--- @param mId string The Module ID
--- @param moduleName string The display name of the module for the settings panel
local function Init(mId, moduleName)
	local panelData = Init_ModulePanel(moduleName, "Resource Orb Frames Settings")

	local optionsTable = {
		{
			type = "header",
			name = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_HEADER),
			width = "full",
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
			disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
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
			disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
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
			end,
			width = "full",
			warning = "Requires Reload UI",
			requiresReload = true,
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
            disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
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
                    type = "checkbox",
                    name = "Enable Weapon Swap Animation",
                    tooltip = "Plays a slide animation when switching between main and backup weapon bars.",
                    getFunc = function() 
                        if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return false end
                        -- Default to false if nil
                        local val = BETTERUI.Settings.Modules["ResourceOrbFrames"].weaponSwapAnimation
                        if val == nil then return false end
                        return val
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].weaponSwapAnimation = value
                    end,
                    width = "full",
                },
                -- ============================================================================
                -- ULTIMATE NUMBER DISPLAY
                -- ============================================================================
                {
                    type = "header",
                    name = GetString(SI_BETTERUI_ULTIMATE_DISPLAY_HEADER),
                },
                {
                    type = "checkbox",
                    name = GetString(SI_BETTERUI_SHOW_ULTIMATE_NUMBER),
                    tooltip = GetString(SI_BETTERUI_SHOW_ULTIMATE_NUMBER_TOOLTIP),
                    getFunc = function() 
                        if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return false end
                        return BETTERUI.Settings.Modules["ResourceOrbFrames"].showUltimateNumber == true
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].showUltimateNumber = value
                    end,
                    width = "full",
                    warning = "Requires Reload UI",
                    requiresReload = true,
                },
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_ULTIMATE_TEXT_SIZE),
                    tooltip = GetString(SI_BETTERUI_ULTIMATE_TEXT_SIZE_TOOLTIP),
                    min = 12,
                    max = 48,
                    step = 1,
                    getFunc = function() 
                        if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 27 end
                        return BETTERUI.Settings.Modules["ResourceOrbFrames"].ultimateTextSize or 27 
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].ultimateTextSize = value
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    disabled = function()
                        local settings = BETTERUI.Settings.Modules["ResourceOrbFrames"]
                        return not settings or not settings.showUltimateNumber
                    end,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_ULTIMATE_TEXT_COLOR),
                    tooltip = GetString(SI_BETTERUI_ULTIMATE_TEXT_COLOR_TOOLTIP),
                    getFunc = function()
                        if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 1, 1, 1, 1 end
                        local color = BETTERUI.Settings.Modules["ResourceOrbFrames"].ultimateTextColor or {1, 1, 1, 1}
                        return color[1], color[2], color[3], color[4] or 1
                    end,
                    setFunc = function(r, g, b, a)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].ultimateTextColor = {r, g, b, a}
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    disabled = function()
                        local settings = BETTERUI.Settings.Modules["ResourceOrbFrames"]
                        return not settings or not settings.showUltimateNumber
                    end,
                    width = "full",
                },
                -- ============================================================================
                -- QUICKSLOT COOLDOWN TIMER
                -- ============================================================================
                {
                    type = "header",
                    name = GetString(SI_BETTERUI_QUICKSLOT_COOLDOWN_HEADER),
                },
                {
                    type = "checkbox",
                    name = GetString(SI_BETTERUI_SHOW_QUICKSLOT_COOLDOWN),
                    tooltip = GetString(SI_BETTERUI_SHOW_QUICKSLOT_COOLDOWN_TOOLTIP),
                    getFunc = function() 
                        if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return false end
                        return BETTERUI.Settings.Modules["ResourceOrbFrames"].showQuickslotCooldown == true
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].showQuickslotCooldown = value
                    end,
                    width = "full",
                    warning = "Requires Reload UI",
                    requiresReload = true,
                },
                -- ============================================================================
                -- COMBAT INDICATORS
                -- ============================================================================
                {
                    type = "header",
                    name = GetString(SI_BETTERUI_COMBAT_INDICATORS_HEADER),
                },
                {
                    type = "checkbox",
                    name = GetString(SI_BETTERUI_COMBAT_GLOW_ENABLED),
                    tooltip = GetString(SI_BETTERUI_COMBAT_GLOW_ENABLED_TOOLTIP),
                    getFunc = function() 
                        if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return false end
                        return BETTERUI.Settings.Modules["ResourceOrbFrames"].showCombatGlow == true
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].showCombatGlow = value
                    end,
                    width = "full",
                    warning = "Requires Reload UI",
                    requiresReload = true,
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_COMBAT_GLOW_COLOR),
                    tooltip = GetString(SI_BETTERUI_COMBAT_GLOW_COLOR_TOOLTIP),
                    getFunc = function()
                        if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return 1, 0.3, 0.1, 0.8 end
                        local color = BETTERUI.Settings.Modules["ResourceOrbFrames"].combatGlowColor or {1, 0.3, 0.1, 0.8}
                        return color[1], color[2], color[3], color[4] or 0.8
                    end,
                    setFunc = function(r, g, b, a)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].combatGlowColor = {r, g, b, a}
                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    disabled = function()
                        local settings = BETTERUI.Settings.Modules["ResourceOrbFrames"]
                        return not settings or not settings.showCombatGlow
                    end,
                    width = "full",
                },
                {
                    type = "checkbox",
                    name = GetString(SI_BETTERUI_COMBAT_ICON_ENABLED),
                    tooltip = GetString(SI_BETTERUI_COMBAT_ICON_ENABLED_TOOLTIP),
                    getFunc = function() 
                        if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return false end
                        return BETTERUI.Settings.Modules["ResourceOrbFrames"].showCombatIcon == true
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].showCombatIcon = value
                    end,
                    width = "full",
                    warning = "Requires Reload UI",
                    requiresReload = true,
                },
                {
                    type = "checkbox",
                    name = GetString(SI_BETTERUI_COMBAT_AUDIO_ENABLED),
                    tooltip = GetString(SI_BETTERUI_COMBAT_AUDIO_ENABLED_TOOLTIP),
                    getFunc = function() 
                        if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return false end
                        return BETTERUI.Settings.Modules["ResourceOrbFrames"].playCombatAudio == true
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].playCombatAudio = value
                    end,
                    width = "full",
                    warning = "Requires Reload UI",
                    requiresReload = true,
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
                        -- Reset new settings (default to off - user must opt-in)
                        settings.showUltimateNumber = false
                        settings.ultimateTextSize = 27
                        settings.ultimateTextColor = {1, 1, 1, 1}
                        settings.showQuickslotCooldown = false
                        settings.showCombatGlow = false
                        settings.showCombatIcon = false
                        settings.playCombatAudio = false
                        settings.combatGlowColor = {1, 0.3, 0.1, 0.8}

                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
                    width = "half",
                },
            },
        },
        {
            type = "submenu",
            name = GetString(SI_BETTERUI_ORB_TEXT_SUBMENU),
            controls = {
                -- Animated Orb Fill
                {
                    type = "checkbox",
                    name = "Enable Swirl Effect",
                    tooltip = "Slowly rotates the orb fill texture, creating a gentle swirling effect.",
                    getFunc = function() 
                        if not BETTERUI.Settings.Modules["ResourceOrbFrames"] then return false end
                        return BETTERUI.Settings.Modules["ResourceOrbFrames"].orbAnimFlow 
                    end,
                    setFunc = function(value)
                        BETTERUI.Settings.Modules["ResourceOrbFrames"].orbAnimFlow = value
                    end,
                    disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
                    width = "full",
                },
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
                    disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
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
                        return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") or not settings.hideLeftOrnament 
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
                    disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
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
                        return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") or not settings.hideRightOrnament 
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
                    disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
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
                    disabled = function() return not (BETTERUI.GetModuleEnabled("ResourceOrbFrames") and BETTERUI.Settings.Modules["ResourceOrbFrames"].xpBarEnabled) end,
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
                    disabled = function() return not (BETTERUI.GetModuleEnabled("ResourceOrbFrames") and BETTERUI.Settings.Modules["ResourceOrbFrames"].castBarEnabled) end,
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
                    disabled = function() return not (BETTERUI.GetModuleEnabled("ResourceOrbFrames") and BETTERUI.Settings.Modules["ResourceOrbFrames"].mountStaminaBarEnabled) end,
                    width = "half",
                },
            },
        },
    }
	LAM:RegisterAddonPanel("BETTERUI_"..mId, panelData)
	LAM:RegisterOptionControls("BETTERUI_"..mId, optionsTable)
end

--- Initializes ResourceOrbFrames default settings.
---
--- Purpose: Defines defaults for scale, offset, colors, and visibility of orb elements.
--- Mechanics:
--- - Checks each setting key; if missing, assigns default value.
--- - Default Scale: 1.15.
--- - Default Center Bar: "XP".
--- - Sets text sizes and colors for various bars (Health, Magicka, Stamina).
---
--- References: Called during module initialization to ensure valid configuration.
---
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
        customFrontBar = {
            enabled = true,
            offsetX = 0,
            offsetY = 0,
            ultimate = { offsetX = 0, offsetY = 0 },
            quickslotButton = { offsetX = 0, offsetY = 0 },
            companionButton = { offsetX = 0, offsetY = 0 },
            gamepad = { buttonSize = nil, spacing = nil, ultimateSize = 70 },
            keyboard = { buttonSize = nil, spacing = nil, ultimateSize = 55 },
        },
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
    
    if m_options.customFrontBar == nil then 
        m_options.customFrontBar = defaults.customFrontBar 
    else
        -- Deep merge for existing incomplete settings
        local cfb = m_options.customFrontBar
        local d_cfb = defaults.customFrontBar
        if cfb.enabled == nil then cfb.enabled = d_cfb.enabled end
        if cfb.offsetX == nil then cfb.offsetX = d_cfb.offsetX end
        if cfb.offsetY == nil then cfb.offsetY = d_cfb.offsetY end
        
        if cfb.ultimate == nil then cfb.ultimate = d_cfb.ultimate end
        if cfb.quickslotButton == nil then cfb.quickslotButton = d_cfb.quickslotButton end
        if cfb.companionButton == nil then cfb.companionButton = d_cfb.companionButton end
        if cfb.gamepad == nil then cfb.gamepad = d_cfb.gamepad end
        if cfb.keyboard == nil then cfb.keyboard = d_cfb.keyboard end
    end
    return m_options
end

--- Sets up the Resource Orb Frames module.
function BETTERUI.ResourceOrbFrames.Setup()
    Init("ResourceOrbFrames", "Resource Orb Frames")
end
