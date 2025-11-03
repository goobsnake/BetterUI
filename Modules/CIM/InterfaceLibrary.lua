-- shadowcep: Patched for compatibility with ESO Update 33
local _

BETTERUI_TEST_SCENE_NAME = "BETTERUI_BANKING"

local BANKING_INTERACTION =
{
    type = "Banking",
    interactTypes = { INTERACTION_BANK },
}

local function WrapInt(value, min, max)
    return (zo_floor(value) - min) % (max - min + 1) + min
end

function BETTERUI.CIM.SetTooltipWidth(width)
    -- Setup the larger and offset LEFT_TOOLTIP and background fragment so that the new inventory fits!
    GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT.control:SetWidth(width)
   -- GAMEPAD_LEFT_TOOLTIP_BACKGROUND_FRAGMENT.control:SetDimensions(50, 50)
--shadowcep[[
    GAMEPAD_TOOLTIPS.tooltips.GAMEPAD_LEFT_TOOLTIP.control:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT, width+66, 52)
    GAMEPAD_TOOLTIPS.tooltips.GAMEPAD_LEFT_TOOLTIP.control:SetAnchor(BOTTOMLEFT,GuiRoot,BOTTOMLEFT, width+66, -125)
--shadowcep]]
end

BETTERUI.Interface.Window = ZO_Object:Subclass()

function BETTERUI.Interface.Window:New(...)
	local object = ZO_Object.New(self)
    object:Initialize(...)
	return object
end

function BETTERUI.Interface.Window:Initialize(tlw_name, scene_name)
    self.windowName = tlw_name
    self.control = BETTERUI.WindowManager:CreateControlFromVirtual(tlw_name, GuiRoot, "BETTERUI_GenericInterface")
    self.header = self.control:GetNamedChild("ContainerHeader")
    self.footer = self.control:GetNamedChild("ContainerFooter")

    self.spinner = self.control:GetNamedChild("ContainerList"):GetNamedChild("SpinnerContainer")
    self.spinner:InitializeSpinner()

    -- Wrap the spinner's max and min values
    self.spinner.spinner.constrainRangeFunc = WrapInt

    -- Stop the spinner inheriting the scrollList's alpha, allowing the list to be deactivated correctly
    self.spinner:SetInheritAlpha(false)

    self:DeactivateSpinner()

    self.header.MoveNext = function() self:OnTabNext() end
    self.header.MovePrev = function() self:OnTabPrev() end

	self.header.columns = {}

    BETTERUI_TEST_SCENE = ZO_InteractScene:New(BETTERUI_TEST_SCENE_NAME, SCENE_MANAGER, BANKING_INTERACTION)

    self:InitializeFragment("BETTERUI_TEST_FRAGMENT")
    self:InitializeScene(BETTERUI_TEST_SCENE)

    self:InitializeList()
end

function BETTERUI.Interface.Window:SetSpinnerValue(max, value)
    self.spinner:SetMinMax(1, max)
    self.spinner:SetValue(value)
end



function BETTERUI.Interface.Window:ActivateSpinner()
    self.spinner:SetHidden(false)
    self.spinner:Activate()
    if(self:GetList() ~= nil) then self:GetList():Deactivate() end
end

function BETTERUI.Interface.Window:DeactivateSpinner()
    self.spinner:SetValue(1)
    self.spinner:SetHidden(true)
    self.spinner:Deactivate()
    if(self:GetList() ~= nil) then self:GetList():Activate() end
end

function BETTERUI.Interface.Window:UpdateSpinnerConfirmation(activateSpinner, list)
    self.confirmationMode = activateSpinner
    if activateSpinner then
        self:ActivateSpinner()
        --self.spinner:AnchorToSelectedListEntry(list)
        --ZO_GamepadGenericHeader_Deactivate(self.header)

    else
        self:DeactivateSpinner()
        --ZO_GamepadGenericHeader_Activate(self.header)

    end

    list:RefreshVisible()
    self:ApplySpinnerMinMax(activateSpinner)
    list:SetDirectionalInputEnabled(not activateSpinner)
end

function BETTERUI.Interface.Window:ApplySpinnerMinMax(toggleValue)
    if(toggleValue) then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.triggerSpinnerBinds)
    else
        KEYBIND_STRIP:AddKeybindButtonGroup(self.triggerSpinnerBinds)
    end
end

-- GetList() can be extended to allow for multiple lists in one Window object
function BETTERUI.Interface.Window:GetList()
    return self.list
end


function BETTERUI.Interface.Window:InitializeKeybind()
    self.coreKeybinds = {
    }

    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.mainKeybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON) -- "Back"

    self.triggerSpinnerBinds = {}
end


function BETTERUI.Interface.Window:InitializeList(listName)
    self.list = BETTERUI_VerticalItemParametricScrollList:New(self.control:GetNamedChild("Container"):GetNamedChild("List")) -- replace the itemList with my own generic one (with better gradient size, etc.)

    self:GetList():SetAlignToScreenCenter(true, 30)

    self:GetList().maxOffset = 0
    self:GetList().headerDefaultPadding = 15
    self:GetList().headerSelectedPadding = 0
    self:GetList().universalPostPadding = 5
end

-- Overridden
function BETTERUI.Interface.Window:RefreshList()
end

-- Overridden
function BETTERUI.Interface.Window:OnItemSelectedChange()
end

function BETTERUI.Interface.Window:SetupList(rowTemplate, SetupFunct)
    self.itemListTemplate = rowTemplate
    self:GetList():AddDataTemplate(rowTemplate, SetupFunct, ZO_GamepadMenuEntryTemplateParametricListFunction)
end

function BETTERUI.Interface.Window:AddTemplate(rowTemplate, SetupFunct)
    self:GetList():AddDataTemplate(rowTemplate,SetupFunct, ZO_GamepadMenuEntryTemplateParametricListFunction)
end

function BETTERUI.Interface.Window:AddEntryToList(data)
    self:GetList():AddEntry(self.itemListTemplate, data)
    self:GetList():Commit()
end

function BETTERUI.Interface.Window:AddColumn(columnName, xOffset)
    local colNumber = #self.header.columns + 1
    self.header.columns[colNumber] = CreateControlFromVirtual("Column"..colNumber,self.header:GetNamedChild("HeaderColumnBar"),"BETTERUI_GenericColumn_Label")
    -- Nudge column headers further downward for better alignment with divider bars
    self.header.columns[colNumber]:SetAnchor(LEFT, self.header:GetNamedChild("HeaderColumnBar"), BOTTOMLEFT, xOffset, 109)
    self.header.columns[colNumber]:SetText(columnName)
end

function BETTERUI.Interface.Window:SetTitle(headerText)
    self.header:GetNamedChild("Header"):GetNamedChild("TitleContainer"):GetNamedChild("Title"):SetText(headerText)
end

function BETTERUI.Interface.Window:RefreshVisible()
    self:RefreshList()
    -- self.list.selectedDataCallback = function(list, selectedData)
    --     ddebug("SetOnSelectedDataChangedCallback called")
    --     self.currentSelection = selectedData
    --     self:OnItemSelectedChange(selectedData)
    -- end
    self:GetList():RefreshVisible()
end

function BETTERUI.Interface.Window:SetOnSelectedDataChangedCallback(selectedDataCallback)
    self.selectedDataCallback = selectedDataCallback
end

function BETTERUI.Interface.Window:InitializeFragment()
	self.fragment = ZO_SimpleSceneFragment:New(self.control)
    self.fragment:SetHideOnSceneHidden(true)

    self.footerFragment = ZO_SimpleSceneFragment:New(BETTERUI_BankingFooterBar)
    self.footerFragment:SetHideOnSceneHidden(true)
end

function BETTERUI.Interface.Window:InitializeScene(SCENE_NAME)
    self.sceneName = SCENE_NAME
    SCENE_NAME:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    SCENE_NAME:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD)
    SCENE_NAME:AddFragment(self.fragment)
    SCENE_NAME:AddFragment(FRAME_EMOTE_FRAGMENT_INVENTORY)
    SCENE_NAME:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    SCENE_NAME:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    SCENE_NAME:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    SCENE_NAME:AddFragment(self.footerFragment)



    local function SceneStateChange(oldState, newState)
        if(newState == SCENE_SHOWING) then
            KEYBIND_STRIP:AddKeybindButtonGroup(self.coreKeybinds)
        	BETTERUI.CIM.SetTooltipWidth(BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH)
        elseif(newState == SCENE_HIDING) then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.coreKeybinds)
           BETTERUI.CIM.SetTooltipWidth(BETTERUI_ZO_GAMEPAD_DEFAULT_PANEL_WIDTH)
        elseif(newState == SCENE_HIDDEN) then

        end
    end
    SCENE_NAME:RegisterCallback("StateChange",  SceneStateChange)

end

function BETTERUI.Interface.Window:ToggleScene()
	--SCENE_MANAGER:Show
	SCENE_MANAGER:Toggle(BETTERUI_TEST_SCENE_NAME)
end

function BETTERUI.Interface.Window:OnTabNext()
    ddebug("OnTabNext")
end

function BETTERUI.Interface.Window:OnTabPrev()
    ddebug("OnTabPrev")
end
