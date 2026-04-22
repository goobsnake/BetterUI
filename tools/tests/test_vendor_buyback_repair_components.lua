--[[
File: tools/tests/test_vendor_buyback_repair_components.lua
Purpose: Direct regression coverage for vendor buyback and repair components.
]]

CURT_MONEY = 1
ITEMTYPE_NONE = 0
ITEM_DISPLAY_QUALITY_NORMAL = 1

BAG_WORN = 1
BAG_BACKPACK = 2

SI_ITEM_ACTION_BUYBACK = "Buyback"
SI_ITEM_ACTION_REPAIR = "Repair"
SI_BETTERUI_VENDOR_CANNOT_AFFORD = "Cannot afford"
SI_BETTERUI_VENDOR_CONDITION = "Condition: <<1>>"
SI_TOOLTIP_ITEM_NAME = "<<1>>"

local testsPassed = 0
local alertCalls = {}
local buybackCalls = {}
local repairItemCalls = {}
local repairAllCalls = 0
local shownDialogs = {}

local buybackRows = {
    [1] = {
        icon = "buyback_blade",
        name = "Steel Blade",
        stackCount = 1,
        price = 75,
        functionalQuality = 2,
        meetsRequirements = true,
        displayQuality = 3,
    },
    [2] = {
        icon = "buyback_staff",
        name = "Oak Staff",
        stackCount = 1,
        price = 120,
        functionalQuality = 1,
        meetsRequirements = true,
        displayQuality = 2,
    },
}

local repairState = {
    bagSizes = {
        [BAG_WORN] = 2,
        [BAG_BACKPACK] = 2,
    },
    conditions = {
        [BAG_WORN] = {
            [0] = 60,
            [1] = 100,
        },
        [BAG_BACKPACK] = {
            [0] = 30,
            [1] = 100,
        },
    },
    names = {
        [BAG_WORN] = {
            [0] = "Travel Sword",
            [1] = "Polished Helm",
        },
        [BAG_BACKPACK] = {
            [0] = "Backup Blade",
            [1] = "Fresh Apple",
        },
    },
    icons = {
        [BAG_WORN] = {
            [0] = "repair_sword",
            [1] = "repair_helm",
        },
        [BAG_BACKPACK] = {
            [0] = "repair_blade",
            [1] = "repair_apple",
        },
    },
    qualities = {
        [BAG_WORN] = {
            [0] = 3,
            [1] = 2,
        },
        [BAG_BACKPACK] = {
            [0] = 2,
            [1] = 1,
        },
    },
    repairCosts = {
        [BAG_WORN] = {
            [0] = 45,
            [1] = 0,
        },
        [BAG_BACKPACK] = {
            [0] = 15,
            [1] = 0,
        },
    },
}

local function assertEq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected=%s, actual=%s)", message, tostring(expected), tostring(actual)))
    end
    testsPassed = testsPassed + 1
end

local function assertTrue(value, message)
    assertEq(value == true, true, message)
end

function GetString(id)
    return tostring(id or "")
end

function zo_strformat(fmt, value)
    if fmt == SI_TOOLTIP_ITEM_NAME then
        return tostring(value or "")
    end
    return (tostring(fmt or ""):gsub("<<1>>", tostring(value or "")))
end

function GetItemQualityColor()
    return {
        UnpackRGBA = function()
            return 1, 1, 1, 1
        end,
    }
end

function GetItemLinkItemType(itemLink)
    if itemLink == "buyback:1" then
        return 100
    end
    return ITEMTYPE_NONE
end

function GetNumBuybackItems()
    return 2
end

function GetBuybackItemInfo(entryIndex)
    local row = buybackRows[entryIndex]
    return row.icon, row.name, row.stackCount, row.price, row.functionalQuality, row.meetsRequirements, row.displayQuality
end

function GetBuybackItemLink(entryIndex)
    return "buyback:" .. tostring(entryIndex)
end

function BuybackItem(entryIndex)
    buybackCalls[#buybackCalls + 1] = entryIndex
end

function GetBagSize(bagId)
    return repairState.bagSizes[bagId] or 0
end

function GetItemCondition(bagId, slotIndex)
    return repairState.conditions[bagId][slotIndex]
end

function GetItemInfo(bagId, slotIndex)
    return repairState.icons[bagId][slotIndex], 1, nil, nil, nil, nil, nil, repairState.qualities[bagId][slotIndex]
end

function GetItemName(bagId, slotIndex)
    return repairState.names[bagId][slotIndex]
end

function GetItemRepairCost(bagId, slotIndex)
    return repairState.repairCosts[bagId][slotIndex]
end

function GetItemLink(bagId, slotIndex)
    return string.format("repair:%d:%d", bagId, slotIndex)
end

function GetRepairAllCost()
    return 120
end

function ZO_CurrencyControl_FormatCurrencyAndAppendIcon()
    return "120g"
end

function ZO_Dialogs_ShowGamepadDialog(dialogName, payload)
    shownDialogs[#shownDialogs + 1] = { dialogName = dialogName, payload = payload }
end

function RepairItem(bagId, slotIndex)
    repairItemCalls[#repairItemCalls + 1] = { bagId = bagId, slotIndex = slotIndex }
end

function RepairAll()
    repairAllCalls = repairAllCalls + 1
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
    CIM = {
        UserAlertText = function(tag, message)
            alertCalls[#alertCalls + 1] = { tag = tag, message = message }
        end,
    },
}

dofile("Modules/Vendor/Components/BuybackComponent.lua")
dofile("Modules/Vendor/Components/RepairComponent.lua")

local Buyback = BETTERUI.Vendor.BuybackComponent
local Repair = BETTERUI.Vendor.RepairComponent

local function newList()
    return {
        entries = {},
        selectedData = nil,
        GetSelectedData = function(self)
            return self.selectedData
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

do
    local vendor = {
        list = newList(),
        CanAfford = function(_, price)
            return price <= 75
        end,
        HasInventorySpace = function()
            return true
        end,
    }
    vendor.list.selectedData = { dataSource = { entryIndex = 1, price = 75 } }

    assertEq(Buyback:GetPrimaryActionName(), "Buyback", "buyback component reports the localized primary action label")
    assertTrue(Buyback:IsPrimaryActionEnabled(vendor), "buyback primary action enables for affordable rows with inventory space")

    Buyback:OnPrimaryAction(vendor)
    assertEq(buybackCalls[#buybackCalls], 1, "buyback action repurchases the selected entry")

    vendor.CanAfford = function()
        return false
    end
    Buyback:OnPrimaryAction(vendor)
    assertEq(alertCalls[#alertCalls].tag, "Buyback:CannotAfford", "buyback action alerts when the selected row is unaffordable")

    vendor.CanAfford = function()
        return true
    end
    vendor.HasInventorySpace = function()
        return false
    end
    Buyback:OnPrimaryAction(vendor)
    assertEq(alertCalls[#alertCalls].tag, "Buyback:CannotCarry", "buyback action alerts when the inventory is full")
end

do
    local vendor = {
        list = newList(),
        searchQuery = "blade",
    }

    Buyback:BuildList(vendor)
    assertEq(#vendor.list.entries, 1, "buyback list keeps only rows matching the active search query")
    assertEq(vendor.list.entries[1].dataSource.entryIndex, 1, "buyback list preserves the original buyback entry index")
end

do
    local vendor = {
        list = newList(),
        CanAfford = function(_, price)
            return price <= 45
        end,
    }
    vendor.list.selectedData = { dataSource = { repairCost = 45, bagId = BAG_WORN, slotIndex = 0 } }

    assertEq(Repair:GetPrimaryActionName(), "Repair", "repair component reports the localized primary action label")
    assertTrue(Repair:IsPrimaryActionEnabled(vendor), "repair primary action enables for damaged affordable items")

    Repair:OnPrimaryAction(vendor)
    assertEq(repairItemCalls[#repairItemCalls].bagId, BAG_WORN, "repair action uses the selected bag id")
    assertEq(repairItemCalls[#repairItemCalls].slotIndex, 0, "repair action uses the selected slot index")

    vendor.CanAfford = function()
        return false
    end
    Repair:OnPrimaryAction(vendor)
    assertEq(alertCalls[#alertCalls].tag, "Repair:CannotAfford", "repair action alerts when the selected row is unaffordable")
end

do
    local vendor = {
        CanAfford = function(_, price)
            return price <= 120
        end,
    }

    Repair:RepairAll(vendor)
    assertEq(shownDialogs[#shownDialogs].dialogName, "REPAIR_ALL", "repair all opens the native repair-all confirmation dialog")
    assertEq(shownDialogs[#shownDialogs].payload.cost, 120, "repair all passes the native dialog the aggregate repair cost")

    shownDialogs[#shownDialogs].payload.callback()
    assertEq(repairAllCalls, 1, "repair all dialog callback executes the native repair-all action")

    vendor.CanAfford = function()
        return false
    end
    Repair:RepairAll(vendor)
    assertEq(alertCalls[#alertCalls].tag, "Repair:CannotAffordAll", "repair all alerts when the aggregate repair cost is unaffordable")
end

do
    local vendor = {
        list = newList(),
        searchQuery = "blade",
    }

    Repair:BuildList(vendor)
    assertEq(#vendor.list.entries, 1, "repair list keeps only damaged rows matching the active search query")
    assertEq(vendor.list.entries[1].dataSource.repairCost, 15, "repair list exposes the selected row repair cost")
    assertEq(vendor.list.entries[1].dataSource.statValue, "Condition: 30", "repair list formats the condition label for the UI")
end

print(string.format("test_vendor_buyback_repair_components.lua: %d assertions passed", testsPassed))
