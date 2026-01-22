--[[
File: Modules/CIM/CategoryDefinitions.lua
Purpose: Centralized configuration for inventory categories and craft bag filters.
         Used by Inventory module to populate category lists dynamically instead of
         hardcoding definitions in multiple places.
Last Modified: 2026-01-21
]]

BETTERUI.Inventory = BETTERUI.Inventory or {}
BETTERUI.Inventory.Categories = {}

-- Craft Bag Categories
-- Ordered list of categories to display when the user opens the Craft Bag
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

-- Inventory Categories (Backpack)
-- Ordered list of categories for the main inventory
BETTERUI.Inventory.Categories.Inventory = {
    {
        -- All Items
        -- Note: Uses NewCategoryItem(nil, ...) logic
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds",
        filterType = nil,
        isStatic = true -- Always show if category list is not empty (handled by NewCategoryItem logic)
    },
    {
        -- Equipped Items
        -- Dynamic: Only shown if HasAnyItemsNew(BAG_WORN) or similar logic? 
        -- Actually original logic checks GetNumBagUsedSlots(BAG_WORN) > 0
        type = "Equipped",
        nameStringId = SI_BETTERUI_INV_ITEM_EQUIPPED,
        iconFile = "esoui/art/inventory/gamepad/gp_inventory_icon_equipped.dds",
        showEquipped = true
    },
    {
        -- Weapons
        filterType = ITEMFILTERTYPE_WEAPONS,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_weapons.dds"
    },
    {
        -- Armor
        filterType = ITEMFILTERTYPE_ARMOR,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_apparel.dds"
    },
    {
        -- Jewelry
        filterType = ITEMFILTERTYPE_JEWELRY,
        iconFile = "EsoUI/Art/Crafting/Gamepad/gp_jewelry_tabicon_icon.dds"
    },
    {
        -- Consumables
        filterType = ITEMFILTERTYPE_CONSUMABLE,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_consumables.dds"
    },
    {
        -- Materials
        filterType = ITEMFILTERTYPE_CRAFTING,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_materials.dds"
    },
    {
        -- Furnishings
        filterType = ITEMFILTERTYPE_FURNISHING,
        iconFile = "EsoUI/Art/Crafting/Gamepad/gp_crafting_menuicon_furnishings.dds"
    },
    {
        -- Companion Items
        filterType = ITEMFILTERTYPE_COMPANION,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_companionItems.dds"
    },
    {
        -- Miscellaneous
        filterType = ITEMFILTERTYPE_MISCELLANEOUS,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_miscellaneous.dds"
    },
    {
        -- Quickslots
        filterType = ITEMFILTERTYPE_QUICKSLOT,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_quickslot.dds"
    },
    {
        -- Quest Items
        type = "Quest",
        nameStringId = SI_GAMEPAD_INVENTORY_QUEST_ITEMS,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_quest.dds",
        filterType = ITEMFILTERTYPE_QUEST
    },
    {
        -- Stolen Items
        type = "Stolen",
        nameStringId = SI_BETTERUI_INV_ITEM_STOLEN,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_stolenitem.dds",
        showStolen = true
    },
    {
        -- Junk
        type = "Junk",
        nameStringId = SI_BETTERUI_INV_ITEM_JUNK,
        iconFile = "esoui/art/inventory/inventory_tabicon_junk_up.dds",
        showJunk = true
    }
}
