--[[
File: Modules/CIM/UI/ScrollIndicator.lua
Purpose: Provides a visual scroll indicator for parametric lists (inventory, banking).
         Shows current scroll position with a track, thumb, and up/down arrows.
Author: BetterUI Team
Last Modified: 2026-01-29
]]

-- Ensure namespace exists
if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.ScrollIndicator then BETTERUI.CIM.ScrollIndicator = {} end

local ScrollIndicator = BETTERUI.CIM.ScrollIndicator

-- ============================================================================
-- CONSTANTS
-- ============================================================================

--[[
Constant: SCROLL_INDICATOR
Description: Visual configuration for the scroll indicator.
Direction: offsetX positive = RIGHT, offsetY positive = DOWN
]]
local SCROLL_INDICATOR = {
    TRACK = {
        WIDTH = 28,                                        -- Match thumb width
        COLOR = { r = 0.15, g = 0.15, b = 0.15, a = 0.5 }, -- Subtle dark background
        OFFSET_X = -5,                                     -- Very close to right edge
    },
    THUMB = {
        WIDTH = 28,                                        -- Width for visibility
        MIN_HEIGHT = 240,                                  -- Doubled height for noticeable movement
        COLOR = { r = 0.85, g = 0.72, b = 0.35, a = 1.0 }, -- Brighter gold matching side divider
    },
    ARROW = {
        SIZE = 32,   -- Larger arrows
        PADDING = 6, -- More padding from dividers
    },
}

-- ============================================================================
-- INTERNAL STATE
-- ============================================================================

-- Cache for scroll indicator instances by list control
local indicatorInstances = {}

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

--[[
Function: CreateIndicatorControls
Description: Creates the visual controls for the scroll indicator.
Mechanism: Creates textures for track, thumb, and arrows positioned relative to the list.
param: listControl (table) - The parametric list control to attach to.
return: table - Table containing references to created controls.
]]
local function CreateIndicatorControls(listControl)
    local controlName = listControl:GetName() .. "ScrollIndicator"


    -- Main container for scroll indicator
    local container = WINDOW_MANAGER:CreateControl(controlName, listControl, CT_CONTROL)
    container:SetAnchor(TOPRIGHT, listControl, TOPRIGHT, SCROLL_INDICATOR.TRACK.OFFSET_X, 0)
    container:SetAnchor(BOTTOMRIGHT, listControl, BOTTOMRIGHT, SCROLL_INDICATOR.TRACK.OFFSET_X, 0)
    container:SetWidth(SCROLL_INDICATOR.ARROW.SIZE)
    container:SetHidden(false) -- Make sure container is visible


    -- Up Arrow
    local upArrow = WINDOW_MANAGER:CreateControl(controlName .. "UpArrow", container, CT_TEXTURE)
    upArrow:SetTexture("EsoUI/Art/Buttons/Gamepad/gp_upArrow.dds")
    upArrow:SetDimensions(SCROLL_INDICATOR.ARROW.SIZE, SCROLL_INDICATOR.ARROW.SIZE)
    upArrow:SetAnchor(TOP, container, TOP, 0, SCROLL_INDICATOR.ARROW.PADDING)
    upArrow:SetHidden(false) -- Show for testing

    -- Down Arrow
    local downArrow = WINDOW_MANAGER:CreateControl(controlName .. "DownArrow", container, CT_TEXTURE)
    downArrow:SetTexture("EsoUI/Art/Buttons/Gamepad/gp_downArrow.dds")
    downArrow:SetDimensions(SCROLL_INDICATOR.ARROW.SIZE, SCROLL_INDICATOR.ARROW.SIZE)
    downArrow:SetAnchor(BOTTOM, container, BOTTOM, 0, -SCROLL_INDICATOR.ARROW.PADDING)
    downArrow:SetHidden(false) -- Show for testing

    -- Track (background)
    local track = WINDOW_MANAGER:CreateControl(controlName .. "Track", container, CT_TEXTURE)
    track:SetTexture("EsoUI/Art/Miscellaneous/inset_bg.dds")
    track:SetWidth(SCROLL_INDICATOR.TRACK.WIDTH)
    track:SetAnchor(TOP, upArrow, BOTTOM, 0, SCROLL_INDICATOR.ARROW.PADDING)
    track:SetAnchor(BOTTOM, downArrow, TOP, 0, -SCROLL_INDICATOR.ARROW.PADDING)
    track:SetColor(
        SCROLL_INDICATOR.TRACK.COLOR.r,
        SCROLL_INDICATOR.TRACK.COLOR.g,
        SCROLL_INDICATOR.TRACK.COLOR.b,
        SCROLL_INDICATOR.TRACK.COLOR.a
    )
    track:SetHidden(false) -- Show for testing

    -- Thumb (position indicator)
    local thumb = WINDOW_MANAGER:CreateControl(controlName .. "Thumb", container, CT_TEXTURE)
    thumb:SetTexture("EsoUI/Art/Windows/Gamepad/gp_nav1_horDividerFlat.dds")
    thumb:SetWidth(SCROLL_INDICATOR.THUMB.WIDTH)
    thumb:SetHeight(SCROLL_INDICATOR.THUMB.MIN_HEIGHT)
    thumb:SetColor(
        SCROLL_INDICATOR.THUMB.COLOR.r,
        SCROLL_INDICATOR.THUMB.COLOR.g,
        SCROLL_INDICATOR.THUMB.COLOR.b,
        SCROLL_INDICATOR.THUMB.COLOR.a
    )
    thumb:SetAnchor(TOP, track, TOP, 0, 0) -- Anchor initially
    thumb:SetHidden(false)                 -- Show for testing


    return {
        container = container,
        upArrow = upArrow,
        downArrow = downArrow,
        track = track,
        thumb = thumb,
    }
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

--[[
Function: ScrollIndicator.Initialize
Description: Initializes the scroll indicator for a parametric list.
Mechanism: Creates the indicator controls and stores an instance reference.
param: listControl (table) - The parametric list control.
return: table - The indicator instance.
]]
function ScrollIndicator.Initialize(listControl)
    if not listControl then return nil end

    local controlName = listControl:GetName()

    -- Return existing instance if already initialized
    if indicatorInstances[controlName] then
        return indicatorInstances[controlName]
    end

    -- Create new indicator
    local controls = CreateIndicatorControls(listControl)

    local instance = {
        listControl = listControl,
        controls = controls,
        totalItems = 0,
        visibleItems = 0,
        currentIndex = 1,
    }

    indicatorInstances[controlName] = instance
    return instance
end

--[[
Function: ScrollIndicator.Update
Description: Updates the scroll indicator position and visibility.
Mechanism: Calculates thumb position based on current index and total items.
           Shows/hides arrows and track based on whether scrolling is possible.
param: listControl (table) - The parametric list control.
param: currentIndex (number) - Currently selected item index (1-based).
param: totalItems (number) - Total number of items in the list.
param: visibleItems (number) - Number of items visible at once.
]]
function ScrollIndicator.Update(listControl, currentIndex, totalItems, visibleItems)
    if not listControl then return end

    local controlName = listControl:GetName()
    local instance = indicatorInstances[controlName]

    -- Auto-initialize if not already done
    if not instance then
        instance = ScrollIndicator.Initialize(listControl)
    end

    if not instance or not instance.controls then return end

    -- Update cached state
    instance.currentIndex = currentIndex or 1
    instance.totalItems = totalItems or 0
    instance.visibleItems = visibleItems or 10

    local controls = instance.controls

    -- Determine if scrolling is possible
    local canScroll = totalItems > visibleItems

    -- Show/hide based on scrollability
    controls.track:SetHidden(not canScroll)
    controls.thumb:SetHidden(not canScroll)

    if not canScroll then
        controls.upArrow:SetHidden(true)
        controls.downArrow:SetHidden(true)
        return
    end

    -- Calculate scroll position (0-1 range)
    local maxScrollIndex = totalItems - visibleItems + 1
    local scrollPosition = (currentIndex - 1) / math.max(1, maxScrollIndex - 1)
    scrollPosition = zo_clamp(scrollPosition, 0, 1)

    -- Calculate thumb height (proportional to visible items)
    local trackHeight = controls.track:GetHeight()
    local thumbHeightRatio = visibleItems / totalItems
    local thumbHeight = math.max(SCROLL_INDICATOR.THUMB.MIN_HEIGHT, trackHeight * thumbHeightRatio)
    controls.thumb:SetHeight(thumbHeight)

    -- Calculate thumb position
    local availableTrackSpace = trackHeight - thumbHeight
    local thumbOffset = availableTrackSpace * scrollPosition

    -- Position thumb relative to track top
    controls.thumb:ClearAnchors()
    controls.thumb:SetAnchor(TOP, controls.track, TOP, 0, thumbOffset)

    -- Arrows are always visible (no longer hidden based on position)
    controls.upArrow:SetHidden(false)
    controls.downArrow:SetHidden(false)
end

--[[
Function: ScrollIndicator.Hide
Description: Hides the scroll indicator completely.
param: listControl (table) - The parametric list control.
]]
function ScrollIndicator.Hide(listControl)
    if not listControl then return end

    local controlName = listControl:GetName()
    local instance = indicatorInstances[controlName]

    if instance and instance.controls then
        instance.controls.container:SetHidden(true)
    end
end

--[[
Function: ScrollIndicator.Show
Description: Shows the scroll indicator (if scrolling is possible).
param: listControl (table) - The parametric list control.
]]
function ScrollIndicator.Show(listControl)
    if not listControl then return end

    local controlName = listControl:GetName()
    local instance = indicatorInstances[controlName]

    if instance and instance.controls then
        instance.controls.container:SetHidden(false)
        -- Re-update to ensure correct visibility
        ScrollIndicator.Update(listControl, instance.currentIndex, instance.totalItems, instance.visibleItems)
    end
end

--[[
Function: ScrollIndicator.SetTrackAnchors
Description: Sets custom anchors for the scroll track to position it relative to header/footer.
param: listControl (table) - The parametric list control.
param: topAnchorControl (table) - Control to anchor top to (e.g., header divider).
param: bottomAnchorControl (table) - Control to anchor bottom to (e.g., footer divider).
param: topOffset (number) - Offset from top anchor.
param: bottomOffset (number) - Offset from bottom anchor.
]]
function ScrollIndicator.SetTrackAnchors(listControl, topAnchorControl, bottomAnchorControl, topOffset, bottomOffset)
    if not listControl then return end

    local controlName = listControl:GetName()
    local instance = indicatorInstances[controlName]

    if not instance or not instance.controls then return end

    local container = instance.controls.container

    container:ClearAnchors()

    if topAnchorControl then
        container:SetAnchor(TOP, topAnchorControl, BOTTOM, SCROLL_INDICATOR.TRACK.OFFSET_X, topOffset or 0)
    else
        container:SetAnchor(TOPRIGHT, listControl, TOPRIGHT, SCROLL_INDICATOR.TRACK.OFFSET_X, 0)
    end

    if bottomAnchorControl then
        container:SetAnchor(BOTTOM, bottomAnchorControl, TOP, 0, bottomOffset or 0)
    else
        container:SetAnchor(BOTTOMRIGHT, listControl, BOTTOMRIGHT, SCROLL_INDICATOR.TRACK.OFFSET_X, 0)
    end
end
