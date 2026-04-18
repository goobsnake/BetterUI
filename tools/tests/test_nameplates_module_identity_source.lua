--[[
File: tools/tests/test_nameplates_module_identity_source.lua
Purpose: Locks the Nameplates module identity so registry names, typed module
         aliases, and root contracts stay aligned.
Usage:
  lua tools/tests/test_nameplates_module_identity_source.lua
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

print("test_nameplates_module_identity_source")

local bootstrap = read_file("BetterUI.lua")
local types = read_file("Modules/CIM/Core/Data/Types.lua")
local generalInterface = read_file("Modules/GeneralInterface/Module.lua")
local nameplates = read_file("Modules/GeneralInterface/Nameplates/Nameplates.lua")

assert_contains(types, '---| "Nameplates"',
    "ModuleName aliases include the Nameplates runtime identity")
assert_contains(bootstrap, 'name = "Nameplates",',
    "The module registry keeps a first-class Nameplates entry")
assert_contains(bootstrap, 'namespace = "Nameplates",',
    "The Nameplates registry entry points at the dedicated namespace")
assert_contains(bootstrap, 'depends = "GeneralInterface"',
    "The Nameplates registry entry preserves the GeneralInterface enablement dependency")

assert_contains(generalInterface, 'runtimeOwner = "Modules/GeneralInterface/Tooltips/",',
    "GeneralInterface runtime ownership no longer absorbs Nameplates runtime hooks")
assert_contains(generalInterface, 'nests the separate Nameplates submenu',
    "GeneralInterface notes document Nameplates as a separate module surfaced through the shared panel")

assert_contains(nameplates, 'Nameplates.ARCHETYPE = "settings-owner"',
    "Nameplates declares its own module archetype")
assert_contains(nameplates, 'Nameplates.ROOT_CONTRACT = {',
    "Nameplates publishes a dedicated module root contract")
assert_contains(nameplates, 'name = "Nameplates",',
    "The Nameplates root contract uses the canonical module name")
assert_contains(nameplates, 'runtimeOwner = "Modules/GeneralInterface/Nameplates/Nameplates.lua",',
    "Nameplates runtime ownership points at its dedicated module file")

print("  OK")
