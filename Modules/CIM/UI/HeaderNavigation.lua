--[[
File: Modules/CIM/UI/HeaderNavigation.lua
Purpose: Shared header navigation functions for category cycling.
         Provides consistent navigation behavior for Inventory and Banking.
Author: BetterUI Team
Last Modified: 2026-01-28
]]

-- ============================================================================
-- NAMESPACE INITIALIZATION
-- ============================================================================

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.HeaderNavigation = BETTERUI.CIM.HeaderNavigation or {}

-- Alias for NavigationState API
local NavState = BETTERUI.CIM.NavigationState

-- ============================================================================
-- NAVIGATION STATE INITIALIZATION
-- ============================================================================

--[[
Function: BETTERUI.CIM.HeaderNavigation.GetOrCreateState
Description: Gets or creates navigation state for a module instance.
Rationale: Ensures consistent state object across all navigation operations.
param: instance (table) - The module instance.
return: table - The navigation state object.
]]
--- @param instance table The module instance
--- @return table state The navigation state object
function BETTERUI.CIM.HeaderNavigation.GetOrCreateState(instance)
    if not instance._navState then
        instance._navState = NavState.Create()
    end
    return instance._navState
end

-- ============================================================================
-- CATEGORY CYCLING
-- ============================================================================

--[[
Function: BETTERUI.CIM.HeaderNavigation.CycleCategory
Description: Cycles category selection via shoulder buttons (LB/RB).
Rationale: Provides consistent wrap-around navigation for category headers.
Mechanism:
  1. Saves current position before switching.
  2. Calculates new index with wrap-around.
  3. Sets cycling flag to prevent duplicate saves.
  4. Drives selection via tabBar if available, otherwise updates manually.
param: instance (table) - The module instance (e.g., Inventory or Banking).
param: delta (number) - Direction: +1 for next, -1 for prev.
param: options (table) - Configuration:
  - categories: array of category data
  - getCurrentIndex: function() → current index
  - setCurrentIndex: function(idx) → sets new index
  - tabBar: optional tabBar to drive selection
  - onRefresh: function() → called to refresh after change
]]
--- @param instance table The module instance
--- @param delta number Direction: +1 for next, -1 for prev
--- @param options table Configuration options
function BETTERUI.CIM.HeaderNavigation.CycleCategory(instance, delta, options)
    if not options.categories or #options.categories < 2 then return end

    local state = BETTERUI.CIM.HeaderNavigation.GetOrCreateState(instance)
    local count = #options.categories
    local currentIdx = options.getCurrentIndex()
    local newIdx = BETTERUI.CIM.Utils.WrapValue(currentIdx + delta, count)

    -- Save position for current category BEFORE switching
    if instance.SaveListPosition then
        instance:SaveListPosition()
    end

    -- Flag to prevent onSelectedChanged from saving again
    NavState.StartCycling(state)

    -- Drive selection via tabBar if available
    if options.tabBar then
        options.tabBar:SetSelectedIndex(newIdx, true, true)
    else
        -- Manual update
        options.setCurrentIndex(newIdx)
        if options.onRefresh then
            options.onRefresh()
        end
    end

    NavState.StopCycling(state)
end

-- ============================================================================
-- COALESCED SELECTION HANDLER
-- ============================================================================

--[[
Function: BETTERUI.CIM.HeaderNavigation.CreateCoalescedHandler
Description: Creates a debounced onSelectedChanged callback for category headers.
Rationale: Prevents rapid navigation from triggering multiple refreshes.
Mechanism:
  1. Saves position before switch (unless already done by CycleCategory).
  2. Uses NavigationState for token-based coalescing.
  3. Waits for delay before applying the category change.
param: options (table) - Configuration:
  - delay: coalesce delay in ms (default: 100)
  - onSave: function(instance) → called to save position
  - onApply: function(instance, newIndex) → called to apply category
  - sceneCheck: function() → returns true if scene still visible
return: function(list, selectedData) - Callback for onSelectedChanged.
]]
--- @param options table Configuration options
--- @return function callback The debounced callback function
function BETTERUI.CIM.HeaderNavigation.CreateCoalescedHandler(options)
    local delay = options.delay or BETTERUI.CIM.CONST.TIMING.CATEGORY_CHANGE_DELAY_MS

    return function(instance, list, selectedData)
        local state = BETTERUI.CIM.HeaderNavigation.GetOrCreateState(instance)

        -- Skip during mode toggle or header suppression
        if NavState.ShouldSuppressCallback(state) then return end

        -- Save position BEFORE switching (unless CycleCategory already did)
        if not NavState.IsCycling(state) and options.onSave then
            options.onSave(instance)
        end

        -- Capture pending index - don't update immediately to prevent corruption
        local pendingCategoryIndex = list.selectedIndex or 1

        -- Start coalesced change using NavigationState
        local token = NavState.StartCategoryChange(state, pendingCategoryIndex)

        zo_callLater(function()
            -- Check if scene is still visible
            if options.sceneCheck and not options.sceneCheck() then
                NavState.CancelCategoryChange(state, token)
                return
            end

            -- Finish change if token is still valid
            if not NavState.FinishCategoryChange(state, token) then
                return -- Stale callback
            end

            if options.onApply then
                options.onApply(instance, pendingCategoryIndex)
            end
        end, delay)
    end
end
