--[[
File: Modules/CIM/Core/Diagnostics/SceneLog.lua
Purpose: Framework-level scene-transition logger. A SINGLE additive manager-level
         callback observes EVERY SCENE_MANAGER transition -- keyboard, gamepad,
         interaction scenes (bank / guild bank / companion / armory), native ESO
         scenes, the HUD, and scenes created after load -- and streams one [BUI]
         breadcrumb per state change through BETTERUI.Log.

         This fills a gap: previously a scene transition was logged ONLY when an
         individual module hand-wired its own BETTERUI.Log.Info(SCENE, "OnSceneShowing")
         inside a per-scene StateChange handler. Transitions for ESO's own scenes, or
         any scene whose module callback didn't fire, were invisible.

Mechanism:
  ZO_Scene:SetState dispatches centrally via sceneManager:OnSceneStateChange ->
  FireCallbacks("SceneStateChanged", scene, oldState, newState), so ONE additive
  SCENE_MANAGER:RegisterCallback("SceneStateChanged", ...) sees them all -- including
  scenes registered after us, because the manager dispatches centrally rather than
  per-scene. We NEVER wrap/replace SCENE_MANAGER methods: a global monkeypatch taints
  protected gamepad paths (see BankingSceneLifecycle SetupSceneInterception, kept a
  deliberate no-op for exactly this reason). Registration is additive only, mirroring
  Modules/ResourceOrbFrames/Core/OrbEvents.lua:202.

Cost when off:
  The handler's first statement is the cheap memoized BETTERUI.Log.IsActive() gate;
  when logging is off it returns before building any string or table. Activation rides
  the existing Log active-state memo (/builog on|off and the persisted DEBUG_LOGGING
  flag), so no new on/off plumbing is added to the logging subsystem.

Level/format:
  Emits at INFO / CATEGORY.SCENE so lines survive the 'debug' preset (minLevel=INFO).
  The scene name and state verb are baked into the MESSAGE STRING -- under 'debug'
  payloadCapture is off and the data table is dropped at dispatch, so the message must
  stand alone. On disk: `[BUI] <ts> INFO SCENE | scene <name> <verb>`.

Slash command: /buiscene -- dump the current scene + recent-transition ring in chat.
]]

BETTERUI.CIM = BETTERUI.CIM or {}

local SceneLog = {}
BETTERUI.CIM.SceneLog = SceneLog
BETTERUI.SceneLog = SceneLog

-- Engine globals are absent/stubbed in the pure-Lua unit-test harness; resolve them
-- defensively so file-scope load can never crash on a missing global.
local function G(name) return rawget(_G, name) end

-- Map a scene-state constant -> human verb. Built guard-by-guard (not as a table
-- literal) so a nil constant can never raise "table index is nil" at load on a
-- partial client or in the harness.
local STATE_NAME = {}
local function MapState(const, verb)
    if const ~= nil then STATE_NAME[const] = verb end
end
MapState(G("SCENE_SHOWING"), "showing")
MapState(G("SCENE_SHOWN"),   "shown")
MapState(G("SCENE_HIDING"),  "hiding")
MapState(G("SCENE_HIDDEN"),  "hidden")

local SCENE_HIDDEN = G("SCENE_HIDDEN")
local SCENE_SHOWN = G("SCENE_SHOWN")

local m_registered = false

-- Fixed-size recent-transition ring for /buiscene (newest overwrites oldest).
local RING_SIZE = 24
local m_ring = {}
local m_ringIdx = 0

local function PushRing(entry)
    m_ringIdx = (m_ringIdx % RING_SIZE) + 1
    m_ring[m_ringIdx] = entry
end

local function RecentChronological()
    local count = 0
    for _, entry in pairs(m_ring) do
        if entry then count = count + 1 end
    end

    local ordered = {}
    if count == 0 then return ordered end

    local startIdx = count < RING_SIZE and 1 or ((m_ringIdx % RING_SIZE) + 1)
    for offset = 0, count - 1 do
        local idx = ((startIdx + offset - 1) % RING_SIZE) + 1
        local entry = m_ring[idx]
        if entry then ordered[#ordered + 1] = entry end
    end
    return ordered
end

local function Now()
    local clock = G("GetGameTimeMilliseconds")
    return type(clock) == "function" and clock() or 0
end

local function CurrentSceneName()
    local sm = G("SCENE_MANAGER")
    if sm and sm.GetCurrentSceneName then
        local ok, name = pcall(sm.GetCurrentSceneName, sm)
        if ok then return name end
    end
    return nil
end

-- The single manager-level handler. arg1 is the ZO_Scene object (OrbEvents.lua:203
-- reads newState as the 3rd arg, confirming this arity); degrade safely if arg1 is
-- unexpectedly a string or nil rather than erroring on a hot UI path.
local function OnSceneStateChanged(scene, oldState, newState)
    -- INERT-WHEN-OFF: cheap memoized union gate (InterfaceLog /builog OR DEBUG_LOGGING).
    -- Returns before any string build / table alloc when logging is off.
    if not (BETTERUI.Log and BETTERUI.Log.IsActive()) then return end

    -- ESO scenes are USERDATA, not tables -- resolve through Names.Scene (handles string/
    -- table/userdata + pcall-guards the :GetName() call) so native scene transitions don't
    -- all collapse to "<unknown>". Fall back to a bare resolve if Names isn't loaded yet.
    local N = BETTERUI.CIM and BETTERUI.CIM.Names
    local name = (N and N.Scene and N.Scene(scene))
        or (type(scene) == "string" and scene)
        or "<unknown>"
    local verb = STATE_NAME[newState] or ("state(" .. tostring(newState) .. ")")
    local fromVerb = STATE_NAME[oldState] or ("state(" .. tostring(oldState) .. ")")

    PushRing({ scene = name, verb = verb, t = Now() })

    -- Self-describing message: name + the from->to transition live in the MESSAGE (not
    -- only the data table), because the 'debug' preset drops the data table at dispatch.
    -- from/to are human verbs (showing/shown/hiding/hidden), never raw state constants.
    local msg = "scene " .. name .. " " .. verb .. " (from " .. fromVerb .. ")"
    local wasHidden = (SCENE_HIDDEN ~= nil and oldState == SCENE_HIDDEN)
    local data = {
        scene = name,
        from = fromVerb,
        to = verb,
        wasHidden = wasHidden,
        -- Backward-compatible alias for existing log consumers.
        wasPushed = wasHidden,
        cur = CurrentSceneName(),
    }
    local W = BETTERUI.CIM and BETTERUI.CIM.WatchMode
    if W and type(W.DescribeActiveKeybinds) == "function" then
        local ok, keybinds = pcall(W.DescribeActiveKeybinds)
        if ok then data.keybinds = keybinds end
    end

    -- Tier by settledness: SHOWN/HIDDEN are the milestones a user cares about (INFO --
    -- survive the 'info' preset); SHOWING/HIDING are intermediate flow (DEBUG). When the
    -- constants are absent (test harness / partial client) default to INFO so nothing is
    -- silently lost.
    if SCENE_SHOWN == nil and SCENE_HIDDEN == nil then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SCENE, msg, data)
    elseif newState == SCENE_SHOWN or newState == SCENE_HIDDEN then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SCENE, msg, data)
    else
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.SCENE, msg, data)
    end
end

--- Idempotently register the single additive SceneStateChanged callback. Safe to call
--- repeatedly (file-scope load + RuntimeSetup.Apply); no-ops without SCENE_MANAGER.
--- The m_registered guard guarantees exactly one registration per session, so a
--- /reloadui (fresh Lua state, fresh callback table) never stacks handlers.
---@return boolean registered  true only on the call that actually registered
function SceneLog.EnsureRegistered()
    if m_registered then return false end
    local sm = G("SCENE_MANAGER")
    if not (sm and sm.RegisterCallback) then return false end
    sm:RegisterCallback("SceneStateChanged", OnSceneStateChanged)
    m_registered = true
    return true
end

---@return boolean
function SceneLog.IsRegistered() return m_registered end

--- Live recent-transition ring (diagnostics / tests).
---@return table
function SceneLog.GetRecent() return m_ring end

---@return table ordered oldest -> newest
function SceneLog.GetRecentChronological() return RecentChronological() end

-- Register now if SCENE_MANAGER already exists (the common case at load); RuntimeSetup
-- .Apply re-calls post-SavedVars as a belt-and-suspenders. Self-gating means the
-- registration timing relative to logging on/off does not matter.
SceneLog.EnsureRegistered()

-- /buiscene: print the current scene + recent transition ring, without tailing the file.
local SLASH = G("SLASH_COMMANDS")
if type(SLASH) == "table" then
    local function PrintSceneLogCommand()
        local chat = G("d")
        if type(chat) ~= "function" then return end
        chat(string.format("|c0066ff[BetterUI]|r scene now: %s | logging %s | registered=%s",
            tostring(CurrentSceneName()),
            (BETTERUI.Log and BETTERUI.Log.IsActive()) and "|c00ff00ON|r" or "off",
            tostring(m_registered)))
        local recent = RecentChronological()
        for i = 1, #recent do
            local e = recent[i]
            if e then chat(string.format("  %s %s @%s", tostring(e.scene), tostring(e.verb), tostring(e.t))) end
        end
    end
    local registerSlash = BETTERUI.CIM and BETTERUI.CIM.Utils and BETTERUI.CIM.Utils.RegisterSlashCommand
    if type(registerSlash) == "function" then
        registerSlash("/buiscene", PrintSceneLogCommand, {
            owner = "SceneLog",
            fallbackCommand = "/buiscenelog",
        })
    elseif type(SLASH["/buiscene"]) ~= "function" then
        SLASH["/buiscene"] = PrintSceneLogCommand
    elseif type(SLASH["/buiscenelog"]) ~= "function" then
        SLASH["/buiscenelog"] = PrintSceneLogCommand
    end
end
