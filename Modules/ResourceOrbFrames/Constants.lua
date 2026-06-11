--[[
File: Modules/ResourceOrbFrames/Constants.lua
Purpose: Defines all static constants for the ResourceOrbFrames module.
         Centralizes layout dimensions, positioning offsets, and configuration values.
]]


-- SKILL BAR ENHANCEMENT CONSTANTS
-- These constants are used by ResourceOrbFrames.lua for the skill bar enhancements.


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

-- NAMESPACE GUARDS
-- Constants.lua is the first ResourceOrbFrames file in the manifest load order.
-- These guards must run before any CONST sub-table assignments below.
if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
if not BETTERUI.ResourceOrbFrames.CONST then BETTERUI.ResourceOrbFrames.CONST = {} end

-- LAYOUT CONFIGURATION
-- Defines the ability slot dimensions and offsets for main bar skinning.
-- Used by: ResourceOrbFrames.lua (ApplyActionBarSkin)
BETTERUI.ResourceOrbFrames.CONST.LAYOUT_CONFIG = {
    GAMEPAD = {
        abilitySlotOffsetX = 10, -- Global gamepad slot X nudge (+ right, - left) when skinning native controls.
    },
    KEYBOARD = {
        abilitySlotOffsetX = 2, -- Global keyboard slot X nudge (+ right, - left) when skinning native controls.
    }
}

-- RESOURCE ORB FRAMES - STRUCTURED CONFIGURATION
--
-- OFFSET DIRECTIONS:
--   X: + moves right, - moves left
--   Y: + moves down, - moves up
--
-- nil values inherit from parent config (e.g., slots or front bar)

--- Dimensions for the Resource Orb Frames layout.
--- Rationale: Centralizing these values allows for easier UI scaling and theme support.
BETTERUI.ResourceOrbFrames.CONST.ORBS_DIMENSIONS = {
    GAMEPAD_FRAME_WIDTH = 600,  -- Root frame width in gamepad mode (wider to fit custom bars).
    GAMEPAD_FRAME_HEIGHT = 256, -- Root frame height in gamepad mode.
    KEYBOARD_FRAME_WIDTH = 550, -- Root frame width in keyboard mode.
    ORNAMENT_SIZE = 465,        -- Shared square texture size for left/right ornament art.
    ORB_TEXTURE_SIZE = 240,     -- Base orb mask/border texture dimensions.
    FILL_TEXTURE_SIZE = 256,    -- Fill texture canvas size before per-orb scaling/cropping.
}
--- Background fill padding. Fog2 (dimmed background) is scaled by this factor
--- relative to the Fog (resource fill) to fully cover the orb interior and
--- prevent game-world bleed at the edges when resources drain.
--- Per-resource values allow independent tuning (health is a full circle, mag/stam are halves).
BETTERUI.ResourceOrbFrames.CONST.ORBS_BG_FILL_PADDING = {
    health  = 1.02, -- 2% larger; full-circle orb shows edges more prominently
    magicka = 1.04, -- 4% larger; half-texture needs more coverage
    stamina = 1.04, -- 4% larger; mirrors magicka
}

--- Configuration table for the Resource Orb Frames (Health/Magicka/Stamina orbs).
---
--- Purpose: Defines all spatial relationships and sizing for the ARPG-style interface.
--- Mechanics: Nested table structure defining x/y offsets, scales, and dimensional constraints for orb elements.
--- References: Used by Modules/GeneralInterface/ResourceOrbFrames.lua to build the custom HUD.
BETTERUI_ORB_FRAMES = {
    -- FRAME DIMENSIONS
    -- Top-level container sizing
    frame = {
        gamepad = {
            width = BETTERUI.ResourceOrbFrames.CONST.ORBS_DIMENSIONS.GAMEPAD_FRAME_WIDTH,
            height = BETTERUI.ResourceOrbFrames.CONST.ORBS_DIMENSIONS.GAMEPAD_FRAME_HEIGHT
        },
        keyboard = {
            width = BETTERUI.ResourceOrbFrames.CONST.ORBS_DIMENSIONS.KEYBOARD_FRAME_WIDTH,
            height = BETTERUI.ResourceOrbFrames.CONST.ORBS_DIMENSIONS.GAMEPAD_FRAME_HEIGHT
        },
    },

    -- SKILL BUTTON DIMENSIONS
    -- Controls the size and spacing of skill bar buttons
    slots = {
        gamepad = {
            width = 64,         -- Button size in pixels
            spacing = 10,       -- Gap between buttons (increase to spread apart)
            dualBarOffset = 44, -- Horizontal offset when dual bar is visible
        },
        keyboard = {
            width = 64,         -- Matches gamepad for visual parity when switching modes
            spacing = 10,       -- Gap between buttons (increase to spread apart)
            dualBarOffset = 44, -- Horizontal offset when dual bar is visible
        },
    },

    -- SKILL BAR POSITIONING
    -- Controls the position of front and back skill bars
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

        -- CUSTOM FRONT BAR
        -- Replaces native ZO_ActionBar1 with custom-built bar
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
                buttonSize = nil,  -- nil uses slots.keyboard.width (now matches gamepad)
                spacing = nil,     -- nil uses slots.keyboard.spacing
                ultimateSize = 70, -- Matches gamepad for visual parity
            },
        },

        -- CUSTOM BACK BAR
        -- Secondary weapon bar shown above front bar
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

    -- ORNAMENT POSITIONS
    -- Statue graphics positioned relative to BgMiddle center
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

    -- ORB RING POSITIONS
    -- Orb border circles positioned relative to their ornament center
    -- noOrnament: Alternate positions relative to BgMiddle when ornament is hidden
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

    -- FILL LAYER SIZING
    -- Colored resource display inside orbs
    -- scaleW/scaleH: size as fraction of borderSize (0.5 = 50%)
    -- x/y: offset from orb center (+ right/down, - left/up)
    fills = {
        health = { scaleW = 0.695, scaleH = 0.695, x = -1, y = -1 },
        magicka = { scaleW = 0.38, scaleH = 0.695, x = -19, y = 0 },
        stamina = { scaleW = 0.38, scaleH = 0.695, x = -93, y = 1 },
        resource = { scaleW = 0.75, scaleH = 0.695, x = 0, y = 0 },
        shield = { scaleW = 1.0, scaleH = 1.0, x = -3, y = 3, ringScale = 0.73 }, -- scaleW/scaleH relative to ring size (borderSize * ringScale)
    },

    -- SPLITTER (Magicka/Stamina Divider)
    -- Vertical line separating the two resource pools
    splitter = {
        width = 225,        -- Line width in pixels
        heightScale = 0.64, -- Height as fraction of borderSize (0.81 = 81%)
        x = -2,             -- Horizontal offset (+ right, - left)
        y = -3,             -- Vertical offset (+ down, - up)
    },

    -- LABEL OFFSETS
    -- Numeric text position adjustments from default centered position
    labels = {
        health = { x = 0, y = -8 },    -- (+ right/down, - left/up)
        magicka = { x = -32, y = -8 }, -- (+ right/down, - left/up)
        stamina = { x = 32, y = -8 },  -- (+ right/down, - left/up)
        shield = { x = 0, y = 14 },    -- (+ right/down, - left/up)
    },

}

-- CUSTOM BARS

-- Namespaced bar configuration (replaces former BETTERUI_*_BAR_* globals)
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

BETTERUI.ResourceOrbFrames.CONST.BARS = {
    -- Shared fill texture for all rectangular bars
    FILL_TEXTURE = "esoui/art/miscellaneous/progressbar_genericfill_tall.dds",

    -- Experience/Champion Bar (Below left ornament)
    -- Fill tuning: *_SCALE = fraction of bar dimension, *_OFFSET = pixel nudge
    XP = {
        BACKDROP_TEXTURE  = "Bar.dds",
        FILL_TEXTURE      = "esoui/art/miscellaneous/progressbar_genericfill_tall.dds",
        SCALE             = 1.0,          -- Scale multiplier for XP bar
        OFFSET_X          = 5,            -- X offset from center (+ right, - left)
        OFFSET_Y          = -85,          -- Y offset from BgMiddle bottom (- up, + down)
        WIDTH             = 228,          -- Width in pixels
        HEIGHT            = 190,          -- Height in pixels
        LABEL_OFFSET_X    = -2,           -- Text nudge from fill-region center (+ right)
        LABEL_OFFSET_Y    = 2,            -- Text nudge from fill-region center (+ down)
        TEXTURE_BOUNDS    = { left = 0, right = 1, top = 0, bottom = 1 },
        FILL_WIDTH_SCALE  = 0.58,         -- Fill width as fraction of bar width (1.0 = full)
        FILL_HEIGHT_SCALE = 0.15,         -- Fill height as fraction of bar height (1.0 = full)
        FILL_OFFSET_X     = 0,            -- Fill track horizontal offset (+ right, - left)
        FILL_OFFSET_Y     = 2,            -- Fill track vertical offset (+ down, - up)
        FILL_INSET_X      = 20,           -- Legacy fallback (if fill-region invalid)
        FILL_INSET_Y      = 4,            -- Legacy fallback (if fill-region invalid)
        -- Positioning when Left Ornament is hidden (DIRECT offsets from BgMiddle center)
        NO_ORNAMENT_OFFSET_X = -423,      -- (- left, + right)
        NO_ORNAMENT_OFFSET_Y = 108,       -- (+ down, - up)
    },

    -- Cast Bar (centered above top/back bar)
    CAST = {
        BACKDROP_TEXTURE   = "CastBar.dds",
        FILL_TEXTURE       = "esoui/art/miscellaneous/progressbar_genericfill_tall.dds",
        SCALE              = 1.0,         -- Scale multiplier for Cast bar
        OFFSET_X           = -30,         -- X offset from center (- left, + right)
        OFFSET_Y           = 110,         -- Y offset from back bar top (+ down, closer to bar)
        INSTANT_DISPLAY_MS = 850,         -- Preview duration for instant skills (ms)
        WIDTH              = 300,         -- Width in pixels
        HEIGHT             = 275,         -- Height in pixels
        LABEL_OFFSET_X     = -3,          -- Text nudge (+ right)
        LABEL_OFFSET_Y     = 0,           -- Text nudge (+ down)
        TEXTURE_BOUNDS     = { left = 0, right = 1, top = 0, bottom = 1 },
        FILL_WIDTH_SCALE   = 0.59,        -- Fill width fraction (1.0 = full)
        FILL_HEIGHT_SCALE  = 0.10,        -- Fill height fraction (1.0 = full)
        FILL_OFFSET_X      = 10,          -- Fill track (+ right, - left)
        FILL_OFFSET_Y      = 0,           -- Fill track (+ down, - up)
        FILL_INSET_X       = 45,          -- Legacy fallback
        FILL_INSET_Y       = 59,          -- Legacy fallback
    },

    -- Mount Stamina Bar (under right ornament when mounted)
    MOUNT = {
        BACKDROP_TEXTURE   = "MountBar.dds",
        FILL_TEXTURE       = "esoui/art/miscellaneous/progressbar_genericfill_tall.dds",
        SCALE              = 1.0,         -- Scale multiplier for mount bar
        OFFSET_X           = 0,           -- X offset from center (+ right, - left)
        OFFSET_Y           = -85,         -- Y offset from ornament bottom (- up, + down)
        WIDTH              = 220,         -- Width in pixels
        HEIGHT             = 185,         -- Height in pixels
        LABEL_OFFSET_X     = 0,           -- Text nudge (+ right)
        LABEL_OFFSET_Y     = 1,           -- Text nudge (+ down)
        TEXTURE_BOUNDS     = { left = 0, right = 1, top = 0, bottom = 1 },
        FILL_WIDTH_SCALE   = 0.55,        -- Fill width fraction (1.0 = full)
        FILL_HEIGHT_SCALE  = 0.15,        -- Fill height fraction (1.0 = full)
        FILL_OFFSET_X      = 0,           -- Fill track (+ right, - left)
        FILL_OFFSET_Y      = 0,           -- Fill track (+ down, - up)
        FILL_INSET_X       = 45,          -- Legacy fallback
        FILL_INSET_Y       = 59,          -- Legacy fallback
        -- Positioning when Right Ornament is hidden (DIRECT offsets from BgMiddle center)
        NO_ORNAMENT_OFFSET_X = 424,       -- (+ right, - left)
        NO_ORNAMENT_OFFSET_Y = 110,       -- (+ down, - up)
    },
}

-- Build computed fill regions from the nested config
local BARS = BETTERUI.ResourceOrbFrames.CONST.BARS
BARS.XP.FILL_REGION = BuildBarFillRegionFromBox(
    BARS.XP.WIDTH, BARS.XP.HEIGHT,
    BARS.XP.FILL_WIDTH_SCALE, BARS.XP.FILL_HEIGHT_SCALE,
    BARS.XP.FILL_OFFSET_X, BARS.XP.FILL_OFFSET_Y
)
BARS.CAST.FILL_REGION = BuildBarFillRegionFromBox(
    BARS.CAST.WIDTH, BARS.CAST.HEIGHT,
    BARS.CAST.FILL_WIDTH_SCALE, BARS.CAST.FILL_HEIGHT_SCALE,
    BARS.CAST.FILL_OFFSET_X, BARS.CAST.FILL_OFFSET_Y
)
BARS.MOUNT.FILL_REGION = BuildBarFillRegionFromBox(
    BARS.MOUNT.WIDTH, BARS.MOUNT.HEIGHT,
    BARS.MOUNT.FILL_WIDTH_SCALE, BARS.MOUNT.FILL_HEIGHT_SCALE,
    BARS.MOUNT.FILL_OFFSET_X, BARS.MOUNT.FILL_OFFSET_Y
)

-- DEBUG FLAGS

-- Shield debug is now managed via BETTERUI.CIM.FeatureFlags (SHIELD_DEBUG)
-- and BETTERUI.CIM.Debug.FLAGS.SHIELD_OVERLAY. See DeveloperDebug.lua.
