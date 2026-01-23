--[[
File: Modules/CIM/InterfaceLibrary.lua
Purpose: Base window class and UI utilities for gamepad inventory/banking.
         Provides core abstractions shared across BetterUI's gamepad screens,
         including window management, search integration, and spinner utilities.
Author: BetterUI Team
Last Modified: 2026-01-19
]]

local _

BETTERUI.Interface = BETTERUI.Interface or {}

--- Ensures a keybind descriptor is added to the keybind strip (handles duplicates).
---
--- Purpose: Safely registers a keybind group without causing duplicate keybind errors.
--- Mechanics: Iterates existing groups; if found, updates it. If not, adds it.
--- References: Used by Window:ApplySpinnerMinMax and other dynamic keybind overrides.
---
--- @param descriptor table The keybind descriptor to add.

--[[
Function: BETTERUI.Interface.EnsureKeybindGroupAdded
Description: Safely registers a keybind group without causing duplicates.
Rationale: Prevent errors when adding same keybind descriptor multiple times.
Mechanism: Iterates existing groups; if found, updates it. If not, adds it.
param: descriptor (table) - The keybind descriptor to add.
]]
function BETTERUI.Interface.EnsureKeybindGroupAdded(descriptor)
    if not descriptor or not KEYBIND_STRIP then return end
    local groups = KEYBIND_STRIP.keybindButtonGroups or {}
    for _, group in ipairs(groups) do
        if group == descriptor then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(descriptor)
            return
        end
    end
    KEYBIND_STRIP:AddKeybindButtonGroup(descriptor)
    KEYBIND_STRIP:UpdateKeybindButtonGroup(descriptor)
end

--[[
Function: BETTERUI.Interface.CreateSearchKeybindDescriptor
Description: Creates keybind descriptors for text search functionality.
Rationale: Standardizes search navigation (Select, Back, Down) across modules.
Mechanism: Returns a table of keybind definitions with visibility callbacks tied to the search context.
param: context (table) - The search context object (must have textSearchHeaderControl, searchQuery, etc.).
return: table - Array of keybind descriptors.
]]
function BETTERUI.Interface.CreateSearchKeybindDescriptor(context)
    local function HasVisibleSearchControl()
        if not context or not context.textSearchHeaderControl then return false end
        return not context.textSearchHeaderControl:IsHidden()
    end

    local function HasSearchText()
        if not context then return false end
        local text = context.searchQuery
        return text ~= nil and tostring(text) ~= ""
    end

    return {
        {
            name = function()
                return GetString(SI_GAMEPAD_SELECT_OPTION)
            end,
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            keybind = "UI_SHORTCUT_PRIMARY",
            disabledDuringSceneHiding = true,
            visible = function()
                return HasVisibleSearchControl()
            end,
            callback = function()
                if context and context.ExitSearchFocus then
                    context:ExitSearchFocus()
                end
            end,
        },
        {
            name = function()
                local hasText = context and context.searchQuery and tostring(context.searchQuery) ~= ""
                if hasText then
                    return GetString(SI_BETTERUI_CLEAR_SEARCH) or GetString(SI_GAMEPAD_SELECT_OPTION)
                end
                return GetString(SI_GAMEPAD_BACK_OPTION)
            end,
            alignment = KEYBIND_STRIP_ALIGN_RIGHT,
            keybind = "UI_SHORTCUT_NEGATIVE",
            disabledDuringSceneHiding = true,
            visible = function()
                return HasVisibleSearchControl()
            end,
            callback = function()
                local hasText = HasSearchText()
                if hasText then
                    if context and context.ClearTextSearch then
                        context:ClearTextSearch()
                    end
                else
                    if context and context.ExitSearchFocus then
                        context:ExitSearchFocus()
                    end
                end
            end,
        },
        {
            name = function()
                return GetString(SI_GAMEPAD_SCRIPTS_KEYBIND_DOWN) or "Down"
            end,
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            keybind = "UI_SHORTCUT_DOWN",
            disabledDuringSceneHiding = true,
            visible = function()
                return HasVisibleSearchControl()
            end,
            callback = function()
                if context and context.ExitSearchFocus then
                    context:ExitSearchFocus()
                end
            end,
        },
    }
end

BETTERUI_BANKING_SCENE_NAME = "BETTERUI_BANKING"

local BANKING_INTERACTION =
{
    type = "Banking",
    interactTypes = { INTERACTION_BANK },
}

local function WrapInt(value, min, max)
    return (zo_floor(value) - min) % (max - min + 1) + min
end

--- Sets tooltip panel width and repositions the left tooltip.
---
--- Purpose: Adjusts the UI layout to accommodate wider or narrower lists.
--- Mechanics: Resizes GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT and anchors the tooltip relative to it.
--- References: Called during scene state changes (SceneStateChange) in InterfaceLibrary.
---
--- @param width number The new width of the background fragment.
--[[
Function: BETTERUI.CIM.SetTooltipWidth
Description: Sets tooltip panel width and repositions the left tooltip.
Rationale: Adjusts the UI layout to accommodate wider or narrower lists dynamically.
Mechanism: Resizes GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT and anchors the tooltip relative to it.
param: width (number) - The new width of the background fragment.
References: Called during scene state changes (SceneStateChange) in InterfaceLibrary.
]]
function BETTERUI.CIM.SetTooltipWidth(width)
    -- Adjust background fragment and tooltip anchors for custom inventory width
    GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT.control:SetWidth(width)
    GAMEPAD_TOOLTIPS.tooltips.GAMEPAD_LEFT_TOOLTIP.control:SetAnchor(TOPLEFT,GuiRoot,TOPLEFT, width+66, 52)
    GAMEPAD_TOOLTIPS.tooltips.GAMEPAD_LEFT_TOOLTIP.control:SetAnchor(BOTTOMLEFT,GuiRoot,BOTTOMLEFT, width+66, -125)
end

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

--- Initializes the window.
---
--- Purpose: Sets up the control, header, footer, spinner, and scene fragments.
--- Mechanics: Creates the physical UI control from a virtual template (BETTERUI_GenericInterface).
---            Initializes child components (Header, Footer, Spinner).
--- References: Called by :New().
---
--- @param tlw_name string The name of the TopLevelWindow control.
--- @param scene_name string The name of the scene to create/associate.
--[[
Function: BETTERUI.Interface.Window:Initialize
Description: Initializes the window instance.
Rationale: Sets up the control hierarchy, header/footer references, and spinner components.
Mechanism:
  1. Creates the physical UI control from 'BETTERUI_GenericInterface' virtual template.
  2. Finds and caches references to child controls (Header, Footer, Spinner).
  3. Initializes the spinner and wraps its range function.
  4. Sets up parametric list and scene fragments.
param: tlw_name (string) - The name of the TopLevelWindow control.
param: scene_name (string) - The name of the scene to create/associate.
]]
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

    BETTERUI_BANKING_SCENE = ZO_InteractScene:New(BETTERUI_BANKING_SCENE_NAME, SCENE_MANAGER, BANKING_INTERACTION)

    self:InitializeFragment("BETTERUI_BANKING_FRAGMENT")
    self:InitializeScene(BETTERUI_BANKING_SCENE)

    self:InitializeList()
end

--- Sets the spinner's value range and current value.
--- @param max number The maximum value.
--- @param value number The current value.
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
    if(self:GetList() ~= nil) then self:GetList():Deactivate() end
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
    if(self:GetList() ~= nil) then self:GetList():Activate() end
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

--- Gets the current primary list.
--- Can be overridden by subclasses to support multiple lists.
--- @return table The active scroll list.
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


--- Initializes the main parametric scroll list.
--- @param listName string|nil Optional list name (not used in default implementation).
--[[
Function: BETTERUI.Interface.Window:InitializeList
Description: Initializes the main parametric scroll list.
Rationale: Creates `BETTERUI_VerticalItemParametricScrollList` with custom settings for BetterUI.
param: listName (string|nil) - Optional list name (not used in default implementation).
]]
function BETTERUI.Interface.Window:InitializeList(listName)
    self.list = BETTERUI_VerticalItemParametricScrollList:New(self.control:GetNamedChild("Container"):GetNamedChild("List")) -- replace the itemList with my own generic one (with better gradient size, etc.)

    self:GetList():SetAlignToScreenCenter(true, 30)

    self:GetList().maxOffset = 0
    self:GetList().headerDefaultPadding = 15
    self:GetList().headerSelectedPadding = 0
    self:GetList().universalPostPadding = 5
end

--[[
Function: PatchMouseInteractivity (Local Helper)
Description: Makes the search control and its children interactive for mouse users.
]]
local function PatchMouseInteractivity(searchControl, focusHandler)
    if searchControl.SetMouseEnabled then
        searchControl:SetMouseEnabled(true)
    end
    searchControl:SetHandler("OnMouseUp", function()
        if focusHandler and focusHandler.SetFocused then
            focusHandler:SetFocused(true)
        end
    end)

    -- Try to enable mouse and click-to-focus on common child names (edit box or icon)
    local childCandidates = { "Edit", "TextField", "SearchEdit", "Input", "Entry", "EditBox", "SearchIcon", "Icon", "Texture", "InputContainer" }
    for _, name in ipairs(childCandidates) do
        if searchControl.GetNamedChild then
            local child = searchControl:GetNamedChild(name)
            if child then
                if child.SetMouseEnabled then child:SetMouseEnabled(true) end
                if child.SetHandler then
                    child:SetHandler("OnMouseUp", function()
                        if focusHandler and focusHandler.SetFocused then
                            focusHandler:SetFocused(true)
                        end
                    end)
                end
                -- enlarge icon/texture children if possible
                if child.SetDimensions then
                    -- TODO(refactor): pcall(function() child:SetDimensions(28, 28) end)
                    -- If child can be nil, add a nil-check instead:
                    --   if child then child:SetDimensions(28, 28) end
                    pcall(function() child:SetDimensions(28, 28) end)
                end
            end
        end
    end
end

--[[
Function: RegisterNarrationHandler (Local Helper)
Description: Registers narration logic for the search header.
]]
local function RegisterNarrationHandler(window, focusHandler)
    if SCREEN_NARRATION_MANAGER and focusHandler then
        local textSearchHeaderNarrationInfo =
        {
            headerNarrationFunction = function()
                if window.GetHeaderNarration then
                    return window:GetHeaderNarration()
                end
                return nil
            end,
            resultsNarrationFunction = function()
                local narrations = {}
                local currentList = window:GetList()
                if currentList and currentList.IsEmpty and currentList:IsEmpty() then
                    local noItemText = ""
                    if currentList.GetNoItemText then
                        noItemText = currentList:GetNoItemText()
                    end
                    ZO_AppendNarration(narrations, SCREEN_NARRATION_MANAGER:CreateNarratableObject(noItemText))
                end
                return narrations
            end,
        }
        SCREEN_NARRATION_MANAGER:RegisterTextSearchHeader(focusHandler, textSearchHeaderNarrationInfo)
    end
end

--[[
Function: BETTERUI.Interface.Window:AddSearch
Description: Integrates text search capability into the window.
Rationale: Allows users to filter lists by text input (items, banks, etc.).
Mechanism:
  1. Creates a header editbox control using 'ZO_Gamepad_TextSearch_HeaderEditbox'.
  2. Wraps it in `ZO_TextSearch_Header_Gamepad` for logic handling.
  3. Registers keybinds and focus management.
  4. Patches the control to be mouse-interactive using `PatchMouseInteractivity`.
  5. Registers with SCREEN_NARRATION_MANAGER using `RegisterNarrationHandler`.
param: textSearchKeybindStripDescriptor (table) - Keybinds for the search state.
param: onTextSearchTextChangedCallback (function) - Callback when search text changes.
]]
function BETTERUI.Interface.Window:AddSearch(textSearchKeybindStripDescriptor, onTextSearchTextChangedCallback)
    -- Create the header editbox control from the common virtual template
    if not self.header then return end
    self.textSearchKeybindStripDescriptor = textSearchKeybindStripDescriptor
    self.textSearchHeaderControl = CreateControlFromVirtual("$(parent)SearchContainer", self.header, "ZO_Gamepad_TextSearch_HeaderEditbox")
    -- ZO_TextSearch_Header_Gamepad is provided by the engine's common gamepad libraries
    if ZO_TextSearch_Header_Gamepad then
    self.textSearchHeaderFocus = ZO_TextSearch_Header_Gamepad:New(self.textSearchHeaderControl, onTextSearchTextChangedCallback)
    -- Keep the callback so callers can recreate the control under GuiRoot if needed
    self.textSearchCallback = onTextSearchTextChangedCallback
        -- Treat this as the header focus control for the window
        if not self.headerFocus then
            self.headerFocus = self.textSearchHeaderFocus
            -- movement controller not required here, but keep a placeholder
            if not self.movementController then
                if ZO_MovementController then
                    self.movementController = ZO_MovementController:New(MOVEMENT_CONTROLLER_DIRECTION_VERTICAL)
                end
            end
        end

        if ZO_GamepadGenericHeader_SetHeaderFocusControl then
            -- Try the most specific focusable target first (the tabBar control
            -- created by BETTERUI_TabBarScrollList), then the generic header
            -- control, then the root header control. This covers modules that
            -- initialize the header/tabbar on different child controls.
            local headerTarget = nil
            if self.headerGeneric and self.headerGeneric.tabBar and self.headerGeneric.tabBar.control then
                headerTarget = self.headerGeneric.tabBar.control
            elseif self.headerGeneric then
                headerTarget = self.headerGeneric
            else
                headerTarget = self.header
            end
            ZO_GamepadGenericHeader_SetHeaderFocusControl(headerTarget, self.textSearchHeaderControl)
        end

        -- Make the search control slightly larger and mouse-interactive so PC users can click it
        PatchMouseInteractivity(self.textSearchHeaderControl, self.textSearchHeaderFocus)

        -- Register for narration if available
        RegisterNarrationHandler(self, self.textSearchHeaderFocus)
    end

end

--[[
Function: BETTERUI.Interface.Window:IsTextSearchEntryHidden
Description: Checks if the search entry field is hidden.
return: boolean - True if hidden or not initialized, False otherwise.
]]
function BETTERUI.Interface.Window:IsTextSearchEntryHidden()
    if self.textSearchHeaderControl then
        return self.textSearchHeaderControl:IsHidden()
    end
    return true
end

--[[
Function: BETTERUI.Interface.Window:SetTextSearchEntryHidden
Description: Sets the visibility of the search entry field.
param: isHidden (boolean) - True to hide, False to show.
]]
function BETTERUI.Interface.Window:SetTextSearchEntryHidden(isHidden)
    if self.textSearchHeaderControl then
        self.textSearchHeaderControl:SetHidden(isHidden)
    end
end

--[[
Function: BETTERUI.Interface.Window:SetTextSearchFocused
Description: Sets focus state of the search entry.
Rationale: Used to programmatically focus the search box.
Mechanism: Sets focus and brings window to front to ensure it honors input.
param: isFocused (boolean) - True to focus, False to unfocus.
]]
function BETTERUI.Interface.Window:SetTextSearchFocused(isFocused)
    if self.textSearchHeaderFocus and self.headerFocus then
        self.textSearchHeaderFocus:SetFocused(isFocused)
        -- TODO(refactor): Multiple pcall wrappers in search focus handling.
        -- Refactor to explicit nil-checking pattern for clarity and debuggability.
        pcall(function()
            -- Bring search control to front so it's visible and not layered behind header elements
            if self.textSearchHeaderControl and self.textSearchHeaderControl.BringWindowToFront then
                pcall(function() self.textSearchHeaderControl:BringWindowToFront() end)
            end
        end)
    end
end

--[[
Function: BETTERUI.Interface.Window:GetActiveList
Description: Gets the currently active list.
Rationale: Helper to retrieve the list that should currently receive input.
Mechanism: Tries to call `GetCurrentList` (polymorphic) if it exists, otherwise returns `self.list`.
return: table - The active list control.
]]
function BETTERUI.Interface.Window:GetActiveList()
    if self.GetCurrentList then
        local ok, list = pcall(function() return self:GetCurrentList() end)
        if ok then
            return list
        end
    end
    return self.list
end

--[[
Function: BETTERUI.Interface.Window:ActivateSearchHeader
Description: Activates the search header mode.
Rationale: Switches context from list navigation to search input.
Mechanism: Sets internal flag `_searchHeaderActive` and activates the focus object.
]]
function BETTERUI.Interface.Window:ActivateSearchHeader()
    if self.textSearchHeaderFocus and not self._searchHeaderActive then
        self._searchHeaderActive = true
        self.textSearchHeaderFocus:Activate()
        pcall(function()
            if self.textSearchHeaderControl and self.textSearchHeaderControl.BringWindowToFront then
                self.textSearchHeaderControl:BringWindowToFront()
            end
        end)
    end
end

--[[
Function: BETTERUI.Interface.Window:DeactivateSearchHeader
Description: Deactivates the search header mode.
Rationale: Switches context back to list navigation.
]]
function BETTERUI.Interface.Window:DeactivateSearchHeader()
    if self.textSearchHeaderFocus and self._searchHeaderActive then
        self._searchHeaderActive = false
        self.textSearchHeaderFocus:Deactivate()
    end
end

--[[
Function: BETTERUI.Interface.Window:IsSearchHeaderActive
Description: Checks if search header is currently active.
return: boolean - True if active.
]]
function BETTERUI.Interface.Window:IsSearchHeaderActive()
    return self._searchHeaderActive == true
end

--[[
Function: BETTERUI.Interface.Window:ClearSearchText
Description: Clears the current search query.
]]
function BETTERUI.Interface.Window:ClearSearchText()
    if self.textSearchHeaderFocus then
        self.textSearchHeaderFocus:ClearText()
    end
end

--[[
Function: BETTERUI.Interface.Window:IsSearchFocused
Description: Checks if the search box has input focus.
return: boolean - True if focused.
]]
function BETTERUI.Interface.Window:IsSearchFocused()
    return self.textSearchHeaderFocus and self.textSearchHeaderFocus:HasFocus()
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
    self:GetList():AddDataTemplate(rowTemplate,SetupFunct, ZO_GamepadMenuEntryTemplateParametricListFunction)
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
    self.header.columns[colNumber] = CreateControlFromVirtual("Column"..colNumber,self.header:GetNamedChild("HeaderColumnBar"),"BETTERUI_GenericColumn_Label")
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
]]
function BETTERUI.Interface.Window:InitializeFragment()
	self.fragment = ZO_SimpleSceneFragment:New(self.control)
    self.fragment:SetHideOnSceneHidden(true)

    self.footerFragment = ZO_SimpleSceneFragment:New(BETTERUI_BankingFooterBar)
    self.footerFragment:SetHideOnSceneHidden(true)
end

--[[
Function: BETTERUI.Interface.Window:InitializeScene
Description: Initializes the ESO scene object and registers callbacks.
Rationale: Integrates the window into the ESO scene manager provided scene.
param: SCENE_NAME (object) - The existing scene object.
]]
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

--[[
Function: BETTERUI.Interface.Window:ToggleScene
Description: Toggles the window's scene visibility.
]]
function BETTERUI.Interface.Window:ToggleScene()
	--SCENE_MANAGER:Show
	SCENE_MANAGER:Toggle(BETTERUI_BANKING_SCENE_NAME)
end

--[[
Function: BETTERUI.Interface.Window:OnTabNext
Description: Handler for Next Tab action.
Rationale: Placeholder debug function. Subclasses should override.
]]
function BETTERUI.Interface.Window:OnTabNext()
    ddebug("OnTabNext")
end

--[[
Function: BETTERUI.Interface.Window:OnTabPrev
Description: Handler for Previous Tab action.
Rationale: Placeholder debug function. Subclasses should override.
]]
function BETTERUI.Interface.Window:OnTabPrev()
    ddebug("OnTabPrev")
end
