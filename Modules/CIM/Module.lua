-- BetterUI Common Interface Module (CIM)
-- Provides shared UI components: scroll lists, headers, tooltips

local _
local LAM = LibAddonMenu2

--- Initializes default settings for the Common Interface Module (CIM).
--- Purpose: Defines defaults for trigger sensitivity, loop speeds, and compatibility.
--- @param m_options table The options table to initialize.
--- @return table The initialized options table.
function BETTERUI.CIM.InitModule(m_options)
    if m_options["triggerSpeed"] == nil then m_options["triggerSpeed"] = 10 end
    if m_options["enhanceCompat"] == nil then m_options["enhanceCompat"] = false end
    if m_options["rhScrollSpeed"] == nil then m_options["rhScrollSpeed"] = 50 end
    if m_options["tooltipSize"] == nil then m_options["tooltipSize"] = 24 end
    return m_options
end
