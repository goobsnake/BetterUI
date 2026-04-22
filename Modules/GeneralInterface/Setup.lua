if BETTERUI.GeneralInterface == nil then BETTERUI.GeneralInterface = {} end

local GeneralInterface = BETTERUI.GeneralInterface
GeneralInterface.Settings = GeneralInterface.Settings or {}

local function GetGeneralInterfaceOptions()
	if type(GeneralInterface.GetSettingsOptions) ~= "function" then
		return nil
	end

	return GeneralInterface.GetSettingsOptions()
end

local function GetNameplateOptions()
	local nameplates = BETTERUI.Nameplates
	if not nameplates or type(nameplates.GetSettingsOptions) ~= "function" then
		return nil
	end

	return nameplates.GetSettingsOptions()
end

local function Init(mId, moduleName)
	local panelData = BETTERUI.Init_ModulePanel(moduleName, "General Interface Settings")

	local optionsTable = {}

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

GeneralInterface.Settings.RegisterPanel = Init

local function InstallMailDeleteHook()
	BETTERUI.PostHook(ZO_MailInbox_Gamepad, 'InitializeKeybindDescriptors', function(self)
		for i, descriptor in ipairs(self.mainKeybindDescriptor) do
			if type(descriptor) == "table" and descriptor.keybind == "UI_SHORTCUT_SECONDARY" then
				local origCallback = descriptor["callback"]
				if not origCallback then break end
				descriptor["callback"] = function()
					local moduleSettings = BETTERUI.GetModuleSettings("GeneralInterface")
					if moduleSettings and moduleSettings.removeDeleteDialog then
						self:Delete()
					else
						origCallback()
					end
				end
				break
			end
		end
	end)
end

local function InstallInventoryTooltipHooks(tooltipHelpers)
	if not (tooltipHelpers
		and type(tooltipHelpers.InventoryHook) == "function"
		and type(tooltipHelpers.CreateInventoryHookConfig) == "function") then
		return
	end

	local tooltipTypes = { GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP, GAMEPAD_MOVABLE_TOOLTIP }
	for _, tooltipType in ipairs(tooltipTypes) do
		local tooltipControl = GAMEPAD_TOOLTIPS:GetTooltip(tooltipType)
		tooltipHelpers.InventoryHook(tooltipHelpers.CreateInventoryHookConfig(tooltipControl, tooltipType))
	end
end

local function InstallStoreTooltipHooks()
	local storeTooltipTypes = { GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP, GAMEPAD_MOVABLE_TOOLTIP }
	for _, tooltipType in ipairs(storeTooltipTypes) do
		local tooltipControl = GAMEPAD_TOOLTIPS:GetTooltip(tooltipType)
		if tooltipControl and tooltipControl.LayoutStoreWindowItem and not tooltipControl._betteruiStoreLayoutHookInstalled then
			ZO_PreHook(tooltipControl, "LayoutStoreWindowItem", function(self, itemData, ...)
				if itemData and itemData.itemLink then
					self._betterui_itemLink = itemData.itemLink
				end
				self._betterui_storeStackCount = (itemData and (itemData.stackCount or itemData.stack or itemData.quantity)) or 1
			end)
			ZO_PostHook(tooltipControl, "LayoutStoreWindowItem", function(self, itemData, ...)
				self._betterui_bagId = nil
				self._betterui_slotIndex = nil
			end)
			tooltipControl._betteruiStoreLayoutHookInstalled = true
		end
	end
end

local function InstallTopLineSuppressionHooks()
	local tooltipTypes = { GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP, GAMEPAD_MOVABLE_TOOLTIP }
	for _, tooltipType in ipairs(tooltipTypes) do
		local tooltipControl = GAMEPAD_TOOLTIPS:GetTooltip(tooltipType)
		if tooltipControl and tooltipControl.AddTopLinesToTopSection and not tooltipControl._betteruiTopLinesHookInstalled then
			ZO_PreHook(tooltipControl, "AddTopLinesToTopSection", function(self, topSection, itemLink, showPlayerLocked, tradeBoPData)
				local settings = BETTERUI.GetModuleSettings("CIM")
				local enhancementsEnabled = settings and settings.enableTooltipEnhancements ~= false
				if enhancementsEnabled then
					local topSubsection = topSection:AcquireSection(self:GetStyle("topSubsectionItemDetails"))
					topSection:AddSectionEvenIfEmpty(topSubsection)
					return true
				end
				return false
			end)
			tooltipControl._betteruiTopLinesHookInstalled = true
		end
	end
end

local function RegisterGuildStoreSuppression(tooltipHelpers)
	local scene = SCENE_MANAGER and SCENE_MANAGER.scenes and SCENE_MANAGER.scenes['gamepad_trading_house']
	if not scene then
		return
	end

	scene:RegisterCallback("StateChange", function(oldState, newState)
		if not BETTERUI.GetModuleSettings("GeneralInterface").guildStoreErrorSuppress then
			return
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

local function RegisterTooltipCacheInvalidation()
	local function invalidateCacheOnUpdate(_, bagId)
		if type(GeneralInterface.InvalidateResearchableTraitCache) == "function" then
			GeneralInterface.InvalidateResearchableTraitCache(bagId)
		end
	end

	BETTERUI.EventManager:RegisterForEvent("BETTERUI_Tooltips_InvSingle", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
		invalidateCacheOnUpdate)
	BETTERUI.EventManager:RegisterForEvent("BETTERUI_Tooltips_InvFull", EVENT_INVENTORY_FULL_UPDATE,
		invalidateCacheOnUpdate)
end

local function ApplyChatHistoryLimit()
	if ZO_ChatWindowTemplate1Buffer ~= nil then
		ZO_ChatWindowTemplate1Buffer:SetMaxHistoryLines(BETTERUI.Settings
			.Modules["GeneralInterface"].chatHistory)
	end
end

GeneralInterface._SetupInstallers = {
	InitPanel = Init,
	InstallMailDeleteHook = InstallMailDeleteHook,
	InstallInventoryTooltipHooks = InstallInventoryTooltipHooks,
	InstallStoreTooltipHooks = InstallStoreTooltipHooks,
	InstallTopLineSuppressionHooks = InstallTopLineSuppressionHooks,
	RegisterGuildStoreSuppression = RegisterGuildStoreSuppression,
	RegisterTooltipCacheInvalidation = RegisterTooltipCacheInvalidation,
	ApplyChatHistoryLimit = ApplyChatHistoryLimit,
}


---@type BetterUIModuleSetupHook
function GeneralInterface.Setup()
	BETTERUI.CIM.TryRegisterModulePanel(GeneralInterface, "GeneralInterface", "General", "General Interface")

	-- Only apply hooks/logic if Tooltips module is enabled
	if not BETTERUI.GetModuleEnabled("GeneralInterface") then return end

	-- Do not override ZO_IsIngameUI here.
	-- Replacing shared global helpers can taint protected gamepad callstacks.

	InstallMailDeleteHook()

	local tooltipHelpers = GeneralInterface.Tooltips
	InstallInventoryTooltipHooks(tooltipHelpers)
	InstallStoreTooltipHooks()
	InstallTopLineSuppressionHooks()
	RegisterGuildStoreSuppression(tooltipHelpers)
	RegisterTooltipCacheInvalidation()
	ApplyChatHistoryLimit()
end
