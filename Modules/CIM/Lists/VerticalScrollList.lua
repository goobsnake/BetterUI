--[[
File: Modules/CIM/Lists/VerticalScrollList.lua
Purpose: Vertical Parametric Scroll List implementation.
         Extends ZO_ParametricScrollList with custom gradient fading.
]]

local DEFAULT_EXPECTED_ENTRY_HEIGHT = 30
local DEFAULT_EXPECTED_HEADER_HEIGHT = 24
local MINIMUM_ALLOWED_FADE_GRADIENT = 32
local LIST_ORIENTATION = (BETTERUI.CIM and BETTERUI.CIM.ListGlobals and BETTERUI.CIM.ListGlobals.ORIENTATION) or
{
    VERTICAL = true,
    HORIZONTAL = false,
}
local DEFAULT_GRADIENT_SIZE = (BETTERUI.CIM and BETTERUI.CIM.ListGlobals and BETTERUI.CIM.ListGlobals.DEFAULT_GRADIENT_SIZE) or
{
    VERTICAL = 32,
    HORIZONTAL = 32,
}


--- Gets the relevant dimension (Height/Width) based on list orientation.
---
local function GetControlDimensionForMode(mode, control)
    return mode == LIST_ORIENTATION.VERTICAL and control:GetHeight() or control:GetWidth()
end

--- Gets the starting edge (Top/Left) based on list orientation.
---
local function GetStartOfControl(mode, control)
    return mode == LIST_ORIENTATION.VERTICAL and control:GetTop() or control:GetLeft()
end

--- Gets the ending edge (Bottom/Right) based on list orientation.
---
local function GetEndOfControl(mode, control)
    return mode == LIST_ORIENTATION.VERTICAL and control:GetBottom() or control:GetRight()
end

-- CLASS: BETTERUI_VerticalParametricScrollList
-- Customized Vertical Scroll List with enhanced Gradient Fading logic.
BETTERUI_VerticalParametricScrollList = ZO_ParametricScrollList:Subclass()

--- Creates a new vertical parametric scroll list instance.
---
--- Purpose: Overrides EnsureValidGradient to apply specific top/bottom fades.
--- Mechanics:
--- - Dynamically calculates gradient sizes based on list content and alignment.
--- - Ensures clean fades at the edges of the scroll area.
---
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

            if scrollList.mode == LIST_ORIENTATION.VERTICAL then
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
                    DEFAULT_GRADIENT_SIZE.VERTICAL)
                local gradientEndSize = zo_min(gradientMaxEnd,
                    DEFAULT_GRADIENT_SIZE.VERTICAL)

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
function BETTERUI_VerticalParametricScrollList:Initialize(control)
    ZO_ParametricScrollList.Initialize(self, control, LIST_ORIENTATION.VERTICAL,
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
function BETTERUI_VerticalItemParametricScrollList:New(control)
    local list = BETTERUI_VerticalParametricScrollList.New(self, control)
    list:SetUniversalPostPadding(GAMEPAD_DEFAULT_POST_PADDING)
    return list
end
