--[[
File: Modules/CIM/UI/HeaderSortIntegration.lua
Purpose: Installs the shared header-sort owner contract.
         One integration object now owns owner methods, keybind swapping,
         optional list-start entry, and navigation suspension hooks.
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.UI then BETTERUI.CIM.UI = {} end

BETTERUI.CIM.UI.HeaderSortIntegration = {}

local HeaderSortIntegration = BETTERUI.CIM.UI.HeaderSortIntegration

local function ResolveList(integration)
    if integration.listFn then
        return integration.listFn(integration.owner)
    end

    return integration.list or (integration.owner and (integration.owner.list or integration.owner.itemList))
end

local function ResolveController(integration)
    if integration.initControllerFn then
        integration.initControllerFn(integration.owner)
    end

    if integration.headerControllerFn then
        return integration.headerControllerFn(integration.owner)
    end

    return integration.controller
end

local function GetHeaderKeybindDescriptor(integration, controller)
    if not controller then
        return nil
    end

    if not controller._headerSortKeybindDescriptor and controller.CreateKeybindDescriptor then
        controller._headerSortKeybindDescriptor = controller:CreateKeybindDescriptor(function()
            HeaderSortIntegration.ExitHeaderMode(integration)
        end)
    end

    return controller._headerSortKeybindDescriptor
end

--- Installs the shared header sort owner contract.
---@param owner table
---@param options table?
---@return table integration
function HeaderSortIntegration.Install(owner, options)
    options = options or {}

    local integration = {
        owner = owner,
        list = options.list,
        listFn = options.listFn,
        controller = options.controller,
        headerControllerFn = options.headerControllerFn,
        initControllerFn = options.initControllerFn,
        keybindDescriptor = options.keybindDescriptor or options.mainKeybindDescriptor,
        deactivateNavigationFn = options.deactivateNavigationFn,
        reactivateNavigationFn = options.reactivateNavigationFn,
        onEnterHeaderMode = options.onEnterHeaderMode,
        onExitHeaderMode = options.onExitHeaderMode,
        autoEnterOnListStart = options.autoEnterOnListStart == true,
        isActive = false,
        activeKeybindDescriptor = nil,
    }

    owner._headerSortIntegration = integration

    function owner:EnterHeaderSortMode()
        return HeaderSortIntegration.EnterHeaderMode(integration)
    end

    function owner:ExitHeaderSortMode()
        return HeaderSortIntegration.ExitHeaderMode(integration)
    end

    if integration.autoEnterOnListStart then
        local list = ResolveList(integration)
        if list and list.SetOnHitBeginningOfListCallback then
            list:SetOnHitBeginningOfListCallback(function()
                if not integration.isActive then
                    owner:EnterHeaderSortMode()
                end
            end)
        end
    end

    return integration
end

--- Backward-compatible wrapper for older static-list callers.
---@param list table
---@param controller table
---@param options table?
---@return table integration
function HeaderSortIntegration.Setup(list, controller, options)
    options = options or {}
    local owner = options.owner or { list = list }
    options.list = list
    options.controller = controller
    if options.autoEnterOnListStart == nil then
        options.autoEnterOnListStart = true
    end
    return HeaderSortIntegration.Install(owner, options)
end

--- Enters header sort navigation mode.
---@param integration table
---@return boolean
function HeaderSortIntegration.EnterHeaderMode(integration)
    if integration.isActive then
        return false
    end

    local owner = integration.owner
    local navigationSuspended = false
    if integration.deactivateNavigationFn then
        integration.deactivateNavigationFn(owner)
        navigationSuspended = true
    end

    local list = ResolveList(integration)
    if not list or not list.GetNumItems or list:GetNumItems() == 0 then
        if navigationSuspended and integration.reactivateNavigationFn then
            integration.reactivateNavigationFn(owner)
        end
        return false
    end

    local controller = ResolveController(integration)
    if not controller or not controller.EnterHeaderMode then
        if navigationSuspended and integration.reactivateNavigationFn then
            integration.reactivateNavigationFn(owner)
        end
        return false
    end

    if controller:EnterHeaderMode() == false then
        if navigationSuspended and integration.reactivateNavigationFn then
            integration.reactivateNavigationFn(owner)
        end
        return false
    end

    integration.controller = controller
    integration.isActive = true
    owner.isInHeaderSortMode = true

    PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)

    if KEYBIND_STRIP and KEYBIND_STRIP.RemoveAllKeyButtonGroups then
        KEYBIND_STRIP:RemoveAllKeyButtonGroups()
    end

    integration.activeKeybindDescriptor = GetHeaderKeybindDescriptor(integration, controller)
    if integration.activeKeybindDescriptor and KEYBIND_STRIP and KEYBIND_STRIP.AddKeybindButtonGroup then
        KEYBIND_STRIP:AddKeybindButtonGroup(integration.activeKeybindDescriptor)
    end

    if integration.onEnterHeaderMode then
        integration.onEnterHeaderMode(owner, controller, list)
    end

    return true
end

--- Exits header sort navigation mode and returns to the list.
---@param integration table
---@return boolean
function HeaderSortIntegration.ExitHeaderMode(integration)
    if not integration.isActive then
        return false
    end

    local owner = integration.owner
    local controller = integration.controller or ResolveController(integration)

    integration.isActive = false
    owner.isInHeaderSortMode = false

    if controller and controller.ExitHeaderMode then
        controller:ExitHeaderMode()
    end

    PlaySound(SOUNDS.GAMEPAD_MENU_BACK)

    if integration.activeKeybindDescriptor and KEYBIND_STRIP and KEYBIND_STRIP.RemoveKeybindButtonGroup then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(integration.activeKeybindDescriptor)
        integration.activeKeybindDescriptor = nil
    end

    if integration.keybindDescriptor and KEYBIND_STRIP and KEYBIND_STRIP.AddKeybindButtonGroup then
        KEYBIND_STRIP:AddKeybindButtonGroup(integration.keybindDescriptor)
        if KEYBIND_STRIP.UpdateKeybindButtonGroup then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(integration.keybindDescriptor)
        end
    end

    if owner.EnsureHeaderKeybindsActive then
        owner:EnsureHeaderKeybindsActive()
    end

    if integration.reactivateNavigationFn then
        integration.reactivateNavigationFn(owner)
    end

    if integration.onExitHeaderMode then
        integration.onExitHeaderMode(owner, controller)
    end

    return true
end

---@param integration table?
---@return boolean
function HeaderSortIntegration.IsActive(integration)
    return integration and integration.isActive or false
end

--- Backward-compatible wrapper around the unified installer.
---@param instance table
---@param config table
---@return table?
function HeaderSortIntegration.ApplyMixin(instance, config)
    if not instance or not config then
        return nil
    end

    return HeaderSortIntegration.Install(instance, config)
end
