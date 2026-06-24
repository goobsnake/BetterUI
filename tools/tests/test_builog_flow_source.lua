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
local inventoryState = readFile("Modules/Inventory/State/ListStateManager.lua")
local bankingState = readFile("Modules/Banking/State/StateManager.lua")
local bankingKeybinds = readFile("Modules/Banking/Keybinds/KeybindManager.lua")

check(slotActions:find("inventoryJunk", 1, true) ~= nil and slotActions:find("FlowBegin", 1, true) ~= nil,
    "primary inventory junk actions begin builog flows")
check(itemActions:find("inventory dialog junk toggle requested", 1, true) ~= nil,
    "dialog inventory junk action emits flow context")
check(itemActions:find("inventory dialog junk toggle cache invalidated; waiting for inventory update", 1, true) ~= nil
    and itemActions:find("inventory dialog action confirmed", 1, true) ~= nil,
    "dialog inventory actions log confirmation and wait for inventory-update refresh")
check(transferActions:find("bankTransfer", 1, true) ~= nil and transferActions:find("bank transfer refresh decision", 1, true) ~= nil,
    "bank transfers emit flow context through refresh scheduling")
check(transferActions:find("bank transfer blocked", 1, true) ~= nil
    and transferActions:find("guild_transfer_denied", 1, true) ~= nil
    and transferActions:find("request_move_failed", 1, true) ~= nil
    and transferActions:find("GetTransferItemLink", 1, true) ~= nil,
    "bank transfers log blocked capacity/permission paths and item metadata")
check(transferActions:find("guild bank transfer requested", 1, true) ~= nil
    and transferActions:find("guild bank transfer refresh decision", 1, true) ~= nil,
    "guild bank transfers emit flow context through refresh scheduling")
check(bankingKeybinds:find("bankCurrencyTransfer", 1, true) ~= nil
    and bankingKeybinds:find("bank currency transfer completed", 1, true) ~= nil
    and bankingKeybinds:find("bank currency transfer failed", 1, true) ~= nil,
    "bank currency transfers emit completed and failed builog flow context")
check(inventory:find('RegisterSnapshotProvider("inventory"', 1, true) ~= nil,
    "inventory registers a watch snapshot provider")
check(banking:find('RegisterSnapshotProvider("banking"', 1, true) ~= nil,
    "banking registers a watch snapshot provider")
check(inventoryState:find("SetInventoryWatchView", 1, true) ~= nil
    and bankingState:find("SetBankingWatchView", 1, true) ~= nil,
    "inventory and banking feed production view context into watch mode")
check(inventory:find("visible=0", 1, true) ~= nil and inventory:find("visible=1", 1, true) ~= nil
    and banking:find("visible=0", 1, true) ~= nil and banking:find("visible=1", 1, true) ~= nil,
    "inventory and banking snapshots distinguish hidden and visible windows")
check(keybinds:find("inventory keybind refreshed", 1, true) ~= nil
    and keybinds:find("CATEGORY.STATE", 1, true) ~= nil,
    "successful inventory keybind refresh outcomes are visible at STATE level")
check(keybinds:find("inventory keybind refresh incomplete", 1, true) ~= nil,
    "incomplete inventory keybind refresh outcomes remain visible at STATE level")
check(keybinds:find("inventory dialog restore complete", 1, true) ~= nil
    and keybinds:find("inventory dialog restore skipped", 1, true) ~= nil
    and itemActions:find("inventory dialog finish restore complete", 1, true) ~= nil,
    "dialog restore attempts log their eventual state/keybind outcome")
check(keybinds:find("hasStrip", 1, true) ~= nil and keybinds:find("updated =", 1, true) ~= nil,
    "inventory keybind logs distinguish missing strip from successful update")
check(slotActions:find("inventory primary action resolved", 1, true) ~= nil
    and slotActions:find("inventory primary action invoked", 1, true) ~= nil
    and slotActions:find("GetSlotItemLink", 1, true) ~= nil,
    "primary action resolution and invocation log selected action and item metadata")
check(itemList:find("inventory item list refreshed", 1, true) ~= nil,
    "inventory item-list refresh outcomes are visible at STATE level")
check(inventory:find("inventory category list refreshed", 1, true) ~= nil
    and inventory:find("inventory category list refresh scheduled", 1, true) ~= nil
    and inventory:find("updates =", 1, true) ~= nil,
    "inventory update/category refresh reactions are visible as coalesced STATE outcomes")
check(bankList:find("bank list refreshed", 1, true) ~= nil,
    "bank list refresh outcomes are visible at STATE level")
check(bankingKeybinds:find("bank primary transfer invoked", 1, true) ~= nil
    and transferActions:find("bank action dialog shown", 1, true) ~= nil,
    "banking primary transfer and action dialog hand-offs are visible")
check(banking:find("bank currency UI refresh complete", 1, true) ~= nil,
    "bank currency event refreshes emit STATE outcomes")
check(transferActions:find("bank transfer list refresh scheduled", 1, true) ~= nil
    and transferActions:find("bank transfer list refresh skipped", 1, true) ~= nil
    and transferActions:find("flow = flow", 1, true) ~= nil,
    "bank transfer refresh scheduling, skipped paths, and deferred flow context are visible")

print("\n=== Test Summary ===")
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))
if failed > 0 then os.exit(1) else print("\nAll tests passed!"); os.exit(0) end
