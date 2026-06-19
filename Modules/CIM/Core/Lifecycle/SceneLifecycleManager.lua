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
                                    show/hide time so groups created after Register() are picked
                                    up. Takes precedence over `keybinds` when present.
  taskManager (table|nil) - Task manager with :CancelAll() method
  eventRegistryModule (string|nil) - Module name for EventRegistry cleanup
  onShowing (function|nil) - Callback when scene starts showing
  onHiding (function|nil) - Callback when scene starts hiding
  onHidden (function|nil) - Callback when scene is fully hidden
]]

-- Type annotation for SceneLifecycleConfig is in Types.lua

-- Resolve the keybind button groups for this lifecycle event.
-- Prefer config.keybindsResolver (a closure) so groups are resolved at show/hide
-- time rather than captured by value at registration. This lets callers register
-- before their keybind groups exist (e.g. a window whose InitializeScene runs
-- before InitializeKeybind) without the group silently dropping to {nil}.
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

local function BuildStateChangeHandler(screen, config)
    config = config or {}

    return function(oldState, newState)
        local sceneName = ""
        if screen and screen.scene and screen.scene.GetName then
            local ok, name = pcall(screen.scene.GetName, screen.scene)
            if ok then sceneName = name end
        end
        if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SCENE, "stateChange", { scene = sceneName, state = newState }) end

        if newState == SCENE_SHOWING then
            local showingGroups = ResolveKeybindGroups(config)
            for _, group in ipairs(showingGroups) do
                BETTERUI.CIM.SafeExecute("SceneLifecycle:addKeybind", function() KEYBIND_STRIP:AddKeybindButtonGroup(group) end)
            end
            local wasPushed = (oldState == SCENE_HIDDEN)
            if BETTERUI.Log then BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SCENE, "sceneShowing", { scene = sceneName, wasPushed = wasPushed, keybindGroups = #showingGroups }) end
            if config.onShowing then
                BETTERUI.CIM.SafeExecute("SceneLifecycle:onShowing", config.onShowing, screen, wasPushed)
            end
        elseif newState == SCENE_HIDING then
            local hidingGroups = ResolveKeybindGroups(config)
            for _, group in ipairs(hidingGroups) do
                BETTERUI.CIM.SafeExecute("SceneLifecycle:removeKeybind", function() KEYBIND_STRIP:RemoveKeybindButtonGroup(group) end)
            end
            if BETTERUI.Log then BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SCENE, "sceneHiding", { scene = sceneName, keybindGroups = #hidingGroups }) end
            if config.taskManager and config.taskManager.CancelAll then
                BETTERUI.CIM.SafeExecute("SceneLifecycle:cancelTasks", function() config.taskManager:CancelAll() end)
            end
            if config.onHiding then
                BETTERUI.CIM.SafeExecute("SceneLifecycle:onHiding", config.onHiding, screen)
            end
        elseif newState == SCENE_HIDDEN then
            if BETTERUI.Log then BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SCENE, "sceneHidden", { scene = sceneName, eventRegistryModule = config.eventRegistryModule }) end
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

--- Unregisters a previously-registered lifecycle StateChange handler.
--- Safe to call when nothing is registered (no-op).
---@param screen table
---@return nil
function BETTERUI.CIM.SceneLifecycle.Unregister(screen)
    if not screen then return end
    local handle = screen._sceneLifecycleHandle
    if not handle then return end
    if handle.scene and handle.scene.UnregisterCallback then
        handle.scene:UnregisterCallback("StateChange", handle.handler)
    end
    screen._sceneLifecycleHandle = nil
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SCENE, "lifecycleUnregister", {}) end
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

    -- Guard against double-registration: a re-init (e.g. reloadui or re-entry)
    -- would otherwise stack StateChange handlers, doubling onShowing/onHiding and
    -- the keybind add/remove + task CancelAll work. Tear down the prior handle first.
    if screen._sceneLifecycleHandle then
        BETTERUI.CIM.SceneLifecycle.Unregister(screen)
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
    screen._sceneLifecycleHandle = { scene = scene, handler = stateChangeHandler }
    return stateChangeHandler
end
