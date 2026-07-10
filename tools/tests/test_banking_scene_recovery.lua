--[[
File: tools/tests/test_banking_scene_recovery.lua
Purpose: BUI-STAB-001 Phase 5 -- deterministic regression coverage for the
         generation-bound hidden-scene recovery in BankingSceneLifecycle.

Covers:
  * Stale recovery callback after bank re-entry (handle removal + generation guard).
  * Callback-first ordering at the SHOWING boundary (recovery wins if it fires first).
  * SHOWING invalidation (cancel + generation bump).
  * HIDING invalidation.
  * Intentional exit to another scene (recovery stands down).
  * Genuinely stranded open-bank recovery (and BetterUI-bank-engaged rejection).

Usage:
  lua tools/tests/test_banking_scene_recovery.lua
]]

if false then
    dofile("Modules/Banking/Scene/BankingSceneLifecycle.lua")
end

BETTERUI_BANKING_SCENE_NAME = "betterui_banking"
BETTERUI_GUILD_BANKING_SCENE_NAME = "betterui_guild_banking"

BAG_BACKPACK = 1
BAG_BANK = 2

SCENE_SHOWING = "showing"
SCENE_SHOWN = "shown"
SCENE_HIDING = "hiding"
SCENE_HIDDEN = "hidden"

-- Guild-bank event globals: BankingSceneLifecycle captures these into a module
-- table at load time. Defining them keeps that table array contiguous.
EVENT_GUILD_BANK_SELECTED = 2001
EVENT_GUILD_BANK_DESELECTED = 2002
EVENT_GUILD_BANK_ITEMS_READY = 2003
EVENT_GUILD_BANK_ITEM_ADDED = 2004
EVENT_GUILD_BANK_ITEM_REMOVED = 2005
EVENT_GUILD_BANK_UPDATED_QUANTITY = 2006
EVENT_GUILD_BANK_OPEN_ERROR = 2007
EVENT_GUILD_BANKED_MONEY_UPDATE = 2008
EVENT_GUILD_RANKS_CHANGED = 2009
EVENT_GUILD_MEMBER_RANK_CHANGED = 2010
EVENT_GUILD_SELF_LEFT_GUILD = 2011

local testsPassed = 0
local testsFailed = 0

local function assertTrue(condition, message)
    if condition then
        testsPassed = testsPassed + 1
    else
        testsFailed = testsFailed + 1
        print("  [FAILED] " .. message)
    end
end

local function assertEqual(expected, actual, message)
    assertTrue(expected == actual, string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)))
end

-- ---------------------------------------------------------------------------
-- Deterministic fake scheduler: zo_callLater queues; nothing fires until an
-- explicit flush, so tests control the exact moment the recovery callback runs.
-- ---------------------------------------------------------------------------
local scheduled = {}
local nextCallLaterId = 0
local removedCallLaterIds = {}

function zo_callLater(callback, delay)
    nextCallLaterId = nextCallLaterId + 1
    scheduled[nextCallLaterId] = { callback = callback, delay = delay }
    return nextCallLaterId
end

function zo_removeCallLater(id)
    table.insert(removedCallLaterIds, id)
    scheduled[id] = nil
end

local function flushScheduled()
    local ids = {}
    for id in pairs(scheduled) do
        table.insert(ids, id)
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local entry = scheduled[id]
        if entry then
            scheduled[id] = nil
            entry.callback()
        end
    end
end

-- ---------------------------------------------------------------------------
-- Controllable environment: gamepad mode, bank-open state, scene manager.
-- ---------------------------------------------------------------------------
local gamepadMode = true
local bankOpen = true

function IsInGamepadPreferredMode()
    return gamepadMode
end

function IsBankOpen()
    return bankOpen
end

local sceneState = {
    currentSceneName = nil,
    nextSceneName = nil,
    showing = {},      -- name -> true
    sceneStates = {},  -- name -> SCENE_SHOWING / SCENE_SHOWN
    shown = {},        -- ordered list of Show() targets
}

local function resetSceneState()
    sceneState.currentSceneName = nil
    sceneState.nextSceneName = nil
    sceneState.showing = {}
    sceneState.sceneStates = {}
    sceneState.shown = {}
end

SCENE_MANAGER = {
    GetCurrentSceneName = function()
        return sceneState.currentSceneName
    end,
    GetNextScene = function()
        if not sceneState.nextSceneName then
            return nil
        end
        local name = sceneState.nextSceneName
        return { GetName = function() return name end }
    end,
    IsShowing = function(_, name)
        return sceneState.showing[name] == true
    end,
    GetScene = function(_, name)
        return {
            GetName = function() return name end,
            GetState = function() return sceneState.sceneStates[name] end,
            IsShowing = function() return sceneState.showing[name] == true end,
        }
    end,
    Show = function(_, name)
        table.insert(sceneState.shown, name)
    end,
    Hide = function() end,
}

local function recoveryShownInventory()
    for _, name in ipairs(sceneState.shown) do
        if name == "gamepad_inventory_root" then
            return true
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Minimal BETTERUI harness: only what OnSceneShowing/Hiding/Hidden touch.
-- KEYBIND_STRIP is nil so the keybind-strip teardown early-returns.
-- ---------------------------------------------------------------------------
KEYBIND_STRIP = nil
GAMEPAD_LEFT_TOOLTIP = {}
GAMEPAD_TOOLTIPS = { Reset = function() end }

SHARED_INVENTORY = {
    RegisterCallback = function() end,
    UnregisterCallback = function() end,
}
CALLBACK_MANAGER = {
    RegisterCallback = function() end,
    UnregisterCallback = function() end,
}
EVENT_MANAGER = {
    RegisterForEvent = function() end,
    UnregisterForEvent = function() end,
}

function GetString(id)
    return tostring(id)
end

BETTERUI = {
    Banking = {
        LIST_WITHDRAW = 1,
        LIST_DEPOSIT = 2,
        ReadTransferContextSnapshot = function()
            return { interactionBag = BAG_BANK, withdrawSourceBags = { BAG_BANK } }
        end,
        SetRuntimeBankBags = function() end,
        ResolveWindowCategoryKey = function()
            return "all"
        end,
        RefreshManager = { Cancel = function() end },
        Tasks = {
            Cancel = function() end,
            CancelAll = function() end,
            Schedule = function() end,
            IsPending = function() return false end,
        },
        GuildBank = {
            IsGuildBankMode = function() return false end,
            SetLoading = function() end,
        },
    },
    Interface = {
        RemoveKeybindGroupIfPresent = function() end,
    },
    Utils = {
        IsBankingSceneShowing = function() return true end,
    },
    CIM = {
        SceneCleanup = {
            CleanupInputState = function() end,
            DeactivateLists = function() end,
            ClearSearchState = function() end,
        },
    },
}

BETTERUI.Banking.Class = {}

dofile("Modules/Banking/Scene/BankingSceneLifecycle.lua")

local function createWindow()
    local window = {
        currentMode = BETTERUI.Banking.LIST_WITHDRAW,
        lastPositions = {},
        list = {
            Clear = function() end,
            Commit = function() end,
            Activate = function() end,
        },
        headerGeneric = {
            tabBar = {
                SetSelectedIndexWithoutAnimation = function() end,
            },
        },
    }

    function window:SetListUpdatesSuppressed() end
    function window:AreListUpdatesSuppressed() return false end
    function window:ComputeVisibleBankCategories() return { { key = "all" } } end
    function window:RebuildHeaderCategories() end
    function window:SetTitle() end
    function window:RefreshList() end
    function window:RefreshActiveKeybinds() end
    function window:AddKeybinds() end
    function window:UpdateExternalAddons() end
    function window:IsBatchProcessing() return false end
    function window:RequestBatchAbort() end

    return setmetatable(window, { __index = BETTERUI.Banking.Class })
end

local function resetEnv()
    gamepadMode = true
    bankOpen = true
    resetSceneState()
    scheduled = {}
    nextCallLaterId = 0
    removedCallLaterIds = {}
end

-- Strand the scene machinery: gamepad bank open, current scene is a dead state.
local function makeStranded()
    gamepadMode = true
    bankOpen = true
    sceneState.currentSceneName = "hud"
    sceneState.nextSceneName = nil
end

print("\n=== Banking hidden-scene recovery (BUI-STAB-001 Phase 5) ===\n")

-- Case 1a: stale recovery callback after bank re-entry via OnSceneShowing.
-- SHOWING removes the handle AND bumps the generation, so a flush is a no-op.
do
    resetEnv()
    local window = createWindow()
    makeStranded()
    window:OnSceneHidden()
    assertTrue(window._bankingSceneRecoverCallLaterId ~= nil, "1a: recovery scheduled on hidden")
    window:OnSceneShowing(false)
    assertEqual(nil, window._bankingSceneRecoverCallLaterId, "1a: SHOWING clears the pending recovery handle")
    assertTrue(#removedCallLaterIds >= 1, "1a: SHOWING removes the scheduled callLater by handle")
    flushScheduled()
    assertTrue(not recoveryShownInventory(), "1a: no recovery after bank re-entry")
end

-- Case 1b: generation guard neutralizes a callback that survived handle removal.
-- Simulate a re-entry that bumped the generation while the callback stayed queued.
do
    resetEnv()
    local window = createWindow()
    makeStranded()
    window:OnSceneHidden()
    -- Callback is still queued; simulate a generation bump that missed the handle.
    window._bankingSceneRecoverGeneration = window._bankingSceneRecoverGeneration + 1
    flushScheduled()
    assertTrue(not recoveryShownInventory(), "1b: generation-guard neutralizes a stale queued callback")
end

-- Case 1c: a stale callback that survived removal must not clear the handle
-- belonging to a newer recovery generation.
do
    resetEnv()
    local window = createWindow()
    makeStranded()
    window:OnSceneHidden()
    local staleId = window._bankingSceneRecoverCallLaterId
    local staleCallback = scheduled[staleId].callback

    window:OnSceneShowing(false)
    makeStranded()
    window:OnSceneHidden()
    local currentId = window._bankingSceneRecoverCallLaterId

    staleCallback()
    assertEqual(currentId, window._bankingSceneRecoverCallLaterId,
        "1c: stale callback preserves the newer recovery handle")
    window:OnSceneShowing(false)
    assertEqual(nil, window._bankingSceneRecoverCallLaterId,
        "1c: SHOWING can still cancel the newer recovery")
end

-- Case 2: callback-first ordering at the boundary. If the recovery fires BEFORE
-- any SHOWING, the generation is intact and the genuinely stranded case recovers.
do
    resetEnv()
    local window = createWindow()
    makeStranded()
    window:OnSceneHidden()
    flushScheduled() -- callback fires first, generation still matches
    assertTrue(recoveryShownInventory(), "2: callback fired before re-entry recovers inventory")
    -- A later SHOWING must not undo the already-performed recovery.
    window:OnSceneShowing(false)
    assertTrue(recoveryShownInventory(), "2: recovery stands after a subsequent SHOWING")
end

-- Case 3: SHOWING invalidation increments the generation and drops the handle.
do
    resetEnv()
    local window = createWindow()
    makeStranded()
    window:OnSceneHidden()
    local genBefore = window._bankingSceneRecoverGeneration
    window:OnSceneShowing(false)
    assertTrue(window._bankingSceneRecoverGeneration > genBefore, "3: SHOWING bumps the recovery generation")
    assertEqual(nil, window._bankingSceneRecoverCallLaterId, "3: SHOWING clears the recovery handle")
    flushScheduled()
    assertTrue(not recoveryShownInventory(), "3: SHOWING invalidation prevents recovery")
end

-- Case 4 (HIDING invalidation): a fresh HIDING supersedes a pending recovery.
do
    resetEnv()
    local window = createWindow()
    makeStranded()
    window:OnSceneHidden()
    local genBefore = window._bankingSceneRecoverGeneration
    window:OnSceneHiding()
    assertTrue(window._bankingSceneRecoverGeneration > genBefore, "4: HIDING bumps the recovery generation")
    assertEqual(nil, window._bankingSceneRecoverCallLaterId, "4: HIDING clears the recovery handle")
    flushScheduled()
    assertTrue(not recoveryShownInventory(), "4: HIDING invalidation prevents recovery")
end

-- Case 5: intentional exit to another scene. A non-inventory next scene means the
-- player is leaving on purpose; recovery must stand down.
do
    resetEnv()
    local window = createWindow()
    gamepadMode = true
    bankOpen = true
    sceneState.currentSceneName = "hud"
    sceneState.nextSceneName = "gamepad_guild_hub"
    window:OnSceneHidden()
    flushScheduled()
    assertTrue(not recoveryShownInventory(), "5: intentional exit to another scene suppresses recovery")
end

-- Case 6: genuinely stranded open-bank recovery -- and the BetterUI-bank-engaged
-- rejection so inventory is shown ONLY for the genuinely stranded case.
do
    -- 6a: stranded on the bare vanilla banking scene -> recover.
    resetEnv()
    local window = createWindow()
    gamepadMode = true
    bankOpen = true
    sceneState.currentSceneName = "gamepad_banking"
    window:OnSceneHidden()
    flushScheduled()
    assertTrue(recoveryShownInventory(), "6a: genuinely stranded bare banking scene recovers inventory")

    -- 6b: stranded with nil current scene -> recover.
    resetEnv()
    window = createWindow()
    gamepadMode = true
    bankOpen = true
    sceneState.currentSceneName = nil
    window:OnSceneHidden()
    flushScheduled()
    assertTrue(recoveryShownInventory(), "6b: nil current scene recovers inventory")

    -- 6c: BetterUI personal bank scene is the current scene -> NOT stranded, reject.
    resetEnv()
    window = createWindow()
    gamepadMode = true
    bankOpen = true
    sceneState.currentSceneName = BETTERUI_BANKING_SCENE_NAME
    window:OnSceneHidden()
    flushScheduled()
    assertTrue(not recoveryShownInventory(), "6c: active BetterUI bank scene rejects recovery")

    -- 6d: BetterUI guild bank scene queued as next -> reject.
    resetEnv()
    window = createWindow()
    gamepadMode = true
    bankOpen = true
    sceneState.currentSceneName = "hud"
    sceneState.nextSceneName = BETTERUI_GUILD_BANKING_SCENE_NAME
    window:OnSceneHidden()
    flushScheduled()
    assertTrue(not recoveryShownInventory(), "6d: BetterUI guild bank scene queued next rejects recovery")

    -- 6e: BetterUI guild bank scene reports its own state as showing -> reject.
    resetEnv()
    window = createWindow()
    gamepadMode = true
    bankOpen = true
    sceneState.currentSceneName = "hud"
    sceneState.sceneStates[BETTERUI_GUILD_BANKING_SCENE_NAME] = SCENE_SHOWING
    window:OnSceneHidden()
    flushScheduled()
    assertTrue(not recoveryShownInventory(), "6e: requested BetterUI guild bank scene rejects recovery")
end

-- Safeguards preserved: not gamepad, or bank already closed, or inventory already
-- showing -> never recover.
do
    resetEnv()
    local window = createWindow()
    makeStranded()
    gamepadMode = false
    window:OnSceneHidden()
    flushScheduled()
    assertTrue(not recoveryShownInventory(), "safeguard: keyboard mode suppresses recovery")

    resetEnv()
    window = createWindow()
    makeStranded()
    bankOpen = false
    window:OnSceneHidden()
    flushScheduled()
    assertTrue(not recoveryShownInventory(), "safeguard: closed bank suppresses recovery")

    resetEnv()
    window = createWindow()
    makeStranded()
    sceneState.showing["gamepad_inventory_root"] = true
    window:OnSceneHidden()
    flushScheduled()
    -- Inventory already showing: our recovery must not re-issue a Show.
    assertEqual(0, #sceneState.shown, "safeguard: inventory already showing suppresses recovery Show")
end

print("\n=== Test Summary ===")
print("Passed: " .. testsPassed)
print("Failed: " .. testsFailed)

if testsFailed > 0 then
    print("\nFAILED -- see above for details")
    os.exit(1)
else
    print("\nAll tests passed!")
end
