--[[
File: tools/tests/test_orb_independent_positioning.lua
Purpose: Source-level tests for independent orb offset positioning (HUD-001).
         Verifies that UpdateOrbLayout applies orbOffsetX/orbOffsetY when
         enableIndependentOrbOffset is true.
]]

local function assertTrue(condition, message)
    if not condition then
        error("ASSERTION FAILED: " .. tostring(message), 2)
    end
end

local function assertEqual(expected, actual, message)
    assertTrue(expected == actual, string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)))
end

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    return content
end

local source = read_file("Modules/ResourceOrbFrames/Core/OrbVisuals.lua")
assertTrue(source ~= nil, "OrbVisuals.lua readable")

-- Test 1: orbOffsetX and orbOffsetY are read from settings
assertTrue(source:find("orbOffsetX = settings%.enableIndependentOrbOffset and %(settings%.orbOffsetX or 0%) or 0") ~= nil,
    "Source reads orbOffsetX with enableIndependentOrbOffset guard")
assertTrue(source:find("orbOffsetY = settings%.enableIndependentOrbOffset and %(settings%.orbOffsetY or 0%) or 0") ~= nil,
    "Source reads orbOffsetY with enableIndependentOrbOffset guard")

-- Test 2: Left orb positioning includes offsets in all branches
-- ornament visible branch
assertTrue(source:find("cfg%.orbs%.left%.x %* leftVisibleScale %+ orbOffsetX") ~= nil,
    "Left orb X includes offset in ornament-visible branch")
assertTrue(source:find("cfg%.orbs%.left%.y %* leftVisibleScale %+ orbOffsetY") ~= nil,
    "Left orb Y includes offset in ornament-visible branch")

-- fallback branch
assertTrue(source:find("cfg%.ornaments%.left%.x %+ cfg%.orbs%.left%.x %+ orbOffsetX") ~= nil,
    "Left orb X includes offset in fallback branch")
assertTrue(source:find("cfg%.ornaments%.left%.y %+ cfg%.orbs%.left%.y %+ orbOffsetY") ~= nil,
    "Left orb Y includes offset in fallback branch")

-- Test 3: Right orb positioning includes offsets in all branches
assertTrue(source:find("cfg%.orbs%.right%.x %* rightVisibleScale %+ orbOffsetX") ~= nil,
    "Right orb X includes offset in ornament-visible branch")
assertTrue(source:find("cfg%.orbs%.right%.y %* rightVisibleScale %+ orbOffsetY") ~= nil,
    "Right orb Y includes offset in ornament-visible branch")

assertTrue(source:find("cfg%.ornaments%.right%.x %+ cfg%.orbs%.right%.x %+ orbOffsetX") ~= nil,
    "Right orb X includes offset in fallback branch")
assertTrue(source:find("cfg%.ornaments%.right%.y %+ cfg%.orbs%.right%.y %+ orbOffsetY") ~= nil,
    "Right orb Y includes offset in fallback branch")

-- Test 4: Defaults include the new settings
local defaultsSource = read_file("Modules/ResourceOrbFrames/Settings/Defaults.lua")
assertTrue(defaultsSource ~= nil, "Defaults.lua readable")

assertTrue(defaultsSource:find("enableIndependentOrbOffset = false") ~= nil,
    "Defaults: enableIndependentOrbOffset defaults to false")
assertTrue(defaultsSource:find("orbOffsetX = 0") ~= nil,
    "Defaults: orbOffsetX defaults to 0")
assertTrue(defaultsSource:find("orbOffsetY = 0") ~= nil,
    "Defaults: orbOffsetY defaults to 0")

-- Test 5: Module defines the setting contracts
local moduleSource = read_file("Modules/ResourceOrbFrames/Module.lua")
assertTrue(moduleSource ~= nil, "Module.lua readable")

assertTrue(moduleSource:find("enableIndependentOrbOffset = CreateSettingContract%(") ~= nil,
    "Module: enableIndependentOrbOffset contract exists")
assertTrue(moduleSource:find("orbOffsetX = CreateSettingContract%(") ~= nil,
    "Module: orbOffsetX contract exists")
assertTrue(moduleSource:find("orbOffsetY = CreateSettingContract%(") ~= nil,
    "Module: orbOffsetY contract exists")

-- Test 6: UI controls exist and are gated by the toggle
assertTrue(moduleSource:find("SI_BETTERUI_RESOURCE_ORB_FRAMES_INDEPENDENT_ORB_OFFSET") ~= nil,
    "Module: Independent orb offset checkbox exists")
assertTrue(moduleSource:find("SI_BETTERUI_RESOURCE_ORB_FRAMES_ORB_OFFSET_Y") ~= nil,
    "Module: orbOffsetY slider exists")
assertTrue(moduleSource:find("SI_BETTERUI_RESOURCE_ORB_FRAMES_ORB_OFFSET_X") ~= nil,
    "Module: orbOffsetX slider exists")
assertTrue(moduleSource:find("not generalContracts%.enableIndependentOrbOffset%.get%(") ~= nil,
    "Module: Sliders disabled when toggle is off")

print("test_orb_independent_positioning.lua: ALL TESTS PASSED")
