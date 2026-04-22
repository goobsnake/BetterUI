--[[
File: tools/tests/test_banking_transfer.lua
Purpose: Tests for Banking transfer helper surface (deposit permissions,
         guild transfer decisions, and denial notifications) while keeping
         lower-level transfer helpers internal to MultiSelectActions.

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
SI_STOLEN_ITEM_CANNOT_DEPOSIT_MESSAGE = "SI_STOLEN_ITEM_CANNOT_DEPOSIT_MESSAGE"
SI_FURNITURE_VAULT_ERROR_STOLEN_FURNITURE = "SI_FURNITURE_VAULT_ERROR_STOLEN_FURNITURE"

-- Configurable stub state
local slotStacks = {}
local itemBindTypes = {}
local bagSizes = {}
local bagUsed = {}
local esoPlus = false
local alerts = {}
local userNotifications = {}
local stringValues = {
    [SI_FURNITURE_VAULT_ERROR_NEED_ESO_PLUS] = "Furniture vault requires ESO+",
    [SI_FURNITURE_VAULT_ERROR_NEED_COLLECTIBLE] = "Furniture vault requires collectible",
    [SI_GAMEPAD_GUILD_BANK_NO_PERMISSION] = "No guild permission",
    [SI_GAMEPAD_GUILD_BANK_NO_WITHDRAW_PERMISSIONS] = "No withdraw",
    [SI_GAMEPAD_GUILD_BANK_NO_DEPOSIT_PERMISSIONS] = "No deposit %s",
    [SI_STOLEN_ITEM_CANNOT_DEPOSIT_MESSAGE] = "Stolen items cannot be deposited",
    [SI_FURNITURE_VAULT_ERROR_STOLEN_FURNITURE] = "Stolen furniture cannot enter the vault",
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

UI_ALERT_CATEGORY_ERROR = 1
SOUNDS = { NEGATIVE_CLICK = "negative" }

function ZO_Alert(_, _, stringId)
    alerts[#alerts + 1] = stringId
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
        TRANSFER_MODE_MAIN_BANK = "main-bank",
        TRANSFER_MODE_HOUSE_BANK = "house-bank",
        TRANSFER_MODE_GUILD_BANK = "guild-bank",
        _ResolveBankBag = function(bankBagId)
            if bankBagId == nil or bankBagId == 0 then
                return BAG_BANK
            end
            return bankBagId
        end,
        GetCurrentBank = function()
            return BETTERUI.Banking._ResolveBankBag(BETTERUI.Banking.RuntimeState.currentUsedBank)
        end,
        GetTransferContext = function()
            local isGuildBank = BETTERUI.Banking.GuildBank
                and type(BETTERUI.Banking.GuildBank.IsGuildBankMode) == "function"
                and BETTERUI.Banking.GuildBank.IsGuildBankMode()
                or false
            local sourceBag = isGuildBank and BAG_GUILDBANK
                or BETTERUI.Banking._ResolveBankBag(
                    GetBankingBag and GetBankingBag() or BETTERUI.Banking.RuntimeState.currentUsedBank
                )
            local targetBag = sourceBag == BAG_GUILDBANK and BAG_GUILDBANK
                or BETTERUI.Banking._ResolveBankBag(BETTERUI.Banking.RuntimeState.currentUsedBank)
            local kind = BETTERUI.Banking.TRANSFER_MODE_MAIN_BANK
            if isGuildBank or sourceBag == BAG_GUILDBANK then
                kind = BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK
            elseif sourceBag ~= BAG_BANK then
                kind = BETTERUI.Banking.TRANSFER_MODE_HOUSE_BANK
            end
            return {
                kind = kind,
                interactionBag = sourceBag,
                depositTargetBag = targetBag,
                withdrawSourceBags = (kind == BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK)
                    and { BAG_GUILDBANK }
                    or (targetBag == BAG_BANK and { BAG_BANK, BAG_SUBSCRIBER_BANK } or { targetBag }),
                sourceIsFurnitureVault = sourceBag == BAG_FURNITURE_VAULT,
                targetIsFurnitureVault = targetBag == BAG_FURNITURE_VAULT,
            }
        end,
        GetTransferState = function()
            return BETTERUI.Banking.GetTransferContext()
        end,
        IsGuildBankTransfer = function()
            return BETTERUI.Banking.GetTransferContext().kind == BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK
        end,
        IsMainBankTransfer = function()
            return BETTERUI.Banking.GetTransferContext().kind == BETTERUI.Banking.TRANSFER_MODE_MAIN_BANK
        end,
        IsHouseBankTransfer = function()
            return BETTERUI.Banking.GetTransferContext().kind == BETTERUI.Banking.TRANSFER_MODE_HOUSE_BANK
        end,
        GetActiveInteractionBag = function()
            return BETTERUI.Banking.GetTransferContext().interactionBag
        end,
        GetActiveDepositBag = function()
            return BETTERUI.Banking.GetTransferContext().depositTargetBag
        end,
        GetWithdrawSourceBags = function()
            return BETTERUI.Banking.GetTransferContext().withdrawSourceBags
        end,
        GuildBank = {
            IsGuildBankMode = function() return false end,
            GetDepositTargetBag = function() return BAG_GUILDBANK end,
            GetPermissionDenial = function() return nil end,
        },
        RuntimeState = {
            currentUsedBank = BAG_BANK,
            lastUsedBank = BAG_BANK,
        },
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
        UserNotify = function(_, stringId)
            userNotifications[#userNotifications + 1] = stringId
        end,
    },
}

dofile("Modules/Banking/Core/MultiSelectActions.lua")
dofile("Modules/Banking/Actions/TransferActions.lua")

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

local function readFile(path)
    local file = assert(io.open(path, "r"))
    local content = file:read("*a")
    file:close()
    return content
end

local function resetState()
    slotStacks = {}
    itemBindTypes = {}
    bagSizes = {}
    bagUsed = {}
    esoPlus = false
    alerts = {}
    userNotifications = {}
    resolveSlotResults = {}
    BETTERUI.CIM.ProtectionPolicy.CanTransferItem = function() return true end
    BETTERUI.CIM.ProtectionPolicy.CanDepositToFurnitureVault = function() return true end
    BETTERUI.Banking.GuildBank.IsGuildBankMode = function() return false end
    BETTERUI.Banking.GuildBank.GetPermissionDenial = function() return nil end
end

-- ============================================================================
-- TESTS: Internal transfer helper contract
-- ============================================================================

print("\n=== Internal transfer helper contract ===\n")

local multiSelectActionsSource = readFile("Modules/Banking/Core/MultiSelectActions.lua")
assertTrue(multiSelectActionsSource:match("local function ResolveStackCount") ~= nil,
    "ResolveStackCount stays internal to MultiSelectActions")
assertTrue(multiSelectActionsSource:match("local function ResolveDepositTargetBag") ~= nil,
    "ResolveDepositTargetBag stays internal to MultiSelectActions")
assertNil(BETTERUI.Banking.ResolveTransferStackCount,
    "ResolveTransferStackCount is no longer exported on BETTERUI.Banking")
assertNil(BETTERUI.Banking.ResolveDepositDestinationBag,
    "ResolveDepositDestinationBag is no longer exported on BETTERUI.Banking")

-- ============================================================================
-- TESTS: IsDepositSupportedForBank
-- ============================================================================

print("\n=== IsDepositSupportedForBank ===\n")

resetState()
print("-- Normal item deposit allowed --")
slotStacks["1:5"] = 10
assertTrue(BETTERUI.Banking.Transfer.CanDepositIntoBank(1, 5, BAG_BANK), "Normal item can be deposited")

resetState()
print("\n-- ProtectionPolicy denies transfer --")
BETTERUI.CIM.ProtectionPolicy.CanTransferItem = function() return false, BETTERUI.CIM.ProtectionPolicy.DENY.STOLEN end
local allowed, reason = BETTERUI.Banking.Transfer.CanDepositIntoBank(1, 5, BAG_BANK)
assertFalse(allowed, "Denied by ProtectionPolicy")
assertEqual(BETTERUI.CIM.ProtectionPolicy.DENY.STOLEN, reason, "Returns deny reason from policy")

resetState()
print("\n-- Bind-on-pickup item blocked --")
BETTERUI.CIM.ProtectionPolicy.CanTransferItem = function() return false, "bop_backpack" end
allowed, reason = BETTERUI.Banking.Transfer.CanDepositIntoBank(1, 5, BAG_BANK)
assertFalse(allowed, "BOP item cannot be deposited")
assertEqual("bop_backpack", reason, "Returns BOP deny reason")

resetState()
print("\n-- Bind-on-equip item allowed --")
itemBindTypes["1:5"] = BIND_TYPE_ON_EQUIP
assertTrue(BETTERUI.Banking.Transfer.CanDepositIntoBank(1, 5, BAG_BANK), "BOE item can be deposited")

resetState()
print("\n-- Furniture vault denied by gemmable check --")
CROWN_GEMIFICATION_MANAGER = { IsItemGemmable = function() return true end }
allowed, reason = BETTERUI.Banking.Transfer.CanDepositIntoBank(1, 5, BAG_FURNITURE_VAULT)
assertFalse(allowed, "Furniture vault deposit denied for gemmable item")
assertEqual(BETTERUI.CIM.ProtectionPolicy.DENY.CROWN_GEMMABLE, reason,
    "Returns crown gemmable deny reason")
CROWN_GEMIFICATION_MANAGER = nil

resetState()
print("\n-- Furniture vault allowed when not gemmable --")
CROWN_GEMIFICATION_MANAGER = { IsItemGemmable = function() return false end }
assertTrue(BETTERUI.Banking.Transfer.CanDepositIntoBank(1, 5, BAG_FURNITURE_VAULT),
    "Furniture vault deposit allowed for non-gemmable item")
CROWN_GEMIFICATION_MANAGER = nil

resetState()
print("\\n-- Furniture vault denied when vault access is locked --")
HOUSING_EDITOR_STATE = {
    CanDepositIntoFurnitureVault = function()
        return false
    end,
}
allowed, reason = BETTERUI.Banking.Transfer.CanDepositIntoBank(1, 5, BAG_FURNITURE_VAULT)
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
local canTransfer, denyReason, denialText, denialStringId = BETTERUI.Banking.Transfer.ResolveGuildBankTransferDecision(
    BETTERUI.Banking.LIST_WITHDRAW, BAG_GUILDBANK, 5
)
assertFalse(canTransfer, "Structured guild denial blocks transfer")
assertEqual(BETTERUI.CIM.ProtectionPolicy.DENY.GUILD_PERMISSION, denyReason,
    "Structured guild denial returns shared guild-permission reason")
assertEqual("No withdraw", denialText, "Structured guild denial preserves localized text")
assertEqual(SI_GAMEPAD_GUILD_BANK_NO_WITHDRAW_PERMISSIONS, denialStringId,
    "Structured guild denial preserves the shared string ID")

resetState()
assertNil(BETTERUI.Banking.ResolveTransferDeniedStringId,
    "ResolveTransferDeniedStringId stays internal to MultiSelectActions")

print("\n=== Transfer denial notification contract ===\n")

assertNil(BETTERUI.Banking.ResolveTransferDeniedNotification,
    "ResolveTransferDeniedNotification stays internal to MultiSelectActions")

BETTERUI.Banking.Transfer.NotifyTransferDenied(
    "Banking.TransferTests",
    BAG_FURNITURE_VAULT,
    BETTERUI.CIM.ProtectionPolicy.DENY.FURNITURE_VAULT_LOCKED
)
assertNotNil(alerts[1], "Furniture vault denial notifies through alert mode")

resetState()
BETTERUI.Banking.Transfer.NotifyTransferDenied(
    "Banking.TransferTests",
    BAG_BANK,
    BETTERUI.CIM.ProtectionPolicy.DENY.STOLEN
)
assertNotNil(userNotifications[1], "Stolen-item denial notifies through UserNotify mode")

-- ============================================================================
-- TESTS: Intent-level transfer helpers
-- ============================================================================

print("\n=== Intent-level transfer helpers ===\n")

resetState()
BETTERUI.Banking.RuntimeState.currentUsedBank = 0
assertEqual(BAG_BANK, BETTERUI.Banking.GetActiveDepositBag(),
    "GetActiveDepositBag normalizes zero-sentinel runtime banks")

BETTERUI.Banking.RuntimeState.currentUsedBank = BAG_GUILDBANK
assertTrue(BETTERUI.Banking.IsGuildBankTransfer(),
    "IsGuildBankTransfer reflects guild-bank transfer mode")
assertEqual(BAG_GUILDBANK, BETTERUI.Banking.GetTransferState().interactionBag,
    "GetTransferState resolves the active guild-bank source")
assertEqual(BAG_GUILDBANK, BETTERUI.Banking.GetTransferState().withdrawSourceBags[1],
    "GetTransferState resolves guild-bank withdraw source bags")

-- ============================================================================
-- TESTS: API Exposure
-- ============================================================================

print("\n=== API Exposure ===\n")

assertNotNil(BETTERUI.Banking.GetTransferContext, "GetTransferContext accessor exists for the local transfer harness")
assertNotNil(BETTERUI.Banking.GetTransferState, "GetTransferState accessor exists")
assertNotNil(BETTERUI.Banking.Transfer, "Transfer service exposed")
assertNotNil(BETTERUI.Banking.Transfer.CanDepositIntoBank, "Transfer exposes deposit validation")
assertNotNil(BETTERUI.Banking.Transfer.ResolveGuildBankTransferDecision,
    "Transfer exposes guild-bank transfer decisions")
assertNotNil(BETTERUI.Banking.Transfer.NotifyTransferDenied, "Transfer exposes transfer denial notifications")
assertNotNil(BETTERUI.Banking.Transfer.NotifyGuildBankTransferDenied,
    "Transfer exposes guild-bank denial notifications")
assertNotNil(BETTERUI.Banking.TryTransferInventorySlot, "Banking exposes the single-slot inventory transfer seam")
assertNotNil(BETTERUI.Banking.IsGuildBankTransfer, "IsGuildBankTransfer exposed")
assertNotNil(BETTERUI.Banking.GetActiveDepositBag, "GetActiveDepositBag exposed")
assertNotNil(BETTERUI.Banking.GetWithdrawSourceBags, "GetWithdrawSourceBags exposed on the local transfer harness")
assertNil(BETTERUI.Banking.ResolveTransferStackCount, "ResolveTransferStackCount is internal")
assertNil(BETTERUI.Banking.ResolveDepositDestinationBag, "ResolveDepositDestinationBag is internal")
assertNil(BETTERUI.Banking.ResolveTransferDeniedNotification, "ResolveTransferDeniedNotification is internal")

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
