--[[
File: tools/tests/test_trading_house_boundary_annotations_source.lua
Purpose: Guards the Trading House boundary aliases so lifecycle and callback
         payloads stay explicitly typed after the runtime split.
Usage:
  lua tools/tests/test_trading_house_boundary_annotations_source.lua
]]

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

print("test_trading_house_boundary_annotations_source")

local runtimeSource = read_file("Modules/TradingHouse/Core/TradingHouseRuntime.lua")
local flowSource = read_file("Modules/TradingHouse/Core/TradingHouseRuntimeFlow.lua")

assert_contains(runtimeSource, "---@alias TradingHouseSceneLifecyclePayload",
    "Trading House runtime names its lifecycle payload")
assert_contains(runtimeSource, "---@alias TradingHouseSelectionPayload",
    "Trading House runtime names selection callback payloads")
assert_contains(runtimeSource, "local lifecyclePayload = {",
    "Trading House runtime registers a named lifecycle payload")
assert_contains(flowSource, "---@alias TradingHouseCreateListingDialogData",
    "Trading House runtime flow names dialog payloads")
assert_contains(flowSource, "---@alias TradingHouseResponsePayload",
    "Trading House runtime flow names response payloads")
assert_contains(flowSource, "local responsePayload = {",
    "Trading House runtime flow normalizes response callback payloads")

print("  OK")
