--[[
File: Modules/CIM/Core/SceneLifecycleManager.lua
Purpose: Unified scene lifecycle management for all BetterUI modules.
         Consolidates scene state change handling, keybind management,
         task cleanup, and event registry management.
Author: BetterUI Team
Last Modified: 2026-01-29
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

--[[
Function: BETTERUI.CIM.SceneLifecycle.Register
Description: Registers scene lifecycle handlers for a screen.
Rationale: Consolidates scene state change handling across all modules,
           reducing duplicate handler code and ensuring consistent cleanup.
param: screen (table) - The screen instance with a `scene` field.
param: config (SceneLifecycleConfig) - Configuration for lifecycle handling.
]]
--- @param screen table The screen instance (has `scene` field)
--- @param config SceneLifecycleConfig
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

    scene:RegisterCallback("StateChange", function(oldState, newState)
        if newState == SCENE_SHOWING then
            -- Add keybinds
            if config.keybinds then
                for _, group in ipairs(config.keybinds) do
                    KEYBIND_STRIP:AddKeybindButtonGroup(group)
                end
            end
            -- Call showing handler
            if config.onShowing then
                local wasPushed = (oldState == SCENE_HIDDEN)
                BETTERUI.CIM.SafeExecute("SceneLifecycle:onShowing", config.onShowing, screen, wasPushed)
            end
        elseif newState == SCENE_HIDING then
            -- Remove keybinds
            if config.keybinds then
                for _, group in ipairs(config.keybinds) do
                    KEYBIND_STRIP:RemoveKeybindButtonGroup(group)
                end
            end
            -- Cancel pending tasks
            if config.taskManager and config.taskManager.CancelAll then
                config.taskManager:CancelAll()
            end
            -- Call hiding handler
            if config.onHiding then
                BETTERUI.CIM.SafeExecute("SceneLifecycle:onHiding", config.onHiding, screen)
            end
        elseif newState == SCENE_HIDDEN then
            -- Unregister events
            if config.eventRegistryModule and BETTERUI.CIM.EventRegistry then
                BETTERUI.CIM.EventRegistry.UnregisterAll(config.eventRegistryModule)
            end
            -- Call hidden handler
            if config.onHidden then
                BETTERUI.CIM.SafeExecute("SceneLifecycle:onHidden", config.onHidden, screen)
            end
        end
    end)
end

