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

local MANIFEST_OPTIONAL_ADDONS = {
    "MasterMerchant",
    "ArkadiusTradeTools",
    "TamrielTradeCentre",
    "AutoCategory",
}

local function CloneArray(values)
    local clone = {}
    for index, value in ipairs(values or {}) do
        clone[index] = value
    end
    return clone
end

function OptionalAddons.GetManifestGlobals()
    return CloneArray(MANIFEST_OPTIONAL_ADDONS)
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
