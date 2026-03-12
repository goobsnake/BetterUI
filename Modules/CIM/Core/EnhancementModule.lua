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

	-- General Interface settings (flat section, consistent with Inventory/Banking)
	if BETTERUI.GeneralInterface and BETTERUI.GeneralInterface.GetSettingsOptions then
		table.insert(optionsTable, {
			type = "header",
			name = GetString(SI_BETTERUI_GENERAL_INTERFACE_GENERAL_HEADER),
			width = "full",
		})
		table.insert(optionsTable, {
			type = "description",
			text = GetString(SI_BETTERUI_GENERAL_INTERFACE_GENERAL_DESC),
			width = "full",
		})

		local generalOptions = BETTERUI.GeneralInterface.GetSettingsOptions()
		if generalOptions then
			for _, option in ipairs(generalOptions) do
				table.insert(optionsTable, option)
			end
		end
	end

	-- Nameplate Settings Submenu
	if BETTERUI.Nameplates and BETTERUI.Nameplates.GetSettingsOptions then
		table.insert(optionsTable, {
			type = "submenu",
			name = GetString(SI_BETTERUI_NAMEPLATES_HEADER),
			controls = BETTERUI.Nameplates.GetSettingsOptions()
		})
	end

	-- Alphabetize top-level submenu rows (e.g., Enhanced Nameplates / Enhanced Tooltips).
	if BETTERUI.CIM and BETTERUI.CIM.Settings and BETTERUI.CIM.Settings.SortTopLevelSubmenusAlphabetically then
		BETTERUI.CIM.Settings.SortTopLevelSubmenusAlphabetically(optionsTable)
	end

	-- Alphabetize top-level General settings and all submenu settings.
	if BETTERUI.CIM and BETTERUI.CIM.Settings and BETTERUI.CIM.Settings.SortSettingsAlphabetically then
		BETTERUI.CIM.Settings.SortSettingsAlphabetically(optionsTable, true)
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
function BETTERUI.GeneralInterface.Setup()
	Init("General", "General Interface")

	-- Only apply hooks/logic if Tooltips module is enabled
	if not BETTERUI.Settings.Modules["GeneralInterface"].m_enabled then return end

	if IsPrivateFunction('IsInUI') then
		ZO_IsIngameUI = function()
			return SCRIBING_DATA_MANAGER ~= nil
		end
	end

	-- Always hook mail delete, but check setting at runtime for live-refresh support
	BETTERUI.PostHook(ZO_MailInbox_Gamepad, 'InitializeKeybindDescriptors', function(self)
		-- TODO(fragile): Hardcoded index [3] assumes Delete is always the 3rd keybind; if ZOS reorders descriptors, this hooks the wrong action. Find by keybind name instead
		local origCallback = self.mainKeybindDescriptor[3]["callback"]
		self.mainKeybindDescriptor[3]["callback"] = function()
			if BETTERUI.Settings.Modules["GeneralInterface"].removeDeleteDialog then
				self:Delete() -- Skip confirmation
			else
				origCallback() -- Original behavior with confirmation
			end
		end
	end)

	BETTERUI.InventoryHook(GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP), GAMEPAD_LEFT_TOOLTIP, "LayoutItem", BETTERUI.ReturnItemLink,
		"LayoutBagItem", BETTERUI.ReturnSelectedData, "LayoutGuildStoreSearchResult", BETTERUI.ReturnStoreSearch)
	BETTERUI.InventoryHook(GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_RIGHT_TOOLTIP), GAMEPAD_RIGHT_TOOLTIP, "LayoutItem", BETTERUI.ReturnItemLink,
		"LayoutBagItem", BETTERUI.ReturnSelectedData, "LayoutGuildStoreSearchResult", BETTERUI.ReturnStoreSearch)
	BETTERUI.InventoryHook(GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_MOVABLE_TOOLTIP), GAMEPAD_MOVABLE_TOOLTIP, "LayoutItem", BETTERUI.ReturnItemLink,
		"LayoutBagItem", BETTERUI.ReturnSelectedData, "LayoutGuildStoreSearchResult", BETTERUI.ReturnStoreSearch)

	-- SUPPRESS NATIVE TOP-SECTION LABELS (bag/bank counts, bound, stolen, set collection)
	-- When BetterUI tooltip enhancements are enabled, our custom status label in
	-- UpdateTooltipEquippedText already displays this information.
	-- The native AddTopLinesToTopSection adds pool-managed controls that are difficult
	-- to reliably hide after-the-fact (ZO_ControlPool parents to GuiRoot, then re-parents
	-- on acquire). Instead, we prevent them from being created in the first place.
	--
	-- IMPORTANT: ZO_Tooltip:Initialize uses zo_mixin(control, ..., self) which copies
	-- all methods from ZO_Tooltip onto each control. Modifying ZO_Tooltip.AddTopLinesToTopSection
	-- after initialization won't affect already-created controls. We must override the
	-- method directly on each tooltip control instance.
	local tooltipTypes = { GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP, GAMEPAD_MOVABLE_TOOLTIP }
	for _, tooltipType in ipairs(tooltipTypes) do
		local tooltipControl = GAMEPAD_TOOLTIPS:GetTooltip(tooltipType)
		if tooltipControl and tooltipControl.AddTopLinesToTopSection then
			local originalAddTopLines = tooltipControl.AddTopLinesToTopSection
			tooltipControl.AddTopLinesToTopSection = function(self, topSection, itemLink, showPlayerLocked, tradeBoPData)
				local settings = BETTERUI.Settings.Modules["CIM"]
				local enhancementsEnabled = settings and settings.enableTooltipEnhancements ~= false
				if enhancementsEnabled then
					-- Skip native labels — BetterUI's custom label handles them
					-- We still need to add the empty subsection to preserve tooltip layout
					local topSubsection = topSection:AcquireSection(self:GetStyle("topSubsectionItemDetails"))
					topSection:AddSectionEvenIfEmpty(topSubsection)
					return
				end
				-- Enhancements disabled — fall through to native behavior
				return originalAddTopLines(self, topSection, itemLink, showPlayerLocked, tradeBoPData)
			end
		end
	end

	-- Always register scene callback, check setting at runtime for live-refresh support
	local scene = SCENE_MANAGER and SCENE_MANAGER.scenes and SCENE_MANAGER.scenes['gamepad_trading_house']
	if scene then
		scene:RegisterCallback("StateChange", function(oldState, newState)
			-- Check setting at runtime to support live toggle
			if not BETTERUI.Settings.Modules["GeneralInterface"].guildStoreErrorSuppress then
				return -- Setting disabled, no-op
			end
			if newState == SCENE_SHOWING then
				EVENT_MANAGER:UnregisterForEvent("ErrorFrame", EVENT_LUA_ERROR)
				gsErrorSuppress = 1
			elseif newState == SCENE_HIDDEN then
				EVENT_MANAGER:RegisterForEvent("ErrorFrame", EVENT_LUA_ERROR)
				gsErrorSuppress = 0
			end
		end)
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

	if (ZO_ChatWindowTemplate1Buffer ~= nil) then
		ZO_ChatWindowTemplate1Buffer:SetMaxHistoryLines(BETTERUI.Settings
			.Modules["GeneralInterface"].chatHistory)
	end
end
