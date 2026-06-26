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
		L.SetLastAction({ flow = event, message = tostring(event) .. ":" .. tostring(phase) })
	end
	local categories = L.CATEGORY or {}
	L.TraceEvent(category or categories.GENERAL, event, phase, payload)
end

local function CountGeneralInterfaceTooltipHooks(flagName)
	if not (GAMEPAD_TOOLTIPS and type(GAMEPAD_TOOLTIPS.GetTooltip) == "function") then
		return 0
	end
	local tooltipTypes = { GAMEPAD_LEFT_TOOLTIP, GAMEPAD_RIGHT_TOOLTIP, GAMEPAD_MOVABLE_TOOLTIP }
	local count = 0
	for i = 1, #tooltipTypes do
		local tooltipType = tooltipTypes[i]
		if tooltipType ~= nil then
			local tooltipControl = GAMEPAD_TOOLTIPS:GetTooltip(tooltipType)
			if tooltipControl and tooltipControl[flagName] == true then
				count = count + 1
			end
		end
	end
	return count
end

local function HasGeneralInterfaceMailDeleteHook(mailInbox)
	if type(mailInbox) ~= "table" or type(mailInbox.mainKeybindDescriptor) ~= "table" then
		return false
	end
	for _, descriptor in ipairs(mailInbox.mainKeybindDescriptor) do
		if type(descriptor) == "table" and descriptor.keybind == "UI_SHORTCUT_SECONDARY" then
			return descriptor._betteruiDeleteHookInstalled == true
		end
	end
	return false
end

local function DescribeRedactedMailText(value)
	if value == nil then return nil end
	if type(value) == "string" then
		return { present = value ~= "", length = #value }
	end
	return { present = true, type = type(value) }
end

local function SnapshotSelectedMail(mailInbox)
	local snapshot = {}
	local selectedData
	local list = mailInbox and (mailInbox.mailList or mailInbox.list or mailInbox.mailInboxList) or nil
	if list and type(list.GetTargetData) == "function" then
		local ok, data = pcall(function() return list:GetTargetData() end)
		if ok then selectedData = data end
	end
	local ds = selectedData and (selectedData.dataSource or selectedData) or nil
	if ds then
		local mailId = ds.mailId or ds.id or ds.mailIndex
		local sender = ds.senderDisplayName or ds.sender
		local subject = ds.subject
		snapshot.hasMailId = mailId ~= nil
		snapshot.index = ds.mailIndex or ds.index
		snapshot.sender = DescribeRedactedMailText(sender)
		snapshot.subject = DescribeRedactedMailText(subject)
		snapshot.hasAttachments = ds.hasAttachments or (type(ds.numAttachments) == "number" and ds.numAttachments > 0) or nil
		snapshot.hasCOD = type(ds.codAmount) == "number" and ds.codAmount > 0 or nil
	end
	if mailInbox and type(mailInbox.GetSelectedMailId) == "function" then
		local ok, mailId = pcall(function() return mailInbox:GetSelectedMailId() end)
		if ok and mailId ~= nil then snapshot.hasMailId = true end
	end
	return next(snapshot) and snapshot or nil
end

local function RegisterGeneralInterfaceSnapshotProvider()
	local watch = BETTERUI.CIM and BETTERUI.CIM.WatchMode
	if not (watch and watch.RegisterSnapshotProvider) then return end
	watch.RegisterSnapshotProvider("generalInterface", function()
		local settings = type(BETTERUI.GetModuleSettings) == "function" and BETTERUI.GetModuleSettings("GeneralInterface") or nil
		local cimSettings = type(BETTERUI.GetModuleSettings) == "function" and BETTERUI.GetModuleSettings("CIM") or nil
		local mailInbox = rawget(_G, "MAIL_INBOX_GAMEPAD") or rawget(_G, "ZO_MailInbox_Gamepad")
		local tooltipHelpers = GeneralInterface.Tooltips
		return string.format(
			"enabled=%s scene=%s removeDeleteDialog=%s guildStoreSuppress=%s chatHistory=%s showMarketPrice=%s marketPriority=%s craftingPrice=%s tooltipEnhancements=%s tooltipSize=%s styleTrait=%s knowledge=%s comparison=%s ttc=%s mm=%s att=%s mailHook=%s mailPrehook=%s tooltipRuntime=%s storeHooks=%s topLineHooks=%s researchCache=%s",
			tostring(type(BETTERUI.GetModuleEnabled) == "function" and BETTERUI.GetModuleEnabled("GeneralInterface") or nil),
			tostring(GetCurrentSceneName()),
			tostring(settings and settings.removeDeleteDialog == true or false),
			tostring(settings and settings.guildStoreErrorSuppress == true or false),
			tostring(settings and settings.chatHistory or nil),
			tostring(settings and settings.showMarketPrice == true or false),
			tostring(settings and settings.marketPricePriority or nil),
			tostring(settings and settings.showCraftingMarketPrice == true or false),
			tostring(cimSettings and cimSettings.enableTooltipEnhancements == true or false),
			tostring(cimSettings and cimSettings.tooltipSize or nil),
			tostring(settings and settings.showStyleTrait == true or false),
			tostring(settings and settings.showKnowledgeStatus == true or false),
			tostring(settings and settings.showItemComparison == true or false),
			tostring(settings and settings.ttcIntegration == true or false),
			tostring(settings and settings.mmIntegration == true or false),
			tostring(settings and settings.attIntegration == true or false),
			tostring(HasGeneralInterfaceMailDeleteHook(mailInbox)),
			tostring(mailInbox and mailInbox._betteruiDeleteDescriptorPreHookInstalled == true or false),
			tostring(tooltipHelpers and type(tooltipHelpers.InitializeRuntime) == "function" or false),
			tostring(CountGeneralInterfaceTooltipHooks("_betteruiStoreLayoutHookInstalled")),
			tostring(CountGeneralInterfaceTooltipHooks("_betteruiTopLinesHookInstalled")),
			tostring(type(GeneralInterface.InvalidateResearchableTraitCache) == "function"))
	end)
end

RegisterGeneralInterfaceSnapshotProvider()

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
			TraceGeneralInterface("general_interface.mail_delete", "hook_skipped", { fn = "HookMailDeleteDescriptor", reason = "missingInbox" })
			return false
		end

		for _, descriptor in ipairs(mailInbox.mainKeybindDescriptor) do
			if type(descriptor) == "table" and descriptor.keybind == "UI_SHORTCUT_SECONDARY" then
				local origCallback = descriptor.callback
				if descriptor._betteruiDeleteHookInstalled
					and origCallback == descriptor._betteruiDeleteHookCallback then
					return true
				end
				if type(origCallback) ~= "function" then
					return false
				end

				descriptor._betteruiDeleteHookOriginalCallback = origCallback
				descriptor.callback = function(...)
					local moduleSettings = BETTERUI.GetModuleSettings("GeneralInterface")
					local selectedMail = SnapshotSelectedMail(mailInbox)
					if moduleSettings and moduleSettings.removeDeleteDialog and type(mailInbox.Delete) == "function" then
						TraceGeneralInterface("general_interface.mail_delete", "keybind_fired", { fn = "mailDeleteDescriptor.callback", shortcut = descriptor.keybind, directDelete = true, selectedMail = selectedMail })
						local ok, result = pcall(function() return mailInbox:Delete() end)
						if not ok then
							TraceGeneralInterface("general_interface.mail_delete", "direct_delete_failed", { fn = "mailDeleteDescriptor.callback", shortcut = descriptor.keybind, selectedMail = selectedMail, error = tostring(result) })
							return nil
						end
						TraceGeneralInterface("general_interface.mail_delete", "direct_delete_dispatched", { fn = "mailDeleteDescriptor.callback", shortcut = descriptor.keybind, selectedMail = selectedMail, result = result })
						return result
					end
					TraceGeneralInterface("general_interface.mail_delete", "keybind_fired", { fn = "mailDeleteDescriptor.callback", shortcut = descriptor.keybind, directDelete = false, selectedMail = selectedMail })
					local ok, result = pcall(origCallback, ...)
					if not ok then
						TraceGeneralInterface("general_interface.mail_delete", "native_callback_failed", { fn = "mailDeleteDescriptor.callback", shortcut = descriptor.keybind, selectedMail = selectedMail, error = tostring(result) })
						return nil
					end
					TraceGeneralInterface("general_interface.mail_delete", "native_callback_dispatched", { fn = "mailDeleteDescriptor.callback", shortcut = descriptor.keybind, selectedMail = selectedMail, result = result })
					return result
				end
				descriptor._betteruiDeleteHookCallback = descriptor.callback
				descriptor._betteruiDeleteHookInstalled = true
				TraceGeneralInterface("general_interface.mail_delete", "hook_installed", { fn = "HookMailDeleteDescriptor", shortcut = descriptor.keybind })
				return true
			end
		end

		TraceGeneralInterface("general_interface.mail_delete", "hook_skipped", { fn = "HookMailDeleteDescriptor", reason = "missingDescriptor" })
		return false
	end

	local function InstallOnLiveMailInbox(mailInbox)
		if type(mailInbox) ~= "table" then
			return false
		end

		local hookInstaller = type(ZO_PostHook) == "function" and ZO_PostHook or ZO_PreHook
		if type(mailInbox.InitializeKeybindDescriptors) == "function"
			and hookInstaller
			and not mailInbox._betteruiDeleteDescriptorHookInstalled then
			hookInstaller(mailInbox, "InitializeKeybindDescriptors", function(self)
				TraceGeneralInterface("general_interface.mail_delete", "descriptor_rebuilt", { fn = "InitializeKeybindDescriptors" })
				HookMailDeleteDescriptor(self)
			end)
			mailInbox._betteruiDeleteDescriptorHookInstalled = true
			mailInbox._betteruiDeleteDescriptorPreHookInstalled = true
			TraceGeneralInterface("general_interface.mail_delete", "hook_installed", { fn = "InstallOnLiveMailInbox", method = "InitializeKeybindDescriptors", postHook = hookInstaller == ZO_PostHook })
		end

		return HookMailDeleteDescriptor(mailInbox)
	end

	if InstallOnLiveMailInbox(rawget(_G, "MAIL_INBOX_GAMEPAD")) then
		return
	end

	if not InstallOnLiveMailInbox(rawget(_G, "ZO_MailInbox_Gamepad")) then
		TraceGeneralInterface("general_interface.mail_delete", "hook_skipped", { fn = "InstallMailDeleteHook", reason = "missingInbox" })
		local retryCount = GeneralInterface._mailDeleteHookRetryCount or 0
		if retryCount < 5 and type(zo_callLater) == "function" and not GeneralInterface._mailDeleteHookRetryCallId then
			GeneralInterface._mailDeleteHookRetryCount = retryCount + 1
			GeneralInterface._mailDeleteHookRetryCallId = zo_callLater(function()
				GeneralInterface._mailDeleteHookRetryCallId = nil
				InstallMailDeleteHook()
			end, 1000)
			TraceGeneralInterface("general_interface.mail_delete", "retry_scheduled", {
				fn = "InstallMailDeleteHook",
				retry = GeneralInterface._mailDeleteHookRetryCount,
				delayMs = 1000,
			})
		elseif retryCount >= 5 then
			TraceGeneralInterface("general_interface.mail_delete", "retry_exhausted", { fn = "InstallMailDeleteHook", retries = retryCount })
		end
	end
end

local function InstallCraftingPriceTooltipHooks()
	local craftingPriceTooltip = GeneralInterface.Tooltips and GeneralInterface.Tooltips.CraftingPriceTooltip or nil
	if craftingPriceTooltip and type(craftingPriceTooltip.InstallHooks) == "function" then
		local installedBefore = craftingPriceTooltip.AreHooksInstalled and craftingPriceTooltip.AreHooksInstalled() == true or false
		craftingPriceTooltip.InstallHooks()
		local installedAfter = craftingPriceTooltip.AreHooksInstalled and craftingPriceTooltip.AreHooksInstalled() == true or false
		TraceGeneralInterface("general_interface.crafting_price_tooltip_hooks", "setup_retry", {
			fn = "InstallCraftingPriceTooltipHooks",
			installedBefore = installedBefore,
			installedAfter = installedAfter,
		})
	else
		TraceGeneralInterface("general_interface.crafting_price_tooltip_hooks", "skipped", {
			fn = "InstallCraftingPriceTooltipHooks",
			reason = "missingInstaller",
		})
	end
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
	local settings = BETTERUI.GetModuleSettings and BETTERUI.GetModuleSettings("CIM") or nil
	local enhancementsEnabled = true
	if type(BETTERUI.GetSetting) == "function" then
		enhancementsEnabled = BETTERUI.GetSetting("CIM", "enableTooltipEnhancements", true) ~= false
	elseif settings and settings.enableTooltipEnhancements ~= nil then
		enhancementsEnabled = settings.enableTooltipEnhancements ~= false
	end
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

	GeneralInterface._guildStoreSuppressionRegisteredScenes = GeneralInterface._guildStoreSuppressionRegisteredScenes or {}
	if GeneralInterface._guildStoreSuppressionRegisteredScenes.gamepad_trading_house then
		TraceGeneralInterface("general_interface.guild_store_suppression", "skipped", { fn = "RegisterGuildStoreSuppression", reason = "alreadyRegistered", scene = "gamepad_trading_house" })
		return
	end

	-- IMPORTANT: never touch the global "ErrorFrame" EVENT_LUA_ERROR registration.
	-- Unregistering it would permanently disable Lua error display game-wide
	-- (ZOS registers it once with a callback we cannot restore). Suppression is
	-- handled entirely through the addon-local SetGuildStoreErrorSuppressed flag.
	scene:RegisterCallback("StateChange", function(oldState, newState)
		local activeTooltipHelpers = GeneralInterface.Tooltips or tooltipHelpers
		if not (activeTooltipHelpers and type(activeTooltipHelpers.SetGuildStoreErrorSuppressed) == "function") then
			TraceGeneralInterface("general_interface.guild_store_suppression", "state_skipped", { fn = "StateChange", reason = "missingHelper", oldState = oldState, newState = newState })
			return
		end
		if newState == SCENE_SHOWING then
			local moduleSettings = BETTERUI.GetModuleSettings("GeneralInterface")
			if moduleSettings and moduleSettings.guildStoreErrorSuppress then
				activeTooltipHelpers.SetGuildStoreErrorSuppressed(true)
				TraceGeneralInterface("general_interface.guild_store_suppression", "state_changed", { fn = "StateChange", oldState = oldState, newState = newState, suppressed = true })
			else
				TraceGeneralInterface("general_interface.guild_store_suppression", "state_changed", { fn = "StateChange", oldState = oldState, newState = newState, suppressed = false, reason = "settingDisabled" })
			end
		elseif newState == SCENE_HIDING or newState == SCENE_HIDDEN then
			-- Always clear on hide so suppression cannot leak past the scene
			-- (even if the setting was toggled off while the scene was showing).
			activeTooltipHelpers.SetGuildStoreErrorSuppressed(false)
			TraceGeneralInterface("general_interface.guild_store_suppression", "state_changed", { fn = "StateChange", oldState = oldState, newState = newState, suppressed = false })
		end
	end)
	GeneralInterface._guildStoreSuppressionRegisteredScenes.gamepad_trading_house = true
	TraceGeneralInterface("general_interface.guild_store_suppression", "registered", { fn = "RegisterGuildStoreSuppression", scene = "gamepad_trading_house" })
end

local function RegisterTooltipCacheInvalidation()
	if GeneralInterface._tooltipCacheInvalidationRegistered then
		TraceGeneralInterface("general_interface.tooltip_cache", "events_skipped", { fn = "RegisterTooltipCacheInvalidation", reason = "alreadyRegistered" })
		return
	end
	if not (BETTERUI.EventManager and type(BETTERUI.EventManager.RegisterForEvent) == "function") then
		TraceGeneralInterface("general_interface.tooltip_cache", "events_skipped", { fn = "RegisterTooltipCacheInvalidation", reason = "missingEventManager" })
		return
	end

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
	GeneralInterface._tooltipCacheInvalidationRegistered = true
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
	local chatSystems = {
		{ name = "keyboard", system = rawget(_G, "KEYBOARD_CHAT_SYSTEM") },
		{ name = "gamepad", system = rawget(_G, "GAMEPAD_CHAT_SYSTEM") },
	}
	local appliedWindows = 0
	for i = 1, #chatSystems do
		local chatSystem = chatSystems[i].system
		local ok, containers = pcall(function() return chatSystem and chatSystem.containers or nil end)
		if not ok then
			TraceGeneralInterface("general_interface.chat_history", "system_skipped", {
				fn = "ApplyChatHistoryLimit",
				index = i,
				system = chatSystems[i].name,
				reason = "containerReadError",
				error = tostring(containers),
			})
			containers = nil
		end
		if containers then
			for _, container in ipairs(containers) do
				for _, window in ipairs(container.windows or {}) do
					local buffer = window and window.buffer or nil
					if buffer and buffer.SetMaxHistoryLines then
						local setOk, setErr = pcall(function() buffer:SetMaxHistoryLines(numLines) end)
						if setOk then
							appliedWindows = appliedWindows + 1
						else
							TraceGeneralInterface("general_interface.chat_history", "window_skipped", {
								fn = "ApplyChatHistoryLimit",
								index = i,
								system = chatSystems[i].name,
								reason = "setFailed",
								error = tostring(setErr),
							})
						end
					end
				end
			end
		else
			TraceGeneralInterface("general_interface.chat_history", "system_skipped", { fn = "ApplyChatHistoryLimit", index = i, system = chatSystems[i].name, reason = "missingChatSystem" })
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
	InstallCraftingPriceTooltipHooks()
	RegisterGuildStoreSuppression(tooltipHelpers)
	RegisterTooltipCacheInvalidation()
	ApplyChatHistoryLimit()
	TraceGeneralInterface("general_interface.setup", "end", { fn = "Setup" })
end
