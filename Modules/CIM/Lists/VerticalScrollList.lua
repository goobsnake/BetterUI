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
function BETTERUI_VerticalParametricScrollList:New(...)
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "vertical list new")
    end
    return ZO_ParametricScrollList.New(self, ...)
end

--- Initializes the list with default padding and sound.
function BETTERUI_VerticalParametricScrollList:Initialize(control)
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "vertical list init", { controlName = control and control.GetName and control:GetName() or "nil" })
    end
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
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "vertical item list new", { controlName = control and control.GetName and control:GetName() or "nil" })
    end
    local list = BETTERUI_VerticalParametricScrollList.New(self, control)
    list:SetUniversalPostPadding(GAMEPAD_DEFAULT_POST_PADDING)
    return list
end
