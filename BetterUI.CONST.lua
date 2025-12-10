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

-- Icon offsets (negative = left of item icon)
BETTERUI_EQUIPPED_ICON_OFFSET_X = -5    -- Equipped indicator (lock icon, etc.)
BETTERUI_STATUS_INDICATOR_OFFSET_X = -2 -- Status indicator (new item, stolen, etc.)

-- ============================================================================
-- RESOURCE ORB FRAMES - STRUCTURED CONFIGURATION
-- 
-- OFFSET DIRECTIONS:
--   X: + moves right, - moves left
--   Y: + moves down, - moves up
-- 
-- nil values inherit from parent config (e.g., slots or front bar)
-- ============================================================================

BETTERUI_ORB_FRAMES = {
    -- =======================================================================
    -- SKILL BUTTON DIMENSIONS
    -- Controls the size and spacing of skill bar buttons
    -- =======================================================================
    slots = {
        gamepad = { 
            width = 64,           -- Button size in pixels
            spacing = 10,         -- Gap between buttons (increase to spread apart)
            dualBarOffset = 44,   -- Horizontal offset when dual bar is visible
        },
        keyboard = { 
            width = 50,           -- Button size in pixels
            spacing = 2,          -- Gap between buttons (increase to spread apart)
            dualBarOffset = 12,   -- Horizontal offset when dual bar is visible
        },
    },
    
    -- =======================================================================
    -- SKILL BAR POSITIONING
    -- Controls the position of front and back skill bars
    -- =======================================================================
    bars = {
        shiftY = 70,              -- Vertical shift for BOTH bars (+ down, - up)
        ultimateGap = 66,         -- Gap before ultimate button in pixels
        
        -- Ultimate button offsets (shift left to make room for quickslot on right)
        frontUltimateOffsetX = -22, -- Front bar ultimate (+ right, - left)
        backUltimateOffsetX = -40,  -- Back bar ultimate (+ right, - left)
        
        -- Quickslot icon position (relative to BgMiddle center)
        quickslot = {
            x = 308,              -- Horizontal offset (+ right, - left)
            y = -27,              -- Vertical offset (+ down, - up)
        },
        
        -- Companion Ultimate icon position (relative to BgMiddle center)
        companionUltimate = {
            x = -297,             -- Horizontal offset (+ right, - left)
            y = -20,              -- Vertical offset (+ down, - up)
        },
        
        -- ===================================================================
        -- CUSTOM FRONT BAR
        -- Replaces native ZO_ActionBar1 with custom-built bar
        -- ===================================================================
        customFrontBar = {
            enabled = true,        -- Set false to use native front bar
            offsetX = 17,          -- Whole bar horizontal offset (+ right, - left)
            offsetY = 72,          -- Whole bar vertical offset (+ down, - up)
            
            -- Fine-tune individual button positions
            ultimate = {
                offsetX = -40,     -- Ultimate horizontal (+ right, - left)
                offsetY = 0,       -- Ultimate vertical (+ down, - up)
            },
            quickslotButton = {
                offsetX = 0,       -- Quickslot horizontal (+ right, - left)
                offsetY = 0,       -- Quickslot vertical (+ down, - up)
            },
            companionButton = {
                offsetX = 0,       -- Companion horizontal (+ right, - left)
                offsetY = 0,       -- Companion vertical (+ down, - up)
            },
            
            -- Mode-specific sizing (nil = use slots config)
            gamepad = {
                buttonSize = nil,  -- nil uses slots.gamepad.width
                spacing = nil,     -- nil uses slots.gamepad.spacing
                ultimateSize = 70, -- Ultimate button size (larger than skills)
            },
            keyboard = {
                buttonSize = nil,  -- nil uses slots.keyboard.width
                spacing = nil,     -- nil uses slots.keyboard.spacing
                ultimateSize = 55, -- Ultimate button size (larger than skills)
            },
        },
        
        -- ===================================================================
        -- CUSTOM BACK BAR
        -- Secondary weapon bar shown above front bar
        -- ===================================================================
        customBackBar = {
            offsetX = 0,           -- Whole bar horizontal offset (+ right, - left)
            offsetY = 0,           -- Whole bar vertical offset (+ down, - up)
            
            -- Fine-tune ultimate button position
            ultimate = {
                offsetX = 0,       -- Ultimate horizontal (+ right, - left)
                offsetY = 0,       -- Ultimate vertical (+ down, - up)
            },
            
            -- Mode-specific sizing (nil = inherit from front bar)
            gamepad = {
                buttonSize = nil,  -- nil uses front bar size
                spacing = 50,      -- Gap between buttons
                ultimateSize = nil,-- nil uses front bar ultimateSize
            },
            keyboard = {
                buttonSize = nil,  -- nil uses front bar size
                spacing = 50,      -- Gap between buttons
                ultimateSize = nil,-- nil uses front bar ultimateSize
            },
        },
        
        -- Bar container base positions (before customBar offsets applied)
        bottom = {                 -- Front bar container
            x = -40,               -- Horizontal offset (+ right, - left)
            gamepadY = -15,        -- Gamepad vertical (+ down, - up)
            keyboardY = -15,       -- Keyboard vertical (+ down, - up)
        },
        top = {                    -- Back bar container
            x = 25,                -- Horizontal offset (+ right, - left)
            gamepadY = -95,        -- Gamepad vertical (+ down, - up)
            keyboardY = -95,       -- Keyboard vertical (+ down, - up)
        },
    },
    
    -- =======================================================================
    -- ORNAMENT POSITIONS
    -- Statue graphics positioned relative to BgMiddle center
    -- =======================================================================
    ornaments = {
        left = { 
            x = -475,              -- Horizontal offset (+ right, - left)
            y = -15,               -- Vertical offset (+ down, - up)
            size = 375,            -- Size in pixels
            scale = 1.0,           -- Scale multiplier (1.0 = 100%)
        },
        right = { 
            x = 475,               -- Horizontal offset (+ right, - left)
            y = -25,               -- Vertical offset (+ down, - up)
            size = 400,            -- Size in pixels
            scale = 1.0,           -- Scale multiplier (1.0 = 100%)
        },
    },
    
    -- =======================================================================
    -- ORB RING POSITIONS
    -- Orb border circles positioned relative to their ornament center
    -- =======================================================================
    orbs = {
        left = { 
            x = 50,                -- Horizontal offset (+ right, - left)
            y = -10,               -- Vertical offset (+ down, - up)
            borderSize = 200,      -- Ring diameter in pixels
        },
        right = { 
            x = -60,               -- Horizontal offset (+ right, - left)
            y = 5,                 -- Vertical offset (+ down, - up)
            borderSize = 200,      -- Ring diameter in pixels
        },
    },
    
    -- =======================================================================
    -- FILL LAYER SIZING
    -- Colored resource display inside orbs
    -- scaleW/scaleH: size as fraction of borderSize (0.5 = 50%)
    -- x/y: offset from orb center (+ right/down, - left/up)
    -- =======================================================================
    fills = {
        health = { scaleW = 0.50, scaleH = 0.53, x = 0, y = 0 },
        magicka = { scaleW = 0.30, scaleH = 0.53, x = -10, y = -3 },
        stamina = { scaleW = 0.30, scaleH = 0.53, x = -60, y = -3 },
        resource = { scaleW = 0.50, scaleH = 0.53, x = 0, y = 0 },
        shield = { scaleW = 0.65, scaleH = 0.65, x = 0, y = 0 },
    },
    
    -- =======================================================================
    -- SPLITTER (Magicka/Stamina Divider)
    -- Vertical line separating the two resource pools
    -- =======================================================================
    splitter = { 
        width = 200,               -- Line width in pixels
        heightScale = 0.70,        -- Height as fraction of borderSize (0.7 = 70%)
        x = 4,                     -- Horizontal offset (+ right, - left)
        y = -5,                    -- Vertical offset (+ down, - up)
    },
    
    -- =======================================================================
    -- LABEL OFFSETS
    -- Numeric text position adjustments from default centered position
    -- =======================================================================
    labels = {
        health = { x = 0, y = 0 },   -- (+ right/down, - left/up)
        magicka = { x = 27, y = 0 }, -- (+ right/down, - left/up)
        stamina = { x = -20, y = 0 },-- (+ right/down, - left/up)
        shield = { x = 0, y = 25 },  -- (+ right/down, - left/up)
    },
}

-- ============================================================================
-- CUSTOM BARS
-- ============================================================================

-- Experience/Champion Bar positioning (Below left ornament)
BETTERUI_XP_BAR_SCALE = 1.0                -- Scale multiplier for XP bar
BETTERUI_XP_BAR_OFFSET_X = 0               -- X offset from center (positive = right)
BETTERUI_XP_BAR_OFFSET_Y = -99             -- Y offset from BgMiddle bottom (negative = up)
BETTERUI_XP_BAR_FILL_INSET_X = 35          -- Horizontal inset for fill bar within frame
BETTERUI_XP_BAR_FILL_INSET_Y = 55          -- Vertical inset for fill bar within frame
BETTERUI_XP_BAR_WIDTH = 250                -- Width of the XP bar in pixels
BETTERUI_XP_BAR_HEIGHT = 150               -- Height of the XP bar in pixels
BETTERUI_XP_BAR_LABEL_OFFSET_Y = 2         -- Vertical offset for text label (from center)

-- Cast Bar positioning (centered above top/back bar)
BETTERUI_CAST_BAR_SCALE = 1.0              -- Scale multiplier for Cast bar
BETTERUI_CAST_BAR_OFFSET_X = -30           -- X offset from center (negative = left)
BETTERUI_CAST_BAR_OFFSET_Y = 40            -- Y offset from back bar top (positive = down, closer to bar)
BETTERUI_CAST_BAR_FILL_INSET_X = 30        -- Horizontal inset for fill bar within frame
BETTERUI_CAST_BAR_FILL_INSET_Y = 58        -- Vertical inset for fill bar within frame
BETTERUI_CAST_BAR_WIDTH = 250              -- Width of the cast bar in pixels
BETTERUI_CAST_BAR_HEIGHT = 150             -- Height of the cast bar in pixels
BETTERUI_CAST_BAR_LABEL_OFFSET_Y = 2       -- Vertical offset for text label (from center)

-- Mount Stamina Bar positioning (under right ornament when mounted)
BETTERUI_MOUNT_STAMINA_BAR_SCALE = 1.0     -- Scale multiplier for mount stamina bar
BETTERUI_MOUNT_STAMINA_BAR_OFFSET_X = 0    -- X offset from center (positive = right)
BETTERUI_MOUNT_STAMINA_BAR_OFFSET_Y = -99  -- Y offset from ornament bottom (negative = up)
BETTERUI_MOUNT_STAMINA_BAR_FILL_INSET_X = 22   -- Horizontal inset for fill bar within frame
BETTERUI_MOUNT_STAMINA_BAR_FILL_INSET_Y = 60   -- Vertical inset for fill bar within frame
BETTERUI_MOUNT_STAMINA_BAR_WIDTH = 250     -- Width of the mount stamina bar in pixels
BETTERUI_MOUNT_STAMINA_BAR_HEIGHT = 150    -- Height of the mount stamina bar in pixels
BETTERUI_MOUNT_STAMINA_BAR_LABEL_OFFSET_Y = 2  -- Vertical offset for text label (from center)

-- ============================================================================
-- DEBUG FLAGS
-- ============================================================================

-- Set to true to show the shield overlay ring for visual debugging
BETTERUI_SHIELD_DEBUG = true