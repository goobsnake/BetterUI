--[[
File: Modules/CIM/UI/ScrollIndicatorControls.lua
Purpose: Internal constants, state, mouse interaction helpers, and control creation
         for the parametric list scroll indicator.
         Split from ScrollIndicator.lua for maintainability.
]]

-- Ensure namespace exists
if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.ScrollIndicator then BETTERUI.CIM.ScrollIndicator = {} end

-- CONSTANTS

--- Visual configuration for the scroll indicator.
--- Direction: offsetX positive = RIGHT, offsetY positive = DOWN
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

-- INTERNAL STATE

-- Cache for scroll indicator instances by list control
local indicatorInstances = {}

-- MOUSE INTERACTION CONSTANTS

local MOUSE_INTERACTION = {
    ARROW_REPEAT_DELAY_MS = 400,    -- Initial delay before repeat starts
    ARROW_REPEAT_INTERVAL_MS = 150, -- Interval between repeated scrolls
}

-- INTERNAL HELPER FUNCTIONS - MOUSE INTERACTION

local function StartArrowRepeat(instance, direction)
    if not instance or not instance.listObject then return end

    -- Store the direction for the repeat handler
    instance.arrowRepeatDirection = direction
    instance.arrowRepeatActive = true
    instance.arrowRepeatToken = (instance.arrowRepeatToken or 0) + 1
    local repeatToken = instance.arrowRepeatToken
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "scroll indicator start arrow repeat", { direction = direction })
    end

    -- Use a unique update name per instance to avoid collisions
    local updateName = "BetterUI_ScrollIndicatorArrowRepeat_" .. tostring(instance.listControl:GetName())
    EVENT_MANAGER:UnregisterForUpdate(updateName)

    -- Initial delay before repeat starts
    zo_callLater(function()
        if repeatToken ~= instance.arrowRepeatToken or not instance.arrowRepeatActive then return end

        -- Start the repeat interval
        EVENT_MANAGER:RegisterForUpdate(updateName, MOUSE_INTERACTION.ARROW_REPEAT_INTERVAL_MS, function()
            if repeatToken ~= instance.arrowRepeatToken or not instance.arrowRepeatActive or not instance.listObject then
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

local function StopArrowRepeat(instance)
    if not instance then return end

    instance.arrowRepeatActive = false
    instance.arrowRepeatDirection = nil
    instance.arrowRepeatToken = (instance.arrowRepeatToken or 0) + 1

    local updateName = "BetterUI_ScrollIndicatorArrowRepeat_" .. tostring(instance.listControl:GetName())
    EVENT_MANAGER:UnregisterForUpdate(updateName)
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "scroll indicator stop arrow repeat", { updateName = updateName })
    end
end

local function SetupArrowMouseHandlers(instance)
    if not instance or not instance.controls then return end

    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "scroll indicator setup arrow mouse handlers", { controlName = instance.listControl and instance.listControl.GetName and instance.listControl:GetName() or "nil" })
    end

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

    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "scroll indicator selectable bounds", { totalItems = totalItems, firstSelectableIndex = firstSelectableIndex, lastSelectableIndex = lastSelectableIndex })
    end

    return firstSelectableIndex, lastSelectableIndex
end

--- Stops an active thumb drag and removes the per-frame drag tracker.
local function StopThumbDrag(instance)
    if not instance then return end

    instance.isDragging = false

    if instance.controls and instance.controls.container then
        instance.controls.container:SetHandler("OnUpdate", nil)
    end
end

local function SetupThumbDragHandlers(instance)
    if not instance or not instance.controls then return end

    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "scroll indicator setup thumb drag handlers", { controlName = instance.listControl and instance.listControl.GetName and instance.listControl:GetName() or "nil" })
    end

    local thumb = instance.controls.thumb
    local track = instance.controls.track

    -- Enable mouse interaction on thumb
    thumb:SetMouseEnabled(true)

    -- Track drag state
    instance.isDragging = false

    -- Per-frame drag tracker; installed on drag start, removed on drag end/Destroy.
    local function OnDragUpdate()
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
    end

    thumb:SetHandler("OnMouseDown", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT and instance.listObject then
            instance.isDragging = true
            -- Install the per-frame tracker only while dragging
            instance.controls.container:SetHandler("OnUpdate", OnDragUpdate)
        end
    end)

    thumb:SetHandler("OnMouseUp", function(control, button)
        if button == MOUSE_BUTTON_INDEX_LEFT then
            StopThumbDrag(instance)
        end
    end)

    -- Also stop dragging if mouse exits the control area
    thumb:SetHandler("OnMouseExit", function()
        -- Don't immediately stop - allow dragging outside thumb if still holding
    end)

    local eventName = "BetterUI_ScrollIndicatorThumbDrag_" .. tostring(instance.listControl:GetName())

    -- Global mouse up handler to catch releases outside the thumb
    local function OnGlobalMouseUp(eventCode, button, ctrl, alt, shift, command)
        if button == MOUSE_BUTTON_INDEX_LEFT and instance.isDragging then
            StopThumbDrag(instance)
        end
    end

    -- Register for global mouse up to handle release outside thumb. Re-setup can
    -- happen without Destroy when named controls are reused, so clear any prior
    -- registration for this instance before installing the new callback.
    if instance.globalMouseUpEventName and EVENT_MANAGER and EVENT_MANAGER.UnregisterForEvent then
        EVENT_MANAGER:UnregisterForEvent(instance.globalMouseUpEventName, EVENT_GLOBAL_MOUSE_UP)
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "scroll indicator unregistered global mouse up", { eventName = instance.globalMouseUpEventName })
        end
    end
    instance.globalMouseUpHandler = nil
    instance.globalMouseUpEventName = nil

    if EVENT_MANAGER and EVENT_MANAGER.RegisterForEvent then
        EVENT_MANAGER:RegisterForEvent(eventName, EVENT_GLOBAL_MOUSE_UP, OnGlobalMouseUp)

        -- Store for cleanup (used by ScrollIndicator.Destroy)
        instance.globalMouseUpHandler = OnGlobalMouseUp
        instance.globalMouseUpEventName = eventName
    end
end

-- HELPER FUNCTIONS

--- Applies the texture and coordinates to the thumb control.
local function ApplyThumbTexture(thumb)
    if not thumb then return end

    local textureConfig = SCROLL_INDICATOR.THUMB
    thumb:SetTexture(textureConfig.TEXTURE)
    local coords = textureConfig.TEXTURE_COORDS
    thumb:SetTextureCoords(coords.left, coords.right, coords.top, coords.bottom)
end

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
    -- Must have a texture file for mouse hit detection to work
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

-- EXPORT INTERNALS FOR PUBLIC API

BETTERUI.CIM.ScrollIndicator._Internals = {
    SCROLL_INDICATOR = SCROLL_INDICATOR,
    indicatorInstances = indicatorInstances,
    SetupArrowMouseHandlers = SetupArrowMouseHandlers,
    SetupThumbDragHandlers = SetupThumbDragHandlers,
    StopArrowRepeat = StopArrowRepeat,
    StopThumbDrag = StopThumbDrag,
    GetSelectableBounds = GetSelectableBounds,
    CreateIndicatorControls = CreateIndicatorControls,
}
