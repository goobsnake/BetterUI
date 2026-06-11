
---@type BetterUIModuleRoot
BETTERUI.ResourceOrbFrames = BETTERUI.ResourceOrbFrames or {}
local ResourceOrbFrames = BETTERUI.ResourceOrbFrames
local ARCHETYPES = BETTERUI.CIM and BETTERUI.CIM.ARCHETYPES or {}
local SETTINGS_OWNER = ARCHETYPES.SETTINGS_OWNER or "settings-owner"
ResourceOrbFrames.Settings = ResourceOrbFrames.Settings or {}

---@type BetterUIModuleArchetypeSettingsOwner
ResourceOrbFrames.ARCHETYPE = SETTINGS_OWNER
---@type BetterUIModuleRootContract
ResourceOrbFrames.ROOT_CONTRACT = {
    name = "ResourceOrbFrames",
    archetype = ResourceOrbFrames.ARCHETYPE,
    init = true,
    setup = true,
}

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

--- Initializes ResourceOrbFrames settings panel.
local function InitSettingsPanel(mId, moduleName)
    local panelData = BETTERUI.Init_ModulePanel(moduleName, "Resource Orb Frames Settings")

    local function Apply()
        if type(ResourceOrbFrames.ApplySettings) == "function" then
            ResourceOrbFrames.ApplySettings()
        end
    end

    local moduleDefaults = {}
    if type(ResourceOrbFrames.GetDefaults) == "function" then
        moduleDefaults = ResourceOrbFrames.GetDefaults() or {}
    end

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
        Apply()
    end

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
        enableIndependentOrbOffset = CreateSettingContract("enableIndependentOrbOffset", false),
        orbOffsetX = CreateSettingContract("orbOffsetX", 0),
        orbOffsetY = CreateSettingContract("orbOffsetY", 0),
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
            type = "checkbox",
            name = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_INDEPENDENT_ORB_OFFSET")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_INDEPENDENT_ORB_OFFSET_TOOLTIP")),
            getFunc = generalContracts.enableIndependentOrbOffset.get,
            setFunc = generalContracts.enableIndependentOrbOffset.set,
            disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
            default = generalContracts.enableIndependentOrbOffset.default,
            width = "full",
        },
        {
            type = "slider",
            name = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_ORB_OFFSET_Y")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_ORB_OFFSET_Y_TOOLTIP")),
            min = -300,
            max = 300,
            step = 5,
            getFunc = generalContracts.orbOffsetY.get,
            setFunc = generalContracts.orbOffsetY.set,
            disabled = function()
                return not BETTERUI.GetModuleEnabled("ResourceOrbFrames")
                    or not generalContracts.enableIndependentOrbOffset.get()
            end,
            default = generalContracts.orbOffsetY.default,
        },
        {
            type = "slider",
            name = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_ORB_OFFSET_X")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_RESOURCE_ORB_FRAMES_ORB_OFFSET_X_TOOLTIP")),
            min = -300,
            max = 300,
            step = 5,
            getFunc = generalContracts.orbOffsetX.get,
            setFunc = generalContracts.orbOffsetX.set,
            disabled = function()
                return not BETTERUI.GetModuleEnabled("ResourceOrbFrames")
                    or not generalContracts.enableIndependentOrbOffset.get()
            end,
            default = generalContracts.orbOffsetX.default,
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

ResourceOrbFrames.Settings.RegisterPanel = InitSettingsPanel

local function TrackPanelRegistration(reason)
    ResourceOrbFrames._panelRegistrationReason = reason
    ResourceOrbFrames._panelRegistrationDeferred = reason == "missing_register_panel"
end

local function EnsureResourceOrbFramesSetupContracts()
    BETTERUI.CIM.RegisterModuleAccessors(ResourceOrbFrames, "ResourceOrbFrames")

    if type(BETTERUI.CIM.TryRegisterModulePanel) == "function" then
        local panelOk, panelReason = BETTERUI.CIM.TryRegisterModulePanel(ResourceOrbFrames, "ResourceOrbFrames", "ResourceOrbFrames", "Resource Orb Frames")
        TrackPanelRegistration(panelReason)
        if not panelOk and panelReason ~= nil and panelReason ~= "missing_register_panel" and BETTERUI.Debug then
            BETTERUI.Debug(string.format("[ResourceOrbFrames] Settings panel registration reported: %s",
                tostring(panelReason)))
        end
        return
    end

    if type(ResourceOrbFrames.Settings) == "table" and type(ResourceOrbFrames.Settings.RegisterPanel) == "function" then
        ResourceOrbFrames.Settings.RegisterPanel("ResourceOrbFrames", "Resource Orb Frames")
    end
end

--- Sets up the Resource Orb Frames module.
---@type BetterUIModuleSetupHook
function ResourceOrbFrames.Setup()
    EnsureResourceOrbFramesSetupContracts()
end
