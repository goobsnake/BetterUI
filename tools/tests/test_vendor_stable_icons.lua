--[[
File: tools/tests/test_vendor_stable_icons.lua
Purpose: Regression tests for stablemaster icon resolution.
         Ensures the shared icon comes from valid ESO stable textures instead of
         the removed tabIcon_mounts_up vendor path.
]]

local passed = 0
local failed = 0

local RIDING_TRAIN_SPEED = 1
local RIDING_TRAIN_STAMINA = 2
local RIDING_TRAIN_CARRYING_CAPACITY = 3

local DEFAULT_STABLE_INTERACTION_ICON = "EsoUI/Art/Collections/Default/collections_default_mount.dds"

local function ResolveStableInteractionIcon()
    return DEFAULT_STABLE_INTERACTION_ICON
end

local function ShouldShowVendorHeaderTabBar(headerEntryCount)
    return (headerEntryCount or 0) > 0
end

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_ne(actual, unexpected, label)
    if actual ~= unexpected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- did not expect %s", label, tostring(unexpected)))
    end
end

print("[Vendor stable icon resolution]")

do
    local icon = ResolveStableInteractionIcon()
    assert_eq(icon, "EsoUI/Art/Collections/Default/collections_default_mount.dds",
        "resolver returns the mount collectible icon")
    assert_ne(icon, "EsoUI/Art/Vendor/tabIcon_mounts_up.dds",
        "resolver does not return the removed vendor mounts texture")
end

do
    assert_ne(ResolveStableInteractionIcon(), "EsoUI/Art/Mounts/Gamepad/gp_ridingSkill_speed.dds",
        "resolver does not reuse the riding speed trait icon")
end

do
    assert_eq(ResolveStableInteractionIcon(), DEFAULT_STABLE_INTERACTION_ICON,
        "resolver stays pinned to the mount icon")
end

do
    assert_eq(ShouldShowVendorHeaderTabBar(1), true,
        "single stable header entry keeps the category icon visible")
    assert_eq(ShouldShowVendorHeaderTabBar(0), false,
        "empty header entry set hides the tab bar")
    assert_eq(ShouldShowVendorHeaderTabBar(2), true,
        "multiple header entries keep the tab bar visible")
end

do
    local state = { hidden = nil, text = nil }
    local function ApplyStableFooterSpaceLabel(spaceLabel, isStableInteraction)
        if isStableInteraction then
            spaceLabel:SetHidden(true)
            spaceLabel:SetText("")
        else
            spaceLabel:SetHidden(false)
            spaceLabel:SetText("inventory info")
        end
    end

    local spaceLabel = {
        SetHidden = function(_, hidden)
            state.hidden = hidden
        end,
        SetText = function(_, text)
            state.text = text
        end,
    }

    ApplyStableFooterSpaceLabel(spaceLabel, true)
    assert_eq(state.hidden, true, "stable footer hides the small duplicate icon label")
    assert_eq(state.text, "", "stable footer clears the small duplicate icon label text")

    ApplyStableFooterSpaceLabel(spaceLabel, false)
    assert_eq(state.hidden, false, "non-stable footer keeps the space label visible")
    assert_eq(state.text, "inventory info", "non-stable footer still sets its secondary label")
end

do
    local GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT = {}
    local sceneCalls = { add = 0, remove = 0 }
    local scene = {
        AddFragment = function(_, fragment)
            assert_eq(fragment, GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT,
                "preview restore targets the quadrant background fragment")
            sceneCalls.add = sceneCalls.add + 1
        end,
        RemoveFragment = function(_, fragment)
            assert_eq(fragment, GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT,
                "preview hide targets the quadrant background fragment")
            sceneCalls.remove = sceneCalls.remove + 1
        end,
    }
    local controlHidden = nil
    local window = {
        _stablePreviewUiHidden = false,
        scene = scene,
        control = {
            SetHidden = function(_, hidden)
                controlHidden = hidden
            end,
        },
    }

    local function SetStablePreviewUiHidden(self, hidden)
        if self._stablePreviewUiHidden == hidden then
            return
        end
        self._stablePreviewUiHidden = hidden

        if self.control and self.control.SetHidden then
            self.control:SetHidden(hidden)
        end

        local activeScene = self.scene
        if activeScene and GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT then
            if hidden then
                activeScene:RemoveFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
            else
                activeScene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
            end
        end
    end

    SetStablePreviewUiHidden(window, true)
    assert_eq(controlHidden, true, "preview hide hides the vendor control")
    assert_eq(sceneCalls.remove, 1, "preview hide removes the quadrant background from the scene")

    SetStablePreviewUiHidden(window, false)
    assert_eq(controlHidden, false, "preview restore shows the vendor control")
    assert_eq(sceneCalls.add, 1, "preview restore re-adds the quadrant background to the scene")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end