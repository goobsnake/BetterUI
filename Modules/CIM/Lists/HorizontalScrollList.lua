--[[
File: Modules/CIM/Lists/HorizontalScrollList.lua
Purpose: Horizontal Scroll List implementations (Standard and Parametric).
Author: BetterUI Team
Last Modified: 2026-01-26
]]

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
function BETTERUI_HorizontalScrollList_Gamepad:Initialize(control, templateName, numVisibleEntries, setupFunction,
                                                          equalityFunction, onCommitWithItemsFunction, onClearedFunction)
    ZO_HorizontalScrollList.Initialize(self, control, templateName, numVisibleEntries, setupFunction, equalityFunction,
        onCommitWithItemsFunction, onClearedFunction)
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
function BETTERUI_HorizontalScrollList_Gamepad:UpdateAnchors(primaryControlOffsetX, initialUpdate,
                                                             reselectingDuringRebuild)
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
                self.setupFunction(control, data, selected, reselectingDuringRebuild, self.enabled,
                    self.selectedFromParent)
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

--[[
Function: BETTERUI_HorizontalParametricScrollList:New
Description: Creates a new horizontal parametric scroll list.
param: control (table) - The list control.
param: onActivatedChangedFunction (function) - Callback for activation state changes.
param: onCommitWithItemsFunction (function) - Callback on commit with items.
param: onClearedFunction (function) - Callback on clear.
return: table - The new list instance.
]]
function BETTERUI_HorizontalParametricScrollList:New(control, onActivatedChangedFunction, onCommitWithItemsFunction,
                                                     onClearedFunction)
    onActivatedChangedFunction = onActivatedChangedFunction or ZO_GamepadOnDefaultScrollListActivatedChanged
    local list = ZO_ParametricScrollList.New(self, control, PARAMETRIC_SCROLL_LIST_HORIZONTAL, onActivatedChangedFunction,
        onCommitWithItemsFunction, onClearedFunction)
    list:SetHeaderPadding(GAMEPAD_HEADER_DEFAULT_PADDING, GAMEPAD_HEADER_SELECTED_PADDING)
    list:SetPlaySoundFunction(BETTERUI.GamepadParametricScrollListPlaySound)
    return list
end
