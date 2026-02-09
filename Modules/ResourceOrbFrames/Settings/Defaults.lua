--[[
File: Modules/ResourceOrbFrames/Settings/Defaults.lua
Purpose: Default settings for Resource Orb Frames module.
Author: BetterUI Team
Last Modified: 2026-02-08
]]

BETTERUI.ResourceOrbFrames = BETTERUI.ResourceOrbFrames or {}

--- Default values for all ResourceOrbFrames settings.
--- @return table The default settings table.
local function GetDefaults()
    return {
        m_enabled = true,
        scale = 1.0,
        offsetY = 0,
        useCustomTextures = false,
        centerBarType = "XP",
        healthTextSize = 20,
        healthTextColor = { 1, 1, 1, 1 },
        magickaTextSize = 20,
        magickaTextColor = { 1, 1, 1, 1 },
        staminaTextSize = 20,
        staminaTextColor = { 1, 1, 1, 1 },
        shieldTextSize = 20,
        shieldTextColor = { 0, 1, 1, 1 },
        xpBarEnabled = true, -- CHANGED: Showcase for new users
        xpBarTextSize = 16,
        xpBarTextColor = { 1, 1, 1, 1 },
        castBarEnabled = true, -- CHANGED: Showcase for new users
        castBarAlwaysShow = false,
        castBarTextSize = 16,
        castBarTextColor = { 1, 1, 1, 1 },
        mountStaminaBarEnabled = true, -- CHANGED: Showcase for new users
        mountStaminaBarTextSize = 16,
        mountStaminaBarTextColor = { 1, 1, 1, 1 },
        orbAnimFlow = false,
        cooldownTextSize = 27,
        cooldownTextColor = { 0.86, 0.84, 0.13, 1 },
        quickslotTextSize = 27,
        quickslotTextColor = { 1, 1, 1, 1 },
        weaponSwapAnimation = true, -- CHANGED: Showcase for new users
        showUltimateNumber = true,  -- CHANGED: Showcase for new users
        ultimateTextSize = 27,
        ultimateTextColor = { 1, 1, 1, 1 },
        showQuickslotCooldown = false,
        showQuickslotCount = true,
        showCombatGlow = false,
        combatGlowColor = { 1, 0.3, 0.1, 0.8 },
        showCombatIcon = false,
        playCombatAudio = false,
        backBarOpacity = 1,
        hideLeftOrnament = false,
        hideRightOrnament = false,
        leftOrbSizeScale = 1.0,
        rightOrbSizeScale = 1.0,
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
end

--- Initializes ResourceOrbFrames default settings.
---
--- Purpose: Defines defaults for scale, offset, colors, and visibility of orb elements.
--- Mechanics: Checks each setting key; if missing, assigns default value.
---
--- @param m_options table The options table to initialize.
--- @return table The initialized options table with defaults applied.
function BETTERUI.ResourceOrbFrames.InitModule(m_options)
    m_options = m_options or {}
    local defaults = GetDefaults()

    -- Apply simple defaults
    for key, value in pairs(defaults) do
        if key ~= "customFrontBar" and m_options[key] == nil then
            m_options[key] = value
        end
    end

    -- Deep merge for customFrontBar
    if m_options.customFrontBar == nil then
        m_options.customFrontBar = defaults.customFrontBar
    else
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

-- Export defaults for use by OptionsBuilder
BETTERUI.ResourceOrbFrames.GetDefaults = GetDefaults
