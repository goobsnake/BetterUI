--[[
File: Modules/CIM/Lists/ParametricListScreen.lua
Purpose: Enhanced Gamepad List Screen Wrapper.
]]

-- Matches ESOUI's file-local constant (zo_gamepadparametricscrolllistscreen.lua).
local ALWAYS_ANIMATE = true

-- CLASS: BETTERUI_Gamepad_ParametricList_Screen
-- Enhanced Gamepad List Screen Wrapper.
-- Contains Header, HeaderFragment, List, and basic logic.
BETTERUI_Gamepad_ParametricList_Screen = ZO_Gamepad_ParametricList_Screen:Subclass()

--- Creates a new Gamepad Parametric List Screen.
---@param ... any
---@return table
function BETTERUI_Gamepad_ParametricList_Screen:New(...)
    return ZO_Gamepad_ParametricList_Screen.New(self, ...)
end

--- Initializes the screen.
---@param control table
---@param createTabBar boolean?
---@param activateOnShow boolean?
---@param scene table?
function BETTERUI_Gamepad_ParametricList_Screen:Initialize(control, createTabBar, activateOnShow, scene)
    control.owner = self
    self.control = control

    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SCENE, "parametric list screen init", { createTabBar = createTabBar == true, activateOnShow = activateOnShow ~= false })
    end

    local mask = control:GetNamedChild("Mask")
    local container = mask:GetNamedChild("Container")
    control.container = container

    self.activateOnShow = (activateOnShow ~= false) -- nil should be true
    self:SetScene(scene)

    -- Mirror ZO_Gamepad_ParametricList_Screen:Initialize: store the header
    -- container on self so the inherited GetHeaderContainer() returns it.
    self.headerContainer = container:GetNamedChild("HeaderContainer")
    control.header = self.headerContainer.header
    self.headerFragment = ZO_ConveyorSceneFragment:New(self.headerContainer, ALWAYS_ANIMATE)

    self.header = control.header

    -- Mirror ZO_Gamepad_ParametricList_Screen:Initialize: the generic header
    -- initializer always runs (it populates header.controls, which
    -- GenericHeader.Refresh indexes unconditionally); createTabBar only gates
    -- the tab-bar setup inside it.
    if self.header
        and BETTERUI.GenericHeader and BETTERUI.GenericHeader.Initialize then
        BETTERUI.GenericHeader.Initialize(self.header, createTabBar)
    end

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

--- Sets whether lists use trigger keybinds.
---@param addListTriggerKeybinds boolean
---@param optionalHeaderComparator fun(a: table, b: table): boolean|nil
function BETTERUI_Gamepad_ParametricList_Screen:SetListsUseTriggerKeybinds(addListTriggerKeybinds,
                                                                           optionalHeaderComparator)
    self.addListTriggerKeybinds = addListTriggerKeybinds
    self.listTriggerHeaderComparator = optionalHeaderComparator
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "set lists use trigger keybinds", { enabled = addListTriggerKeybinds == true })
    end

    if (not addListTriggerKeybinds) then
        self:TryRemoveListTriggers()
    end
end
