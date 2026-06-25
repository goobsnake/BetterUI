--[[
File: Modules/CIM/Core/Diagnostics/WatchMode.lua
Purpose: The enrichment layer used by the AI presets: `watch` (debug depth + AI
         context) and `inspect` (trace depth + AI context). Activated/deactivated by
         Log.ApplyPreset when entering/leaving those presets. Five differentiators:

           1. Per-line context suffix  -> every line self-anchors with
              `scene= view= flow= lastAction=` so a tailer reading ONE line knows where
              the player is and what they last did (registered via SetContextProvider).
           2. Startup preamble         -> on activate, a STATE record with addon/schema/
              api/world/player/zone + the enabled-addon list, so an AI joining mid-stream
              can anchor the session.
           3. Periodic state snapshot  -> a self-rescheduling heartbeat that emits a STATE
              record aggregating registered snapshot providers (liveness + live state).
           4. Flow envelopes           -> Log.FlowBegin/FlowEnd correlate multi-step ops;
              the flow id rides the context suffix until the next action.
           5. Optional category policy -> replay-grade sessions default to no hidden
              categories, but this hook can mute proven noise without touching callers.

         Everything is pcall-guarded and inert unless an AI preset is active, so normal
         play pays nothing. Depends on BETTERUI.Log (loaded first) and BETTERUI.CIM.Names.
]]

BETTERUI.CIM = BETTERUI.CIM or {}

local Watch = {}
BETTERUI.CIM.WatchMode = Watch
BETTERUI.WatchMode = Watch

local function G(name) return rawget(_G, name) end
local function log() return BETTERUI.Log end
local function names() return BETTERUI.CIM and BETTERUI.CIM.Names end

local active = false
local currentView = nil         -- optional module-set sub-view label (e.g. "DepositTab")
local snapshotProviders = {}    -- name -> fn
local snapshotOrder = {}        -- ordered provider names (stable snapshot field order)
local snapshotScheduled = false
local snapshotTimerId = nil     -- pending heartbeat timer id (cancelled on Deactivate)
local snapshotTimerIntervalMs = nil -- interval used by the pending heartbeat timer

local WATCH_SNAPSHOT_INTERVAL_MS = 10000
local INSPECT_SNAPSHOT_INTERVAL_MS = 3000
-- Replay-grade watch/inspect must not hide the exact surfaces an AI needs to
-- reconstruct gameplay. Keep the hook for user overrides, but default to no mutes.
local DEFAULT_MUTED_CATEGORIES = {}

local function BuildDefaultMutedCategories()
    local out = {}
    for i = 1, #DEFAULT_MUTED_CATEGORIES do out[DEFAULT_MUTED_CATEGORIES[i]] = true end
    return out
end

local mutedCategories = BuildDefaultMutedCategories() -- category -> true (silenced in watch only)

-- Guarded call of a global fn by name: result or nil, never raises.
local function safeCall(fnName, ...)
    local fn = G(fnName)
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, ...)
    if ok then return v end
    return nil
end

local function snapshotIntervalMs()
    local L = log()
    local preset = L and L.GetPreset and L.GetPreset() or nil
    if preset == "inspect" then
        return INSPECT_SNAPSHOT_INTERVAL_MS
    end
    return WATCH_SNAPSHOT_INTERVAL_MS
end

-- Current scene name via SCENE_MANAGER, resolved through Names (handles userdata).
local function currentSceneName()
    local sm = G("SCENE_MANAGER")
    local t = type(sm)
    if t ~= "table" and t ~= "userdata" then return nil end
    local ok, scene = pcall(function() return sm:GetCurrentScene() end)
    if not ok or scene == nil then return nil end
    local N = names()
    if not N then return nil end
    local resolved = N.Scene(scene)
    if resolved == "<unknown>" then return nil end
    return resolved
end

-- ============================================================================
-- 1. Per-line context suffix (registered with Log.SetContextProvider on activate)
-- ============================================================================

-- Returns "scene=.. view=.. flow=.. lastAction=.." (only the set parts). Cheap, never
-- raises (Log pcall-guards it too). scene/view/flow are bare tokens; lastAction (which
-- can contain spaces) is quoted so the k=v stream stays parseable.
-- Keep scene/view as single BARE k=v tokens (the documented format): collapse internal
-- whitespace + neutralize the pipe so a name with a space/pipe can't break the parse.
local function safeToken(s)
    local ok, str = pcall(tostring, s)
    if not (ok and type(str) == "string") then return "?" end
    return (str:gsub("%s+", "_"):gsub("|", "/"))
end

local function contextSuffix(_level, _category)
    local parts = {}
    local scene = currentSceneName()
    if scene then parts[#parts + 1] = "scene=" .. safeToken(scene) end
    if currentView then parts[#parts + 1] = "view=" .. safeToken(currentView) end
    local L = log()
    local la = L and L.GetLastAction and L.GetLastAction()
    if type(la) == "table" then
        if la.flow then parts[#parts + 1] = "flow=" .. safeToken(la.flow) end
        if la.message and la.message ~= "" then
            -- Collapse newlines/tabs (a raw newline would split the record into two physical
            -- lines) and neutralize the pipe, THEN escape backslash + quote so an embedded "
            -- can't break the k=v contract.
            local okM, m = pcall(tostring, la.message)
            m = (okM and type(m) == "string") and m or "?"
            m = m:gsub("[\r\n\t]+", " "):gsub("|", "/"):gsub("\\", "\\\\"):gsub('"', '\\"')
            parts[#parts + 1] = 'lastAction="' .. m .. '"'
        end
    end
    if #parts == 0 then return "" end
    return table.concat(parts, " ")
end

-- ============================================================================
-- 2. Startup preamble
-- ============================================================================

local function emitActiveAddons()
    local L = log()
    if not (L and L.Info) then return end
    local getNum = G("GetNumAddOns")
    local getInfo = G("GetAddOnInfo")
    if type(getNum) ~= "function" or type(getInfo) ~= "function" then return end
    local okN, n = pcall(getNum)
    if not okN or type(n) ~= "number" then return end
    local listed, total = {}, 0
    for i = 1, n do
        -- GetAddOnInfo: name, title, author, description, enabled, state, isOutOfDate, isLibrary
        local ok, name, _title, _author, _desc, enabled = pcall(getInfo, i)
        if ok and enabled then
            total = total + 1
            if #listed < 40 then listed[#listed + 1] = name or ("addon" .. i) end
        end
    end
    local categories = L.CATEGORY or {}
    L.Info(categories.STATE, "active addons", { count = total, names = table.concat(listed, ",") })
end

local function emitPreamble()
    local L = log()
    if not L then return end
    local data = {
        schema = L.SCHEMA,
        preset = (L.GetPreset and L.GetPreset()) or "watch", -- watch OR inspect (both activate WatchMode)
        heartbeatMs = snapshotIntervalMs(),
        sid = L.GetSessionId and L.GetSessionId() or nil,
        api = safeCall("GetAPIVersion"),
        world = safeCall("GetWorldName"),
        player = safeCall("GetUnitName", "player"),
        zone = safeCall("GetUnitZone", "player"),
    }
    local categories = L.CATEGORY or {}
    L.Info(categories.STATE, "AI diagnostic session started -- live Interface.log stream; grep '[BUI]' for the clean feed", data)
    emitActiveAddons()
end

-- ============================================================================
-- 3. Periodic state snapshot (registry + self-rescheduling heartbeat)
-- ============================================================================

--- Register a named snapshot provider. fn() returns any value Log can render (number/
--- string/bool). Re-registering the same name replaces the fn (keeps field order).
---@param name string
---@param fn function
function Watch.RegisterSnapshotProvider(name, fn)
    if type(name) ~= "string" or name == "" or type(fn) ~= "function" then return end
    if snapshotProviders[name] == nil then snapshotOrder[#snapshotOrder + 1] = name end
    snapshotProviders[name] = fn
end

--- Emit one STATE snapshot now (heartbeat + aggregated provider values). Public so a
--- command or test can force one; also driven by the periodic timer.
function Watch.Snapshot()
    local L = log()
    if not L or not L.Debug then return end
    if L.EnabledFor and not L.EnabledFor(L.LEVEL.DEBUG, L.CATEGORY.STATE) then return end
    local data = { scene = currentSceneName() or "<none>", heartbeatMs = snapshotIntervalMs() }
    -- Surface the file-sink drop count so an AI tailing the log can SEE when a burst shed
    -- records (i.e. it may have missed context) straight from the heartbeat.
    local il = BETTERUI.CIM and BETTERUI.CIM.InterfaceLog
    if il and il.GetStats then
        local okS, s = pcall(il.GetStats)
        if okS and type(s) == "table" then data.dropped = s.dropped end
    end
    local la = L.GetLastAction and L.GetLastAction()
    if type(la) == "table" then
        if la.flow then data.flow = la.flow end
        if la.message and la.message ~= "" then data.lastAction = la.message end
    end
    for i = 1, #snapshotOrder do
        local nm = snapshotOrder[i]
        local fn = snapshotProviders[nm]
        if fn then
            local ok, v = pcall(fn)
            if ok and v ~= nil then data[nm] = v end
        end
    end
    pcall(L.Debug, L.CATEGORY.STATE, "snapshot", data)
end

local function scheduleSnapshot()
    if snapshotScheduled then return end
    local later = G("zo_callLater")
    if type(later) ~= "function" then return end
    local intervalMs = snapshotIntervalMs()
    snapshotScheduled = true
    snapshotTimerIntervalMs = intervalMs
    snapshotTimerId = later(function()
        snapshotScheduled = false
        snapshotTimerIntervalMs = nil
        if not active then return end -- watch left; stop the heartbeat
        pcall(Watch.Snapshot) -- a snapshot hiccup must not break the reschedule
        scheduleSnapshot()
    end, intervalMs)
end

local function rescheduleSnapshotIfIntervalChanged()
    if not snapshotScheduled then return end
    local desiredIntervalMs = snapshotIntervalMs()
    if snapshotTimerIntervalMs == desiredIntervalMs then return end
    local remove = G("zo_removeCallLater")
    if not (snapshotTimerId and type(remove) == "function") then return end
    local cancelOk, removed = pcall(remove, snapshotTimerId)
    if not (cancelOk and removed ~= false) then return end
    snapshotTimerId = nil
    snapshotScheduled = false
    snapshotTimerIntervalMs = nil
    scheduleSnapshot()
end

-- ============================================================================
-- 4. Curated auto-mute (tunable documented defaults -- calibrate in-client)
-- ============================================================================

--- Replace the watch-only mute set. Pass a list of category names; takes effect on the
--- next activate (or immediately if already active).
---@param list string[]|nil
function Watch.SetMutedCategories(list)
    local L = log()
    -- restore current mutes before swapping, so a live change is clean.
    if active and L and L.SetCategoryEnabled then
        for cat in pairs(mutedCategories) do L.SetCategoryEnabled(cat, true) end
    end
    mutedCategories = {}
    if type(list) == "table" then
        for i = 1, #list do
            if type(list[i]) == "string" then mutedCategories[list[i]] = true end
        end
    end
    if active and L and L.SetCategoryEnabled then
        for cat in pairs(mutedCategories) do L.SetCategoryEnabled(cat, false) end
    end
end

-- ============================================================================
-- Lifecycle (called by Log.ApplyPreset)
-- ============================================================================

function Watch.IsActive() return active end
function Watch.SetView(label) currentView = (type(label) == "string" and label ~= "") and label or nil end

--- Enter AI enrichment: register the context provider, apply mutes, emit the
--- preamble, and start the snapshot heartbeat. Idempotent.
function Watch.Activate()
    local L = log()
    -- (Re)assert the provider + mutes on EVERY call: Log.ApplyPreset resets
    -- categoryDisabled before invoking us, so re-applying an AI preset must restore the mutes
    -- (and re-register the provider) even when already active.
    if L and L.SetContextProvider then L.SetContextProvider(contextSuffix) end
    if L and L.SetCategoryEnabled then
        for cat in pairs(mutedCategories) do L.SetCategoryEnabled(cat, false) end
    end
    if active then
        rescheduleSnapshotIfIntervalChanged()
        return
    end -- preamble + heartbeat fire once per activation
    active = true
    emitPreamble()
    scheduleSnapshot()
end

--- Leave AI enrichment: drop the context provider and restore muted categories.
--- The snapshot heartbeat self-stops on its next tick (active=false). Idempotent.
function Watch.Deactivate()
    if not active then return end
    active = false
    -- Cancel the pending heartbeat timer so a rapid watch->off->watch re-arms ONE clean
    -- timer instead of leaking/doubling (don't just rely on the active=false self-stop).
    local remove = G("zo_removeCallLater")
    if snapshotTimerId and type(remove) == "function" then pcall(remove, snapshotTimerId) end
    snapshotTimerId = nil
    snapshotScheduled = false
    snapshotTimerIntervalMs = nil
    local L = log()
    if L and L.SetContextProvider then L.SetContextProvider(nil) end
    if L and L.SetCategoryEnabled then
        for cat in pairs(mutedCategories) do L.SetCategoryEnabled(cat, true) end
    end
    currentView = nil
end
