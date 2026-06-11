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

---@param options BetterUIHeaderSortInstallOptions|nil
---@return BetterUIHeaderSortControllerContract
local function NormalizeControllerContract(options)
    local contract = options and options.controllerContract or {}
    return {
        instance = contract.instance or nil,
        field = contract.field or "headerSortController",
        aliasFields = contract.aliasFields or {},
        resolve = contract.resolve or nil,
        initialize = contract.initialize or nil,
    }
end

---@param options BetterUIHeaderSortInstallOptions|nil
---@return BetterUIHeaderSortKeybindContract
local function NormalizeKeybindContract(options)
    local contract = options and options.keybinds or {}
    return {
        mainDescriptor = contract.mainDescriptor or nil,
        -- Additional owner-supplied keybind groups (e.g. tab-bar LB/RB) that
        -- must be suspended while header-sort mode owns the strip.
        ownedDescriptors = contract.ownedDescriptors or {},
    }
end

---@param options BetterUIHeaderSortInstallOptions|nil
---@return BetterUIHeaderSortNavigationContract
local function NormalizeNavigationContract(options)
    local contract = options and options.navigation or {}
    return {
        deactivate = contract.deactivate or nil,
        reactivate = contract.reactivate or nil,
        suspendTabBar = contract.suspendTabBar == true,
    }
end

---@param options BetterUIHeaderSortInstallOptions|nil
---@return BetterUIHeaderSortCallbackContract
local function NormalizeCallbackContract(options)
    local contract = options and options.callbacks or {}
    return {
        onSortChanged = contract.onSortChanged or nil,
        onControllerCreated = contract.onControllerCreated or nil,
        onEnterHeaderMode = contract.onEnterHeaderMode or nil,
        onExitHeaderMode = contract.onExitHeaderMode or nil,
    }
end

local function ResolveList(integration)
    if integration.listFn then
        return integration.listFn(integration.owner)
    end

    return integration.list or (integration.owner and (integration.owner.list or integration.owner.itemList))
end

---@param integration BetterUIHeaderSortIntegration
---@param controller table|nil
local function AssignController(integration, controller)
    if not controller then
        return nil
    end

    local owner = integration.owner
    local controllerContract = integration.controllerContract
    local controllerField = controllerContract.field
    if owner and controllerField then
        owner[controllerField] = controller
    end

    for _, aliasField in ipairs(controllerContract.aliasFields or {}) do
        if owner and aliasField then
            owner[aliasField] = controller
        end
    end

    integration.controller = controller

    if integration.callbacks.onControllerCreated then
        integration.callbacks.onControllerCreated(owner, controller, ResolveList(integration))
    end

    return controller
end

---@param integration BetterUIHeaderSortIntegration
local function BuildController(integration)
    local list = ResolveList(integration)
    if integration.createControllerFn then
        return integration.createControllerFn(integration.owner, list)
    end

    if integration.columns then
        local controllerClass = BETTERUI.CIM and BETTERUI.CIM.UI and BETTERUI.CIM.UI.HeaderSortController
        if controllerClass and controllerClass.New then
            return controllerClass:New(list, integration.columns, integration.callbacks.onSortChanged)
        end
    end

    return nil
end

---@param integration BetterUIHeaderSortIntegration
---@return table|nil
local function PeekController(integration)
    if not integration then
        return nil
    end

    if integration.controller then
        return integration.controller
    end

    local owner = integration.owner
    local controllerContract = integration.controllerContract or {}
    if owner and controllerContract.field and owner[controllerContract.field] then
        return owner[controllerContract.field]
    end

    for _, aliasField in ipairs(controllerContract.aliasFields or {}) do
        if owner and aliasField and owner[aliasField] then
            return owner[aliasField]
        end
    end

    return nil
end

---@param integration BetterUIHeaderSortIntegration
local function ResolveController(integration)
    local existingController = PeekController(integration)
    if existingController then
        integration.controller = existingController
        return existingController
    end

    local controllerContract = integration.controllerContract
    if controllerContract.initialize then
        controllerContract.initialize(integration.owner)
    end

    if controllerContract.resolve then
        local resolvedController = controllerContract.resolve(integration.owner)
        if resolvedController then
            return AssignController(integration, resolvedController)
        end
    end

    return AssignController(integration, BuildController(integration))
end

local function SuspendOwnerTabBar(owner)
    if not owner then
        return
    end
    local tabBar = owner and owner.headerGeneric and owner.headerGeneric.tabBar
    owner._reactivateTabBarAfterHeaderSort = false
    if tabBar and tabBar.active and tabBar.Deactivate then
        tabBar:Deactivate()
        owner._reactivateTabBarAfterHeaderSort = true
    end
end

local function RestoreOwnerTabBar(owner)
    if not owner or not owner._reactivateTabBarAfterHeaderSort then
        return
    end

    owner._reactivateTabBarAfterHeaderSort = false
    local tabBar = owner.headerGeneric and owner.headerGeneric.tabBar
    if tabBar and tabBar.Activate then
        tabBar:Activate()
    end
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
---@param options BetterUIHeaderSortInstallOptions|nil
---@return BetterUIHeaderSortIntegration integration
function HeaderSortIntegration.Install(owner, options)
    options = options or {}

    local controllerContract = NormalizeControllerContract(options)
    local keybinds = NormalizeKeybindContract(options)
    local navigation = NormalizeNavigationContract(options)
    local callbacks = NormalizeCallbackContract(options)

    local integration = {
        owner = owner,
        list = options.list,
        listFn = options.listFn,
        controller = controllerContract.instance,
        controllerContract = controllerContract,
        columns = options.columns,
        callbacks = callbacks,
        createControllerFn = options.createControllerFn,
        keybinds = keybinds,
        keybindDescriptor = keybinds.mainDescriptor,
        navigation = navigation,
        controllerField = controllerContract.field,
        controllerAliasFields = controllerContract.aliasFields,
        autoEnterOnListStart = options.autoEnterOnListStart == true,
        isActive = false,
        activeKeybindDescriptor = nil,
    }

    -- Header-sort mode owns LB/RB, so the owner's tab bar (which registers its
    -- own LB/RB group) is always suspended unless the owner installed custom
    -- navigation handlers. suspendTabBar stays accepted for compatibility.
    navigation.deactivate = navigation.deactivate or SuspendOwnerTabBar
    navigation.reactivate = navigation.reactivate or RestoreOwnerTabBar

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

--- Enters header sort navigation mode.
---@param integration BetterUIHeaderSortIntegration
---@return boolean
function HeaderSortIntegration.EnterHeaderMode(integration)
    if integration.isActive then
        return false
    end

    local owner = integration.owner
    local navigationSuspended = false
    if integration.navigation.deactivate then
        integration.navigation.deactivate(owner)
        navigationSuspended = true
    end

    local list = ResolveList(integration)
    if not list or not list.GetNumItems or list:GetNumItems() == 0 then
        if navigationSuspended and integration.navigation.reactivate then
            integration.navigation.reactivate(owner)
        end
        return false
    end

    local controller = ResolveController(integration)
    if not controller or not controller.EnterHeaderMode then
        if navigationSuspended and integration.navigation.reactivate then
            integration.navigation.reactivate(owner)
        end
        return false
    end

    if controller:EnterHeaderMode() == false then
        if navigationSuspended and integration.navigation.reactivate then
            integration.navigation.reactivate(owner)
        end
        return false
    end

    integration.controller = controller
    integration.isActive = true
    owner.isInHeaderSortMode = true

    PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)

    -- Remove only the keybind groups BetterUI owns; wiping the whole strip
    -- (RemoveAllKeyButtonGroups) would also destroy groups owned by the
    -- native UI and other addons. All owner-supplied groups (main descriptor
    -- plus any extra owned descriptors, e.g. LB/RB groups) are suspended so
    -- the header-sort LB/RB buttons can never collide with them.
    local ownedGroups = {}
    if integration.keybinds.mainDescriptor then
        ownedGroups[#ownedGroups + 1] = integration.keybinds.mainDescriptor
    end
    for _, ownedDescriptor in ipairs(integration.keybinds.ownedDescriptors or {}) do
        ownedGroups[#ownedGroups + 1] = ownedDescriptor
    end

    local removeOwnedGroups = BETTERUI.Interface and BETTERUI.Interface.RemoveOwnedKeybindGroups
    if removeOwnedGroups then
        integration.suspendedKeybindGroups = removeOwnedGroups(ownedGroups)
    elseif KEYBIND_STRIP and KEYBIND_STRIP.RemoveKeybindButtonGroup then
        local removed = {}
        for _, group in ipairs(ownedGroups) do
            if not KEYBIND_STRIP.HasKeybindButtonGroup or KEYBIND_STRIP:HasKeybindButtonGroup(group) then
                KEYBIND_STRIP:RemoveKeybindButtonGroup(group)
                removed[#removed + 1] = group
            end
        end
        integration.suspendedKeybindGroups = removed
    end

    integration.activeKeybindDescriptor = GetHeaderKeybindDescriptor(integration, controller)
    if integration.activeKeybindDescriptor and KEYBIND_STRIP and KEYBIND_STRIP.AddKeybindButtonGroup then
        KEYBIND_STRIP:AddKeybindButtonGroup(integration.activeKeybindDescriptor)
    end

    if integration.callbacks.onEnterHeaderMode then
        integration.callbacks.onEnterHeaderMode(owner, controller, list)
    end

    return true
end

--- Exits header sort navigation mode and returns to the list.
---@param integration BetterUIHeaderSortIntegration
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

    -- Restore exactly the owned groups suspended on enter; fall back to the
    -- legacy main-descriptor re-add when nothing was captured.
    local suspendedGroups = integration.suspendedKeybindGroups
    integration.suspendedKeybindGroups = nil
    local restoreGroups = BETTERUI.Interface and BETTERUI.Interface.RestoreKeybindGroups
    if suspendedGroups and #suspendedGroups > 0 then
        if restoreGroups then
            restoreGroups(suspendedGroups)
        elseif KEYBIND_STRIP and KEYBIND_STRIP.AddKeybindButtonGroup then
            for _, group in ipairs(suspendedGroups) do
                KEYBIND_STRIP:AddKeybindButtonGroup(group)
            end
        end
    elseif integration.keybinds.mainDescriptor and KEYBIND_STRIP and KEYBIND_STRIP.AddKeybindButtonGroup then
        KEYBIND_STRIP:AddKeybindButtonGroup(integration.keybinds.mainDescriptor)
        if KEYBIND_STRIP.UpdateKeybindButtonGroup then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(integration.keybinds.mainDescriptor)
        end
    end

    if owner.EnsureHeaderKeybindsActive then
        owner:EnsureHeaderKeybindsActive()
    end

    if integration.navigation.reactivate then
        integration.navigation.reactivate(owner)
    end

    if integration.callbacks.onExitHeaderMode then
        integration.callbacks.onExitHeaderMode(owner, controller)
    end

    return true
end

---@param integration BetterUIHeaderSortIntegration|nil
---@return table?
function HeaderSortIntegration.EnsureController(integration)
    if not integration then
        return nil
    end
    return ResolveController(integration)
end

---@param owner table?
---@return table?
function HeaderSortIntegration.EnsureControllerForOwner(owner)
    if not owner then
        return nil
    end

    if owner._headerSortIntegration then
        return ResolveController(owner._headerSortIntegration)
    end

    return owner.headerSortController or owner.sortController
end

---@param owner table?
---@return table?
function HeaderSortIntegration.PeekController(owner)
    if not owner then
        return nil
    end

    if owner._headerSortIntegration then
        return PeekController(owner._headerSortIntegration)
    end

    return owner.headerSortController or owner.sortController
end

---@param owner table?
---@return table?
function HeaderSortIntegration.GetController(owner)
    return HeaderSortIntegration.PeekController(owner)
end

---@param integration BetterUIHeaderSortIntegration|nil
---@return boolean
function HeaderSortIntegration.IsActive(integration)
    return integration and integration.isActive or false
end
