local TABBAR_MOVEMENT_TYPES = (BETTERUI.CIM and BETTERUI.CIM.ListGlobals and BETTERUI.CIM.ListGlobals.TABBAR_MOVEMENT_TYPES) or
{
    PAGE_FORWARD = ZO_PARAMETRIC_MOVEMENT_TYPES.LAST,
    PAGE_BACK = ZO_PARAMETRIC_MOVEMENT_TYPES.LAST + 1,
    PAGE_NAVIGATION_FAILED = ZO_PARAMETRIC_MOVEMENT_TYPES.LAST + 2,
}

BETTERUI_TabBarScrollList = BETTERUI_HorizontalParametricScrollList:Subclass()

---@return boolean
function BETTERUI_TabBarScrollList:ShouldWrapShoulderNavigation()
    -- Always allow wrapping so navigation cycles through all entries at
    -- boundaries regardless of the visual carousel layout mode.
    return true
end

function BETTERUI_TabBarScrollList:New(control, leftIcon, rightIcon, data, onActivatedChangedFunction,
                                       onCommitWithItemsFunction, onClearedFunction)
    local list = BETTERUI_HorizontalParametricScrollList.New(self, control, onActivatedChangedFunction,
        onCommitWithItemsFunction, onClearedFunction)
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
    list:SetPlaySoundFunction(BETTERUI.GamepadParametricScrollListPlaySound)

    -- Enable Carousel Mode:
    -- In this mode, the selected item stays fixed (usually to the left), and the list contents
    -- rotate around it. Allows for seamless circular navigation through categories.
    list.carouselMode = true
    list.carouselStartOffset = BETTERUI.CIM.CONST.CAROUSEL.startOffset
    list.carouselItemSpacing = BETTERUI.CIM.CONST.CAROUSEL.itemSpacing
    list.carouselVerticalOffset = BETTERUI.CIM.CONST.CAROUSEL.verticalOffset

    return list
end

--- Override UpdateAnchors to implement CAROUSEL rotation behavior.
---@param continousTargetOffset number
---@param initialUpdate boolean?
---@param reselectingDuringRebuild boolean?
---@param blockSelectionChangedCallback boolean?
function BETTERUI_TabBarScrollList:UpdateAnchors(continousTargetOffset, initialUpdate, reselectingDuringRebuild,
                                                 blockSelectionChangedCallback)
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

    -- Position items using shared offset constants for consistent alignment with
    -- SelectedBg triangle and CountBadge across both carousel and non-carousel modes.
    -- Carousel mode: circular order starting from selected item (wraps around)
    -- Non-carousel mode: natural order (1, 2, 3...) shifted so selected item stays at startOffset
    local currentOffset = self.carouselStartOffset + animationOffset

    for i = 0, numItems - 1 do
        local dataIndex
        if self.carouselMode then
            -- Circular order: selected item first, then wraps around
            dataIndex = ((newSelectedDataIndex - 1 + i) % numItems) + 1
        else
            -- Linear order: items in natural sequence (1, 2, 3...)
            -- Offset shifted so that the selected item always lands at carouselStartOffset
            dataIndex = i + 1
            currentOffset = self.carouselStartOffset + animationOffset
                + (i - (newSelectedDataIndex - 1)) * self.carouselItemSpacing
        end

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
        self:FireCallbacks("SelectedDataChanged", self, self.selectedData, oldSelectedData, nil, self
            .targetSelectedIndex)
        -- Fire our specific custom callback property
        if self.onSelectedDataChangedCallback then
            self.onSelectedDataChangedCallback(self, self.selectedData, oldSelectedData, reselectingDuringRebuild)
        end
    end
end

--- Activates the tab bar and its keybinds.
function BETTERUI_TabBarScrollList:Activate()
    KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor)
    BETTERUI_HorizontalParametricScrollList.Activate(self)
end

--- Deactivates the tab bar and removes keybinds.
function BETTERUI_TabBarScrollList:Deactivate()
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.keybindStripDescriptor)
    BETTERUI_HorizontalParametricScrollList.Deactivate(self)
end

-- Custom Callback Management
-- Override these to handle the dual-callback nature of standard ZO lists vs Carousel mode
--- Sets the data change callback.
---@param callback fun(list: table, selectedData: table?, oldSelectedData: table?, reselectingDuringRebuild: boolean)?
function BETTERUI_TabBarScrollList:SetOnSelectedDataChangedCallback(callback)
    self.onSelectedDataChangedCallback = callback -- For Carousel mode

    -- Clean up old wrapper
    if self._zo_selectedDataChangedWrapper then
        self:UnregisterCallback("SelectedDataChanged", self._zo_selectedDataChangedWrapper)
        self._zo_selectedDataChangedWrapper = nil
    end

    -- Register wrapper for Non-Carousel mode (acting as standard list)
    if callback then
        self._zo_selectedDataChangedWrapper = function(list, selectedData, oldSelectedData, reachedTarget,
                                                       targetSelectedIndex)
            if not self.carouselMode then
                if reachedTarget == false then return end -- wait for animation end
                callback(list, selectedData, oldSelectedData, false)
            end
        end
        self:RegisterCallback("SelectedDataChanged", self._zo_selectedDataChangedWrapper)
    end
end

--- Removes the data change callback.
---@param callback fun()?
function BETTERUI_TabBarScrollList:RemoveOnSelectedDataChangedCallback(callback)
    self.onSelectedDataChangedCallback = nil
    if self._zo_selectedDataChangedWrapper then
        self:UnregisterCallback("SelectedDataChanged", self._zo_selectedDataChangedWrapper)
        self._zo_selectedDataChangedWrapper = nil
    end
end

--- Sets up LB/RB keybinds.
function BETTERUI_TabBarScrollList:InitializeKeybindStripDescriptors()
    self.keybindStripDescriptor =
    {
        {
            keybind = "UI_SHORTCUT_LEFT_SHOULDER",
            ethereal = true,
            callback = function()
                if self.active then self:MovePrevious(self:ShouldWrapShoulderNavigation()) end
            end,
        },
        {
            keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
            ethereal = true,
            callback = function()
                if self.active then self:MoveNext(self:ShouldWrapShoulderNavigation()) end
            end,
        },
    }
end

--- Commits changes.
---@param dontReselect boolean?
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

--- Enables/Disables Pip (Dot) indicators.
---@param enabled boolean
---@param divider table?
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

--- Updates Pip indicators based on selection.
function BETTERUI_TabBarScrollList:RefreshPips()
    if not self.pipsEnabled then
        if self.pips then self.pips:RefreshPips() end
        return
    end
    local selectedIndex = self.targetSelectedIndex or self.selectedIndex
    local numPips = 0
    local selectedPipIndex = 0
    for i = 1, #self.dataList do
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

--- Sets selection with animation.
---@param selectedIndex integer
---@param allowEvenIfDisabled boolean?
---@param forceAnimation boolean?
function BETTERUI_TabBarScrollList:SetSelectedIndex(selectedIndex, allowEvenIfDisabled, forceAnimation)
    -- BetterUI Fix: Capture old data BEFORE calling base class (which updates selectedData)
    local oldSelectedData = self.selectedData
    local oldSelectedIndex = self.selectedIndex

    BETTERUI_HorizontalParametricScrollList.SetSelectedIndex(self, selectedIndex, allowEvenIfDisabled, forceAnimation)
    self:RefreshPips()
    if self.UpdateAnchors then
        self:UpdateAnchors(selectedIndex, false, false, false)
    end

    -- BetterUI Fix: Fire callback directly if selection actually changed
    -- This is necessary because the base class updates selectedData before UpdateAnchors,
    -- causing the "selectedData ~= oldSelectedData" check to fail
    if self.selectedIndex ~= oldSelectedIndex and self.onSelectedDataChangedCallback then
        self.onSelectedDataChangedCallback(self, self.selectedData, oldSelectedData, false)
    end
end

--- Sets selection immediately without animation.
---@param selectedIndex integer
---@param allowEvenIfDisabled boolean?
---@param dontCallSelectedDataChangedCallback boolean?
function BETTERUI_TabBarScrollList:SetSelectedIndexWithoutAnimation(selectedIndex, allowEvenIfDisabled,
                                                                    dontCallSelectedDataChangedCallback)
    ZO_ParametricScrollList.SetSelectedIndexWithoutAnimation(self, selectedIndex, allowEvenIfDisabled,
        dontCallSelectedDataChangedCallback)
    self:RefreshPips()
    if self.UpdateAnchors then
        self:UpdateAnchors(selectedIndex, true, false, false)
    end
end

--- Moves to previous item.
---@param allowWrapping boolean?
---@param suppressFailSound boolean?
---@return boolean succeeded
function BETTERUI_TabBarScrollList:MovePrevious(allowWrapping, suppressFailSound)
    ZO_ConveyorSceneFragment_SetMovingBackward()
    local succeeded = ZO_ParametricScrollList.MovePrevious(self)
    if not succeeded and allowWrapping then
        ZO_ConveyorSceneFragment_SetMovingForward()
        self:SetLastIndexSelected() -- Wrap to last
        succeeded = true
    end
    if succeeded then
        self.onPlaySoundFunction(TABBAR_MOVEMENT_TYPES.PAGE_BACK)
        if self.UpdateAnchors then
            self:UpdateAnchors(self.targetSelectedIndex or self.selectedIndex, false, false, false)
        end
    elseif not suppressFailSound then
        self.onPlaySoundFunction(TABBAR_MOVEMENT_TYPES.PAGE_NAVIGATION_FAILED)
    end
    if (self.MovePrevCallback ~= nil) then self.MovePrevCallback(self.parent, succeeded) end
    return succeeded
end

--- Moves to next item.
---@param allowWrapping boolean?
---@param suppressFailSound boolean?
---@return boolean succeeded
function BETTERUI_TabBarScrollList:MoveNext(allowWrapping, suppressFailSound)
    ZO_ConveyorSceneFragment_SetMovingForward()
    local succeeded = ZO_ParametricScrollList.MoveNext(self)
    if not succeeded and allowWrapping then
        ZO_ConveyorSceneFragment_SetMovingBackward()
        ZO_ParametricScrollList.SetFirstIndexSelected(self) -- Wrap to first
        succeeded = true
    end
    if succeeded then
        self.onPlaySoundFunction(TABBAR_MOVEMENT_TYPES.PAGE_FORWARD)
        if self.UpdateAnchors then
            self:UpdateAnchors(self.targetSelectedIndex or self.selectedIndex, false, false, false)
        end
    elseif not suppressFailSound then
        self.onPlaySoundFunction(TABBAR_MOVEMENT_TYPES.PAGE_NAVIGATION_FAILED)
    end
    if (self.MoveNextCallback ~= nil) then self.MoveNextCallback(self.parent, succeeded) end
    return succeeded
end

-- EVENT HANDLERS (Global)
-- Called from XML via OnClicked, etc.

--- Global handler for Left Icon click.
---@param buttonControl table
function BETTERUI_TabBar_OnLeftIconClicked(buttonControl)
    local tabBar = buttonControl:GetParent()
    local scrollList = tabBar and tabBar.scrollList
    if scrollList and scrollList.MovePrevious then
        local allowWrapping = true
        if scrollList.ShouldWrapShoulderNavigation then
            allowWrapping = scrollList:ShouldWrapShoulderNavigation()
        end
        scrollList:MovePrevious(allowWrapping)
    end
end

--- Global handler for Right Icon click.
---@param buttonControl table
function BETTERUI_TabBar_OnRightIconClicked(buttonControl)
    local tabBar = buttonControl:GetParent()
    local scrollList = tabBar and tabBar.scrollList
    if scrollList and scrollList.MoveNext then
        local allowWrapping = true
        if scrollList.ShouldWrapShoulderNavigation then
            allowWrapping = scrollList:ShouldWrapShoulderNavigation()
        end
        scrollList:MoveNext(allowWrapping)
    end
end

--- Global handler for direct category icon click.
---
--- Purpose: Handles category selection via icon click.
--- Mechanics:
--- 1. Identifies the parent scrollList.
--- 2. Finds the data index for the clicked control.
--- 3. Special Case: If in Inventory scene, dispatches directly to GAMEPAD_INVENTORY:OnCategoryClicked.
--- 4. Default: Calls scrollList:SetSelectedIndex.
---
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
