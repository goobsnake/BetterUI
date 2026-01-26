--[[
File: Modules/CIM/Lists/VerticalScrollList.lua
Purpose: Vertical Parametric Scroll List implementation.
         Extends ZO_ParametricScrollList with custom gradient fading.
Author: BetterUI Team
Last Modified: 2026-01-26
]]

local DEFAULT_EXPECTED_ENTRY_HEIGHT = 30
local DEFAULT_EXPECTED_HEADER_HEIGHT = 24

--[[
Function: GetControlDimensionForMode
Description: Gets the relevant dimension (Height/Width) based on list orientation.
param: mode (boolean) - Vertical (true) or Horizontal (false).
param: control (table) - The control to check.
return: number - The dimension size.
]]
local function GetControlDimensionForMode(mode, control)
    return mode == PARAMETRIC_SCROLL_LIST_VERTICAL and control:GetHeight() or control:GetWidth()
end

--[[
Function: GetStartOfControl
Description: Gets the starting edge (Top/Left) based on list orientation.
param: mode (boolean) - Vertical (true) or Horizontal (false).
param: control (table) - The control to check.
return: number - The start coordinate.
]]
local function GetStartOfControl(mode, control)
    return mode == PARAMETRIC_SCROLL_LIST_VERTICAL and control:GetTop() or control:GetLeft()
end

--[[
Function: GetEndOfControl
Description: Gets the ending edge (Bottom/Right) based on list orientation.
param: mode (boolean) - Vertical (true) or Horizontal (false).
param: control (table) - The control to check.
return: number - The end coordinate.
]]
local function GetEndOfControl(mode, control)
    return mode == PARAMETRIC_SCROLL_LIST_VERTICAL and control:GetBottom() or control:GetRight()
end

-- ============================================================================
-- CLASS: BETTERUI_VerticalParametricScrollList
-- Customized Vertical Scroll List with enhanced Gradient Fading logic.
-- ============================================================================
BETTERUI_VerticalParametricScrollList = ZO_ParametricScrollList:Subclass()

--[[
Function: BETTERUI_VerticalParametricScrollList:New
Description: Creates a new vertical parametric scroll list instance.
Rationale: Initializes the list with custom fade gradient logic.
Mechanism:
  - Overrides EnsureValidGradient to apply specific top/bottom fades.
  - Dynamically calculates gradient sizes based on list content and alignment.
  - Ensures clean fades at the edges of the scroll area.
param: ... (any) - Arguments passed to ZO_ParametricScrollList:New.
return: table - The new list instance.
]]
function BETTERUI_VerticalParametricScrollList:New(...)
    local list = ZO_ParametricScrollList.New(self, ...)

    -- Override EnsureValidGradient to provide custom fade behavior
    list.EnsureValidGradient = function(self)
        if self.validateGradient and self.validGradientDirty then
            -- Cache key based on inputs
            local listHeight = self.scrollControl:GetHeight()
            local centerOffset = self.fixedCenterOffset

            -- Optimization: Skip recalculation if dimensions haven't changed
            if self._gradientCacheHeight == listHeight and self._gradientCacheOffset == centerOffset then
                self.validGradientDirty = false
                return
            end

            if self.mode == PARAMETRIC_SCROLL_LIST_VERTICAL then
                local listStart = GetStartOfControl(self.mode, self.scrollControl)
                local listEnd = GetEndOfControl(self.mode, self.scrollControl)
                local listMid = listStart + (GetControlDimensionForMode(self.mode, self.scrollControl) / 2.0)

                if self.alignToScreenCenter and self.alignToScreenCenterAnchor then
                    listMid = GetStartOfControl(self.mode, self.alignToScreenCenterAnchor)
                end
                listMid = listMid + self.fixedCenterOffset

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
                local MINIMUM_ALLOWED_FADE_GRADIENT = 32
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

--[[
Function: BETTERUI_VerticalParametricScrollList:Initialize
Description: Initializes the list with default padding and sound.
param: control (table) - The list control.
]]
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
Description: Subclass specifically for Item Lists (Inventory rows).
Rationale: Sets default post-padding for inventory items.
]]
BETTERUI_VerticalItemParametricScrollList = BETTERUI_VerticalParametricScrollList:Subclass()

--[[
Function: BETTERUI_VerticalItemParametricScrollList:New
Description: Constructor for item list.
param: control (table) - The list control.
return: table - The new list instance.
]]
function BETTERUI_VerticalItemParametricScrollList:New(control)
    local list = BETTERUI_VerticalParametricScrollList.New(self, control)
    list:SetUniversalPostPadding(GAMEPAD_DEFAULT_POST_PADDING)
    return list
end
