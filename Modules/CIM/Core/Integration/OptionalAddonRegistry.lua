--[[
File: Modules/CIM/Core/Integration/OptionalAddonRegistry.lua
Purpose: Central registry for optional addon identities, display names, and load checks.
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.OptionalAddons = BETTERUI.CIM.OptionalAddons or {}

local OptionalAddons = BETTERUI.CIM.OptionalAddons

OptionalAddons.KEYS = OptionalAddons.KEYS or {}
OptionalAddons.KEYS.MASTER_MERCHANT = "MasterMerchant"
OptionalAddons.KEYS.ARKADIUS_TRADE_TOOLS = "ArkadiusTradeTools"
OptionalAddons.KEYS.TAMRIEL_TRADE_CENTRE = "TamrielTradeCentre"
OptionalAddons.KEYS.AUTO_CATEGORY = "AutoCategory"
OptionalAddons.KEYS.FCO_ITEM_SAVER = "FCOItemSaver"
OptionalAddons.KEYS.DOLGUBON_LAZY_WRIT_CRAFTER = "DolgubonsLazyWritCreator"
OptionalAddons.KEYS.ALPHA_GEAR = "AlphaGear"

local ADDON_DEFS = {
    [OptionalAddons.KEYS.MASTER_MERCHANT] = {
        manifest = "MasterMerchant",
        global = "MasterMerchant",
        displayName = "Master Merchant",
        groups = {
            market = true,
            guildStore = true,
        },
    },
    [OptionalAddons.KEYS.ARKADIUS_TRADE_TOOLS] = {
        manifest = "ArkadiusTradeTools",
        global = "ArkadiusTradeTools",
        displayName = "Arkadius Trade Tools",
        groups = {
            market = true,
            guildStore = true,
        },
    },
    [OptionalAddons.KEYS.TAMRIEL_TRADE_CENTRE] = {
        manifest = "TamrielTradeCentre",
        global = "TamrielTradeCentre",
        displayName = "Tamriel Trade Centre",
        groups = {
            market = true,
        },
    },
    [OptionalAddons.KEYS.AUTO_CATEGORY] = {
        manifest = "AutoCategory",
        global = "AutoCategory",
        displayName = "Auto Category",
        groups = {},
    },
    [OptionalAddons.KEYS.FCO_ITEM_SAVER] = {
        manifest = "FCOItemSaver",
        global = "FCOIS",
        displayName = "FCO ItemSaver",
        groups = {},
    },
    [OptionalAddons.KEYS.DOLGUBON_LAZY_WRIT_CRAFTER] = {
        manifest = "DolgubonsLazyWritCreator",
        global = "WritCreater",
        displayName = "Dolgubon's Lazy Writ Crafter",
        groups = {},
    },
    [OptionalAddons.KEYS.ALPHA_GEAR] = {
        manifest = "AlphaGear",
        global = "AG",
        displayName = "AlphaGear",
        groups = {},
    },
}

-- Canonical optional-addon key order.
-- Keep BetterUI.txt OptionalDependsOn synchronized with this list.
local OPTIONAL_ADDON_KEYS = {
    OptionalAddons.KEYS.MASTER_MERCHANT,
    OptionalAddons.KEYS.ARKADIUS_TRADE_TOOLS,
    OptionalAddons.KEYS.TAMRIEL_TRADE_CENTRE,
    OptionalAddons.KEYS.AUTO_CATEGORY,
    OptionalAddons.KEYS.FCO_ITEM_SAVER,
    OptionalAddons.KEYS.DOLGUBON_LAZY_WRIT_CRAFTER,
    OptionalAddons.KEYS.ALPHA_GEAR,
}

local GLOBAL_TO_KEY = {}
local MANIFEST_TO_KEY = {}
for addonKey, addonDef in pairs(ADDON_DEFS) do
    local manifestName = addonDef and addonDef.manifest
    if type(manifestName) == "string" and manifestName ~= "" then
        MANIFEST_TO_KEY[manifestName] = addonKey
    end
    local globalName = addonDef and addonDef.global
    if type(globalName) == "string" and globalName ~= "" then
        GLOBAL_TO_KEY[globalName] = addonKey
    end
end

local function CloneArray(values)
    local clone = {}
    for index, value in ipairs(values or {}) do
        clone[index] = value
    end
    return clone
end

function OptionalAddons.ResolveKey(addonKeyOrGlobal)
    if type(addonKeyOrGlobal) ~= "string" or addonKeyOrGlobal == "" then
        return nil
    end
    if ADDON_DEFS[addonKeyOrGlobal] then
        return addonKeyOrGlobal
    end
    return GLOBAL_TO_KEY[addonKeyOrGlobal] or MANIFEST_TO_KEY[addonKeyOrGlobal]
end

function OptionalAddons.GetGlobalName(addonKeyOrGlobal)
    local resolvedKey = OptionalAddons.ResolveKey(addonKeyOrGlobal)
    local addonDef = resolvedKey and ADDON_DEFS[resolvedKey] or nil
    local globalName = addonDef and addonDef.global or nil
    if type(globalName) ~= "string" then
        return nil
    end
    return globalName
end

function OptionalAddons.GetAddonKeysByGroup(groupName)
    if type(groupName) ~= "string" or groupName == "" then
        return {}
    end

    local groupKeys = {}
    for _, addonKey in ipairs(OPTIONAL_ADDON_KEYS) do
        local addonDef = ADDON_DEFS[addonKey]
        if addonDef and addonDef.groups and addonDef.groups[groupName] == true then
            groupKeys[#groupKeys + 1] = addonKey
        end
    end
    return groupKeys
end

function OptionalAddons.GetManifestGlobals()
    return OptionalAddons.GetManifestNames(OPTIONAL_ADDON_KEYS)
end

function OptionalAddons.GetAddonKeys()
    return CloneArray(OPTIONAL_ADDON_KEYS)
end

function OptionalAddons.GetMarketAddonKeys()
    return OptionalAddons.GetAddonKeysByGroup("market")
end

function OptionalAddons.GetGuildStoreAddonKeys()
    return OptionalAddons.GetAddonKeysByGroup("guildStore")
end

function OptionalAddons.GetGlobals(addonKeys)
    local globals = {}
    for _, addonKeyOrGlobal in ipairs(addonKeys or {}) do
        local resolvedKey = OptionalAddons.ResolveKey(addonKeyOrGlobal)
        local addonDef = resolvedKey and ADDON_DEFS[resolvedKey] or nil
        if addonDef and addonDef.global then
            globals[#globals + 1] = addonDef.global
        end
    end
    return globals
end

function OptionalAddons.GetManifestNames(addonKeys)
    local manifests = {}
    for _, addonKeyOrGlobal in ipairs(addonKeys or {}) do
        local resolvedKey = OptionalAddons.ResolveKey(addonKeyOrGlobal)
        local addonDef = resolvedKey and ADDON_DEFS[resolvedKey] or nil
        local manifestName = addonDef and addonDef.manifest or nil
        if type(manifestName) == "string" and manifestName ~= "" then
            manifests[#manifests + 1] = manifestName
        end
    end
    return manifests
end

function OptionalAddons.GetGlobal(addonKeyOrGlobal)
    local globalName = OptionalAddons.GetGlobalName(addonKeyOrGlobal)
    if not globalName then
        return nil
    end
    return _G[globalName]
end

function OptionalAddons.GetMarketGlobals()
    return OptionalAddons.GetGlobals(OptionalAddons.GetMarketAddonKeys())
end

function OptionalAddons.GetGuildStoreGlobals()
    return OptionalAddons.GetGlobals(OptionalAddons.GetGuildStoreAddonKeys())
end

function OptionalAddons.GetDisplayName(addonKeyOrGlobal)
    local resolvedKey = OptionalAddons.ResolveKey(addonKeyOrGlobal)
    local addonDef = resolvedKey and ADDON_DEFS[resolvedKey] or nil
    return addonDef and addonDef.displayName or addonKeyOrGlobal
end

function OptionalAddons.GetDisplayNameForGlobal(globalName)
    return OptionalAddons.GetDisplayName(globalName)
end

function OptionalAddons.IsLoaded(addonKeyOrGlobal)
    return OptionalAddons.GetGlobal(addonKeyOrGlobal) ~= nil
end

