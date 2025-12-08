-- BetterUI Parametric Scroll List Templates
-- Custom scroll list implementations for gamepad UI
-- Based on ZO_GamepadParametricScrollListTemplates with enhanced functionality

-- Tab bar movement types (extends ZO_PARAMETRIC_MOVEMENT_TYPES)
ZO_TABBAR_MOVEMENT_TYPES =
{
    PAGE_FORWARD = ZO_PARAMETRIC_MOVEMENT_TYPES.LAST,
    PAGE_BACK = ZO_PARAMETRIC_MOVEMENT_TYPES.LAST + 1,
    PAGE_NAVIGATION_FAILED = ZO_PARAMETRIC_MOVEMENT_TYPES.LAST + 2
}
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

-- Plays navigation sound for scroll list movement
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

local function GetControlDimensionForMode(mode, control)
    return mode == PARAMETRIC_SCROLL_LIST_VERTICAL and control:GetHeight() or control:GetWidth()
end

local function GetStartOfControl(mode, control)
    return mode == PARAMETRIC_SCROLL_LIST_VERTICAL and control:GetTop() or control:GetLeft()
end
local function GetEndOfControl(mode, control)
    return mode == PARAMETRIC_SCROLL_LIST_VERTICAL and control:GetBottom() or control:GetRight()
end


BETTERUI_VerticalParametricScrollList = ZO_ParametricScrollList:Subclass()
--- Creates a new vertical parametric scroll list instance
function BETTERUI_VerticalParametricScrollList:New(...)
    local list = ZO_ParametricScrollList.New(self, ...)

    list.EnsureValidGradient = function(self)
        if self.validateGradient and self.validGradientDirty then
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
                -- Have some small minimum effect
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
            end
            self.validGradientDirty = false
        end
    end
    return list
end

--- Initializes the vertical parametric scroll list with default settings
function BETTERUI_VerticalParametricScrollList:Initialize(control)
    ZO_ParametricScrollList.Initialize(self, control, PARAMETRIC_SCROLL_LIST_VERTICAL, ZO_GamepadOnDefaultScrollListActivatedChanged)
    self:SetHeaderPadding(GAMEPAD_HEADER_DEFAULT_PADDING, GAMEPAD_HEADER_SELECTED_PADDING)
    self:SetUniversalPostPadding(GAMEPAD_DEFAULT_POST_PADDING)
    self:SetPlaySoundFunction(GamepadParametricScrollListPlaySound)

    self.alignToScreenCenterExpectedEntryHalfHeight = 30
end

BETTERUI_VerticalItemParametricScrollList = BETTERUI_VerticalParametricScrollList:Subclass()
--- Creates a new vertical item parametric scroll list instance
function BETTERUI_VerticalItemParametricScrollList:New(control)
    local list = BETTERUI_VerticalParametricScrollList.New(self, control)
    list:SetUniversalPostPadding(GAMEPAD_DEFAULT_POST_PADDING)
    return list
end

BETTERUI_HorizontalScrollList_Gamepad = ZO_HorizontalScrollList:Subclass()

--- Creates a new horizontal scroll list for gamepad
function BETTERUI_HorizontalScrollList_Gamepad:New(...)
    return ZO_HorizontalScrollList.New(self, ...)
end

--- Initializes the horizontal scroll list with template and functions
function BETTERUI_HorizontalScrollList_Gamepad:Initialize(control, templateName, numVisibleEntries, setupFunction, equalityFunction, onCommitWithItemsFunction, onClearedFunction)
    ZO_HorizontalScrollList.Initialize(self, control, templateName, numVisibleEntries, setupFunction, equalityFunction, onCommitWithItemsFunction, onClearedFunction)
    self:SetActive(true)
    self.movementController = ZO_MovementController:New(MOVEMENT_CONTROLLER_DIRECTION_HORIZONTAL)
end

--- Updates the anchors and positions of the scroll list controls
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

--- Sets the callback function for when activation state changes
function BETTERUI_HorizontalScrollList_Gamepad:SetOnActivatedChangedFunction(onActivatedChangedFunction)
    self.onActivatedChangedFunction = onActivatedChangedFunction
    self.dirty = true
end

--- Commits the scroll list changes and updates arrow visibility
function BETTERUI_HorizontalScrollList_Gamepad:Commit()
    ZO_HorizontalScrollList.Commit(self)

    local hideArrows = not self.active
    self.leftArrow:SetHidden(hideArrows)
    self.rightArrow:SetHidden(hideArrows)
end

--- Sets the active state of the scroll list, activating/deactivating directional input
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

function BETTERUI_HorizontalScrollList_Gamepad:Activate()
    self:SetActive(true)
end

function BETTERUI_HorizontalScrollList_Gamepad:Deactivate()
    self:SetActive(false)
end

BETTERUI_HorizontalParametricScrollList = ZO_ParametricScrollList:Subclass()
--- Creates a new horizontal parametric scroll list instance
function BETTERUI_HorizontalParametricScrollList:New(control, onActivatedChangedFunction, onCommitWithItemsFunction, onClearedFunction)
    onActivatedChangedFunction = onActivatedChangedFunction or ZO_GamepadOnDefaultScrollListActivatedChanged
    local list = ZO_ParametricScrollList.New(self, control, PARAMETRIC_SCROLL_LIST_HORIZONTAL, onActivatedChangedFunction, onCommitWithItemsFunction, onClearedFunction)
    list:SetHeaderPadding(GAMEPAD_HEADER_DEFAULT_PADDING, GAMEPAD_HEADER_SELECTED_PADDING)
    list:SetPlaySoundFunction(GamepadParametricScrollListPlaySound)
    return list
end

BETTERUI_TabBarScrollList = BETTERUI_HorizontalParametricScrollList:Subclass()
--- Creates a new tab bar scroll list instance with navigation icons
function BETTERUI_TabBarScrollList:New(control, leftIcon, rightIcon, data, onActivatedChangedFunction, onCommitWithItemsFunction, onClearedFunction)
    local list = BETTERUI_HorizontalParametricScrollList.New(self, control, onActivatedChangedFunction, onCommitWithItemsFunction, onClearedFunction)
    list:EnableAnimation(true)
    list:SetDirectionalInputEnabled(false)
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
    
    -- Enable carousel mode: selected item stays at left, items rotate in order
    -- Default values from BetterUI.CONST.lua can be overridden per-context via carouselConfig
    list.carouselMode = true
    list.carouselStartOffset = BETTERUI_CAROUSEL_START_OFFSET
    list.carouselItemSpacing = BETTERUI_CAROUSEL_ITEM_SPACING
    list.carouselVerticalOffset = BETTERUI_CAROUSEL_VERTICAL_OFFSET
    
    return list
end

--- Override UpdateAnchors to implement carousel rotation behavior
--- In carousel mode, the selected item is always positioned at the left (after LB icon),
--- and other items are arranged in circular order to the right
function BETTERUI_TabBarScrollList:UpdateAnchors(continousTargetOffset, initialUpdate, reselectingDuringRebuild, blockSelectionChangedCallback)
    if not self.carouselMode then
        -- Use default behavior if carousel mode is disabled
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
        
        -- Apply parametric function if exists
        local parametricFunction = self:GetParametricFunctionForDataIndex(dataIndex)
        if parametricFunction then
            parametricFunction(control, i, baseOffset)
        end
        
        -- Position the control horizontally, with vertical offset to align with LB/RB icons
        local verticalOffset = self.carouselVerticalOffset or 5
        control:ClearAnchors()
        control:SetAnchor(LEFT, self.scrollControl, LEFT, currentOffset, verticalOffset)
        
        -- Move to next position
        local controlWidth = control:GetWidth()
        if controlWidth == 0 then controlWidth = self.carouselItemSpacing end
        currentOffset = currentOffset + controlWidth
    end
    
    -- Release unused controls
    for control in pairs(self.unseenControls) do
        self:ReleaseControl(control)
    end
    ZO_ClearTable(self.unseenControls)
    
    -- Fire selection changed callback
    if (self.selectedData ~= oldSelectedData or initialUpdate) and not blockSelectionChangedCallback then
        self:FireCallbacks("SelectedDataChanged", self, self.selectedData, oldSelectedData, nil, self.targetSelectedIndex)
        if self.onSelectedDataChangedCallback then
            self.onSelectedDataChangedCallback(self, self.selectedData, oldSelectedData, reselectingDuringRebuild)
        end
    end
end
function BETTERUI_TabBarScrollList:Activate()
    KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor)
    BETTERUI_HorizontalParametricScrollList.Activate(self)
end
function BETTERUI_TabBarScrollList:Deactivate()
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor)
    BETTERUI_HorizontalParametricScrollList.Deactivate(self)
end
function BETTERUI_TabBarScrollList:InitializeKeybindStripDescriptors()
    self.keybindStripDescriptor =
    {
        {
            keybind = "UI_SHORTCUT_LEFT_SHOULDER",
            ethereal = true,
            callback = function()
                if self.active then
                    self:MovePrevious(true)
                end
            end,
        },
        {
            keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
            ethereal = true,
            callback = function()
                if self.active then
                    self:MoveNext(true)
                end
            end,
        },
    }
end
function BETTERUI_TabBarScrollList:Commit(dontReselect)
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
function BETTERUI_TabBarScrollList:SetPipsEnabled(enabled, divider)
    self.pipsEnabled = enabled
    if not divider then
        -- There is a default divider in the tabbar control
        divider = self.control:GetNamedChild("Divider")
    end
    if not self.pips and enabled then
        self.pips = ZO_GamepadPipCreator:New(divider)
    end
    self:RefreshPips()
end
function BETTERUI_TabBarScrollList:RefreshPips()
    if not self.pipsEnabled then
        if self.pips then
            self.pips:RefreshPips()
        end
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

function BETTERUI_TabBarScrollList:SetSelectedIndex(selectedIndex, allowEvenIfDisabled, forceAnimation)
    BETTERUI_HorizontalParametricScrollList.SetSelectedIndex(self, selectedIndex, allowEvenIfDisabled, forceAnimation)
    self:RefreshPips()
    -- Force carousel visual update after index change
    if self.carouselMode and self.UpdateAnchors then
        self:UpdateAnchors(selectedIndex, false, false)
    end
end

function BETTERUI_TabBarScrollList:SetSelectedIndexWithoutAnimation(selectedIndex, allowEvenIfDisabled, dontCallSelectedDataChangedCallback)
    ZO_ParametricScrollList.SetSelectedIndexWithoutAnimation(self, selectedIndex, allowEvenIfDisabled, dontCallSelectedDataChangedCallback)
    self:RefreshPips()
    -- Force carousel visual update after index change
    if self.carouselMode and self.UpdateAnchors then
        self:UpdateAnchors(selectedIndex, true, false)
    end
end

function BETTERUI_TabBarScrollList:MovePrevious(allowWrapping, suppressFailSound)
    ZO_ConveyorSceneFragment_SetMovingBackward()
    local succeeded = ZO_ParametricScrollList.MovePrevious(self)
    if not succeeded and allowWrapping then
        ZO_ConveyorSceneFragment_SetMovingForward()
        self:SetLastIndexSelected() --Wrap
        succeeded = true
    end
    if succeeded then
        self.onPlaySoundFunction(ZO_TABBAR_MOVEMENT_TYPES.PAGE_BACK)
        -- Force carousel visual update after movement
        if self.carouselMode and self.UpdateAnchors then
            self:UpdateAnchors(self.targetSelectedIndex or self.selectedIndex, false, false)
        end
    elseif not suppressFailSound then
        self.onPlaySoundFunction(ZO_TABBAR_MOVEMENT_TYPES.PAGE_NAVIGATION_FAILED)
    end
    if(self.MovePrevCallback ~= nil) then self.MovePrevCallback(self.parent, succeeded) end
        return succeeded
end

function BETTERUI_TabBarScrollList:MoveNext(allowWrapping, suppressFailSound)
    ZO_ConveyorSceneFragment_SetMovingForward()
    local succeeded = ZO_ParametricScrollList.MoveNext(self)
    if not succeeded and allowWrapping then
        ZO_ConveyorSceneFragment_SetMovingBackward()
        ZO_ParametricScrollList.SetFirstIndexSelected(self)
        succeeded = true
    end
    if succeeded then
        self.onPlaySoundFunction(ZO_TABBAR_MOVEMENT_TYPES.PAGE_FORWARD)
        -- Force carousel visual update after movement
        if self.carouselMode and self.UpdateAnchors then
            self:UpdateAnchors(self.targetSelectedIndex or self.selectedIndex, false, false)
        end
    elseif not suppressFailSound then
        self.onPlaySoundFunction(ZO_TABBAR_MOVEMENT_TYPES.PAGE_NAVIGATION_FAILED)
    end
    if(self.MoveNextCallback ~= nil) then self.MoveNextCallback(self.parent, succeeded) end
        return succeeded
end

-- Global click handler functions for XML OnClicked events
-- These find the scrollList from the button's parent and call navigation 
-- (the guard is checked in MovePrevious/MoveNext so we don't need separate debounce)
function BETTERUI_TabBar_OnLeftIconClicked(buttonControl)
    local tabBar = buttonControl:GetParent()
    local scrollList = tabBar and tabBar.scrollList
    if scrollList and scrollList.MovePrevious then
        scrollList:MovePrevious(true)
    end
end

function BETTERUI_TabBar_OnRightIconClicked(buttonControl)
    local tabBar = buttonControl:GetParent()
    local scrollList = tabBar and tabBar.scrollList
    if scrollList and scrollList.MoveNext then
        scrollList:MoveNext(true)
    end
end

-- Click handler for category icons - navigates directly to the clicked category
function BETTERUI_TabBar_OnCategoryIconClicked(categoryControl)
    local scrollList = nil
    -- Find the parent scrollList
    local parent = categoryControl:GetParent()
    while parent do
        if parent.scrollList then
            scrollList = parent.scrollList
            break
        end
        parent = parent:GetParent()
    end
    
    if not scrollList or not scrollList.dataList then return end
    
    -- Check navigation guard
    if scrollList.IsNavigationGuarded and scrollList:IsNavigationGuarded() then
        return
    end
    
    -- Find the index of the clicked category
    for i, data in ipairs(scrollList.dataList) do
        local control = scrollList:GetControlFromData(data)
        if control == categoryControl then
            -- Navigate to this index (with guard protection)
            if scrollList.SetNavigationGuard then
                scrollList:SetNavigationGuard()
            end
            scrollList:SetSelectedIndex(i, true, true)
            return
        end
    end
end

local SUB_LIST_CENTER_OFFSET = -50
BETTERUI_VerticalParametricScrollListSubList = BETTERUI_VerticalParametricScrollList:Subclass()
--- Creates a new vertical parametric scroll list sub-list instance for nested menus
function BETTERUI_VerticalParametricScrollListSubList:New(control, parentList, parentKeybinds, onDataChosen)
    local manager = BETTERUI_VerticalParametricScrollList.New(self, control, parentList, parentKeybinds, onDataChosen)
    return manager
end
function BETTERUI_VerticalParametricScrollListSubList:Initialize(control, parentList, parentKeybinds, onDataChosen)
    BETTERUI_VerticalParametricScrollList.Initialize(self, control)
    self.parentList = parentList
    self.parentKeybinds = parentKeybinds
    self.onDataChosen = onDataChosen
    self:InitializeKeybindStrip()
    self.control:SetHidden(true)
    self:SetFixedCenterOffset(SUB_LIST_CENTER_OFFSET)
end
function BETTERUI_VerticalParametricScrollListSubList:Commit(dontReselect)
    ZO_ParametricScrollList.Commit(self, dontReselect)
    self:UpdateAnchors(self.targetSelectedIndex)
    self.onDataChosen(self:GetTargetData())
end
function BETTERUI_VerticalParametricScrollListSubList:CancelSelection()
    local indexToReturnTo = zo_clamp(self.indexOnOpen, 1, #self.dataList)
    self.targetSelectedIndex = indexToReturnTo
    self:UpdateAnchors(indexToReturnTo)
    self.onDataChosen(self:GetDataForDataIndex(indexToReturnTo))
end
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
function BETTERUI_VerticalParametricScrollListSubList:Activate()
    self.parentList:Deactivate()
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.parentKeybinds)
    BETTERUI_VerticalParametricScrollList.Activate(self)
    KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor)
    self.control:SetHidden(false)
    self.indexOnOpen = self.selectedIndex
    self.didSelectEntry = false
end
function BETTERUI_VerticalParametricScrollListSubList:Deactivate()
    if not self.active then
        return
    end
    if self.active and not self.didSelectEntry then
        self:CancelSelection()
    end
    BETTERUI_VerticalParametricScrollList.Deactivate(self)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor)
    self.parentList:Activate()
    KEYBIND_STRIP:AddKeybindButtonGroup(self.parentKeybinds)
    self.control:SetHidden(true)
end

BETTERUI_Gamepad_ParametricList_Screen = ZO_Gamepad_ParametricList_Screen:Subclass()

--- Creates a new gamepad parametric list screen instance
function BETTERUI_Gamepad_ParametricList_Screen:New(...)
    local object = ZO_Gamepad_ParametricList_Screen.New(self)
    object:Initialize(...)
    return object
end

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
    --ZO_GamepadGenericHeader_Initialize(self.header, createTabBar)

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
