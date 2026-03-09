--[[
File: Modules/ResourceOrbFrames/Constants.lua
Purpose: Defines all static constants for the ResourceOrbFrames module.
         Centralizes layout dimensions, positioning offsets, and configuration values.
Author: BetterUI Team
Last Modified: 2026-02-12
]]


-- ============================================================================
-- SKILL BAR ENHANCEMENT CONSTANTS
-- ============================================================================
-- These constants are used by ResourceOrbFrames.lua for the skill bar enhancements.

-- Minimum cooldown duration (in ms) to display a cooldown timer.
-- Cooldowns shorter than this are treated as global cooldowns (GCD) and not shown.
-- Why 1500ms: Most potions have 45-60 second cooldowns; GCD is ~1 second.
BETTERUI_MIN_COOLDOWN_DISPLAY_MS = 1500

-- Default text size used for ultimate number and quickslot displays
BETTERUI_DEFAULT_SKILL_TEXT_SIZE = 27 -- Baseline font size for quickslot/ultimate text; increase improves readability but can overlap button glyphs.

-- Quickslot count text anchor offsets.
-- Keybind offsets are used when the quickslot button has a ButtonText keybind label.
BETTERUI_QUICKSLOT_COUNT_TEXT_KEYBIND_OFFSET_X = 0  -- Count-text X nudge from keybind label center (+ right, - left).
BETTERUI_QUICKSLOT_COUNT_TEXT_KEYBIND_OFFSET_Y = -2 -- Count-text Y nudge from keybind label center (+ down, - up).
BETTERUI_QUICKSLOT_COUNT_TEXT_BUTTON_OFFSET_X = 0   -- Count-text X nudge when anchored directly to quickslot button (+ right, - left).
BETTERUI_QUICKSLOT_COUNT_TEXT_BUTTON_OFFSET_Y = 1   -- Count-text Y nudge when anchored directly to button (+ down, - up).

-- Ultimate number text anchor and dimensions.
BETTERUI_ULTIMATE_NUMBER_TEXT_OFFSET_X = 0  -- Ultimate value X nudge from bottom-center anchor (+ right, - left).
BETTERUI_ULTIMATE_NUMBER_TEXT_OFFSET_Y = -5 -- Ultimate value Y nudge from bottom-center anchor (+ down, - up).
BETTERUI_ULTIMATE_NUMBER_TEXT_HEIGHT = 32   -- Label box height; increase gives more vertical room for larger fonts.

-- Combat icon placement (relative to quickslot button by default).
BETTERUI_COMBAT_ICON_TEXTURE = "EsoUI/Art/Options/Gamepad/gp_options_combat.dds" -- In-combat indicator texture path
BETTERUI_COMBAT_ICON_SIZE = 46                                                   -- Square icon size in pixels.
BETTERUI_COMBAT_ICON_OFFSET_X = 0                                                -- Horizontal nudge from quickslot anchor (+ right, - left).
BETTERUI_COMBAT_ICON_OFFSET_Y = -8                                               -- Vertical nudge from quickslot anchor (+ down, - up).
BETTERUI_COMBAT_ICON_TINT_R = 1.0                                                -- Red pulse tint R channel.
BETTERUI_COMBAT_ICON_TINT_G = 0.20                                               -- Red pulse tint G channel.
BETTERUI_COMBAT_ICON_TINT_B = 0.20                                               -- Red pulse tint B channel.
BETTERUI_COMBAT_ICON_PULSE_MIN_ALPHA = 0.45                                      -- Pulse low alpha floor.
BETTERUI_COMBAT_ICON_PULSE_MAX_ALPHA = 1.0                                       -- Pulse high alpha ceiling.
BETTERUI_COMBAT_ICON_PULSE_DURATION_MS = 700                                     -- One-way pulse duration in milliseconds.

-- ============================================================================
-- LAYOUT CONFIGURATION
-- Defines the ability slot dimensions and offsets for main bar skinning.
-- Used by: ResourceOrbFrames.lua (ApplyActionBarSkin)
-- ============================================================================
-- TODO(fix): Namespace LAYOUT_CONFIG under BETTERUI.ResourceOrbFrames.CONST.LAYOUT_CONFIG to prevent global collision
LAYOUT_CONFIG = {
    GAMEPAD = {
        abilitySlotWidth = 67,   -- Gamepad action-slot width; higher values enlarge slot boxes.
        abilitySlotOffsetX = 10, -- Global gamepad slot X nudge (+ right, - left) when skinning native controls.
    },
    KEYBOARD = {
        abilitySlotWidth = 50,  -- Keyboard action-slot width; keeps keyboard profile compact.
        abilitySlotOffsetX = 2, -- Global keyboard slot X nudge (+ right, - left) when skinning native controls.
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
    GAMEPAD_FRAME_WIDTH = 600,  -- Root frame width in gamepad mode (wider to fit custom bars).
    GAMEPAD_FRAME_HEIGHT = 256, -- Root frame height in gamepad mode.
    KEYBOARD_FRAME_WIDTH = 550, -- Root frame width in keyboard mode.
    ORNAMENT_SIZE = 465,        -- Shared square texture size for left/right ornament art.
    ORB_TEXTURE_SIZE = 240,     -- Base orb mask/border texture dimensions.
    FILL_TEXTURE_SIZE = 256,    -- Fill texture canvas size before per-orb scaling/cropping.
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
            width = 64,         -- Button size in pixels
            spacing = 10,       -- Gap between buttons (increase to spread apart)
            dualBarOffset = 44, -- Horizontal offset when dual bar is visible
        },
        keyboard = {
            width = 50,         -- Button size in pixels
            spacing = 2,        -- Gap between buttons (increase to spread apart)
            dualBarOffset = 12, -- Horizontal offset when dual bar is visible
        },
    },

    -- =======================================================================
    -- SKILL BAR POSITIONING
    -- Controls the position of front and back skill bars
    -- =======================================================================
    bars = {
        shiftY = 70,      -- Vertical shift for BOTH bars (+ down, - up)
        ultimateGap = 66, -- Gap before ultimate button in pixels

        -- Ultimate button offsets (shift left to make room for quickslot on right)
        frontUltimateOffsetX = -22, -- Front bar ultimate (+ right, - left)
        backUltimateOffsetX = -40,  -- Back bar ultimate (+ right, - left)

        -- Quickslot icon position (relative to BgMiddle center)
        quickslot = {
            x = 285, -- Horizontal offset (+ right, - left)
            y = -18, -- Vertical offset (+ down, - up)
        },

        -- Companion Ultimate icon position (relative to BgMiddle center)
        companionUltimate = {
            x = -290, -- Horizontal offset (+ right, - left)
            y = -22,  -- Vertical offset (+ down, - up)
        },

        -- ===================================================================
        -- CUSTOM FRONT BAR
        -- Replaces native ZO_ActionBar1 with custom-built bar
        -- ===================================================================
        customFrontBar = {
            m_enabled = true, -- Set false to use native front bar
            offsetX = 17,     -- Whole bar horizontal offset (+ right, - left)
            offsetY = 72,     -- Whole bar vertical offset (+ down, - up)

            -- Fine-tune individual button positions
            ultimate = {
                offsetX = -40, -- Ultimate horizontal (+ right, - left)
                offsetY = 0,   -- Ultimate vertical (+ down, - up)
            },
            quickslotButton = {
                offsetX = 0, -- Quickslot horizontal (+ right, - left)
                offsetY = 0, -- Quickslot vertical (+ down, - up)
            },
            companionButton = {
                offsetX = 17, -- Companion horizontal (+ right, - left)
                offsetY = 1,  -- Companion vertical (+ down, - up)
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
            offsetX = 2,  -- Whole bar horizontal offset (+ right, - left)
            offsetY = -5, -- Whole bar vertical offset (+ down, - up)

            -- Fine-tune ultimate button position
            ultimate = {
                offsetX = 0, -- Ultimate horizontal (+ right, - left)
                offsetY = 0, -- Ultimate vertical (+ down, - up)
            },

            -- Mode-specific sizing (nil = inherit from front bar)
            gamepad = {
                buttonSize = nil,   -- nil uses front bar size
                spacing = 10,       -- Gap between buttons
                ultimateSize = nil, -- nil uses front bar ultimateSize
            },
            keyboard = {
                buttonSize = nil,   -- nil uses front bar size
                spacing = 10,       -- Gap between buttons
                ultimateSize = nil, -- nil uses front bar ultimateSize
            },
        },

        -- Bar container base positions (before customBar offsets applied)
        bottom = {           -- Front bar container
            x = -40,         -- Horizontal offset (+ right, - left)
            gamepadY = -15,  -- Gamepad vertical (+ down, - up)
            keyboardY = -15, -- Keyboard vertical (+ down, - up)
        },
        top = {              -- Back bar container
            x = 25,          -- Horizontal offset (+ right, - left)
            gamepadY = -95,  -- Gamepad vertical (+ down, - up)
            keyboardY = -95, -- Keyboard vertical (+ down, - up)
        },
    },

    -- =======================================================================
    -- ORNAMENT POSITIONS
    -- Statue graphics positioned relative to BgMiddle center
    -- =======================================================================
    ornaments = {
        left = {
            x = -445,    -- Horizontal offset (+ right, - left)
            y = -54,     -- Vertical offset (+ down, - up)
            size = 300,  -- Size in pixels
            scale = 1.0, -- Scale multiplier (1.0 = 100%)
        },
        right = {
            x = 455,     -- Horizontal offset (+ right, - left)
            y = -50,     -- Vertical offset (+ down, - up)
            size = 300,  -- Size in pixels
            scale = 1.0, -- Scale multiplier (1.0 = 100%)
        },
    },

    -- =======================================================================
    -- ORB RING POSITIONS
    -- Orb border circles positioned relative to their ornament center
    -- noOrnament: Alternate positions relative to BgMiddle when ornament is hidden
    -- =======================================================================
    orbs = {
        left = {
            x = 63,              -- Horizontal offset (+ right, - left)
            y = -15,             -- Vertical offset (+ down, - up)
            borderSize = 225,    -- Ring diameter in pixels
            visibleScale = 1.00, -- Ornament-visible orb scale (relative to borderSize)
            -- Alternate positioning when left ornament is hidden (relative to BgMiddle)
            noOrnament = {
                x = -425, -- Direct position relative to BgMiddle center
                y = 0,    -- Direct vertical position relative to BgMiddle
            },
        },
        right = {
            x = -61,             -- Horizontal offset (+ right, - left)
            y = -15,             -- Vertical offset (+ down, - up)
            borderSize = 225,    -- Ring diameter in pixels
            visibleScale = 1.00, -- Ornament-visible orb scale (relative to borderSize)
            -- Alternate positioning when right ornament is hidden (relative to BgMiddle)
            noOrnament = {
                x = 425, -- Direct position relative to BgMiddle center
                y = 0,   -- Direct vertical position relative to BgMiddle
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
        health = { scaleW = 0.695, scaleH = 0.695, x = -1, y = -1 },
        magicka = { scaleW = 0.38, scaleH = 0.695, x = -19, y = 0 },
        stamina = { scaleW = 0.38, scaleH = 0.695, x = -93, y = 1 },
        resource = { scaleW = 0.75, scaleH = 0.695, x = 0, y = 0 },
        shield = { scaleW = 1.0, scaleH = 1.0, x = -3, y = 3, ringScale = 0.73 }, -- scaleW/scaleH relative to ring size (borderSize * ringScale)
    },

    -- =======================================================================
    -- SPLITTER (Magicka/Stamina Divider)
    -- Vertical line separating the two resource pools
    -- =======================================================================
    splitter = {
        width = 225,        -- Line width in pixels
        heightScale = 0.64, -- Height as fraction of borderSize (0.81 = 81%)
        x = -2,             -- Horizontal offset (+ right, - left)
        y = -3,             -- Vertical offset (+ down, - up)
    },

    -- =======================================================================
    -- LABEL OFFSETS
    -- Numeric text position adjustments from default centered position
    -- =======================================================================
    labels = {
        health = { x = 0, y = -8 },    -- (+ right/down, - left/up)
        magicka = { x = -32, y = -8 }, -- (+ right/down, - left/up)
        stamina = { x = 32, y = -8 },  -- (+ right/down, - left/up)
        shield = { x = 0, y = 14 },    -- (+ right/down, - left/up)
    },

    -- =======================================================================
    -- CUSTOM OVERLAYS
    -- Optional images displayed when Ornaments are hidden (e.g., Health.dds)
    -- NOTE: These are raw SetAnchor(CENTER, ..., x, y) offsets:
    --       +X moves RIGHT, -X moves LEFT, +Y moves DOWN, -Y moves UP.
    -- =======================================================================
    overlays = {
        health = {
            scale = 0.835, -- Size multiplier relative to border size
            x = 1,         -- Horizontal offset from center (+ right, - left)
            y = 1          -- Vertical offset from center (+ down, - up)
        },
        magStam = {
            scale = 0.83, -- Size multiplier relative to border size
            x = 4,        -- Horizontal offset from center (+ right, - left)
            y = -1        -- Vertical offset from center (+ down, - up)
        },
    },
}

-- ============================================================================
-- CUSTOM BARS
-- ============================================================================

-- TODO(refactor): Namespace bar config globals (BETTERUI_XP_BAR_*, BETTERUI_CAST_BAR_*, BETTERUI_MOUNT_STAMINA_BAR_*) under BETTERUI.ResourceOrbFrames.CONST.BARS
-- Fill tuning quick guide (applies to XP/Cast/Mount bars):
-- 1) Shrink/stretch fill track width with *_FILL_WIDTH_SCALE (1.0 = full bar width).
-- 2) Shrink/stretch fill track height with *_FILL_HEIGHT_SCALE (1.0 = full bar height).
-- 3) Move fill right/left with *_FILL_OFFSET_X (+ right, - left).
-- 4) Move fill down/up with *_FILL_OFFSET_Y (+ down, - up).
-- 5) Label anchors auto-center on the fill track; use *_BAR_LABEL_OFFSET_X/Y for final text nudges.

-- ============================================================================
-- RECTANGULAR BAR GRAPHICS
-- Backdrop textures are module-local DDS files (resolved from Textures).
-- Fill textures can be an ESO full path or a module-local DDS filename.
-- ============================================================================
BETTERUI_BAR_FILL_TEXTURE = "esoui/art/miscellaneous/progressbar_genericfill_tall.dds"

BETTERUI_XP_BAR_BACKDROP_TEXTURE = "Bar.dds"
BETTERUI_XP_BAR_FILL_TEXTURE = BETTERUI_BAR_FILL_TEXTURE

BETTERUI_CAST_BAR_BACKDROP_TEXTURE = "CastBar.dds"
BETTERUI_CAST_BAR_FILL_TEXTURE = BETTERUI_BAR_FILL_TEXTURE

BETTERUI_MOUNT_STAMINA_BAR_BACKDROP_TEXTURE = "MountBar.dds"
BETTERUI_MOUNT_STAMINA_BAR_FILL_TEXTURE = BETTERUI_BAR_FILL_TEXTURE

local function BuildBarFillRegionFromBox(barWidth, barHeight, fillWidthScale, fillHeightScale, fillOffsetX, fillOffsetY)
    -- Converts developer-friendly scale/offset values into normalized UV-like region bounds [0..1].
    local halfWidth = (fillWidthScale or 1) * 0.5
    local halfHeight = (fillHeightScale or 1) * 0.5
    local centerX = 0.5 + ((fillOffsetX or 0) / barWidth)
    local centerY = 0.5 + ((fillOffsetY or 0) / barHeight)

    return {
        left = centerX - halfWidth,
        right = centerX + halfWidth,
        top = centerY - halfHeight,
        bottom = centerY + halfHeight,
    }
end

-- Experience/Champion Bar positioning (Below left ornament)
BETTERUI_XP_BAR_SCALE = 1.0         -- Scale multiplier for XP bar
BETTERUI_XP_BAR_OFFSET_X = 5        -- X offset from center (positive = right)
BETTERUI_XP_BAR_OFFSET_Y = -85      -- Y offset from BgMiddle bottom (negative = up)
BETTERUI_XP_BAR_WIDTH = 228         -- Width of the XP bar in pixels
BETTERUI_XP_BAR_HEIGHT = 190        -- Height of the XP bar in pixels
BETTERUI_XP_BAR_LABEL_OFFSET_X = -2 -- Horizontal offset for text label (from fill-region center)
BETTERUI_XP_BAR_LABEL_OFFSET_Y = 2  -- Vertical offset for text label (from fill-region center)
BETTERUI_XP_BAR_TEXTURE_BOUNDS = {
    left = 0,                       -- Full texture (recalibrate once DDS artwork margins are known)
    right = 1,
    top = 0,
    bottom = 1,
}
BETTERUI_XP_BAR_FILL_WIDTH_SCALE = 0.58  -- Fill width as fraction of bar width (1.0 = full width)
BETTERUI_XP_BAR_FILL_HEIGHT_SCALE = 0.15 -- Fill height as fraction of bar height (1.0 = full height)
BETTERUI_XP_BAR_FILL_OFFSET_X = 0        -- Fill track horizontal offset (+ right, - left)
BETTERUI_XP_BAR_FILL_OFFSET_Y = 2        -- Fill track vertical offset (+ down, - up)
BETTERUI_XP_BAR_FILL_INSET_X = 20        -- Legacy fallback only (used only if fill-region config is invalid)
BETTERUI_XP_BAR_FILL_INSET_Y = 4         -- Legacy fallback only (used only if fill-region config is invalid)
BETTERUI_XP_BAR_FILL_REGION = BuildBarFillRegionFromBox(
    BETTERUI_XP_BAR_WIDTH,
    BETTERUI_XP_BAR_HEIGHT,
    BETTERUI_XP_BAR_FILL_WIDTH_SCALE,
    BETTERUI_XP_BAR_FILL_HEIGHT_SCALE,
    BETTERUI_XP_BAR_FILL_OFFSET_X,
    BETTERUI_XP_BAR_FILL_OFFSET_Y
)
-- XP Bar positioning when Left Ornament is hidden (relative to BgMiddle center)
-- These are DIRECT offsets from CENTER of BgMiddle, adjust to position bar on-screen
BETTERUI_XP_BAR_NO_ORNAMENT_OFFSET_X = -423 -- X offset from BgMiddle center (negative = left)
BETTERUI_XP_BAR_NO_ORNAMENT_OFFSET_Y = 108  -- Y offset from BgMiddle center (+ down, - up)

-- Cast Bar positioning (centered above top/back bar)
BETTERUI_CAST_BAR_SCALE = 1.0              -- Scale multiplier for Cast bar
BETTERUI_CAST_BAR_OFFSET_X = -30           -- X offset from center (negative = left)
BETTERUI_CAST_BAR_OFFSET_Y = 110           -- Y offset from back bar top (positive = down, closer to bar)
BETTERUI_CAST_BAR_INSTANT_DISPLAY_MS = 850 -- Preview duration for instant skills (milliseconds)
BETTERUI_CAST_BAR_WIDTH = 300              -- Width of the cast bar in pixels
BETTERUI_CAST_BAR_HEIGHT = 275             -- Height of the cast bar in pixels
BETTERUI_CAST_BAR_LABEL_OFFSET_X = -3      -- Horizontal offset for text label (from fill-region center)
BETTERUI_CAST_BAR_LABEL_OFFSET_Y = 0       -- Vertical offset for text label (from fill-region center)
BETTERUI_CAST_BAR_TEXTURE_BOUNDS = {
    left = 0,                              -- Full texture (recalibrate once DDS artwork margins are known)
    right = 1,
    top = 0,
    bottom = 1,
}
BETTERUI_CAST_BAR_FILL_WIDTH_SCALE = 0.59  -- Fill width as fraction of bar width (1.0 = full width)
BETTERUI_CAST_BAR_FILL_HEIGHT_SCALE = 0.10 -- Fill height as fraction of bar height (1.0 = full height)
BETTERUI_CAST_BAR_FILL_OFFSET_X = 10       -- Fill track horizontal offset (+ right, - left)
BETTERUI_CAST_BAR_FILL_OFFSET_Y = 0        -- Fill track vertical offset (+ down, - up)
BETTERUI_CAST_BAR_FILL_INSET_X = 45        -- Legacy fallback only (used only if fill-region config is invalid)
BETTERUI_CAST_BAR_FILL_INSET_Y = 59        -- Legacy fallback only (used only if fill-region config is invalid)
BETTERUI_CAST_BAR_FILL_REGION = BuildBarFillRegionFromBox(
    BETTERUI_CAST_BAR_WIDTH,
    BETTERUI_CAST_BAR_HEIGHT,
    BETTERUI_CAST_BAR_FILL_WIDTH_SCALE,
    BETTERUI_CAST_BAR_FILL_HEIGHT_SCALE,
    BETTERUI_CAST_BAR_FILL_OFFSET_X,
    BETTERUI_CAST_BAR_FILL_OFFSET_Y
)

-- Mount Stamina Bar positioning (under right ornament when mounted)
BETTERUI_MOUNT_STAMINA_BAR_SCALE = 1.0        -- Scale multiplier for mount stamina bar
BETTERUI_MOUNT_STAMINA_BAR_OFFSET_X = 0       -- X offset from center (positive = right)
BETTERUI_MOUNT_STAMINA_BAR_OFFSET_Y = -85     -- Y offset from ornament bottom (negative = up)
BETTERUI_MOUNT_STAMINA_BAR_WIDTH = 220        -- Width of the mount stamina bar in pixels
BETTERUI_MOUNT_STAMINA_BAR_HEIGHT = 185       -- Height of the mount stamina bar in pixels
BETTERUI_MOUNT_STAMINA_BAR_LABEL_OFFSET_X = 0 -- Horizontal offset for text label (from fill-region center)
BETTERUI_MOUNT_STAMINA_BAR_LABEL_OFFSET_Y = 1 -- Vertical offset for text label (from fill-region center)
BETTERUI_MOUNT_STAMINA_BAR_TEXTURE_BOUNDS = {
    left = 0,                                 -- Full texture (recalibrate once DDS artwork margins are known)
    right = 1,
    top = 0,
    bottom = 1,
}
BETTERUI_MOUNT_STAMINA_BAR_FILL_WIDTH_SCALE = 0.55  -- Fill width as fraction of bar width (1.0 = full width)
BETTERUI_MOUNT_STAMINA_BAR_FILL_HEIGHT_SCALE = 0.15 -- Fill height as fraction of bar height (1.0 = full height)
BETTERUI_MOUNT_STAMINA_BAR_FILL_OFFSET_X = 0        -- Fill track horizontal offset (+ right, - left)
BETTERUI_MOUNT_STAMINA_BAR_FILL_OFFSET_Y = 0        -- Fill track vertical offset (+ down, - up)
BETTERUI_MOUNT_STAMINA_BAR_FILL_INSET_X = 45        -- Legacy fallback only (used only if fill-region config is invalid)
BETTERUI_MOUNT_STAMINA_BAR_FILL_INSET_Y = 59        -- Legacy fallback only (used only if fill-region config is invalid)
BETTERUI_MOUNT_STAMINA_BAR_FILL_REGION = BuildBarFillRegionFromBox(
    BETTERUI_MOUNT_STAMINA_BAR_WIDTH,
    BETTERUI_MOUNT_STAMINA_BAR_HEIGHT,
    BETTERUI_MOUNT_STAMINA_BAR_FILL_WIDTH_SCALE,
    BETTERUI_MOUNT_STAMINA_BAR_FILL_HEIGHT_SCALE,
    BETTERUI_MOUNT_STAMINA_BAR_FILL_OFFSET_X,
    BETTERUI_MOUNT_STAMINA_BAR_FILL_OFFSET_Y
)
-- Mount Stamina Bar positioning when Right Ornament is hidden (relative to BgMiddle center)
-- These are DIRECT offsets from CENTER of BgMiddle, adjust to position bar on-screen
BETTERUI_MOUNT_STAMINA_BAR_NO_ORNAMENT_OFFSET_X = 424 -- X offset from BgMiddle center (positive = right)
BETTERUI_MOUNT_STAMINA_BAR_NO_ORNAMENT_OFFSET_Y = 110 -- Y offset from BgMiddle center (+ down, - up)

-- ============================================================================
-- DEBUG FLAGS
-- ============================================================================

-- TODO(cleanup): Migrate BETTERUI_SHIELD_DEBUG to CIM FeatureFlags system instead of bare global
-- Set to true to show the shield overlay ring for visual debugging (MUST default to false for production)
BETTERUI_SHIELD_DEBUG = false
