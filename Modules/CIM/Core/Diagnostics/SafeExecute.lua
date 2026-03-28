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

---@param path string Dot-separated path relative to BETTERUI (e.g. "CIM.Font.DEFAULTS")
---@return any|nil value The resolved value, or nil if any segment is missing
function BETTERUI.CIM.TryResolve(path)
    local node = BETTERUI
    for segment in path:gmatch("[^%.]+") do
        node = node[segment]
        if node == nil then return nil end
    end
    return node
end

---@param path string Dot-separated path to a function on BETTERUI
---@param ... any Arguments to pass to the resolved function
---@return boolean ok true if the function was found and called
---@return any|nil result The function's return value, or nil if not found
function BETTERUI.CIM.TryCall(path, ...)
    local fn = BETTERUI.CIM.TryResolve(path)
    if type(fn) ~= "function" then return false, nil end
    return true, fn(...)
end
