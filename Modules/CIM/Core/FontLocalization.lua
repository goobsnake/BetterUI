--[[
File: Modules/CIM/Core/FontLocalization.lua
Purpose: Font localization utility for language-aware font handling.
         Provides detection of user language, font compatibility checks,
         and centralized Western-only font list for migration logic.
Author: BetterUI Team
Last Modified: 2026-02-05
]]

-------------------------------------------------------------------------------------------------
-- FONT LOCALIZATION UTILITIES
-------------------------------------------------------------------------------------------------

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.Font then BETTERUI.CIM.Font = {} end
if not BETTERUI.CIM.Font.Localization then BETTERUI.CIM.Font.Localization = {} end

local Localization = BETTERUI.CIM.Font.Localization

--[[
Constant: WESTERN_ONLY_FONTS
Description: Table of font paths that only support Western/Latin characters.
             These fonts will cause glyph rendering failures for CJK and Russian text.
Used By: InitModule migration logic in Banking, Inventory, Nameplates
]]
Localization.WESTERN_ONLY_FONTS = {
    ["EsoUI/Common/Fonts/FTN57.otf"] = true,
    ["EsoUI/Common/Fonts/FTN47.otf"] = true,
    ["EsoUI/Common/Fonts/FTN87.otf"] = true,
    ["EsoUI/Common/Fonts/Univers57.otf"] = true,
    ["EsoUI/Common/Fonts/Univers67.otf"] = true,
    ["EsoUI/Common/Fonts/ProseAntiquePSMT.otf"] = true,
    ["EsoUI/Common/Fonts/Handwritten_Bold.otf"] = true,
    ["EsoUI/Common/Fonts/TrajanPro-Regular.otf"] = true,
    ["EsoUI/Common/Fonts/Skyrim_Handwritten.otf"] = true,
    ["EsoUI/Common/Fonts/consola.otf"] = true,
}

--[[
Constant: LANGUAGE_GROUPS
Description: Mapping of language codes to their script/font requirements.
Used By: GetCurrentLanguageGroup, IsFontLocalizedForLanguage
]]
Localization.LANGUAGE_GROUPS = {
    en = "western",
    de = "western",
    es = "western",
    fr = "western",
    ru = "cyrillic",
    jp = "cjk",
    zh = "cjk",
}

--[[
Function: Localization.GetCurrentLanguage
Description: Returns the user's current game language code.
Rationale: ESO stores language preference in CVar "language.2".
return: string - Language code (e.g., "en", "de", "jp", "zh", "ru")
]]
--- @return string languageCode The current game language code
function Localization.GetCurrentLanguage()
    return GetCVar("language.2") or "en"
end

--[[
Function: Localization.GetCurrentLanguageGroup
Description: Returns the script group for the current language.
Rationale: Groups languages by their glyph requirements for font selection.
return: string - "western", "cyrillic", or "cjk"
]]
--- @return "western"|"cyrillic"|"cjk" group The script group for the current language
function Localization.GetCurrentLanguageGroup()
    local lang = Localization.GetCurrentLanguage()
    return Localization.LANGUAGE_GROUPS[lang] or "western"
end

--[[
Function: Localization.IsEnglish
Description: Returns whether the current language is English.
Rationale: Used to skip migration for English users who have full font compatibility.
return: boolean - True if current language is English
]]
--- @return boolean isEnglish True if current language is English
function Localization.IsEnglish()
    return Localization.GetCurrentLanguage() == "en"
end

--[[
Function: Localization.IsFontWesternOnly
Description: Checks if a font path is Western-only (lacks CJK/Cyrillic support).
Rationale: Used by migration logic to determine if a font needs upgrading.
param: fontPath (string) - The font file path to check.
return: boolean - True if the font only supports Western characters.
]]
--- @param fontPath string The font file path to check
--- @return boolean isWesternOnly True if font only supports Western characters
function Localization.IsFontWesternOnly(fontPath)
    return Localization.WESTERN_ONLY_FONTS[fontPath] == true
end

--[[
Function: Localization.IsFontLocalizedForLanguage
Description: Checks if a font path is compatible with the user's current language.
Rationale: Fonts using $(...) variables or not in WESTERN_ONLY_FONTS are considered safe.
param: fontPath (string) - The font file path to check.
return: boolean - True if the font is compatible with the current language.
]]
--- @param fontPath string The font file path to check
--- @return boolean isLocalized True if font is compatible with current language
function Localization.IsFontLocalizedForLanguage(fontPath)
    -- Font variables (e.g., $(GAMEPAD_MEDIUM_FONT)) are always localized
    if fontPath and string.sub(fontPath, 1, 2) == "$(" then
        return true
    end

    -- For English users, all fonts are compatible
    if Localization.IsEnglish() then
        return true
    end

    -- For non-English users, Western-only fonts are NOT localized
    return not Localization.IsFontWesternOnly(fontPath)
end

--[[
Function: Localization.GetLocalizedFontDefault
Description: Returns the appropriate localized font variable for a context.
Rationale: Different UI contexts may prefer different font weights.
param: context (string) - "medium" for lists, "bold" for nameplates/headers.
return: string - The localized font variable.
]]
--- @param context "medium"|"bold" The font weight context
--- @return string fontVariable The localized font variable
function Localization.GetLocalizedFontDefault(context)
    if context == "bold" then
        return "$(BOLD_FONT)"
    else
        return "$(GAMEPAD_MEDIUM_FONT)"
    end
end

--[[
Function: Localization.GetFontCompatibilityWarning
Description: Returns a warning string if host font is not compatible with current language.
Rationale: Used in settings tooltips to warn users about incompatible font choices.
param: fontPath (string) - The font file path to check.
return: string|nil - Warning message or nil if font is compatible.
]]
--- @param fontPath string The font file path to check
--- @return string|nil warning Warning message or nil if compatible
function Localization.GetFontCompatibilityWarning(fontPath)
    if Localization.IsEnglish() then
        return nil
    end

    if Localization.IsFontWesternOnly(fontPath) then
        local langGroup = Localization.GetCurrentLanguageGroup()
        if langGroup == "cjk" then
            return GetString(SI_BETTERUI_FONT_WARNING_CJK) or
                "This font may not display Chinese/Japanese characters correctly."
        elseif langGroup == "cyrillic" then
            return GetString(SI_BETTERUI_FONT_WARNING_CYRILLIC) or
                "This font may not display Russian characters correctly."
        end
    end

    return nil
end

--[[
Function: Localization.GetFilteredFontChoices
Description: Returns font choice names filtered for the current language.
Rationale: Non-English users should only see fonts compatible with their language.
param: sourceChoices (table) - Array of font choice display names.
param: sourceValues (table) - Array of font path values (parallel to sourceChoices).
return: table - Filtered array of font choice names.
]]
--- @param sourceChoices table Array of font choice display names
--- @param sourceValues table Array of font path values
--- @return table filteredChoices Filtered array of font choice names
function Localization.GetFilteredFontChoices(sourceChoices, sourceValues)
    -- English users get all fonts
    if Localization.IsEnglish() then
        return sourceChoices
    end

    -- Non-English users: filter out Western-only fonts
    local filtered = {}
    for i, choice in ipairs(sourceChoices) do
        local fontPath = sourceValues[i]
        if Localization.IsFontLocalizedForLanguage(fontPath) then
            table.insert(filtered, choice)
        end
    end
    return filtered
end

--[[
Function: Localization.GetFilteredFontValues
Description: Returns font path values filtered for the current language.
Rationale: Non-English users should only see fonts compatible with their language.
param: sourceChoices (table) - Array of font choice display names.
param: sourceValues (table) - Array of font path values (parallel to sourceChoices).
return: table - Filtered array of font path values.
]]
--- @param sourceChoices table Array of font choice display names
--- @param sourceValues table Array of font path values
--- @return table filteredValues Filtered array of font path values
function Localization.GetFilteredFontValues(sourceChoices, sourceValues)
    -- English users get all fonts
    if Localization.IsEnglish() then
        return sourceValues
    end

    -- Non-English users: filter out Western-only fonts
    local filtered = {}
    for i, fontPath in ipairs(sourceValues) do
        if Localization.IsFontLocalizedForLanguage(fontPath) then
            table.insert(filtered, fontPath)
        end
    end
    return filtered
end

--[[
Function: Localization.GetFilteredFontArrays
Description: Returns both filtered choices and values for current language.
Rationale: Convenience function for settings panels that need both arrays.
param: sourceChoices (table) - Array of font choice display names.
param: sourceValues (table) - Array of font path values.
return: table, table - Filtered choices and values arrays.
]]
--- @param sourceChoices table Array of font choice display names
--- @param sourceValues table Array of font path values
--- @return table filteredChoices, table filteredValues
function Localization.GetFilteredFontArrays(sourceChoices, sourceValues)
    return Localization.GetFilteredFontChoices(sourceChoices, sourceValues),
        Localization.GetFilteredFontValues(sourceChoices, sourceValues)
end
