--[[
File: Modules/CIM/UI/HeaderSortIntegration.lua
Purpose: Integrates HeaderSortController with parametric scroll lists.
         Hooks HitBeginningOfList callback to enter header sort mode.

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


-------------------------------------------------------------------------------------------------
-- KEYBIND DESCRIPTORS
-------------------------------------------------------------------------------------------------

--- Creates keybind descriptors for header sort navigation mode.
---
--- @param controller table The header sort controller instance.
--- @param onExitCallback function Called when exiting header mode.
--- @param onSortCallback function Called when sort is toggled.
--- @return table Keybind descriptor for header mode.
local function CreateHeaderModeKeybinds(controller, onExitCallback, onSortCallback)
    return {
        alignment = KEYBIND_STRIP_ALIGN_CENTER,
        -- A Button - Toggle Sort
        {
            name = GetString(rawget(_G, "SI_BETTERUI_HEADER_SORT")), -- "SORT"
            keybind = "UI_SHORTCUT_PRIMARY",
            visible = function()
                return controller:IsActive()
            end,
            callback = function()
                if controller:ToggleSort() then
                    if onSortCallback then
                        onSortCallback()
                    end
                    KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
                end
            end,
        },
        -- B Button - Exit Header Mode
        {
            name = GetString(rawget(_G, "SI_GAMEPAD_BACK_OPTION")),
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
        -- X Button - Clear Sort
        {
            ---@diagnostic disable-next-line: undefined-global
            name = GetString(rawget(_G, "SI_BETTERUI_CLEAR_SORT")),
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = function()
                if not controller:IsActive() then return false end
                local currentDirection = controller.sortDirections[controller:GetCurrentColumnIndex()]
                return currentDirection and currentDirection ~= BETTERUI.CIM.UI.HeaderSortController.SORT_DIRECTION.NONE
            end,
            callback = function()
                if controller:ClearSort() then
                    if onSortCallback then
                        onSortCallback()
                    end
                    KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
                end
            end,
        },
        -- LB: Navigate to previous column (visible on keybind strip)
        {
            order = 40,
            name = function()
                local idx = controller:GetCurrentColumnIndex()
                if idx > 1 then
                    local col = controller.columns[idx - 1]
                    return col and (col.originalText or col.name) or ""
                end
                return ""
            end,
            keybind = "UI_SHORTCUT_LEFT_SHOULDER",
            visible = function()
                return controller:IsActive() and controller:GetCurrentColumnIndex() > 1
            end,
            callback = function()
                if controller:IsActive() and controller:NavigateLeft() then
                    PlaySound(SOUNDS.HOR_LIST_ITEM_SELECTED)
                    KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
                end
            end,
        },
        -- RB: Navigate to next column (visible on keybind strip)
        {
            order = 50,
            name = function()
                local idx = controller:GetCurrentColumnIndex()
                local count = #controller.columns
                if idx < count then
                    local col = controller.columns[idx + 1]
                    return col and (col.originalText or col.name) or ""
                end
                return ""
            end,
            keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
            visible = function()
                return controller:IsActive() and controller:GetCurrentColumnIndex() < #controller.columns
            end,
            callback = function()
                if controller:IsActive() and controller:NavigateRight() then
                    PlaySound(SOUNDS.HOR_LIST_ITEM_SELECTED)
                    KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
                end
            end,
        },
        -- NOTE: Stick-direction keybinds (UI_SHORTCUT_LEFT_STICK_*) do not work in
        -- header sort mode because DIRECTIONAL_INPUT routes stick input to the game
        -- world when no list is actively consuming it. B button is the reliable exit.
    }
end

-------------------------------------------------------------------------------------------------
-- INTEGRATION SETUP
-------------------------------------------------------------------------------------------------

--- Sets up header sort integration for a parametric scroll list.
---
--- @param list table The parametric scroll list instance.
--- @param controller table The header sort controller.
--- @param options table Configuration options.
--- @return table Integration state object for manual control.
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

--- Enters header sort navigation mode.
---
--- @param integration table The integration state object.
--- @param options table Configuration options from Setup.
function HeaderSortIntegration.EnterHeaderMode(integration, options)
    if integration.isActive then return end

    integration.isActive = true
    integration.controller:EnterHeaderMode()

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

--- Exits header sort navigation mode and returns to list.
---
--- @param integration table The integration state object.
--- @param options table Configuration options from Setup.
function HeaderSortIntegration.ExitHeaderMode(integration, options)
    if not integration.isActive then return end

    integration.isActive = false
    integration.controller:ExitHeaderMode()

    -- Swap keybind strip back
    if options.keybindStrip and options.mainKeybindDescriptor then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(integration.headerModeKeybinds)
        KEYBIND_STRIP:AddKeybindButtonGroup(options.mainKeybindDescriptor)
    end

    -- Callback
    if options.onExitHeaderMode then
        options.onExitHeaderMode()
    end
end

--- Returns whether header mode is currently active for an integration.
---
--- @param integration table The integration state object.
--- @return boolean True if in header mode.
function HeaderSortIntegration.IsActive(integration)
    return integration and integration.isActive
end

-------------------------------------------------------------------------------------------------
-- MIXIN PATTERN
-------------------------------------------------------------------------------------------------

--- Injects EnterHeaderSortMode() and ExitHeaderSortMode() methods into an instance.
---
--- Purpose: This eliminates duplicate code across Inventory and Banking modules.
---
--- @param instance table The class instance to add methods to (e.g., InventoryClass, BankingClass).
--- @param config table Configuration options.
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

        -- Enter header mode on controller
        controller:EnterHeaderMode()

        -- Play sound for entering header mode
        PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)

        -- Swap keybinds to header mode
        -- First, clear all keybind groups to prevent stale action names showing
        -- (e.g., "Equip"/"Use" lingering from rapid button presses before entering sort mode)
        KEYBIND_STRIP:RemoveAllKeyButtonGroups()

        -- Create header mode keybinds via shared CIM factory
        -- Cache descriptor on the controller itself to support multiple independent lists (Inventory/CraftBag)
        if not controller._headerSortKeybindDescriptor then
            controller._headerSortKeybindDescriptor = controller:CreateKeybindDescriptor(
                function() self:ExitHeaderSortMode() end
            )
        end
        self._activeHeaderSortKeybindDescriptor = controller._headerSortKeybindDescriptor
        KEYBIND_STRIP:AddKeybindButtonGroup(self._activeHeaderSortKeybindDescriptor)
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
        if self._activeHeaderSortKeybindDescriptor then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self._activeHeaderSortKeybindDescriptor)
            self._activeHeaderSortKeybindDescriptor = nil
        elseif self.headerSortKeybindDescriptor then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.headerSortKeybindDescriptor)
        end

        local mainKeybinds = config.keybindDescriptor or self.mainKeybindStripDescriptor or self.coreKeybinds
        if mainKeybinds then
            KEYBIND_STRIP:AddKeybindButtonGroup(mainKeybinds)
            KEYBIND_STRIP:UpdateKeybindButtonGroup(mainKeybinds)
        end

        local instanceObj = self
        if instanceObj.EnsureHeaderKeybindsActive then
            instanceObj:EnsureHeaderKeybindsActive()
        end
    end
end
