--[[
Purpose: Provides safe execution wrapper for error-prone operations.
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
-- See docs/TRIBAL_KNOWLEDGE.md "Error Handling Patterns" for SafeExecute vs guard clause guidance

-- tostring that can never raise (a caught error value may be a table with a hostile
-- __tostring -- the error handler itself must honour SafeExecute's never-raise contract).
local function safeStr(v, fallback)
    local ok, s = pcall(tostring, v)
    if ok and type(s) == "string" then return s end
    return fallback or "<?>"
end

-- Route a SAFE-category error through the unified logger when present (guarded so a
-- partially-loaded logger can't raise from the error handler), else the legacy Debug seam.
local function logSafeError(context, msg, src)
    local L = BETTERUI.Log
    if L and type(L.Error) == "function" then
        local category = (L.CATEGORY and L.CATEGORY.SAFE) or "SAFE"
        pcall(L.Error, category, string.format("%s: %s", context, msg), src and { src = src } or nil)
    elseif type(BETTERUI.Debug) == "function" then
        BETTERUI.Debug(string.format("[Error] %s: %s", context, msg))
    end
end

local function normalizeLuaSrc(path, lno)
    if not path then return nil end
    return ((path:match("[Bb]etter[Uu][Ii][/\\](.+)$") or path):gsub("\\", "/")) .. ":" .. lno
end

local function srcFromErrorMessage(msg)
    local path, lno = msg:match("^(.-%.lua):(%d+):")
    return normalizeLuaSrc(path, lno)
end

local function srcFromSafeExecuteBoundary()
    local debugInfo = BETTERUI.CIM and BETTERUI.CIM.DebugInfo
    if not (debugInfo and type(debugInfo.CaptureCallerFrame) == "function") then
        return nil
    end
    local ok, src = pcall(debugInfo.CaptureCallerFrame, 3, {
        "Diagnostics[/\\]SafeExecute%.lua",
    })
    return ok and src or nil
end

---@param context string Descriptive label for error messages
---@param fn function|nil The function to execute safely
---@param ... any Arguments to pass to fn
---@return boolean ok true if fn executed without error
---@return any result fn's return value on success, or error message on failure
function BETTERUI.CIM.SafeExecute(context, fn, ...)
    if not fn then
        logSafeError(context, "No function provided", nil)
        return false, "No function provided"
    end

    -- Call pcall directly with the varargs: packing into a table and unpack(args) would
    -- truncate argument lists containing embedded nils. Keeps the hot SUCCESS path
    -- allocation-free (no xpcall/closure).
    local ok, result = pcall(fn, ...)

    if not ok then
        -- Surface the caught error through the unified logger: ERROR level -> Interface.log
        -- when logging is active (so swallowed faults stop being invisible). Inert (silent)
        -- for normal players with logging disabled, preserving the legacy swallow behavior.
        local msg = safeStr(result, "<error>")
        -- Lift the boundary fault location: Lua error() prefixes the message with
        -- "<file>.lua:<line>: " at the START, so anchor to ^ (never capture a .lua:line that
        -- appears LATER in the message), and allow spaces/parens in the path. For
        -- error(table) / engine errors without a leading prefix, fall back to the
        -- SafeExecute call boundary so swallowed faults still have a navigable src.
        local src = srcFromErrorMessage(msg) or srcFromSafeExecuteBoundary()
        logSafeError(context, msg, src)
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
    if not ok and result == "optional_path_missing" and type(BETTERUI.Debug) == "function" then
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
    -- Guard the ESO globals (rawget + pcall): these run from error paths and may be called
    -- pre-load or in a test harness where GetString/ZO_Alert/SOUNDS don't exist yet.
    local getString = rawget(_G, "GetString")
    local resolvedMessage = message
    if type(message) == "number" and type(getString) == "function" then
        local okS, s = pcall(getString, message) -- a bad string id must not raise the error path
        if okS then resolvedMessage = s end
    end
    if type(BETTERUI.Debug) == "function" then
        local okT, t = pcall(tostring, resolvedMessage)
        BETTERUI.Debug(string.format("[UserNotify] %s: %s", context, (okT and t) or "<?>"))
    end
    local alert = rawget(_G, "ZO_Alert")
    if type(alert) == "function" then
        local sounds = rawget(_G, "SOUNDS")
        -- Pass the raw message/string-id to ZO_Alert: it resolves string ids internally.
        pcall(alert, rawget(_G, "UI_ALERT_CATEGORY_ERROR"), sound or (sounds and sounds.NEGATIVE_CLICK), message)
    end
end

--- Unified user-facing informational notification (non-error).
--- Wraps ZO_AlertNoSuppression for consistent logging of user feedback.
---@param context string Descriptive label for logging (e.g., "Buy:CannotAfford")
---@param messageText string The user-facing alert message text
---@param sound? number Sound constant (default: nil for silent)
function BETTERUI.CIM.UserAlertText(context, messageText, sound)
    if type(BETTERUI.Debug) == "function" then
        local okT, t = pcall(tostring, messageText)
        BETTERUI.Debug(string.format("[UserAlert] %s: %s", context, (okT and t) or "<?>"))
    end
    local alert = rawget(_G, "ZO_AlertNoSuppression")
    if type(alert) == "function" then
        pcall(alert, rawget(_G, "UI_ALERT_CATEGORY_ALERT"), sound, messageText)
    end
end
