--[[
File: tools/tests/test_accessibility_narration_source.lua
Purpose: Source-shape regression pins for ACC-010 gamepad narration trigger wiring.

Usage:
  lua tools/tests/test_accessibility_narration_source.lua
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
    local handle, err = io.open(path, "r")
    assert_true(handle ~= nil, string.format("opens source file: %s (%s)", path, tostring(err)))
    if not handle then return "" end
    local content = handle:read("*a") or ""
    handle:close()
    return content
end

local narrationHelper = read_file("Modules/CIM/Core/Integration/NarrationHelper.lua")
assert_true(narrationHelper:find("function%s+Narration%.QueueSceneNarration%(") ~= nil,
    "NarrationHelper exposes QueueSceneNarration")
assert_true(narrationHelper:find("QueueCustomEntry") ~= nil,
    "QueueSceneNarration delegates to SCREEN_NARRATION_MANAGER:QueueCustomEntry")
assert_true(narrationHelper:find("narrationType%s*=%s*GetUIScreenNarrationType%(%)") ~= nil,
    "registered custom narration objects use UI screen narration type")
assert_true(narrationHelper:find("customObjectNarrationInfo") ~= nil,
    "QueueSceneNarration guards against unregistered custom objects")

local inventoryTriggerFiles = {
    "Modules/Inventory/Lists/InventoryList.lua",
    "Modules/Inventory/Lists/ItemListManager.lua",
    "Modules/Inventory/Lists/CraftBagListManager.lua",
}

local inventoryClass = read_file("Modules/Inventory/Core/InventoryClass.lua")
assert_true(inventoryClass:find("ZO_GAMEPAD_INVENTORY_SCENE_NAME%s*=%s*\"gamepad_inventory_root\"") ~= nil,
    "inventory scene name matches ESO's gamepad inventory root scene")
assert_true(inventoryClass:find("function%s+BETTERUI%.Inventory%.GetNarrationSceneName%(") ~= nil,
    "inventory exposes the narration scene name helper")
assert_true(inventoryClass:find("function%s+BETTERUI%.Inventory%.QueueSceneNarration%(") ~= nil,
    "inventory queues scene narration through a shared scene-name helper")
assert_true(inventoryClass:find("queueSceneNarration(BETTERUI.Inventory.GetNarrationSceneName())", 1, true) ~= nil,
    "inventory narration queue uses the registered gamepad inventory scene name")

local inventoryModule = read_file("Modules/Inventory/Module.lua")
assert_true(inventoryModule:find("Inventory%.GetNarrationSceneName%(%)") ~= nil,
    "inventory narration registration uses the gamepad inventory scene name helper")
assert_true(inventoryModule:find('"gamepadInventory"', 1, true) == nil,
    "inventory narration registration does not use the obsolete scene alias")

for _, path in ipairs(inventoryTriggerFiles) do
    local source = read_file(path)
    assert_true(source:find("QueueInventoryNarration") ~= nil,
        path .. " queues inventory scene narration")
    assert_true(source:find("BETTERUI.Inventory.QueueSceneNarration", 1, true) ~= nil,
        path .. " delegates to the shared inventory narration queue")
    assert_true(source:find('"gamepadInventory"', 1, true) == nil,
        path .. " does not use the obsolete inventory scene alias")
end

local triggerChecks = {
    {
        path = "Modules/Banking/Banking.lua",
        scene = "BETTERUI_BANKING_SCENE_NAME",
        extra = "BETTERUI_GUILD_BANKING_SCENE_NAME",
        label = "banking",
    },
    {
        path = "Modules/Vendor/Core/VendorBootstrapRuntime.lua",
        scene = "BETTERUI_VENDOR_SCENE_NAME",
        label = "vendor",
    },
    {
        path = "Modules/TradingHouse/Core/TradingHouseRuntime.lua",
        scene = "BETTERUI_TRADING_HOUSE_SCENE_NAME",
        label = "trading house",
    },
    {
        path = "Modules/Companions/Core/CompanionListManager.lua",
        scene = "BETTERUI_COMPANION_EQUIP_SCENE_NAME",
        label = "companions",
    },
}

for _, check in ipairs(triggerChecks) do
    local source = read_file(check.path)
    assert_true(source:find("QueueSceneNarration") ~= nil,
        check.label .. " queues scene narration from selection changes")
    assert_true(source:find(check.scene, 1, true) ~= nil,
        check.label .. " references the registered narration scene")
    if check.extra then
        assert_true(source:find(check.extra, 1, true) ~= nil,
            check.label .. " handles the alternate registered narration scene")
    end
end

local searchManager = read_file("Modules/CIM/Core/Data/SearchManager.lua")
assert_true(searchManager:find("resultsNarrationFunction") ~= nil,
    "search narration keeps ESO's resultsNarrationFunction hook")
assert_true(searchManager:find("AppendSelectedItemSearchNarration") ~= nil,
    "search narration folds selected-item details into the read results hook")
assert_true(searchManager:find("selectedItemNarrationFunction") == nil,
    "search narration no longer relies on the unused selectedItemNarrationFunction key")

if failed > 0 then
    error(string.format("test_accessibility_narration_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_accessibility_narration_source.lua: %d passed", passed))
