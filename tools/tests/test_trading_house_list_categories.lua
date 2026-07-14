-- Behavior contract for mode-owned Trading House categories.

local passed, failed = 0, 0
local function assert_eq(actual, expected, message)
    if actual ~= expected then
        failed = failed + 1
        print("FAIL: " .. message .. " (expected " .. tostring(expected)
            .. ", got " .. tostring(actual) .. ")")
    else
        passed = passed + 1
    end
end

BETTERUI = {
    TradingHouse = {},
    CIM = {
        ItemTaxonomy = {
            BANK_CATEGORY_DEFS = {
                { key = "all", nameStringId = "ALL", iconFile = "all.dds" },
                { key = "weapons", nameStringId = "WEAPONS", iconFile = "weapons.dds", filterType = 10 },
                { key = "misc", nameStringId = "MISC", iconFile = "misc.dds", filterType = 99 },
            },
        },
    },
}

function GetString(id)
    return ({ ALL = "All Items", WEAPONS = "Weapons", MISC = "Miscellaneous" })[id]
end

function GetItemLinkFilterTypeInfo(itemLink)
    return itemLink == "weapon-link" and 10 or 99
end

dofile("Modules/TradingHouse/Core/ListCategories.lua")

local Categories = BETTERUI.TradingHouse.ListCategories
local component = { selectedCategoryKey = "__all" }
local rows = {
    Categories.Annotate({ name = "Sword", itemLink = "weapon-link" }),
    Categories.Annotate({ name = "Rock", itemLink = "misc-link" }),
}

local filtered = Categories.Prepare(component, rows)
assert_eq(#filtered, 2, "All Items preserves every row")
assert_eq(#component.categories, 3, "Category list contains All plus populated categories")
assert_eq(component.categories[1].key, "__all", "All Items is always first")
assert_eq(component.categories[2].key, "weapons", "Taxonomy order is stable")
assert_eq(rows[1].listCategoryIcon, "weapons.dds", "Rows use taxonomy icons")
assert_eq(component.categories[1].filterType, nil,
    "All Items keeps the unfiltered gold icon tint")
assert_eq(component.categories[2].filterType, 10, "Populated categories retain their filter tint metadata")

component.selectedCategoryKey = "weapons"
filtered = Categories.Prepare(component, rows)
assert_eq(#filtered, 1, "Selected category filters the active list")
assert_eq(filtered[1].name, "Sword", "Only matching rows survive filtering")

component.selectedCategoryKey = "missing"
filtered = Categories.Prepare(component, rows)
assert_eq(component.selectedCategoryKey, "__all", "Missing categories fall back to All Items")
assert_eq(#filtered, 2, "Fallback restores the complete list")

local refreshCount = 0
local instance = { RefreshList = function() refreshCount = refreshCount + 1 end }
Categories.Set(component, "weapons", instance)
Categories.Set(component, "weapons", instance)
assert_eq(refreshCount, 1, "Category changes refresh once and same-selection callbacks are inert")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
