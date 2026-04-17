--[[
File: tools/tests/test_narration_helper.lua
Purpose: Regression coverage for narration mode registration without Banking reach-through.
Usage:
  lua tools/tests/test_narration_helper.lua
]]

local passed = 0
local failed = 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

BETTERUI = {
    CIM = {},
}

SCREEN_NARRATION_MANAGER = {
    CreateNarratableObject = function(_, text)
        return text
    end,
}

function ZO_AppendNarration(target, narration)
    if narration ~= nil then
        table.insert(target, narration)
    end
end

function GetString(value)
    return tostring(value)
end

SI_BANK_DEPOSIT = "Deposit"
SI_BANK_WITHDRAW = "Withdraw"

dofile("Modules/CIM/Core/Integration/NarrationHelper.lua")

print("[NarrationHelper banking mode registration]")

BETTERUI.CIM.Narration.RegisterBankingModeLabels({
    [10] = SI_BANK_DEPOSIT,
    [20] = SI_BANK_WITHDRAW,
})

do
    local depositNarrations = BETTERUI.CIM.Narration.NarrateBankingMode(10)
    assert_eq(depositNarrations[1], "Deposit", "registered deposit mode narrates without Banking constants")
end

do
    local withdrawNarrations = BETTERUI.CIM.Narration.NarrateBankingMode(20)
    assert_eq(withdrawNarrations[1], "Withdraw", "registered withdraw mode narrates without Banking constants")
end

do
    local unknownNarrations = BETTERUI.CIM.Narration.NarrateBankingMode(99)
    assert_eq(#unknownNarrations, 0, "unregistered modes stay silent")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
