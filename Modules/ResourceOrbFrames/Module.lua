--[[
File: Modules/ResourceOrbFrames/Module.lua
Purpose: Configuration module for Resource Orb Frames.
         Manages LibAddonMenu settings panel and default values.
]]

---@type BetterUIModuleRoot
BETTERUI.ResourceOrbFrames = BETTERUI.ResourceOrbFrames or {}
local ResourceOrbFrames = BETTERUI.ResourceOrbFrames

ResourceOrbFrames.ARCHETYPE = "settings-owner"
---@type BetterUIModuleRootContract
ResourceOrbFrames.ROOT_CONTRACT = {
    name = "ResourceOrbFrames",
    archetype = ResourceOrbFrames.ARCHETYPE,
    initOwner = "Modules/ResourceOrbFrames/Module.lua",
    setupOwner = "Modules/ResourceOrbFrames/Module.lua",
    runtimeOwner = "Modules/ResourceOrbFrames/ResourceOrbFrames.lua + Modules/ResourceOrbFrames/SkillBar/",
    settingsOwner = "Modules/ResourceOrbFrames/Module.lua + Modules/ResourceOrbFrames/Settings/",
    notes = "Module.lua owns the public entrypoints and settings panel, while Settings/Defaults.lua owns defaults data and ResourceOrbFrames.lua/SkillBar/ own runtime behavior.",
}

--- Re-exposes the standard module init contract from Module.lua while delegating
--- the actual defaults work to Settings/Defaults.lua.
---@param m_options BetterUIModuleOptions|nil Module options table
---@return BetterUIModuleOptions m_options Options table with defaults applied
---@type BetterUIModuleInitHook
function ResourceOrbFrames.InitModule(m_options)
    local initializeDefaults = ResourceOrbFrames.InitializeDefaults
    if type(initializeDefaults) == "function" then
        return initializeDefaults(m_options)
    end
    return m_options or {}
end

--- Initializes the settings panel for Resource Orb Frames.
---
--- Purpose: Creates a LibAddonMenu panel with all configurable options.
--- Note: This is the LAM panel setup function, NOT the defaults-initialization
---       function. Public InitModule is exposed from this file and delegates to
---       Settings/Defaults.lua.
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

    local SettingsUtils = ResourceOrbFrames.Utils and ResourceOrbFrames.Utils.Settings or {}
    local GetResourceOrbSettings = SettingsUtils.Get or function()
        return BETTERUI.GetModuleSettings("ResourceOrbFrames")
    end
    local EnsureResourceOrbSettings = SettingsUtils.Ensure or function()
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

    local function CreateSettingContract(key, fallback)
        local defaultValue = Default(key, fallback)
        local getFunc, setFunc = GetSet(key, defaultValue)
        return {
            key = key,
            default = defaultValue,
            get = getFunc,
            set = setFunc,
        }
    end

    local function CreateColorContract(key, fallback)
        local defaultValue = CloneColor(Default(key, nil), fallback)
        local getFunc, setFunc = GetColorSet(key, defaultValue)
        return {
            key = key,
            default = defaultValue,
            get = getFunc,
            set = setFunc,
        }
    end

    local function CreateTextContract(sizeKey, sizeFallback, colorKey, colorFallback)
        return {
            size = CreateSettingContract(sizeKey, sizeFallback),
            color = CreateColorContract(colorKey, colorFallback),
        }
    end

    local generalContracts = {
        scale = CreateSettingContract("scale", 1),
        offsetX = CreateSettingContract("offsetX", 0),
        offsetY = CreateSettingContract("offsetY", 0),
    }

    local sharedContracts = {
        getSettings = GetResourceOrbSettings,
        resetSettingsGroup = ResetSettingsGroup,
    }

    local settingsContracts = {
        skillBars = {
            cooldownText = CreateTextContract("cooldownTextSize", BETTERUI_DEFAULT_SKILL_TEXT_SIZE, "cooldownTextColor",
                { 0.86, 0.84, 0.13, 1 }),
            quickslot = {
                showCooldown = CreateSettingContract("showQuickslotCooldown", true),
                showCount = CreateSettingContract("showQuickslotCount", true),
                text = CreateTextContract("quickslotTextSize", 27, "quickslotTextColor", { 1, 1, 1, 1 }),
            },
            backBar = {
                opacity = CreateSettingContract("backBarOpacity", 1),
                hidden = CreateSettingContract("hideBackBar", false),
                weaponSwapAnimation = CreateSettingContract("weaponSwapAnimation", true),
            },
            ultimate = {
                showNumber = CreateSettingContract("showUltimateNumber", true),
                text = CreateTextContract("ultimateTextSize", 27, "ultimateTextColor", { 1, 1, 1, 1 }),
            },
            combatIndicators = {
                glow = CreateSettingContract("showCombatGlow", true),
                icon = CreateSettingContract("showCombatIcon", true),
                audio = CreateSettingContract("playCombatAudio", true),
            },
        },
        orbText = {
            visuals = {
                animations = CreateSettingContract("orbAnimFlow", true),
                leftOrnamentHidden = CreateSettingContract("hideLeftOrnament", false),
                leftSizeScale = CreateSettingContract("leftOrbSizeScale", 1.0),
                rightOrnamentHidden = CreateSettingContract("hideRightOrnament", false),
                rightSizeScale = CreateSettingContract("rightOrbSizeScale", 1.0),
            },
            resourceText = {
                health = CreateTextContract("healthTextSize", 20, "healthTextColor", { 1, 1, 1, 1 }),
                magicka = CreateTextContract("magickaTextSize", 20, "magickaTextColor", { 1, 1, 1, 1 }),
                stamina = CreateTextContract("staminaTextSize", 20, "staminaTextColor", { 1, 1, 1, 1 }),
                shield = CreateTextContract("shieldTextSize", 20, "shieldTextColor", { 0.4, 0.9, 1, 1 }),
            },
        },
        bars = {
            xp = {
                enabled = CreateSettingContract("xpBarEnabled", true),
                text = CreateTextContract("xpBarTextSize", 16, "xpBarTextColor", { 1, 1, 1, 1 }),
            },
            cast = {
                enabled = CreateSettingContract("castBarEnabled", true),
                alwaysShow = CreateSettingContract("castBarAlwaysShow", false),
                text = CreateTextContract("castBarTextSize", 16, "castBarTextColor", { 1, 1, 1, 1 }),
            },
            mount = {
                enabled = CreateSettingContract("mountStaminaBarEnabled", true),
                text = CreateTextContract("mountStaminaBarTextSize", 16, "mountStaminaBarTextColor",
                    { 1, 1, 1, 1 }),
            },
        },
    }

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
            getFunc = generalContracts.scale.get,
            setFunc = generalContracts.scale.set,
            disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
            default = generalContracts.scale.default,
        },
        {
            type = "slider",
            name = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_OFFSET")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_OFFSET_TOOLTIP")),
            min = -300,
            max = 300,
            step = 5,
            getFunc = generalContracts.offsetY.get,
            setFunc = generalContracts.offsetY.set,
            disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
            default = generalContracts.offsetY.default,
        },
        {
            type = "slider",
            name = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_OFFSET_X")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_OFFSET_X_TOOLTIP")),
            min = -500,
            max = 500,
            step = 5,
            getFunc = generalContracts.offsetX.get,
            setFunc = generalContracts.offsetX.set,
            disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
            default = generalContracts.offsetX.default,
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
    optionsTable[#optionsTable + 1] = BuildSubmenus.BuildSkillBarsSubmenu(settingsContracts.skillBars, sharedContracts)
    optionsTable[#optionsTable + 1] = BuildSubmenus.BuildOrbTextSubmenu(settingsContracts.orbText, sharedContracts)
    do
        local xpSub, castSub, mountSub = BuildSubmenus.BuildBarSubmenus(settingsContracts.bars, sharedContracts)
        optionsTable[#optionsTable + 1] = xpSub
        optionsTable[#optionsTable + 1] = castSub
        optionsTable[#optionsTable + 1] = mountSub
    end

    -- Reorder section groups inside targeted submenus (e.g., Skill Bars) by header name.
    BuildSubmenus.ApplySubmenuSectionOrdering(optionsTable)

    BETTERUI.CIM.Settings.RegisterModulePanel(mId, panelData, optionsTable)
end

--- Sets up the Resource Orb Frames module.
---@type BetterUIModuleSetupHook
function ResourceOrbFrames.Setup()
    InitSettingsPanel("ResourceOrbFrames", "Resource Orb Frames")
end
