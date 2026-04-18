--[[
File: Modules/CIM/Core/Types.lua
Purpose: Shared EmmyLua type definitions for BetterUI.
         Provides centralized type annotations used across all modules.

This file should be loaded early in the CIM module load order.
It defines types that are referenced by annotations throughout the codebase.
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Types = {}

-- ESO API TYPE STUBS
-- These definitions help the IDE understand ESO's global types

---@alias BagId number ESO bag constant (e.g. BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK, BAG_GUILDBANK)
---@alias SlotIndex number Zero-based slot position within a bag
---@alias ItemLink string ESO item link string (e.g. "|H1:item:...|h|h")
---@alias EventCode number ESO EVENT_* constant

-- CORE ITEM DATA TYPES

---@class SlotData
---@field bagId BagId Bag containing this item
---@field slotIndex SlotIndex Slot position within the bag
---@field name string Display name of the item
---@field quality number Item quality/rarity tier (0-5)
---@field stackCount number Current stack size
---@field iconFile string Texture path for the item icon
---@field itemLink ItemLink Full ESO item link
---@field meetsUsageRequirement boolean Whether the current character can use this item
---@field locked boolean Whether the item is locked by the player
---@field isPlayerLocked boolean Whether the item has a player lock
---@field filterData number[] Array of filter type constants for categorization
---@field statValue number Item stat/armor/damage value
---@field sellPrice number Vendor sell price in gold
---@field traitType number Trait type constant
---@field level number Required level or champion level

-- CATEGORY TYPES

---@class CategoryDef
---@field name string Display name of the category
---@field icon string Texture path for the category icon
---@field filters number[] Filter type constants that match this category
---@field subcategories CategoryDef[]|nil Optional subcategory definitions

---@alias CategoryIndex number One-based index into the visible category list

-- SORTING TYPES

---@alias SortKey
---| "name"
---| "quality"
---| "stackCount"
---| "level"
---| "value"
---| "type"
---| "trait"
---| "status"

---@alias SortDirection "asc"|"desc"

-- MODULE TYPES

---@alias ModuleName
---| "Inventory"
---| "Banking"
---| "ResourceOrbFrames"
---| "Writs"
---| "CIM"
---| "Vendor"
---| "TradingHouse"
---| "Companions"
---| "GeneralInterface"
---| "Nameplates"

---@alias BetterUIModuleArchetype
---| "runtime-coordinator"
---| "settings-owner"
---| "thin-entrypoint"

---@alias BetterUIModuleOptions table<string, BetterUIModuleSettingValue|nil>
---@alias BetterUIModuleInitHook fun(m_options: BetterUIModuleOptions|nil): BetterUIModuleOptions
---@alias BetterUIModuleSetupHook fun()

---@class BetterUIModuleRootContract
---@field name ModuleName
---@field archetype BetterUIModuleArchetype
---@field initOwner string
---@field setupOwner string|nil
---@field runtimeOwner string
---@field settingsOwner string|nil
---@field notes string

---@class BetterUIModuleRoot
---@field ARCHETYPE BetterUIModuleArchetype
---@field ROOT_CONTRACT BetterUIModuleRootContract
---@field InitModule BetterUIModuleInitHook|nil
---@field Setup BetterUIModuleSetupHook|nil
---@field GetSetting fun(key: BetterUIModuleSettingKey): BetterUIModuleSettingValue|nil
---@field SetSetting fun(key: BetterUIModuleSettingKey, value: BetterUIModuleSettingValue): boolean|nil
---@field DEFAULTS table|nil

-- SCENE & LIFECYCLE TYPES

---@alias SceneState "showing"|"shown"|"hiding"|"hidden"

---@class SceneStateChange
---@field oldState SceneState Previous scene state
---@field newState SceneState New scene state

-- KEYBIND TYPES

---@class KeybindDescriptor
---@field keybind string Keybind action name
---@field name string|function Display name for the keybind
---@field callback function Action to perform when keybind is pressed
---@field visible function|nil Optional visibility predicate
---@field enabled function|nil Optional enabled predicate

---@class BetterUIHeaderSortColumnDef
---@field name string Display name shown in the header row
---@field key string Stable column identifier
---@field sortKey string|nil Data field used for comparisons
---@field defaultDirection SortDirection|nil Preferred initial direction

---@class BetterUIHeaderSortControllerContract
---@field instance table|nil Existing controller instance to reuse
---@field field string|nil Primary owner field that stores the controller
---@field aliasFields string[]|nil Additional owner fields that mirror the controller
---@field resolve fun(owner: table): table|nil Optional resolver for dynamic controller ownership
---@field initialize fun(owner: table)|nil Optional initializer that prepares controller state before resolution

---@class BetterUIHeaderSortKeybindContract
---@field mainDescriptor table|nil Owner keybind descriptor restored after header mode exits

---@class BetterUIHeaderSortNavigationContract
---@field deactivate fun(owner: table)|nil Callback that suspends owner navigation before header mode
---@field reactivate fun(owner: table)|nil Callback that restores owner navigation after header mode
---@field suspendTabBar boolean|nil When true, use the shared tab-bar suspend/restore behavior

---@class BetterUIHeaderSortCallbackContract
---@field onSortChanged fun(columnKey: string, direction: SortDirection, sortFn: function|nil)|nil
---@field onControllerCreated fun(owner: table, controller: table, list: table|nil)|nil
---@field onEnterHeaderMode fun(owner: table, controller: table, list: table|nil)|nil
---@field onExitHeaderMode fun(owner: table, controller: table|nil)|nil

---@class BetterUIHeaderSortInstallOptions
---@field list table|nil Static list owned by the integration
---@field listFn fun(owner: table): table|nil Optional list resolver for dynamic list owners
---@field columns BetterUIHeaderSortColumnDef[]|nil Column descriptors used to build controllers
---@field controllerContract BetterUIHeaderSortControllerContract|nil Controller ownership contract
---@field keybinds BetterUIHeaderSortKeybindContract|nil Owner keybind contract
---@field navigation BetterUIHeaderSortNavigationContract|nil Navigation suspend/restore contract
---@field callbacks BetterUIHeaderSortCallbackContract|nil Shared lifecycle callbacks
---@field createControllerFn fun(owner: table, list: table|nil): table|nil Optional controller factory override
---@field autoEnterOnListStart boolean|nil Whether hitting the top of the list should enter header mode

---@class BetterUIHeaderSortLegacyInstallOptions
---@field controller table|nil Deprecated flat controller instance field
---@field controllerField string|nil Deprecated flat controller owner field
---@field controllerAliasFields string[]|nil Deprecated flat controller alias fields
---@field headerControllerFn fun(owner: table): table|nil Deprecated flat controller resolver
---@field initControllerFn fun(owner: table)|nil Deprecated flat controller initializer
---@field keybindDescriptor table|nil Deprecated flat owner keybind descriptor
---@field mainKeybindDescriptor table|nil Deprecated flat owner keybind descriptor alias
---@field deactivateNavigationFn fun(owner: table)|nil Deprecated flat navigation suspend callback
---@field reactivateNavigationFn fun(owner: table)|nil Deprecated flat navigation restore callback
---@field onSortChangedCallback fun(columnKey: string, direction: SortDirection, sortFn: function|nil)|nil Deprecated flat sort callback
---@field onControllerCreated fun(owner: table, controller: table, list: table|nil)|nil Deprecated flat controller-created callback
---@field onEnterHeaderMode fun(owner: table, controller: table, list: table|nil)|nil Deprecated flat enter callback
---@field onExitHeaderMode fun(owner: table, controller: table|nil)|nil Deprecated flat exit callback
---@field suspendTabBar boolean|nil Deprecated flat tab-bar suspend flag

---@class BetterUIHeaderSortIntegration
---@field owner table Owner instance receiving the header-sort contract
---@field list table|nil Static list reference
---@field listFn fun(owner: table): table|nil Dynamic list resolver
---@field controller table|nil Active header sort controller
---@field controllerContract BetterUIHeaderSortControllerContract
---@field columns BetterUIHeaderSortColumnDef[]|nil Column descriptors
---@field callbacks BetterUIHeaderSortCallbackContract
---@field keybinds BetterUIHeaderSortKeybindContract
---@field navigation BetterUIHeaderSortNavigationContract
---@field createControllerFn fun(owner: table, list: table|nil): table|nil
---@field autoEnterOnListStart boolean
---@field isActive boolean
---@field activeKeybindDescriptor table|nil

-- CALLBACK EVENT NAMES

---@alias BetterUIEvent
---| "BETTERUI_EVENT_ACTION_DIALOG_SETUP"
---| "BETTERUI_EVENT_ACTION_DIALOG_FINISH"
---| "BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM"
---| "BetterUI_ForceLayoutUpdate"
---| "BETTERUI_EVENT_INVENTORY_REFRESH"
---| "BETTERUI_EVENT_BANK_REFRESH"

-- TIMING CONSTANTS TYPE

---@class TimingConstants
---@field DEBOUNCE_MS number Debounce for heavy UI updates (ms)
---@field CATEGORY_CHANGE_DELAY_MS number Category navigation coalescing delay (ms)
---@field MOVE_COALESCE_DELAY_MS number Item move coalescing delay (ms)

-- SETTINGS TYPES

---@alias BetterUIListModuleName
---| "Inventory"
---| "Banking"
---| "Vendor"
---| "TradingHouse"
---| "Companions"

---@class BetterUISharedFontSettings
---@field nameFont string|nil
---@field nameFontSize number|nil
---@field nameFontStyle string|number|nil
---@field columnFont string|nil
---@field columnFontSize number|nil
---@field columnFontStyle string|number|nil
---@field showIconEnchantment boolean|nil
---@field showIconSetGear boolean|nil
---@field showIconUnboundItem boolean|nil
---@field showIconResearchableTrait boolean|nil
---@field showIconUnknownRecipe boolean|nil
---@field showIconUnknownBook boolean|nil

---@class BetterUIInventorySettings: BetterUISharedFontSettings
---@field quickDestroy boolean|nil
---@field enableBatchDestroy boolean|nil
---@field enableCarousel boolean|nil
---@field useTriggersForSkip boolean|nil
---@field triggerSpeed number|nil
---@field bindOnEquipProtection boolean|nil
---@field enableCompanionJunk boolean|nil
---@field currencyPreset string|nil
---@field currencyOrder string|nil

---@class BetterUIBankingSettings: BetterUISharedFontSettings
---@field enableGuildBank boolean|nil
---@field enableCarousel boolean|nil
---@field useTriggersForSkip boolean|nil
---@field triggerSpeed number|nil

---@class BetterUIVendorSettings: BetterUISharedFontSettings
---@field enableCarousel boolean|nil
---@field enableBatchJunkSell boolean|nil
---@field abbreviateVendorCurrency boolean|nil

---@class BetterUITradingHouseSettings: BetterUISharedFontSettings
---@field enableCarousel boolean|nil
---@field searchPresets table|nil

---@class BetterUICompanionsSettings: BetterUISharedFontSettings
---@field enableCompanionEquipment boolean|nil
---@field quickDestroy boolean|nil
---@field batchDestroy boolean|nil
---@field bindOnEquipProtection boolean|nil
---@field enableCompanionJunk boolean|nil

---@class BetterUIGeneralInterfaceSettings
---@field showMarketPrice boolean|nil
---@field marketPricePriority string|nil
---@field showStyleTrait boolean|nil
---@field showKnowledgeStatus boolean|nil
---@field chatHistory number|nil
---@field attIntegration boolean|nil
---@field mmIntegration boolean|nil
---@field ttcIntegration boolean|nil
---@field guildStoreErrorSuppress boolean|nil
---@field removeDeleteDialog boolean|nil

---@class BetterUINameplatesSettings
---@field m_enabled boolean|nil
---@field font string|nil
---@field style number|string|nil
---@field size number|nil

---@class BetterUIResourceOrbFramesFrontBarOffsetSettings
---@field offsetX number|nil
---@field offsetY number|nil

---@class BetterUIResourceOrbFramesFrontBarLayoutSettings
---@field buttonSize number|nil
---@field spacing number|nil
---@field ultimateSize number|nil

---@class BetterUIResourceOrbFramesFrontBarSettings
---@field m_enabled boolean|nil
---@field offsetX number|nil
---@field offsetY number|nil
---@field ultimate BetterUIResourceOrbFramesFrontBarOffsetSettings|nil
---@field quickslotButton BetterUIResourceOrbFramesFrontBarOffsetSettings|nil
---@field companionButton BetterUIResourceOrbFramesFrontBarOffsetSettings|nil
---@field gamepad BetterUIResourceOrbFramesFrontBarLayoutSettings|nil
---@field keyboard BetterUIResourceOrbFramesFrontBarLayoutSettings|nil

---@class BetterUIResourceOrbFramesSettings
---@field m_enabled boolean|nil
---@field scale number|nil
---@field offsetX number|nil
---@field offsetY number|nil
---@field centerBarType string|nil
---@field healthTextSize number|nil
---@field healthTextColor table|nil
---@field magickaTextSize number|nil
---@field magickaTextColor table|nil
---@field staminaTextSize number|nil
---@field staminaTextColor table|nil
---@field shieldTextSize number|nil
---@field shieldTextColor table|nil
---@field xpBarEnabled boolean|nil
---@field xpBarTextSize number|nil
---@field xpBarTextColor table|nil
---@field castBarEnabled boolean|nil
---@field castBarAlwaysShow boolean|nil
---@field castBarTextSize number|nil
---@field castBarTextColor table|nil
---@field mountStaminaBarEnabled boolean|nil
---@field mountStaminaBarTextSize number|nil
---@field mountStaminaBarTextColor table|nil
---@field orbAnimFlow boolean|nil
---@field cooldownTextSize number|nil
---@field cooldownTextColor table|nil
---@field quickslotTextSize number|nil
---@field quickslotTextColor table|nil
---@field weaponSwapAnimation boolean|nil
---@field showUltimateNumber boolean|nil
---@field ultimateTextSize number|nil
---@field ultimateTextColor table|nil
---@field showQuickslotCooldown boolean|nil
---@field showQuickslotCount boolean|nil
---@field showCombatGlow boolean|nil
---@field showCombatIcon boolean|nil
---@field playCombatAudio boolean|nil
---@field backBarOpacity number|nil
---@field hideBackBar boolean|nil
---@field hideLeftOrnament boolean|nil
---@field hideRightOrnament boolean|nil
---@field leftOrbSizeScale number|nil
---@field rightOrbSizeScale number|nil
---@field customFrontBar BetterUIResourceOrbFramesFrontBarSettings|nil

---@alias BetterUISharedFontSettingKey
---| "nameFont"
---| "nameFontSize"
---| "nameFontStyle"
---| "columnFont"
---| "columnFontSize"
---| "columnFontStyle"
---| "showIconEnchantment"
---| "showIconSetGear"
---| "showIconUnboundItem"
---| "showIconResearchableTrait"
---| "showIconUnknownRecipe"
---| "showIconUnknownBook"

---@alias BetterUISharedFontSettingValue string|number|boolean|nil

---@alias BetterUIInventorySettingKey
---| BetterUISharedFontSettingKey
---| "quickDestroy"
---| "enableBatchDestroy"
---| "enableCarousel"
---| "useTriggersForSkip"
---| "triggerSpeed"
---| "bindOnEquipProtection"
---| "enableCompanionJunk"
---| "currencyPreset"
---| "currencyOrder"

---@alias BetterUIInventorySettingValue BetterUISharedFontSettingValue

---@alias BetterUIBankingSettingKey
---| BetterUISharedFontSettingKey
---| "enableGuildBank"
---| "enableCarousel"
---| "useTriggersForSkip"
---| "triggerSpeed"

---@alias BetterUIBankingSettingValue BetterUISharedFontSettingValue

---@alias BetterUIVendorSettingKey
---| BetterUISharedFontSettingKey
---| "enableCarousel"
---| "enableBatchJunkSell"
---| "abbreviateVendorCurrency"

---@alias BetterUIVendorSettingValue BetterUISharedFontSettingValue

---@alias BetterUITradingHouseSettingKey
---| BetterUISharedFontSettingKey
---| "enableCarousel"
---| "searchPresets"

---@alias BetterUITradingHouseSettingValue BetterUISharedFontSettingValue|table

---@alias BetterUICompanionsSettingKey
---| BetterUISharedFontSettingKey
---| "enableCompanionEquipment"
---| "quickDestroy"
---| "batchDestroy"
---| "bindOnEquipProtection"
---| "enableCompanionJunk"

---@alias BetterUICompanionsSettingValue BetterUISharedFontSettingValue

---@alias BetterUIGeneralInterfaceSettingKey
---| "showMarketPrice"
---| "marketPricePriority"
---| "showStyleTrait"
---| "showKnowledgeStatus"
---| "chatHistory"
---| "attIntegration"
---| "mmIntegration"
---| "ttcIntegration"
---| "guildStoreErrorSuppress"
---| "removeDeleteDialog"

---@alias BetterUIGeneralInterfaceSettingValue string|number|boolean|nil

---@alias BetterUINameplatesSettingKey
---| "m_enabled"
---| "font"
---| "style"
---| "size"

---@alias BetterUINameplatesSettingValue string|number|boolean|nil

---@alias BetterUIResourceOrbFramesSettingKey
---| "m_enabled"
---| "scale"
---| "offsetX"
---| "offsetY"
---| "centerBarType"
---| "healthTextSize"
---| "healthTextColor"
---| "magickaTextSize"
---| "magickaTextColor"
---| "staminaTextSize"
---| "staminaTextColor"
---| "shieldTextSize"
---| "shieldTextColor"
---| "xpBarEnabled"
---| "xpBarTextSize"
---| "xpBarTextColor"
---| "castBarEnabled"
---| "castBarAlwaysShow"
---| "castBarTextSize"
---| "castBarTextColor"
---| "mountStaminaBarEnabled"
---| "mountStaminaBarTextSize"
---| "mountStaminaBarTextColor"
---| "orbAnimFlow"
---| "cooldownTextSize"
---| "cooldownTextColor"
---| "quickslotTextSize"
---| "quickslotTextColor"
---| "weaponSwapAnimation"
---| "showUltimateNumber"
---| "ultimateTextSize"
---| "ultimateTextColor"
---| "showQuickslotCooldown"
---| "showQuickslotCount"
---| "showCombatGlow"
---| "showCombatIcon"
---| "playCombatAudio"
---| "backBarOpacity"
---| "hideBackBar"
---| "hideLeftOrnament"
---| "hideRightOrnament"
---| "leftOrbSizeScale"
---| "rightOrbSizeScale"
---| "customFrontBar"

---@alias BetterUIResourceOrbFramesSettingValue string|number|boolean|table|nil

---@alias BetterUIModuleSettingKey
---| BetterUIInventorySettingKey
---| BetterUIBankingSettingKey
---| BetterUIVendorSettingKey
---| BetterUITradingHouseSettingKey
---| BetterUICompanionsSettingKey
---| BetterUIGeneralInterfaceSettingKey
---| BetterUINameplatesSettingKey
---| BetterUIResourceOrbFramesSettingKey

---@alias BetterUIModuleSettingValue
---| BetterUIInventorySettingValue
---| BetterUIBankingSettingValue
---| BetterUIVendorSettingValue
---| BetterUITradingHouseSettingValue
---| BetterUICompanionsSettingValue
---| BetterUIGeneralInterfaceSettingValue
---| BetterUINameplatesSettingValue
---| BetterUIResourceOrbFramesSettingValue

---@alias BetterUIListModuleSettings
---| BetterUIInventorySettings
---| BetterUIBankingSettings
---| BetterUIVendorSettings
---| BetterUITradingHouseSettings
---| BetterUICompanionsSettings

---@alias BetterUIModuleSettings
---| BetterUIInventorySettings
---| BetterUIBankingSettings
---| BetterUIVendorSettings
---| BetterUITradingHouseSettings
---| BetterUICompanionsSettings
---| BetterUIGeneralInterfaceSettings
---| BetterUINameplatesSettings
---| BetterUIResourceOrbFramesSettings
---| table<string, BetterUIModuleSettingValue|nil>

---@class ModuleSettings
---@field GetSetting fun(key: BetterUIModuleSettingKey): BetterUIModuleSettingValue|nil Get a module setting value
---@field SetSetting fun(key: BetterUIModuleSettingKey, value: BetterUIModuleSettingValue): boolean Set a module setting value
---@field FONT_CHOICES string[] Available font display names
---@field FONT_VALUES string[] Font internal identifiers
---@field FONTSTYLE_CHOICES string[] Available font style names
---@field FONTSTYLE_VALUES string[] Font style identifiers
---@field DEFAULTS BetterUISharedFontSettings Default shared font settings

---@alias BetterUIControlModifyTextType integer
--- Accepted value passed to ZO_Control:SetModifyTextType / ZO_GamepadEntryData:SetModifyTextType.

---@class BetterUIInventoryRowData: SlotData
---@field listModuleName BetterUIListModuleName|nil
---@field moduleName BetterUIListModuleName|nil
---@field bestGamepadItemCategoryName string|nil
---@field bestItemCategoryName string|nil
---@field itemCategoryName string|nil
---@field bestItemTypeName string|nil
---@field cached_itemLink ItemLink|nil
---@field cached_itemType number|nil
---@field cached_traitName string|nil
---@field cached_setItem boolean|nil
---@field cached_hasEnchantment boolean|nil
---@field cached_isRecipeAndUnknown boolean|nil
---@field cached_isBook boolean|nil
---@field cached_isBookKnown boolean|nil
---@field cached_isBookAndUnknown boolean|nil
---@field cached_isTraitResearchable boolean|nil
---@field cached_isUnbound boolean|nil
---@field stackSellPrice number|nil
---@field text string|nil
---@field label string|nil
---@field stolen boolean|nil
---@field isBoPTradeable boolean|nil
---@field isEquippedInCurrentCategory boolean|nil
---@field isEquippedInAnotherCategory boolean|nil
---@field modifyTextType BetterUIControlModifyTextType|nil
---@field labelColor table|nil

---@class BetterUIInventoryEntryData
---@field dataSource BetterUIInventoryRowData|nil
---@field listModuleName BetterUIListModuleName|nil
---@field moduleName BetterUIListModuleName|nil
---@field text string|nil
---@field label string|nil
---@field name string|nil
---@field iconFile string|nil
---@field stackCount number|nil
---@field stackSellPrice number|nil
---@field labelColor table|nil
---@field cached_itemLink ItemLink|nil
---@field cached_itemType number|nil
---@field cached_traitName string|nil
---@field cached_setItem boolean|nil
---@field cached_hasEnchantment boolean|nil
---@field cached_isRecipeAndUnknown boolean|nil
---@field cached_isBook boolean|nil
---@field cached_isBookKnown boolean|nil
---@field cached_isBookAndUnknown boolean|nil
---@field cached_isTraitResearchable boolean|nil
---@field cached_isUnbound boolean|nil
---@field stolen boolean|nil
---@field isBoPTradeable boolean|nil
---@field isEquippedInCurrentCategory boolean|nil
---@field isEquippedInAnotherCategory boolean|nil
---@field modifyTextType BetterUIControlModifyTextType|nil

---@alias BetterUIInventoryEntryLike BetterUIInventoryEntryData|BetterUIInventoryRowData
