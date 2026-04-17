--[[
File: tools/tests/test_cim_support_module_source.lua
Purpose: Source-level regression checks for shared CIM support modules that
         define protection policy, constants, and common batch actions.

Usage:
  lua tools/tests/test_cim_support_module_source.lua
]]

local passed = 0
local failed = 0

local function assert_true(value, label)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("Assertion failed: " .. label .. "\n")
    end
end

local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local protectionPolicy = read_file("Modules/CIM/Actions/ProtectionPolicy.lua")
assert_true(protectionPolicy:find("BETTERUI%.CIM%.ProtectionPolicy = %{%}") ~= nil,
    "ProtectionPolicy initializes the shared protection-policy table")
assert_true(protectionPolicy:find("Policy%.DENY = %{%s*") ~= nil,
    "ProtectionPolicy defines deny reason codes")
assert_true(protectionPolicy:find("function Policy%.CanDestroyItem%(bagId, slotIndex, slotType%)") ~= nil,
    "ProtectionPolicy exposes CanDestroyItem")
assert_true(protectionPolicy:find("function Policy%.CanTransferItem%(bagId, slotIndex, targetBag%)") ~= nil,
    "ProtectionPolicy exposes CanTransferItem")
assert_true(protectionPolicy:find("function Policy%.CanDepositToFurnitureVault%(bagId, slotIndex%)") ~= nil,
    "ProtectionPolicy exposes CanDepositToFurnitureVault")
assert_true(protectionPolicy:find("function Policy%.CanStowToCraftBag%(bagId, slotIndex%)") ~= nil,
    "ProtectionPolicy exposes CanStowToCraftBag")
assert_true(protectionPolicy:find("function Policy%.IsProtected%(bagId, slotIndex%)") ~= nil,
    "ProtectionPolicy exposes IsProtected")

local constantsLua = read_file("Modules/CIM/Constants.lua")
assert_true(constantsLua:find("BETTERUI%.CIM%.CONST%.TIMING = %{%s*") ~= nil,
    "Constants defines shared timing configuration")
assert_true(constantsLua:find("BETTERUI%.CIM%.CONST%.UI = %{%s*") ~= nil,
    "Constants defines shared UI configuration")
assert_true(constantsLua:find("BETTERUI%.CIM%.CONST%.MODULES = %{%s*") ~= nil,
    "Constants defines shared module identifiers")
assert_true(constantsLua:find("BETTERUI%.CIM%.CONST%.SEARCH_BAR = %{%s*") ~= nil,
    "Constants defines shared search-bar positioning")

local constantsUi = read_file("Modules/CIM/ConstantsUI.lua")
assert_true(constantsUi:find("BETTERUI%.CIM%.CONST%.LAYOUT = %{%}") ~= nil,
    "ConstantsUI initializes the shared layout table")
assert_true(constantsUi:find("BETTERUI%.CIM%.CONST%.LAYOUT%.PANEL = %{%s*") ~= nil,
    "ConstantsUI defines panel layout constants")
assert_true(constantsUi:find("BETTERUI%.CIM%.CONST%.LAYOUT%.COLUMNS = %{%s*") ~= nil,
    "ConstantsUI defines column layout constants")
assert_true(constantsUi:find("BETTERUI%.CIM%.CONST%.COLORS = %{%s*") ~= nil,
    "ConstantsUI defines shared CIM colors")
assert_true(constantsUi:find("BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH = BETTERUI%.CIM%.CONST%.LAYOUT%.PANEL%.WIDTH") ~= nil,
    "ConstantsUI keeps the backward-compatible panel-width alias")
assert_true(constantsUi:find("BETTERUI_SUBMENU_LABEL_OFFSET_X = BETTERUI%.CIM%.CONST%.LAYOUT%.COLUMNS%.SUBMENU%.OFFSET_X") ~= nil,
    "ConstantsUI keeps the backward-compatible column alias")

local batchActions = read_file("Modules/CIM/Core/Batching/BatchActions.lua")
assert_true(batchActions:find("BETTERUI%.CIM%.BatchActions = BETTERUI%.CIM%.BatchActions or %{%}") ~= nil,
    "BatchActions initializes the shared batch-action module")
assert_true(batchActions:find("local function ExtractSlot%(itemData%)") ~= nil,
    "BatchActions defines the shared ExtractSlot helper")
assert_true(batchActions:find("function BatchActions%.BatchLock%(self%)") ~= nil,
    "BatchActions exposes BatchLock")
assert_true(batchActions:find("function BatchActions%.BatchUnlock%(self%)") ~= nil,
    "BatchActions exposes BatchUnlock")
assert_true(batchActions:find("function BatchActions%.BatchMarkAsJunk%(self%)") ~= nil,
    "BatchActions exposes BatchMarkAsJunk")
assert_true(batchActions:find("function BatchActions%.BatchUnmarkAsJunk%(self%)") ~= nil,
    "BatchActions exposes BatchUnmarkAsJunk")
assert_true(batchActions:find("function BatchActions%.AnalyzeSelectedItems%(selectedItems%)") ~= nil,
    "BatchActions exposes AnalyzeSelectedItems")

if failed > 0 then
    error(string.format("test_cim_support_module_source.lua failed with %d failure%(s%)", failed))
end

print(string.format("test_cim_support_module_source.lua: %d passed", passed))
