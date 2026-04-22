--[[
File: Modules/CIM/UI/ScrollIndicator.lua
Purpose: Public API for the parametric list scroll indicator.
         Internal constants, helpers, and control creation are in ScrollIndicatorControls.lua.
]]

-- Ensure namespace exists
if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.ScrollIndicator then BETTERUI.CIM.ScrollIndicator = {} end

local ScrollIndicator = BETTERUI.CIM.ScrollIndicator

-- Import internals from ScrollIndicatorControls.lua
local I = ScrollIndicator._Internals or {}
local SCROLL_INDICATOR = I.SCROLL_INDICATOR or {}
local indicatorInstances = I.indicatorInstances or {}
local SetupArrowMouseHandlers = I.SetupArrowMouseHandlers or function() end
local SetupThumbDragHandlers = I.SetupThumbDragHandlers or function() end
local StopArrowRepeat = I.StopArrowRepeat or function() end
local GetSelectableBounds = I.GetSelectableBounds or function(_, t) return 1, t end
local CreateIndicatorControls = I.CreateIndicatorControls or function() return {} end

-- PUBLIC API

local function ApplyOffsets(instance, listControl, options)
    local actualOffsetX = (options and options.offsetX) or (SCROLL_INDICATOR.TRACK and SCROLL_INDICATOR.TRACK.OFFSET_X or 25)
    local actualOffsetTopY = (options and options.offsetTopY) or 0
    local actualOffsetBottomY = (options and options.offsetBottomY) or 0
    local container = instance and instance.controls and instance.controls.container
    if not container then
        return
    end

    container:ClearAnchors()
    container:SetAnchor(TOPRIGHT, listControl, TOPRIGHT, actualOffsetX, actualOffsetTopY)
    container:SetAnchor(BOTTOMRIGHT, listControl, BOTTOMRIGHT, actualOffsetX, actualOffsetBottomY)
end

local function EnsureMouseHandlers(instance)
    if not instance or not instance.listObject or instance.mouseHandlersSetup then
        return
    end

    SetupArrowMouseHandlers(instance)
    SetupThumbDragHandlers(instance)
    instance.mouseHandlersSetup = true
end

--- Ensures the scroll indicator exists for a parametric list and applies layout options.
---@param listControl table
---@param options table|nil
---@return table? instance
function ScrollIndicator.Ensure(listControl, options)
    if not listControl then return nil end

    local controlName = listControl:GetName()

    if indicatorInstances[controlName] then
        local instance = indicatorInstances[controlName]
        if options then
            ApplyOffsets(instance, listControl, options)
        end
        return instance
    end

    local controls = CreateIndicatorControls(
        listControl,
        options and options.offsetX or nil,
        options and options.offsetTopY or nil,
        options and options.offsetBottomY or nil
    )

    local instance = {
        listControl = listControl,
        controls = controls,
        totalItems = 0,
        visibleItems = 0,
        currentIndex = 1,
        listObject = nil,
        mouseHandlersSetup = false,
    }

    indicatorInstances[controlName] = instance
    ApplyOffsets(instance, listControl, options)
    return instance
end

--- Binds the interactive list object for an existing indicator.
---@param listControl table
---@param listObject table|nil
---@return table? instance
function ScrollIndicator.BindListObject(listControl, listObject)
    local instance = ScrollIndicator.Ensure(listControl)
    if not instance then
        return nil
    end

    instance.listObject = listObject
    EnsureMouseHandlers(instance)
    return instance
end

--- Updates the scroll indicator position and visibility.
--- Shows/hides arrows and track based on whether scrolling is possible.
---
---@param listControl table
---@param currentIndex integer
---@param totalItems integer
---@param visibleItems integer
---@return nil
function ScrollIndicator.Update(listControl, currentIndex, totalItems, visibleItems)
    if not listControl then return end

    local controlName = listControl:GetName()
    local instance = indicatorInstances[controlName]

    if not instance then
        instance = ScrollIndicator.Ensure(listControl)
    end

    if not instance or not instance.controls then return end

    -- Update cached state
    instance.currentIndex = currentIndex or 1
    instance.totalItems = totalItems or 0
    instance.visibleItems = visibleItems or 10

    local controls = instance.controls
    local THUMB_CFG = SCROLL_INDICATOR.THUMB or {}

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
    local minThumbHeight = THUMB_CFG.MIN_HEIGHT or 120
    local thumbHeight = math.max(minThumbHeight, trackHeight * math.min(thumbHeightRatio, 1))

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

--- Hides the scroll indicator completely.
---
---@param listControl table
---@return nil
function ScrollIndicator.Hide(listControl)
    if not listControl then return end

    local controlName = listControl:GetName()
    local instance = indicatorInstances[controlName]

    if instance and instance.controls then
        instance.controls.container:SetHidden(true)
    end
end

--- Shows the scroll indicator (if scrolling is possible).
---
---@param listControl table
---@return nil
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

--- Sets custom anchors for the scroll track to position it relative to header/footer.
---
---@param listControl table
---@param topAnchorControl table?
---@param bottomAnchorControl table?
---@param topOffset number?
---@param bottomOffset number?
---@return nil
function ScrollIndicator.SetTrackAnchors(listControl, topAnchorControl, bottomAnchorControl, topOffset, bottomOffset)
    if not listControl then return end

    local controlName = listControl:GetName()
    local instance = indicatorInstances[controlName]

    if not instance or not instance.controls then return end

    local container = instance.controls.container
    local trackOffsetX = (SCROLL_INDICATOR.TRACK and SCROLL_INDICATOR.TRACK.OFFSET_X) or 25

    container:ClearAnchors()

    if topAnchorControl then
        container:SetAnchor(TOP, topAnchorControl, BOTTOM, trackOffsetX, topOffset or 0)
    else
        container:SetAnchor(TOPRIGHT, listControl, TOPRIGHT, trackOffsetX, 0)
    end

    if bottomAnchorControl then
        container:SetAnchor(BOTTOM, bottomAnchorControl, TOP, 0, bottomOffset or 0)
    else
        container:SetAnchor(BOTTOMRIGHT, listControl, BOTTOMRIGHT, trackOffsetX, 0)
    end
end

--- Sets or updates the list object reference for mouse interaction.
---
---@param listControl table
---@param listObject table
---@return nil
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

--- Cleans up a scroll indicator instance, unregistering all event handlers.
---
---@param listControl table
---@return nil
function ScrollIndicator.Destroy(listControl)
    if not listControl then return end

    local controlName = listControl:GetName()
    local instance = indicatorInstances[controlName]

    if not instance then return end

    -- Unregister global mouse up handler
    if instance.globalMouseUpEventName then
        EVENT_MANAGER:UnregisterForEvent(instance.globalMouseUpEventName, EVENT_GLOBAL_MOUSE_UP)
    end

    -- Stop any active arrow repeat
    StopArrowRepeat(instance)

    -- Clear drag state
    instance.isDragging = false

    -- Hide controls
    if instance.controls and instance.controls.container then
        instance.controls.container:SetHidden(true)
    end

    -- Remove from cache
    indicatorInstances[controlName] = nil
end
