--[[
File: tools/tests/test_inventory_deferred_init_source.lua
Purpose: Guards the explicit deferred-initialization bridge for the Inventory scene.

Usage:
  lua tools/tests/test_inventory_deferred_init_source.lua
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

local function assert_not_contains(haystack, needle, label)
    if haystack:find(needle, 1, true) then
        error(label .. "\nUnexpected: " .. needle)
    end
end

print("test_inventory_deferred_init_source")

local inventoryRuntime = read_file("Modules/Inventory/Inventory.lua")
local inventoryModule = read_file("Modules/Inventory/Module.lua")
local inventoryClass = read_file("Modules/Inventory/Core/InventoryClass.lua")
local headerManager = read_file("Modules/Inventory/Core/HeaderManager.lua")
local listStateManager = read_file("Modules/Inventory/State/ListStateManager.lua")

assert_contains(inventoryRuntime, "function BETTERUI.Inventory.Class:OnDeferredInitialize()",
    "Inventory runtime must define the deferred initialization hook")
assert_contains(inventoryRuntime, "if self._betterUIDeferredInventoryInitialized then return end",
    "OnDeferredInitialize must guard against duplicate BetterUI initialization")
assert_contains(inventoryRuntime, "self._betterUIDeferredInventoryInitialized = true",
    "OnDeferredInitialize must mark BetterUI deferred initialization as complete")
assert_contains(inventoryRuntime, "function BETTERUI.Inventory.Class:PerformDeferredInitialize()",
    "Inventory runtime must define an explicit deferred initialization bridge")
assert_contains(inventoryRuntime,
    "local parentPerformDeferredInitialize = ZO_GamepadInventory and ZO_GamepadInventory.PerformDeferredInitialize",
    "PerformDeferredInitialize must preserve native parent deferred initialization when available")
assert_contains(inventoryRuntime, "parentPerformDeferredInitialize(self)",
    "PerformDeferredInitialize must invoke the native parent implementation when available")
assert_contains(inventoryRuntime,
    "if not self._betterUIDeferredInventoryInitialized and self.OnDeferredInitialize then",
    "PerformDeferredInitialize must fall back to BetterUI's deferred setup hook when native flow skips it")
assert_contains(inventoryRuntime, "self:OnDeferredInitialize()",
    "PerformDeferredInitialize must invoke BetterUI deferred setup as a fallback")
assert_contains(inventoryRuntime, "if self.scene and self.scene:IsShowing() then",
    "Deferred inventory init must only activate the item list immediately when the scene is already visible")
assert_contains(inventoryRuntime, "self.currentListType = nil",
    "Deferred inventory init must avoid leaving a hidden list marked active")
assert_contains(inventoryRuntime, "self.previousListType = nil",
    "Deferred inventory init must clear stale previous list state before first visible activation")

assert_contains(inventoryModule, "GAMEPAD_INVENTORY:PerformDeferredInitialize()",
    "Inventory module setup must explicitly bridge deferred initialization when replacing the native runtime")

assert_contains(headerManager, "BETTERUI.GenericFooter.control = self.control",
    "Header initialization must point the generic footer at the inventory control")
assert_contains(headerManager, "BETTERUI.GenericFooter:Initialize()",
    "Header initialization must initialize the generic footer with method-call syntax")
if headerManager:find("BETTERUI%.GenericFooter%.Initialize%(self%)", 1, false) then
    error("Header initialization must not call GenericFooter.Initialize(self)")
end

assert_contains(listStateManager, "if listDescriptor == self.currentListType then",
    "SwitchActiveList must short-circuit same-list requests to avoid recursive re-entry through category callbacks")
assert_not_contains(listStateManager, "NeedsVisibleListActivation",
    "SwitchActiveList must not re-enter the same list while activation is still bootstrapping")

local refreshHeaderBody = inventoryClass:match(
    "function BETTERUI%.Inventory%.Class:RefreshHeader%(blockCallback%)\n([%s%S]-)\nend"
)
if not refreshHeaderBody then
    error("InventoryClass must define RefreshHeader")
end
assert_not_contains(refreshHeaderBody, "self:RefreshCategoryList()",
    "RefreshHeader must not rebuild category lists; callers already refresh categories explicitly")

print("  OK")
