--[[
File: Modules/CIM/Lists/ParametricListScreen.lua
Purpose: Enhanced Gamepad List Screen Wrapper.
Author: BetterUI Team
Last Modified: 2026-01-26
]]

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
Note: We pass ... to the parent's New, which handles Initialize automatically.
]]
function BETTERUI_Gamepad_ParametricList_Screen:New(...)
    return ZO_Gamepad_ParametricList_Screen.New(self, ...)
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
    self.addListTriggerKeybinds = false
    self.listTriggerKeybinds = nil
    self.listTriggerHeaderComparator = nil

    self:InitializeKeybindStripDescriptors()

    self.dirty = true
end

function BETTERUI_Gamepad_ParametricList_Screen:SetListsUseTriggerKeybinds(addListTriggerKeybinds,
                                                                           optionalHeaderComparator)
    self.addListTriggerKeybinds = addListTriggerKeybinds
    self.listTriggerHeaderComparator = optionalHeaderComparator

    if (not addListTriggerKeybinds) then
        self:TryRemoveListTriggers()
    end
end
