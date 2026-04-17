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
    runtimeOwner = "Modules/Companions/Core/CompanionsRuntime.lua + Modules/Companions/Core/ + Modules/Companions/Actions/ + Modules/Companions/Dialogs/",
    settingsOwner = "Modules/Companions/Module.lua + Modules/Companions/Settings/",
    notes = "Module.lua owns the public Init/Setup contract and settings-panel wiring, while CompanionsRuntime.lua plus Core/, Actions/, and Dialogs/ implement the live companion scene, events, keybinds, and dialog flow.",
}

-- Wire standard font aliases, font descriptors, and GetSetting/SetSetting accessors
if BETTERUI.CIM and BETTERUI.CIM.RegisterModuleAccessors then
    BETTERUI.CIM.RegisterModuleAccessors("Companions")
end

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

-- Runtime keybind, scene, and event helpers live in Core/CompanionsRuntime.lua.

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
    Companions.instance.coreKeybinds = Companions.BuildCoreKeybinds(Companions.instance)
    Companions.SetupSort(Companions.instance)
    Companions.CreateScene(Companions.instance)
    Companions.RegisterSceneLifecycle(Companions.instance)

    Companions.instance:InitCompanionFooter()

    -- Narration
    if BETTERUI.CIM.Narration and BETTERUI.CIM.Narration.RegisterListNarration then
        BETTERUI.CIM.Narration.RegisterListNarration(
            BETTERUI_COMPANION_EQUIP_SCENE_NAME,
            function() return Companions.instance and Companions.instance.list and Companions.instance.list:GetTargetData() end,
            function() return Companions.instance and Companions.instance:GetTitle() end
        )
    end

    Companions.RegisterEvents(EVENT_MANAGER)

    Companions.initialized = true
end
