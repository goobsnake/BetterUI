--[[
File: tools/tests/test_inventory_initialize_runtime.lua
Purpose: Runtime regression for the immediate inventory initialize path so
         action surfaces are deferred until OnDeferredInitialize owns them.
Usage:
  lua tools/tests/test_inventory_initialize_runtime.lua
]]

local function assert_eq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected=%s, actual=%s)", message, tostring(expected), tostring(actual)))
    end
end

BETTERUI = {
    Inventory = {
        ClassMixins = {},
        ApplyAllMixins = function()
        end,
    },
    CIM = {
        DeferredTask = {
            CreateManager = function()
                return {}
            end,
            CreateLazyManagerProxy = function()
                return {}
            end,
        },
        UnifiedScreen = {
            FOOTER_MODE_CURRENCY = "currency",
            Initialize = function(instance, control, _, _, scene)
                instance.control = control
                instance.scene = scene or {
                    IsShowing = function()
                        return false
                    end,
                }
            end,
        },
    },
}

ZO_GamepadInventory = {}

function ZO_GamepadInventory:Subclass()
    local child = {}
    child.__index = child
    setmetatable(child, { __index = self })
    return child
end

GAMEPAD_INVENTORY_ROOT_SCENE = {
    IsShowing = function()
        return false
    end,
}

ZO_GAMEPAD_HEADER_TABBAR_CREATE = {}
EVENT_VISUAL_LAYER_CHANGED = 1

dofile("Modules/Inventory/Core/InventoryClass.lua")

local initializeItemActionsCalls = 0
local initializeActionsDialogCalls = 0
local initializeSplitStackDialogCalls = 0
local registeredEvents = {}
local setHandlers = {}

local control = {
    RegisterForEvent = function(_, eventId)
        registeredEvents[#registeredEvents + 1] = eventId
    end,
    SetHandler = function(_, handlerName)
        setHandlers[#setHandlers + 1] = handlerName
    end,
}

local instance = setmetatable({
    InitializeItemActions = function()
        initializeItemActionsCalls = initializeItemActionsCalls + 1
    end,
    InitializeActionsDialog = function()
        initializeActionsDialogCalls = initializeActionsDialogCalls + 1
    end,
    InitializeSplitStackDialog = function()
        initializeSplitStackDialogCalls = initializeSplitStackDialogCalls + 1
    end,
    RefreshKeybinds = function()
    end,
    TrySetClearNewFlag = function()
    end,
}, { __index = BETTERUI.Inventory.Class })

instance:Initialize(control)

assert_eq(initializeItemActionsCalls, 0, "InventoryClass.Initialize defers item-action setup")
assert_eq(initializeActionsDialogCalls, 0, "InventoryClass.Initialize defers action-dialog setup")
assert_eq(initializeSplitStackDialogCalls, 1, "InventoryClass.Initialize still wires split-stack support immediately")
assert_eq(registeredEvents[1], EVENT_VISUAL_LAYER_CHANGED, "InventoryClass.Initialize still registers visual-layer refresh handling")
assert_eq(setHandlers[1], "OnUpdate", "InventoryClass.Initialize still installs its update handler")

print("test_inventory_initialize_runtime.lua: PASS")
