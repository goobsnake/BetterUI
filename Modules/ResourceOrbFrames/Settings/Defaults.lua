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
        elementPositionsUnlocked = false,
        -- Only m_enabled is read from saved settings; all front bar layout
        -- values (offsets, button sizes, spacing) come from the layout config
        -- in Constants.lua (BETTERUI_ORB_FRAMES.bars.customFrontBar).
        customFrontBar = {
            m_enabled = true,
        },
        elementPositions = {
            leftOrb = { locked = true, offsetX = 0, offsetY = 0 },
            rightOrb = { locked = true, offsetX = 0, offsetY = 0 },
            skillBars = { locked = true, offsetX = 0, offsetY = 0 },
            xpBar = { locked = true, offsetX = 0, offsetY = 0 },
            mountBar = { locked = true, offsetX = 0, offsetY = 0 },
            castBar = { locked = true, offsetX = 0, offsetY = 0 },
            quickslot = { locked = true, offsetX = 0, offsetY = 0 },
            companionUltimate = { locked = true, offsetX = 0, offsetY = 0 },
        },
    }
end

-- Import shared utilities (canonical definitions in SettingsAccessor.lua)
local ClampInteger = BETTERUI.ClampInteger
local ClampNumber = BETTERUI.ClampNumber
local ELEMENT_POSITION_KEYS = { "leftOrb", "rightOrb", "skillBars", "xpBar", "mountBar", "castBar", "quickslot", "companionUltimate" }

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

local function AnyLegacyElementUnlocked(m_options)
    local ep = m_options and m_options.elementPositions
    if type(ep) ~= "table" then
        return false
    end
    for _, k in ipairs(ELEMENT_POSITION_KEYS) do
        if type(ep[k]) == "table" and ep[k].locked == false then
            return true
        end
    end
    return false
end

local function AddOffsetToElementPosition(elementPositions, key, offsetX, offsetY)
    if type(elementPositions) ~= "table" then
        return
    end
    if type(elementPositions[key]) ~= "table" then
        elementPositions[key] = { locked = true, offsetX = 0, offsetY = 0 }
    end
    local ep = elementPositions[key]
    ep.offsetX = (tonumber(ep.offsetX) or 0) + offsetX
    ep.offsetY = (tonumber(ep.offsetY) or 0) + offsetY
end

local function MigrateLegacyIndependentOrbOffset(m_options)
    if type(m_options) ~= "table" or m_options.enableIndependentOrbOffset ~= true then
        return
    end

    local offsetX = tonumber(m_options.orbOffsetX) or 0
    local offsetY = tonumber(m_options.orbOffsetY) or 0
    if offsetX ~= 0 or offsetY ~= 0 then
        for _, k in ipairs({ "leftOrb", "rightOrb", "xpBar", "mountBar" }) do
            AddOffsetToElementPosition(m_options.elementPositions, k, offsetX, offsetY)
        end
    end

    m_options.enableIndependentOrbOffset = false
    m_options.orbOffsetX = 0
    m_options.orbOffsetY = 0
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

    local ep = m_options.elementPositions
    if type(ep) == "table" then
        for _, k in ipairs(ELEMENT_POSITION_KEYS) do
            if type(ep[k]) == "table" then
                ep[k].offsetX = ClampInteger(ep[k].offsetX, -600, 600, 0)
                ep[k].offsetY = ClampInteger(ep[k].offsetY, -600, 600, 0)
            end
        end
    end

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
    local shouldBackfillGlobalUnlock = m_options.elementPositionsUnlocked == nil
    local legacyGlobalUnlock = AnyLegacyElementUnlocked(m_options)

    -- Retire legacy setting now that custom texture switching is removed.
    m_options.useCustomTextures = nil

    -- Apply simple defaults
    for key, value in pairs(defaults) do
        if key ~= "customFrontBar" and key ~= "elementPositions" and m_options[key] == nil then
            m_options[key] = value
        end
    end
    if shouldBackfillGlobalUnlock then
        m_options.elementPositionsUnlocked = legacyGlobalUnlock
    end

    -- Deep merge for customFrontBar
    if m_options.customFrontBar == nil then
        m_options.customFrontBar = CloneTable(defaults.customFrontBar)
    else
        MergeMissingDefaults(m_options.customFrontBar, defaults.customFrontBar)
    end

    -- Deep merge for elementPositions
    if m_options.elementPositions == nil then
        m_options.elementPositions = CloneTable(defaults.elementPositions)
    else
        MergeMissingDefaults(m_options.elementPositions, defaults.elementPositions)
    end

    MigrateLegacyIndependentOrbOffset(m_options)

    -- Migration/sanitization: normalize persisted numeric settings to current slider limits.
    NormalizeNumericSettings(m_options, defaults)

    return m_options
end

-- Export defaults for use by OptionsBuilder
BETTERUI.ResourceOrbFrames.InitializeDefaults = InitializeDefaults
BETTERUI.ResourceOrbFrames.GetDefaults = GetDefaults
