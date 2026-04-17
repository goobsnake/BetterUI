--[[
File: Modules/CIM/Core/SettingsReset.lua
Purpose: Shared helper for resetting all BetterUI settings back to defaults.
]]

if not BETTERUI then BETTERUI = {} end
if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.Settings then BETTERUI.CIM.Settings = {} end

local MODULE_RESET_ORDER = {
    { "CIM", BETTERUI.CIM },
    { "Inventory", BETTERUI.Inventory },
    { "Banking", BETTERUI.Banking },
    { "Vendor", BETTERUI.Vendor },
    { "TradingHouse", BETTERUI.TradingHouse },
    { "Companions", BETTERUI.Companions },
    { "Writs", BETTERUI.Writs },
    { "GeneralInterface", BETTERUI.GeneralInterface },
    { "Nameplates", BETTERUI.Nameplates },
    { "ResourceOrbFrames", BETTERUI.ResourceOrbFrames },
}

--- Deep copies a value, handling circular references.
---
local function DeepCopy(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy

    for key, nestedValue in pairs(value) do
        copy[DeepCopy(key, seen)] = DeepCopy(nestedValue, seen)
    end

    return copy
end

--- Checks if a key should be retained during settings reset.
---
local function IsRetainedTopLevelKey(key)
    return key == "useAccountWide"
        or key == "firstInstall"
        or key == "Modules"
        or key == "FeatureFlags"
        or key == "SortOptions"
end

--- Builds default settings for a module.
---
local function BuildModuleDefaults(moduleName, moduleNamespace)
    local moduleSettings = {}

    -- Phase: build-module-defaults
    if moduleNamespace and type(moduleNamespace.InitModule) == "function" then
        local success, result = BETTERUI.CIM.SafeExecute(
            "SettingsReset:BuildModuleDefaults:" .. moduleName,
            moduleNamespace.InitModule,
            moduleSettings
        )
        if success and type(result) == "table" then
            moduleSettings = result
        end
    elseif BETTERUI.Defaults and type(BETTERUI.Defaults.ApplyModuleDefaults) == "function" then
        moduleSettings = BETTERUI.Defaults.ApplyModuleDefaults(moduleName, moduleSettings)
    end

    return DeepCopy(moduleSettings)
end

--- Resets the settings store to defaults.
---
local function ResetSettingsStore(store)
    if type(store) ~= "table" then
        return
    end

    local preservedUseAccountWide = store.useAccountWide

    for key in pairs(store) do
        if not IsRetainedTopLevelKey(key) then
            store[key] = nil
        end
    end

    if preservedUseAccountWide == nil then
        preservedUseAccountWide = (BETTERUI.DefaultSettings and BETTERUI.DefaultSettings.useAccountWide) or false
    end

    store.useAccountWide = preservedUseAccountWide
    store.FeatureFlags = {}
    store.SortOptions = {}
    store.Modules = {}

    for _, moduleInfo in ipairs(MODULE_RESET_ORDER) do
        local moduleName = moduleInfo[1]
        local moduleNamespace = moduleInfo[2]
        store.Modules[moduleName] = BuildModuleDefaults(moduleName, moduleNamespace)
    end

    if BETTERUI.Defaults and type(BETTERUI.Defaults.ApplyFirstInstallDefaults) == "function" then
        BETTERUI.Defaults.ApplyFirstInstallDefaults(store)
    end

    store.firstInstall = false
end

--- Gets the active settings store.
---
local function GetActiveSettingsStore()
    if type(BETTERUI.Settings) == "table" then
        return BETTERUI.Settings
    end

    local savedVars = BETTERUI.SavedVars
    local globalVars = BETTERUI.GlobalVars

    if type(savedVars) == "table" and savedVars.useAccountWide and type(globalVars) == "table" then
        return globalVars
    end

    if type(savedVars) == "table" then
        return savedVars
    end

    if type(globalVars) == "table" then
        return globalVars
    end

    return nil
end

--- Resets all BetterUI settings to their default values.
function BETTERUI.CIM.Settings.ResetAllSettingsToDefaults()
    local targetStore = GetActiveSettingsStore()
    if type(targetStore) ~= "table" then
        return
    end

    ResetSettingsStore(targetStore)
    BETTERUI.Settings = targetStore

    local nameplatesSettings = targetStore.Modules and targetStore.Modules["Nameplates"]
    if BETTERUI.Nameplates and type(BETTERUI.Nameplates.OnEnabledChanged) == "function" and
        (type(nameplatesSettings) ~= "table" or nameplatesSettings.m_enabled ~= true) then
        -- Nameplate font overrides can persist until explicitly restored.
        BETTERUI.Nameplates.OnEnabledChanged(false, true)
    end

    if BETTERUI.CIM.FeatureFlags and type(BETTERUI.CIM.FeatureFlags.ResetToDefaults) == "function" then
        BETTERUI.CIM.FeatureFlags.ResetToDefaults()
    end

    if BETTERUI.UpdateCIMState then
        BETTERUI.UpdateCIMState()
    end
end
