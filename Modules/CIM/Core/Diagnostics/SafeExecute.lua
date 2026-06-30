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

local function now()
    local clock = rawget(_G, "GetGameTimeMilliseconds")
    if type(clock) == "function" then
        local ok, value = pcall(clock)
        if ok and type(value) == "number" then return value end
    end
    return math.floor((os.clock and os.clock() or 0) * 1000)
end

local function IsBuilogEnabled()
    local interfaceLog = BETTERUI.CIM and BETTERUI.CIM.InterfaceLog
    return interfaceLog and interfaceLog.IsEnabled and interfaceLog.IsEnabled() == true
end

local function raiseNativeError(context, msg, src)
    local message = string.format("%s: %s", context, msg)
    if src then
        message = message .. "\n" .. src
    end

    if type(BETTERUI.RaiseNativeError) == "function" then
        return BETTERUI.RaiseNativeError(message)
    end

    local defer = rawget(_G, "zo_callLater")
    if type(defer) == "function" then
        defer(function() error("[BETTERUI] " .. message, 0) end, 0)
        return true
    end
    return false
end

-- Route a SAFE-category error through builog when active, otherwise surface the
-- caught fault through the native Lua error popup path.
local function logSafeError(context, msg, src)
    local L = BETTERUI.Log
    if IsBuilogEnabled() and L and type(L.Error) == "function" then
        local category = (L.CATEGORY and L.CATEGORY.SAFE) or "SAFE"
        pcall(L.Error, category, string.format("%s: %s", context, msg), src and { src = src } or nil)
        return
    end

    if IsBuilogEnabled() then
        local interfaceLog = BETTERUI.CIM and BETTERUI.CIM.InterfaceLog
        if interfaceLog and type(interfaceLog.Write) == "function" then
            pcall(interfaceLog.Write, string.format("%s: %s", context, msg))
            return
        end
    end

    raiseNativeError(context, msg, src)
end

local function logSafeSuccess(context, elapsedMs, result)
    local L = BETTERUI.Log
    if not (L and type(L.TraceEvent) == "function") then return end
    local categories = L.CATEGORY or {}
    local resultType = type(result)
    pcall(L.TraceEvent, categories.SAFE or "SAFE", "safe_execute", "success", {
        context = context,
        elapsedMs = elapsedMs,
        resultType = resultType,
        result = resultType ~= "table" and safeStr(result, "<?>") or "<table>",
    })
end

local function SafeSuccessTraceEnabled()
    local L = BETTERUI.Log
    if not (L and type(L.TraceEvent) == "function") then return false end
    if type(L.EnabledFor) == "function" then
        local category = (L.CATEGORY and L.CATEGORY.SAFE) or "SAFE"
        local level = L.LEVEL and L.LEVEL.DEBUG or nil
        if level ~= nil then
            return L.EnabledFor(level, category)
        end
    end
    if type(L.IsActive) == "function" then
        return L.IsActive()
    end
    return true
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
    local traceSuccess = SafeSuccessTraceEnabled()
    local startMs = traceSuccess and now() or nil
    local ok, result = pcall(fn, ...)
    local elapsedMs = traceSuccess and (now() - startMs) or nil

    if not ok then
        -- Surface the caught error through builog when active; otherwise schedule a
        -- native Lua error so normal players get ESO's standard error popup.
        local msg = safeStr(result, "<error>")
        -- Lift the boundary fault location: Lua error() prefixes the message with
        -- "<file>.lua:<line>: " at the START, so anchor to ^ (never capture a .lua:line that
        -- appears LATER in the message), and allow spaces/parens in the path. For
        -- error(table) / engine errors without a leading prefix, fall back to the
        -- SafeExecute call boundary so caught faults still have a navigable src.
        local src = srcFromErrorMessage(msg) or srcFromSafeExecuteBoundary()
        logSafeError(context, msg, src)
    elseif traceSuccess then
        logSafeSuccess(context, elapsedMs, result)
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
