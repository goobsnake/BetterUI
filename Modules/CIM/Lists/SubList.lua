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
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "sublist init", { controlName = control and control.GetName and control:GetName() or "nil" })
    end
end

--- Commits selection and triggers callback.
---@param dontReselect boolean?
function BETTERUI_VerticalParametricScrollListSubList:Commit(dontReselect)
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "sublist commit", { targetSelectedIndex = self.targetSelectedIndex })
    end
    ZO_ParametricScrollList.Commit(self, dontReselect)
    self:UpdateAnchors(self.targetSelectedIndex)
    if self.onDataChosen then
        self.onDataChosen(self:GetTargetData())
    end
end

--- Cancels selection and reverts to entry index.
function BETTERUI_VerticalParametricScrollListSubList:CancelSelection()
    local listSize = self.dataList and #self.dataList or 0
    if not self.indexOnOpen or listSize == 0 then
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "sublist cancel selection skipped", { listSize = listSize, hasIndexOnOpen = self.indexOnOpen ~= nil })
        end
        return
    end

    local indexToReturnTo = zo_clamp(self.indexOnOpen, 1, listSize)
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "sublist cancel selection", { indexToReturnTo = indexToReturnTo })
    end
    self.targetSelectedIndex = indexToReturnTo
    self:UpdateAnchors(indexToReturnTo)
    if self.onDataChosen then
        self.onDataChosen(self:GetDataForDataIndex(indexToReturnTo))
    end
end

--- Sets up navigation keybinds (Enter/Back).
function BETTERUI_VerticalParametricScrollListSubList:InitializeKeybindStrip()
    local function OnEntered()
        if self.onDataChosen then
            self.onDataChosen(self:GetTargetData())
        end
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
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        local totalItems = self.dataList and #self.dataList or 0
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "sublist activate", { totalItems = totalItems })
    end

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

    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "sublist deactivate", { didSelectEntry = self.didSelectEntry == true })
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
