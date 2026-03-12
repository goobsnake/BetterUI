--[[
File: Modules/CIM/Core/DefaultsRegistry.lua
Purpose: Centralized default values for all BetterUI modules.
         Single source of truth for settings defaults, first-install states,
         and destructive setting identification.
Author: BetterUI Team
Last Modified: 2026-01-29

Key Responsibilities:
1. Define default module enable states for first-time installations
2. Define default setting values for each module
3. Identify destructive settings that need special UI treatment
4. Provide utility functions for applying defaults
]]

BETTERUI.Defaults = BETTERUI.Defaults or {}

-- ============================================================================
-- FIRST INSTALL MODULE STATES
-- ============================================================================
-- These are applied ONLY on first install (when firstInstall flag is true)
-- Existing users are never affected by changes here

BETTERUI.Defaults.FirstInstall = {
    Inventory = true,         -- Core feature, showcase
    Banking = true,           -- Core feature, showcase
    GeneralInterface = true,  -- Enhanced tooltips, QoL
    ResourceOrbFrames = true, -- Per user request
    Writs = false,            -- Niche feature, opt-in
    Nameplates = false,       -- Align with reset/default baseline
}

-- ============================================================================
-- MODULE SETTING DEFAULTS
-- ============================================================================
-- Default values for individual settings within each module
-- Used by InitModule functions to initialize missing settings

BETTERUI.Defaults.Modules = {
    -- ========================================================================
    -- INVENTORY MODULE
    -- ========================================================================
    Inventory = {
        -- Display Features (showcase for new users)
        enableCarousel = true, -- Modern tab navigation

        -- Icon Visibility (all on by default)
        showIconEnchantment = true,
        showIconSetGear = true,
        showIconUnboundItem = true,
        showIconResearchableTrait = true,
        showIconUnknownRecipe = true,
        showIconUnknownBook = true,

        -- Safety Features
        bindOnEquipProtection = true, -- Warn before equipping BoE items

        -- Destructive Features (OFF by default)
        quickDestroy = false,       -- DESTRUCTIVE: skip destroy confirmation
        enableBatchDestroy = false, -- DESTRUCTIVE: allow destroy in multi-select mode

        -- Optional Features
        useTriggersForSkip = false,  -- Personal preference
        triggerSpeed = 10,           -- Lines to skip with triggers
        enableCompanionJunk = false, -- Requires FCO Companion addon
    },

    -- ========================================================================
    -- BANKING MODULE
    -- ========================================================================
    Banking = {
        -- Display Features (showcase for new users)
        enableCarousel = true, -- Modern tab navigation

        -- Icon Visibility (all on by default)
        showIconEnchantment = true,
        showIconSetGear = true,
        showIconUnboundItem = true,
        showIconResearchableTrait = true,
        showIconUnknownRecipe = true,
        showIconUnknownBook = true,

        -- Optional Features
        useTriggersForSkip = false,  -- Personal preference
        triggerSpeed = 10,           -- Lines to skip with triggers
    },

    -- ========================================================================
    -- GENERAL INTERFACE MODULE
    -- ========================================================================
    GeneralInterface = {
        -- Shared Market Value Display (used by both Inventory and Banking item rows)
        showMarketPrice = true,
        marketPricePriority = "mm_att_ttc",

        -- Trait & Research
        showStyleTrait = true, -- Show style/trait info in tooltips

        -- Chat History
        chatHistory = 200, -- Reasonable default

        -- Addon Integrations (auto-enable, greyed out if addon not present)
        attIntegration = true, -- Arkadius Trade Tools
        mmIntegration = true,  -- Master Merchant
        ttcIntegration = true, -- Tamriel Trade Centre

        -- Quality of Life
        guildStoreErrorSuppress = true, -- Suppress guild store errors

        -- Destructive Features (OFF by default)
        removeDeleteDialog = false, -- DESTRUCTIVE: skip mail delete confirmation
    },

    -- ========================================================================
    -- CIM (Common Interface Module) CORE SETTINGS
    -- ========================================================================
    CIM = {
        rhScrollSpeed = 50,               -- Right-hand tooltip scroll speed
        tooltipSize = 24,                 -- Tooltip font size
        enableTooltipEnhancements = true, -- Enable enhanced tooltip formatting
        enhanceCompat = false,            -- Enhanced compatibility mode
    },

    -- ========================================================================
    -- RESOURCE ORB FRAMES MODULE
    -- ========================================================================
    ResourceOrbFrames = {
        -- Core Settings
        scale = 1.0,
        offsetY = 0,

        -- Showcase Features (ON by default for great first impression)
        showUltimateNumber = true,     -- Show ultimate % on action bar
        xpBarEnabled = true,           -- Show XP progress bar
        castBarEnabled = true,         -- Show casting bar
        mountStaminaBarEnabled = true, -- Show mount stamina bar
        weaponSwapAnimation = true,    -- Animate weapon swap
        showQuickslotCount = true,     -- Show quickslot item count

        -- Combat Indicators (ON by default)
        showCombatGlow = true,
        showCombatIcon = true,
        playCombatAudio = true,

        -- Quickslot Settings
        showQuickslotCooldown = false, -- Personal preference

        -- Orb Settings
        orbAnimFlow = false,
        hideLeftOrnament = false,
        hideRightOrnament = false,
        leftOrbSizeScale = 1.0,
        rightOrbSizeScale = 1.0,

        -- Text Settings (sensible defaults)
        healthTextSize = 20,
        healthTextColor = { 1, 1, 1, 1 },
        magickaTextSize = 20,
        magickaTextColor = { 1, 1, 1, 1 },
        staminaTextSize = 20,
        staminaTextColor = { 1, 1, 1, 1 },
        shieldTextSize = 20,
        shieldTextColor = { 0, 1, 1, 1 },

        -- Skill Bar Text
        cooldownTextSize = 27,
        cooldownTextColor = { 0.86, 0.84, 0.13, 1 },
        quickslotTextSize = 27,
        quickslotTextColor = { 1, 1, 1, 1 },
        ultimateTextSize = 27,
        ultimateTextColor = { 1, 1, 1, 1 },

        -- Bar Settings
        backBarOpacity = 1,
        xpBarTextSize = 16,
        xpBarTextColor = { 1, 1, 1, 1 },
        castBarAlwaysShow = false,
        castBarTextSize = 16,
        castBarTextColor = { 1, 1, 1, 1 },
        mountStaminaBarTextSize = 16,
        mountStaminaBarTextColor = { 1, 1, 1, 1 },

        -- Center Bar
        centerBarType = "XP",
    },

    -- ========================================================================
    -- NAMEPLATES MODULE
    -- ========================================================================
    Nameplates = {
        m_enabled = false,
        font = "$(BOLD_FONT)", -- Uses ESO's localized font for CJK support
        style = FONT_STYLE_SOFT_SHADOW_THIN or 5,
        size = 16,
    },

    -- ========================================================================
    -- WRITS MODULE (minimal settings)
    -- ========================================================================
    Writs = {
        -- No specific settings, just m_enabled controlled by Master Settings
    },
}

-- ============================================================================
-- DESTRUCTIVE SETTINGS
-- ============================================================================
-- Settings that can cause data loss or require special warning UI
-- Format: "ModuleName.settingKey" = true

BETTERUI.Defaults.DestructiveSettings = {
    ["Inventory.quickDestroy"] = true,
    ["Inventory.enableBatchDestroy"] = true,
    ["GeneralInterface.removeDeleteDialog"] = true,
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Checks if a setting is marked as destructive.
--- @param moduleName string The module name
--- @param settingKey string The setting key
--- @return boolean isDestructive True if the setting is destructive
function BETTERUI.Defaults.IsDestructive(moduleName, settingKey)
    local key = moduleName .. "." .. settingKey
    return BETTERUI.Defaults.DestructiveSettings[key] == true
end

--- Gets the default value for a specific module setting.
--- @param moduleName string The module name
--- @param settingKey string The setting key
--- @return any|nil defaultValue The default value, or nil if not defined
function BETTERUI.Defaults.GetDefault(moduleName, settingKey)
    local moduleDefaults = BETTERUI.Defaults.Modules[moduleName]
    if moduleDefaults then
        return moduleDefaults[settingKey]
    end
    return nil
end

--- Gets all default values for a module.
--- @param moduleName string The module name
--- @return table defaults Table of default key-value pairs
function BETTERUI.Defaults.GetModuleDefaults(moduleName)
    return BETTERUI.Defaults.Modules[moduleName] or {}
end

--- Applies first-install defaults to the settings.
--- Only called when BETTERUI.Settings.firstInstall is true.
--- @param settings table The BETTERUI.Settings table to modify
function BETTERUI.Defaults.ApplyFirstInstallDefaults(settings)
    if not settings or not settings.Modules then return end

    local firstInstall = BETTERUI.Defaults.FirstInstall
    for moduleName, enabled in pairs(firstInstall) do
        settings.Modules[moduleName] = settings.Modules[moduleName] or {}
        settings.Modules[moduleName].m_enabled = enabled
    end

    BETTERUI.Debug("Applied first-install module defaults")
end

--- Applies default values to a module's settings table.
--- Only sets values that are nil (preserves existing user settings).
--- @param moduleName string The module name
--- @param m_options table The module's options table to initialize
--- @return table m_options The initialized options table
function BETTERUI.Defaults.ApplyModuleDefaults(moduleName, m_options)
    m_options = m_options or {}
    local defaults = BETTERUI.Defaults.Modules[moduleName]

    if defaults then
        for key, value in pairs(defaults) do
            if m_options[key] == nil then
                m_options[key] = value
            end
        end
    end

    return m_options
end
