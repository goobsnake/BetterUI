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

local function DescribeDescriptor(descriptor, label)
    local L = BETTERUI.Log
    if L and L.DescribeKeybindDescriptor then
        return L.DescribeKeybindDescriptor(descriptor, label)
    end
    return tostring(descriptor)
end

local function DescribeDescriptors(descriptors, label)
    local L = BETTERUI.Log
    if L and L.DescribeKeybindDescriptors then
        return L.DescribeKeybindDescriptors(descriptors, label)
    end
    return tostring(descriptors)
end

local function DescribeOwnerScene(owner)
    if not owner then return "nil" end
    if owner.scene and owner.scene.GetName then
        local ok, name = pcall(owner.scene.GetName, owner.scene)
        if ok and name then return tostring(name) end
    end
    return tostring(owner.sceneName or owner.scene_name or owner.name or "unknown")
end

local function GetListItemCount(list)
    if list and list.GetNumItems then
        local ok, count = pcall(list.GetNumItems, list)
        if ok then return count end
    end
    return nil
end

local function GetMethod(instance, methodName)
    if not instance then return nil end
    local ok, method = pcall(function() return instance[methodName] end)
    if ok and type(method) == "function" then
        return method
    end
    return nil
end

local function IsListActive(list)
    local isActive = GetMethod(list, "IsActive")
    if not isActive then return nil end
    local ok, active = pcall(isActive, list)
    if ok then return active == true end
    return nil
end

local function DescribeListState(list)
    return {
        items = GetListItemCount(list),
        active = IsListActive(list),
        canDeactivate = GetMethod(list, "Deactivate") ~= nil,
        canActivate = GetMethod(list, "Activate") ~= nil,
    }
end

local function HasKeybindGroup(descriptor)
    local hasGroup = BETTERUI.Interface and BETTERUI.Interface.HasKeybindGroup
    return type(hasGroup) == "function" and hasGroup(descriptor) == true
end

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
        suspendList = contract.suspendList == true,
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
        BETTERUI.CIM.SafeExecute("HeaderSortIntegration:onControllerCreated", integration.callbacks.onControllerCreated, owner, controller, ResolveList(integration))
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

local function SuspendActiveList(integration, list)
    integration.suspendedList = nil
    integration.reactivateListAfterHeaderSort = false

    local deactivate = GetMethod(list, "Deactivate")
    local listActive = IsListActive(list)
    if not deactivate or listActive == false then
        if BETTERUI.Log then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "header sort list suspend skipped", {
                fn = "HeaderSortIntegration.SuspendActiveList",
                reason = deactivate and "inactive" or "missingDeactivate",
                scene = DescribeOwnerScene(integration.owner),
                list = DescribeListState(list),
            })
        end
        return
    end

    local ok, err = pcall(deactivate, list)
    if ok then
        integration.suspendedList = list
        integration.reactivateListAfterHeaderSort = true
        if BETTERUI.Log then
            BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.KEYBIND, "header sort list suspended", {
                fn = "HeaderSortIntegration.SuspendActiveList",
                scene = DescribeOwnerScene(integration.owner),
                list = DescribeListState(list),
            })
        end
    elseif BETTERUI.Log and BETTERUI.Log.Warn then
        BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.KEYBIND, "header sort list suspend failed", {
            fn = "HeaderSortIntegration.SuspendActiveList",
            scene = DescribeOwnerScene(integration.owner),
            error = tostring(err),
            list = DescribeListState(list),
        })
    end
end

local function RestoreActiveList(integration)
    local list = integration.suspendedList
    local shouldReactivate = integration.reactivateListAfterHeaderSort == true
    integration.suspendedList = nil
    integration.reactivateListAfterHeaderSort = false

    if not shouldReactivate then
        return
    end

    local activate = GetMethod(list, "Activate")
    if not activate then
        if BETTERUI.Log and BETTERUI.Log.Warn then
            BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.KEYBIND, "header sort list restore failed", {
                fn = "HeaderSortIntegration.RestoreActiveList",
                reason = "missingActivate",
                scene = DescribeOwnerScene(integration.owner),
                list = DescribeListState(list),
            })
        end
        return
    end

    local ok, err = pcall(activate, list)
    if ok then
        if BETTERUI.Log then
            BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.KEYBIND, "header sort list restored", {
                fn = "HeaderSortIntegration.RestoreActiveList",
                scene = DescribeOwnerScene(integration.owner),
                list = DescribeListState(list),
            })
        end
    elseif BETTERUI.Log and BETTERUI.Log.Warn then
        BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.KEYBIND, "header sort list restore failed", {
            fn = "HeaderSortIntegration.RestoreActiveList",
            scene = DescribeOwnerScene(integration.owner),
            error = tostring(err),
            list = DescribeListState(list),
        })
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

    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        local keybinds = options.keybinds or {}
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SORT, "header sort install", {
            fn = "HeaderSortIntegration.Install",
            scene = DescribeOwnerScene(owner),
            columns = options.columns and #options.columns or 0,
            autoEnter = options.autoEnterOnListStart == true,
            main = DescribeDescriptor(keybinds.mainDescriptor, "main"),
            owned = DescribeDescriptors(keybinds.ownedDescriptors, "owned"),
        })
    end

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
            if list._betteruiHeaderSortHitBeginningCallback and list.UnregisterCallback then
                list:UnregisterCallback("HitBeginningOfList", list._betteruiHeaderSortHitBeginningCallback)
            end
            list._betteruiHeaderSortHitBeginningCallback = function()
                if not integration.isActive then
                    owner:EnterHeaderSortMode()
                end
            end
            list:SetOnHitBeginningOfListCallback(list._betteruiHeaderSortHitBeginningCallback)
        end
    end

    return integration
end

--- Enters header sort navigation mode.
---@param integration BetterUIHeaderSortIntegration
---@return boolean
function HeaderSortIntegration.EnterHeaderMode(integration)
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.NAV, "enter header mode", {
            fn = "HeaderSortIntegration.EnterHeaderMode",
            active = integration.isActive,
            scene = DescribeOwnerScene(integration.owner),
            main = DescribeDescriptor(integration.keybinds and integration.keybinds.mainDescriptor, "main"),
            activeKeybind = DescribeDescriptor(integration.activeKeybindDescriptor, "active"),
            stripHasMain = HasKeybindGroup(integration.keybinds and integration.keybinds.mainDescriptor),
            list = DescribeListState(ResolveList(integration)),
        })
    end

    if integration.isActive then
        if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.SORT, "header sort enter skipped", { fn = "HeaderSortIntegration.EnterHeaderMode", reason = "alreadyActive", scene = DescribeOwnerScene(integration.owner) }) end
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
        if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.SORT, "header sort enter skipped", { fn = "HeaderSortIntegration.EnterHeaderMode", reason = "emptyList", scene = DescribeOwnerScene(owner), listItems = GetListItemCount(list) }) end
        if navigationSuspended and integration.navigation.reactivate then
            integration.navigation.reactivate(owner)
        end
        return false
    end

    local controller = ResolveController(integration)
    if not controller or not controller.EnterHeaderMode then
        if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SORT, "header sort enter failed", { fn = "HeaderSortIntegration.EnterHeaderMode", reason = "missingController", scene = DescribeOwnerScene(owner) }) end
        if navigationSuspended and integration.navigation.reactivate then
            integration.navigation.reactivate(owner)
        end
        return false
    end

    if controller:EnterHeaderMode() == false then
        if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.SORT, "header sort enter skipped", { fn = "HeaderSortIntegration.EnterHeaderMode", reason = "controllerRejected", scene = DescribeOwnerScene(owner) }) end
        if navigationSuspended and integration.navigation.reactivate then
            integration.navigation.reactivate(owner)
        end
        return false
    end

    integration.controller = controller
    integration.isActive = true
    owner.isInHeaderSortMode = true
    controller._headerSortIntegration = integration
    if integration.navigation.suspendList then
        SuspendActiveList(integration, list)
    else
        integration.suspendedList = nil
        integration.reactivateListAfterHeaderSort = false
        if BETTERUI.Log then
            BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.KEYBIND, "header sort list preserved", {
                fn = "HeaderSortIntegration.EnterHeaderMode",
                scene = DescribeOwnerScene(owner),
                list = DescribeListState(list),
            })
        end
    end

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
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "header sort suspend owner keybinds", {
            fn = "HeaderSortIntegration.EnterHeaderMode",
            scene = DescribeOwnerScene(owner),
            owned = DescribeDescriptors(ownedGroups, "owned"),
        })
    end

    local removeOwnedGroups = BETTERUI.Interface and BETTERUI.Interface.RemoveOwnedKeybindGroups
    if removeOwnedGroups then
        integration.suspendedKeybindGroups = removeOwnedGroups(ownedGroups)
    end
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "header sort owner keybinds suspended", {
            fn = "HeaderSortIntegration.EnterHeaderMode",
            scene = DescribeOwnerScene(owner),
            suspended = DescribeDescriptors(integration.suspendedKeybindGroups, "suspended"),
        })
    end

    integration.activeKeybindDescriptor = GetHeaderKeybindDescriptor(integration, controller)
    local activeKeybindRefresh = "none"
    if integration.activeKeybindDescriptor then
        local ensureGroup = BETTERUI.Interface and BETTERUI.Interface.EnsureKeybindGroupAdded
        local updateGroup = BETTERUI.Interface and BETTERUI.Interface.UpdateKeybindGroup
        local updateCurrent = BETTERUI.Interface and BETTERUI.Interface.UpdateCurrentKeybindGroups
        if type(ensureGroup) == "function" then
            ensureGroup(integration.activeKeybindDescriptor)
        end
        if type(updateGroup) == "function" then
            updateGroup(integration.activeKeybindDescriptor)
            activeKeybindRefresh = "descriptor"
        elseif type(updateCurrent) == "function" then
            updateCurrent()
            activeKeybindRefresh = "current"
        end
    end
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SORT, "header sort keybind active", {
            fn = "HeaderSortIntegration.EnterHeaderMode",
            scene = DescribeOwnerScene(owner),
            descriptor = DescribeDescriptor(integration.activeKeybindDescriptor, "header"),
            listItems = GetListItemCount(list),
            stripHasHeader = HasKeybindGroup(integration.activeKeybindDescriptor),
            stripHasMain = HasKeybindGroup(integration.keybinds and integration.keybinds.mainDescriptor),
            refresh = activeKeybindRefresh,
            list = DescribeListState(list),
        })
    end
    if not HasKeybindGroup(integration.activeKeybindDescriptor) and BETTERUI.Log and BETTERUI.Log.Warn then
        BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.KEYBIND, "header sort keybind activation failed", {
            fn = "HeaderSortIntegration.EnterHeaderMode",
            scene = DescribeOwnerScene(owner),
            descriptor = DescribeDescriptor(integration.activeKeybindDescriptor, "header"),
            refresh = activeKeybindRefresh,
            list = DescribeListState(list),
        })
    end

    if integration.callbacks.onEnterHeaderMode then
        BETTERUI.CIM.SafeExecute("HeaderSortIntegration:onEnterHeaderMode", integration.callbacks.onEnterHeaderMode, owner, controller, list)
    end

    return true
end

--- Exits header sort navigation mode and returns to the list.
---@param integration BetterUIHeaderSortIntegration
---@return boolean
function HeaderSortIntegration.ExitHeaderMode(integration)
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.NAV, "exit header mode", {
            fn = "HeaderSortIntegration.ExitHeaderMode",
            active = integration.isActive,
            scene = DescribeOwnerScene(integration.owner),
            activeKeybind = DescribeDescriptor(integration.activeKeybindDescriptor, "active"),
            suspended = DescribeDescriptors(integration.suspendedKeybindGroups, "suspended"),
            list = DescribeListState(integration.suspendedList or ResolveList(integration)),
        })
    end

    if not integration.isActive then
        if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.SORT, "header sort exit skipped", { fn = "HeaderSortIntegration.ExitHeaderMode", reason = "notActive", scene = DescribeOwnerScene(integration.owner) }) end
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

    if integration.activeKeybindDescriptor then
        BETTERUI.Interface.RemoveKeybindGroupIfPresent(integration.activeKeybindDescriptor)
        if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "header sort keybind removed", { fn = "HeaderSortIntegration.ExitHeaderMode", descriptor = DescribeDescriptor(integration.activeKeybindDescriptor, "header"), scene = DescribeOwnerScene(owner) }) end
        integration.activeKeybindDescriptor = nil
    end

    -- Restore exactly the owned groups suspended on enter; fall back to the
    -- legacy main-descriptor re-add when nothing was captured.
    local suspendedGroups = integration.suspendedKeybindGroups
    integration.suspendedKeybindGroups = nil
    local restoreGroups = BETTERUI.Interface and BETTERUI.Interface.RestoreKeybindGroups
    local mainDescriptor = integration.keybinds and integration.keybinds.mainDescriptor
    local mainRestoredDuringExit = false
    if suspendedGroups and mainDescriptor then
        for _, suspendedGroup in ipairs(suspendedGroups) do
            if suspendedGroup == mainDescriptor then
                mainRestoredDuringExit = true
                break
            end
        end
    end
    local restorePath = "none"
    if suspendedGroups and #suspendedGroups > 0 then
        restorePath = "suspended"
        if restoreGroups then
            restoreGroups(suspendedGroups)
        end
    elseif mainDescriptor then
        restorePath = "fallbackMain"
        mainRestoredDuringExit = true
        BETTERUI.Interface.EnsureKeybindGroupAdded(mainDescriptor)
    end
    local restoreRefresh = "none"
    if BETTERUI.Interface.UpdateCurrentKeybindGroups and BETTERUI.Interface.UpdateCurrentKeybindGroups() then
        restoreRefresh = "current"
    elseif mainDescriptor and BETTERUI.Interface.UpdateKeybindGroup then
        BETTERUI.Interface.UpdateKeybindGroup(mainDescriptor)
        restoreRefresh = "main"
    end
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SORT, "header sort keybinds restored", {
            fn = "HeaderSortIntegration.ExitHeaderMode",
            scene = DescribeOwnerScene(owner),
            restored = DescribeDescriptors(suspendedGroups, "restored"),
            restorePath = restorePath,
            main = DescribeDescriptor(mainDescriptor, "main"),
            stripHasMain = HasKeybindGroup(mainDescriptor),
            refresh = restoreRefresh,
        })
    end

    if integration.navigation.reactivate then
        integration.navigation.reactivate(owner)
    end

    RestoreActiveList(integration)

    if owner.EnsureHeaderKeybindsActive then
        owner:EnsureHeaderKeybindsActive()
    end

    local finalRefresh = "none"
    if mainDescriptor and (mainRestoredDuringExit or HasKeybindGroup(mainDescriptor)) then
        BETTERUI.Interface.EnsureKeybindGroupAdded(mainDescriptor)
        finalRefresh = "main"
    end
    if BETTERUI.Interface.UpdateCurrentKeybindGroups and BETTERUI.Interface.UpdateCurrentKeybindGroups() then
        finalRefresh = "current"
    end
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "header sort owner keybinds finalized", {
            fn = "HeaderSortIntegration.ExitHeaderMode",
            scene = DescribeOwnerScene(owner),
            main = DescribeDescriptor(mainDescriptor, "main"),
            stripHasMain = HasKeybindGroup(mainDescriptor),
            refresh = finalRefresh,
        })
    end

    if integration.callbacks.onExitHeaderMode then
        BETTERUI.CIM.SafeExecute("HeaderSortIntegration:onExitHeaderMode", integration.callbacks.onExitHeaderMode, owner, controller)
    end

    return true
end

---@param integration BetterUIHeaderSortIntegration|nil
---@return table?
function HeaderSortIntegration.EnsureController(integration)
    if not integration then
        return nil
    end
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SORT, "header sort ensure controller", { fn = "HeaderSortIntegration.EnsureController", scene = DescribeOwnerScene(integration.owner) })
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
