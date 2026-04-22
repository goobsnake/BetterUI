--[[
File: tools/tests/test_banking_guild_transfer_gate_source.lua
Purpose: Guards the shared guild-bank transfer gate wiring across banking entry points.

Usage:
  lua tools/tests/test_banking_guild_transfer_gate_source.lua
]]

if false then
    dofile("Modules/CIM/Actions/GenericSlotActions.lua")
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

local multiSelect = read_file("Modules/Banking/Core/MultiSelectActions.lua")
assert_true(multiSelect:find("ResolveGuildBankTransferDecision") ~= nil,
    "MultiSelectActions defines the shared guild-bank transfer decision helper")
assert_true(
    multiSelect:find("Transfer%.NotifyGuildBankTransferDenied") ~= nil
        and multiSelect:find("TransferRules = transferService") == nil,
    "MultiSelectActions exports the shared guild-bank denial notifier through Banking.Transfer without the TransferRules alias")

local transferActions = read_file("Modules/Banking/Actions/TransferActions.lua")
assert_true(transferActions:find("TryTransferInventorySlot") ~= nil,
    "TransferActions owns the single-slot Banking transfer seam")
assert_true(transferActions:find("transferService%.NotifyGuildBankTransferDenied") ~= nil,
    "TransferActions routes guild-bank moves through the shared denial helper")

local genericSlotActions = read_file("Modules/CIM/Actions/GenericSlotActions.lua")
assert_true(genericSlotActions:find("TryTransferInventorySlot") ~= nil,
    "GenericSlotActions delegates single-item bank transfers to the Banking-owned seam")

local keybindManager = read_file("Modules/Banking/Keybinds/KeybindManager.lua")
assert_true(keybindManager:find("ResolveGuildBankTransferKeybindState") ~= nil,
    "KeybindManager centralizes guild-bank transfer keybind gating")
assert_true(keybindManager:find("transferService and transferService%.ResolveGuildBankTransferDecision") ~= nil,
    "KeybindManager reuses the shared guild-bank transfer decision helper")

if failed > 0 then
    error(string.format("test_banking_guild_transfer_gate_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_banking_guild_transfer_gate_source.lua: %d passed", passed))
