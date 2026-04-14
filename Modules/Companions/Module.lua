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

BETTERUI.Companions = BETTERUI.Companions or {}

-- Wire standard font aliases, font descriptors, and GetSetting/SetSetting accessors
if BETTERUI.CIM and BETTERUI.CIM.RegisterModuleAccessors then
    BETTERUI.CIM.RegisterModuleAccessors("Companions")
end

-- LOCAL STATE
local Companions   = BETTERUI.Companions
local EVENT_NS     = "BetterUI_Companions"

--- Initializes defaults and applies fallback values for saved variables.
---@param m_options table|nil Module options from saved variables
---@return table m_options Initialized options with defaults applied
function BETTERUI.Companions.InitModule(m_options)
    m_options = m_options or {}
    local defaults = BETTERUI.Companions.DEFAULTS
    local fallbackDefaults = {
        enableCompanionEquipment = true,
        quickDestroy = false,
        batchDestroy = true,
        bindOnEquipProtection = true,
        enableCompanionJunk = true,
    }

    m_options = BETTERUI.CIM.InitModuleDefaults("Companions", m_options, defaults, fallbackDefaults)
    return m_options
end

--- Lifecycle hook: registers settings panel and initializes the module.
--- Called by BETTERUI.LoadModules() via MODULE_REGISTRY.
function BETTERUI.Companions.Setup()
    if not BETTERUI.Companions._panelRegistered
        and BETTERUI.Companions.Settings
        and BETTERUI.Companions.Settings.RegisterPanel then
        local ok, err = pcall(BETTERUI.Companions.Settings.RegisterPanel, "Companions", "Companions")
        if ok then
            BETTERUI.Companions._panelRegistered = true
        elseif BETTERUI.Debug then
            BETTERUI.Debug("[Companions] Settings panel registration failed: " .. tostring(err))
        end
    end

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
    local ms = Companions.multiSelectManager
    if ms and ms:IsActive() then
        return GetString(SI_GAMEPAD_BACK_OPTION)
    end
    return GetString(rawget(_G, "SI_BETTERUI_INV_MULTI_SELECT") or "SI_BETTERUI_INV_MULTI_SELECT")
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
                return GetString(rawget(_G, "SI_GAMEPAD_INVENTORY_SEARCH") or "SI_GAMEPAD_INVENTORY_SEARCH")
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

local function OnCompanionActivated()
    if not Companions.instance then return end
    if Companions.instance:IsSceneShowing() then
        Companions.instance:RefreshCategories()
        Companions.instance:RefreshList()
        Companions.instance:RefreshCompanionFooter()
        Companions.instance:EnsureListInputActive()
        Companions.instance:UpdateItemTooltips(Companions.instance.list and Companions.instance.list:GetTargetData())
    end
end

local function OnCompanionDeactivated()
    if not Companions.instance then return end
    if Companions.instance:IsSceneShowing() then
        SCENE_MANAGER:HideCurrentScene()
    end
end

local function OnInventoryUpdated()
    if not Companions.instance then return end
    if not Companions.instance:IsSceneShowing() then return end

    Companions.Tasks:Cancel("listRefresh")
    Companions.Tasks:Schedule("listRefresh", 100, function()
        if Companions.instance and Companions.instance:IsSceneShowing() then
            Companions.instance:RefreshCategories()
            Companions.instance:RefreshList()
            Companions.instance:RefreshCompanionFooter()
            Companions.instance:EnsureListInputActive()
            Companions.instance:UpdateItemTooltips(Companions.instance.list and Companions.instance.list:GetTargetData())
        end
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
    Companions.instance:InitializeCategoryHeader()

    local COL = BETTERUI.CIM.CONST.LAYOUT.COLUMNS
    Companions.instance:AddColumn(GetString(SI_BETTERUI_INV_HEADER_NAME), COL[1])
    Companions.instance:AddColumn(GetString(SI_BETTERUI_INV_HEADER_TYPE), COL[2])
    Companions.instance:AddColumn(GetString(SI_BETTERUI_INV_HEADER_TRAIT), COL[3])
    Companions.instance:AddColumn(GetString(SI_BETTERUI_INV_HEADER_STAT), COL[4])
    Companions.instance:AddColumn(GetString(SI_BETTERUI_INV_HEADER_VALUE), COL[5])
    Companions.instance:RefreshCategories()
    Companions.instance:EnsureColumnHeadersVisible()

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
    if BETTERUI.CIM.SearchMixin and Companions.instance.AddSearch then
        Companions.instance:AddSearch(
            BETTERUI.Interface.CreateSearchKeybindDescriptor(Companions.instance),
            function(query)
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
            })
        end
    end

    -- Sort Controller
    if BETTERUI.CIM.UI and BETTERUI.CIM.UI.HeaderSortController then
        local ok, err = pcall(function()
            local sortController = BETTERUI.CIM.UI.HeaderSortController:New(Companions.instance)
            sortController:AddColumn(GetString(SI_BETTERUI_INV_HEADER_NAME), "name")
            sortController:AddColumn(GetString(SI_BETTERUI_INV_HEADER_TYPE), "type")
            sortController:AddColumn(GetString(SI_BETTERUI_INV_HEADER_TRAIT), "trait")
            sortController:AddColumn(GetString(SI_BETTERUI_INV_HEADER_STAT), "stat")
            sortController:AddColumn(GetString(SI_BETTERUI_INV_HEADER_VALUE), "value")
            sortController:SetSortChangedCallback(function()
                Companions.instance:RefreshList()
            end)
            Companions.instance.sortController = sortController
        end)
        if not ok and BETTERUI.Debug then
            BETTERUI.Debug("[Companions] Sort controller init failed: " .. tostring(err))
        end
    end

    -- Keybinds
    Companions.instance.coreKeybinds = BuildCoreKeybinds(Companions.instance)

    -- Header Sort Integration
    if Companions.instance.sortController and BETTERUI.CIM.UI.HeaderSortIntegration and BETTERUI.CIM.UI.HeaderSortIntegration.Setup then
        local ok, err = pcall(function()
            BETTERUI.CIM.UI.HeaderSortIntegration.Setup(
                Companions.instance.list,
                Companions.instance.sortController,
                {
                    keybindStrip = true,
                    mainKeybindDescriptor = Companions.instance.coreKeybinds,
                    onSortChanged = function()
                        Companions.instance:RefreshList()
                    end,
                }
            )
        end)
        if not ok and BETTERUI.Debug then
            BETTERUI.Debug("[Companions] Header sort integration setup failed: " .. tostring(err))
        end
    end

    -- Fragments
    Companions.instance.fragment = ZO_SimpleSceneFragment:New(Companions.instance.control)
    Companions.instance.fragment:SetHideOnSceneHidden(true)
    local companionFooterDummy = BETTERUI.WindowManager:CreateControl(
        "BETTERUI_CompanionFooterDummy", GuiRoot, CT_CONTROL)
    companionFooterDummy:SetHidden(true)
    Companions.instance.footerFragment = ZO_SimpleSceneFragment:New(companionFooterDummy)
    Companions.instance.footerFragment:SetHideOnSceneHidden(true)

    -- Scene
    local sceneName = BETTERUI_COMPANION_EQUIP_SCENE_NAME
    local scene = ZO_InteractScene:New(sceneName, SCENE_MANAGER, Companions.COMPANION_INTERACTION)
    Companions.instance.scene = scene

    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD)
    scene:AddFragment(Companions.instance.fragment)
    scene:AddFragment(FRAME_EMOTE_FRAGMENT_INVENTORY)
    scene:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    scene:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    scene:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    scene:AddFragment(Companions.instance.footerFragment)

    -- Scene lifecycle
    BETTERUI.CIM.SceneLifecycle.Register(Companions.instance, {
        keybinds = { Companions.instance.coreKeybinds },
        taskManager = Companions.Tasks,
        onShowing = function(screen, wasPushed)
            BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.WIDTH)
            screen:RefreshCategories()
            screen:RefreshList()
            screen:RefreshCompanionFooter()
            screen:EnsureColumnHeadersVisible()
            screen:EnsureHeaderKeybindsActive()
            screen:EnsureListInputActive()
            screen:UpdateItemTooltips(screen.list and screen.list:GetTargetData())
        end,
        onHiding = function(screen)
            BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.ZO_WIDTH)
            screen:DeactivateListInput()
            screen:DeactivateHeaderKeybinds()
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
        end,
    })

    scene:RegisterCallback("StateChange", function(_, newState)
        if not Companions.instance then return end
        if newState == SCENE_SHOWN then
            Companions.instance:EnsureColumnHeadersVisible()
            Companions.instance:EnsureListInputActive()
            Companions.instance:UpdateItemTooltips(Companions.instance.list and Companions.instance.list:GetTargetData())
        end
    end)

    -- Alias
    SCENE_MANAGER.scenes["companionEquipmentGamepad"] = scene
    COMPANION_EQUIPMENT_GAMEPAD_SCENE = scene
    COMPANION_EQUIPMENT_GAMEPAD = Companions.instance

    Companions.instance:InitCompanionFooter()

    -- Narration
    if BETTERUI.CIM.Narration and BETTERUI.CIM.Narration.RegisterListNarration then
        BETTERUI.CIM.Narration.RegisterListNarration(
            BETTERUI_COMPANION_EQUIP_SCENE_NAME,
            function() return Companions.instance and Companions.instance.list and Companions.instance.list:GetTargetData() end,
            function() return Companions.instance and Companions.instance:GetTitle() end
        )
    end

    -- Events
    local em = EVENT_MANAGER
    if em then
        if EVENT_COMPANION_ACTIVATED then
            em:RegisterForEvent(EVENT_NS .. "_CompActivated",
                EVENT_COMPANION_ACTIVATED, OnCompanionActivated)
        end
        if EVENT_COMPANION_DEACTIVATED then
            em:RegisterForEvent(EVENT_NS .. "_CompDeactivated",
                EVENT_COMPANION_DEACTIVATED, OnCompanionDeactivated)
        end
        em:RegisterForEvent(EVENT_NS .. "_InvUpdate",
            EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventoryUpdated)
        em:RegisterForEvent(EVENT_NS .. "_InvFull",
            EVENT_INVENTORY_FULL_UPDATE, OnInventoryUpdated)
    end

    Companions.initialized = true
end
