-- BetterUI Common Interface Module (CIM)
-- Provides shared UI components: scroll lists, headers, tooltips

local _
local LAM = LibAddonMenu2

-- Initialize CIM default settings
--- @param m_options table: Options table to initialize
--- @return table: Initialized options
function BETTERUI.CIM.InitModule(m_options)
	m_options["triggerSpeed"] = 10
	m_options["enhanceCompat"] = false
	m_options["rhScrollSpeed"] = 50
	m_options["tooltipSize"] = "Default"
	return m_options
end
