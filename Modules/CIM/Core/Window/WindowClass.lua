--[[
File: Modules/CIM/Core/Window/WindowClass.lua
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
--- 2. Finds and caches references to child controls (Header, Footer).
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

    self.header.columns = {}

    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "initialize window", { tlw_name = tlw_name, template = template }) end

    self:InitializeList()
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
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "initialize list", { hasListControl = listControl ~= nil }) end
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
---@param controlPoolPrefix string|nil Short pooled-control name prefix; keeps generated names under the engine limit
function BETTERUI.Interface.Window:SetupList(rowTemplate, setupCallback, controlPoolPrefix)
    self:GetList():AddDataTemplate(rowTemplate, setupCallback, ZO_GamepadMenuEntryTemplateParametricListFunction,
        nil, controlPoolPrefix)
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "list template", { template = rowTemplate }) end
end

--- Adds an additional data template to the list (for multi-template lists).
---@param rowTemplate string
---@param setupCallback fun(control: table, data: table, selected: boolean)
---@param controlPoolPrefix string|nil Short pooled-control name prefix; keeps generated names under the engine limit
function BETTERUI.Interface.Window:AddTemplate(rowTemplate, setupCallback, controlPoolPrefix)
    self:GetList():AddDataTemplate(rowTemplate, setupCallback, ZO_GamepadMenuEntryTemplateParametricListFunction,
        nil, controlPoolPrefix)
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "list template", { template = rowTemplate }) end
end

--- Initializes keybinds for the window.
function BETTERUI.Interface.Window:InitializeKeybind()
    self.coreKeybinds = {
    }

    -- A base window may reach this before a subclass assigns the descriptor; the
    -- engine helper indexes the table directly, so guarantee it exists (without
    -- clobbering a descriptor a subclass already set).
    self.mainKeybindStripDescriptor = self.mainKeybindStripDescriptor or {}

    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.mainKeybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON) -- "Back"

    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "initialize keybinds", {}) end
end

--- Adds a column header to the window.
---@param columnName string
---@param xOffset number
function BETTERUI.Interface.Window:AddColumn(columnName, xOffset)
    local colNumber = #self.header.columns + 1
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.FOOTER, "add footer column", { colNumber = colNumber, xOffset = xOffset }) end
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

    -- Mouse click handler to toggle sort on this column.
    -- Use ZO_PostHookHandler so any existing OnMouseUp handler on the label is
    -- preserved instead of being clobbered by a direct SetHandler assignment.
    if not label._betteruiColumnMouseUpHooked then
        label._betteruiColumnMouseUpHooked = true
        ZO_PostHookHandler(label, "OnMouseUp", function(control, button, upInside)
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
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SCENE, "initialize fragment", {}) end
end

--- Initializes the ESO scene object and registers callbacks.
--- Uses SceneLifecycleManager for unified lifecycle handling.
---@param scene table
function BETTERUI.Interface.Window:InitializeScene(scene)
    self.scene = scene
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SCENE, "initialize scene", { sceneName = self.sceneName }) end
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD)
    scene:AddFragment(self.fragment)
    scene:AddFragment(FRAME_EMOTE_FRAGMENT_INVENTORY)
    scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    scene:AddFragment(self.footerFragment)

    -- Use SceneLifecycleManager for unified lifecycle handling.
    -- coreKeybinds is created later in InitializeKeybind() (subclasses commonly call
    -- InitializeScene before InitializeKeybind), so capturing { self.coreKeybinds }
    -- here would bind {nil} and never add the group. Resolve at show/hide time instead.
    BETTERUI.CIM.SceneLifecycle.Register(self, {
        keybindsResolver = function()
            local groups = {}
            if self.coreKeybinds then groups[#groups + 1] = self.coreKeybinds end
            return groups
        end,
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
        if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SCENE, "toggle scene", { sceneName = self.sceneName }) end
    elseif self.scene then
        -- Fallback: use scene object's name if available
        SCENE_MANAGER:Toggle(self.scene:GetName())
        if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SCENE, "toggle scene", { sceneName = self.scene:GetName() }) end
    else
        if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.GENERAL, "[Window] ToggleScene called but no sceneName or scene is set") end
    end
end

--- Apply Search Mixin
--- SearchManager.lua defines BETTERUI.Interface.SearchMixin with search-related methods.
--- Apply them to the Window class if the mixin is available.
if BETTERUI.Interface.SearchMixin then
    for name, fn in pairs(BETTERUI.Interface.SearchMixin) do
        BETTERUI.Interface.Window[name] = fn
    end
end
