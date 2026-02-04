--[[
File: Modules/CIM/UI/HeaderSortIntegration.lua
Purpose: Integrates HeaderSortController with parametric scroll lists.
         Hooks HitBeginningOfList callback to enter header sort mode.
Author: BetterUI Team
Last Modified: 2026-01-30

USAGE:
    1. Create HeaderSortController with column definitions
    2. Call BETTERUI.CIM.UI.HeaderSortIntegration.Setup(listInstance, headerController, options)
    3. List will now support D-pad Up at first item → header mode
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.UI then BETTERUI.CIM.UI = {} end

BETTERUI.CIM.UI.HeaderSortIntegration = {}

local HeaderSortIntegration = BETTERUI.CIM.UI.HeaderSortIntegration

-------------------------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------------------------

local HEADER_MODE_KEYBIND_LAYER = "HeaderSortMode"

-------------------------------------------------------------------------------------------------
-- KEYBIND DESCRIPTORS
-------------------------------------------------------------------------------------------------

--[[
Function: CreateHeaderModeKeybinds
Description: Creates keybind descriptors for header sort navigation mode.
param: controller (HeaderSortController) - The header sort controller instance.
param: onExitCallback (function) - Called when exiting header mode.
param: onSortCallback (function) - Called when sort is toggled.
return: table - Keybind descriptor for header mode.
]]
local function CreateHeaderModeKeybinds(controller, onExitCallback, onSortCallback)
    return {
        alignment = KEYBIND_STRIP_ALIGN_CENTER,
        -- A Button - Toggle Sort
        {
            name = GetString(SI_BETTERUI_HEADER_SORT), -- "SORT"
            keybind = "UI_SHORTCUT_PRIMARY",
            visible = function()
                return controller:IsActive()
            end,
            callback = function()
                if controller:ToggleSort() then
                    if onSortCallback then
                        onSortCallback()
                    end
                end
            end,
        },
        -- B Button - Exit Header Mode
        {
            name = GetString(SI_GAMEPAD_BACK_OPTION),
            keybind = "UI_SHORTCUT_NEGATIVE",
            visible = function()
                return controller:IsActive()
            end,
            callback = function()
                if onExitCallback then
                    onExitCallback()
                end
            end,
        },
        -- D-pad navigation keybinds (ethereal = hidden from UI)
        -- Note: Uses keybinds instead of DIRECTIONAL_INPUT to avoid
        -- protected function errors with IsKeyDown
        {
            keybind = "UI_SHORTCUT_LEFT_STICK_LEFT",
            ethereal = true,
            callback = function()
                if controller:IsActive() and controller:NavigateLeft() then
                    PlaySound(SOUNDS.HOR_LIST_ITEM_SELECTED)
                end
            end,
        },
        {
            keybind = "UI_SHORTCUT_LEFT_STICK_RIGHT",
            ethereal = true,
            callback = function()
                if controller:IsActive() and controller:NavigateRight() then
                    PlaySound(SOUNDS.HOR_LIST_ITEM_SELECTED)
                end
            end,
        },
        {
            keybind = "UI_SHORTCUT_LEFT_STICK_DOWN",
            ethereal = true,
            callback = function()
                if onExitCallback then
                    onExitCallback()
                end
            end,
        },
    }
end

-------------------------------------------------------------------------------------------------
-- INTEGRATION SETUP
-------------------------------------------------------------------------------------------------

--[[
Function: HeaderSortIntegration.Setup
Description: Sets up header sort integration for a parametric scroll list.
param: list (table) - The parametric scroll list instance.
param: controller (HeaderSortController) - The header sort controller.
param: options (table) - Configuration options:
       - onEnterHeaderMode: function() - Called when entering header mode
       - onExitHeaderMode: function() - Called when exiting header mode
       - onSortChanged: function(columnKey, direction, sortFn) - Called when sort changes
       - keybindStrip: table - The keybind strip to update
       - mainKeybindDescriptor: table - The main keybind descriptor to restore on exit
return: table - Integration state object for manual control.
]]
function HeaderSortIntegration.Setup(list, controller, options)
    options = options or {}

    local integration = {
        list = list,
        controller = controller,
        isActive = false,
        headerModeKeybinds = nil,
        originalDirectionalInput = nil,
    }

    -- Create header mode keybinds
    integration.headerModeKeybinds = CreateHeaderModeKeybinds(
        controller,
        function() -- onExit
            HeaderSortIntegration.ExitHeaderMode(integration, options)
        end,
        function() -- onSort
            if options.onSortChanged then
                local column, direction = controller:GetActiveSortColumn()
                if column then
                    options.onSortChanged(column.key, direction, column.sortFn)
                end
            end
        end
    )

    -- Hook HitBeginningOfList callback to enter header mode
    list:SetOnHitBeginningOfListCallback(function()
        if not integration.isActive then
            HeaderSortIntegration.EnterHeaderMode(integration, options)
        end
    end)

    -- Store reference on list for external access
    list._headerSortIntegration = integration

    return integration
end

--[[
Function: HeaderSortIntegration.EnterHeaderMode
Description: Enters header sort navigation mode.
param: integration (table) - The integration state object.
param: options (table) - Configuration options from Setup.
]]
function HeaderSortIntegration.EnterHeaderMode(integration, options)
    if integration.isActive then return end

    integration.isActive = true
    integration.controller:EnterHeaderMode()

    -- Deactivate list's directional input to prevent scrolling
    if integration.list.directionalInputEnabled ~= nil then
        integration.originalDirectionalInput = integration.list.directionalInputEnabled
        integration.list:SetDirectionalInputEnabled(false)
    end

    -- Swap keybind strip (navigation is now handled via ethereal keybinds)
    if options.keybindStrip and options.mainKeybindDescriptor then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(options.mainKeybindDescriptor)
        KEYBIND_STRIP:AddKeybindButtonGroup(integration.headerModeKeybinds)
    end

    -- Callback
    if options.onEnterHeaderMode then
        options.onEnterHeaderMode()
    end
end

--[[
Function: HeaderSortIntegration.ExitHeaderMode
Description: Exits header sort navigation mode and returns to list.
param: integration (table) - The integration state object.
param: options (table) - Configuration options from Setup.
]]
function HeaderSortIntegration.ExitHeaderMode(integration, options)
    if not integration.isActive then return end

    integration.isActive = false
    integration.controller:ExitHeaderMode()

    -- Restore list's directional input
    if integration.originalDirectionalInput ~= nil then
        integration.list:SetDirectionalInputEnabled(integration.originalDirectionalInput)
        integration.originalDirectionalInput = nil
    end

    -- Swap keybind strip back
    if options.keybindStrip and options.mainKeybindDescriptor then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(integration.headerModeKeybinds)
        KEYBIND_STRIP:AddKeybindButtonGroup(options.mainKeybindDescriptor)
    end

    -- Re-activate list
    if integration.list.Activate then
        integration.list:Activate()
    end

    -- Callback
    if options.onExitHeaderMode then
        options.onExitHeaderMode()
    end
end

--[[
Function: HeaderSortIntegration.IsActive
Description: Returns whether header mode is currently active for an integration.
param: integration (table) - The integration state object.
return: boolean - True if in header mode.
]]
function HeaderSortIntegration.IsActive(integration)
    return integration and integration.isActive
end

-------------------------------------------------------------------------------------------------
-- MIXIN PATTERN
-------------------------------------------------------------------------------------------------

--[[
Function: HeaderSortIntegration.ApplyMixin
Description: Injects EnterHeaderSortMode() and ExitHeaderSortMode() methods into an instance.
             This eliminates duplicate code across Inventory and Banking modules.
param: instance (table) - The class instance to add methods to (e.g., InventoryClass, BankingClass)
param: config (table) - Configuration options:
       - list: The parametric scroll list instance
       - keybindDescriptor: The main keybind descriptor to swap out/restore
       - headerControllerFn: function() returning the header sort controller
       - initControllerFn: function() to initialize the controller if needed
       - refreshFn: function() to refresh the list after sort changes (optional)
]]
function HeaderSortIntegration.ApplyMixin(instance, config)
    if not instance or not config then return end

    --- Enters header sort navigation mode.
    --- Called when user presses D-pad Up at the first item in the list.
    function instance:EnterHeaderSortMode()
        if self.isInHeaderSortMode then return end

        -- Support both static list and dynamic listFn for screens with multiple lists (e.g., Inventory + CraftBag)
        local list = (config.listFn and config.listFn()) or config.list or self.list or self.itemList
        if not list or list:GetNumItems() == 0 then
            return
        end

        -- Initialize controller if needed
        if config.initControllerFn then
            config.initControllerFn()
        end

        local controller = config.headerControllerFn and config.headerControllerFn()
        if not controller then return end

        self.isInHeaderSortMode = true

        -- Deactivate the item list (stop list directional input)
        if list.Deactivate then
            list:Deactivate()
        end

        -- Enter header mode on controller
        controller:EnterHeaderMode()

        -- Play sound for entering header mode
        PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)

        -- Swap keybinds to header mode
        local mainKeybinds = config.keybindDescriptor or self.mainKeybindStripDescriptor or self.coreKeybinds
        if mainKeybinds then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(mainKeybinds)
        end

        -- Create header mode keybinds via shared CIM factory
        if not self.headerSortKeybindDescriptor then
            self.headerSortKeybindDescriptor = controller:CreateKeybindDescriptor(
                function() self:ExitHeaderSortMode() end
            )
        end
        KEYBIND_STRIP:AddKeybindButtonGroup(self.headerSortKeybindDescriptor)
    end

    --- Exits header sort navigation mode.
    --- Returns focus to the item list.
    function instance:ExitHeaderSortMode()
        if not self.isInHeaderSortMode then return end

        self.isInHeaderSortMode = false

        local controller = config.headerControllerFn and config.headerControllerFn()
        if controller then
            controller:ExitHeaderMode()
        end

        -- Play sound for exiting header mode
        PlaySound(SOUNDS.GAMEPAD_MENU_BACK)

        -- Restore keybinds
        if self.headerSortKeybindDescriptor then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.headerSortKeybindDescriptor)
        end

        local mainKeybinds = config.keybindDescriptor or self.mainKeybindStripDescriptor or self.coreKeybinds
        if mainKeybinds then
            KEYBIND_STRIP:AddKeybindButtonGroup(mainKeybinds)
        end

        -- Reactivate the item list
        local list = (config.listFn and config.listFn()) or config.list or self.list or self.itemList
        if list and list.Activate then
            list:Activate()
        end
    end
end
