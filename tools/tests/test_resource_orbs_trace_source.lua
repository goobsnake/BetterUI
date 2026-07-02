--[[
File: tools/tests/test_resource_orbs_trace_source.lua
Purpose: Source contract for BUI-TRACE-003 Phase 3 combat/HUD trace parity.

Usage:
  lua tools/tests/test_resource_orbs_trace_source.lua
]]

local function readFile(path)
    local handle = io.open(path, "r")
    if not handle then return "" end
    local content = handle:read("*a") or ""
    handle:close()
    return content
end

local function containsAfter(haystack, anchor, needle)
    local anchorIndex = haystack:find(anchor, 1, true)
    return anchorIndex ~= nil and haystack:find(needle, anchorIndex, true) ~= nil
end

local function between(haystack, startNeedle, endNeedle)
    local startIndex = haystack:find(startNeedle, 1, true)
    if not startIndex then return "" end
    local contentStart = startIndex + #startNeedle
    local endIndex = haystack:find(endNeedle, contentStart, true)
    if not endIndex then return haystack:sub(contentStart) end
    return haystack:sub(contentStart, endIndex - 1)
end

local passed, failed = 0, 0
local function check(cond, msg)
    if cond then passed = passed + 1; print("  [OK] " .. msg)
    else failed = failed + 1; print("  [X] " .. msg) end
end

print("\n=== Resource Orbs / HUD trace source contract ===\n")

local ultimate = readFile("Modules/ResourceOrbFrames/SkillBar/UltimateManager.lua")
local coordinator = readFile("Modules/ResourceOrbFrames/SkillBar/Coordinator.lua")
local orbBarUpdates = readFile("Modules/ResourceOrbFrames/Core/OrbBarUpdates.lua")
local orbEvents = readFile("Modules/ResourceOrbFrames/Core/OrbEvents.lua")
local resourceOrbs = readFile("Modules/ResourceOrbFrames/ResourceOrbFrames.lua")
local nameplates = readFile("Modules/Nameplates/Nameplates.lua")
local generalSetup = readFile("Modules/GeneralInterface/Setup.lua")
local ultimateChangedKeyBlock = between(ultimate, "local stateKey = table.concat({", "}, \":\")")

check(ultimate:find('"resource_orbs.ultimate", "changed"', 1, true) ~= nil
    and ultimate:find("_betteruiUltimateChangedKey", 1, true) ~= nil
    and ultimate:find("frameIndex = frameIndex", 1, true) ~= nil
    and ultimate:find("ready = ready == true", 1, true) ~= nil
    and ultimate:find("local function ShouldTraceUltimate()", 1, true) ~= nil
    and containsAfter(ultimate, "if not ShouldTraceUltimate() then return end", "local stateKey = table.concat")
    and ultimateChangedKeyBlock:find("tostring(abilityCost)", 1, true) ~= nil
    and ultimateChangedKeyBlock:find("tostring(frameIndex)", 1, true) ~= nil
    and ultimateChangedKeyBlock:find("tostring(ready == true)", 1, true) ~= nil
    and ultimateChangedKeyBlock:find("tostring(reason)", 1, true) ~= nil
    and ultimateChangedKeyBlock:find("currentUltimate", 1, true) == nil,
    "ultimate meter emits transition-only resource_orbs.ultimate changed records")

check(coordinator:find('"resource_orbs.bar_swap", "changed"', 1, true) ~= nil
    and coordinator:find("m_lastActiveWeaponPair", 1, true) ~= nil
    and coordinator:find("if oldPair == newPair then return end", 1, true) ~= nil
    and coordinator:find("if oldPair == nil or oldPair == newPair then return end", 1, true) == nil
    and coordinator:find("oldBar = DescribeWeaponPair(oldPair)", 1, true) ~= nil
    and coordinator:find("newBar = DescribeWeaponPair(newPair)", 1, true) ~= nil,
    "skill bar swap emits changed records with old/new bar labels")

check(orbBarUpdates:find('"resource_orbs.cast", "begin"', 1, true) ~= nil
    and orbBarUpdates:find('"resource_orbs.cast", "end"', 1, true) ~= nil
    and containsAfter(orbBarUpdates, "self.isCasting = true", '"resource_orbs.cast", "begin"')
    and containsAfter(orbBarUpdates, "self.isCasting = false", '"resource_orbs.cast", "end"'),
    "cast bar emits begin/end records on casting transitions")

check(orbEvents:find('"resource_orbs.combat", "changed"', 1, true) ~= nil
    and orbEvents:find("m_lastCombatState", 1, true) ~= nil
    and orbEvents:find("if m_lastCombatState == combat then return end", 1, true) ~= nil,
    "combat indicator events emit coalesced combat changed records")

check(resourceOrbs:find("bar=%s", 1, true) ~= nil
    and resourceOrbs:find("ultReady=%s", 1, true) ~= nil
    and resourceOrbs:find("DescribeActiveWeaponBar()", 1, true) ~= nil
    and resourceOrbs:find("IsUltimateReady()", 1, true) ~= nil,
    "resourceOrbs snapshot carries combat, active bar, and ultimate-ready state")

check(nameplates:find('"nameplates.visibility", "changed"', 1, true) ~= nil
    and nameplates:find("lastNameplatesVisible", 1, true) ~= nil
    and nameplates:find('"nameplates.refresh", "end"', 1, true) ~= nil
    and nameplates:find("activeRules=%s", 1, true) ~= nil
    and nameplates:find("CountActiveNameplateRules(settings)", 1, true) ~= nil,
    "nameplates expose visibility decisions, refresh counts, and snapshot rule counts")

check(nameplates:find("if not (settings and settings.m_enabled == true) then return 0 end", 1, true) ~= nil,
    "nameplates disabled snapshots report zero active rules")

check(generalSetup:find('"general_interface.mail_delete", "requested"', 1, true) ~= nil
    and generalSetup:find('"general_interface.mail_delete", "confirmed"', 1, true) ~= nil
    and generalSetup:find('"general_interface.mail_delete", "skipped"', 1, true) ~= nil
    and generalSetup:find("selectedMail = selectedMail", 1, true) ~= nil,
    "GeneralInterface mail delete lifecycle emits requested/confirmed/skipped with mail identity")

check(generalSetup:find("payload._inputAnchorDetail == true", 1, true) ~= nil
    and generalSetup:find("_inputAnchorDetail = true", 1, true) ~= nil
    and generalSetup:find('payload.fn == "mailDeleteDescriptor.callback"', 1, true) == nil,
    "GeneralInterface mail delete strips anchor fields only for explicit keybind detail records")

check(generalSetup:find('"general_interface.chat_history", "requested"', 1, true) ~= nil
    and generalSetup:find('"general_interface.chat_history", "confirmed"', 1, true) ~= nil
    and generalSetup:find('"general_interface.chat_history", "applied"', 1, true) ~= nil
    and containsAfter(generalSetup, '"general_interface.chat_history", "requested"', "buffer:SetMaxHistoryLines(numLines)")
    and containsAfter(generalSetup, "buffer:SetMaxHistoryLines(numLines)", '"general_interface.chat_history", "confirmed"'),
    "GeneralInterface chat history emits requested/confirmed around buffer mutations")

print(string.format("\nResource-orbs trace tests: %d passed, %d failed\n", passed, failed))
if failed > 0 then os.exit(1) end
