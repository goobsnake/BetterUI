--[[
File: tools/tests/test_front_bar_helpers.lua
Purpose: Unit tests for pure functions in ResourceOrbFrames/SkillBar/
         FrontBarPressFeedback.lua and FrontBarCooldowns.lua.
         Tests run standalone with a Lua interpreter (no ESO environment).
]]

-- ============================================================================
-- MINIMAL ESO STUBS
-- ============================================================================

BETTERUI = { ResourceOrbFrames = { SkillBar = {}, Utils = {} } }

HOTBAR_CATEGORY_QUICKSLOT_WHEEL = 9
HOTBAR_CATEGORY_COMPANION = 10
ACTION_BAR_ULTIMATE_SLOT_INDEX = 7

function GetCurrentQuickslot() return 9 end

-- ============================================================================
-- EXTRACT PURE FUNCTIONS UNDER TEST
-- ============================================================================

-- From FrontBarPressFeedback.lua
local function ResolvePressFeedbackButtonName(slotIndex, hotbarCategory)
    if hotbarCategory == HOTBAR_CATEGORY_QUICKSLOT_WHEEL then
        return "QuickslotButton"
    end
    if hotbarCategory == HOTBAR_CATEGORY_COMPANION then
        return "CompanionButton"
    end
    local ultimateSlot = ACTION_BAR_ULTIMATE_SLOT_INDEX and (ACTION_BAR_ULTIMATE_SLOT_INDEX + 1) or 8
    if slotIndex == ultimateSlot then
        return "UltimateButton"
    end
    local numericSlot = tonumber(slotIndex)
    if numericSlot and numericSlot >= 3 and numericSlot <= 7 then
        return "Button" .. tostring(numericSlot - 2)
    end
    if numericSlot and numericSlot == GetCurrentQuickslot() then
        return "QuickslotButton"
    end
    return nil
end

-- From FrontBarCooldowns.lua
local function GetQuickslotCountAnchorOffsets()
    local keybindOffsetX = BETTERUI_QUICKSLOT_COUNT_TEXT_KEYBIND_OFFSET_X or 0
    local keybindOffsetY = BETTERUI_QUICKSLOT_COUNT_TEXT_KEYBIND_OFFSET_Y or -2
    local buttonOffsetX = BETTERUI_QUICKSLOT_COUNT_TEXT_BUTTON_OFFSET_X or 0
    local buttonOffsetY = BETTERUI_QUICKSLOT_COUNT_TEXT_BUTTON_OFFSET_Y or 1
    return keybindOffsetX, keybindOffsetY, buttonOffsetX, buttonOffsetY
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

local function assert_nil(value, label)
    if value == nil then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s — expected nil, got %s", label, tostring(value)))
    end
end

-- ============================================================================
-- TESTS: ResolvePressFeedbackButtonName
-- ============================================================================

print("[ResolvePressFeedbackButtonName]")
assert_eq(ResolvePressFeedbackButtonName(3, HOTBAR_CATEGORY_QUICKSLOT_WHEEL), "QuickslotButton", "quickslot wheel → QuickslotButton")
assert_eq(ResolvePressFeedbackButtonName(3, HOTBAR_CATEGORY_COMPANION), "CompanionButton", "companion → CompanionButton")
assert_eq(ResolvePressFeedbackButtonName(8, 1), "UltimateButton", "ultimate slot → UltimateButton")
assert_eq(ResolvePressFeedbackButtonName(3, 1), "Button1", "slot 3 → Button1")
assert_eq(ResolvePressFeedbackButtonName(4, 1), "Button2", "slot 4 → Button2")
assert_eq(ResolvePressFeedbackButtonName(5, 1), "Button3", "slot 5 → Button3")
assert_eq(ResolvePressFeedbackButtonName(6, 1), "Button4", "slot 6 → Button4")
assert_eq(ResolvePressFeedbackButtonName(7, 1), "Button5", "slot 7 → Button5")
assert_eq(ResolvePressFeedbackButtonName(9, 1), "QuickslotButton", "current quickslot → QuickslotButton")
assert_nil(ResolvePressFeedbackButtonName(1, 1), "slot 1 → nil")
assert_nil(ResolvePressFeedbackButtonName(2, 1), "slot 2 → nil")
assert_nil(ResolvePressFeedbackButtonName(nil, 1), "nil slot → nil")

-- ============================================================================
-- TESTS: GetQuickslotCountAnchorOffsets
-- ============================================================================

print("[GetQuickslotCountAnchorOffsets]")
do
    -- Without globals set, should use defaults
    local kx, ky, bx, by = GetQuickslotCountAnchorOffsets()
    assert_eq(kx, 0, "default keybindOffsetX")
    assert_eq(ky, -2, "default keybindOffsetY")
    assert_eq(bx, 0, "default buttonOffsetX")
    assert_eq(by, 1, "default buttonOffsetY")

    -- With globals set
    BETTERUI_QUICKSLOT_COUNT_TEXT_KEYBIND_OFFSET_X = 5
    BETTERUI_QUICKSLOT_COUNT_TEXT_KEYBIND_OFFSET_Y = -10
    BETTERUI_QUICKSLOT_COUNT_TEXT_BUTTON_OFFSET_X = 3
    BETTERUI_QUICKSLOT_COUNT_TEXT_BUTTON_OFFSET_Y = 7
    kx, ky, bx, by = GetQuickslotCountAnchorOffsets()
    assert_eq(kx, 5, "custom keybindOffsetX")
    assert_eq(ky, -10, "custom keybindOffsetY")
    assert_eq(bx, 3, "custom buttonOffsetX")
    assert_eq(by, 7, "custom buttonOffsetY")

    -- Reset globals
    BETTERUI_QUICKSLOT_COUNT_TEXT_KEYBIND_OFFSET_X = nil
    BETTERUI_QUICKSLOT_COUNT_TEXT_KEYBIND_OFFSET_Y = nil
    BETTERUI_QUICKSLOT_COUNT_TEXT_BUTTON_OFFSET_X = nil
    BETTERUI_QUICKSLOT_COUNT_TEXT_BUTTON_OFFSET_Y = nil
end

-- ============================================================================
-- RESULTS
-- ============================================================================

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
