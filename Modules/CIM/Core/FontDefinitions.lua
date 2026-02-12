--[[
File: Modules/CIM/Core/FontDefinitions.lua
Purpose: Shared font definitions and utility functions for inventory/banking modules.
         Provides centralized font arrays, defaults, and descriptor builders.
Author: BetterUI Team
Last Modified: 2026-01-27
]]

-------------------------------------------------------------------------------------------------
-- SHARED FONT DEFINITIONS
-------------------------------------------------------------------------------------------------

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.Font then BETTERUI.CIM.Font = {} end

--[[
Table: BETTERUI.CIM.Font.CHOICES
Description: Human-readable font names for LAM dropdown menus.
Used By: Banking/Module.lua, Inventory/Settings/FontSettings.lua
]]
BETTERUI.CIM.Font.CHOICES = {
    "System Default (Localized)", -- Uses ESO's language-appropriate font
    "System Bold (Localized)",    -- Bold variant, localized
    "Antique (Localized)",        -- Stylized serif, localized for CJK
    "Handwritten (Localized)",    -- Handwritten style, localized for CJK
    "Stone Tablet (Localized)",   -- Carved stone style, localized for CJK
    "Univers 57",
    "Univers 67 (Bold)",
    "Futura Condensed Light",
    "Futura Condensed Medium",
    "Futura Condensed Bold",
    "Prose Antique",
    "Handwritten Bold",
    "Trajan Pro",
    "Skyrim Handwritten",
    "Consolas",
}

--[[
Table: BETTERUI.CIM.Font.VALUES
Description: ESO font file paths corresponding to CHOICES.
             The first entry uses $(GAMEPAD_MEDIUM_FONT) which ESO resolves to
             the correct font for each language (Chinese, Japanese, etc.).
Used By: Banking/Module.lua, Inventory/Settings/FontSettings.lua
]]
BETTERUI.CIM.Font.VALUES = {
    "$(GAMEPAD_MEDIUM_FONT)", -- ESO's localized medium font
    "$(BOLD_FONT)",           -- ESO's localized bold font
    "$(ANTIQUE_FONT)",        -- Resolves to ProseAntique (Western) or KafuPenji (JP) or MYoyo (ZH)
    "$(HANDWRITTEN_FONT)",    -- Resolves to Handwritten_Bold (Western) or localized equivalent
    "$(STONE_TABLET_FONT)",   -- Resolves to TrajanPro (Western) or localized equivalent
    "EsoUI/Common/Fonts/Univers57.otf",
    "EsoUI/Common/Fonts/Univers67.otf",
    "EsoUI/Common/Fonts/FTN47.otf",
    "EsoUI/Common/Fonts/FTN57.otf",
    "EsoUI/Common/Fonts/FTN87.otf",
    "EsoUI/Common/Fonts/ProseAntiquePSMT.otf",
    "EsoUI/Common/Fonts/Handwritten_Bold.otf",
    "EsoUI/Common/Fonts/TrajanPro-Regular.otf",
    "EsoUI/Common/Fonts/Skyrim_Handwritten.otf",
    "EsoUI/Common/Fonts/consola.otf",
}

--[[
Table: BETTERUI.CIM.Font.STYLE_CHOICES
Description: Human-readable font style names for LAM dropdown menus.
Used By: Banking/Module.lua, Inventory/Settings/FontSettings.lua
]]
BETTERUI.CIM.Font.STYLE_CHOICES = {
    "Normal",
    "Outline",
    "Thick Outline",
    "Shadow",
    "Soft Shadow (Thick)",
    "Soft Shadow (Thin)",
}

--[[
Table: BETTERUI.CIM.Font.STYLE_VALUES
Description: ESO font style suffixes corresponding to STYLE_CHOICES.
Used By: Banking/Module.lua, Inventory/Settings/FontSettings.lua
]]
BETTERUI.CIM.Font.STYLE_VALUES = {
    "",                  -- Normal (no style suffix)
    "outline",           -- Outline
    "thick-outline",     -- Thick Outline
    "shadow",            -- Shadow
    "soft-shadow-thick", -- Soft Shadow (Thick)
    "soft-shadow-thin",  -- Soft Shadow (Thin)
}

--[[
Table: BETTERUI.CIM.Font.DEFAULTS
Description: Default font settings shared across modules.
             Modules can override specific values in their own settings.
Used By: Banking/Module.lua, Inventory/Settings/FontSettings.lua
]]
BETTERUI.CIM.Font.DEFAULTS = {
    nameFont = "$(GAMEPAD_MEDIUM_FONT)", -- Uses ESO's localized font for CJK support
    nameFontSize = 24,
    nameFontStyle = "",
    columnFont = "$(GAMEPAD_MEDIUM_FONT)", -- Uses ESO's localized font for CJK support
    columnFontSize = 24,
    columnFontStyle = "",
}

BETTERUI.CIM.Font.SIZE_MIN = 12
BETTERUI.CIM.Font.SIZE_MAX = 48

local function ClampFontSize(sizeValue, fallback)
    local numeric = tonumber(sizeValue)
    if not numeric then
        return fallback
    end

    local rounded = math.floor(numeric + 0.5)
    local minValue = BETTERUI.CIM.Font.SIZE_MIN
    local maxValue = BETTERUI.CIM.Font.SIZE_MAX

    if rounded < minValue then
        return minValue
    end
    if rounded > maxValue then
        return maxValue
    end
    return rounded
end

-------------------------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.CIM.Font.GetSizeValue
Description: Converts a font size setting to a numeric pixel value.
Rationale: Handles migration from legacy string values ("Small", "Large") to numbers.
Mechanism: Returns the number if already numeric, otherwise returns default 24.
param: sizeValue (string|number) - The size setting value.
return: number - The font size in pixels.
]]
--- @param sizeValue string|number The size setting value
--- @return number fontSize The font size in pixels
function BETTERUI.CIM.Font.GetSizeValue(sizeValue)
    return ClampFontSize(sizeValue, BETTERUI.CIM.Font.DEFAULTS.nameFontSize)
end

--- Normalizes shared module font sizes to the active slider bounds.
--- @param m_options table Module settings table
--- @param defaults table|nil Optional module defaults table
--- @return table m_options The normalized settings table
function BETTERUI.CIM.Font.NormalizeModuleFontSettings(m_options, defaults)
    if type(m_options) ~= "table" then
        return m_options
    end

    local moduleDefaults = defaults or BETTERUI.CIM.Font.DEFAULTS
    local defaultNameSize = BETTERUI.CIM.Font.GetSizeValue(moduleDefaults and moduleDefaults.nameFontSize)
    local defaultColumnSize = BETTERUI.CIM.Font.GetSizeValue(moduleDefaults and moduleDefaults.columnFontSize)

    m_options.nameFontSize = ClampFontSize(m_options.nameFontSize, defaultNameSize)
    m_options.columnFontSize = ClampFontSize(m_options.columnFontSize, defaultColumnSize)

    return m_options
end

--[[
Function: BETTERUI.CIM.Font.BuildDescriptor
Description: Builds an ESO font descriptor string from path, size, and style.
Rationale: Consolidates the font descriptor creation logic used by multiple modules.
param: fontPath (string) - The font file path.
param: fontSize (number) - The font size in pixels.
param: fontStyle (string|nil) - The font style suffix (optional).
return: string - ESO font descriptor (path|size|style).
]]
--- @param fontPath string The font file path
--- @param fontSize number The font size in pixels
--- @param fontStyle string|nil The font style suffix (optional)
--- @return string descriptor ESO font descriptor (path|size|style)
function BETTERUI.CIM.Font.BuildDescriptor(fontPath, fontSize, fontStyle)
    if fontStyle and fontStyle ~= "" then
        return string.format("%s|%d|%s", fontPath, fontSize, fontStyle)
    else
        return string.format("%s|%d", fontPath, fontSize)
    end
end

--[[
Function: BETTERUI.CIM.Font.GetModuleFontDescriptor
Description: Gets a font descriptor for a specific module using its settings.
Rationale: Generic helper that can be used by any module that stores font settings.
param: moduleName (string) - The module key in BETTERUI.Settings.Modules (e.g., "Banking", "Inventory").
param: fontType (string) - "name" or "column" to specify which font setting to retrieve.
return: string - ESO font descriptor (path|size|style).
]]
--- @param moduleName string The module key in BETTERUI.Settings.Modules
--- @param fontType "name"|"column" Which font setting to retrieve
--- @return string descriptor ESO font descriptor (path|size|style)
function BETTERUI.CIM.Font.GetModuleFontDescriptor(moduleName, fontType)
    local settings = BETTERUI.Settings.Modules[moduleName]
    local defaults = BETTERUI.CIM.Font.DEFAULTS

    local fontPath, fontSize, fontStyle
    if fontType == "name" then
        fontPath = (settings and settings.nameFont) or defaults.nameFont
        fontSize = BETTERUI.CIM.Font.GetSizeValue((settings and settings.nameFontSize) or defaults.nameFontSize)
        fontStyle = (settings and settings.nameFontStyle) or defaults.nameFontStyle
    else -- "column"
        fontPath = (settings and settings.columnFont) or defaults.columnFont
        fontSize = BETTERUI.CIM.Font.GetSizeValue((settings and settings.columnFontSize) or defaults.columnFontSize)
        fontStyle = (settings and settings.columnFontStyle) or defaults.columnFontStyle
    end

    return BETTERUI.CIM.Font.BuildDescriptor(fontPath, fontSize, fontStyle)
end
