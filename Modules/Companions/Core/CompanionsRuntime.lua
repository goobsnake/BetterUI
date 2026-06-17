--[[
File: Modules/Companions/Core/CompanionsRuntime.lua
Purpose: Runtime scene, event, and keybind orchestration for the Companions module.
         Keeps Module.lua focused on lifecycle wiring while this file owns the
         live runtime helpers used by companion equipment flow.
]]

local Companions = BETTERUI.Companions
local EVENT_NS = "BetterUI_Companions"

---@return table helpers
local function EnsureCompanionBoundaryHelpers()
    Companions.BoundaryHelpers = Companions.BoundaryHelpers or {}
    local helpers = Companions.BoundaryHelpers

    if type(helpers.WrapError) ~= "function" then
        helpers.WrapError = function(operation, err)
            if Companions and type(Companions.WrapRuntimeError) == "function" then
                return Companions.WrapRuntimeError(operation, err)
            end
            return string.format("[Companions] %s failed: %s", operation, tostring(err))
        end
    end

    if type(helpers.ExecuteBoundary) ~= "function" then
        helpers.ExecuteBoundary = function(context, fn, ...)
            if BETTERUI.CIM and type(BETTERUI.CIM.SafeExecute) == "function" then
                return BETTERUI.CIM.SafeExecute(context, fn, ...)
            end
            if type(fn) ~= "function" then
                return false, "No function provided"
            end
            return pcall(fn, ...)
        end
    end

    return helpers
end

Companions.EnsureBoundaryHelpers = Companions.EnsureBoundaryHelpers or EnsureCompanionBoundaryHelpers
local companionsBoundaryHelpers = Companions.EnsureBoundaryHelpers()
Companions.GetBoundary = Companions.GetBoundary or function()
    return companionsBoundaryHelpers
end
Companions.WrapBoundaryError = Companions.WrapBoundaryError or companionsBoundaryHelpers.WrapError
Companions.ExecuteBoundary = Companions.ExecuteBoundary or companionsBoundaryHelpers.ExecuteBoundary

local function RefreshVisibleCompanionScene(screen, options)
    if not screen or not screen.IsSceneShowing or not screen:IsSceneShowing() then
        return false
    end

    screen:RefreshCategories()
    screen:RefreshList()
    screen:RefreshCompanionFooter()

    if options and options.refreshTitle then
        screen:RefreshCategoryTitle()
    end
    if options and options.ensureColumns then
        screen:EnsureColumnHeadersVisible()
    end
    if options and options.ensureHeaderKeybinds then
        screen:EnsureHeaderKeybindsActive()
    end

    screen:EnsureListInputActive()

    if options and options.positionSearch and screen.PositionSearchControl then
        screen:PositionSearchControl()
    end

    screen:UpdateItemTooltips(screen.list and screen.list:GetTargetData())
    return true
end

local function CallCompanionSearchLifecycle(instance, action)
    local searchMixin = BETTERUI.Interface and BETTERUI.Interface.SearchMixin
    if searchMixin and searchMixin.CallSearchLifecycle then
        return searchMixin.CallSearchLifecycle(instance, action)
    end

    local lifecycle = instance and instance.SEARCH_LIFECYCLE
    local methodName = lifecycle and lifecycle[action]
    local method = methodName and instance and instance[methodName]
    if type(method) == "function" then
        return method(instance)
    end
    return nil
end

local function PatchCompanionListMovePrevious(instance)
    if not (instance and instance.list and instance.list.MovePrevious) then
        return
    end

    local originalMovePrevious = instance.list.MovePrevious
    instance.list.MovePrevious = function(list, allowWrapping, suppressFailSound)
        local didMove = originalMovePrevious(list, allowWrapping, suppressFailSound)
        if didMove then
            return true
        end
        CallCompanionSearchLifecycle(instance, "requestEnter")
        return true
    end
end

local function ConfigureCompanionListLayout(instance)
    local listControl = instance.list and instance.list.control
    local headerGeneric = instance.headerGeneric
    if not (listControl and headerGeneric) then
        return
    end

    local container = instance.control and instance.control:GetNamedChild("Container")
    local footer = container and container:GetNamedChild("Footer")
    local footerFooter = footer and footer:GetNamedChild("Footer")
    listControl:ClearAnchors()
    listControl:SetAnchor(TOPLEFT, headerGeneric, BOTTOMLEFT, 20, 15)
    if footerFooter then
        listControl:SetAnchor(BOTTOMRIGHT, footerFooter, TOPRIGHT, 0, -8)
    end
end

local function InitializeCompanionMultiSelect(instance)
    if BETTERUI.CIM and BETTERUI.CIM.MultiSelectManager and BETTERUI.CIM.MultiSelectManager.Create then
        Companions.multiSelectManager = BETTERUI.CIM.MultiSelectManager.Create(instance.list, function()
            if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
                KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
            end
        end)
    else
        Companions.multiSelectManager = nil
    end
end

local function InitializeCompanionSearch(instance)
    if not (BETTERUI.Interface.SearchMixin and instance.AddSearch) then
        return
    end

    instance:AddSearch(
        BETTERUI.Interface.CreateSearchKeybindDescriptor(instance),
        function(queryOrControl)
            local query = type(queryOrControl) == "string" and queryOrControl
                or (queryOrControl and queryOrControl.GetText and queryOrControl:GetText())
                or ""
            instance.searchQuery = query
            instance:RefreshList()
        end
    )

    if BETTERUI.Interface.SearchMixin.SetupEditBoxHandlers then
        BETTERUI.Interface.SearchMixin.SetupEditBoxHandlers(instance, {
            isSceneShowing = function()
                return instance and instance:IsSceneShowing()
            end,
            enterHeaderFn = function(window)
                CallCompanionSearchLifecycle(window, "requestEnter")
            end,
        })
    end
end

local function InitializeCompanionList(instance)
    instance:SetupList(
        "BETTERUI_GamepadItemSubEntryTemplate",
        BETTERUI_SharedGamepadEntry_OnSetup,
        "BUI_ItemRow"
    )
    instance:InitializeListPresentation()
    PatchCompanionListMovePrevious(instance)
    instance:InitializeCategoryHeader()

    local headerColumns = BETTERUI.CIM.CONST.HEADER_LAYOUT.COLUMNS
    instance:AddColumn(GetString(SI_BETTERUI_INV_HEADER_NAME), headerColumns.NAME)
    instance:AddColumn(GetString(SI_BETTERUI_INV_HEADER_TYPE), headerColumns.TYPE)
    instance:AddColumn(GetString(SI_BETTERUI_INV_HEADER_TRAIT), headerColumns.TRAIT)
    instance:AddColumn(GetString(SI_BETTERUI_INV_HEADER_STAT), headerColumns.STAT)
    instance:AddColumn(GetString(SI_BETTERUI_INV_HEADER_VALUE), headerColumns.VALUE)
    instance:RefreshCategories()
    instance:EnsureColumnHeadersVisible()
    ConfigureCompanionListLayout(instance)
end

local function RegisterCompanionNarration()
    if BETTERUI.CIM.Narration and BETTERUI.CIM.Narration.RegisterListNarration then
        BETTERUI.CIM.Narration.RegisterListNarration(
            BETTERUI_COMPANION_EQUIP_SCENE_NAME,
            function() return Companions.instance and Companions.instance.list and Companions.instance.list:GetTargetData() end,
            function() return Companions.instance and Companions.instance:GetTitle() end
        )
    end
end

function Companions.InitializeRuntime()
    Companions.RegisterDialogs()

    local instance = Companions.Class:New(
        "BETTERUI_CompanionWindow", BETTERUI_COMPANION_EQUIP_SCENE_NAME)
    Companions.instance = instance
    instance:SetTitle(
        "|c0066FF" .. GetString(rawget(_G, "SI_BETTERUI_COMPANIONS_TITLE") or "SI_BETTERUI_COMPANIONS_TITLE") .. "|r")

    InitializeCompanionList(instance)
    InitializeCompanionMultiSelect(instance)
    instance.multiSelectManager = Companions.multiSelectManager
    InitializeCompanionSearch(instance)

    instance.coreKeybinds = Companions.BuildCoreKeybinds(instance)
    local sortOk, sortErr = Companions.SetupSort(instance)
    if not sortOk and sortErr then
        if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.LIFECYCLE, sortErr) end
    end
    -- Sort-setup failure degrades sorting only; module initialization continues.
    instance.sortSetupReady = sortOk == true
    instance.sortSetupDegraded = not sortOk
    instance.sortSetupError = not sortOk and sortErr or nil
    Companions.CreateScene(instance)
    Companions.RegisterSceneLifecycle(instance)
    instance:InitCompanionFooter()
    RegisterCompanionNarration()
    Companions.RegisterEvents(EVENT_MANAGER)

    return instance
end

function Companions.SetupSort(instance)
    local headerSortIntegration = BETTERUI.CIM.UI and BETTERUI.CIM.UI.HeaderSortIntegration
    if not (headerSortIntegration and headerSortIntegration.Install) then
        return false, "[Companions] Header sort integration unavailable"
    end

    local ok, err = pcall(function()
        local integration = headerSortIntegration.Install(instance, {
            list = instance.list,
            columns = {
                { name = GetString(SI_BETTERUI_INV_HEADER_NAME), key = "name" },
                { name = GetString(SI_BETTERUI_INV_HEADER_TYPE), key = "type" },
                { name = GetString(SI_BETTERUI_INV_HEADER_TRAIT), key = "trait" },
                { name = GetString(SI_BETTERUI_INV_HEADER_STAT), key = "stat" },
                { name = GetString(SI_BETTERUI_INV_HEADER_VALUE), key = "value", defaultDirection = "descending" },
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
        headerSortIntegration.EnsureController(integration)
    end)
    if not ok then
        return false, string.format("[Companions] Header sort setup failed: %s", tostring(err))
    end

    return true
end

function Companions.CreateScene(instance)
    instance.fragment = ZO_SimpleSceneFragment:New(instance.control)
    instance.fragment:SetHideOnSceneHidden(true)

    local companionFooterDummy = BETTERUI.WindowManager:CreateControl(
        "BETTERUI_CompanionFooterDummy", GuiRoot, CT_CONTROL)
    companionFooterDummy:SetHidden(true)
    instance.footerFragment = ZO_SimpleSceneFragment:New(companionFooterDummy)
    instance.footerFragment:SetHideOnSceneHidden(true)

    local scene = ZO_InteractScene:New(BETTERUI_COMPANION_EQUIP_SCENE_NAME, SCENE_MANAGER, Companions.COMPANION_INTERACTION)
    instance.scene = scene

    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD)
    scene:AddFragment(instance.fragment)
    scene:AddFragment(FRAME_EMOTE_FRAGMENT_INVENTORY)
    scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    scene:AddFragment(instance.footerFragment)

    scene:RegisterCallback("StateChange", function(_, newState)
        if not Companions.instance then
            return
        end
        if newState == SCENE_SHOWN then
            Companions.instance:EnsureColumnHeadersVisible()
            Companions.instance:EnsureListInputActive()
            Companions.instance:UpdateItemTooltips(Companions.instance.list and Companions.instance.list:GetTargetData())
        end
    end)

    SCENE_MANAGER.scenes["companionEquipmentGamepad"] = scene
    COMPANION_EQUIPMENT_GAMEPAD_SCENE = scene
    -- COMPANION_EQUIPMENT_GAMEPAD is replaced with the BetterUI screen object.
    -- ZOS code or other addons may still call ZO_CompanionEquipment_Gamepad
    -- methods the replacement does not shim; resolve those to a logged no-op
    -- instead of crashing on a nil method call.
    do
        local classMeta = getmetatable(instance)
        local classIndex = classMeta and classMeta.__index
        -- Cache resolved no-op shims per method name so repeated lookups do not
        -- allocate a new closure (or spam the log) on every missing-method access.
        local noOpShims = {}
        setmetatable(instance, {
            __index = function(target, key)
                local value
                if type(classIndex) == "function" then
                    value = classIndex(target, key)
                elseif type(classIndex) == "table" then
                    value = classIndex[key]
                end
                if value ~= nil then
                    return value
                end
                local shim = noOpShims[key]
                if shim ~= nil then
                    return shim
                end
                local zosClass = rawget(_G, "ZO_CompanionEquipment_Gamepad")
                if type(zosClass) == "table" and type(zosClass[key]) == "function" then
                    shim = function(...)
                        if BETTERUI.Log then
                            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.GENERAL, string.format(
                                "Companions: absorbing ZO_CompanionEquipment_Gamepad.%s(...)",
                                tostring(key)))
                        end
                    end
                    noOpShims[key] = shim
                    return shim
                end
                return nil
            end,
        })
    end
    COMPANION_EQUIPMENT_GAMEPAD = instance
    return scene
end

function Companions.RegisterSceneLifecycle(instance)
    BETTERUI.CIM.SceneLifecycle.Register(instance, {
        keybinds = { instance.coreKeybinds },
        taskManager = Companions.Tasks,
        onShowing = function(screen)
            if BETTERUI.Log and BETTERUI.Log.IsActive() then
                local listCount = (screen.list and screen.list.GetNumItems) and screen.list:GetNumItems() or 0
                BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SCENE, "companionShow", {
                    sortSetupDegraded = screen.sortSetupDegraded == true,
                    listCount = listCount
                })
            end
            BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.WIDTH)
            RefreshVisibleCompanionScene(screen, {
                refreshTitle = true,
                ensureColumns = true,
                ensureHeaderKeybinds = true,
                positionSearch = true,
            })
        end,
        onHiding = function(screen)
            BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.ZO_WIDTH)
            screen:DeactivateListInput()
            screen:DeactivateHeaderKeybinds()
            if screen.ForceReleaseDirectionalInput then
                screen:ForceReleaseDirectionalInput()
            end
            if Companions.multiSelectManager then
                Companions.multiSelectManager:ExitSelectionMode()
            end
            CallCompanionSearchLifecycle(Companions.instance, "exit")
            local category = screen:GetCurrentCategory()
            if category and screen.list then
                BETTERUI.CIM.PositionManager.SavePosition("Companions", category.key, screen.list)
            end
            if GAMEPAD_TOOLTIPS then
                GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
                GAMEPAD_TOOLTIPS:Reset(GAMEPAD_RIGHT_TOOLTIP)
            end
            if screen.TryClearNewStatusOnHidden then
                screen:TryClearNewStatusOnHidden()
            end
        end,
        onHidden = function(screen)
            screen:DeactivateListInput()
            screen:DeactivateHeaderKeybinds()
            if screen.ForceReleaseDirectionalInput then
                screen:ForceReleaseDirectionalInput()
            end
        end,
    })
end

local function OnCompanionActivated()
    RefreshVisibleCompanionScene(Companions.instance)
end

local function OnCompanionDeactivated()
    if not Companions.instance then
        return
    end
    if Companions.instance:IsSceneShowing() then
        SCENE_MANAGER:HideCurrentScene()
    end
end

local function OnInventoryUpdated()
    if not Companions.instance or not Companions.instance:IsSceneShowing() then
        return
    end

    Companions.Tasks:Cancel("listRefresh")
    Companions.Tasks:Schedule("listRefresh", 100, function()
        RefreshVisibleCompanionScene(Companions.instance)
    end)
end

function Companions.RegisterEvents(eventManager)
    if not eventManager then
        return
    end

    if EVENT_COMPANION_ACTIVATED then
        eventManager:RegisterForEvent(EVENT_NS .. "_CompActivated",
            EVENT_COMPANION_ACTIVATED, OnCompanionActivated)
    end
    if EVENT_COMPANION_DEACTIVATED then
        eventManager:RegisterForEvent(EVENT_NS .. "_CompDeactivated",
            EVENT_COMPANION_DEACTIVATED, OnCompanionDeactivated)
    end
    eventManager:RegisterForEvent(EVENT_NS .. "_InvUpdate",
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventoryUpdated)
    eventManager:RegisterForEvent(EVENT_NS .. "_InvFull",
        EVENT_INVENTORY_FULL_UPDATE, OnInventoryUpdated)
end

--- Compatibility entrypoint used by ESO's shared slot action pipeline.
--- @param inventorySlot table
function BETTERUI.Companions.Class:TryEquipItem(inventorySlot)
    if not inventorySlot or not ZO_Inventory_GetBagAndIndex then
        return
    end
    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    Companions.TryEquipCompanionItem(bagId, slotIndex)
end

local function IsMultiSelectAvailable()
    return Companions.instance and Companions.instance.list and Companions.instance.list:GetNumItems() > 0
end

local function GetMultiSelectKeybindName()
    -- Shared CIM label builder; inline fallback only for test harnesses that
    -- load this file without the CIM keybind module.
    local keybinds = BETTERUI.CIM and BETTERUI.CIM.Keybinds
    if keybinds and keybinds.GetMultiSelectLabel then
        return keybinds.GetMultiSelectLabel()
    end
    return GetString(rawget(_G, "SI_BETTERUI_MULTI_SELECT") or "SI_BETTERUI_MULTI_SELECT")
end

---@param instance BETTERUI.Companions.Class
---@return table keybindGroup
function Companions.BuildCoreKeybinds(instance)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = function()
                local ms = Companions.multiSelectManager
                if ms and ms:IsActive() then
                    return GetString(SI_GAMEPAD_SELECT_OPTION)
                end
                local selectedData = instance.list and instance.list:GetSelectedData()
                if selectedData then
                    local ds = selectedData.dataSource or selectedData
                    if ds.isEquipped then
                        return GetString(SI_ITEM_ACTION_UNEQUIP)
                    end
                end
                return GetString(SI_ITEM_ACTION_EQUIP)
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
                local ms = Companions.multiSelectManager
                if ms and ms:IsActive() then
                    local selectedData = instance.list and instance.list:GetSelectedData()
                    if selectedData then
                        ms:ToggleSelection(selectedData)
                        instance:RefreshList()
                        instance:EnsureListInputActive()
                    end
                    return
                end
                local selectedData = instance.list and instance.list:GetSelectedData()
                if not selectedData then
                    return
                end
                local ds = selectedData.dataSource or selectedData
                local bagId = ds.bagId
                local slotIndex = ds.slotIndex
                if bagId == nil or slotIndex == nil then
                    return
                end
                if ds.isEquipped then
                    Companions.TryUnequipCompanionItem(slotIndex)
                else
                    Companions.TryEquipCompanionItem(bagId, slotIndex)
                end
                Companions.Tasks:Schedule("keybindRefresh", 100, function()
                    if Companions.instance and Companions.instance:IsSceneShowing() and Companions.instance.coreKeybinds then
                        KEYBIND_STRIP:UpdateKeybindButtonGroup(Companions.instance.coreKeybinds)
                    end
                end)
            end,
            enabled = function()
                local selectedData = instance.list and instance.list:GetSelectedData()
                return selectedData ~= nil
            end,
        },
        {
            name = function()
                local ms = Companions.multiSelectManager
                if ms and ms:IsActive() then
                    return GetString(rawget(_G, "SI_BETTERUI_INV_BATCH_ACTIONS") or "SI_BETTERUI_INV_BATCH_ACTIONS")
                end
                return GetString(SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND)
            end,
            keybind = "UI_SHORTCUT_TERTIARY",
            visible = function()
                local selectedData = instance.list and instance.list:GetSelectedData()
                if not selectedData then
                    return false
                end
                local ms = Companions.multiSelectManager
                if ms and ms:IsActive() then
                    return ms:HasSelections()
                end
                return true
            end,
            callback = function()
                local ms = Companions.multiSelectManager
                if ms and ms:IsActive() then
                    if ZO_Dialogs_ShowGamepadDialog then
                        ZO_Dialogs_ShowGamepadDialog("BETTERUI_COMPANION_BATCH_DIALOG")
                    end
                    return
                end
                local selectedData = instance.list and instance.list:GetSelectedData()
                if selectedData and ZO_Dialogs_ShowGamepadDialog then
                    ZO_Dialogs_ShowGamepadDialog("BETTERUI_COMPANION_ACTION_DIALOG", { selectedData = selectedData })
                end
            end,
        },
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = function()
                if instance.searchQuery and instance.searchQuery ~= "" then
                    return GetString(rawget(_G, "SI_BETTERUI_CLEAR_SEARCH"))
                end
                return GetString(rawget(_G, "SI_BETTERUI_INV_SEARCH") or "SI_BETTERUI_INV_SEARCH")
            end,
            keybind = "UI_SHORTCUT_QUATERNARY",
            disabledDuringSceneHiding = true,
            visible = function()
                if instance._searchModeActive then
                    return false
                end
                if instance.sortController and instance.sortController:IsActive() then
                    return false
                end
                local ms = Companions.multiSelectManager
                if ms and ms:IsActive() then
                    return false
                end
                return instance.textSearchHeaderControl ~= nil and not instance.textSearchHeaderControl:IsHidden()
            end,
            callback = function()
                if instance.searchQuery and instance.searchQuery ~= "" then
                    CallCompanionSearchLifecycle(instance, "clear")
                else
                    CallCompanionSearchLifecycle(instance, "requestEnter")
                end
                if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
                    KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
                end
            end,
        },
        {
            name = function()
                return GetMultiSelectKeybindName()
            end,
            keybind = "UI_SHORTCUT_QUINARY",
            visible = function()
                local ms = Companions.multiSelectManager
                if ms and ms:IsActive() then
                    return false
                end
                return IsMultiSelectAvailable()
            end,
            callback = function()
                local ms = Companions.multiSelectManager
                if not ms then
                    return
                end
                if ms:IsActive() then
                    ms:ExitSelectionMode()
                else
                    ms:EnterSelectionMode()
                end
                instance:RefreshList()
                instance:EnsureListInputActive()
                if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
                    KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
                end
            end,
        },
        {
            name = function()
                local ms = Companions.multiSelectManager
                if ms and ms:IsActive() then
                    return GetString(rawget(_G, "SI_BETTERUI_MULTI_SELECT_CANCEL") or "SI_BETTERUI_MULTI_SELECT_CANCEL")
                end
                return nil
            end,
            keybind = "UI_SHORTCUT_RIGHT_STICK",
            visible = function()
                local ms = Companions.multiSelectManager
                return ms and ms:IsActive() or false
            end,
            callback = function()
                local ms = Companions.multiSelectManager
                if not ms or not ms:IsActive() then
                    return
                end
                ms:ExitSelectionMode()
                instance:RefreshList()
                instance:EnsureListInputActive()
                if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
                    KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
                end
            end,
        },
        {
            name = GetString(SI_GAMEPAD_BACK_OPTION),
            keybind = "UI_SHORTCUT_NEGATIVE",
            callback = function()
                local ms = Companions.multiSelectManager
                if ms and ms:IsActive() then
                    ms:ExitSelectionMode()
                    instance:RefreshList()
                    instance:EnsureListInputActive()
                    if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
                        KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
                    end
                    return
                end
                SCENE_MANAGER:HideCurrentScene()
            end,
        },
    }
end
