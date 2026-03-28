--[[
File: Modules/Inventory/Scene/InventorySceneLifecycle.lua
Purpose: Scene state change handler for the Inventory module.
         Manages SHOWING, HIDING, and HIDDEN lifecycle transitions.
]]

-- Constants (must match Inventory.lua)
local INVENTORY_CATEGORY_LIST = "categoryList"
local INVENTORY_ITEM_LIST = "itemList"

--- Handles scene state changes (SHOWING, HIDING, HIDDEN).
--- Purpose: Manages initialization deferral, visualization layers, list activation, and state cleanup.
function BETTERUI.Inventory.Class:OnStateChanged(oldState, newState)
	if newState == SCENE_SHOWING then
		self:PerformDeferredInitialize()
		BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.WIDTH)

		-- Mark when scene showed so we can skip redundant category refreshes during initial load
		self._sceneShowedTime = GetFrameTimeSeconds and GetFrameTimeSeconds() or 0

		-- Invalidate slot data cache so RefreshItemList gets fresh data from SHARED_INVENTORY.
		-- While the scene was hidden, the _inventoryUpdateCallback is unregistered, so any
		-- inventory changes (e.g., container consumption during looting) won't have
		-- invalidated the cache. This ensures consumed items are removed on return.
		self:InvalidateSlotDataCache()

		--figure out which list to land on
		local listToActivate = self.previousListType or INVENTORY_CATEGORY_LIST
		-- We normally do not want to enter the gamepad inventory on the item list
		-- the exception is if we are coming back to the inventory, like from looting a container
		local wasOnStack = SCENE_MANAGER:WasSceneOnStack(ZO_GAMEPAD_INVENTORY_SCENE_NAME)
		-- Also detect brief scene detours (container loot, enchanting, etc.) via time-based check
		local timeSinceHidden = GetFrameTimeSeconds and (GetFrameTimeSeconds() - (self._sceneHiddenTime or 0)) or 999
		local isBriefDetour = (timeSinceHidden < 2.0)
		if
			listToActivate == INVENTORY_ITEM_LIST and not wasOnStack and not isBriefDetour
		then
			listToActivate = INVENTORY_CATEGORY_LIST
		end

		-- switching the active list will handle activating/refreshing header, keybinds, etc.
		-- Position restoration is handled by SwitchActiveList via savedInventoryCategoryKey
		-- and savedInventoryPositionsByKey (saved in SCENE_HIDING).
		self:SwitchActiveList(listToActivate)

		self:ActivateHeader()

		-- CRITICAL: Explicitly activate the current list to ensure DIRECTIONAL_INPUT is claimed.
		-- Banking does this explicitly (self.list:Activate()) while Inventory relied on implicit
		-- activation through SwitchActiveList. The implicit path has conditions that may not fire
		-- (e.g., if IsHeaderActive() returns true from stale state after reloadui).
		-- This explicit activation ensures the joystick works properly on initial load.
		local currentList = self:GetCurrentList()
		if currentList and currentList.Activate then
			currentList:Activate()
		end

		BETTERUI.CIM.Utils.SetExternalToolbarHidden(true)

		ZO_InventorySlot_SetUpdateCallback(function()
			self:RefreshItemActions()
		end)

		-- Register for item preview refresh callbacks (native ESO feature)
		if ITEM_PREVIEW_GAMEPAD then
			if not self.onItemPreviewRefreshActionsCallback then
				self.onItemPreviewRefreshActionsCallback = function()
					self:RefreshItemActions()
				end
			end
			ITEM_PREVIEW_GAMEPAD:RegisterCallback("RefreshActions", self.onItemPreviewRefreshActionsCallback)
		end

		-- Register SHARED_INVENTORY callbacks for scene lifecycle (prevent memory leaks)
		-- Callbacks are unregistered in SCENE_HIDDEN and re-registered here on subsequent shows
		-- Skip on first show (already registered in PerformDeferredInitialize)
		if self._inventoryUpdateCallback and self._inventoryCallbacksUnregistered then
			SHARED_INVENTORY:RegisterCallback("FullInventoryUpdate", self._inventoryUpdateCallback)
			SHARED_INVENTORY:RegisterCallback("SingleSlotInventoryUpdate", self._inventoryUpdateCallback)
			SHARED_INVENTORY:RegisterCallback("SingleQuestUpdate", self._inventoryUpdateCallback)
			self._inventoryCallbacksUnregistered = false
		end

		self.currentPreviewBagId = nil
		self.currentPreviewSlotIndex = nil
		-- search is handled via hold callbacks on X/Y; no separate A-based keybind group required
	elseif newState == SCENE_HIDING then
		ZO_InventorySlot_SetUpdateCallback(nil)
		if self:IsBatchProcessing() then
			self:RequestBatchAbort()
		end
		self:Deactivate()
		self:DeactivateHeader()

		BETTERUI.CIM.Utils.SetExternalToolbarHidden(false)

		if self.callLaterLeftToolTip ~= nil then
			EVENT_MANAGER:UnregisterForUpdate(self.callLaterLeftToolTip)
			self.callLaterLeftToolTip = nil
		end
		-- search hold behavior is part of main keybind descriptors; nothing to remove here
		-- Save the current list position so it can be restored when the scene is shown again
		self:SaveListPosition()
	elseif newState == SCENE_HIDDEN then
		-- Use shared CIM cleanup for input state (header sort, selection mode, search focus, tab bar)
		BETTERUI.CIM.SceneCleanup.CleanupInputState(self)

		-- Deactivate all lists to release DIRECTIONAL_INPUT
		-- Note: Inventory has multiple lists (itemList, craftBagList, categoryList)
		BETTERUI.CIM.SceneCleanup.DeactivateLists(self, self.itemList, self.craftBagList, self.categoryList)

		local savedListType = self.currentListType
		self:SwitchActiveList(nil)
		-- Always preserve previousListType so returning from brief scene detours
		-- (container loot, enchanting, etc.) restores to the correct list.
		self.previousListType = savedListType
		-- Track when scene was hidden for time-based brief-detour detection
		self._sceneHiddenTime = GetFrameTimeSeconds and GetFrameTimeSeconds() or 0
		BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.ZO_WIDTH)

		self.listWaitingOnDestroyRequest = nil
		BETTERUI.Inventory.NewItemTracker.CommitPendingClears()

		self:ClearActiveKeybinds()

		-- Unregister item preview callbacks
		if ITEM_PREVIEW_GAMEPAD and self.onItemPreviewRefreshActionsCallback then
			ITEM_PREVIEW_GAMEPAD:UnregisterCallback("RefreshActions", self.onItemPreviewRefreshActionsCallback)
		end

		-- Unregister SHARED_INVENTORY callbacks to prevent memory leaks
		if self._inventoryUpdateCallback then
			SHARED_INVENTORY:UnregisterCallback("FullInventoryUpdate", self._inventoryUpdateCallback)
			SHARED_INVENTORY:UnregisterCallback("SingleSlotInventoryUpdate", self._inventoryUpdateCallback)
			SHARED_INVENTORY:UnregisterCallback("SingleQuestUpdate", self._inventoryUpdateCallback)
			self._inventoryCallbacksUnregistered = true
		end

		ZO_SavePlayerConsoleProfile()

		BETTERUI.CIM.Utils.SetExternalToolbarHidden(false)

		if self.callLaterLeftToolTip ~= nil then
			EVENT_MANAGER:UnregisterForUpdate(self.callLaterLeftToolTip)
			self.callLaterLeftToolTip = nil
		end

		-- Clear search state using shared helper
		BETTERUI.CIM.SceneCleanup.ClearSearchState(self)

		-- Save the current list position so it can be restored when the scene is shown again
		self:SaveListPosition()
	end
end
