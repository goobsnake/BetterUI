local _
local LAM = LibAddonMenu2

local changed = false
--- Initializes the settings panel for the Banking module
--- @param mId string: Module ID for panel registration
--- @param moduleName string: Display name for the module
local function Init(mId, moduleName)
	local panelData = Init_ModulePanel(moduleName, "Banking Improvement Settings")

	local optionsTable = {
		{
			type = "checkbox",
			name = "Item Icon - Unbound Items",
			tooltip = "Show an icon after unbound items.",
			getFunc = function () return BETTERUI.Settings.Modules["Banking"].showIconUnboundItem end,
			setFunc = function (value) BETTERUI.Settings.Modules["Banking"].showIconUnboundItem = value
				changed = true end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = "Item Icon - Enchantment",
			tooltip = "Show an icon after enchanted item.",
			getFunc = function () return BETTERUI.Settings.Modules["Banking"].showIconEnchantment end,
			setFunc = function (value) BETTERUI.Settings.Modules["Banking"].showIconEnchantment = value
				changed = true end,
			width = "full",
			requiresReload = true,
		},
		{
			type = "checkbox",
			name = "Item Icon - Set Gear",
			tooltip = "Show an icon after set gears.",
			getFunc = function () return BETTERUI.Settings.Modules["Banking"].showIconSetGear end,
			setFunc = function (value) BETTERUI.Settings.Modules["Banking"].showIconSetGear = value
				changed = true end,
			width = "full",
			requiresReload = true,
		},
	}
	LAM:RegisterAddonPanel("BETTERUI_"..mId, panelData)
	LAM:RegisterOptionControls("BETTERUI_"..mId, optionsTable)
end

--- Initializes default settings for the Banking module
--- @param m_options table: The options table to initialize
--- @return table: The initialized options table
function BETTERUI.Banking.InitModule(m_options)
	m_options["showIconEnchantment"] = true
	m_options["showIconSetGear"] = true
	m_options["showIconUnboundItem"] = true
	return m_options
end

--- Sets up the Banking module by initializing settings and calling init function
function BETTERUI.Banking.Setup()

	Init("Bank", "Banking")

	BETTERUI.Banking.Init()

end
