--[[
File: Modules/CIM/Core/Diagnostics/Perf.lua
Purpose: Lightweight performance markers. Time a span and emit a DEBUG/PERF record
         ("<label> took <ms>ms" + optional fields) so a log reader can see WHICH
         operations are slow during a capture, not just that the client hitched.

         Gated by Log.EnabledFor(DEBUG, PERF): when PERF logging is off, Perf.Begin
         returns nil and the only cost on a hot path is that one gate check -- no clock
         read, no table, no record. Pair Perf.Begin/Perf.End, or wrap with Perf.Measure.
         Everything is pcall-guarded and depends only on BETTERUI.Log (loaded first).
]]

BETTERUI.CIM = BETTERUI.CIM or {}

local Perf = {}
BETTERUI.CIM.Perf = Perf
BETTERUI.Perf = Perf

local function G(name) return rawget(_G, name) end
-- Always returns a number (0 if the clock is unavailable / misbehaves), so elapsed math
-- can never raise or produce a non-number.
local function now()
    local c = G("GetGameTimeMilliseconds")
    if type(c) ~= "function" then return 0 end
    local ok, v = pcall(c)
    return (ok and type(v) == "number") and v or 0
end

--- Start timing a span. Returns an opaque token for Perf.End, or nil when PERF logging is
--- off (so a hot path pays only the gate check). Pair with Perf.End.
---@param label string
---@return table|nil token
function Perf.Begin(label)
    local L = BETTERUI.Log
    if not (L and L.EnabledFor and L.EnabledFor(L.LEVEL.DEBUG, L.CATEGORY.PERF)) then return nil end
    return { label = tostring(label or "span"), t0 = now() }
end

--- Finish timing a span started by Perf.Begin. No-ops on a nil token (PERF was off at
--- Begin). Emits a DEBUG/PERF record "<label> took <ms>ms" with optional fields merged in.
---@param token table|nil
---@param data table|nil
function Perf.End(token, data)
    local L = BETTERUI.Log
    local function TraceEndError(reason, extra)
        if not (L and L.TraceEvent) then return end
        extra = extra or {}
        extra.reason = reason
        extra.tokenPresent = token ~= nil
        extra.tokenType = type(token)
        local categories = L.CATEGORY or {}
        L.TraceEvent(categories.PERF or "PERF", "perf.span", "end_error", extra)
    end
    if type(token) ~= "table" or type(token.t0) ~= "number" then
        if token ~= nil then TraceEndError("invalidToken") end
        return
    end
    if token.finished then
        TraceEndError("alreadyFinished", { label = token.label, ageMs = now() - token.t0 })
        return
    end
    token.finished = true -- consume the token so a double-End can't emit a duplicate timing
    if not (L and L.Debug) then
        TraceEndError("loggerUnavailable", { label = token.label })
        return
    end
    local ms = now() - token.t0
    if ms < 0 then ms = 0 end -- a clock that went backwards / disappeared must not emit junk
    local payload = { ms = ms }
    if type(data) == "table" then for k, v in pairs(data) do payload[k] = v end end
    pcall(L.Debug, L.CATEGORY.PERF, token.label .. " took " .. tostring(ms) .. "ms", payload)
end

--- Convenience: time fn(...) and forward ALL of its return values (embedded/trailing nils
--- preserved via the varargs trampoline). When PERF logging is off, calls fn directly with
--- ZERO timing overhead. Times the SUCCESS path only; an error in fn propagates unchanged
--- (Perf never swallows it, and emits no record for the failed span).
---@param label string
---@param fn function
---@return any ...
function Perf.Measure(label, fn, ...)
    local token = Perf.Begin(label)
    if not token then return fn(...) end
    local function finish(...) Perf.End(token); return ... end
    return finish(fn(...))
end
