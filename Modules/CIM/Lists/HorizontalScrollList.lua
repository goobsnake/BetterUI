--[[
File: Modules/CIM/Lists/HorizontalScrollList.lua
Purpose: Horizontal Scroll List implementations (Standard and Parametric).
]]

-- CLASS: BETTERUI_HorizontalScrollList_Gamepad
-- Basic Horizontal List (Non-Parametric) wrapper
BETTERUI_HorizontalScrollList_Gamepad = ZO_HorizontalScrollList:Subclass()

--- Creates a new horizontal scroll list instance.
---@param ... any
---@return table
function BETTERUI_HorizontalScrollList_Gamepad:New(...)
    return ZO_HorizontalScrollList.New(self, ...)
end

--- Initializes the horizontal scroll list.
---@param control table
---@param templateName string
---@param numVisibleEntries integer
---@param setupFunction fun(control: table, data: table, selected: boolean)
---@param equalityFunction fun(a: table, b: table): boolean
---@param onCommitWithItemsFunction fun()?
---@param onClearedFunction fun()?
function BETTERUI_HorizontalScrollList_Gamepad:Initialize(control, templateName, numVisibleEntries, setupFunction,
                                                          equalityFunction, onCommitWithItemsFunction, onClearedFunction)
    ZO_HorizontalScrollList.Initialize(self, control, templateName, numVisibleEntries, setupFunction, equalityFunction,
        onCommitWithItemsFunction, onClearedFunction)
    self:SetActive(true)
    self.movementController = ZO_MovementController:New(MOVEMENT_CONTROLLER_DIRECTION_HORIZONTAL)
end

--- Updates the anchors and positions of the scroll list controls.
---@param primaryControlOffsetX number
---@param initialUpdate boolean?
---@param reselectingDuringRebuild boolean?
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

--- Sets the callback for activation state changes.
---@param onActivatedChangedFunction fun(list: table, active: boolean)?
function BETTERUI_HorizontalScrollList_Gamepad:SetOnActivatedChangedFunction(onActivatedChangedFunction)
    self.onActivatedChangedFunction = onActivatedChangedFunction
    self.dirty = true
end

--- Commits the list data and updates UI.
function BETTERUI_HorizontalScrollList_Gamepad:Commit()
    ZO_HorizontalScrollList.Commit(self)

    local hideArrows = not self.active
    self.leftArrow:SetHidden(hideArrows)
    self.rightArrow:SetHidden(hideArrows)
end

--- Sets the active state of the list.
---@param active boolean
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

--- Wrapper for SetActive(true).
function BETTERUI_HorizontalScrollList_Gamepad:Activate()
    self:SetActive(true)
end

--- Wrapper for SetActive(false).
function BETTERUI_HorizontalScrollList_Gamepad:Deactivate()
    self:SetActive(false)
end

-- CLASS: BETTERUI_HorizontalParametricScrollList
-- Base class for horizontal parametric lists.
BETTERUI_HorizontalParametricScrollList = ZO_ParametricScrollList:Subclass()
local LIST_ORIENTATION = (BETTERUI.CIM and BETTERUI.CIM.ListGlobals and BETTERUI.CIM.ListGlobals.ORIENTATION) or
{
    VERTICAL = true,
    HORIZONTAL = false,
}

--- Creates a new horizontal parametric scroll list.
---@param control table
---@param onActivatedChangedFunction fun(list: table, active: boolean)?
---@param onCommitWithItemsFunction fun()?
---@param onClearedFunction fun()?
---@return table
function BETTERUI_HorizontalParametricScrollList:New(control, onActivatedChangedFunction, onCommitWithItemsFunction,
                                                     onClearedFunction)
    onActivatedChangedFunction = onActivatedChangedFunction or ZO_GamepadOnDefaultScrollListActivatedChanged
    local list = ZO_ParametricScrollList.New(self, control, LIST_ORIENTATION.HORIZONTAL, onActivatedChangedFunction,
        onCommitWithItemsFunction, onClearedFunction)
    list:SetHeaderPadding(GAMEPAD_HEADER_DEFAULT_PADDING, GAMEPAD_HEADER_SELECTED_PADDING)
    list:SetPlaySoundFunction(BETTERUI.GamepadParametricScrollListPlaySound)
    return list
end
