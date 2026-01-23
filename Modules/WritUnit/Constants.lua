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
    -- LOCALIZATION: These patterns are English-only. For other languages, the quest
    -- names may differ. Consider adding localized pattern sets keyed by GetCVar("language.2")
    -- if non-English support is needed.
    --
    -- Order matters: patterns are checked in order, last match wins.
    -------------------------------------------------------------------------------------------------
    PATTERNS = {
        {pattern = "blacksmith", craftType = CRAFTING_TYPE_BLACKSMITHING},
        {pattern = "cloth",      craftType = CRAFTING_TYPE_CLOTHIER},
        {pattern = "woodwork",   craftType = CRAFTING_TYPE_WOODWORKING},
        {pattern = "enchant",    craftType = CRAFTING_TYPE_ENCHANTING},
        {pattern = "provision",  craftType = CRAFTING_TYPE_PROVISIONING},
        {pattern = "alchemist",  craftType = CRAFTING_TYPE_ALCHEMY},
        {pattern = "jewelry",    craftType = CRAFTING_TYPE_JEWELRYCRAFTING},
        {pattern = "witches",    craftType = CRAFTING_TYPE_PROVISIONING}, -- Festival event
    }
}
