-- Regression: Inventory's ethereal LB/RB carousel must not act in foreign scenes.
BETTERUI = {
    Inventory = {},
    CIM = {
        Utils = {},
        HeaderNavigation = {},
    },
    GenericHeader = {
        SetTitleText = function() end,
    },
}

local cycleCount = 0
function BETTERUI.CIM.HeaderNavigation.CycleCategory(parent, step, options)
    cycleCount = cycleCount + 1
    local index = options.getCurrentIndex()
    options.setCurrentIndex(index + step)
    options.onRefresh()
end

dofile("Modules/Inventory/Core/Utils.lua")

local showing = false
local savedPositionCount = 0
local parent = {
    scene = {
        IsShowing = function() return showing end,
    },
    categoryList = {
        dataList = {
            { text = "All" },
            { text = "Equipped" },
        },
        selectedIndex = 1,
        targetSelectedIndex = 1,
        selectedData = { text = "All" },
    },
    header = {},
    ToSavedPosition = function()
        savedPositionCount = savedPositionCount + 1
    end,
}

assert(BETTERUI.Inventory.Utils.OnTabNext(parent, true) == false,
    "foreign-scene bumper callback must fail closed")
assert(cycleCount == 0, "foreign-scene callback must not cycle hidden categories")
assert(savedPositionCount == 0, "foreign-scene callback must not refresh hidden inventory")

showing = true
assert(BETTERUI.Inventory.Utils.OnTabNext(parent, true) == true,
    "inventory-scene bumper callback must remain active")
assert(cycleCount == 1, "inventory-scene callback must cycle categories")
assert(savedPositionCount == 1, "inventory-scene callback must refresh normally")

showing = false
assert(BETTERUI.Inventory.Utils.OnTabPrev(parent, true) == false,
    "foreign-scene previous callback must also fail closed")
assert(cycleCount == 1, "foreign-scene previous callback must not cycle categories")

print("inventory carousel ownership regression tests passed")
