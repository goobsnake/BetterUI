--[[
File: Modules/CIM/Module.lua
Purpose: Core initialization for the Common Interface Module (CIM).
         CIM provides shared UI components like generic headers, footers,
         and parametric scroll lists used across BetterUI.
]]

local ClampInteger = BETTERUI.ClampInteger

---@param m_options table|nil Raw settings table to initialize
---@return table Modified options with defaults applied
function BETTERUI.CIM.InitModule(m_options)
    m_options = m_options or {}
    local defaults = BETTERUI.CIM.CONST.DEFAULTS

    local ok, result = BETTERUI.CIM.TryCall("Defaults.ApplyModuleDefaults", "CIM", m_options)
    if ok then
        m_options = result
    else
        if m_options["enhanceCompat"] == nil then m_options["enhanceCompat"] = false end
        if m_options["rhScrollSpeed"] == nil then m_options["rhScrollSpeed"] = defaults.DEFAULT_RH_SCROLL_SPEED end
        if m_options["tooltipSize"] == nil then m_options["tooltipSize"] = defaults.DEFAULT_TOOLTIP_SIZE end
        if m_options["enableTooltipEnhancements"] == nil then m_options["enableTooltipEnhancements"] = true end
    end

    local minFontSize = BETTERUI.CIM.TryResolve("CIM.Font.SIZE_MIN") or 12
    local maxFontSize = BETTERUI.CIM.TryResolve("CIM.Font.SIZE_MAX") or 48
    m_options["rhScrollSpeed"] = ClampInteger(m_options["rhScrollSpeed"], 1, 1000, defaults.DEFAULT_RH_SCROLL_SPEED)
    m_options["tooltipSize"] = ClampInteger(m_options["tooltipSize"], minFontSize, maxFontSize, defaults.DEFAULT_TOOLTIP_SIZE)

    return m_options
end
