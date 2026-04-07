--[[
File: Modules/TradingHouse/Module.lua
Purpose: Entry point and settings configuration for the Trading House module.

Registers the TradingHouse panel in the BetterUI addon settings and provides
font descriptor factories for the name and column rendering.
]]

-- Module initialization
BETTERUI.TradingHouse = BETTERUI.TradingHouse or {}

-- Wire standard font aliases, font descriptors, and GetSetting/SetSetting accessors
BETTERUI.CIM.RegisterModuleAccessors("TradingHouse")

-- Initializes defaults and migrates legacy settings for the TradingHouse module.
-- Called by BETTERUI.ModuleOptions() via pcall with m_options.
---@param m_options table|nil Module options from saved variables
---@return table m_options Initialized options with defaults applied
function BETTERUI.TradingHouse.InitModule(m_options)
    m_options = m_options or {}
    ---@cast m_options table
    local defaults = BETTERUI.TradingHouse.DEFAULTS
    local fallbackDefaults = {
        showIconEnchantment = true,
        showIconSetGear = true,
        showIconUnboundItem = true,
        showIconResearchableTrait = true,
        showIconUnknownRecipe = true,
        showIconUnknownBook = true,
        enableCarousel = true,
    }

    m_options = BETTERUI.CIM.InitModuleDefaults("TradingHouse", m_options, defaults, fallbackDefaults)
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
    BETTERUI.TradingHouse.Settings.RegisterPanel("TradingHouse", "TradingHouse")
    BETTERUI.TradingHouse.Init()
end
