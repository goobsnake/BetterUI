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
local generalSettingsSource = read_file("Modules/GeneralInterface/Tooltips/Settings.lua")
local generalSettingsHelpersSource = read_file("Modules/GeneralInterface/Tooltips/SettingsHelpers.lua")
local tooltipsSource = read_file("Modules/GeneralInterface/Tooltips/Tooltips.lua")
local nameplatesSource = read_file("Modules/Nameplates/Nameplates.lua")
local nameplateSettingsSource = read_file("Modules/Nameplates/Settings.lua")
local bootstrapSource = read_file("BetterUI.lua")
local englishLocale = read_file("lang/en.lua")
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
local stockLayoutStart = assert(tooltipsSource:find("local function ApplyTooltipEquippedStockLayout", 1, true))
local stockLayoutEnd = assert(tooltipsSource:find("local function ClearTooltipEnhancementState", stockLayoutStart, true))
local stockLayoutSource = tooltipsSource:sub(stockLayoutStart, stockLayoutEnd)
assert_contains(stockLayoutSource, "UpdateTooltipEquippedText(normalizedTooltipType, equipSlot)",
    "Default tooltip stock layout refreshes BetterUI's stock fallback with a per-item equipped decision")
assert_contains(stockLayoutSource, "nativeTopAreaPreserved = true",
    "Default tooltip stock layout logs that native top area is preserved")
assert_contains(stockLayoutSource, "stockFallbackRefreshed =",
    "Default tooltip stock layout logs that BetterUI stock fallback state is refreshed")

local clearLinesStart = assert(tooltipsSource:find("local function InstallClearLinesHook", 1, true))
local clearLinesEnd = assert(tooltipsSource:find("local function InstallBagLayoutHook", clearLinesStart, true))
local clearLinesSource = tooltipsSource:sub(clearLinesStart, clearLinesEnd)
assert_contains(clearLinesSource, "local hasDisplayedItem = state.pendingItemLink ~= nil or self._betterui_itemLink ~= nil",
    "ClearLines preserves displayed-item tooltip metadata regardless of the enhancements toggle")
assert_contains(clearLinesSource, "local preserveStockLayoutState = hasDisplayedItem",
    "ClearLines passes displayed-item preservation into enhancement cleanup")
assert_not_contains(clearLinesSource, "enhancementsEnabled == false",
    "ClearLines preservation is not gated to disabled enhanced tooltips")

-- Regression: the tooltip content-lifecycle clear must be preserve-aware so the
-- stock re-layout cycle (native ClearLines then re-append of the SAME item while
-- enhancements are off) is not mis-detected as an immediate strip-after-append
-- (the vendor.sell WARN storm). A preserving clear keeps the lifecycle marker and
-- downgrades to a TRACE "preserved" record instead of a WARN "cleared".
local clearTraceStart = assert(tooltipsSource:find("local function TraceTooltipContentCleared", 1, true))
local clearTraceEnd = assert(tooltipsSource:find("local function SetGuildStoreErrorSuppressed", clearTraceStart, true))
local clearTraceSource = tooltipsSource:sub(clearTraceStart, clearTraceEnd)
assert_contains(clearTraceSource, "if preserveItemData == true then",
    "Tooltip content-clear trace branches on the preserve flag before flagging a clear")
assert_contains(clearTraceSource, "action = \"preserved\"",
    "Preserving tooltip clears emit a 'preserved' record instead of a strip-after-append warning")
local preserveBranchIndex = assert(clearTraceSource:find("if preserveItemData == true then", 1, true))
local markerResetIndex = assert(clearTraceSource:find("tooltipControl._betteruiTooltipContentLifecycle = nil", 1, true))
if markerResetIndex < preserveBranchIndex then
    error("Preserving clears must keep the lifecycle marker: the marker reset must follow the preserve-branch return")
end

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
assert_not_contains(bootstrapSource, "SI_BETTERUI_MASTER_SETTINGS_HEADER",
    "Bootstrap no longer renders a separate General Settings header before the merged General section")
assert_not_contains(bootstrapSource, "SI_BETTERUI_ENABLED_MODULE_SETTINGS_DESC",
    "Bootstrap no longer renders the retired master General description")
local globalSettingsIndex = assert(generalSettingsSource:find("SI_BETTERUI_ENABLE_GLOBAL_SETTINGS", 1, true))
local chatHistoryIndex = assert(generalSettingsSource:find("SI_BETTERUI_CHAT_HISTORY", 1, true))
if chatHistoryIndex < globalSettingsIndex then
    error("Use Global Settings must be authored before Chat History in the General section")
end
assert_contains(generalSettingsSource, "sortAlwaysFirst = true",
    "Use Global Settings is pinned above the alphabetized General controls")
assert_contains(generalSettingsHelpersSource, "BETTERUI.SavedVars.useAccountWide = (BETTERUI.DefaultSettings and BETTERUI.DefaultSettings.useAccountWide) == true",
    "General reset restores the Use Global Settings checkbox to its default")
assert_not_contains(englishLocale, "Tooltip content and market integrations.",
    "Enhanced Tooltips description no longer claims ownership of market integration settings")
assert_contains(englishLocale, "Customize enhanced tooltip content, style and trait details, and font size.",
    "Enhanced Tooltips description focuses on tooltip-specific behavior")
assert_contains(generalSettingsSource, "local function BuildEnhancedNameplatesControls()",
    "General Interface settings import the Nameplates settings controls for a merged dropdown")
assert_contains(generalSettingsSource, 'key = "enhancedNameplates"',
    "General Interface settings define an Enhanced Nameplates submenu")
assert_contains(generalSettingsSource, 'name = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_HEADER"))',
    "Enhanced Nameplates submenu uses the localized Enhanced Nameplates header")
local enhancedNameplatesIndex = assert(generalSettingsSource:find('key = "enhancedNameplates"', 1, true))
local enhancedTooltipsIndex = assert(generalSettingsSource:find('key = "enhancedTooltips"', 1, true))
if enhancedTooltipsIndex < enhancedNameplatesIndex then
    error("Enhanced Nameplates submenu must be authored before Enhanced Tooltips")
end
local nameplateOptionsStart = assert(nameplateSettingsSource:find("function Nameplates.GetSettingsOptions()", 1, true))
local nameplateDescriptionIndex = assert(nameplateSettingsSource:find("SI_BETTERUI_NAMEPLATES_DESC", nameplateOptionsStart, true))
local nameplateEnableIndex = assert(nameplateSettingsSource:find("SI_BETTERUI_NAMEPLATES_ENABLED", nameplateOptionsStart, true))
if nameplateEnableIndex < nameplateDescriptionIndex then
    error("Enhanced Nameplates description must be the first control in the dropdown")
end
local nameplateOpeningControls = nameplateSettingsSource:sub(nameplateOptionsStart, nameplateEnableIndex)
assert_not_contains(nameplateOpeningControls, 'type = "header"',
    "Enhanced Nameplates dropdown opens with its description instead of a nested General header")
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
