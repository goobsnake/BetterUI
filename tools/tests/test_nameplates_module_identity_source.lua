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
local generalInterfaceSetup = read_file("Modules/GeneralInterface/Setup.lua")
local nameplates = read_file("Modules/Nameplates/Nameplates.lua")
local settings = read_file("Modules/Nameplates/Settings.lua")
local contributingGuide = read_file("docs/guides/contributing-guide.md")
local architectureDoc = read_file("docs/reference/architecture.md")

assert_contains(types, '---| "Nameplates"',
    "ModuleName aliases include the Nameplates runtime identity")
assert_contains(bootstrap, 'name = "Nameplates",',
    "The module registry keeps a first-class Nameplates entry")
assert_contains(bootstrap, 'namespace = "Nameplates",',
    "The Nameplates registry entry points at the dedicated namespace")
assert_not_contains(bootstrap, 'depends = "GeneralInterface"',
    "The Nameplates registry entry is no longer coupled to GeneralInterface enablement")
assert_not_contains(bootstrap, "ResolveNameplatesNamespace",
    "Bootstrap no longer exposes split Nameplates namespace ownership seams")
assert_contains(bootstrap, "BETTERUI.Nameplates = BETTERUI.Nameplates or {}",
    "Bootstrap initializes Nameplates as a first-class module namespace")
assert_not_contains(bootstrap, "BETTERUI.GeneralInterface.Nameplates = BETTERUI.Nameplates",
    "Bootstrap no longer publishes a GeneralInterface.Nameplates compatibility alias")
assert_contains(bootstrap, 'moduleName = "Nameplates"',
    "Master module toggles expose Nameplates as a first-class module toggle")

assert_not_contains(generalInterface, "GetNameplatesNamespace",
    "GeneralInterface no longer exports Nameplates namespace ownership seams")
assert_not_contains(generalInterface, "GeneralInterface.Nameplates",
    "GeneralInterface no longer carries Nameplates compatibility aliases")
assert_not_contains(generalInterfaceSetup, "GetNameplateOptions",
    "GeneralInterface setup no longer owns Nameplates settings composition")
assert_not_contains(generalInterfaceSetup, "SI_BETTERUI_NAMEPLATES_HEADER",
    "GeneralInterface setup no longer renders Nameplates options in its panel")

assert_contains(nameplates, 'Nameplates.ARCHETYPE = SETTINGS_OWNER',
    "Nameplates declares its own module archetype")
assert_contains(nameplates, 'Nameplates.ROOT_CONTRACT = {',
    "Nameplates publishes a dedicated module root contract")
assert_contains(nameplates, 'name = "Nameplates",',
    "The Nameplates root contract uses the canonical module name")
assert_contains(nameplates, "local Nameplates = BETTERUI.Nameplates",
    "Nameplates runtime binds through the dedicated Nameplates module namespace")
assert_contains(nameplates, "Nameplates.Settings = Nameplates.Settings or {}",
    "Nameplates runtime owns the module settings seam namespace")
assert_contains(nameplates, "Nameplates.Settings.RegisterPanel = InitPanel",
    "Nameplates runtime binds panel registration through the canonical root")
assert_not_contains(nameplates, "local function TrackPanelRegistration(reason)",
    "Nameplates runtime delegates panel registration tracking to the shared CIM helper")
assert_contains(nameplates, "function Nameplates.InitModule(m_options)",
    "Nameplates runtime owns InitModule defaults and migration behavior")
assert_not_contains(nameplates, "GeneralInterface.Nameplates = Nameplates",
    "Nameplates runtime no longer synchronizes GeneralInterface alias ownership")
assert_contains(nameplates, 'BETTERUI.CIM.RegisterModulePanelWithLogging(Nameplates, "Nameplates", "Nameplates", "Nameplates")',
    "Nameplates setup registers a dedicated Nameplates settings panel")
assert_not_contains(nameplates, "TrackPanelRegistration(panelReason)",
    "Nameplates setup no longer duplicates the shared panel registration diagnostics boilerplate")
assert_contains(settings, "local Nameplates = BETTERUI.Nameplates",
    "Nameplates settings bind through the dedicated Nameplates module namespace")
assert_not_contains(settings, "Nameplates.Settings.RegisterPanel = InitPanel",
    "Nameplates settings helper no longer owns panel registration")
assert_not_contains(settings, "function Nameplates.InitModule(m_options)",
    "Nameplates settings helper no longer owns InitModule defaults")
assert_not_contains(contributingGuide, "`settings-owner`: `Module.lua` is the canonical root and also owns the package's settings surface.",
    "Contributing guide no longer claims settings-owner modules must root at Module.lua")
assert_contains(contributingGuide, "`settings-owner`: one canonical root file owns both runtime and settings seams.",
    "Contributing guide documents the shared settings-owner root ownership contract")
assert_contains(contributingGuide, "`Nameplates` is a `settings-owner` package with [`Nameplates.lua`",
    "Contributing guide documents Nameplates.lua as the Nameplates canonical root shape")
assert_contains(architectureDoc, "| `settings-owner` | `Module.lua` **or** `<Module>.lua`, but ownership stays singular in one root |",
    "Architecture doc allows both settings-owner canonical root shapes")
assert_contains(architectureDoc, "`Nameplates` (`Nameplates.lua`)",
    "Architecture doc records Nameplates.lua as the active Nameplates canonical root")

print("  OK")
