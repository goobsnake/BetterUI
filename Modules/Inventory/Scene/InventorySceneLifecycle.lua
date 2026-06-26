--[[
File: Modules/Inventory/Scene/InventorySceneLifecycle.lua
Purpose: Scene state change handler for the Inventory module.
         Manages SHOWING, HIDING, and HIDDEN lifecycle transitions.
]]

local function GetInventoryListTypes()
	local inventoryConstants = BETTERUI.Inventory and BETTERUI.Inventory.CONST
	assert(inventoryConstants and inventoryConstants.LIST_TYPES,
		"InventorySceneLifecycle requires BETTERUI.Inventory.CONST.LIST_TYPES")
	return inventoryConstants.LIST_TYPES
end

local function GetInventoryListType(key)
	return GetInventoryListTypes()[key]
end

---@param listType string|nil
---@param fallback string|nil
---@return string|nil
local function NormalizeInventoryListType(listType, fallback)
	local inventoryCategoryList = GetInventoryListType("CATEGORY")
	local inventoryItemList = GetInventoryListType("ITEM")
	local inventoryCraftBagList = GetInventoryListType("CRAFT_BAG")
	if listType == inventoryCategoryList
		or listType == inventoryItemList
		or listType == inventoryCraftBagList then
		return listType
	end
	return fallback
end

local function RegisterSharedInventoryCallback(callbackName, callback)
	if not (SHARED_INVENTORY and callbackName and callback and SHARED_INVENTORY.RegisterCallback) then
		return
	end
	if SHARED_INVENTORY.UnregisterCallback then
		SHARED_INVENTORY:UnregisterCallback(callbackName, callback)
	end
	SHARED_INVENTORY:RegisterCallback(callbackName, callback)
end

local function RegisterItemPreviewCallback(callbackName, callback)
	if not (ITEM_PREVIEW_GAMEPAD and callbackName and callback and ITEM_PREVIEW_GAMEPAD.RegisterCallback) then
		return
	end
	if ITEM_PREVIEW_GAMEPAD.UnregisterCallback then
		ITEM_PREVIEW_GAMEPAD:UnregisterCallback(callbackName, callback)
	end
	ITEM_PREVIEW_GAMEPAD:RegisterCallback(callbackName, callback)
end

local function IsKeybindGroupPresent(group)
	return BETTERUI.Interface.HasKeybindGroup(group)
end

local function DescribeKeybindGroup(group, label)
	local L = BETTERUI.Log
	return L and L.DescribeKeybindDescriptor and L.DescribeKeybindDescriptor(group, label) or tostring(group)
end

local function TraceInventoryKeybindOwnership(self, phase, data, warn)
	local L = BETTERUI.Log
	if not L then return end
	data = data or {}
	data.fn = data.fn or "InventorySceneLifecycle"
	data.scene = ZO_GAMEPAD_INVENTORY_SCENE_NAME
	data.currentScene = SCENE_MANAGER and SCENE_MANAGER.GetCurrentSceneName and SCENE_MANAGER:GetCurrentSceneName() or nil
	data.nextScene = SCENE_MANAGER and SCENE_MANAGER.GetNextScene and SCENE_MANAGER:GetNextScene() or nil
	data.main = DescribeKeybindGroup(self and self.mainKeybindStripDescriptor, "main")
	data.active = DescribeKeybindGroup(self and self.activeKeybindDescriptor, "active")
	data.search = DescribeKeybindGroup(self and self.textSearchKeybindStripDescriptor, "search")
	data.stripHasMain = IsKeybindGroupPresent(self and self.mainKeybindStripDescriptor)
	data.stripHasActive = IsKeybindGroupPresent(self and self.activeKeybindDescriptor)
	data.stripHasSearch = IsKeybindGroupPresent(self and self.textSearchKeybindStripDescriptor)
	if L.TraceEvent then
		L.TraceEvent(L.CATEGORY.KEYBIND, "inventory.keybind_ownership", phase, data)
	elseif warn and L.Warn then
		L.Warn(L.CATEGORY.KEYBIND, "inventory keybind ownership warning", data)
	elseif L.Debug then
		L.Debug(L.CATEGORY.KEYBIND, "inventory keybind ownership", data)
	end
	if warn and L.Warn then
		L.Warn(L.CATEGORY.KEYBIND, "inventory keybind ownership warning", data)
	end
end

local function RemoveInventoryKeybindGroup(self, group, label, phase)
	if not group then
		return false
	end
	local beforePresent = IsKeybindGroupPresent(group)
	if beforePresent then
		BETTERUI.Interface.RemoveKeybindGroupIfPresent(group)
	end
	local afterPresent = IsKeybindGroupPresent(group)
	TraceInventoryKeybindOwnership(self, phase, {
		descriptorLabel = label,
		descriptor = DescribeKeybindGroup(group, label),
		beforePresent = beforePresent,
		afterPresent = afterPresent,
		removed = beforePresent and not afterPresent,
	}, afterPresent)
	return beforePresent and not afterPresent
end

local function IsInventoryInstanceShowing(instance)
	if not instance then return false end
	if instance.IsSceneShowing then
		local ok, showing = pcall(instance.IsSceneShowing, instance)
		return ok and showing == true
	end
	if instance.scene and instance.scene.IsShowing then
		local ok, showing = pcall(instance.scene.IsShowing, instance.scene)
		return ok and showing == true
	end
	return false
end

local function EnsureInventorySlotUpdateHook(instance)
	local inventory = BETTERUI.Inventory
	if not inventory then return false end
	inventory._slotUpdateHookInstance = instance
	if inventory._slotUpdateHookInstalled then
		return true
	end
	if type(ZO_PostHook) ~= "function" then
		if BETTERUI.Log and BETTERUI.Log.Warn then
			BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.LIFECYCLE, "inventory slot update hook skipped", {
				fn = "InventorySceneLifecycle.EnsureInventorySlotUpdateHook",
				reason = "missing ZO_PostHook",
			})
		end
		return false
	end

	ZO_PostHook("UpdateMouseoverCommand", function()
		local activeInventory = BETTERUI.Inventory and BETTERUI.Inventory._slotUpdateHookInstance or nil
		if activeInventory and activeInventory.RefreshItemActions and IsInventoryInstanceShowing(activeInventory) then
			activeInventory:RefreshItemActions()
		end
	end)
	inventory._slotUpdateHookInstalled = true
	return true
end

local function RemoveInventoryKeybindsForSceneExit(self, phase)
	TraceInventoryKeybindOwnership(self, phase .. "_before", {})
	local integration = self and self._headerSortIntegration
	if integration and integration.activeKeybindDescriptor then
		RemoveInventoryKeybindGroup(self, integration.activeKeybindDescriptor, "header", phase .. "_header")
		integration.activeKeybindDescriptor = nil
	end
	if self then
		RemoveInventoryKeybindGroup(self, self.activeKeybindDescriptor, "active", phase .. "_active")
		RemoveInventoryKeybindGroup(self, self.mainKeybindStripDescriptor, "main", phase .. "_main")
		RemoveInventoryKeybindGroup(self, self.textSearchKeybindStripDescriptor, "search", phase .. "_search")
		self.activeKeybindDescriptor = nil
		self._searchModeActive = false
	end
	TraceInventoryKeybindOwnership(self, phase .. "_after", {})
end

local function OnSceneShowing(self)
	local inventoryCategoryList = GetInventoryListType("CATEGORY")
	local inventoryItemList = GetInventoryListType("ITEM")

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
	local listToActivate = NormalizeInventoryListType(self.previousListType, inventoryCategoryList)
	-- We normally do not want to enter the gamepad inventory on the item list
	-- the exception is if we are coming back to the inventory, like from looting a container
	local wasOnStack = SCENE_MANAGER:WasSceneOnStack(ZO_GAMEPAD_INVENTORY_SCENE_NAME)
	-- Also detect brief scene detours (container loot, enchanting, etc.) via time-based check
	local timeSinceHidden = GetFrameTimeSeconds and (GetFrameTimeSeconds() - (self._sceneHiddenTime or 0)) or 999
	local isBriefDetour = (timeSinceHidden < 2.0)
	-- On a fresh open (not returning via the scene stack, not a brief detour such as
	-- container loot / enchanting), land on the category list rather than restoring the
	-- previously-active ITEM or CRAFT_BAG list. Previously only the item list was
	-- corrected, so reopening while the craft bag was last active wrongly reopened the
	-- craft bag instead of the category view.
	local inventoryCraftBagList = GetInventoryListType("CRAFT_BAG")
	if not wasOnStack and not isBriefDetour
		and (listToActivate == inventoryItemList or listToActivate == inventoryCraftBagList)
	then
		listToActivate = inventoryCategoryList
	end

	if BETTERUI.Log then
		BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SCENE, "inventory show", {
			prevList = self.previousListType,
			currentList = listToActivate,
			onStack = wasOnStack == true,
		})
	end

	-- switching the active list will handle activating/refreshing header, keybinds, etc.
	-- Position restoration is handled by SwitchActiveList via savedInventoryCategoryKey
	-- and savedInventoryPositionsByKey (saved in SCENE_HIDING).
	self:SwitchActiveList(listToActivate)

	self:ActivateHeader()

	-- Explicitly activate the current list to ensure DIRECTIONAL_INPUT is claimed.
	-- Banking does this explicitly (self.list:Activate()) while Inventory relied on implicit
	-- activation through SwitchActiveList. The implicit path has conditions that may not fire
	-- (e.g., if IsHeaderActive() returns true from stale state after reloadui).
	local currentList = self:GetCurrentList()
	if currentList and currentList.Activate then
		currentList:Activate()
		-- Refresh item actions AFTER the list is active. ZO_GamepadInventory:RefreshItemActions
		-- only sets the selected slot when GetCurrentList():IsActive() is true; SwitchActiveList
		-- ran it earlier while the list was still inactive, so the A/X/Y item-action keybinds
		-- would otherwise stay hidden until the cursor moved. Mirrors Banking activating its
		-- list before populating keybinds.
		if self.RefreshItemActions then
			self:RefreshItemActions()
		end
	end

	BETTERUI.CIM.Utils.SetExternalToolbarHidden(true)

	EnsureInventorySlotUpdateHook(self)

	-- Register for item preview refresh callbacks (native ESO feature)
	if ITEM_PREVIEW_GAMEPAD then
		if not self.onItemPreviewRefreshActionsCallback then
			self.onItemPreviewRefreshActionsCallback = function()
				self:RefreshItemActions()
			end
		end
		RegisterItemPreviewCallback("RefreshActions", self.onItemPreviewRefreshActionsCallback)
	end

	-- Register SHARED_INVENTORY callbacks for scene lifecycle (prevent memory leaks)
	-- Callbacks are unregistered in SCENE_HIDDEN and re-registered here on subsequent shows
	-- Skip on first show (already registered in PerformDeferredInitialize)
	if self._inventoryUpdateCallback and self._inventoryCallbacksUnregistered then
		RegisterSharedInventoryCallback("FullInventoryUpdate", self._inventoryUpdateCallback)
		RegisterSharedInventoryCallback("SingleSlotInventoryUpdate", self._inventoryUpdateCallback)
		RegisterSharedInventoryCallback("SingleQuestUpdate", self._inventoryUpdateCallback)
		self._inventoryCallbacksUnregistered = false
	end

	self.currentPreviewBagId = nil
	self.currentPreviewSlotIndex = nil
	-- search is handled via hold callbacks on X/Y; no separate A-based keybind group required
end

local function OnSceneHiding(self)
	if BETTERUI.Inventory and BETTERUI.Inventory._slotUpdateHookInstance == self then
		BETTERUI.Inventory._slotUpdateHookInstance = nil
	end
	if self:IsBatchProcessing() then
		self:RequestBatchAbort()
	end
	RemoveInventoryKeybindsForSceneExit(self, "hiding")
	self:Deactivate()
	self:DeactivateHeader()

	BETTERUI.CIM.Utils.SetExternalToolbarHidden(false)

	-- Cancel any pending deferred tooltip layout so it cannot fire after the
	-- scene is hidden (DeferredTask-scheduled, not EVENT_MANAGER updates).
	BETTERUI.Inventory.Tasks:Cancel("tooltipUpdate")
	BETTERUI.Inventory.Tasks:Cancel("tooltipRefresh")
	-- search hold behavior is part of main keybind descriptors; nothing to remove here
	-- Save the current list position so it can be restored when the scene is shown again
	self:SaveListPosition()
end

local function OnSceneHidden(self)
	if BETTERUI.Log then
		local integration = self._headerSortIntegration
		BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.STATE, "inventory scene pre-cleanup snapshot", {
			fn = "InventorySceneLifecycle.OnSceneHidden",
			headerSort = self.isInHeaderSortMode == true,
			active = integration and integration.isActive == true,
			activeKeybind = BETTERUI.Log.DescribeKeybindDescriptor and integration and BETTERUI.Log.DescribeKeybindDescriptor(integration.activeKeybindDescriptor, "active") or nil,
			suspendedCount = BETTERUI.Log.CountKeybindDescriptors and integration and BETTERUI.Log.CountKeybindDescriptors(integration.suspendedKeybindGroups) or 0,
			main = BETTERUI.Log.DescribeKeybindDescriptor and BETTERUI.Log.DescribeKeybindDescriptor(self.mainKeybindStripDescriptor, "main") or nil,
		})
	end
	-- Use shared CIM cleanup for input state (header sort, selection mode, search focus, tab bar)
	BETTERUI.CIM.SceneCleanup.CleanupInputState(self)

	-- Deactivate all lists to release DIRECTIONAL_INPUT
	-- Note: Inventory has multiple lists (itemList, craftBagList, categoryList)
	BETTERUI.CIM.SceneCleanup.DeactivateLists(self, self.itemList, self.craftBagList, self.categoryList)

	local savedListType = self.currentListType
	self:SwitchActiveList(nil)
	-- Always preserve previousListType so returning from brief scene detours
	-- (container loot, enchanting, etc.) restores to the correct list.
	self.previousListType = NormalizeInventoryListType(savedListType, nil)
	-- Track when scene was hidden for time-based brief-detour detection
	self._sceneHiddenTime = GetFrameTimeSeconds and GetFrameTimeSeconds() or 0
	BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.ZO_WIDTH)

	self.listWaitingOnDestroyRequest = nil
	BETTERUI.Inventory.NewItemTracker.CommitPendingClears()

	self:ClearActiveKeybinds()
	RemoveInventoryKeybindsForSceneExit(self, "hidden")

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

	-- Cancel any pending deferred tooltip layout so it cannot fire after the
	-- scene is hidden (DeferredTask-scheduled, not EVENT_MANAGER updates).
	BETTERUI.Inventory.Tasks:Cancel("tooltipUpdate")
	BETTERUI.Inventory.Tasks:Cancel("tooltipRefresh")

	-- Clear search state using shared helper
	BETTERUI.CIM.SceneCleanup.ClearSearchState(self)

	-- Save the current list position so it can be restored when the scene is shown again
	self:SaveListPosition()
end

local function ApplyInventorySceneState(self, oldState, newState)
	if newState == SCENE_SHOWING then
		OnSceneShowing(self)
	elseif newState == SCENE_HIDING then
		OnSceneHiding(self)
	elseif newState == SCENE_HIDDEN then
		OnSceneHidden(self)
	end
end

local function BuildInventoryLifecycleHandler(self)
	local sceneLifecycle = BETTERUI.CIM and BETTERUI.CIM.SceneLifecycle
	local createHandler = sceneLifecycle and sceneLifecycle.CreateStateChangeHandler
	if type(createHandler) ~= "function" then
        return function(oldState, newState)
            ApplyInventorySceneState(self, oldState, newState)
        end
	end

    return createHandler(self, {
		taskManager = BETTERUI.Inventory and BETTERUI.Inventory.Tasks or nil,
		onShowing = OnSceneShowing,
		onHiding = OnSceneHiding,
		onHidden = OnSceneHidden,
	})
end

function BETTERUI.Inventory.RegisterSceneLifecycle(screen)
	if not screen then
		return nil
	end

	if type(screen._inventorySceneLifecycleHandler) == "function" then
		screen._inventorySceneLifecycleRegistered = true
		return screen._inventorySceneLifecycleHandler
	end

	screen._inventorySceneLifecycleHandler = BuildInventoryLifecycleHandler(screen)
	screen._inventorySceneLifecycleRegistered = type(screen._inventorySceneLifecycleHandler) == "function"
	return screen._inventorySceneLifecycleHandler
end

--- Handles scene state changes (SHOWING, HIDING, HIDDEN).
--- Purpose: Manages initialization deferral, visualization layers, list activation, and state cleanup.
---@param oldState number Previous scene state constant
---@param newState number New scene state constant
---@return nil
function BETTERUI.Inventory.Class:OnStateChanged(oldState, newState)
	if BETTERUI.Log then BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SCENE, "Inventory Scene state transition", {oldState = oldState, newState = newState}) end
	local lifecycleHandler = BETTERUI.Inventory.RegisterSceneLifecycle(self)
	if type(lifecycleHandler) == "function" then
		lifecycleHandler(oldState, newState)
	end
end
