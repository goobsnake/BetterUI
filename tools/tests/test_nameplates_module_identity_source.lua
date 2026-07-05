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
local positioning = read_file("Modules/Nameplates/Positioning.lua")
local settings = read_file("Modules/Nameplates/Settings.lua")
local defaultsRegistry = read_file("Modules/CIM/Core/Settings/DefaultsRegistry.lua")
local settingsMetadata = read_file("Modules/CIM/Core/Settings/SettingsMetadata.lua")
local englishLocale = read_file("lang/en.lua")
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
assert_contains(bootstrap, 'loadOverride = function()',
    "The Nameplates registry entry declares a positioning load override")
assert_contains(bootstrap, 'settings.nameplatePositionsUnlocked == true',
    "The Nameplates load override keys off the drag-handle unlock toggle")
assert_contains(bootstrap, 'settings.movePlayerInteract == true',
    "The Nameplates load override keys off the player-interact mover toggle")
assert_contains(bootstrap, 'BETTERUI.GetModuleEnabled(entry.name) or IsModuleLoadOverrideActive(entry)',
    "Module loading honors loadOverride so HUD movers survive a disabled Enhanced Nameplates toggle")

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
assert_contains(positioning, "Nameplates.Positioning = Positioning",
    "Nameplates positioning helper stays under the dedicated Nameplates namespace")
assert_contains(positioning, '"ZO_CompassFrame"',
    "Nameplates positioning helper targets the ESO compass frame control")
assert_contains(positioning, "frame:SetDimensions(targetW, targetH)",
    "Compass scaling resizes the frame the way ZOS does (dimensions, not scale)")
assert_not_contains(positioning, "SetScale, compass",
    "Compass pin strip is never SetScale'd; C-side pin math sprays markers across the screen")
assert_contains(positioning, "not descriptor.applyScale and type(control.SetScale)",
    "Descriptors with a custom applyScale are excluded from the generic SetScale path")
assert_contains(positioning, 'CHAINED_TRACKER_GLOBALS = { "ZONE_STORY_TRACKER", "PROMOTIONAL_EVENT_TRACKER" }',
    "Quest-follow chain strips the X pin on both zone story and Golden Pursuits trackers")
assert_not_contains(positioning, "questPanel, bottomRight",
    "HUD trackers are never anchored to the quest panel; that closes an anchor cycle that drops the panel")
assert_contains(positioning, "primary:AddToControl(control)",
    "Chained trackers reuse ZOS's own primary anchor without the screen-edge secondary")
assert_contains(positioning, '"ZO_TargetUnitFramereticleover"',
    "Nameplates positioning helper targets the ESO target/NPC bar control")
assert_contains(positioning, '"ZO_PlayerToPlayerAreaPromptContainer"',
    "Nameplates positioning helper targets the ESO player interact control")
assert_not_contains(positioning, '"ZO_ReticleContainerInteract"',
    "Nameplates positioning no longer targets the reticle prompt")
assert_not_contains(positioning, "moveReticlePrompt",
    "Nameplates positioning no longer owns a reticle mover descriptor")
assert_contains(positioning, 'local parent = EnsureHandleLayer() or rawget(_G, "GuiRoot") or hostControl',
    "Nameplates positioning drag handles are rooted outside transient live controls")
assert_contains(positioning, 'windowManager:CreateTopLevelWindow("BetterUI_NameplateMoverLayer")',
    "Nameplates positioning handles live under a top-level window; GuiRoot children never enter ESO's render list")
assert_contains(positioning, "handle:SetParent(parent)",
    "Nameplates positioning drag handles are reused when the active host control changes")
assert_not_contains(positioning, "handles[key] = nil",
    "Nameplates positioning does not drop handles and recreate duplicate named controls")
assert_contains(positioning, "local useLiveHost = false",
    "Nameplates positioning keeps unlocked drag handles on stable placeholder anchors")
assert_contains(positioning, "relativeTo = rawget(_G, \"GuiRoot\")",
    "Nameplates positioning hidden-frame fallbacks anchor to GuiRoot instead of transient prompt containers")
assert_not_contains(positioning, "UI-TooltipCenter.dds",
    "Nameplates positioning keeps the engine-default color-fill backdrop (texture overrides regressed visibility)")
assert_not_contains(positioning, "SetEdgeTexture",
    "Nameplates positioning does not override the backdrop edge texture")
assert_contains(positioning, "handle:SetHidden(false)",
    "Nameplates positioning keeps handle roots alive so unlock can restore hidden HUD movers")
assert_not_contains(positioning, "handle:SetHidden(visible ~= true)",
    "Nameplates positioning does not hard-hide drag handle roots while locked")
assert_not_contains(positioning, "IsModuleEnabled",
    "General HUD positioning is not gated by the Enhanced Nameplates text toggle")
assert_contains(settings, "disabled = function() return false end",
    "General HUD positioning controls remain available without enabling Enhanced Nameplates")
assert_contains(positioning, "EsoUI/Art/Buttons/leftArrow_up.dds",
    "Nameplates positioning uses native gold ESO arrow art for drag handles")
assert_contains(positioning, "EsoUI/Art/Buttons/scrollbox_downArrow_up.dds",
    "Nameplates positioning keeps all four native gold arrow directions")
assert_not_contains(positioning, "housing_precisionControlIcon",
    "Nameplates positioning avoids the housing icons' baked-in per-axis colors")
assert_not_contains(positioning, "SetTextureRotation",
    "Nameplates positioning uses native directional arrow art instead of runtime texture rotation")
assert_not_contains(nameplates, "moveReticlePrompt",
    "Nameplates runtime no longer carries reticle mover settings")
assert_not_contains(settings, "moveReticlePrompt",
    "Nameplates settings UI no longer exposes reticle mover settings")
assert_not_contains(types, "moveReticlePrompt",
    "CIM types no longer declare reticle mover settings")
assert_not_contains(defaultsRegistry, "moveReticlePrompt",
    "CIM defaults no longer seed reticle mover settings")
assert_not_contains(settingsMetadata, "SI_BETTERUI_NAMEPLATES_MOVE_RETICLE",
    "CIM settings metadata no longer references reticle mover strings")
assert_not_contains(englishLocale, "SI_BETTERUI_NAMEPLATES_MOVE_RETICLE",
    "English locale no longer defines reticle mover strings")
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
assert_contains(architectureDoc, "| **Nameplates** | Nameplates, Positioning, Settings |",
    "Architecture doc records the Nameplates positioning helper")

print("  OK")
