--[[
File: tools/tests/test_scene_cleanup.lua
Purpose: Regression coverage for shared scene cleanup state resets.
Usage:
  lua tools/tests/test_scene_cleanup.lua
]]

BETTERUI = {
    CIM = {},
}

KEYBIND_STRIP = nil

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

local function assert_true(value, label)
    assert_eq(value == true, true, label)
end

dofile("Modules/CIM/Core/Lifecycle/SceneCleanup.lua")

print("[SceneCleanup confirmation reset]")

do
    local searchDeactivated = 0
    local tabBarDeactivated = 0
    local screen
    screen = {
        confirmationMode = true,
        isInHeaderSortMode = true,
        _searchModeActive = true,
        _searchHeaderActive = true,
        textSearchHeaderFocus = {
            Deactivate = function()
                searchDeactivated = searchDeactivated + 1
            end,
            SetFocused = function(_, focused)
                screen.searchFocused = focused
            end,
        },
        headerGeneric = {
            tabBar = {
                Deactivate = function()
                    tabBarDeactivated = tabBarDeactivated + 1
                end,
            },
        },
    }

    BETTERUI.CIM.SceneCleanup.CleanupInputState(screen)

    assert_eq(screen.confirmationMode, false, "cleanup clears stale confirmation mode")
    assert_eq(screen.isInHeaderSortMode, false, "cleanup clears header sort mode")
    assert_eq(screen._searchModeActive, false, "cleanup clears search mode flag")
    assert_eq(screen._searchHeaderActive, false, "cleanup clears search header flag")
    assert_eq(searchDeactivated, 1, "cleanup deactivates search focus")
    assert_eq(tabBarDeactivated, 1, "cleanup deactivates header tab bar")
    assert_true(screen.searchFocused == false, "cleanup clears search focus state")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end