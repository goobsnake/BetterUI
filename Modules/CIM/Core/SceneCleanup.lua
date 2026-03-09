--[[
File: Modules/CIM/Core/SceneCleanup.lua
Purpose: Shared scene cleanup utilities to ensure proper DIRECTIONAL_INPUT release
         when scenes are hidden. Consolidates cleanup patterns from Banking and Inventory.
Author: BetterUI Team
Last Modified: 2026-01-31
]]

-- Create namespace if not exists
BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.SceneCleanup = {}

--[[
Function: BETTERUI.CIM.SceneCleanup.CleanupInputState
Description: Cleans up all input-related state when a scene is hidden. This ensures
             DIRECTIONAL_INPUT registrations are properly released and mode flags are cleared.
Rationale: Extracted from Banking and Inventory OnSceneHidden handlers to eliminate
           code duplication and ensure consistent cleanup behavior.
param: screen (table) - The screen instance (Banking.Class or Inventory.Class)
Returns: void
]]
function BETTERUI.CIM.SceneCleanup.CleanupInputState(screen)
    if not screen then return end

    -- 1. Force-clear header sort mode unconditionally
    -- Mirrors the d403eeaa pattern: always clear state, don't rely on flag checks.
    -- We do NOT call ExitHeaderSortMode() because it re-activates the list,
    -- which is immediately undone by the subsequent DeactivateLists() call.
    screen.isInHeaderSortMode = false
    if screen.headerSortController and screen.headerSortController.ExitHeaderMode then
        screen.headerSortController:ExitHeaderMode()
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
end

--[[
Function: BETTERUI.CIM.SceneCleanup.DeactivateLists
Description: Deactivates all list controls to release DIRECTIONAL_INPUT.
Rationale: Lists register with DIRECTIONAL_INPUT when active and must be
           explicitly deactivated on scene hidden.
param: screen (table) - The screen instance
param: ... (tables) - Additional list objects to deactivate
Returns: void
]]
function BETTERUI.CIM.SceneCleanup.DeactivateLists(screen, ...)
    if not screen then return end

    -- Deactivate primary list if present
    if screen.list and screen.list.Deactivate then
        screen.list:Deactivate()
    end

    -- Deactivate selector if present (Banking pattern)
    if screen.selector and screen.selector.Deactivate then
        screen.selector:Deactivate()
    end

    -- Deactivate any additional lists passed as varargs
    for i = 1, select("#", ...) do
        local list = select(i, ...)
        if list then
            if list.Deactivate then
                list:Deactivate()
            end
            -- Handle wrapper pattern (list.list)
            if list.list and list.list.Deactivate then
                list.list:Deactivate()
            end
        end
    end
end

--[[
Function: BETTERUI.CIM.SceneCleanup.ClearSearchState
Description: Clears search-related state and text when exiting a scene.
param: screen (table) - The screen instance
Returns: void
]]
function BETTERUI.CIM.SceneCleanup.ClearSearchState(screen)
    if not screen then return end

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

    -- Call module's LeaveSearchMode if available
    if screen.LeaveSearchMode then
        screen:LeaveSearchMode()
    end

    -- Call module's ClearTextSearch if available
    if screen.ClearTextSearch then
        screen:ClearTextSearch()
    end
end
