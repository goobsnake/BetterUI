--[[
File: tools/tests/test_orb_independent_positioning.lua
Purpose: Source-level tests for independent orb offset positioning (HUD-001).
         Verifies that the orb composite (ornaments + orbs + bgMiddle-anchored
         XP/mount bars) moves together when enableIndependentOrbOffset is true,
         without double-applying the offset to ornament-anchored orbs.
]]

local function assertTrue(condition, message)
    if not condition then
        error("ASSERTION FAILED: " .. tostring(message), 2)
    end
end

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*all")
    f:close()
    return content
end

local function count_occurrences(haystack, pattern)
    local count = 0
    for _ in haystack:gmatch(pattern) do
        count = count + 1
    end
    return count
end

local source = read_file("Modules/ResourceOrbFrames/Core/OrbVisuals.lua")
assertTrue(source ~= nil, "OrbVisuals.lua readable")

-- Test 1: orbOffsetX and orbOffsetY are read from settings
assertTrue(source:find("orbOffsetX = settings%.enableIndependentOrbOffset and %(settings%.orbOffsetX or 0%) or 0") ~= nil,
    "Source reads orbOffsetX with enableIndependentOrbOffset guard")
assertTrue(source:find("orbOffsetY = settings%.enableIndependentOrbOffset and %(settings%.orbOffsetY or 0%) or 0") ~= nil,
    "Source reads orbOffsetY with enableIndependentOrbOffset guard")

-- Test 2: Ornament anchors carry the offset (the ornaments are the root of
-- the orb composite; everything anchored to them follows automatically)
assertTrue(source:find("cfg%.ornaments%.left%.x %+ orbOffsetX, cfg%.ornaments%.left%.y %+ orbOffsetY") ~= nil,
    "Left ornament anchor includes orb offset")
assertTrue(source:find("cfg%.ornaments%.right%.x %+ orbOffsetX, cfg%.ornaments%.right%.y %+ orbOffsetY") ~= nil,
    "Right ornament anchor includes orb offset")

-- Test 3: Ornament-anchored orb branches must NOT re-apply the offset
-- (the ornament already moved; adding it again would double-apply)
assertTrue(source:find("cfg%.orbs%.left%.x %* leftVisibleScale %+ orbOffsetX") == nil,
    "Left orb ornament-anchored branch does not re-apply offset (X)")
assertTrue(source:find("cfg%.orbs%.left%.y %* leftVisibleScale %+ orbOffsetY") == nil,
    "Left orb ornament-anchored branch does not re-apply offset (Y)")
assertTrue(source:find("cfg%.orbs%.left%.x %* leftVisibleScale") ~= nil,
    "Left orb ornament-anchored branch still anchors via ornament scale")
assertTrue(source:find("cfg%.orbs%.right%.x %* rightVisibleScale %+ orbOffsetX") == nil,
    "Right orb ornament-anchored branch does not re-apply offset (X)")
assertTrue(source:find("cfg%.orbs%.right%.y %* rightVisibleScale %+ orbOffsetY") == nil,
    "Right orb ornament-anchored branch does not re-apply offset (Y)")
assertTrue(source:find("cfg%.orbs%.right%.x %* rightVisibleScale") ~= nil,
    "Right orb ornament-anchored branch still anchors via ornament scale")

-- Test 4: Hidden-ornament and bgMiddle-fallback orb branches still add the offset
assertTrue(source:find("cfg%.orbs%.left%.noOrnament%.x or %(cfg%.ornaments%.left%.x %+ cfg%.orbs%.left%.x%)%) %+ orbOffsetX") ~= nil,
    "Left orb hidden-ornament branch includes offset (X)")
assertTrue(source:find("cfg%.orbs%.left%.noOrnament%.y or %(cfg%.ornaments%.left%.y %+ cfg%.orbs%.left%.y%)%) %+ orbOffsetY") ~= nil,
    "Left orb hidden-ornament branch includes offset (Y)")
assertTrue(source:find("cfg%.orbs%.right%.noOrnament%.x or %(cfg%.ornaments%.right%.x %+ cfg%.orbs%.right%.x%)%) %+ orbOffsetX") ~= nil,
    "Right orb hidden-ornament branch includes offset (X)")
assertTrue(source:find("cfg%.orbs%.right%.noOrnament%.y or %(cfg%.ornaments%.right%.y %+ cfg%.orbs%.right%.y%)%) %+ orbOffsetY") ~= nil,
    "Right orb hidden-ornament branch includes offset (Y)")
assertTrue(source:find("cfg%.ornaments%.left%.x %+ cfg%.orbs%.left%.x %+ orbOffsetX") ~= nil,
    "Left orb bgMiddle fallback includes offset (X)")
assertTrue(source:find("cfg%.ornaments%.left%.y %+ cfg%.orbs%.left%.y %+ orbOffsetY") ~= nil,
    "Left orb bgMiddle fallback includes offset (Y)")
assertTrue(source:find("cfg%.ornaments%.right%.x %+ cfg%.orbs%.right%.x %+ orbOffsetX") ~= nil,
    "Right orb bgMiddle fallback includes offset (X)")
assertTrue(source:find("cfg%.ornaments%.right%.y %+ cfg%.orbs%.right%.y %+ orbOffsetY") ~= nil,
    "Right orb bgMiddle fallback includes offset (Y)")

-- Test 5: Shield orb bgMiddle fallback applies the offset exactly once.
-- The left-orb fallback and the shield fallback are the only two sites using
-- this exact sum; more or fewer copies indicates a drift in offset handling.
assertTrue(count_occurrences(source, "cfg%.ornaments%.left%.x %+ cfg%.orbs%.left%.x %+ orbOffsetX") == 2,
    "Orb offset applied exactly once in left-orb and shield bgMiddle fallbacks")

-- Test 6: XP/mount bars follow the composite in their bgMiddle-anchored
-- branches (ornament-anchored branches follow the ornaments implicitly)
local orchestratorSource = read_file("Modules/ResourceOrbFrames/ResourceOrbFrames.lua")
assertTrue(orchestratorSource ~= nil, "ResourceOrbFrames.lua readable")

assertTrue(orchestratorSource:find("orbOffsetX = settings%.enableIndependentOrbOffset and %(settings%.orbOffsetX or 0%) or 0") ~= nil,
    "Orchestrator reads orbOffsetX with enableIndependentOrbOffset guard")
assertTrue(orchestratorSource:find("orbOffsetY = settings%.enableIndependentOrbOffset and %(settings%.orbOffsetY or 0%) or 0") ~= nil,
    "Orchestrator reads orbOffsetY with enableIndependentOrbOffset guard")

assertTrue(orchestratorSource:find("%(BARS%.XP%.NO_ORNAMENT_OFFSET_X or %-350%) %+ orbOffsetX") ~= nil,
    "XP bar no-ornament branch includes offset (X)")
assertTrue(orchestratorSource:find("%(BARS%.XP%.NO_ORNAMENT_OFFSET_Y or 108%) %+ orbOffsetY") ~= nil,
    "XP bar no-ornament branch includes offset (Y)")
assertTrue(orchestratorSource:find("XP_NO_ORNAMENT_FALLBACK_OFFSET_X %+ orbOffsetX") ~= nil,
    "XP bar bgMiddle fallback includes offset (X)")
assertTrue(orchestratorSource:find("%(BARS%.MOUNT%.NO_ORNAMENT_OFFSET_X or 375%) %+ orbOffsetX") ~= nil,
    "Mount bar no-ornament branch includes offset (X)")
assertTrue(orchestratorSource:find("%(BARS%.MOUNT%.NO_ORNAMENT_OFFSET_Y or 108%) %+ orbOffsetY") ~= nil,
    "Mount bar no-ornament branch includes offset (Y)")
assertTrue(orchestratorSource:find("MOUNT_NO_ORNAMENT_FALLBACK_OFFSET_X %+ orbOffsetX") ~= nil,
    "Mount bar bgMiddle fallback includes offset (X)")
assertTrue(count_occurrences(orchestratorSource, "BAR_FALLBACK_OFFSET_Y %+ orbOffsetY") == 2,
    "Both bar bgMiddle fallbacks include offset (Y)")

-- Test 7: Defaults include the new settings
local defaultsSource = read_file("Modules/ResourceOrbFrames/Settings/Defaults.lua")
assertTrue(defaultsSource ~= nil, "Defaults.lua readable")

assertTrue(defaultsSource:find("enableIndependentOrbOffset = false") ~= nil,
    "Defaults: enableIndependentOrbOffset defaults to false")
assertTrue(defaultsSource:find("orbOffsetX = 0") ~= nil,
    "Defaults: orbOffsetX defaults to 0")
assertTrue(defaultsSource:find("orbOffsetY = 0") ~= nil,
    "Defaults: orbOffsetY defaults to 0")

-- Test 8: Module defines the setting contracts
local moduleSource = read_file("Modules/ResourceOrbFrames/Module.lua")
assertTrue(moduleSource ~= nil, "Module.lua readable")

assertTrue(moduleSource:find("enableIndependentOrbOffset = CreateSettingContract%(") ~= nil,
    "Module: enableIndependentOrbOffset contract exists")
assertTrue(moduleSource:find("orbOffsetX = CreateSettingContract%(") ~= nil,
    "Module: orbOffsetX contract exists")
assertTrue(moduleSource:find("orbOffsetY = CreateSettingContract%(") ~= nil,
    "Module: orbOffsetY contract exists")

-- Test 9: UI controls exist and are gated by the toggle
assertTrue(moduleSource:find("SI_BETTERUI_RESOURCE_ORB_FRAMES_INDEPENDENT_ORB_OFFSET") ~= nil,
    "Module: Independent orb offset checkbox exists")
assertTrue(moduleSource:find("SI_BETTERUI_RESOURCE_ORB_FRAMES_ORB_OFFSET_Y") ~= nil,
    "Module: orbOffsetY slider exists")
assertTrue(moduleSource:find("SI_BETTERUI_RESOURCE_ORB_FRAMES_ORB_OFFSET_X") ~= nil,
    "Module: orbOffsetX slider exists")
assertTrue(moduleSource:find("not generalContracts%.enableIndependentOrbOffset%.get%(") ~= nil,
    "Module: Sliders disabled when toggle is off")

print("test_orb_independent_positioning.lua: ALL TESTS PASSED")
