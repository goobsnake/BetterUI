--[[
File: Modules/CIM/Core/Lifecycle/SceneCleanup.lua
Purpose: Shared scene cleanup utilities to ensure proper DIRECTIONAL_INPUT release
         when scenes are hidden. Consolidates cleanup patterns from Banking and Inventory.
]]

-- Create namespace if not exists
BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.SceneCleanup = {}

local function PurgeKeybindGroup(descriptor)
    if not descriptor then return false end
    local interface = BETTERUI.Interface
    local purgeGroup = interface and interface.RemoveKeybindGroupFromAllStates
    if type(purgeGroup) == "function" then
        return purgeGroup(descriptor)
    end
    local removeGroup = interface and interface.RemoveKeybindGroupIfPresent
    if type(removeGroup) == "function" then
        return removeGroup(descriptor)
    end
    return false
end

local function PurgeKeybindGroups(groups)
    for _, descriptor in ipairs(groups or {}) do
        PurgeKeybindGroup(descriptor)
    end
end

-- This is the final ownership sweep for hidden scenes. It intentionally covers
-- every conventional descriptor field used by BetterUI screens plus tab/header
-- integration state, including groups parked in saved keybind-strip states.
local function PurgeScreenKeybindOwnership(screen, extraGroups)
    if not screen then return end
    local seen = {}
    local function PurgeOnce(descriptor)
        if descriptor and not seen[descriptor] then
            seen[descriptor] = true
            PurgeKeybindGroup(descriptor)
        end
    end

    PurgeOnce(screen.coreKeybinds)
    PurgeOnce(screen.mainKeybindStripDescriptor)
    PurgeOnce(screen.activeKeybindDescriptor)
    PurgeOnce(screen.textSearchKeybindStripDescriptor)
    PurgeOnce(screen.withdrawDepositKeybinds)
    PurgeOnce(screen.currencyKeybinds)
    PurgeOnce(screen.currencySelectorKeybinds)
    PurgeOnce(screen._activeHeaderSortKeybindDescriptor)
    PurgeOnce(screen.headerSortKeybindDescriptor)

    local function PurgeTabBar(header)
        local tabBar = header and header.tabBar
        PurgeOnce(tabBar and tabBar.keybindStripDescriptor)
    end
    PurgeTabBar(screen.headerGeneric)
    PurgeTabBar(screen.header)

    local integration = screen._headerSortIntegration
    if integration then
        PurgeOnce(integration.activeKeybindDescriptor)
        PurgeKeybindGroups(integration.suspendedKeybindGroups)
    end
    PurgeKeybindGroups(extraGroups)
end

--- Cleans up all input-related state when a scene is hidden.
---
--- Purpose: Ensures DIRECTIONAL_INPUT registrations are properly released and mode flags are cleared.
--- Rationale: Extracted from Banking and Inventory OnSceneHidden handlers to eliminate
---            code duplication and ensure consistent cleanup behavior.
---
function BETTERUI.CIM.SceneCleanup.CleanupInputState(screen)
    local headerSortIntegrationState = screen and screen._headerSortIntegration or nil
    local suspendedGroupsBeforeCleanup = headerSortIntegrationState and headerSortIntegrationState.suspendedKeybindGroups or nil
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SCENE, "input state cleanup begin", {
        fn = "SceneCleanup.CleanupInputState",
        hasScreen = screen ~= nil,
        headerSort = screen and screen.isInHeaderSortMode == true,
        activeHeader = screen and BETTERUI.Log.DescribeKeybindDescriptor and BETTERUI.Log.DescribeKeybindDescriptor(screen._activeHeaderSortKeybindDescriptor, "activeHeader") or nil,
        header = screen and BETTERUI.Log.DescribeKeybindDescriptor and BETTERUI.Log.DescribeKeybindDescriptor(screen.headerSortKeybindDescriptor, "header") or nil,
        suspendedCount = BETTERUI.Log.CountKeybindDescriptors and BETTERUI.Log.CountKeybindDescriptors(suspendedGroupsBeforeCleanup) or 0,
    }) end
    if not screen then return end

    -- Clear spinner confirmation state so the next scene show does not remain in spinner mode.
    screen.confirmationMode = false

    -- 1. Force-clear header sort mode unconditionally
    -- Mirrors the d403eeaa pattern: always clear state, don't rely on flag checks.
    -- We do NOT call ExitHeaderSortMode() because it re-activates the list,
    -- which is immediately undone by the subsequent DeactivateLists() call.
    screen.isInHeaderSortMode = false
    local headerSortIntegration = BETTERUI.CIM and BETTERUI.CIM.UI and BETTERUI.CIM.UI.HeaderSortIntegration
    local resolveController = headerSortIntegration
        and (headerSortIntegration.PeekController or headerSortIntegration.GetController)
    local singleHeaderSortController = resolveController
        and resolveController(screen)
        or screen.headerSortController
        or screen.sortController
    if singleHeaderSortController and singleHeaderSortController.ExitHeaderMode then
        singleHeaderSortController:ExitHeaderMode()
    end
    if screen.headerSortControllers then
        for _, controller in pairs(screen.headerSortControllers) do
            if controller and controller.ExitHeaderMode then
                controller:ExitHeaderMode()
            end
        end
    end
    -- Remove sort keybinds if they were added (safety net)
    if screen._activeHeaderSortKeybindDescriptor and KEYBIND_STRIP then
        PurgeKeybindGroup(screen._activeHeaderSortKeybindDescriptor)
        screen._activeHeaderSortKeybindDescriptor = nil
    end
    if screen.headerSortKeybindDescriptor and KEYBIND_STRIP then
        PurgeKeybindGroup(screen.headerSortKeybindDescriptor)
        -- Symmetric with _activeHeaderSortKeybindDescriptor above: clear the reference
        -- after removal so a stale descriptor cannot dangle past scene exit.
        screen.headerSortKeybindDescriptor = nil
    end

    -- Reset the header-sort INTEGRATION state. We intentionally avoid the integration's
    -- ExitHeaderMode() here (it reactivates the list, which DeactivateLists below would
    -- immediately undo), but its isActive flag and active keybind descriptor MUST be cleared:
    -- otherwise the next EnterHeaderMode bails on "if integration.isActive then return false",
    -- permanently dead-ending the sort action after one scene exit. (The current keybind state
    -- on screen.isInHeaderSortMode is cleared above.)
    if headerSortIntegrationState then
        if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "scene cleanup header sort integration reset", {
            fn = "SceneCleanup.CleanupInputState",
            active = headerSortIntegrationState.isActive == true,
            activeKeybind = BETTERUI.Log.DescribeKeybindDescriptor and BETTERUI.Log.DescribeKeybindDescriptor(headerSortIntegrationState.activeKeybindDescriptor, "active") or tostring(headerSortIntegrationState.activeKeybindDescriptor),
            suspended = BETTERUI.Log.DescribeKeybindDescriptors and BETTERUI.Log.DescribeKeybindDescriptors(headerSortIntegrationState.suspendedKeybindGroups, "suspended") or tostring(headerSortIntegrationState.suspendedKeybindGroups),
            suspendedGroupsDropped = BETTERUI.Log.CountKeybindDescriptors and BETTERUI.Log.CountKeybindDescriptors(headerSortIntegrationState.suspendedKeybindGroups) or 0,
        }) end
        headerSortIntegrationState.isActive = false
        PurgeKeybindGroup(headerSortIntegrationState.activeKeybindDescriptor)
        PurgeKeybindGroups(headerSortIntegrationState.suspendedKeybindGroups)
        headerSortIntegrationState.activeKeybindDescriptor = nil
        headerSortIntegrationState.suspendedKeybindGroups = nil
    end
    if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.STATE, "input state cleanup complete", {
        fn = "SceneCleanup.CleanupInputState",
        headerSort = screen.isInHeaderSortMode == true,
        suspendedGroupsDropped = BETTERUI.Log.CountKeybindDescriptors and BETTERUI.Log.CountKeybindDescriptors(suspendedGroupsBeforeCleanup) or 0,
        activeHeaderCleared = screen._activeHeaderSortKeybindDescriptor == nil,
        headerCleared = screen.headerSortKeybindDescriptor == nil,
    }) end

    -- 2. Exit selection mode if active
    if screen.isInSelectionMode then
        if screen.ExitSelectionMode then
            screen:ExitSelectionMode()
        else
            screen.isInSelectionMode = false
            if screen.multiSelectManager and screen.multiSelectManager.ExitSelectionMode then
                screen.multiSelectManager:ExitSelectionMode()
            end
        end
    end

    -- 3. Deactivate search focus to release DIRECTIONAL_INPUT
    screen._searchModeActive = false
    screen._searchHeaderActive = false
    screen._searchTextChangedInProgress = nil
    screen._preserveSearchFocusDuringRefresh = nil
    screen._exitSearchModeInProgress = nil
    screen._requestingVendorHeaderFocus = nil
    screen._requestingVendorHeaderLeave = nil
    screen._requestingVendorSearchHeaderLeave = nil
    screen._restoringVendorSearchFocus = nil
    screen._refreshingVendorHeaderAfterSearchExit = nil
    if screen.textSearchHeaderFocus then
        if screen.textSearchHeaderFocus.Deactivate then
            screen.textSearchHeaderFocus:Deactivate()
        end
        if screen.textSearchHeaderFocus.SetFocused then
            screen.textSearchHeaderFocus:SetFocused(false)
        end
    end

    -- 4. Deactivate tab bar to release DIRECTIONAL_INPUT
    -- Check both headerGeneric (Banking) and header (Inventory) patterns
    local tabBar = screen.headerGeneric and screen.headerGeneric.tabBar
        or screen.header and screen.header.tabBar
    if tabBar and tabBar.Deactivate then
        tabBar:Deactivate()
    end

    -- 5. Clear update suppression flags
    screen._suppressListUpdates = false
    screen._suppressListUpdatesToken = nil

    -- 6. Cancel any pending coalesced list refresh so an in-flight refresh +
    --    RestorePosition cannot fire after teardown (against a hidden/torn-down scene).
    --    Covers managers held on the screen via the conventional field names.
    local cancelledRefreshManagers = {}
    local cancelledAliases = {}
    local function CancelRefreshManager(refreshManager, alias)
        if refreshManager and refreshManager.Cancel and not cancelledRefreshManagers[refreshManager] then
            cancelledRefreshManagers[refreshManager] = true
            table.insert(cancelledAliases, alias)
            refreshManager:Cancel()
        end
    end
    CancelRefreshManager(screen.refreshManager, "refreshManager")
    CancelRefreshManager(screen.listRefreshManager, "listRefreshManager")
    CancelRefreshManager(screen.RefreshManager, "RefreshManager")
    if BETTERUI.Log and BETTERUI.Log.IsActive() and #cancelledAliases > 0 then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SCENE, "scene cleanup cancelled refresh managers", { aliases = cancelledAliases })
    end

    -- 7. Cancel any pending coalesced header-navigation category-change timer.
    if BETTERUI.CIM.HeaderNavigation and BETTERUI.CIM.HeaderNavigation.CancelPending then
        BETTERUI.CIM.HeaderNavigation.CancelPending(screen)
    end

    -- Run last: cleanup callbacks above may remove a dialog state and expose a
    -- saved group. A hidden scene must own no live or saved keybind state.
    PurgeScreenKeybindOwnership(screen, suspendedGroupsBeforeCleanup)
end

--- Deactivates all list controls to release DIRECTIONAL_INPUT.
---
--- Purpose: Ensures lists are properly deactivated when a scene is hidden.
--- Rationale: Lists register with DIRECTIONAL_INPUT when active and must be
---            explicitly deactivated on scene hidden.
---
function BETTERUI.CIM.SceneCleanup.DeactivateLists(screen, ...)
    if not screen then return end

    local listCount = 0
    local deactivated = {}

    local function DeactivateOnce(list)
        if list and list.Deactivate and not deactivated[list] then
            deactivated[list] = true
            list:Deactivate()
            listCount = listCount + 1
        end
    end

    local function DeactivateCandidate(list)
        if not list then return end
        local wrappedList = list.list
        DeactivateOnce(list)
        if wrappedList ~= list then
            DeactivateOnce(wrappedList)
        end
    end

    DeactivateCandidate(screen.list)
    DeactivateCandidate(screen.selector)

    for i = 1, select("#", ...) do
        DeactivateCandidate(select(i, ...))
    end

    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SCENE, "lists deactivated", { lists = listCount }) end
end

--- Clears search-related state and text when exiting a scene.
---
function BETTERUI.CIM.SceneCleanup.ClearSearchState(screen)
    if not screen then return end

    local queryText = screen.searchQuery or ""
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SEARCH, "search cleared", { queryLen = #queryText }) end

    local searchMixin = BETTERUI.Interface and BETTERUI.Interface.SearchMixin
    local callSearchLifecycle = searchMixin and searchMixin.CallSearchLifecycle

    -- Clear search query
    screen.searchQuery = ""

    -- Clear edit box text
    if screen.textSearchHeaderFocus and screen.textSearchHeaderFocus.GetEditBox then
        local editBox = screen.textSearchHeaderFocus:GetEditBox()
        if editBox and editBox.SetText then
            editBox:SetText("")
        end
    end

    if callSearchLifecycle then
        callSearchLifecycle(screen, "exit")
        callSearchLifecycle(screen, "clear")
    else
        if screen.ExitSearchMode then
            screen:ExitSearchMode()
        end

        if screen.ClearSearchInput then
            screen:ClearSearchInput()
        end
    end

    -- Search exit callbacks can restore their scene keybinds. Enforce hidden
    -- ownership after those callbacks have finished.
    PurgeScreenKeybindOwnership(screen)
end
