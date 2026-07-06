--[[
File: tools/tests/test_registry_dependency_contract_source.lua
Purpose: Guards the module registry as the canonical source of CIM dependency
         truth so registry gating and CIM auto-enable behavior do not drift.
Usage:
  lua tools/tests/test_registry_dependency_contract_source.lua
]]

local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local function assert_contains(haystack, needle, label)
    if not haystack:find(needle, 1, true) then
        error(label .. "\nMissing: " .. needle)
    end
end

local function assert_not_contains(haystack, needle, label)
    if haystack:find(needle, 1, true) then
        error(label .. "\nUnexpected: " .. needle)
    end
end

print("test_registry_dependency_contract_source")

local source = read_file("BetterUI.lua")

assert_contains(source, '---@field dependsOnCIM boolean|nil Whether the module requires the CIM shared platform',
    "ModuleRegistryEntry documents dependsOnCIM")
assert_contains(source, '{ name = "GeneralInterface", namespace = "GeneralInterface", dependsOnCIM = true',
    "GeneralInterface registry entry declares its CIM dependency")
assert_contains(source, 'name = "GeneralInterface", namespace = "GeneralInterface", dependsOnCIM = true, alwaysLoad = true',
    "GeneralInterface registry entry remains always-load while declaring its CIM dependency")
assert_contains(source, '{ name = "Writs", namespace = "Writs", dependsOnCIM = true },',
    "Writs registry entry declares its CIM dependency")
assert_contains(source, 'name = "Nameplates",',
    "Nameplates remains a first-class registry entry")
assert_contains(source, 'dependsOnCIM = true,',
    "Nameplates registry entry declares its CIM dependency")
assert_not_contains(source, 'depends = "GeneralInterface"',
    "Nameplates registry entry does not use legacy GeneralInterface dependency gating")
assert_contains(source, 'for _, entry in ipairs(MODULE_REGISTRY) do',
    "UpdateCIMState iterates the registry instead of duplicating dependent names")
assert_contains(source, 'if entry.dependsOnCIM and (entry.alwaysLoad == true or BETTERUI.GetModuleEnabled(entry.name)) then',
    "UpdateCIMState enables CIM from registry-declared always-load or enabled dependents")
assert_contains(source, 'if updatesCIM == nil then',
    "module toggle wiring falls back to registry CIM metadata")
assert_contains(source, 'updatesCIM = ModuleDependsOnCIM(moduleName)',
    "module toggle wiring reuses the registry helper")

print("  OK")
