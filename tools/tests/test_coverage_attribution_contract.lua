--[[
File: tools/tests/test_coverage_attribution_contract.lua
Purpose: Behavioral smoke coverage for real module roots and bootstrap seams.
         This intentionally executes production module setup paths instead of
         crediting coverage by reading source files as plain text.
Usage:
  lua tools/tests/test_coverage_attribution_contract.lua
]]

local passed = 0
local failed = 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, label)
    assert_eq(value, true, label)
end

LibAddonMenu2 = {
    RegisterAddonPanel = function() end,
    RegisterOptionControls = function() end,
}

local eventManager = {
    handlers = {},
}

function eventManager:RegisterForEvent(name, eventCode, callback)
    self.handlers[name] = {
        eventCode = eventCode,
        callback = callback,
    }
end

function eventManager:UnregisterForEvent(name)
    self.handlers[name] = nil
end

function GetWindowManager()
    return {}
end

function GetEventManager()
    return eventManager
end

function GetString(value)
    return tostring(value)
end

EVENT_ADD_ON_LOADED = 1
EVENT_GAMEPAD_PREFERRED_MODE_CHANGED = 2

BETTERUI = nil
dofile("BetterUI.lua")

local registeredAccessors = {}
local registeredPanels = {}
local moduleDefaultsRequested = {}
local companionsInitCalls = 0
local tradingHouseInitCalls = 0

BETTERUI.Debug = function() end
BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.ApplyModuleSharedSettingsStatics = function(moduleNamespace, moduleName)
    moduleNamespace.GetSetting = function(_, key)
        if key == "enableCompanionEquipment" then
            return true
        end
        return true
    end
end
BETTERUI.CIM.RegisterModuleAccessors = function(moduleNamespace, moduleName)
    registeredAccessors[#registeredAccessors + 1] = moduleName
    moduleNamespace.GetSetting = moduleNamespace.GetSetting or function()
        return true
    end
end
BETTERUI.CIM.TryRegisterModulePanel = function(_, moduleScope, moduleId, panelLabel)
    registeredPanels[#registeredPanels + 1] = {
        scope = moduleScope,
        id = moduleId,
        label = panelLabel,
    }
    return true
end
BETTERUI.CIM.InitModuleDefaults = function(moduleName, options, defaults, fallbackDefaults)
    local resolved = options or {}
    moduleDefaultsRequested[#moduleDefaultsRequested + 1] = moduleName
    if type(defaults) == "table" then
        for key, value in pairs(defaults) do
            if resolved[key] == nil then
                resolved[key] = value
            end
        end
    end
    if type(fallbackDefaults) == "table" then
        for key, value in pairs(fallbackDefaults) do
            if resolved[key] == nil then
                resolved[key] = value
            end
        end
    end
    return resolved
end

BETTERUI.Defaults = {
    GetModuleDefaults = function(moduleName)
        moduleDefaultsRequested[#moduleDefaultsRequested + 1] = moduleName .. ":defaults"
        return {}
    end,
}

dofile("Modules/Companions/Module.lua")
dofile("Modules/TradingHouse/Module.lua")
dofile("Modules/ResourceOrbFrames/Module.lua")

BETTERUI.Companions.Init = function()
    companionsInitCalls = companionsInitCalls + 1
end

BETTERUI.TradingHouse.Init = function()
    tradingHouseInitCalls = tradingHouseInitCalls + 1
end

local companionsOptions = BETTERUI.ModuleOptions(BETTERUI.Companions, {}, "Companions")
local tradingHouseOptions = BETTERUI.ModuleOptions(BETTERUI.TradingHouse, {}, "TradingHouse")
local resourceOrbOptions = BETTERUI.ModuleOptions(BETTERUI.ResourceOrbFrames, {}, "ResourceOrbFrames")

assert_true(type(companionsOptions) == "table", "Companions root initializes through BETTERUI.ModuleOptions")
assert_true(type(tradingHouseOptions) == "table", "TradingHouse root initializes through BETTERUI.ModuleOptions")
assert_true(type(resourceOrbOptions) == "table", "ResourceOrbFrames root initializes through BETTERUI.ModuleOptions")

BETTERUI.Companions.Setup()
BETTERUI.TradingHouse.Setup()
BETTERUI.ResourceOrbFrames.Setup()

assert_eq(registeredAccessors[1], "Companions", "Companions setup registers module accessors")
assert_eq(registeredPanels[1].scope, "Companions", "Companions setup routes through shared panel registration")
assert_eq(companionsInitCalls, 1, "Companions setup delegates to the runtime init entrypoint")

assert_eq(registeredAccessors[2], "TradingHouse", "TradingHouse setup registers module accessors")
assert_eq(registeredPanels[2].scope, "TradingHouse", "TradingHouse setup routes through shared panel registration")
assert_eq(tradingHouseInitCalls, 1, "TradingHouse setup delegates to the runtime init entrypoint")

assert_eq(registeredAccessors[3], "ResourceOrbFrames", "ResourceOrbFrames setup registers module accessors")
assert_eq(registeredPanels[3].scope, "ResourceOrbFrames", "ResourceOrbFrames setup routes through shared panel registration")
assert_true(BETTERUI.ResourceOrbFrames._panelRegistrationReason == nil,
    "ResourceOrbFrames setup keeps panel registration in the successful shared state")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
