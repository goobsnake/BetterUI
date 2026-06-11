--[[
File: Modules/TradingHouse/Module.lua
Purpose: Entry point and settings configuration for the Trading House module.

Registers the TradingHouse panel in the BetterUI addon settings and provides
font descriptor factories for the name and column rendering.
]]

-- Module initialization
---@type BetterUIModuleRoot
BETTERUI.TradingHouse = BETTERUI.TradingHouse or {}
local TradingHouse = BETTERUI.TradingHouse
local ARCHETYPES = BETTERUI.CIM and BETTERUI.CIM.ARCHETYPES or {}
local RUNTIME_COORDINATOR = ARCHETYPES.RUNTIME_COORDINATOR or "runtime-coordinator"

---@type BetterUIModuleArchetypeRuntimeCoordinator
TradingHouse.ARCHETYPE = RUNTIME_COORDINATOR
---@type BetterUIModuleRootContract
TradingHouse.ROOT_CONTRACT = {
    name = "TradingHouse",
    archetype = TradingHouse.ARCHETYPE,
    init = true,
    setup = true,
}

-- Wire shared settings statics before runtime accessors register in Setup().
BETTERUI.CIM.ApplyModuleSharedSettingsStatics(TradingHouse, "TradingHouse")

---@param m_options BetterUIModuleOptions|nil Module options table
---@return BetterUIModuleOptions m_options Initialized options with defaults applied
---@type BetterUIModuleInitHook
function BETTERUI.TradingHouse.InitModule(m_options)
    m_options = m_options or {}
    ---@cast m_options BetterUIModuleOptions
    local defaults = BETTERUI.TradingHouse.DEFAULTS
    local moduleDefaults = BETTERUI.Defaults and BETTERUI.Defaults.GetModuleDefaults
        and BETTERUI.Defaults.GetModuleDefaults("TradingHouse") or nil

    m_options = BETTERUI.CIM.InitModuleDefaults("TradingHouse", m_options, defaults, moduleDefaults)

    -- Backfill legacy saved vars that predate canonical module toggles.
    -- Respect explicit user choices (false/true) when already present.
    if m_options.m_enabled == nil then
        m_options.m_enabled = true
    end

    return m_options
end

local function EnsureTradingHouseSetupContracts()
    BETTERUI.CIM.RegisterModuleAccessors(TradingHouse, "TradingHouse")
    BETTERUI.CIM.RegisterModulePanelWithLogging(TradingHouse, "TradingHouse", "TradingHouse", "TradingHouse")
end

---@param totalPrice number Total cost of the stack
---@param quantity number Stack size
---@return string formatted Human-readable unit price string
function BETTERUI.TradingHouse.FormatUnitPrice(totalPrice, quantity)
    if not totalPrice or not quantity or quantity == 0 then return "" end
    local unitPrice = math.floor(totalPrice / quantity)
    return BETTERUI.DisplayNumber(unitPrice) .. "g ea"
end

---@type BetterUIModuleSetupHook
function BETTERUI.TradingHouse.Setup()
    EnsureTradingHouseSetupContracts()
    BETTERUI.TradingHouse.Init()
end
