--[[
File: Modules/CIM/Core/Presentation/FontDefinitions.lua
Purpose: Shared font definitions and utility functions for inventory/banking modules.
         Provides centralized font arrays, defaults, and descriptor builders.
]]

-- SHARED FONT DEFINITIONS

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.Font then BETTERUI.CIM.Font = {} end

--[[
Table: BETTERUI.CIM.Font.CHOICES
Human-readable font names for LAM dropdown menus.
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
ESO font file paths corresponding to CHOICES.
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
Human-readable font style names for LAM dropdown menus.
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
ESO font style suffixes corresponding to STYLE_CHOICES.
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
Default font settings shared across modules.
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

--- Canonical Western-only font list lives in FontLocalization, which loads
--- after this file; resolve it lazily at call time instead of duplicating it.
local function GetWesternOnlyFonts()
    local localization = BETTERUI.CIM.Font and BETTERUI.CIM.Font.Localization
    return (localization and localization.WESTERN_ONLY_FONTS) or {}
end

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

-- UTILITY FUNCTIONS

---@param sizeValue number?
---@return integer
function BETTERUI.CIM.Font.GetSizeValue(sizeValue)
    return ClampFontSize(sizeValue, BETTERUI.CIM.Font.DEFAULTS.nameFontSize)
end

--- Normalizes shared module font sizes to the active slider bounds.
---@param m_options table
---@param defaults table?
---@return table m_options
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

--- Shared module initialization helper for defaults and font migrations.
---@param moduleKey string
---@param m_options table?
---@param defaults table?
---@param fallbackDefaults table?
---@param onBeforeFontMigration fun(opts: table, defs: table)?
---@return table m_options
function BETTERUI.CIM.InitModuleDefaults(moduleKey, m_options, defaults, fallbackDefaults, onBeforeFontMigration)
    if type(m_options) ~= "table" then
        m_options = {}
    end

    local defaultsApi = BETTERUI.Defaults
    if defaultsApi and type(defaultsApi.ApplyModuleDefaults) == "function" then
        m_options = defaultsApi.ApplyModuleDefaults(moduleKey, m_options)
    elseif type(fallbackDefaults) == "table" then
        d("[BetterUI] " .. tostring(moduleKey) .. ": ApplyModuleDefaults unavailable, using fallbacks")
        for key, value in pairs(fallbackDefaults) do
            if m_options[key] == nil then
                m_options[key] = value
            end
        end
    end

    local moduleDefaults = defaults or BETTERUI.CIM.Font.DEFAULTS
    m_options.nameFont = m_options.nameFont or moduleDefaults.nameFont
    m_options.nameFontSize = m_options.nameFontSize or moduleDefaults.nameFontSize
    m_options.nameFontStyle = m_options.nameFontStyle or moduleDefaults.nameFontStyle
    m_options.columnFont = m_options.columnFont or moduleDefaults.columnFont
    m_options.columnFontSize = m_options.columnFontSize or moduleDefaults.columnFontSize
    m_options.columnFontStyle = m_options.columnFontStyle or moduleDefaults.columnFontStyle

    if type(onBeforeFontMigration) == "function" then
        onBeforeFontMigration(m_options, moduleDefaults)
    end

    local currentLang = GetCVar("language.2") or "en"
    if currentLang ~= "en" then
        local westernOnlyFonts = GetWesternOnlyFonts()
        if m_options.nameFont and westernOnlyFonts[m_options.nameFont] then
            m_options.nameFont = "$(GAMEPAD_MEDIUM_FONT)"
        end
        if m_options.columnFont and westernOnlyFonts[m_options.columnFont] then
            m_options.columnFont = "$(GAMEPAD_MEDIUM_FONT)"
        end
    end

    BETTERUI.CIM.Font.NormalizeModuleFontSettings(m_options, moduleDefaults)
    return m_options
end

---@param fontPath string
---@param fontSize integer
---@param fontStyle string?
---@return string descriptor
function BETTERUI.CIM.Font.BuildDescriptor(fontPath, fontSize, fontStyle)
    if fontStyle and fontStyle ~= "" then
        return string.format("%s|%d|%s", fontPath, fontSize, fontStyle)
    else
        return string.format("%s|%d", fontPath, fontSize)
    end
end

---@param moduleName string
---@param fontType string
---@return string descriptor
function BETTERUI.CIM.Font.GetModuleFontDescriptor(moduleName, fontType)
    -- Hot path (called per list row via descriptor closures): use the live
    -- settings table instead of GetModuleSettings, which deep-clones the
    -- module table on every call. The returned table is read-only by convention.
    -- Fall back to the cloning accessor when SettingsAccessor has not loaded
    -- (standalone test harness).
    local getSettings = BETTERUI.GetModuleSettingsLive or BETTERUI.GetModuleSettings
    local settings = getSettings and getSettings(moduleName)
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

--- Creates bound font descriptor closures for a module.
---@param moduleName string
---@return {name: fun(): string, column: fun(): string}
function BETTERUI.CIM.Font.CreateModuleDescriptors(moduleName)
    return {
        name = function() return BETTERUI.CIM.Font.GetModuleFontDescriptor(moduleName, "name") end,
        column = function() return BETTERUI.CIM.Font.GetModuleFontDescriptor(moduleName, "column") end,
    }
end
