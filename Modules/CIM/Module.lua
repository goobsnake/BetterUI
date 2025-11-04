local _
local LAM = LibAddonMenu2

--- Initializes default settings for the Common Interface Module
--- @param m_options table: The options table to initialize
--- @return table: The initialized options table
function BETTERUI.CIM.InitModule(m_options)
	m_options["triggerSpeed"] = 10
	m_options["enhanceCompat"] = false
	m_options["skinSize"] = "Default"
	m_options["rhScrollSpeed"] = 50
	m_options["tooltipSize"] = "Default"
	return m_options
end
