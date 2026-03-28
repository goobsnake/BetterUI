--[[
File: tools/tests/test_orb_bars_pure.lua
Purpose: Unit tests for pure functions in ResourceOrbFrames/Core/OrbBars.lua.
         Tests run standalone with a Lua interpreter (no ESO environment).
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = { ResourceOrbFrames = { CONST = { BARS = { XP = 1, CAST = 2, MOUNT = 3 } } } }
function BETTERUI.CloneColor(c)
    if type(c) ~= "table" then return c end
    return { c[1], c[2], c[3], c[4] }
end

COMBAT_MECHANIC_FLAGS_HEALTH = 1
COMBAT_MECHANIC_FLAGS_MAGICKA = 2
COMBAT_MECHANIC_FLAGS_STAMINA = 4
COMBAT_MECHANIC_FLAGS_ULTIMATE = 8

-- ============================================================================
-- EXTRACT PURE FUNCTIONS UNDER TEST
-- ============================================================================

local function ResolveTexturePath(filename)
    return string.format("%s/%s", "BetterUI/Modules/ResourceOrbFrames/Textures", filename)
end

local function ResolveBarTexturePath(textureFile)
    if not textureFile then return nil end
    if string.find(textureFile, "/", 1, true) or string.find(textureFile, "\\", 1, true) then
        return textureFile
    end
    return ResolveTexturePath(textureFile)
end

local DEFAULT_CAST_BAR_FILL_STYLE = {
    fill = { 1, 1, 0.4, 1 },
    depth = { 0.45, 0.45, 0.18, 1 },
}
local CAST_BAR_ORB_FILL_STYLES = {
    health = {
        fill = { 1, 0, 0, 1 },
        depth = { 0.30196, 0, 0, 1 },
    },
    magicka = {
        fill = { 0, 0.4, 1, 1 },
        depth = { 0, 0, 0.2, 1 },
    },
    stamina = {
        fill = { 0, 1, 0, 1 },
        depth = { 0, 0.30196, 0, 1 },
    },
}

local CloneColor = BETTERUI.CloneColor

local function GetCastBarFillStyle(styleKey)
    local style = CAST_BAR_ORB_FILL_STYLES[styleKey]
    if not style then
        style = DEFAULT_CAST_BAR_FILL_STYLE
    end
    return CloneColor(style.fill), CloneColor(style.depth)
end

local function ResolveCastBarFillColorByPowerType(powerType)
    if powerType == COMBAT_MECHANIC_FLAGS_STAMINA then
        return GetCastBarFillStyle("stamina")
    end
    if powerType == COMBAT_MECHANIC_FLAGS_MAGICKA then
        return GetCastBarFillStyle("magicka")
    end
    if powerType == COMBAT_MECHANIC_FLAGS_HEALTH then
        return GetCastBarFillStyle("health")
    end
    return nil, nil
end

local function IsValidRegion(region)
    return type(region) == "table"
        and type(region.left) == "number"
        and type(region.right) == "number"
        and type(region.top) == "number"
        and type(region.bottom) == "number"
end

-- ============================================================================
-- TEST INFRASTRUCTURE
-- ============================================================================

local passed, failed = 0, 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s — expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, label)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s — expected true, got %s", label, tostring(value)))
    end
end

local function assert_nil(value, label)
    if value == nil then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s — expected nil, got %s", label, tostring(value)))
    end
end

-- ============================================================================
-- TESTS: ResolveTexturePath
-- ============================================================================

print("[ResolveTexturePath]")
assert_eq(ResolveTexturePath("Bar.dds"), "BetterUI/Modules/ResourceOrbFrames/Textures/Bar.dds", "simple filename")
assert_eq(ResolveTexturePath("OrbFill.dds"), "BetterUI/Modules/ResourceOrbFrames/Textures/OrbFill.dds", "orb fill")
assert_eq(ResolveTexturePath(""), "BetterUI/Modules/ResourceOrbFrames/Textures/", "empty string")

-- ============================================================================
-- TESTS: ResolveBarTexturePath
-- ============================================================================

print("[ResolveBarTexturePath]")
assert_nil(ResolveBarTexturePath(nil), "nil returns nil")
assert_eq(ResolveBarTexturePath("Bar.dds"), "BetterUI/Modules/ResourceOrbFrames/Textures/Bar.dds", "bare filename resolved")
assert_eq(ResolveBarTexturePath("custom/path/Bar.dds"), "custom/path/Bar.dds", "path with slash returned as-is")
assert_eq(ResolveBarTexturePath("custom\\path\\Bar.dds"), "custom\\path\\Bar.dds", "path with backslash returned as-is")
assert_eq(ResolveBarTexturePath("OrbFill.dds"), "BetterUI/Modules/ResourceOrbFrames/Textures/OrbFill.dds", "bare orb fill")

-- ============================================================================
-- TESTS: GetCastBarFillStyle
-- ============================================================================

print("[GetCastBarFillStyle]")
do
    local fill, depth = GetCastBarFillStyle("health")
    assert_eq(fill[1], 1, "health fill r")
    assert_eq(fill[2], 0, "health fill g")
    assert_eq(depth[1], 0.30196, "health depth r")

    fill, depth = GetCastBarFillStyle("magicka")
    assert_eq(fill[2], 0.4, "magicka fill g")
    assert_eq(fill[3], 1, "magicka fill b")

    fill, depth = GetCastBarFillStyle("stamina")
    assert_eq(fill[2], 1, "stamina fill g")
    assert_eq(depth[2], 0.30196, "stamina depth g")

    -- unknown key falls back to default
    fill, depth = GetCastBarFillStyle("unknown")
    assert_eq(fill[1], 1, "default fill r")
    assert_eq(fill[2], 1, "default fill g")
    assert_eq(fill[3], 0.4, "default fill b")
    assert_eq(depth[1], 0.45, "default depth r")

    -- nil key also falls back
    fill, depth = GetCastBarFillStyle(nil)
    assert_eq(fill[1], 1, "nil-key fill r")
end

-- ============================================================================
-- TESTS: ResolveCastBarFillColorByPowerType
-- ============================================================================

print("[ResolveCastBarFillColorByPowerType]")
do
    local fill, depth = ResolveCastBarFillColorByPowerType(COMBAT_MECHANIC_FLAGS_STAMINA)
    assert_eq(fill[2], 1, "stamina power → green fill")

    fill, depth = ResolveCastBarFillColorByPowerType(COMBAT_MECHANIC_FLAGS_MAGICKA)
    assert_eq(fill[3], 1, "magicka power → blue fill")

    fill, depth = ResolveCastBarFillColorByPowerType(COMBAT_MECHANIC_FLAGS_HEALTH)
    assert_eq(fill[1], 1, "health power → red fill")

    fill, depth = ResolveCastBarFillColorByPowerType(COMBAT_MECHANIC_FLAGS_ULTIMATE)
    assert_nil(fill, "ultimate power → nil")
    assert_nil(depth, "ultimate power depth → nil")

    fill, depth = ResolveCastBarFillColorByPowerType(999)
    assert_nil(fill, "unknown power → nil")
end

-- ============================================================================
-- TESTS: IsValidRegion
-- ============================================================================

print("[IsValidRegion]")
assert_true(IsValidRegion({ left = 0, right = 1, top = 0, bottom = 1 }), "valid region")
assert_true(IsValidRegion({ left = 0.1, right = 0.9, top = 0.2, bottom = 0.8 }), "valid inset region")
assert_true(not IsValidRegion(nil), "nil is not valid")
assert_true(not IsValidRegion({}), "empty table missing fields")
assert_true(not IsValidRegion({ left = 0, right = 1, top = 0 }), "missing bottom")
assert_true(not IsValidRegion({ left = "0", right = 1, top = 0, bottom = 1 }), "string left value")
assert_true(not IsValidRegion("string"), "string is not valid")
assert_true(not IsValidRegion(42), "number is not valid")

-- ============================================================================
-- RESULTS
-- ============================================================================

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
