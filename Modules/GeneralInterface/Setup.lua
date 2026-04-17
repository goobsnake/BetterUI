-- BetterUI - General Interface Setup
--
-- Module Setup() lifecycle: builds the LAM settings panel, registers tooltip
-- hooks, and initializes Nameplates. Aggregates settings from Tooltips/ and
-- Nameplates/ subdirectories.

if BETTERUI.GeneralInterface == nil then BETTERUI.GeneralInterface = {} end

local GeneralInterface = BETTERUI.GeneralInterface

local function GetGeneralInterfaceOptions()
	if type(GeneralInterface.GetSettingsOptions) ~= "function" then
		return nil
	end

	return GeneralInterface.GetSettingsOptions()
end

local function GetNameplateOptions()
	if not BETTERUI.Nameplates or type(BETTERUI.Nameplates.GetSettingsOptions) ~= "function" then
		return nil
	end

	return BETTERUI.Nameplates.GetSettingsOptions()
end

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
	local generalOptions = GetGeneralInterfaceOptions()
	if generalOptions then
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

		for _, option in ipairs(generalOptions) do
			table.insert(optionsTable, option)
		end
	end

	-- Nameplate Settings Submenu
	local nameplateOptions = GetNameplateOptions()
	if nameplateOptions then
		table.insert(optionsTable, {
			type = "submenu",
			name = GetString(rawget(_G, "SI_BETTERUI_NAMEPLATES_HEADER")),
			controls = nameplateOptions
		})
	end

	BETTERUI.CIM.Settings.RegisterModulePanel(mId, panelData, optionsTable)
end


--- Sets up the General Interface (Tooltips) module.
---
--- Purpose: Registers hooks and event handlers for tooltip enhancements.
--- Mechanics:
--- 1. Calls local `Init` to build the settings menu.
--- 2. Avoids global helper overrides to prevent protected-callstack taint.
--- 3. Hooks `ZO_MailInbox_Gamepad` to allow 'X' keybind for deletion if enabled.
--- 4. Hooks Gamepad Tooltips (`LayoutItem`, `LayoutBagItem`, etc.) to inject custom data.
--- 5. Manages Guild Store error suppression based on scene state (`gamepad_trading_house`).
--- 6. Registers inventory update events to invalidate trait caches.
--- 7. Applies chat history limit.
---
--- References: Called by the core Addon initialization.
---
---@type BetterUIModuleSetupHook
function GeneralInterface.Setup()
	Init("General", "General Interface")

	-- Only apply hooks/logic if Tooltips module is enabled
	if not BETTERUI.GetModuleEnabled("GeneralInterface") then return end

	-- Do not override ZO_IsIngameUI here.
	-- Replacing shared global helpers can taint protected gamepad callstacks.

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

	local tooltipHelpers = GeneralInterface.Tooltips
	if tooltipHelpers
		and type(tooltipHelpers.InventoryHook) == "function"
		and type(tooltipHelpers.CreateInventoryHookConfig) == "function" then
		local tooltipTypes = { GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP, GAMEPAD_MOVABLE_TOOLTIP }
		for _, tooltipType in ipairs(tooltipTypes) do
			local tooltipControl = GAMEPAD_TOOLTIPS:GetTooltip(tooltipType)
			tooltipHelpers.InventoryHook(tooltipHelpers.CreateInventoryHookConfig(tooltipControl, tooltipType))
		end
	end

	-- Hook LayoutStoreWindowItem on each tooltip control to capture item links
	-- for merchant/NPC store items. These use LayoutStoreItemFromLink → LayoutItem
	-- internally, but the item link is not passed through LayoutBagItem, so our
	-- existing hooks can't capture it. This ensures _betterui_itemLink is set
	-- before the LayoutItem wrapper fires for merchant items.
	local storeTooltipTypes = { GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP, GAMEPAD_MOVABLE_TOOLTIP }
	for _, tooltipType in ipairs(storeTooltipTypes) do
		local tooltipControl = GAMEPAD_TOOLTIPS:GetTooltip(tooltipType)
		if tooltipControl and tooltipControl.LayoutStoreWindowItem and not tooltipControl._betteruiStoreLayoutHookInstalled then
			ZO_PreHook(tooltipControl, "LayoutStoreWindowItem", function(self, itemData, ...)
				-- Capture item link for regular items (collectibles/quest items
				-- don't route through LayoutItem, so they naturally skip price injection)
				if itemData and itemData.itemLink then
					self._betterui_itemLink = itemData.itemLink
				end
				self._betterui_storeStackCount = (itemData and (itemData.stackCount or itemData.stack or itemData.quantity)) or 1
			end)
			ZO_PostHook(tooltipControl, "LayoutStoreWindowItem", function(self, itemData, ...)
				-- Clear stale bag context AFTER the call: LayoutItem fires synchronously
				-- inside LayoutStoreWindowItem and can re-write bagId/slotIndex.
				-- Clearing here keeps store item context authoritative.
				self._betterui_bagId = nil
				self._betterui_slotIndex = nil
			end)
			tooltipControl._betteruiStoreLayoutHookInstalled = true
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
	-- after initialization won't affect already-created controls. Use per-instance
	-- prehooks on each tooltip control instead of replacing shared methods.
	local tooltipTypes = { GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP, GAMEPAD_MOVABLE_TOOLTIP }
	for _, tooltipType in ipairs(tooltipTypes) do
		local tooltipControl = GAMEPAD_TOOLTIPS:GetTooltip(tooltipType)
		if tooltipControl and tooltipControl.AddTopLinesToTopSection and not tooltipControl._betteruiTopLinesHookInstalled then
			ZO_PreHook(tooltipControl, "AddTopLinesToTopSection", function(self, topSection, itemLink, showPlayerLocked, tradeBoPData)
				local settings = BETTERUI.GetModuleSettings("CIM")
				local enhancementsEnabled = settings and settings.enableTooltipEnhancements ~= false
				if enhancementsEnabled then
					-- Skip native labels — BetterUI's custom label handles them
					-- We still need to add the empty subsection to preserve tooltip layout
					local topSubsection = topSection:AcquireSection(self:GetStyle("topSubsectionItemDetails"))
					topSection:AddSectionEvenIfEmpty(topSubsection)
					return true
				end
				-- Enhancements disabled — allow native behavior.
				return false
			end)
			tooltipControl._betteruiTopLinesHookInstalled = true
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
				if tooltipHelpers and type(tooltipHelpers.SetGuildStoreErrorSuppressed) == "function" then
					tooltipHelpers.SetGuildStoreErrorSuppressed(true)
				end
			elseif newState == SCENE_HIDDEN then
				EVENT_MANAGER:RegisterForEvent("ErrorFrame", EVENT_LUA_ERROR)
				if tooltipHelpers and type(tooltipHelpers.SetGuildStoreErrorSuppressed) == "function" then
					tooltipHelpers.SetGuildStoreErrorSuppressed(false)
				end
			end
		end)
	end

	-- Invalidate researchable trait cache on inventory changes
	local function invalidateCacheOnUpdate(_, bagId)
		if type(GeneralInterface.InvalidateResearchableTraitCache) == "function" then
			GeneralInterface.InvalidateResearchableTraitCache(bagId)
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
