--[[
File: Modules/CIM/Lists/SubList.lua
Purpose: Nested Menu Support (Sub-lists).
]]

-- CLASS: BETTERUI_VerticalParametricScrollListSubList
-- Nested Menu Support (e.g., sub-categories)
local SUB_LIST_CENTER_OFFSET = -50
BETTERUI_VerticalParametricScrollListSubList = BETTERUI_VerticalParametricScrollList:Subclass()

--- Creates a new sub-list (nested menu) instance.
---@param control table
---@param parentList table
---@param parentKeybinds table
---@param onDataChosen fun(data: table?)
---@return table
function BETTERUI_VerticalParametricScrollListSubList:New(control, parentList, parentKeybinds, onDataChosen)
    local manager = BETTERUI_VerticalParametricScrollList.New(self, control, parentList, parentKeybinds, onDataChosen)
    return manager
end

--- Initializes the sub-list.
---@param control table
---@param parentList table
---@param parentKeybinds table
---@param onDataChosen fun(data: table?)
function BETTERUI_VerticalParametricScrollListSubList:Initialize(control, parentList, parentKeybinds, onDataChosen)
    BETTERUI_VerticalParametricScrollList.Initialize(self, control)
    self.parentList = parentList
    self.parentKeybinds = parentKeybinds
    self.onDataChosen = onDataChosen
    self:InitializeKeybindStrip()
    self.control:SetHidden(true)
    self:SetFixedCenterOffset(SUB_LIST_CENTER_OFFSET)
end

--- Commits selection and triggers callback.
---@param dontReselect boolean?
function BETTERUI_VerticalParametricScrollListSubList:Commit(dontReselect)
    ZO_ParametricScrollList.Commit(self, dontReselect)
    self:UpdateAnchors(self.targetSelectedIndex)
    self.onDataChosen(self:GetTargetData())
end

--- Cancels selection and reverts to entry index.
function BETTERUI_VerticalParametricScrollListSubList:CancelSelection()
    local indexToReturnTo = zo_clamp(self.indexOnOpen, 1, #self.dataList)
    self.targetSelectedIndex = indexToReturnTo
    self:UpdateAnchors(indexToReturnTo)
    self.onDataChosen(self:GetDataForDataIndex(indexToReturnTo))
end

--- Sets up navigation keybinds (Enter/Back).
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

--- Shows and activates the sub-list.
function BETTERUI_VerticalParametricScrollListSubList:Activate()
    self.parentList:Deactivate()
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.parentKeybinds)
    BETTERUI_VerticalParametricScrollList.Activate(self)
    KEYBIND_STRIP:AddKeybindButtonGroup(self.keybindStripDescriptor)
    self.control:SetHidden(false)
    self.indexOnOpen = self.selectedIndex
    self.didSelectEntry = false
end

--- Hides and deactivates the sub-list.
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
