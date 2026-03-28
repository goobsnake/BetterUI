--[[
File: tools/tests/test_writ_patterns.lua
Purpose: Unit tests for writ pattern matching in WritUnit/Constants.lua.
         Tests run standalone with a Lua interpreter (no ESO environment).
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

CRAFTING_TYPE_BLACKSMITHING = 1
CRAFTING_TYPE_CLOTHIER = 2
CRAFTING_TYPE_WOODWORKING = 6
CRAFTING_TYPE_ENCHANTING = 3
CRAFTING_TYPE_PROVISIONING = 4
CRAFTING_TYPE_ALCHEMY = 5
CRAFTING_TYPE_JEWELRYCRAFTING = 7

BETTERUI = { Writs = {} }

-- Mock language CVar
local mockLanguage = "en"
function GetCVar(name)
    if name == "language.2" then return mockLanguage end
    return nil
end

-- ============================================================================
-- LOAD CONSTANTS UNDER TEST (replicated from WritUnit/Constants.lua)
-- ============================================================================

BETTERUI.Writs.CONST = {
    COLORS = {
        COMPLETE = "00FF00",
        INCOMPLETE = "CCCCCC",
    },
    PATTERNS_LOCALIZED = {
        ["en"] = {
            { pattern = "blacksmith", craftType = CRAFTING_TYPE_BLACKSMITHING },
            { pattern = "cloth",      craftType = CRAFTING_TYPE_CLOTHIER },
            { pattern = "woodwork",   craftType = CRAFTING_TYPE_WOODWORKING },
            { pattern = "enchant",    craftType = CRAFTING_TYPE_ENCHANTING },
            { pattern = "provision",  craftType = CRAFTING_TYPE_PROVISIONING },
            { pattern = "alchemist",  craftType = CRAFTING_TYPE_ALCHEMY },
            { pattern = "jewelry",    craftType = CRAFTING_TYPE_JEWELRYCRAFTING },
            { pattern = "witches",    craftType = CRAFTING_TYPE_PROVISIONING },
        },
        ["de"] = {
            { pattern = "schmied",    craftType = CRAFTING_TYPE_BLACKSMITHING },
            { pattern = "schneider",  craftType = CRAFTING_TYPE_CLOTHIER },
            { pattern = "schreiner",  craftType = CRAFTING_TYPE_WOODWORKING },
            { pattern = "verzauber",  craftType = CRAFTING_TYPE_ENCHANTING },
            { pattern = "versorger",  craftType = CRAFTING_TYPE_PROVISIONING },
            { pattern = "alchemist",  craftType = CRAFTING_TYPE_ALCHEMY },
            { pattern = "schmuck",    craftType = CRAFTING_TYPE_JEWELRYCRAFTING },
        },
        ["fr"] = {
            { pattern = "forgeron",   craftType = CRAFTING_TYPE_BLACKSMITHING },
            { pattern = "couturi",    craftType = CRAFTING_TYPE_CLOTHIER },
            { pattern = "travail du bois", craftType = CRAFTING_TYPE_WOODWORKING },
            { pattern = "enchant",    craftType = CRAFTING_TYPE_ENCHANTING },
            { pattern = "cuisine",    craftType = CRAFTING_TYPE_PROVISIONING },
            { pattern = "alchimiste", craftType = CRAFTING_TYPE_ALCHEMY },
            { pattern = "joaillerie", craftType = CRAFTING_TYPE_JEWELRYCRAFTING },
        },
    },
    PATTERNS = {
        { pattern = "blacksmith", craftType = CRAFTING_TYPE_BLACKSMITHING },
        { pattern = "cloth",      craftType = CRAFTING_TYPE_CLOTHIER },
        { pattern = "woodwork",   craftType = CRAFTING_TYPE_WOODWORKING },
        { pattern = "enchant",    craftType = CRAFTING_TYPE_ENCHANTING },
        { pattern = "provision",  craftType = CRAFTING_TYPE_PROVISIONING },
        { pattern = "alchemist",  craftType = CRAFTING_TYPE_ALCHEMY },
        { pattern = "jewelry",    craftType = CRAFTING_TYPE_JEWELRYCRAFTING },
        { pattern = "witches",    craftType = CRAFTING_TYPE_PROVISIONING },
    },
}

function BETTERUI.Writs.CONST.GetLocalizedPatterns()
    local lang = GetCVar("language.2") or "en"
    return BETTERUI.Writs.CONST.PATTERNS_LOCALIZED[lang] or BETTERUI.Writs.CONST.PATTERNS_LOCALIZED["en"]
end

-- ============================================================================
-- TEST INFRASTRUCTURE
-- ============================================================================

local passed, failed = 0, 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s — expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, label)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s — expected true, got %s", label, tostring(value)))
    end
end

-- ============================================================================
-- TESTS: GetLocalizedPatterns
-- ============================================================================

print("[GetLocalizedPatterns]")

-- English patterns
mockLanguage = "en"
do
    local patterns = BETTERUI.Writs.CONST.GetLocalizedPatterns()
    assert_eq(#patterns, 8, "en: 8 patterns")
    assert_eq(patterns[1].pattern, "blacksmith", "en: first pattern is blacksmith")
    assert_eq(patterns[1].craftType, CRAFTING_TYPE_BLACKSMITHING, "en: blacksmith craftType")
    assert_eq(patterns[7].pattern, "jewelry", "en: jewelry pattern exists")
    assert_eq(patterns[8].pattern, "witches", "en: witches festival pattern")
    assert_eq(patterns[8].craftType, CRAFTING_TYPE_PROVISIONING, "en: witches maps to provisioning")
end

-- German patterns
mockLanguage = "de"
do
    local patterns = BETTERUI.Writs.CONST.GetLocalizedPatterns()
    assert_eq(#patterns, 7, "de: 7 patterns")
    assert_eq(patterns[1].pattern, "schmied", "de: first pattern is schmied")
    assert_eq(patterns[1].craftType, CRAFTING_TYPE_BLACKSMITHING, "de: schmied craftType")
    assert_eq(patterns[7].pattern, "schmuck", "de: schmuck (jewelry) pattern")
end

-- French patterns
mockLanguage = "fr"
do
    local patterns = BETTERUI.Writs.CONST.GetLocalizedPatterns()
    assert_eq(#patterns, 7, "fr: 7 patterns")
    assert_eq(patterns[1].pattern, "forgeron", "fr: first pattern is forgeron")
    assert_eq(patterns[3].pattern, "travail du bois", "fr: woodwork is multi-word")
end

-- Unknown language falls back to English
mockLanguage = "jp"
do
    local patterns = BETTERUI.Writs.CONST.GetLocalizedPatterns()
    assert_eq(#patterns, 8, "jp: falls back to en (8 patterns)")
    assert_eq(patterns[1].pattern, "blacksmith", "jp: fallback has blacksmith")
end

-- Nil language falls back to English
mockLanguage = nil
do
    local patterns = BETTERUI.Writs.CONST.GetLocalizedPatterns()
    assert_eq(#patterns, 8, "nil lang: falls back to en")
end

-- ============================================================================
-- TESTS: Pattern matching simulation
-- ============================================================================

print("[Pattern matching]")

-- Simulate the writ quest name matching algorithm (last match wins)
local function matchQuestName(questName, patterns)
    local matched = nil
    for _, entry in ipairs(patterns) do
        if string.find(string.lower(questName), entry.pattern, 1, true) then
            matched = entry.craftType
        end
    end
    return matched
end

mockLanguage = "en"
local enPatterns = BETTERUI.Writs.CONST.GetLocalizedPatterns()
assert_eq(matchQuestName("Blacksmith Writ", enPatterns), CRAFTING_TYPE_BLACKSMITHING, "match: Blacksmith Writ")
assert_eq(matchQuestName("Clothier Certification", enPatterns), CRAFTING_TYPE_CLOTHIER, "match: Clothier Certification")
assert_eq(matchQuestName("Enchanting Daily", enPatterns), CRAFTING_TYPE_ENCHANTING, "match: Enchanting Daily")
assert_eq(matchQuestName("Jewelry Crafting Writ", enPatterns), CRAFTING_TYPE_JEWELRYCRAFTING, "match: Jewelry Crafting Writ")
assert_eq(matchQuestName("Witches Festival Recipe", enPatterns), CRAFTING_TYPE_PROVISIONING, "match: Witches Festival")
assert_eq(matchQuestName("Random Unrelated Quest", enPatterns), nil, "match: no match returns nil")

-- ============================================================================
-- TESTS: Constants structure
-- ============================================================================

print("[Constants structure]")
assert_eq(BETTERUI.Writs.CONST.COLORS.COMPLETE, "00FF00", "COMPLETE color is green")
assert_eq(BETTERUI.Writs.CONST.COLORS.INCOMPLETE, "CCCCCC", "INCOMPLETE color is grey")
assert_eq(#BETTERUI.Writs.CONST.PATTERNS, 8, "legacy PATTERNS has 8 entries")
assert_true(BETTERUI.Writs.CONST.PATTERNS_LOCALIZED["en"] ~= nil, "en locale exists")
assert_true(BETTERUI.Writs.CONST.PATTERNS_LOCALIZED["de"] ~= nil, "de locale exists")
assert_true(BETTERUI.Writs.CONST.PATTERNS_LOCALIZED["fr"] ~= nil, "fr locale exists")

-- ============================================================================
-- RESULTS
-- ============================================================================

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
