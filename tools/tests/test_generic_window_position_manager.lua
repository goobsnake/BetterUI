--[[
File: tools/tests/test_generic_window_position_manager.lua
Purpose: PLT-003 — GenericWindow category-position persistence now delegates to
         the shared, uniqueId-aware BETTERUI.CIM.PositionManager. Verifies the
         cursor restores onto the same ITEM (by uniqueId) after a list reorder,
         falls back to the clamped saved index when the item is gone, isolates
         positions per window, clears correctly, and is safe with no list.
Usage:
  lua tools/tests/test_generic_window_position_manager.lua
]]

-- Engine stubs
function zo_clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi else return v end
end

BETTERUI = { CIM = {} }

-- Minimal BETTERUI.Interface.Window base so GenericWindow can subclass + init.
BETTERUI.Interface = { Window = {} }
function BETTERUI.Interface.Window:Subclass()
    return setmetatable({}, { __index = self })
end
function BETTERUI.Interface.Window.New(class, ...)
    local obj = setmetatable({}, { __index = class })
    if obj.Initialize then obj:Initialize(...) end
    return obj
end
function BETTERUI.Interface.Window:Initialize(_tlw, _scene, _tmpl) end

dofile("Modules/CIM/Core/Data/PositionManager.lua")
dofile("Modules/CIM/Core/Window/GenericWindow.lua")

local passed, failed = 0, 0
local function check(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

assert(type(BETTERUI.CIM.GenericWindow) == "table", "GenericWindow class must load")
assert(type(BETTERUI.CIM.PositionManager) == "table", "PositionManager must load")

local win = BETTERUI.CIM.GenericWindow:New("BetterUITestTLW", "testScene")
check(win.positionModuleKey, "GenericWindow:testScene", "per-window namespace derived from scene name")
check(win.currentCategoryKey, nil, "currentCategoryKey starts nil")

-- Save with the selected item at index 2 (uniqueId ITEM_X), then reorder the list.
win.list = {
    selectedIndex = 2,
    selectedData = { uniqueId = "ITEM_X" },
    dataList = {
        { uniqueId = "ITEM_A" },
        { uniqueId = "ITEM_X" },
        { uniqueId = "ITEM_C" },
    },
}
win:SaveCategoryPosition("cat1")
win.list.dataList = { { uniqueId = "ITEM_X" }, { uniqueId = "ITEM_A" } }
check(win:RestoreCategoryPosition("cat1"), 1, "restores onto the same item by uniqueId after a reorder")

-- uniqueId gone -> clamped saved-index fallback (saved index 3, only 2 items now -> 2).
win.list = {
    selectedIndex = 3,
    selectedData = { uniqueId = "GONE" },
    dataList = { { uniqueId = "P" }, { uniqueId = "Q" }, { uniqueId = "R" } },
}
win:SaveCategoryPosition("cat2")
win.list.dataList = { { uniqueId = "P" }, { uniqueId = "Q" } }
check(win:RestoreCategoryPosition("cat2"), 2, "falls back to the clamped saved index when the item is gone")

-- Unsaved category -> 1.
check(win:RestoreCategoryPosition("never"), 1, "returns 1 for an unsaved category")

-- Clear wipes this window's saved positions.
win:ClearCategoryPositions()
check(win:RestoreCategoryPosition("cat1"), 1, "returns 1 after ClearCategoryPositions")

-- Per-window namespace isolation.
local win2 = BETTERUI.CIM.GenericWindow:New("OtherTLW", "otherScene")
check(win2.positionModuleKey ~= win.positionModuleKey, true, "each window has its own PositionManager namespace")

-- Missing list -> safe defaults (must not error).
local win3 = BETTERUI.CIM.GenericWindow:New("NoListTLW", "noListScene")
win3:SaveCategoryPosition("c")
check(win3:RestoreCategoryPosition("c"), 1, "no list restores to 1 without error")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
