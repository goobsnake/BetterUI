--[[
File: tools/tests/test_vendor_multiselect_focus.lua
Purpose: Regression coverage for vendor multi-select focus retention.
]]

BETTERUI = { CIM = {} }
local keybindRefreshCount = 0

KEYBIND_STRIP = {
    UpdateCurrentKeybindButtonGroups = function()
        keybindRefreshCount = keybindRefreshCount + 1
    end,
}

function zo_clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

dofile("Modules/CIM/Core/Data/PositionManager.lua")

local PositionManager = BETTERUI.CIM.PositionManager

local function assertEq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected=%s, actual=%s)", message, tostring(expected), tostring(actual)))
    end
end

local function buildList(rows, selectedIndex)
    local list = {
        dataList = rows,
        selectedIndex = selectedIndex,
        selectedData = rows[selectedIndex],
        targetData = rows[selectedIndex],
    }

    function list:SetSelectedIndex(index)
        self.selectedIndex = index
        self.targetData = self.dataList[index]
    end

    function list:SetSelectedIndexWithoutAnimation(index)
        self.selectedIndex = index
        self.selectedData = self.dataList[index]
        self.targetData = self.dataList[index]
    end

    function list:GetSelectedData()
        return self.selectedData
    end

    function list:GetTargetData()
        return self.targetData
    end

    return list
end

local VendorClass = {}
VendorClass.__index = VendorClass

function VendorClass:New(mode, list)
    return setmetatable({
        currentMode = mode,
        list = list,
    }, self)
end

function VendorClass:GetCurrentMode()
    return self.currentMode
end

function VendorClass:IsSceneShowing()
    return true
end

function VendorClass:RefreshVendorActionKeybinds()
    if not (KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups) then
        return
    end
    if self.IsSceneShowing and not self:IsSceneShowing() then
        return
    end
    KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
end

function VendorClass:OnItemSelectedChange()
    self:RefreshVendorActionKeybinds()
end

function VendorClass:SaveListPosition()
    local currentMode = self:GetCurrentMode()
    if not currentMode or not self.list then
        return
    end

    PositionManager.SavePosition("Vendor", "mode_" .. currentMode, self.list)
end

function VendorClass:RefreshList()
    local currentMode = self:GetCurrentMode()
    local targetIndex = PositionManager.RestorePosition("Vendor", "mode_" .. currentMode, self.list, self.list.dataList)
    if self.list.SetSelectedIndexWithoutAnimation then
        self.list:SetSelectedIndexWithoutAnimation(targetIndex)
    else
        self.list:SetSelectedIndex(targetIndex)
    end
end

local function buildMultiSelectManager()
    local manager = {
        active = false,
        selected = {},
        selectionCount = 0,
    }

    function manager:EnterSelectionMode()
        self.active = true
    end

    function manager:IsActive()
        return self.active
    end

    function manager:GetSelectedCount()
        return self.selectionCount
    end

    function manager:IsSelected(itemData)
        return self.selected[itemData] == true
    end

    function manager:Select(itemData)
        if not self.selected[itemData] then
            self.selected[itemData] = true
            self.selectionCount = self.selectionCount + 1
        end
    end

    return manager
end

local function enterVendorSelectionMode(vendor, manager)
    vendor:SaveListPosition()
    manager:EnterSelectionMode()
    local target = vendor.list:GetTargetData()
    if not target then
        target = vendor.list:GetSelectedData()
    end
    if target then
        manager:Select(target)
    end
    vendor:RefreshList()
end

local function getPrimaryMultiSelectLabel(list, manager)
    local selectedData = nil
    if list.GetTargetData then
        selectedData = list:GetTargetData()
    end
    if selectedData and manager:IsSelected(selectedData) then
        return "Deselect"
    end
    if manager:GetSelectedCount() > 0 then
        return string.format("Select (%d)", manager:GetSelectedCount())
    end
    return "Select"
end

PositionManager.ClearModule("Vendor")

local entryRows = {
    { dataSource = { entryIndex = 1, name = "Row One" } },
    { dataSource = { entryIndex = 2, name = "Row Two" } },
    { dataSource = { entryIndex = 3, name = "Row Three" } },
}

do
    local vendor = VendorClass:New(1, buildList(entryRows, 2))
    vendor.list = buildList(entryRows, 1)
    vendor:RefreshList()
    assertEq(vendor.list.selectedIndex, 1, "unsaved refresh falls back to the top entry")
end

PositionManager.ClearModule("Vendor")

do
    local vendor = VendorClass:New(1, buildList(entryRows, 2))
    vendor:SaveListPosition()
    vendor.list = buildList(entryRows, 1)
    vendor:RefreshList()
    assertEq(vendor.list.selectedIndex, 2, "saved entry-index rows restore the highlighted position")
end

PositionManager.ClearModule("Vendor")

do
    local originalRows = {
        { uniqueId = "a", name = "A" },
        { uniqueId = "b", name = "B" },
        { uniqueId = "c", name = "C" },
    }
    local rebuiltRows = {
        { uniqueId = "c", name = "C" },
        { uniqueId = "a", name = "A" },
        { uniqueId = "b", name = "B" },
    }
    local vendor = VendorClass:New(2, buildList(originalRows, 2))
    vendor:SaveListPosition()
    vendor.list = buildList(rebuiltRows, 1)
    vendor:RefreshList()
    assertEq(vendor.list.selectedIndex, 3, "unique-id rows restore the same item after a rebuild")
end

do
    local vendor = VendorClass:New(3, buildList(entryRows, 2))
    local manager = buildMultiSelectManager()

    enterVendorSelectionMode(vendor, manager)

    assertEq(manager:GetSelectedCount(), 1, "entering vendor multi-select auto-selects the focused row")
    assertEq(getPrimaryMultiSelectLabel(vendor.list, manager), "Deselect", "primary keybind changes to Deselect for the focused selected row")
end

do
    local vendor = VendorClass:New(4, buildList(entryRows, 2))
    local manager = buildMultiSelectManager()

    manager:EnterSelectionMode()
    manager:Select(entryRows[1])
    vendor.list.selectedData = entryRows[1]
    vendor.list.targetData = entryRows[2]

    assertEq(getPrimaryMultiSelectLabel(vendor.list, manager), "Select (1)", "deselect text only appears for the currently focused selected row")
end

do
    local vendor = VendorClass:New(5, buildList(entryRows, 2))
    local manager = buildMultiSelectManager()

    manager:EnterSelectionMode()
    manager:Select(entryRows[1])
    vendor.list.selectedData = entryRows[1]
    vendor.list.targetData = nil

    assertEq(getPrimaryMultiSelectLabel(vendor.list, manager), "Select (1)", "deselect text does not fall back to a stale selected row when no live target exists")
end

do
    keybindRefreshCount = 0
    local vendor = VendorClass:New(6, buildList(entryRows, 2))

    vendor:OnItemSelectedChange(vendor.list, vendor.list:GetTargetData())
    assertEq(keybindRefreshCount, 1, "changing the focused vendor row refreshes the active keybind strip")
end

print("test_vendor_multiselect_focus.lua: PASS")