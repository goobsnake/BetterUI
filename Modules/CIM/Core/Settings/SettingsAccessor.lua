--[[
File: Modules/CIM/Core/Settings/SettingsAccessor.lua
Purpose: Provides safe module settings access with automatic nil-checking.
         Eliminates repetitive nil checks when accessing BETTERUI.Settings.Modules.
]]

if not BETTERUI then BETTERUI = {} end

---@alias BetterUISettingsObserver fun()

local function CloneSettingsValue(value)
    if type(value) ~= "table" then
        return value
    end

    local clone = {}
    for key, item in pairs(value) do
        clone[key] = CloneSettingsValue(item)
    end
    return clone
end

local function DescribeSettingsValue(value, depth)
    local valueType = type(value)
    if valueType == "nil" or valueType == "boolean" or valueType == "number" then
        return tostring(value)
    end
    if valueType == "string" then
        if #value > 160 then
            return value:sub(1, 157) .. "..."
        end
        return value
    end
    if valueType == "function" then
        return "<function>"
    end
    if valueType ~= "table" then
        return "<" .. valueType .. ">"
    end
    depth = depth or 0
    if depth >= 2 then
        return "<table>"
    end
    local parts = {}
    local count = 0
    for key, item in pairs(value) do
        count = count + 1
        if count > 6 then
            parts[#parts + 1] = "..."
            break
        end
        parts[#parts + 1] = tostring(key) .. "=" .. DescribeSettingsValue(item, depth + 1)
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

local function TraceSettingAccess(event, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    L.TraceEvent(L.CATEGORY.SETTINGS, event, phase, data or {}, L.LEVEL.INFO)
end

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
---@param moduleName ModuleName Module name key
---@param defaults BetterUIModuleSettings|nil Fallback table if module settings are absent
---@return BetterUIModuleSettings settings A detached settings snapshot, or defaults
function BETTERUI.GetModuleSettings(moduleName, defaults)
    if BETTERUI.Settings and BETTERUI.Settings.Modules and type(BETTERUI.Settings.Modules[moduleName]) == "table" then
        return CloneSettingsValue(BETTERUI.Settings.Modules[moduleName])
    end
    return CloneSettingsValue(defaults or {})
end

---@param moduleName ModuleName Module name key
---@param defaults BetterUIModuleSettings|nil Fallback table if module settings are absent
---@return BetterUIModuleSettings settings The live persisted settings table (created when missing)
function BETTERUI.GetModuleSettingsLive(moduleName, defaults)
    if BETTERUI.Settings and BETTERUI.Settings.Modules and BETTERUI.Settings.Modules[moduleName] then
        return BETTERUI.Settings.Modules[moduleName]
    end

    if not BETTERUI.Settings then
        BETTERUI.Settings = {}
    end
    if not BETTERUI.Settings.Modules then
        BETTERUI.Settings.Modules = {}
    end

    local liveSettings = {}
    BETTERUI.Settings.Modules[moduleName] = liveSettings
    TraceSettingAccess("settings.module", "created", {
        module = moduleName,
        source = "GetModuleSettingsLive",
        hadDefaults = type(defaults) == "table",
    })

    if type(defaults) == "table" then
        for key, value in pairs(defaults) do
            liveSettings[key] = CloneSettingsValue(value)
        end
        TraceSettingAccess("settings.module", "defaults_applied", {
            module = moduleName,
            source = "GetModuleSettingsLive",
        })
    end

    return liveSettings
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
---@param moduleName ModuleName Module name key
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
        TraceSettingAccess("settings.module", "created", {
            module = moduleName,
            source = "EnsureModuleSettings",
        })
    end
    return BETTERUI.Settings.Modules[moduleName]
end

---@param moduleName ModuleName Module name key
---@param key BetterUIModuleSettingKey Setting key within the module
---@param fallback BetterUIModuleSettingValue|nil Fallback value if no default is available
---@return BetterUIModuleSettingValue|nil resolvedValue
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

local function TraceTooltipFeatureSetting(moduleName, key, oldValue, newValue, source)
    if moduleName ~= "CIM" then return end
    if key ~= "enableTooltipEnhancements" and key ~= "tooltipSize" and key ~= "rhScrollSpeed" then return end

    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end

    local effectiveOldValue = oldValue
    if effectiveOldValue == nil then
        effectiveOldValue = ResolveSettingDefault(moduleName, key, nil)
    end

    local payload = {
        module = moduleName,
        key = tostring(key),
        source = source or "SetSetting",
        oldValue = DescribeSettingsValue(effectiveOldValue),
        newValue = DescribeSettingsValue(newValue),
        changed = effectiveOldValue ~= newValue,
    }

    if key == "enableTooltipEnhancements" then
        payload.feature = "tooltipEnhancements"
        payload.oldEnabled = effectiveOldValue ~= false
        payload.enabled = newValue ~= false
        payload.effects = newValue ~= false
            and "enhancedFonts,equippedRefresh,duplicateCleanup"
            or "stockFonts,stockRelayout,enhancementCleanup"
    elseif key == "tooltipSize" then
        payload.feature = "tooltipFontSize"
        payload.size = tonumber(newValue)
        payload.effects = "tooltipFontScale"
    elseif key == "rhScrollSpeed" then
        payload.feature = "tooltipScrollSpeed"
        payload.speed = tonumber(newValue)
        payload.effects = "tooltipMouseWheel"
    end

    local categories = L.CATEGORY or {}
    local levels = L.LEVEL or {}
    L.TraceEvent(categories.GENERAL or categories.SETTINGS, "general_interface.tooltip_feature", "setting_changed", payload, levels.INFO)
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
---@param moduleName ModuleName Module name key
---@param key BetterUIModuleSettingKey Setting key within the module
---@param default BetterUIModuleSettingValue|nil Fallback value if the setting is nil
---@return BetterUIModuleSettingValue|nil value A detached setting value, or default
function BETTERUI.GetSetting(moduleName, key, default)
    -- Read only the requested key and clone table-typed values so callers do
    -- not mutate persisted settings without routing through SetSetting.
    local modules = BETTERUI.Settings and BETTERUI.Settings.Modules
    local settings = modules and modules[moduleName]
    if settings and settings[key] ~= nil then
        TraceSettingAccess("settings.value", "read", {
            module = moduleName,
            key = tostring(key),
            source = "saved",
            value = DescribeSettingsValue(settings[key]),
        })
        return CloneSettingsValue(settings[key])
    end
    local resolvedDefault = ResolveSettingDefault(moduleName, key, default)
    TraceSettingAccess("settings.value", "read", {
        module = moduleName,
        key = tostring(key),
        source = "default",
        value = DescribeSettingsValue(resolvedDefault),
    })
    return CloneSettingsValue(resolvedDefault)
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
---@param moduleName ModuleName Module name key
---@param key BetterUIModuleSettingKey Setting key to write
---@param value BetterUIModuleSettingValue Value to store
---@return boolean success True when the value was written
function BETTERUI.SetSetting(moduleName, key, value)
    if type(moduleName) ~= "string" or moduleName == "" or key == nil then
        TraceSettingAccess("settings.value", "write_rejected", {
            module = moduleName,
            key = key ~= nil and tostring(key) or nil,
            reason = "invalid_arguments",
            newValue = DescribeSettingsValue(value),
        })
        return false
    end

    local settings = BETTERUI.EnsureModuleSettings(moduleName)
    local oldValue = settings[key]
    TraceSettingAccess("settings.value", "write_before", {
        module = moduleName,
        key = tostring(key),
        oldValue = DescribeSettingsValue(oldValue),
        newValue = DescribeSettingsValue(value),
    })
    settings[key] = value

    if CALLBACK_MANAGER and CALLBACK_MANAGER.FireCallbacks then
        CALLBACK_MANAGER:FireCallbacks("BETTERUI_EVENT_SETTING_CHANGED", moduleName, key, value)
        TraceSettingAccess("settings.value", "callbacks_fired", {
            module = moduleName,
            key = tostring(key),
            callback = "BETTERUI_EVENT_SETTING_CHANGED",
            newValue = DescribeSettingsValue(value),
        })
    end

    TraceSettingAccess("settings.value", "write_after", {
        module = moduleName,
        key = tostring(key),
        oldValue = DescribeSettingsValue(oldValue),
        newValue = DescribeSettingsValue(settings[key]),
    })
    TraceTooltipFeatureSetting(moduleName, key, oldValue, settings[key], "SetSetting")
    return true
end

--- Creates a factory for generating get/set functions for LAM controls.
--- Reduces boilerplate in Module options tables.
---
--- Usage:
---     local Accessor = BETTERUI.CreateSettingAccessors("MyModule")
---     getFunc, setFunc = Accessor("mySettingKey", defaultValue)
---
---@overload fun(moduleName: "Inventory", callback: BetterUISettingsObserver|nil): fun(key: BetterUIInventorySettingKey, default: BetterUIInventorySettingValue|nil): (fun():BetterUIInventorySettingValue|nil), (fun(value: BetterUIInventorySettingValue): boolean)
---@overload fun(moduleName: "Banking", callback: BetterUISettingsObserver|nil): fun(key: BetterUIBankingSettingKey, default: BetterUIBankingSettingValue|nil): (fun():BetterUIBankingSettingValue|nil), (fun(value: BetterUIBankingSettingValue): boolean)
---@overload fun(moduleName: "Vendor", callback: BetterUISettingsObserver|nil): fun(key: BetterUIVendorSettingKey, default: BetterUIVendorSettingValue|nil): (fun():BetterUIVendorSettingValue|nil), (fun(value: BetterUIVendorSettingValue): boolean)
---@overload fun(moduleName: "TradingHouse", callback: BetterUISettingsObserver|nil): fun(key: BetterUITradingHouseSettingKey, default: BetterUITradingHouseSettingValue|nil): (fun():BetterUITradingHouseSettingValue|nil), (fun(value: BetterUITradingHouseSettingValue): boolean)
---@overload fun(moduleName: "Companions", callback: BetterUISettingsObserver|nil): fun(key: BetterUICompanionsSettingKey, default: BetterUICompanionsSettingValue|nil): (fun():BetterUICompanionsSettingValue|nil), (fun(value: BetterUICompanionsSettingValue): boolean)
---@overload fun(moduleName: "GeneralInterface", callback: BetterUISettingsObserver|nil): fun(key: BetterUIGeneralInterfaceSettingKey, default: BetterUIGeneralInterfaceSettingValue|nil): (fun():BetterUIGeneralInterfaceSettingValue|nil), (fun(value: BetterUIGeneralInterfaceSettingValue): boolean)
---@overload fun(moduleName: "Nameplates", callback: BetterUISettingsObserver|nil): fun(key: BetterUINameplatesSettingKey, default: BetterUINameplatesSettingValue|nil): (fun():BetterUINameplatesSettingValue|nil), (fun(value: BetterUINameplatesSettingValue): boolean)
---@overload fun(moduleName: "ResourceOrbFrames", callback: BetterUISettingsObserver|nil): fun(key: BetterUIResourceOrbFramesSettingKey, default: BetterUIResourceOrbFramesSettingValue|nil): (fun():BetterUIResourceOrbFramesSettingValue|nil), (fun(value: BetterUIResourceOrbFramesSettingValue): boolean)
---@overload fun(moduleName: "CIM", callback: BetterUISettingsObserver|nil): fun(key: BetterUICIMSettingKey, default: BetterUICIMSettingValue|nil): (fun():BetterUICIMSettingValue|nil), (fun(value: BetterUICIMSettingValue): boolean)
---@overload fun(moduleName: "Writs", callback: BetterUISettingsObserver|nil): fun(key: BetterUIWritsSettingKey, default: BetterUIWritsSettingValue|nil): (fun():BetterUIWritsSettingValue|nil), (fun(value: BetterUIWritsSettingValue): boolean)
---@param moduleName ModuleName Module name key
---@param callback BetterUISettingsObserver|nil Optional callback invoked after successful writes
function BETTERUI.CreateSettingAccessors(moduleName, callback)
    return function(key, default)
        ---@type fun():BetterUIModuleSettingValue|nil
        local getFunc = function()
            return BETTERUI.GetSetting(moduleName, key, default)
        end
        ---@type fun(value: BetterUIModuleSettingValue): boolean
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
---@overload fun(moduleName: "Inventory", callback: BetterUISettingsObserver|nil): fun(key: BetterUIInventorySettingKey, default: BetterUIInventorySettingValue|nil): (fun():number, number, number, number), (fun(number, number, number, number|nil): boolean)
---@overload fun(moduleName: "Banking", callback: BetterUISettingsObserver|nil): fun(key: BetterUIBankingSettingKey, default: BetterUIBankingSettingValue|nil): (fun():number, number, number, number), (fun(number, number, number, number|nil): boolean)
---@overload fun(moduleName: "Vendor", callback: BetterUISettingsObserver|nil): fun(key: BetterUIVendorSettingKey, default: BetterUIVendorSettingValue|nil): (fun():number, number, number, number), (fun(number, number, number, number|nil): boolean)
---@overload fun(moduleName: "TradingHouse", callback: BetterUISettingsObserver|nil): fun(key: BetterUITradingHouseSettingKey, default: BetterUITradingHouseSettingValue|nil): (fun():number, number, number, number), (fun(number, number, number, number|nil): boolean)
---@overload fun(moduleName: "Companions", callback: BetterUISettingsObserver|nil): fun(key: BetterUICompanionsSettingKey, default: BetterUICompanionsSettingValue|nil): (fun():number, number, number, number), (fun(number, number, number, number|nil): boolean)
---@overload fun(moduleName: "GeneralInterface", callback: BetterUISettingsObserver|nil): fun(key: BetterUIGeneralInterfaceSettingKey, default: BetterUIGeneralInterfaceSettingValue|nil): (fun():number, number, number, number), (fun(number, number, number, number|nil): boolean)
---@overload fun(moduleName: "Nameplates", callback: BetterUISettingsObserver|nil): fun(key: BetterUINameplatesSettingKey, default: BetterUINameplatesSettingValue|nil): (fun():number, number, number, number), (fun(number, number, number, number|nil): boolean)
---@overload fun(moduleName: "ResourceOrbFrames", callback: BetterUISettingsObserver|nil): fun(key: BetterUIResourceOrbFramesSettingKey, default: BetterUIResourceOrbFramesSettingValue|nil): (fun():number, number, number, number), (fun(number, number, number, number|nil): boolean)
---@overload fun(moduleName: "CIM", callback: BetterUISettingsObserver|nil): fun(key: BetterUICIMSettingKey, default: BetterUICIMSettingValue|nil): (fun():number, number, number, number), (fun(number, number, number, number|nil): boolean)
---@overload fun(moduleName: "Writs", callback: BetterUISettingsObserver|nil): fun(key: BetterUIWritsSettingKey, default: BetterUIWritsSettingValue|nil): (fun():number, number, number, number), (fun(number, number, number, number|nil): boolean)
---@param moduleName ModuleName
---@param callback BetterUISettingsObserver|nil
---@return fun(key: BetterUIModuleSettingKey, default: BetterUIModuleSettingValue|nil): (fun():number, number, number, number), (fun(r: number, g: number, b: number, a: number|nil): boolean)
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
            return baseSet({r, g, b, a})
        end

        return getFunc, setFunc
    end
end

--- Clamps a value to an integer within [minValue, maxValue], falling back if non-numeric.
--- Shared utility to eliminate duplication across CIM, Nameplates, and ResourceOrbFrames settings.
---@param value unknown
---@param minValue integer
---@param maxValue integer
---@param fallback integer
---@return integer
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
---@param value unknown
---@param minValue number
---@param maxValue number
---@param fallback number
---@return number
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
---@param value table|nil
---@param fallback table|nil
---@return number[]
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

---@param moduleOrNamespace table|string
---@param moduleName ModuleName
---@return boolean
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

---@param moduleOrNamespace table|string Module namespace or module name
---@param moduleName ModuleName
---@return boolean
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
        return BETTERUI.GetSetting(resolvedModuleName, key)
    end

    ns.SetSetting = function(key, value)
        return BETTERUI.SetSetting(resolvedModuleName, key, value)
    end

    ns._sharedAccessorsRegistered = true
    return true
end

---@param moduleOrNamespace table|string
---@param moduleName ModuleName
---@param panelId string|nil
---@param panelLabel string|nil
---@return boolean
---@return string|nil
function BETTERUI.CIM.TryRegisterModulePanel(moduleOrNamespace, moduleName, panelId, panelLabel)
    local ns, resolvedModuleName = ResolveModuleRegistrationScope(moduleOrNamespace, moduleName)
    if not ns or type(resolvedModuleName) ~= "string" or resolvedModuleName == "" then
        return false, "invalid_module_scope"
    end

    if ns._panelRegistered == true then
        return true
    end

    local settings = ns.Settings
    local registerPanel = settings and settings.RegisterPanel
    if type(registerPanel) ~= "function" then
        if BETTERUI.Log then
            BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SETTINGS, string.format("[%s] Settings panel registration seam unavailable", resolvedModuleName))
        end
        return false, "missing_register_panel"
    end

    local previousPanelName = BETTERUI.CIM.Settings._activeModulePanelName
    local previousPanelLabel = BETTERUI.CIM.Settings._activeModulePanelLabel
    BETTERUI.CIM.Settings._activeModulePanelName = resolvedModuleName
    BETTERUI.CIM.Settings._activeModulePanelLabel = panelLabel or resolvedModuleName
    local ok, panelResult, panelReason = pcall(registerPanel, panelId, panelLabel)
    BETTERUI.CIM.Settings._activeModulePanelName = previousPanelName
    BETTERUI.CIM.Settings._activeModulePanelLabel = previousPanelLabel
    if not ok then
        if BETTERUI.Log then
            BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SETTINGS, string.format("[%s] Settings panel registration failed: %s", resolvedModuleName, tostring(panelResult)))
        end
        return false, "register_panel_failed"
    end

    if panelResult == false then
        local reason = panelReason or "register_panel_failed"
        if BETTERUI.Log then
            BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SETTINGS, string.format("[%s] Settings panel registration rejected: %s", resolvedModuleName, tostring(reason)))
        end
        return false, reason
    end

    -- Legacy RegisterPanel seams may not return a status; preserve compatibility.
    ns._panelRegistered = true
    return true
end

---Setup-time wrapper around TryRegisterModulePanel that consolidates the shared
---module bootstrap boilerplate: records machine-readable registration diagnostics
---on the module namespace and debug-reports non-deferred failures.
---@param moduleOrNamespace table|string
---@param moduleName ModuleName
---@param panelId string|nil
---@param panelLabel string|nil
---@param moduleNameForLog string|nil Debug log tag override; defaults to moduleName.
---@return boolean panelOk
---@return string|nil panelReason
function BETTERUI.CIM.RegisterModulePanelWithLogging(moduleOrNamespace, moduleName, panelId, panelLabel, moduleNameForLog)
    local panelOk, panelReason = BETTERUI.CIM.TryRegisterModulePanel(moduleOrNamespace, moduleName, panelId, panelLabel)

    if type(moduleOrNamespace) == "table" then
        moduleOrNamespace._panelRegistrationReason = panelReason
        moduleOrNamespace._panelRegistrationDeferred = panelReason == "missing_register_panel"
    end

    if not panelOk and panelReason ~= nil and panelReason ~= "missing_register_panel" and BETTERUI.Log then
        BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SETTINGS, string.format("[%s] Settings panel registration reported: %s",
            tostring(moduleNameForLog or moduleName), tostring(panelReason)))
    end

    return panelOk, panelReason
end
