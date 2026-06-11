--[[
File: Modules/ResourceOrbFrames/Settings/Defaults.lua
Purpose: Default settings for Resource Orb Frames module.
]]

BETTERUI.ResourceOrbFrames = BETTERUI.ResourceOrbFrames or {}

--- Default values for all ResourceOrbFrames settings.
--- This module keeps the canonical InitModule defaults path because it needs
--- nested-table backfills plus numeric/color normalization that DefaultsRegistry
--- intentionally does not duplicate.
local function GetDefaults()
    return {
        m_enabled = true,
        scale = 1.0,
        offsetX = 0,
        offsetY = 0,
        centerBarType = "XP",
        healthTextSize = 20,
        healthTextColor = { 1, 1, 1, 1 },
        magickaTextSize = 20,
        magickaTextColor = { 1, 1, 1, 1 },
        staminaTextSize = 20,
        staminaTextColor = { 1, 1, 1, 1 },
        shieldTextSize = 20,
        shieldTextColor = { 0.4, 0.9, 1, 1 },
        xpBarEnabled = true,
        xpBarTextSize = 16,
        xpBarTextColor = { 1, 1, 1, 1 },
        castBarEnabled = true,
        castBarAlwaysShow = false,
        castBarTextSize = 16,
        castBarTextColor = { 1, 1, 1, 1 },
        mountStaminaBarEnabled = true,
        mountStaminaBarTextSize = 16,
        mountStaminaBarTextColor = { 1, 1, 1, 1 },
        orbAnimFlow = true,
        cooldownTextSize = 27,
        cooldownTextColor = { 0.86, 0.84, 0.13, 1 },
        quickslotTextSize = 27,
        quickslotTextColor = { 1, 1, 1, 1 },
        weaponSwapAnimation = true,
        showUltimateNumber = true,
        ultimateTextSize = 27,
        ultimateTextColor = { 1, 1, 1, 1 },
        showQuickslotCooldown = true,
        showQuickslotCount = true,
        showCombatGlow = true,
        showCombatIcon = true,
        playCombatAudio = true,
        backBarOpacity = 1,
        hideBackBar = false,
        hideLeftOrnament = false,
        hideRightOrnament = false,
        leftOrbSizeScale = 1.0,
        rightOrbSizeScale = 1.0,
        enableIndependentOrbOffset = false,
        orbOffsetX = 0,
        orbOffsetY = 0,
        -- Only m_enabled is read from saved settings; all front bar layout
        -- values (offsets, button sizes, spacing) come from the layout config
        -- in Constants.lua (BETTERUI_ORB_FRAMES.bars.customFrontBar).
        customFrontBar = {
            m_enabled = true,
        },
    }
end

-- Import shared utilities (canonical definitions in SettingsAccessor.lua)
local ClampInteger = BETTERUI.ClampInteger
local ClampNumber = BETTERUI.ClampNumber

local function CloneTable(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, nestedValue in pairs(value) do
        copy[key] = CloneTable(nestedValue)
    end
    return copy
end

local function MergeMissingDefaults(target, defaults)
    if type(target) ~= "table" or type(defaults) ~= "table" then
        return target
    end

    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = CloneTable(value)
        elseif type(target[key]) == "table" and type(value) == "table" then
            MergeMissingDefaults(target[key], value)
        end
    end

    return target
end

local function NormalizeNumericSettings(m_options, defaults)
    if type(m_options) ~= "table" then
        return
    end

    -- General frame controls.
    m_options.scale = ClampNumber(m_options.scale, 0.75, 1.75, defaults.scale or 1.0)
    m_options.offsetX = ClampInteger(m_options.offsetX, -500, 500, defaults.offsetX or 0)
    m_options.offsetY = ClampInteger(m_options.offsetY, -300, 300, defaults.offsetY or 0)

    -- Skill/orb sliders with decimal ranges.
    m_options.backBarOpacity = ClampNumber(m_options.backBarOpacity, 0.3, 1.0, defaults.backBarOpacity or 1)
    m_options.leftOrbSizeScale = ClampNumber(m_options.leftOrbSizeScale, 1.0, 1.2, defaults.leftOrbSizeScale or 1.0)
    m_options.rightOrbSizeScale = ClampNumber(m_options.rightOrbSizeScale, 1.0, 1.2, defaults.rightOrbSizeScale or 1.0)

    m_options.orbOffsetX = ClampInteger(m_options.orbOffsetX, -300, 300, defaults.orbOffsetX or 0)
    m_options.orbOffsetY = ClampInteger(m_options.orbOffsetY, -300, 300, defaults.orbOffsetY or 0)

    -- Orb value text: enforce 12-26.
    m_options.healthTextSize = ClampInteger(m_options.healthTextSize, 12, 26, defaults.healthTextSize or 20)
    m_options.magickaTextSize = ClampInteger(m_options.magickaTextSize, 12, 26, defaults.magickaTextSize or 20)
    m_options.staminaTextSize = ClampInteger(m_options.staminaTextSize, 12, 26, defaults.staminaTextSize or 20)
    m_options.shieldTextSize = ClampInteger(m_options.shieldTextSize, 12, 26, defaults.shieldTextSize or 20)

    -- Bars: enforce 5-20.
    m_options.xpBarTextSize = ClampInteger(m_options.xpBarTextSize, 5, 20, defaults.xpBarTextSize or 16)
    m_options.castBarTextSize = ClampInteger(m_options.castBarTextSize, 5, 20, defaults.castBarTextSize or 16)
    m_options.mountStaminaBarTextSize = ClampInteger(m_options.mountStaminaBarTextSize, 5, 20,
        defaults.mountStaminaBarTextSize or 16)

    -- Skill text: enforce 12-30.
    m_options.cooldownTextSize = ClampInteger(m_options.cooldownTextSize, 12, 30, defaults.cooldownTextSize or 27)
    m_options.quickslotTextSize = ClampInteger(m_options.quickslotTextSize, 12, 30, defaults.quickslotTextSize or 27)
    m_options.ultimateTextSize = ClampInteger(m_options.ultimateTextSize, 12, 30, defaults.ultimateTextSize or 27)
end

--- Delegated defaults helper for ResourceOrbFrames.InitModule.
---
--- Called from ResourceOrbFrames.InitModule after Module.lua exposes the public
--- module entrypoint and root contract.
---
---@param m_options table|nil Module options table (created if nil)
---@return table m_options Options table with defaults applied
local function InitializeDefaults(m_options)
    m_options = m_options or {}
    local defaults = GetDefaults()

    -- Retire legacy setting now that custom texture switching is removed.
    m_options.useCustomTextures = nil

    -- Apply simple defaults
    for key, value in pairs(defaults) do
        if key ~= "customFrontBar" and m_options[key] == nil then
            m_options[key] = value
        end
    end

    -- Deep merge for customFrontBar
    if m_options.customFrontBar == nil then
        m_options.customFrontBar = CloneTable(defaults.customFrontBar)
    else
        MergeMissingDefaults(m_options.customFrontBar, defaults.customFrontBar)
    end

    -- Migration/sanitization: normalize persisted numeric settings to current slider limits.
    NormalizeNumericSettings(m_options, defaults)

    return m_options
end

-- Export defaults for use by OptionsBuilder
BETTERUI.ResourceOrbFrames.InitializeDefaults = InitializeDefaults
BETTERUI.ResourceOrbFrames.GetDefaults = GetDefaults
