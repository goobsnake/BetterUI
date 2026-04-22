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
    "local transferContext = BETTERUI.Banking.ReadTransferContextSnapshot",
    "TransferActions resolves transfer destination through the canonical transfer-context reader"
)

assert_not_contains(
    transferActions,
    "BETTERUI.Banking.Transfer = transferService",
    "TransferActions no longer fabricates or rewrites the Banking transfer service namespace"
)

assert_contains(
    transferActions,
    "local transferService, transferServiceReason = RequireTransferService()",
    "TransferActions requires the dedicated Banking transfer service instead of fabricating a fallback table"
)

assert_contains(
    transferActions,
    "local getTransferService = BETTERUI.Banking and BETTERUI.Banking.GetTransferService or nil",
    "TransferActions resolves transfer authorization through the dedicated Banking transfer service entrypoint"
)

assert_not_contains(
    transferActions,
    "RequireTransferSupport",
    "TransferActions no longer resolves transfer support through a generic Banking helper table"
)

assert_contains(
    transferActions,
    "transferService.NotifyGuildBankTransferDenied",
    "TransferActions binds guild-bank denial behavior through the dedicated Banking transfer service"
)

assert_contains(
    transferActions,
    "local isGuildBankMode = transferContext.kind == BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK",
    "TransferActions resolves guild-bank mode through the canonical transfer-context snapshot"
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
    "transferService and transferService.ResolveGuildBankTransferDecision",
    "KeybindManager resolves guild-bank keybind gating through Banking.Transfer"
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

assert_not_contains(
    bankingClass,
    "function BETTERUI.Banking.GetWithdrawSourceBags()",
    "BankingClass no longer exposes raw withdraw-source wrapper helpers"
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
    "---@param self BETTERUI.Banking.Class\n---@param list BetterUIBankingListSource|nil",
    "KeybindManager types the public trigger descriptor receiver and list source"
)

assert_contains(
    keybindManager,
    "---@return BetterUIKeybindDescriptor leftTrigger",
    "KeybindManager types the public trigger descriptor contract"
)

assert_contains(
    keybindManager,
    "---@param self BETTERUI.Banking.Class\n---@return nil\nfunction BETTERUI.Banking.Class:InitializeKeybind()",
    "KeybindManager types the public InitializeKeybind method"
)

assert_contains(
    keybindManager,
    "---@param self BETTERUI.Banking.Class\n---@return nil\nfunction BETTERUI.Banking.Class:RefreshActiveKeybinds()",
    "KeybindManager types the public RefreshActiveKeybinds method"
)

print("  OK")
