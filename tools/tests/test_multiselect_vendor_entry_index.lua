--[[
File: tools/tests/test_multiselect_vendor_entry_index.lua
Purpose: Regression coverage for vendor buyback-style multi-select keys.
]]

-- Minimal framework stubs
SOUNDS = {
    GAMEPAD_MENU_FORWARD = "fwd",
    GAMEPAD_MENU_BACK = "back",
    GAMEPAD_MENU_BACKWARD = "backward",
}

local function noop() end
PlaySound = noop

ZO_Object = {}
function ZO_Object:Subclass()
    local cls = {}
    cls.__index = cls
    setmetatable(cls, { __index = self })
    function cls:New(...)
        local obj = setmetatable({}, cls)
        if obj.Initialize then
            obj:Initialize(...)
        end
        return obj
    end
    return cls
end
function ZO_Object.New(self)
    local obj = setmetatable({}, self)
    return obj
end

BETTERUI = { CIM = {} }

dofile("Modules/CIM/Core/Data/MultiSelectManager.lua")

local MultiSelectManager = BETTERUI.CIM.MultiSelectManager

local function assertEq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected=%s, actual=%s)", message, tostring(expected), tostring(actual)))
    end
end

local function assertTrue(value, message)
    if not value then
        error(message or "expected true")
    end
end

local function buildList(entries)
    return {
        dataList = entries,
        GetNumItems = function(self)
            return #self.dataList
        end,
        GetDataForDataIndex = function(self, index)
            return self.dataList[index]
        end,
    }
end

-- Entry-index-only rows mirror vendor buyback data (no bagId/slotIndex).
local rowOne = { dataSource = { entryIndex = 1, name = "Row One" } }
local rowTwo = { dataSource = { entryIndex = 2, name = "Row Two" } }

local manager = MultiSelectManager.Create(buildList({ rowOne, rowTwo }))
manager:EnterSelectionMode()

local keys = manager:GetItemSelectionKeys(rowOne)
assertEq(keys[1], "entry_1", "entry-index key should be generated for vendor rows")

local toggledSelected = manager:ToggleSelection(rowOne)
assertTrue(toggledSelected, "entry-index rows should be selectable")
assertEq(manager:GetSelectedCount(), 1, "toggle should increase selection count")

manager:ClearSelections()
manager:SelectAll()
assertEq(manager:GetSelectedCount(), 2, "SelectAll should include entry-index rows")

print("test_multiselect_vendor_entry_index.lua: PASS")
