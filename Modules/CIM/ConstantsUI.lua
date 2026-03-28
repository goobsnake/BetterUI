--[[
File: Modules/CIM/ConstantsUI.lua
Purpose: UI layout constants, backward-compatibility aliases, color definitions,
         icon paths, sort schema, and header layout geometry.
         Split from Constants.lua for maintainability.
]]

---@diagnostic disable: lowercase-global, undefined-global

if not BETTERUI then BETTERUI = {} end
if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.CONST then BETTERUI.CIM.CONST = {} end

-- ============================================================================
-- TOOLTIP LAYOUT CONSTANTS
-- Migrated from GeneralInterface/Constants.lua
-- ============================================================================

--[[
Constant: BETTERUI.CIM.CONST.TOOLTIP_MAX_FADE_GRADIENT_SIZE
Description: Maximum size for tooltip fade gradient effect.
Used By: Inventory/Module.lua
]]
BETTERUI.CIM.CONST.TOOLTIP_MAX_FADE_GRADIENT_SIZE = 10

--[[
Constant: BETTERUI.CIM.CONST.TOOLTIP_X_OFFSET
Description: Horizontal offset for tooltip positioning.
Direction: Positive (+) moves RIGHT.
Used By: Inventory/Module.lua
]]
BETTERUI.CIM.CONST.TOOLTIP_X_OFFSET = 40

--[[
Constant: BETTERUI.CIM.CONST.TOOLTIP_Y_OFFSET
Description: Vertical offset for tooltip positioning.
Direction: Positive (+) moves DOWN, Negative (-) moves UP.
Used By: Inventory/Module.lua
]]
BETTERUI.CIM.CONST.TOOLTIP_Y_OFFSET = -100

--[[
Constant: BETTERUI.CIM.CONST.TOOLTIP_SCROLL_OFFSET_Y
Description: Vertical offset for tooltip scroll container.
Direction: Positive (+) moves DOWN.
Used By: Inventory/UI/TooltipUtils.lua
]]
BETTERUI.CIM.CONST.TOOLTIP_SCROLL_OFFSET_Y = 40

-- ============================================================================
-- RESEARCH SYSTEM (Migrated from BetterUI.CONST.lua)
-- ============================================================================

--[[
Table: BETTERUI.CIM.CONST.CraftingSkillTypes
Description: Crafting skill types for research trait tracking.
Used By: Tooltips and Inventory modules to check research status.
]]
BETTERUI.CIM.CONST.CraftingSkillTypes = { CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER,
    CRAFTING_TYPE_JEWELRYCRAFTING, CRAFTING_TYPE_WOODWORKING }

-- ============================================================================
-- UI LAYOUT (Migrated from BetterUI.CONST.lua)
-- ============================================================================

BETTERUI.CIM.CONST.LAYOUT = {}

--[[
Table: BETTERUI.CIM.CONST.LAYOUT.PANEL
Description: Panel width configurations for inventory/banking screens.
Used By: XML templates and list managers.
]]
BETTERUI.CIM.CONST.LAYOUT.PANEL = {
    WIDTH = 1350,           -- Full custom panel width; larger values widen list/currency real estate.
    ZO_WIDTH = 470,         -- Native ZO panel width used when a vanilla-width container is required.
    CONTAINER_WIDTH = 1325, -- Inner content frame width; lower values add side gutters.
}

--[[
Table: BETTERUI.CIM.CONST.LAYOUT.PADDING
Description: Horizontal padding values for UI elements.
Used By: XML templates and list entry calculations.
]]
BETTERUI.CIM.CONST.LAYOUT.PADDING = {
    DEFAULT = 47,   -- Panel offset from GuiRoot (fixes scrollbar clipping)
    CONTAINER = 24, -- Container offset from panel (shifts content left)
    OTHER = 10,
    SCREEN = 40,
}

--[[
Table: BETTERUI.CIM.CONST.LAYOUT.LIST
Description: List positioning and icon sizing.
Used By: Inventory and Banking list templates.
]]
BETTERUI.CIM.CONST.LAYOUT.LIST = {
    SCREEN_X_OFFSET = 90, -- List container X offset from panel left (+ right, - left).
    ICON_WIDTH = 50,      -- Base list-entry icon size (icon height follows this width in templates).
    --[[
    Constant: CONTAINER
    Description: Offsets for list container anchoring relative to header/footer.
    Direction: Negative (-) X moves LEFT from anchor, Positive (+) Y moves DOWN.
    Used By: Banking.lua, WindowClass.lua
    ]]
    CONTAINER = {
        HEADER_X_OFFSET = 0,  -- Horizontal list nudge from header anchor (+ right, - left).
        HEADER_Y_OFFSET = 17, -- Vertical distance below header dividers (+ down, - up).
        FOOTER_Y_OFFSET = 10, -- Bottom padding above footer (+ down = less visible list space).
        -- Fixed offset for column headers (decoupled from list position)
        -- Calculation: entry_padding(36) + fine_tune(-35) = +1
        COLUMN_HEADER_X_ADJUST = 1, -- Fine horizontal alignment for header labels vs row columns.
    },
}

--[[
Constant: BETTERUI.CIM.CONST.LAYOUT.COLUMN_HEADER_Y_OFFSET
Description: Y offset for column header labels relative to header bar.
Direction: Positive (+) moves DOWN.
Used By: WindowClass.lua AddColumn method
]]
BETTERUI.CIM.CONST.LAYOUT.COLUMN_HEADER_Y_OFFSET = 109

--[[
Constant: BETTERUI.CIM.CONST.LAYOUT.COLUMN_WIDTHS
Description: Column widths for header hit regions used in sorting.
Used By: WindowClass.lua AddColumn method
Layout: { NAME, TYPE, TRAIT, STAT, VALUE }
]]
BETTERUI.CIM.CONST.LAYOUT.COLUMN_WIDTHS = {
    540, -- NAME header hit width (longest text + icons).
    250, -- TYPE header hit width.
    180, -- TRAIT header hit width.
    130, -- STAT header hit width.
    100, -- VALUE header hit width.
}

--[[
Table: BETTERUI.CIM.CONST.LAYOUT.COLUMNS
Description: X Offsets and Widths for the inventory grid columns.
Direction: OFFSET_X is Positive (+) moving RIGHT from the left edge of the list entry.
Used By: Inventory list templates.
]]
BETTERUI.CIM.CONST.LAYOUT.COLUMNS = {
    SUBMENU = { OFFSET_X = 70, WIDTH = 500 },   -- Name/submenu column start (+ right) and width budget.
    TYPE    = { OFFSET_X = 513, WIDTH = 250 },  -- Item type column start (+ right) and width budget.
    TRAIT   = { OFFSET_X = 773, WIDTH = 180 },  -- Trait column start (+ right) and width budget.
    STAT    = { OFFSET_X = 963, WIDTH = 130 },  -- Stat column start (+ right) and width budget.
    VALUE   = { OFFSET_X = 1113, WIDTH = 100 }, -- Value column start (+ right) and width budget.
}

--[[
Table: BETTERUI.CIM.CONST.LAYOUT.TOOLTIP
Description: Tooltip positioning offsets for enhanced tooltips.
Used By: CIM tooltip layout.
]]
BETTERUI.CIM.CONST.LAYOUT.TOOLTIP = {
    STATUS_LABEL_OFFSET_Y = 60,  -- Status text vertical offset in enhanced tooltip (+ down, - up).
    BODY_OFFSET_Y_ENHANCED = 50, -- Body block offset when enhanced sections are visible (+ down, - up).
    PRICE_LABEL_HEIGHT = 32,     -- Price label row height; increase creates taller price lane.
    PRICE_LABEL_OFFSET_Y = 5,    -- Price label vertical nudge inside tooltip footer (+ down, - up).
}

-- Backward Compatibility Aliases (XML Support)
-- AUDIT (2026-03-14): All aliases below are actively consumed by XML templates.
-- XML cannot reference Lua namespace paths (BETTERUI.CIM.CONST.*), so these globals
-- MUST remain. Lua code should use canonical BETTERUI.CIM.CONST.LAYOUT.* paths.
-- Removed aliases (zero XML/Lua consumers): BETTERUI_SEARCH_BAR_SPACING_Y,
-- BETTERUI_GAMEPAD_SCREEN_PADDING, BETTERUI_GAMEPAD_LIST_SCREEN_X_OFFSET,
-- BETTERUI_GAMEPAD_LIST_TOTAL_PADDING_HORZ, BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_HWIDTH.

-- PANEL
BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH = BETTERUI.CIM.CONST.LAYOUT.PANEL.WIDTH
BETTERUI_ZO_GAMEPAD_DEFAULT_PANEL_WIDTH = BETTERUI.CIM.CONST.LAYOUT.PANEL.ZO_WIDTH
BETTERUI_GAMEPAD_DEFAULT_PANEL_CONTAINER_WIDTH = BETTERUI.CIM.CONST.LAYOUT.PANEL.CONTAINER_WIDTH

-- PADDING
BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING = BETTERUI.CIM.CONST.LAYOUT.PADDING.DEFAULT
BETTERUI_GAMEPAD_CONTAINER_HORIZ_PADDING = BETTERUI.CIM.CONST.LAYOUT.PADDING.CONTAINER
BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING_OTHER = BETTERUI.CIM.CONST.LAYOUT.PADDING.OTHER

-- LIST
BETTERUI_TABBAR_ICON_WIDTH = BETTERUI.CIM.CONST.LAYOUT.LIST.ICON_WIDTH

-- LIST ENTRY DIMENSIONS (derived; inlined to canonical paths)
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH = BETTERUI.CIM.CONST.LAYOUT.PANEL.WIDTH -
    (2 * BETTERUI.CIM.CONST.LAYOUT.PADDING.DEFAULT)
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_ICON_X_OFFSET = -20
BETTERUI_GAMEPAD_LIST_ENTRY_INDENT = BETTERUI.CIM.CONST.LAYOUT.LIST.SCREEN_X_OFFSET -
    (BETTERUI.CIM.CONST.LAYOUT.PADDING.SCREEN + BETTERUI.CIM.CONST.LAYOUT.PADDING.DEFAULT)
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_INDENT = BETTERUI_GAMEPAD_LIST_ENTRY_INDENT
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH_AFTER_INDENT = BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH -
    BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_INDENT

-- POSITIONING
BETTERUI_GAMEPAD_QUADRANT_1_LEFT = BETTERUI.CIM.CONST.LAYOUT.PADDING.DEFAULT

-- Backward Compatibility Aliases (XML Support) - COLUMNS
-- These aliases mirror canonical values in BETTERUI.CIM.CONST.LAYOUT.COLUMNS.
-- Tune the canonical table above; aliases are kept for XML/backward compatibility only.
BETTERUI_SUBMENU_LABEL_OFFSET_X = BETTERUI.CIM.CONST.LAYOUT.COLUMNS.SUBMENU.OFFSET_X -- + right, - left.
BETTERUI_SUBMENU_LABEL_WIDTH = BETTERUI.CIM.CONST.LAYOUT.COLUMNS.SUBMENU.WIDTH       -- Column width budget.
BETTERUI_ITEM_TYPE_OFFSET_X = BETTERUI.CIM.CONST.LAYOUT.COLUMNS.TYPE.OFFSET_X        -- + right, - left.
BETTERUI_ITEM_TYPE_WIDTH = BETTERUI.CIM.CONST.LAYOUT.COLUMNS.TYPE.WIDTH              -- Column width budget.
BETTERUI_TRAIT_OFFSET_X = BETTERUI.CIM.CONST.LAYOUT.COLUMNS.TRAIT.OFFSET_X           -- + right, - left.
BETTERUI_TRAIT_WIDTH = BETTERUI.CIM.CONST.LAYOUT.COLUMNS.TRAIT.WIDTH                 -- Column width budget.
BETTERUI_STAT_OFFSET_X = BETTERUI.CIM.CONST.LAYOUT.COLUMNS.STAT.OFFSET_X             -- + right, - left.
BETTERUI_STAT_WIDTH = BETTERUI.CIM.CONST.LAYOUT.COLUMNS.STAT.WIDTH                   -- Column width budget.
BETTERUI_VALUE_OFFSET_X = BETTERUI.CIM.CONST.LAYOUT.COLUMNS.VALUE.OFFSET_X           -- + right, - left.
BETTERUI_VALUE_WIDTH = BETTERUI.CIM.CONST.LAYOUT.COLUMNS.VALUE.WIDTH                 -- Column width budget.

-- ============================================================================
-- COLORS (Migrated from BetterUI.CONST.lua)
-- ============================================================================

--[[
Table: BETTERUI.CIM.CONST.COLORS
Description: Color definitions for UI elements.
Used By: Tab bar icons and category navigation.
]]
BETTERUI.CIM.CONST.COLORS = {
    -- Tab bar icon colors for category navigation
    TAB_ICON_GOLD = { 1, 0.95, 0.5, 1 }, -- Gold tint for category icons
    TAB_ICON_FILTER = { 1, 1, 1, 1 },    -- White for filter type icons

    -- Tooltip research status colors (hex strings for inline coloring)
    RESEARCHABLE = "00FF00",   -- Green for "Researchable" text
    FOUND_LOCATION = "FF9900", -- Orange for "Found in X" location text
}

--[[
Table: BETTERUI.CIM.CONST.SEARCH_CHILD_NAMES
Description: Child control names to check for mouse interactivity in search controls.
Rationale: Centralizes fragile hardcoded array for easier maintenance.
Used By: CIM/Core/SearchManager.lua PatchMouseInteractivity function.
]]
BETTERUI.CIM.CONST.SEARCH_CHILD_NAMES = {
    "Edit", "TextField", "SearchEdit", "Input", "Entry",
    "EditBox", "SearchIcon", "Icon", "Texture", "InputContainer"
}

-- ============================================================================
-- TOOLTIP DEFAULTS (Migrated from BetterUI.CONST.lua)
-- ============================================================================

--[[
Table: BETTERUI.CIM.CONST.TOOLTIP_DEFAULTS
Description: Default font sizing for tooltips.
Used By: Tooltip rendering.
]]
BETTERUI.CIM.CONST.TOOLTIP_DEFAULTS = {
    DEFAULT_FONT_SIZE = 24
}

-- ============================================================================
-- ICONS (Migrated from BetterUI.CONST.lua)
-- ============================================================================

--[[
Table: BETTERUI.CIM.CONST.ICONS
Description: Icon paths for equipment and item status indicators.
Used By: Inventory and Banking list rendering.
]]
BETTERUI.CIM.CONST.ICONS = {
    -- Equipment Status
    EQUIP_MAIN = "BetterUI/Modules/CIM/Images/inv_equip.dds",
    EQUIP_BACKUP = "BetterUI/Modules/CIM/Images/inv_equip_backup.dds",
    EQUIP_SLOT = "BetterUI/Modules/CIM/Images/inv_equip_quickslot.dds",
    NEW_ITEM = "EsoUI/Art/Miscellaneous/Gamepad/gp_icon_new.dds",
    DEFAULT_SLOT = "/esoui/art/inventory/inventory_slot.dds",
    -- Item Status Indicators (used in InventoryList label setup)
    STOLEN = "BetterUI/Modules/CIM/Images/inv_stolen.dds",
    ENCHANTED = "BetterUI/Modules/CIM/Images/inv_enchanted.dds",
    SET_ITEM = "BetterUI/Modules/CIM/Images/inv_setitem.dds",
    UNBOUND = "/esoui/art/guild/gamepad/gp_ownership_icon_guildtrader.dds",
    RESEARCHABLE_TRAIT = "esoui/art/inventory/inventory_trait_intricate_icon.dds",
    RECIPE_UNKNOWN = "/esoui/art/inventory/gamepad/gp_inventory_icon_craftbag_provisioning.dds",
    BOOK_UNKNOWN = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_loreLibrary.dds",
}

-- ============================================================================
-- CIM DEFAULTS (Migrated from BetterUI.CONST.lua)
-- ============================================================================

--[[
Table: BETTERUI.CIM.CONST.DEFAULTS
Description: Default settings for Common Interface Module components.
Used By: CIM initialization and settings panels.
]]
BETTERUI.CIM.CONST.DEFAULTS = {
    DEFAULT_TRIGGER_SPEED = 10,
    DEFAULT_RH_SCROLL_SPEED = 50,
    DEFAULT_TOOLTIP_SIZE = 24,
}

-- ============================================================================
-- SORT SCHEMA
-- Shared sort schema for gamepad inventory-style lists
-- ============================================================================

--[[
Table: BETTERUI.CIM.CONST.SORT_SCHEMA
Description: Sort schema for gamepad inventory item ordering.
             Defines the sort priority chain: Type -> Name -> Level -> CP -> Icon -> ID.
Used By: DefaultSortComparator for Inventory and Banking list sorting.
]]
BETTERUI.CIM.CONST.SORT_SCHEMA = {
    sortPriorityName       = { tiebreaker = "bestItemTypeName" },
    bestItemTypeName       = { tiebreaker = "name" },
    name                   = { tiebreaker = "requiredLevel" },
    requiredLevel          = { tiebreaker = "requiredChampionPoints", isNumeric = true },
    requiredChampionPoints = { tiebreaker = "iconFile", isNumeric = true },
    iconFile               = { tiebreaker = "uniqueId" },
    uniqueId               = { isId64 = true },
}

-- ============================================================================
-- HEADER LAYOUT (Migrated from BetterUI.CONST.lua)
-- ============================================================================

--[[
Table: BETTERUI.CIM.CONST.HEADER_LAYOUT
Description: Layout constants for GenericHeader positioning.
Used By: GenericHeader.xml and GenericHeader.lua.
]]
BETTERUI.CIM.CONST.HEADER_LAYOUT = {
    DIVIDER = {
        --[[
        Constant: DIVIDER.OFFSET_Y
        Description: Vertical offset for the bottom divider.
        Direction: Positive (+) moves DOWN.
        Used By: GenericHeader.xml
        ]]
        OFFSET_Y = 77,
        SPACING = 4, -- Gap between the first and second divider lines; larger value increases separation.
    },
    --[[
    Constant: COLUMNS
    Description: Horizontal X offsets for grid column headers from TabBar BOTTOMLEFT.
    Direction: Positive (+) moves RIGHT from TabBar left anchor.
    NOTE: These values match Inventory columns in GenericHeader.xml (lines 268-315).
          Row data anchors: Label(70) + TYPE(513) = 583 from row entry.
          TabBar position aligns with row entries so header X = row absolute X + adjustment.
    Used By: WindowClass.AddColumn (Banking only - Inventory uses XML-defined columns)
    ]]
    COLUMNS = {
        NAME = 80,    -- Matches GenericHeader.xml Column1Label (line 274)
        TYPE = 592,   -- Matches GenericHeader.xml Column2Label (line 283)
        TRAIT = 852,  -- Matches GenericHeader.xml Column4Label (line 293)
        STAT = 1042,  -- Matches GenericHeader.xml Column6Label (line 302)
        VALUE = 1192, -- Matches GenericHeader.xml Column5Label (line 311)
    },
    EQUIP_SLOT = {
        --[[
        Constant: EQUIP_SLOT.BACKUP_X
        Description: Horizontal offset for the 'Equip' text label for backup slots.
        Direction: Negative (-) moves LEFT from the right anchor.
        Used By: GenericHeader.xml
        ]]
        BACKUP_X = -210,
        ICON_GAP_X = 45, -- Horizontal gap from Equip text to icon anchor (+ right, - left).
    },
    OFFSETS = {
        --[[
        Constant: OFFSETS.MAIN_HAND_X / BACKUP_HAND_X
        Description: Horizontal anchor offsets for equipment icons.
        Direction: Negative (-) moves LEFT from the anchor point.
        Used By: GenericHeader.xml
        ]]
        MAIN_HAND_X = -155,
        BACKUP_HAND_X = -155
    }
}

-- ============================================================================
-- BACKWARDS COMPATIBILITY ALIASES
-- ============================================================================

-- Tooltip legacy aliases REMOVED (2026-02-02)
-- Consumers migrated to use BETTERUI.CIM.CONST.* paths:
--   - CIM/Core/TooltipLayout.lua
--   - Inventory/Module.lua
--   - Inventory/UI/TooltipUtils.lua

-- BETTERUI.CONST.* namespace aliases REMOVED (2026-03-14)
-- All Lua consumers migrated to canonical BETTERUI.CIM.CONST.* paths:
--   - CIM/Module.lua → BETTERUI.CIM.CONST.DEFAULTS
--   - CIM/Tooltips/Tooltips.lua → BETTERUI.CIM.CONST.TOOLTIP_DEFAULTS
--   - CIM/UI/GenericHeader.lua → BETTERUI.CIM.CONST.COLORS, BETTERUI.CIM.CONST.ICONS
--   - Inventory/Lists/InventoryList.lua → BETTERUI.CIM.CONST.ICONS
--   - Inventory/UI/TooltipUtils.lua → BETTERUI.CIM.CONST.LAYOUT.TOOLTIP
