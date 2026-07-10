--[[
File: Modules/CIM/Core/Lifecycle/SceneLifecycleManager.lua
Purpose: Unified scene lifecycle management for all BetterUI modules.
         Consolidates scene state change handling, keybind management,
         task cleanup, and event registry management.
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end

BETTERUI.CIM.SceneLifecycle = {}

--[[
Class: SceneLifecycleConfig
Description: Configuration for scene lifecycle registration.

Fields:
  keybinds (table[]|nil) - Array of keybind button group descriptors (captured by value)
  keybindsResolver (function|nil) - Closure returning the keybind group array; resolved at
                                    SHOWING time and snapshotted so the exact groups added are
                                    removed on HIDING (or direct HIDDEN), even if the resolver
                                    returns different groups later. Groups created after Register()
                                    are still picked up. Takes precedence over `keybinds` when present.
  taskManager (table|nil) - Task manager with :CancelAll() method
  eventRegistryModule (string|nil) - Module name for EventRegistry cleanup
  onShowing (function|nil) - Callback when scene starts showing
  onHiding (function|nil) - Callback when scene starts hiding
  onHidden (function|nil) - Callback when scene is fully hidden
]]

-- Type annotation for SceneLifecycleConfig is in Types.lua

-- Resolve the keybind button groups at SHOWING time.
-- Prefer config.keybindsResolver (a closure) so groups are resolved at show time
-- rather than captured by value at registration. This lets callers register
-- before their keybind groups exist (e.g. a window whose InitializeScene runs
-- before InitializeKeybind) without the group silently dropping to {nil}.
-- The SHOWING result is snapshotted by the handler and removed exactly on HIDING.
local function ResolveKeybindGroups(config)
    if config.keybindsResolver then
        -- Protect against a throwing resolver so show/hide cleanup still proceeds.
        local ok, groups = pcall(config.keybindsResolver)
        if ok and type(groups) == "table" then return groups end
        if not ok and BETTERUI.Log then
            BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SCENE, "[SceneLifecycle] keybindsResolver failed", { error = tostring(groups) })
        end
        return {}
    end
    if type(config.keybinds) == "table" then return config.keybinds end
    return {}
end

local function SnapshotKeybindGroups(groups)
    local snapshot = {}
    for index, group in ipairs(groups or {}) do
        snapshot[index] = group
    end
    return snapshot
end

local function DescribeKeybindGroups(groups)
    local L = BETTERUI.Log
    return L and L.DescribeKeybindDescriptors and L.DescribeKeybindDescriptors(groups, "scene") or tostring(#(groups or {}))
end

local function EnsureKeybindGroupAdded(group)
    local ensureGroup = BETTERUI.Interface and BETTERUI.Interface.EnsureKeybindGroupAdded
    if ensureGroup then
        return ensureGroup(group)
    end
    return false
end

local function RemoveKeybindGroupIfPresent(group)
    local removeGroup = BETTERUI.Interface and BETTERUI.Interface.RemoveKeybindGroupIfPresent
    if removeGroup then
        return removeGroup(group)
    end
    return false
end

local function BuildStateChangeHandler(screen, config)
    config = config or {}
    -- Capture the scene registered at handler creation time so logs and cleanup
    -- remain tied to the scene this handler was bound to, even if screen.scene
    -- mutates later (e.g. a screen driving multiple scenes).
    local registeredScene = screen and screen.scene or nil
    -- Snapshot of the keybind groups resolved at SHOWING. The exact snapshot is
    -- removed on HIDING; a direct HIDDEN transition removes any remaining
    -- snapshot as a fallback. This prevents a mutable keybindsResolver from
    -- causing leaks or over-removal.
    local showingSnapshot = nil

    return function(oldState, newState)
        local sceneName = ""
        if registeredScene and registeredScene.GetName then
            local ok, name = pcall(registeredScene.GetName, registeredScene)
            if ok then sceneName = name end
        end
        if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SCENE, "scene state changed", { scene = sceneName, state = newState }) end

        if newState == SCENE_SHOWING then
            showingSnapshot = SnapshotKeybindGroups(ResolveKeybindGroups(config))
            for index, group in ipairs(showingSnapshot) do
                if BETTERUI.Log then
                    BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "scene lifecycle add keybind", {
                        fn = "SceneLifecycle:showing",
                        scene = sceneName,
                        index = index,
                        descriptor = BETTERUI.Log.DescribeKeybindDescriptor and BETTERUI.Log.DescribeKeybindDescriptor(group, "add") or tostring(group),
                    })
                end
                BETTERUI.CIM.SafeExecute("SceneLifecycle:addKeybind", function() EnsureKeybindGroupAdded(group) end)
            end
            local wasPushed = (oldState == SCENE_HIDDEN)
            if BETTERUI.Log then BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SCENE, "scene showing", { scene = sceneName, wasPushed = wasPushed, keybindGroups = #showingSnapshot, descriptors = DescribeKeybindGroups(showingSnapshot) }) end
            if config.onShowing then
                BETTERUI.CIM.SafeExecute("SceneLifecycle:onShowing", config.onShowing, screen, wasPushed)
            end
        elseif newState == SCENE_HIDING then
            -- Preserve the legacy static-array teardown path for late registration
            -- that observes HIDING without having observed this scene's SHOWING.
            -- Resolver output is never re-read here because only its SHOWING snapshot
            -- has authoritative identity.
            local hidingGroups = showingSnapshot or config.keybinds or {}
            for index, group in ipairs(hidingGroups) do
                if BETTERUI.Log then
                    BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "scene lifecycle remove keybind", {
                        fn = "SceneLifecycle:hiding",
                        scene = sceneName,
                        index = index,
                        descriptor = BETTERUI.Log.DescribeKeybindDescriptor and BETTERUI.Log.DescribeKeybindDescriptor(group, "remove") or tostring(group),
                    })
                end
                BETTERUI.CIM.SafeExecute("SceneLifecycle:removeKeybind", function() RemoveKeybindGroupIfPresent(group) end)
            end
            if BETTERUI.Log then BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SCENE, "scene hiding", { scene = sceneName, keybindGroups = #hidingGroups, descriptors = DescribeKeybindGroups(hidingGroups) }) end
            showingSnapshot = nil
            if config.taskManager and config.taskManager.CancelAll then
                BETTERUI.CIM.SafeExecute("SceneLifecycle:cancelTasks", function() config.taskManager:CancelAll() end)
            end
            if config.onHiding then
                BETTERUI.CIM.SafeExecute("SceneLifecycle:onHiding", config.onHiding, screen)
            end
        elseif newState == SCENE_HIDDEN then
            -- Direct-HIDDEN fallback: if the scene transitions straight to HIDDEN
            -- without HIDING, remove the SHOWING snapshot so keybinds don't leak.
            if showingSnapshot then
                for index, group in ipairs(showingSnapshot) do
                    if BETTERUI.Log then
                        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "scene lifecycle remove keybind", {
                            fn = "SceneLifecycle:hiddenFallback",
                            scene = sceneName,
                            index = index,
                            descriptor = BETTERUI.Log.DescribeKeybindDescriptor and BETTERUI.Log.DescribeKeybindDescriptor(group, "remove") or tostring(group),
                        })
                    end
                    BETTERUI.CIM.SafeExecute("SceneLifecycle:removeKeybind", function() RemoveKeybindGroupIfPresent(group) end)
                end
                if BETTERUI.Log then BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SCENE, "scene hidden keybind fallback", { scene = sceneName, keybindGroups = #showingSnapshot, descriptors = DescribeKeybindGroups(showingSnapshot) }) end
                showingSnapshot = nil
            end
            -- Re-cancel tasks on hidden before event cleanup and user callback.
            if config.taskManager and config.taskManager.CancelAll then
                BETTERUI.CIM.SafeExecute("SceneLifecycle:cancelTasksHidden", function() config.taskManager:CancelAll() end)
            end
            if BETTERUI.Log then BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SCENE, "scene hidden", { scene = sceneName, eventRegistryModule = config.eventRegistryModule }) end
            if config.eventRegistryModule and BETTERUI.CIM.EventRegistry then
                BETTERUI.CIM.SafeExecute("SceneLifecycle:unregisterEvents", function() BETTERUI.CIM.EventRegistry.UnregisterAll(config.eventRegistryModule) end)
            end
            if config.onHidden then
                BETTERUI.CIM.SafeExecute("SceneLifecycle:onHidden", config.onHidden, screen)
            end
        end
    end
end

function BETTERUI.CIM.SceneLifecycle.CreateStateChangeHandler(screen, config)
    if not screen then
        if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SCENE, "[SceneLifecycle] No screen provided") end
        return nil
    end
    if config ~= nil and type(config) ~= "table" then
        if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SCENE, "[SceneLifecycle] Invalid config type") end
        config = nil
    end

    return BuildStateChangeHandler(screen, config)
end

--- Unregisters previously-registered lifecycle StateChange handlers for a screen.
--- A screen can drive MORE THAN ONE scene (e.g. the bank window owns both the
--- personal and guild-bank scenes), so handlers are tracked per scene. Pass a
--- specific `scene` to unregister just that one; omit it to unregister all of the
--- screen's handlers. Safe to call when nothing is registered (no-op).
---@param screen table
---@param scene table|nil  Specific scene to unregister; nil unregisters all.
---@return nil
function BETTERUI.CIM.SceneLifecycle.Unregister(screen, scene)
    if not screen then return end
    local handles = screen._sceneLifecycleHandles
    if not handles then return end

    local function drop(s)
        local handle = handles[s]
        if not handle then return end
        if handle.scene and handle.scene.UnregisterCallback then
            handle.scene:UnregisterCallback("StateChange", handle.handler)
        end
        handles[s] = nil
    end

    if scene then
        drop(scene)
    else
        -- Collect keys before mutating the table we iterate.
        local scenes = {}
        for s in pairs(handles) do scenes[#scenes + 1] = s end
        for _, s in ipairs(scenes) do drop(s) end
    end
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SCENE, "lifecycle unregistered", {}) end
end

function BETTERUI.CIM.SceneLifecycle.Register(screen, config)
    if not screen then
        if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SCENE, "[SceneLifecycle] No screen provided") end
        return
    end

    local scene = screen.scene
    if not scene then
        if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SCENE, "[SceneLifecycle] No scene on screen object") end
        return
    end

    screen._sceneLifecycleHandles = screen._sceneLifecycleHandles or {}

    -- Guard against double-registration FOR THIS SCENE: a re-init (e.g. reloadui or
    -- re-entry) would otherwise stack StateChange handlers on the same scene. Tear
    -- down only the prior handle for THIS scene, leaving handlers the screen
    -- registered for OTHER scenes intact. A single screen can own several scenes --
    -- the bank window drives BOTH the personal and guild-bank scenes -- so the old
    -- screen-keyed guard clobbered a sibling scene's handler, silently breaking that
    -- scene's lifecycle (no OnSceneShowing -> no content/backdrop -> empty window).
    if screen._sceneLifecycleHandles[scene] then
        BETTERUI.CIM.SceneLifecycle.Unregister(screen, scene)
    end

    local stateChangeHandler = BETTERUI.CIM.SceneLifecycle.CreateStateChangeHandler(screen, config)
    if not stateChangeHandler then
        return
    end

    if scene.RegisterCallback then
        scene:RegisterCallback("StateChange", stateChangeHandler)
    else
        if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SCENE, "[SceneLifecycle] Scene does not support RegisterCallback") end
        return
    end
    screen._sceneLifecycleHandles[scene] = { scene = scene, handler = stateChangeHandler }
    return stateChangeHandler
end
