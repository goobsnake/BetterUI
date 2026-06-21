--[[
File: tools/tests/test_names.lua
Purpose: Unit tests for the Names.lua identifier resolvers.
Usage:   lua tools/tests/test_names.lua
]]

BETTERUI = { CIM = {} }

-- ESO stubs used by Names.Item.
function GetItemName(bag, slot)
    if bag == 1 and slot == 5 then return "Rubedite Ingot" end
    return ""
end
function zo_strformat(_, s) return s end

dofile("Modules/CIM/Core/Diagnostics/Names.lua")
local Names = BETTERUI.CIM.Names

local passed, failed = 0, 0
local function check(cond, msg)
    if cond then passed = passed + 1; print("  [OK] " .. msg)
    else failed = failed + 1; print("  [X] " .. msg) end
end

print("\n=== Names Tests ===\n")

-- Control
check(Names.Control("Foo") == "Foo", "Control: string passthrough")
local named = { GetName = function() return "BUI_BankList" end }
check(Names.Control(named) == "BUI_BankList", "Control: resolves :GetName()")
check(Names.Control({}, "fb") == "fb", "Control: unnamed -> fallback")
check(Names.Control(nil) == "<unnamed>", "Control: nil -> <unnamed>")
local erroring = { GetName = function() error("boom") end }
check(Names.Control(erroring, "fb2") == "fb2", "Control: erroring :GetName is pcall-guarded -> fallback")

-- Parent
local child = { GetParent = function() return named end }
check(Names.Parent(child) == "BUI_BankList", "Parent: resolves parent name")
check(Names.Parent({}) == "<none>", "Parent: no GetParent -> <none>")

-- Scene
check(Names.Scene("hud") == "hud", "Scene: string passthrough")
check(Names.Scene({ GetName = function() return "gamepad_banking" end }) == "gamepad_banking", "Scene: resolves name")
check(Names.Scene(nil) == "<unknown>", "Scene: nil -> <unknown>")

-- Category
local cats = { { name = "Weapons" }, { displayName = "Armor" }, "Materials" }
check(Names.Category(cats, 1) == "Weapons", "Category: name field")
check(Names.Category(cats, 2) == "Armor", "Category: displayName field")
check(Names.Category(cats, 3) == "Materials", "Category: string entry")
check(Names.Category(cats, 9):find("category%[9%]") ~= nil, "Category: out-of-range -> fallback")

-- Sort
check(Names.Sort("Quality", true) == "Quality desc", "Sort: true -> desc")
check(Names.Sort("Name", false) == "Name asc", "Sort: false -> asc")
check(Names.Sort("Value") == "Value", "Sort: no direction")

-- Item
check(Names.Item(1, 5) == "Rubedite Ingot", "Item: resolves name from bag/slot")
check(Names.Item(9, 9):find("item%[9:9%]") ~= nil, "Item: unresolved -> fallback")

-- FlattenText / PreviewText
check(Names.FlattenText("a\nb\tc") == "a b c", "FlattenText: collapses newlines/tabs")
local preview, len = Names.PreviewText(string.rep("x", 50), 10)
check(#preview == 13 and len == 50, "PreviewText: caps to maxChars + '...' and reports original length")

-- Userdata controls/scenes (ESO controls are userdata, not tables) via newproxy.
if type(newproxy) == "function" then
    local ud = newproxy(true)
    getmetatable(ud).__index = { GetName = function() return "BUI_UserdataCtrl" end }
    check(Names.Control(ud) == "BUI_UserdataCtrl", "Control: resolves userdata control via :GetName()")
    local udChild = newproxy(true)
    getmetatable(udChild).__index = { GetParent = function() return ud end }
    check(Names.Parent(udChild) == "BUI_UserdataCtrl", "Parent: resolves userdata parent")
    local udScene = newproxy(true)
    getmetatable(udScene).__index = { GetName = function() return "gamepad_bank" end }
    check(Names.Scene(udScene) == "gamepad_bank", "Scene: resolves userdata scene")
else
    print("  [--] newproxy unavailable; skipping userdata cases")
end

-- A hostile __tostring must never raise (a log call can never error).
local hostile = setmetatable({}, { __tostring = function() error("boom") end })
check(Names.FlattenText(hostile) == "<?>", "FlattenText: erroring __tostring is guarded -> fallback")
check(type(Names.Sort(hostile)) == "string", "Sort: erroring __tostring fallback is guarded")

-- Missing item API -> fallback, no crash.
local savedGetItemName = GetItemName
GetItemName = nil
check(Names.Item(1, 5):find("item%[1:5%]") ~= nil, "Item: missing GetItemName API -> fallback")
GetItemName = savedGetItemName

print("\n=== Test Summary ===")
print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))
if failed > 0 then os.exit(1) else print("\nAll tests passed!"); os.exit(0) end
