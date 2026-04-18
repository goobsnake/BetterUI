--[[
File: tools/tests/test_inventory_module_source.lua
Purpose: Source-level regression checks for the Inventory module bootstrap
         contract and setup failure handling.

Usage:
  lua tools/tests/test_inventory_module_source.lua
]]

local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local function assert_true(value, label)
    if not value then
        error(label)
    end
end

print("test_inventory_module_source")

local source = read_file("Modules/Inventory/Module.lua")

assert_true(source:find('setupOwner = "Modules/Inventory/Module.lua %+ Modules/Inventory/Core/InventoryClass.lua"', 1, false) ~= nil,
    "Inventory root contract documents both setup owners")
assert_true(source:find("local function NotifyInventorySetupFailure%(context, messageText%)") ~= nil,
    "Inventory module exposes a shared setup failure notifier")
assert_true(source:find('BETTERUI%.CIM and BETTERUI%.CIM%.UserNotifyText') ~= nil,
    "Inventory setup failure notifier prefers the shared CIM notifier")
assert_true(source:find('d%("%[BetterUI%] Inventory: CraftBagQuantityDialog init failed"%)') == nil,
    "Inventory module no longer uses bare debug logging for craft bag setup failure")
assert_true(source:find('d%("%[BetterUI%] Inventory: Narration registration failed"%)') == nil,
    "Inventory module no longer uses bare debug logging for narration setup failure")

print("  OK")
