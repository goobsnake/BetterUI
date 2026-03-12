--[[
File: Modules/ResourceOrbFrames/Module.lua
Purpose: Configuration module for Resource Orb Frames.
         Manages LibAddonMenu settings panel and default values.
Author: BetterUI Team
Last Modified: 2026-02-13
]]

local LAM = LibAddonMenu2

local function NormalizeSectionSortName(name)
    if type(name) ~= "string" then
        return ""
    end

    local normalized = name
    normalized = normalized:gsub("|c%x%x%x%x%x%x", "")
    normalized = normalized:gsub("|r", "")
    normalized = normalized:gsub("|t[^|]+|t", "")
    normalized = normalized:gsub("%s+", " ")
    normalized = normalized:gsub("^%s+", "")
    normalized = normalized:gsub("%s+$", "")

    if zo_strlower then
        return zo_strlower(normalized)
    end
    return string.lower(normalized)
end

local function SortSubmenuHeaderSectionsAlphabetically(controls)
    if type(controls) ~= "table" then
        return
    end

    local trailingButtons = {}
    while #controls > 0 do
        local lastControl = controls[#controls]
        if type(lastControl) == "table" and lastControl.type == "button" then
            table.insert(trailingButtons, 1, lastControl)
            table.remove(controls, #controls)
        else
            break
        end
    end

    local sections = {}
    local currentSection = nil

    for _, control in ipairs(controls) do
        local isHeader = type(control) == "table" and control.type == "header" and type(control.name) == "string"
        if isHeader then
            currentSection = { control }
            table.insert(sections, currentSection)
        elseif currentSection then
            table.insert(currentSection, control)
        end
    end

    table.sort(sections, function(leftSection, rightSection)
        local leftHeader = leftSection[1]
        local rightHeader = rightSection[1]
        local leftKey = NormalizeSectionSortName(leftHeader and leftHeader.name)
        local rightKey = NormalizeSectionSortName(rightHeader and rightHeader.name)
        if leftKey == rightKey then
            return tostring(leftHeader and leftHeader.name) < tostring(rightHeader and rightHeader.name)
        end
        return leftKey < rightKey
    end)

    local rebuilt = {}
    for _, section in ipairs(sections) do
        for _, control in ipairs(section) do
            table.insert(rebuilt, control)
        end
    end
    for _, control in ipairs(trailingButtons) do
        table.insert(rebuilt, control)
    end

    for i = 1, #controls do
        controls[i] = nil
    end
    for i = 1, #rebuilt do
        controls[i] = rebuilt[i]
    end
end

local function ApplySubmenuSectionOrdering(optionsTable)
    if type(optionsTable) ~= "table" then
        return
    end

    local skillBarsSubmenuName = GetString(SI_BETTERUI_SKILL_BARS_SUBMENU)
    for _, option in ipairs(optionsTable) do
        if type(option) == "table"
            and option.type == "submenu"
            and option.name == skillBarsSubmenuName
            and type(option.controls) == "table" then
            SortSubmenuHeaderSectionsAlphabetically(option.controls)
        end
    end
end

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

    local moduleDefaults = {}
    if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.GetDefaults then
        moduleDefaults = BETTERUI.ResourceOrbFrames.GetDefaults()
    end

    local function Default(key, fallback)
        local value = moduleDefaults[key]
        if value == nil then
            return fallback
        end
        return value
    end

    local function GetResourceOrbSettings()
        local modules = BETTERUI and BETTERUI.Settings and BETTERUI.Settings.Modules
        if not modules then
            return nil
        end
        return modules["ResourceOrbFrames"]
    end

    local function EnsureResourceOrbSettings()
        if not BETTERUI or not BETTERUI.Settings then
            return nil
        end
        BETTERUI.Settings.Modules = BETTERUI.Settings.Modules or {}
        if type(BETTERUI.Settings.Modules["ResourceOrbFrames"]) ~= "table" then
            BETTERUI.Settings.Modules["ResourceOrbFrames"] = {}
        end
        return BETTERUI.Settings.Modules["ResourceOrbFrames"]
    end

    local function CloneColor(value, fallback)
        local source = value
        if type(source) ~= "table" then
            source = fallback
        end
        if type(source) ~= "table" then
            return { 1, 1, 1, 1 }
        end
        return {
            source[1] or 1,
            source[2] or 1,
            source[3] or 1,
            source[4] or 1,
        }
    end

    -- Accessor with live update
    local GetSet = BETTERUI.CreateSettingAccessors("ResourceOrbFrames", Apply)
    local GetColorSet = BETTERUI.CreateColorSettingAccessors("ResourceOrbFrames", Apply)

    local getScale, setScale = GetSet("scale", Default("scale", 1))
    local getOffsetX, setOffsetX = GetSet("offsetX", Default("offsetX", 0))
    local getOffset, setOffset = GetSet("offsetY", Default("offsetY", 0))

    local getCooldownSize, setCooldownSize = GetSet("cooldownTextSize",
        Default("cooldownTextSize", BETTERUI_DEFAULT_SKILL_TEXT_SIZE))
    local getCooldownColor, setCooldownColor = GetColorSet("cooldownTextColor",
        CloneColor(Default("cooldownTextColor", nil), { 0.86, 0.84, 0.13, 1 }))
    local getQuickslotSize, setQuickslotSize = GetSet("quickslotTextSize", Default("quickslotTextSize", 27))
    local getQuickslotColor, setQuickslotColor = GetColorSet("quickslotTextColor",
        CloneColor(Default("quickslotTextColor", nil), { 1, 1, 1, 1 }))
    local getBackBarOpacity, setBackBarOpacity = GetSet("backBarOpacity", Default("backBarOpacity", 1))
    local getHideBackBar, setHideBackBar = GetSet("hideBackBar", Default("hideBackBar", false))
    local getWeaponAnim, setWeaponAnim = GetSet("weaponSwapAnimation", Default("weaponSwapAnimation", true))

    local getShowUlt, setShowUlt = GetSet("showUltimateNumber", Default("showUltimateNumber", true))
    local getUltSize, setUltSize = GetSet("ultimateTextSize", Default("ultimateTextSize", 27))
    local getUltColor, setUltColor = GetColorSet("ultimateTextColor",
        CloneColor(Default("ultimateTextColor", nil), { 1, 1, 1, 1 }))

    local getShowQuickCool, setShowQuickCool = GetSet("showQuickslotCooldown", Default("showQuickslotCooldown", true))
    local getShowQuickCount, setShowQuickCount = GetSet("showQuickslotCount", Default("showQuickslotCount", true))

    local getShowGlow, setShowGlow = GetSet("showCombatGlow", Default("showCombatGlow", true))
    local getShowCombatIcon, setShowCombatIcon = GetSet("showCombatIcon", Default("showCombatIcon", true))
    local getPlayAudio, setPlayAudio = GetSet("playCombatAudio", Default("playCombatAudio", true))

    local getOrbAnim, setOrbAnim = GetSet("orbAnimFlow", Default("orbAnimFlow", true))
    local getHideLeft, setHideLeft = GetSet("hideLeftOrnament", Default("hideLeftOrnament", false))
    local getLeftSize, setLeftSize = GetSet("leftOrbSizeScale", Default("leftOrbSizeScale", 1.0))
    local getHideRight, setHideRight = GetSet("hideRightOrnament", Default("hideRightOrnament", false))
    local getRightSize, setRightSize = GetSet("rightOrbSizeScale", Default("rightOrbSizeScale", 1.0))

    local getHealthSize, setHealthSize = GetSet("healthTextSize", Default("healthTextSize", 20))
    local getHealthColor, setHealthColor = GetColorSet("healthTextColor",
        CloneColor(Default("healthTextColor", nil), { 1, 1, 1, 1 }))
    -- TODO(cleanup): Rename getMagsize to getMagSize for consistent getter/setter casing
    local getMagsize, setMagSize = GetSet("magickaTextSize", Default("magickaTextSize", 20))
    local getMagColor, setMagColor = GetColorSet("magickaTextColor",
        CloneColor(Default("magickaTextColor", nil), { 1, 1, 1, 1 }))
    local getStamSize, setStamSize = GetSet("staminaTextSize", Default("staminaTextSize", 20))
    local getStamColor, setStamColor = GetColorSet("staminaTextColor",
        CloneColor(Default("staminaTextColor", nil), { 1, 1, 1, 1 }))
    local getShieldSize, setShieldSize = GetSet("shieldTextSize", Default("shieldTextSize", 20))
    local getShieldColor, setShieldColor = GetColorSet("shieldTextColor",
        CloneColor(Default("shieldTextColor", nil), { 0.4, 0.9, 1, 1 }))

    local getXpEnabled, setXpEnabled = GetSet("xpBarEnabled", Default("xpBarEnabled", true))
    local getXpSize, setXpSize = GetSet("xpBarTextSize", Default("xpBarTextSize", 16))
    local getXpColor, setXpColor = GetColorSet("xpBarTextColor",
        CloneColor(Default("xpBarTextColor", nil), { 1, 1, 1, 1 }))

    local getCastEnabled, setCastEnabled = GetSet("castBarEnabled", Default("castBarEnabled", true))
    local getCastAlways, setCastAlways = GetSet("castBarAlwaysShow", Default("castBarAlwaysShow", false))
    local getCastSize, setCastSize = GetSet("castBarTextSize", Default("castBarTextSize", 16))
    local getCastColor, setCastColor = GetColorSet("castBarTextColor",
        CloneColor(Default("castBarTextColor", nil), { 1, 1, 1, 1 }))

    local getMountEnabled, setMountEnabled = GetSet("mountStaminaBarEnabled", Default("mountStaminaBarEnabled", true))
    local getMountSize, setMountSize = GetSet("mountStaminaBarTextSize", Default("mountStaminaBarTextSize", 16))
    local getMountColor, setMountColor = GetColorSet("mountStaminaBarTextColor",
        CloneColor(Default("mountStaminaBarTextColor", nil), { 1, 1, 1, 1 }))

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
            default = Default("scale", 1),
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
            default = Default("offsetY", 0),
        },
        {
            type = "slider",
            name = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_OFFSET_X),
            tooltip = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_OFFSET_X_TOOLTIP),
            min = -500,
            max = 500,
            step = 5,
            getFunc = getOffsetX,
            setFunc = setOffsetX,
            disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
            default = Default("offsetX", 0),
        },
        -- TODO(refactor): Extract reset settings pattern to single ResetSettings() function - duplicated at lines 332, 509, 689
        {
            type = "button",
            name = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET),
            tooltip = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET_TOOLTIP),
            func = function()
                local settings = EnsureResourceOrbSettings()
                if not settings then
                    return
                end
                settings.scale = Default("scale", 1)
                settings.offsetX = Default("offsetX", 0)
                settings.offsetY = Default("offsetY", 0)

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
                    name = GetString(SI_BETTERUI_TEXT_SIZE),
                    tooltip = GetString(SI_BETTERUI_SKILL_COOLDOWN_SCALE_TOOLTIP),
                    min = 12,
                    max = 30,
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
                    type = "checkbox",
                    name = GetString(SI_BETTERUI_SHOW_QUICKSLOT_COOLDOWN),
                    tooltip = GetString(SI_BETTERUI_SHOW_QUICKSLOT_COOLDOWN_TOOLTIP),
                    getFunc = getShowQuickCool,
                    setFunc = setShowQuickCool,
                    width = "full",
                },
                {
                    type = "checkbox",
                    name = GetString(SI_BETTERUI_SHOW_QUICKSLOT_QUANTITY),
                    tooltip = GetString(SI_BETTERUI_SHOW_QUICKSLOT_QUANTITY_TOOLTIP),
                    getFunc = getShowQuickCount,
                    setFunc = setShowQuickCount,
                    width = "full",
                },
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_TEXT_SIZE),
                    tooltip = GetString(SI_BETTERUI_QUICKSLOT_SCALE_TOOLTIP),
                    min = 12,
                    max = 30,
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
                    disabled = function()
                        local settings = GetResourceOrbSettings()
                        return not BETTERUI.GetModuleEnabled("ResourceOrbFrames")
                            or (settings and settings.hideBackBar)
                    end,
                    width = "full",
                },
                {
                    type = "checkbox",
                    name = GetString(SI_BETTERUI_HIDE_BACK_BAR),
                    tooltip = GetString(SI_BETTERUI_HIDE_BACK_BAR_TOOLTIP),
                    getFunc = getHideBackBar,
                    setFunc = setHideBackBar,
                    disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
                    width = "full",
                },
                {
                    type = "checkbox",
                    name = GetString(SI_BETTERUI_ROF_WEAPON_SWAP_ANIMATION),
                    tooltip = GetString(SI_BETTERUI_ROF_WEAPON_SWAP_ANIMATION_TOOLTIP),
                    getFunc = getWeaponAnim,
                    setFunc = setWeaponAnim,
                    disabled = function()
                        local settings = GetResourceOrbSettings()
                        return not BETTERUI.GetModuleEnabled("ResourceOrbFrames")
                            or (settings and settings.hideBackBar)
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
                    getFunc = getShowUlt,
                    setFunc = setShowUlt,
                    width = "full",
                },
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_ULTIMATE_TEXT_SIZE),
                    tooltip = GetString(SI_BETTERUI_ULTIMATE_TEXT_SIZE_TOOLTIP),
                    min = 12,
                    max = 30,
                    step = 1,
                    getFunc = getUltSize,
                    setFunc = setUltSize,
                    disabled = function()
                        local settings = GetResourceOrbSettings()
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
                        local settings = GetResourceOrbSettings()
                        return not settings or not settings.showUltimateNumber
                    end,
                    width = "full",
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
                },
                {
                    type = "checkbox",
                    name = GetString(SI_BETTERUI_COMBAT_ICON_ENABLED),
                    tooltip = GetString(SI_BETTERUI_COMBAT_ICON_ENABLED_TOOLTIP),
                    getFunc = getShowCombatIcon,
                    setFunc = setShowCombatIcon,
                    width = "full",
                },
                {
                    type = "checkbox",
                    name = GetString(SI_BETTERUI_COMBAT_AUDIO_ENABLED),
                    tooltip = GetString(SI_BETTERUI_COMBAT_AUDIO_ENABLED_TOOLTIP),
                    getFunc = getPlayAudio,
                    setFunc = setPlayAudio,
                    width = "full",
                },
                {
                    type = "button",
                    name = GetString(SI_BETTERUI_RESET_SKILL_BAR),
                    func = function()
                        local settings = EnsureResourceOrbSettings()
                        if not settings then
                            return
                        end
                        settings.cooldownTextSize = Default("cooldownTextSize", 27)
                        settings.cooldownTextColor = CloneColor(Default("cooldownTextColor", nil),
                            { 0.86, 0.84, 0.13, 1 })
                        settings.quickslotTextSize = Default("quickslotTextSize", 27)
                        settings.quickslotTextColor = CloneColor(Default("quickslotTextColor", nil), { 1, 1, 1, 1 })
                        settings.backBarOpacity = Default("backBarOpacity", 1)
                        settings.hideBackBar = Default("hideBackBar", false)
                        settings.weaponSwapAnimation = Default("weaponSwapAnimation", true)
                        settings.showUltimateNumber = Default("showUltimateNumber", true)
                        settings.ultimateTextSize = Default("ultimateTextSize", 27)
                        settings.ultimateTextColor = CloneColor(Default("ultimateTextColor", nil), { 1, 1, 1, 1 })
                        settings.showQuickslotCooldown = Default("showQuickslotCooldown", true)
                        settings.showQuickslotCount = Default("showQuickslotCount", true)
                        settings.showCombatGlow = Default("showCombatGlow", true)
                        settings.showCombatIcon = Default("showCombatIcon", true)
                        settings.playCombatAudio = Default("playCombatAudio", true)

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
                {
                    type = "header",
                    name = GetString(SI_BETTERUI_ORB_VISUALS_HEADER),
                },
                {
                    type = "checkbox",
                    name = GetString(SI_BETTERUI_ROF_ORB_ANIMATIONS),
                    tooltip = GetString(SI_BETTERUI_ROF_ORB_ANIMATIONS_TOOLTIP),
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
                        local settings = GetResourceOrbSettings()
                        return not BETTERUI.GetModuleEnabled("ResourceOrbFrames")
                            or not (settings and settings.hideLeftOrnament)
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
                        local settings = GetResourceOrbSettings()
                        return not BETTERUI.GetModuleEnabled("ResourceOrbFrames")
                            or not (settings and settings.hideRightOrnament)
                    end,
                    width = "full",
                },
                {
                    type = "header",
                    name = GetString(SI_BETTERUI_ORB_TEXT_SETTINGS_HEADER),
                },
                -- Health Text Settings
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_ORB_TEXT_HEALTH_SIZE),
                    tooltip = GetString(SI_BETTERUI_ORB_TEXT_HEALTH_SIZE_TOOLTIP),
                    min = 12,
                    max = 26,
                    step = 1,
                    getFunc = getHealthSize,
                    setFunc = function(value)
                        setHealthSize(value); CALLBACK_MANAGER:FireCallbacks("BetterUI_ForceLayoutUpdate")
                    end,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_ORB_TEXT_HEALTH_COLOR),
                    tooltip = GetString(SI_BETTERUI_ORB_TEXT_HEALTH_COLOR_TOOLTIP),
                    getFunc = getHealthColor,
                    setFunc = function(r, g, b, a)
                        setHealthColor(r, g, b, a); CALLBACK_MANAGER:FireCallbacks("BetterUI_ForceLayoutUpdate")
                    end,
                    width = "full",
                },
                -- Magicka Text Settings
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_ORB_TEXT_MAGICKA_SIZE),
                    tooltip = GetString(SI_BETTERUI_ORB_TEXT_MAGICKA_SIZE_TOOLTIP),
                    min = 12,
                    max = 26,
                    step = 1,
                    getFunc = getMagsize,
                    setFunc = function(value)
                        setMagSize(value); CALLBACK_MANAGER:FireCallbacks("BetterUI_ForceLayoutUpdate")
                    end,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_ORB_TEXT_MAGICKA_COLOR),
                    tooltip = GetString(SI_BETTERUI_ORB_TEXT_MAGICKA_COLOR_TOOLTIP),
                    getFunc = getMagColor,
                    setFunc = function(r, g, b, a)
                        setMagColor(r, g, b, a); CALLBACK_MANAGER:FireCallbacks("BetterUI_ForceLayoutUpdate")
                    end,
                    width = "full",
                },
                -- Stamina Text Settings
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_ORB_TEXT_STAMINA_SIZE),
                    tooltip = GetString(SI_BETTERUI_ORB_TEXT_STAMINA_SIZE_TOOLTIP),
                    min = 12,
                    max = 26,
                    step = 1,
                    getFunc = getStamSize,
                    setFunc = function(value)
                        setStamSize(value); CALLBACK_MANAGER:FireCallbacks("BetterUI_ForceLayoutUpdate")
                    end,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_ORB_TEXT_STAMINA_COLOR),
                    tooltip = GetString(SI_BETTERUI_ORB_TEXT_STAMINA_COLOR_TOOLTIP),
                    getFunc = getStamColor,
                    setFunc = function(r, g, b, a)
                        setStamColor(r, g, b, a); CALLBACK_MANAGER:FireCallbacks("BetterUI_ForceLayoutUpdate")
                    end,
                    width = "full",
                },
                -- Shield Text Settings
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_ORB_TEXT_SHIELD_SIZE),
                    tooltip = GetString(SI_BETTERUI_ORB_TEXT_SHIELD_SIZE_TOOLTIP),
                    min = 12,
                    max = 26,
                    step = 1,
                    getFunc = getShieldSize,
                    setFunc = function(value)
                        setShieldSize(value); CALLBACK_MANAGER:FireCallbacks("BetterUI_ForceLayoutUpdate")
                    end,
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
                    name = GetString(SI_BETTERUI_ORB_TEXT_RESET),
                    tooltip = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET_TOOLTIP),
                    func = function()
                        local settings = EnsureResourceOrbSettings()
                        if not settings then
                            return
                        end
                        -- Ornament visibility and orb scaling
                        settings.hideLeftOrnament = Default("hideLeftOrnament", false)
                        settings.hideRightOrnament = Default("hideRightOrnament", false)
                        settings.leftOrbSizeScale = Default("leftOrbSizeScale", 1.0)
                        settings.rightOrbSizeScale = Default("rightOrbSizeScale", 1.0)
                        -- Text settings
                        settings.healthTextSize = Default("healthTextSize", 20)
                        settings.healthTextColor = CloneColor(Default("healthTextColor", nil), { 1, 1, 1, 1 })
                        settings.magickaTextSize = Default("magickaTextSize", 20)
                        settings.magickaTextColor = CloneColor(Default("magickaTextColor", nil), { 1, 1, 1, 1 })
                        settings.staminaTextSize = Default("staminaTextSize", 20)
                        settings.staminaTextColor = CloneColor(Default("staminaTextColor", nil), { 1, 1, 1, 1 })
                        settings.shieldTextSize = Default("shieldTextSize", 20)
                        settings.shieldTextColor = CloneColor(Default("shieldTextColor", nil), { 0.4, 0.9, 1, 1 })

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
                    sortAlwaysFirst = true,
                    getFunc = getXpEnabled,
                    setFunc = setXpEnabled,
                    width = "full",
                },
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_XP_BAR_TEXT_SIZE),
                    tooltip = GetString(SI_BETTERUI_XP_BAR_TEXT_SIZE_TOOLTIP),
                    min = 5,
                    max = 20,
                    step = 1,
                    getFunc = getXpSize,
                    setFunc = setXpSize,
                    disabled = function()
                        local settings = GetResourceOrbSettings()
                        return not (settings and settings.xpBarEnabled == true)
                    end,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_XP_BAR_TEXT_COLOR),
                    tooltip = GetString(SI_BETTERUI_XP_BAR_TEXT_COLOR_TOOLTIP),
                    getFunc = getXpColor,
                    setFunc = setXpColor,
                    disabled = function()
                        local settings = GetResourceOrbSettings()
                        return not (settings and settings.xpBarEnabled == true)
                    end,
                    width = "full",
                },
                {
                    type = "button",
                    name = GetString(SI_BETTERUI_XP_BAR_RESET),
                    tooltip = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET_TOOLTIP),
                    func = function()
                        local settings = EnsureResourceOrbSettings()
                        if not settings then
                            return
                        end
                        settings.xpBarTextSize = Default("xpBarTextSize", 16)
                        settings.xpBarTextColor = CloneColor(Default("xpBarTextColor", nil), { 1, 1, 1, 1 })

                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    -- Check for both overall enabled and specific feature enabled
                    disabled = function()
                        local settings = GetResourceOrbSettings()
                        return not (BETTERUI.GetModuleEnabled("ResourceOrbFrames") and settings and settings.xpBarEnabled == true)
                    end,
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
                    sortAlwaysFirst = true,
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
                    disabled = function()
                        local settings = GetResourceOrbSettings()
                        return not (settings and settings.castBarEnabled == true)
                    end,
                    width = "full",
                },
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_CAST_BAR_TEXT_SIZE),
                    tooltip = GetString(SI_BETTERUI_CAST_BAR_TEXT_SIZE_TOOLTIP),
                    min = 5,
                    max = 20,
                    step = 1,
                    getFunc = getCastSize,
                    setFunc = setCastSize,
                    disabled = function()
                        local settings = GetResourceOrbSettings()
                        return not (settings and settings.castBarEnabled == true)
                    end,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_CAST_BAR_TEXT_COLOR),
                    tooltip = GetString(SI_BETTERUI_CAST_BAR_TEXT_COLOR_TOOLTIP),
                    getFunc = getCastColor,
                    setFunc = setCastColor,
                    disabled = function()
                        local settings = GetResourceOrbSettings()
                        return not (settings and settings.castBarEnabled == true)
                    end,
                    width = "full",
                },
                {
                    type = "button",
                    name = GetString(SI_BETTERUI_CAST_BAR_RESET),
                    tooltip = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET_TOOLTIP),
                    func = function()
                        local settings = EnsureResourceOrbSettings()
                        if not settings then
                            return
                        end
                        settings.castBarTextSize = Default("castBarTextSize", 16)
                        settings.castBarTextColor = CloneColor(Default("castBarTextColor", nil), { 1, 1, 1, 1 })

                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    disabled = function()
                        local settings = GetResourceOrbSettings()
                        return not (BETTERUI.GetModuleEnabled("ResourceOrbFrames") and settings and settings.castBarEnabled == true)
                    end,
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
                    sortAlwaysFirst = true,
                    getFunc = getMountEnabled,
                    setFunc = setMountEnabled,
                    width = "full",
                },
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_MOUNT_BAR_TEXT_SIZE),
                    tooltip = GetString(SI_BETTERUI_MOUNT_BAR_TEXT_SIZE_TOOLTIP),
                    min = 5,
                    max = 20,
                    step = 1,
                    getFunc = getMountSize,
                    setFunc = setMountSize,
                    disabled = function()
                        local settings = GetResourceOrbSettings()
                        return not (settings and settings.mountStaminaBarEnabled == true)
                    end,
                    width = "full",
                },
                {
                    type = "colorpicker",
                    name = GetString(SI_BETTERUI_MOUNT_BAR_TEXT_COLOR),
                    tooltip = GetString(SI_BETTERUI_MOUNT_BAR_TEXT_COLOR_TOOLTIP),
                    getFunc = getMountColor,
                    setFunc = setMountColor,
                    disabled = function()
                        local settings = GetResourceOrbSettings()
                        return not (settings and settings.mountStaminaBarEnabled == true)
                    end,
                    width = "full",
                },
                {
                    type = "button",
                    name = GetString(SI_BETTERUI_MOUNT_STAMINA_BAR_RESET),
                    tooltip = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET_TOOLTIP),
                    func = function()
                        local settings = EnsureResourceOrbSettings()
                        if not settings then
                            return
                        end
                        settings.mountStaminaBarTextSize = Default("mountStaminaBarTextSize", 16)
                        settings.mountStaminaBarTextColor = CloneColor(Default("mountStaminaBarTextColor", nil),
                            { 1, 1, 1, 1 })

                        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
                            BETTERUI.ResourceOrbFrames.ApplySettings()
                        end
                    end,
                    disabled = function()
                        local settings = GetResourceOrbSettings()
                        return not (BETTERUI.GetModuleEnabled("ResourceOrbFrames") and settings and settings.mountStaminaBarEnabled == true)
                    end,
                    width = "half",
                },
            },
        },
    }

    -- Reorder section groups inside targeted submenus (e.g., Skill Bars) by header name.
    ApplySubmenuSectionOrdering(optionsTable)

    -- Alphabetize top-level submenu rows, then alphabetize settings inside each section/submenu.
    if BETTERUI.CIM and BETTERUI.CIM.Settings and BETTERUI.CIM.Settings.SortTopLevelSubmenusAlphabetically then
        BETTERUI.CIM.Settings.SortTopLevelSubmenusAlphabetically(optionsTable)
    end

    -- Alphabetize top-level General settings and all submenu settings.
    if BETTERUI.CIM and BETTERUI.CIM.Settings and BETTERUI.CIM.Settings.SortSettingsAlphabetically then
        BETTERUI.CIM.Settings.SortSettingsAlphabetically(optionsTable, true)
    end

    LAM:RegisterAddonPanel("BETTERUI_" .. mId, panelData)
    LAM:RegisterOptionControls("BETTERUI_" .. mId, optionsTable)
end

-- Note: InitModule is now provided by Settings/Defaults.lua

--- Sets up the Resource Orb Frames module.
function BETTERUI.ResourceOrbFrames.Setup()
    Init("ResourceOrbFrames", "Resource Orb Frames")
end
