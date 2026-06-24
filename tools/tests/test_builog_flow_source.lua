--[[
File: tools/tests/test_builog_flow_source.lua
Purpose: Source contract for live builog observability. Flow APIs must stay wired
         into the user flows that are hardest to debug from Interface.log alone:
         inventory junk toggles, banking transfers, keybind refreshes, list refresh
         outcomes, and watch snapshot providers.
Usage:   lua tools/tests/test_builog_flow_source.lua
]]

local function readFile(path)
    local handle = io.open(path, "r")
    if not handle then return "" end
    local content = handle:read("*a") or ""
    handle:close()
    return content
end

local passed, failed = 0, 0
local function check(cond, msg)
    if cond then passed = passed + 1; print("  [OK] " .. msg)
    else failed = failed + 1; print("  [X] " .. msg) end
end

print("\n=== builog flow instrumentation source contract ===\n")

local slotActions = readFile("Modules/Inventory/Actions/SlotActions.lua")
local itemActions = readFile("Modules/Inventory/Actions/ItemActionHandlers.lua")
local transferActions = readFile("Modules/Banking/Actions/TransferActions.lua")
local inventory = readFile("Modules/Inventory/Inventory.lua")
local banking = readFile("Modules/Banking/Banking.lua")
local keybinds = readFile("Modules/Inventory/Core/InventoryClass.lua")
local itemList = readFile("Modules/Inventory/Lists/ItemListManager.lua")
local bankList = readFile("Modules/Banking/Lists/BankListManager.lua")

check(slotActions:find("inventoryJunk", 1, true) ~= nil and slotActions:find("FlowBegin", 1, true) ~= nil,
    "primary inventory junk actions begin builog flows")
check(itemActions:find("inventory dialog junk toggle requested", 1, true) ~= nil,
    "dialog inventory junk action emits flow context")
check(transferActions:find("bankTransfer", 1, true) ~= nil and transferActions:find("bank transfer refresh decision", 1, true) ~= nil,
    "bank transfers emit flow context through refresh scheduling")
check(transferActions:find("guild bank transfer requested", 1, true) ~= nil
    and transferActions:find("guild bank transfer refresh decision", 1, true) ~= nil,
    "guild bank transfers emit flow context through refresh scheduling")
check(inventory:find('RegisterSnapshotProvider("inventory"', 1, true) ~= nil,
    "inventory registers a watch snapshot provider")
check(banking:find('RegisterSnapshotProvider("banking"', 1, true) ~= nil,
    "banking registers a watch snapshot provider")
check(inventory:find("visible=0", 1, true) ~= nil and inventory:find("visible=1", 1, true) ~= nil
    and banking:find("visible=0", 1, true) ~= nil and banking:find("visible=1", 1, true) ~= nil,
    "inventory and banking snapshots distinguish hidden and visible windows")
check(keybinds:find("inventory keybind refreshed", 1, true) ~= nil
    and keybinds:find("CATEGORY.KEYBIND", 1, true) ~= nil,
    "successful inventory keybind refresh detail stays in muted KEYBIND category")
check(keybinds:find("inventory keybind refresh incomplete", 1, true) ~= nil,
    "incomplete inventory keybind refresh outcomes remain visible at STATE level")
check(keybinds:find("hasStrip", 1, true) ~= nil and keybinds:find("updated =", 1, true) ~= nil,
    "inventory keybind logs distinguish missing strip from successful update")
check(itemList:find("inventory item list refreshed", 1, true) ~= nil,
    "inventory item-list refresh outcomes are visible at STATE level")
check(bankList:find("bank list refreshed", 1, true) ~= nil,
    "bank list refresh outcomes are visible at STATE level")
check(transferActions:find("bank transfer list refresh scheduled", 1, true) ~= nil
    and transferActions:find("bank transfer list refresh skipped", 1, true) ~= nil
    and transferActions:find("flow = flow", 1, true) ~= nil,
    "bank transfer refresh scheduling, skipped paths, and deferred flow context are visible")

print("\n=== Test Summary ===")
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))
if failed > 0 then os.exit(1) else print("\nAll tests passed!"); os.exit(0) end
