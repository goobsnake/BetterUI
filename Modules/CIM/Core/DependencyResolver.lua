--[[
File: Modules/CIM/Core/DependencyResolver.lua
Purpose: Validates module dependencies and determines correct load order.
Author: BetterUI Team
Last Modified: 2026-01-31

Used By: BetterUI.lua (module initialization)
Dependencies: None (core utility)
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end

-- ============================================================================
-- DEPENDENCY RESOLVER
-- ============================================================================

--[[
Table: BETTERUI.CIM.DependencyResolver
Description: Validates and orders module dependencies.
Rationale: Prevents load order bugs by detecting circular dependencies
           and ensuring modules load after their dependencies.
Mechanism:
  1. Register() adds a module with its dependencies.
  2. Resolve() returns a valid load order (topological sort).
  3. Validate() checks for circular dependencies.
]]
BETTERUI.CIM.DependencyResolver = {
    -- Registered modules { name = { dependencies = {}, priority = 0 } }
    _modules = {},
}

--[[
Function: BETTERUI.CIM.DependencyResolver.Register
Description: Registers a module with its dependencies.
param: moduleName (string) - The module name.
param: dependencies (table|nil) - Array of dependency module names.
param: priority (number|nil) - Optional load priority (lower = earlier, default 100).
]]
--- @param moduleName string The module name
--- @param dependencies table|nil Array of dependency module names
--- @param priority number|nil Optional load priority
function BETTERUI.CIM.DependencyResolver.Register(moduleName, dependencies, priority)
    BETTERUI.CIM.DependencyResolver._modules[moduleName] = {
        name = moduleName,
        dependencies = dependencies or {},
        priority = priority or 100,
    }
end

--[[
Function: BETTERUI.CIM.DependencyResolver.Validate
Description: Checks for circular dependencies.
return: boolean valid - True if no circular dependencies.
return: string|nil error - Error message if invalid.
]]
--- @return boolean valid True if no circular dependencies
--- @return string|nil error Error message if invalid
function BETTERUI.CIM.DependencyResolver.Validate()
    local modules = BETTERUI.CIM.DependencyResolver._modules
    local visited = {}
    local inStack = {}

    local function visit(name, path)
        if inStack[name] then
            -- Circular dependency detected
            return false, "Circular dependency: " .. table.concat(path, " -> ") .. " -> " .. name
        end
        if visited[name] then
            return true, nil
        end

        visited[name] = true
        inStack[name] = true
        table.insert(path, name)

        local mod = modules[name]
        if mod and mod.dependencies then
            for _, dep in ipairs(mod.dependencies) do
                local ok, err = visit(dep, path)
                if not ok then
                    return false, err
                end
            end
        end

        table.remove(path)
        inStack[name] = false
        return true, nil
    end

    for name, _ in pairs(modules) do
        local ok, err = visit(name, {})
        if not ok then
            return false, err
        end
    end

    return true, nil
end

--[[
Function: BETTERUI.CIM.DependencyResolver.Resolve
Description: Returns modules in valid load order (topological sort).
return: table|nil order - Array of module names in load order.
return: string|nil error - Error message if invalid.
]]
--- @return table|nil order Array of module names in load order
--- @return string|nil error Error message if invalid
function BETTERUI.CIM.DependencyResolver.Resolve()
    local ok, err = BETTERUI.CIM.DependencyResolver.Validate()
    if not ok then
        return nil, err
    end

    local modules = BETTERUI.CIM.DependencyResolver._modules
    local sorted = {}
    local visited = {}

    local function visit(name)
        if visited[name] then return end
        visited[name] = true

        local mod = modules[name]
        if mod and mod.dependencies then
            for _, dep in ipairs(mod.dependencies) do
                visit(dep)
            end
        end

        table.insert(sorted, name)
    end

    -- Sort by priority first
    local byPriority = {}
    for name, mod in pairs(modules) do
        table.insert(byPriority, { name = name, priority = mod.priority or 100 })
    end
    table.sort(byPriority, function(a, b)
        return a.priority < b.priority
    end)

    -- Then topological sort
    for _, entry in ipairs(byPriority) do
        visit(entry.name)
    end

    return sorted, nil
end

--[[
Function: BETTERUI.CIM.DependencyResolver.GetDependenciesFor
Description: Returns the dependencies for a specific module.
param: moduleName (string) - The module to query.
return: table - Array of dependency names.
]]
--- @param moduleName string The module to query
--- @return table dependencies Array of dependency names
function BETTERUI.CIM.DependencyResolver.GetDependenciesFor(moduleName)
    local mod = BETTERUI.CIM.DependencyResolver._modules[moduleName]
    if mod then
        return mod.dependencies or {}
    end
    return {}
end

--[[
Function: BETTERUI.CIM.DependencyResolver.Clear
Description: Clears all registered modules (for testing).
]]
function BETTERUI.CIM.DependencyResolver.Clear()
    BETTERUI.CIM.DependencyResolver._modules = {}
end
