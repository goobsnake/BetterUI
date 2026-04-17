--[[
Purpose: Provides safe execution wrapper for error-prone operations.
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
-- See docs/TRIBAL_KNOWLEDGE.md "Error Handling Patterns" for SafeExecute vs guard clause guidance

---@param context string Descriptive label for error messages
---@param fn function|nil The function to execute safely
---@param ... any Arguments to pass to fn
---@return boolean ok true if fn executed without error
---@return any result fn's return value on success, or error message on failure
function BETTERUI.CIM.SafeExecute(context, fn, ...)
    if not fn then
        BETTERUI.Debug(string.format("[Error] %s: No function provided", context))
        return false, "No function provided"
    end

    local args = { ... }
    local ok, result = pcall(function()
        return fn(unpack(args))
    end)

    if not ok then
        BETTERUI.Debug(string.format("[Error] %s: %s", context, tostring(result)))
    end

    return ok, result
end

---@param eventName string Event name for error context
---@param callback function|nil The callback to execute
---@param ... any Arguments to pass to callback
---@return boolean ok
---@return any result
function BETTERUI.CIM.SafeExecuteCallback(eventName, callback, ...)
    return BETTERUI.CIM.SafeExecute("Callback: " .. eventName, callback, ...)
end

---@param path string Dot-separated path relative to BETTERUI for optional lookup only (e.g. "ExternalAddon.Callback")
---@return any|nil value The resolved value, or nil if any segment is missing
local function ResolveOptionalBetterUIPath(path)
    local node = BETTERUI
    for segment in path:gmatch("[^%.]+") do
        node = node[segment]
        if node == nil then return nil end
    end
    return node
end

---@param path string Dot-separated path to an optional function on BETTERUI
---@param ... any Arguments to pass to the resolved function
---@return boolean ok true if the function was found and called
---@return any|nil result The function's return value, or nil if not found
local function CallOptionalBetterUIPath(path, ...)
    local fn = ResolveOptionalBetterUIPath(path)
    if type(fn) ~= "function" then return false, nil end
    return true, fn(...)
end

--- Optional add-on dispatch helper for BETTERUI path lookups.
--- Stable internal BetterUI seams should be invoked directly instead of by string path.
--- Unlike SafeExecute, this only skips missing targets; it does not wrap errors.
---@param path string Dot-separated path to an optional function on BETTERUI
---@param ... any Arguments to pass to the resolved function
---@return boolean ok true if the function was found and called
---@return any|nil result The function's return value, or nil if not found
function BETTERUI.CIM.SafeCall(path, ...)
    return CallOptionalBetterUIPath(path, ...)
end

--- Unified user-facing error notification with structured logging.
--- Combines ZO_Alert for user feedback with SafeExecute infrastructure for logging.
--- Use this instead of calling ZO_Alert(UI_ALERT_CATEGORY_ERROR, ...) directly.
---@param context string Descriptive label for error logging (e.g., "EquipAction:Equip")
---@param messageStringId number String ID for the user-facing alert message
---@param sound? number Sound constant (default: SOUNDS.NEGATIVE_CLICK)
function BETTERUI.CIM.UserNotify(context, messageStringId, sound)
    BETTERUI.Debug(string.format("[UserNotify] %s: %s", context, tostring(GetString(messageStringId))))
    ZO_Alert(UI_ALERT_CATEGORY_ERROR, sound or SOUNDS.NEGATIVE_CLICK, messageStringId)
end

--- Unified user-facing error notification for pre-resolved text strings.
--- Use when the error message is already a string (e.g., from IsEquipable's error return).
---@param context string Descriptive label for error logging
---@param messageText string The user-facing alert message text
---@param sound? number Sound constant (default: SOUNDS.NEGATIVE_CLICK)
function BETTERUI.CIM.UserNotifyText(context, messageText, sound)
    BETTERUI.Debug(string.format("[UserNotify] %s: %s", context, tostring(messageText)))
    ZO_Alert(UI_ALERT_CATEGORY_ERROR, sound or SOUNDS.NEGATIVE_CLICK, messageText)
end

--- Unified user-facing informational notification (non-error).
--- Wraps ZO_AlertNoSuppression for consistent logging of user feedback.
---@param context string Descriptive label for logging (e.g., "Buy:CannotAfford")
---@param messageText string The user-facing alert message text
---@param sound? number Sound constant (default: nil for silent)
function BETTERUI.CIM.UserAlertText(context, messageText, sound)
    BETTERUI.Debug(string.format("[UserAlert] %s: %s", context, tostring(messageText)))
    ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, sound, messageText)
end
