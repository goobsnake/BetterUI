--[[
File: tools/tests/test_bootstrap_setup_contracts_source.lua
Purpose: Guards bootstrap setup contracts so module accessors register during
         setup, panel registration follows one non-fatal helper, and inventory
         entry formatting resolves active module scenes through live instances.
Usage:
  lua tools/tests/test_bootstrap_setup_contracts_source.lua
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

print("test_bootstrap_setup_contracts_source")

local accessorSource = read_file("Modules/CIM/Core/Settings/SettingsAccessor.lua")
local cimModule = read_file("Modules/CIM/Module.lua")
local inventoryModule = read_file("Modules/Inventory/Module.lua")
local vendorModule = read_file("Modules/Vendor/Module.lua")
local companionsModule = read_file("Modules/Companions/Module.lua")
local bankingModule = read_file("Modules/Banking/Module.lua")
local tradingHouseModule = read_file("Modules/TradingHouse/Module.lua")
local resourceOrbModule = read_file("Modules/ResourceOrbFrames/Module.lua")
local writsModule = read_file("Modules/Writs/Module.lua")
local generalInterfaceSetup = read_file("Modules/GeneralInterface/Setup.lua")
local nameplatesModule = read_file("Modules/Nameplates/Nameplates.lua")
local nameplatesPositioning = read_file("Modules/Nameplates/Positioning.lua")
local nameplatesSettings = read_file("Modules/Nameplates/Settings.lua")
local resourceOrbElementDrag = read_file("Modules/ResourceOrbFrames/Core/ElementDrag.lua")
local inventoryFormatting = read_file("Modules/Inventory/Lists/InventoryEntryFormatting.lua")

assert_contains(accessorSource, "function BETTERUI.CIM.ApplyModuleSharedSettingsStatics(",
    "CIM exposes the pure import-time shared settings helper")
assert_contains(accessorSource, "function BETTERUI.CIM.TryRegisterModulePanel(",
    "CIM exposes the shared non-fatal module panel helper")
assert_contains(accessorSource, "function BETTERUI.CIM.RegisterModulePanelWithLogging(",
    "CIM exposes the consolidated panel registration helper with tracking and debug reporting")
assert_contains(accessorSource, "ns._sharedAccessorsRegistered = true",
    "module accessors are tracked as setup-time registration state")

assert_contains(cimModule, 'local RUNTIME_COORDINATOR = ARCHETYPES.RUNTIME_COORDINATOR or "runtime-coordinator"',
    "CIM resolves the runtime-coordinator archetype from shared archetype constants")
assert_contains(cimModule, 'CIM.ROOT_CONTRACT = {',
    "CIM defines a documented root contract")
assert_contains(cimModule, 'name = "CIM",',
    "CIM root contract declares module ownership")
assert_contains(cimModule, "setup = false,",
    "CIM root contract opts out of setup-time invocation")
assert_not_contains(cimModule, "function CIM.Setup(",
    "CIM remains bootstrap-owned and does not define a root Setup hook")

assert_contains(inventoryModule, 'BETTERUI.CIM.ApplyModuleSharedSettingsStatics(Inventory, "Inventory")',
    "Inventory keeps only pure shared settings statics at import time")
assert_contains(inventoryModule, 'function Inventory.Setup()',
    "Inventory exposes an explicit setup-time hook")
assert_contains(inventoryModule, 'RegisterSharedItemSupport()',
    "Inventory.Setup() performs SharedItemSupport registration during setup")
assert_contains(inventoryModule, 'BETTERUI.CIM.RegisterModuleAccessors(Inventory, "Inventory")',
    "Inventory registers accessors during setup")
assert_contains(inventoryModule, 'BETTERUI.CIM.Keybinds.RegisterInventoryActionModes({',
    "Inventory action-mode registration now lives behind setup-time bootstrap")
assert_contains(inventoryModule, 'BETTERUI.CIM.RegisterModulePanelWithLogging(Inventory, "Inventory", "Inventory", "Inventory")',
    "Inventory setup uses the shared panel registration helper")

assert_contains(vendorModule, 'BETTERUI.CIM.ApplyModuleSharedSettingsStatics(Vendor, "Vendor")',
    "Vendor keeps only pure shared settings statics at import time")
assert_contains(vendorModule, 'function BETTERUI.Vendor.Setup()',
    "Vendor exposes an explicit setup-time hook")
assert_contains(vendorModule, 'BETTERUI.CIM.RegisterModuleAccessors(Vendor, "Vendor")',
    "Vendor registers accessors during setup")
assert_contains(vendorModule, 'BETTERUI.CIM.TryRegisterModulePanel(Vendor, "Vendor", "Vendor", "Vendor")',
    "Vendor setup uses the shared panel registration helper")

assert_contains(companionsModule, 'BETTERUI.CIM.ApplyModuleSharedSettingsStatics(Companions, MODULE_NAME)',
    "Companions keeps only pure shared settings statics at import time")
assert_contains(companionsModule, 'local function EnsureCompanionsSetupContracts()',
    "Companions defines an explicit setup-time bootstrap helper")
assert_contains(companionsModule, 'BETTERUI.CIM.RegisterModuleAccessors(Companions, "Companions")',
    "Companions registers accessors during setup")
assert_contains(companionsModule, 'BETTERUI.CIM.RegisterModulePanelWithLogging(Companions, "Companions", "Companions", "Companions")',
    "Companions setup uses the shared panel registration helper")
assert_contains(companionsModule, 'return BETTERUI.Companions.Init()',
    "Companions setup propagates runtime initialization failures to bootstrap")

assert_contains(bankingModule, 'BETTERUI.CIM.TryRegisterModulePanel(Banking, "Banking", "Bank", "Banking")',
    "Banking setup uses the shared panel registration helper")
assert_contains(bankingModule, 'BETTERUI.CIM.ApplyModuleSharedSettingsStatics(Banking, "Banking")',
    "Banking keeps only shared settings statics at import time")
assert_contains(bankingModule, 'local function EnsureBankingSetupContracts()',
    "Banking defines an explicit setup-time bootstrap helper")
assert_contains(bankingModule, 'BETTERUI.CIM.RegisterModuleAccessors(Banking, "Banking")',
    "Banking registers accessors during setup")
assert_contains(bankingModule, 'RegisterBankingModeLabels({',
    "Banking narration labels register during setup-time bootstrap")
assert_contains(tradingHouseModule, 'BETTERUI.CIM.RegisterModulePanelWithLogging(TradingHouse, "TradingHouse", "TradingHouse", "TradingHouse")',
    "TradingHouse setup uses the shared panel registration helper")
assert_contains(tradingHouseModule, 'BETTERUI.CIM.ApplyModuleSharedSettingsStatics(TradingHouse, "TradingHouse")',
    "TradingHouse keeps only shared settings statics at import time")
assert_contains(tradingHouseModule, 'local function EnsureTradingHouseSetupContracts()',
    "TradingHouse defines an explicit setup-time bootstrap helper")
assert_contains(tradingHouseModule, 'BETTERUI.CIM.RegisterModuleAccessors(TradingHouse, "TradingHouse")',
    "TradingHouse registers accessors during setup")
assert_contains(generalInterfaceSetup, 'GeneralInterface.Settings = GeneralInterface.Settings or {}',
    "GeneralInterface setup exposes a settings panel registration seam")
assert_contains(generalInterfaceSetup, 'GeneralInterface.Settings.RegisterPanel = Init',
    "GeneralInterface setup binds panel construction to the settings seam")
assert_contains(generalInterfaceSetup,
    'BETTERUI.CIM.RegisterModulePanelWithLogging(GeneralInterface, "GeneralInterface", "General", "General Interface")',
    "GeneralInterface setup uses the shared panel registration helper")
assert_not_contains(generalInterfaceSetup, "GetNameplateOptions",
    "GeneralInterface setup no longer owns Nameplates settings composition")

assert_contains(nameplatesModule, "Nameplates.Settings = Nameplates.Settings or {}",
    "Nameplates root exposes a dedicated settings panel seam")
assert_contains(nameplatesModule, "Nameplates.Settings.RegisterPanel = InitPanel",
    "Nameplates root binds dedicated panel construction through InitPanel")
assert_contains(nameplatesModule, "function Nameplates.InitModule(m_options)",
    "Nameplates root owns InitModule defaults/migration behavior")
assert_contains(nameplatesModule, "moveTargetBar = false,",
    "Nameplates root defaults include the target/NPC bar mover")
assert_contains(nameplatesModule, "movePlayerInteract = false,",
    "Nameplates root defaults include the player-interact mover")
assert_not_contains(nameplatesSettings, "Nameplates.Settings.RegisterPanel = InitPanel",
    "Nameplates settings helper no longer owns panel registration")
assert_not_contains(nameplatesSettings, "function Nameplates.InitModule(m_options)",
    "Nameplates settings helper no longer owns InitModule defaults")
assert_not_contains(nameplatesSettings, "local clampNameplateSize = Nameplates.ClampNameplateSize",
    "Nameplates settings must not capture runtime helpers before manifest dependents load")
assert_contains(nameplatesModule, 'BETTERUI.CIM.RegisterModulePanelWithLogging(Nameplates, "Nameplates", "Nameplates", "Nameplates")',
    "Nameplates setup uses the shared panel registration helper")
assert_contains(nameplatesModule, "ApplyNameplatePositioning(settings)",
    "Nameplates runtime applies movable HUD positioning with current settings")
assert_contains(nameplatesPositioning, "function Positioning.ApplyCurrentSettings(settings)",
    "Nameplates positioning helper exposes an apply-current-settings bridge")
assert_contains(nameplatesPositioning, "local HANDLE_SIZE = 64",
    "Nameplates mover handles stay compact enough for live HUD overlays")
assert_contains(nameplatesPositioning, "local HANDLE_MATCH_MAX_WIDTH = 560",
    "Nameplates mover boxes match element footprints but cap wide hosts instead of covering the screen")
assert_contains(nameplatesPositioning, "local HANDLE_ARROW_EDGE_INSET = 2",
    "Nameplates move arrows hug the box edges instead of clustering at the center")
assert_contains(nameplatesPositioning, "and AnchorsMatch(ReadControlAnchors(control, controlName, descriptor), applyAnchors, offsetX, offsetY) then",
    "Nameplates unlocked refresh skips unchanged anchor reapply diagnostics")
assert_contains(nameplatesPositioning, "if applied > 0 or restored > 0 then",
    "Nameplates positioning logs only actual apply/restore transitions")
assert_contains(nameplatesPositioning, 'local playerToPlayer = rawget(_G, "PLAYER_TO_PLAYER")',
    "Nameplates player-interact mover resolves ESOUI's PLAYER_TO_PLAYER prompt container")
assert_contains(nameplatesSettings, 'key = "moveTargetBar"',
    "Nameplates position settings expose the target/NPC bar mover")
assert_contains(nameplatesSettings, 'key = "movePlayerInteract"',
    "Nameplates position settings expose the player-interact mover")
assert_contains(nameplatesSettings, 'IsPositionSliderDisabled("targetBar")',
    "Nameplates target-bar position sliders use the targetBar descriptor gate")
assert_contains(nameplatesSettings, 'IsPositionSliderDisabled("playerInteract")',
    "Nameplates player-interact position sliders use the playerInteract descriptor gate")

assert_contains(resourceOrbModule, 'function ResourceOrbFrames.Setup()',
    "ResourceOrbFrames exposes an explicit setup-time hook")
assert_contains(resourceOrbModule, 'BETTERUI.CIM.RegisterModuleAccessors(ResourceOrbFrames, "ResourceOrbFrames")',
    "ResourceOrbFrames registers accessors during setup")
assert_contains(resourceOrbModule, 'ResourceOrbFrames.Settings = ResourceOrbFrames.Settings or {}',
    "ResourceOrbFrames exposes a settings panel registration seam")
assert_contains(resourceOrbModule, 'ResourceOrbFrames.Settings.RegisterPanel = InitSettingsPanel',
    "ResourceOrbFrames binds panel construction to the settings seam")
assert_contains(resourceOrbModule,
    'BETTERUI.CIM.RegisterModulePanelWithLogging(ResourceOrbFrames, "ResourceOrbFrames", "ResourceOrbFrames",',
    "ResourceOrbFrames setup uses the shared panel registration helper")
assert_contains(resourceOrbElementDrag, "local HANDLE_SIZE = 64",
    "Resource orb drag handles stay compact enough for clustered HUD elements")
assert_contains(resourceOrbElementDrag, "local HANDLE_ARROW_EDGE_INSET = 2",
    "Resource orb move icon separates directional arrows so they do not read as one cross")
assert_contains(resourceOrbElementDrag, "handle:SetCenterColor(0.15, 0.45, 1, alpha)",
    "Resource orb drag handles use the same blue backdrop treatment as nameplate movers")
assert_contains(writsModule, 'local THIN_ENTRYPOINT = ARCHETYPES.THIN_ENTRYPOINT or "thin-entrypoint"',
    "Writs resolves the thin-entrypoint archetype from shared archetype constants")
assert_contains(writsModule, "Writs.ROOT_CONTRACT = {",
    "Writs defines a documented root contract")
assert_contains(writsModule, 'name = "Writs",',
    "Writs root contract declares module ownership")
assert_contains(writsModule, "setup = true,",
    "Writs root contract keeps setup-time invocation enabled")

assert_contains(inventoryFormatting, 'local function IsModuleSceneShowing(moduleRoot)',
    "Inventory entry formatting resolves active modules through live module instances")
assert_contains(inventoryFormatting, 'if IsModuleSceneShowing(BETTERUI.Vendor) then',
    "Inventory entry formatting checks the vendor instance directly")
assert_contains(inventoryFormatting, 'if IsModuleSceneShowing(BETTERUI.Companions) then',
    "Inventory entry formatting checks the companions instance directly")
assert_contains(inventoryFormatting, 'if IsModuleSceneShowing(BETTERUI.TradingHouse) then',
    "Inventory entry formatting checks the trading-house instance directly")
assert_not_contains(inventoryFormatting, 'BETTERUI_VENDOR_SCENE_NAME',
    "Inventory entry formatting no longer depends on the vendor scene-name alias")
assert_not_contains(inventoryFormatting, 'BETTERUI_COMPANION_EQUIP_SCENE_NAME',
    "Inventory entry formatting no longer depends on the companions scene-name alias")
assert_not_contains(inventoryFormatting, 'BETTERUI_TRADING_HOUSE_SCENE_NAME',
    "Inventory entry formatting no longer depends on the trading-house scene-name alias")
assert_not_contains(inventoryFormatting, 'SCENE_MANAGER:GetScene(',
    "Inventory entry formatting no longer probes scenes by global manager alias")

print("  OK")
