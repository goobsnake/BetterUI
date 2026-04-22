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

print("test_general_interface_source")

local moduleSource = read_file("Modules/GeneralInterface/Module.lua")
local setupSource = read_file("Modules/GeneralInterface/Setup.lua")
local nameplatesSource = read_file("Modules/Nameplates/Nameplates.lua")
local nameplateSettingsSource = read_file("Modules/Nameplates/Settings.lua")
local bootstrapSource = read_file("BetterUI.lua")

assert_not_contains(moduleSource, "GetNameplatesNamespace",
    "GeneralInterface module no longer owns a Nameplates namespace resolver")
assert_contains(moduleSource, "BETTERUI.Nameplates = BETTERUI.Nameplates or {}",
    "GeneralInterface module binds to the dedicated Nameplates module namespace")
assert_contains(moduleSource, "GeneralInterface.Nameplates = BETTERUI.Nameplates",
    "GeneralInterface module keeps Nameplates only as compatibility alias")

assert_not_contains(setupSource, "local nameplates = BETTERUI.Nameplates",
    "GeneralInterface setup no longer resolves Nameplates options")
assert_not_contains(setupSource, "GetNameplateOptions",
    "GeneralInterface setup no longer owns Nameplates settings composition")
assert_not_contains(setupSource, "SI_BETTERUI_NAMEPLATES_HEADER",
    "GeneralInterface panel no longer renders a Nameplates submenu")

assert_contains(nameplatesSource, "local Nameplates = BETTERUI.Nameplates",
    "Nameplates runtime resolves from the dedicated Nameplates module namespace")
assert_contains(nameplatesSource, "GeneralInterface.Nameplates = Nameplates",
    "Nameplates runtime repopulates the GeneralInterface alias for compatibility")
assert_contains(nameplatesSource, 'BETTERUI.CIM.TryRegisterModulePanel(Nameplates, "Nameplates", "Nameplates", "Nameplates")',
    "Nameplates runtime registers its own settings panel")
assert_contains(nameplateSettingsSource, "return BETTERUI.GetModuleSettings(\"Nameplates\")",
    "Nameplates settings keep the dedicated Nameplates module settings identity")
assert_contains(nameplateSettingsSource, "Nameplates.Settings = Nameplates.Settings or {}",
    "Nameplates settings expose the dedicated settings panel seam")
assert_contains(nameplateSettingsSource, "Nameplates.Settings.RegisterPanel = InitPanel",
    "Nameplates settings bind the dedicated panel registration helper")
assert_not_contains(bootstrapSource, "ResolveNameplatesNamespace",
    "Bootstrap no longer advertises split Nameplates namespace ownership")
assert_contains(bootstrapSource, "BETTERUI.Nameplates = BETTERUI.Nameplates or {}",
    "Bootstrap initializes Nameplates as a first-class module namespace")
assert_contains(bootstrapSource, "BETTERUI.GeneralInterface.Nameplates = BETTERUI.Nameplates",
    "Bootstrap keeps GeneralInterface.Nameplates as compatibility alias only")
assert_not_contains(bootstrapSource, 'depends = "GeneralInterface"',
    "Bootstrap no longer hard-couples Nameplates setup to GeneralInterface")

print("  OK")
