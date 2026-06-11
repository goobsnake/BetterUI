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

    -- Call pcall directly with the varargs: packing into a table and
    -- unpack(args) would truncate argument lists containing embedded nils.
    local ok, result = pcall(fn, ...)

    if not ok then
        BETTERUI.Debug(string.format("[Error] %s: %s", context, tostring(result)))
    end

    return ok, result
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
    if type(fn) ~= "function" then
        return false, "optional_path_missing"
    end

    return BETTERUI.CIM.SafeExecute("OptionalPath: " .. path, fn, ...)
end

---@param context string Descriptive label for logging
---@param path string Dot-separated path to an optional function on BETTERUI
---@param ... any Arguments to pass to the resolved function
---@return boolean ok true when the function exists and executes without error
---@return any result Function return value, missing-path reason, or error text
function BETTERUI.CIM.SafeExecuteOptionalPath(context, path, ...)
    local ok, result = CallOptionalBetterUIPath(path, ...)
    if not ok and result == "optional_path_missing" and BETTERUI.Debug then
        BETTERUI.Debug(string.format("[Warn] %s: Optional path missing (%s)", context, tostring(path)))
    end
    return ok, result
end

--- Unified user-facing error notification with structured logging.
--- Accepts either a string ID or pre-resolved text so callers do not need a
--- second text-only helper for the same error path.
---@param context string Descriptive label for error logging (e.g., "EquipAction:Equip")
---@param message number|string String ID or resolved alert message text
---@param sound? number Sound constant (default: SOUNDS.NEGATIVE_CLICK)
function BETTERUI.CIM.UserNotify(context, message, sound)
    local resolvedMessage = type(message) == "number" and GetString(message) or message
    BETTERUI.Debug(string.format("[UserNotify] %s: %s", context, tostring(resolvedMessage)))
    ZO_Alert(UI_ALERT_CATEGORY_ERROR, sound or SOUNDS.NEGATIVE_CLICK, message)
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
