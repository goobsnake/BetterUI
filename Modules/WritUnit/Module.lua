---------------------------------------------------------------------------------------------------
-- BetterUI - Writ Module
--
-- This module displays daily writ progress when the user interacts with a crafting station.
-- It listens for crafting events and updates a custom UI panel with the current writ requirements.
--
-- TODO(enhancement): Add setting to enable/disable writ panel display
-- TODO(cleanup): Event handlers check eventCode != 0 but ESO events don't return 0 - verify necessity
---------------------------------------------------------------------------------------------------

local _

-- Initializes Writs default settings
--- Initializes the Writs module settings.
--- Currently a passthrough as there are no specific settings for this module yet.
--- @param m_options table The module options table.
--- @return table The initialized options table.
function BETTERUI.Writs.InitModule(m_options)
    return m_options
end

-- Event: Crafting station interaction started
--- Event handler for crafting station interaction (Start).
--- Shows the Writ panel if the interaction is valid.
--- @param eventCode number The event code.
--- @param craftId number The crafting station ID.
--- @param sameStation boolean Whether the user is interacting with the same station type.
local function OnCraftStation(eventCode, craftId, sameStation)
	if eventCode ~= 0 then -- 0 is an invalid code
			BETTERUI.Writs.Show(tonumber(craftId))
	end
end

-- Event: Crafting station interaction ended
--- Event handler for crafting station interaction (End).
--- Hides the Writ panel.
--- @param eventCode number The event code.
local function OnCloseCraftStation(eventCode)
	BETTERUI.Writs.Hide()
end

-- Event: Item crafted
--- Event handler for crafting completion.
--- Refreshes the Writ panel to show updated progress.
--- @param eventCode number The event code.
--- @param craftId number The crafting ID (usually matching the station type).
local function OnCraftItem(eventCode, craftId)
	if eventCode ~= 0 then -- 0 is an invalid code
			BETTERUI.Writs.Show(tonumber(craftId))
	end
end

-- Sets up Writs module: creates UI and registers event handlers
--- Sets up the Writs module.
--- Creates the top-level window and registers event listeners for crafting interactions.
function BETTERUI.Writs.Setup()
	local tlw = BETTERUI.WindowManager:CreateTopLevelWindow("BETTERUI_TLW")
	local BETTERUI_WP = BETTERUI.WindowManager:CreateControlFromVirtual("BETTERUI_WritsPanel",tlw,"BETTERUI_WritsPanel")

	EVENT_MANAGER:RegisterForEvent(BETTERUI.name, EVENT_CRAFTING_STATION_INTERACT, OnCraftStation)
	EVENT_MANAGER:RegisterForEvent(BETTERUI.name, EVENT_END_CRAFTING_STATION_INTERACT, OnCloseCraftStation)
	EVENT_MANAGER:RegisterForEvent(BETTERUI.name, EVENT_CRAFT_COMPLETED, OnCraftItem)

	BETTERUI_WP:SetHidden(true)
end