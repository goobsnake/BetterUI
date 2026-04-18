--[[
File: tools/tests/test_settings_panel_registration.lua
Purpose: Regression tests for centralized settings panel registration helpers.
Usage: lua tools/tests/test_settings_panel_registration.lua
]]

local registeredPanels = {}
local registeredOptions = {}
local debugMessages = {}
local passed = 0
local failed = 0

LibAddonMenu2 = {
    RegisterAddonPanel = function(_, panelId, panelData)
        registeredPanels[#registeredPanels + 1] = {
            id = panelId,
            data = panelData,
        }
    end,
    RegisterOptionControls = function(_, panelId, optionsData)
        registeredOptions[#registeredOptions + 1] = {
            id = panelId,
            data = optionsData,
        }
    end,
}

function zo_strlower(value)
    return string.lower(value)
end

BETTERUI = {
    CIM = {
        Settings = {},
    },
}

function BETTERUI.Debug(message)
    debugMessages[#debugMessages + 1] = message
end

local function assert_equal(expected, actual, message)
    if expected == actual then
        passed = passed + 1
        print("  [OK] " .. message)
    else
        failed = failed + 1
        print("  [X] " .. message)
        print("    Expected: " .. tostring(expected))
        print("    Actual:   " .. tostring(actual))
    end
end

print("\n=== Settings Panel Registration Tests ===\n")

dofile("Modules/CIM/Core/Settings/SettingsFactory.lua")
dofile("Modules/CIM/Core/Settings/SettingsAccessor.lua")

local options = {
    { type = "submenu", name = "Zulu", controls = {} },
    { type = "submenu", name = "Alpha", controls = {} },
}

BETTERUI.CIM.Settings.RegisterModulePanel("General", { name = "General Interface" }, options)

assert_equal("BETTERUI_General", registeredPanels[1].id, "register helper prefixes panel id")
assert_equal("BETTERUI_General", registeredOptions[1].id, "options registration reuses normalized panel id")
assert_equal("Alpha", registeredOptions[1].data[1].name, "top-level submenu order is centralized before registration")
assert_equal("Zulu", registeredOptions[1].data[2].name, "later submenu remains after alphabetical sort")

local seamRegisterCalls = 0
local lifecycleModule = {
    Settings = {
        RegisterPanel = function(mId, moduleName)
            seamRegisterCalls = seamRegisterCalls + 1
            BETTERUI.CIM.Settings.RegisterModulePanel(mId, { name = moduleName }, {})
        end,
    },
}

assert_equal(true, BETTERUI.CIM.TryRegisterModulePanel(lifecycleModule, "LifecycleModule", "Lifecycle", "Lifecycle"),
    "lifecycle-safe helper returns true when panel seam succeeds")
assert_equal(true, BETTERUI.CIM.TryRegisterModulePanel(lifecycleModule, "LifecycleModule", "Lifecycle", "Lifecycle"),
    "lifecycle-safe helper is idempotent for repeated setup calls")
assert_equal(1, seamRegisterCalls, "settings seam is invoked only once for repeated setup calls")
assert_equal("BETTERUI_Lifecycle", registeredPanels[2].id, "lifecycle-safe helper routes through normalized panel registration")
assert_equal(true, lifecycleModule._panelRegistered, "lifecycle-safe helper marks panel registration state")

assert_equal(false, BETTERUI.CIM.TryRegisterModulePanel({}, "MissingSeamModule", "Missing", "Missing"),
    "lifecycle-safe helper returns false when module settings seam is unavailable")
assert_equal(1, #debugMessages, "missing seam emits a single debug trace")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
