---------------------------------------------------------------------------------------------------
-- BetterUI - CIM Enhancement Module
--
-- This module acts as the central configuration hub for various CIM enhancements (formerly General Interface).
-- It integrates with LibAddonMenu to provide settings for:
-- 1. Tooltips: Font size, MasterMerchant/TTC integration, and mail deletion confirmation.
-- 2. Nameplates: Enabling/disabling, font customization, and style adjustments.
-- 3. Resource Orb Frames: Configuration for the custom resource orb UI (Health/Magicka/Stamina).
--
-- ARCHITECTURE:
--   This file defines the settings panel structure using LAM (LibAddonMenu2).
--   Actual functionality is implemented in separate files:
--     - Tooltips.lua: Tooltip enhancement logic
--     - Nameplates.lua: Nameplate font customization
--     - ResourceOrbFrames.lua: Orb UI implementation
--     - TooltipSettings.lua & NameplateSettings.lua: Configuration definitions
--
---------------------------------------------------------------------------------------------------

local _
local LAM = LibAddonMenu2

if BETTERUI.GeneralInterface == nil then BETTERUI.GeneralInterface = {} end


--- Initializes the settings panel for General Interface options.
---
--- Purpose: Creates a LibAddonMenu panel with all configurable options.
--- Mechanics:
--- - Aggregates settings from separate settings files.
--- - Defines `optionsTable` with checkboxes, sliders, and submenus.
--- - Uses `LAM:RegisterAddonPanel` and `LAM:RegisterOptionControls`.
---
--- References: Called during module setup.
---
--- @param mId string The Module ID (unused, for standardized module signature)
--- @param moduleName string The display name of the module for the settings panel
local function Init(mId, moduleName)
	local panelData = BETTERUI.Init_ModulePanel(moduleName, "General Interface Settings")

	local optionsTable = {}

	-- Tooltip Settings Submenu
	if BETTERUI.GeneralInterface and BETTERUI.GeneralInterface.GetSettingsOptions then
		table.insert(optionsTable, {
			type = "submenu",
			name = "General",
			controls = BETTERUI.GeneralInterface.GetSettingsOptions()
		})
	end

	-- Nameplate Settings Submenu
	if BETTERUI.Nameplates and BETTERUI.Nameplates.GetSettingsOptions then
		table.insert(optionsTable, {
			type = "submenu",
			name = GetString(SI_BETTERUI_NAMEPLATES_HEADER),
			controls = BETTERUI.Nameplates.GetSettingsOptions()
		})
	end

	LAM:RegisterAddonPanel("BETTERUI_" .. mId, panelData)
	LAM:RegisterOptionControls("BETTERUI_" .. mId, optionsTable)
end


--- Sets up the General Interface (Tooltips) module.
---
--- Purpose: Registers hooks and event handlers for tooltip enhancements.
--- Mechanics:
--- 1. Calls local `Init` to build the settings menu.
--- 2. Defines `ZO_IsIngameUI` polyfill if missing (for Scribing).
--- 3. Hooks `ZO_MailInbox_Gamepad` to allow 'X' keybind for deletion if enabled.
--- 4. Hooks Gamepad Tooltips (`LayoutItem`, `LayoutBagItem`, etc.) to inject custom data.
--- 5. Manages Guild Store error suppression based on scene state (`gamepad_trading_house`).
--- 6. Registers inventory update events to invalidate trait caches.
--- 7. Applies chat history limit.
---
--- References: Called by the core Addon initialization.
---
--- @param m_options table The options table to initialize (unused here, handled by InitModule).
--- @return table The initialized options table.
function BETTERUI.GeneralInterface.Setup()
	Init("General", "General Interface")

	-- Only apply hooks/logic if Tooltips module is enabled
	if not BETTERUI.Settings.Modules["GeneralInterface"].m_enabled then return end

	if IsPrivateFunction('IsInUI') then
		ZO_IsIngameUI = function()
			return SCRIBING_DATA_MANAGER ~= nil
		end
	end

	if BETTERUI.Settings.Modules["GeneralInterface"].removeDeleteDialog then
		BETTERUI.PostHook(ZO_MailInbox_Gamepad, 'InitializeKeybindDescriptors', function(self)
			self.mainKeybindDescriptor[3]["callback"] = function() self:Delete() end
		end)
	end

	BETTERUI.InventoryHook(GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP), "LayoutItem", BETTERUI.ReturnItemLink,
		"LayoutBagItem", BETTERUI.ReturnSelectedData, "LayoutGuildStoreSearchResult", BETTERUI.ReturnStoreSearch)
	BETTERUI.InventoryHook(GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_RIGHT_TOOLTIP), "LayoutItem", BETTERUI.ReturnItemLink,
		"LayoutBagItem", BETTERUI.ReturnSelectedData, "LayoutGuildStoreSearchResult", BETTERUI.ReturnStoreSearch)
	BETTERUI.InventoryHook(GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_MOVABLE_TOOLTIP), "LayoutItem", BETTERUI.ReturnItemLink,
		"LayoutBagItem", BETTERUI.ReturnSelectedData, "LayoutGuildStoreSearchResult", BETTERUI.ReturnStoreSearch)



	-- Move guild store error suppression to scene lifecycle to avoid frequent toggling during tooltip draws
	if BETTERUI.Settings.Modules["GeneralInterface"].guildStoreErrorSuppress then
		local scene = SCENE_MANAGER and SCENE_MANAGER.scenes and SCENE_MANAGER.scenes['gamepad_trading_house']
		if scene then
			scene:RegisterCallback("StateChange", function(oldState, newState)
				if newState == SCENE_SHOWING then
					EVENT_MANAGER:UnregisterForEvent("ErrorFrame", EVENT_LUA_ERROR)
					gsErrorSuppress = 1
				elseif newState == SCENE_HIDDEN then
					EVENT_MANAGER:RegisterForEvent("ErrorFrame", EVENT_LUA_ERROR)
					gsErrorSuppress = 0
				end
			end)
		end
	end

	-- Invalidate researchable trait cache on inventory changes
	local function invalidateCacheOnUpdate(_, bagId)
		if BETTERUI and BETTERUI.GeneralInterface and BETTERUI.GeneralInterface.InvalidateResearchableTraitCache then
			BETTERUI.GeneralInterface.InvalidateResearchableTraitCache(bagId)
		end
	end

	BETTERUI.EventManager:RegisterForEvent("BETTERUI_Tooltips_InvSingle", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
		invalidateCacheOnUpdate)
	BETTERUI.EventManager:RegisterForEvent("BETTERUI_Tooltips_InvFull", EVENT_INVENTORY_FULL_UPDATE,
		invalidateCacheOnUpdate)

	if (ZO_ChatWindowTemplate1Buffer ~= nil) then ZO_ChatWindowTemplate1Buffer:SetMaxHistoryLines(BETTERUI.Settings
		.Modules["GeneralInterface"].chatHistory) end
end
