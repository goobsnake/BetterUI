--[[
File: Modules/CIM/Module.lua
Purpose: Core initialization for the Common Interface Module (CIM).
         CIM provides shared UI components like generic headers, footers,
         and parametric scroll lists used across BetterUI.
Author: BetterUI Team
Last Modified: 2026-02-08
]]

local LAM = LibAddonMenu2

local function ClampInteger(value, minValue, maxValue, fallback)
    local numeric = tonumber(value)
    if not numeric then
        return fallback
    end

    local rounded = math.floor(numeric + 0.5)
    if rounded < minValue then
        return minValue
    end
    if rounded > maxValue then
        return maxValue
    end
    return rounded
end

--[[
Function: BETTERUI.CIM.InitModule
Description: Initializes default settings for the Common Interface Module.
Rationale: Ensures all critical configuration values exist before the module is used.
Mechanism: Checks for nil values in the provided options table and assigns defaults.
param: m_options (table) - The raw settings/options table to be initialized.
return: table - The modified options table with default values applied.
References: Called by BetterUI.lua during addon initialization.
]]
function BETTERUI.CIM.InitModule(m_options)
    m_options = m_options or {}
    local defaults = BETTERUI.CONST.CIM

    if BETTERUI.Defaults and BETTERUI.Defaults.ApplyModuleDefaults then
        m_options = BETTERUI.Defaults.ApplyModuleDefaults("CIM", m_options)
    else
        if m_options["enhanceCompat"] == nil then m_options["enhanceCompat"] = false end
        if m_options["rhScrollSpeed"] == nil then m_options["rhScrollSpeed"] = defaults.DEFAULT_RH_SCROLL_SPEED end
        if m_options["tooltipSize"] == nil then m_options["tooltipSize"] = defaults.DEFAULT_TOOLTIP_SIZE end
        if m_options["enableTooltipEnhancements"] == nil then m_options["enableTooltipEnhancements"] = true end
    end

    local minFontSize = (BETTERUI.CIM and BETTERUI.CIM.Font and BETTERUI.CIM.Font.SIZE_MIN) or 12
    local maxFontSize = (BETTERUI.CIM and BETTERUI.CIM.Font and BETTERUI.CIM.Font.SIZE_MAX) or 48
    m_options["rhScrollSpeed"] = ClampInteger(m_options["rhScrollSpeed"], 1, 1000, defaults.DEFAULT_RH_SCROLL_SPEED)
    m_options["tooltipSize"] = ClampInteger(m_options["tooltipSize"], minFontSize, maxFontSize, defaults.DEFAULT_TOOLTIP_SIZE)

    return m_options
end
