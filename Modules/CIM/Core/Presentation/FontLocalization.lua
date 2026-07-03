--[[
File: Modules/CIM/Core/Presentation/FontLocalization.lua
Purpose: Font localization utility for language-aware font handling.
         Provides detection of user language, font compatibility checks,
         and centralized Western-only font list for migration logic.
]]

-- FONT LOCALIZATION UTILITIES

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

---@return string
function Localization.GetCurrentLanguage()
    return GetCVar("language.2") or "en"
end

---@return string
function Localization.GetCurrentLanguageGroup()
    local lang = Localization.GetCurrentLanguage()
    return Localization.LANGUAGE_GROUPS[lang] or "western"
end

---@return boolean
function Localization.IsEnglish()
    return Localization.GetCurrentLanguage() == "en"
end

---@param fontPath string?
---@return boolean
function Localization.IsFontWesternOnly(fontPath)
    return Localization.WESTERN_ONLY_FONTS[fontPath] == true
end

---@param fontPath string?
---@return boolean
function Localization.IsFontLocalizedForLanguage(fontPath)
    -- Font variables (e.g., $(GAMEPAD_MEDIUM_FONT)) are always localized
    if fontPath and string.sub(fontPath, 1, 2) == "$(" then
        return true
    end

    -- Western-script clients (English/German/French/Spanish) can use the
    -- bundled Western-only font files; only CJK/Cyrillic clients need fallback.
    if Localization.GetCurrentLanguageGroup() == "western" then
        return true
    end

    -- For non-Western users, Western-only fonts are NOT localized.
    return not Localization.IsFontWesternOnly(fontPath)
end

---@param fontPath string?
---@return string?
function Localization.GetFontCompatibilityWarning(fontPath)
    if Localization.GetCurrentLanguageGroup() == "western" then
        return nil
    end

    if Localization.IsFontWesternOnly(fontPath) then
        local langGroup = Localization.GetCurrentLanguageGroup()
        if langGroup == "cjk" then
            return GetString(rawget(_G, "SI_BETTERUI_FONT_WARNING_CJK")) or
                "This font may not display Chinese/Japanese characters correctly."
        elseif langGroup == "cyrillic" then
            return GetString(rawget(_G, "SI_BETTERUI_FONT_WARNING_CYRILLIC")) or
                "This font may not display Russian characters correctly."
        end
    end

    return nil
end

---@param sourceChoices string[]
---@param sourceValues string[]
---@return string[]
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

---@param sourceChoices string[]
---@param sourceValues string[]
---@return string[]
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

---@param sourceChoices string[]
---@param sourceValues string[]
---@return string[] filteredChoices
---@return string[] filteredValues
function Localization.GetFilteredFontArrays(sourceChoices, sourceValues)
    return Localization.GetFilteredFontChoices(sourceChoices, sourceValues),
        Localization.GetFilteredFontValues(sourceChoices, sourceValues)
end
