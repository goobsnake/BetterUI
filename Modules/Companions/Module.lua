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
BETTERUI.CIM.ApplyModuleSharedSettingsStatics(Companions, "Companions")

local function WrapCompanionRuntimeError(operation, err)
    return string.format("[Companions] %s failed: %s", operation, tostring(err))
end

Companions.WrapRuntimeError = WrapCompanionRuntimeError

local function EnsureCompanionsSetupContracts()
    BETTERUI.CIM.RegisterModuleAccessors(Companions, "Companions")
end

--- Initializes defaults and applies fallback values for saved variables.
---
--- INIT CONTRACT: This function implements the standard InitModule signature.
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
    EnsureCompanionsSetupContracts()
    BETTERUI.CIM.TryRegisterModulePanel(Companions, "Companions", "Companions", "Companions")

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
