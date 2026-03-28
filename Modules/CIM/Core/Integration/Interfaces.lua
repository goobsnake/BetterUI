--[[
File: Modules/CIM/Core/Interfaces.lua
Purpose: Defines strict interface contracts for BetterUI module implementations.
         Provides type-checking and validation for module registrations.
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Interfaces = {}

-- INTERFACE DEFINITIONS


-- INTERFACE VALIDATION

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

