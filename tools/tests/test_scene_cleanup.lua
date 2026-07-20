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

local function assert_contains(list, expected, label)
    for _, value in ipairs(list) do
        if value == expected then
            passed = passed + 1
            return
        end
    end
    failed = failed + 1
    print(string.format("  FAIL: %s -- missing %s", label, tostring(expected)))
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
        _searchTextChangedInProgress = true,
        _preserveSearchFocusDuringRefresh = true,
        _exitSearchModeInProgress = true,
        _requestingVendorHeaderFocus = true,
        _requestingVendorHeaderLeave = true,
        _requestingVendorSearchHeaderLeave = true,
        _restoringVendorSearchFocus = true,
        _refreshingVendorHeaderAfterSearchExit = true,
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
    assert_eq(screen._searchTextChangedInProgress, nil, "cleanup clears search change guard")
    assert_eq(screen._preserveSearchFocusDuringRefresh, nil, "cleanup clears search focus preservation guard")
    assert_eq(screen._exitSearchModeInProgress, nil, "cleanup clears search exit guard")
    assert_eq(screen._requestingVendorHeaderFocus, nil, "cleanup clears vendor header focus guard")
    assert_eq(screen._requestingVendorHeaderLeave, nil, "cleanup clears vendor header leave guard")
    assert_eq(screen._requestingVendorSearchHeaderLeave, nil, "cleanup clears vendor search header leave guard")
    assert_eq(screen._restoringVendorSearchFocus, nil, "cleanup clears vendor search focus restore guard")
    assert_eq(screen._refreshingVendorHeaderAfterSearchExit, nil, "cleanup clears vendor post-search refresh guard")
    assert_eq(searchDeactivated, 1, "cleanup deactivates search focus")
    assert_eq(tabBarDeactivated, 1, "cleanup deactivates header tab bar")
    assert_true(screen.searchFocused == false, "cleanup clears search focus state")
end

do
    local purged = {}
    BETTERUI.Interface = {
        RemoveKeybindGroupFromAllStates = function(group)
            purged[#purged + 1] = group
            return true, 1
        end,
    }
    KEYBIND_STRIP = {}
    local activeHeader = { id = "active-header" }
    local header = { id = "header" }
    local integrationHeader = { id = "integration-header" }
    local search = { id = "search" }
    local screen = {
        isInHeaderSortMode = true,
        _activeHeaderSortKeybindDescriptor = activeHeader,
        headerSortKeybindDescriptor = header,
        textSearchKeybindStripDescriptor = search,
        _headerSortIntegration = {
            isActive = true,
            activeKeybindDescriptor = integrationHeader,
        },
    }

    BETTERUI.CIM.SceneCleanup.CleanupInputState(screen)
    BETTERUI.CIM.SceneCleanup.ClearSearchState(screen)
    assert_contains(purged, activeHeader,
        "hidden cleanup purges the active header descriptor from saved states")
    assert_contains(purged, header,
        "hidden cleanup purges the header descriptor from saved states")
    assert_contains(purged, integrationHeader,
        "hidden cleanup purges the integration header descriptor from saved states")
    assert_contains(purged, search,
        "hidden cleanup purges the search descriptor from saved states")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end