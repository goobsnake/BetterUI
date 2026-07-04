--[[
File: Modules/Vendor/Core/VendorBootstrapRuntime.lua
Purpose: Own vendor setup/bootstrap composition so Vendor.lua only coordinates collaborators.
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}
local Vendor = BETTERUI.Vendor
Vendor.BootstrapRuntime = Vendor.BootstrapRuntime or {}
local BootstrapRuntime = Vendor.BootstrapRuntime

local TraceVendorBootstrap = (BETTERUI.Log and BETTERUI.Log.MakeTracer)
    and BETTERUI.Log.MakeTracer{
        module = "Vendor",
        feature = "vendor-bootstrap",
        category = (BETTERUI.Log and BETTERUI.Log.CATEGORY or {}).LIFECYCLE or "LIFECYCLE",
    }
    or function() end

local function DescribeKeybinds(descriptor, label)
    local L = BETTERUI and BETTERUI.Log
    if L and L.DescribeKeybindDescriptors and descriptor then
        return L.DescribeKeybindDescriptors(descriptor, label or "vendor-keybinds")
    end
    return nil
end

local function ShouldPreserveSearchFocus(instance)
    if not instance then
        return false
    end
    if instance._preserveSearchFocusDuringRefresh == true then
        return true
    end
    if instance.list and instance.list.IsActive then
        local ok, active = pcall(function() return instance.list:IsActive() end)
        if ok and active == true then
            return false
        end
    end
    if instance.textSearchHeaderFocus and instance.textSearchHeaderFocus.IsActive then
        local ok, active = pcall(function() return instance.textSearchHeaderFocus:IsActive() end)
        if ok and active == true then
            return true
        end
    end
    if instance.IsHeaderFocused then
        local ok, active = pcall(function() return instance:IsHeaderFocused() end)
        if ok and active == true then
            return true
        end
    end
    return false
end

---@param instance BETTERUI.Vendor.Class
---@param deps table
---@return nil
function BootstrapRuntime.InitializeList(instance, deps)
    instance:SetupList(
        "BETTERUI_GamepadItemSubEntryTemplate",
        deps.rowSetup,
        "BUI_ItemRow"
    )
    instance:AddTemplate(
        "BETTERUI_GamepadStableTrainingEntryTemplate",
        deps.rowSetup,
        "BUI_StableRow"
    )
    instance.list:SetOnSelectedDataChangedCallback(function(list, selectedData)
        if instance._searchModeActive and instance.list
            and instance.list.IsActive and instance.list:IsActive() then
            instance:OnItemSelectedChange(list, selectedData)
            instance:UpdateScrollIndicator(list)
            if not ShouldPreserveSearchFocus(instance) then
                instance:OnSearchFocusLost()
            end
            return
        end
        instance:OnItemSelectedChange(list, selectedData)
        instance:UpdateScrollIndicator(list)
    end)
    if instance.list then
        instance.list.owner = instance
        -- Use the shared CIM.Lists.WrapMovePreviousToHeader helper extracted from the
        -- identical pattern that was duplicated in Banking, Companions, and Vendor.
        if BETTERUI.CIM.Lists and BETTERUI.CIM.Lists.WrapMovePreviousToHeader then
            BETTERUI.CIM.Lists.WrapMovePreviousToHeader(instance.list, function()
                if instance.OnHeaderEntered then
                    instance:OnHeaderEntered()
                elseif instance.RequestHeaderFocus then
                    instance:RequestHeaderFocus()
                end
            end)
        end
    end

    deps.addColumns(instance)
    instance:InitializeCategoryHeader()
    instance:InitializeScrollIndicator()
    instance.searchQuery = ""
end

---@param instance BETTERUI.Vendor.Class
---@return nil
function BootstrapRuntime.InitializeSearch(instance)
    local searchCallbackRevision = 0
    local searchHandlerRevision = 0

    local function HandleVendorSearchChanged(searchText)
        if instance.OnSearchTextChanged then
            instance:OnSearchTextChanged(searchText)
        else
            instance.searchQuery = searchText ~= nil and tostring(searchText) or ""
            instance:RefreshList()
        end
        searchCallbackRevision = searchCallbackRevision + 1
    end

    instance.textSearchKeybindStripDescriptor = BETTERUI.Interface.CreateSearchKeybindDescriptor(instance)
    if instance.AddSearch then
        instance:AddSearch(instance.textSearchKeybindStripDescriptor, HandleVendorSearchChanged)
        if instance.PositionSearchControl then
            instance:PositionSearchControl()
        end
    end
    if BETTERUI.Interface.SearchMixin and BETTERUI.Interface.SearchMixin.SetupEditBoxHandlers then
        BETTERUI.Interface.SearchMixin.SetupEditBoxHandlers(instance, {
            isSceneShowing = function()
                return instance.IsSceneShowing and instance:IsSceneShowing() or false
            end,
            onTextChanged = function(window, txt)
                if searchHandlerRevision == searchCallbackRevision then
                    if window.OnSearchTextChanged then
                        window:OnSearchTextChanged(txt or "")
                    else
                        window.searchQuery = txt or ""
                        if window.RefreshList then
                            window:RefreshList()
                        end
                    end
                end
                searchHandlerRevision = searchCallbackRevision
                BETTERUI.Interface.UpdateCurrentKeybindGroups()
            end,
            enterHeaderFn = function(window)
                if window.RequestHeaderFocus then
                    window:RequestHeaderFocus()
                else
                    window:EnterSearchMode()
                end
            end,
        })
    end
end

---@param instance BETTERUI.Vendor.Class
---@param deps table
---@return nil
function BootstrapRuntime.InitializeInteractiveSurfaces(instance, deps)
    instance.coreKeybinds = deps.buildCoreKeybinds(instance)

    if BETTERUI.CIM and BETTERUI.CIM.MultiSelectManager and BETTERUI.CIM.MultiSelectManager.Create then
        Vendor.multiSelectManager = BETTERUI.CIM.MultiSelectManager.Create(instance.list, function()
            BETTERUI.Interface.UpdateCurrentKeybindGroups()
        end)
    else
        Vendor.multiSelectManager = nil
    end
    instance.multiSelectManager = Vendor.multiSelectManager

    if BETTERUI.CIM.UI and BETTERUI.CIM.UI.HeaderSortIntegration and BETTERUI.CIM.UI.HeaderSortIntegration.Install then
        deps.runVendorSetupStep("Header sort integration setup", function()
            local integration = BETTERUI.CIM.UI.HeaderSortIntegration.Install(instance, {
                list = instance.list,
                columns = {
                    { name = GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_NAME") or "SI_BETTERUI_BANKING_COLUMN_NAME"), key = "name" },
                    { name = GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_TYPE") or "SI_BETTERUI_BANKING_COLUMN_TYPE"), key = "type" },
                    { name = GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_TRAIT") or "SI_BETTERUI_BANKING_COLUMN_TRAIT"), key = "trait" },
                    { name = GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_STAT") or "SI_BETTERUI_BANKING_COLUMN_STAT"), key = "stat" },
                    { name = GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_VALUE") or "SI_BETTERUI_BANKING_COLUMN_VALUE"), key = "value", defaultDirection = "descending" },
                },
                callbacks = {
                    onSortChanged = function()
                        instance:RefreshList()
                    end,
                },
                controllerContract = {
                    field = "sortController",
                    aliasFields = { "headerSortController" },
                },
                keybinds = {
                    mainDescriptor = instance.coreKeybinds,
                },
                autoEnterOnListStart = true,
            })
            BETTERUI.CIM.UI.HeaderSortIntegration.EnsureController(integration)
        end)
    end
end

---@param instance BETTERUI.Vendor.Class
---@return nil
function BootstrapRuntime.CreateScene(instance)
    instance.fragment = ZO_SimpleSceneFragment:New(instance.control)
    instance.fragment:SetHideOnSceneHidden(true)

    local vendorFooterDummy = BETTERUI.WindowManager:CreateControl(
        "BETTERUI_VendorFooterDummy", GuiRoot, CT_CONTROL)
    vendorFooterDummy:SetHidden(true)
    instance.footerFragment = ZO_SimpleSceneFragment:New(vendorFooterDummy)
    instance.footerFragment:SetHideOnSceneHidden(true)

    local scene = ZO_InteractScene:New(BETTERUI_VENDOR_SCENE_NAME, SCENE_MANAGER, Vendor.VENDOR_INTERACTION)
    instance.scene = scene
    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD)
    scene:AddFragment(instance.fragment)
    scene:AddFragment(FRAME_EMOTE_FRAGMENT_INVENTORY)
    scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    scene:AddFragment(instance.footerFragment)
end

---@param instance BETTERUI.Vendor.Class
---@param deps table
---@return nil
function BootstrapRuntime.RegisterSceneLifecycle(instance, deps)
    TraceVendorBootstrap("vendor.bootstrap", "scene_lifecycle_register", {
        hasInstance = instance ~= nil,
        keybinds = DescribeKeybinds(instance and instance.coreKeybinds, "vendor-core"),
    })
    BETTERUI.CIM.SceneLifecycle.Register(instance, {
        keybinds = { instance.coreKeybinds },
        taskManager = deps.taskManager,
        onShowing = function(screen, wasPushed)
            TraceVendorBootstrap("vendor.scene", "showing_begin", {
                wasPushed = wasPushed,
                currentMode = screen.GetCurrentMode and screen:GetCurrentMode() or nil,
                keybinds = DescribeKeybinds(screen and screen.coreKeybinds, "vendor-core"),
            })
            screen._vendorCloseCleanupApplied = false
            BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.WIDTH)
            if screen.ReleaseNativeStoreInputOwnership then
                screen:ReleaseNativeStoreInputOwnership()
            end
            if screen.ForceReleaseDirectionalInput then
                screen:ForceReleaseDirectionalInput()
            end
            screen:ApplyNativeStoreMode(screen:GetCurrentMode())
            screen:RefreshVendorFooter()
            screen:InitializeScrollIndicator()
            screen:RefreshList()
            screen:EnsureHeaderKeybindsActive()
            screen:EnsureColumnHeadersVisible()
            if ITEM_PREVIEW_GAMEPAD and ITEM_PREVIEW_GAMEPAD.RegisterCallback then
                if not screen.onItemPreviewRefreshActionsCallback then
                    screen.onItemPreviewRefreshActionsCallback = function()
                        if screen.RefreshVendorActionKeybinds then
                            screen:RefreshVendorActionKeybinds()
                        else
                            BETTERUI.Interface.UpdateCurrentKeybindGroups()
                        end
                    end
                end
                ITEM_PREVIEW_GAMEPAD:RegisterCallback("RefreshActions", screen.onItemPreviewRefreshActionsCallback)
            end
            if screen.list then
                screen:OnItemSelectedChange(screen.list, screen.list:GetTargetData())
                screen:UpdateScrollIndicator(screen.list)
            end
            TraceVendorBootstrap("vendor.keybind_layer", "add_before", {
                currentMode = screen.GetCurrentMode and screen:GetCurrentMode() or nil,
                keybinds = DescribeKeybinds(screen and screen.coreKeybinds, "vendor-core"),
            })
            local refreshed = BETTERUI.Interface.UpdateCurrentKeybindGroups()
            TraceVendorBootstrap("vendor.keybind_layer", "add_after", {
                currentMode = screen.GetCurrentMode and screen:GetCurrentMode() or nil,
                keybinds = DescribeKeybinds(screen and screen.coreKeybinds, "vendor-core"),
                refreshed = refreshed == true,
            })
            TraceVendorBootstrap("vendor.bootstrap", "showing_complete", {
                currentMode = screen.GetCurrentMode and screen:GetCurrentMode() or nil,
                hasList = screen.list ~= nil,
            })
            TraceVendorBootstrap("vendor.scene", "showing_end", {
                currentMode = screen.GetCurrentMode and screen:GetCurrentMode() or nil,
                hasList = screen.list ~= nil,
            })
        end,
        onHiding = function(screen)
            TraceVendorBootstrap("vendor.scene", "hiding_begin", {
                currentMode = screen.GetCurrentMode and screen:GetCurrentMode() or nil,
            })
            BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.ZO_WIDTH)
            if ITEM_PREVIEW_GAMEPAD and ITEM_PREVIEW_GAMEPAD.UnregisterCallback and screen.onItemPreviewRefreshActionsCallback then
                ITEM_PREVIEW_GAMEPAD:UnregisterCallback("RefreshActions", screen.onItemPreviewRefreshActionsCallback)
            end
            local currentMode = screen:GetCurrentMode()
            if currentMode and screen.list then
                screen:SaveListPosition()
            end
            if Vendor.multiSelectManager then
                Vendor.multiSelectManager:ExitSelectionMode()
            end
            screen._suppressListUpdates = false
            screen._isDirty = false
            if Vendor.RunLifecycleCloseCleanup then
                Vendor.RunLifecycleCloseCleanup(screen)
            else
                if screen.DisableStablePreviewMode then
                    screen:DisableStablePreviewMode()
                end
                if screen.ReleaseNativeStoreInputOwnership then
                    screen:ReleaseNativeStoreInputOwnership()
                end
                if screen.ForceReleaseDirectionalInput then
                    screen:ForceReleaseDirectionalInput()
                end
            end
            TraceVendorBootstrap("vendor.keybind_layer", "remove_before", {
                currentMode = screen.GetCurrentMode and screen:GetCurrentMode() or nil,
                keybinds = DescribeKeybinds(screen and screen.coreKeybinds, "vendor-core"),
            })
            screen:DeactivateHeaderKeybinds()
            screen:DeactivateListInput()
            TraceVendorBootstrap("vendor.keybind_layer", "remove_after", {
                currentMode = screen.GetCurrentMode and screen:GetCurrentMode() or nil,
            })
            if BETTERUI.CIM and BETTERUI.CIM.SceneCleanup then
                BETTERUI.CIM.SceneCleanup.CleanupInputState(screen)
                BETTERUI.CIM.SceneCleanup.DeactivateLists(screen, screen.list)
                BETTERUI.CIM.SceneCleanup.ClearSearchState(screen)
            end
            if GAMEPAD_TOOLTIPS then
                GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
                GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
            end
            if BETTERUI.CIM.SharedItemSupport and BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip then
                BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip(GAMEPAD_LEFT_TOOLTIP)
                BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip(GAMEPAD_RIGHT_TOOLTIP)
            end
            if screen.list and screen.list.control and BETTERUI.CIM and BETTERUI.CIM.ScrollIndicator then
                BETTERUI.CIM.ScrollIndicator.Hide(screen.list.control)
            end
            TraceVendorBootstrap("vendor.scene", "hiding_end", {
                currentMode = screen.GetCurrentMode and screen:GetCurrentMode() or nil,
            })
        end,
        onHidden = function(screen)
            TraceVendorBootstrap("vendor.scene", "hidden_begin", {
                currentMode = screen.GetCurrentMode and screen:GetCurrentMode() or nil,
            })
            if Vendor.RunLifecycleCloseCleanup then
                Vendor.RunLifecycleCloseCleanup(screen)
            else
                if screen.DisableStablePreviewMode then
                    screen:DisableStablePreviewMode()
                end
                if screen.ReleaseNativeStoreInputOwnership then
                    screen:ReleaseNativeStoreInputOwnership()
                end
                if screen.ForceReleaseDirectionalInput then
                    screen:ForceReleaseDirectionalInput()
                end
            end
            if BETTERUI.CIM and BETTERUI.CIM.SceneCleanup then
                BETTERUI.CIM.SceneCleanup.CleanupInputState(screen)
                BETTERUI.CIM.SceneCleanup.DeactivateLists(screen, screen.list)
                BETTERUI.CIM.SceneCleanup.ClearSearchState(screen)
            end
            local component = screen:GetActiveComponent()
            if component and component.Deactivate then
                component:Deactivate(screen)
            end
            TraceVendorBootstrap("vendor.scene", "hidden_end", {
                currentMode = screen.GetCurrentMode and screen:GetCurrentMode() or nil,
                hadComponent = component ~= nil,
            })
        end,
    })
end
