--[[
File: tools/tests/test_vendor_list_runtime.lua
Purpose: Runtime coverage for the controller runtime's list refresh seam.
Usage:
  lua tools/tests/test_vendor_list_runtime.lua
]]

local function assert_eq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected=%s, actual=%s)", message, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, message)
    assert_eq(value == true, true, message)
end

local keybindUpdates = 0
local selectionRefreshes = 0
local scheduledTasks = {}

BETTERUI = {
    Interface = {
        UpdateCurrentKeybindGroups = function()
            if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
                KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
                return true
            end
            return false
        end,
    },
    Vendor = {
        MODE = {
            BUY = 1,
            SELL = 2,
        },
        Tasks = {
            Cancel = function()
            end,
            Schedule = function(_, taskKey, delayMs, callback)
                scheduledTasks[#scheduledTasks + 1] = {
                    key = taskKey,
                    delayMs = delayMs,
                    callback = callback,
                }
            end,
        },
        multiSelectManager = {
            RefreshSelections = function()
                selectionRefreshes = selectionRefreshes + 1
            end,
        },
        EnsureNativeStoreComponents = function()
        end,
        ShouldAbortDeferredVendorRefresh = function()
            return false
        end,
    },
    CIM = {
        UI = {
            HeaderSortController = {
                SORT_DIRECTION = {
                    NONE = 0,
                    DESCENDING = 2,
                },
            },
        },
        PositionManager = {
            RestorePosition = function()
                return 2
            end,
        },
    },
}

ZO_SORT_ORDER_UP = 1
ZO_SORT_ORDER_DOWN = 2

KEYBIND_STRIP = {
    UpdateCurrentKeybindButtonGroups = function()
        keybindUpdates = keybindUpdates + 1
    end,
}

function GetString(value)
    return tostring(value)
end

SI_GAMEPAD_INVENTORY_EMPTY = "EMPTY"
SI_BETTERUI_SEARCH_NO_RESULTS = "NO_RESULTS"

dofile("Modules/Vendor/Core/Lifecycle/VendorControllerRuntime.lua")

local ControllerRuntime = BETTERUI.Vendor.ControllerRuntime
local MODE = BETTERUI.Vendor.MODE

local buildCalls = 0
local selectedDataNotifications = 0
local noItemText = nil
local committed = false
local selectedIndex = nil

local component = {
    GetCategories = function()
        return {
            { key = "all", name = "All" },
        }
    end,
    BuildList = function(_, instance)
        buildCalls = buildCalls + 1
        instance.list.dataList = {
            { dataSource = { entryIndex = 11, name = "Oak Bow" } },
            { dataSource = { entryIndex = 15, name = "Ash Bow" } },
        }
    end,
}

local list = {
    dataList = {},
    Clear = function(self)
        self.dataList = {}
    end,
    SetNoItemText = function(_, text)
        noItemText = text
    end,
    Commit = function()
        committed = true
    end,
    SetSelectedIndexWithoutAnimation = function(self, index)
        selectedIndex = index
        self.selectedIndex = index
        self.targetData = self.dataList[index]
    end,
    GetTargetData = function(self)
        return self.targetData
    end,
}

local vendorInstance = {
    list = list,
    currentMode = MODE.BUY,
    _suppressListUpdates = false,
    _isDirty = false,
    _buyListRetryCount = 0,
    ApplyListLayoutTuning = function()
    end,
    GetActiveComponent = function()
        return component
    end,
    SetModeCategories = function(self, mode, categories)
        self.lastCategoryMode = mode
        self.lastCategories = categories
    end,
    GetCurrentMode = function(self)
        return self.currentMode
    end,
    ApplySortToList = function(self)
        ControllerRuntime.ApplySortToList(self)
        self.sortApplied = true
    end,
    EnsureColumnHeadersVisible = function(self)
        self.headersVisible = true
    end,
    IsSceneShowing = function()
        return true
    end,
    EnsureListInputActive = function(self)
        self.listInputEnsured = true
    end,
    OnItemSelectedChange = function(self, _, selectedDataArg)
        selectedDataNotifications = selectedDataNotifications + 1
        self.lastSelectedData = selectedDataArg
    end,
    RefreshCoreKeybindOwnership = function(self, reason)
        self.coreKeybindRefreshCount = (self.coreKeybindRefreshCount or 0) + 1
        self.coreKeybindRefreshReason = reason
        return true
    end,
    UpdateScrollIndicator = function(self, listArg)
        self.lastScrollIndicatorList = listArg
    end,
    IsSceneActiveOrShowing = function()
        return true
    end,
    ApplyNativeStoreMode = function(self, mode)
        self.lastAppliedNativeMode = mode
    end,
    RefreshList = function(self)
        self.refreshInvocations = (self.refreshInvocations or 0) + 1
    end,
}

ControllerRuntime.RefreshList(vendorInstance, {
    getModeModuleKey = function(mode)
        return "Vendor_" .. tostring(mode)
    end,
    getCategoryKey = function()
        return "k:all"
    end,
    resolveModeEmptyStateText = function()
        return "No vendor items"
    end,
})

assert_eq(buildCalls, 1, "controller runtime delegates row construction to the active component")
assert_eq(vendorInstance.lastCategoryMode, MODE.BUY, "controller runtime refreshes categories for the active mode")
assert_eq(#vendorInstance.lastCategories, 1, "controller runtime stores the active mode categories")
assert_eq(noItemText, "No vendor items", "controller runtime applies mode-specific empty-state text")
assert_true(vendorInstance.sortApplied == true, "controller runtime applies list sorting")
assert_eq(committed, true, "controller runtime commits the rebuilt list")
assert_eq(selectedIndex, 2, "controller runtime restores the saved list position")
assert_eq(selectionRefreshes, 1, "controller runtime refreshes multi-select overlays")
assert_true(vendorInstance.headersVisible == true, "controller runtime restores column headers")
assert_true(vendorInstance.listInputEnsured == true, "controller runtime restores list input when the scene is showing")
assert_eq(selectedDataNotifications, 1, "controller runtime replays item-selection change handlers")
assert_eq(vendorInstance.lastSelectedData.dataSource.entryIndex, 11, "controller runtime notifies selection handlers with the restored target row")
assert_eq(vendorInstance.coreKeybindRefreshCount, 1, "controller runtime re-ensures core keybind ownership after rebuilding the list")
assert_eq(vendorInstance.coreKeybindRefreshReason, "listRefresh", "controller runtime records the list-refresh keybind ownership reason")
assert_eq(keybindUpdates, 0, "controller runtime avoids blind keybind refresh when owner refresh is available")
assert_eq(vendorInstance.lastScrollIndicatorList, list, "controller runtime refreshes the scroll indicator")

local emptyList = {
    dataList = {},
    Clear = function(self)
        self.dataList = {}
    end,
    SetNoItemText = function()
    end,
    Commit = function()
    end,
    GetTargetData = function()
        return nil
    end,
}

local emptyVendorInstance = {
    list = emptyList,
    currentMode = MODE.BUY,
    _suppressListUpdates = false,
    _isDirty = false,
    _buyListRetryCount = 0,
    ApplyListLayoutTuning = function()
    end,
    GetActiveComponent = function()
        return {
            GetCategories = function()
                return {}
            end,
            BuildList = function()
            end,
        }
    end,
    SetModeCategories = function()
    end,
    GetCurrentMode = function(self)
        return self.currentMode
    end,
    ApplySortToList = function()
    end,
    EnsureColumnHeadersVisible = function()
    end,
    IsSceneShowing = function()
        return false
    end,
    IsSceneActiveOrShowing = function()
        return true
    end,
    UpdateScrollIndicator = function()
    end,
    ApplyNativeStoreMode = function(self, mode)
        self.lastAppliedNativeMode = mode
    end,
    RefreshList = function(self)
        self.refreshInvocations = (self.refreshInvocations or 0) + 1
    end,
}

ControllerRuntime.RefreshList(emptyVendorInstance, {
    getModeModuleKey = function(mode)
        return "Vendor_" .. tostring(mode)
    end,
    getCategoryKey = function()
        return "k:all"
    end,
    resolveModeEmptyStateText = function()
        return nil
    end,
})

assert_eq(scheduledTasks[#scheduledTasks].key, "buyListRetry", "controller runtime schedules buy-list retries for empty vendor buy scenes")
assert_eq(scheduledTasks[#scheduledTasks].delayMs, 180, "controller runtime reuses the established empty-buy retry delay")

print("test_vendor_list_runtime.lua: PASS")
