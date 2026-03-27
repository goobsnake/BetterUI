--[[
File: Modules/CIM/Lists/VerticalScrollList.lua
Purpose: Vertical Parametric Scroll List implementation.
         Extends ZO_ParametricScrollList with custom gradient fading.
Author: BetterUI Team
Last Modified: 2026-01-26
]]

-- ─── Constants ───────────────────────────────────────────────────────────────
local DEFAULT_EXPECTED_ENTRY_HEIGHT = 30
local DEFAULT_EXPECTED_HEADER_HEIGHT = 24
local MINIMUM_ALLOWED_FADE_GRADIENT = 32

-- ─── Private Helpers ────────────────────────────────────────────────────────

--- Gets the relevant dimension (Height/Width) based on list orientation.
---
--- @param mode boolean Vertical (true) or Horizontal (false).
--- @param control table The control to check.
--- @return number The dimension size.
local function GetControlDimensionForMode(mode, control)
    return mode == PARAMETRIC_SCROLL_LIST_VERTICAL and control:GetHeight() or control:GetWidth()
end

--- Gets the starting edge (Top/Left) based on list orientation.
---
--- @param mode boolean Vertical (true) or Horizontal (false).
--- @param control table The control to check.
--- @return number The start coordinate.
local function GetStartOfControl(mode, control)
    return mode == PARAMETRIC_SCROLL_LIST_VERTICAL and control:GetTop() or control:GetLeft()
end

--- Gets the ending edge (Bottom/Right) based on list orientation.
---
--- @param mode boolean Vertical (true) or Horizontal (false).
--- @param control table The control to check.
--- @return number The end coordinate.
local function GetEndOfControl(mode, control)
    return mode == PARAMETRIC_SCROLL_LIST_VERTICAL and control:GetBottom() or control:GetRight()
end

-- ============================================================================
-- CLASS: BETTERUI_VerticalParametricScrollList
-- Customized Vertical Scroll List with enhanced Gradient Fading logic.
-- ============================================================================
BETTERUI_VerticalParametricScrollList = ZO_ParametricScrollList:Subclass()

--- Creates a new vertical parametric scroll list instance.
---
--- Purpose: Overrides EnsureValidGradient to apply specific top/bottom fades.
--- Mechanics:
--- - Dynamically calculates gradient sizes based on list content and alignment.
--- - Ensures clean fades at the edges of the scroll area.
---
--- @param ... any Arguments passed to ZO_ParametricScrollList:New.
--- @return BetterUIVerticalParametricScrollList The new list instance.
function BETTERUI_VerticalParametricScrollList:New(...)
    local list = ZO_ParametricScrollList.New(self, ...)

    -- Override EnsureValidGradient to provide custom fade behavior
    list.EnsureValidGradient = function(scrollList)
        if scrollList.validateGradient and scrollList.validGradientDirty then
            -- Cache key based on inputs
            local listHeight = scrollList.scrollControl:GetHeight()
            local centerOffset = scrollList.fixedCenterOffset

            -- Optimization: Skip recalculation if dimensions haven't changed
            if scrollList._gradientCacheHeight == listHeight and scrollList._gradientCacheOffset == centerOffset then
                scrollList.validGradientDirty = false
                return
            end

            if scrollList.mode == PARAMETRIC_SCROLL_LIST_VERTICAL then
                local listStart = GetStartOfControl(scrollList.mode, scrollList.scrollControl)
                local listEnd = GetEndOfControl(scrollList.mode, scrollList.scrollControl)
                local listMid = listStart + (GetControlDimensionForMode(scrollList.mode, scrollList.scrollControl) / 2.0)

                if scrollList.alignToScreenCenter and scrollList.alignToScreenCenterAnchor then
                    listMid = GetStartOfControl(scrollList.mode, scrollList.alignToScreenCenterAnchor)
                end
                listMid = listMid + scrollList.fixedCenterOffset

                local hasHeaders = false
                for templateName, dataTypeInfo in pairs(self.dataTypes) do
                    if dataTypeInfo.hasHeader then
                        hasHeaders = true
                        break
                    end
                end

                local selectedControlBufferStart = 0
                if hasHeaders then
                    selectedControlBufferStart = selectedControlBufferStart - self.headerSelectedPadding +
                    DEFAULT_EXPECTED_HEADER_HEIGHT
                end
                local selectedControlBufferEnd = DEFAULT_EXPECTED_ENTRY_HEIGHT
                if self.alignToScreenCenterExpectedEntryHalfHeight then
                    selectedControlBufferEnd = self.alignToScreenCenterExpectedEntryHalfHeight * 2.0
                end

                -- Calculate fading gradients
                local gradientMaxStart = zo_max(listMid - listStart - selectedControlBufferStart,
                    MINIMUM_ALLOWED_FADE_GRADIENT)
                local gradientMaxEnd = zo_max(listEnd - listMid - selectedControlBufferEnd, MINIMUM_ALLOWED_FADE_GRADIENT)
                local gradientStartSize = zo_min(gradientMaxStart,
                    BETTERUI_VERTICAL_PARAMETRIC_LIST_DEFAULT_FADE_GRADIENT_SIZE)
                local gradientEndSize = zo_min(gradientMaxEnd,
                    BETTERUI_VERTICAL_PARAMETRIC_LIST_DEFAULT_FADE_GRADIENT_SIZE)

                local FIRST_FADE_GRADIENT = 1
                local SECOND_FADE_GRADIENT = 2
                local GRADIENT_TEX_CORD_0 = 0
                local GRADIENT_TEX_CORD_1 = 1
                local GRADIENT_TEX_CORD_NEG_1 = -1

                self.scrollControl:SetFadeGradient(FIRST_FADE_GRADIENT, GRADIENT_TEX_CORD_0, GRADIENT_TEX_CORD_1,
                    gradientStartSize)
                self.scrollControl:SetFadeGradient(SECOND_FADE_GRADIENT, GRADIENT_TEX_CORD_0, GRADIENT_TEX_CORD_NEG_1,
                    gradientEndSize)

                -- Update cache
                self._gradientCacheHeight = listHeight
                self._gradientCacheOffset = centerOffset
            end
            self.validGradientDirty = false
        end
    end
    return list
end

--- Initializes the list with default padding and sound.
---
--- @param control table The list control.
function BETTERUI_VerticalParametricScrollList:Initialize(control)
    ZO_ParametricScrollList.Initialize(self, control, PARAMETRIC_SCROLL_LIST_VERTICAL,
        ZO_GamepadOnDefaultScrollListActivatedChanged)
    self:SetHeaderPadding(GAMEPAD_HEADER_DEFAULT_PADDING, GAMEPAD_HEADER_SELECTED_PADDING)
    self:SetUniversalPostPadding(GAMEPAD_DEFAULT_POST_PADDING)
    self:SetPlaySoundFunction(BETTERUI.GamepadParametricScrollListPlaySound)

    self.alignToScreenCenterExpectedEntryHalfHeight = 30
end

--[[
Class: BETTERUI_VerticalItemParametricScrollList
Subclass specifically for Item Lists (Inventory rows).
]]
BETTERUI_VerticalItemParametricScrollList = BETTERUI_VerticalParametricScrollList:Subclass()

--- Constructor for item list.
---
--- @param control table The list control.
--- @return BetterUIVerticalItemParametricScrollList The new list instance.
function BETTERUI_VerticalItemParametricScrollList:New(control)
    local list = BETTERUI_VerticalParametricScrollList.New(self, control)
    list:SetUniversalPostPadding(GAMEPAD_DEFAULT_POST_PADDING)
    return list
end
