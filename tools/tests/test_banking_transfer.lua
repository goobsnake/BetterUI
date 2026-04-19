--[[
File: tools/tests/test_banking_transfer.lua
Purpose: Tests for Banking transfer logic: ResolveStackCount, ResolveDepositTargetBag,
         IsDepositSupportedForBank. These local functions are exposed via
         BETTERUI.Banking.TransferHelpers (legacy fallback: _TransferHelpers) for testability.

Usage:
  lua tools/tests/test_banking_transfer.lua
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BAG_BACKPACK = 1
BAG_BANK = 2
BAG_SUBSCRIBER_BANK = 6
BAG_GUILDBANK = 3
BAG_FURNITURE_VAULT = 100
BIND_TYPE_ON_PICKUP_BACKPACK = 3
BIND_TYPE_NONE = 0
BIND_TYPE_ON_EQUIP = 1
SI_GAMEPAD_GUILD_BANK_NO_PERMISSION = "SI_GAMEPAD_GUILD_BANK_NO_PERMISSION"
SI_GAMEPAD_GUILD_BANK_NO_WITHDRAW_PERMISSIONS = "SI_GAMEPAD_GUILD_BANK_NO_WITHDRAW_PERMISSIONS"
SI_GAMEPAD_GUILD_BANK_NO_DEPOSIT_PERMISSIONS = "SI_GAMEPAD_GUILD_BANK_NO_DEPOSIT_PERMISSIONS"
SI_FURNITURE_VAULT_ERROR_NEED_ESO_PLUS = "SI_FURNITURE_VAULT_ERROR_NEED_ESO_PLUS"
SI_FURNITURE_VAULT_ERROR_NEED_COLLECTIBLE = "SI_FURNITURE_VAULT_ERROR_NEED_COLLECTIBLE"

-- Configurable stub state
local slotStacks = {}
local itemBindTypes = {}
local bagSizes = {}
local bagUsed = {}
local esoPlus = false
local stringValues = {
    [SI_FURNITURE_VAULT_ERROR_NEED_ESO_PLUS] = "Furniture vault requires ESO+",
    [SI_FURNITURE_VAULT_ERROR_NEED_COLLECTIBLE] = "Furniture vault requires collectible",
    [SI_GAMEPAD_GUILD_BANK_NO_PERMISSION] = "No guild permission",
    [SI_GAMEPAD_GUILD_BANK_NO_WITHDRAW_PERMISSIONS] = "No withdraw",
    [SI_GAMEPAD_GUILD_BANK_NO_DEPOSIT_PERMISSIONS] = "No deposit %s",
}

function GetSlotStackSize(bagId, slotIndex)
    return slotStacks[bagId .. ":" .. slotIndex] or 0
end

function GetItemBindType(bagId, slotIndex)
    return itemBindTypes[bagId .. ":" .. slotIndex] or BIND_TYPE_NONE
end

function GetBagUseableSize(bagId)
    return bagSizes[bagId] or 100
end

function GetNumBagUsedSlots(bagId)
    return bagUsed[bagId] or 0
end

function IsESOPlusSubscriber()
    return esoPlus
end

function GetString(id)
    return stringValues[id] or tostring(id)
end

function zo_clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

-- ============================================================================
-- BETTERUI STUBS
-- ============================================================================

-- Track what ResolveMoveDestinationSlot returns per bag
local resolveSlotResults = {}

BETTERUI = {
    Banking = {
        LIST_WITHDRAW = 1,
        LIST_DEPOSIT = 2,
        ResolveBankBag = function(bankBagId)
            if bankBagId == nil or bankBagId == 0 then
                return BAG_BANK
            end
            return bankBagId
        end,
        GetCurrentBank = function()
            return BETTERUI.Banking.ResolveBankBag(BETTERUI.Banking.currentUsedBank)
        end,
        GuildBank = {
            IsGuildBankMode = function() return false end,
            GetDepositTargetBag = function() return BAG_GUILDBANK end,
            GetPermissionDenial = function() return nil end,
            GetPermissionDenialReason = function() return nil end,
        },
        currentUsedBank = BAG_BANK,
        Class = {},
    },
    CIM = {
        BatchConfig = {
            BatchStepHandled = function() return "handled" end,
            BatchStepQueued = function() return "queued" end,
            BatchStepSkipped = function() return "skipped" end,
            BatchStepStopped = function(reason) return "stopped", reason end,
            ComposeBatchOptions = function(...)
                return { ... }
            end,
            WithServer = function(options)
                return options
            end,
            WithAck = function(options)
                return options
            end,
            WithPacing = function(options)
                return options
            end,
        },
        ProtectionPolicy = {
            DENY = {
                STOLEN = "stolen",
                CROWN_GEMMABLE = "crown_gemmable",
                FURNITURE_VAULT_LOCKED = "furniture_vault_locked",
                GUILD_PERMISSION = "guild_permission",
            },
            CanTransferItem = function() return true end,
            CanDepositToFurnitureVault = function() return true end,
        },
        Utils = {
            ResolveMoveDestinationSlot = function(bagId, slotIndex, targetBag)
                local key = targetBag
                if resolveSlotResults[key] ~= nil then
                    return resolveSlotResults[key]
                end
                -- Default: has space
                return true
            end,
        },
        MultiSelectMixin = {},
        BatchActions = {
            ExtractSlot = function(itemData)
                return itemData.bagId, itemData.slotIndex
            end,
            HasItemAtSlot = function(bagId, slotIndex)
                return (slotStacks[bagId .. ":" .. slotIndex] or 0) > 0
            end,
        },
    },
}

dofile("Modules/Banking/Core/MultiSelectActions.lua")

-- ============================================================================
-- TEST FRAMEWORK
-- ============================================================================

local testsPassed = 0
local testsFailed = 0

local function assertEqual(expected, actual, message)
    if expected == actual then
        testsPassed = testsPassed + 1
        print("  [OK] " .. message)
    else
        testsFailed = testsFailed + 1
        print("  [FAILED] " .. message)
        print("    Expected: " .. tostring(expected))
        print("    Actual:   " .. tostring(actual))
    end
end

local function assertTrue(value, message)
    assertEqual(true, value, message)
end

local function assertFalse(value, message)
    assertEqual(false, value, message)
end

local function assertNil(value, message)
    if value == nil then
        testsPassed = testsPassed + 1
        print("  [OK] " .. message)
    else
        testsFailed = testsFailed + 1
        print("  [FAILED] " .. message)
        print("    Expected: nil")
        print("    Actual:   " .. tostring(value))
    end
end

local function assertNotNil(value, message)
    if value ~= nil then
        testsPassed = testsPassed + 1
        print("  [OK] " .. message)
    else
        testsFailed = testsFailed + 1
        print("  [FAILED] " .. message)
    end
end

local function resetState()
    slotStacks = {}
    itemBindTypes = {}
    bagSizes = {}
    bagUsed = {}
    esoPlus = false
    resolveSlotResults = {}
    BETTERUI.CIM.ProtectionPolicy.CanTransferItem = function() return true end
    BETTERUI.CIM.ProtectionPolicy.CanDepositToFurnitureVault = function() return true end
    BETTERUI.Banking.GuildBank.IsGuildBankMode = function() return false end
    BETTERUI.Banking.GuildBank.GetPermissionDenial = function() return nil end
    BETTERUI.Banking.GuildBank.GetPermissionDenialReason = function() return nil end
end

-- Grab exposed helpers (prefer explicit public seam, fallback to legacy aliases)
local Helpers = (BETTERUI.Banking.GetTransferSupport and BETTERUI.Banking.GetTransferSupport())
    or BETTERUI.Banking.TransferHelpers
    or BETTERUI.Banking._TransferHelpers

-- ============================================================================
-- TESTS: ResolveStackCount
-- ============================================================================

print("\n=== ResolveStackCount ===\n")

resetState()
print("-- Normal stack resolution --")
slotStacks["1:5"] = 10
local itemData = { stackCount = 5 }
local result = Helpers.ResolveStackCount(itemData, 1, 5)
assertEqual(5, result, "Returns requested stack when within live range")

resetState()
print("\n-- Stack clamped to live amount --")
slotStacks["1:5"] = 3
itemData = { stackCount = 10 }
result = Helpers.ResolveStackCount(itemData, 1, 5)
assertEqual(3, result, "Clamps to live stack when request exceeds it")

resetState()
print("\n-- Item vanished (race condition) --")
slotStacks = {} -- no item at slot
itemData = { stackCount = 5 }
result = Helpers.ResolveStackCount(itemData, 1, 5)
assertNil(result, "Returns nil when item no longer exists")

resetState()
print("\n-- Zero live stack --")
slotStacks["1:5"] = 0
itemData = { stackCount = 5 }
result = Helpers.ResolveStackCount(itemData, 1, 5)
assertNil(result, "Returns nil when live stack is zero")

resetState()
print("\n-- dataSource takes precedence --")
slotStacks["1:5"] = 20
itemData = { stackCount = 3, dataSource = { stackCount = 15 } }
result = Helpers.ResolveStackCount(itemData, 1, 5)
assertEqual(15, result, "Uses dataSource.stackCount when present")

resetState()
print("\n-- Missing stackCount defaults to 1 --")
slotStacks["1:5"] = 10
itemData = {}
result = Helpers.ResolveStackCount(itemData, 1, 5)
assertEqual(1, result, "Defaults to 1 when no stackCount in itemData")

resetState()
print("\n-- Single item stack --")
slotStacks["1:5"] = 1
itemData = { stackCount = 1 }
result = Helpers.ResolveStackCount(itemData, 1, 5)
assertEqual(1, result, "Handles single item stack correctly")

-- ============================================================================
-- TESTS: IsDepositSupportedForBank
-- ============================================================================

print("\n=== IsDepositSupportedForBank ===\n")

resetState()
print("-- Normal item deposit allowed --")
slotStacks["1:5"] = 10
assertTrue(Helpers.IsDepositSupportedForBank(1, 5, BAG_BANK), "Normal item can be deposited")

resetState()
print("\n-- ProtectionPolicy denies transfer --")
BETTERUI.CIM.ProtectionPolicy.CanTransferItem = function() return false, BETTERUI.CIM.ProtectionPolicy.DENY.STOLEN end
local allowed, reason = Helpers.IsDepositSupportedForBank(1, 5, BAG_BANK)
assertFalse(allowed, "Denied by ProtectionPolicy")
assertEqual(BETTERUI.CIM.ProtectionPolicy.DENY.STOLEN, reason, "Returns deny reason from policy")

resetState()
print("\n-- Bind-on-pickup item blocked --")
BETTERUI.CIM.ProtectionPolicy.CanTransferItem = function() return false, "bop_backpack" end
allowed, reason = Helpers.IsDepositSupportedForBank(1, 5, BAG_BANK)
assertFalse(allowed, "BOP item cannot be deposited")
assertEqual("bop_backpack", reason, "Returns BOP deny reason")

resetState()
print("\n-- Bind-on-equip item allowed --")
itemBindTypes["1:5"] = BIND_TYPE_ON_EQUIP
assertTrue(Helpers.IsDepositSupportedForBank(1, 5, BAG_BANK), "BOE item can be deposited")

resetState()
print("\n-- Furniture vault denied by gemmable check --")
CROWN_GEMIFICATION_MANAGER = { IsItemGemmable = function() return true end }
allowed, reason = Helpers.IsDepositSupportedForBank(1, 5, BAG_FURNITURE_VAULT)
assertFalse(allowed, "Furniture vault deposit denied for gemmable item")
assertEqual(BETTERUI.CIM.ProtectionPolicy.DENY.CROWN_GEMMABLE, reason,
    "Returns crown gemmable deny reason")
CROWN_GEMIFICATION_MANAGER = nil

resetState()
print("\n-- Furniture vault allowed when not gemmable --")
CROWN_GEMIFICATION_MANAGER = { IsItemGemmable = function() return false end }
assertTrue(Helpers.IsDepositSupportedForBank(1, 5, BAG_FURNITURE_VAULT),
    "Furniture vault deposit allowed for non-gemmable item")
CROWN_GEMIFICATION_MANAGER = nil

resetState()
print("\\n-- Furniture vault denied when vault access is locked --")
HOUSING_EDITOR_STATE = {
    CanDepositIntoFurnitureVault = function()
        return false
    end,
}
allowed, reason = Helpers.IsDepositSupportedForBank(1, 5, BAG_FURNITURE_VAULT)
assertFalse(allowed, "Furniture vault deposit denied when vault is locked")
assertEqual(BETTERUI.CIM.ProtectionPolicy.DENY.FURNITURE_VAULT_LOCKED, reason,
    "Returns shared furniture-vault-locked deny reason")
HOUSING_EDITOR_STATE = nil

-- ============================================================================
-- TESTS: Guild-bank denial reason flow
-- ============================================================================

print("\\n=== Guild-bank denial reason flow ===\\n")

resetState()
BETTERUI.Banking.GuildBank.IsGuildBankMode = function() return true end
BETTERUI.Banking.GuildBank.GetPermissionDenial = function()
    return {
        reason = BETTERUI.CIM.ProtectionPolicy.DENY.GUILD_PERMISSION,
        stringId = SI_GAMEPAD_GUILD_BANK_NO_WITHDRAW_PERMISSIONS,
        text = "No withdraw",
    }
end
local canTransfer, denyReason, denialText, denialStringId = Helpers.ResolveGuildBankTransferDecision(
    BETTERUI.Banking.LIST_WITHDRAW, BAG_GUILDBANK, 5
)
assertFalse(canTransfer, "Structured guild denial blocks transfer")
assertEqual(BETTERUI.CIM.ProtectionPolicy.DENY.GUILD_PERMISSION, denyReason,
    "Structured guild denial returns shared guild-permission reason")
assertEqual("No withdraw", denialText, "Structured guild denial preserves localized text")
assertEqual(SI_GAMEPAD_GUILD_BANK_NO_WITHDRAW_PERMISSIONS, denialStringId,
    "Structured guild denial preserves the shared string ID")

resetState()
assertNil(Helpers.ResolveTransferDeniedStringId(BAG_GUILDBANK, "unknown_reason"),
    "Unknown guild-bank deny reasons do not collapse into a generic permission string")

print("\n=== Transfer denial notification contract ===\n")

assertNotNil(Helpers.ResolveTransferDeniedNotification, "ResolveTransferDeniedNotification exported")
assertNotNil(Helpers.TRANSFER_DENIAL_ALERT, "Transfer denial alert mode constant exposed")
assertNotNil(Helpers.TRANSFER_DENIAL_TOAST, "Transfer denial toast mode constant exposed")
assertEqual(1, Helpers.TRANSFER_DENIAL_ALERT, "Transfer denial alert mode is explicit")
assertEqual(2, Helpers.TRANSFER_DENIAL_TOAST, "Transfer denial toast mode is explicit")

local vaultDeniedNotification = Helpers.ResolveTransferDeniedNotification(
    BAG_FURNITURE_VAULT,
    BETTERUI.CIM.ProtectionPolicy.DENY.FURNITURE_VAULT_LOCKED
)
assertNotNil(vaultDeniedNotification, "Furniture vault denial resolves to structured notification")
assertEqual(Helpers.TRANSFER_DENIAL_ALERT, vaultDeniedNotification.mode,
    "Furniture vault denial uses alert mode")
assertNotNil(vaultDeniedNotification.stringId, "Furniture vault denial resolves string ID")

-- ============================================================================
-- TESTS: ResolveDepositTargetBag
-- ============================================================================

print("\n=== ResolveDepositTargetBag ===\n")

resetState()
print("-- Deposit to primary bank with space --")
resolveSlotResults[BAG_BANK] = true
result = Helpers.ResolveDepositTargetBag(1, 5, BAG_BANK)
assertEqual(BAG_BANK, result, "Routes to primary bank when space available")

resetState()
print("\n-- Primary full, ESO+ fallback to subscriber bank --")
esoPlus = true
resolveSlotResults[BAG_BANK] = false
resolveSlotResults[BAG_SUBSCRIBER_BANK] = true
result = Helpers.ResolveDepositTargetBag(1, 5, BAG_BANK)
assertEqual(BAG_SUBSCRIBER_BANK, result, "Falls back to subscriber bank for ESO+ users")

resetState()
print("\n-- Primary full, no ESO+ subscriber --")
esoPlus = false
resolveSlotResults[BAG_BANK] = false
bagSizes[BAG_BANK] = 60
bagUsed[BAG_BANK] = 60
result = Helpers.ResolveDepositTargetBag(1, 5, BAG_BANK)
assertEqual("skip", result, "Returns 'skip' when bank full and not ESO+")

resetState()
print("\n-- Primary full but free slots exist (unbankable item) --")
esoPlus = false
resolveSlotResults[BAG_BANK] = false
bagSizes[BAG_BANK] = 60
bagUsed[BAG_BANK] = 50 -- 10 free slots
result = Helpers.ResolveDepositTargetBag(1, 5, BAG_BANK)
assertEqual("unbankable", result, "Returns 'unbankable' when slots free but item can't go there")

resetState()
print("\n-- ESO+ both banks full --")
esoPlus = true
resolveSlotResults[BAG_BANK] = false
resolveSlotResults[BAG_SUBSCRIBER_BANK] = false
bagSizes[BAG_BANK] = 60
bagUsed[BAG_BANK] = 60
bagSizes[BAG_SUBSCRIBER_BANK] = 60
bagUsed[BAG_SUBSCRIBER_BANK] = 60
result = Helpers.ResolveDepositTargetBag(1, 5, BAG_BANK)
assertEqual("skip", result, "Returns 'skip' when both banks are full")

resetState()
print("\n-- ESO+ primary full, subscriber has space but can't resolve --")
esoPlus = true
resolveSlotResults[BAG_BANK] = false
resolveSlotResults[BAG_SUBSCRIBER_BANK] = false
bagSizes[BAG_BANK] = 60
bagUsed[BAG_BANK] = 60
bagSizes[BAG_SUBSCRIBER_BANK] = 60
bagUsed[BAG_SUBSCRIBER_BANK] = 50 -- 10 free but resolve fails
result = Helpers.ResolveDepositTargetBag(1, 5, BAG_BANK)
assertEqual("unbankable", result, "Returns 'unbankable' when subscriber has space but can't resolve")

resetState()
print("\n-- Non-BAG_BANK target (e.g., house bank) with space --")
local HOUSE_BANK = 50
resolveSlotResults[HOUSE_BANK] = true
result = Helpers.ResolveDepositTargetBag(1, 5, HOUSE_BANK)
assertEqual(HOUSE_BANK, result, "Routes to house bank when space available")

resetState()
print("\n-- Non-BAG_BANK target full --")
resolveSlotResults[HOUSE_BANK] = false
bagSizes[HOUSE_BANK] = 30
bagUsed[HOUSE_BANK] = 30
result = Helpers.ResolveDepositTargetBag(1, 5, HOUSE_BANK)
assertEqual("skip", result, "Returns 'skip' when house bank full")

resetState()
print("\n-- Non-BAG_BANK target has free slots but can't resolve --")
resolveSlotResults[HOUSE_BANK] = false
bagSizes[HOUSE_BANK] = 30
bagUsed[HOUSE_BANK] = 20
result = Helpers.ResolveDepositTargetBag(1, 5, HOUSE_BANK)
assertEqual("unbankable", result, "Returns 'unbankable' for house bank with space but unresolvable")

resetState()
print("\n-- Guild bank mode --")
BETTERUI.Banking.GuildBank.IsGuildBankMode = function() return true end
resolveSlotResults[BAG_GUILDBANK] = true
result = Helpers.ResolveDepositTargetBag(1, 5, BAG_BANK)
assertEqual(BAG_GUILDBANK, result, "Routes to guild bank target in guild mode")

resetState()
print("\n-- Guild bank mode, can't resolve (unbankable) --")
BETTERUI.Banking.GuildBank.IsGuildBankMode = function() return true end
resolveSlotResults[BAG_GUILDBANK] = false
bagSizes[BAG_GUILDBANK] = 500
bagUsed[BAG_GUILDBANK] = 400 -- has free space
result = Helpers.ResolveDepositTargetBag(1, 5, BAG_BANK)
assertEqual("unbankable", result, "Returns 'unbankable' in guild bank mode when can't resolve")

resetState()
print("\n-- Guild bank full --")
BETTERUI.Banking.GuildBank.IsGuildBankMode = function() return true end
resolveSlotResults[BAG_GUILDBANK] = false
bagSizes[BAG_GUILDBANK] = 500
bagUsed[BAG_GUILDBANK] = 500
result = Helpers.ResolveDepositTargetBag(1, 5, BAG_BANK)
assertEqual("skip", result, "Returns 'skip' when guild bank completely full")

-- ============================================================================
-- TESTS: API Exposure
-- ============================================================================

print("\n=== API Exposure ===\n")

assertNotNil(BETTERUI.Banking.GetTransferSupport, "GetTransferSupport accessor exists")
assertNotNil(BETTERUI.Banking._TransferHelpers, "_TransferHelpers table exists")
assertNotNil(BETTERUI.Banking.TransferHelpers, "TransferHelpers seam table exists")
assertEqual(Helpers, BETTERUI.Banking.GetTransferSupport(), "GetTransferSupport returns the shared transfer support table")
assertNotNil(Helpers.ResolveStackCount, "ResolveStackCount exposed")
assertNotNil(Helpers.IsDepositSupportedForBank, "IsDepositSupportedForBank exposed")
assertNotNil(Helpers.ResolveDepositTargetBag, "ResolveDepositTargetBag exposed")
assertNotNil(Helpers.ResolveTransferDeniedNotification, "ResolveTransferDeniedNotification exposed")

-- ============================================================================
-- SUMMARY
-- ============================================================================

print("\n=== Test Summary ===")
print("Passed: " .. testsPassed)
print("Failed: " .. testsFailed)

if testsFailed > 0 then
    print("\nFAILED — see above for details")
    os.exit(1)
else
    print("\nAll tests passed!")
end
