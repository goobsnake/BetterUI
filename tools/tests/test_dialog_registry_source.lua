--[[
File: tools/tests/test_dialog_registry_source.lua
Purpose: Source-level regression checks for the CIM dialog registry boundary.

Usage:
  lua tools/tests/test_dialog_registry_source.lua
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

local moduleFiles = {
    "Modules/Banking/Core/GuildBankAdapter.lua",
    "Modules/Banking/Core/MultiSelectActions.lua",
    "Modules/Companions/Actions/CompanionActions.lua",
    "Modules/Companions/Dialogs/CompanionDialogs.lua",
    "Modules/Inventory/Actions/ActionDialogHooks.lua",
    "Modules/TradingHouse/Core/BrowseFilters.lua",
    "Modules/TradingHouse/Core/PriceEntry.lua",
    "Modules/TradingHouse/Core/SearchPresets.lua",
    "Modules/TradingHouse/Core/TradingHouseRuntimeFlow.lua",
    "Modules/Vendor/Vendor.lua",
}

local registrySource = read_file("Modules/CIM/Dialogs/DialogRegistry.lua")
assert_true(registrySource:find("ZO_Dialogs_RegisterCustomDialog", 1, true) ~= nil,
    "DialogRegistry owns the raw ZO dialog registration API")
assert_true(registrySource:find("ESO_Dialogs[", 1, true) ~= nil,
    "DialogRegistry owns raw ESO_Dialogs table access")
assert_true(registrySource:find("dialog ownership changed before re-register", 1, true) == nil,
    "DialogRegistry does not emit a duplicate secondary ownership warning")
assert_true(registrySource:find("function BETTERUI.CIM.Dialogs.ShowForOwner", 1, true) ~= nil,
    "DialogRegistry tracks dialogs against their scene owner")
assert_true(registrySource:find("function BETTERUI.CIM.Dialogs.ReleaseOwned", 1, true) ~= nil,
    "DialogRegistry exposes source-owned dialog teardown")
assert_true(registrySource:find("function BETTERUI.CIM.Dialogs.ClaimShownForOwner", 1, true) ~= nil,
    "DialogRegistry can claim dialogs opened by ESOUI helper functions")
assert_true(registrySource:find("ZO_Dialogs_ReleaseAllDialogsOfName", 1, true) ~= nil,
    "DialogRegistry releases displayed and queued dialogs through ESOUI's filtered API")

for _, path in ipairs(moduleFiles) do
    local source = read_file(path)
    assert_true(source:find("ZO_Dialogs_RegisterCustomDialog", 1, true) == nil,
        path .. " does not call the raw ZO dialog registration API")
    assert_true(source:find("ESO_Dialogs[", 1, true) == nil,
        path .. " does not access the raw ESO_Dialogs table")
end

local guildBankSource = read_file("Modules/Banking/Core/GuildBankAdapter.lua")
assert_true(guildBankSource:find("dialogs.Register(dialogName, dialogInfo)", 1, true) ~= nil,
    "GuildBankAdapter registers the final dialog table through CIM.Dialogs")
assert_true(guildBankSource:find("orig.setup", 1, true) == nil,
    "GuildBankAdapter does not mutate dialog setup after registration")

local multiSelectSource = read_file("Modules/Banking/Core/MultiSelectActions.lua")
assert_true(multiSelectSource:find("dialogs.GetCurrentInfo(dialogName)", 1, true) ~= nil,
    "MultiSelectActions uses the registry to guard and fetch dialog state")

if failed > 0 then
    error(string.format("test_dialog_registry_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_dialog_registry_source.lua: %d passed", passed))
