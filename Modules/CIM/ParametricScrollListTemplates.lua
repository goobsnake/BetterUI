--[[
File: Modules/CIM/ParametricScrollListTemplates.lua
Purpose: Custom Scroll List implementations for BetterUI's Gamepad interfaces.
         Extends the native ZOS scroll list classes to add:
         - Custom gradients and fading (Vertical Lists)
         - Hybrid Mouse wheel support
         - Carousel Mode (Tab Bar): Items rotate circularly around a selection
         - Sub-lists (Nested menus)
Author: BetterUI Team
Last Modified: 2026-01-16
]]

-- Tab bar movement types (extends ZO_PARAMETRIC_MOVEMENT_TYPES)
-- Tab bar movement types (extends ZO_PARAMETRIC_MOVEMENT_TYPES)
ZO_TABBAR_MOVEMENT_TYPES =
{
    PAGE_FORWARD = ZO_PARAMETRIC_MOVEMENT_TYPES.LAST,
    PAGE_BACK = ZO_PARAMETRIC_MOVEMENT_TYPES.LAST + 1,
    PAGE_NAVIGATION_FAILED = ZO_PARAMETRIC_MOVEMENT_TYPES.LAST + 2
}

-- Sound mappings for list navigation
ZO_PARAMETRIC_SCROLL_MOVEMENT_SOUNDS =
{
    [ZO_PARAMETRIC_MOVEMENT_TYPES.MOVE_NEXT] = SOUNDS.GAMEPAD_MENU_DOWN,
    [ZO_PARAMETRIC_MOVEMENT_TYPES.MOVE_PREVIOUS] = SOUNDS.GAMEPAD_MENU_UP,
    [ZO_PARAMETRIC_MOVEMENT_TYPES.JUMP_NEXT] = SOUNDS.GAMEPAD_MENU_JUMP_DOWN,
    [ZO_PARAMETRIC_MOVEMENT_TYPES.JUMP_PREVIOUS] = SOUNDS.GAMEPAD_MENU_JUMP_UP,
    [ZO_TABBAR_MOVEMENT_TYPES.PAGE_FORWARD] = SOUNDS.GAMEPAD_PAGE_FORWARD,
    [ZO_TABBAR_MOVEMENT_TYPES.PAGE_BACK] = SOUNDS.GAMEPAD_PAGE_BACK,
    [ZO_TABBAR_MOVEMENT_TYPES.PAGE_NAVIGATION_FAILED] = SOUNDS.GAMEPAD_PAGE_NAVIGATION_FAILED,
}

--[[
Function: GamepadParametricScrollListPlaySound
Description: Plays navigation sound for scroll list movement.
param: movementType (number) - The type of movement (next, prev, jump, etc.).
]]
local function GamepadParametricScrollListPlaySound(movementType)
    PlaySound(ZO_PARAMETRIC_SCROLL_MOVEMENT_SOUNDS[movementType])
end

-- Scroll list orientation constants
PARAMETRIC_SCROLL_LIST_VERTICAL = true
PARAMETRIC_SCROLL_LIST_HORIZONTAL = false
BETTERUI_VERTICAL_PARAMETRIC_LIST_DEFAULT_FADE_GRADIENT_SIZE = 32
BETTERUI_HORIZONTAL_PARAMETRIC_LIST_DEFAULT_FADE_GRADIENT_SIZE = 32

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

--- Creates a new vertical parametric scroll list instance.
---
--- Purpose: Initializes the list with custom gradient logic.
--- Mechanics: Overrides EnsureValidGradient to apply top/bottom fades.
--- References: Used as base for BetterUI vertical lists.
---
--- @param ... any Arguments for ZO_ParametricScrollList:New.
--- @return table The new list instance.
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
                    selectedControlBufferStart = selectedControlBufferStart - self.headerSelectedPadding + DEFAULT_EXPECTED_HEADER_HEIGHT
                end
                local selectedControlBufferEnd = DEFAULT_EXPECTED_ENTRY_HEIGHT
                if self.alignToScreenCenterExpectedEntryHalfHeight then
                    selectedControlBufferEnd = self.alignToScreenCenterExpectedEntryHalfHeight * 2.0
                end
                
                -- Calculate fading gradients
                local MINIMUM_ALLOWED_FADE_GRADIENT = 32
                local gradientMaxStart = zo_max(listMid - listStart - selectedControlBufferStart, MINIMUM_ALLOWED_FADE_GRADIENT)
                local gradientMaxEnd = zo_max(listEnd - listMid - selectedControlBufferEnd, MINIMUM_ALLOWED_FADE_GRADIENT)
                local gradientStartSize = zo_min(gradientMaxStart, BETTERUI_VERTICAL_PARAMETRIC_LIST_DEFAULT_FADE_GRADIENT_SIZE)
                local gradientEndSize = zo_min(gradientMaxEnd, BETTERUI_VERTICAL_PARAMETRIC_LIST_DEFAULT_FADE_GRADIENT_SIZE)
                
                local FIRST_FADE_GRADIENT = 1
                local SECOND_FADE_GRADIENT = 2
                local GRADIENT_TEX_CORD_0 = 0
                local GRADIENT_TEX_CORD_1 = 1
                local GRADIENT_TEX_CORD_NEG_1 = -1
                
                self.scrollControl:SetFadeGradient(FIRST_FADE_GRADIENT, GRADIENT_TEX_CORD_0, GRADIENT_TEX_CORD_1, gradientStartSize)
                self.scrollControl:SetFadeGradient(SECOND_FADE_GRADIENT, GRADIENT_TEX_CORD_0, GRADIENT_TEX_CORD_NEG_1, gradientEndSize)
                
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
    ZO_ParametricScrollList.Initialize(self, control, PARAMETRIC_SCROLL_LIST_VERTICAL, ZO_GamepadOnDefaultScrollListActivatedChanged)
    self:SetHeaderPadding(GAMEPAD_HEADER_DEFAULT_PADDING, GAMEPAD_HEADER_SELECTED_PADDING)
    self:SetUniversalPostPadding(GAMEPAD_DEFAULT_POST_PADDING)
    self:SetPlaySoundFunction(GamepadParametricScrollListPlaySound)

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


-- ============================================================================
-- CLASS: BETTERUI_HorizontalScrollList_Gamepad
-- Basic Horizontal List (Non-Parametric) wrapper
-- ============================================================================
BETTERUI_HorizontalScrollList_Gamepad = ZO_HorizontalScrollList:Subclass()

-- ============================================================================
-- CLASS: BETTERUI_HorizontalScrollList_Gamepad
-- Basic Horizontal List (Non-Parametric) wrapper
-- ============================================================================
BETTERUI_HorizontalScrollList_Gamepad = ZO_HorizontalScrollList:Subclass()

--[[
Function: BETTERUI_HorizontalScrollList_Gamepad:New
Description: Creates a new horizontal scroll list instance.
param: ... (any) - Arguments for ZO_HorizontalScrollList:New.
return: table - The new list instance.
]]
function BETTERUI_HorizontalScrollList_Gamepad:New(...)
    return ZO_HorizontalScrollList.New(self, ...)
end

--[[
Function: BETTERUI_HorizontalScrollList_Gamepad:Initialize
Description: Initializes the horizontal scroll list.
param: control (table) - The list control.
param: templateName (string) - The row template name.
param: numVisibleEntries (number) - Number of visible entries.
param: setupFunction (function) - Sub-function to setup each entry.
param: equalityFunction (function) - Function to compare entries.
param: onCommitWithItemsFunction (function) - Callback on commit with items.
param: onClearedFunction (function) - Callback on list clear.
]]
function BETTERUI_HorizontalScrollList_Gamepad:Initialize(control, templateName, numVisibleEntries, setupFunction, equalityFunction, onCommitWithItemsFunction, onClearedFunction)
    ZO_HorizontalScrollList.Initialize(self, control, templateName, numVisibleEntries, setupFunction, equalityFunction, onCommitWithItemsFunction, onClearedFunction)
    self:SetActive(true)
    self.movementController = ZO_MovementController:New(MOVEMENT_CONTROLLER_DIRECTION_HORIZONTAL)
end

--[[
Function: BETTERUI_HorizontalScrollList_Gamepad:UpdateAnchors
Description: Updates the anchors and positions of the scroll list controls.
Rationale: Handles position interpolation and scaling for the 'selected' item effect.
Mechanism:
  - Iterates visible controls.
  - Calculates offsets based on primaryControlOffsetX.
  - Applies Scale effect to center item using Lerp/Ease.
  - Updates Arrow button visibility/enabled state.
param: primaryControlOffsetX (number) - Current X offset for the primary control.
param: initialUpdate (boolean) - True if this is the first update.
param: reselectingDuringRebuild (boolean) - True if reselecting.
]]
function BETTERUI_HorizontalScrollList_Gamepad:UpdateAnchors(primaryControlOffsetX, initialUpdate, reselectingDuringRebuild)
    if self.isUpdatingAnchors then return end
    self.isUpdatingAnchors = true

    local oldPrimaryControlOffsetX = self.lastPrimaryControlOffsetX or 0
    local oldVisibleIndex = zo_round(oldPrimaryControlOffsetX / self.controlEntryWidth)
    local newVisibleIndex = zo_round(primaryControlOffsetX / self.controlEntryWidth)

    local visibleIndicesChanged = oldVisibleIndex ~= newVisibleIndex
    local oldData = self.selectedData
    for i, control in ipairs(self.controls) do
        local index = self:CalculateOffsetIndex(i, newVisibleIndex)
        if not self.allowWrapping and (index >= #self.list or index < 0) then
            control:SetHidden(true)
        else
            control:SetHidden(false)

            if initialUpdate or visibleIndicesChanged then
                local dataIndex = self:CalculateDataIndexFromOffset(index)
                local selected = i == self.halfNumVisibleEntries + 1

                local data = self.list[dataIndex]
                if selected then
                    self.selectedData = data
                    if not reselectingDuringRebuild and self.selectionHighlightAnimation and not self.selectionHighlightAnimation:IsPlaying() then
                        self.selectionHighlightAnimation:PlayFromStart()
                    end
                    if not initialUpdate and not reselectingDuringRebuild and self.dragging then
                        self.onPlaySoundFunction(ZO_HORIZONTALSCROLLLIST_MOVEMENT_TYPES.INITIAL_UPDATE)
                    end
                end
                self.setupFunction(control, data, selected, reselectingDuringRebuild, self.enabled, self.selectedFromParent)
            end

            local offsetX = primaryControlOffsetX + index * self.controlEntryWidth
            control:SetAnchor(CENTER, self.control, CENTER, offsetX, 25)

            if self.minScale and self.maxScale then
                local amount = ZO_EaseInQuintic(zo_max(1.0 - zo_abs(offsetX) / (self.control:GetWidth() * .5), 0.0))
                control:SetScale(zo_lerp(self.minScale, self.maxScale, amount))
            end
        end
    end

    self.lastPrimaryControlOffsetX = primaryControlOffsetX

    self.leftArrow:SetEnabled(self.enabled and (self.allowWrapping or newVisibleIndex ~= 0))
    self.rightArrow:SetEnabled(self.enabled and (self.allowWrapping or newVisibleIndex ~= 1 - #self.list))

    self.isUpdatingAnchors = false

    if (self.selectedData ~= oldData or initialUpdate) and self.onSelectedDataChangedCallback then
        self.onSelectedDataChangedCallback(self.selectedData, oldData, reselectingDuringRebuild)
    end
end

--[[
Function: BETTERUI_HorizontalScrollList_Gamepad:SetOnActivatedChangedFunction
Description: Sets the callback for activation state changes.
param: onActivatedChangedFunction (function) - The callback.
]]
function BETTERUI_HorizontalScrollList_Gamepad:SetOnActivatedChangedFunction(onActivatedChangedFunction)
    self.onActivatedChangedFunction = onActivatedChangedFunction
    self.dirty = true
end

--[[
Function: BETTERUI_HorizontalScrollList_Gamepad:Commit
Description: Commits the list data and updates UI.
Rationale: Also handles Arrow visibility based on active state.
]]
function BETTERUI_HorizontalScrollList_Gamepad:Commit()
    ZO_HorizontalScrollList.Commit(self)

    local hideArrows = not self.active
    self.leftArrow:SetHidden(hideArrows)
    self.rightArrow:SetHidden(hideArrows)
end

--[[
Function: BETTERUI_HorizontalScrollList_Gamepad:SetActive
Description: Sets the active state of the list.
Rationale: Manages directional input activation and arrow visibility.
param: active (boolean) - True to activate.
]]
function BETTERUI_HorizontalScrollList_Gamepad:SetActive(active)
    if (self.active ~= active) or self.dirty then
        self.active = active
        self.dirty = false

        if self.active then
            DIRECTIONAL_INPUT:Activate(self)
            self.leftArrow:SetHidden(false)
            self.rightArrow:SetHidden(false)
        else
            DIRECTIONAL_INPUT:Deactivate(self)
            self.leftArrow:SetHidden(true)
            self.rightArrow:SetHidden(true)
        end

        if self.onActivatedChangedFunction then
            self.onActivatedChangedFunction(self, self.active)
        end
    end
end

--[[
Function: BETTERUI_HorizontalScrollList_Gamepad:Activate
Description: wrapper for SetActive(true).
]]
function BETTERUI_HorizontalScrollList_Gamepad:Activate()
    self:SetActive(true)
end

--[[
Function: BETTERUI_HorizontalScrollList_Gamepad:Deactivate
Description: wrapper for SetActive(false).
]]
function BETTERUI_HorizontalScrollList_Gamepad:Deactivate()
    self:SetActive(false)
end


-- ============================================================================
-- CLASS: BETTERUI_HorizontalParametricScrollList
-- Base class for horizontal parametric lists.
-- ============================================================================
BETTERUI_HorizontalParametricScrollList = ZO_ParametricScrollList:Subclass()
-- ============================================================================
-- CLASS: BETTERUI_HorizontalParametricScrollList
-- Base class for horizontal parametric lists.
-- ============================================================================
BETTERUI_HorizontalParametricScrollList = ZO_ParametricScrollList:Subclass()

--[[
Function: BETTERUI_HorizontalParametricScrollList:New
Description: Creates a new horizontal parametric scroll list.
param: control (table) - The list control.
param: onActivatedChangedFunction (function) - Callback for activation state changes.
param: onCommitWithItemsFunction (function) - Callback on commit with items.
param: onClearedFunction (function) - Callback on clear.
return: table - The new list instance.
]]
function BETTERUI_HorizontalParametricScrollList:New(control, onActivatedChangedFunction, onCommitWithItemsFunction, onClearedFunction)
    onActivatedChangedFunction = onActivatedChangedFunction or ZO_GamepadOnDefaultScrollListActivatedChanged
    local list = ZO_ParametricScrollList.New(self, control, PARAMETRIC_SCROLL_LIST_HORIZONTAL, onActivatedChangedFunction, onCommitWithItemsFunction, onClearedFunction)
    list:SetHeaderPadding(GAMEPAD_HEADER_DEFAULT_PADDING, GAMEPAD_HEADER_SELECTED_PADDING)
    list:SetPlaySoundFunction(GamepadParametricScrollListPlaySound)
    return list
end


-- ============================================================================
-- CLASS: BETTERUI_TabBarScrollList
-- The heart of BetterUI's category navigation using LB/RB.
-- Implements Carousel Mode where items rotate circularly.
-- ============================================================================
BETTERUI_TabBarScrollList = BETTERUI_HorizontalParametricScrollList:Subclass()

--[[
Function: BETTERUI_TabBarScrollList:New
Description: Creates a new tab bar scroll list instance with LB/RB navigation icons.
Rationale: Implements the "Carousel" header navigation (Circular Tab Bar).
Mechanism:
  1. Extends HorizontalParametricScrollList.
  2. Adds Left/Right shoulder button icons.
  3. Enables "Carousel Mode" (circular scrolling around a fixed selection).
  4. Sets up keybinds for shoulder navigation.
param: control (table) - The list control.
param: leftIcon (table) - The visual control for the left icon.
param: rightIcon (table) - The visual control for the right icon.
param: data (table) - Configuration data (attachedTo, parent, callbacks).
param: onActivatedChangedFunction (function) - Callback for activation changes.
param: onCommitWithItemsFunction (function) - Callback for commit.
param: onClearedFunction (function) - Callback for clear.
return: table - The new tab bar list instance.
]]
function BETTERUI_TabBarScrollList:New(control, leftIcon, rightIcon, data, onActivatedChangedFunction, onCommitWithItemsFunction, onClearedFunction)
    local list = BETTERUI_HorizontalParametricScrollList.New(self, control, onActivatedChangedFunction, onCommitWithItemsFunction, onClearedFunction)
    list:EnableAnimation(true)
    list:SetDirectionalInputEnabled(false) -- Standard directional input disabled, uses LB/RB
    list:SetHideUnselectedControls(false)

    local function CreateButtonIcon(name, parent, keycode, anchor)
        local buttonIcon = CreateControl(name, parent, CT_BUTTON)
        buttonIcon:SetNormalTexture(ZO_Keybindings_GetTexturePathForKey(keycode))
        buttonIcon:SetDimensions(ZO_TABBAR_ICON_WIDTH, ZO_TABBAR_ICON_HEIGHT)
        buttonIcon:SetAnchor(anchor, control, anchor)
        return buttonIcon
    end

    list.attachedTo = data.attachedTo
    list.parent = data.parent
    list.MoveNextCallback = data.onNext
    list.MovePrevCallback = data.onPrev

    list.leftIcon = leftIcon or CreateButtonIcon("$(parent)LeftIcon", control, KEY_GAMEPAD_LEFT_SHOULDER, LEFT)
    list.rightIcon = rightIcon or CreateButtonIcon("$(parent)RightIcon", control, KEY_GAMEPAD_RIGHT_SHOULDER, RIGHT)
    list.entryAnchors = { CENTER, CENTER }
    list:InitializeKeybindStripDescriptors()
    list.control = control
    list:SetPlaySoundFunction(GamepadParametricScrollListPlaySound)

    -- Enable Carousel Mode:
    -- In this mode, the selected item stays fixed (usually to the left), and the list contents
    -- rotate around it. Allows for seamless circular navigation through categories.
    list.carouselMode = true
    list.carouselStartOffset = BETTERUI_CAROUSEL_START_OFFSET
    list.carouselItemSpacing = BETTERUI_CAROUSEL_ITEM_SPACING
    list.carouselVerticalOffset = BETTERUI_CAROUSEL_VERTICAL_OFFSET

    return list
end

--[[
Function: BETTERUI_TabBarScrollList:UpdateAnchors
Description: Override UpdateAnchors to implement CAROUSEL rotation behavior.
Rationale: Positions list items in a circular carousel or linear list.
Mechanism:
  - If Carousel Mode: Positions items relative to the selected item (Center), wrapping around.
  - If Normal Mode: Falls back to ZO_ParametricScrollList logic (Camera moves).
param: continousTargetOffset (number) - The floating point index of the selection.
param: initialUpdate (boolean) - True if this is the first update.
param: reselectingDuringRebuild (boolean) - True if reselecting.
param: blockSelectionChangedCallback (boolean) - True to supress callbacks.
]]
function BETTERUI_TabBarScrollList:UpdateAnchors(continousTargetOffset, initialUpdate, reselectingDuringRebuild, blockSelectionChangedCallback)
    if not self.carouselMode then
        -- Fallback to default parametric list behavior if carousel is disabled
        return ZO_ParametricScrollList.UpdateAnchors(self, continousTargetOffset, initialUpdate, reselectingDuringRebuild, blockSelectionChangedCallback)
    end

    self.visibleControls, self.unseenControls = self.unseenControls, self.visibleControls
    ZO_ClearTable(self.visibleControls)

    local numItems = #self.dataList
    if numItems == 0 then return end

    local newSelectedDataIndex = zo_round(continousTargetOffset)
    local selectedDataChanged = self.selectedIndex ~= newSelectedDataIndex
    local oldSelectedData = self.selectedData

    -- Play sound on selection change
    if self.soundEnabled and not self.jumping and selectedDataChanged and oldSelectedData then
        if newSelectedDataIndex > self.selectedIndex then
            self.onPlaySoundFunction(ZO_PARAMETRIC_MOVEMENT_TYPES.MOVE_NEXT)
        else
            self.onPlaySoundFunction(ZO_PARAMETRIC_MOVEMENT_TYPES.MOVE_PREVIOUS)
        end
    end

    self.selectedData = self:GetDataForDataIndex(newSelectedDataIndex)
    self.selectedIndex = newSelectedDataIndex

    -- Calculate animation offset for smooth transitions
    -- This interpolates positions as continousTargetOffset changes (e.g. 1.0 -> 1.5 -> 2.0)
    local baseOffset = newSelectedDataIndex - continousTargetOffset
    local animationOffset = baseOffset * self.carouselItemSpacing

    -- Position items in carousel order starting from the selected item
    local currentOffset = self.carouselStartOffset + animationOffset

    for i = 0, numItems - 1 do
        -- Calculate the actual data index in circular order starting from selected
        local dataIndex = ((newSelectedDataIndex - 1 + i) % numItems) + 1

        local control, justCreated = self:AcquireControlAtDataIndex(dataIndex)
        self.unseenControls[control] = nil
        self.visibleControls[control] = true

        local isSelected = (dataIndex == newSelectedDataIndex)

        if justCreated or selectedDataChanged or initialUpdate then
            self:RunSetupOnControl(control, dataIndex, isSelected, reselectingDuringRebuild, self.enabled, self.active)
        end

        -- Apply parametric function (scaling/fading) if it exists for this data type
        local parametricFunction = self:GetParametricFunctionForDataIndex(dataIndex)
        if parametricFunction then
            parametricFunction(control, i, baseOffset)
        end

        -- Position the control horizontally, with vertical offset to align with LB/RB icons
        local verticalOffset = self.carouselVerticalOffset or 5
        control:ClearAnchors()
        control:SetAnchor(LEFT, self.scrollControl, LEFT, currentOffset, verticalOffset)

        -- Move offset for next item
        local controlWidth = control:GetWidth()
        if controlWidth == 0 then controlWidth = self.carouselItemSpacing end
        currentOffset = currentOffset + controlWidth
    end

    -- Release unused controls (items no longer visible, though usually all are in carousel)
    for control in pairs(self.unseenControls) do
        self:ReleaseControl(control)
    end
    ZO_ClearTable(self.unseenControls)

    -- Fire selection changed callback
    if (self.selectedData ~= oldSelectedData or initialUpdate) and not blockSelectionChangedCallback then
        -- Fire generic ZO callback
        self:FireCallbacks("SelectedDataChanged", self, self.selectedData, oldSelectedData, nil, self.targetSelectedIndex)
        -- Fire our specific custom callback property
        if self.onSelectedDataChangedCallback then
            self.onSelectedDataChangedCallback(self, self.selectedData, oldSelectedData, reselectingDuringRebuild)
        end
    end
end

--[[
Function: BETTERUI_TabBarScrollList:Activate
Description: Activates the tab bar and its keybinds.
]]
function BETTERUI_TabBarScrollList:Activate()
    KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor)
    BETTERUI_HorizontalParametricScrollList.Activate(self)
end

--[[
Function: BETTERUI_TabBarScrollList:Deactivate
Description: Deactivates the tab bar and removes keybinds.
]]
function BETTERUI_TabBarScrollList:Deactivate()
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor)
    BETTERUI_HorizontalParametricScrollList.Deactivate(self)
end

-- Custom Callback Management
-- Override these to handle the dual-callback nature of standard ZO lists vs Carousel mode
--[[
Function: BETTERUI_TabBarScrollList:SetOnSelectedDataChangedCallback
Description: Sets the data change callback.
Rationale: Uses a wrapper to filter out intermediate 'false' returns during animation if not in carousel mode.
param: callback (function) - The user callback.
]]
function BETTERUI_TabBarScrollList:SetOnSelectedDataChangedCallback(callback)
    self.onSelectedDataChangedCallback = callback -- For Carousel mode

    -- Clean up old wrapper
    if self._zo_selectedDataChangedWrapper then
        self:UnregisterCallback("SelectedDataChanged", self._zo_selectedDataChangedWrapper)
        self._zo_selectedDataChangedWrapper = nil
    end

    -- Register wrapper for Non-Carousel mode (acting as standard list)
    if callback then
        self._zo_selectedDataChangedWrapper = function(list, selectedData, oldSelectedData, reachedTarget, targetSelectedIndex)
            if not self.carouselMode then
                if reachedTarget == false then return end -- wait for animation end
                callback(list, selectedData, oldSelectedData, false)
            end
        end
        self:RegisterCallback("SelectedDataChanged", self._zo_selectedDataChangedWrapper)
    end
end

--[[
Function: BETTERUI_TabBarScrollList:RemoveOnSelectedDataChangedCallback
Description: Removes the data change callback.
]]
function BETTERUI_TabBarScrollList:RemoveOnSelectedDataChangedCallback(callback)
    self.onSelectedDataChangedCallback = nil
    if self._zo_selectedDataChangedWrapper then
        self:UnregisterCallback("SelectedDataChanged", self._zo_selectedDataChangedWrapper)
        self._zo_selectedDataChangedWrapper = nil
    end
end

--[[
Function: BETTERUI_TabBarScrollList:InitializeKeybindStripDescriptors
Description: Sets up LB/RB keybinds.
]]
function BETTERUI_TabBarScrollList:InitializeKeybindStripDescriptors()
    self.keybindStripDescriptor =
    {
        {
            keybind = "UI_SHORTCUT_LEFT_SHOULDER",
            ethereal = true,
            callback = function()
                if self.active then self:MovePrevious(true) end
            end,
        },
        {
            keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
            ethereal = true,
            callback = function()
                if self.active then self:MoveNext(true) end
            end,
        },
    }
end

--[[
Function: BETTERUI_TabBarScrollList:Commit
Description: Commits changes.
Rationale: Hides nav arrows if only 1 item exists.
]]
function BETTERUI_TabBarScrollList:Commit(dontReselect)
    -- Hide arrows if only 1 item
    if #self.dataList > 1 then
        self.leftIcon:SetHidden(false)
        self.rightIcon:SetHidden(false)
    else
        self.leftIcon:SetHidden(true)
        self.rightIcon:SetHidden(true)
    end
    BETTERUI_HorizontalParametricScrollList.Commit(self, dontReselect)
    self:RefreshPips()
end

--[[
Function: BETTERUI_TabBarScrollList:SetPipsEnabled
Description: Enables/Disables Pip (Dot) indicators.
param: enabled (boolean) - True to enable.
param: divider (table) - The control to anchor pips to.
]]
function BETTERUI_TabBarScrollList:SetPipsEnabled(enabled, divider)
    self.pipsEnabled = enabled
    if not divider then
        divider = self.control:GetNamedChild("Divider")
    end
    if not self.pips and enabled then
        self.pips = ZO_GamepadPipCreator:New(divider)
    end
    self:RefreshPips()
end

--[[
Function: BETTERUI_TabBarScrollList:RefreshPips
Description: Updates Pip indicators based on selection.
]]
function BETTERUI_TabBarScrollList:RefreshPips()
    if not self.pipsEnabled then
        if self.pips then self.pips:RefreshPips() end
        return
    end
    local selectedIndex = self.targetSelectedIndex or self.selectedIndex
    local numPips = 0
    local selectedPipIndex = 0
    for i = 1,#self.dataList do
        if self.dataList[i].canSelect ~= false then
            numPips = numPips + 1
            local active = (selectedIndex == i)
            if active then
                selectedPipIndex = numPips
            end
        end
    end
    self.pips:RefreshPips(numPips, selectedPipIndex)
end

--[[
Function: BETTERUI_TabBarScrollList:SetSelectedIndex
Description: Sets selection with animation.
Mechanism: Updates pips and triggers UpdateAnchors if in Carousel mode.
]]
function BETTERUI_TabBarScrollList:SetSelectedIndex(selectedIndex, allowEvenIfDisabled, forceAnimation)
    -- BetterUI Fix: Capture old data BEFORE calling base class (which updates selectedData)
    local oldSelectedData = self.selectedData
    local oldSelectedIndex = self.selectedIndex
    
    BETTERUI_HorizontalParametricScrollList.SetSelectedIndex(self, selectedIndex, allowEvenIfDisabled, forceAnimation)
    self:RefreshPips()
    if self.carouselMode and self.UpdateAnchors then
        self:UpdateAnchors(selectedIndex, false, false)
    end
    
    -- BetterUI Fix: Fire callback directly if selection actually changed
    -- This is necessary because the base class updates selectedData before UpdateAnchors,
    -- causing the "selectedData ~= oldSelectedData" check to fail
    if self.selectedIndex ~= oldSelectedIndex and self.onSelectedDataChangedCallback then
        self.onSelectedDataChangedCallback(self, self.selectedData, oldSelectedData, false)
    end
end

--[[
Function: BETTERUI_TabBarScrollList:SetSelectedIndexWithoutAnimation
Description: Sets selection immediately without animation.
]]
function BETTERUI_TabBarScrollList:SetSelectedIndexWithoutAnimation(selectedIndex, allowEvenIfDisabled, dontCallSelectedDataChangedCallback)
    ZO_ParametricScrollList.SetSelectedIndexWithoutAnimation(self, selectedIndex, allowEvenIfDisabled, dontCallSelectedDataChangedCallback)
    self:RefreshPips()
    if self.carouselMode and self.UpdateAnchors then
        self:UpdateAnchors(selectedIndex, true, false)
    end
end

--[[
Function: BETTERUI_TabBarScrollList:MovePrevious
Description: Moves to previous item.
Rationale: Handles wrapping (First -> Last).
return: boolean - True if successful.
]]
function BETTERUI_TabBarScrollList:MovePrevious(allowWrapping, suppressFailSound)
    ZO_ConveyorSceneFragment_SetMovingBackward()
    local succeeded = ZO_ParametricScrollList.MovePrevious(self)
    if not succeeded and allowWrapping then
        ZO_ConveyorSceneFragment_SetMovingForward()
        self:SetLastIndexSelected() -- Wrap to last
        succeeded = true
    end
    if succeeded then
        self.onPlaySoundFunction(ZO_TABBAR_MOVEMENT_TYPES.PAGE_BACK)
        if self.carouselMode and self.UpdateAnchors then
            self:UpdateAnchors(self.targetSelectedIndex or self.selectedIndex, false, false)
        end
    elseif not suppressFailSound then
        self.onPlaySoundFunction(ZO_TABBAR_MOVEMENT_TYPES.PAGE_NAVIGATION_FAILED)
    end
    if(self.MovePrevCallback ~= nil) then self.MovePrevCallback(self.parent, succeeded) end
    return succeeded
end

--[[
Function: BETTERUI_TabBarScrollList:MoveNext
Description: Moves to next item.
Rationale: Handles wrapping (Last -> First).
return: boolean - True if successful.
]]
function BETTERUI_TabBarScrollList:MoveNext(allowWrapping, suppressFailSound)
    ZO_ConveyorSceneFragment_SetMovingForward()
    local succeeded = ZO_ParametricScrollList.MoveNext(self)
    if not succeeded and allowWrapping then
        ZO_ConveyorSceneFragment_SetMovingBackward()
        ZO_ParametricScrollList.SetFirstIndexSelected(self) -- Wrap to first
        succeeded = true
    end
    if succeeded then
        self.onPlaySoundFunction(ZO_TABBAR_MOVEMENT_TYPES.PAGE_FORWARD)
        if self.carouselMode and self.UpdateAnchors then
            self:UpdateAnchors(self.targetSelectedIndex or self.selectedIndex, false, false)
        end
    elseif not suppressFailSound then
        self.onPlaySoundFunction(ZO_TABBAR_MOVEMENT_TYPES.PAGE_NAVIGATION_FAILED)
    end
    if(self.MoveNextCallback ~= nil) then self.MoveNextCallback(self.parent, succeeded) end
    return succeeded
end

-- ============================================================================
-- EVENT HANDLERS (Global)
-- Called from XML via OnClicked, etc.
-- ============================================================================

-- ============================================================================
-- EVENT HANDLERS (Global)
-- Called from XML via OnClicked, etc.
-- ============================================================================

--[[
Function: BETTERUI_TabBar_OnLeftIconClicked
Description: Global handler for Left Icon click.
param: buttonControl (table) - The control clicked.
]]
function BETTERUI_TabBar_OnLeftIconClicked(buttonControl)
    local tabBar = buttonControl:GetParent()
    local scrollList = tabBar and tabBar.scrollList
    if scrollList and scrollList.MovePrevious then
        scrollList:MovePrevious(true)
    end
end

--[[
Function: BETTERUI_TabBar_OnRightIconClicked
Description: Global handler for Right Icon click.
param: buttonControl (table) - The control clicked.
]]
function BETTERUI_TabBar_OnRightIconClicked(buttonControl)
    local tabBar = buttonControl:GetParent()
    local scrollList = tabBar and tabBar.scrollList
    if scrollList and scrollList.MoveNext then
        scrollList:MoveNext(true)
    end
end

--[[
Function: BETTERUI_TabBar_OnCategoryIconClicked
Description: Global handler for direct category icon click.
Rationale: Allows clicking directly on a category icon to jump to it.
Mechanism:
1. Identifies the parent scrollList.
2. Finds the data index for the clicked control.
3. Special Case: If in Inventory scene, dispatches directly to GAMEPAD_INVENTORY:OnCategoryClicked to ensure reliable switching.
4. Default: Calls scrollList:SetSelectedIndex.
param: categoryControl (table) - The UI control that was clicked.
]]
function BETTERUI_TabBar_OnCategoryIconClicked(categoryControl)
    local scrollList = nil
    -- Traverse up to find the scrollList owner
    local parent = categoryControl:GetParent()
    while parent do
        if parent.scrollList then
            scrollList = parent.scrollList
            break
        end
        parent = parent:GetParent()
    end

    if not scrollList or not scrollList.dataList then return end

    -- Check guard (prevents rapid jumps if busy)
    if scrollList.IsNavigationGuarded and scrollList:IsNavigationGuarded() then
        return
    end

    -- Match control to data to set index
    local foundIndex = nil
    for i, data in ipairs(scrollList.dataList) do
        local control = scrollList:GetControlFromData(data)
        if control == categoryControl then
            foundIndex = i
            break
        end
    end
    
    if foundIndex then
        if scrollList.SetNavigationGuard then
            scrollList:SetNavigationGuard()
        end

        -- BetterUI Fix: Explicitly handle Inventory scene to ensure reliable switching
        if SCENE_MANAGER and SCENE_MANAGER:IsShowing("gamepad_inventory_root") and GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.OnCategoryClicked then
            GAMEPAD_INVENTORY:OnCategoryClicked(foundIndex)
            -- Sync the visual tab bar to match the logic update
            scrollList:SetSelectedIndexWithoutAnimation(foundIndex, true, true)
            return
        end

        -- Standard Behavior: Use SetSelectedIndex with callback enabled
        scrollList:SetSelectedIndex(foundIndex, true, false)
    end
end


-- ============================================================================
-- CLASS: BETTERUI_VerticalParametricScrollListSubList
-- Nested Menu Support (e.g., sub-categories)
-- ============================================================================
local SUB_LIST_CENTER_OFFSET = -50
BETTERUI_VerticalParametricScrollListSubList = BETTERUI_VerticalParametricScrollList:Subclass()

--[[
Function: BETTERUI_VerticalParametricScrollListSubList:New
Description: Creates a new sub-list (nested menu) instance.
param: control (table) - The list control.
param: parentList (table) - The parent list that spawned this.
param: parentKeybinds (table) - Keybinds to restore when exiting.
param: onDataChosen (function) - Callback when an item is chosen.
return: table - The new sub-list instance.
]]
function BETTERUI_VerticalParametricScrollListSubList:New(control, parentList, parentKeybinds, onDataChosen)
    local manager = BETTERUI_VerticalParametricScrollList.New(self, control, parentList, parentKeybinds, onDataChosen)
    return manager
end

--[[
Function: BETTERUI_VerticalParametricScrollListSubList:Initialize
Description: Initializes the sub-list.
Rationale: Hides initially and sets offset.
]]
function BETTERUI_VerticalParametricScrollListSubList:Initialize(control, parentList, parentKeybinds, onDataChosen)
    BETTERUI_VerticalParametricScrollList.Initialize(self, control)
    self.parentList = parentList
    self.parentKeybinds = parentKeybinds
    self.onDataChosen = onDataChosen
    self:InitializeKeybindStrip()
    self.control:SetHidden(true)
    self:SetFixedCenterOffset(SUB_LIST_CENTER_OFFSET)
end

--[[
Function: BETTERUI_VerticalParametricScrollListSubList:Commit
Description: Commits selection and triggers callback.
]]
function BETTERUI_VerticalParametricScrollListSubList:Commit(dontReselect)
    ZO_ParametricScrollList.Commit(self, dontReselect)
    self:UpdateAnchors(self.targetSelectedIndex)
    self.onDataChosen(self:GetTargetData())
end

--[[
Function: BETTERUI_VerticalParametricScrollListSubList:CancelSelection
Description: Cancels selection and reverts to entry index.
]]
function BETTERUI_VerticalParametricScrollListSubList:CancelSelection()
    local indexToReturnTo = zo_clamp(self.indexOnOpen, 1, #self.dataList)
    self.targetSelectedIndex = indexToReturnTo
    self:UpdateAnchors(indexToReturnTo)
    self.onDataChosen(self:GetDataForDataIndex(indexToReturnTo))
end

--[[
Function: BETTERUI_VerticalParametricScrollListSubList:InitializeKeybindStrip
Description: Sets up navigation keybinds (Enter/Back).
]]
function BETTERUI_VerticalParametricScrollListSubList:InitializeKeybindStrip()
    local function OnEntered()
        self.onDataChosen(self:GetTargetData())
        self.didSelectEntry = true
        self:Deactivate()
    end
    local function OnBack()
        self:Deactivate()
    end
    self.keybindStripDescriptor = {}
    ZO_Gamepad_AddForwardNavigationKeybindDescriptors(self.keybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON, OnEntered)
    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.keybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON, OnBack)
    ZO_Gamepad_AddListTriggerKeybindDescriptors(self.keybindStripDescriptor, self)
end

--[[
Function: BETTERUI_VerticalParametricScrollListSubList:Activate
Description: Shows and activates the sub-list.
Mechanism: Swaps keybinds from parent to self.
]]
function BETTERUI_VerticalParametricScrollListSubList:Activate()
    self.parentList:Deactivate()
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.parentKeybinds)
    BETTERUI_VerticalParametricScrollList.Activate(self)
    KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor)
    self.control:SetHidden(false)
    self.indexOnOpen = self.selectedIndex
    self.didSelectEntry = false
end

--[[
Function: BETTERUI_VerticalParametricScrollListSubList:Deactivate
Description: Hides and deactivates the sub-list.
Mechanism: Restores parent keybinds and focus.
]]
function BETTERUI_VerticalParametricScrollListSubList:Deactivate()
    if not self.active then return end

    if self.active and not self.didSelectEntry then
        self:CancelSelection()
    end
    BETTERUI_VerticalParametricScrollList.Deactivate(self)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor)
    self.parentList:Activate()
    KEYBIND_STRIP:AddKeybindButtonGroup(self.parentKeybinds)
    self.control:SetHidden(true)
end


-- ============================================================================
-- CLASS: BETTERUI_Gamepad_ParametricList_Screen
-- Enhanced Gamepad List Screen Wrapper.
-- Contains Header, HeaderFragment, List, and basic logic.
-- ============================================================================
BETTERUI_Gamepad_ParametricList_Screen = ZO_Gamepad_ParametricList_Screen:Subclass()

--[[
Function: BETTERUI_Gamepad_ParametricList_Screen:New
Description: Creates a new Gamepad Parametric List Screen.
return: table - The new screen instance.
]]
function BETTERUI_Gamepad_ParametricList_Screen:New(...)
    local object = ZO_Gamepad_ParametricList_Screen.New(self)
    object:Initialize(...)
    return object
end

--[[
Function: BETTERUI_Gamepad_ParametricList_Screen:Initialize
Description: Initializes the screen.
param: control (table) - The screen control.
param: createTabBar (boolean) - Whether to create a tab bar (unused here, layout based).
param: activateOnShow (boolean) - Whether to activate list when shown.
param: scene (object) - The scene object to associate.
]]
function BETTERUI_Gamepad_ParametricList_Screen:Initialize(control, createTabBar, activateOnShow, scene)
    control.owner = self
    self.control = control

    local mask = control:GetNamedChild("Mask")
    local container = mask:GetNamedChild("Container")
    control.container = container

    self.activateOnShow = (activateOnShow ~= false) -- nil should be true
    self:SetScene(scene)

    local headerContainer = container:GetNamedChild("HeaderContainer")
    control.header = headerContainer.header
    self.headerFragment = ZO_ConveyorSceneFragment:New(headerContainer, ALWAYS_ANIMATE)

    self.header = control.header

    self.updateCooldownMS = 0

    self.lists = {}
    self:AddList("Main")
    self._currentList = nil
    self.addListTriggerKeybinds = true
    self.listTriggerKeybinds = nil
    self.listTriggerHeaderComparator = nil

    self:InitializeKeybindStripDescriptors()

    self.dirty = true
end

function BETTERUI_Gamepad_ParametricList_Screen:SetListsUseTriggerKeybinds(addListTriggerKeybinds, optionalHeaderComparator)
    self.addListTriggerKeybinds = addListTriggerKeybinds
    self.listTriggerHeaderComparator = optionalHeaderComparator

    if(not addListTriggerKeybinds) then
        self:TryRemoveListTriggers()
    end
end
