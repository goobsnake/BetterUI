--[[
File: Modules/Companions/Core/CompanionsRuntime.lua
Purpose: Runtime scene, event, and keybind orchestration for the Companions module.
         Keeps Module.lua focused on lifecycle wiring while this file owns the
         live runtime helpers used by companion equipment flow.
]]

local Companions = BETTERUI.Companions
local EVENT_NS = "BetterUI_Companions"

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

function Companions.SetupSort(instance)
    if BETTERUI.CIM.UI and BETTERUI.CIM.UI.HeaderSortIntegration and BETTERUI.CIM.UI.HeaderSortIntegration.Install then
        local ok, err = pcall(function()
            local integration = BETTERUI.CIM.UI.HeaderSortIntegration.Install(instance, {
                list = instance.list,
                columns = {
                    { name = GetString(SI_BETTERUI_INV_HEADER_NAME), key = "name" },
                    { name = GetString(SI_BETTERUI_INV_HEADER_TYPE), key = "type" },
                    { name = GetString(SI_BETTERUI_INV_HEADER_TRAIT), key = "trait" },
                    { name = GetString(SI_BETTERUI_INV_HEADER_STAT), key = "stat" },
                    { name = GetString(SI_BETTERUI_INV_HEADER_VALUE), key = "value", defaultDirection = "descending" },
                },
                onSortChangedCallback = function()
                    instance:RefreshList()
                end,
                controllerField = "sortController",
                controllerAliasFields = { "headerSortController" },
                keybindDescriptor = instance.coreKeybinds,
                autoEnterOnListStart = true,
            })
            BETTERUI.CIM.UI.HeaderSortIntegration.EnsureController(integration)
        end)
        if not ok and BETTERUI.Debug then
            BETTERUI.Debug("[Companions] Header sort setup failed: " .. tostring(err))
        end
    end
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
    COMPANION_EQUIPMENT_GAMEPAD = instance
    return scene
end

function Companions.RegisterSceneLifecycle(instance)
    BETTERUI.CIM.SceneLifecycle.Register(instance, {
        keybinds = { instance.coreKeybinds },
        taskManager = Companions.Tasks,
        onShowing = function(screen)
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
            local searchMixin = BETTERUI.Interface and BETTERUI.Interface.SearchMixin
            if searchMixin and searchMixin.CallSearchLifecycle and Companions.instance then
                searchMixin.CallSearchLifecycle(Companions.instance, "exit")
            elseif Companions.instance and Companions.instance.ExitSearchMode then
                Companions.instance:ExitSearchMode()
            end
            local category = screen:GetCurrentCategory()
            if category and screen.list then
                BETTERUI.CIM.PositionManager.SavePosition("Companions", category.key, screen.list)
            end
            if GAMEPAD_TOOLTIPS then
                GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
                GAMEPAD_TOOLTIPS:Reset(GAMEPAD_RIGHT_TOOLTIP)
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
                    if instance.ClearTextSearch then
                        instance:ClearTextSearch()
                    end
                else
                    instance:EnterSearchFocus()
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
