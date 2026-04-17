--[[
File: tools/tests/test_inventory_slot_actions.lua
Purpose: Regression tests for Inventory SlotActions primary action resolution.
         Verifies ActivatePrimaryCommand does not crash when evaluating
         replacement actions like "Equip".

Usage:
  lua tools/tests/test_inventory_slot_actions.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = {
    Inventory = {},
    CIM = {},
}

function BETTERUI.Debug() end

-- String constants used by SlotActions
SI_ITEM_ACTION_USE = 1
SI_ITEM_ACTION_EQUIP = 2
SI_ITEM_ACTION_UNEQUIP = 3
SI_ITEM_ACTION_BANK_WITHDRAW = 4
SI_ITEM_ACTION_BANK_DEPOSIT = 5
SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG = 6
SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG = 7
SI_ITEM_ACTION_SHOW_MAP = 8
SI_ITEM_ACTION_START_SKILL_RESPEC = 9
SI_ITEM_ACTION_START_ATTRIBUTE_RESPEC = 10
SI_ITEM_ACTION_SPLIT_STACK = 11
SI_ITEM_ACTION_LINK_TO_CHAT = 12
SI_ITEM_ACTION_DESTROY = 13

local stringMap = {
    [SI_ITEM_ACTION_USE] = "Use",
    [SI_ITEM_ACTION_EQUIP] = "Equip",
    [SI_ITEM_ACTION_UNEQUIP] = "Unequip",
    [SI_ITEM_ACTION_BANK_WITHDRAW] = "Withdraw",
    [SI_ITEM_ACTION_BANK_DEPOSIT] = "Deposit",
    [SI_ITEM_ACTION_ADD_ITEMS_TO_CRAFT_BAG] = "Add to Craft Bag",
    [SI_ITEM_ACTION_REMOVE_ITEMS_FROM_CRAFT_BAG] = "Retrieve",
    [SI_ITEM_ACTION_SHOW_MAP] = "Show on Map",
    [SI_ITEM_ACTION_START_SKILL_RESPEC] = "Open Skills",
    [SI_ITEM_ACTION_START_ATTRIBUTE_RESPEC] = "Open Attributes",
    [SI_ITEM_ACTION_SPLIT_STACK] = "Split Stack",
    [SI_ITEM_ACTION_LINK_TO_CHAT] = "Link to Chat",
    [SI_ITEM_ACTION_DESTROY] = "Destroy",
}

function GetString(id)
    return stringMap[id]
end

function ZO_Dialogs_IsShowingDialog()
    return false
end

function ZO_InventorySlot_DiscoverSlotActionsFromActionList(_, _)
    -- no-op for unit test
end

ZO_ItemSlotActionsController = {}
function ZO_ItemSlotActionsController:Subclass()
    local class = {}
    setmetatable(class, { __index = self })
    return class
end

GAMEPAD_INVENTORY = {
    TryEquipItem = function() end,
}

SCENE_MANAGER = { scenes = {} }

local safeExecuteCalls = {}

-- CIM helpers called from SlotActions
BETTERUI.CIM.SafeExecute = function(_, fn, ...)
    if type(fn) ~= "function" then return false, "No function" end
    safeExecuteCalls[#safeExecuteCalls + 1] = _
    local ok, result = pcall(fn, ...)
    if not ok then
        return false, result
    end
    return true, result
end
BETTERUI.CIM.SecureOpenSkills = function() end
BETTERUI.CIM.ResolveCraftBagState = function(_, _, primaryAction)
    return primaryAction
end
BETTERUI.CIM.DeduplicateActions = function() end
BETTERUI.CIM.TryUseItem = function() end
BETTERUI.CIM.TryBankItem = function() end
BETTERUI.CIM.TryMoveToCraftBag = function() end
BETTERUI.CIM.CanItemMoveToCraftBag = function() return false end
BETTERUI.CIM.IsSlotInCraftBag = function() return false end
BETTERUI.CIM.TryCall = function() return false end
BETTERUI.CIM.SetupSecureAction = function(actionsList)
    actionsList._setupCalls = (actionsList._setupCalls or 0) + 1
end

-- ============================================================================
-- IMPORT MODULE UNDER TEST
-- ============================================================================

local moduleLoaded, moduleLoadError = pcall(function()
    dofile("Modules/Inventory/Actions/SlotActions.lua")
end)

-- ============================================================================
-- TEST HARNESS
-- ============================================================================

local tests_passed = 0
local tests_failed = 0

local function assert_equal(expected, actual, message)
    if expected == actual then
        tests_passed = tests_passed + 1
        print("  [OK] " .. message)
    else
        tests_failed = tests_failed + 1
        print("  [X] " .. message)
        print("    Expected: " .. tostring(expected))
        print("    Actual:   " .. tostring(actual))
    end
end

local function assert_true(value, message)
    assert_equal(true, value, message)
end

-- ============================================================================
-- TESTS
-- ============================================================================

print("\n=== Inventory SlotActions Regression Tests ===\n")

assert_true(moduleLoaded, "SlotActions module loads when optional action-string constants are missing")
if not moduleLoaded then
    print("    Load error: " .. tostring(moduleLoadError))
end

if moduleLoaded then

local slotActionsStub = {
    m_slotActions = {
        { "Inspect", function() end }
    },
    Clear = function(self)
        self.m_slotActions = { { "Inspect", function() end } }
    end,
    SetInventorySlot = function(self, inventorySlot)
        self._inventorySlot = inventorySlot
    end,
    GetPrimaryActionName = function()
        return "Equip"
    end,
    AddSlotAction = function(self, name, callback, actionType, visibilityFunction, options)
        self.m_slotActions[#self.m_slotActions + 1] = { name, callback, actionType, visibilityFunction, options }
    end,
}

local controller = setmetatable({ slotActions = slotActionsStub }, { __index = BETTERUI.Inventory.SlotActions })
local inventorySlot = { bagId = 1, slotIndex = 74 }

local ok1 = pcall(function()
    controller:ActivatePrimaryCommand(inventorySlot)
end)
assert_true(ok1, "ActivatePrimaryCommand does not crash for Equip primary action")
assert_equal("Equip", controller.actionName, "Resolved actionName remains Equip")

local ok2 = pcall(function()
    controller:ActivatePrimaryCommand(inventorySlot)
end)
assert_true(ok2, "Second call does not crash (cached lookup path)")

assert_true((slotActionsStub._setupCalls or 0) >= 1, "SetupSecureAction was invoked for replacement action")

local visibilityStub = {
    m_slotActions = {
        { "Link to Chat", function() end },
        { "Destroy", function() end, "secondary", function() error("visibility exploded") end },
        { "Inspect", function() end, "secondary", function() return true end },
    },
    Clear = function(self)
        self.m_slotActions = {
            { "Link to Chat", function() end },
            { "Destroy", function() end, "secondary", function() error("visibility exploded") end },
            { "Inspect", function() end, "secondary", function() return true end },
        }
    end,
    SetInventorySlot = function(self, slot)
        self._inventorySlot = slot
    end,
    GetPrimaryActionName = function()
        return "Link to Chat"
    end,
    AddSlotAction = function(self, name, callback, actionType, visibilityFunction, options)
        self.m_slotActions[#self.m_slotActions + 1] = { name, callback, actionType, visibilityFunction, options }
    end,
}

local visibilityController = setmetatable({ slotActions = visibilityStub }, { __index = BETTERUI.Inventory.SlotActions })
local ok3 = pcall(function()
    visibilityController:ActivatePrimaryCommand(inventorySlot)
end)
assert_true(ok3, "Visibility callback failures stay fail-closed without crashing primary-action resolution")
assert_equal("Inspect", visibilityController.actionName,
    "Primary-action fallback skips actions whose visibility callback raises")
assert_true(safeExecuteCalls[#safeExecuteCalls] == "SlotActions.visibility:Inspect"
        or safeExecuteCalls[#safeExecuteCalls - 1] == "SlotActions.visibility:Destroy",
    "Visibility checks route through CIM.SafeExecute with action-specific context")
end

-- ============================================================================
-- SUMMARY
-- ============================================================================

print("\n=== Test Summary ===")
print(string.format("Passed: %d", tests_passed))
print(string.format("Failed: %d", tests_failed))

if tests_failed > 0 then
    os.exit(1)
else
    print("\nAll tests passed")
    os.exit(0)
end
