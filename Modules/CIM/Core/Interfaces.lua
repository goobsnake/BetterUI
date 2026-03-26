--[[
File: Modules/CIM/Core/Interfaces.lua
Purpose: Defines strict interface contracts for BetterUI module implementations.
         Provides type-checking and validation for module registrations.
Author: BetterUI Team
Last Modified: 2026-03-26
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Interfaces = {}

-- ============================================================================
-- INTERFACE DEFINITIONS
-- ============================================================================

--- @class BetterUI.ModuleInterface
--- @field name string The module identifier (e.g., "Banking", "Inventory")
--- @field Setup fun(): nil Module initialization function; called once during addon load
--- @field RegisterSettings? fun(id: string, name: string): nil Optional: called by Settings module to register addon menu entry; preconditions: Settings module loaded

--- @class BetterUI.ListInterface
--- @field RefreshList fun(self): nil Refresh the list contents; called after data changes
--- @field GetTargetData fun(self): table|nil Get currently selected item; called by keybind handlers
--- @field Activate fun(self): nil Activate the list for input; called when scene shows
--- @field Deactivate fun(self): nil Deactivate the list; called when scene hides

--- @class BetterUI.SceneInterface
--- @field OnStateChanged fun(self, oldState: string, newState: string): nil Scene lifecycle handler; called by SCENE_MANAGER on state transitions
--- @field OnEffectivelyShown? fun(self): nil Optional: called by ZO_Scene when scene becomes effectively shown (after transitions); use for focus-dependent init
--- @field OnEffectivelyHidden? fun(self): nil Optional: called by ZO_Scene when scene becomes effectively hidden; use for cleanup that requires visible state

--- @class BetterUI.KeybindInterface
--- @field name string Keybind action name
--- @field keybind string The keybind string (e.g., "UI_SHORTCUT_PRIMARY")
--- @field callback fun(): nil The action callback; called when keybind triggered
--- @field visible? fun(): boolean Optional: called by KEYBIND_STRIP to determine visibility; return false to hide
--- @field enabled? fun(): boolean Optional: called by KEYBIND_STRIP to determine enabled state; return false to gray out

-- ============================================================================
-- INTERFACE VALIDATION
-- ============================================================================

--[[
Function: BETTERUI.CIM.Interfaces.ValidateModule
Description: Validates that a module table conforms to the ModuleInterface.
Called by: Module registration system during addon initialization.
]]
--- @param module table The module to validate
--- @param requiredFields? string[] Optional additional required fields
--- @return boolean valid True if module conforms to interface
--- @return string? error Error message if validation failed
function BETTERUI.CIM.Interfaces.ValidateModule(module, requiredFields)
    if not module then
        return false, "Module is nil"
    end
    if type(module.name) ~= "string" then
        return false, "Module.name must be a string"
    end
    if type(module.Setup) ~= "function" then
        return false, "Module.Setup must be a function"
    end

    -- Check additional required fields if specified
    if requiredFields then
        for _, field in ipairs(requiredFields) do
            if module[field] == nil then
                return false, "Module is missing required field: " .. field
            end
        end
    end

    return true
end

