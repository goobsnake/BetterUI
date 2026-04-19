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

assert_true(source:find('setup = true', 1, true) ~= nil,
    "Inventory root contract opts into setup execution explicitly")
assert_true(source:find("local function NotifyInventorySetupFailure%(context, messageText%)") ~= nil,
    "Inventory module exposes a shared setup failure notifier")
assert_true(source:find('BETTERUI%.CIM and BETTERUI%.CIM%.UserNotify') ~= nil,
    "Inventory setup failure notifier prefers the shared CIM notifier")
assert_true(source:find('BETTERUI%.CIM%.UserNotify%(context, messageText%)') ~= nil,
    "Inventory setup failure notifier routes text failures through the canonical shared notifier")
assert_true(source:find('d%("%[BetterUI%] " %.%. tostring%(messageText%)%)') == nil,
    "Inventory setup failure notifier no longer degrades to a local debug-only fallback")
assert_true(source:find('d%("%[BetterUI%] Inventory: CraftBagQuantityDialog init failed"%)') == nil,
    "Inventory module no longer uses bare debug logging for craft bag setup failure")
assert_true(source:find('d%("%[BetterUI%] Inventory: Narration registration failed"%)') == nil,
    "Inventory module no longer uses bare debug logging for narration setup failure")

print("  OK")
