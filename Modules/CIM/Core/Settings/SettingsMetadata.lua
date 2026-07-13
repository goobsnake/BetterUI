--[[
File: Modules/CIM/Core/Settings/SettingsMetadata.lua
Purpose: Settings metadata registry and default/reset management.
         Defines per-module setting metadata (labels, tooltips, defaults, dependencies).
         Provides lookup, default retrieval, and group-based reset functions.
]]

-- NAMESPACE INITIALIZATION

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.Settings then BETTERUI.CIM.Settings = {} end
local OptionalAddons = assert(BETTERUI.CIM.OptionalAddons,
    "BetterUI: CIM.OptionalAddons must load before SettingsMetadata")
local ADDON_KEYS = assert(OptionalAddons.KEYS,
    "BetterUI: CIM.OptionalAddons.KEYS must load before SettingsMetadata")

local function TraceSettingsMetadata(event, phase, data)
    local L = BETTERUI and BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = "CIM"
    data.feature = "settingsMetadata"
    if L.SetLastAction then
        L.SetLastAction({ flow = event, message = tostring(event) .. ":" .. tostring(phase) })
    end
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.SETTINGS or categories.SETTING or "SETTINGS", event, phase, data)
end

-- SETTINGS METADATA REGISTRY

local SETTINGS_METADATA_REGISTRY = {
    Shared = {
        showIconUnboundItem = {
            labelStringId = SI_BETTERUI_ICON_UNBOUND,
            tooltipStringId = SI_BETTERUI_ICON_UNBOUND_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "iconCustomization",
            resetGroup = "iconCustomization",
        },
        showIconEnchantment = {
            labelStringId = SI_BETTERUI_ICON_ENCHANTMENT,
            tooltipStringId = SI_BETTERUI_ICON_ENCHANTMENT_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "iconCustomization",
            resetGroup = "iconCustomization",
        },
        showIconSetGear = {
            labelStringId = SI_BETTERUI_ICON_SET_GEAR,
            tooltipStringId = SI_BETTERUI_ICON_SET_GEAR_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "iconCustomization",
            resetGroup = "iconCustomization",
        },
        showIconResearchableTrait = {
            labelStringId = SI_BETTERUI_ICON_RESEARCHABLE_TRAIT,
            tooltipStringId = SI_BETTERUI_ICON_RESEARCHABLE_TRAIT_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "iconCustomization",
            resetGroup = "iconCustomization",
        },
        showIconUnknownRecipe = {
            labelStringId = SI_BETTERUI_ICON_UNKNOWN_RECIPE,
            tooltipStringId = SI_BETTERUI_ICON_UNKNOWN_RECIPE_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "iconCustomization",
            resetGroup = "iconCustomization",
        },
        showIconUnknownBook = {
            labelStringId = SI_BETTERUI_ICON_UNKNOWN_BOOK,
            tooltipStringId = SI_BETTERUI_ICON_UNKNOWN_BOOK_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "iconCustomization",
            resetGroup = "iconCustomization",
        },
    },

    Inventory = {
        quickDestroy = {
            labelStringId = SI_BETTERUI_QUICK_DESTROY,
            tooltipStringId = SI_BETTERUI_QUICK_DESTROY_TOOLTIP,
            defaultValue = false,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        enableBatchDestroy = {
            labelStringId = SI_BETTERUI_ENABLE_BATCH_DESTROY,
            tooltipStringId = SI_BETTERUI_ENABLE_BATCH_DESTROY_TOOLTIP,
            defaultValue = false,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        enableCarousel = {
            labelStringId = SI_BETTERUI_ENABLE_CAROUSEL_NAV,
            tooltipStringId = SI_BETTERUI_ENABLE_CAROUSEL_NAV_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        useTriggersForSkip = {
            labelStringId = SI_BETTERUI_TRIGGER_SKIP_TYPE,
            tooltipStringId = SI_BETTERUI_TRIGGER_SKIP_TYPE_TOOLTIP,
            defaultValue = false,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        triggerSpeed = {
            labelStringId = SI_BETTERUI_TRIGGER_SKIP,
            tooltipStringId = SI_BETTERUI_TRIGGER_SKIP_TOOLTIP,
            defaultValue = 10,
            dependency = {
                module = "Inventory",
                key = "useTriggersForSkip",
            },
            sortGroup = "general",
            resetGroup = "general",
        },
        bindOnEquipProtection = {
            labelStringId = SI_BETTERUI_BOE_PROTECTION,
            tooltipStringId = SI_BETTERUI_BOE_PROTECTION_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        enableCompanionJunk = {
            labelStringId = SI_BETTERUI_ENABLE_COMPANION_JUNK,
            tooltipStringId = SI_BETTERUI_ENABLE_COMPANION_JUNK_TOOLTIP,
            defaultValue = false,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
    },

    Banking = {
        enableGuildBank = {
            labelStringId = SI_BETTERUI_GUILD_BANK_ENABLED,
            tooltipStringId = SI_BETTERUI_GUILD_BANK_ENABLED_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        enableCarousel = {
            labelStringId = SI_BETTERUI_ENABLE_CAROUSEL_NAV,
            tooltipStringId = SI_BETTERUI_ENABLE_CAROUSEL_NAV_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        useTriggersForSkip = {
            labelStringId = SI_BETTERUI_TRIGGER_SKIP_TYPE,
            tooltipStringId = SI_BETTERUI_TRIGGER_SKIP_TYPE_TOOLTIP,
            defaultValue = false,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        triggerSpeed = {
            labelStringId = SI_BETTERUI_TRIGGER_SKIP,
            tooltipStringId = SI_BETTERUI_TRIGGER_SKIP_TOOLTIP,
            defaultValue = 10,
            dependency = {
                module = "Banking",
                key = "useTriggersForSkip",
            },
            sortGroup = "general",
            resetGroup = "general",
        },
    },

    Vendor = {
        abbreviateVendorCurrency = {
            labelStringId = SI_BETTERUI_ABBREVIATE_CURRENCY,
            tooltipStringId = SI_BETTERUI_ABBREVIATE_CURRENCY_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        enableCarousel = {
            labelStringId = SI_BETTERUI_ENABLE_CAROUSEL_NAV,
            tooltipStringId = SI_BETTERUI_ENABLE_CAROUSEL_NAV_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        enableBatchJunkSell = {
            labelStringId = SI_BETTERUI_VENDOR_BATCH_JUNK_SELL,
            tooltipStringId = SI_BETTERUI_VENDOR_BATCH_JUNK_SELL_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        skipBuyConfirm = {
            labelStringId = SI_BETTERUI_VENDOR_SKIP_BUY_CONFIRM,
            tooltipStringId = SI_BETTERUI_VENDOR_SKIP_BUY_CONFIRM_TOOLTIP,
            defaultValue = false,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
    },

    TradingHouse = {
        enableCarousel = {
            labelStringId = SI_BETTERUI_ENABLE_CAROUSEL_NAV,
            tooltipStringId = SI_BETTERUI_ENABLE_CAROUSEL_NAV_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        useMarketPricesInSellList = {
            labelStringId = SI_BETTERUI_TH_SELL_MARKET_PRICES,
            tooltipStringId = SI_BETTERUI_TH_SELL_MARKET_PRICES_TOOLTIP,
            defaultValue = false,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
    },

    Companions = {
        enableCarousel = {
            labelStringId = SI_BETTERUI_ENABLE_CAROUSEL_NAV,
            tooltipStringId = SI_BETTERUI_ENABLE_CAROUSEL_NAV_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        quickDestroy = {
            labelStringId = SI_BETTERUI_INV_QUICK_DESTROY,
            tooltipStringId = SI_BETTERUI_INV_QUICK_DESTROY_TOOLTIP,
            defaultValue = false,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        batchDestroy = {
            labelStringId = SI_BETTERUI_INV_BATCH_DESTROY,
            tooltipStringId = SI_BETTERUI_INV_BATCH_DESTROY_TOOLTIP,
            defaultValue = false,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        bindOnEquipProtection = {
            labelStringId = SI_BETTERUI_INV_BOE_PROTECTION,
            tooltipStringId = SI_BETTERUI_INV_BOE_PROTECTION_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        enableCompanionJunk = {
            labelStringId = SI_BETTERUI_INV_COMPANION_JUNK,
            tooltipStringId = SI_BETTERUI_INV_COMPANION_JUNK_TOOLTIP,
            defaultValue = false,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        enableCompanionEquipment = {
            labelStringId = SI_BETTERUI_COMPANIONS_ENABLE_EQUIPMENT,
            tooltipStringId = SI_BETTERUI_COMPANIONS_ENABLE_EQUIPMENT_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
    },

    GeneralInterface = {
        chatHistory = {
            labelStringId = SI_BETTERUI_CHAT_HISTORY,
            tooltipStringId = SI_BETTERUI_CHAT_HISTORY_TOOLTIP,
            defaultValue = 200,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        removeDeleteDialog = {
            labelStringId = SI_BETTERUI_REMOVE_DELETE_MAIL_CONFIRM,
            tooltipStringId = SI_BETTERUI_REMOVE_DELETE_WARNING,
            defaultValue = false,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        showMarketPrice = {
            labelStringId = SI_BETTERUI_SHOW_MARKET_PRICE,
            tooltipStringId = SI_BETTERUI_SHOW_MARKET_PRICE_TOOLTIP,
            defaultValue = true,
            dependency = {
                addons = OptionalAddons.GetMarketGlobals(),
            },
            sortGroup = "marketIntegration",
            resetGroup = "marketIntegration",
        },
        guildStoreErrorSuppress = {
            labelStringId = SI_BETTERUI_GS_ERROR_SUPPRESS,
            tooltipStringId = SI_BETTERUI_GS_ERROR_SUPPRESS_TOOLTIP,
            defaultValue = true,
            dependency = {
                addons = OptionalAddons.GetGuildStoreGlobals(),
            },
            sortGroup = "marketIntegration",
            resetGroup = "marketIntegration",
        },
        attIntegration = {
            labelStringId = SI_BETTERUI_ATT_INTEGRATION,
            tooltipStringId = SI_BETTERUI_ATT_INTEGRATION_TOOLTIP,
            defaultValue = true,
            dependency = {
                addons = OptionalAddons.GetGlobals({ ADDON_KEYS.ARKADIUS_TRADE_TOOLS }),
            },
            sortGroup = "marketIntegration",
            resetGroup = "marketIntegration",
        },
        mmIntegration = {
            labelStringId = SI_BETTERUI_MM_INTEGRATION,
            tooltipStringId = SI_BETTERUI_MM_INTEGRATION_TOOLTIP,
            defaultValue = true,
            dependency = {
                addons = OptionalAddons.GetGlobals({ ADDON_KEYS.MASTER_MERCHANT }),
            },
            sortGroup = "marketIntegration",
            resetGroup = "marketIntegration",
        },
        ttcIntegration = {
            labelStringId = SI_BETTERUI_TTC_INTEGRATION,
            tooltipStringId = SI_BETTERUI_TTC_INTEGRATION_TOOLTIP,
            defaultValue = true,
            dependency = {
                addons = OptionalAddons.GetGlobals({ ADDON_KEYS.TAMRIEL_TRADE_CENTRE }),
            },
            sortGroup = "marketIntegration",
            resetGroup = "marketIntegration",
        },
        marketPricePriority = {
            labelStringId = SI_BETTERUI_MARKET_PRICE_PRIORITY,
            tooltipStringId = SI_BETTERUI_MARKET_PRICE_PRIORITY_TOOLTIP,
            defaultValue = "mm_att_ttc",
            dependency = nil,
            sortGroup = "marketIntegration",
            resetGroup = "marketIntegration",
        },
        showCraftingMarketPrice = {
            labelStringId = SI_BETTERUI_SHOW_CRAFTING_MARKET_PRICE,
            tooltipStringId = SI_BETTERUI_SHOW_CRAFTING_MARKET_PRICE_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "marketIntegration",
            resetGroup = "marketIntegration",
        },
        showStyleTrait = {
            labelStringId = SI_BETTERUI_SHOW_STYLE_TRAIT,
            tooltipStringId = SI_BETTERUI_SHOW_STYLE_TRAIT_TOOLTIP,
            defaultValue = true,
            dependency = {
                module = "CIM",
                key = "enableTooltipEnhancements",
            },
            sortGroup = "enhancedTooltips",
            resetGroup = "enhancedTooltips",
        },
        showKnowledgeStatus = {
            labelStringId = SI_BETTERUI_SHOW_KNOWLEDGE_STATUS,
            tooltipStringId = SI_BETTERUI_SHOW_KNOWLEDGE_STATUS_TOOLTIP,
            defaultValue = true,
            dependency = {
                module = "CIM",
                key = "enableTooltipEnhancements",
            },
            sortGroup = "enhancedTooltips",
            resetGroup = "enhancedTooltips",
        },
        showItemComparison = {
            labelStringId = SI_BETTERUI_SHOW_ITEM_COMPARISON,
            tooltipStringId = SI_BETTERUI_SHOW_ITEM_COMPARISON_TOOLTIP,
            defaultValue = true,
            dependency = {
                module = "CIM",
                key = "enableTooltipEnhancements",
            },
            sortGroup = "enhancedTooltips",
            resetGroup = "enhancedTooltips",
        },
    },

    CIM = {
        rhScrollSpeed = {
            labelStringId = SI_BETTERUI_MOUSE_SCROLL_SPEED,
            tooltipStringId = SI_BETTERUI_MOUSE_SCROLL_SPEED_TOOLTIP,
            defaultValue = 50,
            dependency = nil,
            sortGroup = "generalInterfaceGeneral",
            resetGroup = "generalInterfaceGeneral",
        },
        enableTooltipEnhancements = {
            labelStringId = SI_BETTERUI_ENABLE_TOOLTIP_ENHANCEMENTS,
            tooltipStringId = SI_BETTERUI_ENABLE_TOOLTIP_ENHANCEMENTS_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "enhancedTooltips",
            resetGroup = "enhancedTooltips",
        },
        tooltipSize = {
            labelStringId = SI_BETTERUI_TOOLTIP_FONT_SIZE,
            tooltipStringId = SI_BETTERUI_TOOLTIP_FONT_SIZE_TOOLTIP,
            defaultValue = 24,
            dependency = {
                module = "CIM",
                key = "enableTooltipEnhancements",
            },
            sortGroup = "enhancedTooltips",
            resetGroup = "enhancedTooltips",
        },
    },

    Nameplates = {
        m_enabled = {
            labelStringId = SI_BETTERUI_NAMEPLATES_ENABLED,
            tooltipStringId = SI_BETTERUI_NAMEPLATES_ENABLED_TOOLTIP,
            defaultValue = false,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        moveCompassFrame = {
            labelStringId = SI_BETTERUI_NAMEPLATES_MOVE_COMPASS,
            tooltipStringId = SI_BETTERUI_NAMEPLATES_MOVE_COMPASS_TOOLTIP,
            defaultValue = false,
            dependency = nil,
            sortGroup = "positioning",
            resetGroup = "positioning",
        },
        compassFrameOffsetX = {
            labelStringId = SI_BETTERUI_NAMEPLATES_COMPASS_OFFSET_X,
            tooltipStringId = SI_BETTERUI_NAMEPLATES_OFFSET_X_TOOLTIP,
            defaultValue = 0,
            dependency = nil,
            sortGroup = "positioning",
            resetGroup = "positioning",
        },
        compassFrameOffsetY = {
            labelStringId = SI_BETTERUI_NAMEPLATES_COMPASS_OFFSET_Y,
            tooltipStringId = SI_BETTERUI_NAMEPLATES_OFFSET_Y_TOOLTIP,
            defaultValue = 0,
            dependency = nil,
            sortGroup = "positioning",
            resetGroup = "positioning",
        },
        moveTargetBar = {
            labelStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_MOVE_TARGET_BAR"),
            tooltipStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_MOVE_TARGET_BAR_TOOLTIP"),
            defaultValue = false,
            dependency = nil,
            sortGroup = "positioning",
            resetGroup = "positioning",
        },
        targetBarOffsetX = {
            labelStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_TARGET_BAR_OFFSET_X"),
            tooltipStringId = SI_BETTERUI_NAMEPLATES_OFFSET_X_TOOLTIP,
            defaultValue = 0,
            dependency = nil,
            sortGroup = "positioning",
            resetGroup = "positioning",
        },
        targetBarOffsetY = {
            labelStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_TARGET_BAR_OFFSET_Y"),
            tooltipStringId = SI_BETTERUI_NAMEPLATES_OFFSET_Y_TOOLTIP,
            defaultValue = 0,
            dependency = nil,
            sortGroup = "positioning",
            resetGroup = "positioning",
        },
        movePlayerInteract = {
            labelStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_MOVE_PLAYER_INTERACT"),
            tooltipStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_MOVE_PLAYER_INTERACT_TOOLTIP"),
            defaultValue = false,
            dependency = nil,
            sortGroup = "positioning",
            resetGroup = "positioning",
        },
        playerInteractOffsetX = {
            labelStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_PLAYER_INTERACT_OFFSET_X"),
            tooltipStringId = SI_BETTERUI_NAMEPLATES_OFFSET_X_TOOLTIP,
            defaultValue = 0,
            dependency = nil,
            sortGroup = "positioning",
            resetGroup = "positioning",
        },
        playerInteractOffsetY = {
            labelStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_PLAYER_INTERACT_OFFSET_Y"),
            tooltipStringId = SI_BETTERUI_NAMEPLATES_OFFSET_Y_TOOLTIP,
            defaultValue = 0,
            dependency = nil,
            sortGroup = "positioning",
            resetGroup = "positioning",
        },
        moveQuestTracker = {
            labelStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_MOVE_QUEST_TRACKER"),
            tooltipStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_MOVE_QUEST_TRACKER_TOOLTIP"),
            defaultValue = false,
            dependency = nil,
            sortGroup = "positioning",
            resetGroup = "positioning",
        },
        questTrackerOffsetX = {
            labelStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_QUEST_TRACKER_OFFSET_X"),
            tooltipStringId = SI_BETTERUI_NAMEPLATES_OFFSET_X_TOOLTIP,
            defaultValue = 0,
            dependency = nil,
            sortGroup = "positioning",
            resetGroup = "positioning",
        },
        questTrackerOffsetY = {
            labelStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_QUEST_TRACKER_OFFSET_Y"),
            tooltipStringId = SI_BETTERUI_NAMEPLATES_OFFSET_Y_TOOLTIP,
            defaultValue = 0,
            dependency = nil,
            sortGroup = "positioning",
            resetGroup = "positioning",
        },
        moveGroupFrames = {
            labelStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_MOVE_GROUP_FRAMES"),
            tooltipStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_MOVE_GROUP_FRAMES_TOOLTIP"),
            defaultValue = false,
            dependency = nil,
            sortGroup = "positioning",
            resetGroup = "positioning",
        },
        groupFramesOffsetX = {
            labelStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_GROUP_FRAMES_OFFSET_X"),
            tooltipStringId = SI_BETTERUI_NAMEPLATES_OFFSET_X_TOOLTIP,
            defaultValue = 0,
            dependency = nil,
            sortGroup = "positioning",
            resetGroup = "positioning",
        },
        groupFramesOffsetY = {
            labelStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_GROUP_FRAMES_OFFSET_Y"),
            tooltipStringId = SI_BETTERUI_NAMEPLATES_OFFSET_Y_TOOLTIP,
            defaultValue = 0,
            dependency = nil,
            sortGroup = "positioning",
            resetGroup = "positioning",
        },
        compassFrameScale = {
            labelStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_COMPASS_SCALE"),
            tooltipStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_SCALE_TOOLTIP"),
            defaultValue = 1,
            dependency = nil,
            sortGroup = "positioning",
            resetGroup = "positioning",
        },
        targetBarScale = {
            labelStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_TARGET_BAR_SCALE"),
            tooltipStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_SCALE_TOOLTIP"),
            defaultValue = 1,
            dependency = nil,
            sortGroup = "positioning",
            resetGroup = "positioning",
        },
        playerInteractScale = {
            labelStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_PLAYER_INTERACT_SCALE"),
            tooltipStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_SCALE_TOOLTIP"),
            defaultValue = 1,
            dependency = nil,
            sortGroup = "positioning",
            resetGroup = "positioning",
        },
        questTrackerScale = {
            labelStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_QUEST_TRACKER_SCALE"),
            tooltipStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_SCALE_TOOLTIP"),
            defaultValue = 1,
            dependency = nil,
            sortGroup = "positioning",
            resetGroup = "positioning",
        },
        groupFramesScale = {
            labelStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_GROUP_FRAMES_SCALE"),
            tooltipStringId = rawget(_G, "SI_BETTERUI_NAMEPLATES_SCALE_TOOLTIP"),
            defaultValue = 1,
            dependency = nil,
            sortGroup = "positioning",
            resetGroup = "positioning",
        },
    },
}

local function CloneDefaultValue(value)
    if type(value) ~= "table" then
        return value
    end

    local clone = {}
    for key, item in pairs(value) do
        if type(item) == "table" then
            clone[key] = CloneDefaultValue(item)
        else
            clone[key] = item
        end
    end
    return clone
end

--- Returns centralized metadata for a module setting key.
--- Falls back to Shared metadata when module-specific metadata is unavailable.
function BETTERUI.CIM.Settings.GetSettingMetadata(moduleName, settingKey)
    if type(settingKey) ~= "string" then
        return nil
    end

    local moduleRegistry = SETTINGS_METADATA_REGISTRY[moduleName]
    if type(moduleRegistry) == "table" and moduleRegistry[settingKey] then
        return moduleRegistry[settingKey]
    end

    local sharedRegistry = SETTINGS_METADATA_REGISTRY.Shared
    if type(sharedRegistry) == "table" then
        return sharedRegistry[settingKey]
    end

    return nil
end

--- Returns optional addon dependency globals for a setting, if defined.
--- Returned list is a cloned snapshot to avoid mutating metadata registry state.
function BETTERUI.CIM.Settings.GetSettingDependencyAddons(moduleName, settingKey)
    local metadata = BETTERUI.CIM.Settings.GetSettingMetadata(moduleName, settingKey)
    local dependency = metadata and metadata.dependency
    local addons = dependency and dependency.addons
    if type(addons) ~= "table" then
        return nil
    end
    return CloneDefaultValue(addons)
end

--- Returns the default value for a module setting using metadata first, then DefaultsRegistry.
function BETTERUI.CIM.Settings.GetSettingDefault(moduleName, settingKey, fallback)
    local metadata = BETTERUI.CIM.Settings.GetSettingMetadata(moduleName, settingKey)
    if metadata and metadata.defaultValue ~= nil then
        return CloneDefaultValue(metadata.defaultValue)
    end

    local defaultsApi = BETTERUI.Defaults
    if defaultsApi and type(defaultsApi.GetModuleDefaults) == "function" then
        local defaults = defaultsApi.GetModuleDefaults(moduleName)
        local registryDefault = defaults and defaults[settingKey]
        if registryDefault ~= nil then
            return CloneDefaultValue(registryDefault)
        end
    end

    return fallback
end

--- Resets module settings that belong to the requested reset group.
---@return boolean handled True when the registry reset was applied; callers
--- with their own fallback (e.g. IconSettingsFactory) only skip it on true.
function BETTERUI.CIM.Settings.ResetModuleSettingsByGroup(moduleName, resetGroup)
    if type(moduleName) ~= "string" or type(resetGroup) ~= "string" then
        TraceSettingsMetadata("settings.group_reset", "skipped", {
            reason = "invalidArguments",
            targetModule = moduleName,
            resetGroup = resetGroup,
        })
        return false
    end

    TraceSettingsMetadata("settings.group_reset", "begin", {
        targetModule = moduleName,
        resetGroup = resetGroup,
    })

    local settings = BETTERUI.EnsureModuleSettings(moduleName)
    if type(settings) ~= "table" or not next(settings) then
        TraceSettingsMetadata("settings.group_reset", "skipped", {
            reason = "missingSettings",
            targetModule = moduleName,
            resetGroup = resetGroup,
        })
        return false
    end

    local function applyDefaultSetting(settingKey, defaultValue)
        local usedSetSetting = false
        local applied = false
        if type(BETTERUI.SetSetting) == "function" then
            usedSetSetting = true
            applied = BETTERUI.SetSetting(moduleName, settingKey, defaultValue) == true
        else
            settings[settingKey] = defaultValue
            applied = true
        end
        TraceSettingsMetadata("settings.group_reset", applied and "setting_applied" or "setting_failed", {
            targetModule = moduleName,
            resetGroup = resetGroup,
            key = tostring(settingKey),
            viaSetSetting = usedSetSetting,
        })
        return applied
    end

    local function applyRegistryReset(registryTable)
        if type(registryTable) ~= "table" then
            return 0
        end

        local appliedCount = 0
        for settingKey, metadata in pairs(registryTable) do
            if type(metadata) == "table" and metadata.resetGroup == resetGroup then
                local defaultValue = BETTERUI.CIM.Settings.GetSettingDefault(moduleName, settingKey, nil)
                if defaultValue ~= nil then
                    if applyDefaultSetting(settingKey, defaultValue) then
                        appliedCount = appliedCount + 1
                    end
                end
            end
        end
        return appliedCount
    end

    -- Shared metadata first, then module metadata to allow module-specific overrides.
    local sharedCount = applyRegistryReset(SETTINGS_METADATA_REGISTRY.Shared)
    local moduleCount = applyRegistryReset(SETTINGS_METADATA_REGISTRY[moduleName])
    local appliedCount = sharedCount + moduleCount
    TraceSettingsMetadata("settings.group_reset", "end", {
        targetModule = moduleName,
        resetGroup = resetGroup,
        sharedCount = sharedCount,
        moduleCount = moduleCount,
        appliedCount = appliedCount,
    })
    if appliedCount == 0 then
        TraceSettingsMetadata("settings.group_reset", "empty", {
            targetModule = moduleName,
            resetGroup = resetGroup,
        })
        return false
    end
    return true
end
