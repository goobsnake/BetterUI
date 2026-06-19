--[[
File: Modules/CIM/Core/Lifecycle/SceneCleanup.lua
Purpose: Shared scene cleanup utilities to ensure proper DIRECTIONAL_INPUT release
         when scenes are hidden. Consolidates cleanup patterns from Banking and Inventory.
]]

-- Create namespace if not exists
BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.SceneCleanup = {}

--- Cleans up all input-related state when a scene is hidden.
---
--- Purpose: Ensures DIRECTIONAL_INPUT registrations are properly released and mode flags are cleared.
--- Rationale: Extracted from Banking and Inventory OnSceneHidden handlers to eliminate
---            code duplication and ensure consistent cleanup behavior.
---
function BETTERUI.CIM.SceneCleanup.CleanupInputState(screen)
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SCENE, "cleanupInputState", { hasScreen = screen ~= nil }) end
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
        KEYBIND_STRIP:RemoveKeybindButtonGroup(screen._activeHeaderSortKeybindDescriptor)
        screen._activeHeaderSortKeybindDescriptor = nil
    end
    if screen.headerSortKeybindDescriptor and KEYBIND_STRIP then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(screen.headerSortKeybindDescriptor)
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
    local headerSortIntegrationState = screen._headerSortIntegration
    if headerSortIntegrationState then
        headerSortIntegrationState.isActive = false
        if headerSortIntegrationState.activeKeybindDescriptor and KEYBIND_STRIP
            and KEYBIND_STRIP.RemoveKeybindButtonGroup then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(headerSortIntegrationState.activeKeybindDescriptor)
        end
        headerSortIntegrationState.activeKeybindDescriptor = nil
        headerSortIntegrationState.suspendedKeybindGroups = nil
    end

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
    local refreshManager = screen.refreshManager
        or screen.listRefreshManager
        or screen.RefreshManager
    if refreshManager and refreshManager.Cancel then
        refreshManager:Cancel()
    end

    -- 7. Cancel any pending coalesced header-navigation category-change timer.
    if BETTERUI.CIM.HeaderNavigation and BETTERUI.CIM.HeaderNavigation.CancelPending then
        BETTERUI.CIM.HeaderNavigation.CancelPending(screen)
    end
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

    -- Deactivate primary list if present
    if screen.list and screen.list.Deactivate then
        screen.list:Deactivate()
        listCount = listCount + 1
    end

    -- Deactivate selector if present (Banking pattern)
    if screen.selector and screen.selector.Deactivate then
        screen.selector:Deactivate()
        listCount = listCount + 1
    end

    -- Deactivate any additional lists passed as varargs
    for i = 1, select("#", ...) do
        local list = select(i, ...)
        if list then
            if list.Deactivate then
                list:Deactivate()
                listCount = listCount + 1
            end
            -- Handle wrapper pattern (list.list)
            if list.list and list.list.Deactivate then
                list.list:Deactivate()
                listCount = listCount + 1
            end
        end
    end

    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SCENE, "deactivateLists", { lists = listCount }) end
end

--- Clears search-related state and text when exiting a scene.
---
function BETTERUI.CIM.SceneCleanup.ClearSearchState(screen)
    if not screen then return end

    local queryText = screen.searchQuery or ""
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SEARCH, "clearSearch", { queryLen = #queryText }) end

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

    -- Remove search keybinds if present
    if screen.textSearchKeybindStripDescriptor and KEYBIND_STRIP then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(screen.textSearchKeybindStripDescriptor)
    end

    if callSearchLifecycle then
        callSearchLifecycle(screen, "exit")
        callSearchLifecycle(screen, "clear")
        return
    end

    if screen.ExitSearchMode then
        screen:ExitSearchMode()
    end

    if screen.ClearSearchInput then
        screen:ClearSearchInput()
    end
end
