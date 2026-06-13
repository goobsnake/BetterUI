--[[
File: tools/tests/test_orb_latch.lua
Purpose: Behavioral regression coverage for the per-frame latching added to
         ResourceOrbFrames bar/orb refresh code, driving the REAL module code
         (OrbBars.lua + OrbBarUpdates.lua + OrbVisuals.lua) under minimal stubs.

         FIX 1: ExperienceBar:Update latches static style + label text + value;
                a second identical-value frame must NOT re-apply font / SetText /
                UpdateVisuals, while a changed-value frame must.
         FIX 2: BetterUIOrbBar:RefreshLabel caches the bucketed string and only
                calls SetText when it differs.

Usage:
  lua tools/tests/test_orb_latch.lua
]]

-- ============================================================================
-- TEST HARNESS
-- ============================================================================

local passed, failed = 0, 0

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

-- ============================================================================
-- MINIMAL ESO ENVIRONMENT STUBS
-- ============================================================================

-- Instrumented control: every method is a recording no-op. Each control tracks
-- per-method call counts and the last text it received.
local function NewControl(name)
    local c = { _name = name, _calls = {}, _hidden = false, _text = nil }
    local function bump(method) c._calls[method] = (c._calls[method] or 0) + 1 end
    function c:SetTexture() bump("SetTexture") end
    function c:SetTextureCoords() bump("SetTextureCoords") end
    function c:SetAnchor() bump("SetAnchor") end
    function c:ClearAnchors() bump("ClearAnchors") end
    function c:SetDimensions() bump("SetDimensions") end
    function c:SetScale() bump("SetScale") end
    function c:SetFont() bump("SetFont") end
    function c:SetColor() bump("SetColor") end
    function c:SetGradientColors() bump("SetGradientColors") end
    function c:SetHorizontalAlignment() bump("SetHorizontalAlignment") end
    function c:SetVerticalAlignment() bump("SetVerticalAlignment") end
    function c:SetHandler() bump("SetHandler") end
    function c:SetHidden(v) bump("SetHidden"); self._hidden = v end
    function c:IsHidden() return self._hidden end
    function c:SetText(t) bump("SetText"); self._text = t end
    function c:GetNamedChild(child) return self["_child_" .. child] end
    function c:calls(method) return self._calls[method] or 0 end
    return c
end

-- ZO_Object minimal class system (Subclass / New).
ZO_Object = {}
function ZO_Object:Subclass()
    local sub = setmetatable({}, { __index = self })
    sub.__index = sub
    return sub
end
function ZO_Object.New(class)
    return setmetatable({}, { __index = class })
end

WINDOW_MANAGER = {
    CreateControl = function(_, name)
        return NewControl(name)
    end,
}

CT_CONTROL, CT_TEXTURE, CT_LABEL = 1, 2, 3
CENTER, LEFT, RIGHT, TOPLEFT = "CENTER", "LEFT", "RIGHT", "TOPLEFT"
TEXT_ALIGN_CENTER = 1
ORIENTATION_VERTICAL = 1
POWERTYPE_HEALTH, POWERTYPE_MAGICKA, POWERTYPE_STAMINA = 1, 2, 4
ATTRIBUTE_VISUAL_POWER_SHIELDING = 99
COMBAT_MECHANIC_FLAGS_HEALTH = 1
COMBAT_MECHANIC_FLAGS_MAGICKA = 2
COMBAT_MECHANIC_FLAGS_STAMINA = 4
COMBAT_MECHANIC_FLAGS_ULTIMATE = 8
COMBAT_MECHANIC_FLAGS_MOUNT_STAMINA = 16

function GetFrameTimeSeconds() return 0 end
function GetFrameTimeMilliseconds() return 0 end
function GetString(id) return "STR_" .. tostring(id) end
function zo_roundToNearest(v) return v end
function zo_max(a, b) if a > b then return a end return b end

-- Champion / XP API. Driven by mutable module-level values so tests can flip
-- between champion and non-champion and between identical / changed values.
local g_isChampion = false
local g_xp = 0
local g_xpMax = 0
function IsUnitChampion() return g_isChampion end
function GetUnitXP() return g_xp end
function GetUnitXPMax() return g_xpMax end
function GetPlayerChampionPointsEarned() return 10 end
function GetPlayerChampionXP() return 0 end
function GetNumChampionXPInChampionPoint() return 400000 end
function IsMounted() return false end
function GetUnitPower() return 0, 1 end

-- ============================================================================
-- BETTERUI NAMESPACE + MODULE SETTINGS
-- ============================================================================

local g_settings = {
    xpBarEnabled = true,
    xpBarTextSize = 16,
    xpBarTextColor = { 1, 1, 1, 1 },
    castBarEnabled = false,
    mountStaminaBarEnabled = false,
}

BETTERUI = {
    ResourceOrbFrames = {
        CONST = {
            BARS = {
                FILL_TEXTURE = "fill.dds",
                XP = { WIDTH = 250, HEIGHT = 150, SCALE = 1.0, FILL_INSET_X = 8, FILL_INSET_Y = 4,
                    LABEL_OFFSET_X = 0, LABEL_OFFSET_Y = 0, BACKDROP_TEXTURE = "Bar.dds" },
                CAST = { WIDTH = 250, HEIGHT = 150 },
                MOUNT = { WIDTH = 250, HEIGHT = 150 },
            },
        },
        Utils = {},
        Animations = {},
    },
    ControlUtils = {
        FindControl = function(parent, name)
            if parent and parent.GetNamedChild then return parent:GetNamedChild(name) end
            return nil
        end,
    },
    CIM = {
        SafeExecute = function(_, fn, ...) return pcall(fn, ...) end,
    },
    CloneColor = function(c)
        if type(c) ~= "table" then return c end
        return { c[1], c[2], c[3], c[4] }
    end,
}
BETTERUI.ControlUtils.InvalidateControlCache = function() end

local Utils = BETTERUI.ResourceOrbFrames.Utils
Utils.Settings = {
    GetLive = function() return g_settings end,
    Get = function() return g_settings end,
}
Utils.GetSettings = Utils.Settings.Get
function Utils.ClampTextSize(value, minValue, maxValue, fallback)
    local n = tonumber(value) or fallback
    if n < minValue then n = minValue end
    if n > maxValue then n = maxValue end
    return n
end

-- ============================================================================
-- LOAD REAL MODULE CODE
-- ============================================================================

dofile("Modules/ResourceOrbFrames/Core/OrbBars.lua")
dofile("Modules/ResourceOrbFrames/Core/OrbBarUpdates.lua")
dofile("Modules/ResourceOrbFrames/Core/OrbVisuals.lua")

local Bars = BETTERUI.ResourceOrbFrames.Bars

print("[ResourceOrbFrames Latch]")

-- ============================================================================
-- FIX 1: ExperienceBar:Update latches style + text + value
-- ============================================================================

local parent = NewControl("Parent")
local xpBar = Bars.CreateExperienceBar(parent)
local label = xpBar.label

g_isChampion = false
g_xp = 500
g_xpMax = 1000

-- First update: applies everything (fresh latch).
xpBar:Update()
local font1 = label:calls("SetFont")
local text1 = label:calls("SetText")
assert_true(font1 >= 1, "first XP update applies font")
assert_true(text1 >= 1, "first XP update sets label text")
assert_eq(label._text, "XP: 500 / 1000", "first XP update renders the XP label")

-- Second update with the SAME values: must NOT re-apply font or SetText.
xpBar:Update()
assert_eq(label:calls("SetFont"), font1, "identical XP update does NOT re-apply font (style latched)")
assert_eq(label:calls("SetText"), text1, "identical XP update does NOT re-call SetText (text latched)")

-- Third update with CHANGED xp value: must re-render the label text.
g_xp = 750
xpBar:Update()
assert_eq(label:calls("SetText"), text1 + 1, "changed XP value re-calls SetText once")
assert_eq(label._text, "XP: 750 / 1000", "changed XP value renders new label text")
-- Style (font) is unchanged because text size/color did not change.
assert_eq(label:calls("SetFont"), font1, "changed XP value does NOT re-apply font (style still latched)")

-- Changing the text size flips the style latch -> font re-applies.
g_settings.xpBarTextSize = 18
xpBar:Update()
assert_eq(label:calls("SetFont"), font1 + 1, "changed text size re-applies font (style latch reset)")

-- ============================================================================
-- FIX 3: nil XP API returns are coerced to numbers (no %d-on-nil error)
-- ============================================================================

local nilParent = NewControl("NilParent")
local nilBar = Bars.CreateExperienceBar(nilParent)
g_xp = nil
g_xpMax = nil
local okNil = pcall(function() nilBar:Update() end)
assert_true(okNil, "XP update survives nil GetUnitXP/GetUnitXPMax returns")
assert_eq(nilBar.label._text, "XP: 0 / 0", "nil XP API returns coerce to 0")

-- ============================================================================
-- FIX 2: BetterUIOrbBar:RefreshLabel caches the bucketed string
-- ============================================================================

local orbControl = NewControl("OrbControl")
local orbLabel = NewControl("OrbLabel")
orbControl._child_Fog = NewControl("Fog")
orbControl._child_Fog2 = NewControl("Fog2")
orbControl._child_Label = orbLabel

local orb = BetterUIOrbBar:New(orbControl, POWERTYPE_HEALTH)

-- Two values that bucket to the SAME string ("20k"): SetText once.
orb.currentValue = 20000
orb:RefreshLabel()
local orbText1 = orbLabel:calls("SetText")
assert_eq(orbText1, 1, "first RefreshLabel sets the bucketed label")
assert_eq(orbLabel._text, "20k", "20000 buckets to 20k")

orb.currentValue = 20400 -- still rounds to "20k"
orb:RefreshLabel()
assert_eq(orbLabel:calls("SetText"), orbText1, "same-bucket RefreshLabel does NOT re-call SetText")

-- A value that buckets differently re-renders.
orb.currentValue = 21000 -- "21k"
orb:RefreshLabel()
assert_eq(orbLabel:calls("SetText"), orbText1 + 1, "different-bucket RefreshLabel re-calls SetText")
assert_eq(orbLabel._text, "21k", "21000 buckets to 21k")

-- ============================================================================
-- RESULTS
-- ============================================================================

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
