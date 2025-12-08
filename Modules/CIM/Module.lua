-- BetterUI Common Interface Module (CIM)
-- Provides shared UI components: scroll lists, headers, tooltips

local _
local LAM = LibAddonMenu2

-- Initialize CIM default settings
--- @param m_options table: Options table to initialize
--- @return table: Initialized options
function BETTERUI.CIM.InitModule(m_options)
    if m_options["triggerSpeed"] == nil then m_options["triggerSpeed"] = 10 end
    if m_options["enhanceCompat"] == nil then m_options["enhanceCompat"] = false end
    if m_options["rhScrollSpeed"] == nil then m_options["rhScrollSpeed"] = 50 end
    if m_options["tooltipSize"] == nil then m_options["tooltipSize"] = 24 end
    return m_options
end
