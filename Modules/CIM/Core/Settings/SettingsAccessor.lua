--[[
File: Modules/CIM/SettingsAccessor.lua
Purpose: Provides safe module settings access with automatic nil-checking.
         Eliminates repetitive nil checks when accessing BETTERUI.Settings.Modules.
]]

if not BETTERUI then BETTERUI = {} end

---@overload fun(moduleName: "Inventory", defaults: BetterUIInventorySettings|nil): BetterUIInventorySettings
---@overload fun(moduleName: "Banking", defaults: BetterUIBankingSettings|nil): BetterUIBankingSettings
---@overload fun(moduleName: "Vendor", defaults: BetterUIVendorSettings|nil): BetterUIVendorSettings
---@overload fun(moduleName: "TradingHouse", defaults: BetterUITradingHouseSettings|nil): BetterUITradingHouseSettings
---@overload fun(moduleName: "Companions", defaults: BetterUICompanionsSettings|nil): BetterUICompanionsSettings
---@overload fun(moduleName: "GeneralInterface", defaults: BetterUIGeneralInterfaceSettings|nil): BetterUIGeneralInterfaceSettings
---@overload fun(moduleName: "Nameplates", defaults: BetterUINameplatesSettings|nil): BetterUINameplatesSettings
---@overload fun(moduleName: "ResourceOrbFrames", defaults: BetterUIResourceOrbFramesSettings|nil): BetterUIResourceOrbFramesSettings
---@overload fun(moduleName: "CIM", defaults: BetterUICIMSettings|nil): BetterUICIMSettings
---@overload fun(moduleName: "Writs", defaults: BetterUIWritsSettings|nil): BetterUIWritsSettings
---@param moduleName ModuleName|string Module name key (e.g. "Inventory", "Banking")
---@param defaults BetterUIModuleSettings|nil Fallback table if module settings are absent
---@return BetterUIModuleSettings settings The module's settings table, or defaults
function BETTERUI.GetModuleSettings(moduleName, defaults)
    if BETTERUI.Settings and BETTERUI.Settings.Modules and BETTERUI.Settings.Modules[moduleName] then
        return BETTERUI.Settings.Modules[moduleName]
    end
    return defaults or {}
end

--- Ensures the settings table exists for a module, creating it if necessary.
--- Unlike GetModuleSettings, the returned reference is persisted in BETTERUI.Settings.Modules,
--- so callers may write through it. Use this for mutation patterns; use GetModuleSettings for reads.
---@overload fun(moduleName: "Inventory"): BetterUIInventorySettings
---@overload fun(moduleName: "Banking"): BetterUIBankingSettings
---@overload fun(moduleName: "Vendor"): BetterUIVendorSettings
---@overload fun(moduleName: "TradingHouse"): BetterUITradingHouseSettings
---@overload fun(moduleName: "Companions"): BetterUICompanionsSettings
---@overload fun(moduleName: "GeneralInterface"): BetterUIGeneralInterfaceSettings
---@overload fun(moduleName: "Nameplates"): BetterUINameplatesSettings
---@overload fun(moduleName: "ResourceOrbFrames"): BetterUIResourceOrbFramesSettings
---@overload fun(moduleName: "CIM"): BetterUICIMSettings
---@overload fun(moduleName: "Writs"): BetterUIWritsSettings
---@param moduleName ModuleName|string Module name key
---@return BetterUIModuleSettings settings The module settings table (always non-nil)
function BETTERUI.EnsureModuleSettings(moduleName)
    if not BETTERUI.Settings then
        BETTERUI.Settings = {}
    end
    if not BETTERUI.Settings.Modules then
        BETTERUI.Settings.Modules = {}
    end
    if type(BETTERUI.Settings.Modules[moduleName]) ~= "table" then
        BETTERUI.Settings.Modules[moduleName] = {}
    end
    return BETTERUI.Settings.Modules[moduleName]
end

local function ResolveSettingDefault(moduleName, key, fallback)
    local settingsApi = BETTERUI.CIM and BETTERUI.CIM.Settings
    if settingsApi and settingsApi.GetSettingDefault then
        local defaultValue = settingsApi.GetSettingDefault(moduleName, key, fallback)
        if defaultValue ~= nil then
            return defaultValue
        end
    end

    local defaultsApi = BETTERUI.Defaults
    if defaultsApi and defaultsApi.GetDefault then
        local defaultValue = defaultsApi.GetDefault(moduleName, key)
        if defaultValue ~= nil then
            return defaultValue
        end
    end

    return fallback
end

---@overload fun(moduleName: "Inventory", key: BetterUIInventorySettingKey, default: BetterUIInventorySettingValue|nil): BetterUIInventorySettingValue|nil
---@overload fun(moduleName: "Banking", key: BetterUIBankingSettingKey, default: BetterUIBankingSettingValue|nil): BetterUIBankingSettingValue|nil
---@overload fun(moduleName: "Vendor", key: BetterUIVendorSettingKey, default: BetterUIVendorSettingValue|nil): BetterUIVendorSettingValue|nil
---@overload fun(moduleName: "TradingHouse", key: BetterUITradingHouseSettingKey, default: BetterUITradingHouseSettingValue|nil): BetterUITradingHouseSettingValue|nil
---@overload fun(moduleName: "Companions", key: BetterUICompanionsSettingKey, default: BetterUICompanionsSettingValue|nil): BetterUICompanionsSettingValue|nil
---@overload fun(moduleName: "GeneralInterface", key: BetterUIGeneralInterfaceSettingKey, default: BetterUIGeneralInterfaceSettingValue|nil): BetterUIGeneralInterfaceSettingValue|nil
---@overload fun(moduleName: "Nameplates", key: BetterUINameplatesSettingKey, default: BetterUINameplatesSettingValue|nil): BetterUINameplatesSettingValue|nil
---@overload fun(moduleName: "ResourceOrbFrames", key: BetterUIResourceOrbFramesSettingKey, default: BetterUIResourceOrbFramesSettingValue|nil): BetterUIResourceOrbFramesSettingValue|nil
---@overload fun(moduleName: "CIM", key: BetterUICIMSettingKey, default: BetterUICIMSettingValue|nil): BetterUICIMSettingValue|nil
---@overload fun(moduleName: "Writs", key: BetterUIWritsSettingKey, default: BetterUIWritsSettingValue|nil): BetterUIWritsSettingValue|nil
---@param moduleName ModuleName|string Module name key
---@param key BetterUIModuleSettingKey|string Setting key within the module
---@param default BetterUIModuleSettingValue|nil Fallback value if the setting is nil
---@return BetterUIModuleSettingValue|nil value The setting value, or default
function BETTERUI.GetSetting(moduleName, key, default)
    local settings = BETTERUI.GetModuleSettings(moduleName)
    if settings[key] ~= nil then
        return settings[key]
    end
    return default
end

---@overload fun(moduleName: "Inventory", key: BetterUIInventorySettingKey, value: BetterUIInventorySettingValue): boolean
---@overload fun(moduleName: "Banking", key: BetterUIBankingSettingKey, value: BetterUIBankingSettingValue): boolean
---@overload fun(moduleName: "Vendor", key: BetterUIVendorSettingKey, value: BetterUIVendorSettingValue): boolean
---@overload fun(moduleName: "TradingHouse", key: BetterUITradingHouseSettingKey, value: BetterUITradingHouseSettingValue): boolean
---@overload fun(moduleName: "Companions", key: BetterUICompanionsSettingKey, value: BetterUICompanionsSettingValue): boolean
---@overload fun(moduleName: "GeneralInterface", key: BetterUIGeneralInterfaceSettingKey, value: BetterUIGeneralInterfaceSettingValue): boolean
---@overload fun(moduleName: "Nameplates", key: BetterUINameplatesSettingKey, value: BetterUINameplatesSettingValue): boolean
---@overload fun(moduleName: "ResourceOrbFrames", key: BetterUIResourceOrbFramesSettingKey, value: BetterUIResourceOrbFramesSettingValue): boolean
---@overload fun(moduleName: "CIM", key: BetterUICIMSettingKey, value: BetterUICIMSettingValue): boolean
---@overload fun(moduleName: "Writs", key: BetterUIWritsSettingKey, value: BetterUIWritsSettingValue): boolean
---@param moduleName ModuleName|string Module name key
---@param key BetterUIModuleSettingKey|string Setting key to write (must not be nil)
---@param value BetterUIModuleSettingValue Value to store
---@return boolean success True when the value was written
function BETTERUI.SetSetting(moduleName, key, value)
    if type(moduleName) ~= "string" or moduleName == "" or key == nil then
        return false
    end

    local settings = BETTERUI.EnsureModuleSettings(moduleName)
    settings[key] = value

    if CALLBACK_MANAGER and CALLBACK_MANAGER.FireCallbacks then
        CALLBACK_MANAGER:FireCallbacks("BETTERUI_EVENT_SETTING_CHANGED", moduleName, key, value)
    end

    return true
end

--- Creates a factory for generating get/set functions for LAM controls.
--- Reduces boilerplate in Module options tables.
---
--- Usage:
---     local Accessor = BETTERUI.CreateSettingAccessors("MyModule")
---     getFunc, setFunc = Accessor("mySettingKey", defaultValue)
---
function BETTERUI.CreateSettingAccessors(moduleName, callback)
    return function(key, default)
        local getFunc = function()
            return BETTERUI.GetSetting(moduleName, key, default)
        end

        local setFunc = function(value)
            local success = BETTERUI.SetSetting(moduleName, key, value)
            if success and callback then callback() end
            return success
        end

        return getFunc, setFunc
    end
end

--- Creates a factory for generating get/set functions for COLOR LAM controls.
--- Automatically unpacks table {r,g,b,a} for getFunc and packs for setFunc.
---
function BETTERUI.CreateColorSettingAccessors(moduleName, callback)
    local baseFactory = BETTERUI.CreateSettingAccessors(moduleName, callback)

    return function(key, default)
        local baseGet, baseSet = baseFactory(key, default)

        local getFunc = function()
            local col = baseGet()
            if type(col) == "table" then
                return col[1], col[2], col[3], col[4] or 1
            end
            return 1, 1, 1, 1 -- Fallback
        end

        local setFunc = function(r, g, b, a)
            baseSet({r, g, b, a})
        end

        return getFunc, setFunc
    end
end

--- Clamps a value to an integer within [minValue, maxValue], falling back if non-numeric.
--- Shared utility to eliminate duplication across CIM, Nameplates, and ResourceOrbFrames settings.
function BETTERUI.ClampInteger(value, minValue, maxValue, fallback)
    local numeric = tonumber(value)
    if not numeric then
        return fallback
    end

    local rounded = math.floor(numeric + 0.5)
    if rounded < minValue then
        return minValue
    end
    if rounded > maxValue then
        return maxValue
    end
    return rounded
end

--- Clamps a numeric value within [minValue, maxValue] without rounding, falling back if non-numeric.
function BETTERUI.ClampNumber(value, minValue, maxValue, fallback)
    local numeric = tonumber(value)
    if not numeric then
        return fallback
    end
    if numeric < minValue then
        return minValue
    end
    if numeric > maxValue then
        return maxValue
    end
    return numeric
end

--- Deep-copies an RGBA color table {r, g, b, a}, falling back if value is not a table.
function BETTERUI.CloneColor(value, fallback)
    local source = value
    if type(source) ~= "table" then
        source = fallback
    end
    if type(source) ~= "table" then
        return { 1, 1, 1, 1 }
    end
    return {
        source[1] or 1,
        source[2] or 1,
        source[3] or 1,
        source[4] or 1,
    }
end

--- Wires standard font aliases and GetSetting/SetSetting accessors onto a module namespace.
--- Eliminates identical boilerplate across Banking, Inventory, and Vendor Module.lua files.
---
--- Usage (in Module.lua):
---   BETTERUI.CIM.RegisterModuleAccessors("Banking")
---
local function ResolveModuleRegistrationScope(moduleOrNamespace, moduleName)
    if type(moduleOrNamespace) == "table" then
        return moduleOrNamespace, moduleName
    end
    if type(moduleOrNamespace) == "string" then
        return BETTERUI[moduleOrNamespace], moduleOrNamespace
    end
    return nil, moduleName
end

local function ApplyModuleSharedSettingsStatics(ns)
    ns.FONT_CHOICES = BETTERUI.CIM.Font.CHOICES
    ns.FONT_VALUES = BETTERUI.CIM.Font.VALUES
    ns.FONTSTYLE_CHOICES = BETTERUI.CIM.Font.STYLE_CHOICES
    ns.FONTSTYLE_VALUES = BETTERUI.CIM.Font.STYLE_VALUES
    ns.DEFAULTS = BETTERUI.CIM.Font.DEFAULTS
end

function BETTERUI.CIM.ApplyModuleSharedSettingsStatics(moduleOrNamespace, moduleName)
    local ns, resolvedModuleName = ResolveModuleRegistrationScope(moduleOrNamespace, moduleName)
    if not ns or type(resolvedModuleName) ~= "string" or resolvedModuleName == "" then
        return false
    end

    assert(BETTERUI.CIM.Font,
        "BetterUI: CIM.Font must load before module settings statics are applied for " .. resolvedModuleName)

    ApplyModuleSharedSettingsStatics(ns)
    return true
end

function BETTERUI.CIM.RegisterModuleAccessors(moduleOrNamespace, moduleName)
    local ns, resolvedModuleName = ResolveModuleRegistrationScope(moduleOrNamespace, moduleName)
    if not ns or type(resolvedModuleName) ~= "string" or resolvedModuleName == "" then
        return false
    end

    if ns._sharedAccessorsRegistered == true then
        return true
    end

    BETTERUI.CIM.ApplyModuleSharedSettingsStatics(ns, resolvedModuleName)

    -- Font descriptor closures
    local descriptors = BETTERUI.CIM.Font.CreateModuleDescriptors(resolvedModuleName)
    ns.GetNameFontDescriptor = descriptors.name
    ns.GetColumnFontDescriptor = descriptors.column

    -- Settings accessors
    ns.GetSetting = function(key)
        if key == nil then return nil end
        local defaultValue = ResolveSettingDefault(resolvedModuleName, key, nil)
        return BETTERUI.GetSetting(resolvedModuleName, key, defaultValue)
    end

    ns.SetSetting = function(key, value)
        return BETTERUI.SetSetting(resolvedModuleName, key, value)
    end

    ns._sharedAccessorsRegistered = true
    return true
end

function BETTERUI.CIM.TryRegisterModulePanel(moduleOrNamespace, moduleName, panelId, panelLabel)
    local ns, resolvedModuleName = ResolveModuleRegistrationScope(moduleOrNamespace, moduleName)
    if not ns or type(resolvedModuleName) ~= "string" or resolvedModuleName == "" then
        return false
    end

    if ns._panelRegistered == true then
        return true
    end

    local settings = ns.Settings
    local registerPanel = settings and settings.RegisterPanel
    if type(registerPanel) ~= "function" then
        if BETTERUI.Debug then
            BETTERUI.Debug(string.format("[%s] Settings panel registration seam unavailable", resolvedModuleName))
        end
        return false
    end

    local ok, err = pcall(registerPanel, panelId, panelLabel)
    if ok then
        ns._panelRegistered = true
        return true
    end

    if BETTERUI.Debug then
        BETTERUI.Debug(string.format("[%s] Settings panel registration failed: %s", resolvedModuleName, tostring(err)))
    end
    return false
end
