--[[
File: Modules/CIM/Core/SettingsMetadata.lua
Purpose: Settings metadata registry and default/reset management.
         Defines per-module setting metadata (labels, tooltips, defaults, dependencies).
         Provides lookup, default retrieval, and group-based reset functions.
]]

-- NAMESPACE INITIALIZATION

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.Settings then BETTERUI.CIM.Settings = {} end

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
            tooltipStringId = nil,
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
                addons = { "MasterMerchant", "ArkadiusTradeTools", "TamrielTradeCentre" },
            },
            sortGroup = "marketIntegration",
            resetGroup = "marketIntegration",
        },
        guildStoreErrorSuppress = {
            labelStringId = SI_BETTERUI_GS_ERROR_SUPPRESS,
            tooltipStringId = SI_BETTERUI_GS_ERROR_SUPPRESS_TOOLTIP,
            defaultValue = true,
            dependency = {
                addons = { "MasterMerchant", "ArkadiusTradeTools" },
            },
            sortGroup = "marketIntegration",
            resetGroup = "marketIntegration",
        },
        attIntegration = {
            labelStringId = SI_BETTERUI_ATT_INTEGRATION,
            tooltipStringId = SI_BETTERUI_ATT_INTEGRATION_TOOLTIP,
            defaultValue = true,
            dependency = {
                addons = { "ArkadiusTradeTools" },
            },
            sortGroup = "marketIntegration",
            resetGroup = "marketIntegration",
        },
        mmIntegration = {
            labelStringId = SI_BETTERUI_MM_INTEGRATION,
            tooltipStringId = SI_BETTERUI_MM_INTEGRATION_TOOLTIP,
            defaultValue = true,
            dependency = {
                addons = { "MasterMerchant" },
            },
            sortGroup = "marketIntegration",
            resetGroup = "marketIntegration",
        },
        ttcIntegration = {
            labelStringId = SI_BETTERUI_TTC_INTEGRATION,
            tooltipStringId = SI_BETTERUI_TTC_INTEGRATION_TOOLTIP,
            defaultValue = true,
            dependency = {
                addons = { "TamrielTradeCentre" },
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

--- Returns the default value for a module setting using metadata first, then DefaultsRegistry.
function BETTERUI.CIM.Settings.GetSettingDefault(moduleName, settingKey, fallback)
    local metadata = BETTERUI.CIM.Settings.GetSettingMetadata(moduleName, settingKey)
    if metadata and metadata.defaultValue ~= nil then
        return CloneDefaultValue(metadata.defaultValue)
    end

    local getDefault = BETTERUI.CIM.TryResolve("Defaults.GetDefault")
    if getDefault then
        local registryDefault = getDefault(moduleName, settingKey)
        if registryDefault ~= nil then
            return CloneDefaultValue(registryDefault)
        end
    end

    return fallback
end

--- Resets module settings that belong to the requested reset group.
function BETTERUI.CIM.Settings.ResetModuleSettingsByGroup(moduleName, resetGroup)
    if type(moduleName) ~= "string" or type(resetGroup) ~= "string" then
        return
    end

    local settings = BETTERUI.GetModuleSettings(moduleName)
    if not next(settings) then
        return
    end

    local function applyRegistryReset(registryTable)
        if type(registryTable) ~= "table" then
            return
        end

        for settingKey, metadata in pairs(registryTable) do
            if type(metadata) == "table" and metadata.resetGroup == resetGroup then
                local defaultValue = BETTERUI.CIM.Settings.GetSettingDefault(moduleName, settingKey, nil)
                if defaultValue ~= nil then
                    settings[settingKey] = defaultValue
                end
            end
        end
    end

    -- Shared metadata first, then module metadata to allow module-specific overrides.
    applyRegistryReset(SETTINGS_METADATA_REGISTRY.Shared)
    applyRegistryReset(SETTINGS_METADATA_REGISTRY[moduleName])
end
