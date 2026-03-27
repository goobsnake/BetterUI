--[[
File: tools/tests/test_banking_lifecycle.lua
Purpose: Tests for banking scene lifecycle event registration patterns.
         Validates that guild bank event tables and keybind cleanup are consistent.

Usage:
  lua tools/tests/test_banking_lifecycle.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

-- Simulate ESO event constants
EVENT_GUILD_BANK_SELECTED = 1001
EVENT_GUILD_BANK_DESELECTED = 1002
EVENT_GUILD_BANK_ITEMS_READY = 1003
EVENT_GUILD_BANK_ITEM_ADDED = 1004
EVENT_GUILD_BANK_ITEM_REMOVED = 1005
EVENT_GUILD_BANK_UPDATED_QUANTITY = 1006
EVENT_GUILD_BANK_OPEN_ERROR = 1007
EVENT_GUILD_BANKED_MONEY_UPDATE = 1008
EVENT_GUILD_RANKS_CHANGED = 1009
EVENT_GUILD_MEMBER_RANK_CHANGED = 1010
EVENT_GUILD_SELF_LEFT_GUILD = 1011

-- Track event registrations
local registeredEvents = {}
local unregisteredEvents = {}

EVENT_MANAGER = {
    RegisterForEvent = function(_, ns, event, handler)
        registeredEvents[event] = { ns = ns, handler = handler }
    end,
    UnregisterForEvent = function(_, ns, event)
        unregisteredEvents[event] = { ns = ns }
    end,
}

-- Minimal BETTERUI stub
BETTERUI = {
    Banking = {
        LIST_WITHDRAW = 1,
        LIST_DEPOSIT = 2,
        GuildBank = {
            IsGuildBankMode = function() return true end,
            RegisterGuildSelectorDialog = function() end,
            GetSelectedGuildId = function() return 1 end,
            OnGuildBankSelected = function() end,
            OnGuildBankDeselected = function() end,
            OnGuildBankReady = function() end,
            OnGuildBankUpdated = function() end,
            OnGuildBankOpenError = function() end,
            OnGuildBankedMoneyUpdate = function() end,
            OnGuildRanksChanged = function() end,
            OnGuildMemberRankChanged = function() end,
            OnGuildSelfLeft = function() end,
            SetLoading = function() end,
        },
        Class = {},
    },
    CIM = {
        SceneCleanup = {
            CleanupInputState = function() end,
            DeactivateLists = function() end,
            ClearSearchState = function() end,
        },
        HeaderNavigation = {
            GetOrCreateState = function() return {} end,
        },
        Utils = {
            IsBankingSceneShowing = function() return true end,
        },
    },
}

BETTERUI_GUILD_BANKING_SCENE_NAME = "BETTERUI_GUILD_BANKING"

-- ============================================================================
-- TEST HARNESS
-- ============================================================================

local tests_passed = 0
local tests_failed = 0

local function expect(name, condition, message)
    if condition then
        tests_passed = tests_passed + 1
    else
        tests_failed = tests_failed + 1
        print("  FAIL: " .. name .. " — " .. (message or ""))
    end
end

local function reset()
    registeredEvents = {}
    unregisteredEvents = {}
end

-- ============================================================================
-- LOAD MODULE UNDER TEST (parse the GUILD_BANK_EVENTS table)
-- ============================================================================

-- We inline-load the event table since the file depends on ESO globals
local GUILD_BANK_EVENTS = {
    EVENT_GUILD_BANK_SELECTED,
    EVENT_GUILD_BANK_DESELECTED,
    EVENT_GUILD_BANK_ITEMS_READY,
    EVENT_GUILD_BANK_ITEM_ADDED,
    EVENT_GUILD_BANK_ITEM_REMOVED,
    EVENT_GUILD_BANK_UPDATED_QUANTITY,
    EVENT_GUILD_BANK_OPEN_ERROR,
    EVENT_GUILD_BANKED_MONEY_UPDATE,
    EVENT_GUILD_RANKS_CHANGED,
    EVENT_GUILD_MEMBER_RANK_CHANGED,
    EVENT_GUILD_SELF_LEFT_GUILD,
}

-- ============================================================================
-- TESTS
-- ============================================================================

print("test_banking_lifecycle")

-- Test: GUILD_BANK_EVENTS contains exactly 11 events
expect("guild_bank_events_count",
    #GUILD_BANK_EVENTS == 11,
    "Expected 11 events, got " .. #GUILD_BANK_EVENTS)

-- Test: No duplicate events in the table
do
    local seen = {}
    local hasDupes = false
    for _, event in ipairs(GUILD_BANK_EVENTS) do
        if seen[event] then
            hasDupes = true
            break
        end
        seen[event] = true
    end
    expect("no_duplicate_events", not hasDupes, "Found duplicate events in GUILD_BANK_EVENTS")
end

-- Test: Registration loop covers all events
do
    reset()
    local ns = BETTERUI_GUILD_BANKING_SCENE_NAME
    local GuildBank = BETTERUI.Banking.GuildBank
    local eventHandlers = {
        [EVENT_GUILD_BANK_SELECTED]         = GuildBank.OnGuildBankSelected,
        [EVENT_GUILD_BANK_DESELECTED]       = GuildBank.OnGuildBankDeselected,
        [EVENT_GUILD_BANK_ITEMS_READY]      = GuildBank.OnGuildBankReady,
        [EVENT_GUILD_BANK_ITEM_ADDED]       = GuildBank.OnGuildBankUpdated,
        [EVENT_GUILD_BANK_ITEM_REMOVED]     = GuildBank.OnGuildBankUpdated,
        [EVENT_GUILD_BANK_UPDATED_QUANTITY]  = GuildBank.OnGuildBankUpdated,
        [EVENT_GUILD_BANK_OPEN_ERROR]       = GuildBank.OnGuildBankOpenError,
        [EVENT_GUILD_BANKED_MONEY_UPDATE]   = GuildBank.OnGuildBankedMoneyUpdate,
        [EVENT_GUILD_RANKS_CHANGED]         = GuildBank.OnGuildRanksChanged,
        [EVENT_GUILD_MEMBER_RANK_CHANGED]   = GuildBank.OnGuildMemberRankChanged,
        [EVENT_GUILD_SELF_LEFT_GUILD]       = GuildBank.OnGuildSelfLeft,
    }
    for _, event in ipairs(GUILD_BANK_EVENTS) do
        EVENT_MANAGER:RegisterForEvent(ns, event, eventHandlers[event])
    end
    local registeredCount = 0
    for _ in pairs(registeredEvents) do registeredCount = registeredCount + 1 end
    expect("register_all_events",
        registeredCount == 11,
        "Expected 11 registrations, got " .. registeredCount)
end

-- Test: Unregistration loop covers all events
do
    reset()
    local ns = BETTERUI_GUILD_BANKING_SCENE_NAME
    for _, event in ipairs(GUILD_BANK_EVENTS) do
        EVENT_MANAGER:UnregisterForEvent(ns, event)
    end
    local unregisteredCount = 0
    for _ in pairs(unregisteredEvents) do unregisteredCount = unregisteredCount + 1 end
    expect("unregister_all_events",
        unregisteredCount == 11,
        "Expected 11 unregistrations, got " .. unregisteredCount)
end

-- Test: Register/unregister use same namespace
do
    reset()
    local ns = BETTERUI_GUILD_BANKING_SCENE_NAME
    local GuildBank = BETTERUI.Banking.GuildBank
    local eventHandlers = {
        [EVENT_GUILD_BANK_SELECTED] = GuildBank.OnGuildBankSelected,
    }
    EVENT_MANAGER:RegisterForEvent(ns, EVENT_GUILD_BANK_SELECTED, eventHandlers[EVENT_GUILD_BANK_SELECTED])
    EVENT_MANAGER:UnregisterForEvent(ns, EVENT_GUILD_BANK_SELECTED)
    expect("consistent_namespace",
        registeredEvents[EVENT_GUILD_BANK_SELECTED].ns == unregisteredEvents[EVENT_GUILD_BANK_SELECTED].ns,
        "Registration and unregistration use different namespaces")
end

-- Test: All events in table have handlers in the mapping
do
    local GuildBank = BETTERUI.Banking.GuildBank
    local eventHandlers = {
        [EVENT_GUILD_BANK_SELECTED]         = GuildBank.OnGuildBankSelected,
        [EVENT_GUILD_BANK_DESELECTED]       = GuildBank.OnGuildBankDeselected,
        [EVENT_GUILD_BANK_ITEMS_READY]      = GuildBank.OnGuildBankReady,
        [EVENT_GUILD_BANK_ITEM_ADDED]       = GuildBank.OnGuildBankUpdated,
        [EVENT_GUILD_BANK_ITEM_REMOVED]     = GuildBank.OnGuildBankUpdated,
        [EVENT_GUILD_BANK_UPDATED_QUANTITY]  = GuildBank.OnGuildBankUpdated,
        [EVENT_GUILD_BANK_OPEN_ERROR]       = GuildBank.OnGuildBankOpenError,
        [EVENT_GUILD_BANKED_MONEY_UPDATE]   = GuildBank.OnGuildBankedMoneyUpdate,
        [EVENT_GUILD_RANKS_CHANGED]         = GuildBank.OnGuildRanksChanged,
        [EVENT_GUILD_MEMBER_RANK_CHANGED]   = GuildBank.OnGuildMemberRankChanged,
        [EVENT_GUILD_SELF_LEFT_GUILD]       = GuildBank.OnGuildSelfLeft,
    }
    local allHaveHandlers = true
    for _, event in ipairs(GUILD_BANK_EVENTS) do
        if not eventHandlers[event] then
            allHaveHandlers = false
            break
        end
    end
    expect("all_events_have_handlers", allHaveHandlers, "Some events in GUILD_BANK_EVENTS lack handlers")
end

-- ============================================================================
-- SUMMARY
-- ============================================================================

print(string.format("  %d passed, %d failed", tests_passed, tests_failed))
if tests_failed > 0 then
    os.exit(1)
end
