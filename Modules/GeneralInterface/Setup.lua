if BETTERUI.GeneralInterface == nil then BETTERUI.GeneralInterface = {} end

local GeneralInterface = BETTERUI.GeneralInterface
GeneralInterface.Settings = GeneralInterface.Settings or {}

local function GetCurrentSceneName()
	if SCENE_MANAGER and type(SCENE_MANAGER.GetCurrentSceneName) == "function" then
		local ok, sceneName = pcall(function() return SCENE_MANAGER:GetCurrentSceneName() end)
		if ok then return sceneName end
	end
	return nil
end

local function TraceGeneralInterface(event, phase, data, category)
	local L = BETTERUI and BETTERUI.Log or nil
	if not L or type(L.TraceEvent) ~= "function" then return end
	local payload = data or {}
	payload.module = "GeneralInterface"
	payload.scene = GetCurrentSceneName()
	payload.gamepad = IsInGamepadPreferredMode and IsInGamepadPreferredMode() or nil
	if type(L.SetLastAction) == "function" then
		L.SetLastAction(event)
	end
	local categories = L.CATEGORY or {}
	L.TraceEvent(category or categories.GENERAL, event, phase, payload)
end

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
	local function HookMailDeleteDescriptor(mailInbox)
		if type(mailInbox) ~= "table" or type(mailInbox.mainKeybindDescriptor) ~= "table" then
			return false
		end

		for _, descriptor in ipairs(mailInbox.mainKeybindDescriptor) do
			if type(descriptor) == "table" and descriptor.keybind == "UI_SHORTCUT_SECONDARY" then
				local origCallback = descriptor.callback
				if type(origCallback) ~= "function" or descriptor._betteruiDeleteHookInstalled then
					return descriptor._betteruiDeleteHookInstalled == true
				end

				descriptor.callback = function(...)
					local moduleSettings = BETTERUI.GetModuleSettings("GeneralInterface")
					if moduleSettings and moduleSettings.removeDeleteDialog and type(mailInbox.Delete) == "function" then
						TraceGeneralInterface("general_interface.mail_delete", "keybind_fired", { fn = "mailDeleteDescriptor.callback", shortcut = descriptor.keybind, directDelete = true })
						return mailInbox:Delete()
					end
					TraceGeneralInterface("general_interface.mail_delete", "keybind_fired", { fn = "mailDeleteDescriptor.callback", shortcut = descriptor.keybind, directDelete = false })
					return origCallback(...)
				end
				descriptor._betteruiDeleteHookInstalled = true
				TraceGeneralInterface("general_interface.mail_delete", "hook_installed", { fn = "HookMailDeleteDescriptor", shortcut = descriptor.keybind })
				return true
			end
		end

		return false
	end

	local function InstallOnLiveMailInbox(mailInbox)
		if type(mailInbox) ~= "table" then
			return false
		end

		if type(mailInbox.InitializeKeybindDescriptors) == "function" and not mailInbox._betteruiDeleteDescriptorPreHookInstalled then
			ZO_PreHook(mailInbox, "InitializeKeybindDescriptors", function(self)
				TraceGeneralInterface("general_interface.mail_delete", "descriptor_rebuilt", { fn = "InitializeKeybindDescriptors" })
				HookMailDeleteDescriptor(self)
			end)
			mailInbox._betteruiDeleteDescriptorPreHookInstalled = true
			TraceGeneralInterface("general_interface.mail_delete", "prehook_installed", { fn = "InstallOnLiveMailInbox", method = "InitializeKeybindDescriptors" })
		end

		return HookMailDeleteDescriptor(mailInbox)
	end

	if InstallOnLiveMailInbox(rawget(_G, "MAIL_INBOX_GAMEPAD")) then
		return
	end

	InstallOnLiveMailInbox(rawget(_G, "ZO_MailInbox_Gamepad"))
end

local function InstallInventoryTooltipHooks(tooltipHelpers)
	if not (tooltipHelpers
		and type(tooltipHelpers.InventoryHook) == "function"
		and type(tooltipHelpers.CreateInventoryHookConfig) == "function") then
		TraceGeneralInterface("general_interface.inventory_tooltip_hooks", "skipped", { fn = "InstallInventoryTooltipHooks", reason = "missingHelpers" })
		return
	end
	if not GAMEPAD_TOOLTIPS or type(GAMEPAD_TOOLTIPS.GetTooltip) ~= "function" then
		TraceGeneralInterface("general_interface.inventory_tooltip_hooks", "skipped", { fn = "InstallInventoryTooltipHooks", reason = "missingGamepadTooltips" })
		return
	end

	local tooltipTypes = { GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP, GAMEPAD_MOVABLE_TOOLTIP }
	for _, tooltipType in ipairs(tooltipTypes) do
		local tooltipControl = GAMEPAD_TOOLTIPS:GetTooltip(tooltipType)
		tooltipHelpers.InventoryHook(tooltipHelpers.CreateInventoryHookConfig(tooltipControl, tooltipType))
		TraceGeneralInterface("general_interface.inventory_tooltip_hooks", "hook_requested", { fn = "InstallInventoryTooltipHooks", tooltipType = tooltipType, hasControl = tooltipControl ~= nil })
	end
end

local function InstallStoreTooltipHooks()
	if not GAMEPAD_TOOLTIPS or type(GAMEPAD_TOOLTIPS.GetTooltip) ~= "function" then
		TraceGeneralInterface("general_interface.store_tooltip_hooks", "skipped", { fn = "InstallStoreTooltipHooks", reason = "missingGamepadTooltips" })
		return
	end
	local storeTooltipTypes = { GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP, GAMEPAD_MOVABLE_TOOLTIP }
	for _, tooltipType in ipairs(storeTooltipTypes) do
		local tooltipControl = GAMEPAD_TOOLTIPS:GetTooltip(tooltipType)
		if tooltipControl and tooltipControl.LayoutStoreWindowItem and not tooltipControl._betteruiStoreLayoutHookInstalled then
			ZO_PreHook(tooltipControl, "LayoutStoreWindowItem", function(self, itemData, ...)
				if itemData and itemData.itemLink then
					self._betterui_itemLink = itemData.itemLink
				end
				self._betterui_storeStackCount = (itemData and (itemData.stackCount or itemData.stack or itemData.quantity)) or 1
				TraceGeneralInterface("general_interface.store_tooltip", "layout_begin", { fn = "LayoutStoreWindowItem", tooltipType = tooltipType, itemLink = itemData and itemData.itemLink or nil, stackCount = self._betterui_storeStackCount })
			end)
			TraceGeneralInterface("general_interface.store_tooltip_hooks", "prehook_installed", { fn = "InstallStoreTooltipHooks", method = "LayoutStoreWindowItem", tooltipType = tooltipType, target = type(tooltipControl) })
			ZO_PostHook(tooltipControl, "LayoutStoreWindowItem", function(self, itemData, ...)
				TraceGeneralInterface("general_interface.store_tooltip", "layout_end", { fn = "LayoutStoreWindowItem", tooltipType = tooltipType, itemLink = self._betterui_itemLink, stackCount = self._betterui_storeStackCount })
				self._betterui_bagId = nil
				self._betterui_slotIndex = nil
			end)
			TraceGeneralInterface("general_interface.store_tooltip_hooks", "posthook_installed", { fn = "InstallStoreTooltipHooks", method = "LayoutStoreWindowItem", tooltipType = tooltipType, target = type(tooltipControl) })
			tooltipControl._betteruiStoreLayoutHookInstalled = true
		else
			TraceGeneralInterface("general_interface.store_tooltip_hooks", "hook_skipped", { fn = "InstallStoreTooltipHooks", tooltipType = tooltipType, reason = tooltipControl and "alreadyInstalledOrMissingMethod" or "missingTooltipControl" })
		end
	end
end

-- Resolve the rendering-side scene gate so suppression and rendering share ONE
-- source of truth. When BetterUI's enhancement will NOT render in the current
-- context (an "incompatible" scene such as the housing furniture browser), the
-- suppression hook must NOT fire — otherwise native top-section content (the
-- set-collection Collected/Uncollected line, bound/stolen/stack-count lines) is
-- stripped and any other addon's earlier-registered PreHook is blocked, in a
-- context where BetterUI renders nothing to replace it. Mirrors the LayoutItem /
-- equipped-text hooks in Tooltips.lua. (Compat fix; do not regress PB-004.)
local function ShouldSuppressNativeTopLines()
	local settings = BETTERUI.GetModuleSettings("CIM")
	local enhancementsEnabled = settings and settings.enableTooltipEnhancements ~= false
	if not enhancementsEnabled then
		TraceGeneralInterface("general_interface.top_lines", "suppression_decision", { fn = "ShouldSuppressNativeTopLines", suppress = false, reason = "enhancementsDisabled" })
		return false
	end
	local tooltipHelpers = GeneralInterface.Tooltips
	local sceneGate = tooltipHelpers and tooltipHelpers.IsIncompatibleSceneActive
	if type(sceneGate) == "function" and sceneGate() then
		-- Enhancement is enabled but will not render in this scene; let native
		-- top-lines and other addons' hooks run.
		TraceGeneralInterface("general_interface.top_lines", "suppression_decision", { fn = "ShouldSuppressNativeTopLines", suppress = false, reason = "incompatibleScene" })
		return false
	end
	TraceGeneralInterface("general_interface.top_lines", "suppression_decision", { fn = "ShouldSuppressNativeTopLines", suppress = true })
	return true
end

local function InstallTopLineSuppressionHooks()
	if not GAMEPAD_TOOLTIPS or type(GAMEPAD_TOOLTIPS.GetTooltip) ~= "function" then
		TraceGeneralInterface("general_interface.top_line_hooks", "skipped", { fn = "InstallTopLineSuppressionHooks", reason = "missingGamepadTooltips" })
		return
	end
	local tooltipTypes = { GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP, GAMEPAD_MOVABLE_TOOLTIP }
	for _, tooltipType in ipairs(tooltipTypes) do
		local tooltipControl = GAMEPAD_TOOLTIPS:GetTooltip(tooltipType)
		if tooltipControl and tooltipControl.AddTopLinesToTopSection and not tooltipControl._betteruiTopLinesHookInstalled then
			ZO_PreHook(tooltipControl, "AddTopLinesToTopSection", function(self, topSection, itemLink, showPlayerLocked, tradeBoPData)
				if ShouldSuppressNativeTopLines() then
					local topSubsection = topSection:AcquireSection(self:GetStyle("topSubsectionItemDetails"))
					topSection:AddSectionEvenIfEmpty(topSubsection)
					TraceGeneralInterface("general_interface.top_lines", "suppressed", { fn = "AddTopLinesToTopSection", tooltipType = tooltipType, itemLink = itemLink, showPlayerLocked = showPlayerLocked, hasTradeBoPData = tradeBoPData ~= nil })
					return true
				end
				TraceGeneralInterface("general_interface.top_lines", "native_allowed", { fn = "AddTopLinesToTopSection", tooltipType = tooltipType, itemLink = itemLink, showPlayerLocked = showPlayerLocked, hasTradeBoPData = tradeBoPData ~= nil })
				return false
			end)
			TraceGeneralInterface("general_interface.top_line_hooks", "prehook_installed", { fn = "InstallTopLineSuppressionHooks", method = "AddTopLinesToTopSection", tooltipType = tooltipType, target = type(tooltipControl) })
			tooltipControl._betteruiTopLinesHookInstalled = true
		else
			TraceGeneralInterface("general_interface.top_line_hooks", "hook_skipped", { fn = "InstallTopLineSuppressionHooks", tooltipType = tooltipType, reason = tooltipControl and "alreadyInstalledOrMissingMethod" or "missingTooltipControl" })
		end
	end
end

local function RegisterGuildStoreSuppression(tooltipHelpers)
	local scene = SCENE_MANAGER and SCENE_MANAGER.scenes and SCENE_MANAGER.scenes['gamepad_trading_house']
	if not scene then
		TraceGeneralInterface("general_interface.guild_store_suppression", "skipped", { fn = "RegisterGuildStoreSuppression", reason = "missingScene", scene = "gamepad_trading_house" })
		return
	end

	-- IMPORTANT: never touch the global "ErrorFrame" EVENT_LUA_ERROR registration.
	-- Unregistering it would permanently disable Lua error display game-wide
	-- (ZOS registers it once with a callback we cannot restore). Suppression is
	-- handled entirely through the addon-local SetGuildStoreErrorSuppressed flag.
	scene:RegisterCallback("StateChange", function(oldState, newState)
		if not (tooltipHelpers and type(tooltipHelpers.SetGuildStoreErrorSuppressed) == "function") then
			TraceGeneralInterface("general_interface.guild_store_suppression", "state_skipped", { fn = "StateChange", reason = "missingHelper", oldState = oldState, newState = newState })
			return
		end
		if newState == SCENE_SHOWING then
			local moduleSettings = BETTERUI.GetModuleSettings("GeneralInterface")
			if moduleSettings and moduleSettings.guildStoreErrorSuppress then
				tooltipHelpers.SetGuildStoreErrorSuppressed(true)
				TraceGeneralInterface("general_interface.guild_store_suppression", "state_changed", { fn = "StateChange", oldState = oldState, newState = newState, suppressed = true })
			else
				TraceGeneralInterface("general_interface.guild_store_suppression", "state_changed", { fn = "StateChange", oldState = oldState, newState = newState, suppressed = false, reason = "settingDisabled" })
			end
		elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
			-- Always clear on hide so suppression cannot leak past the scene
			-- (even if the setting was toggled off while the scene was showing).
			tooltipHelpers.SetGuildStoreErrorSuppressed(false)
			TraceGeneralInterface("general_interface.guild_store_suppression", "state_changed", { fn = "StateChange", oldState = oldState, newState = newState, suppressed = false })
		end
	end)
	TraceGeneralInterface("general_interface.guild_store_suppression", "registered", { fn = "RegisterGuildStoreSuppression", scene = "gamepad_trading_house" })
end

local function RegisterTooltipCacheInvalidation()
	local function invalidateCacheOnUpdate(_, bagId)
		if type(GeneralInterface.InvalidateResearchableTraitCache) == "function" then
			GeneralInterface.InvalidateResearchableTraitCache(bagId)
			TraceGeneralInterface("general_interface.tooltip_cache", "invalidated", { fn = "invalidateCacheOnUpdate", bagId = bagId })
		else
			TraceGeneralInterface("general_interface.tooltip_cache", "invalidate_skipped", { fn = "invalidateCacheOnUpdate", reason = "missingInvalidateFunction", bagId = bagId })
		end
	end

	BETTERUI.EventManager:RegisterForEvent("BETTERUI_Tooltips_InvSingle", EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
		invalidateCacheOnUpdate)
	BETTERUI.EventManager:RegisterForEvent("BETTERUI_Tooltips_InvFull", EVENT_INVENTORY_FULL_UPDATE,
		invalidateCacheOnUpdate)
	TraceGeneralInterface("general_interface.tooltip_cache", "events_registered", { fn = "RegisterTooltipCacheInvalidation" })
end

-- U50: the old ZO_ChatWindowTemplate1Buffer instance name no longer exists.
-- Chat buffers are reached through the chat systems' container/window objects.
function GeneralInterface.ApplyChatHistoryLimit(numLines)
	numLines = tonumber(numLines)
	if not numLines or numLines < 1 then
		TraceGeneralInterface("general_interface.chat_history", "skipped", { fn = "ApplyChatHistoryLimit", reason = "invalidLineCount", numLines = numLines })
		return
	end
	local chatSystems = { KEYBOARD_CHAT_SYSTEM, GAMEPAD_CHAT_SYSTEM }
	local appliedWindows = 0
	for i = 1, #chatSystems do
		local chatSystem = chatSystems[i]
		local containers = chatSystem and chatSystem.containers
		if containers then
			for _, container in ipairs(containers) do
				for _, window in ipairs(container.windows or {}) do
					if window.buffer and window.buffer.SetMaxHistoryLines then
						window.buffer:SetMaxHistoryLines(numLines)
						appliedWindows = appliedWindows + 1
					end
				end
			end
		end
	end
	TraceGeneralInterface("general_interface.chat_history", "applied", { fn = "ApplyChatHistoryLimit", numLines = numLines, windows = appliedWindows })
end

local function ApplyChatHistoryLimit()
	local settings = BETTERUI.GetModuleSettings("GeneralInterface")
	TraceGeneralInterface("general_interface.chat_history", "apply_from_settings", { fn = "ApplyChatHistoryLimit", numLines = settings and settings.chatHistory or 200 })
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
	TraceGeneralInterface("general_interface.setup", "begin", { fn = "Setup" })
	BETTERUI.CIM.RegisterModulePanelWithLogging(GeneralInterface, "GeneralInterface", "General", "General Interface")

	-- Only apply hooks/logic when the GeneralInterface module toggle is enabled.
	if not BETTERUI.GetModuleEnabled("GeneralInterface") then
		TraceGeneralInterface("general_interface.setup", "skipped", { fn = "Setup", reason = "moduleDisabled" })
		return
	end

	-- Do not override ZO_IsIngameUI here.
	-- Replacing shared global helpers can taint protected gamepad callstacks.

	InstallMailDeleteHook()

	local tooltipHelpers = GeneralInterface.Tooltips
	if tooltipHelpers and type(tooltipHelpers.InitializeRuntime) == "function" then
		tooltipHelpers.InitializeRuntime()
		TraceGeneralInterface("general_interface.tooltip_runtime", "initialized", { fn = "Setup" })
	else
		TraceGeneralInterface("general_interface.tooltip_runtime", "skipped", { fn = "Setup", reason = "missingInitializeRuntime" })
	end
	InstallInventoryTooltipHooks(tooltipHelpers)
	InstallStoreTooltipHooks()
	InstallTopLineSuppressionHooks()
	RegisterGuildStoreSuppression(tooltipHelpers)
	RegisterTooltipCacheInvalidation()
	ApplyChatHistoryLimit()
	TraceGeneralInterface("general_interface.setup", "end", { fn = "Setup" })
end
