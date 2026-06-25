--[[
File: Modules/CIM/Core/Settings/SettingsReset.lua
Purpose: Shared helper for resetting all BetterUI settings back to defaults.
]]

if not BETTERUI then BETTERUI = {} end
if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.Settings then BETTERUI.CIM.Settings = {} end

local function CountTableKeys(value)
    if type(value) ~= "table" then return 0 end
    local count = 0
    for _ in pairs(value) do count = count + 1 end
    return count
end

local function TraceSettingsReset(phase, data)
    local L = BETTERUI and BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = "CIM"
    data.feature = "settingsReset"
    if L.SetLastAction then
        L.SetLastAction({ flow = "settings.reset", message = "settings.reset:" .. tostring(phase) })
    end
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.SETTINGS or categories.SETTING or "SETTINGS", "settings.reset", phase, data)
end

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
        or key == "version" -- ZO_SavedVars bookkeeping key in the raw data table
end

--- Returns the table that actually holds persisted keys.
--- ZO_SavedVars:New returns an interface table whose data lives behind the
--- metatable __index, so pairs() over the interface itself never sees the
--- persisted keys (see esoui/libraries/utility/zo_savedvars.lua,
--- CreateExposedInterface). Plain-table stores are returned unchanged.
local function GetRawStoreData(store)
    local mt = getmetatable(store)
    local rawData = mt and mt.__index
    if type(rawData) == "table" then
        return rawData
    end
    if type(rawData) == "function" then
        TraceSettingsReset("raw_store_proxy", {
            reason = "functionIndexProxy",
            storeType = type(store),
        })
    end
    return store
end

--- Builds default settings for a module.
---
local function BuildModuleDefaults(moduleName, moduleNamespace)
    local moduleSettings = {}

    TraceSettingsReset("module_defaults_begin", {
        targetModule = moduleName,
        hasInitModule = moduleNamespace and type(moduleNamespace.InitModule) == "function" or false,
        hasDefaultsRegistry = BETTERUI.Defaults and type(BETTERUI.Defaults.ApplyModuleDefaults) == "function" or false,
    })

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

    local defaults = DeepCopy(moduleSettings)
    TraceSettingsReset("module_defaults_end", {
        targetModule = moduleName,
        keyCount = CountTableKeys(defaults),
    })
    return defaults
end

--- Resets the settings store to defaults.
---
local function ResetSettingsStore(store)
    if type(store) ~= "table" then
        TraceSettingsReset("store_reset_skipped", { reason = "invalidStore" })
        return
    end

    -- pairs() over the ZO_SavedVars interface table is a no-op: persisted keys
    -- live in the raw backing table behind the metatable __index. Operate on
    -- the raw table so stale keys are actually cleared.
    local rawStore = GetRawStoreData(store)
    TraceSettingsReset("store_reset_begin", {
        topLevelKeyCount = CountTableKeys(rawStore),
    })

    local preservedUseAccountWide = rawStore.useAccountWide
    local clearedKeyCount = 0

    for key in pairs(rawStore) do
        if not IsRetainedTopLevelKey(key) then
            rawStore[key] = nil
            clearedKeyCount = clearedKeyCount + 1
        end
    end

    if preservedUseAccountWide == nil then
        preservedUseAccountWide = (BETTERUI.DefaultSettings and BETTERUI.DefaultSettings.useAccountWide) or false
    end

    rawStore.useAccountWide = preservedUseAccountWide
    rawStore.FeatureFlags = {}
    rawStore.SortOptions = {}
    rawStore.Modules = {}

    local resetModuleCount = 0
    for _, moduleInfo in ipairs(MODULE_RESET_ORDER) do
        local moduleName = moduleInfo[1]
        local moduleNamespace = moduleInfo[2]
        rawStore.Modules[moduleName] = BuildModuleDefaults(moduleName, moduleNamespace)
        resetModuleCount = resetModuleCount + 1
    end

    if BETTERUI.Defaults and type(BETTERUI.Defaults.ApplyFirstInstallDefaults) == "function" then
        BETTERUI.Defaults.ApplyFirstInstallDefaults(rawStore)
    end

    rawStore.firstInstall = false
    TraceSettingsReset("store_reset_end", {
        clearedKeyCount = clearedKeyCount,
        resetModuleCount = resetModuleCount,
        useAccountWide = rawStore.useAccountWide,
    })
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
        TraceSettingsReset("all_reset_skipped", { reason = "missingActiveStore" })
        return
    end

    TraceSettingsReset("all_reset_begin", {
        hasSavedVars = type(BETTERUI.SavedVars) == "table",
        hasGlobalVars = type(BETTERUI.GlobalVars) == "table",
        activeKeyCount = CountTableKeys(GetRawStoreData(targetStore)),
    })

    ResetSettingsStore(targetStore)
    BETTERUI.Settings = targetStore

    local nameplatesSettings = targetStore.Modules and targetStore.Modules["Nameplates"]
    local restoredNameplates = false
    if BETTERUI.Nameplates and type(BETTERUI.Nameplates.OnEnabledChanged) == "function" and
        (type(nameplatesSettings) ~= "table" or nameplatesSettings.m_enabled ~= true) then
        -- Nameplate font overrides can persist until explicitly restored.
        BETTERUI.Nameplates.OnEnabledChanged(false, true)
        restoredNameplates = true
    end

    local resetFeatureFlags = false
    if BETTERUI.CIM.FeatureFlags and type(BETTERUI.CIM.FeatureFlags.ResetToDefaults) == "function" then
        BETTERUI.CIM.FeatureFlags.ResetToDefaults()
        resetFeatureFlags = true
    end

    local updatedCimState = false
    if BETTERUI.UpdateCIMState then
        BETTERUI.UpdateCIMState()
        updatedCimState = true
    end

    TraceSettingsReset("all_reset_end", {
        restoredNameplates = restoredNameplates,
        resetFeatureFlags = resetFeatureFlags,
        updatedCimState = updatedCimState,
        moduleCount = targetStore.Modules and CountTableKeys(targetStore.Modules) or 0,
    })
end
