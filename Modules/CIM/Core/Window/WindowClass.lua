--[[
File: Modules/CIM/Core/WindowClass.lua
Purpose: Base window class for gamepad inventory/banking screens.
Author: BetterUI Team
Last Modified: 2026-03-26


Provides core abstractions shared across BetterUI's gamepad screens,
including window management, spinner utilities, and scene integration.

Note: Scene creation is NOT done here - each module (Banking, etc.) should
create its own scene and call InitializeFragment/InitializeScene.
]]

--- @class BETTERUI.Interface
BETTERUI.Interface = BETTERUI.Interface or {}

---==========================================================
--- SECTION: Private Helpers
---==========================================================

--- Wraps an integer value within min/max bounds
--- @private
--- @param value number The value to wrap
--- @param min number The minimum bound
--- @param max number The maximum bound
--- @return number wrappedValue The wrapped integer value
local function WrapInt(value, min, max)
    return (zo_floor(value) - min) % (max - min + 1) + min
end

---==========================================================
--- SECTION: Window Class Definition
---==========================================================

--- @class BETTERUI.Interface.Window : ZO_Object
--- @field windowName string The name of the top-level window
--- @field sceneName string|nil The scene name identifier
--- @field control Control|nil The main UI control
--- @field header Control|nil The header control
--- @field footer Control|nil The footer control
--- @field spinner Control|nil The spinner control
--- @field list table|nil The scroll list
--- @field scene table|nil The scene object
--- @field fragment table|nil The scene fragment
--- @field footerFragment table|nil The footer fragment
--- @field coreKeybinds table|nil Core keybind descriptors
--- @field mainKeybindStripDescriptor table|nil Main keybind strip descriptor
--- @field triggerSpinnerBinds table|nil Spinner-specific keybinds
--- @field confirmationMode boolean|nil Whether spinner confirmation mode is active
--- @field itemListTemplate string|nil The template name for list items
--- @field selectedDataCallback function|nil Callback for selection changes
--- @field header columns table|nil Column header controls
BETTERUI.Interface.Window = ZO_Object:Subclass()

--- Constructor for the Base Window class.
---
--- @param ... any Arguments passed to Initialize.
--- @return BETTERUI.Interface.Window The new window object.
function BETTERUI.Interface.Window:New(...)
    local object = ZO_Object.New(self)
    object:Initialize(...)
    return object
end

--- Initializes the window instance.
---
--- Purpose: Sets up the physical UI control and child references.
--- Mechanics:
--- 1. Creates the physical UI control from 'BETTERUI_GenericInterface' virtual template.
--- 2. Finds and caches references to child controls (Header, Footer, Spinner).
--- 3. Initializes the spinner and wraps its range function.
--- 4. Sets up header navigation callbacks.
---
--- Note: Scene/fragment setup is NOT done here. Subclasses should:
--- 1. Create their own scene (e.g., ZO_InteractScene:New(...))
--- 2. Call self:InitializeFragment()
--- 3. Call self:InitializeScene(scene)
---
--- @param tlw_name string The name of the TopLevelWindow control.
--- @param scene_name string Reserved for future use (scene name identifier).
--- @param virtualTemplate string|nil Optional template override (defaults to BETTERUI_GenericInterface).
function BETTERUI.Interface.Window:Initialize(tlw_name, scene_name, virtualTemplate)
    self.windowName = tlw_name
    self.sceneName = scene_name -- Store for reference by subclasses
    local template = virtualTemplate or "BETTERUI_GenericInterface"
    self.control = BETTERUI.WindowManager:CreateControlFromVirtual(tlw_name, GuiRoot, template)
    self.header = self.control:GetNamedChild("ContainerHeader")
    self.footer = self.control:GetNamedChild("ContainerFooter")

    -- Safely get spinner control from the hierarchy
    local containerList = self.control:GetNamedChild("ContainerList")
    self.spinner = containerList and containerList:GetNamedChild("SpinnerContainer")

    if self.spinner and self.spinner.InitializeSpinner then
        self.spinner:InitializeSpinner()

        -- Wrap the spinner's max and min values
        if self.spinner.spinner then
            self.spinner.spinner.constrainRangeFunc = WrapInt
        end

        -- Stop the spinner inheriting the scrollList's alpha, allowing the list to be deactivated correctly
        self.spinner:SetInheritAlpha(false)
    end

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

---==========================================================
--- SECTION: Spinner Management
---==========================================================

--- Sets the spinner's range and current value.
---
--- @param max number The maximum allowed value (min is always 1).
--- @param value number The current value to set.
function BETTERUI.Interface.Window:SetSpinnerValue(max, value)
    if not self.spinner then return end
    self.spinner:SetMinMax(1, max)
    self.spinner:SetValue(value)
end

--- Shows and activates the spinner, deactivating the main list.
function BETTERUI.Interface.Window:ActivateSpinner()
    if not self.spinner then return end
    self.spinner:SetHidden(false)
    self.spinner:Activate()
    if (self:GetList() ~= nil) then self:GetList():Deactivate() end
end

--- Hides and deactivates the spinner, reactivating the main list.
function BETTERUI.Interface.Window:DeactivateSpinner()
    if self.spinner then
        self.spinner:SetValue(1)
        self.spinner:SetHidden(true)
        self.spinner:Deactivate()
    end
    if (self:GetList() ~= nil) then self:GetList():Activate() end
end

--- Toggles spinner confirmation mode.
---
--- @param activateSpinner boolean True to show/activate, False to hide/deactivate.
--- @param list table The list control to refresh.
function BETTERUI.Interface.Window:UpdateSpinnerConfirmation(activateSpinner, list)
    self.confirmationMode = activateSpinner
    if activateSpinner then
        self:ActivateSpinner()
    else
        self:DeactivateSpinner()
    end

    if list then
        list:RefreshVisible()
        list:SetDirectionalInputEnabled(not activateSpinner)
    end
    self:ApplySpinnerMinMax(activateSpinner)
end

--- Updates keybinds when spinner is toggled.
---
--- @param toggleValue boolean True if spinner is active.
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

---==========================================================
--- SECTION: List Management
---==========================================================

--- Gets the current primary list.
---
--- @return table|nil list The active scroll list.
function BETTERUI.Interface.Window:GetList()
    return self.list
end

--- Initializes the main parametric scroll list.
---
--- @param listName string|nil Optional list name (not used in default implementation).
function BETTERUI.Interface.Window:InitializeList(listName)
    self.list = BETTERUI_VerticalItemParametricScrollList:New(self.control:GetNamedChild("Container"):GetNamedChild(
        "List")) -- replace the itemList with my own generic one (with better gradient size, etc.)

    self:GetList():SetAlignToScreenCenter(true, 30)

    self:GetList().maxOffset = 0
    self:GetList().headerDefaultPadding = 15
    self:GetList().headerSelectedPadding = 0
    self:GetList().universalPostPadding = 5
end

--- Placeholder for list refresh logic.
--- Subclasses should override this to implement specific refresh behavior.
function BETTERUI.Interface.Window:RefreshList()
    -- Placeholder: subclasses should override for list refresh logic
end

--- Placeholder for selection change logic.
--- Subclasses should override this to handle item selection changes.
function BETTERUI.Interface.Window:OnItemSelectedChange()
    -- Placeholder: subclasses should override for selection change logic
end

--- Configures the main list template.
---
--- @param rowTemplate string The XML template name for list rows.
--- @param setupCallback function The setup callback function for rows.
function BETTERUI.Interface.Window:SetupList(rowTemplate, setupCallback)
    self.itemListTemplate = rowTemplate
    self:GetList():AddDataTemplate(rowTemplate, setupCallback, ZO_GamepadMenuEntryTemplateParametricListFunction)
end

--- Adds an additional data template to the list (for multi-template lists).
---
--- @param rowTemplate string The XML template name.
--- @param setupCallback function The setup callback.
function BETTERUI.Interface.Window:AddTemplate(rowTemplate, setupCallback)
    self:GetList():AddDataTemplate(rowTemplate, setupCallback, ZO_GamepadMenuEntryTemplateParametricListFunction)
end

--- Adds a single entry to the list and commits.
---
--- @param data table The data object for the entry.
function BETTERUI.Interface.Window:AddEntryToList(data)
    self:GetList():AddEntry(self.itemListTemplate, data)
    self:GetList():Commit()
end

---==========================================================
--- SECTION: Keybind Management
---==========================================================

--- Initializes keybinds for the window.
function BETTERUI.Interface.Window:InitializeKeybind()
    self.coreKeybinds = {
    }

    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.mainKeybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON) -- "Back"

    self.triggerSpinnerBinds = {}
end

---==========================================================
--- SECTION: Header and Column Management
---==========================================================

--- Adds a column header to the window.
---
--- @param columnName string The text to display.
--- @param xOffset number The horizontal position (left-aligned anchor from TabBar BOTTOMLEFT).
function BETTERUI.Interface.Window:AddColumn(columnName, xOffset)
    local colNumber = #self.header.columns + 1
    -- Create label as child of HeaderColumnBar for container purposes
    local label = CreateControlFromVirtual("Column" .. colNumber,
        self.header:GetNamedChild("HeaderColumnBar"), "BETTERUI_GenericColumn_Label")
    self.header.columns[colNumber] = label

    -- Find the TabBar control - columns anchor to TabBar's BOTTOMLEFT (like Inventory)
    local tabBar = self.header:GetNamedChild("HeaderTabBar")
    if not tabBar then
        -- Fallback to HeaderColumnBar if TabBar not found
        tabBar = self.header:GetNamedChild("HeaderColumnBar")
    end

    -- Anchor to TabBar's BOTTOMLEFT (matching Inventory's GenericHeader.xml column layout)
    -- Use HEADER_LAYOUT.COLUMNS values which match Inventory offsets (80/592/852/1042/1192)
    label:SetAnchor(LEFT, tabBar, BOTTOMLEFT,
        xOffset, BETTERUI.CIM.CONST.LAYOUT.COLUMN_HEADER_Y_OFFSET)
    label:SetText(columnName)

    -- Set explicit dimensions for proper mouse hit region
    local COLUMN_WIDTHS = BETTERUI.CIM.CONST.LAYOUT.COLUMN_WIDTHS
    local columnWidth = COLUMN_WIDTHS[colNumber] or 100
    label:SetDimensions(columnWidth, 30)


    -- Enable mouse interaction for keyboard/mouse users
    label:SetMouseEnabled(true)
    label.columnIndex = colNumber
    label.owner = self

    -- Mouse click handler to toggle sort on this column
    label:SetHandler("OnMouseUp", function(control, button, upInside)
        if upInside and button == MOUSE_BUTTON_INDEX_LEFT then
            local owner = control.owner
            if owner and owner.headerSortController then
                -- Toggle sort for this specific column (UpdateVisuals called internally)
                owner.headerSortController:ToggleSortForColumn(control.columnIndex)
                PlaySound(SOUNDS.DEFAULT_CLICK)
            end
        end
    end)
end

--- Sets the window title text.
---
--- @param headerText string The title text.
function BETTERUI.Interface.Window:SetTitle(headerText)
    self.header:GetNamedChild("Header"):GetNamedChild("TitleContainer"):GetNamedChild("Title"):SetText(headerText)
end

---==========================================================
--- SECTION: UI Refresh and Callbacks
---==========================================================

--- Refreshes the list and its visibility.
function BETTERUI.Interface.Window:RefreshVisible()
    self:RefreshList()
    self:GetList():RefreshVisible()
end

--- Sets the callback for selection changes.
---
--- @param selectedDataCallback function The callback function.
function BETTERUI.Interface.Window:SetOnSelectedDataChangedCallback(selectedDataCallback)
    self.selectedDataCallback = selectedDataCallback
end

---==========================================================
--- SECTION: Scene and Fragment Management
---==========================================================

--- Initializes scene fragments for the window.
---
--- @param footerControl userdata|nil Optional footer bar control. Defaults to BETTERUI_BankingFooterBar.
function BETTERUI.Interface.Window:InitializeFragment(footerControl)
    self.fragment = ZO_SimpleSceneFragment:New(self.control)
    self.fragment:SetHideOnSceneHidden(true)

    -- Use provided footer control or default to banking footer
    local footer = footerControl or BETTERUI_BankingFooterBar
    self.footerFragment = ZO_SimpleSceneFragment:New(footer)
    self.footerFragment:SetHideOnSceneHidden(true)
end

--- Initializes the ESO scene object and registers callbacks.
--- Uses SceneLifecycleManager for unified lifecycle handling.
---
--- @param scene table The scene object to initialize with.
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

    -- Use SceneLifecycleManager for unified lifecycle handling
    BETTERUI.CIM.SceneLifecycle.Register(self, {
        keybinds = { self.coreKeybinds },
        taskManager = BETTERUI.CIM.Tasks,
        onShowing = function(screen, wasPushed)
            BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.WIDTH)
            -- Allow subclasses to extend via OnSceneShowing
            if screen.OnSceneShowing then
                screen:OnSceneShowing(wasPushed)
            end
        end,
        onHiding = function(screen)
            BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.ZO_WIDTH)
            -- Allow subclasses to extend via OnSceneHiding
            if screen.OnSceneHiding then
                screen:OnSceneHiding()
            end
        end,
        onHidden = function(screen)
            -- Allow subclasses to extend via OnSceneHidden
            if screen.OnSceneHidden then
                screen:OnSceneHidden()
            end
        end,
    })
end

--- Toggles the window's scene visibility.
--- Note: Subclasses must set self.sceneName during initialization for this to work.
function BETTERUI.Interface.Window:ToggleScene()
    if self.sceneName then
        SCENE_MANAGER:Toggle(self.sceneName)
    elseif self.scene then
        -- Fallback: use scene object's name if available
        SCENE_MANAGER:Toggle(self.scene:GetName())
    else
        BETTERUI.Debug("[Window] ToggleScene called but no sceneName or scene is set")
    end
end

---==========================================================
--- SECTION: Navigation Handlers
---==========================================================

--- Handler for Next Tab action.
--- Placeholder: subclasses should override for tab navigation.
function BETTERUI.Interface.Window:OnTabNext()
    -- Placeholder: subclasses should override for tab navigation
end

--- Handler for Previous Tab action.
--- Placeholder: subclasses should override for tab navigation.
function BETTERUI.Interface.Window:OnTabPrev()
    -- Placeholder: subclasses should override for tab navigation
end

---==========================================================
--- SECTION: Mixin Integration
---==========================================================

--- Apply Search Mixin
--- SearchManager.lua defines BETTERUI.Interface.SearchMixin with search-related methods.
--- Apply them to the Window class if the mixin is available.
if BETTERUI.Interface.SearchMixin then
    for name, fn in pairs(BETTERUI.Interface.SearchMixin) do
        BETTERUI.Interface.Window[name] = fn
    end
end
