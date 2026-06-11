if BETTERUI.GeneralInterface == nil then BETTERUI.GeneralInterface = {} end

local GeneralInterface = BETTERUI.GeneralInterface
GeneralInterface.Settings = GeneralInterface.Settings or {}

local function GetGeneralInterfaceOptions()
	if type(GeneralInterface.GetSettingsOptions) ~= "function" then
		return nil
	end

	return GeneralInterface.GetSettingsOptions()
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

	-- IMPORTANT: never touch the global "ErrorFrame" EVENT_LUA_ERROR registration.
	-- Unregistering it would permanently disable Lua error display game-wide
	-- (ZOS registers it once with a callback we cannot restore). Suppression is
	-- handled entirely through the addon-local SetGuildStoreErrorSuppressed flag.
	scene:RegisterCallback("StateChange", function(oldState, newState)
		if not (tooltipHelpers and type(tooltipHelpers.SetGuildStoreErrorSuppressed) == "function") then
			return
		end
		if newState == SCENE_SHOWING then
			local moduleSettings = BETTERUI.GetModuleSettings("GeneralInterface")
			if moduleSettings and moduleSettings.guildStoreErrorSuppress then
				tooltipHelpers.SetGuildStoreErrorSuppressed(true)
			end
		elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
			-- Always clear on hide so suppression cannot leak past the scene
			-- (even if the setting was toggled off while the scene was showing).
			tooltipHelpers.SetGuildStoreErrorSuppressed(false)
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

-- U50: the old ZO_ChatWindowTemplate1Buffer instance name no longer exists.
-- Chat buffers are reached through the chat systems' container/window objects.
function GeneralInterface.ApplyChatHistoryLimit(numLines)
	numLines = tonumber(numLines)
	if not numLines or numLines < 1 then
		return
	end
	local chatSystems = { KEYBOARD_CHAT_SYSTEM, GAMEPAD_CHAT_SYSTEM }
	for i = 1, #chatSystems do
		local chatSystem = chatSystems[i]
		local containers = chatSystem and chatSystem.containers
		if containers then
			for _, container in ipairs(containers) do
				for _, window in ipairs(container.windows or {}) do
					if window.buffer and window.buffer.SetMaxHistoryLines then
						window.buffer:SetMaxHistoryLines(numLines)
					end
				end
			end
		end
	end
end

local function ApplyChatHistoryLimit()
	local settings = BETTERUI.GetModuleSettings("GeneralInterface")
	GeneralInterface.ApplyChatHistoryLimit((settings and settings.chatHistory) or 200)
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
	BETTERUI.CIM.RegisterModulePanelWithLogging(GeneralInterface, "GeneralInterface", "General", "General Interface")

	-- Only apply hooks/logic when the GeneralInterface module toggle is enabled.
	if not BETTERUI.GetModuleEnabled("GeneralInterface") then return end

	-- Do not override ZO_IsIngameUI here.
	-- Replacing shared global helpers can taint protected gamepad callstacks.

	InstallMailDeleteHook()

	local tooltipHelpers = GeneralInterface.Tooltips
	if tooltipHelpers and type(tooltipHelpers.InitializeRuntime) == "function" then
		tooltipHelpers.InitializeRuntime()
	end
	InstallInventoryTooltipHooks(tooltipHelpers)
	InstallStoreTooltipHooks()
	InstallTopLineSuppressionHooks()
	RegisterGuildStoreSuppression(tooltipHelpers)
	RegisterTooltipCacheInvalidation()
	ApplyChatHistoryLimit()
end
