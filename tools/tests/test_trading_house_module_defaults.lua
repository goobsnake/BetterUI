--[[
File: tools/tests/test_trading_house_module_defaults.lua
Purpose: Regression tests for Trading House module default initialization.
Usage:
  lua tools/tests/test_trading_house_module_defaults.lua
]]

BETTERUI = {
    TradingHouse = {},
    CIM = {},
}

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

BETTERUI.CIM.InitModuleDefaults = function(_, opts, _, fallbackDefaults)
    opts = opts or {}
    for key, value in pairs(fallbackDefaults or {}) do
        if opts[key] == nil then
            opts[key] = value
        end
    end
    return opts
end

BETTERUI.CIM.RegisterModuleAccessors = function(_)
end

dofile("Modules/TradingHouse/Module.lua")

print("[TradingHouse.InitModule m_enabled backfill]")

do
    local options = BETTERUI.TradingHouse.InitModule({})
    assert_eq(options.m_enabled, true, "missing m_enabled defaults to true")
end

do
    local options = BETTERUI.TradingHouse.InitModule({ m_enabled = false })
    assert_eq(options.m_enabled, false, "explicit false is preserved")
end

do
    local options = BETTERUI.TradingHouse.InitModule({ m_enabled = true })
    assert_eq(options.m_enabled, true, "explicit true is preserved")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
