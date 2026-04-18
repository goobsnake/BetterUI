--[[
File: tools/tests/test_writs_root_contract_source.lua
Purpose: Guards the Writs module root so it matches the standard BetterUI
         module contract surface and keeps the filesystem/root identity
         aligned to the canonical Writs name.
Usage:
  lua tools/tests/test_writs_root_contract_source.lua
]]

if false then
    dofile("Modules/Writs/Module.lua")
end

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

print("test_writs_root_contract_source")

local moduleSource = read_file("Modules/Writs/Module.lua")
local typesSource = read_file("Modules/CIM/Core/Data/Types.lua")

assert_contains(moduleSource, "---@type BetterUIModuleRoot", "Writs root declares the standard module-root type")
assert_contains(moduleSource, "local Writs = BETTERUI.Writs", "Writs root binds a canonical local module handle")
assert_contains(moduleSource, "Writs.ROOT_CONTRACT = {", "Writs root declares a root contract")
assert_contains(moduleSource, 'name = "Writs"', "Writs root contract uses the canonical module identity")
assert_contains(moduleSource, "local function ApplyWritsDefaults(m_options)",
    "Writs root owns a local defaults adapter")
assert_contains(moduleSource, 'function Writs.InitModule(m_options)', "Writs root exposes the standard InitModule hook")
assert_contains(moduleSource, 'GetModuleDefaults("Writs")',
    "Writs InitModule delegates to DefaultsRegistry")
assert_contains(moduleSource, 'ApplyModuleDefaults("Writs", m_options)',
    "Writs InitModule uses DefaultsRegistry directly")
if moduleSource:find('RegisterModuleAccessors%("Writs"%)') then
    error("Writs root should not register CIM accessors directly anymore")
end
if moduleSource:find('BETTERUI%.CIM%.InitModuleDefaults%("Writs"') then
    error("Writs InitModule should not use the CIM defaults helper anymore")
end
assert_contains(moduleSource, 'function Writs.Setup()', "Writs root exposes the standard Setup hook")
assert_contains(typesSource, '---| "Writs"', "ModuleName type includes the canonical Writs identity")

print("  OK")
