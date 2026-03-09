--[[
File: Modules/CIM/CategoryDefinitions.lua
Purpose: Centralized configuration for inventory categories and craft bag filters.
         Used by Inventory module to populate category lists dynamically instead of
         hardcoding definitions in multiple places.

         Also provides shared category definitions for Banking module to eliminate
         duplication between Banking.lua's BANK_CATEGORY_DEFS and Inventory categories.
Last Modified: 2026-01-27
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
        filterType = nil,             -- All
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
    { key = "all",        nameStringId = SI_BETTERUI_INV_ITEM_ALL,        filterType = nil,                          iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds" },
    { key = "weapons",    nameStringId = SI_BETTERUI_INV_ITEM_WEAPONS,    filterType = ITEMFILTERTYPE_WEAPONS,       iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_weapons.dds" },
    { key = "apparel",    nameStringId = SI_BETTERUI_INV_ITEM_APPAREL,    filterType = ITEMFILTERTYPE_ARMOR,         iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_apparel.dds" },
    { key = "jewelry",    nameStringId = SI_BETTERUI_INV_ITEM_JEWELRY,    filterType = ITEMFILTERTYPE_JEWELRY,       iconFile = "EsoUI/Art/Crafting/Gamepad/gp_jewelry_tabicon_icon.dds" },
    { key = "consumable", nameStringId = SI_BETTERUI_INV_ITEM_CONSUMABLE, filterType = ITEMFILTERTYPE_CONSUMABLE,    iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_consumables.dds" },
    { key = "materials",  nameStringId = SI_BETTERUI_INV_ITEM_MATERIALS,  filterType = ITEMFILTERTYPE_CRAFTING,      iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_materials.dds" },
    { key = "furnishing", nameStringId = SI_BETTERUI_INV_ITEM_FURNISHING, filterType = ITEMFILTERTYPE_FURNISHING,    iconFile = "EsoUI/Art/Crafting/Gamepad/gp_crafting_menuicon_furnishings.dds" },
    { key = "misc",       nameStringId = SI_BETTERUI_INV_ITEM_MISC,       filterType = ITEMFILTERTYPE_MISCELLANEOUS, iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_miscellaneous.dds" },
    -- Companion items exist only on newer APIs; guard with presence check when building
    { key = "companion",  nameStringId = SI_ITEMFILTERTYPE_COMPANION,     filterType = ITEMFILTERTYPE_COMPANION,     iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_companionItems.dds", optional = true },
    -- Junk is not a filterType; handled specially in DoesItemMatchCategory
    { key = "junk",       nameStringId = SI_BETTERUI_INV_ITEM_JUNK,       filterType = nil,                          special = "junk",                                                              iconFile = "esoui/art/inventory/inventory_tabicon_junk_up.dds" },
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


-------------------------------------------------------------------------------------------------
-- SHARED ITEM CATEGORIZATION HELPERS
-------------------------------------------------------------------------------------------------
-- These functions are shared between Inventory and Banking modules for consistent
-- item categorization and description generation.
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.Inventory.Categories.GetCategoryTypeFromWeaponType
Description: Maps a weapon item to a gamepad weapon category type.
Rationale: Centralizes weapon categorization logic used by both Inventory and Banking.
Mechanism: Checks weapon type and returns appropriate GAMEPAD_WEAPON_CATEGORY_* constant.
param: bagId (number) - The bag containing the item.
param: slotIndex (number) - The slot index of the item.
return: number|nil - The weapon category constant, or nil if not a weapon.
]]
function BETTERUI.Inventory.Categories.GetCategoryTypeFromWeaponType(bagId, slotIndex)
    local weaponType = GetItemWeaponType(bagId, slotIndex)
    if weaponType == WEAPONTYPE_AXE or weaponType == WEAPONTYPE_HAMMER or weaponType == WEAPONTYPE_SWORD or weaponType == WEAPONTYPE_DAGGER then
        return GAMEPAD_WEAPON_CATEGORY_ONE_HANDED_MELEE
    elseif weaponType == WEAPONTYPE_TWO_HANDED_SWORD or weaponType == WEAPONTYPE_TWO_HANDED_AXE or weaponType == WEAPONTYPE_TWO_HANDED_HAMMER then
        return GAMEPAD_WEAPON_CATEGORY_TWO_HANDED_MELEE
    elseif weaponType == WEAPONTYPE_FIRE_STAFF or weaponType == WEAPONTYPE_FROST_STAFF or weaponType == WEAPONTYPE_LIGHTNING_STAFF then
        return GAMEPAD_WEAPON_CATEGORY_DESTRUCTION_STAFF
    elseif weaponType == WEAPONTYPE_HEALING_STAFF then
        return GAMEPAD_WEAPON_CATEGORY_RESTORATION_STAFF
    elseif weaponType == WEAPONTYPE_BOW then
        return GAMEPAD_WEAPON_CATEGORY_TWO_HANDED_BOW
    elseif weaponType ~= WEAPONTYPE_NONE then
        return GAMEPAD_WEAPON_CATEGORY_UNCATEGORIZED
    end
end

--[[
Function: BETTERUI.Inventory.Categories.GetBestItemCategoryDescription
Description: Computes the best category description string for an item.
Rationale: Centralizes description generation logic used by both Inventory and Banking.
Mechanism: Checks for Stolen, InvalidEquip, Weapons, Armor, and builds combined type+equip string.
param: itemData (table) - The item data object with bagId, slotIndex, equipType, itemType.
return: string - The localized category description.
]]
function BETTERUI.Inventory.Categories.GetBestItemCategoryDescription(itemData)
    local isItemStolen = IsItemStolen(itemData.bagId, itemData.slotIndex)

    if isItemStolen then
        return GetString(SI_BETTERUI_STOLEN)
    end

    if itemData.equipType == EQUIP_TYPE_INVALID then
        return GetString("SI_ITEMTYPE", itemData.itemType)
    end
    -- Weapon type with handedness suffix only for weapons that have both variants
    local weaponType = GetItemWeaponType(itemData.bagId, itemData.slotIndex)
    if weaponType and weaponType ~= WEAPONTYPE_NONE then
        local weaponName = GetString("SI_WEAPONTYPE", weaponType)
        -- Only Axe, Sword, and Hammer have both 1H and 2H variants — add suffix for clarity
        -- Bow (always 2H), Dagger (always 1H), Staves (always 2H), Shield get no suffix
        local needsSuffix = (weaponType == WEAPONTYPE_AXE or weaponType == WEAPONTYPE_TWO_HANDED_AXE)
            or (weaponType == WEAPONTYPE_SWORD or weaponType == WEAPONTYPE_TWO_HANDED_SWORD)
            or (weaponType == WEAPONTYPE_HAMMER or weaponType == WEAPONTYPE_TWO_HANDED_HAMMER)
        if needsSuffix and (itemData.equipType == EQUIP_TYPE_ONE_HAND or itemData.equipType == EQUIP_TYPE_TWO_HAND) then
            local handedness = GetString("SI_EQUIPTYPE", itemData.equipType)
            return weaponName .. " - " .. handedness
        end
        return weaponName
    end
    local armorType = GetItemArmorType(itemData.bagId, itemData.slotIndex)
    local itemLink = GetItemLink(itemData.bagId, itemData.slotIndex)
    if armorType ~= ARMORTYPE_NONE then
        return GetString("SI_ARMORTYPE", armorType) .. " " .. GetString("SI_EQUIPTYPE", GetItemLinkEquipType(itemLink))
    end

    local fullDesc = GetString("SI_ITEMTYPE", itemData.itemType)

    -- Stops types like "Poison" displaying "Poison" twice
    if (fullDesc ~= GetString("SI_EQUIPTYPE", GetItemLinkEquipType(itemLink))) then
        fullDesc = fullDesc .. " " .. GetString("SI_EQUIPTYPE", GetItemLinkEquipType(itemLink))
    end

    return fullDesc
end
