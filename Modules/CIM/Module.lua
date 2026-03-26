--[[
File: Modules/CIM/Module.lua
Purpose: Core initialization for the Common Interface Module (CIM).
         CIM provides shared UI components like generic headers, footers,
         and parametric scroll lists used across BetterUI.
Author: BetterUI Team
Last Modified: 2026-02-08
]]

local LAM = LibAddonMenu2

-- Import shared utility (canonical definition in SettingsAccessor.lua)
local ClampInteger = BETTERUI.ClampInteger

--- Initializes default settings for the Common Interface Module.
---
--- Purpose: Callback for module initialization.
--- Mechanics: Applies default values for CIM-specific settings.
--- References: Called by BetterUI.lua during addon initialization.
---
--- @param m_options table|nil The raw settings/options table to be initialized.
--- @return table The modified options table with default values applied.
function BETTERUI.CIM.InitModule(m_options)
    m_options = m_options or {}
    local defaults = BETTERUI.CIM.CONST.DEFAULTS

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
