--[[
File: Modules/CIM/Core/Integration/OptionalAddonRegistry.lua
Purpose: Central registry for optional addon identities, display names, and load checks.
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.OptionalAddons = BETTERUI.CIM.OptionalAddons or {}

local OptionalAddons = BETTERUI.CIM.OptionalAddons

local ADDON_DEFS = {
    MasterMerchant = {
        global = "MasterMerchant",
        displayName = "Master Merchant",
    },
    ArkadiusTradeTools = {
        global = "ArkadiusTradeTools",
        displayName = "Arkadius Trade Tools",
    },
    TamrielTradeCentre = {
        global = "TamrielTradeCentre",
        displayName = "Tamriel Trade Centre",
    },
    AutoCategory = {
        global = "AutoCategory",
        displayName = "Auto Category",
    },
}

-- Canonical optional-addon key order.
-- Keep BetterUI.txt OptionalDependsOn synchronized with this list.
local OPTIONAL_ADDON_KEYS = {
    "MasterMerchant",
    "ArkadiusTradeTools",
    "TamrielTradeCentre",
    "AutoCategory",
}

local MARKET_ADDON_KEYS = {
    "MasterMerchant",
    "ArkadiusTradeTools",
    "TamrielTradeCentre",
}

local GUILD_STORE_ADDON_KEYS = {
    "MasterMerchant",
    "ArkadiusTradeTools",
}

local function CloneArray(values)
    local clone = {}
    for index, value in ipairs(values or {}) do
        clone[index] = value
    end
    return clone
end

function OptionalAddons.GetManifestGlobals()
    return OptionalAddons.GetGlobals(OPTIONAL_ADDON_KEYS)
end

function OptionalAddons.GetAddonKeys()
    return CloneArray(OPTIONAL_ADDON_KEYS)
end

function OptionalAddons.GetMarketAddonKeys()
    return CloneArray(MARKET_ADDON_KEYS)
end

function OptionalAddons.GetGuildStoreAddonKeys()
    return CloneArray(GUILD_STORE_ADDON_KEYS)
end

function OptionalAddons.GetGlobals(addonKeys)
    local globals = {}
    for _, addonKey in ipairs(addonKeys or {}) do
        local addonDef = ADDON_DEFS[addonKey]
        if addonDef and addonDef.global then
            globals[#globals + 1] = addonDef.global
        end
    end
    return globals
end

function OptionalAddons.GetGlobal(addonKey)
    local addonDef = ADDON_DEFS[addonKey]
    local globalName = addonDef and addonDef.global or nil
    if type(globalName) ~= "string" then
        return nil
    end
    return _G[globalName]
end

function OptionalAddons.GetMarketGlobals()
    return OptionalAddons.GetGlobals(MARKET_ADDON_KEYS)
end

function OptionalAddons.GetGuildStoreGlobals()
    return OptionalAddons.GetGlobals(GUILD_STORE_ADDON_KEYS)
end

function OptionalAddons.GetDisplayName(addonKey)
    local addonDef = ADDON_DEFS[addonKey]
    return addonDef and addonDef.displayName or addonKey
end

function OptionalAddons.IsLoaded(addonKey)
    return OptionalAddons.GetGlobal(addonKey) ~= nil
end

function OptionalAddons.AnyLoaded(addonKeys)
    for _, addonKey in ipairs(addonKeys or {}) do
        if OptionalAddons.IsLoaded(addonKey) then
            return true
        end
    end
    return false
end
