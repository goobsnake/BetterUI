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
local tooltipsSource = read_file("Modules/GeneralInterface/Tooltips/Tooltips.lua")
local nameplatesSource = read_file("Modules/Nameplates/Nameplates.lua")
local nameplateSettingsSource = read_file("Modules/Nameplates/Settings.lua")
local bootstrapSource = read_file("BetterUI.lua")
local contributingGuide = read_file("docs/guides/contributing-guide.md")
local architectureDoc = read_file("docs/reference/architecture.md")

assert_not_contains(moduleSource, "GetNameplatesNamespace",
    "GeneralInterface module no longer owns a Nameplates namespace resolver")
assert_not_contains(moduleSource, "BETTERUI.Nameplates",
    "GeneralInterface module no longer bootstraps Nameplates ownership or aliases")
assert_not_contains(moduleSource, "GeneralInterface.Nameplates",
    "GeneralInterface module no longer exports a Nameplates compatibility alias")

assert_not_contains(setupSource, "local nameplates = BETTERUI.Nameplates",
    "GeneralInterface setup no longer resolves Nameplates options")
assert_not_contains(setupSource, "GetNameplateOptions",
    "GeneralInterface setup no longer owns Nameplates settings composition")
assert_not_contains(setupSource, "SI_BETTERUI_NAMEPLATES_HEADER",
    "GeneralInterface panel no longer renders a Nameplates submenu")
assert_not_contains(setupSource, "type(ZO_PostHook) == \"function\" and ZO_PostHook or ZO_PreHook",
    "GeneralInterface setup no longer falls back to ZO_PreHook")
assert_contains(setupSource, "if type(ZO_PostHook) ~= \"function\" then",
    "GeneralInterface setup requires ZO_PostHook before installing mail-delete hook")
local stockRelayoutStart = assert(tooltipsSource:find("local function ScheduleTooltipEquippedStockRelayout", 1, true))
local stockRelayoutEnd = assert(tooltipsSource:find("local function ClearTooltipEnhancementState", stockRelayoutStart, true))
local stockRelayoutSource = tooltipsSource:sub(stockRelayoutStart, stockRelayoutEnd)
assert_contains(stockRelayoutSource, "UpdateTooltipEquippedText(normalizedTooltipType, nil)",
    "Default tooltip stock relayout still refreshes BetterUI's stock fallback price/body state")
assert_contains(stockRelayoutSource, "nativeTopAreaPreserved = true",
    "Default tooltip stock relayout logs that native top area is preserved")
assert_contains(stockRelayoutSource, "stockFallbackRefreshed =",
    "Default tooltip stock relayout logs that BetterUI stock fallback state is refreshed")

assert_contains(nameplatesSource, "local Nameplates = BETTERUI.Nameplates",
    "Nameplates runtime resolves from the dedicated Nameplates module namespace")
assert_not_contains(nameplatesSource, "GeneralInterface.Nameplates = Nameplates",
    "Nameplates runtime no longer backfills GeneralInterface aliases")
assert_contains(nameplatesSource, "Nameplates.Settings = Nameplates.Settings or {}",
    "Nameplates runtime owns the settings seam namespace")
assert_contains(nameplatesSource, "Nameplates.Settings.RegisterPanel = InitPanel",
    "Nameplates runtime owns panel registration through the root file")
assert_contains(nameplatesSource, "function Nameplates.InitModule(m_options)",
    "Nameplates runtime owns module defaults/init behavior")
assert_contains(nameplatesSource, 'BETTERUI.CIM.RegisterModulePanelWithLogging(Nameplates, "Nameplates", "Nameplates", "Nameplates")',
    "Nameplates runtime registers its own settings panel")
assert_contains(nameplateSettingsSource, "return BETTERUI.GetModuleSettings(\"Nameplates\")",
    "Nameplates settings keep the dedicated Nameplates module settings identity")
assert_not_contains(nameplateSettingsSource, "Nameplates.Settings.RegisterPanel = InitPanel",
    "Nameplates settings helper no longer owns panel registration")
assert_not_contains(nameplateSettingsSource, "function Nameplates.InitModule(m_options)",
    "Nameplates settings helper no longer owns InitModule defaults")
assert_not_contains(bootstrapSource, "ResolveNameplatesNamespace",
    "Bootstrap no longer advertises split Nameplates namespace ownership")
assert_contains(bootstrapSource, "BETTERUI.Nameplates = BETTERUI.Nameplates or {}",
    "Bootstrap initializes Nameplates as a first-class module namespace")
assert_not_contains(bootstrapSource, "BETTERUI.GeneralInterface.Nameplates = BETTERUI.Nameplates",
    "Bootstrap no longer publishes GeneralInterface.Nameplates compatibility aliases")
assert_not_contains(bootstrapSource, 'depends = "GeneralInterface"',
    "Bootstrap no longer hard-couples Nameplates setup to GeneralInterface")
assert_contains(contributingGuide, "`settings-owner`: one canonical root file owns both runtime and settings seams.",
    "Contributing guide documents that settings-owner modules keep a single canonical root owner")
assert_not_contains(contributingGuide, "`settings-owner`: `Module.lua` is the canonical root and also owns the package's settings surface.",
    "Contributing guide no longer forces settings-owner modules to root at Module.lua")
assert_contains(contributingGuide, "`runtime-coordinator`: the canonical root coordinates runtime lifecycle and shared services.",
    "Contributing guide aligns archetype wording with runtime-coordinator contracts")
assert_not_contains(contributingGuide, "`runtime-facade`:",
    "Contributing guide no longer uses the legacy runtime-facade archetype label")
assert_contains(architectureDoc, "| **GeneralInterface** | Module, Setup | Tooltips | Requires CIM; registry-managed module |",
    "Architecture doc reflects GeneralInterface as a registry-managed CIM-dependent module")
assert_contains(architectureDoc, "| **Nameplates** | Nameplates, Positioning, Settings | (root-owned helpers) | Requires CIM; registry-managed module |",
    "Architecture doc reflects Nameplates as a registry-managed CIM-dependent module")

print("  OK")
