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

print("test_general_interface_source")

local moduleSource = read_file("Modules/GeneralInterface/Module.lua")
local setupSource = read_file("Modules/GeneralInterface/Setup.lua")
local nameplatesSource = read_file("Modules/GeneralInterface/Nameplates/Nameplates.lua")
local nameplateSettingsSource = read_file("Modules/GeneralInterface/Nameplates/Settings.lua")
local bootstrapSource = read_file("BetterUI.lua")

assert_contains(moduleSource, "local function GetNameplatesNamespace()",
    "GeneralInterface module defines one canonical Nameplates namespace seam")
assert_contains(moduleSource, "GeneralInterface.GetNameplatesNamespace = GetNameplatesNamespace",
    "GeneralInterface publishes the Nameplates namespace seam for sibling files")
assert_contains(moduleSource, "local nameplates = GeneralInterface.Nameplates",
    "GeneralInterface resolves Nameplates from its own namespace root first")
assert_contains(moduleSource, "BETTERUI.Nameplates = nameplates",
    "GeneralInterface maintains BETTERUI.Nameplates only as compatibility alias")

assert_contains(setupSource, "local function ResolveNameplatesNamespace()",
    "GeneralInterface setup resolves Nameplates through one canonical namespace seam")
assert_contains(setupSource, "GeneralInterface.GetNameplatesNamespace",
    "GeneralInterface setup uses the shared Nameplates namespace seam")
assert_contains(setupSource, "local nameplates = GeneralInterface.Nameplates",
    "GeneralInterface setup treats the GeneralInterface root as canonical")

assert_contains(nameplatesSource, "GeneralInterface.GetNameplatesNamespace",
    "Nameplates runtime resolves its table through the shared GeneralInterface seam")
assert_contains(nameplatesSource, "Nameplates = GeneralInterface.Nameplates",
    "Nameplates module binds to the GeneralInterface namespace root")
assert_contains(nameplateSettingsSource, "return BETTERUI.GetModuleSettings(\"Nameplates\")",
    "Nameplates settings keep the dedicated Nameplates module settings identity")
assert_contains(bootstrapSource, "BETTERUI.GeneralInterface.Nameplates = BETTERUI.GeneralInterface.Nameplates or BETTERUI.Nameplates or {}",
    "Bootstrap canonicalizes the Nameplates namespace under GeneralInterface")
assert_contains(bootstrapSource, "BETTERUI.Nameplates = BETTERUI.GeneralInterface.Nameplates",
    "Bootstrap keeps BETTERUI.Nameplates as compatibility alias")

print("  OK")
