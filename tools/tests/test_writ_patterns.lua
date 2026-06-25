--[[
File: tools/tests/test_writ_patterns.lua
Purpose: Regression tests for the Writs constants, quest parsing, and module lifecycle.

Usage:
  lua tools/tests/test_writ_patterns.lua
]]

CRAFTING_TYPE_BLACKSMITHING = 1
CRAFTING_TYPE_CLOTHIER = 2
CRAFTING_TYPE_ENCHANTING = 3
CRAFTING_TYPE_PROVISIONING = 4
CRAFTING_TYPE_ALCHEMY = 5
CRAFTING_TYPE_WOODWORKING = 6
CRAFTING_TYPE_JEWELRYCRAFTING = 7

QUEST_TYPE_CRAFTING = 11
EVENT_CRAFTING_STATION_INTERACT = 101
EVENT_END_CRAFTING_STATION_INTERACT = 102
EVENT_CRAFT_COMPLETED = 103
MAX_JOURNAL_QUESTS = 10

local mockLanguage = "en"
local moduleEnabled = true
local questJournal = {}
local safeExecuteContexts = {}
local safeExecuteFailureContext = nil
local registeredEvents = {}

local passed, failed = 0, 0

local writNameText = nil
local writDescText = nil
local writPanelHidden = nil

local writNameLabel = {
    SetText = function(_, value)
        writNameText = value
    end,
}

local writDescLabel = {
    SetText = function(_, value)
        writDescText = value
    end,
}

local writPanel = {
    SetHidden = function(_, value)
        writPanelHidden = value
    end,
}

BETTERUI_WritsPanelSlotContainerExtractionSlotWritName = writNameLabel
BETTERUI_WritsPanelSlotContainerExtractionSlotWritDesc = writDescLabel
BETTERUI_WritsPanel = writPanel

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, label)
    assert_eq(value, true, label)
end

local function assert_contains(haystack, needle, label)
    local matched = type(haystack) == "string" and haystack:find(needle, 1, true) ~= nil
    assert_eq(matched, true, label)
end

function GetCVar(name)
    if name == "language.2" then
        return mockLanguage
    end
    return nil
end

function zo_strformat(fmt, ...)
    local values = { ... }
    return (tostring(fmt):gsub("<<(%d+)>>", function(index)
        return tostring(values[tonumber(index)] or "")
    end))
end

function IsValidQuestIndex(questId)
    return questJournal[questId] ~= nil
end

function GetJournalQuestType(questId)
    local quest = questJournal[questId]
    return quest and quest.questType or nil
end

function GetJournalQuestInfo(questId)
    local quest = questJournal[questId]
    return quest and quest.name or nil
end

function GetJournalQuestNumConditions(questId)
    local quest = questJournal[questId]
    return #(quest and quest.conditions or {})
end

function GetJournalQuestConditionInfo(questId, _, lineId)
    local condition = questJournal[questId] and questJournal[questId].conditions[lineId]
    if not condition then
        return "", 0, 0, false, false, nil, false
    end
    return condition.line or "",
        condition.current or 0,
        condition.maximum or 0,
        condition.isFailCondition or false,
        condition.complete or false,
        nil,
        condition.isVisible
end

BETTERUI = {
    name = "BetterUI",
    Writs = {},
    CIM = {
        SafeExecute = function(context, fn, ...)
            safeExecuteContexts[#safeExecuteContexts + 1] = context
            if context == safeExecuteFailureContext then
                return false, "forced_failure"
            end
            return fn(...)
        end,
        EventRegistry = {
            Register = function(_, namespace, eventCode, callback)
                EVENT_MANAGER:RegisterForEvent(namespace, eventCode, callback)
                return true
            end,
        },
    },
    WindowManager = {
        CreateTopLevelWindow = function(_, name)
            return { name = name }
        end,
        CreateControlFromVirtual = function(_, name)
            assert_eq(name, "BETTERUI_WritsPanel", "writ setup creates the expected virtual panel")
            return writPanel
        end,
    },
}

function BETTERUI.GetModuleEnabled(moduleName)
    if moduleName == "Writs" then
        return moduleEnabled
    end
    return true
end

EVENT_MANAGER = {}

function EVENT_MANAGER:RegisterForEvent(name, eventCode, callback)
    registeredEvents[name .. ":" .. tostring(eventCode)] = callback
end

local function getEventCallback(eventCode)
    return registeredEvents["BetterUI_Writs:" .. tostring(eventCode)]
end

local function resetUiState()
    writNameText = nil
    writDescText = nil
    writPanelHidden = nil
    safeExecuteContexts = {}
    safeExecuteFailureContext = nil
end

local function hasSafeExecuteContext(expectedContext)
    for _, context in ipairs(safeExecuteContexts) do
        if context == expectedContext then
            return true
        end
    end
    return false
end

dofile("Modules/Writs/Constants.lua")
dofile("Modules/Writs/Core/Writ.lua")
dofile("Modules/Writs/Module.lua")

print("[Writ constants]")

do
    mockLanguage = "en"
    local patterns = BETTERUI.Writs.CONST.GetLocalizedPatterns()
    assert_eq(#patterns, 8, "english pattern list loads")
    assert_eq(patterns[1].pattern, "blacksmith", "english patterns preserve ordering")
    assert_eq(patterns[#patterns].pattern, "witches", "english festival fallback stays last")
end

do
    mockLanguage = "de"
    local patterns = BETTERUI.Writs.CONST.GetLocalizedPatterns()
    assert_eq(#patterns, 8, "german pattern list loads")
    assert_eq(patterns[1].craftType, CRAFTING_TYPE_BLACKSMITHING, "german blacksmith pattern maps correctly")
    assert_eq(patterns[6].pattern, "hexen", "german festival fallback stays in localized patterns")
end

do
    mockLanguage = "jp"
    local patterns = BETTERUI.Writs.CONST.GetLocalizedPatterns()
    assert_eq(#patterns, 8, "unknown locale falls back to english patterns")
    assert_eq(patterns[1].pattern, "blacksmith", "unknown locale preserves english fallback ordering")
end

print("[Writ objective formatting]")

questJournal = {
    [1] = {
        name = "Blacksmith Writ",
        questType = QUEST_TYPE_CRAFTING,
        conditions = {
            { line = "Forge Rubedite Sword", current = 1, maximum = 1, complete = true, isVisible = true },
            { line = "Deliver weapons", current = 0, maximum = 1, complete = false, isVisible = true },
            { line = "", current = 0, maximum = 1, complete = false, isVisible = true },
            { line = "Hidden objective", current = 0, maximum = 1, complete = false, isVisible = false },
            { line = "Fail condition", current = 0, maximum = 1, complete = false, isVisible = true, isFailCondition = true },
        },
    },
}

do
    local formatted = BETTERUI.Writs.GetFormattedObjectives(1)
    assert_contains(formatted, "|c00FF00", "completed writ lines use the completion color")
    assert_contains(formatted, "|cCCCCCC", "incomplete writ lines use the incomplete color")
    assert_true(formatted:find("Hidden objective", 1, true) == nil, "hidden objectives are excluded")
    assert_true(formatted:find("Fail condition", 1, true) == nil, "fail conditions are excluded")
end

print("[Writ update and panel display]")

questJournal = {
    [1] = {
        name = "Blacksmith Writ",
        questType = QUEST_TYPE_CRAFTING,
        conditions = {
            { line = "Forge Rubedite Sword", current = 1, maximum = 1, complete = true, isVisible = true },
        },
    },
    [2] = {
        name = "Witches Festival Cloth Donation",
        questType = QUEST_TYPE_CRAFTING,
        conditions = {
            { line = "Cook the festival dish", current = 0, maximum = 1, complete = false, isVisible = true },
        },
    },
    [3] = {
        name = "Unrelated Story Quest",
        questType = 999,
        conditions = {
            { line = "Talk to the quest giver", current = 0, maximum = 1, complete = false, isVisible = true },
        },
    },
}

mockLanguage = "en"
BETTERUI.Writs.CacheControls()
resetUiState()
BETTERUI.Writs.RefreshActiveWrits()
assert_eq(safeExecuteContexts[1], "Writs:RefreshActiveWrits", "refresh uses the canonical SafeExecute context")
assert_eq(BETTERUI.Writs.List[CRAFTING_TYPE_BLACKSMITHING].id, 1, "blacksmith writ is indexed by craft type")
assert_eq(BETTERUI.Writs.List[CRAFTING_TYPE_PROVISIONING].id, 2, "last matching pattern wins for witches festival writs")

local showOk = BETTERUI.Writs.ShowForCraftType(CRAFTING_TYPE_BLACKSMITHING)
assert_eq(showOk, true, "show-for-craft returns success for an active writ")
assert_true(hasSafeExecuteContext("Writs:ShowForCraftType"),
    "show-for-craft uses the canonical SafeExecute context")
assert_contains(writNameText, "Blacksmith Writ", "show writes the active writ title")
assert_contains(writDescText, "Forge Rubedite Sword", "show writes the formatted objective text")
assert_eq(writPanelHidden, false, "show reveals the writ panel")

BETTERUI.Writs.HidePanel()
assert_eq(writPanelHidden, true, "hide conceals the writ panel")

print("[Locale fallback pattern matching]")

do
    questJournal = {
        [1] = {
            name = "Blacksmith Writ",
            questType = QUEST_TYPE_CRAFTING,
            conditions = {
                { line = "Forge Rubedite Sword", current = 1, maximum = 1, complete = true, isVisible = true },
            },
        },
    }
    mockLanguage = "jp"
    resetUiState()

    local refreshOk, refreshErr = BETTERUI.Writs.RefreshActiveWrits()
    assert_eq(refreshOk, true, "refresh succeeds when locale falls back to english writ patterns")
    assert_eq(refreshErr, nil, "refresh with fallback locale patterns reports no error")
    assert_eq(BETTERUI.Writs.List[CRAFTING_TYPE_BLACKSMITHING].id, 1,
        "english quest names are matched through the fallback locale pattern set")

    local showLocaleOk, showLocaleErr = BETTERUI.Writs.ShowForCraftType(CRAFTING_TYPE_BLACKSMITHING)
    assert_eq(showLocaleOk, true, "show-for-craft succeeds through fallback locale patterns")
    assert_eq(showLocaleErr, nil, "show-for-craft reports no error when fallback patterns match")
end

mockLanguage = "en"
questJournal = {
    [1] = {
        name = "Blacksmith Writ",
        questType = QUEST_TYPE_CRAFTING,
        conditions = {
            { line = "Forge Rubedite Sword", current = 1, maximum = 1, complete = true, isVisible = true },
        },
    },
    [2] = {
        name = "Witches Festival Cloth Donation",
        questType = QUEST_TYPE_CRAFTING,
        conditions = {
            { line = "Cook the festival dish", current = 0, maximum = 1, complete = false, isVisible = true },
        },
    },
    [3] = {
        name = "Unrelated Story Quest",
        questType = 999,
        conditions = {
            { line = "Talk to the quest giver", current = 0, maximum = 1, complete = false, isVisible = true },
        },
    },
}

print("[Writ failure contract]")
do
    BETTERUI.Writs.List = {
        [CRAFTING_TYPE_BLACKSMITHING] = { id = 77, writLines = "stale" },
    }
    safeExecuteFailureContext = "Writs:RefreshActiveWrits"
    local ok, err = BETTERUI.Writs.RefreshActiveWrits()
    assert_eq(ok, false, "refresh returns failure when SafeExecute fails")
    assert_eq(err, "forced_failure", "refresh surfaces the SafeExecute error")
    assert_eq(BETTERUI.Writs.List[CRAFTING_TYPE_BLACKSMITHING].id, 77,
        "refresh failure preserves the previous active writ lookup")

    resetUiState()
    BETTERUI.Writs.List = {
        [CRAFTING_TYPE_BLACKSMITHING] = { id = 77, writLines = "stale" },
    }
    safeExecuteFailureContext = "Writs:RefreshActiveWrits"
    ok, err = BETTERUI.Writs.ShowForCraftType(CRAFTING_TYPE_BLACKSMITHING)
    assert_eq(ok, false, "show-for-craft returns failure when refresh fails")
    assert_eq(err, "forced_failure", "show-for-craft surfaces the refresh failure")
    assert_eq(writNameText, nil, "show-for-craft does not repaint stale UI on refresh failure")
    assert_eq(BETTERUI.Writs.Get, nil, "legacy Get alias has been removed")
    assert_eq(BETTERUI.Writs.Update, nil, "legacy Update alias has been removed")
    assert_eq(BETTERUI.Writs.Show, nil, "legacy Show alias has been removed")
    assert_eq(BETTERUI.Writs.Hide, nil, "legacy Hide alias has been removed")
end

print("[Writ module lifecycle]")

resetUiState()
moduleEnabled = true
BETTERUI.Writs.List = {}
BETTERUI.Writs.Setup()
assert_eq(writPanelHidden, true, "setup hides the writ panel by default")
assert_true(type(getEventCallback(EVENT_CRAFTING_STATION_INTERACT)) == "function", "setup registers craft-station enter handler")
assert_true(type(getEventCallback(EVENT_END_CRAFTING_STATION_INTERACT)) == "function", "setup registers craft-station exit handler")
assert_true(type(getEventCallback(EVENT_CRAFT_COMPLETED)) == "function", "setup registers craft-completed handler")

resetUiState()
getEventCallback(EVENT_CRAFTING_STATION_INTERACT)(nil, tostring(CRAFTING_TYPE_BLACKSMITHING))
assert_eq(safeExecuteContexts[1], "Writs:OnCraftStation", "entering a station runs through SafeExecute")
assert_contains(writNameText, "Blacksmith Writ", "entering a station shows the matching writ")

resetUiState()
moduleEnabled = false
getEventCallback(EVENT_CRAFTING_STATION_INTERACT)(nil, tostring(CRAFTING_TYPE_BLACKSMITHING))
assert_eq(#safeExecuteContexts, 0, "disabled writ module ignores craft-station entry")

moduleEnabled = true
resetUiState()
getEventCallback(EVENT_CRAFT_COMPLETED)(nil, tostring(CRAFTING_TYPE_PROVISIONING))
assert_eq(safeExecuteContexts[1], "Writs:OnCraftItem", "craft completion refreshes writ display through SafeExecute")
assert_contains(writNameText, "Witches Festival Cloth Donation", "craft completion refreshes the current station writ")

resetUiState()
writPanelHidden = false
getEventCallback(EVENT_END_CRAFTING_STATION_INTERACT)(nil)
assert_eq(safeExecuteContexts[1], "Writs:OnCloseCraftStation", "closing a station routes through SafeExecute")
assert_eq(writPanelHidden, true, "closing a station hides the writ panel")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
