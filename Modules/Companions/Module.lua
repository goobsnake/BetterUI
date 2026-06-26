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
local MODULE_NAME = "Companions"
local ARCHETYPES = BETTERUI.CIM and BETTERUI.CIM.ARCHETYPES or {}
local RUNTIME_COORDINATOR = ARCHETYPES.RUNTIME_COORDINATOR or "runtime-coordinator"

---@type BetterUIModuleArchetypeRuntimeCoordinator
Companions.ARCHETYPE = RUNTIME_COORDINATOR
---@type BetterUIModuleRootContract
Companions.ROOT_CONTRACT = {
    name = MODULE_NAME,
    archetype = Companions.ARCHETYPE,
    init = true,
    setup = true,
}

-- Wire shared settings statics before runtime accessors register in Setup().
BETTERUI.CIM.ApplyModuleSharedSettingsStatics(Companions, MODULE_NAME)

local function EnsureCompanionsSetupContracts()
    BETTERUI.CIM.RegisterModuleAccessors(Companions, "Companions")
    BETTERUI.CIM.RegisterModulePanelWithLogging(Companions, "Companions", "Companions", "Companions")
end

local function WrapCompanionRuntimeError(operation, err)
    return string.format("[Companions] %s failed: %s", operation, tostring(err))
end

Companions.WrapRuntimeError = WrapCompanionRuntimeError

local function NotifyCompanionSetupFailure(messageText)
    if BETTERUI.CIM and BETTERUI.CIM.UserNotify then
        BETTERUI.CIM.UserNotify("Companions.Init", messageText)
        return
    end
    if BETTERUI.Log then
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIFECYCLE, tostring(messageText))
    end
end

local function TraceCompanionInit(phase, data)
    local log = BETTERUI and BETTERUI.Log or nil
    if not (log and log.TraceEvent) then return end
    data = data or {}
    data.module = "Companions"
    data.scene = BETTERUI_COMPANION_EQUIP_SCENE_NAME
    data.feature = "companion-init"
    data.fn = data.fn or "Companions.Init"
    log.TraceEvent((log.CATEGORY or {}).LIFECYCLE, "companions.init", phase, data)
end

local function CountCompanionSnapshotRows(list)
    if not list then return 0 end
    if list.GetNumItems then
        local ok, count = pcall(function() return list:GetNumItems() end)
        if ok and type(count) == "number" then return count end
    end
    return type(list.dataList) == "table" and #list.dataList or 0
end

local function GetCompanionSnapshotSelectedIndex(list)
    if not list then return 0 end
    if type(list.selectedIndex) == "number" then return list.selectedIndex end
    if list.GetSelectedIndex then
        local ok, index = pcall(function() return list:GetSelectedIndex() end)
        if ok and type(index) == "number" then return index end
    end
    return 0
end

local function GetCompanionSnapshotSelectionToken(list)
    if not list then return "nil" end
    local selectedOk, selected = pcall(function()
        if list.GetTargetData then
            return list:GetTargetData()
        elseif list.GetSelectedData then
            return list:GetSelectedData()
        end
        return list.selectedData
    end)
    if not selectedOk then return "error" end
    local data = selected and (selected.dataSource or selected) or nil
    local activeCompanionId = HasActiveCompanion and HasActiveCompanion() and GetActiveCompanionDefId and GetActiveCompanionDefId() or nil
    return data and string.format("companion=%s,activeCompanion=%s,collectible=%s,bag=%s,slot=%s,entry=%s", tostring(data.companionId or data.companionDefId or activeCompanionId or "nil"), tostring(activeCompanionId or "nil"), tostring(data.collectibleId or "nil"), tostring(data.bagId or "nil"), tostring(data.slotIndex or "nil"), tostring(data.entryIndex or "nil")) or string.format("activeCompanion=%s", tostring(activeCompanionId or "nil"))
end

local function GetCompanionSnapshotCategory(instance)
    local category = instance and instance.GetCurrentCategory and instance:GetCurrentCategory() or nil
    return category and (category.key or category.name or category.filterType) or nil
end

local function IsCompanionSnapshotKeybindPresent(descriptor)
    return BETTERUI.Interface.HasKeybindGroup(descriptor) and 1 or 0
end

local function RegisterCompanionSnapshotProvider()
    local watch = BETTERUI.CIM and BETTERUI.CIM.WatchMode
    if not (watch and watch.RegisterSnapshotProvider) then return end
    watch.RegisterSnapshotProvider("companions", function()
        local instance = Companions.instance
        if not instance then
            return string.format("init=%s window=0 error=%s", tostring(Companions.initialized == true), tostring(Companions._initError or "nil"))
        end
        local visible = instance.IsSceneShowing and instance:IsSceneShowing() or false
        local multiSelect = Companions.multiSelectManager or instance.multiSelectManager
        local selectedCount = 0
        if multiSelect and multiSelect.GetSelectedItems then
            local selectedItems = multiSelect:GetSelectedItems()
            selectedCount = type(selectedItems) == "table" and #selectedItems or 0
        end
        return string.format(
            "init=%s window=1 visible=%s category=%s rows=%s selectedIndex=%s selectedId=%s refreshing=%s search=%d sortReady=%s sortDegraded=%s multiselect=%s keybindCore=%s",
            tostring(Companions.initialized == true),
            tostring(visible),
            tostring(GetCompanionSnapshotCategory(instance)),
            tostring(CountCompanionSnapshotRows(instance.list)),
            tostring(GetCompanionSnapshotSelectedIndex(instance.list)),
            tostring(GetCompanionSnapshotSelectionToken(instance.list)),
            tostring(instance._isRefreshing == true),
            instance.searchQuery and #tostring(instance.searchQuery) or 0,
            tostring(instance.sortSetupReady == true),
            tostring(instance.sortSetupDegraded == true),
            tostring(selectedCount),
            tostring(IsCompanionSnapshotKeybindPresent(instance.coreKeybinds)))
    end)
end

RegisterCompanionSnapshotProvider()

---@param m_options BetterUIModuleOptions|nil Module options table
---@return BetterUIModuleOptions m_options Initialized options with defaults applied
---@type BetterUIModuleInitHook
function BETTERUI.Companions.InitModule(m_options)
    m_options = m_options or {}
    ---@cast m_options BetterUIModuleOptions
    local defaults = BETTERUI.Companions.DEFAULTS
    local moduleDefaults = BETTERUI.Defaults and BETTERUI.Defaults.GetModuleDefaults
        and BETTERUI.Defaults.GetModuleDefaults("Companions") or nil

    m_options = BETTERUI.CIM.InitModuleDefaults(MODULE_NAME, m_options, defaults, moduleDefaults)
    return m_options
end

---@type BetterUIModuleSetupHook
function BETTERUI.Companions.Setup()
    EnsureCompanionsSetupContracts()

    if BETTERUI.Companions.GetSetting("enableCompanionEquipment") == false then
        return true
    end

    return BETTERUI.Companions.Init()
end

-- Runtime keybind, scene, and event helpers live in Core/CompanionsRuntime.lua.

-- INITIALIZATION

function BETTERUI.Companions.Init()
    if Companions.initialized then
        TraceCompanionInit("skipped", { reason = "alreadyInitialized", hasInstance = Companions.instance ~= nil })
        return true
    end

    TraceCompanionInit("begin", { hasInteraction = INTERACTION_COMPANION_MENU ~= nil })

    if not INTERACTION_COMPANION_MENU then
        local initErr = "missingInteraction"
        if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.LIFECYCLE, "companion menu interaction missing; init skipped") end
        Companions._initError = initErr
        TraceCompanionInit("skipped", { reason = initErr, initialized = false })
        return false, initErr
    end

    local instance, initErr = Companions.InitializeRuntime()
    if not instance then
        Companions._initError = initErr
        if initErr then
            NotifyCompanionSetupFailure(initErr)
        end
        TraceCompanionInit("failed", { reason = tostring(initErr or "unknown"), initialized = false })
        return false, initErr
    end

    Companions._initError = nil
    Companions.initialized = true
    TraceCompanionInit("end", { initialized = true, hasInstance = true })
    return true
end
