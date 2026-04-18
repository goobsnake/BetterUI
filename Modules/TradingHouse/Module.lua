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

TradingHouse.ARCHETYPE = "runtime-coordinator"
---@type BetterUIModuleRootContract
TradingHouse.ROOT_CONTRACT = {
    name = "TradingHouse",
    archetype = TradingHouse.ARCHETYPE,
    initOwner = "Modules/TradingHouse/Module.lua",
    setupOwner = "Modules/TradingHouse/Module.lua",
    runtimeOwner = "Modules/TradingHouse/Module.lua + Modules/TradingHouse/TradingHouse.lua + Modules/TradingHouse/Core/ + Modules/TradingHouse/Components/",
    settingsOwner = "Modules/TradingHouse/Module.lua + Modules/TradingHouse/Settings/",
    notes = "Module.lua owns Init/Setup wiring and shared trading-house helpers, delegates module-setting defaults to DefaultsRegistry, keeps shared CIM font defaults, and relies on Core/TradingHouseRuntime.lua plus TradingHouse.lua/Components for runtime flow.",
}

-- Wire standard font aliases, font descriptors, and GetSetting/SetSetting accessors
BETTERUI.CIM.ApplyModuleSharedSettingsStatics(TradingHouse, "TradingHouse")

local function EnsureTradingHouseSetupContracts()
    BETTERUI.CIM.RegisterModuleAccessors(TradingHouse, "TradingHouse")
end

--- Initializes defaults and migrates legacy settings for the TradingHouse module.
---
--- INIT CONTRACT: This function implements the standard InitModule signature.
---
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

--- Formats unit price for display.
---@param totalPrice number Total cost of the stack
---@param quantity number Stack size
---@return string formatted Human-readable unit price string
function BETTERUI.TradingHouse.FormatUnitPrice(totalPrice, quantity)
    if not totalPrice or not quantity or quantity == 0 then return "" end
    local unitPrice = math.floor(totalPrice / quantity)
    return BETTERUI.DisplayNumber(unitPrice) .. "g ea"
end

--[[
Function: BETTERUI.TradingHouse.Setup
Lifecycle hook to setup the Trading House module.
References: Called by BETTERUI.LoadModules() in BetterUI.lua.
]]
---@return nil
function BETTERUI.TradingHouse.Setup()
    EnsureTradingHouseSetupContracts()
    BETTERUI.CIM.TryRegisterModulePanel(TradingHouse, "TradingHouse", "TradingHouse", "TradingHouse")
    BETTERUI.TradingHouse.Init()
end
