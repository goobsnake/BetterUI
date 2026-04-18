--[[
File: tools/tests/test_bootstrap_typed_contracts_source.lua
Purpose: Guards the typed bootstrap contract pass so live module names, shared
         settings accessors, and inventory entry payloads use named types.
Usage:
  lua tools/tests/test_bootstrap_typed_contracts_source.lua
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

print("test_bootstrap_typed_contracts_source")

local types = read_file("Modules/CIM/Core/Data/Types.lua")
local settingsAccessor = read_file("Modules/CIM/Core/Settings/SettingsAccessor.lua")
local inventoryList = read_file("Modules/Inventory/Lists/InventoryList.lua")
local inventoryFormatting = read_file("Modules/Inventory/Lists/InventoryEntryFormatting.lua")

assert_contains(types, '---| "TradingHouse"',
    "ModuleName aliases include TradingHouse")
assert_contains(types, '---| "Companions"',
    "ModuleName aliases include Companions")
assert_contains(types, '---@class BetterUIInventorySettings: BetterUISharedFontSettings',
    "typed inventory settings contract exists")
assert_contains(types, '---@class BetterUIInventoryRowData: SlotData',
    "typed inventory row payload exists")
assert_contains(types, '---@class BetterUIInventoryEntryData',
    "typed inventory entry payload exists")
assert_contains(types, '---@alias BetterUIControlModifyTextType',
    "inventory modify-text uses a named control contract")
assert_contains(types, '---@field modifyTextType BetterUIControlModifyTextType|nil',
    "inventory payloads stop using raw any for modifyTextType")
assert_contains(types, '---@alias BetterUIListModuleSettings',
    "shared list-module settings union exists")

assert_contains(settingsAccessor, '---@overload fun(moduleName: "Inventory", defaults: BetterUIInventorySettings|nil): BetterUIInventorySettings',
    "GetModuleSettings exposes typed inventory overloads")
assert_contains(settingsAccessor, '---@overload fun(moduleName: "GeneralInterface", defaults: BetterUIGeneralInterfaceSettings|nil): BetterUIGeneralInterfaceSettings',
    "GetModuleSettings exposes typed GeneralInterface overloads")
assert_contains(settingsAccessor, '---@param moduleName ModuleName|string Module name key',
    "shared settings helpers use ModuleName-aware annotations")

assert_contains(inventoryList, '---@param left BetterUIInventoryRowData Left item data',
    "inventory list comparator uses the named row contract")
assert_contains(inventoryList, '---@param data BetterUIInventoryEntryData Entry data with bagId, slotIndex, cached_itemLink, etc.',
    "inventory entry setup uses the named entry contract")
assert_contains(inventoryList, '---@param slotsTable BetterUIInventoryRowData[] Array to insert slot data into',
    "inventory list population uses the typed row-array contract")

assert_contains(inventoryFormatting, '--- @param data BetterUIInventoryEntryLike|nil',
    "inventory formatter resolves module names from a named entry contract")
assert_contains(inventoryFormatting, '--- @param moduleSettings BetterUIListModuleSettings|nil Module settings table',
    "inventory formatter uses the typed list-module settings contract")
assert_contains(inventoryFormatting, '--- @param data BetterUIInventoryEntryData ZO_GamepadEntryData with dataSource',
    "inventory formatter entry annotations use the named entry contract")

print("  OK")
