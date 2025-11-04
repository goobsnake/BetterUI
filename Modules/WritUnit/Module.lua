local _
local LAM = LibAddonMenu2

--- Initializes the settings panel for the WritUnit module
--- @param mId string: Module ID for panel registration
--- @param moduleName string: Display name for the module
local function Init(mId, moduleName)
	local panelData = Init_ModulePanel(moduleName, "Writ Settings")

	LAM:RegisterAddonPanel("BETTERUI_"..mId, panelData)
	LAM:RegisterOptionControls("BETTERUI_"..mId, optionsTable)
end

--- Initializes default settings for the Writs module
--- @param m_options table: The options table to initialize
--- @return table: The initialized options table
function BETTERUI.Writs.InitModule(m_options)
    return m_options
end

--- Event handler for when a crafting station is interacted with
--- @param eventCode number: The event code
--- @param craftId number: The craft ID
--- @param sameStation boolean: Whether it's the same station
local function OnCraftStation(eventCode, craftId, sameStation)
	if eventCode ~= 0 then -- 0 is an invalid code
			BETTERUI.Writs.Show(tonumber(craftId))
	end
end

--- Event handler for when a crafting station interaction ends
--- @param eventCode number: The event code
local function OnCloseCraftStation(eventCode)
	BETTERUI.Writs.Hide()
end

--- Event handler for when an item is crafted
--- @param eventCode number: The event code
--- @param craftId number: The craft ID
local function OnCraftItem(eventCode, craftId)
	if eventCode ~= 0 then -- 0 is an invalid code
			BETTERUI.Writs.Show(tonumber(craftId))
	end
end

--- Sets up the Writs module by creating UI elements and registering event handlers
function BETTERUI.Writs.Setup()
	local tlw = BETTERUI.WindowManager:CreateTopLevelWindow("BETTERUI_TLW")
	local BETTERUI_WP = BETTERUI.WindowManager:CreateControlFromVirtual("BETTERUI_WritsPanel",tlw,"BETTERUI_WritsPanel")

	EVENT_MANAGER:RegisterForEvent(BETTERUI.name, EVENT_CRAFTING_STATION_INTERACT, OnCraftStation)
	EVENT_MANAGER:RegisterForEvent(BETTERUI.name, EVENT_END_CRAFTING_STATION_INTERACT, OnCloseCraftStation)
	EVENT_MANAGER:RegisterForEvent(BETTERUI.name, EVENT_CRAFT_COMPLETED, OnCraftItem)

	BETTERUI_WP:SetHidden(true)
end