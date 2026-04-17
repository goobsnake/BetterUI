--[[
File: Modules/Companions/Module.lua
Purpose: Entry point for the Companions equipment management module.
         Provides companion equipment viewing/management through BetterUI's
         enhanced interface (column headers, icon badges, font controls).

ESO Reference: ZO_CompanionEquipment_Gamepad in
  esoui/ingame/companion/gamepad/companionequipment_gamepad.lua
  Uses BAG_COMPANION_WORN for equipped companion gear and BAG_BACKPACK for
  equippable companion items. Scene: "companionEquipmentGamepad".
]]

---@type BetterUIModuleRoot
BETTERUI.Companions = BETTERUI.Companions or {}
local Companions = BETTERUI.Companions

Companions.ARCHETYPE = "runtime-coordinator"
---@type BetterUIModuleRootContract
Companions.ROOT_CONTRACT = {
    name = "Companions",
    archetype = Companions.ARCHETYPE,
    initOwner = "Modules/Companions/Module.lua",
    setupOwner = "Modules/Companions/Module.lua",
    runtimeOwner = "Modules/Companions/Module.lua + Modules/Companions/Core/ + Modules/Companions/Actions/ + Modules/Companions/Dialogs/",
    settingsOwner = "Modules/Companions/Module.lua + Modules/Companions/Settings/",
    notes = "Module.lua owns Init/Setup wiring and companion runtime orchestration, delegates module-setting defaults to DefaultsRegistry, and keeps shared CIM font defaults while Core/, Actions/, and Dialogs/ implement list behavior, actions, and dialog flow.",
}

-- Wire standard font aliases, font descriptors, and GetSetting/SetSetting accessors
if BETTERUI.CIM and BETTERUI.CIM.RegisterModuleAccessors then
    BETTERUI.CIM.RegisterModuleAccessors("Companions")
end

-- LOCAL STATE
local EVENT_NS     = "BetterUI_Companions"
local OnCompanionActivated
local OnCompanionDeactivated
local OnInventoryUpdated

local function WrapCompanionRuntimeError(operation, err)
    return string.format("[Companions] %s failed: %s", operation, tostring(err))
end

Companions.WrapRuntimeError = WrapCompanionRuntimeError

local function RegisterCompanionsPanel()
    if Companions._panelRegistered
        or not Companions.Settings
        or not Companions.Settings.RegisterPanel then
        return
    end

    local ok, err = pcall(Companions.Settings.RegisterPanel, "Companions", "Companions")
    if ok then
        Companions._panelRegistered = true
    elseif BETTERUI.Debug then
        BETTERUI.Debug("[Companions] Settings panel registration failed: " .. tostring(err))
    end
end

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

local function SetupCompanionSort(instance)
    if BETTERUI.CIM.UI and BETTERUI.CIM.UI.HeaderSortController then
        local ok, err = pcall(function()
            local sortController = BETTERUI.CIM.UI.HeaderSortController:New(instance)
            sortController:AddColumn(GetString(SI_BETTERUI_INV_HEADER_NAME), "name")
            sortController:AddColumn(GetString(SI_BETTERUI_INV_HEADER_TYPE), "type")
            sortController:AddColumn(GetString(SI_BETTERUI_INV_HEADER_TRAIT), "trait")
            sortController:AddColumn(GetString(SI_BETTERUI_INV_HEADER_STAT), "stat")
            sortController:AddColumn(GetString(SI_BETTERUI_INV_HEADER_VALUE), "value")
            sortController:SetSortChangedCallback(function()
                instance:RefreshList()
            end)
            instance.sortController = sortController
        end)
        if not ok and BETTERUI.Debug then
            BETTERUI.Debug("[Companions] Sort controller init failed: " .. tostring(err))
        end
    end

    if instance.sortController and BETTERUI.CIM.UI.HeaderSortIntegration and BETTERUI.CIM.UI.HeaderSortIntegration.Setup then
        local ok, err = pcall(function()
            BETTERUI.CIM.UI.HeaderSortIntegration.Setup(
                instance.list,
                instance.sortController,
                {
                    keybindStrip = true,
                    mainKeybindDescriptor = instance.coreKeybinds,
                    onSortChanged = function()
                        instance:RefreshList()
                    end,
                }
            )
        end)
        if not ok and BETTERUI.Debug then
            BETTERUI.Debug("[Companions] Header sort integration setup failed: " .. tostring(err))
        end
    end
end

local function CreateCompanionScene(instance)
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
        if not Companions.instance then return end
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

local function RegisterCompanionSceneLifecycle(instance)
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
            if Companions.instance and Companions.instance.ExitSearchFocus then
                Companions.instance:ExitSearchFocus()
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

local function RegisterCompanionEvents(eventManager)
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

--- Initializes defaults and applies fallback values for saved variables.
---
--- INIT CONTRACT: This function implements the standard InitModule signature.
--- It is called by BETTERUI.ModuleOptions() via pcall with only m_options.
---
--- Standard InitModule Signature (consistent across all modules):
---
--- Wrapper Function (caller in BetterUI.lua):
---   BETTERUI.ModuleOptions(m_namespace, m_options, moduleName)
---
---@param m_options BetterUIModuleOptions|nil Module options table
---@return BetterUIModuleOptions m_options Initialized options with defaults applied
---@type BetterUIModuleInitHook
function BETTERUI.Companions.InitModule(m_options)
    m_options = m_options or {}
    ---@cast m_options BetterUIModuleOptions
    local defaults = BETTERUI.Companions.DEFAULTS
    local moduleDefaults = BETTERUI.Defaults and BETTERUI.Defaults.GetModuleDefaults
        and BETTERUI.Defaults.GetModuleDefaults("Companions") or nil

    m_options = BETTERUI.CIM.InitModuleDefaults("Companions", m_options, defaults, moduleDefaults)
    return m_options
end

--- Lifecycle hook: registers settings panel and initializes the module.
--- Called by BETTERUI.LoadModules() via MODULE_REGISTRY.
function BETTERUI.Companions.Setup()
    RegisterCompanionsPanel()

    if BETTERUI.Companions.GetSetting("enableCompanionEquipment") == false then
        return
    end

    BETTERUI.Companions.Init()
end

-- KEYBINDS

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
local function BuildCoreKeybinds(instance)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        -- Primary action: Equip / Unequip (or Toggle Selection in multi-select)
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
                if not selectedData then return end
                local ds = selectedData.dataSource or selectedData
                local bagId = ds.bagId
                local slotIndex = ds.slotIndex
                if bagId == nil or slotIndex == nil then return end
                if ds.isEquipped then
                    Companions.TryUnequipCompanionItem(slotIndex)
                else
                    Companions.TryEquipCompanionItem(bagId, slotIndex)
                end
                -- Refresh keybinds after equip/unequip to update action label
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
        -- Tertiary: Y-Menu (Action Dialog) when not in multi-select; Batch dialog when in multi-select
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
                if not selectedData then return false end
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
        -- Quaternary: Clear Search (only when search active)
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
                if instance._searchModeActive then return false end
                if instance.sortController and instance.sortController:IsActive() then return false end
                local ms = Companions.multiSelectManager
                if ms and ms:IsActive() then return false end
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
        -- Quinary: Enter/Exit Multi-Select
        {
            name = function() return GetMultiSelectKeybindName() end,
            keybind = "UI_SHORTCUT_QUINARY",
            visible = function()
                local ms = Companions.multiSelectManager
                if ms and ms:IsActive() then return false end
                return IsMultiSelectAvailable()
            end,
            callback = function()
                local ms = Companions.multiSelectManager
                if not ms then return end
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
        -- Back / Exit
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

-- EVENT HANDLERS

function OnCompanionActivated()
    RefreshVisibleCompanionScene(Companions.instance)
end

function OnCompanionDeactivated()
    if not Companions.instance then return end
    if Companions.instance:IsSceneShowing() then
        SCENE_MANAGER:HideCurrentScene()
    end
end

function OnInventoryUpdated()
    if not Companions.instance then return end
    if not Companions.instance:IsSceneShowing() then return end

    Companions.Tasks:Cancel("listRefresh")
    Companions.Tasks:Schedule("listRefresh", 100, function()
        RefreshVisibleCompanionScene(Companions.instance)
    end)
end

-- INITIALIZATION

function BETTERUI.Companions.Init()
    if Companions.initialized then return end

    if not INTERACTION_COMPANION_MENU then
        BETTERUI.Debug("[Companions] INTERACTION_COMPANION_MENU not available — skipping init")
        Companions.initialized = true
        return
    end

    Companions.RegisterDialogs()

    Companions.instance = Companions.Class:New(
        "BETTERUI_CompanionWindow", BETTERUI_COMPANION_EQUIP_SCENE_NAME)
    Companions.instance:SetTitle(
        "|c0066FF" .. GetString(rawget(_G, "SI_BETTERUI_COMPANIONS_TITLE") or "SI_BETTERUI_COMPANIONS_TITLE") .. "|r")

    Companions.instance:SetupList(
        "BETTERUI_GamepadItemSubEntryTemplate",
        BETTERUI_SharedGamepadEntry_OnSetup
    )
    Companions.instance:InitializeListPresentation()

    -- Monkeypatch MovePrevious to allow moving "up" from the top of the list into the header/search bar.
    if Companions.instance.list and Companions.instance.list.MovePrevious then
        local originalMovePrevious = Companions.instance.list.MovePrevious
        Companions.instance.list.MovePrevious = function(list, allowWrapping, suppressFailSound)
            local didMove = originalMovePrevious(list, allowWrapping, suppressFailSound)
            if didMove then
                return true
            end
            if Companions.instance and Companions.instance.OnHeaderEntered then
                Companions.instance:OnHeaderEntered()
            elseif Companions.instance and Companions.instance.RequestHeaderFocus then
                Companions.instance:RequestHeaderFocus()
            end
            return true
        end
    end

    Companions.instance:InitializeCategoryHeader()

    local HDR_COL = BETTERUI.CIM.CONST.HEADER_LAYOUT.COLUMNS
    Companions.instance:AddColumn(GetString(SI_BETTERUI_INV_HEADER_NAME), HDR_COL.NAME)
    Companions.instance:AddColumn(GetString(SI_BETTERUI_INV_HEADER_TYPE), HDR_COL.TYPE)
    Companions.instance:AddColumn(GetString(SI_BETTERUI_INV_HEADER_TRAIT), HDR_COL.TRAIT)
    Companions.instance:AddColumn(GetString(SI_BETTERUI_INV_HEADER_STAT), HDR_COL.STAT)
    Companions.instance:AddColumn(GetString(SI_BETTERUI_INV_HEADER_VALUE), HDR_COL.VALUE)
    Companions.instance:RefreshCategories()
    Companions.instance:EnsureColumnHeadersVisible()

    -- Adjust list left anchor: GenericInterface default offsetX=-27 clips equipped
    -- icons past the panel edge; shift right to give icon margin.
    do
        local listControl = Companions.instance.list and Companions.instance.list.control
        local headerGeneric = Companions.instance.headerGeneric
        if listControl and headerGeneric then
            local container = Companions.instance.control
                and Companions.instance.control:GetNamedChild("Container")
            local footer = container and container:GetNamedChild("Footer")
            local footerFooter = footer and footer:GetNamedChild("Footer")
            listControl:ClearAnchors()
            listControl:SetAnchor(TOPLEFT, headerGeneric, BOTTOMLEFT, 20, 15)
            if footerFooter then
                listControl:SetAnchor(BOTTOMRIGHT, footerFooter, TOPRIGHT, 0, -8)
            end
        end
    end

    -- Multi-Select
    if BETTERUI.CIM and BETTERUI.CIM.MultiSelectManager and BETTERUI.CIM.MultiSelectManager.Create then
        Companions.multiSelectManager = BETTERUI.CIM.MultiSelectManager.Create(Companions.instance.list, function()
            if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
                KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
            end
        end)
    else
        Companions.multiSelectManager = nil
    end

    -- Search
    if BETTERUI.Interface.SearchMixin and Companions.instance.AddSearch then
        Companions.instance:AddSearch(
            BETTERUI.Interface.CreateSearchKeybindDescriptor(Companions.instance),
            function(queryOrControl)
                -- SetupEditBoxHandlers calls origOnTextChanged(editbox), so we may receive
                -- an editbox control rather than a plain string. Extract text defensively.
                local query = type(queryOrControl) == "string" and queryOrControl
                    or (queryOrControl and queryOrControl.GetText and queryOrControl:GetText())
                    or ""
                Companions.instance.searchQuery = query
                Companions.instance:RefreshList()
            end
        )
        -- Header sort integration handles SetOnHitBeginningOfListCallback for sort mode.
        -- Search focus is entered via the Quaternary (X) keybind.
        if BETTERUI.Interface.SearchMixin and BETTERUI.Interface.SearchMixin.SetupEditBoxHandlers then
            BETTERUI.Interface.SearchMixin.SetupEditBoxHandlers(Companions.instance, {
                isSceneShowing = function()
                    return Companions.instance and Companions.instance:IsSceneShowing()
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

    -- Keybinds
    Companions.instance.coreKeybinds = BuildCoreKeybinds(Companions.instance)
    SetupCompanionSort(Companions.instance)
    CreateCompanionScene(Companions.instance)
    RegisterCompanionSceneLifecycle(Companions.instance)

    Companions.instance:InitCompanionFooter()

    -- Narration
    if BETTERUI.CIM.Narration and BETTERUI.CIM.Narration.RegisterListNarration then
        BETTERUI.CIM.Narration.RegisterListNarration(
            BETTERUI_COMPANION_EQUIP_SCENE_NAME,
            function() return Companions.instance and Companions.instance.list and Companions.instance.list:GetTargetData() end,
            function() return Companions.instance and Companions.instance:GetTitle() end
        )
    end

    RegisterCompanionEvents(EVENT_MANAGER)

    Companions.initialized = true
end
