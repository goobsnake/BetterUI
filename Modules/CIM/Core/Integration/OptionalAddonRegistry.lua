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

local ADDON_DEFS = {
    [OptionalAddons.KEYS.MASTER_MERCHANT] = {
        global = "MasterMerchant",
        displayName = "Master Merchant",
        groups = {
            market = true,
            guildStore = true,
        },
    },
    [OptionalAddons.KEYS.ARKADIUS_TRADE_TOOLS] = {
        global = "ArkadiusTradeTools",
        displayName = "Arkadius Trade Tools",
        groups = {
            market = true,
            guildStore = true,
        },
    },
    [OptionalAddons.KEYS.TAMRIEL_TRADE_CENTRE] = {
        global = "TamrielTradeCentre",
        displayName = "Tamriel Trade Centre",
        groups = {
            market = true,
        },
    },
    [OptionalAddons.KEYS.AUTO_CATEGORY] = {
        global = "AutoCategory",
        displayName = "Auto Category",
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
}

local GLOBAL_TO_KEY = {}
for addonKey, addonDef in pairs(ADDON_DEFS) do
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
    return GLOBAL_TO_KEY[addonKeyOrGlobal]
end

function OptionalAddons.GetKeyForGlobal(globalName)
    if type(globalName) ~= "string" or globalName == "" then
        return nil
    end
    return GLOBAL_TO_KEY[globalName]
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
    return OptionalAddons.GetGlobals(OPTIONAL_ADDON_KEYS)
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

function OptionalAddons.AnyLoaded(addonKeys)
    for _, addonKeyOrGlobal in ipairs(addonKeys or {}) do
        if OptionalAddons.IsLoaded(addonKeyOrGlobal) then
            return true
        end
    end
    return false
end
