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
  keybinds (table[]|nil) - Array of keybind button group descriptors
  taskManager (table|nil) - Task manager with :CancelAll() method
  eventRegistryModule (string|nil) - Module name for EventRegistry cleanup
  onShowing (function|nil) - Callback when scene starts showing
  onHiding (function|nil) - Callback when scene starts hiding
  onHidden (function|nil) - Callback when scene is fully hidden
]]

-- Type annotation for SceneLifecycleConfig is in Types.lua

local function BuildStateChangeHandler(screen, config)
    config = config or {}

    return function(oldState, newState)
        if newState == SCENE_SHOWING then
            if config.keybinds then
                for _, group in ipairs(config.keybinds) do
                    KEYBIND_STRIP:AddKeybindButtonGroup(group)
                end
            end
            if config.onShowing then
                local wasPushed = (oldState == SCENE_HIDDEN)
                BETTERUI.CIM.SafeExecute("SceneLifecycle:onShowing", config.onShowing, screen, wasPushed)
            end
        elseif newState == SCENE_HIDING then
            if config.keybinds then
                for _, group in ipairs(config.keybinds) do
                    KEYBIND_STRIP:RemoveKeybindButtonGroup(group)
                end
            end
            if config.taskManager and config.taskManager.CancelAll then
                config.taskManager:CancelAll()
            end
            if config.onHiding then
                BETTERUI.CIM.SafeExecute("SceneLifecycle:onHiding", config.onHiding, screen)
            end
        elseif newState == SCENE_HIDDEN then
            if config.eventRegistryModule and BETTERUI.CIM.EventRegistry then
                BETTERUI.CIM.EventRegistry.UnregisterAll(config.eventRegistryModule)
            end
            if config.onHidden then
                BETTERUI.CIM.SafeExecute("SceneLifecycle:onHidden", config.onHidden, screen)
            end
        end
    end
end

function BETTERUI.CIM.SceneLifecycle.CreateStateChangeHandler(screen, config)
    if not screen then
        BETTERUI.Debug("[SceneLifecycle] No screen provided")
        return nil
    end

    return BuildStateChangeHandler(screen, config)
end

function BETTERUI.CIM.SceneLifecycle.Register(screen, config)
    if not screen then
        BETTERUI.Debug("[SceneLifecycle] No screen provided")
        return
    end

    local scene = screen.scene
    if not scene then
        BETTERUI.Debug("[SceneLifecycle] No scene on screen object")
        return
    end

    local stateChangeHandler = BETTERUI.CIM.SceneLifecycle.CreateStateChangeHandler(screen, config)
    if not stateChangeHandler then
        return
    end

    scene:RegisterCallback("StateChange", stateChangeHandler)
end
