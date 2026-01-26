--[[
File: Modules/CIM/Lists/SubList.lua
Purpose: Nested Menu Support (Sub-lists).
Author: BetterUI Team
Last Modified: 2026-01-26
]]

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
