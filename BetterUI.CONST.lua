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
-- RESOURCE ORB FRAMES - ACTION BAR LAYOUT
-- Controls the custom dual action bar positioning in the Resource Orb Frames
-- ============================================================================

-- Skill button dimensions (pixels)
BETTERUI_RESOURCE_ORB_FRAMES_GAMEPAD_SLOT_WIDTH = 64          -- Width/height of skill buttons in gamepad mode
BETTERUI_RESOURCE_ORB_FRAMES_KEYBOARD_SLOT_WIDTH = 50         -- Width/height of skill buttons in keyboard mode

-- Spacing between skill buttons (pixels)
BETTERUI_RESOURCE_ORB_FRAMES_GAMEPAD_SLOT_SPACING = 10        -- Gap between adjacent skill buttons in gamepad mode
BETTERUI_RESOURCE_ORB_FRAMES_KEYBOARD_SLOT_SPACING = 2        -- Gap between adjacent skill buttons in keyboard mode

-- Dual bar horizontal offset
BETTERUI_RESOURCE_ORB_FRAMES_GAMEPAD_DUAL_BAR_OFFSET = 44     -- Horizontal offset for dual bar in gamepad mode
BETTERUI_RESOURCE_ORB_FRAMES_KEYBOARD_DUAL_BAR_OFFSET = 12    -- Horizontal offset for dual bar in keyboard mode

-- Back bar (top bar) ultimate skill gap - extra spacing before ultimate
BETTERUI_RESOURCE_ORB_FRAMES_ULTIMATE_GAP = 66                -- Extra pixels between 5th skill and ultimate on back bar

-- ============================================================================
-- RESOURCE ORB FRAMES - SKILL BAR POSITIONING
-- ============================================================================
-- 
-- BOTTOM BAR = The main/active skill bar (the one you're currently using)
-- TOP BAR = The back/inactive skill bar (your weapon swap bar)
--
-- To move a bar UP: decrease the Y value (more negative)
-- To move a bar DOWN: increase the Y value (less negative)
-- To move a bar LEFT: decrease the X value (negative)
-- To move a bar RIGHT: increase the X value (positive)
-- ============================================================================

-- Global vertical shift (moves BOTH bars together)
BETTERUI_RESOURCE_ORB_FRAMES_BAR_SHIFT_Y = 70                 -- Increase to move both bars down

-- BOTTOM BAR (main skill bar) position adjustments
BETTERUI_RESOURCE_ORB_FRAMES_BOTTOM_BAR_OFFSET_X = -40          -- Move bottom bar left/right (0 = centered)
BETTERUI_RESOURCE_ORB_FRAMES_GAMEPAD_BOTTOM_BAR_Y = -15       -- Gamepad: bottom bar up/down
BETTERUI_RESOURCE_ORB_FRAMES_KEYBOARD_BOTTOM_BAR_Y = -15      -- Keyboard: bottom bar up/down

-- TOP BAR (back/weapon swap skill bar) position adjustments  
BETTERUI_RESOURCE_ORB_FRAMES_TOP_BAR_OFFSET_X = 25             -- Move top bar left/right (0 = centered)
BETTERUI_RESOURCE_ORB_FRAMES_GAMEPAD_TOP_BAR_Y = -103         -- Gamepad: top bar up/down (more negative = higher)
BETTERUI_RESOURCE_ORB_FRAMES_KEYBOARD_TOP_BAR_Y = -103        -- Keyboard: top bar up/down (more negative = higher)

-- Legacy shift factor (keep at 0 for aligned bars)
BETTERUI_RESOURCE_ORB_FRAMES_MAIN_BAR_SHIFT_LEFT_FACTOR = 0

-- Other bar elements
BETTERUI_RESOURCE_ORB_FRAMES_INDICATOR_OFFSET_X = -10         -- Bar swap indicator position
BETTERUI_RESOURCE_ORB_FRAMES_QUICKSLOT_OFFSET_X = 0         -- Quickslot button distance from main bar

-- ============================================================================
-- RESOURCE ORB FRAMES - ORB & ORNAMENT LAYOUT
-- ============================================================================

-- ============================================================================
-- ORNAMENT (STATUE) POSITIONING
-- Ornaments are the demon/knight statue graphics that frame the orbs
-- These are positioned relative to BgMiddle (center of skill bars)
-- ============================================================================

-- Left Ornament (Demon)
BETTERUI_ORNAMENT_LEFT_OFFSET_X = -450    -- X position from center (negative = left)
BETTERUI_ORNAMENT_LEFT_OFFSET_Y = -15     -- Y offset (negative = up)
BETTERUI_ORNAMENT_LEFT_SIZE = 375         -- Base size in pixels
BETTERUI_ORNAMENT_LEFT_SCALE = 1.0        -- Scale multiplier (1.0 = 100%, 1.5 = 150%, etc.)

-- Right Ornament (Knight)
BETTERUI_ORNAMENT_RIGHT_OFFSET_X = 450    -- X position from center (positive = right)
BETTERUI_ORNAMENT_RIGHT_OFFSET_Y = -25    -- Y offset (negative = up)
BETTERUI_ORNAMENT_RIGHT_SIZE = 400        -- Base size in pixels
BETTERUI_ORNAMENT_RIGHT_SCALE = 1.0       -- Scale multiplier (1.0 = 100%, 1.5 = 150%, etc.)

-- ============================================================================
-- ORB BORDER (RING GRAPHIC)
-- The circular border/ring graphic that sits inside the ornament holes
-- ============================================================================

-- Orb Border position relative to Ornament center
BETTERUI_ORB_LEFT_OFFSET_X = 50           -- Left Orb X nudge (positive = right)
BETTERUI_ORB_LEFT_OFFSET_Y = -10          -- Left Orb Y nudge (positive = down)
BETTERUI_ORB_RIGHT_OFFSET_X = -60           -- Right Orb X nudge (positive = right)
BETTERUI_ORB_RIGHT_OFFSET_Y = 5          -- Right Orb Y nudge (positive = down)

-- Orb Border size (separate for each side)
BETTERUI_ORB_BORDER_LEFT_SIZE = 200       -- Left Orb border size (OrbBorder.dds)
BETTERUI_ORB_BORDER_RIGHT_SIZE = 200      -- Right Orb border size (OrbBorder.dds)
BETTERUI_ORB_AURA_SIZE = 350              -- Size of the glow aura effect

-- ============================================================================
-- ORB FILL (RESOURCE LEVEL DISPLAY)
-- The colored fill that shows your current health/magicka/stamina level
-- Fill size is calculated as: Border Size * Fill Scale
-- Fill is automatically centered within the border
-- ============================================================================

-- Fill scale (0.75 = 75% of border size, adjust to fit inside the ring)
BETTERUI_ORB_FILL_SCALE = 0.55            -- Fill size as percentage of border size
-- If you'd like to control the left (Health) and right (Magicka/Stamina) fill sizes independently,
-- set these scales. They default to the legacy `BETTERUI_ORB_FILL_SCALE` for backward compatibility.
BETTERUI_ORB_FILL_HEALTH_SCALE = BETTERUI_ORB_FILL_SCALE  -- Health orb fill scale (left orb)
BETTERUI_ORB_FILL_RESOURCE_SCALE = BETTERUI_ORB_FILL_SCALE -- Resource orb fill scale (right orb)

-- HEALTH FILL (Left Orb - Red) - Fine-tune position after centering
BETTERUI_ORB_FILL_HEALTH_OFFSET_X = 0     -- Health fill X nudge (positive = right)
BETTERUI_ORB_FILL_HEALTH_OFFSET_Y = 0     -- Health fill Y nudge (positive = down)

-- RESOURCE FILL (Right Orb - Blue/Green for Magicka/Stamina) - Fine-tune position after centering
BETTERUI_ORB_FILL_RESOURCE_OFFSET_X = 0   -- Resource fill X nudge (positive = right)
BETTERUI_ORB_FILL_RESOURCE_OFFSET_Y = 0   -- Resource fill Y nudge (positive = down)

-- ============================================================================
-- ORB SPLITTER (DIVIDER LINE - Magicka/Stamina Separator)
-- The vertical line graphic that divides the magicka and stamina fills
-- ============================================================================

-- Splitter width (thickness of the divider line in pixels - decrease to make thinner)
BETTERUI_ORB_SPLITTER_WIDTH = 200          -- Width of the divider line (decrease for thinner line)

-- Splitter height (how tall the divider line is - as percentage of border size)
BETTERUI_ORB_SPLITTER_HEIGHT_SCALE = 0.70  -- Height as percentage of orb border size (1.0 = full height)

-- Splitter position fine-tuning (offsets from center of resource orb)
BETTERUI_ORB_SPLITTER_OFFSET_X = 4        -- Splitter X nudge (positive = move right)
BETTERUI_ORB_SPLITTER_OFFSET_Y = -5        -- Splitter Y nudge (positive = move down)