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
local headerManager = read_file("Modules/Banking/UI/HeaderManager.lua")
local footerManager = read_file("Modules/Banking/UI/FooterManager.lua")
local guildBankAdapter = read_file("Modules/Banking/Core/GuildBankAdapter.lua")

assert_contains(
    transferActions,
    "BETTERUI.Banking.ReadTransferContextSnapshot()",
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

assert_not_contains(
    transferActions,
    "or BETTERUI.Banking.GetTransferState()",
    "TransferActions no longer falls back through duplicate transfer-context reader names"
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
    "local function GetTransferContext()",
    "KeybindManager no longer keeps a file-local transfer-context ladder"
)

assert_contains(
    keybindManager,
    "transferService and transferService.ResolveGuildBankTransferDecision",
    "KeybindManager resolves guild-bank keybind gating through Banking.Transfer"
)

assert_contains(
    keybindManager,
    "type(BETTERUI.Banking.IsTransferPending) == \"function\"",
    "KeybindManager guards optional pending-transfer helper before calling it"
)

assert_contains(
    keybindManager,
    "BETTERUI.Banking.IsTransferPending(bagId, slotIndex)",
    "KeybindManager blocks repeated transfer keybinds while any selected transfer is pending"
)

assert_not_contains(
    keybindManager,
    "if self.currentMode == LIST_DEPOSIT then\n        local bagId, slotIndex = GetEntryBagAndSlot(selectedData)",
    "KeybindManager pending-transfer gating is no longer deposit-only"
)

assert_contains(
    keybindManager,
    "BETTERUI.Banking.ReadTransferContextSnapshot()",
    "KeybindManager resolves keybind state through the canonical Banking transfer snapshot seam"
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

assert_contains(
    keybindManager,
    "WrapBankingKeybindGroup",
    "Banking keybind descriptors route through the shared input anchor"
)

assert_contains(
    keybindManager,
    "anchor.WrapGroup(group, \"Banking\")",
    "Banking input anchors carry module and live input mode context"
)

assert_contains(
    keybindManager,
    "WrapBankingKeybindGroup(self.coreKeybinds)",
    "Banking wraps the core keybind descriptor group at construction"
)

assert_contains(
    keybindManager,
    "WrapBankingKeybindGroup(self.withdrawDepositKeybinds)",
    "Banking wraps the item transfer keybind descriptor group at construction"
)

assert_contains(
    keybindManager,
    "WrapBankingKeybindGroup(self.currencySelectorKeybinds)",
    "Banking wraps the currency selector keybind descriptor group at construction"
)

assert_contains(
    keybindManager,
    "WrapBankingKeybindGroup(self.currencyKeybinds)",
    "Banking wraps the currency transfer keybind descriptor group at construction"
)

assert_contains(
    keybindManager,
    "TraceBankKeybind(\"bank.stack_all\", \"refresh_scheduled\"",
    "Stack All schedules a post-action refresh trace"
)

assert_contains(
    keybindManager,
    "TraceBankKeybind(\"bank.primary_transfer\", \"blocked\"",
    "Primary transfer keybind traces pending-transfer disabled state"
)

assert_contains(
    keybindManager,
    "local function CurrencyAmountForLog(amount)",
    "Banking keybind traces route absolute balance payloads through the privacy gate"
)

assert_contains(
    keybindManager,
    "carriedGold = CurrencyAmountForLog(GetCarriedCurrencyAmount(CURT_MONEY))",
    "Banking upgrade traces omit carriedGold when builog privacy is on"
)

assert_contains(
    keybindManager,
    "payload.postCallFromDelta = CurrencyDelta(postCall.postCallFrom, before.beforeFrom)",
    "Banking currency privacy traces emit post-call from delta"
)

assert_contains(
    keybindManager,
    "payload.settledToDelta = CurrencyDelta(settled.settledTo, before.beforeTo)",
    "Banking currency privacy traces emit settled to delta"
)

assert_contains(
    keybindManager,
    "payload.beforeFrom = before.beforeFrom",
    "Banking currency absolute balance fields stay in the non-privacy branch"
)

assert_contains(
    keybindManager,
    "local canTransfer, denialText = CanUsePrimaryTransfer(self)",
    "Primary transfer callback re-checks the enabled transfer contract before moving"
)

assert_contains(
    keybindManager,
    "callbackRecheckFailed",
    "Primary transfer callback traces stale callback re-check denials"
)

assert_contains(
    keybindManager,
    "transferPendingCleared",
    "Primary transfer keybind traces when pending-transfer disabled state clears"
)

assert_contains(
    keybindManager,
    "BETTERUI.Banking.Tasks:Schedule(\"stackAllRefresh\", 120, function()",
    "Stack All refresh is task-coalesced through the Banking task scheduler"
)

assert_contains(
    headerManager,
    "TraceBankHeader(\"bank.header\", \"entries_built\"",
    "Bank header rebuild logs the selectable category entries"
)

assert_contains(
    footerManager,
    "TraceBankFooter(\"bank.footer\", \"refreshed\"",
    "Bank footer refresh logs visible capacity and currency state"
)

assert_contains(
    guildBankAdapter,
    "TraceGuildBank(\"bank.guild_bank\", \"money_updated\"",
    "Guild bank money events emit trace state"
)

print("  OK")
