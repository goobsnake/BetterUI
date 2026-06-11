--[[
File: Modules/CIM/Core/Data/ItemTaxonomy.lua
Purpose: Neutral shared taxonomy seam for reusable item-category descriptors.
         Banking, Inventory, and Vendor compose mode-specific category tables
         from this shared source instead of owning duplicate local copies.
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.ItemTaxonomy = BETTERUI.CIM.ItemTaxonomy or {}

local ItemTaxonomy = BETTERUI.CIM.ItemTaxonomy

local function MergeDescriptor(base, overlay)
    local merged = {}
    if base then
        for key, value in pairs(base) do
            merged[key] = value
        end
    end
    if overlay then
        for key, value in pairs(overlay) do
            merged[key] = value
        end
    end
    return merged
end

local function BuildCategoryDefs(baseDescriptors, overlaysByKey, extras)
    local categories = {}
    for i = 1, #baseDescriptors do
        local descriptor = baseDescriptors[i]
        categories[#categories + 1] = MergeDescriptor(descriptor, overlaysByKey and overlaysByKey[descriptor.key] or nil)
    end
    if extras then
        for i = 1, #extras do
            categories[#categories + 1] = MergeDescriptor(extras[i])
        end
    end
    return categories
end

local SHARED_ITEM_CATEGORY_DESCRIPTORS = {
    { key = "all",        nameStringId = SI_BETTERUI_INV_ITEM_ALL,        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds" },
    { key = "weapons",    nameStringId = SI_BETTERUI_INV_ITEM_WEAPONS,    iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_weapons.dds" },
    { key = "apparel",    nameStringId = SI_BETTERUI_INV_ITEM_APPAREL,    iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_apparel.dds" },
    { key = "jewelry",    nameStringId = SI_BETTERUI_INV_ITEM_JEWELRY,    iconFile = "EsoUI/Art/Crafting/Gamepad/gp_jewelry_tabicon_icon.dds" },
    { key = "consumable", nameStringId = SI_BETTERUI_INV_ITEM_CONSUMABLE, iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_consumables.dds" },
    { key = "materials",  nameStringId = SI_BETTERUI_INV_ITEM_MATERIALS,  iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_materials.dds" },
    { key = "furnishing", nameStringId = SI_BETTERUI_INV_ITEM_FURNISHING, iconFile = "EsoUI/Art/Crafting/Gamepad/gp_crafting_menuicon_furnishings.dds" },
    { key = "misc",       nameStringId = SI_BETTERUI_INV_ITEM_MISC,       iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_miscellaneous.dds" },
}

local BANK_CATEGORY_OVERRIDES = {
    all = { filterType = nil },
    weapons = { filterType = ITEMFILTERTYPE_WEAPONS },
    apparel = { filterType = ITEMFILTERTYPE_ARMOR },
    jewelry = { filterType = ITEMFILTERTYPE_JEWELRY },
    consumable = { filterType = ITEMFILTERTYPE_CONSUMABLE },
    materials = { filterType = ITEMFILTERTYPE_CRAFTING },
    furnishing = { filterType = ITEMFILTERTYPE_FURNISHING },
    misc = { filterType = ITEMFILTERTYPE_MISCELLANEOUS },
}

local VENDOR_BUY_CATEGORY_OVERRIDES = {
    all = { filterType = nil },
    weapons = { filterType = ITEMFILTERTYPE_WEAPONS },
    apparel = { filterType = ITEMFILTERTYPE_ARMOR },
    jewelry = { filterType = ITEMFILTERTYPE_JEWELRY },
    consumable = { filterType = ITEMFILTERTYPE_CONSUMABLE },
    materials = { filterType = ITEMFILTERTYPE_CRAFTING },
    furnishing = { filterType = ITEMFILTERTYPE_FURNISHING },
}

local VENDOR_SELL_CATEGORY_OVERRIDES = {
    all = { filterType = nil },
    weapons = { filterType = ITEMFILTERTYPE_WEAPONS },
    apparel = { filterType = ITEMFILTERTYPE_ARMOR },
    jewelry = { filterType = ITEMFILTERTYPE_JEWELRY },
    consumable = { filterType = ITEMFILTERTYPE_CONSUMABLE },
    materials = { filterType = ITEMFILTERTYPE_CRAFTING },
    furnishing = { filterType = ITEMFILTERTYPE_FURNISHING },
    misc = { filterType = ITEMFILTERTYPE_MISCELLANEOUS },
}

local BANK_CATEGORY_EXTRAS = {
    -- SI_ITEMFILTERTYPE27 is the generated "Companion Items" string for ITEMFILTERTYPE_COMPANION.
    { key = "companion",  nameStringId = SI_ITEMFILTERTYPE27, filterType = ITEMFILTERTYPE_COMPANION, iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_companionItems.dds", optional = true },
    { key = "junk",       nameStringId = SI_BETTERUI_INV_ITEM_JUNK,   filterType = nil,                      special = "junk",                                              iconFile = "esoui/art/inventory/inventory_tabicon_junk_up.dds" },
}

local VENDOR_SELL_CATEGORY_EXTRAS = {
    { key = "junk", nameStringId = SI_BETTERUI_INV_ITEM_JUNK, iconFile = "esoui/art/inventory/inventory_tabicon_junk_up.dds", special = "junk" },
}

ItemTaxonomy.SHARED_ITEM_CATEGORY_DESCRIPTORS = SHARED_ITEM_CATEGORY_DESCRIPTORS
ItemTaxonomy.BANK_CATEGORY_DEFS = BuildCategoryDefs(SHARED_ITEM_CATEGORY_DESCRIPTORS, BANK_CATEGORY_OVERRIDES, BANK_CATEGORY_EXTRAS)
ItemTaxonomy.VENDOR_BUY_CATEGORY_DEFS = BuildCategoryDefs(SHARED_ITEM_CATEGORY_DESCRIPTORS, VENDOR_BUY_CATEGORY_OVERRIDES)
ItemTaxonomy.VENDOR_SELL_CATEGORY_DEFS = BuildCategoryDefs(SHARED_ITEM_CATEGORY_DESCRIPTORS, VENDOR_SELL_CATEGORY_OVERRIDES, VENDOR_SELL_CATEGORY_EXTRAS)
