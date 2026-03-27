--[[
File: Modules/CIM/Core/SafeExecute.lua
Purpose: Provides safe execution wrapper for error-prone operations.
Author: BetterUI Team
Last Modified: 2026-01-29
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
-- See docs/TRIBAL_KNOWLEDGE.md "Error Handling Patterns" for SafeExecute vs guard clause guidance

--- @param context string Description of the operation for logging
--- @param fn function The function to execute
--- @param ... any Arguments to pass to the function
--- @return boolean success True if execution succeeded
--- @return any result The function result or error message
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

--- @param eventName string The event name for logging
--- @param callback function The callback to execute
--- @param ... any Arguments to pass to the callback
--- @return boolean success True if execution succeeded
--- @return any result The callback result or error message
function BETTERUI.CIM.SafeExecuteCallback(eventName, callback, ...)
    return BETTERUI.CIM.SafeExecute("Callback: " .. eventName, callback, ...)
end
