--[[
File: tools/tests/test_settings_accessor_source.lua
Purpose: Source-contract regression checks for the shared settings type surface.

Usage:
  lua tools/tests/test_settings_accessor_source.lua
]]

local passed = 0
local failed = 0

local function assert_true(value, label)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("Assertion failed: " .. label .. "\n")
    end
end

local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local typesSource = read_file("Modules/CIM/Core/Data/Types.lua")
local accessorSource = read_file("Modules/CIM/Core/Settings/SettingsAccessor.lua")

assert_true(typesSource:find('---@class BetterUIResourceOrbFramesSettings') ~= nil,
    "Types defines a ResourceOrbFrames settings schema")
assert_true(typesSource:find('---@alias BetterUIModuleSettingKey') ~= nil,
    "Types defines a shared settings key alias")
assert_true(typesSource:find('---@alias BetterUIModuleSettingValue') ~= nil,
    "Types defines a shared settings value alias")
assert_true(typesSource:find('---@field GetSetting fun%(key: BetterUIModuleSettingKey%): BetterUIModuleSettingValue|nil') ~= nil,
    "Types pins module GetSetting to the shared key/value aliases")
assert_true(typesSource:find('---@field SetSetting fun%(key: BetterUIModuleSettingKey, value: BetterUIModuleSettingValue%): boolean') ~= nil,
    "Types pins module SetSetting to the shared key/value aliases")
assert_true(typesSource:find('---@alias BetterUIResourceOrbFramesSettingKey') ~= nil,
    "Types defines a ResourceOrbFrames settings key alias")

assert_true(accessorSource:find('---@overload fun%(moduleName: "ResourceOrbFrames", defaults: BetterUIResourceOrbFramesSettings|nil%)') ~= nil,
    "SettingsAccessor overloads GetModuleSettings for ResourceOrbFrames")
assert_true(accessorSource:find('---@overload fun%(moduleName: "Inventory", key: BetterUIInventorySettingKey, default: BetterUIInventorySettingValue|nil%)') ~= nil,
    "SettingsAccessor overloads GetSetting with module-specific key/value aliases")
assert_true(accessorSource:find('---@overload fun%(moduleName: "ResourceOrbFrames", key: BetterUIResourceOrbFramesSettingKey, value: BetterUIResourceOrbFramesSettingValue%)') ~= nil,
    "SettingsAccessor overloads SetSetting for ResourceOrbFrames")
assert_true(accessorSource:find('---@param default any') == nil,
    "SettingsAccessor no longer annotates GetSetting defaults as any")
assert_true(accessorSource:find('---@return any value') == nil,
    "SettingsAccessor no longer annotates GetSetting return values as any")
assert_true(accessorSource:find('---@param value any') == nil,
    "SettingsAccessor no longer annotates SetSetting values as any")

print(string.format("\nResults: %d passed, %d failed", passed, failed))

if failed > 0 then
    os.exit(1)
end

print("All tests passed!")
