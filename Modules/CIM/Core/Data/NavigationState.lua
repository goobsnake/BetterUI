--[[
File: Modules/CIM/Core/Data/NavigationState.lua
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
---@class BETTERUI.CIM.NavigationState
---@field Create fun(): NavigationStateData
---@field StartCategoryChange fun(state: NavigationStateData, newIndex: number): number
---@field FinishCategoryChange fun(state: NavigationStateData, token: number): boolean
---@field CancelCategoryChange fun(state: NavigationStateData, token: number): boolean
---@field IsChangeValid fun(state: NavigationStateData, token: number): boolean
BETTERUI.CIM.NavigationState = {}

---@class NavigationStateData
---@field changeToken number Monotonically increasing token for coalescing
---@field pendingCategoryIndex number|nil Pending category index during coalescing
---@field suppressListUpdates boolean Whether list updates are suppressed
---@field suppressListUpdatesToken number|nil Token associated with suppression
---@field suppressHeaderCallback boolean Whether header callback is suppressed
---@field isCyclingCategory boolean Whether a category cycle is in progress
---@field justToggledMode boolean Whether mode was just toggled

-- STATE FACTORY

---@return NavigationStateData
function BETTERUI.CIM.NavigationState.Create()
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.NAV, "navStateCreate") end
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

---@param state NavigationStateData
---@param newIndex number New category index
---@return number token Change token for this transition
function BETTERUI.CIM.NavigationState.StartCategoryChange(state, newIndex)
    state.changeToken = state.changeToken + 1
    state.pendingCategoryIndex = newIndex
    state.suppressListUpdates = true
    state.suppressListUpdatesToken = state.changeToken
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.NAV, "startCategoryChange", { token = state.changeToken, newIndex = newIndex }) end
    return state.changeToken
end

---@param state NavigationStateData
---@param token number Token from StartCategoryChange
---@return boolean success True if the finish matched the current token
function BETTERUI.CIM.NavigationState.FinishCategoryChange(state, token)
    local success = token == state.changeToken
    if success then
        if state.suppressListUpdates and state.suppressListUpdatesToken == token then
            state.suppressListUpdates = false
            state.suppressListUpdatesToken = nil
        end
        state.pendingCategoryIndex = nil
    end
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.NAV, "finishCategoryChange", { token = token, success = success }) end
    return success
end

---@param state NavigationStateData
---@param token number Token from StartCategoryChange
---@return boolean cancelled True if the cancellation was valid
function BETTERUI.CIM.NavigationState.CancelCategoryChange(state, token)
    local success = state.suppressListUpdatesToken == token
    if success then
        state.suppressListUpdates = false
        state.suppressListUpdatesToken = nil
        state.pendingCategoryIndex = nil
    end
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.NAV, "cancelCategoryChange", { token = token, success = success }) end
    return success
end

---@param state NavigationStateData
---@param token number Token to validate
---@return boolean valid True if token matches current changeToken
function BETTERUI.CIM.NavigationState.IsChangeValid(state, token)
    local valid = token == state.changeToken
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.NAV, "isChangeValid", { token = token, valid = valid }) end
    return valid
end

-- CYCLING STATE HELPERS

---@param state NavigationStateData
function BETTERUI.CIM.NavigationState.StartCycling(state)
    state.isCyclingCategory = true
end

---@param state NavigationStateData
function BETTERUI.CIM.NavigationState.StopCycling(state)
    state.isCyclingCategory = false
end

---@param state NavigationStateData
---@param value boolean
function BETTERUI.CIM.NavigationState.SetModeToggle(state, value)
    state.justToggledMode = value
end

-- QUERY HELPERS

---@param state NavigationStateData
---@return boolean
function BETTERUI.CIM.NavigationState.ShouldSuppressCallback(state)
    return state.justToggledMode or state.suppressHeaderCallback
end

---@param state NavigationStateData
---@return boolean
function BETTERUI.CIM.NavigationState.IsCycling(state)
    return state.isCyclingCategory
end
