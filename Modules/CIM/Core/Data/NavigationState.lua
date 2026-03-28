--[[
File: Modules/CIM/Core/NavigationState.lua
Purpose: Provides a structured state object for category navigation.
         Replaces scattered boolean flags with a consolidated state machine.
]]

-- ============================================================================
-- NAMESPACE INITIALIZATION
-- ============================================================================

BETTERUI.CIM = BETTERUI.CIM or {}

--[[
Table: BETTERUI.CIM.NavigationState
Description: Factory for navigation state objects.
             Used by HeaderNavigation to manage category change coordination.
Rationale: Eliminates flag sprawl (6+ boolean flags) with a structured state object.
Used By: HeaderNavigation.CycleCategory, CreateCoalescedHandler
]]
BETTERUI.CIM.NavigationState = {}

-- ============================================================================
-- STATE FACTORY
-- ============================================================================

--- @return {changeToken: number, pendingCategoryIndex: number|nil, suppressListUpdates: boolean, suppressListUpdatesToken: number|nil, suppressHeaderCallback: boolean, isCyclingCategory: boolean, justToggledMode: boolean} state New navigation state object
function BETTERUI.CIM.NavigationState.Create()
    return {
        -- Token for coalescing category changes (incremented each change)
        changeToken = 0,

        -- Pending category index during coalescing
        pendingCategoryIndex = nil,

        -- Suppression flags
        suppressListUpdates = false,
        suppressListUpdatesToken = nil,
        suppressHeaderCallback = false,

        -- Transition flags
        isCyclingCategory = false,
        justToggledMode = false,
    }
end

-- ============================================================================
-- STATE TRANSITIONS
-- ============================================================================

--- @param state table The navigation state object
--- @param newIndex number The pending category index
--- @return number token The token for this change
function BETTERUI.CIM.NavigationState.StartCategoryChange(state, newIndex)
    state.changeToken = state.changeToken + 1
    state.pendingCategoryIndex = newIndex
    state.suppressListUpdates = true
    state.suppressListUpdatesToken = state.changeToken
    return state.changeToken
end

--- @param state table The navigation state object
--- @param token number The token from StartCategoryChange
--- @return boolean isValid True if this was the latest change
function BETTERUI.CIM.NavigationState.FinishCategoryChange(state, token)
    if token ~= state.changeToken then
        return false -- Stale callback
    end

    if state.suppressListUpdates and state.suppressListUpdatesToken == token then
        state.suppressListUpdates = false
        state.suppressListUpdatesToken = nil
    end

    state.pendingCategoryIndex = nil
    return true
end

--- @param state table The navigation state object
--- @param token number The token to validate against
--- @return boolean cancelled True if cancelled, false if token was stale
function BETTERUI.CIM.NavigationState.CancelCategoryChange(state, token)
    if state.suppressListUpdatesToken == token then
        state.suppressListUpdates = false
        state.suppressListUpdatesToken = nil
        state.pendingCategoryIndex = nil
        return true
    end
    return false
end

--- @param state table The navigation state object
--- @param token number The token to validate
--- @return boolean isValid True if token matches current change token
function BETTERUI.CIM.NavigationState.IsChangeValid(state, token)
    return token == state.changeToken
end

-- ============================================================================
-- CYCLING STATE HELPERS
-- ============================================================================

--- @param state table The navigation state object
function BETTERUI.CIM.NavigationState.StartCycling(state)
    state.isCyclingCategory = true
end

--- @param state table The navigation state object
function BETTERUI.CIM.NavigationState.StopCycling(state)
    state.isCyclingCategory = false
end

--- @param state table The navigation state object
--- @param value boolean Whether mode was just toggled
function BETTERUI.CIM.NavigationState.SetModeToggle(state, value)
    state.justToggledMode = value
end

-- ============================================================================
-- QUERY HELPERS
-- ============================================================================

--- @param state table The navigation state object
--- @return boolean shouldSuppress True if callbacks should be skipped
function BETTERUI.CIM.NavigationState.ShouldSuppressCallback(state)
    return state.justToggledMode or state.suppressHeaderCallback
end

--- @param state table The navigation state object
--- @return boolean isCycling True if currently cycling via LB/RB
function BETTERUI.CIM.NavigationState.IsCycling(state)
    return state.isCyclingCategory
end
