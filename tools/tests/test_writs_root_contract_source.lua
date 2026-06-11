--[[
File: tools/tests/test_writs_root_contract_source.lua
Purpose: Guards the Writs module root so it matches the standard BetterUI
         module contract surface and verifies runtime lifecycle behavior.
Usage:
  lua tools/tests/test_writs_root_contract_source.lua
]]

if false then
    dofile("Modules/Writs/Module.lua")
end

local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local function assert_contains(haystack, needle, label)
    if not haystack:find(needle, 1, true) then
        error(label .. "\nMissing: " .. needle)
    end
end

local function assert_true(value, label)
    if not value then
        error(label)
    end
end

local function assert_eq(actual, expected, label)
    if actual ~= expected then
        error(string.format("%s\nExpected: %s\nActual: %s", label, tostring(expected), tostring(actual)))
    end
end

print("test_writs_root_contract_source")

local moduleSource = read_file("Modules/Writs/Module.lua")
local typesSource = read_file("Modules/CIM/Core/Data/Types.lua")

assert_contains(moduleSource, "---@type BetterUIModuleRoot", "Writs root declares the standard module-root type")
assert_contains(moduleSource, "local Writs = BETTERUI.Writs", "Writs root binds a canonical local module handle")
assert_contains(moduleSource, "Writs.ROOT_CONTRACT = {", "Writs root declares a root contract")
assert_contains(moduleSource, 'name = "Writs"', "Writs root contract uses the canonical module identity")
assert_contains(moduleSource, "local function ApplyWritsDefaults(m_options)",
    "Writs root owns a local defaults adapter")
assert_contains(moduleSource, 'function Writs.InitModule(m_options)', "Writs root exposes the standard InitModule hook")
assert_contains(moduleSource, 'GetModuleDefaults("Writs")',
    "Writs InitModule delegates to DefaultsRegistry")
assert_contains(moduleSource, 'ApplyModuleDefaults("Writs", m_options)',
    "Writs InitModule uses DefaultsRegistry directly")
if moduleSource:find('RegisterModuleAccessors%("Writs"%)') then
    error("Writs root should not register CIM accessors directly anymore")
end
if moduleSource:find('BETTERUI%.CIM%.InitModuleDefaults%("Writs"') then
    error("Writs InitModule should not use the CIM defaults helper anymore")
end
assert_contains(moduleSource, 'function Writs.Setup()', "Writs root exposes the standard Setup hook")
assert_contains(typesSource, '---| "Writs"', "ModuleName type includes the canonical Writs identity")

local EVENT_ENTER = 101
local EVENT_EXIT = 102
local EVENT_CRAFTED = 103
EVENT_CRAFTING_STATION_INTERACT = EVENT_ENTER
EVENT_END_CRAFTING_STATION_INTERACT = EVENT_EXIT
EVENT_CRAFT_COMPLETED = EVENT_CRAFTED

local safeExecuteContexts = {}
local registeredEvents = {}
local hidePanelCalls = 0
local shownCraftType = nil
local cacheControlsCalls = 0
local moduleEnabled = true
local createdWindowName = nil
local createdVirtualControlName = nil
local panelHiddenValue = nil
local applyDefaultsCalls = 0
local getDefaultsCalls = 0

BETTERUI = {
    name = "BetterUI",
    Writs = {
        CacheControls = function()
            cacheControlsCalls = cacheControlsCalls + 1
        end,
        ShowForCraftType = function(craftType)
            shownCraftType = craftType
        end,
        HidePanel = function()
            hidePanelCalls = hidePanelCalls + 1
        end,
    },
    CIM = {
        ARCHETYPES = {
            THIN_ENTRYPOINT = "thin-entrypoint",
        },
        SafeExecute = function(context, fn, ...)
            safeExecuteContexts[#safeExecuteContexts + 1] = context
            fn(...)
            return true, nil
        end,
        EventRegistry = {
            Register = function(_, namespace, eventCode, callback)
                EVENT_MANAGER:RegisterForEvent(namespace, eventCode, callback)
                return true
            end,
        },
    },
    Defaults = {
        ApplyModuleDefaults = function(moduleName, options)
            applyDefaultsCalls = applyDefaultsCalls + 1
            assert_eq(moduleName, "Writs", "InitModule applies defaults for Writs")
            options.applyPath = "apply"
            return options
        end,
        GetModuleDefaults = function()
            getDefaultsCalls = getDefaultsCalls + 1
            return {
                existing = "default",
                fallbackOnly = "from_fallback_defaults",
            }
        end,
    },
    WindowManager = {
        CreateTopLevelWindow = function(_, name)
            createdWindowName = name
            return { name = name }
        end,
        CreateControlFromVirtual = function(_, name)
            createdVirtualControlName = name
            return {
                SetHidden = function(_, value)
                    panelHiddenValue = value
                end,
            }
        end,
    },
}

function BETTERUI.GetModuleEnabled(moduleName)
    assert_eq(moduleName, "Writs", "module-enabled checks target the Writs module")
    return moduleEnabled
end

EVENT_MANAGER = {}
function EVENT_MANAGER:RegisterForEvent(name, eventCode, callback)
    registeredEvents[name .. ":" .. tostring(eventCode)] = callback
end

dofile("Modules/Writs/Module.lua")
local Writs = BETTERUI.Writs

assert_eq(Writs.ARCHETYPE, "thin-entrypoint", "Writs root uses thin-entrypoint archetype")
assert_eq(Writs.ROOT_CONTRACT.name, "Writs", "Writs root contract keeps canonical name")
assert_eq(Writs.ROOT_CONTRACT.archetype, "thin-entrypoint", "Writs root contract mirrors archetype")
assert_eq(Writs.ROOT_CONTRACT.init, true, "Writs root contract advertises init support")
assert_eq(Writs.ROOT_CONTRACT.setup, true, "Writs root contract advertises setup support")
assert_true(type(Writs.InitModule) == "function", "Writs root exposes InitModule")
assert_true(type(Writs.Setup) == "function", "Writs root exposes Setup")

local initWithApply = Writs.InitModule({ existing = "keep" })
assert_eq(applyDefaultsCalls, 1, "InitModule uses ApplyModuleDefaults when available")
assert_eq(getDefaultsCalls, 0, "InitModule does not touch GetModuleDefaults when apply helper exists")
assert_eq(initWithApply.existing, "keep", "InitModule preserves provided option values")
assert_eq(initWithApply.applyPath, "apply", "InitModule returns ApplyModuleDefaults result")

BETTERUI.Defaults.ApplyModuleDefaults = nil
local initWithFallback = Writs.InitModule({ existing = "keep" })
assert_eq(getDefaultsCalls, 1, "InitModule falls back to GetModuleDefaults when apply helper is missing")
assert_eq(initWithFallback.existing, "keep", "fallback defaults do not overwrite explicit options")
assert_eq(initWithFallback.fallbackOnly, "from_fallback_defaults", "fallback defaults fill missing options")

Writs.Setup()
assert_eq(createdWindowName, "BETTERUI_Writs_TLW", "Setup creates the writs top-level window")
assert_eq(createdVirtualControlName, "BETTERUI_WritsPanel", "Setup creates the writ panel virtual control")
assert_eq(cacheControlsCalls, 1, "Setup caches writ panel controls")
assert_eq(panelHiddenValue, true, "Setup hides the panel by default")
assert_true(type(registeredEvents["BetterUI_Writs:" .. tostring(EVENT_ENTER)]) == "function",
    "Setup registers the craft-station enter handler")
assert_true(type(registeredEvents["BetterUI_Writs:" .. tostring(EVENT_EXIT)]) == "function",
    "Setup registers the craft-station exit handler")
assert_true(type(registeredEvents["BetterUI_Writs:" .. tostring(EVENT_CRAFTED)]) == "function",
    "Setup registers the craft-completed handler")

moduleEnabled = true
safeExecuteContexts = {}
shownCraftType = nil
registeredEvents["BetterUI_Writs:" .. tostring(EVENT_ENTER)](nil, tostring(7))
assert_eq(safeExecuteContexts[1], "Writs:OnCraftStation", "craft-station enter executes via SafeExecute")
assert_eq(shownCraftType, 7, "craft-station enter forwards a numeric craft id")

moduleEnabled = false
safeExecuteContexts = {}
shownCraftType = nil
registeredEvents["BetterUI_Writs:" .. tostring(EVENT_ENTER)](nil, tostring(7))
assert_eq(#safeExecuteContexts, 0, "disabled Writs module ignores craft-station enter events")
assert_eq(shownCraftType, nil, "disabled Writs module does not call ShowForCraftType")

moduleEnabled = true
safeExecuteContexts = {}
registeredEvents["BetterUI_Writs:" .. tostring(EVENT_CRAFTED)](nil, tostring(6))
assert_eq(safeExecuteContexts[1], "Writs:OnCraftItem", "craft completion executes via SafeExecute")
assert_eq(shownCraftType, 6, "craft completion forwards the crafting type")

safeExecuteContexts = {}
hidePanelCalls = 0
registeredEvents["BetterUI_Writs:" .. tostring(EVENT_EXIT)](nil)
assert_eq(safeExecuteContexts[1], "Writs:OnCloseCraftStation", "craft-station exit executes via SafeExecute")
assert_eq(hidePanelCalls, 1, "craft-station exit hides the writ panel")

print("  OK")
