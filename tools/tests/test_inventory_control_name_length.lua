--[[
File: tools/tests/test_inventory_control_name_length.lua
Purpose: Regression test for PB-005. The ESO engine truncates control names longer
         than 63 characters, spamming interface.log and risking name collisions.
         The pooled list controls under the inventory TopLevel built their names by
         cascading $(parent): <TopLevel>MaskContainerItemsListScroll<pooled child>.
         With the old TopLevel name (BETTERUI_GamepadInventoryTopLevel, 32 chars) the
         scroll control name alone was already 60 chars, so any pooled child (e.g.
         SelectionIndicator) overflowed the 63-char limit.

         The fix renames the TopLevel control to a short token (BUI_GpInv, 9 chars).
         This test reconstructs the worst-case pooled control names from both the old
         and new TopLevel names and asserts:
           1. The OLD name overflowed the engine limit (characterizes the bug).
           2. The NEW name keeps every worst-case pooled name <= 63 chars.

Mirrors the rename in:
  - Modules/Inventory/Templates/GamepadInventory.xml (TopLevelControl name)
  - Modules/Inventory/Module.lua (Class:New / ZO_SimpleSceneFragment:New)
  - .luarc.json (globals whitelist)
]]

local ENGINE_CONTROL_NAME_LIMIT = 63

local OLD_TOPLEVEL = "BETTERUI_GamepadInventoryTopLevel"
local NEW_TOPLEVEL = "BUI_GpInv"

-- The $(parent) cascade from BETTERUI_Gamepad_ParametricList_Screen down to the
-- pooled item-list scroll control (matches the interface.log warning shape).
local SCROLL_SUFFIX = "MaskContainerItemsListScroll"

-- Worst-case pooled child suffixes appended to the scroll control name. Pooled
-- controls append a numeric index plus a named child; SelectionIndicator is the
-- longest named child on the inventory entry template. Index 99 covers a deep
-- pool without being unrealistic.
local POOLED_CHILD_SUFFIXES = {
    "99SelectionIndicator",
    "99BG",
    "99Icon",
    "99StatusIndicator",
}

local function worstPooledName(topLevel)
    local longest = ""
    for _, suffix in ipairs(POOLED_CHILD_SUFFIXES) do
        local name = topLevel .. SCROLL_SUFFIX .. suffix
        if #name > #longest then
            longest = name
        end
    end
    return longest
end

-- ===========================================================================
-- Test harness
-- ===========================================================================
local tests_passed = 0
local tests_failed = 0

local function assert_true(value, message)
    if value == true then
        tests_passed = tests_passed + 1
        print("  [OK] " .. message)
    else
        tests_failed = tests_failed + 1
        print("  [X] " .. message)
    end
end

print("=== PB-005: pooled control names must stay within the 63-char limit ===")

-- Scenario 1 (characterizes the BUG): the old TopLevel overflowed.
do
    local oldName = worstPooledName(OLD_TOPLEVEL)
    print(string.format("  old worst-case name (%d chars): %s", #oldName, oldName))
    assert_true(#oldName > ENGINE_CONTROL_NAME_LIMIT,
        "OLD/buggy: worst-case pooled name exceeds the 63-char engine limit")
end

-- Scenario 2 (the FIX): the new TopLevel keeps every worst-case name within limit.
do
    local newName = worstPooledName(NEW_TOPLEVEL)
    print(string.format("  new worst-case name (%d chars): %s", #newName, newName))
    assert_true(#newName <= ENGINE_CONTROL_NAME_LIMIT,
        "FIX: worst-case pooled name is within the 63-char engine limit")

    -- Every individual pooled child name must also fit.
    local allFit = true
    for _, suffix in ipairs(POOLED_CHILD_SUFFIXES) do
        local name = NEW_TOPLEVEL .. SCROLL_SUFFIX .. suffix
        if #name > ENGINE_CONTROL_NAME_LIMIT then
            allFit = false
        end
    end
    assert_true(allFit, "FIX: all pooled child control names fit within the limit")
end

-- Scenario 3: the short category-list controlPoolPrefix ("BUI_Cat") also produces
-- names within the limit (belt-and-suspenders measure added in CategoryListManager).
do
    local catName = "BUI_Cat" .. "99" .. "SelectionIndicator"
    print(string.format("  category pool name (%d chars): %s", #catName, catName))
    assert_true(#catName <= ENGINE_CONTROL_NAME_LIMIT,
        "FIX: category pool prefix produces names within the limit")
end

print("\n=== Summary ===")
print(string.format("Passed: %d", tests_passed))
print(string.format("Failed: %d", tests_failed))
print("")

if tests_failed > 0 then
    os.exit(1)
end
