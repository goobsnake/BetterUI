--[[
File: Modules/CIM/Core/Diagnostics/DebugInfo.lua
Purpose: Capture a call-site (file:line:function) for WARN/ERROR records using ONLY
         debug.traceback -- the one debug-library function ESO retail exposes to
         addons.

         VALIDATED addon-callable: BetterUI's own DebugCommands.lua already calls
         `debug.traceback("", 4)` in production. `debug.getinfo`/`getlocal` are NOT
         available in retail and are never used here.

LUA 5.1 GOTCHA (ESO's runtime, verified in-harness): the message arg MUST be a string.
  `debug.traceback(nil, level)` returns nil -- a non-string message is returned
  untouched by db_traceback -- so we pass "" (matching DebugCommands.lua), never nil.

CRITICAL usage rule:
  CaptureCallerFrame MUST be called SYNCHRONOUSLY on the caller's stack, before the
  log line is deferred via zo_callLater. If captured inside the deferred callback the
  stack only contains the logger/defer frames, not the original call site.

Cost: a traceback is string allocation + a stack walk. Only use on WARN/ERROR (low
  volume) and SafeExecute boundaries -- NEVER on DEBUG/INFO/TRACE hot paths. Everything
  is pcall-guarded and degrades to nil so it can never turn a log call into an error.
]]

BETTERUI.CIM = BETTERUI.CIM or {}

local DebugInfo = {}
BETTERUI.CIM.DebugInfo = DebugInfo
BETTERUI.DebugInfo = DebugInfo

local function G(name) return rawget(_G, name) end

local MAX_TRACE_CHARS = 1200
local MAX_FRAMES = 12

--- Whether debug.traceback is callable in this environment.
---@return boolean
function DebugInfo.HasTraceback()
    local dbg = G("debug")
    return type(dbg) == "table" and type(dbg.traceback) == "function"
end

--- Captured stack-trace text (guarded + capped). Returns trace, truncated or nil,false.
---@param startLevel number|nil  traceback start frame (default 2)
---@param maxChars number|nil
---@return string|nil trace, boolean truncated
function DebugInfo.Traceback(startLevel, maxChars)
    if not DebugInfo.HasTraceback() then return nil, false end
    local dbg = G("debug")
    -- "" (not nil): Lua 5.1 returns a non-string message untouched, so nil -> nil.
    local ok, tb = pcall(dbg.traceback, "", (type(startLevel) == "number") and startLevel or 2)
    if not ok or type(tb) ~= "string" then return nil, false end
    maxChars = (type(maxChars) == "number" and maxChars > 0) and maxChars or MAX_TRACE_CHARS
    if #tb > maxChars then return tb:sub(1, maxChars), true end
    return tb, false
end

-- Only the logger's OWN files are skipped so `src` points at the real caller.
-- CaptureCallerFrame runs synchronously on the caller's stack (before any defer), so no
-- zo_callLater/deferred frames are present to confuse the scan -- and skipping a literal
-- "zo_callLater" substring risks dropping a legitimate caller frame, so it's omitted.
local SKIP_PATTERNS = {
    "Diagnostics[/\\]Log%.lua",
    "Diagnostics[/\\]InterfaceLog%.lua",
    "Diagnostics[/\\]DebugInfo%.lua",
}

local function isLoggerFrame(line)
    for i = 1, #SKIP_PATTERNS do
        if line:find(SKIP_PATTERNS[i]) then return true end
    end
    return false
end

--- Synchronously capture the calling site as a compact `src` string, skipping logger
--- frames. e.g. "Modules/CIM/Core/Window/ControlUtils.lua:80:FindControl". Returns nil
--- when traceback is unavailable or no application frame parses.
--- MUST be called on the caller's stack (before any defer). NOT for hot paths.
---@param startLevel number|nil  traceback start frame (default 2)
---@return string|nil
function DebugInfo.CaptureCallerFrame(startLevel)
    if not DebugInfo.HasTraceback() then return nil end
    local dbg = G("debug")
    -- "" (not nil): Lua 5.1 returns a non-string message untouched, so nil -> nil.
    local ok, tb = pcall(dbg.traceback, "", (type(startLevel) == "number") and startLevel or 2)
    if not ok or type(tb) ~= "string" then return nil end
    if #tb > MAX_TRACE_CHARS then tb = tb:sub(1, MAX_TRACE_CHARS) end -- bound the scan

    local count = 0
    for line in tb:gmatch("[^\r\n]+") do
        count = count + 1
        if count > MAX_FRAMES then break end
        -- ESO frames look like: user:/AddOns/BetterUI/.../File.lua:123: in function 'Name'
        local path, lno = line:match("([%w_%.%-/\\]+%.lua):(%d+)")
        if path and not isLoggerFrame(line) then
            -- Normalize to a repo-relative path (strip everything up to BetterUI/).
            local rel = path:match("[Bb]etter[Uu][Ii][/\\](.+)$") or path
            rel = rel:gsub("\\", "/")
            local src = rel .. ":" .. lno
            local fn = line:match("in function ['\"<]([^'\">]+)")
            if fn and fn ~= "" then src = src .. ":" .. fn end
            return src
        end
    end
    return nil
end
