--[[
File: tools/tests/test_vendor_stable_active_mount.lua
Purpose: Unit tests for StableTrainingComponent active mount icon resolution.
Usage:
  lua tools/tests/test_vendor_stable_active_mount.lua
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

-- Minimal stub environment so StableTrainingComponent.lua can load.
BETTERUI = {
    Vendor = {},
    CIM = {
        UserAlertText = function() end,
    },
}

RIDING_TRAIN_SPEED = 1
RIDING_TRAIN_STAMINA = 2
RIDING_TRAIN_CARRYING_CAPACITY = 3

DEFAULT_STABLE_INTERACTION_ICON = "EsoUI/Art/Collections/Default/collections_default_mount.dds"
CUSTOM_DEFAULT_ICON = "custom/default.dds"

COLLECTIBLE_CATEGORY_TYPE_MOUNT = 10
GAMEPLAY_ACTOR_CATEGORY_PLAYER = 1

function GetString(value)
    return tostring(value)
end

-- Stub active mount lookup; tests will override these.
local activeCollectibleId = 0
local collectibleIcons = {}
local collectibleNames = {}

function GetActiveCollectibleByType(categoryType, actorCategory)
    if categoryType == COLLECTIBLE_CATEGORY_TYPE_MOUNT
        and actorCategory == GAMEPLAY_ACTOR_CATEGORY_PLAYER then
        return activeCollectibleId
    end
    return 0
end

function GetCollectibleIcon(collectibleId)
    return collectibleIcons[collectibleId]
end

function GetCollectibleName(collectibleId)
    return collectibleNames[collectibleId]
end

dofile("Modules/Vendor/Components/StableTrainingComponent.lua")

print("[Vendor stable active mount icon]")

local resolve = BETTERUI.Vendor.ResolveActiveMountIcon
assert_eq(type(resolve), "function", "ResolveActiveMountIcon is exposed on Vendor")

-- No active mount falls back to the provided default.
activeCollectibleId = 0
assert_eq(resolve(CUSTOM_DEFAULT_ICON), CUSTOM_DEFAULT_ICON, "no active mount uses supplied default")
assert_eq(resolve(nil), DEFAULT_STABLE_INTERACTION_ICON, "no active mount falls back to module default")

-- Active mount returns its icon.
activeCollectibleId = 42
collectibleIcons[42] = "EsoUI/Art/Mounts/mount_42.dds"
assert_eq(resolve(CUSTOM_DEFAULT_ICON), "EsoUI/Art/Mounts/mount_42.dds", "active mount icon returned")

-- Active mount with blank icon falls back.
activeCollectibleId = 43
collectibleIcons[43] = ""
assert_eq(resolve(CUSTOM_DEFAULT_ICON), CUSTOM_DEFAULT_ICON, "blank active icon falls back")

-- GetStableNoMountWarning uses fallback string when no SI_ id exists.
local warning = BETTERUI.Vendor.GetStableNoMountWarning()
assert_eq(type(warning), "string", "no-mount warning is a string")
assert_eq(warning ~= "", true, "no-mount warning is non-empty")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
