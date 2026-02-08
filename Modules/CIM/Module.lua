--[[
File: Modules/CIM/Module.lua
Purpose: Core initialization for the Common Interface Module (CIM).
         CIM provides shared UI components like generic headers, footers,
         and parametric scroll lists used across BetterUI.
Author: BetterUI Team
Last Modified: 2026-02-08
]]

local LAM = LibAddonMenu2

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

    if BETTERUI.Defaults and BETTERUI.Defaults.ApplyModuleDefaults then
        m_options = BETTERUI.Defaults.ApplyModuleDefaults("CIM", m_options)
    else
        local defaults = BETTERUI.CONST.CIM
        if m_options["triggerSpeed"] == nil then m_options["triggerSpeed"] = defaults.DEFAULT_TRIGGER_SPEED end
        if m_options["enhanceCompat"] == nil then m_options["enhanceCompat"] = false end
        if m_options["rhScrollSpeed"] == nil then m_options["rhScrollSpeed"] = defaults.DEFAULT_RH_SCROLL_SPEED end
        if m_options["tooltipSize"] == nil then m_options["tooltipSize"] = defaults.DEFAULT_TOOLTIP_SIZE end
        if m_options["enableTooltipEnhancements"] == nil then m_options["enableTooltipEnhancements"] = true end
    end

    return m_options
end
