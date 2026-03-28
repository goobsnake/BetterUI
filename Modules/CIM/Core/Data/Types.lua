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
---| "WritUnit"
---| "CIM"
---| "Vendor"
---| "GeneralInterface"

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

---@class ModuleSettings
---@field GetSetting fun(key: string): any Get a module setting value
---@field SetSetting fun(key: string, value: any) Set a module setting value
---@field FONT_CHOICES string[] Available font display names
---@field FONT_VALUES string[] Font internal identifiers
---@field FONTSTYLE_CHOICES string[] Available font style names
---@field FONTSTYLE_VALUES string[] Font style identifiers
---@field DEFAULTS table Default font settings


