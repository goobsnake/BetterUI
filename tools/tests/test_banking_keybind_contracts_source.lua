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
    "local function GetRequiredTransferHelper(helperName)",
    "TransferActions resolves transfer helpers through a live helper getter"
)

assert_contains(
    transferActions,
    "GetTransferSupport",
    "TransferActions resolves helpers through the bounded transfer-support accessor"
)

assert_contains(
    transferActions,
    "GetRequiredTransferHelper(\"NotifyGuildBankTransferDenied\")",
    "TransferActions resolves guild-bank denial helper at call time"
)

assert_not_contains(
    transferActions,
    "local IsDepositAllowedForCurrentBank = BETTERUI.Banking._TransferHelpers.IsDepositSupportedForBank",
    "TransferActions no longer captures deposit helpers at file scope"
)

assert_not_contains(
    keybindManager,
    "BETTERUI.Banking.TransferHelpers or BETTERUI.Banking._TransferHelpers",
    "KeybindManager no longer reads Banking transfer helper tables directly"
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
