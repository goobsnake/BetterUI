--[[
File: tools/tests/test_trading_house_runtime_source.lua
Purpose: Guards the Trading House root/runtime split so TradingHouse.lua stays
         focused on lifecycle wiring while the core runtime helper owns scene
         ownership, keybinds, dialogs, and event routing.
Usage:
  lua tools/tests/test_trading_house_runtime_source.lua
]]

if false then
    dofile("Modules/TradingHouse/Core/TradingHouseRuntime.lua")
    dofile("Modules/TradingHouse/Core/TradingHouseRuntimeFlow.lua")
    dofile("Modules/TradingHouse/TradingHouse.lua")
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

local function assert_not_contains(haystack, needle, label)
    if haystack:find(needle, 1, true) then
        error(label .. "\nUnexpected: " .. needle)
    end
end

print("test_trading_house_runtime_source")

local entrySource = read_file("Modules/TradingHouse/TradingHouse.lua")
local runtimeSource = read_file("Modules/TradingHouse/Core/TradingHouseRuntime.lua")
local flowSource = read_file("Modules/TradingHouse/Core/TradingHouseRuntimeFlow.lua")
local manifestSource = read_file("BetterUI.txt")

assert_contains(runtimeSource, "function TH.RegisterSceneLifecycle(instance)",
    "Trading House runtime helper owns scene lifecycle registration")
assert_contains(runtimeSource, "function TH.BuildCoreKeybinds(thInstance)",
    "Trading House runtime helper owns core keybind construction")
assert_contains(runtimeSource, "function TH.BuildTabKeybinds(thInstance)",
    "Trading House runtime helper owns tab keybind construction")
assert_contains(flowSource, "function TH.RegisterCreateListingDialog()",
    "Trading House flow helper owns dialog registration")
assert_contains(flowSource, "function TH.RegisterEvents(eventManager)",
    "Trading House flow helper owns event registration")
assert_contains(flowSource, "function TH.OnOpenTradingHouse()",
    "Trading House flow helper owns open callback routing")
assert_contains(flowSource, "function TH.TakeOverNativeTradingHouse()",
    "Trading House flow helper owns native scene takeover")

assert_not_contains(entrySource, "local function RegisterCreateListingDialog(",
    "TradingHouse.lua no longer defines dialog registration locally")
assert_not_contains(entrySource, "local function RegisterTradingHouseSceneLifecycle(",
    "TradingHouse.lua no longer defines scene lifecycle locally")
assert_not_contains(entrySource, "local function RegisterTradingHouseEvents(",
    "TradingHouse.lua no longer defines event registration locally")
assert_not_contains(entrySource, "local function TakeOverNativeTradingHouse(",
    "TradingHouse.lua no longer defines native scene takeover locally")
assert_not_contains(entrySource, "local function BuildCoreKeybinds(",
    "TradingHouse.lua no longer defines keybind builders locally")
assert_contains(entrySource, "TH.RegisterCreateListingDialog()",
    "TradingHouse.lua delegates dialog registration to the runtime helper")
assert_contains(entrySource, "TH.BuildCoreKeybinds(TH.instance)",
    "TradingHouse.lua delegates core keybind construction to the runtime helper")
assert_contains(entrySource, "TH.BuildTabKeybinds(TH.instance)",
    "TradingHouse.lua delegates tab keybind construction to the runtime helper")
assert_contains(entrySource, "TH.TakeOverNativeTradingHouse()",
    "TradingHouse.lua delegates native scene takeover to the runtime helper")
assert_contains(entrySource, "TH.RegisterSceneLifecycle(TH.instance)",
    "TradingHouse.lua delegates scene lifecycle registration to the runtime helper")
assert_contains(entrySource, "TH.RegisterEvents(EVENT_MANAGER)",
    "TradingHouse.lua delegates event registration to the runtime helper")
assert_contains(manifestSource, "Modules\\TradingHouse\\Core\\TradingHouseRuntime.lua",
    "Addon manifest loads the new Trading House runtime helper")
assert_contains(manifestSource, "Modules\\TradingHouse\\Core\\TradingHouseRuntimeFlow.lua",
    "Addon manifest loads the new Trading House flow helper")

print("  OK")
