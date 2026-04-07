-- BetterUI English Localization

--
---
--- Purpose: Defines localized string constants for English.
--- Mechanics: Registers string IDs with the ESO localization system (ZO_CreateStringId).
---

-- String IDs for UI labels, tooltips, and messages

-- UI Labels (Resource Orb Frames)
ZO_CreateStringId("SI_BETTERUI_LABEL_CAST_BAR", "Cast Bar")
ZO_CreateStringId("SI_BETTERUI_LABEL_MOUNT_STAMINA", "Mount Stamina")

-- List States
ZO_CreateStringId("SI_BETTERUI_EMPTY_LIST", "Nothing in list")
ZO_CreateStringId("SI_BETTERUI_LOADING_LIST", "Loading list...")
ZO_CreateStringId("SI_BETTERUI_SEARCH_NO_RESULTS", "No items found")

-- Market Price Tooltip Strings (TTC / MM / ATT integration)
ZO_CreateStringId("SI_BETTERUI_MARKET_NO_PRICE_DATA", "<<1>>: No Price Data")
ZO_CreateStringId("SI_BETTERUI_MARKET_TTC_AVG_SUG", "TTC: Avg: <<1>> / Sug: <<2>>")
ZO_CreateStringId("SI_BETTERUI_MARKET_TTC_AVG", "TTC: Avg: <<1>>")
ZO_CreateStringId("SI_BETTERUI_MARKET_TTC_SUG", "TTC: Sug: <<1>>")
ZO_CreateStringId("SI_BETTERUI_MARKET_TTC_STACK_AVG_SUG", "TTC: (<<1>>x) Avg: <<2>> / Sug: <<3>>")
ZO_CreateStringId("SI_BETTERUI_MARKET_TTC_STACK_AVG", "TTC: (<<1>>x) Avg: <<2>>")
ZO_CreateStringId("SI_BETTERUI_MARKET_TTC_STACK_SUG", "TTC: (<<1>>x) Sug: <<2>>")
ZO_CreateStringId("SI_BETTERUI_MARKET_PRICE", "<<1>>: <<2>>")
ZO_CreateStringId("SI_BETTERUI_MARKET_PRICE_STACK", "<<1>>: <<2>>, (<<3>>x) <<4>>")

-- Footer Currency Labels
ZO_CreateStringId("SI_BETTERUI_FOOTER_CARRY", "Carry")
ZO_CreateStringId("SI_BETTERUI_FOOTER_GOLD", "Gold")
ZO_CreateStringId("SI_BETTERUI_FOOTER_KEYS", "Undaunted Keys")
ZO_CreateStringId("SI_BETTERUI_FOOTER_CRYSTALS", "Transmute Crystals")
ZO_CreateStringId("SI_BETTERUI_FOOTER_CROWNS", "Crowns")
ZO_CreateStringId("SI_BETTERUI_FOOTER_GEMS", "Crown Gems")
ZO_CreateStringId("SI_BETTERUI_FOOTER_BANK", "Bank")
ZO_CreateStringId("SI_BETTERUI_FOOTER_TELVAR", "Tel Var")
ZO_CreateStringId("SI_BETTERUI_FOOTER_AP", "AP")
ZO_CreateStringId("SI_BETTERUI_FOOTER_WRITS", "Writs")
ZO_CreateStringId("SI_BETTERUI_FOOTER_TRADE_BARS", "Trade Bars")
ZO_CreateStringId("SI_BETTERUI_FOOTER_OUTFIT_TOKENS", "Outfit Tokens")
ZO_CreateStringId("SI_BETTERUI_FOOTER_SEALS", "Seals")
ZO_CreateStringId("SI_BETTERUI_FOOTER_TOME_POINTS", "Tome Points")

-- Footer Capacity Labels
ZO_CreateStringId("SI_BETTERUI_FOOTER_BAG_CAPACITY", "BAG:")
ZO_CreateStringId("SI_BETTERUI_FOOTER_BANK_CAPACITY", "BANK:")



-- Footer Currency Display Labels (short versions for footer display)
ZO_CreateStringId("SI_BETTERUI_FOOTER_GOLD_LABEL", "GOLD:")
ZO_CreateStringId("SI_BETTERUI_FOOTER_AP_LABEL", "AP:")
ZO_CreateStringId("SI_BETTERUI_FOOTER_TELVAR_LABEL", "TEL VAR:")
ZO_CreateStringId("SI_BETTERUI_FOOTER_KEYS_LABEL", "KEYS:")
ZO_CreateStringId("SI_BETTERUI_FOOTER_TRANSMUTE_LABEL", "CRYSTALS:")
ZO_CreateStringId("SI_BETTERUI_FOOTER_CROWNS_LABEL", "CROWNS:")
ZO_CreateStringId("SI_BETTERUI_FOOTER_GEMS_LABEL", "GEMS:")
ZO_CreateStringId("SI_BETTERUI_FOOTER_WRITS_LABEL", "WRITS:")
ZO_CreateStringId("SI_BETTERUI_FOOTER_TRADE_BARS_LABEL", "BARS:")
ZO_CreateStringId("SI_BETTERUI_FOOTER_OUTFIT_LABEL", "OUTFIT:")
ZO_CreateStringId("SI_BETTERUI_FOOTER_SEALS_LABEL", "SEALS:")
ZO_CreateStringId("SI_BETTERUI_FOOTER_TOME_POINTS_LABEL", "TOMES:")
ZO_CreateStringId("SI_BETTERUI_FOOTER_EVENT_TICKETS_LABEL", "TICKETS:")

-- Destroy Confirmation Messages
ZO_CreateStringId("SI_BETTERUI_DESTROY_CONFIRM_FORMAT", "Are you sure you want to destroy <<1>>? This cannot be undone.")
ZO_CreateStringId("SI_BETTERUI_DESTROY_CONFIRM_GENERIC",
    "Are you sure you want to destroy this item? This cannot be undone.")


-- Currency limit alert
ZO_CreateStringId("SI_BETTERUI_CURRENCY_ENABLE_LIMIT_WARNING",
    "Maximum visible currencies reached (<<1>>). Disable one currency before enabling another.")



-- Header Labels (Inventory/Guild Store)
ZO_CreateStringId("SI_BETTERUI_FULL_INVENTORY_ALL", "All")
ZO_CreateStringId("SI_BETTERUI_EQUIP", "Equip:")
ZO_CreateStringId("SI_BETTERUI_BROWSE_LISTINGS", "Browse Listings")
ZO_CreateStringId("SI_BETTERUI_BROWSE_NAME", "Name")
ZO_CreateStringId("SI_BETTERUI_BROWSE_SELLER", "Seller")
ZO_CreateStringId("SI_BETTERUI_BROWSE_TIME_LEFT", "Time Left")
ZO_CreateStringId("SI_BETTERUI_BROWSE_PROFIT", "Profit")
ZO_CreateStringId("SI_BETTERUI_BROWSE_PRICE", "Price")
ZO_CreateStringId("SI_BETTERUI_INV_ITEM_ALL", "All Items")
ZO_CreateStringId("SI_BETTERUI_INV_ITEM_MATERIALS", "Materials")
ZO_CreateStringId("SI_BETTERUI_INV_ITEM_WEAPONS", "Weapons")
ZO_CreateStringId("SI_BETTERUI_INV_ITEM_APPAREL", "Apparel")
ZO_CreateStringId("SI_BETTERUI_INV_ITEM_JEWELRY", "Jewelry")
ZO_CreateStringId("SI_BETTERUI_INV_ITEM_CONSUMABLE", "Consumables")
ZO_CreateStringId("SI_BETTERUI_INV_ITEM_MISC", "Miscellaneous")
ZO_CreateStringId("SI_BETTERUI_INV_ITEM_JUNK", "Junk")
ZO_CreateStringId("SI_BETTERUI_INV_ITEM_EQUIPPED", "Equipped")
ZO_CreateStringId("SI_BETTERUI_INV_ITEM_STOLEN", "Stolen")
ZO_CreateStringId("SI_BETTERUI_INV_ITEM_FURNISHING", "Furnishings")

ZO_CreateStringId("SI_BETTERUI_INV_EQUIPSLOT_TITLE", "Equipping item...")
ZO_CreateStringId("SI_BETTERUI_INV_EQUIPSLOT_MAIN", "Main")

ZO_CreateStringId("SI_BETTERUI_INV_EQUIP_PROMPT_MAIN", "Main Hand")
ZO_CreateStringId("SI_BETTERUI_INV_EQUIP_PROMPT_BACKUP", "Off Hand")

ZO_CreateStringId("SI_BETTERUI_INV_SWITCH_EQUIPSLOT", "Switch Weapons")
ZO_CreateStringId("SI_BETTERUI_INV_ACTION_QUICKSLOT_ASSIGN", "Assign Quickslot")
ZO_CreateStringId("SI_BETTERUI_INV_ACTION_QUICKSLOT_UNASSIGN", "Unassign Quickslot")

ZO_CreateStringId("SI_BETTERUI_INV_EQUIPSLOT_BACKUP", "Backup")
ZO_CreateStringId("SI_BETTERUI_BANKING_WITHDRAW", "WITHDRAW")
ZO_CreateStringId("SI_BETTERUI_BANKING_DEPOSIT", "DEPOSIT")

ZO_CreateStringId("SI_BETTERUI_INV_ACTION_TO_TEMPLATE", "Go To <<1>>")

ZO_CreateStringId("SI_BETTERUI_INV_ACTION_CB", "Crafting Bag")
ZO_CreateStringId("SI_BETTERUI_INV_ACTION_INV", "All Items")

ZO_CreateStringId("SI_BETTERUI_INV_SWITCH_INFO", "Switch Info")
ZO_CreateStringId("SI_BETTERUI_INV_EQUIP", "Equip")
ZO_CreateStringId("SI_BETTERUI_INV_FIRST_SLOT", "First Slot")
ZO_CreateStringId("SI_BETTERUI_INV_SECOND_SLOT", "Second Slot")
ZO_CreateStringId("SI_BETTERUI_SAVE_EQUIP_CONFIRM_TITLE", "Equip Item")
ZO_CreateStringId("SI_BETTERUI_SAVE_EQUIP_CONFIRM_EQUIP_BOE", "Equipping <<t:1>> will bind it to you. Continue?")
ZO_CreateStringId("SI_BETTERUI_SAVE_EQUIP_EQUIP", "Equip")
ZO_CreateStringId("SI_BETTERUI_INV_EQUIP_ONE_HAND_WEAPON",
    "Do you want to equip <<t:1>>\ninto main hand or off hand in |cFF6600<<2>>|r weapon bar?")
ZO_CreateStringId("SI_BETTERUI_INV_EQUIP_OTHER_WEAPON", "Do you want to equip <<t:1>> in |cFF6600<<2>>|r weapon bar?")
ZO_CreateStringId("SI_BETTERUI_INV_EQUIP_RING", "Do you want to equip <<t:1>> in first or second ring slot?")
ZO_CreateStringId("SI_BETTERUI_BANKING_TOGGLE_LIST", "Toggle List")
ZO_CreateStringId("SI_BETTERUI_CONFIRM_AMOUNT", "CONFIRM AMOUNT")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_GOLD", "GOLD")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_TEL_VAR", "TEL VAR")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_ALLIANCE_POINT", "AP")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_WRIT_VOUCHER", "WRITS")
ZO_CreateStringId("SI_BETTERUI_BANKING_COLUMN_NAME", "Name")
ZO_CreateStringId("SI_BETTERUI_BANKING_COLUMN_TYPE", "Type")
ZO_CreateStringId("SI_BETTERUI_BANKING_COLUMN_TRAIT", "Trait")
ZO_CreateStringId("SI_BETTERUI_BANKING_COLUMN_STAT", "Stat")
ZO_CreateStringId("SI_BETTERUI_BANKING_COLUMN_VALUE", "Value")
ZO_CreateStringId("SI_BETTERUI_ACTION_UNMARK_AS_JUNK", "Unmark as Junk")
ZO_CreateStringId("SI_BETTERUI_ACTION_MARK_AS_JUNK", "Mark as Junk")
ZO_CreateStringId("SI_BETTERUI_ENABLE_COMPANION_JUNK", "Enable Companion Junk Actions")
ZO_CreateStringId("SI_BETTERUI_ENABLE_COMPANION_JUNK_TOOLTIP",
    "Enables 'Mark as Junk' for companion items. Requires a compatible addon (e.g., FCO Companion) for companion junk to function.")
ZO_CreateStringId("SI_BETTERUI_INV_RECIPE_KNOWN", "KNOWN")
ZO_CreateStringId("SI_BETTERUI_INV_RECIPE_UNKNOWN", "UNKNOWN")
ZO_CreateStringId("SI_BETTERUI_CLEAR_SEARCH", "Clear Search")
ZO_CreateStringId("SI_BETTERUI_HEADER_SORT", "Sort")

-- Multi-Select Mode
ZO_CreateStringId("SI_BETTERUI_MULTI_SELECT", "Multi-Select")
ZO_CreateStringId("SI_BETTERUI_DESELECT_ITEM", "Deselect")
ZO_CreateStringId("SI_BETTERUI_SELECT_WITH_COUNT", "Select (<<1>>)")
ZO_CreateStringId("SI_BETTERUI_DESELECT_ALL", "Deselect All")
ZO_CreateStringId("SI_BETTERUI_SELECT_ALL", "Select All")
ZO_CreateStringId("SI_BETTERUI_SELECTED_COUNT", "<<1>> Selected")
ZO_CreateStringId("SI_BETTERUI_BATCH_ACTIONS", "Batch Actions")
ZO_CreateStringId("SI_BETTERUI_BATCH_ACTIONS_DESC",
    "Choose an action to apply to applicable selected items. Locked items may not be compatible with certain actions.")
ZO_CreateStringId("SI_BETTERUI_BATCH_PROCESSING_COMPLETE", "<<1>> items processed.")
ZO_CreateStringId("SI_BETTERUI_BATCH_ABORTED_COMPLETE", "Aborted: Processed <<1>> of <<2>> items.")
ZO_CreateStringId("SI_BETTERUI_BATCH_PARTIAL_SUCCESS", "Complete: Processed <<1>> of <<2>> items. Some skipped.")
ZO_CreateStringId("SI_BETTERUI_BATCH_ABORTED_SCENE_EXIT", "Aborted (Interrupted): Processed <<2>> of <<3>> items.")
ZO_CreateStringId("SI_BETTERUI_BATCH_BAG_FULL", "Bag Full: Processed <<1>> of <<2>> items.")
ZO_CreateStringId("SI_BETTERUI_SCENE_BANKING", "Banking")
ZO_CreateStringId("SI_BETTERUI_SCENE_INVENTORY", "Inventory")
ZO_CreateStringId("SI_BETTERUI_ABORT_ACTION", "Abort Action")
ZO_CreateStringId("SI_BETTERUI_BATCH_DURATION_SECONDS", "<<1>>sec")
ZO_CreateStringId("SI_BETTERUI_BATCH_DURATION_MINUTES_SECONDS", "<<1>>min <<2>>sec")

ZO_CreateStringId("SI_BETTERUI_MASTER_SETTINGS_HEADER", "Master Settings")
ZO_CreateStringId("SI_BETTERUI_MASTER_SETTINGS_TITLE", "Master Addon Settings")
ZO_CreateStringId("SI_BETTERUI_ENABLE_GLOBAL_SETTINGS", "Use Global Settings")
ZO_CreateStringId("SI_BETTERUI_ENABLE_GLOBAL_TOOLTIP",
    "When enabled, settings will be saved account-wide instead of per-character - This requires a reloadui.")
ZO_CreateStringId("SI_BETTERUI_ENABLE_TOOLTIPS", "Enable |c0066FFGeneral Interface Improvements|r")
ZO_CreateStringId("SI_BETTERUI_ENABLE_TOOLTIPS_TOOLTIP", "Vast improvements to the ingame tooltips and UI (Gamepad UI only)")
ZO_CreateStringId("SI_BETTERUI_ENABLE_INVENTORY", "Enable |c0066FFEnhanced Inventory|r")
ZO_CreateStringId("SI_BETTERUI_ENABLE_INVENTORY_TOOLTIP", "Completely redesigns the inventory interface (Gamepad UI only)")
ZO_CreateStringId("SI_BETTERUI_ENABLE_BANKING", "Enable |c0066FFEnhanced Banking|r")
ZO_CreateStringId("SI_BETTERUI_ENABLE_BANKING_TOOLTIP", "Completely redesigns the banking interface (Gamepad UI only)")
ZO_CreateStringId("SI_BETTERUI_ENABLE_VENDOR", "Enable |c0066FFEnhanced Vendor|r")
ZO_CreateStringId("SI_BETTERUI_ENABLE_VENDOR_TOOLTIP", "Completely redesigns the vendor/merchant interface (Gamepad UI only)")
ZO_CreateStringId("SI_BETTERUI_ENABLE_COMPANIONS", "Enable |c0066FFCompanion Equipment|r")
ZO_CreateStringId("SI_BETTERUI_ENABLE_COMPANIONS_TOOLTIP", "Enhances companion equipment management with BetterUI list navigation (Gamepad UI only)")
ZO_CreateStringId("SI_BETTERUI_ENABLE_WRITS", "Enable |c0066FFDaily Writs|r")
ZO_CreateStringId("SI_BETTERUI_ENABLE_WRITS_TOOLTIP", "Displays the daily writ, and progress, at each crafting station (Gamepad UI only)")
ZO_CreateStringId("SI_BETTERUI_MASTER_RESET_ALL", "Reset All To Defaults")
ZO_CreateStringId("SI_BETTERUI_MASTER_RESET_ALL_TOOLTIP",
    "Reset ALL BetterUI settings to their default values. Reload the UI afterward to fully apply the restored defaults.")

-- Feature Flags Settings
ZO_CreateStringId("SI_BETTERUI_FEATURE_FLAGS_HEADER", "Feature Flags")
ZO_CreateStringId("SI_BETTERUI_FEATURE_FLAGS_DESC",
    "Toggle experimental or optional features. Some changes may require a /reloadui.")

ZO_CreateStringId("SI_BETTERUI_STOLEN", "Stolen")

-- Crafting Bag Categories (Inventory/Banking)
ZO_CreateStringId("SI_BETTERUI_CATEGORY_ALCHEMY", "Alchemy")
ZO_CreateStringId("SI_BETTERUI_CATEGORY_BLACKSMITHING", "Blacksmithing")
ZO_CreateStringId("SI_BETTERUI_CATEGORY_CLOTHING", "Clothing")
ZO_CreateStringId("SI_BETTERUI_CATEGORY_ENCHANTING", "Enchanting")
ZO_CreateStringId("SI_BETTERUI_CATEGORY_JEWELRY_CRAFTING", "Jewelry Crafting")
ZO_CreateStringId("SI_BETTERUI_CATEGORY_PROVISIONING", "Provisioning/Fishing")
ZO_CreateStringId("SI_BETTERUI_CATEGORY_WOODWORKING", "Woodworking")
ZO_CreateStringId("SI_BETTERUI_CATEGORY_STYLE_MATERIAL", "Style Material")
ZO_CreateStringId("SI_BETTERUI_CATEGORY_CRAFTING_BAG", "Crafting Bag")
ZO_CreateStringId("SI_BETTERUI_CATEGORY_TRAIT_GEMS", "Trait Gems")

-- Currency Visibility Settings
ZO_CreateStringId("SI_BETTERUI_CURRENCY_SUBMENU", "Currency Visibility & Order")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_DESC",
    "Configure which currencies are shown and their display order. Use presets for quick setup or customize individually.")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_PRESET", "Quick Preset")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_PRESET_TOOLTIP",
    "Apply a preset configuration for currency display. Custom settings will be overwritten.")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_PRESET_DEFAULT", "Default (All Visible)")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_PRESET_PVP", "PvP Focus")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_PRESET_CRAFTER", "Crafter Focus")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_PRESET_EVENTS", "Events Focus")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_PRESET_CUSTOM", "Custom")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_RESET", "Reset Currency Settings")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_RESET_TOOLTIP",
    "Reset all currency visibility and order settings to default values.")
ZO_CreateStringId("SI_BETTERUI_GENERAL_RESET", "Reset General Settings")
ZO_CreateStringId("SI_BETTERUI_GENERAL_RESET_TOOLTIP",
    "Reset all settings in this General section to their default values.")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_POS_1", "1st")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_POS_2", "2nd")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_POS_3", "3rd")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_POS_4", "4th")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_POS_5", "5th")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_POS_6", "6th")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_POS_7", "7th")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_POS_8", "8th")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_POS_9", "9th")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_POS_10", "10th")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_POS_11", "11th")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_POS_12", "12th")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_SHOW_GOLD", "Show Gold")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_ORDER_GOLD", "Gold Position")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_SHOW_AP", "Show Alliance Points")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_ORDER_AP", "AP Position")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_SHOW_TELVAR", "Show Tel Var Stones")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_ORDER_TELVAR", "Tel Var Position")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_SHOW_KEYS", "Show Undaunted Keys")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_ORDER_KEYS", "Keys Position")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_SHOW_TRANSMUTE", "Show Transmute Crystals")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_ORDER_TRANSMUTE", "Transmute Position")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_SHOW_CROWNS", "Show Crowns")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_ORDER_CROWNS", "Crowns Position")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_SHOW_GEMS", "Show Crown Gems")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_ORDER_GEMS", "Gems Position")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_SHOW_WRITS", "Show Writ Vouchers")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_ORDER_WRITS", "Writs Position")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_SHOW_TRADE_BARS", "Show Trade Bars")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_ORDER_TRADE_BARS", "Trade Bars Position")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_SHOW_OUTFIT", "Show Outfit Tokens")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_ORDER_OUTFIT", "Outfit Position")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_SHOW_SEALS", "Show Seals")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_ORDER_SEALS", "Seals Position")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_SHOW_TOME_POINTS", "Show Tome Points")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_ORDER_TOME_POINTS", "Tome Points Position")
-- Event Tickets (legacy name for Trade Bars, used for backwards compatibility)
ZO_CreateStringId("SI_BETTERUI_CURRENCY_SHOW_EVENT_TICKETS", "Show Event Tickets")
ZO_CreateStringId("SI_BETTERUI_CURRENCY_ORDER_EVENT_TICKETS", "Event Tickets Position")

-- Enhanced Nameplates
ZO_CreateStringId("SI_BETTERUI_NAMEPLATES_HEADER", "Enhanced Nameplates")
ZO_CreateStringId("SI_BETTERUI_NAMEPLATES_DESC",
    "Customize nameplate fonts, styles, and sizes for player and NPC nameplates.")
ZO_CreateStringId("SI_BETTERUI_NAMEPLATES_ENABLED", "Enable Enhanced Nameplates")
ZO_CreateStringId("SI_BETTERUI_NAMEPLATES_ENABLED_TOOLTIP",
    "Toggle the Enhanced Nameplates feature. When enabled, custom font settings will be applied to all nameplates.")
ZO_CreateStringId("SI_BETTERUI_NAMEPLATES_FONT", "Font")
ZO_CreateStringId("SI_BETTERUI_NAMEPLATES_FONT_TOOLTIP", "Select the font for nameplates from ESO's built-in fonts.")
ZO_CreateStringId("SI_BETTERUI_NAMEPLATES_STYLE", "Font Style")
ZO_CreateStringId("SI_BETTERUI_NAMEPLATES_STYLE_TOOLTIP",
    "Select the style effect for nameplate text (outline, shadow, etc).")
ZO_CreateStringId("SI_BETTERUI_NAMEPLATES_SIZE", "Size")
ZO_CreateStringId("SI_BETTERUI_NAMEPLATES_SIZE_TOOLTIP", "Adjust the size of nameplate text. Default is 16.")
ZO_CreateStringId("SI_BETTERUI_NAMEPLATES_RESET", "Reset Nameplate Settings")
ZO_CreateStringId("SI_BETTERUI_NAMEPLATES_RESET_TOOLTIP", "Reset all nameplate settings to their default values.")

-- Inventory General Settings
ZO_CreateStringId("SI_BETTERUI_INV_GENERAL_HEADER", "General")
ZO_CreateStringId("SI_BETTERUI_INV_GENERAL_DESC",
    "Configure core inventory behavior, including navigation, protection, and interaction options. These settings apply to the Gamepad UI only.")

-- Inventory Font Settings
ZO_CreateStringId("SI_BETTERUI_INV_FONT_HEADER", "Font Customization")
ZO_CreateStringId("SI_BETTERUI_INV_FONT_DESC",
    "Customize fonts for the inventory list. Set different fonts for the Name column and other columns (Type, Trait, Stat, Value).")


-- Inventory Name Column Font Settings
ZO_CreateStringId("SI_BETTERUI_INV_NAME_FONT_SUBMENU", "Name Column Font")
ZO_CreateStringId("SI_BETTERUI_INV_NAME_FONT", "Font")
ZO_CreateStringId("SI_BETTERUI_INV_NAME_FONT_TOOLTIP", "Select the font for item names.")
ZO_CreateStringId("SI_BETTERUI_INV_NAME_FONT_SIZE", "Size")
ZO_CreateStringId("SI_BETTERUI_INV_NAME_FONT_SIZE_TOOLTIP", "Select the font size for item names.")
ZO_CreateStringId("SI_BETTERUI_INV_NAME_FONT_STYLE", "Font Style")
ZO_CreateStringId("SI_BETTERUI_INV_NAME_FONT_STYLE_TOOLTIP", "Select the font style for item names.")

-- Inventory Column Font Settings (Type, Trait, Stat, Value)
ZO_CreateStringId("SI_BETTERUI_INV_COLUMN_FONT_SUBMENU", "Other Columns Font (Type, Trait, Stat, Value)")
ZO_CreateStringId("SI_BETTERUI_INV_COLUMN_FONT", "Font")
ZO_CreateStringId("SI_BETTERUI_INV_COLUMN_FONT_TOOLTIP", "Select the font for column data (Type, Trait, Stat, Value).")
ZO_CreateStringId("SI_BETTERUI_INV_COLUMN_FONT_SIZE", "Size")
ZO_CreateStringId("SI_BETTERUI_INV_COLUMN_FONT_SIZE_TOOLTIP", "Select the font size for column data.")
ZO_CreateStringId("SI_BETTERUI_INV_COLUMN_FONT_STYLE", "Font Style")
ZO_CreateStringId("SI_BETTERUI_INV_COLUMN_FONT_STYLE_TOOLTIP", "Select the font style for column data.")

-- Banking General Settings
ZO_CreateStringId("SI_BETTERUI_BANK_GENERAL_HEADER", "General")
ZO_CreateStringId("SI_BETTERUI_BANK_GENERAL_DESC",
    "Configure core banking behavior, including navigation and interaction options. These settings apply to the Gamepad UI only.")

-- Banking Font Settings
ZO_CreateStringId("SI_BETTERUI_BANK_FONT_HEADER", "Font Customization")
ZO_CreateStringId("SI_BETTERUI_BANK_FONT_DESC",
    "Customize fonts for the banking list. Set different fonts for the Name column and other columns (Type, Trait, Stat, Value).")


-- Banking Name Column Font Settings
ZO_CreateStringId("SI_BETTERUI_BANK_NAME_FONT_SUBMENU", "Name Column Font")
ZO_CreateStringId("SI_BETTERUI_BANK_NAME_FONT", "Font")
ZO_CreateStringId("SI_BETTERUI_BANK_NAME_FONT_TOOLTIP", "Select the font for item names.")
ZO_CreateStringId("SI_BETTERUI_BANK_NAME_FONT_SIZE", "Size")
ZO_CreateStringId("SI_BETTERUI_BANK_NAME_FONT_SIZE_TOOLTIP", "Select the font size for item names.")
ZO_CreateStringId("SI_BETTERUI_BANK_NAME_FONT_STYLE", "Font Style")
ZO_CreateStringId("SI_BETTERUI_BANK_NAME_FONT_STYLE_TOOLTIP", "Select the font style for item names.")

-- Banking Column Font Settings (Type, Trait, Stat, Value)
ZO_CreateStringId("SI_BETTERUI_BANK_COLUMN_FONT_SUBMENU", "Other Columns Font (Type, Trait, Stat, Value)")
ZO_CreateStringId("SI_BETTERUI_BANK_COLUMN_FONT", "Font")
ZO_CreateStringId("SI_BETTERUI_BANK_COLUMN_FONT_TOOLTIP", "Select the font for column data (Type, Trait, Stat, Value).")
ZO_CreateStringId("SI_BETTERUI_BANK_COLUMN_FONT_SIZE", "Size")
ZO_CreateStringId("SI_BETTERUI_BANK_COLUMN_FONT_SIZE_TOOLTIP", "Select the font size for column data.")
ZO_CreateStringId("SI_BETTERUI_BANK_COLUMN_FONT_STYLE", "Font Style")
ZO_CreateStringId("SI_BETTERUI_BANK_COLUMN_FONT_STYLE_TOOLTIP", "Select the font style for column data.")

-- Individual Reset Strings
ZO_CreateStringId("SI_BETTERUI_NAME_FONT_RESET", "Reset Name Font Settings")
ZO_CreateStringId("SI_BETTERUI_NAME_FONT_RESET_TOOLTIP", "Reset name font settings to defaults.")
ZO_CreateStringId("SI_BETTERUI_COLUMN_FONT_RESET", "Reset Other Font Settings")
ZO_CreateStringId("SI_BETTERUI_COLUMN_FONT_RESET_TOOLTIP", "Reset column font settings to defaults.")

-- Font Localization Warnings
ZO_CreateStringId("SI_BETTERUI_FONT_WARNING_CJK",
    "|t24:24:EsoUI/Art/Miscellaneous/ESO_Icon_Warning.dds|t This font may not display Chinese/Japanese characters correctly. Consider using a localized font option.")
ZO_CreateStringId("SI_BETTERUI_FONT_WARNING_CYRILLIC",
    "|t24:24:EsoUI/Art/Miscellaneous/ESO_Icon_Warning.dds|t This font may not display Russian characters correctly. Consider using a localized font option.")

-- Tooltip Strings
ZO_CreateStringId("SI_BETTERUI_BIND_FOR_COLLECTION", "Bind for Collection")

-- Orb Text Settings
ZO_CreateStringId("SI_BETTERUI_ORB_TEXT_HEALTH_SIZE", "Health Text Size")
ZO_CreateStringId("SI_BETTERUI_ORB_TEXT_HEALTH_SIZE_TOOLTIP", "Adjust the font size of the health text")
ZO_CreateStringId("SI_BETTERUI_ORB_TEXT_HEALTH_COLOR", "Health Text Color")
ZO_CreateStringId("SI_BETTERUI_ORB_TEXT_HEALTH_COLOR_TOOLTIP", "Adjust the color of the health text")
ZO_CreateStringId("SI_BETTERUI_ORB_TEXT_MAGICKA_SIZE", "Magicka Text Size")
ZO_CreateStringId("SI_BETTERUI_ORB_TEXT_MAGICKA_SIZE_TOOLTIP", "Adjust the font size of the magicka text")
ZO_CreateStringId("SI_BETTERUI_ORB_TEXT_MAGICKA_COLOR", "Magicka Text Color")
ZO_CreateStringId("SI_BETTERUI_ORB_TEXT_MAGICKA_COLOR_TOOLTIP", "Adjust the color of the magicka text")
ZO_CreateStringId("SI_BETTERUI_ORB_TEXT_STAMINA_SIZE", "Stamina Text Size")
ZO_CreateStringId("SI_BETTERUI_ORB_TEXT_STAMINA_SIZE_TOOLTIP", "Adjust the font size of the stamina text")
ZO_CreateStringId("SI_BETTERUI_ORB_TEXT_STAMINA_COLOR", "Stamina Text Color")
ZO_CreateStringId("SI_BETTERUI_ORB_TEXT_STAMINA_COLOR_TOOLTIP", "Adjust the color of the stamina text")
ZO_CreateStringId("SI_BETTERUI_ORB_TEXT_SHIELD_SIZE", "Shield Text Size")
ZO_CreateStringId("SI_BETTERUI_ORB_TEXT_SHIELD_SIZE_TOOLTIP", "Adjust the font size of the shield text")
ZO_CreateStringId("SI_BETTERUI_ORB_TEXT_SHIELD_COLOR", "Shield Text Color")
ZO_CreateStringId("SI_BETTERUI_ORB_TEXT_SHIELD_COLOR_TOOLTIP", "Adjust the color of the shield text")
ZO_CreateStringId("SI_BETTERUI_ORB_VISUALS_HEADER", "Orb Visuals")
ZO_CreateStringId("SI_BETTERUI_ORB_TEXT_SETTINGS_HEADER", "Orb Text")

-- Resource Orb Frames
ZO_CreateStringId("SI_BETTERUI_RESOURCE_ORB_FRAMES_HEADER", "General")
ZO_CreateStringId("SI_BETTERUI_RESOURCE_ORB_FRAMES_DESC",
    "Configure the Resource Orb Frames HUD overlay, including scale, position, and visual options. Works in both Gamepad and Keyboard UI modes.")


ZO_CreateStringId("SI_BETTERUI_RESOURCE_ORB_FRAMES_SCALE", "Scale")
ZO_CreateStringId("SI_BETTERUI_RESOURCE_ORB_FRAMES_SCALE_TOOLTIP", "Overall size of the frame.")
ZO_CreateStringId("SI_BETTERUI_RESOURCE_ORB_FRAMES_OFFSET", "Offset (Up/Down)")
ZO_CreateStringId("SI_BETTERUI_RESOURCE_ORB_FRAMES_OFFSET_TOOLTIP",
    "Move the frame up/down. Positive moves up; negative moves down.")
ZO_CreateStringId("SI_BETTERUI_RESOURCE_ORB_FRAMES_OFFSET_X", "Offset (Left/Right)")
ZO_CreateStringId("SI_BETTERUI_RESOURCE_ORB_FRAMES_OFFSET_X_TOOLTIP",
    "Move the frame left/right. Negative moves left; positive moves right.")
ZO_CreateStringId("SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET", "Reset General Settings")
ZO_CreateStringId("SI_BETTERUI_RESOURCE_ORB_FRAMES_RESET_TOOLTIP",
    "Reset settings in this section to their default values.")

ZO_CreateStringId("SI_BETTERUI_HIDE_LEFT_ORNAMENT", "Hide Left Ornament")
ZO_CreateStringId("SI_BETTERUI_HIDE_LEFT_ORNAMENT_TOOLTIP", "Hides the decorative ornament around the left (health) orb")
ZO_CreateStringId("SI_BETTERUI_LEFT_ORB_SIZE", "Left Orb Size")
ZO_CreateStringId("SI_BETTERUI_LEFT_ORB_SIZE_TOOLTIP",
    "Adjust the size of the left (health) orb when ornament is hidden. 1.0 = 100%, 1.1 = 110%, 1.2 = 120%")
ZO_CreateStringId("SI_BETTERUI_HIDE_RIGHT_ORNAMENT", "Hide Right Ornament")
ZO_CreateStringId("SI_BETTERUI_HIDE_RIGHT_ORNAMENT_TOOLTIP",
    "Hides the decorative ornament around the right (magicka/stamina) orb")
ZO_CreateStringId("SI_BETTERUI_RIGHT_ORB_SIZE", "Right Orb Size")
ZO_CreateStringId("SI_BETTERUI_RIGHT_ORB_SIZE_TOOLTIP",
    "Adjust the size of the right (magicka/stamina) orb when ornament is hidden. 1.0 = 100%, 1.1 = 110%, 1.2 = 120%")

ZO_CreateStringId("SI_BETTERUI_ORB_TEXT_SUBMENU", "Orb Settings")
ZO_CreateStringId("SI_BETTERUI_XP_BAR_SUBMENU", "Experience Bar")
ZO_CreateStringId("SI_BETTERUI_CAST_BAR_SUBMENU", "Cast Bar")
ZO_CreateStringId("SI_BETTERUI_MOUNT_STAMINA_BAR_SUBMENU", "Mount Stamina Bar")

-- Navigation Settings
ZO_CreateStringId("SI_BETTERUI_ENABLE_CAROUSEL_NAV", "Enable Carousel Navigation")
ZO_CreateStringId("SI_BETTERUI_ENABLE_CAROUSEL_NAV_TOOLTIP",
    "Use the modern carousel style navigation instead of the classic tab bar.")

-- Generic / Shared Settings
ZO_CreateStringId("SI_BETTERUI_TEXT_SIZE", "Text Size")
ZO_CreateStringId("SI_BETTERUI_FONT_COLOR", "Font Color")

-- General Interface Settings
ZO_CreateStringId("SI_BETTERUI_GENERAL_INTERFACE_GENERAL_HEADER", "General")
ZO_CreateStringId("SI_BETTERUI_GENERAL_INTERFACE_GENERAL_DESC",
    "Configure core interface behavior, tooltip integrations, and quality-of-life options. These settings apply to the Gamepad UI only.")
ZO_CreateStringId("SI_BETTERUI_ENHANCED_TOOLTIPS_HEADER", "Enhanced Tooltips")
ZO_CreateStringId("SI_BETTERUI_ENHANCED_TOOLTIPS_DESC",
    "Customize enhanced tooltip behavior, including style/trait details and font sizing.")
ZO_CreateStringId("SI_BETTERUI_ENHANCED_TOOLTIPS_RESET", "Reset Tooltip Settings")
ZO_CreateStringId("SI_BETTERUI_ENHANCED_TOOLTIPS_RESET_TOOLTIP",
    "Reset all settings in this Enhanced Tooltips section to their default values.")
ZO_CreateStringId("SI_BETTERUI_MARKET_INTEGRATION_HEADER", "Market Price Integration")
ZO_CreateStringId("SI_BETTERUI_MARKET_INTEGRATION_DESC",
    "Configure market-value sources for item tooltips. Prices appear in Inventory and Banking value columns, and in the default UI tooltip and BetterUI enhanced tooltip across all applicable scenes (guild stores, merchants, assistants, and more).")
ZO_CreateStringId("SI_BETTERUI_MARKET_INTEGRATION_RESET", "Reset Market Settings")
ZO_CreateStringId("SI_BETTERUI_MARKET_INTEGRATION_RESET_TOOLTIP",
    "Reset all settings in this Market Price Integration section to their default values.")
ZO_CreateStringId("SI_BETTERUI_MARKET_PRICE_PRIORITY", "Market Price Source Priority")
ZO_CreateStringId("SI_BETTERUI_MARKET_PRICE_PRIORITY_TOOLTIP",
    "Choose the source order used when replacing Value in Inventory and Banking.")
ZO_CreateStringId("SI_BETTERUI_MARKET_PRIORITY_MM_ATT_TTC",
    "Master Merchant > Arkadius Trade Tools > Tamriel Trade Centre")
ZO_CreateStringId("SI_BETTERUI_MARKET_PRIORITY_MM_TTC_ATT",
    "Master Merchant > Tamriel Trade Centre > Arkadius Trade Tools")
ZO_CreateStringId("SI_BETTERUI_MARKET_PRIORITY_ATT_MM_TTC",
    "Arkadius Trade Tools > Master Merchant > Tamriel Trade Centre")
ZO_CreateStringId("SI_BETTERUI_MARKET_PRIORITY_ATT_TTC_MM",
    "Arkadius Trade Tools > Tamriel Trade Centre > Master Merchant")
ZO_CreateStringId("SI_BETTERUI_MARKET_PRIORITY_TTC_MM_ATT",
    "Tamriel Trade Centre > Master Merchant > Arkadius Trade Tools")
ZO_CreateStringId("SI_BETTERUI_MARKET_PRIORITY_TTC_ATT_MM",
    "Tamriel Trade Centre > Arkadius Trade Tools > Master Merchant")
ZO_CreateStringId("SI_BETTERUI_GS_ERROR_SUPPRESS", "Guild Store Error Suppression")
ZO_CreateStringId("SI_BETTERUI_GS_ERROR_SUPPRESS_TOOLTIP", "Removes guild store error messages caused by MM or ATT")
ZO_CreateStringId("SI_BETTERUI_ATT_INTEGRATION", "Arkadius Trade Tools")
ZO_CreateStringId("SI_BETTERUI_ATT_INTEGRATION_TOOLTIP", "Hooks ATT Price info into the item tooltips")
ZO_CreateStringId("SI_BETTERUI_MM_INTEGRATION", "Master Merchant integration")
ZO_CreateStringId("SI_BETTERUI_MM_INTEGRATION_TOOLTIP", "Hooks Master Merchant into the item tooltips")
ZO_CreateStringId("SI_BETTERUI_TTC_INTEGRATION", "Tamriel Trade Centre integration")
ZO_CreateStringId("SI_BETTERUI_TTC_INTEGRATION_TOOLTIP", "Hooks TTC Price info into the item tooltips")
ZO_CreateStringId("SI_BETTERUI_ADDON_NOT_DETECTED_TOOLTIP", "Addon not detected: <<1>>.")
ZO_CreateStringId("SI_BETTERUI_SHOW_STYLE_TRAIT", "Tooltip - Style and Trait Knowledge")
ZO_CreateStringId("SI_BETTERUI_SHOW_STYLE_TRAIT_TOOLTIP",
    "Shows an item's style and researchable trait details in the enhanced tooltip. This is separate from item-list icons.")
ZO_CreateStringId("SI_BETTERUI_SHOW_KNOWLEDGE_STATUS", "Tooltip - Recipe & Book Knowledge Status")
ZO_CreateStringId("SI_BETTERUI_SHOW_KNOWLEDGE_STATUS_TOOLTIP",
    "Shows whether recipes, motifs, and lore books are known or not yet learned in the enhanced tooltip. Appears across all scenes.")
ZO_CreateStringId("SI_BETTERUI_CHAT_HISTORY", "Chat window history size")
ZO_CreateStringId("SI_BETTERUI_CHAT_HISTORY_TOOLTIP", "Alters how many lines to store in the chat buffer, default=200")
ZO_CreateStringId("SI_BETTERUI_REMOVE_DELETE_MAIL_CONFIRM", "Skip Mail Delete Confirmation")
ZO_CreateStringId("SI_BETTERUI_MOUSE_SCROLL_SPEED", "Mouse Scrolling speed on Left Hand tooltip")
ZO_CreateStringId("SI_BETTERUI_MOUSE_SCROLL_SPEED_TOOLTIP",
    "Change how quickly the left tooltip scrolls when using the mouse wheel.")
ZO_CreateStringId("SI_BETTERUI_TRIGGER_SKIP", "Number of lines to skip on trigger")
ZO_CreateStringId("SI_BETTERUI_TRIGGER_SKIP_TOOLTIP", "Change how quickly the menu skips when pressing the triggers.")
ZO_CreateStringId("SI_BETTERUI_TOOLTIP_FONT_SIZE", "Tooltip Font Size")
ZO_CreateStringId("SI_BETTERUI_TOOLTIP_FONT_SIZE_TOOLTIP", "Allows you to see more or less item info at once in tooltips")

-- Tooltip Enhancements
ZO_CreateStringId("SI_BETTERUI_ENABLE_TOOLTIP_ENHANCEMENTS", "Enable Tooltip Enhancements")
ZO_CreateStringId("SI_BETTERUI_ENABLE_TOOLTIP_ENHANCEMENTS_TOOLTIP",
    "Enables custom improvements, font scaling, and additional info in the tooltip header. If disabled, reverts to native UI with only Market Price added.")

-- Destructive Settings Warnings
ZO_CreateStringId("SI_BETTERUI_QUICK_DESTROY_WARNING",
    "WARNING: Items will be destroyed WITHOUT confirmation. This can result in permanent item loss.")
ZO_CreateStringId("SI_BETTERUI_ENABLE_BATCH_DESTROY", "Enable multi-select destroy")
ZO_CreateStringId("SI_BETTERUI_ENABLE_BATCH_DESTROY_TOOLTIP",
    "**USE WITH CAUTION** When enabled, the Destroy action appears in the multi-select batch actions menu. This does NOT affect regular single-item destroy.")
ZO_CreateStringId("SI_BETTERUI_ENABLE_BATCH_DESTROY_WARNING",
    "WARNING: BetterUI is not responsible for any accidentally destroyed items. Batch destroy is irreversible. Proceed with caution.")
ZO_CreateStringId("SI_BETTERUI_REMOVE_DELETE_WARNING",
    "WARNING: Mail will be deleted WITHOUT confirmation. Attached items may be lost.")


ZO_CreateStringId("SI_BETTERUI_ENABLE_ORBS", "Enable |c0066FFResource Orb Frames|r")
ZO_CreateStringId("SI_BETTERUI_ENABLE_ORBS_TOOLTIP", "ARPG-style resource orbs and skill bar replacement (Gamepad & Keyboard UI)")

-- Skill Bars Settings (ResourceOrbFrames)
ZO_CreateStringId("SI_BETTERUI_SKILL_BARS_SUBMENU", "Skill Bars")
ZO_CreateStringId("SI_BETTERUI_SKILL_COOLDOWN_TIMER_HEADER", "Skill Cooldown Timer")
ZO_CreateStringId("SI_BETTERUI_SKILL_COOLDOWN_SCALE_TOOLTIP", "Adjust the font size of the skill cooldown timer")
ZO_CreateStringId("SI_BETTERUI_SKILL_COOLDOWN_COLOR_TOOLTIP", "Adjust the color of the skill cooldown timer")
ZO_CreateStringId("SI_BETTERUI_QUICKSLOTS_HEADER", "Quickslots")
ZO_CreateStringId("SI_BETTERUI_QUICKSLOT_SCALE_TOOLTIP", "Adjust the font size of the quickslot count")
ZO_CreateStringId("SI_BETTERUI_QUICKSLOT_COLOR_TOOLTIP", "Adjust the color of the quickslot count")
ZO_CreateStringId("SI_BETTERUI_BACK_BAR_HEADER", "Back Bar Appearance")
ZO_CreateStringId("SI_BETTERUI_BACK_BAR_OPACITY", "Back Bar Opacity")
ZO_CreateStringId("SI_BETTERUI_BACK_BAR_OPACITY_TOOLTIP",
    "Adjust how dimmed the back bar icons appear. Lower values make the back bar less noticeable.")
ZO_CreateStringId("SI_BETTERUI_HIDE_BACK_BAR", "Hide Back Bar")
ZO_CreateStringId("SI_BETTERUI_HIDE_BACK_BAR_TOOLTIP",
    "Completely hides the back bar (top skill bar). Useful for Oakensoul or one-bar builds.")
ZO_CreateStringId("SI_BETTERUI_RESET_SKILL_BAR", "Reset Skill Bar Settings")
ZO_CreateStringId("SI_BETTERUI_ORB_TEXT_RESET", "Reset Orb Settings")
ZO_CreateStringId("SI_BETTERUI_XP_BAR_RESET", "Reset Exp Bar Settings")
ZO_CreateStringId("SI_BETTERUI_CAST_BAR_RESET", "Reset Cast Bar Settings")
ZO_CreateStringId("SI_BETTERUI_MOUNT_STAMINA_BAR_RESET", "Reset Mount Bar Settings")

-- ResourceOrbFrames Additional Settings
ZO_CreateStringId("SI_BETTERUI_ROF_WEAPON_SWAP_ANIMATION", "Enable Weapon Swap Animation")
ZO_CreateStringId("SI_BETTERUI_ROF_WEAPON_SWAP_ANIMATION_TOOLTIP",
    "Plays a slide animation when switching between main and backup weapon bars.")
ZO_CreateStringId("SI_BETTERUI_ROF_ORB_ANIMATIONS", "Enable Orb Animations")
ZO_CreateStringId("SI_BETTERUI_ROF_ORB_ANIMATIONS_TOOLTIP",
    "Adds subtle animations to orb elements. Resource fills gently oscillate, and the shield overlay slowly rotates.")

-- Ultimate Number Display Settings
ZO_CreateStringId("SI_BETTERUI_ULTIMATE_DISPLAY_HEADER", "Ultimate Number Display")
ZO_CreateStringId("SI_BETTERUI_SHOW_ULTIMATE_NUMBER", "Show Ultimate Number")
ZO_CreateStringId("SI_BETTERUI_SHOW_ULTIMATE_NUMBER_TOOLTIP",
    "Display your current ultimate value on the ultimate button.")
ZO_CreateStringId("SI_BETTERUI_ULTIMATE_TEXT_SIZE", "Ultimate Text Size")
ZO_CreateStringId("SI_BETTERUI_ULTIMATE_TEXT_SIZE_TOOLTIP", "Font size for the ultimate number display.")
ZO_CreateStringId("SI_BETTERUI_ULTIMATE_TEXT_COLOR", "Ultimate Text Color")
ZO_CreateStringId("SI_BETTERUI_ULTIMATE_TEXT_COLOR_TOOLTIP", "Color for the ultimate number display.")

-- Quickslot Cooldown Settings
ZO_CreateStringId("SI_BETTERUI_SHOW_QUICKSLOT_COOLDOWN", "Show Quickslot Cooldown")
ZO_CreateStringId("SI_BETTERUI_SHOW_QUICKSLOT_COOLDOWN_TOOLTIP",
    "Display cooldown timer on the quickslot button, replacing the item count during cooldown.")
ZO_CreateStringId("SI_BETTERUI_SHOW_QUICKSLOT_QUANTITY", "Show Quickslot Quantity")
ZO_CreateStringId("SI_BETTERUI_SHOW_QUICKSLOT_QUANTITY_TOOLTIP",
    "Displays the item count for the current quickslot item.")

-- Combat Indicators Settings
ZO_CreateStringId("SI_BETTERUI_COMBAT_INDICATORS_HEADER", "Combat Indicators")
ZO_CreateStringId("SI_BETTERUI_COMBAT_GLOW_ENABLED", "Enable Combat Glow")
ZO_CreateStringId("SI_BETTERUI_COMBAT_GLOW_ENABLED_TOOLTIP",
    "Display a pulsing red/orange glow around the skill bar when in combat.")
ZO_CreateStringId("SI_BETTERUI_COMBAT_ICON_ENABLED", "Enable Combat Icon")
ZO_CreateStringId("SI_BETTERUI_COMBAT_ICON_ENABLED_TOOLTIP", "Display a crossed swords icon when in combat.")
ZO_CreateStringId("SI_BETTERUI_COMBAT_AUDIO_ENABLED", "Enable Combat Audio Cue")
ZO_CreateStringId("SI_BETTERUI_COMBAT_AUDIO_ENABLED_TOOLTIP", "Play a sound when entering and exiting combat.")

-- XP Bar Settings
ZO_CreateStringId("SI_BETTERUI_XP_BAR_ENABLED", "Enable Experience Bar")
ZO_CreateStringId("SI_BETTERUI_XP_BAR_ENABLED_TOOLTIP",
    "Displays an experience/champion point bar below the left ornament")
ZO_CreateStringId("SI_BETTERUI_XP_BAR_TEXT_SIZE", "XP Text Size")
ZO_CreateStringId("SI_BETTERUI_XP_BAR_TEXT_SIZE_TOOLTIP", "Adjust the font size of the experience text")
ZO_CreateStringId("SI_BETTERUI_XP_BAR_TEXT_COLOR", "XP Text Color")
ZO_CreateStringId("SI_BETTERUI_XP_BAR_TEXT_COLOR_TOOLTIP", "Adjust the color of the experience text")

-- Cast Bar Settings
ZO_CreateStringId("SI_BETTERUI_CAST_BAR_ENABLED", "Enable Cast Bar")
ZO_CreateStringId("SI_BETTERUI_CAST_BAR_ENABLED_TOOLTIP", "Displays a casting bar above the top skill bar")
ZO_CreateStringId("SI_BETTERUI_CAST_BAR_ALWAYS_SHOW", "Always Show Cast Bar")
ZO_CreateStringId("SI_BETTERUI_CAST_BAR_ALWAYS_SHOW_TOOLTIP",
    "When enabled, the cast bar frame is always visible. When disabled, the cast bar only appears during casting.")
ZO_CreateStringId("SI_BETTERUI_CAST_BAR_TEXT_SIZE", "Cast Text Size")
ZO_CreateStringId("SI_BETTERUI_CAST_BAR_TEXT_SIZE_TOOLTIP", "Adjust the font size of the cast timer")
ZO_CreateStringId("SI_BETTERUI_CAST_BAR_TEXT_COLOR", "Cast Text Color")
ZO_CreateStringId("SI_BETTERUI_CAST_BAR_TEXT_COLOR_TOOLTIP", "Adjust the color of the cast timer text")

-- Mount Stamina Bar Settings
ZO_CreateStringId("SI_BETTERUI_MOUNT_BAR_ENABLED", "Enable Mount Stamina Bar")
ZO_CreateStringId("SI_BETTERUI_MOUNT_BAR_ENABLED_TOOLTIP", "Displays a mount stamina bar under the right ornament")
ZO_CreateStringId("SI_BETTERUI_MOUNT_BAR_TEXT_SIZE", "Mount Stamina Text Size")
ZO_CreateStringId("SI_BETTERUI_MOUNT_BAR_TEXT_SIZE_TOOLTIP", "Adjust the font size of the mount stamina text")
ZO_CreateStringId("SI_BETTERUI_MOUNT_BAR_TEXT_COLOR", "Mount Stamina Text Color")
ZO_CreateStringId("SI_BETTERUI_MOUNT_BAR_TEXT_COLOR_TOOLTIP", "Adjust the color of the mount stamina text")

-- Inventory / Banking Shared Icon Settings
ZO_CreateStringId("SI_BETTERUI_ICON_UNBOUND", "Item Icon - Unbound Items")
ZO_CreateStringId("SI_BETTERUI_ICON_UNBOUND_TOOLTIP", "Show an icon after unbound items.")
ZO_CreateStringId("SI_BETTERUI_ICON_ENCHANTMENT", "Item Icon - Enchantment")
ZO_CreateStringId("SI_BETTERUI_ICON_ENCHANTMENT_TOOLTIP", "Show an icon after enchanted item.")
ZO_CreateStringId("SI_BETTERUI_ICON_SET_GEAR", "Item Icon - Set Gear")
ZO_CreateStringId("SI_BETTERUI_ICON_SET_GEAR_TOOLTIP", "Show an icon after set gears.")
ZO_CreateStringId("SI_BETTERUI_ICON_RESEARCHABLE_TRAIT", "Item Icon - Researchable Trait")
ZO_CreateStringId("SI_BETTERUI_ICON_RESEARCHABLE_TRAIT_TOOLTIP",
    "Show an icon after items with traits you can research.")
ZO_CreateStringId("SI_BETTERUI_ICON_UNKNOWN_RECIPE", "Item Icon - Unknown Recipe")
ZO_CreateStringId("SI_BETTERUI_ICON_UNKNOWN_RECIPE_TOOLTIP",
    "Show an icon after recipe items that are not yet learned.")
ZO_CreateStringId("SI_BETTERUI_ICON_UNKNOWN_BOOK", "Item Icon - Unknown Book")
ZO_CreateStringId("SI_BETTERUI_ICON_UNKNOWN_BOOK_TOOLTIP",
    "Show an icon after books or lorebooks that are not yet learned.")
ZO_CreateStringId("SI_BETTERUI_ICON_SUBMENU_HEADER", "Item Icon Customization")
ZO_CreateStringId("SI_BETTERUI_ICON_SUBMENU_TOOLTIP", "Configure which status icons appear next to item names.")
ZO_CreateStringId("SI_BETTERUI_ICON_SUBMENU_DESC",
    "Choose which item-state icons to display in Inventory and Banking lists. Icons scale with Name column font size and can be toggled individually.")
ZO_CreateStringId("SI_BETTERUI_ICON_SUBMENU_RESET", "Reset Item Icon Settings")
ZO_CreateStringId("SI_BETTERUI_ICON_SUBMENU_RESET_TOOLTIP",
    "Reset item icon customization settings to their default values.")

-- Inventory Specific Settings
ZO_CreateStringId("SI_BETTERUI_QUICK_DESTROY", "Enable quick destroy functionality")
ZO_CreateStringId("SI_BETTERUI_QUICK_DESTROY_TOOLTIP",
    "**USE WITH CAUTION** Quickly destroys items without a confirmation dialog! Does not apply to multi-select mode (batch destroy always requires confirmation).")
ZO_CreateStringId("SI_BETTERUI_TRIGGER_SKIP_TYPE", "Use triggers to move to next item")
ZO_CreateStringId("SI_BETTERUI_TRIGGER_SKIP_TYPE_TOOLTIP",
    "Rather than skip a certain number of items every trigger press (default global behaviour), this will move to the next item")
ZO_CreateStringId("SI_BETTERUI_SHOW_MARKET_PRICE", "Replace \"Value\" with the market's price")
ZO_CreateStringId("SI_BETTERUI_SHOW_MARKET_PRICE_TOOLTIP",
    "Replaces the Value column in Inventory and Banking with MM, ATT, or TTC market prices when available.")
ZO_CreateStringId("SI_BETTERUI_BOE_PROTECTION", "Bind on Equip Protection")
ZO_CreateStringId("SI_BETTERUI_BOE_PROTECTION_TOOLTIP", "Show a dialog before equipping Bind on Equip items")

-- Banking Specific Strings
ZO_CreateStringId("SI_BETTERUI_BANK_HOUSE_EMPTY", "HOUSE BANK IS EMPTY!")
ZO_CreateStringId("SI_BETTERUI_BANK_HOUSE", "HOUSE BANK")
ZO_CreateStringId("SI_BETTERUI_BANK_PLAYER_EMPTY", "PLAYER BAG IS EMPTY!")
ZO_CreateStringId("SI_BETTERUI_BANK_PLAYER", "PLAYER BAG")
ZO_CreateStringId("SI_BETTERUI_BANK_NO_FUNDS", "Not enough funds available for transfer.")
ZO_CreateStringId("SI_BETTERUI_BANK_TITLE", "Advanced Banking")
ZO_CreateStringId("SI_BETTERUI_BANK_DEPOSIT_QUANTITY", "Deposit How Many?")
ZO_CreateStringId("SI_BETTERUI_BANK_WITHDRAW_QUANTITY", "Withdraw How Many?")
ZO_CreateStringId("SI_BETTERUI_BANK_DEPOSIT_PROMPT", "Select the amount to deposit")
ZO_CreateStringId("SI_BETTERUI_BANK_WITHDRAW_PROMPT", "Select the amount to withdraw")
ZO_CreateStringId("SI_BETTERUI_BANK_WITHDRAW_MAX", "Withdraw Stack")
ZO_CreateStringId("SI_BETTERUI_BANK_DEPOSIT_MAX", "Deposit Stack")
ZO_CreateStringId("SI_BETTERUI_BANK_SLIDER_MIN", "Min Quantity")
ZO_CreateStringId("SI_BETTERUI_BANK_SLIDER_MAX", "Max Quantity")

-- Craft Bag Stow/Retrieve Quantity Dialog
ZO_CreateStringId("SI_BETTERUI_STOW_QUANTITY", "Stow How Many?")
ZO_CreateStringId("SI_BETTERUI_RETRIEVE_QUANTITY", "Retrieve How Many?")
ZO_CreateStringId("SI_BETTERUI_STOW_PROMPT", "Select the amount to stow")
ZO_CreateStringId("SI_BETTERUI_RETRIEVE_PROMPT", "Select the amount to retrieve")
ZO_CreateStringId("SI_BETTERUI_STOW_STACK", "Stow Stack")
ZO_CreateStringId("SI_BETTERUI_RETRIEVE_STACK", "Retrieve Stack")

-- Imagery strings moved from Globals.lua
ZO_CreateStringId("SI_BETTERUI_INV_EQUIP_TEXT_HIGHLIGHT", "|cFF6600<<1>>|r")
ZO_CreateStringId("SI_BETTERUI_INV_EQUIP_TEXT_NORMAL", "|cCCCCCC<<1>>|r")
ZO_CreateStringId("SI_BETTERUI_CLEAR_SORT", "Clear Sort")
ZO_CreateStringId("SI_BETTERUI_SLIDER_DEPOSIT", "Deposit")
ZO_CreateStringId("SI_BETTERUI_SLIDER_KEEPS", "Keeps")
ZO_CreateStringId("SI_BETTERUI_SLIDER_RETRIEVE", "Retrieve")
ZO_CreateStringId("SI_BETTERUI_SLIDER_STAYS", "Stays")
ZO_CreateStringId("SI_BETTERUI_SLIDER_STOW", "Stow")

-- Vendor Settings Strings
ZO_CreateStringId("SI_BETTERUI_VENDOR_GENERAL_HEADER", "General")
ZO_CreateStringId("SI_BETTERUI_VENDOR_GENERAL_DESC",
    "Configure core vendor behavior, including navigation and batch options. These settings apply to the Gamepad UI only.")
ZO_CreateStringId("SI_BETTERUI_VENDOR_BATCH_JUNK_SELL", "Batch Junk Sell")
ZO_CreateStringId("SI_BETTERUI_VENDOR_BATCH_JUNK_SELL_TOOLTIP",
    "When enabled, provides a quick option to sell all junk items at once when visiting a vendor.")
ZO_CreateStringId("SI_BETTERUI_VENDOR_FONT_HEADER", "Font Customization")
ZO_CreateStringId("SI_BETTERUI_VENDOR_FONT_DESC",
    "Customize fonts for the vendor list. Set different fonts for the Name column and other columns.")
ZO_CreateStringId("SI_BETTERUI_VENDOR_NAME_FONT_SUBMENU", "Name Column Font")
ZO_CreateStringId("SI_BETTERUI_VENDOR_NAME_FONT", "Font")
ZO_CreateStringId("SI_BETTERUI_VENDOR_NAME_FONT_TOOLTIP", "Select the font for item names.")
ZO_CreateStringId("SI_BETTERUI_VENDOR_NAME_FONT_SIZE", "Size")
ZO_CreateStringId("SI_BETTERUI_VENDOR_NAME_FONT_SIZE_TOOLTIP", "Select the font size for item names.")
ZO_CreateStringId("SI_BETTERUI_VENDOR_NAME_FONT_STYLE", "Font Style")
ZO_CreateStringId("SI_BETTERUI_VENDOR_NAME_FONT_STYLE_TOOLTIP", "Select the font style for item names.")
ZO_CreateStringId("SI_BETTERUI_VENDOR_COLUMN_FONT_SUBMENU", "Other Columns Font")
ZO_CreateStringId("SI_BETTERUI_VENDOR_COLUMN_FONT", "Font")
ZO_CreateStringId("SI_BETTERUI_VENDOR_COLUMN_FONT_TOOLTIP", "Select the font for column data.")
ZO_CreateStringId("SI_BETTERUI_VENDOR_COLUMN_FONT_SIZE", "Size")
ZO_CreateStringId("SI_BETTERUI_VENDOR_COLUMN_FONT_SIZE_TOOLTIP", "Select the font size for column data.")
ZO_CreateStringId("SI_BETTERUI_VENDOR_COLUMN_FONT_STYLE", "Font Style")
ZO_CreateStringId("SI_BETTERUI_VENDOR_COLUMN_FONT_STYLE_TOOLTIP", "Select the font style for column data.")
ZO_CreateStringId("SI_BETTERUI_VENDOR_CANNOT_AFFORD", "Cannot afford this item.")
ZO_CreateStringId("SI_BETTERUI_VENDOR_CANNOT_CARRY", "Not enough inventory space.")
ZO_CreateStringId("SI_BETTERUI_VENDOR_TAB_BUY", "Buy")
ZO_CreateStringId("SI_BETTERUI_VENDOR_TAB_SELL", "Sell")
ZO_CreateStringId("SI_BETTERUI_VENDOR_TAB_REPAIR", "Repair")
ZO_CreateStringId("SI_BETTERUI_VENDOR_TAB_BUYBACK", "Buyback")
ZO_CreateStringId("SI_BETTERUI_VENDOR_TAB_FENCE_SELL", "Sell Stolen")
ZO_CreateStringId("SI_BETTERUI_VENDOR_TAB_FENCE_LAUNDER", "Launder")
ZO_CreateStringId("SI_BETTERUI_VENDOR_TITLE", "Enhanced Vendor")
ZO_CreateStringId("SI_BETTERUI_VENDOR_NO_JUNK", "No junk items to sell.")
ZO_CreateStringId("SI_BETTERUI_VENDOR_CONDITION", "<<1>>%")
ZO_CreateStringId("SI_BETTERUI_FENCE_SELLS_REMAINING", "Fence Sells Remaining: <<1>>/<<2>>")
ZO_CreateStringId("SI_BETTERUI_FENCE_LAUNDERS_REMAINING", "Fence Launders Remaining: <<1>>/<<2>>")

-- Guild Bank Settings
ZO_CreateStringId("SI_BETTERUI_GUILD_BANK_ENABLED", "Enable Enhanced Guild Bank")
ZO_CreateStringId("SI_BETTERUI_GUILD_BANK_ENABLED_TOOLTIP",
    "When enabled, BetterUI replaces the default guild bank interface with the enhanced Banking layout. Disable to use the default ESO guild bank UI. Requires /reloadui.")
ZO_CreateStringId("SI_BETTERUI_SLIDER_WITHDRAW", "Withdraw")

-- Companions Module
ZO_CreateStringId("SI_BETTERUI_COMPANIONS_TITLE", "Companion Equipment")
ZO_CreateStringId("SI_BETTERUI_COMPANIONS_GENERAL_HEADER", "General")
ZO_CreateStringId("SI_BETTERUI_COMPANIONS_GENERAL_DESC",
    "Configure BetterUI companion equipment behavior. These settings apply to the Gamepad UI only.")
ZO_CreateStringId("SI_BETTERUI_COMPANIONS_ENABLE_EQUIPMENT", "Enable Companion Equipment Replacement")
ZO_CreateStringId("SI_BETTERUI_COMPANIONS_ENABLE_EQUIPMENT_TOOLTIP",
    "When enabled, BetterUI replaces the default companion equipment gamepad screen. Requires /reloadui.")
ZO_CreateStringId("SI_BETTERUI_COMPANIONS_FONT_HEADER", "Font Customization")
ZO_CreateStringId("SI_BETTERUI_COMPANIONS_FONT_DESC",
    "Customize fonts for the companions equipment list.")
ZO_CreateStringId("SI_BETTERUI_COMPANIONS_NAME_FONT_SUBMENU", "Name Column Font")
ZO_CreateStringId("SI_BETTERUI_COMPANIONS_NAME_FONT", "Font")
ZO_CreateStringId("SI_BETTERUI_COMPANIONS_NAME_FONT_TOOLTIP", "Select the font for companion item names.")
ZO_CreateStringId("SI_BETTERUI_COMPANIONS_NAME_FONT_SIZE", "Size")
ZO_CreateStringId("SI_BETTERUI_COMPANIONS_NAME_FONT_SIZE_TOOLTIP", "Select the font size for companion item names.")
ZO_CreateStringId("SI_BETTERUI_COMPANIONS_NAME_FONT_STYLE", "Font Style")
ZO_CreateStringId("SI_BETTERUI_COMPANIONS_NAME_FONT_STYLE_TOOLTIP", "Select the font style for companion item names.")
ZO_CreateStringId("SI_BETTERUI_COMPANIONS_COLUMN_FONT_SUBMENU", "Other Columns Font")
ZO_CreateStringId("SI_BETTERUI_COMPANIONS_COLUMN_FONT", "Font")
ZO_CreateStringId("SI_BETTERUI_COMPANIONS_COLUMN_FONT_TOOLTIP", "Select the font for type, trait, stat, and value columns.")
ZO_CreateStringId("SI_BETTERUI_COMPANIONS_COLUMN_FONT_SIZE", "Size")
ZO_CreateStringId("SI_BETTERUI_COMPANIONS_COLUMN_FONT_SIZE_TOOLTIP", "Select the font size for companion column data.")
ZO_CreateStringId("SI_BETTERUI_COMPANIONS_COLUMN_FONT_STYLE", "Font Style")
ZO_CreateStringId("SI_BETTERUI_COMPANIONS_COLUMN_FONT_STYLE_TOOLTIP", "Select the font style for companion column data.")
