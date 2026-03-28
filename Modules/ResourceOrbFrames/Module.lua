--[[
File: Modules/ResourceOrbFrames/Module.lua
Purpose: Configuration module for Resource Orb Frames.
         Manages LibAddonMenu settings panel and default values.
]]

local LAM = LibAddonMenu2

-- Wire standard font aliases, font descriptors, and GetSetting/SetSetting accessors
BETTERUI.CIM.RegisterModuleAccessors("ResourceOrbFrames")

--- Initializes the settings panel for Resource Orb Frames.
---
--- Purpose: Creates a LibAddonMenu panel with all configurable options.
--- Note: This is the LAM panel setup function, NOT the defaults-initialization
---       function. Defaults are handled by InitModule in Settings/Defaults.lua.
--- Attributes:
--- - Settings for scale, offset, and textures.
--- - Toggle options for ornaments, skill bar features, and overlays.
--- - Customization for fonts (size/color) on all elements.
---
local function InitSettingsPanel(mId, moduleName)
    local panelData = BETTERUI.Init_ModulePanel(moduleName, "Resource Orb Frames Settings")

    local function Apply()
        BETTERUI.CIM.TryCall("ResourceOrbFrames.ApplySettings")
    end

    local moduleDefaults = {}
    local ok, defaults = BETTERUI.CIM.TryCall("ResourceOrbFrames.GetDefaults")
    if ok then moduleDefaults = defaults end

    local function Default(key, fallback)
        local value = moduleDefaults[key]
        if value == nil then
            return fallback
        end
        return value
    end

    local function GetResourceOrbSettings()
        return BETTERUI.GetModuleSettings("ResourceOrbFrames")
    end

    local function EnsureResourceOrbSettings()
        return BETTERUI.EnsureModuleSettings("ResourceOrbFrames")
    end

    local CloneColor = BETTERUI.CloneColor

    --[[
    Function: ResetSettingsGroup
    Description: Resets a group of settings keys to their defaults and applies changes.
    Rationale: Extracted from 3 duplicated reset-button function bodies to eliminate boilerplate.
    param: keyDefaults (table) - Array of {key, value?, isColor?, colorFallback?} entries.
    ]]
    local function ResetSettingsGroup(keyDefaults)
        local settings = EnsureResourceOrbSettings()
        if not settings then return end
        for _, entry in ipairs(keyDefaults) do
            if entry.isColor then
                settings[entry.key] = CloneColor(Default(entry.key, nil), entry.colorFallback)
            else
                settings[entry.key] = Default(entry.key, entry.value)
            end
        end
        BETTERUI.CIM.TryCall("ResourceOrbFrames.ApplySettings")
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
    local getMagSize, setMagSize = GetSet("magickaTextSize", Default("magickaTextSize", 20))
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
            name = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_HEADER")),
            width = "full",
        },
        {
            type = "description",
            text = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_DESC")),
            width = "full",
        },

        {
            type = "slider",
            name = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_SCALE")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_SCALE_TOOLTIP")),
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
            name = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_OFFSET")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_OFFSET_TOOLTIP")),
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
            name = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_OFFSET_X")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_OFFSET_X_TOOLTIP")),
            min = -500,
            max = 500,
            step = 5,
            getFunc = getOffsetX,
            setFunc = setOffsetX,
            disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
            default = Default("offsetX", 0),
        },
        {
            type = "button",
            name = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET_TOOLTIP")),
            func = function()
                ResetSettingsGroup({
                    { key = "scale", value = 1 },
                    { key = "offsetX", value = 0 },
                    { key = "offsetY", value = 0 },
                })
            end,
            disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
            width = "half",
        },
    }

    local BuildSubmenus = BETTERUI.ResourceOrbFrames.SettingsSubmenus
    local submenuAccessors = {
        -- Settings helpers
        GetSettings = GetResourceOrbSettings,
        ResetSettingsGroup = ResetSettingsGroup,
        -- Skill Bars
        getCooldownSize = getCooldownSize, setCooldownSize = setCooldownSize,
        getCooldownColor = getCooldownColor, setCooldownColor = setCooldownColor,
        getQuickslotSize = getQuickslotSize, setQuickslotSize = setQuickslotSize,
        getQuickslotColor = getQuickslotColor, setQuickslotColor = setQuickslotColor,
        getBackBarOpacity = getBackBarOpacity, setBackBarOpacity = setBackBarOpacity,
        getHideBackBar = getHideBackBar, setHideBackBar = setHideBackBar,
        getWeaponAnim = getWeaponAnim, setWeaponAnim = setWeaponAnim,
        getShowUlt = getShowUlt, setShowUlt = setShowUlt,
        getUltSize = getUltSize, setUltSize = setUltSize,
        getUltColor = getUltColor, setUltColor = setUltColor,
        getShowQuickCool = getShowQuickCool, setShowQuickCool = setShowQuickCool,
        getShowQuickCount = getShowQuickCount, setShowQuickCount = setShowQuickCount,
        getShowGlow = getShowGlow, setShowGlow = setShowGlow,
        getShowCombatIcon = getShowCombatIcon, setShowCombatIcon = setShowCombatIcon,
        getPlayAudio = getPlayAudio, setPlayAudio = setPlayAudio,
        -- Orb Text
        getOrbAnim = getOrbAnim, setOrbAnim = setOrbAnim,
        getHideLeft = getHideLeft, setHideLeft = setHideLeft,
        getLeftSize = getLeftSize, setLeftSize = setLeftSize,
        getHideRight = getHideRight, setHideRight = setHideRight,
        getRightSize = getRightSize, setRightSize = setRightSize,
        getHealthSize = getHealthSize, setHealthSize = setHealthSize,
        getHealthColor = getHealthColor, setHealthColor = setHealthColor,
        getMagSize = getMagSize, setMagSize = setMagSize,
        getMagColor = getMagColor, setMagColor = setMagColor,
        getStamSize = getStamSize, setStamSize = setStamSize,
        getStamColor = getStamColor, setStamColor = setStamColor,
        getShieldSize = getShieldSize, setShieldSize = setShieldSize,
        getShieldColor = getShieldColor, setShieldColor = setShieldColor,
        -- Bar submenus
        getXpEnabled = getXpEnabled, setXpEnabled = setXpEnabled,
        getXpSize = getXpSize, setXpSize = setXpSize,
        getXpColor = getXpColor, setXpColor = setXpColor,
        getCastEnabled = getCastEnabled, setCastEnabled = setCastEnabled,
        getCastAlways = getCastAlways, setCastAlways = setCastAlways,
        getCastSize = getCastSize, setCastSize = setCastSize,
        getCastColor = getCastColor, setCastColor = setCastColor,
        getMountEnabled = getMountEnabled, setMountEnabled = setMountEnabled,
        getMountSize = getMountSize, setMountSize = setMountSize,
        getMountColor = getMountColor, setMountColor = setMountColor,
    }

    -- Append all submenu tables from SettingsSubmenus.lua
    optionsTable[#optionsTable + 1] = BuildSubmenus.BuildSkillBarsSubmenu(submenuAccessors)
    optionsTable[#optionsTable + 1] = BuildSubmenus.BuildOrbTextSubmenu(submenuAccessors)
    do
        local xpSub, castSub, mountSub = BuildSubmenus.BuildBarSubmenus(submenuAccessors)
        optionsTable[#optionsTable + 1] = xpSub
        optionsTable[#optionsTable + 1] = castSub
        optionsTable[#optionsTable + 1] = mountSub
    end

    -- Reorder section groups inside targeted submenus (e.g., Skill Bars) by header name.
    BuildSubmenus.ApplySubmenuSectionOrdering(optionsTable)

    -- Alphabetize top-level submenu rows, then alphabetize settings inside each section/submenu.
    BETTERUI.CIM.TryCall("CIM.Settings.SortTopLevelSubmenusAlphabetically", optionsTable)

    -- Alphabetize top-level General settings and all submenu settings.
    BETTERUI.CIM.TryCall("CIM.Settings.SortSettingsAlphabetically", optionsTable, true)

    LAM:RegisterAddonPanel("BETTERUI_" .. mId, panelData)
    LAM:RegisterOptionControls("BETTERUI_" .. mId, optionsTable)
end

--- Sets up the Resource Orb Frames module.
---@return nil
function BETTERUI.ResourceOrbFrames.Setup()
    InitSettingsPanel("ResourceOrbFrames", "Resource Orb Frames")
end
