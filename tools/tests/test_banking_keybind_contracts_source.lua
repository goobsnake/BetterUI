--[[
File: tools/tests/test_banking_keybind_contracts_source.lua
Purpose: Guards the Banking keybind contract/type cleanup and live helper lookup seams.

Usage:
  lua tools/tests/test_banking_keybind_contracts_source.lua
]]

local function read_file(path)
    local file = assert(io.open(path, "r"))
    local content = file:read("*a")
    file:close()
    return content
end

local function assert_contains(haystack, needle, message)
    if not haystack:find(needle, 1, true) then
        error(message .. "\nMissing: " .. needle)
    end
end

local function assert_not_contains(haystack, needle, message)
    if haystack:find(needle, 1, true) then
        error(message .. "\nUnexpected: " .. needle)
    end
end

print("test_banking_keybind_contracts_source")

local transferActions = read_file("Modules/Banking/Actions/TransferActions.lua")
local bankingClass = read_file("Modules/Banking/Core/BankingClass.lua")
local keybindManager = read_file("Modules/Banking/Keybinds/KeybindManager.lua")

assert_contains(
    transferActions,
    "local targetBankBag = BETTERUI.Banking.GetActiveDepositBag()",
    "TransferActions resolves transfer destination through intent-level Banking helpers"
)

assert_contains(
    transferActions,
    "local TransferRules = assert(BETTERUI.Banking and BETTERUI.Banking.TransferRules",
    "TransferActions resolves transfer authorization through the dedicated Banking transfer service"
)

assert_not_contains(
    transferActions,
    "RequireTransferSupport",
    "TransferActions no longer resolves transfer support through a generic Banking helper table"
)

assert_contains(
    transferActions,
    "TransferRules.NotifyGuildBankTransferDenied",
    "TransferActions binds guild-bank denial behavior through the dedicated Banking transfer service"
)

assert_contains(
    transferActions,
    "local isGuildBank = BETTERUI.Banking.IsGuildBankTransfer()",
    "TransferActions resolves guild-bank mode through intent-level Banking helpers"
)

assert_not_contains(
    transferActions,
    "local IsDepositAllowedForCurrentBank = BETTERUI.Banking._TransferHelpers.IsDepositSupportedForBank",
    "TransferActions no longer captures deposit helpers at file scope"
)

assert_not_contains(
    keybindManager,
    "GetBankingTransferHelper(",
    "KeybindManager no longer dispatches transfer helpers by string name"
)

assert_not_contains(
    keybindManager,
    "RequireTransferSupport",
    "KeybindManager no longer resolves transfer behavior through a generic Banking helper table"
)

assert_not_contains(
    keybindManager,
    "GetTransferContext().",
    "KeybindManager no longer reads transfer-context fields directly"
)

assert_contains(
    keybindManager,
    "transferRules and transferRules.ResolveGuildBankTransferDecision",
    "KeybindManager resolves guild-bank keybind gating through Banking.TransferRules"
)

assert_contains(
    bankingClass,
    "function BETTERUI.Banking.IsGuildBankTransfer()",
    "BankingClass exposes IsGuildBankTransfer as the transfer-mode helper seam"
)

assert_contains(
    bankingClass,
    "function BETTERUI.Banking.GetActiveDepositBag()",
    "BankingClass exposes GetActiveDepositBag for transfer destination checks"
)

assert_contains(
    bankingClass,
    "function BETTERUI.Banking.GetWithdrawSourceBags()",
    "BankingClass exposes GetWithdrawSourceBags for withdraw source routing"
)

assert_contains(
    bankingClass,
    "---@field withdrawDepositKeybinds BetterUIKeybindDescriptorGroup|nil",
    "Banking class exposes a typed transfer keybind group"
)

assert_contains(
    bankingClass,
    "---@field currencySelectorKeybinds BetterUIKeybindDescriptorGroup|nil",
    "Banking class exposes a typed currency selector keybind group"
)

assert_contains(
    keybindManager,
    "---@alias BetterUIBankingKeybindGroup BetterUIKeybindDescriptorGroup",
    "KeybindManager defines a named public keybind-group alias"
)

assert_contains(
    keybindManager,
    "---@param self BetterUIBankingClass\n---@param list BetterUIBankingListSource|nil",
    "KeybindManager types the public trigger descriptor receiver and list source"
)

assert_contains(
    keybindManager,
    "---@return BetterUIKeybindDescriptor leftTrigger",
    "KeybindManager types the public trigger descriptor contract"
)

assert_contains(
    keybindManager,
    "---@param self BetterUIBankingClass\n---@return nil\nfunction BETTERUI.Banking.Class:InitializeKeybind()",
    "KeybindManager types the public InitializeKeybind method"
)

assert_contains(
    keybindManager,
    "---@param self BetterUIBankingClass\n---@return nil\nfunction BETTERUI.Banking.Class:RefreshActiveKeybinds()",
    "KeybindManager types the public RefreshActiveKeybinds method"
)

print("  OK")
