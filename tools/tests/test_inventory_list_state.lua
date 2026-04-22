--[[
File: tools/tests/test_inventory_list_state.lua
Purpose: Unit tests for InventoryList list-building behavior and the
         ListStateManager switch/restore flow for craft bag state.
]]

if false then
    dofile("Modules/Inventory/Lists/InventoryList.lua")
    dofile("Modules/Inventory/State/ListStateManager.lua")
end

local registeredCallbacks = {}
local scrollIndicatorUpdates = {}
local tooltipResets = {}
local pendingClearCommits = 0
local generatedSingleSlotData = {}

BETTERUI = {
    Inventory = {
        CONST = {
            LIST_TYPES = {
                CATEGORY = "categoryList",
                ITEM = "itemList",
                CRAFT_BAG = "craftBagList",
            },
            ITEM_LIST_ACTION_MODE = 2,
            CRAFT_BAG_ACTION_MODE = 3,
        },
        Class = {},
        State = {},
        _EntryFormatting = {
            GetActiveListModuleName = function()
                return "Inventory"
            end,
            ResolveEntryModuleName = function(data)
                return data and data.listModuleName or "Inventory"
            end,
            ShouldShowMarketPrice = function()
                return true
            end,
            GetActiveNameFontSize = function()
                return 28
            end,
        },
        Categories = {
            GetBestItemCategoryDescription = function(itemData)
                return itemData.categoryDescription or itemData.category or itemData.name or "Unknown"
            end,
        },
        Utils = {},
        NewItemTracker = {},
    },
    CIM = {
        Keybinds = {},
        ScrollIndicator = {},
        SharedItemSupport = {
            GetBestItemCategoryDescription = function(itemData)
                return itemData.categoryDescription or itemData.category or itemData.name or "Unknown"
            end,
        },
    },
    GenericHeader = {},
}

function BETTERUI.Debug() end

function BETTERUI.Inventory.GetSetting(key)
    if key == "triggerSpeed" then
        return 4
    end
    return true
end

function BETTERUI.Inventory.FindCategoryIndexByKey(self, key)
    for index, entry in ipairs(self.categoryList.dataList or {}) do
        if entry.key == key then
            return index
        end
    end
    return nil
end

function BETTERUI.Inventory.GetCategoryKey(data)
    return data and data.key or nil
end

function BETTERUI.Inventory.Utils.SafeGetTargetData(list)
    if not list then
        return nil
    end
    if list.targetData then
        return list.targetData
    end
    if list.selectedData then
        return list.selectedData
    end
    if list.list then
        return list.list.targetData or list.list.selectedData
    end
    return nil
end

BETTERUI.Inventory.NewItemTracker.CommitPendingClears = function()
    pendingClearCommits = pendingClearCommits + 1
end

BETTERUI.Inventory.NewItemTracker.PrepareFromSelectedData = function(data)
    BETTERUI.Inventory.NewItemTracker.lastPrepared = data
end

BETTERUI.CIM.Keybinds.CreateListTriggerKeybinds = function()
    return { key = "LT" }, { key = "RT" }
end

BETTERUI.CIM.ScrollIndicator.Ensure = function(control)
    control.scrollIndicatorInitialized = true
end

BETTERUI.CIM.ScrollIndicator.BindListObject = function() end

BETTERUI.CIM.ScrollIndicator.Update = function(...)
    scrollIndicatorUpdates[#scrollIndicatorUpdates + 1] = { ... }
end

function BETTERUI.GenericHeader.SetTitleText(header, text)
    header.titleText = text
end

ZO_GamepadInventoryList = {}

function ZO_GamepadInventoryList:Subclass()
    local child = {}
    child.__index = child
    setmetatable(child, { __index = self })
    return child
end

function ZO_GamepadInventoryList.New(class, ...)
    local object = setmetatable({}, { __index = class })
    if object.Initialize then
        object:Initialize(...)
    end
    return object
end

function ZO_GamepadInventoryList:SetOnSelectedDataChangedCallback(callback)
    self.selectedDataChangedCallback = callback
end

function ZO_GamepadInventoryList:Activate()
    self.isActivated = true
end

function ZO_GamepadInventoryList:Deactivate()
    self.isDeactivated = true
end

function ZO_GamepadInventoryList:GetParametricList()
    return self.list
end

function ZO_GamepadInventoryList:SetupItemEntry(entry, itemData)
    entry.dataSource = itemData
    entry.slotIndex = itemData.slotIndex
end

local function createVerticalList(control)
    local list = {
        control = control,
        entries = {},
        selectedIndex = 1,
        targetSelectedIndex = 1,
    }

    function list:AddDataTemplate(templateName, setupFunction)
        self.lastTemplateName = templateName
        self.lastTemplateSetup = setupFunction
    end

    function list:AddDataTemplateWithHeader(templateName, setupFunction)
        self.lastTemplateWithHeaderName = templateName
        self.lastTemplateWithHeaderSetup = setupFunction
    end

    function list:Clear()
        self.entries = {}
    end

    function list:AddEntry(templateName, entry)
        self.entries[#self.entries + 1] = { template = templateName, entry = entry }
    end

    function list:AddEntryWithHeader(templateName, entry)
        self.entries[#self.entries + 1] = { template = templateName, entry = entry, withHeader = true }
    end

    function list:Commit()
        self.didCommit = true
    end

    function list:GetSelectedIndex()
        return self.selectedIndex
    end

    function list:GetNumEntries()
        return #self.entries
    end

    function list:GetTargetData()
        return self.targetData
    end

    function list:RefreshVisible()
        self.refreshVisibleCount = (self.refreshVisibleCount or 0) + 1
    end

    function list:SetSelectedIndexWithoutAnimation(index)
        self.selectedIndex = index
        self.targetSelectedIndex = index
        self.selectedData = self.dataList and self.dataList[index] or nil
        self.targetData = self.selectedData
    end

    return list
end

BETTERUI_VerticalParametricScrollList = {}

function BETTERUI_VerticalParametricScrollList:New(control)
    return createVerticalList(control)
end

ZO_GamepadMenuEntryTemplateParametricListFunction = function() end
ZO_SharedGamepadEntry_OnSetup = function() end

function MenuEntryTemplateEquality() end

ZO_GamepadEntryData = {}

function ZO_GamepadEntryData:New(name, iconFile)
    local entry = {
        name = name,
        iconFile = iconFile,
    }

    function entry:SetHeader(headerText)
        self.header = headerText
    end

    return entry
end

function zo_strformat(formatString, value)
    return tostring(formatString):gsub("<<1>>", tostring(value))
end

function zo_clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

SI_INVENTORY_HEADER = "<<1>>"
BAG_VIRTUAL = 999

function GetItemLinkRequiredChampionPoints(itemData)
    return itemData.requiredChampionPoints or 0
end

function ZO_Inventory_BindSlot() end

SHARED_INVENTORY = {}

function SHARED_INVENTORY:GenerateSingleSlotData(inventoryType, slotIndex)
    return generatedSingleSlotData[string.format("%s:%s", tostring(inventoryType), tostring(slotIndex))]
end

function SHARED_INVENTORY:RegisterCallback(eventName, callback)
    registeredCallbacks[eventName] = callback
end

GAMEPAD_LEFT_TOOLTIP = "left-tooltip"
GAMEPAD_RIGHT_TOOLTIP = "right-tooltip"

GAMEPAD_TOOLTIPS = {
    Reset = function(_, tooltipName)
        tooltipResets[#tooltipResets + 1] = tooltipName
    end,
}

dofile("Modules/Inventory/Lists/InventoryList.lua")
dofile("Modules/Inventory/State/ListStateManager.lua")

local tests_passed = 0
local tests_failed = 0

local function assert_equal(expected, actual, message)
    if expected == actual then
        tests_passed = tests_passed + 1
        print("  [OK] " .. message)
    else
        tests_failed = tests_failed + 1
        print("  [X] " .. message)
        print("       Expected: " .. tostring(expected))
        print("       Actual:   " .. tostring(actual))
    end
end

local function assert_true(value, message)
    assert_equal(true, value, message)
end

local function assert_same(expected, actual, message)
    assert_true(expected == actual, message)
end

local function makeControl()
    return {
        hidden = false,
        handlers = {},
        SetHandler = function(self, handlerName, callback)
            self.handlers[handlerName] = callback
        end,
        IsHidden = function(self)
            return self.hidden
        end,
    }
end

print("\n=== Inventory List / State Tests ===\n")

print("-- InventoryList initializes callbacks and rebuilds grouped entries --")
do
    registeredCallbacks = {}
    scrollIndicatorUpdates = {}
    local entrySetupCalls = 0

    local list = setmetatable({}, { __index = BETTERUI.Inventory.List })
    local control = makeControl()

    list:Initialize(control, {
        inventoryType = 5,
        slotType = "slotType",
        selectedDataCallback = function() end,
        entrySetupCallback = function()
            entrySetupCalls = entrySetupCalls + 1
            return true
        end,
        categoryResolver = function(itemData)
            return itemData.category
        end,
        sortFunction = function(left, right)
            return left.name < right.name
        end,
        useTriggers = true,
    })

    local legacyContractAccepted = pcall(function()
        list:Initialize(control, 5, "slotType")
    end)
    assert_equal(false, legacyContractAccepted, "InventoryList no longer accepts legacy positional initialization")

    assert_equal("Inventory", list.listModuleName, "InventoryList initializes with the Inventory module tag")
    assert_equal(2, #list.triggerKeybinds, "InventoryList creates both trigger keybinds")
    assert_true(control.handlers.OnEffectivelyShown ~= nil, "InventoryList wires the OnEffectivelyShown handler")
    assert_true(registeredCallbacks.FullInventoryUpdate ~= nil, "InventoryList registers the full inventory callback")
    assert_true(registeredCallbacks.SingleSlotInventoryUpdate ~= nil,
        "InventoryList registers the single-slot inventory callback")
    assert_true(list.list.lastTemplateSetup ~= nil, "InventoryList registers a row setup function")

    list.list.lastTemplateSetup({}, { bagId = 5, slotIndex = 1 }, false, false, true, true)
    assert_equal(1, entrySetupCalls, "InventoryList options initializer routes row setup through entrySetupCallback")

    generatedSingleSlotData["5:3"] = {
        slotIndex = 3,
        name = "Apple",
        category = "Consumables",
        categoryDescription = "Food",
    }

    local slots = {}
    list:AddSlotDataToTable(slots, 5, 3)
    assert_equal(1, #slots, "AddSlotDataToTable appends accepted slot data")
    assert_equal("Consumables", slots[1].bestGamepadItemCategoryName,
        "AddSlotDataToTable stores the derived category name")
    assert_equal("Food", slots[1].bestItemTypeName, "AddSlotDataToTable stores the formatted item type label")
    assert_equal("Inventory", slots[1].listModuleName, "AddSlotDataToTable tags entries with the owning module")

    list.GenerateSlotTable = function()
        return {
            { slotIndex = 2, name = "Berries", iconFile = "berries.dds", bestGamepadItemCategoryName = "Consumables" },
            { slotIndex = 1, name = "Apple", iconFile = "apple.dds", bestGamepadItemCategoryName = "Consumables" },
            { slotIndex = 9, name = "Sword", iconFile = "sword.dds", bestGamepadItemCategoryName = "Weapons" },
        }
    end

    list:RefreshList()

    assert_equal(3, #list.list.entries, "RefreshList creates one entry per generated slot")
    assert_equal("Apple", list.list.entries[1].entry.dataSource.name,
        "RefreshList honors the Initialize sortFunction override")
    assert_equal("Consumables", list.list.entries[1].entry.header, "RefreshList attaches a header for the first category")
    assert_equal("Weapons", list.list.entries[3].entry.header, "RefreshList adds a new header when the category changes")
    assert_same(list.list.entries[2].entry, list.dataBySlotIndex[2], "RefreshList indexes entries by slot index")
    assert_true(#scrollIndicatorUpdates > 0, "RefreshList updates the scroll indicator after rebuilding")
end

print("\n-- InventoryList live-update callbacks use tracked bag ids consistently --")
do
    registeredCallbacks = {}
    generatedSingleSlotData = {}

    local list = setmetatable({}, { __index = BETTERUI.Inventory.List })
    local control = makeControl()

    list:Initialize(control, {
        inventoryType = { 5, BAG_VIRTUAL },
        slotType = "slotType",
        categoryResolver = function(itemData)
            return itemData.category
        end,
        useTriggers = true,
    })

    list.RefreshList = function(self)
        self.refreshCount = (self.refreshCount or 0) + 1
    end

    list.dataBySlotIndex[7] = {}
    generatedSingleSlotData["5:7"] = {
        slotIndex = 7,
        name = "Potion",
        category = "Consumables",
        categoryDescription = "Potions",
        requiredChampionPoints = 1,
    }

    registeredCallbacks.FullInventoryUpdate(5)
    registeredCallbacks.FullInventoryUpdate(42)
    assert_equal(1, list.refreshCount, "FullInventoryUpdate only refreshes tracked bag ids")

    registeredCallbacks.SingleSlotInventoryUpdate(5, 7)
    assert_equal("Consumables", list.dataBySlotIndex[7].dataSource.bestGamepadItemCategoryName,
        "Single-slot refresh rebuilds category fields for tracked bags")
    assert_equal("Inventory", list.dataBySlotIndex[7].dataSource.listModuleName,
        "Single-slot refresh keeps the explicit list owner on rebuilt entries")
    assert_equal(1, list.dataBySlotIndex[7].dataSource.requiredChampionPoints,
        "Tracked non-virtual bags still populate champion point data")

    list.dataBySlotIndex[8] = {}
    generatedSingleSlotData["999:8"] = {
        slotIndex = 8,
        name = "Dust",
        category = "Crafting",
        categoryDescription = "Materials",
    }

    registeredCallbacks.SingleSlotInventoryUpdate(BAG_VIRTUAL, 8)
    assert_equal(nil, list.dataBySlotIndex[8].dataSource.requiredChampionPoints,
        "Virtual bag refreshes skip champion point decoration")

    list.dataBySlotIndex[9] = { untouched = true }
    registeredCallbacks.SingleSlotInventoryUpdate(42, 9)
    assert_equal(true, list.dataBySlotIndex[9].untouched, "Single-slot refresh ignores unrelated bag ids")
end

print("\n-- SwitchActiveList restores craft bag category and item position state --")
do
    pendingClearCommits = 0
    tooltipResets = {}

    local craftInnerList = {
        dataList = {
            { uniqueId = "uid-1" },
            { uniqueId = "uid-2" },
        },
        SetSelectedIndexWithoutAnimation = function(self, index)
            self.selectedIndex = index
            self.selectedData = self.dataList[index]
            self.targetData = self.selectedData
        end,
    }

    local instance = setmetatable({
        currentListType = BETTERUI.Inventory.CONST.LIST_TYPES.ITEM,
        scene = {
            IsShowing = function()
                return true
            end,
        },
        isInSelectionMode = true,
        isInCraftBagSelectionMode = true,
        savedCraftBagCategoryKey = "craft",
        savedCraftBagPositionsByKey = { craft = 2 },
        savedCraftBagSelectedItemUniqueByKey = { craft = "uid-2" },
        categoryList = {
            dataList = {
                { key = "all", text = "All Items" },
                { key = "craft", text = "Craft Bag", onClickDirection = 1 },
            },
            SetSelectedIndexWithoutAnimation = function(self, index)
                self.selectedIndex = index
                self.selectedData = self.dataList[index]
                self.targetData = self.selectedData
            end,
        },
        header = {
            tabBar = {
                SetSelectedIndexWithoutAnimation = function(self, index)
                    self.selectedIndex = index
                end,
                UpdateAnchors = function(self, index)
                    self.anchorIndex = index
                end,
            },
        },
        itemList = {
            selectedData = { name = "Inventory Item" },
        },
        craftBagList = {
            list = craftInnerList,
        },
        headerSortControllers = {
            craftBagList = {
                UpdateVisuals = function(self)
                    self.updated = true
                end,
            },
        },
        mainKeybindStripDescriptor = { id = "main" },
    }, { __index = BETTERUI.Inventory.Class })

    function instance:ExitSelectionMode()
        self.didExitSelectionMode = true
    end

    function instance:ExitCraftBagSelectionMode()
        self.didExitCraftBagSelectionMode = true
    end

    function instance:SaveListPosition()
        self.savedListPosition = (self.savedListPosition or 0) + 1
    end

    function instance:SetCurrentList(listControl)
        self.currentList = listControl
    end

    function instance:SetActiveKeybinds(descriptor)
        self.activeKeybinds = descriptor
    end

    function instance:RefreshCategoryList()
        self.categoryRefreshes = (self.categoryRefreshes or 0) + 1
    end

    function instance:RefreshCraftBagList()
        self.craftBagRefreshes = (self.craftBagRefreshes or 0) + 1
    end

    function instance:SetSelectedItemUniqueId(itemData)
        self.selectedItemUnique = itemData and itemData.uniqueId or nil
    end

    function instance:RefreshItemActions()
        self.itemActionRefreshes = (self.itemActionRefreshes or 0) + 1
    end

    function instance:RefreshHeader(blockCallback)
        self.headerBlockCallback = blockCallback
    end

    function instance:LayoutCraftBagTooltip(tooltip)
        self.lastCraftBagTooltip = tooltip
    end

    function instance:UpdateItemLeftTooltip(itemData)
        self.lastLeftTooltip = itemData
    end

    function instance:RefreshKeybinds()
        self.keybindRefreshes = (self.keybindRefreshes or 0) + 1
    end

    instance:SwitchActiveList(BETTERUI.Inventory.CONST.LIST_TYPES.CRAFT_BAG)

    assert_true(instance.didExitSelectionMode, "SwitchActiveList exits inventory multi-select mode before switching")
    assert_true(instance.didExitCraftBagSelectionMode,
        "SwitchActiveList exits craft bag multi-select mode before switching")
    assert_equal(1, instance.savedListPosition, "SwitchActiveList persists the previous list position")
    assert_equal(BETTERUI.Inventory.CONST.LIST_TYPES.CRAFT_BAG, instance.currentListType,
        "SwitchActiveList updates the active list type")
    assert_equal(BETTERUI.Inventory.CONST.LIST_TYPES.ITEM, instance.previousListType,
        "SwitchActiveList records the previous list type")
    assert_equal(1, pendingClearCommits, "SwitchActiveList commits pending new-item clear operations")
    assert_equal(2, #tooltipResets, "SwitchActiveList resets both gamepad tooltips")
    assert_same(instance.craftBagList, instance.currentList, "SwitchActiveList activates the craft bag list control")
    assert_equal(2, instance.categoryList.selectedIndex, "SwitchActiveList restores the saved craft bag category")
    assert_equal(2, craftInnerList.selectedIndex, "SwitchActiveList restores the saved craft bag item position")
    assert_equal("uid-2", instance.selectedItemUnique, "SwitchActiveList restores the saved craft bag selected item")
    assert_equal(BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE, instance.actionMode,
        "SwitchActiveList switches into craft bag action mode")
    assert_equal("Craft Bag", instance.header.titleText, "SwitchActiveList updates the header title to the restored category")
    assert_equal(GAMEPAD_LEFT_TOOLTIP, instance.lastCraftBagTooltip,
        "SwitchActiveList lays out the craft bag tooltip for the restored selection")
    assert_true(instance.headerSortControllers.craftBagList.updated,
        "SwitchActiveList refreshes the active header sort controller visuals")
    assert_equal(1, instance.keybindRefreshes, "SwitchActiveList refreshes keybinds after activation")
end

print("\n=== Summary ===")
print(string.format("Passed: %d", tests_passed))
print(string.format("Failed: %d", tests_failed))
print("")

if tests_failed > 0 then
    os.exit(1)
end
