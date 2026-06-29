--[[
File: tools/tests/test_optional_addon_contract_source.lua
Purpose: Keeps optional-addon ownership aligned between manifest declarations
         and the CIM optional-addon registry contract.
Usage:
  lua tools/tests/test_optional_addon_contract_source.lua
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

local function find_line_index(lines, expected)
    for index, line in ipairs(lines) do
        if line == expected then
            return index
        end
    end
    return nil
end

local function assert_line_order(lines, earlier, later, label)
    local earlierIndex = assert(find_line_index(lines, earlier), "Missing manifest line: " .. earlier)
    local laterIndex = assert(find_line_index(lines, later), "Missing manifest line: " .. later)
    if earlierIndex >= laterIndex then
        error(label .. "\nExpected order:\n  " .. earlier .. "\n  " .. later)
    end
end

print("test_optional_addon_contract_source")

local manifest = read_file("BetterUI.txt")
local registry = read_file("Modules/CIM/Core/Integration/OptionalAddonRegistry.lua")
local metadata = read_file("Modules/CIM/Core/Settings/SettingsMetadata.lua")
local manifestLines = {}
for line in manifest:gmatch("[^\r\n]+") do
    manifestLines[#manifestLines + 1] = line
end

local manifestLine = manifest:match("## OptionalDependsOn:%s*([^\n\r]+)")
if not manifestLine then
    error("Manifest must declare OptionalDependsOn")
end

assert_contains(registry, "local OPTIONAL_ADDON_KEYS = {",
    "OptionalAddonRegistry exposes one canonical optional-addon key list")
assert_not_contains(registry, "MANIFEST_OPTIONAL_ADDONS",
    "OptionalAddonRegistry no longer carries a second manifest-only addon list")
assert_not_contains(registry, "local MARKET_ADDON_KEYS = {",
    "OptionalAddonRegistry no longer carries a second market-only addon key list")
assert_not_contains(registry, "local GUILD_STORE_ADDON_KEYS = {",
    "OptionalAddonRegistry no longer carries a second guild-store addon key list")
assert_contains(registry, "function OptionalAddons.GetManifestGlobals()",
    "OptionalAddonRegistry keeps the backwards-compatible manifest-facing seam")
assert_contains(registry, "function OptionalAddons.GetManifestNames(addonKeys)",
    "OptionalAddonRegistry exposes manifest dependency names separately from runtime globals")
assert_contains(registry, "return OptionalAddons.GetManifestNames(OPTIONAL_ADDON_KEYS)",
    "Manifest dependency names are derived from the canonical optional-addon key list")
assert_contains(registry, "function OptionalAddons.GetAddonKeys()",
    "OptionalAddonRegistry exposes canonical addon keys for contract checks")
assert_contains(registry, "OptionalAddons.KEYS.MASTER_MERCHANT = \"MasterMerchant\"",
    "OptionalAddonRegistry exposes typed addon-key constants")
assert_contains(registry, "function OptionalAddons.ResolveKey(addonKeyOrGlobal)",
    "OptionalAddonRegistry resolves public addon keys and globals through one seam")
assert_contains(registry, "manifest = \"FCOItemSaver\"",
    "FCO ItemSaver manifest name is tracked separately")
assert_contains(registry, "global = \"FCOIS\"",
    "FCO ItemSaver runtime global is tracked separately")
assert_contains(registry, "manifest = \"DolgubonsLazyWritCreator\"",
    "Dolgubon Lazy Writ Crafter manifest name is tracked separately")
assert_contains(registry, "global = \"WritCreater\"",
    "Dolgubon Lazy Writ Crafter runtime global is tracked separately")
assert_contains(registry, "manifest = \"AlphaGear\"",
    "AlphaGear manifest name is tracked separately")
assert_contains(registry, "global = \"AG\"",
    "AlphaGear runtime global is tracked separately")

local expectedManifest = "MasterMerchant ArkadiusTradeTools TamrielTradeCentre AutoCategory FCOItemSaver DolgubonsLazyWritCreator AlphaGear"
if manifestLine ~= expectedManifest then
    error("OptionalDependsOn must stay aligned with OptionalAddonRegistry OPTIONAL_ADDON_KEYS\nExpected: "
        .. expectedManifest .. "\nActual: " .. manifestLine)
end

assert_contains(manifest, "Modules\\CIM\\Core\\Integration\\OptionalAddonRegistry.lua",
    "Manifest must load OptionalAddonRegistry before optional-addon consumers")
assert_line_order(
    manifestLines,
    "Modules\\CIM\\Core\\Integration\\OptionalAddonRegistry.lua",
    "Modules\\CIM\\Core\\Integration\\MarketIntegration.lua",
    "OptionalAddonRegistry must load before MarketIntegration"
)
assert_line_order(
    manifestLines,
    "Modules\\Inventory\\Core\\InventoryClass.lua",
    "Modules\\Inventory\\State\\PositionManager.lua",
    "InventoryClass must load before Inventory PositionManager attaches class methods"
)
assert_line_order(
    manifestLines,
    "Modules\\Inventory\\Core\\InventoryClass.lua",
    "Modules\\Inventory\\State\\ListStateManager.lua",
    "InventoryClass must load before Inventory ListStateManager attaches class methods"
)
assert_not_contains(manifest, "Modules\\Inventory\\Core\\MixinLoader.lua",
    "Manifest must not reference the removed Inventory MixinLoader shim")
assert_contains(manifest, "Modules\\Vendor\\Core\\Policy\\VendorModePolicy.lua",
    "Manifest must point VendorModePolicy at the Policy subfolder")
assert_contains(manifest, "Modules\\Vendor\\Core\\Presentation\\VendorSelectionRuntime.lua",
    "Manifest must point VendorSelectionRuntime at the Presentation subfolder")
assert_contains(manifest, "Modules\\Vendor\\Core\\Bridge\\VendorNativeStoreBridge.lua",
    "Manifest must point VendorNativeStoreBridge at the Bridge subfolder")
assert_contains(manifest, "Modules\\Vendor\\Core\\Lifecycle\\VendorEventBridge.lua",
    "Manifest must point VendorEventBridge at the Lifecycle subfolder")
assert_contains(manifest, "Modules\\Vendor\\Core\\Lifecycle\\VendorInteractionRuntime.lua",
    "Manifest must point VendorInteractionRuntime at the Lifecycle subfolder")
assert_contains(manifest, "Modules\\Vendor\\Core\\Lifecycle\\VendorControllerRuntime.lua",
    "Manifest must point VendorControllerRuntime at the Lifecycle subfolder")
assert_contains(manifest, "Modules\\Vendor\\Core\\Presentation\\VendorPresentationRuntime.lua",
    "Manifest must point VendorPresentationRuntime at the Presentation subfolder")
assert_contains(manifest, "Modules\\Vendor\\Core\\List\\VendorRowSetup.lua",
    "Manifest must point VendorRowSetup at the List subfolder")
assert_contains(manifest, "Modules\\Vendor\\Core\\List\\BatchActionCounts.lua",
    "Manifest must point BatchActionCounts at the List subfolder")
assert_not_contains(manifest, "Modules\\Vendor\\Core\\VendorModePolicy.lua",
    "Manifest must not reference the removed flat VendorModePolicy path")
assert_not_contains(manifest, "Modules\\Vendor\\Core\\VendorSelectionRuntime.lua",
    "Manifest must not reference the removed flat VendorSelectionRuntime path")
assert_not_contains(manifest, "Modules\\Vendor\\Core\\VendorNativeStoreBridge.lua",
    "Manifest must not reference the removed flat VendorNativeStoreBridge path")
assert_not_contains(manifest, "Modules\\Vendor\\Core\\VendorEventBridge.lua",
    "Manifest must not reference the removed flat VendorEventBridge path")
assert_not_contains(manifest, "Modules\\Vendor\\Core\\VendorInteractionRuntime.lua",
    "Manifest must not reference the removed flat VendorInteractionRuntime path")
assert_not_contains(manifest, "Modules\\Vendor\\Core\\VendorControllerRuntime.lua",
    "Manifest must not reference the removed flat VendorControllerRuntime path")
assert_not_contains(manifest, "Modules\\Vendor\\Core\\VendorPresentationRuntime.lua",
    "Manifest must not reference the removed flat VendorPresentationRuntime path")
assert_not_contains(manifest, "Modules\\Vendor\\Core\\VendorRowSetup.lua",
    "Manifest must not reference the removed flat VendorRowSetup path")
assert_not_contains(manifest, "Modules\\Vendor\\Core\\BatchActionCounts.lua",
    "Manifest must not reference the removed flat BatchActionCounts path")

assert_contains(metadata, "OptionalAddons.GetMarketGlobals()",
    "Settings metadata resolves market addon dependencies through OptionalAddonRegistry")
assert_contains(metadata, "OptionalAddons.GetGuildStoreGlobals()",
    "Settings metadata resolves guild-store dependencies through OptionalAddonRegistry")
assert_contains(metadata, "OptionalAddons.GetGlobals({ ADDON_KEYS.ARKADIUS_TRADE_TOOLS })",
    "Settings metadata resolves ATT dependency through OptionalAddonRegistry key constants")
assert_contains(metadata, "OptionalAddons.GetGlobals({ ADDON_KEYS.MASTER_MERCHANT })",
    "Settings metadata resolves MM dependency through OptionalAddonRegistry key constants")
assert_contains(metadata, "OptionalAddons.GetGlobals({ ADDON_KEYS.TAMRIEL_TRADE_CENTRE })",
    "Settings metadata resolves TTC dependency through OptionalAddonRegistry key constants")

print("  OK")
