--[[
File: Modules/CIM/Core/NavigationState.lua
Purpose: Provides a structured state object for category navigation.
         Replaces scattered boolean flags with a consolidated state machine.
Author: BetterUI Team
Last Modified: 2026-01-28
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

--[[
Function: BETTERUI.CIM.NavigationState.Create
Description: Creates a new navigation state object for a module instance.
return: table - A navigation state object with methods for state transitions.
]]
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

--[[
Function: BETTERUI.CIM.NavigationState.StartCategoryChange
Description: Begins a category change, setting up coalescing state.
param: state (table) - The navigation state object.
param: newIndex (number) - The pending category index.
return: number - The token for this change (used to validate callbacks).
]]
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

--[[
Function: BETTERUI.CIM.NavigationState.FinishCategoryChange
Description: Completes a category change if the token is still valid.
param: state (table) - The navigation state object.
param: token (number) - The token from StartCategoryChange.
return: boolean - True if this was the latest change (still valid).
]]
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

--[[
Function: BETTERUI.CIM.NavigationState.CancelCategoryChange
Description: Cancels a pending category change (e.g., scene hidden).
param: state (table) - The navigation state object.
param: token (number) - The token to validate against.
return: boolean - True if cancelled, false if token was stale.
]]
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

--[[
Function: BETTERUI.CIM.NavigationState.IsChangeValid
Description: Checks if a change token is still the current one.
param: state (table) - The navigation state object.
param: token (number) - The token to validate.
return: boolean - True if token matches current change token.
]]
--- @param state table The navigation state object
--- @param token number The token to validate
--- @return boolean isValid True if token matches current change token
function BETTERUI.CIM.NavigationState.IsChangeValid(state, token)
    return token == state.changeToken
end

-- ============================================================================
-- CYCLING STATE HELPERS
-- ============================================================================

--[[
Function: BETTERUI.CIM.NavigationState.StartCycling
Description: Sets cycling flag (during LB/RB navigation).
param: state (table) - The navigation state object.
]]
--- @param state table The navigation state object
function BETTERUI.CIM.NavigationState.StartCycling(state)
    state.isCyclingCategory = true
end

--[[
Function: BETTERUI.CIM.NavigationState.StopCycling
Description: Clears cycling flag.
param: state (table) - The navigation state object.
]]
--- @param state table The navigation state object
function BETTERUI.CIM.NavigationState.StopCycling(state)
    state.isCyclingCategory = false
end

--[[
Function: BETTERUI.CIM.NavigationState.SetModeToggle
Description: Sets mode toggle flag (during Withdraw/Deposit toggle).
param: state (table) - The navigation state object.
param: value (boolean) - Whether mode was just toggled.
]]
--- @param state table The navigation state object
--- @param value boolean Whether mode was just toggled
function BETTERUI.CIM.NavigationState.SetModeToggle(state, value)
    state.justToggledMode = value
end

-- ============================================================================
-- QUERY HELPERS
-- ============================================================================

--[[
Function: BETTERUI.CIM.NavigationState.ShouldSuppressCallback
Description: Checks if callbacks should be suppressed based on current state.
param: state (table) - The navigation state object.
return: boolean - True if callbacks should be skipped.
]]
--- @param state table The navigation state object
--- @return boolean shouldSuppress True if callbacks should be skipped
function BETTERUI.CIM.NavigationState.ShouldSuppressCallback(state)
    return state.justToggledMode or state.suppressHeaderCallback
end

--[[
Function: BETTERUI.CIM.NavigationState.IsCycling
Description: Returns whether category cycling is in progress.
param: state (table) - The navigation state object.
return: boolean - True if currently cycling via LB/RB.
]]
--- @param state table The navigation state object
--- @return boolean isCycling True if currently cycling via LB/RB
function BETTERUI.CIM.NavigationState.IsCycling(state)
    return state.isCyclingCategory
end
