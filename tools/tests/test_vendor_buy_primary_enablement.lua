--[[
File: tools/tests/test_vendor_buy_primary_enablement.lua
Purpose: Direct regression coverage for vendor buy component enablement and buy-side list building.
]]

CURT_NONE = 0
CURT_MONEY = 1

ITEMFILTERTYPE_WEAPONS = 1
ITEMFILTERTYPE_ARMOR = 2
ITEMFILTERTYPE_JEWELRY = 3
ITEMFILTERTYPE_CONSUMABLE = 4
ITEMFILTERTYPE_CRAFTING = 5
ITEMFILTERTYPE_FURNISHING = 6

ITEMTYPE_NONE = 0
ITEM_DISPLAY_QUALITY_NORMAL = 1
ITEM_TRAIT_TYPE_NONE = 0

SI_ITEM_ACTION_BUY = "Buy"
SI_TOOLTIP_ITEM_NAME = "<<1>>"
SI_BETTERUI_VENDOR_CANNOT_AFFORD = "Cannot afford"
SI_BETTERUI_VENDOR_CANNOT_CARRY = "Cannot carry"
SI_BETTERUI_INV_ITEM_ALL = "All"
SI_BETTERUI_INV_ITEM_WEAPONS = "Weapons"
SI_BETTERUI_INV_ITEM_APPAREL = "Apparel"
SI_BETTERUI_INV_ITEM_JEWELRY = "Jewelry"
SI_BETTERUI_INV_ITEM_CONSUMABLE = "Consumable"
SI_BETTERUI_INV_ITEM_MATERIALS = "Materials"
SI_BETTERUI_INV_ITEM_FURNISHING = "Furnishing"
SI_BETTERUI_INV_ITEM_MISC = "Misc"

local testsPassed = 0
local buyCalls = {}
local alertCalls = {}
local ensureCalls = {}
local cancelCalls = {}
local scheduledTasks = {}
local applyModeCalls = {}
local refreshCount = 0

local itemTypesByLink = {
    ["link:1"] = 100,
    ["link:2"] = 200,
    ["link:3"] = ITEMTYPE_NONE,
}

local itemTypeNames = {
    [100] = "Weapons",
    [200] = "Armor",
}

local traitNames = {
    [9] = "Charged",
}

local storeRows = {
    [1] = {
        icon = "icon_sword",
        name = "Iron Sword",
        stack = 1,
        price = 25,
        sellPrice = 8,
        meetsReqsToBuy = true,
        displayQuality = 3,
        currencyType1 = CURT_MONEY,
        currencyQuantity1 = 25,
        entryType = 10,
        filterData = { ITEMFILTERTYPE_WEAPONS },
        statValue = "Damage 10",
    },
    [2] = {
        icon = "icon_armor",
        name = "Leather Jerkin",
        stack = 1,
        price = 40,
        sellPrice = 15,
        meetsReqsToBuy = true,
        displayQuality = 2,
        currencyType1 = CURT_MONEY,
        currencyQuantity1 = 40,
        entryType = 20,
        filterData = { ITEMFILTERTYPE_ARMOR },
        statValue = "Armor 12",
    },
    [3] = {
        icon = "icon_apple",
        name = "Apple",
        stack = 5,
        price = 5,
        sellPrice = 1,
        meetsReqsToBuy = true,
        displayQuality = 1,
        currencyType1 = CURT_NONE,
        currencyQuantity1 = 5,
        entryType = 30,
        filterData = {},
        statValue = "Fresh",
    },
}

local unpackValues = table.unpack or unpack

local function assertEq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected=%s, actual=%s)", message, tostring(expected), tostring(actual)))
    end
    testsPassed = testsPassed + 1
end

local function assertTrue(value, message)
    assertEq(value == true, true, message)
end

function GetString(id, value)
    if id == "SI_ITEMTYPE" then
        return itemTypeNames[value] or tostring(value or "")
    end
    if id == "SI_ITEMTRAITTYPE" then
        return traitNames[value] or tostring(value or "")
    end
    return tostring(id or "")
end

function zo_strformat(fmt, value)
    if fmt == SI_TOOLTIP_ITEM_NAME then
        return tostring(value or "")
    end
    return (tostring(fmt or ""):gsub("<<1>>", tostring(value or "")))
end

function GetStoreEntryInfo(entryIndex)
    local row = storeRows[entryIndex]
    if not row then
        return nil
    end

    return row.icon, row.name, row.stack, row.price, row.sellPrice, row.meetsReqsToBuy, nil,
        row.displayQuality, nil, row.currencyType1, row.currencyQuantity1, nil, nil, row.entryType
end

function GetNumStoreItems()
    return 3
end

function GetStoreItemLink(entryIndex)
    return "link:" .. tostring(entryIndex)
end

function GetStoreEntryTypeInfo(entryIndex)
    local row = storeRows[entryIndex]
    return unpackValues(row and row.filterData or {})
end

function GetStoreEntryStatValue(entryIndex)
    local row = storeRows[entryIndex]
    return row and row.statValue or ""
end

function GetItemLinkItemType(itemLink)
    return itemTypesByLink[itemLink] or ITEMTYPE_NONE
end

function GetItemLinkTraitInfo(itemLink)
    if itemLink == "link:1" then
        return 9
    end
    return ITEM_TRAIT_TYPE_NONE
end

function GetItemQualityColor()
    return {
        UnpackRGBA = function()
            return 1, 1, 1, 1
        end,
    }
end

function BuyStoreItem(entryIndex, quantity)
    buyCalls[#buyCalls + 1] = { entryIndex = entryIndex, quantity = quantity }
end

ZO_ColorDef = {
    New = function(_, r, g, b, a)
        return { r = r, g = g, b = b, a = a }
    end,
}

ZO_GamepadEntryData = {
    New = function(name, icon)
        return {
            name = name,
            icon = icon,
            SetDataSource = function(self, dataSource)
                self.dataSource = dataSource
            end,
            SetNameColors = function(self, activeColor, inactiveColor)
                self.activeColor = activeColor
                self.inactiveColor = inactiveColor
            end,
        }
    end,
}

BETTERUI = {
    Vendor = {
        MODE = {
            BUY = 1,
        },
        ExecuteSafely = function(_, callback, ...)
            local ok, a, b, c, d = pcall(callback, ...)
            if not ok then
                return false
            end
            return true, a, b, c, d
        end,
        EnsureNativeStoreComponents = function(componentName)
            ensureCalls[#ensureCalls + 1] = componentName
        end,
        Tasks = {
            Cancel = function(_, taskId)
                cancelCalls[#cancelCalls + 1] = taskId
            end,
            Schedule = function(_, taskId, delayMs, callback)
                scheduledTasks[taskId] = { delayMs = delayMs, callback = callback }
            end,
        },
        ShouldAbortDeferredVendorRefresh = function()
            return false
        end,
        NormalizeSearchQuery = function(query)
            local normalized = query and string.lower(query) or nil
            if normalized == "" then
                return nil
            end
            return normalized
        end,
        MatchesSearchQuery = function(query, name)
            if not query or query == "" then
                return true
            end
            return string.find(string.lower(name or ""), query, 1, true) ~= nil
        end,
    },
    Utils = {
        SafeGetTargetData = function(list)
            return list:GetTargetData()
        end,
    },
    CIM = {
        UserAlertText = function(tag, message)
            alertCalls[#alertCalls + 1] = { tag = tag, message = message }
        end,
    },
}

dofile("Modules/CIM/Core/Data/ItemTaxonomy.lua")
dofile("Modules/Vendor/Components/BuyComponent.lua")

local Buy = BETTERUI.Vendor.BuyComponent

local function newList()
    return {
        entries = {},
        selectedData = nil,
        targetData = nil,
        GetSelectedData = function(self)
            return self.selectedData
        end,
        GetTargetData = function(self)
            return self.targetData
        end,
        AddEntry = function(self, templateName, entry)
            self.entries[#self.entries + 1] = {
                templateName = templateName,
                entry = entry,
                dataSource = entry.dataSource,
            }
        end,
    }
end

local function newVendor()
    local list = newList()
    return {
        list = list,
        currentCategory = { key = "weapons", filterType = ITEMFILTERTYPE_WEAPONS },
        searchQuery = nil,
        CanAfford = function(_, price, currencyType)
            return price == 25 and currencyType == CURT_MONEY
        end,
        HasInventorySpace = function()
            return true
        end,
        GetCurrentCategory = function(self)
            return self.currentCategory
        end,
        ApplyNativeStoreMode = function(_, mode)
            applyModeCalls[#applyModeCalls + 1] = mode
        end,
        RefreshList = function()
            refreshCount = refreshCount + 1
        end,
    }
end

do
    local vendor = newVendor()
    local categories = Buy:GetCategories(vendor)
    local counts = {}
    for _, category in ipairs(categories) do
        counts[category.key] = category.itemCount
    end

    assertEq(counts.all, 3, "buy categories include all visible store rows")
    assertEq(counts.weapons, 1, "buy categories count weapon rows")
    assertEq(counts.apparel, 1, "buy categories count armor rows")
    assertEq(counts.misc, 1, "buy categories route uncategorized rows into misc")
    assertEq(applyModeCalls[1], BETTERUI.Vendor.MODE.BUY, "buy categories request the native buy mode before reading store data")
end

do
    local vendor = newVendor()
    vendor.searchQuery = "sword"
    Buy:BuildList(vendor)

    assertEq(ensureCalls[#ensureCalls], "storeTextSearch", "buy list ensures the native store search bridge is available")
    assertEq(#vendor.list.entries, 1, "buy list keeps only rows matching the active category and search query")
    assertEq(vendor.list.entries[1].dataSource.entryIndex, 1, "buy list entry keeps the store entry index")
    assertEq(vendor.list.entries[1].dataSource.traitName, "Charged", "buy list decorates rows with trait text when trait data exists")
end

do
    local vendor = newVendor()
    vendor.list.selectedData = { dataSource = { entryIndex = 2, price = 999, currencyType = CURT_MONEY } }
    vendor.list.targetData = { dataSource = { entryIndex = 1, price = 25, currencyType = CURT_NONE } }

    assertTrue(Buy:IsPrimaryActionEnabled(vendor), "buy primary action uses focused target data and treats CURT_NONE as money")
    Buy:OnPrimaryAction(vendor)
    assertEq(buyCalls[#buyCalls].entryIndex, 1, "buy action purchases the focused store entry")
    assertEq(buyCalls[#buyCalls].quantity, 1, "buy action purchases a single item")
end

do
    local vendor = newVendor()
    vendor.CanAfford = function()
        return false
    end
    vendor.list.targetData = { dataSource = { entryIndex = 1, price = 25, currencyType = CURT_MONEY } }

    Buy:OnPrimaryAction(vendor)
    assertEq(alertCalls[#alertCalls].tag, "Buy:CannotAfford", "buy action alerts when the focused item is unaffordable")
end

do
    local vendor = newVendor()
    vendor.HasInventorySpace = function()
        return false
    end
    vendor.list.targetData = { dataSource = { entryIndex = 1, price = 25, currencyType = CURT_MONEY } }

    Buy:OnPrimaryAction(vendor)
    assertEq(alertCalls[#alertCalls].tag, "Buy:CannotCarry", "buy action alerts when the inventory is full")
end

do
    local vendor = newVendor()
    Buy:Activate(vendor)
    assertEq(refreshCount, 1, "buy activate refreshes the vendor list immediately")
    assertEq(cancelCalls[#cancelCalls], "buyActivateRefresh", "buy activate cancels any pending deferred refresh before rescheduling")
    assertEq(scheduledTasks.buyActivateRefresh.delayMs, 120, "buy activate schedules a deferred refresh to catch native store races")

    scheduledTasks.buyActivateRefresh.callback()
    assertEq(applyModeCalls[#applyModeCalls], BETTERUI.Vendor.MODE.BUY, "deferred buy refresh reapplies the native buy mode")
    assertEq(refreshCount, 2, "deferred buy refresh runs the vendor refresh a second time")
end

print(string.format("test_vendor_buy_primary_enablement.lua: %d assertions passed", testsPassed))
