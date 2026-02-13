--[[
File: Modules/CIM/UI/ScrollIndicator.lua
Purpose: Provides a visual scroll indicator for parametric lists (inventory, banking).
         Shows current scroll position with a track, thumb, and up/down arrows.
         Supports mouse interaction: arrow clicks and thumb dragging.
Author: BetterUI Team
Last Modified: 2026-02-07
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
        WIDTH = 14,                                        -- Reduced by 1/5
        COLOR = { r = 0.15, g = 0.15, b = 0.15, a = 0.5 }, -- Subtle dark background
        OFFSET_X = 25,                                     -- Shifted right to align with divider edge
    },
    THUMB = {
        WIDTH = 14,                                         -- Match track width
        MIN_HEIGHT = 120,                                   -- Visual sizing for cleaner look
        COLOR = { r = 0.77, g = 0.65, b = 0.30, a = 0.65 }, -- Match SelectionBar gold (#C4A64D @ 65% for visibility)
        -- Use a native gamepad divider sample row to avoid hidden vertical padding artifacts.
        TEXTURE = "EsoUI/Art/Windows/Gamepad/gp_nav1_horDividerFlat.dds",
        TEXTURE_COORDS = { left = 0, right = 1, top = 0.5, bottom = 0.5 },
    },
    ARROW = {
        SIZE = 32,     -- Larger arrows
        PADDING = 0.5, -- Almost touching dividers
    },
}

-- ============================================================================
-- INTERNAL STATE
-- ============================================================================

-- Cache for scroll indicator instances by list control
local indicatorInstances = {}

-- ============================================================================
-- MOUSE INTERACTION CONSTANTS
-- ============================================================================

--[[
Constant: MOUSE_INTERACTION
Description: Configuration for mouse click and drag behavior.
]]
local MOUSE_INTERACTION = {
    ARROW_REPEAT_DELAY_MS = 400,    -- Initial delay before repeat starts
    ARROW_REPEAT_INTERVAL_MS = 150, -- Interval between repeated scrolls
}

-- ============================================================================
-- INTERNAL HELPER FUNCTIONS - MOUSE INTERACTION
-- ============================================================================

--[[
Function: StartArrowRepeat
Description: Starts repeating scroll in the given direction while arrow is held.
param: instance (table) - The scroll indicator instance.
param: direction (number) - -1 for up (MovePrevious), +1 for down (MoveNext).
]]
local function StartArrowRepeat(instance, direction)
    if not instance or not instance.listObject then return end

    -- Store the direction for the repeat handler
    instance.arrowRepeatDirection = direction
    instance.arrowRepeatActive = true

    -- Use a unique update name per instance to avoid collisions
    local updateName = "BetterUI_ScrollIndicatorArrowRepeat_" .. tostring(instance.listControl:GetName())

    -- Initial delay before repeat starts
    zo_callLater(function()
        if not instance.arrowRepeatActive then return end

        -- Start the repeat interval
        EVENT_MANAGER:RegisterForUpdate(updateName, MOUSE_INTERACTION.ARROW_REPEAT_INTERVAL_MS, function()
            if not instance.arrowRepeatActive or not instance.listObject then
                EVENT_MANAGER:UnregisterForUpdate(updateName)
                return
            end

            if instance.arrowRepeatDirection == -1 then
                instance.listObject:MovePrevious()
            elseif instance.arrowRepeatDirection == 1 then
                instance.listObject:MoveNext()
            end
        end)
    end, MOUSE_INTERACTION.ARROW_REPEAT_DELAY_MS)
end

--[[
Function: StopArrowRepeat
Description: Stops the arrow repeat scrolling.
param: instance (table) - The scroll indicator instance.
]]
local function StopArrowRepeat(instance)
    if not instance then return end

    instance.arrowRepeatActive = false
    instance.arrowRepeatDirection = nil

    local updateName = "BetterUI_ScrollIndicatorArrowRepeat_" .. tostring(instance.listControl:GetName())
    EVENT_MANAGER:UnregisterForUpdate(updateName)
end

--[[
Function: SetupArrowMouseHandlers
Description: Sets up mouse click handlers for the up and down arrows.
param: instance (table) - The scroll indicator instance.
]]
local function SetupArrowMouseHandlers(instance)
    if not instance or not instance.controls then return end

    local upArrow = instance.controls.upArrow
    local downArrow = instance.controls.downArrow

    -- Enable mouse interaction on arrows
    upArrow:SetMouseEnabled(true)
    downArrow:SetMouseEnabled(true)

    -- Up Arrow handlers
    upArrow:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and instance.listObject then
            instance.listObject:MovePrevious()
            PlaySound(SOUNDS.HOR_LIST_ITEM_SELECTED)
            StartArrowRepeat(instance, -1)
        end
    end)

    upArrow:SetHandler("OnMouseUp", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            StopArrowRepeat(instance)
        end
    end)

    upArrow:SetHandler("OnMouseExit", function()
        StopArrowRepeat(instance)
    end)

    -- Down Arrow handlers
    downArrow:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and instance.listObject then
            instance.listObject:MoveNext()
            PlaySound(SOUNDS.HOR_LIST_ITEM_SELECTED)
            StartArrowRepeat(instance, 1)
        end
    end)

    downArrow:SetHandler("OnMouseUp", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            StopArrowRepeat(instance)
        end
    end)

    downArrow:SetHandler("OnMouseExit", function()
        StopArrowRepeat(instance)
    end)
end

--[[
Function: GetSelectableBounds
Description: Resolves the first/last selectable indices for a list.
Rationale: Parametric lists can contain non-selectable rows; using raw item count
           causes the thumb to stop short of visual extremes.
param: instance (table) - The scroll indicator instance.
param: totalItems (number) - Total entries currently in the list.
return: number, number - firstSelectableIndex, lastSelectableIndex
]]
local function GetSelectableBounds(instance, totalItems)
    local firstSelectableIndex = 1
    local lastSelectableIndex = totalItems

    local listObject = instance and instance.listObject
    if listObject and totalItems > 0 then
        if listObject.CalculateFirstSelectableIndex then
            firstSelectableIndex = listObject:CalculateFirstSelectableIndex()
        end
        if listObject.CalculateLastSelectableIndex then
            lastSelectableIndex = listObject:CalculateLastSelectableIndex()
        end
    end

    local maxIndex = math.max(totalItems, 1)
    firstSelectableIndex = zo_clamp(firstSelectableIndex or 1, 1, maxIndex)
    lastSelectableIndex = zo_clamp(lastSelectableIndex or totalItems, firstSelectableIndex, maxIndex)

    return firstSelectableIndex, lastSelectableIndex
end

--[[
Function: SetupThumbDragHandlers
Description: Sets up mouse drag handlers for the thumb to enable drag-to-scroll.
param: instance (table) - The scroll indicator instance.
]]
local function SetupThumbDragHandlers(instance)
    if not instance or not instance.controls then return end

    local thumb = instance.controls.thumb
    local track = instance.controls.track

    -- Enable mouse interaction on thumb
    thumb:SetMouseEnabled(true)

    -- Track drag state
    instance.isDragging = false
    instance.dragStartY = nil

    thumb:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and instance.listObject then
            instance.isDragging = true
            instance.dragStartY = select(2, GetUIMousePosition())
            instance.dragStartIndex = instance.currentIndex or 1
        end
    end)

    thumb:SetHandler("OnMouseUp", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            instance.isDragging = false
            instance.dragStartY = nil
            instance.dragStartIndex = nil
        end
    end)

    -- Also stop dragging if mouse exits the control area
    thumb:SetHandler("OnMouseExit", function()
        -- Don't immediately stop - allow dragging outside thumb if still holding
    end)

    -- Use OnUpdate on the container to track drag position
    local updateName = "BetterUI_ScrollIndicatorThumbDrag_" .. tostring(instance.listControl:GetName())

    instance.controls.container:SetHandler("OnUpdate", function()
        if not instance.isDragging or not instance.listObject then return end

        local currentY = select(2, GetUIMousePosition())
        local trackTop = track:GetTop()
        local trackHeight = track:GetHeight()
        local thumbHeight = thumb:GetHeight()

        if trackHeight <= thumbHeight then return end

        -- Calculate position within the track (0-1)
        local availableSpace = trackHeight - thumbHeight
        local relativeY = currentY - trackTop - (thumbHeight / 2)
        local scrollPercent = zo_clamp(relativeY / availableSpace, 0, 1)

        -- Calculate target index based on scroll percent
        -- Map directly to item index: 0% = item 1, 100% = item totalItems
        local totalItems = instance.totalItems or 0

        if totalItems <= 1 then return end

        -- Map drag position across the selectable range (skips non-selectable rows).
        local firstSelectableIndex, lastSelectableIndex = GetSelectableBounds(instance, totalItems)
        local selectableSpan = lastSelectableIndex - firstSelectableIndex
        if selectableSpan <= 0 then return end

        local targetIndex = math.floor(firstSelectableIndex + (scrollPercent * selectableSpan) + 0.5)
        targetIndex = zo_clamp(targetIndex, firstSelectableIndex, lastSelectableIndex)

        if instance.listObject.CanSelect and instance.listObject.GetNextSelectableIndex and not instance.listObject:CanSelect(targetIndex) then
            targetIndex = instance.listObject:GetNextSelectableIndex(targetIndex - 1)
            if targetIndex > lastSelectableIndex then
                targetIndex = lastSelectableIndex
            end
        end

        -- Only update if index changed
        if targetIndex ~= instance.currentIndex then
            instance.listObject:SetSelectedIndexWithoutAnimation(targetIndex, true, false)
        end
    end)

    -- Global mouse up handler to catch releases outside the thumb
    local function OnGlobalMouseUp(eventCode, button, ctrl, alt, shift, command)
        if button == MOUSE_BUTTON_INDEX_LEFT and instance.isDragging then
            instance.isDragging = false
            instance.dragStartY = nil
            instance.dragStartIndex = nil
        end
    end

    -- Register for global mouse up to handle release outside thumb
    EVENT_MANAGER:RegisterForEvent(updateName, EVENT_GLOBAL_MOUSE_UP, OnGlobalMouseUp)

    -- Store for cleanup
    -- TODO(leak): EVENT_GLOBAL_MOUSE_UP is registered but never unregistered; add a destroy/cleanup method that calls EVENT_MANAGER:UnregisterForEvent
    instance.globalMouseUpHandler = OnGlobalMouseUp
    instance.globalMouseUpEventName = updateName
end

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

local function ApplyThumbTexture(thumb)
    if not thumb then return end

    local textureConfig = SCROLL_INDICATOR.THUMB
    thumb:SetTexture(textureConfig.TEXTURE)
    local coords = textureConfig.TEXTURE_COORDS
    thumb:SetTextureCoords(coords.left, coords.right, coords.top, coords.bottom)
end

--[[
Function: CreateIndicatorControls
Description: Creates the visual controls for the scroll indicator.
Mechanism: Creates textures for track, thumb, and arrows positioned relative to the list.
param: listControl (table) - The parametric list control to attach to.
return: table - Table containing references to created controls.
]]
local function CreateIndicatorControls(listControl, offsetX, offsetTopY, offsetBottomY)
    local controlName = listControl:GetName() .. "ScrollIndicator"
    local actualOffsetX = offsetX or SCROLL_INDICATOR.TRACK.OFFSET_X
    local actualOffsetTopY = offsetTopY or 0
    local actualOffsetBottomY = offsetBottomY or 0

    -- Main container for scroll indicator
    local container = WINDOW_MANAGER:CreateControl(controlName, listControl, CT_CONTROL)
    container:SetAnchor(TOPRIGHT, listControl, TOPRIGHT, actualOffsetX, actualOffsetTopY)
    container:SetAnchor(BOTTOMRIGHT, listControl, BOTTOMRIGHT, actualOffsetX, actualOffsetBottomY)
    container:SetWidth(SCROLL_INDICATOR.ARROW.SIZE)
    container:SetHidden(false)
    -- Set high draw tier to ensure mouse events reach us above list controls
    container:SetDrawTier(DT_HIGH)
    container:SetDrawLayer(DL_OVERLAY)
    container:SetDrawLevel(100) -- Above other content
    -- Note: Don't add empty mouse handlers here - they would block events from reaching children


    -- Up Arrow
    local upArrow = WINDOW_MANAGER:CreateControl(controlName .. "UpArrow", container, CT_TEXTURE)
    upArrow:SetTexture("EsoUI/Art/Buttons/Gamepad/gp_upArrow.dds")
    upArrow:SetDimensions(SCROLL_INDICATOR.ARROW.SIZE, SCROLL_INDICATOR.ARROW.SIZE)
    upArrow:SetAnchor(TOP, container, TOP, 0, SCROLL_INDICATOR.ARROW.PADDING)
    upArrow:SetHidden(false)
    upArrow:SetDrawLevel(101) -- Above container

    -- Down Arrow
    local downArrow = WINDOW_MANAGER:CreateControl(controlName .. "DownArrow", container, CT_TEXTURE)
    downArrow:SetTexture("EsoUI/Art/Buttons/Gamepad/gp_downArrow.dds")
    downArrow:SetDimensions(SCROLL_INDICATOR.ARROW.SIZE, SCROLL_INDICATOR.ARROW.SIZE)
    downArrow:SetAnchor(BOTTOM, container, BOTTOM, 0, -SCROLL_INDICATOR.ARROW.PADDING)
    downArrow:SetHidden(false)
    downArrow:SetDrawLevel(101) -- Above container

    -- Track (background) - centered horizontally with arrows
    local track = WINDOW_MANAGER:CreateControl(controlName .. "Track", container, CT_TEXTURE)
    track:SetTexture("EsoUI/Art/Miscellaneous/inset_bg.dds")
    track:SetWidth(SCROLL_INDICATOR.TRACK.WIDTH)
    -- Use explicit horizontal centering, zero vertical padding for full travel
    local arrowCenterOffset = (SCROLL_INDICATOR.ARROW.SIZE - SCROLL_INDICATOR.TRACK.WIDTH) / 2
    track:SetAnchor(TOPLEFT, upArrow, BOTTOMLEFT, arrowCenterOffset, 0)
    track:SetAnchor(BOTTOMRIGHT, downArrow, TOPRIGHT, -arrowCenterOffset, 0)
    track:SetColor(
        SCROLL_INDICATOR.TRACK.COLOR.r,
        SCROLL_INDICATOR.TRACK.COLOR.g,
        SCROLL_INDICATOR.TRACK.COLOR.b,
        SCROLL_INDICATOR.TRACK.COLOR.a
    )
    track:SetHidden(false)
    track:SetDrawLevel(100) -- Background behind thumb

    -- Thumb (position indicator)
    -- IMPORTANT: Must have a texture file for mouse hit detection to work
    local thumb = WINDOW_MANAGER:CreateControl(controlName .. "Thumb", container, CT_TEXTURE)
    ApplyThumbTexture(thumb)
    thumb:SetWidth(SCROLL_INDICATOR.THUMB.WIDTH)
    thumb:SetHeight(SCROLL_INDICATOR.THUMB.MIN_HEIGHT)
    thumb:SetColor(
        SCROLL_INDICATOR.THUMB.COLOR.r,
        SCROLL_INDICATOR.THUMB.COLOR.g,
        SCROLL_INDICATOR.THUMB.COLOR.b,
        SCROLL_INDICATOR.THUMB.COLOR.a
    )
    thumb:SetAnchor(TOP, track, TOP, 0, 0) -- Anchor initially
    thumb:SetHidden(false)
    thumb:SetDrawLevel(102)                -- Above track, highest priority for mouse


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
           Optionally sets up mouse interaction if listObject is provided.
param: listControl (table) - The parametric list control.
param: offsetX (number?) - Optional X offset override for positioning.
param: offsetTopY (number?) - Optional top Y offset for arrow adjustment.
param: offsetBottomY (number?) - Optional bottom Y offset for arrow adjustment.
param: listObject (table?) - Optional parametric list object for mouse interaction callbacks.
return: table - The indicator instance.
]]
function ScrollIndicator.Initialize(listControl, offsetX, offsetTopY, offsetBottomY, listObject)
    if not listControl then return nil end

    local controlName = listControl:GetName()

    -- Return existing instance if already initialized
    if indicatorInstances[controlName] then
        local instance = indicatorInstances[controlName]

        -- Update listObject if provided (allows late binding)
        if listObject then
            instance.listObject = listObject
            -- Setup handlers if not already done
            if not instance.mouseHandlersSetup then
                SetupArrowMouseHandlers(instance)
                SetupThumbDragHandlers(instance)
                instance.mouseHandlersSetup = true
            end
        end

        -- Update position if new offsets are provided (fixes caching bug)
        if offsetX or offsetTopY or offsetBottomY then
            local actualOffsetX = offsetX or SCROLL_INDICATOR.TRACK.OFFSET_X
            local actualOffsetTopY = offsetTopY or 0
            local actualOffsetBottomY = offsetBottomY or 0

            local container = instance.controls and instance.controls.container
            if container then
                container:ClearAnchors()
                container:SetAnchor(TOPRIGHT, listControl, TOPRIGHT, actualOffsetX, actualOffsetTopY)
                container:SetAnchor(BOTTOMRIGHT, listControl, BOTTOMRIGHT, actualOffsetX, actualOffsetBottomY)
            end
        end

        return instance
    end

    -- Create new indicator
    local controls = CreateIndicatorControls(listControl, offsetX, offsetTopY, offsetBottomY)

    local instance = {
        listControl = listControl,
        controls = controls,
        totalItems = 0,
        visibleItems = 0,
        currentIndex = 1,
        listObject = listObject,
        mouseHandlersSetup = false,
    }

    indicatorInstances[controlName] = instance

    -- Setup mouse interaction if listObject is provided
    if listObject then
        SetupArrowMouseHandlers(instance)
        SetupThumbDragHandlers(instance)
        instance.mouseHandlersSetup = true
    end

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

    -- Always show arrows, track, and thumb
    controls.track:SetHidden(false)
    controls.thumb:SetHidden(false)
    controls.upArrow:SetHidden(false)
    controls.downArrow:SetHidden(false)

    local firstSelectableIndex, lastSelectableIndex = GetSelectableBounds(instance, instance.totalItems)
    local selectableSpan = lastSelectableIndex - firstSelectableIndex

    -- Calculate scroll position (0-1 range)
    -- Normalize against selectable bounds, not raw entry count.
    local scrollPosition = 0
    if selectableSpan > 0 then
        scrollPosition = (currentIndex - firstSelectableIndex) / selectableSpan
    end
    scrollPosition = zo_clamp(scrollPosition, 0, 1)

    -- Get track dimensions
    local trackHeight = controls.track:GetHeight()

    -- Calculate thumb height (proportional to visible items relative to total)
    -- Use full trackHeight so thumb size is consistent with visual track
    local selectableItems = lastSelectableIndex - firstSelectableIndex + 1
    local thumbHeightRatio = visibleItems / math.max(selectableItems, 1)
    local thumbHeight = math.max(SCROLL_INDICATOR.THUMB.MIN_HEIGHT, trackHeight * math.min(thumbHeightRatio, 1))

    -- Calculate available travel distance within the FULL track
    -- This ensures thumb can travel from top arrow to bottom arrow
    local availableTravel = math.max(0, trackHeight - thumbHeight)

    -- Calculate thumb offset from track top
    local thumbOffset = availableTravel * scrollPosition

    -- Position thumb with dual-anchor strategy for pixel-perfect alignment at extremes.
    -- Using TOP anchor with a large offset at position 1.0 causes floating-point accumulation:
    -- track.TOP + offset + thumbHeight may not equal track.BOTTOM exactly in ESO's layout engine.
    -- At the extremes, anchor directly to the track edge to guarantee alignment.
    controls.thumb:ClearAnchors()
    controls.thumb:SetHeight(thumbHeight)

    if currentIndex >= lastSelectableIndex and selectableSpan > 0 then
        -- Last item: anchor thumb BOTTOM to track BOTTOM for pixel-perfect bottom alignment
        controls.thumb:SetAnchor(BOTTOM, controls.track, BOTTOM, 0, 0)
    elseif currentIndex <= firstSelectableIndex or selectableSpan <= 0 then
        -- First item (or single/no items): anchor thumb TOP to track TOP
        controls.thumb:SetAnchor(TOP, controls.track, TOP, 0, 0)
    elseif scrollPosition > 0.5 then
        -- Lower half: anchor from BOTTOM with negative offset for better precision near bottom
        local distanceFromBottom = availableTravel - thumbOffset
        controls.thumb:SetAnchor(BOTTOM, controls.track, BOTTOM, 0, -distanceFromBottom)
    else
        -- Upper half: anchor from TOP with positive offset (standard)
        controls.thumb:SetAnchor(TOP, controls.track, TOP, 0, thumbOffset)
    end

    if BETTERUI.CIM.Debug and BETTERUI.CIM.Debug.IsEnabled() then
        if currentIndex >= lastSelectableIndex - 1 and selectableSpan > 0 then
            zo_callLater(function()
                if not controls or not controls.thumb then return end
                local tT, tB = controls.thumb:GetTop(), controls.thumb:GetBottom()
                local rT, rB = controls.track:GetTop(), controls.track:GetBottom()
                local aT, aB = controls.downArrow:GetTop(), controls.downArrow:GetBottom()
                local cB = controls.container:GetBottom()
                BETTERUI.CIM.Debug.Log(string.format(
                    "[ScrollInd] PIXELS thumb=%d-%d trk=%d-%d arrow=%d-%d cont_bot=%d",
                    tT, tB, rT, rB, aT, aB, cB
                ), "ScrollIndicator")
                BETTERUI.CIM.Debug.Log(string.format(
                    "[ScrollInd] GAPS thumb-to-trkBot=%d thumb-to-arrowTop=%d",
                    rB - tB, aT - tB
                ), "ScrollIndicator")
            end, 100)
        end
    end
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

--[[
Function: ScrollIndicator.SetListObject
Description: Sets or updates the list object reference for mouse interaction.
Rationale: Allows late-binding of the list object after initialization.
param: listControl (table) - The parametric list control.
param: listObject (table) - The parametric list object.
]]
function ScrollIndicator.SetListObject(listControl, listObject)
    if not listControl then return end

    local controlName = listControl:GetName()
    local instance = indicatorInstances[controlName]

    if not instance then return end

    instance.listObject = listObject

    -- Setup handlers if not already done
    if listObject and not instance.mouseHandlersSetup then
        SetupArrowMouseHandlers(instance)
        SetupThumbDragHandlers(instance)
        instance.mouseHandlersSetup = true
    end
end
