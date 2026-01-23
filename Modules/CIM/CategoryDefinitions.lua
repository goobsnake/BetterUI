--[[
File: Modules/CIM/CategoryDefinitions.lua
Purpose: Centralized configuration for inventory categories and craft bag filters.
         Used by Inventory module to populate category lists dynamically instead of
         hardcoding definitions in multiple places.
         
         Also provides shared category definitions for Banking module to eliminate
         duplication between Banking.lua's BANK_CATEGORY_DEFS and Inventory categories.
Last Modified: 2026-01-22
]]

BETTERUI.Inventory = BETTERUI.Inventory or {}
BETTERUI.Inventory.Categories = {}

-- Craft Bag Categories
-- Ordered list of categories to display when the user opens the Craft Bag
--
-- Note: Categories now use a unified schema across Bank and Inventory modules.
BETTERUI.Inventory.Categories.CraftBag = {
    {
        nameStringId = SI_BETTERUI_CATEGORY_CRAFTING_BAG,
        iconFile = "/esoui/art/inventory/gamepad/gp_inventory_icon_craftbag_all.dds",
        filterType = nil, -- All
        onClickDirection = "CRAFTBAG" -- Special flag for list switching logic
    },
    {
        nameStringId = SI_BETTERUI_CATEGORY_ALCHEMY,
        iconFile = "/esoui/art/inventory/gamepad/gp_inventory_icon_craftbag_alchemy.dds",
        filterType = ITEMFILTERTYPE_ALCHEMY,
        onClickDirection = "CRAFTBAG"
    },
    {
        nameStringId = SI_BETTERUI_CATEGORY_BLACKSMITHING,
        iconFile = "/esoui/art/inventory/gamepad/gp_inventory_icon_craftbag_blacksmithing.dds",
        filterType = ITEMFILTERTYPE_BLACKSMITHING,
        onClickDirection = "CRAFTBAG"
    },
    {
        nameStringId = SI_BETTERUI_CATEGORY_CLOTHING,
        iconFile = "/esoui/art/inventory/gamepad/gp_inventory_icon_craftbag_clothing.dds",
        filterType = ITEMFILTERTYPE_CLOTHING,
        onClickDirection = "CRAFTBAG"
    },
    {
        nameStringId = SI_BETTERUI_CATEGORY_ENCHANTING,
        iconFile = "/esoui/art/inventory/gamepad/gp_inventory_icon_craftbag_enchanting.dds",
        filterType = ITEMFILTERTYPE_ENCHANTING,
        onClickDirection = "CRAFTBAG"
    },
    {
        nameStringId = SI_BETTERUI_CATEGORY_JEWELRY_CRAFTING,
        iconFile = "/esoui/art/inventory/gamepad/gp_inventory_tabicon_craftbag_jewelrycrafting.dds",
        filterType = ITEMFILTERTYPE_JEWELRYCRAFTING,
        onClickDirection = "CRAFTBAG"
    },
    {
        nameStringId = SI_BETTERUI_CATEGORY_PROVISIONING,
        iconFile = "/esoui/art/inventory/gamepad/gp_inventory_icon_craftbag_provisioning.dds",
        filterType = ITEMFILTERTYPE_PROVISIONING,
        onClickDirection = "CRAFTBAG"
    },
    {
        nameStringId = SI_BETTERUI_CATEGORY_WOODWORKING,
        iconFile = "/esoui/art/inventory/gamepad/gp_inventory_icon_craftbag_woodworking.dds",
        filterType = ITEMFILTERTYPE_WOODWORKING,
        onClickDirection = "CRAFTBAG"
    },
    {
        nameStringId = SI_BETTERUI_CATEGORY_STYLE_MATERIAL,
        iconFile = "/esoui/art/inventory/gamepad/gp_inventory_icon_craftbag_stylematerial.dds",
        filterType = ITEMFILTERTYPE_STYLE_MATERIALS,
        onClickDirection = "CRAFTBAG"
    },
    {
        nameStringId = SI_BETTERUI_CATEGORY_TRAIT_GEMS,
        iconFile = "/esoui/art/inventory/gamepad/gp_inventory_icon_craftbag_itemtrait.dds",
        filterType = ITEMFILTERTYPE_TRAIT_ITEMS,
        onClickDirection = "CRAFTBAG"
    }
}

-------------------------------------------------------------------------------------------------
-- SHARED BANKING CATEGORY DEFINITIONS
-------------------------------------------------------------------------------------------------
-- These definitions are shared between Banking and Inventory modules to ensure
-- consistent category handling and eliminate code duplication.
-------------------------------------------------------------------------------------------------

BETTERUI.Inventory.Categories.Bank = {
    { key = "all",        nameStringId = SI_BETTERUI_INV_ITEM_ALL,        filterType = nil,                         iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds" },
    { key = "weapons",    nameStringId = SI_BETTERUI_INV_ITEM_WEAPONS,    filterType = ITEMFILTERTYPE_WEAPONS,      iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_weapons.dds" },
    { key = "apparel",    nameStringId = SI_BETTERUI_INV_ITEM_APPAREL,    filterType = ITEMFILTERTYPE_ARMOR,        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_apparel.dds" },
    { key = "jewelry",    nameStringId = SI_BETTERUI_INV_ITEM_JEWELRY,    filterType = ITEMFILTERTYPE_JEWELRY,      iconFile = "EsoUI/Art/Crafting/Gamepad/gp_jewelry_tabicon_icon.dds" },
    { key = "consumable", nameStringId = SI_BETTERUI_INV_ITEM_CONSUMABLE, filterType = ITEMFILTERTYPE_CONSUMABLE,   iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_consumables.dds" },
    { key = "materials",  nameStringId = SI_BETTERUI_INV_ITEM_MATERIALS,  filterType = ITEMFILTERTYPE_CRAFTING,     iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_materials.dds" },
    { key = "furnishing", nameStringId = SI_BETTERUI_INV_ITEM_FURNISHING, filterType = ITEMFILTERTYPE_FURNISHING,   iconFile = "EsoUI/Art/Crafting/Gamepad/gp_crafting_menuicon_furnishings.dds" },
    { key = "misc",       nameStringId = SI_BETTERUI_INV_ITEM_MISC,       filterType = ITEMFILTERTYPE_MISCELLANEOUS,iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_miscellaneous.dds" },
    -- Companion items exist only on newer APIs; guard with presence check when building
    { key = "companion",  nameStringId = SI_ITEMFILTERTYPE_COMPANION,     filterType = ITEMFILTERTYPE_COMPANION,    iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_companionItems.dds", optional = true },
    -- Junk is not a filterType; handled specially in DoesItemMatchCategory
    { key = "junk",       nameStringId = SI_BETTERUI_INV_ITEM_JUNK,       filterType = nil, special = "junk",       iconFile = "esoui/art/inventory/inventory_tabicon_junk_up.dds" },
}

-- Note: BankIcons table removal - icons are now embedded above in 'iconFile'

-- Inventory Categories (Backpack)
-- Ordered list of categories for the main inventory
BETTERUI.Inventory.Categories.Inventory = {
    {
        -- All Items
        key = "All", 
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds",
        filterType = nil,
        isStatic = true -- Always show if category list is not empty
    },
    {
        -- Equipped Items
        key = "Equipped",
        nameStringId = SI_BETTERUI_INV_ITEM_EQUIPPED,
        iconFile = "esoui/art/inventory/gamepad/gp_inventory_icon_equipped.dds",
        showEquipped = true
    },
    {
        -- Weapons
        key = "Weapons",
        filterType = ITEMFILTERTYPE_WEAPONS,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_weapons.dds"
    },
    {
        -- Armor
        key = "Armor",
        filterType = ITEMFILTERTYPE_ARMOR,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_apparel.dds"
    },
    {
        -- Jewelry
        key = "Jewelry",
        filterType = ITEMFILTERTYPE_JEWELRY,
        iconFile = "EsoUI/Art/Crafting/Gamepad/gp_jewelry_tabicon_icon.dds"
    },
    {
        -- Consumables
        key = "Consumables",
        filterType = ITEMFILTERTYPE_CONSUMABLE,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_consumables.dds"
    },
    {
        -- Materials
        key = "Materials",
        filterType = ITEMFILTERTYPE_CRAFTING,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_materials.dds"
    },
    {
        -- Furnishings
        key = "Furnishings",
        filterType = ITEMFILTERTYPE_FURNISHING,
        iconFile = "EsoUI/Art/Crafting/Gamepad/gp_crafting_menuicon_furnishings.dds"
    },
    {
        -- Companion Items
        key = "Companion",
        filterType = ITEMFILTERTYPE_COMPANION,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_companionItems.dds"
    },
    {
        -- Miscellaneous
        key = "Miscellaneous",
        filterType = ITEMFILTERTYPE_MISCELLANEOUS,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_miscellaneous.dds"
    },
    {
        -- Quickslots
        key = "Quickslots",
        filterType = ITEMFILTERTYPE_QUICKSLOT,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_quickslot.dds"
    },
    {
        -- Quest Items
        key = "Quest",
        nameStringId = SI_GAMEPAD_INVENTORY_QUEST_ITEMS,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_quest.dds",
        filterType = ITEMFILTERTYPE_QUEST
    },
    {
        -- Stolen Items
        key = "Stolen",
        nameStringId = SI_BETTERUI_INV_ITEM_STOLEN,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_stolenitem.dds",
        showStolen = true
    },
    {
        -- Junk
        key = "Junk",
        nameStringId = SI_BETTERUI_INV_ITEM_JUNK,
        iconFile = "esoui/art/inventory/inventory_tabicon_junk_up.dds",
        showJunk = true
    }
}

-------------------------------------------------------------------------------------------------
-- SHARED CATEGORY MATCHING FUNCTION
-------------------------------------------------------------------------------------------------
-- Provides a centralized function for checking if an item matches a category.
-- Used by both Inventory and Banking modules for filtering.
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.Inventory.Categories.DoesItemMatchCategory
Description: Checks if itemData belongs to the given category definition.
Rationale: Centralizes filtering logic used by both Inventory and Banking.
Mechanism: Checks 'all' key, special flags (junk, stolen), or uses ESO filter API.
param: itemData (table) - The item's data object (must have isJunk, stolen fields).
param: category (table) - The category definition to check against.
return: boolean - True if the item matches the category.
]]
function BETTERUI.Inventory.Categories.DoesItemMatchCategory(itemData, category)
    -- Handle special category types FIRST
    -- (e.g., 'Junk' has filterType=nil, so checking special first prevents it from matching the 'All' logic)
    if category.special == "junk" or category.showJunk then
        return itemData.isJunk == true
    end
    
    if category.special == "stolen" or category.showStolen then
        return itemData.stolen == true
    end

    -- No category or "all" always matches
    -- Note: Only check this AFTER special categories to avoid false positives for categories like Junk
    if not category or category.key == "all" or category.filterType == nil then
        return true
    end
    
    -- Standard ESO filter type matching
    if category.filterType then
        return ZO_InventoryUtils_DoesNewItemMatchFilterType(itemData, category.filterType)
    end
    
    return true
end

--[[
Function: BETTERUI.Inventory.Categories.GetCategoryIcon
Description: Returns the icon path for a category by key.
param: categoryKey (string) - The category key (e.g., "weapons", "all").
return: string - The icon path, or nil if not found.
]]
function BETTERUI.Inventory.Categories.GetCategoryIcon(categoryKey)
    return BETTERUI.Inventory.Categories.BankIcons[categoryKey]
end

