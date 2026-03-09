--[[
File: Modules/CIM/Core/Types.lua
Purpose: Shared EmmyLua type definitions for BetterUI.
         Provides centralized type annotations used across all modules.
Author: BetterUI Team
Last Modified: 2026-01-29

This file should be loaded early in the CIM module load order.
It defines types that are referenced by annotations throughout the codebase.
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Types = {}

-- ============================================================================
-- ESO API TYPE STUBS
-- These definitions help the IDE understand ESO's global types
-- ============================================================================

---@class ZO_Object
---@field New fun(self): table
---@field Subclass fun(self): table

---@class Control
---@field SetHidden fun(self, hidden: boolean)
---@field IsHidden fun(self): boolean
---@field GetName fun(self): string
---@field GetNamedChild fun(self, name: string): Control|nil
---@field SetParent fun(self, parent: Control|nil)
---@field GetParent fun(self): Control|nil
---@field ClearAnchors fun(self)
---@field SetAnchor fun(self, point: number, relativeTo: Control|nil, relativePoint: number, offsetX: number, offsetY: number)
---@field SetDimensions fun(self, width: number, height: number)
---@field GetWidth fun(self): number
---@field GetHeight fun(self): number
---@field SetAlpha fun(self, alpha: number)
---@field GetAlpha fun(self): number

---@class LabelControl : Control
---@field SetText fun(self, text: string)
---@field GetText fun(self): string
---@field SetColor fun(self, r: number, g: number, b: number, a: number)
---@field SetFont fun(self, font: string)

---@class TextureControl : Control
---@field SetTexture fun(self, texture: string)
---@field SetTextureCoords fun(self, left: number, right: number, top: number, bottom: number)
---@field SetColor fun(self, r: number, g: number, b: number, a: number)

---@class EditControl : Control
---@field SetText fun(self, text: string)
---@field GetText fun(self): string
---@field TakeFocus fun(self)
---@field LoseFocus fun(self)

---@class ZO_Scene
---@field GetName fun(self): string
---@field IsShowing fun(self): boolean
---@field RegisterCallback fun(self, callbackType: string, callback: function)

---@class ZO_Fragment
---@field SetHiddenForReason fun(self, reason: string, hidden: boolean)

---@class ZO_InteractScene : ZO_Scene
---@field New fun(sceneName: string, sceneManager: table, interaction: table): ZO_InteractScene

-- ============================================================================
-- CORE ITEM DATA TYPES
-- ============================================================================

---@class ItemData
---@field bagId number The bag containing this item (BAG_BACKPACK, BAG_BANK, etc.)
---@field slotIndex number The slot index within the bag
---@field quality number Item quality (ITEM_QUALITY_TRASH to ITEM_QUALITY_LEGENDARY)
---@field name string Localized item name
---@field stackCount number Current stack size
---@field stackCountBackpack number|nil Stack count in backpack (for comparison views)
---@field stackCountBank number|nil Stack count in bank (for comparison views)
---@field uniqueId integer Unique item identifier (GetItemUniqueId)
---@field filterData number[] Filter category IDs for this item
---@field itemType number ESO item type constant (ITEMTYPE_*)
---@field equipType number Equipment slot type (EQUIP_TYPE_*)
---@field isEquipped boolean Whether item is currently equipped
---@field isLocked boolean Whether item is locked
---@field isBound boolean Whether item is bound
---@field canBeStored boolean Whether item can be stored in bank
---@field sellPrice number Vendor sell price
---@field icon string Texture path for item icon
---@field meetsUsageRequirement boolean Whether player meets requirements to use
---@field requiredLevel number Required level to use item
---@field requiredChampionPoints number Required champion points
---@field traitType number Item trait type (ITEM_TRAIT_TYPE_*)
---@field isResearchable boolean|nil Whether trait research is available
---@field traitKnown boolean|nil Whether trait is already researched
---@field enchantment string|nil Enchantment name if any
---@field stolen boolean Whether item is stolen
---@field equipSlot number|nil Specific equipment slot if equipped

---@class InventorySlot
---@field bag number Bag ID (BAG_BACKPACK, BAG_BANK, etc.)
---@field index number Slot index within the bag
---@field data ItemData|nil Item data if slot is occupied
---@field control Control|nil The UI control for this slot

---@class SlotData : ItemData
---@field rawName string Non-localized item name for sorting
---@field bestItemCategoryName string|nil Category name from AutoCategory integration
---@field actorCategory number|nil Actor category (player vs companion)
---@field isPlayerLocked boolean|nil Whether locked by player
---@field statusSortOrder number|nil Status-based sort priority

-- ============================================================================
-- CATEGORY TYPES
-- ============================================================================

---@class CategoryData
---@field id number Category identifier
---@field name string Localized category name
---@field icon string Texture path for category icon
---@field filters number[] Filter type IDs included in this category
---@field hidden boolean|nil Whether category should be hidden
---@field sortOrder number|nil Custom sort order

---@class CategoryEntry
---@field categoryId number Category ID
---@field categoryType number Category type constant
---@field name string Display name
---@field icon string Icon texture path
---@field itemCount number Number of items in this category

-- ============================================================================
-- SORTING TYPES
-- ============================================================================

---@alias SortDirection "ascending" | "descending"

---@alias SortTypeKey
---| "name"
---| "quality"
---| "stackCount"
---| "level"
---| "value"
---| "type"
---| "trait"
---| "status"

---@class SortConfig
---@field type SortType Primary sort key
---@field direction SortDirection Sort order
---@field secondary SortType|nil Secondary sort key
---@field secondaryDirection SortDirection|nil Secondary sort direction

---@class SortEntry
---@field name string Display name for sort option
---@field key SortType Sort key
---@field direction SortDirection Default direction
---@field compareFunc fun(a: ItemData, b: ItemData): boolean Custom comparator

-- ============================================================================
-- MODULE TYPES
-- ============================================================================

---@alias ModuleName
---| "Inventory"
---| "Banking"
---| "ResourceOrbFrames"
---| "WritUnit"
---| "CIM"

---@class ModuleSettings
---@field m_enabled boolean Whether module is enabled
---@field [string] any Module-specific settings (varies by module)

---@class ModuleDefaults
---@field m_enabled boolean Default enabled state
---@field [string] any Default values for module settings

-- ============================================================================
-- SCENE & LIFECYCLE TYPES
-- ============================================================================

---@class SceneLifecycleConfig
---@field onShowing fun(self: table, wasPushed: boolean)|nil Called when scene starts showing
---@field onShown fun(self: table)|nil Called when scene finishes showing
---@field onHiding fun(self: table)|nil Called when scene starts hiding
---@field onHidden fun(self: table)|nil Called when scene is fully hidden
---@field keybinds table[]|nil Keybind groups to add/remove with scene
---@field taskManager DeferredTaskManager|nil For automatic task cleanup
---@field eventRegistryModule string|nil Module name for event cleanup

---@class DeferredTaskManager
---@field Schedule fun(self, taskId: string, delayMs: number, callback: function)
---@field Cancel fun(self, taskId: string)
---@field CancelAll fun(self)
---@field IsPending fun(self, taskId: string): boolean

-- ============================================================================
-- KEYBIND TYPES
-- ============================================================================

---@class KeybindDescriptor
---@field name string|fun(): string Keybind label (can be function for dynamic text)
---@field keybind string Keybind action name (e.g., "UI_SHORTCUT_PRIMARY")
---@field callback fun() Action handler called when keybind is pressed
---@field visible fun(): boolean|nil Visibility function (optional)
---@field enabled fun(): boolean|nil Enabled function (optional)
---@field alignment number|nil Strip alignment (KEYBIND_STRIP_ALIGN_*)
---@field order number|nil Sort order within alignment group
---@field sound string|nil Sound to play on activation
---@field ethereal boolean|nil Whether keybind is hidden but active
---@field narrateHandler fun(): string|nil Handler for screen reader narration
---@field narrateHandlerArgs table|nil Arguments for narration handler

---@class KeybindButtonGroup : table
---@field [number] KeybindDescriptor Array of keybind descriptors

-- ============================================================================
-- UI TYPES
-- ============================================================================

---@class HeaderConfig
---@field title string|nil Header title text
---@field titleObject table|nil Title control object
---@field leftIcon string|nil Left icon texture
---@field rightIcon string|nil Right icon texture
---@field data table|nil Additional header data

---@class FooterConfig
---@field showCurrency boolean|nil Whether to show currency display
---@field mode string|nil Footer mode ("INVENTORY", "BANKING", etc.)
---@field showCapacity boolean|nil Whether to show bag capacity
---@field customText string|nil Custom footer text

---@class TooltipConfig
---@field showResearchStatus boolean|nil Show research status
---@field showTraitMatch boolean|nil Show trait match indicator
---@field showComparison boolean|nil Show equipped item comparison
---@field width number|nil Tooltip width override

-- ============================================================================
-- CALLBACK EVENT NAMES
-- ============================================================================

---@alias BetterUIEvent
---| "BETTERUI_EVENT_ACTION_DIALOG_SETUP"
---| "BETTERUI_EVENT_ACTION_DIALOG_FINISH"
---| "BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM"
---| "BetterUI_ForceLayoutUpdate"
---| "BETTERUI_EVENT_INVENTORY_REFRESH"
---| "BETTERUI_EVENT_BANK_REFRESH"

-- ============================================================================
-- TIMING CONSTANTS TYPE
-- ============================================================================

---@class TimingConstants
---@field DEBOUNCE_MS number
---@field CATEGORY_CHANGE_DELAY_MS number
---@field MOVE_COALESCE_DELAY_MS number
---@field TOOLTIP_REFRESH_DELAY_MS number
---@field KEYBIND_REFRESH_DELAY_MS number
---@field KEYBIND_ACTIVATION_DELAY_MS number
---@field CATEGORY_REFRESH_COALESCE_MS number
---@field BATCH_PROCESS_INTERVAL_MS number
---@field BATCH_SIZE_INITIAL number
---@field BATCH_SIZE_REMAINING number
---@field DIALOG_QUEUE_TIMEOUT_MS number
---@field LIST_DESTRUCTION_DELAY_MS number
---@field WEAPON_SWAP_LAYOUT_DELAY_MS number
---@field SCENE_HANDLER_DELAY_MS number
---@field PLAYER_ACTIVATED_INIT_MS number
---@field DIRECTIONAL_FIX_DELAY_MS number

-- ============================================================================
-- FEATURE FLAGS TYPE
-- ============================================================================

---@class FeatureFlagDefinition
---@field name string Feature identifier
---@field description string Human-readable description
---@field defaultEnabled boolean Default state if not overridden
---@field version string Version when feature was introduced

---@class FeatureFlagsAPI
---@field IsEnabled fun(flagName: string): boolean Check if feature is enabled
---@field SetEnabled fun(flagName: string, enabled: boolean) Set feature state
---@field SetOverride fun(flagName: string, enabled: boolean|nil) Set temporary override
---@field ClearOverrides fun() Clear all overrides
---@field GetAllFlags fun(): table<string, {definition: FeatureFlagDefinition, enabled: boolean}>
---@field ResetToDefaults fun() Reset all flags to defaults
---@field FLAGS table<string, string> Flag name constants
