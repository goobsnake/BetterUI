--[[
File: tools/tests/test_companion_actions_source.lua
Purpose: Source-level regression checks for companion item action seams.

Usage:
  lua tools/tests/test_companion_actions_source.lua
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

local source = read_file("Modules/Companions/Actions/CompanionActions.lua")

assert_true(source:find("function Companions%.ResolveCompanionEquipSlot%(bagId, slotIndex%)") ~= nil,
    "CompanionActions exposes ResolveCompanionEquipSlot")
assert_true(source:find("function Companions%.TryEquipCompanionItem%(bagId, slotIndex%)") ~= nil,
    "CompanionActions exposes TryEquipCompanionItem")
assert_true(source:find("function Companions%.TryUnequipCompanionItem%(slotIndex%)") ~= nil,
    "CompanionActions exposes TryUnequipCompanionItem")
assert_true(source:find("function Companions%.ToggleCompanionItemLock%(bagId, slotIndex%)") ~= nil,
    "CompanionActions exposes ToggleCompanionItemLock")
assert_true(source:find("function Companions%.ToggleCompanionItemJunk%(bagId, slotIndex%)") ~= nil,
    "CompanionActions exposes ToggleCompanionItemJunk")
assert_true(source:find("function Companions%.BuildActionList%(selectedData%)") ~= nil,
    "CompanionActions exposes BuildActionList")
assert_true(source:find("function Companions%.ExecuteAction%(actionId, selectedData%)") ~= nil,
    "CompanionActions exposes ExecuteAction")
assert_true(source:find('table.insert%(actions, %{%s*id = "equip", name = GetString%(SI_ITEM_ACTION_EQUIP%) %}%)') ~= nil,
    "CompanionActions offers equip action entries")
assert_true(source:find('table.insert%(actions, %{%s*id = "destroy", name = GetString%(SI_ITEM_ACTION_DESTROY%) %}%)') ~= nil,
    "CompanionActions offers destroy action entries")
assert_true(source:find('elseif actionId == "split" then') ~= nil
        and source:find("Companions%.ShowCompanionSplitStackDialog%(bagId, slotIndex%)") ~= nil,
    "CompanionActions routes split actions through the split-stack dialog helper")

if failed > 0 then
    error(string.format("test_companion_actions_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_companion_actions_source.lua: %d passed", passed))
