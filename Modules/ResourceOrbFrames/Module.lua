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
        if BETTERUI.ResourceOrbFrames and BETTERUI.ResourceOrbFrames.ApplySettings then
            BETTERUI.ResourceOrbFrames.ApplySettings()
        end
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
            name = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_HEADER),
            width = "full",
        },
        {
            type = "description",
            text = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_DESC),
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
        {
            type = "button",
            name = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET),
            tooltip = GetString(SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET_TOOLTIP),
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

    -- Submenu definitions extracted to Settings/SettingsSubmenus.lua
    -- Build them by passing accessor references
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
