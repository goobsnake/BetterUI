--[[
File: Modules/CIM/Core/Interfaces.lua
Purpose: Defines strict interface contracts for BetterUI module implementations.
         Provides type-checking and validation for module registrations.
Author: BetterUI Team
Last Modified: 2026-01-28
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Interfaces = {}

-- ============================================================================
-- INTERFACE DEFINITIONS
-- ============================================================================

--- @class BetterUI.ModuleInterface
--- @field name string The module identifier (e.g., "Banking", "Inventory")
--- @field Setup fun(): nil Module initialization function
--- @field RegisterSettings? fun(id: string, name: string): nil Optional settings registration

--- @class BetterUI.ListInterface
--- @field RefreshList fun(self): nil Refresh the list contents
--- @field GetTargetData fun(self): table|nil Get currently selected item
--- @field Activate fun(self): nil Activate the list for input
--- @field Deactivate fun(self): nil Deactivate the list

--- @class BetterUI.SceneInterface
--- @field OnStateChanged fun(self, oldState: string, newState: string): nil Scene lifecycle handler
--- @field OnEffectivelyShown? fun(self): nil Optional show callback
--- @field OnEffectivelyHidden? fun(self): nil Optional hide callback

--- @class BetterUI.KeybindInterface
--- @field name string Keybind action name
--- @field keybind string The keybind string (e.g., "UI_SHORTCUT_PRIMARY")
--- @field callback fun(): nil The action callback
--- @field visible? fun(): boolean Optional visibility function
--- @field enabled? fun(): boolean Optional enabled function

-- ============================================================================
-- INTERFACE VALIDATION
-- ============================================================================

--[[
Function: BETTERUI.CIM.Interfaces.ValidateModule
Description: Validates that a module table conforms to the ModuleInterface.
Rationale: Provides runtime type safety for module registrations.
Mechanism: Checks required properties exist and are correct types.
References: Called during module registration.
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

