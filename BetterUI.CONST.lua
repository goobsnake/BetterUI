-- BetterUI Constants
-- UI layout values and constants used throughout the addon

local _

-- ============================================================================
-- RESEARCH SYSTEM
-- ============================================================================

-- Crafting skill types for research trait tracking
BETTERUI.CONST.CraftingSkillTypes = { CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER, CRAFTING_TYPE_JEWELRYCRAFTING, CRAFTING_TYPE_WOODWORKING }

-- ============================================================================
-- UI LAYOUT
-- ============================================================================

-- Panel widths
BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH = 1350
BETTERUI_ZO_GAMEPAD_DEFAULT_PANEL_WIDTH = 470

-- Horizontal padding values
BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING = 36
BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING_OTHER = 10
BETTERUI_GAMEPAD_SCREEN_PADDING = 40
BETTERUI_GAMEPAD_LIST_TOTAL_PADDING_HORZ = BETTERUI_GAMEPAD_SCREEN_PADDING + BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING

-- List positioning
BETTERUI_GAMEPAD_LIST_SCREEN_X_OFFSET = 90
BETTERUI_GAMEPAD_DEFAULT_PANEL_CONTAINER_WIDTH = 1325
BETTERUI_TABBAR_ICON_WIDTH = 50

-- ============================================================================
-- CATEGORY CAROUSEL (Tab Bar Icons)
-- Used for the rotating category icon bar in Inventory and Banking headers
-- ============================================================================

-- Default carousel settings (used by Inventory)
BETTERUI_CAROUSEL_START_OFFSET = 710       -- Horizontal position of first category icon (increase to move right)
BETTERUI_CAROUSEL_ITEM_SPACING = 50        -- Space between each category icon
BETTERUI_CAROUSEL_VERTICAL_OFFSET = 12     -- Vertical offset to align icons with LB/RB buttons (increase to move down)

-- Banking-specific carousel overrides (nil means use default)
BETTERUI_BANKING_CAROUSEL_START_OFFSET = 705   -- Horizontal position for banking carousel (increase to move right)
BETTERUI_BANKING_CAROUSEL_VERTICAL_OFFSET = -1  -- Vertical offset for banking (lower value moves icons up)

-- ============================================================================
-- SEARCH BAR POSITIONING
-- Controls the position of the search input field in headers
-- ============================================================================

-- Inventory search bar position
BETTERUI_INV_SEARCH_X_OFFSET = 56          -- Horizontal offset from left edge (increase to move right)
BETTERUI_INV_SEARCH_Y_OFFSET = 1           -- Vertical offset from header bottom (increase to move down)
BETTERUI_INV_SEARCH_RIGHT_INSET = -4       -- Right edge inset (more negative = narrower search bar)

-- Banking search bar position
BETTERUI_BANK_SEARCH_X_OFFSET = 58         -- Horizontal offset from left edge (increase to move right)
BETTERUI_BANK_SEARCH_Y_OFFSET = 15         -- Vertical offset from header bottom (increase to move down)
BETTERUI_BANK_SEARCH_RIGHT_INSET = -8      -- Right edge inset (more negative = narrower search bar)

-- ============================================================================
-- LIST ENTRY DIMENSIONS
-- ============================================================================

-- Entry widths (used in XML templates)
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH = BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH - (2 * BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING)
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_HWIDTH = BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH - BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_ICON_X_OFFSET = -20
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_INDENT = BETTERUI_GAMEPAD_LIST_SCREEN_X_OFFSET - BETTERUI_GAMEPAD_LIST_TOTAL_PADDING_HORZ
BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH_AFTER_INDENT = BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_WIDTH - BETTERUI_GAMEPAD_DEFAULT_LIST_ENTRY_INDENT

-- ============================================================================
-- POSITIONING
-- ============================================================================

-- Quadrant positioning
BETTERUI_GAMEPAD_QUADRANT_1_LEFT = BETTERUI_GAMEPAD_DEFAULT_HORIZ_PADDING

-- ============================================================================
-- XML TEMPLATE VALUES (Column Layout)
-- ============================================================================

-- Sub-menu label positioning
BETTERUI_SUBMENU_LABEL_OFFSET_X = 87
BETTERUI_SUBMENU_LABEL_WIDTH = 540

-- Item type column
BETTERUI_ITEM_TYPE_OFFSET_X = 550
BETTERUI_ITEM_TYPE_WIDTH = 250

-- Trait column
BETTERUI_TRAIT_OFFSET_X = 810
BETTERUI_TRAIT_WIDTH = 180

-- Stat column
BETTERUI_STAT_OFFSET_X = 1000
BETTERUI_STAT_WIDTH = 130

-- Value column
BETTERUI_VALUE_OFFSET_X = 1150
BETTERUI_VALUE_WIDTH = 120

-- Icon offsets
BETTERUI_EQUIPPED_ICON_OFFSET_X = -25
BETTERUI_STATUS_INDICATOR_OFFSET_X = -10

-- ============================================================================
-- RESOURCE ORB FRAMES - STRUCTURED CONFIGURATION
-- All orb-related settings in one organized table
-- 
-- DIRECTION CONVENTION:
--   X: positive = right, negative = left
--   Y: positive = down, negative = up
-- ============================================================================

BETTERUI_ORB_FRAMES = {
    -- Skill button dimensions (pixels)
    slots = {
        gamepad = { 
            width = 64,           -- Button size in pixels
            spacing = 10,         -- Gap between buttons
            dualBarOffset = 44,   -- Dual bar horizontal offset
        },
        keyboard = { 
            width = 50,           -- Button size in pixels
            spacing = 2,          -- Gap between buttons
            dualBarOffset = 12,   -- Dual bar horizontal offset
        },
    },
    
    -- Skill bar positioning (bottom = active bar, top = back bar)
    bars = {
        shiftY = 70,              -- Move BOTH bars down (+) or up (-)
        ultimateGap = 66,         -- Extra gap before ultimate skill (pixels)
        mainBarShiftFactor = 0,   -- Legacy: keep at 0
        indicatorOffsetX = -10,   -- Bar indicator: left (-) or right (+)
        quickslotOffsetX = 0,     -- Quickslot: left (-) or right (+)
        bottom = { 
            x = -40,              -- Main bar: left (-) or right (+)
            gamepadY = -15,       -- Gamepad: up (-) or down (+)
            keyboardY = -15,      -- Keyboard: up (-) or down (+)
        },
        top = { 
            x = 25,               -- Back bar: left (-) or right (+)
            gamepadY = -103,      -- Gamepad: up (-) or down (+)
            keyboardY = -103,     -- Keyboard: up (-) or down (+)
        },
    },
    
    -- Ornament (statue) positioning relative to center of skill bars
    ornaments = {
        left = { 
            x = -450,             -- Left (-) or right (+) from center
            y = -15,              -- Up (-) or down (+)
            size = 375,           -- Size in pixels
            scale = 1.0,          -- Scale multiplier (1.0 = 100%)
        },
        right = { 
            x = 450,              -- Left (-) or right (+) from center
            y = -25,              -- Up (-) or down (+)
            size = 400,           -- Size in pixels
            scale = 1.0,          -- Scale multiplier (1.0 = 100%)
        },
    },
    
    -- Orb border (ring) positioning relative to ornament center
    orbs = {
        left = { 
            x = 50,               -- Left (-) or right (+) nudge
            y = -10,              -- Up (-) or down (+) nudge
            borderSize = 200,     -- Ring size in pixels
        },
        right = { 
            x = -60,              -- Left (-) or right (+) nudge
            y = 5,                -- Up (-) or down (+) nudge
            borderSize = 200,     -- Ring size in pixels
        },
        auraSize = 350,           -- Glow effect size (unused currently)
    },
    
    -- Fill layer (colored resource display inside orb)
    -- scaleW/scaleH: size as fraction of borderSize (0.5 = 50%)
    -- x/y: offset from center, left (-) or right (+), up (-) or down (+)
    fills = {
        health = { scaleW = 0.55, scaleH = 0.55, x = 0, y = 0 },
        magicka = { scaleW = 0.43, scaleH = 0.43, x = 20, y = -5 },
        stamina = { scaleW = 0.5, scaleH = 0.5, x = -20, y = 0 },
        resource = { scaleW = 0.5, scaleH = 0.5, x = 0, y = 0 },  -- Fallback
    },
    
    -- Splitter (magicka/stamina divider line)
    splitter = { 
        width = 200,              -- Line width in pixels
        heightScale = 0.70,       -- Height as fraction of borderSize (0.7 = 70%)
        x = 4,                    -- Left (-) or right (+)
        y = -5,                   -- Up (-) or down (+)
    },
    
    -- Labels (numeric value text positioning)
    -- x/y: offset from default position, left (-) or right (+), up (-) or down (+)
    labels = {
        health = { x = 0, y = 0 },
        magicka = { x = 0, y = 0 },
        stamina = { x = 0, y = 0 },
        shield = { x = 0, y = 0 },
    },
}

-- ============================================================================
-- CUSTOM BARS (Experience/Champion Bar & Cast Bar)
-- These horizontal bars sit above the skill bars using the Bar.dds texture
-- ============================================================================

-- Base bar dimensions (Bar.dds display size)
BETTERUI_BAR_WIDTH = 250                  -- Width of the custom bar in pixels
BETTERUI_BAR_HEIGHT = 150                  -- Height of the custom bar in pixels

-- Experience/Champion Bar positioning (above top skill bar)
BETTERUI_XP_BAR_SCALE = 1.0                -- Scale multiplier for XP bar
BETTERUI_XP_BAR_OFFSET_X = 0               -- X offset from center (positive = right)
BETTERUI_XP_BAR_OFFSET_Y = -25             -- Y offset from BgMiddle bottom (negative = up)
BETTERUI_XP_BAR_FILL_INSET_X = 40          -- Horizontal inset for fill bar within frame
BETTERUI_XP_BAR_FILL_INSET_Y = 55          -- Vertical inset for fill bar within frame

-- Cast Bar positioning (above XP bar)
BETTERUI_CAST_BAR_SCALE = 1.0              -- Scale multiplier for Cast bar
BETTERUI_CAST_BAR_OFFSET_X = 0             -- X offset from center (positive = right)
BETTERUI_CAST_BAR_OFFSET_Y = -160          -- Y offset from BgMiddle bottom (negative = up)
BETTERUI_CAST_BAR_FILL_INSET_X = 40        -- Horizontal inset for fill bar within frame
BETTERUI_CAST_BAR_FILL_INSET_Y = 55        -- Vertical inset for fill bar within frame
