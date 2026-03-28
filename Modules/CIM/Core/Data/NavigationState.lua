--[[
File: Modules/CIM/Core/NavigationState.lua
Purpose: Provides a structured state object for category navigation.
         Replaces scattered boolean flags with a consolidated state machine.
]]

-- NAMESPACE INITIALIZATION

BETTERUI.CIM = BETTERUI.CIM or {}

--[[
Table: BETTERUI.CIM.NavigationState
Description: Factory for navigation state objects.
             Used by HeaderNavigation to manage category change coordination.
Rationale: Eliminates flag sprawl (6+ boolean flags) with a structured state object.
Used By: HeaderNavigation.CycleCategory, CreateCoalescedHandler
]]
BETTERUI.CIM.NavigationState = {}

-- STATE FACTORY

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

-- STATE TRANSITIONS

function BETTERUI.CIM.NavigationState.StartCategoryChange(state, newIndex)
    state.changeToken = state.changeToken + 1
    state.pendingCategoryIndex = newIndex
    state.suppressListUpdates = true
    state.suppressListUpdatesToken = state.changeToken
    return state.changeToken
end

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

function BETTERUI.CIM.NavigationState.CancelCategoryChange(state, token)
    if state.suppressListUpdatesToken == token then
        state.suppressListUpdates = false
        state.suppressListUpdatesToken = nil
        state.pendingCategoryIndex = nil
        return true
    end
    return false
end

function BETTERUI.CIM.NavigationState.IsChangeValid(state, token)
    return token == state.changeToken
end

-- CYCLING STATE HELPERS

function BETTERUI.CIM.NavigationState.StartCycling(state)
    state.isCyclingCategory = true
end

function BETTERUI.CIM.NavigationState.StopCycling(state)
    state.isCyclingCategory = false
end

function BETTERUI.CIM.NavigationState.SetModeToggle(state, value)
    state.justToggledMode = value
end

-- QUERY HELPERS

function BETTERUI.CIM.NavigationState.ShouldSuppressCallback(state)
    return state.justToggledMode or state.suppressHeaderCallback
end

function BETTERUI.CIM.NavigationState.IsCycling(state)
    return state.isCyclingCategory
end
