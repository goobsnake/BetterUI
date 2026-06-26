--[[
File: Modules/Vendor/Core/VendorBootstrapRuntime.lua
Purpose: Own vendor setup/bootstrap composition so Vendor.lua only coordinates collaborators.
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}
local Vendor = BETTERUI.Vendor
Vendor.BootstrapRuntime = Vendor.BootstrapRuntime or {}
local BootstrapRuntime = Vendor.BootstrapRuntime

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
            instance:OnSearchFocusLost()
            return
        end
        instance:OnItemSelectedChange(list, selectedData)
        instance:UpdateScrollIndicator(list)
    end)
    if instance.list then
        instance.list.owner = instance
        -- Direct assignment is intentional: ZO_PostHook does not expose the original
        -- return value, which we need to detect a failed move (list at top).
        -- The _betteruiMovePreviousWrapperInstalled guard prevents double-wrapping.
        if instance.list.MovePrevious and not instance.list._betteruiMovePreviousWrapperInstalled then
            local originalMovePrevious = instance.list.MovePrevious
            instance.list._betteruiMovePreviousWrapperInstalled = true
            instance.list.MovePrevious = function(list, allowWrapping, suppressFailSound)
                local didMove = originalMovePrevious(list, allowWrapping, suppressFailSound)
                if didMove then
                    return true
                end

                if instance.OnHeaderEntered then
                    instance:OnHeaderEntered()
                elseif instance.RequestHeaderFocus then
                    instance:RequestHeaderFocus()
                end
                return true
            end
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
    BETTERUI.CIM.SceneLifecycle.Register(instance, {
        keybinds = { instance.coreKeybinds },
        taskManager = deps.taskManager,
        onShowing = function(screen, wasPushed)
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
            BETTERUI.Interface.UpdateCurrentKeybindGroups()
        end,
        onHiding = function(screen)
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
            screen:DeactivateHeaderKeybinds()
            screen:DeactivateListInput()
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
        end,
        onHidden = function(screen)
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
        end,
    })
end
