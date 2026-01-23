--[[
File: Modules/WritUnit/Constants.lua
Purpose: Constants for the Daily Writ Module.
         Includes pattern matching definitions for writ quest detection.
Last Modified: 2026-01-22
]]

if not BETTERUI.Writs then BETTERUI.Writs = {} end

BETTERUI.Writs.CONST = {
    COLORS = {
        COMPLETE = "00FF00",  -- Green
        INCOMPLETE = "CCCCCC" -- Grey
    },
    
    -------------------------------------------------------------------------------------------------
    -- WRIT DETECTION PATTERNS
    -------------------------------------------------------------------------------------------------
    -- Patterns used to match quest names to crafting types.
    -- Each entry: {pattern = "substring", craftType = CRAFTING_TYPE_XXX}
    --
    -- LOCALIZATION: Patterns are now keyed by language code ("en", "de", "fr").
    -- Use GetAllPatterns() or GetLocalizedPatterns() to retrieve.
    --
    -- Order matters: patterns are checked in order, last match wins.
    -------------------------------------------------------------------------------------------------
    PATTERNS_LOCALIZED = {
        ["en"] = {
            {pattern = "blacksmith", craftType = CRAFTING_TYPE_BLACKSMITHING},
            {pattern = "cloth",      craftType = CRAFTING_TYPE_CLOTHIER},
            {pattern = "woodwork",   craftType = CRAFTING_TYPE_WOODWORKING},
            {pattern = "enchant",    craftType = CRAFTING_TYPE_ENCHANTING},
            {pattern = "provision",  craftType = CRAFTING_TYPE_PROVISIONING},
            {pattern = "alchemist",  craftType = CRAFTING_TYPE_ALCHEMY},
            {pattern = "jewelry",    craftType = CRAFTING_TYPE_JEWELRYCRAFTING},
            {pattern = "witches",    craftType = CRAFTING_TYPE_PROVISIONING}, -- Festival event
        },
        ["de"] = {
            {pattern = "schmied",    craftType = CRAFTING_TYPE_BLACKSMITHING},
            {pattern = "schneider",  craftType = CRAFTING_TYPE_CLOTHIER},
            {pattern = "schreiner",  craftType = CRAFTING_TYPE_WOODWORKING},
            {pattern = "verzauber",  craftType = CRAFTING_TYPE_ENCHANTING},
            {pattern = "versorger",  craftType = CRAFTING_TYPE_PROVISIONING},
            {pattern = "alchemist",  craftType = CRAFTING_TYPE_ALCHEMY},
            {pattern = "schmuck",    craftType = CRAFTING_TYPE_JEWELRYCRAFTING},
        },
        ["fr"] = {
            {pattern = "forgeron",   craftType = CRAFTING_TYPE_BLACKSMITHING},
            {pattern = "couturi",    craftType = CRAFTING_TYPE_CLOTHIER},
            {pattern = "travail du bois", craftType = CRAFTING_TYPE_WOODWORKING},
            {pattern = "enchant",    craftType = CRAFTING_TYPE_ENCHANTING},
            {pattern = "cuisine",    craftType = CRAFTING_TYPE_PROVISIONING},
            {pattern = "alchimiste", craftType = CRAFTING_TYPE_ALCHEMY},
            {pattern = "joaillerie", craftType = CRAFTING_TYPE_JEWELRYCRAFTING},
        }
    },

    -- Fallback for legacy calls (defaults to English)
    PATTERNS = {
        {pattern = "blacksmith", craftType = CRAFTING_TYPE_BLACKSMITHING},
        {pattern = "cloth",      craftType = CRAFTING_TYPE_CLOTHIER},
        {pattern = "woodwork",   craftType = CRAFTING_TYPE_WOODWORKING},
        {pattern = "enchant",    craftType = CRAFTING_TYPE_ENCHANTING},
        {pattern = "provision",  craftType = CRAFTING_TYPE_PROVISIONING},
        {pattern = "alchemist",  craftType = CRAFTING_TYPE_ALCHEMY},
        {pattern = "jewelry",    craftType = CRAFTING_TYPE_JEWELRYCRAFTING},
        {pattern = "witches",    craftType = CRAFTING_TYPE_PROVISIONING},
    }
}

--- Retrieves the pattern set for the current game client language.
--- @return table List of pattern objects
function BETTERUI.Writs.CONST.GetLocalizedPatterns()
    local lang = GetCVar("language.2") or "en"
    return BETTERUI.Writs.CONST.PATTERNS_LOCALIZED[lang] or BETTERUI.Writs.CONST.PATTERNS_LOCALIZED["en"]
end
