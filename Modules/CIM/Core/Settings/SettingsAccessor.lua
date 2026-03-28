--[[
File: Modules/CIM/SettingsAccessor.lua
Purpose: Provides safe module settings access with automatic nil-checking.
         Eliminates repetitive nil checks when accessing BETTERUI.Settings.Modules.
]]

if not BETTERUI then BETTERUI = {} end

--- Gets settings for a module with automatic nil-safety.
function BETTERUI.GetModuleSettings(moduleName, defaults)
    if BETTERUI.Settings and BETTERUI.Settings.Modules and BETTERUI.Settings.Modules[moduleName] then
        return BETTERUI.Settings.Modules[moduleName]
    end
    return defaults or {}
end

--- Ensures the settings table exists for a module, creating it if necessary.
--- Unlike GetModuleSettings, the returned reference is persisted in BETTERUI.Settings.Modules,
--- so callers may write through it. Use this for mutation patterns; use GetModuleSettings for reads.
function BETTERUI.EnsureModuleSettings(moduleName)
    if not BETTERUI.Settings then return nil end
    if not BETTERUI.Settings.Modules then
        BETTERUI.Settings.Modules = {}
    end
    if type(BETTERUI.Settings.Modules[moduleName]) ~= "table" then
        BETTERUI.Settings.Modules[moduleName] = {}
    end
    return BETTERUI.Settings.Modules[moduleName]
end

--- Gets a specific setting value with fallback.
function BETTERUI.GetSetting(moduleName, key, default)
    local settings = BETTERUI.GetModuleSettings(moduleName)
    if settings[key] ~= nil then
        return settings[key]
    end
    return default
end

--- Sets a specific setting value and emits the standard setting-changed callback.
function BETTERUI.SetSetting(moduleName, key, value)
    if key == nil then return end
    if not BETTERUI.Settings or not BETTERUI.Settings.Modules then return end

    if not BETTERUI.Settings.Modules[moduleName] then
        BETTERUI.Settings.Modules[moduleName] = {}
    end

    BETTERUI.Settings.Modules[moduleName][key] = value

    if CALLBACK_MANAGER and CALLBACK_MANAGER.FireCallbacks then
        CALLBACK_MANAGER:FireCallbacks("BETTERUI_EVENT_SETTING_CHANGED", moduleName, key, value)
    end
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
            local settings = BETTERUI.Settings.Modules[moduleName]
            -- Nil check settings table
            if not settings then return default end
            -- Return valid value or default
            if settings[key] ~= nil then
                return settings[key]
            end
            return default
        end

        local setFunc = function(value)
            -- Use the unified SetSetting helper to ensure event emission
            BETTERUI.SetSetting(moduleName, key, value)

            -- Run callback if provided
            if callback then callback() end
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
function BETTERUI.CIM.RegisterModuleAccessors(moduleName)
    local ns = BETTERUI[moduleName]
    if not ns then return end

    -- Font aliases
    ns.FONT_CHOICES = BETTERUI.CIM.Font.CHOICES
    ns.FONT_VALUES = BETTERUI.CIM.Font.VALUES
    ns.FONTSTYLE_CHOICES = BETTERUI.CIM.Font.STYLE_CHOICES
    ns.FONTSTYLE_VALUES = BETTERUI.CIM.Font.STYLE_VALUES
    ns.DEFAULTS = BETTERUI.CIM.Font.DEFAULTS

    -- Font descriptor closures
    local descriptors = BETTERUI.CIM.Font.CreateModuleDescriptors(moduleName)
    ns.GetNameFontDescriptor = descriptors.name
    ns.GetColumnFontDescriptor = descriptors.column

    -- Settings accessors
    ns.GetSetting = function(key)
        if key == nil then return nil end
        local defaultValue = BETTERUI.Defaults and BETTERUI.Defaults.GetDefault and BETTERUI.Defaults.GetDefault(moduleName, key) or nil
        return BETTERUI.GetSetting(moduleName, key, defaultValue)
    end

    ns.SetSetting = function(key, value)
        BETTERUI.SetSetting(moduleName, key, value)
    end
end
