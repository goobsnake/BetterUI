--[[
File: Modules/CIM/Core/WindowClass.lua
Purpose: Base window class for gamepad inventory/banking screens.


Provides core abstractions shared across BetterUI's gamepad screens,
including window management, spinner utilities, and scene integration.

Note: Scene creation is NOT done here - each module (Banking, etc.) should
create its own scene and call InitializeFragment/InitializeScene.
]]

BETTERUI.Interface = BETTERUI.Interface or {}

---@alias BetterUIWindowList table

---@class BetterUIWindow : ZO_Object
---@field windowName string
---@field sceneName string
---@field control table
---@field header BETTERUI_WindowHeader
---@field footer table|nil
---@field list table|nil
---@field scene table|nil
---@field fragment table|nil
---@field footerFragment table|nil
---@field spinner table|nil
---@field headerSortController table|nil
---@field sortController table|nil
---@field mainKeybindStripDescriptor BetterUIKeybindDescriptorGroup|nil
---@field coreKeybinds BetterUIKeybindDescriptorGroup|nil
---@field triggerSpinnerBinds BetterUIKeybindDescriptorGroup|nil

--- Wraps an integer value within min/max bounds
--- @private
local function WrapInt(value, min, max)
    return (zo_floor(value) - min) % (max - min + 1) + min
end


BETTERUI.Interface.Window = ZO_Object:Subclass()

--- Constructor for the Base Window class.
---@param ... any
---@return BetterUIWindow
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
--- Scene/fragment setup is NOT done here. Subclasses should:
--- 1. Create their own scene (e.g., ZO_InteractScene:New(...))
--- 2. Call self:InitializeFragment()
--- 3. Call self:InitializeScene(scene)
---@param tlw_name string
---@param scene_name string
---@param virtualTemplate string?
function BETTERUI.Interface.Window:Initialize(tlw_name, scene_name, virtualTemplate)
    self.windowName = tlw_name
    self.sceneName = scene_name -- Store for reference by subclasses
    local template = virtualTemplate or "BETTERUI_GenericInterface"
    self.control = BETTERUI.WindowManager:CreateControlFromVirtual(tlw_name, GuiRoot, template)
    self.header = self.control:GetNamedChild("ContainerHeader") --[[@as BETTERUI_WindowHeader]]
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

    self:InitializeList()
end

--- Sets the spinner's range and current value.
---@param max integer
---@param value integer
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
---@param activateSpinner boolean
---@param list table?
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
---@param toggleValue boolean
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
---@return BetterUIWindowList|nil
function BETTERUI.Interface.Window:GetList()
    return self.list
end

--- Initializes the main parametric scroll list.
---@param listName string?
function BETTERUI.Interface.Window:InitializeList(listName)
    local container = self.control and self.control:GetNamedChild("Container")
    local listControl = container and container:GetNamedChild("List")
    if not listControl then return end


    self.list = BETTERUI_VerticalItemParametricScrollList:New(listControl) -- replace the itemList with my own generic one (with better gradient size, etc.)

    self:GetList():SetAlignToScreenCenter(true, 30)

    self:GetList().maxOffset = 0
    self:GetList().headerDefaultPadding = 15
    self:GetList().headerSelectedPadding = 0
    self:GetList().universalPostPadding = 5
end

--- Placeholder for list refresh logic.
function BETTERUI.Interface.Window:RefreshList()
end

--- Placeholder for selection change logic.
function BETTERUI.Interface.Window:OnItemSelectedChange()
end

--- Configures the main list template.
---@param rowTemplate string
---@param setupCallback fun(control: table, data: table, selected: boolean)
function BETTERUI.Interface.Window:SetupList(rowTemplate, setupCallback)
    self.itemListTemplate = rowTemplate
    self:GetList():AddDataTemplate(rowTemplate, setupCallback, ZO_GamepadMenuEntryTemplateParametricListFunction)
end

--- Adds an additional data template to the list (for multi-template lists).
---@param rowTemplate string
---@param setupCallback fun(control: table, data: table, selected: boolean)
function BETTERUI.Interface.Window:AddTemplate(rowTemplate, setupCallback)
    self:GetList():AddDataTemplate(rowTemplate, setupCallback, ZO_GamepadMenuEntryTemplateParametricListFunction)
end

--- Adds a single entry to the list and commits.
---@param data table
function BETTERUI.Interface.Window:AddEntryToList(data)
    self:GetList():AddEntry(self.itemListTemplate, data)
    self:GetList():Commit()
end

--- Initializes keybinds for the window.
function BETTERUI.Interface.Window:InitializeKeybind()
    self.coreKeybinds = {
    }

    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.mainKeybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON) -- "Back"

    self.triggerSpinnerBinds = {}
end

--- Adds a column header to the window.
---@param columnName string
---@param xOffset number
function BETTERUI.Interface.Window:AddColumn(columnName, xOffset)
    local colNumber = #self.header.columns + 1
    -- Create label as child of HeaderColumnBar for container purposes
    -- Prefix with windowName to avoid duplicate global control names across modules
    local label = CreateControlFromVirtual(self.windowName .. "Column" .. colNumber,
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
            local headerSortIntegration = BETTERUI.CIM and BETTERUI.CIM.UI and BETTERUI.CIM.UI.HeaderSortIntegration
            local controller = (headerSortIntegration
                and headerSortIntegration.EnsureControllerForOwner
                and headerSortIntegration.EnsureControllerForOwner(owner))
                or (owner and (owner.headerSortController or owner.sortController))
            if controller then
                -- Toggle sort for this specific column (UpdateVisuals called internally)
                controller:ToggleSortForColumn(control.columnIndex)
                PlaySound(SOUNDS.DEFAULT_CLICK)
            end
        end
    end)
end

--- Sets the window title text.
---@param headerText string
function BETTERUI.Interface.Window:SetTitle(headerText)
    self.header:GetNamedChild("Header"):GetNamedChild("TitleContainer"):GetNamedChild("Title"):SetText(headerText)
end

--- Refreshes the list and its visibility.
function BETTERUI.Interface.Window:RefreshVisible()
    self:RefreshList()
    self:GetList():RefreshVisible()
end

--- Sets the callback for selection changes.
---@param selectedDataCallback fun(data: table?)
function BETTERUI.Interface.Window:SetOnSelectedDataChangedCallback(selectedDataCallback)
    self.selectedDataCallback = selectedDataCallback
end

--- Initializes scene fragments for the window.
---@param footerControl table?
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
---@param scene table
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
        taskManager = self.taskManager or BETTERUI.CIM.Tasks,
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
--- Subclasses must set self.sceneName during initialization for this to work.
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

function BETTERUI.Interface.Window:OnTabNext()
end

function BETTERUI.Interface.Window:OnTabPrev()
end

--- Apply Search Mixin
--- SearchManager.lua defines BETTERUI.Interface.SearchMixin with search-related methods.
--- Apply them to the Window class if the mixin is available.
if BETTERUI.Interface.SearchMixin then
    for name, fn in pairs(BETTERUI.Interface.SearchMixin) do
        BETTERUI.Interface.Window[name] = fn
    end
end
