--[[
File: tools/tests/test_cim_support_module_source.lua
Purpose: Source-level regression checks for shared CIM support modules that
         define protection policy, constants, and common batch actions.

Usage:
  lua tools/tests/test_cim_support_module_source.lua
]]

if false then
    dofile("Modules/CIM/Actions/ActionDialogUtils.lua")
    dofile("Modules/CIM/Actions/ProtectionPolicy.lua")
    dofile("Modules/CIM/Constants.lua")
    dofile("Modules/CIM/ConstantsUI.lua")
    dofile("Modules/CIM/Core/Batching/BatchActions.lua")
end

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

local actionDialogUtils = read_file("Modules/CIM/Actions/ActionDialogUtils.lua")
assert_true(actionDialogUtils:find("function BETTERUI%.CIM%.RegisterInventoryDialogInvoker%(invokeDialog%)") ~= nil,
    "ActionDialogUtils exposes the setup-owned inventory dialog registration seam")
assert_true(actionDialogUtils:find("function BETTERUI%.CIM%.InvokeInventoryDialog%(methodName, %.%.%.%)") ~= nil,
    "ActionDialogUtils exposes the shared inventory dialog invoker")

local protectionPolicy = read_file("Modules/CIM/Actions/ProtectionPolicy.lua")
assert_true(protectionPolicy:find("BETTERUI%.CIM%.ProtectionPolicy = BETTERUI%.CIM%.ProtectionPolicy or %{%}") ~= nil,
    "ProtectionPolicy preserves shared protection-policy table identity across loads")
assert_true(protectionPolicy:find("BETTERUI%.CIM%.ProtectionPolicy = %{%}") == nil,
    "ProtectionPolicy does not rebind the shared protection-policy table")
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
assert_true(protectionPolicy:find("function Policy%.CanVendorAction%(actionType, bagId, slotIndex, context%)") ~= nil,
    "ProtectionPolicy exposes shared vendor action authorization")
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
assert_true(batchActions:find("local function GetProtectionPolicy%(%s*%)") ~= nil,
    "BatchActions resolves ProtectionPolicy through an accessor seam")
assert_true(batchActions:find("local ProtectionPolicy = BETTERUI%.CIM and BETTERUI%.CIM%.ProtectionPolicy") == nil,
    "BatchActions avoids import-time ProtectionPolicy snapshots")
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
assert_true(batchActions:find("local function CanLockItem%(bagId, slotIndex%)") ~= nil,
    "BatchActions defines a lock authorization helper")
assert_true(batchActions:find('RequireProtectionPolicyMethod%("CanLockItem"%)') ~= nil,
    "BatchActions lock checks require ProtectionPolicy.CanLockItem")
assert_true(batchActions:find("local function CanUnlockItem%(bagId, slotIndex%)") ~= nil,
    "BatchActions defines an unlock authorization helper")
assert_true(batchActions:find('RequireProtectionPolicyMethod%("CanUnlockItem"%)') ~= nil,
    "BatchActions unlock checks require ProtectionPolicy.CanUnlockItem")

local genericSlotActions = read_file("Modules/CIM/Actions/GenericSlotActions.lua")
local cimUtilities = read_file("Modules/CIM/Core/Utilities.lua")
local companionDialogs = read_file("Modules/Companions/Dialogs/CompanionDialogs.lua")
local vendorBuyComponent = read_file("Modules/Vendor/Components/BuyComponent.lua")
local tooltipSettingsHelpers = read_file("Modules/GeneralInterface/Tooltips/SettingsHelpers.lua")
assert_true(genericSlotActions:find("BETTERUI%.CIM%.InvokeInventoryDialog%(\"TryStowWithQuantity\", inventorySlot%)") ~= nil,
    "GenericSlotActions routes craft-bag quantity dialogs through the shared CIM dialog seam")
assert_true(genericSlotActions:find("local function CanStowToCraftBagWithPolicy%(bagId, slotIndex%)") ~= nil,
    "GenericSlotActions centralizes craft-bag stow authorization through a policy helper")
assert_true(genericSlotActions:find("banking and banking%.TryTransferInventorySlot") ~= nil,
    "GenericSlotActions routes bank transfers through the single Banking-owned transfer seam")
assert_true(genericSlotActions:find("local function GetBankingTransferSupport") == nil,
    "GenericSlotActions does not keep a banking-specific CIM forwarding helper")
assert_true(genericSlotActions:find("BETTERUI%.CIM%.Utils%.GetBankingTransferSupport") == nil,
    "GenericSlotActions avoids the CIM bank transfer support forwarding seam")
assert_true(genericSlotActions:find("policy and policy%.CanStowToCraftBag") ~= nil,
    "GenericSlotActions resolves ProtectionPolicy.CanStowToCraftBag through the policy seam")
assert_true(genericSlotActions:find("CIM%.ProtectionPolicy%.CanStowToCraftBag must load before craft%-bag transfer checks") ~= nil,
    "GenericSlotActions requires ProtectionPolicy.CanStowToCraftBag instead of fail-open fallbacks")
assert_true(genericSlotActions:find("local function ResolvePolicyDeny%(denyKey%)") ~= nil,
    "GenericSlotActions centralizes deny-code resolution through ProtectionPolicy.DENY")
assert_true(genericSlotActions:find('ResolvePolicyDeny%("NO_CRAFT_ACCESS"') == nil,
    "GenericSlotActions no longer runs local no-craft-access fallback logic when policy method is missing")
assert_true(genericSlotActions:find('ResolvePolicyDeny%("NO_ITEM"%)') ~= nil,
    "GenericSlotActions resolves no-item failures through the shared deny constants")
assert_true(genericSlotActions:find("local DENY = %(") == nil,
    "GenericSlotActions no longer defines a local fallback DENY table")
assert_true(genericSlotActions:find(
    "function BETTERUI%.CIM%.TryMoveToCraftBag%(inventorySlot, targetBag, quantity%)") ~= nil,
    "GenericSlotActions supports quantity-aware transfer calls through the shared craft-bag move seam")
assert_true(genericSlotActions:find("BetterUISlotActionEntryLike") ~= nil,
    "GenericSlotActions uses the shared slot-action entry alias")
assert_true(cimUtilities:find("function BETTERUI%.CIM%.Utils%.GetActiveBankTransferContext") == nil,
    "CIM Utilities no longer exposes the banking transfer context forwarding seam")
assert_true(cimUtilities:find("function BETTERUI%.CIM%.Utils%.GetBankingTransferSupport") == nil,
    "CIM Utilities no longer exposes the banking transfer support forwarding seam")
assert_true(cimUtilities:find("function BETTERUI%.CIM%.Utils%.GetBankingSortEntryContext") == nil,
    "CIM Utilities no longer exposes the banking sort-context forwarding seam")
assert_true(cimUtilities:find("function BETTERUI%.CIM%.Utils%.CreateInventorySlotActions") == nil,
    "CIM Utilities no longer exposes the inventory slot-action forwarding seam")
assert_true(cimUtilities:find("function BETTERUI%.CIM%.Utils%.ClearTrackedInventorySlot") == nil,
    "CIM Utilities no longer exposes the inventory tracker forwarding seam")
assert_true(companionDialogs:find("CIM%.Utils%.SafeGetTargetData") ~= nil,
    "Companion dialogs resolve list targets through the canonical CIM utility helper")
assert_true(companionDialogs:find("local function SafeGetTargetData%(") == nil,
    "Companion dialogs no longer define a local SafeGetTargetData clone")
assert_true(vendorBuyComponent:find("CIM%.Utils%.SafeGetTargetData") ~= nil,
    "Vendor buy component resolves focused rows through the canonical CIM utility helper")
assert_true(vendorBuyComponent:find("list:GetSelectedData%(") == nil,
    "Vendor buy component no longer keeps a local selected-data fallback chain")
assert_true(tooltipSettingsHelpers:find("BETTERUI%.Utils%.IsInventorySceneShowing") == nil,
    "Tooltip settings helpers no longer probe root utility scene aliases")
assert_true(tooltipSettingsHelpers:find("BETTERUI%.Utils%.IsBankingSceneShowing") == nil,
    "Tooltip settings helpers no longer probe root utility scene aliases for banking")

if failed > 0 then
    error(string.format("test_cim_support_module_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_cim_support_module_source.lua: %d passed", passed))
