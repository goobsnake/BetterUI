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

local function assert_not_contains(haystack, needle, label)
    if haystack:find(needle, 1, true) then
        error(label .. "\nUnexpected: " .. needle)
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
assert_not_contains(bootstrap, "ResolveNameplatesNamespace",
    "Bootstrap no longer exposes split Nameplates namespace ownership seams")
assert_contains(bootstrap, "BETTERUI.Nameplates = BETTERUI.Nameplates or {}",
    "Bootstrap initializes Nameplates as a first-class module namespace")
assert_contains(bootstrap, "BETTERUI.GeneralInterface.Nameplates = BETTERUI.Nameplates",
    "Bootstrap keeps GeneralInterface.Nameplates as compatibility alias only")

assert_not_contains(generalInterface, "GetNameplatesNamespace",
    "GeneralInterface no longer exports Nameplates namespace ownership seams")
assert_contains(generalInterface, "GeneralInterface.Nameplates = BETTERUI.Nameplates",
    "GeneralInterface keeps a compatibility alias to the dedicated Nameplates module")

assert_contains(nameplates, 'Nameplates.ARCHETYPE = SETTINGS_OWNER',
    "Nameplates declares its own module archetype")
assert_contains(nameplates, 'Nameplates.ROOT_CONTRACT = {',
    "Nameplates publishes a dedicated module root contract")
assert_contains(nameplates, 'name = "Nameplates",',
    "The Nameplates root contract uses the canonical module name")
assert_contains(nameplates, "local Nameplates = BETTERUI.Nameplates",
    "Nameplates runtime binds through the dedicated Nameplates module namespace")
assert_contains(nameplates, "GeneralInterface.Nameplates = Nameplates",
    "Nameplates runtime keeps the GeneralInterface alias synchronized for compatibility")
assert_contains(settings, "local Nameplates = BETTERUI.Nameplates",
    "Nameplates settings bind through the dedicated Nameplates module namespace")

print("  OK")
