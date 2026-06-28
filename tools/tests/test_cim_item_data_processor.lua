--[[
File: tools/tests/test_cim_item_data_processor.lua
Purpose: Unit tests for CIM item-entry factory behavior around list module context propagation.

Regression: item entries should use the caller-provided owning module name instead of
reusing stale list-module context from shared slot data.
]]

BETTERUI = {
    CIM = {},
    Debug = function() end,
}

ZO_GamepadEntryData = {}

function ZO_GamepadEntryData:New(name, icon)
    local row = {
        _name = name,
        _icon = icon,
    }

    function row:SetCooldown()
    end

    function row:SetDataSource(source)
        self.dataSource = source
    end

    function row:SetNameColors()
    end

    function row:SetHeader()
    end

    function row:SetFontScaleOnSelection()
    end

    function row:ClearIcons()
    end

    function row:AddIcon()
    end

    return row
end

function GetItemCooldownInfo()
    return nil, nil
end

function GetQuestToolCooldownInfo()
    return nil, nil
end

function GetQuestItemCooldownInfo()
    return nil, nil
end

local passed = 0
local failed = 0

local function assert_equal(expected, actual, message)
    if expected == actual then
        passed = passed + 1
        print("  [OK] " .. message)
    else
        failed = failed + 1
        print("  [X] " .. message)
        print("    Expected: " .. tostring(expected))
        print("    Actual: " .. tostring(actual))
    end
end

local function assert_true(value, message)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        print("  [X] " .. message)
        print("    Expected: true")
        print("    Actual: " .. tostring(value))
    end
end

dofile("Modules/CIM/Lists/ItemDataProcessor.lua")

print("\n=== CIM Item Data Processor Tests ===\n")

local sourceData = {
    name = "Example Item",
    iconFile = "item.dds",
    listModuleName = "Inventory",
}

local function attachDataSource(row, sourceData)
    row:SetDataSource(sourceData)
end

local bankingRow = BETTERUI.CIM.CreateItemEntryData(sourceData, {
    visualDataInit = attachDataSource,
    listModuleName = "Banking",
})

assert_equal("Banking", bankingRow.listModuleName, "Caller-provided module name wins over source module name")
assert_equal("Banking", sourceData.listModuleName, "Caller-provided module name is propagated back to slot data")
assert_equal("Banking", bankingRow.dataSource.listModuleName, "Row data source receives caller-provided module name")

local inventoryRow = BETTERUI.CIM.CreateItemEntryData({
    name = "Inventory-Source Item",
    iconFile = "item2.dds",
    listModuleName = "Inventory",
}, {})
assert_equal("Inventory", inventoryRow.listModuleName, "Fallback preserves source listModuleName when option omitted")

print("\n=== SUMMARY ===")
print("  Passed: " .. passed)
print("  Failed: " .. failed)

if failed > 0 then
    os.exit(1)
end
