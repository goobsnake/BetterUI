--[[
File: tools/tests/test_settings_panel_registration.lua
Purpose: Regression tests for centralized settings panel registration helpers.
Usage: lua tools/tests/test_settings_panel_registration.lua
]]

local registeredPanels = {}
local registeredOptions = {}
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

local options = {
    { type = "submenu", name = "Zulu", controls = {} },
    { type = "submenu", name = "Alpha", controls = {} },
}

BETTERUI.CIM.Settings.RegisterModulePanel("General", { name = "General Interface" }, options)

assert_equal("BETTERUI_General", registeredPanels[1].id, "register helper prefixes panel id")
assert_equal("BETTERUI_General", registeredOptions[1].id, "options registration reuses normalized panel id")
assert_equal("Alpha", registeredOptions[1].data[1].name, "top-level submenu order is centralized before registration")
assert_equal("Zulu", registeredOptions[1].data[2].name, "later submenu remains after alphabetical sort")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
