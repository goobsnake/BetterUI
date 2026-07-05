
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
    local GetLiveResourceOrbSettings = SettingsUtils.GetLive or SettingsUtils.Ensure or function()
        if type(BETTERUI.GetModuleSettingsLive) == "function" then
            return BETTERUI.GetModuleSettingsLive("ResourceOrbFrames")
        end
        return EnsureResourceOrbSettings()
    end

    local CloneColor = BETTERUI.CloneColor

    local function TraceResourceOrbSettingsReset(phase, data)
        local L = BETTERUI and BETTERUI.Log
        if not (L and L.TraceEvent) then return end
        data = data or {}
        data.module = "ResourceOrbFrames"
        data.feature = "settingsReset"
        if L.SetLastAction then
            L.SetLastAction({ flow = "resource_orbs.settings_reset", message = "resource_orbs.settings_reset:" .. tostring(phase) })
        end
        local categories = L.CATEGORY or {}
        L.TraceEvent(categories.SETTINGS or categories.GENERAL or "SETTINGS", "resource_orbs.settings_reset", phase, data)
    end

    -- Shared element-drag tracer (BUI-CONS-002), defined once on ROF Utils.
    local TraceDrag = BETTERUI.ResourceOrbFrames.Utils and BETTERUI.ResourceOrbFrames.Utils.TraceDrag or function() end

    local function ResetSettingsGroup(keyDefaults)
        local settings = EnsureResourceOrbSettings()
        TraceResourceOrbSettingsReset("begin", { count = type(keyDefaults) == "table" and #keyDefaults or 0 })
        if not settings then
            TraceResourceOrbSettingsReset("skipped", { reason = "missingSettings" })
            return
        end
        local appliedCount = 0
        for _, entry in ipairs(keyDefaults or {}) do
            local value
            if entry.isColor then
                value = CloneColor(Default(entry.key, nil), entry.colorFallback)
            else
                value = Default(entry.key, entry.value)
            end
            local applied = false
            if type(BETTERUI.SetSetting) == "function" then
                applied = BETTERUI.SetSetting("ResourceOrbFrames", entry.key, value) == true
            else
                settings[entry.key] = value
                applied = true
            end
            if applied then appliedCount = appliedCount + 1 end
            TraceResourceOrbSettingsReset(applied and "setting_applied" or "setting_failed", {
                key = tostring(entry.key),
                isColor = entry.isColor == true,
                viaSetSetting = type(BETTERUI.SetSetting) == "function",
            })
        end
        Apply()
        TraceResourceOrbSettingsReset("end", { appliedCount = appliedCount })
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
        elementPositionsUnlocked = CreateSettingContract("elementPositionsUnlocked", false),
    }
    do
        local setUnlocked = generalContracts.elementPositionsUnlocked.set
        generalContracts.elementPositionsUnlocked.set = function(v)
            local unlocked = v == true
            local previous = generalContracts.elementPositionsUnlocked.get()
            setUnlocked(unlocked)
            local rof = BETTERUI.ResourceOrbFrames
            if unlocked and type(rof.AttachElementDragHandles) == "function" then
                rof.AttachElementDragHandles()
            end
            local drag = rof.Drag
            if drag and type(drag.SetAllElementsUnlocked) == "function" then
                drag.SetAllElementsUnlocked(unlocked, GetLiveResourceOrbSettings)
            end
            TraceResourceOrbSettingsReset("element_positions_global_unlock_toggle", {
                previousUnlocked = previous == true,
                unlocked = unlocked,
                updatedHandles = drag and type(drag.SetAllElementsUnlocked) == "function",
            })
        end
    end

    local sharedContracts = {
        getSettings = GetResourceOrbSettings,
        getLiveSettings = GetLiveResourceOrbSettings,
        resetSettingsGroup = ResetSettingsGroup,
        applySettings = Apply,
        globalUnlock = generalContracts.elementPositionsUnlocked,
    }

    local ELEMENT_POSITION_KEYS = {
        "leftOrb", "rightOrb", "skillBars", "xpBar", "mountBar", "castBar", "quickslot", "companionUltimate"
    }

    local function CreateDefaultElementPositions()
        return {
            leftOrb = { locked = true, offsetX = 0, offsetY = 0 },
            rightOrb = { locked = true, offsetX = 0, offsetY = 0 },
            skillBars = { locked = true, offsetX = 0, offsetY = 0 },
            xpBar = { locked = true, offsetX = 0, offsetY = 0 },
            mountBar = { locked = true, offsetX = 0, offsetY = 0 },
            castBar = { locked = true, offsetX = 0, offsetY = 0 },
            quickslot = { locked = true, offsetX = 0, offsetY = 0 },
            companionUltimate = { locked = true, offsetX = 0, offsetY = 0 },
        }
    end

    local function ResetElementPositions(settings)
        if not settings then
            TraceResourceOrbSettingsReset("element_positions_reset_skipped", { reason = "missingSettings" })
            return
        end
        local previousPositions = settings.elementPositions
        TraceDrag("resource_orbs.element_positions", "global_reset", { fn = "ResourceOrbFrames.ResetElementPositions", count = #ELEMENT_POSITION_KEYS })
        TraceResourceOrbSettingsReset("element_positions_reset_begin", { count = #ELEMENT_POSITION_KEYS })
        settings.elementPositions = CreateDefaultElementPositions()
        settings.elementPositionsUnlocked = false
        local drag = BETTERUI.ResourceOrbFrames.Drag
        for _, elemKey in ipairs(ELEMENT_POSITION_KEYS) do
            local previous = previousPositions and previousPositions[elemKey]
            TraceResourceOrbSettingsReset("element_position_reset", {
                elemKey = elemKey,
                previousLocked = previous and previous.locked,
                previousOffsetX = previous and previous.offsetX,
                previousOffsetY = previous and previous.offsetY,
                usesLiveSettings = true,
                updatedHandle = drag and drag.SetAllElementsUnlocked ~= nil,
            })
        end
        if drag and type(drag.SetAllElementsUnlocked) == "function" then
            drag.SetAllElementsUnlocked(false, GetLiveResourceOrbSettings)
        end
        if drag and type(drag.RefreshSettingsPanel) == "function" then
            drag.RefreshSettingsPanel()
            TraceResourceOrbSettingsReset("settings_panel_refresh_requested", { source = "ResetElementPositions" })
        end
        TraceResourceOrbSettingsReset("element_positions_reset_end", { count = #ELEMENT_POSITION_KEYS })
    end

    local function CreateElemPosContract(elemKey)
        return {
            locked = {
                get = function()
                    local s = GetResourceOrbSettings()
                    return not (s and s.elementPositionsUnlocked == true)
                end,
                set = function(v)
                    local s = EnsureResourceOrbSettings()
                    if s and s.elementPositions and s.elementPositions[elemKey] then
                        local previous = s.elementPositionsUnlocked == true
                        s.elementPositionsUnlocked = v ~= true
                        s.elementPositions[elemKey].locked = v
                        TraceResourceOrbSettingsReset("element_lock_toggle", {
                            elemKey = elemKey,
                            previousUnlocked = previous,
                            locked = v,
                            unlocked = s.elementPositionsUnlocked == true,
                            usesLiveSettings = true,
                        })
                        local rof = BETTERUI.ResourceOrbFrames
                        if s.elementPositionsUnlocked == true and type(rof.AttachElementDragHandles) == "function" then
                            rof.AttachElementDragHandles()
                        end
                        local drag = rof.Drag
                        if drag and type(drag.SetAllElementsUnlocked) == "function" then
                            drag.SetAllElementsUnlocked(s.elementPositionsUnlocked == true, GetLiveResourceOrbSettings)
                        end
                        Apply()
                    else
                        TraceResourceOrbSettingsReset("element_lock_toggle_skipped", {
                            elemKey = elemKey,
                            reason = "missingElementPosition",
                        })
                    end
                end,
            },
            offsetX = {
                get = function()
                    local s = GetResourceOrbSettings()
                    local ep = s and s.elementPositions and s.elementPositions[elemKey]
                    return ep and ep.offsetX or 0
                end,
                set = function(v)
                    local s = EnsureResourceOrbSettings()
                    if s and s.elementPositions and s.elementPositions[elemKey] then
                        local previous = s.elementPositions[elemKey].offsetX
                        s.elementPositions[elemKey].offsetX = v
                        TraceResourceOrbSettingsReset("element_offset_set", {
                            elemKey = elemKey,
                            axis = "x",
                            previousOffset = previous,
                            offset = v,
                        })
                        Apply()
                    else
                        TraceResourceOrbSettingsReset("element_offset_set_skipped", {
                            elemKey = elemKey,
                            axis = "x",
                            reason = "missingElementPosition",
                        })
                    end
                end,
            },
            offsetY = {
                get = function()
                    local s = GetResourceOrbSettings()
                    local ep = s and s.elementPositions and s.elementPositions[elemKey]
                    return ep and ep.offsetY or 0
                end,
                set = function(v)
                    local s = EnsureResourceOrbSettings()
                    if s and s.elementPositions and s.elementPositions[elemKey] then
                        local previous = s.elementPositions[elemKey].offsetY
                        s.elementPositions[elemKey].offsetY = v
                        TraceResourceOrbSettingsReset("element_offset_set", {
                            elemKey = elemKey,
                            axis = "y",
                            previousOffset = previous,
                            offset = v,
                        })
                        Apply()
                    else
                        TraceResourceOrbSettingsReset("element_offset_set_skipped", {
                            elemKey = elemKey,
                            axis = "y",
                            reason = "missingElementPosition",
                        })
                    end
                end,
            },
        }
    end

    local elemPosContracts = {
        leftOrb = CreateElemPosContract("leftOrb"), rightOrb = CreateElemPosContract("rightOrb"),
        skillBars = CreateElemPosContract("skillBars"), xpBar = CreateElemPosContract("xpBar"),
        mountBar = CreateElemPosContract("mountBar"), castBar = CreateElemPosContract("castBar"),
        quickslot = CreateElemPosContract("quickslot"), companionUltimate = CreateElemPosContract("companionUltimate"),
    }
    sharedContracts.elemPos = elemPosContracts

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
            getFunc = generalContracts.elementPositionsUnlocked.get,
            setFunc = generalContracts.elementPositionsUnlocked.set,
            disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
            default = generalContracts.elementPositionsUnlocked.default,
            width = "full",
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
                    { key = "elementPositionsUnlocked", value = false },
                    { key = "enableIndependentOrbOffset", value = false },
                    { key = "orbOffsetX", value = 0 },
                    { key = "orbOffsetY", value = 0 },
                })
                ResetElementPositions(EnsureResourceOrbSettings())
                Apply()
            end,
            disabled = function() return not BETTERUI.GetModuleEnabled("ResourceOrbFrames") end,
            width = "half",
        },
        {
            type = "button",
            name = GetString(rawget(_G, "SI_BETTERUI_ROF_RESET_ALL_POSITIONS")),
            tooltip = GetString(rawget(_G, "SI_BETTERUI_ROF_RESET_ALL_POSITIONS_TOOLTIP")),
            func = function()
                ResetElementPositions(EnsureResourceOrbSettings())
                Apply()
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

local function EnsureResourceOrbFramesSetupContracts()
    BETTERUI.CIM.RegisterModuleAccessors(ResourceOrbFrames, "ResourceOrbFrames")

    if type(BETTERUI.CIM.RegisterModulePanelWithLogging) == "function" then
        BETTERUI.CIM.RegisterModulePanelWithLogging(ResourceOrbFrames, "ResourceOrbFrames", "ResourceOrbFrames", "Resource Orb Frames")
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
