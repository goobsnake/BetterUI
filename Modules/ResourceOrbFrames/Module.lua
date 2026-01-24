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
	local panelData = BETTERUI.Init_ModulePanel(moduleName, "Resource Orb Frames Settings")

	local function Apply()
		if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
			BETTERUI.ResourceOrbFrames.ApplySettings()
		end
	end

	-- Accessor with live update
	local GetSet = BETTERUI.CreateSettingAccessors("ResourceOrbFrames", Apply)
	-- Accessor without live update (for reload-required settings)
	local GetSetNoUpdate = BETTERUI.CreateSettingAccessors("ResourceOrbFrames", nil)
    local GetColorSet = BETTERUI.CreateColorSettingAccessors("ResourceOrbFrames", Apply)

    local getScale, setScale = GetSet("scale", 1)
    local getOffset, setOffset = GetSet("offsetY", 0)
    local getCustomTex, setCustomTex = GetSetNoUpdate("useCustomTextures", false)
    
    local getCooldownSize, setCooldownSize = GetSet("cooldownTextSize", 27)
    local getCooldownColor, setCooldownColor = GetColorSet("cooldownTextColor", {0.86, 0.84, 0.13, 1})
    local getQuickslotSize, setQuickslotSize = GetSet("quickslotTextSize", 27)
    local getQuickslotColor, setQuickslotColor = GetColorSet("quickslotTextColor", {1, 1, 1, 1})
    local getBackBarOpacity, setBackBarOpacity = GetSet("backBarOpacity", 0.5)
    local getWeaponAnim, setWeaponAnim = GetSet("weaponSwapAnimation", false)
    
    local getShowUlt, setShowUlt = GetSetNoUpdate("showUltimateNumber", false)
    local getUltSize, setUltSize = GetSet("ultimateTextSize", 27)
    local getUltColor, setUltColor = GetColorSet("ultimateTextColor", {1, 1, 1, 1})
    
    local getShowQuickCool, setShowQuickCool = GetSetNoUpdate("showQuickslotCooldown", false)
    
    local getShowGlow, setShowGlow = GetSetNoUpdate("showCombatGlow", false)
    local getGlowColor, setGlowColor = GetColorSet("combatGlowColor", {1, 0.3, 0.1, 0.8})
    local getShowCombatIcon, setShowCombatIcon = GetSetNoUpdate("showCombatIcon", false)
    local getPlayAudio, setPlayAudio = GetSetNoUpdate("playCombatAudio", false)
    
    local getOrbAnim, setOrbAnim = GetSet("orbAnimFlow", false)
    local getHideLeft, setHideLeft = GetSet("hideLeftOrnament", false)
    local getLeftSize, setLeftSize = GetSet("leftOrbSizeScale", 1.0)
    local getHideRight, setHideRight = GetSet("hideRightOrnament", false)
    local getRightSize, setRightSize = GetSet("rightOrbSizeScale", 1.0)
    
    local getHealthSize, setHealthSize = GetSet("healthTextSize", 20)
    local getHealthColor, setHealthColor = GetColorSet("healthTextColor", {1, 1, 1, 1})
    local getMagsize, setMagSize = GetSet("magickaTextSize", 20)
    local getMagColor, setMagColor = GetColorSet("magickaTextColor", {1, 1, 1, 1})
    local getStamSize, setStamSize = GetSet("staminaTextSize", 20)
    local getStamColor, setStamColor = GetColorSet("staminaTextColor", {1, 1, 1, 1})
    local getShieldSize, setShieldSize = GetSet("shieldTextSize", 20)
    local getShieldColor, setShieldColor = GetColorSet("shieldTextColor", {0, 1, 1, 1})
    
    local getXpEnabled, setXpEnabled = GetSet("xpBarEnabled", false)
    local getXpSize, setXpSize = GetSet("xpBarTextSize", 16)
    local getXpColor, setXpColor = GetColorSet("xpBarTextColor", {1, 1, 1, 1})
    
    local getCastEnabled, setCastEnabled = GetSet("castBarEnabled", false)
    local getCastAlways, setCastAlways = GetSet("castBarAlwaysShow", false)
    local getCastSize, setCastSize = GetSet("castBarTextSize", 16)
    local getCastColor, setCastColor = GetColorSet("castBarTextColor", {1, 1, 1, 1})
    
    local getMountEnabled, setMountEnabled = GetSet("mountBarEnabled", false)
    local getMountSize, setMountSize = GetSet("mountBarTextSize", 16)
    local getMountColor, setMountColor = GetColorSet("mountBarTextColor", {1, 1, 1, 1})

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
			getFunc = getScale,
			setFunc = setScale,
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
			getFunc = getOffset,
			setFunc = setOffset,
			disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
			default = 0,
		},
		{
			type = "checkbox",
			name = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_USE_CUSTOM_TEXTURES),
			tooltip = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_USE_CUSTOM_TEXTURES_TOOLTIP),
			getFunc = getCustomTex,
			setFunc = setCustomTex,
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
                    getFunc = getCooldownSize,
                    setFunc = setCooldownSize,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_FONT_COLOR),
                    tooltip = GetString(SI_BETTERUI_SKILL_COOLDOWN_COLOR_TOOLTIP),
                    getFunc = getCooldownColor,
                    setFunc = setCooldownColor,
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
                    getFunc = getQuickslotSize,
                    setFunc = setQuickslotSize,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_FONT_COLOR),
                    tooltip = GetString(SI_BETTERUI_QUICKSLOT_COLOR_TOOLTIP),
                    getFunc = getQuickslotColor,
                    setFunc = setQuickslotColor,
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
                    getFunc = getBackBarOpacity,
                    setFunc = setBackBarOpacity,
                    width = "full",
                },
                {
                    type = "checkbox",
                    name = "Enable Weapon Swap Animation",
                    tooltip = "Plays a slide animation when switching between main and backup weapon bars.",
                    getFunc = getWeaponAnim,
                    setFunc = setWeaponAnim,
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
                    getFunc = getShowUlt,
                    setFunc = setShowUlt,
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
                    getFunc = getUltSize,
                    setFunc = setUltSize,
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
                    getFunc = getUltColor,
                    setFunc = setUltColor,
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
                    getFunc = getShowQuickCool,
                    setFunc = setShowQuickCool,
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
                    getFunc = getShowGlow,
                    setFunc = setShowGlow,
                    width = "full",
                    warning = "Requires Reload UI",
                    requiresReload = true,
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_COMBAT_GLOW_COLOR),
                    tooltip = GetString(SI_BETTERUI_COMBAT_GLOW_COLOR_TOOLTIP),
                    getFunc = getGlowColor,
                    setFunc = setGlowColor,
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
                    getFunc = getShowCombatIcon,
                    setFunc = setShowCombatIcon,
                    width = "full",
                    warning = "Requires Reload UI",
                    requiresReload = true,
                },
                {
                    type = "checkbox",
                    name = GetString(SI_BETTERUI_COMBAT_AUDIO_ENABLED),
                    tooltip = GetString(SI_BETTERUI_COMBAT_AUDIO_ENABLED_TOOLTIP),
                    getFunc = getPlayAudio,
                    setFunc = setPlayAudio,
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
                    getFunc = getOrbAnim,
                    setFunc = setOrbAnim,
                    disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
                    width = "full",
                },
                -- Ornament Visibility Settings
                {
                    type = "checkbox",
                    name = GetString(SI_BETTERUI_HIDE_LEFT_ORNAMENT),
                    tooltip = GetString(SI_BETTERUI_HIDE_LEFT_ORNAMENT_TOOLTIP),
                    getFunc = getHideLeft,
                    setFunc = setHideLeft,
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
                    getFunc = getLeftSize,
                    setFunc = setLeftSize,
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
                    getFunc = getHideRight,
                    setFunc = setHideRight,
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
                    getFunc = getRightSize,
                    setFunc = setRightSize,
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
                    getFunc = getHealthSize,
                    setFunc = setHealthSize,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_ORB_TEXT_HEALTH_COLOR),
                    tooltip = GetString(SI_BETTERUI_ORB_TEXT_HEALTH_COLOR_TOOLTIP),
                    getFunc = getHealthColor,
                    setFunc = setHealthColor,
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
                    getFunc = getMagsize,
                    setFunc = setMagSize,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_ORB_TEXT_MAGICKA_COLOR),
                    tooltip = GetString(SI_BETTERUI_ORB_TEXT_MAGICKA_COLOR_TOOLTIP),
                    getFunc = getMagColor,
                    setFunc = setMagColor,
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
                    getFunc = getStamSize,
                    setFunc = setStamSize,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_ORB_TEXT_STAMINA_COLOR),
                    tooltip = GetString(SI_BETTERUI_ORB_TEXT_STAMINA_COLOR_TOOLTIP),
                    getFunc = getStamColor,
                    setFunc = setStamColor,
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
                    getFunc = getShieldSize,
                    setFunc = setShieldSize,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_ORB_TEXT_SHIELD_COLOR),
                    tooltip = GetString(SI_BETTERUI_ORB_TEXT_SHIELD_COLOR_TOOLTIP),
                    getFunc = getShieldColor,
                    setFunc = setShieldColor,
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
                    getFunc = getXpEnabled,
                    setFunc = setXpEnabled,
                    width = "full",
                },
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_XP_BAR_TEXT_SIZE),
                    tooltip = GetString(SI_BETTERUI_XP_BAR_TEXT_SIZE_TOOLTIP),
                    min = 5,
                    max = 32,
                    step = 1,
                    getFunc = getXpSize,
                    setFunc = setXpSize,
                    disabled = function() return not BETTERUI.Settings.Modules["ResourceOrbFrames"].xpBarEnabled end,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_XP_BAR_TEXT_COLOR),
                    tooltip = GetString(SI_BETTERUI_XP_BAR_TEXT_COLOR_TOOLTIP),
                    getFunc = getXpColor,
                    setFunc = setXpColor,
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
                    getFunc = getCastEnabled,
                    setFunc = setCastEnabled,
                    width = "full",
                },
                {
                    type = "checkbox",
                    name = GetString(SI_BETTERUI_CAST_BAR_ALWAYS_SHOW),
                    tooltip = GetString(SI_BETTERUI_CAST_BAR_ALWAYS_SHOW_TOOLTIP),
                    getFunc = getCastAlways,
                    setFunc = setCastAlways,
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
                    getFunc = getCastSize,
                    setFunc = setCastSize,
                    disabled = function() return not BETTERUI.Settings.Modules["ResourceOrbFrames"].castBarEnabled end,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_CAST_BAR_TEXT_COLOR),
                    tooltip = GetString(SI_BETTERUI_CAST_BAR_TEXT_COLOR_TOOLTIP),
                    getFunc = getCastColor,
                    setFunc = setCastColor,
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
                    getFunc = getMountEnabled,
                    setFunc = setMountEnabled,
                    width = "full",
                },
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_MOUNT_BAR_TEXT_SIZE),
                    tooltip = GetString(SI_BETTERUI_MOUNT_BAR_TEXT_SIZE_TOOLTIP),
                    min = 5,
                    max = 32,
                    step = 1,
                    getFunc = getMountSize,
                    setFunc = setMountSize,
                    disabled = function() return not BETTERUI.Settings.Modules["ResourceOrbFrames"].mountStaminaBarEnabled end,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_MOUNT_BAR_TEXT_COLOR),
                    tooltip = GetString(SI_BETTERUI_MOUNT_BAR_TEXT_COLOR_TOOLTIP),
                    getFunc = getMountColor,
                    setFunc = setMountColor,
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
        m_enabled = false,
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
        orbAnimFlow = false,
        cooldownTextSize = 27,
        cooldownTextColor = {0.86, 0.84, 0.13, 1},
        quickslotTextSize = 27,
        quickslotTextColor = {1, 1, 1, 1},
        weaponSwapAnimation = false,
        showUltimateNumber = false,
        ultimateTextSize = 27,
        ultimateTextColor = {1, 1, 1, 1},
        showQuickslotCooldown = false,
        showCombatGlow = false,
        combatGlowColor = {1, 0.3, 0.1, 0.8},
        showCombatIcon = false,
        playCombatAudio = false,
        backBarOpacity = 1, -- 0.0 to 1.0, lower = more dimmed
        hideLeftOrnament = false,
        hideRightOrnament = false,
        leftOrbSizeScale = 1.0,   -- 1.0, 1.1, or 1.2 (only used when ornament hidden)
        rightOrbSizeScale = 1.0,  -- 1.0, 1.1, or 1.2 (only used when ornament hidden)
        customFrontBar = {
            m_enabled = true,
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
    if m_options.m_enabled == nil then m_options.m_enabled = defaults.m_enabled end
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
    if m_options.orbAnimFlow == nil then m_options.orbAnimFlow = defaults.orbAnimFlow end
    if m_options.cooldownTextSize == nil then m_options.cooldownTextSize = defaults.cooldownTextSize end
    if m_options.cooldownTextColor == nil then m_options.cooldownTextColor = defaults.cooldownTextColor end
    if m_options.quickslotTextSize == nil then m_options.quickslotTextSize = defaults.quickslotTextSize end
    if m_options.quickslotTextColor == nil then m_options.quickslotTextColor = defaults.quickslotTextColor end
    if m_options.weaponSwapAnimation == nil then m_options.weaponSwapAnimation = defaults.weaponSwapAnimation end
    if m_options.showUltimateNumber == nil then m_options.showUltimateNumber = defaults.showUltimateNumber end
    if m_options.ultimateTextSize == nil then m_options.ultimateTextSize = defaults.ultimateTextSize end
    if m_options.ultimateTextColor == nil then m_options.ultimateTextColor = defaults.ultimateTextColor end
    if m_options.showQuickslotCooldown == nil then m_options.showQuickslotCooldown = defaults.showQuickslotCooldown end
    if m_options.showCombatGlow == nil then m_options.showCombatGlow = defaults.showCombatGlow end
    if m_options.combatGlowColor == nil then m_options.combatGlowColor = defaults.combatGlowColor end
    if m_options.showCombatIcon == nil then m_options.showCombatIcon = defaults.showCombatIcon end
    if m_options.playCombatAudio == nil then m_options.playCombatAudio = defaults.playCombatAudio end
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
        if cfb.m_enabled == nil then cfb.m_enabled = d_cfb.m_enabled end
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
