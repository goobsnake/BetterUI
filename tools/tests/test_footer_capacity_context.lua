local passed = 0
local failed = 0

local function assert_equal(expected, actual, label)
    if expected == actual then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write(string.format(
            "Assertion failed: %s (expected %s, got %s)\n",
            label, tostring(expected), tostring(actual)))
    end
end

BAG_BACKPACK = 1
BAG_COMPANION_WORN = 2
SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT = "capacity"
SI_BETTERUI_FOOTER_BAG_CAPACITY = "SI_BETTERUI_FOOTER_BAG_CAPACITY"

local capacities = {
    [BAG_BACKPACK] = { used = 105, size = 205 },
    [BAG_COMPANION_WORN] = { used = 7, size = 14 },
}

function GetNumBagUsedSlots(bagId)
    return capacities[bagId].used
end

function GetBagSize(bagId)
    return capacities[bagId].size
end

function GetBagUseableSize(bagId)
    return GetBagSize(bagId)
end

function GetString(value)
    return tostring(value)
end

function zo_strformat(formatString, ...)
    local args = { ... }
    if formatString == SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT then
        return string.format("%s/%s", tostring(args[1]), tostring(args[2]))
    end
    return string.format("%s (%s)", tostring(args[1]), tostring(args[2]))
end

local function newLabel()
    return {
        text = nil,
        SetText = function(self, value)
            self.text = value
        end,
    }
end

BETTERUI = {
    CIM = {
        Currency = {
            GetLabelControl = function(footer, name)
                return footer[name]
            end,
            UpdateLabels = function()
                return false
            end,
            PositionLabels = function() end,
        },
        UnifiedFooter = {},
    },
    GenericFooter = {},
    GetModuleSettings = function()
        return {}
    end,
}

dofile("Modules/CIM/UI/GenericFooter.lua")

local inventoryFooter = { CWLabel = newLabel() }
BETTERUI.GenericFooter.Refresh({ footer = inventoryFooter })
assert_equal("SI_BETTERUI_FOOTER_BAG_CAPACITY (105/205)",
    inventoryFooter.CWLabel.text,
    "default footer keeps Inventory backpack capacity")

local companionFooter = { CWLabel = newLabel() }
BETTERUI.GenericFooter.Refresh({
    footer = companionFooter,
    capacityBagId = BAG_COMPANION_WORN,
})
assert_equal("SI_BETTERUI_FOOTER_BAG_CAPACITY (7/14)",
    companionFooter.CWLabel.text,
    "Companion footer uses Companion worn-bag capacity")

ZO_Object = {}
function ZO_Object:Subclass()
    local class = {}
    class.__index = class
    return class
end
function ZO_Object.New(class)
    return setmetatable({}, class)
end

dofile("Modules/CIM/UI/UnifiedFooter.lua")

local control = { container = {} }
local controller = BETTERUI.CIM.UnifiedFooter.Create(control)
local controllerFooter = { CWLabel = newLabel() }
controller:SetupFooter(controllerFooter)
assert_equal("function", type(controller.SetCapacityBagId),
    "UnifiedFooter exposes a screen-local capacity bag override")
if type(controller.SetCapacityBagId) == "function" then
    controller:SetCapacityBagId(BAG_COMPANION_WORN)
    controller:Refresh()
    assert_equal("SI_BETTERUI_FOOTER_BAG_CAPACITY (7/14)",
        controllerFooter.CWLabel.text,
        "UnifiedFooter passes its Companion capacity context to GenericFooter")
end

print(string.format("test_footer_capacity_context.lua: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
