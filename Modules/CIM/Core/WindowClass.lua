--[[
File: Modules/CIM/Core/WindowClass.lua
Purpose: Base window class for gamepad inventory/banking screens.
Author: BetterUI Team
Last Modified: 2026-01-26

Extracted from InterfaceLibrary.lua as part of Phase 3 refactoring.
Provides core abstractions shared across BetterUI's gamepad screens,
including window management, spinner utilities, and scene integration.

Note: Scene creation is NOT done here - each module (Banking, etc.) should
create its own scene and call InitializeFragment/InitializeScene.
]]

local _

BETTERUI.Interface = BETTERUI.Interface or {}

-------------------------------------------------------------------------------------------------
-- PRIVATE HELPERS
-------------------------------------------------------------------------------------------------

local function WrapInt(value, min, max)
    return (zo_floor(value) - min) % (max - min + 1) + min
end

-------------------------------------------------------------------------------------------------
-- WINDOW CLASS
-------------------------------------------------------------------------------------------------

BETTERUI.Interface.Window = ZO_Object:Subclass()

--[[
Function: BETTERUI.Interface.Window:New
Description: Constructor for the Base Window class.
Rationale: Standard factory method for creating new Window instances.
Mechanism: Allocates a new ZO_Object and calls Initialize.
param: ... (any) - Arguments passed to Initialize.
return: table - The new window object.
]]
function BETTERUI.Interface.Window:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end

--[[
Function: BETTERUI.Interface.Window:Initialize
Description: Initializes the window instance.
Rationale: Sets up the control hierarchy, header/footer references, and spinner components.
Mechanism:
  1. Creates the physical UI control from 'BETTERUI_GenericInterface' virtual template.
  2. Finds and caches references to child controls (Header, Footer, Spinner).
  3. Initializes the spinner and wraps its range function.
  4. Sets up header navigation callbacks.

Note: Scene/fragment setup is NOT done here. Subclasses should:
  1. Create their own scene (e.g., ZO_InteractScene:New(...))
  2. Call self:InitializeFragment()
  3. Call self:InitializeScene(scene)

param: tlw_name (string) - The name of the TopLevelWindow control.
param: scene_name (string) - Reserved for future use (scene name identifier).
]]
function BETTERUI.Interface.Window:Initialize(tlw_name, scene_name)
    self.windowName = tlw_name
    self.sceneName = scene_name  -- Store for reference by subclasses
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

    -- Note: Scene creation moved to subclass responsibility (e.g., Banking module)
    -- Subclasses should call:
    --   local scene = ZO_InteractScene:New(sceneName, SCENE_MANAGER, interaction)
    --   self:InitializeFragment()
    --   self:InitializeScene(scene)

    self:InitializeList()
end

--[[
Function: BETTERUI.Interface.Window:SetSpinnerValue
Description: Sets the spinner's range and current value.
param: max (number) - The maximum allowed value (min is always 1).
param: value (number) - The current value to set.
]]
function BETTERUI.Interface.Window:SetSpinnerValue(max, value)
    self.spinner:SetMinMax(1, max)
    self.spinner:SetValue(value)
end

--[[
Function: BETTERUI.Interface.Window:ActivateSpinner
Description: Shows and activates the spinner, deactivating the main list.
Rationale: Shifts focus to the quantity selector (e.g., for splitting stacks).
]]
function BETTERUI.Interface.Window:ActivateSpinner()
    self.spinner:SetHidden(false)
    self.spinner:Activate()
    if (self:GetList() ~= nil) then self:GetList():Deactivate() end
end

--[[
Function: BETTERUI.Interface.Window:DeactivateSpinner
Description: Hides and deactivates the spinner, reactivating the main list.
Rationale: returns focus to the main item list after spinner interaction.
]]
function BETTERUI.Interface.Window:DeactivateSpinner()
    self.spinner:SetValue(1)
    self.spinner:SetHidden(true)
    self.spinner:Deactivate()
    if (self:GetList() ~= nil) then self:GetList():Activate() end
end

--[[
Function: BETTERUI.Interface.Window:UpdateSpinnerConfirmation
Description: Toggles spinner confirmation mode.
Rationale: Used when confirming a stack split or deposit/withdrawal amount.
param: activateSpinner (boolean) - True to show/activate, False to hide/deactivate.
param: list (table) - The list control to refresh.
]]
function BETTERUI.Interface.Window:UpdateSpinnerConfirmation(activateSpinner, list)
    self.confirmationMode = activateSpinner
    if activateSpinner then
        self:ActivateSpinner()
    else
        self:DeactivateSpinner()
    end

    list:RefreshVisible()
    self:ApplySpinnerMinMax(activateSpinner)
    list:SetDirectionalInputEnabled(not activateSpinner)
end

--[[
Function: BETTERUI.Interface.Window:ApplySpinnerMinMax
Description: Updates keybinds when spinner is toggled.
Rationale: Adds specialized keybinds (confirm/cancel) when spinner is active.
param: toggleValue (boolean) - True if spinner is active.
]]
function BETTERUI.Interface.Window:ApplySpinnerMinMax(toggleValue)
    -- Safely toggle a spinner-specific keybind group if one is explicitly provided by a subclass.
    -- Many modules (e.g., Banking) manage spinner keybinds themselves; in those cases this is a no-op.
    if not self.triggerSpinnerBinds or next(self.triggerSpinnerBinds) == nil then return end
    if toggleValue then
        -- Spinner just activated: show its keybinds (if provided by the subclass)
        KEYBIND_STRIP:AddKeybindButtonGroup(self.triggerSpinnerBinds)
    else
        -- Spinner deactivated: remove spinner keybinds (if present)
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.triggerSpinnerBinds)
    end
end

--[[
Function: BETTERUI.Interface.Window:GetList
Description: Gets the current primary list.
Rationale: Accessor method allowing subclasses to override which list is active.
return: table - The active scroll list.
]]
function BETTERUI.Interface.Window:GetList()
    return self.list
end

--[[
Function: BETTERUI.Interface.Window:InitializeKeybind
Description: Initializes keybinds for the window.
Rationale: Sets up default keybind (Back) and placeholders. Subclasses should override.
]]
function BETTERUI.Interface.Window:InitializeKeybind()
    self.coreKeybinds = {
    }

    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.mainKeybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON) -- "Back"

    self.triggerSpinnerBinds = {}
end

--[[
Function: BETTERUI.Interface.Window:InitializeList
Description: Initializes the main parametric scroll list.
Rationale: Creates `BETTERUI_VerticalItemParametricScrollList` with custom settings for BetterUI.
param: listName (string|nil) - Optional list name (not used in default implementation).
]]
function BETTERUI.Interface.Window:InitializeList(listName)
    self.list = BETTERUI_VerticalItemParametricScrollList:New(self.control:GetNamedChild("Container"):GetNamedChild(
    "List"))                                                                                                                 -- replace the itemList with my own generic one (with better gradient size, etc.)

    self:GetList():SetAlignToScreenCenter(true, 30)

    self:GetList().maxOffset = 0
    self:GetList().headerDefaultPadding = 15
    self:GetList().headerSelectedPadding = 0
    self:GetList().universalPostPadding = 5
end

--[[
Function: BETTERUI.Interface.Window:RefreshList
Description: Placeholder for list refresh logic.
Rationale: Intended to be overridden by subclasses.
]]
function BETTERUI.Interface.Window:RefreshList()
end

--[[
Function: BETTERUI.Interface.Window:OnItemSelectedChange
Description: Placeholder for selection change logic.
Rationale: Intended to be overridden by subclasses.
]]
function BETTERUI.Interface.Window:OnItemSelectedChange()
end

--[[
Function: BETTERUI.Interface.Window:SetupList
Description: Configures the main list template.
param: rowTemplate (string) - The XML template name for list rows.
param: SetupFunct (function) - The setup callback function for rows.
]]
function BETTERUI.Interface.Window:SetupList(rowTemplate, SetupFunct)
    self.itemListTemplate = rowTemplate
    self:GetList():AddDataTemplate(rowTemplate, SetupFunct, ZO_GamepadMenuEntryTemplateParametricListFunction)
end

--[[
Function: BETTERUI.Interface.Window:AddTemplate
Description: Adds an additional data template to the list (for multi-template lists).
param: rowTemplate (string) - The XML template name.
param: SetupFunct (function) - The setup callback.
]]
function BETTERUI.Interface.Window:AddTemplate(rowTemplate, SetupFunct)
    self:GetList():AddDataTemplate(rowTemplate, SetupFunct, ZO_GamepadMenuEntryTemplateParametricListFunction)
end

--[[
Function: BETTERUI.Interface.Window:AddEntryToList
Description: Adds a single entry to the list and commits.
param: data (table) - The data object for the entry.
]]
function BETTERUI.Interface.Window:AddEntryToList(data)
    self:GetList():AddEntry(self.itemListTemplate, data)
    self:GetList():Commit()
end

--[[
Function: BETTERUI.Interface.Window:AddColumn
Description: Adds a column header to the window.
param: columnName (string) - The text to display.
param: xOffset (number) - The horizontal position (left-aligned anchor).
]]
function BETTERUI.Interface.Window:AddColumn(columnName, xOffset)
    local colNumber = #self.header.columns + 1
    self.header.columns[colNumber] = CreateControlFromVirtual("Column" .. colNumber,
        self.header:GetNamedChild("HeaderColumnBar"), "BETTERUI_GenericColumn_Label")
    -- Nudge column headers further downward for better alignment with divider bars
    self.header.columns[colNumber]:SetAnchor(LEFT, self.header:GetNamedChild("HeaderColumnBar"), BOTTOMLEFT, xOffset, 109)
    self.header.columns[colNumber]:SetText(columnName)
end

--[[
Function: BETTERUI.Interface.Window:SetTitle
Description: Sets the window title text.
param: headerText (string) - The title text.
]]
function BETTERUI.Interface.Window:SetTitle(headerText)
    self.header:GetNamedChild("Header"):GetNamedChild("TitleContainer"):GetNamedChild("Title"):SetText(headerText)
end

--[[
Function: BETTERUI.Interface.Window:RefreshVisible
Description: Refreshes the list and its visibility.
Rationale: Helper to trigger a full list refresh.
]]
function BETTERUI.Interface.Window:RefreshVisible()
    self:RefreshList()
    self:GetList():RefreshVisible()
end

--[[
Function: BETTERUI.Interface.Window:SetOnSelectedDataChangedCallback
Description: Sets the callback for selection changes.
param: selectedDataCallback (function) - The callback function.
]]
function BETTERUI.Interface.Window:SetOnSelectedDataChangedCallback(selectedDataCallback)
    self.selectedDataCallback = selectedDataCallback
end

--[[
Function: BETTERUI.Interface.Window:InitializeFragment
Description: Initializes scene fragments for the window.
Rationale: Sets up main window fragment and footer fragment.
param: footerControl (userdata|nil) - Optional footer bar control. Defaults to BETTERUI_BankingFooterBar.
]]
function BETTERUI.Interface.Window:InitializeFragment(footerControl)
    self.fragment = ZO_SimpleSceneFragment:New(self.control)
    self.fragment:SetHideOnSceneHidden(true)

    -- Use provided footer control or default to banking footer
    local footer = footerControl or BETTERUI_BankingFooterBar
    self.footerFragment = ZO_SimpleSceneFragment:New(footer)
    self.footerFragment:SetHideOnSceneHidden(true)
end

--[[
Function: BETTERUI.Interface.Window:InitializeScene
Description: Initializes the ESO scene object and registers callbacks.
Rationale: Integrates the window into the ESO scene manager provided scene.
param: scene (object) - The scene object to initialize with.
]]
function BETTERUI.Interface.Window:InitializeScene(scene)
    self.scene = scene
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD)
    scene:AddFragment(self.fragment)
    scene:AddFragment(FRAME_EMOTE_FRAGMENT_INVENTORY)
    scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    scene:AddFragment(self.footerFragment)

    local function SceneStateChange(oldState, newState)
        if (newState == SCENE_SHOWING) then
            KEYBIND_STRIP:AddKeybindButtonGroup(self.coreKeybinds)
            BETTERUI.CIM.SetTooltipWidth(BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH)
        elseif (newState == SCENE_HIDING) then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.coreKeybinds)
            BETTERUI.CIM.SetTooltipWidth(BETTERUI_ZO_GAMEPAD_DEFAULT_PANEL_WIDTH)
        elseif (newState == SCENE_HIDDEN) then

        end
    end
    scene:RegisterCallback("StateChange", SceneStateChange)
end

--[[
Function: BETTERUI.Interface.Window:ToggleScene
Description: Toggles the window's scene visibility.
Note: Uses BETTERUI_BANKING_SCENE_NAME which must be defined by the Banking module.
]]
function BETTERUI.Interface.Window:ToggleScene()
    SCENE_MANAGER:Toggle(BETTERUI_BANKING_SCENE_NAME)
end

--[[
Function: BETTERUI.Interface.Window:OnTabNext
Description: Handler for Next Tab action.
Rationale: Placeholder debug function. Subclasses should override.
]]
function BETTERUI.Interface.Window:OnTabNext()
    -- ddebug("OnTabNext")
end

--[[
Function: BETTERUI.Interface.Window:OnTabPrev
Description: Handler for Previous Tab action.
Rationale: Placeholder debug function. Subclasses should override.
]]
function BETTERUI.Interface.Window:OnTabPrev()
    -- ddebug("OnTabPrev")
end

-------------------------------------------------------------------------------------------------
-- APPLY SEARCH MIXIN
-- SearchManager.lua defines BETTERUI.Interface.SearchMixin with search-related methods.
-- Apply them to the Window class if the mixin is available.
-------------------------------------------------------------------------------------------------

if BETTERUI.Interface.SearchMixin then
    for name, fn in pairs(BETTERUI.Interface.SearchMixin) do
        BETTERUI.Interface.Window[name] = fn
    end
end
