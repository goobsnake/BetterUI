--[[
File: Modules/CIM/Core/Interfaces.lua
Purpose: Defines strict interface contracts for BetterUI module implementations.
         Provides type-checking and validation for module registrations.
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Interfaces = BETTERUI.CIM.Interfaces or {}

-- INTERFACE DEFINITIONS


-- INTERFACE VALIDATION

--- Validates that a module object meets the required interface contract.
--- @param module table|nil The module namespace to validate
--- @param requiredFields string[]|nil Additional required field names
--- @param expectedName string|nil Canonical module name expected by the caller
--- @return boolean valid Whether the module passes validation
--- @return string|nil errorMessage Description of the validation failure
function BETTERUI.CIM.Interfaces.ValidateModule(module, requiredFields, expectedName)
    if not module then
        return false, "Module is nil"
    end

    -- Legacy mode (no expected name): retain the historical shape check.
    if expectedName == nil then
        if type(module.name) ~= "string" then
            return false, "Module.name must be a string"
        end
        if type(module.Setup) ~= "function" then
            return false, "Module.Setup must be a function"
        end
    else
        if type(module.ARCHETYPE) ~= "string" then
            return false, "Module.ARCHETYPE must be a string"
        end

        local contract = module.ROOT_CONTRACT
        if type(contract) ~= "table" then
            return false, "Module.ROOT_CONTRACT must be a table"
        end

        if type(contract.name) ~= "string" then
            return false, "Module.ROOT_CONTRACT.name must be a string"
        end
        if contract.name ~= expectedName then
            return false, "Module.ROOT_CONTRACT.name does not match expected module name"
        end

        if type(contract.archetype) ~= "string" then
            return false, "Module.ROOT_CONTRACT.archetype must be a string"
        end
        if contract.archetype ~= module.ARCHETYPE then
            return false, "Module.ROOT_CONTRACT.archetype must match Module.ARCHETYPE"
        end

        if contract.initOwner ~= nil and type(contract.initOwner) ~= "string" then
            return false, "Module.ROOT_CONTRACT.initOwner must be a string or nil"
        end
        if contract.initOwner ~= nil and contract.initOwner ~= "" and type(module.InitModule) ~= "function" then
            return false, "Module.ROOT_CONTRACT.initOwner is set but Module.InitModule must be a function"
        end

        if contract.setupOwner ~= nil and type(contract.setupOwner) ~= "string" then
            return false, "Module.ROOT_CONTRACT.setupOwner must be a string or nil"
        end
        if contract.setupOwner ~= nil and contract.setupOwner ~= "" and type(module.Setup) ~= "function" then
            return false, "Module.ROOT_CONTRACT.setupOwner is set but Module.Setup must be a function"
        end
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
