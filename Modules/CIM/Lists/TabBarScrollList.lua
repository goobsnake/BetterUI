--[[
File: Modules/CIM/Lists/TabBarScrollList.lua
Purpose: Tab Bar (Carousel) Scroll List implementation.
         Handles circular navigation and LB/RB shoulder button logic.
Author: BetterUI Team
Last Modified: 2026-01-26
]]

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
function BETTERUI_TabBarScrollList:UpdateAnchors(continousTargetOffset, initialUpdate, reselectingDuringRebuild,
                                                 blockSelectionChangedCallback)
    if not self.carouselMode then
        -- Fallback to default parametric list behavior if carousel is disabled
        return ZO_ParametricScrollList.UpdateAnchors(self, continousTargetOffset, initialUpdate, reselectingDuringRebuild,
            blockSelectionChangedCallback)
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
        self:FireCallbacks("SelectedDataChanged", self, self.selectedData, oldSelectedData, nil, self
            .targetSelectedIndex)
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
function BETTERUI_TabBarScrollList:SetSelectedIndexWithoutAnimation(selectedIndex, allowEvenIfDisabled,
                                                                    dontCallSelectedDataChangedCallback)
    ZO_ParametricScrollList.SetSelectedIndexWithoutAnimation(self, selectedIndex, allowEvenIfDisabled,
        dontCallSelectedDataChangedCallback)
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
    if (self.MovePrevCallback ~= nil) then self.MovePrevCallback(self.parent, succeeded) end
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
    if (self.MoveNextCallback ~= nil) then self.MoveNextCallback(self.parent, succeeded) end
    return succeeded
end

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
