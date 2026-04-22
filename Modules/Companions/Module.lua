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

local function TrackPanelRegistration(reason)
    Companions._panelRegistrationReason = reason
    Companions._panelRegistrationDeferred = reason == "missing_register_panel"
end

local function EnsureCompanionsSetupContracts()
    BETTERUI.CIM.RegisterModuleAccessors(Companions, "Companions")
    local panelOk, panelReason = BETTERUI.CIM.TryRegisterModulePanel(Companions, "Companions", "Companions", "Companions")
    TrackPanelRegistration(panelReason)
    if not panelOk and panelReason ~= nil and panelReason ~= "missing_register_panel" and BETTERUI.Debug then
        BETTERUI.Debug(string.format("[%s] Settings panel registration reported: %s", MODULE_NAME, tostring(panelReason)))
    end
end

local function WrapCompanionRuntimeError(operation, err)
    return string.format("[Companions] %s failed: %s", operation, tostring(err))
end

Companions.WrapRuntimeError = WrapCompanionRuntimeError

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

    Companions.InitializeRuntime()

    Companions.initialized = true
end
