-- BetterUI Writ Unit Module
-- Displays daily writ progress at crafting stations

local _

-- Initializes Writs default settings
function BETTERUI.Writs.InitModule(m_options)
    return m_options
end

-- Event: Crafting station interaction started
local function OnCraftStation(eventCode, craftId, sameStation)
	if eventCode ~= 0 then -- 0 is an invalid code
			BETTERUI.Writs.Show(tonumber(craftId))
	end
end

-- Event: Crafting station interaction ended
local function OnCloseCraftStation(eventCode)
	BETTERUI.Writs.Hide()
end

-- Event: Item crafted
local function OnCraftItem(eventCode, craftId)
	if eventCode ~= 0 then -- 0 is an invalid code
			BETTERUI.Writs.Show(tonumber(craftId))
	end
end

-- Sets up Writs module: creates UI and registers event handlers
function BETTERUI.Writs.Setup()
	local tlw = BETTERUI.WindowManager:CreateTopLevelWindow("BETTERUI_TLW")
	local BETTERUI_WP = BETTERUI.WindowManager:CreateControlFromVirtual("BETTERUI_WritsPanel",tlw,"BETTERUI_WritsPanel")

	EVENT_MANAGER:RegisterForEvent(BETTERUI.name, EVENT_CRAFTING_STATION_INTERACT, OnCraftStation)
	EVENT_MANAGER:RegisterForEvent(BETTERUI.name, EVENT_END_CRAFTING_STATION_INTERACT, OnCloseCraftStation)
	EVENT_MANAGER:RegisterForEvent(BETTERUI.name, EVENT_CRAFT_COMPLETED, OnCraftItem)

	BETTERUI_WP:SetHidden(true)
end