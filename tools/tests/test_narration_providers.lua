--[[
File: tools/tests/test_narration_providers.lua
Purpose: PLT-006 — broadened gamepad narration coverage. Verifies the new
         NarrateActionKeybinds builder and the optional `providers` argument to
         RegisterListNarration (category / footer-currency / mode / keybind),
         including that a throwing provider is pcall-isolated from the rest.
Usage:
  lua tools/tests/test_narration_providers.lua
]]

-- ESO stubs
BETTERUI = { CIM = {} }
BETTERUI.CIM.SafeExecute = function(_tag, fn) return fn() end

local captured
SCREEN_NARRATION_MANAGER = {
    CreateNarratableObject = function(_, text) return { text = text } end,
    RegisterCustomObject = function(_, _name, info) captured = info end,
}
SCENE_MANAGER = { GetCurrentSceneName = function() return "scn" end }

function GetString(id) return tostring(id) end
function zo_strformat(fmt) return fmt end
function ZO_AppendNarration(t, n) if n ~= nil then t[#t + 1] = n end end
function GetCurrencyName() return "gold" end

dofile("Modules/CIM/Core/Integration/NarrationHelper.lua")
local Narration = BETTERUI.CIM.Narration

local passed, failed = 0, 0
local function check(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

-- NarrateActionKeybinds: keeps only non-empty string labels.
check(type(Narration.NarrateActionKeybinds), "function", "NarrateActionKeybinds is exported")
check(#Narration.NarrateActionKeybinds({ "Equip", "", "Preview", 123 }), 2, "keybind builder keeps only valid string labels")
check(#Narration.NarrateActionKeybinds(nil), 0, "nil keybinds -> empty")
check(#Narration.NarrateActionKeybinds("nope"), 0, "non-table keybinds -> empty")

-- providers append: category + currency + mode + keybinds all contribute.
Narration.RegisterBankingModeLabels({ [1] = 777 })
Narration.RegisterListNarration("scn", function() return nil end, nil, {
    getCategory = function() return "Weapons", 5 end,
    getCurrency = function() return 1, 100 end,
    getMode = function() return 1 end,
    getKeybinds = function() return { "Equip", "Preview" } end,
})
check(type(captured), "table", "RegisterListNarration registered a custom object")
local out = captured.selectedNarrationFunction()
check(#out >= 4, true, "category/currency/mode/keybind providers all contribute (>=4 entries)")

-- No providers + no selected item -> empty, proving providers are the added source.
captured = nil
Narration.RegisterListNarration("scn", function() return nil end, nil, nil)
check(#captured.selectedNarrationFunction(), 0, "no providers + no item -> empty narration")

-- A throwing provider is pcall-isolated; the others still narrate.
captured = nil
Narration.RegisterListNarration("scn", function() return nil end, nil, {
    getCategory = function() error("boom") end,
    getKeybinds = function() return { "Equip" } end,
})
local out2 = captured.selectedNarrationFunction()
check(#out2, 1, "a throwing provider is isolated; other providers still narrate")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
