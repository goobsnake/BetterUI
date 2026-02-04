--[[
File: Modules/CIM/Core/HoldKeybindWrapper.lua
Purpose: Provides timer-based hold detection for keybind descriptors.
         ESO's ZO_KeybindStrip does not natively support hold actions,
         so this wrapper adds that capability using handlesKeyUp + zo_callLater.
Author: BetterUI Team
Last Modified: 2026-02-03
]]

--------------------------------------------------------------------------------
-- NAMESPACE SETUP
--------------------------------------------------------------------------------

BETTERUI.CIM.HoldKeybindWrapper = {}
local HoldKeybindWrapper = BETTERUI.CIM.HoldKeybindWrapper

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

-- Default hold duration in milliseconds
HoldKeybindWrapper.DEFAULT_HOLD_DURATION = 500

--------------------------------------------------------------------------------
-- HOLD STATE TRACKING
--------------------------------------------------------------------------------

-- Table to track active hold timers by keybind name
local activeHoldTimers = {}

-- Table to track whether a hold action was triggered (to prevent tap on release)
local holdTriggered = {}

--------------------------------------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------------------------------------

--[[
Function: CancelHoldTimer
Description: Cancels any pending hold timer for a keybind.
Rationale: Prevents timer from firing after key release or scene exit.
]]
local function CancelHoldTimer(keybind)
    if activeHoldTimers[keybind] then
        zo_removeCallLater(activeHoldTimers[keybind])
        activeHoldTimers[keybind] = nil
    end
end

--[[
Function: ResetHoldState
Description: Resets all hold state for a keybind.
Rationale: Clean state needed when exiting scenes or on key release.
]]
local function ResetHoldState(keybind)
    CancelHoldTimer(keybind)
    holdTriggered[keybind] = nil
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--[[
Function: HoldKeybindWrapper.Wrap
Description: Wraps a keybind descriptor to add timer-based hold detection.
Rationale: ESO's ZO_KeybindStrip doesn't support hold actions natively.
           This wrapper intercepts key down/up events and uses timers to
           distinguish between tap (quick press) and hold (long press).
Mechanism:
    1. On key down: Start timer with holdDuration
    2. If timer fires before key up: Call holdCallback, mark as triggered
    3. On key up: Cancel timer
       - If hold was triggered: Optionally call holdReleaseCallback
       - If not triggered: Call original callback (tap action)
References: Called when building keybind descriptors in InventoryKeybinds.lua

@param descriptor table The keybind descriptor to wrap
    Required fields:
        keybind: string - The keybind action name
        callback: function - The tap action callback
    Optional fields:
        holdCallback: function - Called after holding for holdDuration
        holdDuration: number - Hold threshold in ms (default 500)
        holdReleaseCallback: function - Called on key up after hold triggered
@return table wrappedDescriptor The wrapped descriptor ready for ZO_KeybindStrip
]]
function HoldKeybindWrapper.Wrap(descriptor)
    if not descriptor then return nil end
    if not descriptor.keybind then return descriptor end

    local keybind = descriptor.keybind
    local originalCallback = descriptor.callback
    local holdCallback = descriptor.holdCallback
    local holdDuration = descriptor.holdDuration or HoldKeybindWrapper.DEFAULT_HOLD_DURATION
    local holdReleaseCallback = descriptor.holdReleaseCallback

    -- If no hold callback, just return original descriptor
    if not holdCallback then
        return descriptor
    end

    -- Create wrapped descriptor
    local wrapped = {}
    for k, v in pairs(descriptor) do
        wrapped[k] = v
    end

    -- Enable key up handling
    wrapped.handlesKeyUp = true

    -- Replace callback with hold-aware version
    wrapped.callback = function(isUp)
        if isUp then
            -- Key released
            local wasHoldTriggered = holdTriggered[keybind]
            ResetHoldState(keybind)

            if wasHoldTriggered then
                -- Hold was triggered - optionally call release callback
                if holdReleaseCallback then
                    holdReleaseCallback()
                end
            else
                -- Quick tap - call original callback
                if originalCallback then
                    originalCallback()
                end
            end
        else
            -- Key pressed - start hold timer
            ResetHoldState(keybind)

            activeHoldTimers[keybind] = zo_callLater(function()
                activeHoldTimers[keybind] = nil
                holdTriggered[keybind] = true
                if holdCallback then
                    holdCallback()
                end
            end, holdDuration)
        end
    end

    -- Remove custom properties that ZO_KeybindStrip doesn't understand
    wrapped.holdCallback = nil
    wrapped.holdDuration = nil
    wrapped.holdReleaseCallback = nil

    return wrapped
end

--[[
Function: HoldKeybindWrapper.CancelAll
Description: Cancels all pending hold timers and resets state.
Rationale: Must be called when hiding scenes to prevent orphaned timers.
References: Called from OnHidden handlers in Inventory/Banking modules
]]
function HoldKeybindWrapper.CancelAll()
    for keybind, _ in pairs(activeHoldTimers) do
        ResetHoldState(keybind)
    end
end

--[[
Function: HoldKeybindWrapper.Cancel
Description: Cancels hold timer and state for a specific keybind.
Rationale: Allows targeted cleanup for specific keybinds.
@param keybind string The keybind action name
]]
function HoldKeybindWrapper.Cancel(keybind)
    ResetHoldState(keybind)
end
