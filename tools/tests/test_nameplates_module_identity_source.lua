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
local nameplates = read_file("Modules/Nameplates/Nameplates.lua")
local settings = read_file("Modules/Nameplates/Settings.lua")

assert_contains(types, '---| "Nameplates"',
    "ModuleName aliases include the Nameplates runtime identity")
assert_contains(bootstrap, 'name = "Nameplates",',
    "The module registry keeps a first-class Nameplates entry")
assert_contains(bootstrap, 'namespace = "Nameplates",',
    "The Nameplates registry entry points at the dedicated namespace")
assert_contains(bootstrap, 'depends = "GeneralInterface"',
    "The Nameplates registry entry preserves the GeneralInterface enablement dependency")
assert_contains(bootstrap, "BETTERUI.ResolveNameplatesNamespace = ResolveNameplatesNamespace",
    "Bootstrap exposes the canonical Nameplates namespace resolver")
assert_contains(bootstrap, "BETTERUI.GeneralInterface.Nameplates = ResolveNameplatesNamespace()",
    "Bootstrap establishes GeneralInterface as the canonical Nameplates namespace owner")
assert_contains(bootstrap, "BETTERUI.Nameplates = BETTERUI.GeneralInterface.Nameplates",
    "Bootstrap keeps BETTERUI.Nameplates as a compatibility alias")

assert_contains(generalInterface, 'GeneralInterface.GetNameplatesNamespace = GetNameplatesNamespace',
    "GeneralInterface exposes one canonical Nameplates namespace seam")
assert_contains(generalInterface, 'BETTERUI.ResolveNameplatesNamespace',
    "GeneralInterface reuses the bootstrap-owned Nameplates resolver")

assert_contains(nameplates, 'Nameplates.ARCHETYPE = SETTINGS_OWNER',
    "Nameplates declares its own module archetype")
assert_contains(nameplates, 'Nameplates.ROOT_CONTRACT = {',
    "Nameplates publishes a dedicated module root contract")
assert_contains(nameplates, 'name = "Nameplates",',
    "The Nameplates root contract uses the canonical module name")
assert_contains(nameplates, 'GeneralInterface.GetNameplatesNamespace',
    "Nameplates runtime binds through the shared GeneralInterface namespace seam")
assert_contains(nameplates, 'BETTERUI.Nameplates = BETTERUI.Nameplates or Nameplates',
    "Nameplates runtime republishes BETTERUI.Nameplates as a compatibility alias only when missing")
assert_contains(settings, 'GeneralInterface.GetNameplatesNamespace',
    "Nameplates settings reuse the shared GeneralInterface namespace seam")

print("  OK")
