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
local inventoryFormatting = read_file("Modules/Inventory/Lists/InventoryEntryFormatting.lua")

assert_contains(accessorSource, "function BETTERUI.CIM.ApplyModuleSharedSettingsStatics(",
    "CIM exposes the pure import-time shared settings helper")
assert_contains(accessorSource, "function BETTERUI.CIM.TryRegisterModulePanel(",
    "CIM exposes the shared non-fatal module panel helper")
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
assert_contains(inventoryModule, 'BETTERUI.CIM.TryRegisterModulePanel(Inventory, "Inventory", "Inventory", "Inventory")',
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
assert_contains(companionsModule, 'BETTERUI.CIM.TryRegisterModulePanel(Companions, "Companions", "Companions", "Companions")',
    "Companions setup uses the shared panel registration helper")

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
assert_contains(tradingHouseModule, 'BETTERUI.CIM.TryRegisterModulePanel(TradingHouse, "TradingHouse", "TradingHouse", "TradingHouse")',
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
    'BETTERUI.CIM.TryRegisterModulePanel(GeneralInterface, "GeneralInterface", "General", "General Interface")',
    "GeneralInterface setup uses the shared panel registration helper")
assert_contains(resourceOrbModule, 'function ResourceOrbFrames.Setup()',
    "ResourceOrbFrames exposes an explicit setup-time hook")
assert_contains(resourceOrbModule, 'BETTERUI.CIM.RegisterModuleAccessors(ResourceOrbFrames, "ResourceOrbFrames")',
    "ResourceOrbFrames registers accessors during setup")
assert_contains(resourceOrbModule, 'ResourceOrbFrames.Settings = ResourceOrbFrames.Settings or {}',
    "ResourceOrbFrames exposes a settings panel registration seam")
assert_contains(resourceOrbModule, 'ResourceOrbFrames.Settings.RegisterPanel = InitSettingsPanel',
    "ResourceOrbFrames binds panel construction to the settings seam")
assert_contains(resourceOrbModule,
    'BETTERUI.CIM.TryRegisterModulePanel(ResourceOrbFrames, "ResourceOrbFrames", "ResourceOrbFrames",',
    "ResourceOrbFrames setup uses the shared panel registration helper")
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
