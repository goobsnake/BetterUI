--[[
File: tools/tests/test_header_sort_keybinds.lua
Purpose: Regression tests for HeaderSortController clear-sort keybind behavior.

Usage:
  lua tools/tests/test_header_sort_keybinds.lua
]]

local passed = 0
local failed = 0

local function assert_equal(expected, actual, message)
    if expected == actual then
        passed = passed + 1
        print("  [OK] " .. message)
    else
        failed = failed + 1
        print("  [X] " .. message)
        print("       Expected: " .. tostring(expected))
        print("       Actual:   " .. tostring(actual))
    end
end

local function assert_true(value, message)
    assert_equal(true, value, message)
end

BETTERUI = {
    CIM = {
        UI = {},
        -- Production loads SafeExecute before CIM/UI; stub it for the harness.
        SafeExecute = function(_, fn, ...) return pcall(fn, ...) end,
    },
}

ZO_Object = {}

function ZO_Object:Subclass()
    local subclass = {}
    subclass.__index = subclass
    setmetatable(subclass, { __index = self })
    return subclass
end

function ZO_Object.New(class)
    return setmetatable({}, class)
end

KEYBIND_STRIP_ALIGN_LEFT = 1
KEYBIND_STRIP = {
    updateCalls = 0,
    groups = {},
    addCalls = 0,
    removeCalls = 0,
    AddKeybindButtonGroup = function(self, descriptor)
        self.addCalls = self.addCalls + 1
        self.groups[descriptor] = true
    end,
    RemoveKeybindButtonGroup = function(self, descriptor)
        self.removeCalls = self.removeCalls + 1
        self.groups[descriptor] = nil
    end,
    UpdateCurrentKeybindButtonGroups = function(self)
        self.updateCalls = self.updateCalls + 1
    end,
    HasKeybindButtonGroup = function(self, descriptor)
        return self.groups[descriptor] == true
    end,
}

SOUNDS = {
    DEFAULT_CLICK = "click",
    HOR_LIST_ITEM_SELECTED = "nav",
}

function PlaySound(_)
end

function GetString(value)
    return tostring(value)
end

SI_BETTERUI_HEADER_SORT = "Sort"
SI_GAMEPAD_BACK_OPTION = "Back"
SI_BETTERUI_CLEAR_SORT = "Clear"

dofile("Modules/CIM/UI/HeaderSortController.lua")
dofile("Modules/CIM/UI/HeaderSortKeybinds.lua")

local HeaderSortController = BETTERUI.CIM.UI.HeaderSortController
local SORT_DIRECTION = HeaderSortController.SORT_DIRECTION

print("\n=== HeaderSort Keybind Tests ===\n")

do
    local callbacks = {}
    local controller = HeaderSortController:New(nil, {
        { key = "name", sortFn = function() return false end },
        { key = "value", sortFn = function() return false end },
    }, function(key, direction)
        callbacks[#callbacks + 1] = { key = key, direction = direction }
    end)

    controller:ToggleSortForColumn(2)
    controller:EnterHeaderMode()
    controller:NavigateLeft()

    local descriptor = controller:CreateKeybindDescriptor(function() end)
    local clearKeybind = descriptor[3]

    assert_equal(1, controller:GetCurrentColumnIndex(), "test starts with cursor off the active sort column")
    assert_equal(SORT_DIRECTION.ASCENDING, controller:GetSortDirection(2), "sort remains active on the second column")
    assert_true(clearKeybind.visible(), "clear-sort keybind remains visible while any sort is active")

    clearKeybind.callback()

    local _, activeDirection = controller:GetActiveSortColumn()
    assert_equal(SORT_DIRECTION.NONE, activeDirection, "clear-sort callback clears the active sort")
    assert_equal(SORT_DIRECTION.NONE, controller:GetSortDirection(2), "active column direction is reset")
    assert_equal("value", callbacks[#callbacks].key, "clear-sort callback reports the cleared column")
    assert_equal(SORT_DIRECTION.NONE, callbacks[#callbacks].direction, "clear-sort callback reports NONE direction")
end

do
    local capturedWarn
    BETTERUI.Log = {
        CATEGORY = { KEYBIND = "KEYBIND", SORT = "SORT" },
        IsActive = function() return true end,
        Trace = function() end,
        TraceEvent = function() end,
        Warn = function(category, message, data)
            capturedWarn = { category = category, message = message, data = data }
        end,
    }

    KEYBIND_STRIP.groups = {}
    local mainDescriptor = { id = "main" }
    local controller = HeaderSortController:New(nil, {
        { key = "name", sortFn = function() return false end },
    }, function() end)
    controller:EnterHeaderMode()

    local descriptor = controller:CreateKeybindDescriptor(function() end)
    controller._headerSortKeybindDescriptor = descriptor
    controller._headerSortIntegration = {
        isActive = true,
        owner = { isInHeaderSortMode = true },
        keybinds = { mainDescriptor = mainDescriptor },
        reactivateListAfterHeaderSort = true,
    }

    KEYBIND_STRIP.groups[mainDescriptor] = true
    descriptor[1].callback()

    assert_equal("header sort keybind ownership repaired", capturedWarn and capturedWarn.message,
        "primary refresh warns when owner keybinds reclaim the strip and are repaired")
    assert_equal(true, capturedWarn and capturedWarn.data and capturedWarn.data.beforeStripHasMain,
        "ownership warning records that the owner main keybind was present")
    assert_equal(false, capturedWarn and capturedWarn.data and capturedWarn.data.beforeStripHasHeader,
        "ownership warning records that the header keybind was missing")
    assert_equal(false, KEYBIND_STRIP.groups[mainDescriptor] == true,
        "primary refresh removes the owner main keybind from the active strip")
    assert_equal(true, KEYBIND_STRIP.groups[descriptor] == true,
        "primary refresh restores the header sort keybind group")

    BETTERUI.Log = nil
end

print("\n=== Summary ===")
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))

if failed > 0 then
    os.exit(1)
end
