--[[
File: tools/tests/test_front_bar_helpers.lua
Purpose: Unit tests for exported helpers in ResourceOrbFrames/SkillBar/
         FrontBarCooldowns.lua using the actual module code.
         Tests run standalone with a Lua interpreter (no ESO environment).
]]

BETTERUI = {
    ResourceOrbFrames = {
        SkillBar = {
            CONST = {
                FRONT_BAR_SLOTS = {},
            },
            CooldownUtils = {},
        },
        Utils = {},
    },
}

local moduleSettings = {
    showQuickslotCount = true,
    quickslotTextSize = 27,
    quickslotTextColor = { 1, 1, 1, 1 },
}

function BETTERUI.ResourceOrbFrames.Utils.FindControl(parent, name)
    if not parent then return nil end
    if parent.GetNamedChild then
        local child = parent:GetNamedChild(name)
        if child then
            return child
        end
    end
    return parent.children and parent.children[name] or nil
end

function BETTERUI.ResourceOrbFrames.Utils.ClampTextSize(value, minValue, maxValue, fallback)
    if type(value) ~= "number" then
        return fallback
    end
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

function BETTERUI.ResourceOrbFrames.Utils.GetSettings()
    return moduleSettings
end

function BETTERUI.ResourceOrbFrames.Utils.GetFrontBarButtonControl()
    return nil
end

ACTION_TYPE_ITEM = 1
TEXT_ALIGN_CENTER = "CENTER"
TEXT_ALIGN_TOP = "TOP"
TOP = "TOP"
BOTTOM = "BOTTOM"
HOTBAR_CATEGORY_QUICKSLOT_WHEEL = 9
HOTBAR_CATEGORY_COMPANION = 10
ACTION_BAR_ULTIMATE_SLOT_INDEX = 7

local currentSlotType = ACTION_TYPE_ITEM
local currentSlotCount = 0

function GetSlotType()
    return currentSlotType
end

function GetSlotItemCount()
    return currentSlotCount
end

function GetCurrentQuickslot()
    return 9
end

dofile("Modules/ResourceOrbFrames/SkillBar/FrontBarCooldowns.lua")

local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar

local function NewLabel()
    return {
        hidden = nil,
        text = nil,
        font = nil,
        color = nil,
        anchor = nil,
        horizontalAlignment = nil,
        verticalAlignment = nil,
        ClearAnchors = function(self)
            self.anchor = nil
        end,
        SetAnchor = function(self, ...)
            self.anchor = { ... }
        end,
        SetHorizontalAlignment = function(self, value)
            self.horizontalAlignment = value
        end,
        SetVerticalAlignment = function(self, value)
            self.verticalAlignment = value
        end,
        SetFont = function(self, value)
            self.font = value
        end,
        SetColor = function(self, ...)
            self.color = { ... }
        end,
        SetText = function(self, value)
            self.text = value
        end,
        SetHidden = function(self, value)
            self.hidden = value
        end,
    }
end

local function NewControl(children)
    local control = {
        children = children or {},
        quickslotCount = nil,
        quickslotEmpty = nil,
    }

    function control:GetNamedChild(name)
        return self.children[name]
    end

    return control
end

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

print("[AnchorQuickslotCountText]")
do
    local label = NewLabel()
    local buttonText = {}
    local button = NewControl({
        CountText = label,
        ButtonText = buttonText,
    })

    SkillBar.AnchorQuickslotCountText(button, label)

    assert_eq(label.anchor[1], TOP, "count text anchor point uses TOP")
    assert_eq(label.anchor[2], buttonText, "count text anchors to button text when present")
    assert_eq(label.anchor[3], BOTTOM, "count text uses button text bottom anchor")
    assert_eq(label.anchor[4], 0, "default keybind offset X")
    assert_eq(label.anchor[5], -2, "default keybind offset Y")
    assert_eq(label.horizontalAlignment, TEXT_ALIGN_CENTER, "count text horizontal alignment")
    assert_eq(label.verticalAlignment, TEXT_ALIGN_TOP, "count text vertical alignment")

    BETTERUI_QUICKSLOT_COUNT_TEXT_BUTTON_OFFSET_X = 4
    BETTERUI_QUICKSLOT_COUNT_TEXT_BUTTON_OFFSET_Y = 6

    local fallbackLabel = NewLabel()
    local fallbackButton = NewControl({
        CountText = fallbackLabel,
    })

    SkillBar.AnchorQuickslotCountText(fallbackButton, fallbackLabel)

    assert_eq(fallbackLabel.anchor[2], fallbackButton, "fallback anchors to button when button text missing")
    assert_eq(fallbackLabel.anchor[4], 4, "fallback button offset X")
    assert_eq(fallbackLabel.anchor[5], 6, "fallback button offset Y")

    BETTERUI_QUICKSLOT_COUNT_TEXT_BUTTON_OFFSET_X = nil
    BETTERUI_QUICKSLOT_COUNT_TEXT_BUTTON_OFFSET_Y = nil
end

print("[UpdateQuickslotCountAndEmptyState]")
do
    local countText = NewLabel()
    local overlay = {
        hidden = nil,
        SetHidden = function(self, value)
            self.hidden = value
        end,
    }

    local button = NewControl({
        CountText = countText,
        UnusableOverlay = overlay,
    })

    moduleSettings.showQuickslotCount = true
    moduleSettings.quickslotTextSize = 99
    moduleSettings.quickslotTextColor = { 0.2, 0.4, 0.6, 0.8 }
    currentSlotType = ACTION_TYPE_ITEM
    currentSlotCount = 5

    local isEmpty = SkillBar.UpdateQuickslotCountAndEmptyState(button, nil, moduleSettings, 9, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    assert_eq(isEmpty, false, "filled quickslot reports non-empty")
    assert_eq(countText.text, 5, "filled quickslot count text")
    assert_eq(countText.hidden, false, "filled quickslot shows count")
    assert_eq(countText.font, "$(BOLD_FONT)|30|thick-outline", "quickslot text size is clamped to max")
    assert_eq(countText.color[1], 0.2, "quickslot text color red channel")
    assert_eq(overlay.hidden, true, "filled quickslot hides unusable overlay")
    assert_eq(button.quickslotCount, 5, "button caches quickslot count")
    assert_eq(button.quickslotEmpty, false, "button caches non-empty state")

    currentSlotCount = 0
    isEmpty = SkillBar.UpdateQuickslotCountAndEmptyState(button, nil, moduleSettings, 9, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    assert_eq(isEmpty, true, "empty quickslot reports empty")
    assert_eq(countText.text, 0, "empty quickslot still renders stack count text")
    assert_eq(countText.hidden, false, "empty quickslot still shows count when enabled")
    assert_eq(overlay.hidden, false, "empty quickslot shows unusable overlay")
    assert_eq(button.quickslotEmpty, true, "button caches empty state")

    moduleSettings.showQuickslotCount = false
    currentSlotType = 99
    currentSlotCount = 7
    isEmpty = SkillBar.UpdateQuickslotCountAndEmptyState(button, nil, moduleSettings, 9, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
    assert_eq(isEmpty, false, "non-item slot is not treated as empty quickslot")
    assert_eq(countText.hidden, true, "non-item slot hides count text")
    assert_eq(overlay.hidden, true, "non-item slot hides unusable overlay")
    assert_eq(button.quickslotCount, nil, "non-item slot clears quickslot count cache")
    assert_eq(button.quickslotEmpty, false, "non-item slot caches non-empty state")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
