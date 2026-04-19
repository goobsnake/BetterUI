--[[
File: Modules/CIM/Core/Interfaces.lua
Purpose: Defines strict interface contracts for BetterUI module implementations.
         Provides type-checking and validation for module registrations.
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Interfaces = BETTERUI.CIM.Interfaces or {}

-- INTERFACE DEFINITIONS

local SUPPORTED_ARCHETYPES = {
    ["runtime-coordinator"] = true,
    ["settings-owner"] = true,
    ["thin-entrypoint"] = true,
}

local function HasSettingsSurface(module)
    if type(module.GetSettingsOptions) == "function" then
        return true
    end
    local settings = module.Settings
    return type(settings) == "table" and type(settings.RegisterPanel) == "function"
end

local function ValidateArchetypeBehavior(module, contract)
    local archetype = contract.archetype
    if not SUPPORTED_ARCHETYPES[archetype] then
        return false, "Module.ROOT_CONTRACT.archetype must be a supported BetterUIModuleArchetype"
    end

    if archetype == "runtime-coordinator" then
        if contract.init ~= true then
            return false, "runtime-coordinator modules must set Module.ROOT_CONTRACT.init to true"
        end
        return true
    end

    if archetype == "settings-owner" then
        if contract.init ~= true or contract.setup ~= true then
            return false, "settings-owner modules must enable both Module.ROOT_CONTRACT.init and Module.ROOT_CONTRACT.setup"
        end
        if not HasSettingsSurface(module) then
            return false, "settings-owner modules must expose GetSettingsOptions or Settings.RegisterPanel"
        end
        return true
    end

    if contract.init ~= true or contract.setup ~= true then
        return false, "thin-entrypoint modules must enable both Module.ROOT_CONTRACT.init and Module.ROOT_CONTRACT.setup"
    end
    return true
end

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

        if type(contract.init) ~= "boolean" then
            return false, "Module.ROOT_CONTRACT.init must be a boolean"
        end
        if contract.init and type(module.InitModule) ~= "function" then
            return false, "Module.ROOT_CONTRACT.init is true but Module.InitModule must be a function"
        end

        if type(contract.setup) ~= "boolean" then
            return false, "Module.ROOT_CONTRACT.setup must be a boolean"
        end
        if contract.setup and type(module.Setup) ~= "function" then
            return false, "Module.ROOT_CONTRACT.setup is true but Module.Setup must be a function"
        end

        local archetypeValid, archetypeErr = ValidateArchetypeBehavior(module, contract)
        if not archetypeValid then
            return false, archetypeErr
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
