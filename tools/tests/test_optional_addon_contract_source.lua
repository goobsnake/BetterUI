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

print("test_optional_addon_contract_source")

local manifest = read_file("BetterUI.txt")
local registry = read_file("Modules/CIM/Core/Integration/OptionalAddonRegistry.lua")
local metadata = read_file("Modules/CIM/Core/Settings/SettingsMetadata.lua")

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
    "OptionalAddonRegistry keeps the manifest-facing globals seam")
assert_contains(registry, "return OptionalAddons.GetGlobals(OPTIONAL_ADDON_KEYS)",
    "Manifest globals are derived from the canonical optional-addon key list")
assert_contains(registry, "function OptionalAddons.GetAddonKeys()",
    "OptionalAddonRegistry exposes canonical addon keys for contract checks")
assert_contains(registry, "OptionalAddons.KEYS.MASTER_MERCHANT = \"MasterMerchant\"",
    "OptionalAddonRegistry exposes typed addon-key constants")
assert_contains(registry, "function OptionalAddons.ResolveKey(addonKeyOrGlobal)",
    "OptionalAddonRegistry resolves public addon keys and globals through one seam")

local expectedManifest = "MasterMerchant ArkadiusTradeTools TamrielTradeCentre AutoCategory"
if manifestLine ~= expectedManifest then
    error("OptionalDependsOn must stay aligned with OptionalAddonRegistry OPTIONAL_ADDON_KEYS\nExpected: "
        .. expectedManifest .. "\nActual: " .. manifestLine)
end

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
