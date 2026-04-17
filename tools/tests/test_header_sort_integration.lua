--[[
File: tools/tests/test_header_sort_integration.lua
Purpose: Regression tests for HeaderSortIntegration setup and mixin flow.

Usage:
  lua tools/tests/test_header_sort_integration.lua
]]

local passed = 0
local failed = 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, label)
    assert_eq(value == true, true, label)
end

BETTERUI = {
    CIM = {
        UI = {
            HeaderSortController = {
                SORT_DIRECTION = {
                    NONE = "none",
                },
            },
        },
    },
}

KEYBIND_STRIP_ALIGN_CENTER = 1

local keybindOps = {}
KEYBIND_STRIP = {
    RemoveKeybindButtonGroup = function(_, group)
        table.insert(keybindOps, "remove")
    end,
    AddKeybindButtonGroup = function(_, group)
        table.insert(keybindOps, "add")
    end,
    UpdateCurrentKeybindButtonGroups = function()
        table.insert(keybindOps, "updateCurrent")
    end,
    UpdateKeybindButtonGroup = function(_, group)
        table.insert(keybindOps, "updateGroup")
    end,
    RemoveAllKeyButtonGroups = function()
        table.insert(keybindOps, "removeAll")
    end,
}

SOUNDS = {
    HOR_LIST_ITEM_SELECTED = "click",
    GAMEPAD_MENU_FORWARD = "forward",
    GAMEPAD_MENU_BACK = "back",
}

local playedSounds = {}
function PlaySound(soundId)
    table.insert(playedSounds, soundId)
end

function GetString(value)
    return tostring(value)
end

SI_BETTERUI_HEADER_SORT = "sort"
SI_GAMEPAD_BACK_OPTION = "back"
SI_BETTERUI_CLEAR_SORT = "clear"

dofile("Modules/CIM/UI/HeaderSortIntegration.lua")

local HeaderSortIntegration = BETTERUI.CIM.UI.HeaderSortIntegration

print("[HeaderSortIntegration]")

local sortChangedPayload = {}
local callbackFn

local list = {
    SetOnHitBeginningOfListCallback = function(_, cb)
        callbackFn = cb
    end,
    GetNumItems = function()
        return 3
    end,
}

local controller = {
    active = false,
    enterCount = 0,
    exitCount = 0,
    toggleCount = 0,
    clearCount = 0,
    currentColumnIndex = 1,
    columns = {
        { key = "name", name = "Name", originalText = "Name", sortFn = function() end },
        { key = "value", name = "Value", originalText = "Value", sortFn = function() end },
    },
    sortDirections = { "asc", "none" },
}

function controller:IsActive()
    return self.active
end

function controller:ToggleSort()
    self.toggleCount = self.toggleCount + 1
    self.sortDirections[self.currentColumnIndex] = "desc"
    return true
end

function controller:ClearSort()
    self.clearCount = self.clearCount + 1
    self.sortDirections[self.currentColumnIndex] = BETTERUI.CIM.UI.HeaderSortController.SORT_DIRECTION.NONE
    return true
end

function controller:NavigateLeft()
    if self.currentColumnIndex > 1 then
        self.currentColumnIndex = self.currentColumnIndex - 1
        return true
    end
    return false
end

function controller:NavigateRight()
    if self.currentColumnIndex < #self.columns then
        self.currentColumnIndex = self.currentColumnIndex + 1
        return true
    end
    return false
end

function controller:GetCurrentColumnIndex()
    return self.currentColumnIndex
end

function controller:GetActiveSortColumn()
    local column = self.columns[self.currentColumnIndex]
    return column, self.sortDirections[self.currentColumnIndex]
end

function controller:EnterHeaderMode()
    self.active = true
    self.enterCount = self.enterCount + 1
end

function controller:ExitHeaderMode()
    self.active = false
    self.exitCount = self.exitCount + 1
end

function controller:CreateKeybindDescriptor(onExit)
    return {
        {
            name = "header",
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = onExit,
        },
    }
end

local mainKeybinds = {}
local integration = HeaderSortIntegration.Setup(list, controller, {
    keybindStrip = true,
    mainKeybindDescriptor = mainKeybinds,
    onSortChanged = function(columnKey, direction, sortFn)
        table.insert(sortChangedPayload, { columnKey = columnKey, direction = direction, sortFn = sortFn })
    end,
})

assert_true(type(callbackFn) == "function", "setup hooks list beginning callback")
assert_eq(list._headerSortIntegration, integration, "setup stores integration on the list")

callbackFn()
assert_true(integration.isActive, "beginning-of-list callback enters header mode")
assert_eq(controller.enterCount, 1, "enter header mode notifies controller")

local primarySortKeybind = integration.headerModeKeybinds[1]
primarySortKeybind.callback()
assert_eq(controller.toggleCount, 1, "header primary keybind toggles sort")
assert_eq(#sortChangedPayload, 1, "sort callback is forwarded from integration")
assert_eq(sortChangedPayload[1].columnKey, "name", "sort callback reports active column key")

local clearKeybind = integration.headerModeKeybinds[3]
assert_true(clearKeybind.visible(), "clear-sort keybind is visible while the active column is sorted")
clearKeybind.callback()
assert_eq(controller.clearCount, 1, "clear-sort keybind clears the active sort state")
assert_eq(sortChangedPayload[#sortChangedPayload].direction, BETTERUI.CIM.UI.HeaderSortController.SORT_DIRECTION.NONE, "clear-sort callback reports the cleared direction")

local rightShoulderKeybind = integration.headerModeKeybinds[5]
assert_true(rightShoulderKeybind.visible(), "right-shoulder keybind is visible before the last column")
assert_eq(rightShoulderKeybind.name(), "Value", "right-shoulder keybind reports the next column label")
rightShoulderKeybind.callback()
assert_eq(controller.currentColumnIndex, 2, "right-shoulder keybind advances the active column")

local leftShoulderKeybind = integration.headerModeKeybinds[4]
assert_true(leftShoulderKeybind.visible(), "left-shoulder keybind is visible after moving off the first column")
assert_eq(leftShoulderKeybind.name(), "Name", "left-shoulder keybind reports the previous column label")
leftShoulderKeybind.callback()
assert_eq(controller.currentColumnIndex, 1, "left-shoulder keybind returns to the previous column")

local exitKeybind = integration.headerModeKeybinds[2]
exitKeybind.callback()
assert_true(not integration.isActive, "header negative keybind exits header mode")
assert_eq(controller.exitCount, 1, "exit header mode notifies controller")
assert_true(not HeaderSortIntegration.IsActive(integration), "IsActive helper reflects the exit state")
assert_true(not HeaderSortIntegration.IsActive(nil), "IsActive helper safely handles nil integrations")

local instance = {
    list = list,
    mainKeybindStripDescriptor = mainKeybinds,
    ensureHeaderKeybindCalls = 0,
}

function instance:EnsureHeaderKeybindsActive()
    self.ensureHeaderKeybindCalls = self.ensureHeaderKeybindCalls + 1
end

HeaderSortIntegration.ApplyMixin(instance, {
    list = list,
    initControllerFn = function() end,
    headerControllerFn = function()
        return controller
    end,
    keybindDescriptor = mainKeybinds,
})

instance:EnterHeaderSortMode()
assert_true(instance.isInHeaderSortMode, "mixin enter toggles header sort mode flag")
assert_eq(playedSounds[#playedSounds], SOUNDS.GAMEPAD_MENU_FORWARD, "mixin enter plays forward sound")
assert_eq(keybindOps[1], "remove", "integration enter removes main keybind group")
assert_eq(keybindOps[2], "add", "integration enter adds header keybind group")
assert_true(controller._headerSortKeybindDescriptor ~= nil, "mixin caches descriptor on the controller")

instance:ExitHeaderSortMode()
assert_true(not instance.isInHeaderSortMode, "mixin exit clears header sort mode flag")
assert_eq(playedSounds[#playedSounds], SOUNDS.GAMEPAD_MENU_BACK, "mixin exit plays back sound")
assert_eq(instance.ensureHeaderKeybindCalls, 1, "mixin exit restores header keybind activity")

local emptyListInstance = {}
HeaderSortIntegration.ApplyMixin(emptyListInstance, {
    list = {
        GetNumItems = function()
            return 0
        end,
    },
    headerControllerFn = function()
        return controller
    end,
})
emptyListInstance:EnterHeaderSortMode()
assert_true(not emptyListInstance.isInHeaderSortMode, "mixin enter is ignored when the bound list has no items")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
