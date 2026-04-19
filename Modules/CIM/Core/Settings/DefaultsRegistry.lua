BETTERUI.Defaults = BETTERUI.Defaults or {}

BETTERUI.Defaults.FirstInstall = {
    Inventory = true,         -- Core feature, showcase
    Banking = true,           -- Core feature, showcase
    Vendor = true,            -- Core feature, enhanced vendor/fence
    TradingHouse = false,     -- Enhanced guild store / trading house (under development)
    Companions = true,        -- Companion equipment manager
    GeneralInterface = true,  -- Enhanced tooltips, QoL
    ResourceOrbFrames = true, -- Per user request
    Writs = false,            -- Niche feature, opt-in
    Nameplates = false,       -- Align with reset/default baseline
}

local function CloneDefaultValue(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, nestedValue in pairs(value) do
        copy[key] = CloneDefaultValue(nestedValue)
    end
    return copy
end

BETTERUI.Defaults.Modules = {
    Inventory = {
        enableCarousel = true, -- Modern tab navigation

        showIconEnchantment = true,
        showIconSetGear = true,
        showIconUnboundItem = true,
        showIconResearchableTrait = true,
        showIconUnknownRecipe = true,
        showIconUnknownBook = true,

        bindOnEquipProtection = true, -- Warn before equipping BoE items

        quickDestroy = false,       -- DESTRUCTIVE: skip destroy confirmation
        enableBatchDestroy = false, -- DESTRUCTIVE: allow destroy in multi-select mode

        useTriggersForSkip = false,  -- Personal preference
        triggerSpeed = 10,           -- Lines to skip with triggers
        enableCompanionJunk = false, -- Requires FCO Companion addon
    },

    Banking = {
        enableCarousel = true, -- Modern tab navigation

        showIconEnchantment = true,
        showIconSetGear = true,
        showIconUnboundItem = true,
        showIconResearchableTrait = true,
        showIconUnknownRecipe = true,
        showIconUnknownBook = true,

        enableGuildBank = true,
        useTriggersForSkip = false,  -- Personal preference
        triggerSpeed = 10,           -- Lines to skip with triggers
    },

    GeneralInterface = {
        showMarketPrice = true,
        marketPricePriority = "mm_att_ttc",

        showStyleTrait = true,      -- Show style/trait info in tooltips
        showKnowledgeStatus = true, -- Show recipe/motif/book known status in enhanced tooltip

        chatHistory = 200, -- Reasonable default

        attIntegration = true, -- Arkadius Trade Tools
        mmIntegration = true,  -- Master Merchant
        ttcIntegration = true, -- Tamriel Trade Centre

        guildStoreErrorSuppress = true, -- Suppress guild store errors

        removeDeleteDialog = false, -- DESTRUCTIVE: skip mail delete confirmation
    },

    CIM = {
        rhScrollSpeed = 50,               -- Right-hand tooltip scroll speed
        tooltipSize = 24,                 -- Tooltip font size
        enableTooltipEnhancements = true, -- Enable enhanced tooltip formatting
        enhanceCompat = false,            -- Enhanced compatibility mode
    },

    -- Keep this table as flat reset/metadata defaults for shared settings helpers.
    -- ResourceOrbFrames/Settings/Defaults.lua remains the InitModule authority
    -- because it deep-merges nested defaults and normalizes persisted values.
    ResourceOrbFrames = {
        scale = 1.0,
        offsetY = 0,

        showUltimateNumber = true,     -- Show ultimate % on action bar
        xpBarEnabled = true,           -- Show XP progress bar
        castBarEnabled = true,         -- Show casting bar
        mountStaminaBarEnabled = true, -- Show mount stamina bar
        weaponSwapAnimation = true,    -- Animate weapon swap
        showQuickslotCount = true,     -- Show quickslot item count

        showCombatGlow = true,
        showCombatIcon = true,
        playCombatAudio = true,

        showQuickslotCooldown = false, -- Personal preference

        orbAnimFlow = false,
        hideLeftOrnament = false,
        hideRightOrnament = false,
        leftOrbSizeScale = 1.0,
        rightOrbSizeScale = 1.0,

        healthTextSize = 20,
        healthTextColor = { 1, 1, 1, 1 },
        magickaTextSize = 20,
        magickaTextColor = { 1, 1, 1, 1 },
        staminaTextSize = 20,
        staminaTextColor = { 1, 1, 1, 1 },
        shieldTextSize = 20,
        shieldTextColor = { 0, 1, 1, 1 },

        cooldownTextSize = 27,
        cooldownTextColor = { 0.86, 0.84, 0.13, 1 },
        quickslotTextSize = 27,
        quickslotTextColor = { 1, 1, 1, 1 },
        ultimateTextSize = 27,
        ultimateTextColor = { 1, 1, 1, 1 },

        backBarOpacity = 1,
        xpBarTextSize = 16,
        xpBarTextColor = { 1, 1, 1, 1 },
        castBarAlwaysShow = false,
        castBarTextSize = 16,
        castBarTextColor = { 1, 1, 1, 1 },
        mountStaminaBarTextSize = 16,
        mountStaminaBarTextColor = { 1, 1, 1, 1 },

        centerBarType = "XP",
    },

    Nameplates = {
        m_enabled = false,
        font = "$(BOLD_FONT)", -- Uses ESO's localized font for CJK support
        style = FONT_STYLE_SOFT_SHADOW_THIN or 5,
        size = 16,
    },

    Writs = {
    },

    Vendor = {
        enableCarousel = true, -- Modern tab navigation
        enableBatchJunkSell = true, -- Batch sell-all-junk confirmation
        abbreviateVendorCurrency = true,

        showIconEnchantment = true,
        showIconSetGear = true,
        showIconUnboundItem = true,
        showIconResearchableTrait = true,
        showIconUnknownRecipe = true,
        showIconUnknownBook = true,
    },

    TradingHouse = {
        enableCarousel = true, -- Modern tab navigation

        showIconEnchantment = true,
        showIconSetGear = true,
        showIconUnboundItem = true,
        showIconResearchableTrait = true,
        showIconUnknownRecipe = true,
        showIconUnknownBook = true,
        searchPresets = {},
    },

    Companions = {
        enableCompanionEquipment = true,
        quickDestroy = false,
        batchDestroy = true,
        bindOnEquipProtection = true,
        enableCompanionJunk = true,

        showIconEnchantment = true,
        showIconSetGear = true,
        showIconUnboundItem = true,
        showIconResearchableTrait = true,
        showIconUnknownRecipe = true,
        showIconUnknownBook = true,
    },
}

BETTERUI.Defaults.DestructiveSettings = {
    ["Inventory.quickDestroy"] = true,
    ["Inventory.enableBatchDestroy"] = true,
    ["GeneralInterface.removeDeleteDialog"] = true,
}

function BETTERUI.Defaults.IsDestructive(moduleName, settingKey)
    local key = moduleName .. "." .. settingKey
    return BETTERUI.Defaults.DestructiveSettings[key] == true
end

function BETTERUI.Defaults.GetDefault(moduleName, settingKey)
    local moduleDefaults = BETTERUI.Defaults.Modules[moduleName]
    if moduleDefaults then
        return moduleDefaults[settingKey]
    end
    return nil
end

function BETTERUI.Defaults.GetModuleDefaults(moduleName)
    return CloneDefaultValue(BETTERUI.Defaults.Modules[moduleName] or {})
end

function BETTERUI.Defaults.ApplyFirstInstallDefaults(settings)
    if not settings or not settings.Modules then return end

    local firstInstall = BETTERUI.Defaults.FirstInstall
    for moduleName, enabled in pairs(firstInstall) do
        settings.Modules[moduleName] = settings.Modules[moduleName] or {}
        settings.Modules[moduleName].m_enabled = enabled
    end

    BETTERUI.Debug("Applied first-install module defaults")
end

function BETTERUI.Defaults.ApplyModuleDefaults(moduleName, m_options)
    m_options = m_options or {}
    local defaults = BETTERUI.Defaults.Modules[moduleName]

    if defaults then
        for key, value in pairs(defaults) do
            if m_options[key] == nil then
                m_options[key] = CloneDefaultValue(value)
            end
        end
    end

    return m_options
end
