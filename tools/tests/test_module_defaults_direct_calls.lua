--[[
File: tools/tests/test_module_defaults_direct_calls.lua
Purpose: Regression tests for direct internal defaults seams.

Usage:
  lua tools/tests/test_module_defaults_direct_calls.lua
]]

BETTERUI = {
    CIM = {
        Font = {
            DEFAULTS = {
                nameFont = "DefaultName",
                nameFontSize = 24,
                nameFontStyle = "soft-shadow-thick",
                columnFont = "DefaultColumn",
                columnFontSize = 20,
                columnFontStyle = "soft-shadow-thick",
            },
        },
    },
    Defaults = {},
    GeneralInterface = {},
}

function BETTERUI.Debug(_)
end

function GetCVar(_)
    return "en"
end

function d(_)
end

local defaultsCallCount = 0
function BETTERUI.Defaults.ApplyModuleDefaults(moduleName, options)
    defaultsCallCount = defaultsCallCount + 1
    options = options or {}
    options.defaultsAppliedFor = moduleName
    options.showMarketPrice = false
    return options
end

BETTERUI.CIM.TryCall = function(name)
    error("Direct defaults seams should not use TryCall: " .. tostring(name))
end

local passed = 0
local failed = 0

local function assertEqual(expected, actual, message)
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

print("\n=== Module Defaults Direct Call Tests ===\n")

dofile("Modules/CIM/Core/Presentation/FontDefinitions.lua")
dofile("Modules/GeneralInterface/Module.lua")

do
    local options = BETTERUI.CIM.InitModuleDefaults("GeneralInterface", {}, BETTERUI.CIM.Font.DEFAULTS)
    assertEqual("GeneralInterface", options.defaultsAppliedFor, "InitModuleDefaults uses BETTERUI.Defaults.ApplyModuleDefaults directly")
end

do
    local options = BETTERUI.GeneralInterface.InitModule({})
    assertEqual("GeneralInterface", options.defaultsAppliedFor, "GeneralInterface.InitModule uses direct defaults seam")
    assertEqual(false, options.showMarketPrice, "GeneralInterface.InitModule preserves direct defaults result")
end

assertEqual(2, defaultsCallCount, "direct defaults seam invoked for both helpers")

print(string.format("\nPassed: %d  Failed: %d", passed, failed))
if failed > 0 then
    os.exit(1)
end
