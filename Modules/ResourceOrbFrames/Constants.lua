--[[
File: Modules/ResourceOrbFrames/Constants.lua
Purpose: Defines all static constants for the ResourceOrbFrames module.
         Centralizes layout dimensions, positioning offsets, and configuration values.
Author: BetterUI Team
Last Modified: 2026-01-23
]]

local _

-- ============================================================================
-- SKILL BAR ENHANCEMENT CONSTANTS
-- ============================================================================
-- These constants are used by ResourceOrbFrames.lua for the skill bar enhancements.

-- Minimum cooldown duration (in ms) to display a cooldown timer.
-- Cooldowns shorter than this are treated as global cooldowns (GCD) and not shown.
-- Why 1500ms: Most potions have 45-60 second cooldowns; GCD is ~1 second.
BETTERUI_MIN_COOLDOWN_DISPLAY_MS = 1500

-- Default text size used for ultimate number and quickslot displays
BETTERUI_DEFAULT_SKILL_TEXT_SIZE = 27

-- ============================================================================
-- LAYOUT CONFIGURATION
-- Defines the ability slot dimensions and offsets for main bar skinning.
-- Used by: ResourceOrbFrames.lua (ApplyActionBarSkin)
-- ============================================================================
LAYOUT_CONFIG = {
    GAMEPAD = { 
        abilitySlotWidth = 67, 
        abilitySlotOffsetX = 10 
    },
    KEYBOARD = { 
        abilitySlotWidth = 50, 
        abilitySlotOffsetX = 2 
    }
}

-- ============================================================================
-- RESOURCE ORB FRAMES - STRUCTURED CONFIGURATION
-- 
-- OFFSET DIRECTIONS:
--   X: + moves right, - moves left
--   Y: + moves down, - moves up
-- 
-- nil values inherit from parent config (e.g., slots or front bar)
-- ============================================================================

--- Dimensions for the Resource Orb Frames layout.
--- Rationale: Centralizing these values allows for easier UI scaling and theme support.
if not BETTERUI.CONST.ORBS then BETTERUI.CONST.ORBS = {} end
BETTERUI.CONST.ORBS.DIMENSIONS = {
    GAMEPAD_FRAME_WIDTH = 600,
    GAMEPAD_FRAME_HEIGHT = 256,
    KEYBOARD_FRAME_WIDTH = 550,
    ORNAMENT_SIZE = 465,
    ORB_TEXTURE_SIZE = 240,
    FILL_TEXTURE_SIZE = 256,
}

--- Configuration table for the Resource Orb Frames (Health/Magicka/Stamina orbs).
---
--- Purpose: Defines all spatial relationships and sizing for the ARPG-style interface.
--- Mechanics: Nested table structure defining x/y offsets, scales, and dimensional constraints for orb elements.
--- References: Used by Modules/GeneralInterface/ResourceOrbFrames.lua to build the custom HUD.
BETTERUI_ORB_FRAMES = {
    -- =======================================================================
    -- FRAME DIMENSIONS
    -- Top-level container sizing
    -- =======================================================================
    frame = {
        gamepad = { 
            width = BETTERUI.CONST.ORBS.DIMENSIONS.GAMEPAD_FRAME_WIDTH, 
            height = BETTERUI.CONST.ORBS.DIMENSIONS.GAMEPAD_FRAME_HEIGHT 
        },
        keyboard = { 
            width = BETTERUI.CONST.ORBS.DIMENSIONS.KEYBOARD_FRAME_WIDTH, 
            height = BETTERUI.CONST.ORBS.DIMENSIONS.GAMEPAD_FRAME_HEIGHT 
        },
    },

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
            x = 285,              -- Horizontal offset (+ right, - left)
            y = -18,              -- Vertical offset (+ down, - up)
        },
        
        -- Companion Ultimate icon position (relative to BgMiddle center)
        companionUltimate = {
            x = -290,             -- Horizontal offset (+ right, - left)
            y = -22,              -- Vertical offset (+ down, - up)
        },
        
        -- ===================================================================
        -- CUSTOM FRONT BAR
        -- Replaces native ZO_ActionBar1 with custom-built bar
        -- ===================================================================
        customFrontBar = {
            m_enabled = true,        -- Set false to use native front bar
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
                offsetX = 17,       -- Companion horizontal (+ right, - left)
                offsetY = 1,       -- Companion vertical (+ down, - up)
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
            offsetX = 2,           -- Whole bar horizontal offset (+ right, - left)
            offsetY = -5,           -- Whole bar vertical offset (+ down, - up)
            
            -- Fine-tune ultimate button position
            ultimate = {
                offsetX = 0,       -- Ultimate horizontal (+ right, - left)
                offsetY = 0,       -- Ultimate vertical (+ down, - up)
            },
            
            -- Mode-specific sizing (nil = inherit from front bar)
            gamepad = {
                buttonSize = nil,  -- nil uses front bar size
                spacing = 10,      -- Gap between buttons
                ultimateSize = nil,-- nil uses front bar ultimateSize
            },
            keyboard = {
                buttonSize = nil,  -- nil uses front bar size
                spacing = 10,      -- Gap between buttons
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
            x = -445,              -- Horizontal offset (+ right, - left)
            y = -15,               -- Vertical offset (+ down, - up)
            size = 375,            -- Size in pixels
            scale = 1.0,           -- Scale multiplier (1.0 = 100%)
        },
        right = { 
            x = 455,               -- Horizontal offset (+ right, - left)
            y = -25,               -- Vertical offset (+ down, - up)
            size = 400,            -- Size in pixels
            scale = 1.0,           -- Scale multiplier (1.0 = 100%)
        },
    },
    
    -- =======================================================================
    -- ORB RING POSITIONS
    -- Orb border circles positioned relative to their ornament center
    -- noOrnament: Alternate positions relative to BgMiddle when ornament is hidden
    -- =======================================================================
    orbs = {
        left = { 
            x = 50,                -- Horizontal offset (+ right, - left)
            y = -10,               -- Vertical offset (+ down, - up)
            borderSize = 200,      -- Ring diameter in pixels
            -- Alternate positioning when left ornament is hidden (relative to BgMiddle)
            noOrnament = {
                x = -395,          -- Direct position relative to BgMiddle center
                y = 25,           -- Direct vertical position relative to BgMiddle
            },
        },
        right = { 
            x = -60,               -- Horizontal offset (+ right, - left)
            y = 5,                 -- Vertical offset (+ down, - up)
            borderSize = 200,      -- Ring diameter in pixels
            -- Alternate positioning when right ornament is hidden (relative to BgMiddle)
            noOrnament = {
                x = 400,           -- Direct position relative to BgMiddle center
                y = 25,           -- Direct vertical position relative to BgMiddle
            },
        },
    },
    
    -- =======================================================================
    -- FILL LAYER SIZING
    -- Colored resource display inside orbs
    -- scaleW/scaleH: size as fraction of borderSize (0.5 = 50%)
    -- x/y: offset from orb center (+ right/down, - left/up)
    -- =======================================================================
    fills = {
        health = { scaleW = 0.535, scaleH = 0.535, x = 2, y = -3 },
        magicka = { scaleW = 0.28, scaleH = 0.535, x = -10, y = -1 },
        stamina = { scaleW = 0.28, scaleH = 0.535, x = -61, y = -1 },
        resource = { scaleW = 0.50, scaleH = 0.535, x = 0, y = 0 },
        shield = { scaleW = 0.535, scaleH = 0.535, x = 2.5, y = -1.5, ringScale = 1.2 },  -- ringScale: shield ring is 20% larger than health orb
    },
    
    -- =======================================================================
    -- SPLITTER (Magicka/Stamina Divider)
    -- Vertical line separating the two resource pools
    -- =======================================================================
    splitter = { 
        width = 200,               -- Line width in pixels
        heightScale = 0.65,        -- Height as fraction of borderSize (0.7 = 70%)
        x = 4,                     -- Horizontal offset (+ right, - left)
        y = -1,                    -- Vertical offset (+ down, - up)
    },
    
    -- =======================================================================
    -- LABEL OFFSETS
    -- Numeric text position adjustments from default centered position
    -- =======================================================================
    labels = {
        health = { x = 2, y = -2 },   -- (+ right/down, - left/up)
        magicka = { x = 25, y = 0 }, -- (+ right/down, - left/up)
        stamina = { x = -20, y = 0 },-- (+ right/down, - left/up)
        shield = { x = 0, y = 25 },  -- (+ right/down, - left/up)
    },

    -- =======================================================================
    -- CUSTOM OVERLAYS
    -- Optional images displayed when Ornaments are hidden (e.g., Health.dds)
    -- NOTE: Offset directions are user-calibrated for these specific textures.
    -- =======================================================================
    overlays = {
        health = { 
            scale = 0.835,           -- Size multiplier relative to border size
            x = 1,                 -- Horizontal offset from center (+ left, - right)
            y = 1                  -- Vertical offset from center (+ up, - down)
        },
        magStam = { 
            scale = 0.83,           -- Size multiplier relative to border size
            x = 4,                 -- Horizontal offset from center (+ left, - right)
            y = -1                  -- Vertical offset from center (+ up, - down)
        },
    },
}

-- ============================================================================
-- CUSTOM BARS
-- ============================================================================

-- Experience/Champion Bar positioning (Below left ornament)
BETTERUI_XP_BAR_SCALE = 1.0                -- Scale multiplier for XP bar
BETTERUI_XP_BAR_OFFSET_X = 0               -- X offset from center (positive = right)
BETTERUI_XP_BAR_OFFSET_Y = -99             -- Y offset from BgMiddle bottom (negative = up)
BETTERUI_XP_BAR_FILL_INSET_X = 45          -- Horizontal inset for fill bar within frame
BETTERUI_XP_BAR_FILL_INSET_Y = 59         -- Vertical inset for fill bar within frame
BETTERUI_XP_BAR_WIDTH = 250                -- Width of the XP bar in pixels
BETTERUI_XP_BAR_HEIGHT = 150               -- Height of the XP bar in pixels
BETTERUI_XP_BAR_LABEL_OFFSET_Y = 2         -- Vertical offset for text label (from center)
-- XP Bar positioning when Left Ornament is hidden (relative to BgMiddle center)
-- These are DIRECT offsets from CENTER of BgMiddle, adjust to position bar on-screen
BETTERUI_XP_BAR_NO_ORNAMENT_OFFSET_X = -350  -- X offset from BgMiddle center (negative = left)
BETTERUI_XP_BAR_NO_ORNAMENT_OFFSET_Y = 108   -- Y offset from BgMiddle center (negative = up)

-- Cast Bar positioning (centered above top/back bar)
BETTERUI_CAST_BAR_SCALE = 1.0              -- Scale multiplier for Cast bar
BETTERUI_CAST_BAR_OFFSET_X = -30           -- X offset from center (negative = left)
BETTERUI_CAST_BAR_OFFSET_Y = 45            -- Y offset from back bar top (positive = down, closer to bar)
BETTERUI_CAST_BAR_FILL_INSET_X = 45        -- Horizontal inset for fill bar within frame
BETTERUI_CAST_BAR_FILL_INSET_Y = 59       -- Vertical inset for fill bar within frame
BETTERUI_CAST_BAR_WIDTH = 250              -- Width of the cast bar in pixels
BETTERUI_CAST_BAR_HEIGHT = 150             -- Height of the cast bar in pixels
BETTERUI_CAST_BAR_LABEL_OFFSET_Y = 2       -- Vertical offset for text label (from center)

-- Mount Stamina Bar positioning (under right ornament when mounted)
BETTERUI_MOUNT_STAMINA_BAR_SCALE = 1.0     -- Scale multiplier for mount stamina bar
BETTERUI_MOUNT_STAMINA_BAR_OFFSET_X = 0    -- X offset from center (positive = right)
BETTERUI_MOUNT_STAMINA_BAR_OFFSET_Y = -99  -- Y offset from ornament bottom (negative = up)
BETTERUI_MOUNT_STAMINA_BAR_FILL_INSET_X = 45   -- Horizontal inset for fill bar within frame
BETTERUI_MOUNT_STAMINA_BAR_FILL_INSET_Y = 59   -- Vertical inset for fill bar within frame
BETTERUI_MOUNT_STAMINA_BAR_WIDTH = 250     -- Width of the mount stamina bar in pixels
BETTERUI_MOUNT_STAMINA_BAR_HEIGHT = 150    -- Height of the mount stamina bar in pixels
BETTERUI_MOUNT_STAMINA_BAR_LABEL_OFFSET_Y = 2  -- Vertical offset for text label (from center)
-- Mount Stamina Bar positioning when Right Ornament is hidden (relative to BgMiddle center)
-- These are DIRECT offsets from CENTER of BgMiddle, adjust to position bar on-screen
BETTERUI_MOUNT_STAMINA_BAR_NO_ORNAMENT_OFFSET_X = 375  -- X offset from BgMiddle center (positive = right)
BETTERUI_MOUNT_STAMINA_BAR_NO_ORNAMENT_OFFSET_Y = 108 -- Y offset from BgMiddle center (negative = up)

-- ============================================================================
-- RECTANGULAR BAR FILL TEXTURES
-- These textures are used for the XP, Cast, and Mount Stamina bars
-- ============================================================================

BETTERUI_BAR_FILL_TEXTURE = "esoui/art/miscellaneous/progressbar_genericfill_tall.dds"

-- ============================================================================
-- DEBUG FLAGS
-- ============================================================================

-- Set to true to show the shield overlay ring for visual debugging
-- Set to true to show the shield overlay ring for visual debugging
BETTERUI_SHIELD_DEBUG = false
