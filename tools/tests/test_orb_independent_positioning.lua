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
assertTrue(source:find("cfg%.ornaments%.left%.x %+ orbOffsetX %+ loX, cfg%.ornaments%.left%.y %+ orbOffsetY %+ loY") ~= nil,
    "Left ornament anchor includes orb and element offsets")
assertTrue(source:find("cfg%.ornaments%.right%.x %+ orbOffsetX %+ roX, cfg%.ornaments%.right%.y %+ orbOffsetY %+ roY") ~= nil,
    "Right ornament anchor includes orb and element offsets")

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
assertTrue(source:find("cfg%.orbs%.left%.noOrnament%.x or %(cfg%.ornaments%.left%.x %+ cfg%.orbs%.left%.x%)%) %+ orbOffsetX %+ loX") ~= nil,
    "Left orb hidden-ornament branch includes orb and element offsets (X)")
assertTrue(source:find("cfg%.orbs%.left%.noOrnament%.y or %(cfg%.ornaments%.left%.y %+ cfg%.orbs%.left%.y%)%) %+ orbOffsetY %+ loY") ~= nil,
    "Left orb hidden-ornament branch includes orb and element offsets (Y)")
assertTrue(source:find("cfg%.orbs%.right%.noOrnament%.x or %(cfg%.ornaments%.right%.x %+ cfg%.orbs%.right%.x%)%) %+ orbOffsetX %+ roX") ~= nil,
    "Right orb hidden-ornament branch includes orb and element offsets (X)")
assertTrue(source:find("cfg%.orbs%.right%.noOrnament%.y or %(cfg%.ornaments%.right%.y %+ cfg%.orbs%.right%.y%)%) %+ orbOffsetY %+ roY") ~= nil,
    "Right orb hidden-ornament branch includes orb and element offsets (Y)")
assertTrue(source:find("cfg%.ornaments%.left%.x %+ cfg%.orbs%.left%.x %+ orbOffsetX %+ loX") ~= nil,
    "Left orb bgMiddle fallback includes orb and element offsets (X)")
assertTrue(source:find("cfg%.ornaments%.left%.y %+ cfg%.orbs%.left%.y %+ orbOffsetY %+ loY") ~= nil,
    "Left orb bgMiddle fallback includes orb and element offsets (Y)")
assertTrue(source:find("cfg%.ornaments%.right%.x %+ cfg%.orbs%.right%.x %+ orbOffsetX %+ roX") ~= nil,
    "Right orb bgMiddle fallback includes orb and element offsets (X)")
assertTrue(source:find("cfg%.ornaments%.right%.y %+ cfg%.orbs%.right%.y %+ orbOffsetY %+ roY") ~= nil,
    "Right orb bgMiddle fallback includes orb and element offsets (Y)")

-- Test 5: Shield orb bgMiddle fallback applies the offset exactly once.
-- The left-orb fallback and the shield fallback are the only two sites using
-- this exact sum; more or fewer copies indicates a drift in offset handling.
assertTrue(count_occurrences(source, "cfg%.ornaments%.left%.x %+ cfg%.orbs%.left%.x %+ orbOffsetX %+ loX") == 2,
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
assertTrue(orchestratorSource:find("BARS%.XP%.OFFSET_X %+ exX %- loX") ~= nil,
    "XP bar ornament branch subtracts left-orb offset so XP can move independently")
assertTrue(orchestratorSource:find("BARS%.MOUNT%.OFFSET_X %+ moX %- roX") ~= nil,
    "Mount bar ornament branch subtracts right-orb offset so mount can move independently")
assertTrue(orchestratorSource:find("BARS%.CAST%.OFFSET_X %+ caX %- sbX") ~= nil,
    "Cast bar bar-container branches subtract skill-bar offset so cast can move independently")
assertTrue(orchestratorSource:find("decoupledAnchors = true") ~= nil,
    "Orchestrator: element offset trace records decoupled anchor mode")

-- Test 7: Defaults include the new settings
local defaultsSource = read_file("Modules/ResourceOrbFrames/Settings/Defaults.lua")
assertTrue(defaultsSource ~= nil, "Defaults.lua readable")

assertTrue(defaultsSource:find("elementPositionsUnlocked = false") ~= nil,
    "Defaults: global element unlock defaults to false")
assertTrue(defaultsSource:find("enableIndependentOrbOffset = false") ~= nil,
    "Defaults: legacy enableIndependentOrbOffset remains readable for migration")
assertTrue(defaultsSource:find("orbOffsetX = 0") ~= nil,
    "Defaults: legacy orbOffsetX remains readable for migration")
assertTrue(defaultsSource:find("orbOffsetY = 0") ~= nil,
    "Defaults: legacy orbOffsetY remains readable for migration")
assertTrue(defaultsSource:find("local function MigrateLegacyIndependentOrbOffset%(m_options%)") ~= nil,
    "Defaults: legacy independent orb offset migrates into element positions")
assertTrue(defaultsSource:find("m_options%.elementPositionsUnlocked = legacyGlobalUnlock") ~= nil,
    "Defaults: legacy per-element unlocked state backfills the global unlock")

-- Test 8: Module defines the global unlock contract and retires the legacy UI contracts
local moduleSource = read_file("Modules/ResourceOrbFrames/Module.lua")
assertTrue(moduleSource ~= nil, "Module.lua readable")

assertTrue(moduleSource:find("elementPositionsUnlocked = CreateSettingContract%(\"elementPositionsUnlocked\", false%)") ~= nil,
    "Module: global element unlock contract exists")
assertTrue(moduleSource:find("drag%.SetAllElementsUnlocked%(unlocked, GetLiveResourceOrbSettings%)") ~= nil,
    "Module: global element unlock updates all drag handles")
assertTrue(moduleSource:find("enableIndependentOrbOffset = CreateSettingContract%(") == nil,
    "Module: legacy independent orb offset no longer has a visible settings contract")
assertTrue(moduleSource:find("orbOffsetX = CreateSettingContract%(") == nil,
    "Module: legacy orbOffsetX no longer has a visible settings contract")
assertTrue(moduleSource:find("orbOffsetY = CreateSettingContract%(") == nil,
    "Module: legacy orbOffsetY no longer has a visible settings contract")

-- Test 9: UI controls expose one global unlock and remove the legacy orb sliders
assertTrue(moduleSource:find("SI_BETTERUI_RESOURCE_ORB_FRAMES_INDEPENDENT_ORB_OFFSET") ~= nil,
    "Module: global unlock checkbox reuses the legacy independent-orb string ID")
-- The legacy per-axis orb-offset slider source guards were retired together with
-- their now-unused lang keys (BUI-CLEAN-002); the global unlock checkbox assertion
-- above remains the current guard. Keeping the removed key literals out of the
-- test lets the host drop them from lang with zero references.

-- Test 10: Mouse drag positioning must write through live settings. The
-- remote interface.log showed delta_applied changed=true followed by drag
-- end offsetX/offsetY=0, which is the signature of mutating a detached
-- settings snapshot.
assertTrue(orchestratorSource:find("local GetLiveSettings = SettingsUtils%.GetLive or GetSettings") ~= nil,
    "Orchestrator: live settings getter is available")
assertTrue(orchestratorSource:find("drag%.AttachDragHandle%(hostControl, elemKey, GetLiveSettings, ApplyFullLayout%)") ~= nil,
    "Orchestrator: drag handles mutate live settings")
assertTrue(orchestratorSource:find("local settings = GetLiveSettings%(%) or {}") ~= nil,
    "Orchestrator: layout reads live element offsets after drag mutation")
assertTrue(orchestratorSource:find("resolveCustomFrontBarButton%(\"QuickslotButton\"%)") ~= nil,
    "Orchestrator: quickslot drag handle resolves only the custom quickslot control")
assertTrue(orchestratorSource:find("local quickslotButton = FindControl%(m_rootFrame, 'QuickslotButton'%)") == nil,
    "Orchestrator: quickslot drag handle does not fall through to the native global QuickslotButton")
assertTrue(orchestratorSource:find("custom_buttons_resolved") ~= nil,
    "Orchestrator: quickslot/companion drag host resolution emits builog trace")

-- Test 11: Drag-driven full layouts must also reassert native ESO action bar
-- suppression, otherwise the default bar can bleed into the custom bars when
-- movement/settings changes wake native UI controls.
assertTrue(orchestratorSource:find("local SuppressNativeBars") ~= nil,
    "Orchestrator: native bar suppression is forward declared for layout")
assertTrue(orchestratorSource:find("SuppressNativeBars%(\"ApplyFullLayout\"%)") ~= nil,
    "Orchestrator: full layout reasserts native bar suppression with trace source")
assertTrue(orchestratorSource:find("SuppressNativeBars%(\"weaponSwapLayout\"%)") ~= nil,
    "Orchestrator: weapon-swap partial layout reasserts native bar suppression")
assertTrue(orchestratorSource:find("SuppressNativeBars%(\"EVENT_ACTION_SLOTS_FULL_UPDATE\"%)") ~= nil,
    "Orchestrator: full action-slot update reasserts native bar suppression")
assertTrue(orchestratorSource:find("SuppressNativeBars%(\"EVENT_ACTION_SLOT_UPDATED\"%)") ~= nil,
    "Orchestrator: single action-slot update reasserts native bar suppression")

-- Test 12: Per-element Reset Position must use the live settings contract and
-- canonical Drag.ResetOffset path so offset persistence, handle state, and
-- builog reset/reset_end traces stay aligned.
assertTrue(moduleSource:find("GetLiveResourceOrbSettings = SettingsUtils%.GetLive or SettingsUtils%.Ensure") ~= nil,
    "Module: live ResourceOrbFrames settings getter exists")
assertTrue(moduleSource:find("getLiveSettings = GetLiveResourceOrbSettings") ~= nil,
    "Module: shared contracts expose live settings")
assertTrue(moduleSource:find("usesLiveSettings = true") ~= nil,
    "Module: element reset/lock traces record live-settings usage")
assertTrue(moduleSource:find("drag%.SetAllElementsUnlocked%(false, GetLiveResourceOrbSettings%)") ~= nil,
    "Module: reset-all locks all drag handles through the global live setting")
assertTrue(moduleSource:find("drag%.SetAllElementsUnlocked%(s%.elementPositionsUnlocked == true, GetLiveResourceOrbSettings%)") ~= nil,
    "Module: legacy lock toggle maps to the global live setting")

local settingsSubmenusSource2 = read_file("Modules/ResourceOrbFrames/Settings/SettingsSubmenus.lua")
assertTrue(settingsSubmenusSource2 ~= nil, "SettingsSubmenus.lua readable")
assertTrue(settingsSubmenusSource2:find("shared%.getLiveSettings") ~= nil,
    "SettingsSubmenus: ResetElemPos prefers the shared live settings getter")
assertTrue(settingsSubmenusSource2:find("drag%.ResetOffset%(k, liveGetter, nil%)") ~= nil,
    "SettingsSubmenus: ResetElemPos calls Drag.ResetOffset with the live settings getter")
assertTrue(settingsSubmenusSource2:find("local function AreElementPositionsUnlocked%(shared%)") ~= nil,
    "SettingsSubmenus: element sliders are gated by the global unlock")
assertTrue(settingsSubmenusSource2:find("getFunc = c%.locked%.get") == nil,
    "SettingsSubmenus: per-element lock checkboxes are no longer rendered")
assertTrue(settingsSubmenusSource2:find("usesLiveSettings = usesLiveSettings") ~= nil,
    "SettingsSubmenus: ResetElemPos trace records live-settings usage")
assertTrue(settingsSubmenusSource2:find("local s = shared and shared%.getSettings and shared%.getSettings%(%)") == nil,
    "SettingsSubmenus: ResetElemPos no longer mutates the detached shared.getSettings() snapshot")

local frontBarSource = read_file("Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua")
assertTrue(frontBarSource ~= nil, "FrontBarManager.lua readable")
assertTrue(frontBarSource:find("resource_orbs%.native_action_bar") ~= nil,
    "FrontBarManager: native action bar hide/restore emits builog traces")
assertTrue(frontBarSource:find("ZO_WeaponSwap_SetPermanentlyHidden%(ZO_ActionBar1WeaponSwap, true%)") ~= nil,
    "FrontBarManager: native weapon swap is permanently hidden with the native action bar")
assertTrue(frontBarSource:find("SetNativeActionBarButtonsHidden%(true%)") ~= nil,
    "FrontBarManager: suppression hides native action button controls, not only labels")
assertTrue(frontBarSource:find("ZO_ActionBar_GetButton%(nil, HOTBAR_CATEGORY_QUICKSLOT_WHEEL%)") ~= nil,
    "FrontBarManager: suppression resolves the native quickslot through ESOUI's quickslot category")
assertTrue(frontBarSource:find("nativeQuickslotHidden = nativeQuickslotHidden") ~= nil,
    "FrontBarManager: suppression trace reports native quickslot hiding")

local orbEventsSource = read_file("Modules/ResourceOrbFrames/Core/OrbEvents.lua")
assertTrue(orbEventsSource ~= nil, "OrbEvents.lua readable")
assertTrue(orbEventsSource:find("m_visibilitySceneCallbacksRegistered") ~= nil,
    "OrbEvents: visibility scene callback latch is separate")
assertTrue(orbEventsSource:find("m_hudSceneHandlersRegistered") ~= nil,
    "OrbEvents: HUD native suppression scene-handler latch is separate")
assertTrue(orbEventsSource:find("DeferredEnforceHide%(50%)") ~= nil,
    "OrbEvents: scene changes schedule native UI suppression reassertion")

print("test_orb_independent_positioning.lua: ALL TESTS PASSED")
