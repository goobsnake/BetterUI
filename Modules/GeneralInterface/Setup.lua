-- BetterUI - General Interface Setup
--
-- Module Setup() lifecycle: builds the LAM settings panel, registers tooltip
-- hooks, and initializes Nameplates. Aggregates settings from Tooltips/ and
-- Nameplates/ subdirectories.
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
local function Init(mId, moduleName)
	local panelData = BETTERUI.Init_ModulePanel(moduleName, "General Interface Settings")

	local optionsTable = {}

	-- General Interface settings (flat section, consistent with Inventory/Banking)
	local getSettingsOpts = BETTERUI.CIM.TryResolve("GeneralInterface.GetSettingsOptions")
	if getSettingsOpts then
		table.insert(optionsTable, {
			type = "header",
			name = GetString(rawget(_G, "SI_BETTERUI_GENERAL_INTERFACE_GENERAL_HEADER")),
			width = "full",
		})
		table.insert(optionsTable, {
			type = "description",
			text = GetString(rawget(_G, "SI_BETTERUI_GENERAL_INTERFACE_GENERAL_DESC")),
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
	local getNameplateOpts = BETTERUI.CIM.TryResolve("Nameplates.GetSettingsOptions")
	if getNameplateOpts then
		table.insert(optionsTable, {
			type = "submenu",
			name = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_HEADER")),
			controls = BETTERUI.Nameplates.GetSettingsOptions()
		})
	end

	-- Alphabetize top-level submenu rows (e.g., Enhanced Nameplates / Enhanced Tooltips).
	BETTERUI.CIM.TryCall("CIM.Settings.SortTopLevelSubmenusAlphabetically", optionsTable)

	-- Alphabetize top-level General settings and all submenu settings.
	BETTERUI.CIM.TryCall("CIM.Settings.SortSettingsAlphabetically", optionsTable, true)

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
	if not BETTERUI.GetModuleEnabled("GeneralInterface") then return end

	if IsPrivateFunction('IsInUI') then
		ZO_IsIngameUI = function()
			return SCRIBING_DATA_MANAGER ~= nil
		end
	end

	-- Always hook mail delete, but check setting at runtime for live-refresh support
	BETTERUI.PostHook(ZO_MailInbox_Gamepad, 'InitializeKeybindDescriptors', function(self)
		-- Find the Delete keybind by its keybind name instead of fragile index
		for i, descriptor in ipairs(self.mainKeybindDescriptor) do
			if type(descriptor) == "table" and descriptor.keybind == "UI_SHORTCUT_SECONDARY" then
				local origCallback = descriptor["callback"]
				-- Guard: descriptor may have no callback (e.g. already patched by another addon)
				if not origCallback then break end
				descriptor["callback"] = function()
					-- Guard: settings may be nil if accessed before SavedVars load completes
					local moduleSettings = BETTERUI.GetModuleSettings("GeneralInterface")
					if moduleSettings and moduleSettings.removeDeleteDialog then
						self:Delete() -- Skip confirmation
					else
						origCallback() -- Original behavior with confirmation
					end
				end
				break
			end
		end
	end)

	BETTERUI.InventoryHook({
		tooltipControl = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP),
		tooltipType    = GAMEPAD_LEFT_TOOLTIP,
		method         = "LayoutItem",
		linkFunc       = BETTERUI.ReturnItemLink,
		method2        = "LayoutBagItem",
		linkFunc2      = BETTERUI.ReturnSelectedData,
		method3        = "LayoutGuildStoreSearchResult",
		linkFunc3      = BETTERUI.ReturnStoreSearch,
	})
	BETTERUI.InventoryHook({
		tooltipControl = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_RIGHT_TOOLTIP),
		tooltipType    = GAMEPAD_RIGHT_TOOLTIP,
		method         = "LayoutItem",
		linkFunc       = BETTERUI.ReturnItemLink,
		method2        = "LayoutBagItem",
		linkFunc2      = BETTERUI.ReturnSelectedData,
		method3        = "LayoutGuildStoreSearchResult",
		linkFunc3      = BETTERUI.ReturnStoreSearch,
	})
	BETTERUI.InventoryHook({
		tooltipControl = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_MOVABLE_TOOLTIP),
		tooltipType    = GAMEPAD_MOVABLE_TOOLTIP,
		method         = "LayoutItem",
		linkFunc       = BETTERUI.ReturnItemLink,
		method2        = "LayoutBagItem",
		linkFunc2      = BETTERUI.ReturnSelectedData,
		method3        = "LayoutGuildStoreSearchResult",
		linkFunc3      = BETTERUI.ReturnStoreSearch,
	})

	-- Hook LayoutStoreWindowItem on each tooltip control to capture item links
	-- for merchant/NPC store items. These use LayoutStoreItemFromLink → LayoutItem
	-- internally, but the item link is not passed through LayoutBagItem, so our
	-- existing hooks can't capture it. This ensures _betterui_itemLink is set
	-- before the LayoutItem wrapper fires for merchant items.
	local storeTooltipTypes = { GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP, GAMEPAD_MOVABLE_TOOLTIP }
	for _, tooltipType in ipairs(storeTooltipTypes) do
		local tooltipControl = GAMEPAD_TOOLTIPS:GetTooltip(tooltipType)
		if tooltipControl and tooltipControl.LayoutStoreWindowItem then
			local originalLayoutStore = tooltipControl.LayoutStoreWindowItem
			tooltipControl.LayoutStoreWindowItem = function(self, itemData, ...)
				-- Capture item link for regular items (collectibles/quest items
				-- don't route through LayoutItem, so they naturally skip price injection)
				if itemData and itemData.itemLink then
					self._betterui_itemLink = itemData.itemLink
				end
				self._betterui_storeStackCount = (itemData and (itemData.stackCount or itemData.stack or itemData.quantity)) or 1
				local result = originalLayoutStore(self, itemData, ...)
				-- Clear stale bag context AFTER the call: LayoutItem fires synchronously
				-- inside originalLayoutStore and re-writes stale closure bagId/slotIndex
				-- onto the tooltip. Clearing here ensures UpdateTooltipEquippedText
				-- sees nil bag context (correct for store items, which are not owned).
				self._betterui_bagId = nil
				self._betterui_slotIndex = nil
				return result
			end
		end
	end

	-- SUPPRESS NATIVE TOP-SECTION LABELS (bag/bank counts, bound, stolen, set collection)
	-- When BetterUI tooltip enhancements are enabled, our custom status label in
	-- UpdateTooltipEquippedText already displays this information.
	-- The native AddTopLinesToTopSection adds pool-managed controls that are difficult
	-- to reliably hide after-the-fact (ZO_ControlPool parents to GuiRoot, then re-parents
	-- on acquire). Instead, we prevent them from being created in the first place.
	--
	-- ZO_Tooltip:Initialize uses zo_mixin(control, ..., self) which copies
	-- all methods from ZO_Tooltip onto each control. Modifying ZO_Tooltip.AddTopLinesToTopSection
	-- after initialization won't affect already-created controls. Override the
	-- method directly on each tooltip control instance.
	local tooltipTypes = { GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP, GAMEPAD_MOVABLE_TOOLTIP }
	for _, tooltipType in ipairs(tooltipTypes) do
		local tooltipControl = GAMEPAD_TOOLTIPS:GetTooltip(tooltipType)
		if tooltipControl and tooltipControl.AddTopLinesToTopSection then
			local originalAddTopLines = tooltipControl.AddTopLinesToTopSection
			tooltipControl.AddTopLinesToTopSection = function(self, topSection, itemLink, showPlayerLocked, tradeBoPData)
				local settings = BETTERUI.GetModuleSettings("CIM")
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
			if not BETTERUI.GetModuleSettings("GeneralInterface").guildStoreErrorSuppress then
				return -- Setting disabled, no-op
			end
			if newState == SCENE_SHOWING then
				EVENT_MANAGER:UnregisterForEvent("ErrorFrame", EVENT_LUA_ERROR)
				BETTERUI.CIM._gsErrorSuppress = 1
			elseif newState == SCENE_HIDDEN then
				EVENT_MANAGER:RegisterForEvent("ErrorFrame", EVENT_LUA_ERROR)
				BETTERUI.CIM._gsErrorSuppress = 0
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
