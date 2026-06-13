--[[
File: Modules/Inventory/Inventory.lua
Purpose: Inventory orchestration surface for shared runtime helpers and
         remaining class behavior that has not yet moved into focused files.
]]


-- CONSTANTS & GLOBALS

-- State and header helpers define focused runtime methods on the shared class.

local function GetInventoryListTypes()
	local inventoryConstants = BETTERUI.Inventory and BETTERUI.Inventory.CONST
	assert(inventoryConstants and inventoryConstants.LIST_TYPES,
		"Inventory runtime requires BETTERUI.Inventory.CONST.LIST_TYPES")
	return inventoryConstants.LIST_TYPES
end

local function GetInventoryListType(key)
	return GetInventoryListTypes()[key]
end

-- REMAINING CLASS METHODS

--- Toggles the tooltip detailed info mode.
---@return nil
function BETTERUI.Inventory.Class:SwitchInfo()
	self.switchInfo = not self.switchInfo
	if self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
		self:UpdateItemLeftTooltip(self.itemList.selectedData)
	end
end

--- Per-frame update handler for delayed list refreshes and tooltip updates.
---@param currentFrameTimeSeconds number|nil Frame timestamp, or nil for manual update
---@return nil
function BETTERUI.Inventory.Class:OnUpdate(currentFrameTimeSeconds)
	-- Post-transition refresh: when the primary action transition window expires,
	-- refresh item actions and keybinds so the A-button label updates to the
	-- post-action state (e.g., "Use" → "Split Stack" after cooldown, or
	-- "Equip" → "Unequip" after the list rebuilds). This runs every frame
	-- via the OnUpdate handler and costs nothing when no transition is active.
	if self._primaryActionTransitionExpiresMs then
		local nowMs = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
		if nowMs > self._primaryActionTransitionExpiresMs then
			self._primaryActionTransitionExpiresMs = nil
			self._primaryActionTransitionName = nil
			if self.RefreshItemActions then
				self:RefreshItemActions()
			end
			self:RefreshKeybinds()
		end
	end

	--if no currentFrameTimeSeconds a manual update was called from outside the update loop.
	if
		not currentFrameTimeSeconds
		or (self.nextUpdateTimeSeconds and (currentFrameTimeSeconds >= self.nextUpdateTimeSeconds))
	then
		self.nextUpdateTimeSeconds = nil

		if self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
			self:RefreshItemList()
			-- it's possible we removed the last item from this list
			-- so we want to switch back to the category list
			if self.itemList:IsEmpty() then
				local currentCategory = self.categoryList and BETTERUI.Inventory.Utils.SafeGetTargetData(self.categoryList)
				if currentCategory and (currentCategory.showJunk or currentCategory.showStolen) then
					-- If a transient category emptied out (e.g., unmark last junk item),
					-- force next category restoration to "All" rather than index-shifting.
					self.savedInventoryCategoryKey = nil
					self.savedInventoryCategoryIndex = 1
				end
				self:SwitchActiveList(GetInventoryListType("CATEGORY"))
			else
				-- don't refresh item actions if we are switching back to the category view
				-- otherwise we get keybindstrip errors (Item actions will try to add an "A" keybind
				-- and we already have an "A" keybind)
				-- During list rebuild windows, target data can be transiently nil.
				-- Skip action refresh in that state so A does not disappear/reappear.
				if not self.pendingBatchData then
					local selectedData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
					if selectedData then
						self:RefreshItemActions()
					end
				end
			end
		elseif self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
			self:RefreshCraftBagList()
			self:RefreshItemActions()
		elseif self.actionMode == BETTERUI.Inventory.CONST.CATEGORY_ITEM_ACTION_MODE then
			self:UpdateCategoryLeftTooltip(BETTERUI.Inventory.Utils.SafeGetTargetData(self.categoryList))
		end
	end
end

--- Delayed initialization logic (runs when scene enters SHOWING state).
---
--- Purpose: Heavy weight setup that shouldn't block startup.
--- Mechanics:
--- - Initializes SaveVars.
--- - Builds Lists (Category, Item, CraftBag).
--- - Initializes Dialogs and Keybinds.
--- - Registers for Engine Events (Money, Inventory Updates).
--- References: Called by `OnStateChanged`.
---
local function InitializeDeferredInventoryState(self)
	local savedVarDefaults = {
		useStatComparisonTooltip = true,
	}
	self.savedVars = ZO_SavedVars:NewAccountWide("ZO_Ingame_SavedVariables", 2, "GamepadInventory", savedVarDefaults)
	self.switchInfo = false

	-- Inventory uses custom trigger keybinds on the active list instead of
	-- the screen-level native header-jump triggers.
	self:SetListsUseTriggerKeybinds(false)

	self.categoryPositions = {}
	self.categoryCraftPositions = {}
	self.populatedCategoryPos = false
	self.populatedCraftPos = false
	self.isPrimaryWeapon = true
end

local function InitializeDeferredInventoryLists(self)
	self:InitializeCategoryList()
	self:InitializeHeader()
	self:InitializeCraftBagList()
	self:InitializeItemList()

	if self.InitializeHeaderSortController then
		self:InitializeHeaderSortController()
	end

	self:InitializeKeybindStrip()
	self:RefreshCategoryList()
	self.savedInventoryCategoryIndex = self.categoryList and self.categoryList.selectedIndex or 1
	self.savedInventoryCategoryKey = nil
	self.savedInventoryPositionsByKey = self.savedInventoryPositionsByKey or {}
	self.savedInventorySelectedItemUniqueByKey = self.savedInventorySelectedItemUniqueByKey or {}
	self.savedCraftBagCategoryIndex = nil
	self.savedCraftBagCategoryKey = nil
	self.savedCraftBagPositionsByKey = self.savedCraftBagPositionsByKey or {}
	self.savedCraftBagSelectedItemUniqueByKey = self.savedCraftBagSelectedItemUniqueByKey or {}

	self:SetSelectedItemUniqueId(self:GenerateItemSlotData(BETTERUI.Inventory.Utils.SafeGetTargetData(self.categoryList)))
	self:RefreshHeader()
	self:ActivateHeader()
end

local function InitializeDeferredInventoryDialogs(self)
	self:InitializeConfirmDestroyDialog()
	self:InitializeConfirmDestroyArmoryItemDialog()
	self:InitializeBatchDestroyDialog()
	self:InitializeEquipSlotDialog()
	self:InitializeItemActions()
	self:InitializeActionsDialog()

	if BETTERUI.GenericFooter then
		BETTERUI.GenericFooter.control = self.control
		BETTERUI.GenericFooter:Initialize()
	end
end

local function RegisterDeferredInventoryCallbacks(self, refreshHeader, refreshSelectedData)
	self.control:RegisterForEvent(EVENT_MONEY_UPDATE, refreshHeader)
	self.control:RegisterForEvent(EVENT_ALLIANCE_POINT_UPDATE, refreshHeader)
	self.control:RegisterForEvent(EVENT_TELVAR_STONE_UPDATE, refreshHeader)
	if EVENT_CURRENCY_UPDATE then
		self.control:RegisterForEvent(EVENT_CURRENCY_UPDATE, refreshHeader)
	end

	local function OnBagSpaceChanged()
		if self.control:IsHidden() then
			return
		end

		-- Keep utility categories (e.g., bag upgrade) in sync with current capacity.
		-- This mirrors native behavior where bag-space purchases immediately update
		-- category availability without waiting for inventory slot updates.
		self:RefreshCategoryList()
		self:RefreshHeader(BLOCK_TABBAR_CALLBACK)
		if self.RefreshKeybinds then
			self:RefreshKeybinds()
		end
	end
	self.control:RegisterForEvent(EVENT_INVENTORY_BOUGHT_BAG_SPACE, OnBagSpaceChanged)
	self.control:RegisterForEvent(EVENT_INVENTORY_BAG_CAPACITY_CHANGED, OnBagSpaceChanged)
	self.control:RegisterForEvent(EVENT_PLAYER_DEAD, refreshSelectedData)
	self.control:RegisterForEvent(EVENT_PLAYER_REINCARNATED, refreshSelectedData)

	-- Learning a recipe/style flips the known/unknown state of OTHER copies of
	-- the same item without any slot update for them; drop the per-item caches
	-- and refresh so rows stop showing stale knowledge.
	local function OnItemKnowledgeChanged()
		if self.InvalidateItemMeta then
			self:InvalidateItemMeta()
		end
		self:InvalidateSlotDataCache()
		if self.control:IsHidden() then
			self:MarkDirty()
			return
		end
		if self:IsBatchProcessing() and self.batchSuppressUiUpdates then
			return
		end
		if self.RefreshItemList then
			self:RefreshItemList()
		end
	end
	if EVENT_RECIPE_LEARNED then
		self.control:RegisterForEvent(EVENT_RECIPE_LEARNED, OnItemKnowledgeChanged)
	end
	if EVENT_STYLE_LEARNED then
		self.control:RegisterForEvent(EVENT_STYLE_LEARNED, OnItemKnowledgeChanged)
	end

	local function OnInventoryUpdated(bagId, slotIndex)
		-- POSITION PRESERVATION: Capture current uniqueId AND index BEFORE any callbacks overwrite data
		-- This is a global fix that works for all inventory actions (Use, Equip, Split, etc.)
		-- When item leaves list (equip to BAG_WORN, consume), uniqueId fails so index is fallback
		if not self._preserveUniqueId then
			local currentData = self.currentlySelectedData
			if currentData then
				local uid = (currentData.dataSource and currentData.dataSource.uniqueId) or currentData.uniqueId
				if uid then
					self._preserveUniqueId = uid
				end
			end
			if self.itemList and self.itemList.selectedIndex then
				self._preserveIndex = self.itemList.selectedIndex
			end
		end

		-- InvalidateItemMeta clears cached per-item fields on the live shared
		-- bag caches (independent of the snapshot InvalidateSlotDataCache
		-- empties), then the snapshot is dropped (mirrors
		-- OnItemKnowledgeChanged).
		if self.InvalidateItemMeta then
			self:InvalidateItemMeta(bagId, slotIndex)
		end
		self:InvalidateSlotDataCache()
		self:MarkDirty()
		if GetFrameTimeSeconds then
			self.nextUpdateTimeSeconds = GetFrameTimeSeconds() + 0.05
		else
			self.nextUpdateTimeSeconds = nil
		end

		if self:IsBatchProcessing() and self.batchSuppressUiUpdates then
			return
		end

		local currentList = self:GetCurrentList()
		if self.scene:IsShowing() then
			if ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
				self:OnUpdate()
			else
				refreshSelectedData()
				if currentList == self.itemList and not self.pendingBatchData then
					-- PB-006: An in-place SingleSlotInventoryUpdate (e.g. a container
					-- replaced by its contents at the same slot) updates the row data
					-- without firing the selection-change callback that recomputes the
					-- cached primary action (itemActions.actionName). The same-frame
					-- fingerprint dedup in SetSelectedInventoryData (keyed on
					-- uniqueId|bagId|slotIndex|slotType) can then skip re-resolution,
					-- leaving the keybind showing the previous item's primary action.
					-- Clear the dedup fingerprint and force a re-resolution for the
					-- currently-selected slot BEFORE RefreshKeybinds reads the cached
					-- actionName, so the label/handler match the new item. Normal
					-- selection changes go through the callback path (not this branch),
					-- so this does not double-fire on ordinary navigation.
					self._lastSetSelectedInventoryDataFingerprint = nil
					self._lastSetSelectedInventoryDataFrame = nil
					if self.RefreshItemActions then
						self:RefreshItemActions()
					end
					self:RefreshKeybinds()
				end
				self:RefreshHeader(BLOCK_TABBAR_CALLBACK)
			end

			local timeSinceShow = GetFrameTimeSeconds and (GetFrameTimeSeconds() - (self._sceneShowedTime or 0)) or 999
			if not self._pendingCategoryListRefresh and timeSinceShow > 0.2 then
				self._pendingCategoryListRefresh = true
				local function TryRefreshCategoriesAfterBatch()
					if not self.scene:IsShowing() then
						self._pendingCategoryListRefresh = false
						return
					end

					if self:IsBatchProcessing() then
						BETTERUI.Inventory.Tasks:Schedule("categoryRefreshCoalesce",
							BETTERUI.CIM.CONST.TIMING.CATEGORY_REFRESH_COALESCE_MS, TryRefreshCategoriesAfterBatch)
						return
					end

					self._pendingCategoryListRefresh = false
					self:RefreshCategoryList()
				end

				BETTERUI.Inventory.Tasks:Schedule("categoryRefreshCoalesce",
					BETTERUI.CIM.CONST.TIMING.CATEGORY_REFRESH_COALESCE_MS, TryRefreshCategoriesAfterBatch)
			end
		end
	end

	self._inventoryUpdateCallback = OnInventoryUpdated
	SHARED_INVENTORY:RegisterCallback("FullInventoryUpdate", self._inventoryUpdateCallback)
	SHARED_INVENTORY:RegisterCallback("SingleSlotInventoryUpdate", self._inventoryUpdateCallback)
	SHARED_INVENTORY:RegisterCallback("SingleQuestUpdate", self._inventoryUpdateCallback)
end

function BETTERUI.Inventory.Class:OnDeferredInitialize()
	if self._betterUIDeferredInventoryInitialized then return end
	self._betterUIDeferredInventoryInitialized = true
	self.isDeferredInitialized = true

	InitializeDeferredInventoryState(self)
	InitializeDeferredInventoryLists(self)
	InitializeDeferredInventoryDialogs(self)

	local function RefreshHeader()
		if not self.control:IsHidden() then
			self:RefreshHeader(BLOCK_TABBAR_CALLBACK)
		end
	end

	local function RefreshSelectedData()
		if not self.control:IsHidden() then
			local selectedData = nil
			local nowMs = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
			local inPrimaryActionTransition = self._primaryActionTransitionExpiresMs
				and nowMs <= self._primaryActionTransitionExpiresMs
			if self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
				selectedData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
			elseif self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
				selectedData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList)
			elseif self.actionMode == BETTERUI.Inventory.CONST.CATEGORY_ITEM_ACTION_MODE then
				local categoryData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.categoryList)
				if categoryData then
					selectedData = self:GenerateItemSlotData(categoryData)
				end
			elseif self.currentlySelectedData then
				selectedData = self.currentlySelectedData
			end

			if selectedData then
				self:SetSelectedInventoryData(selectedData)
			elseif not inPrimaryActionTransition then
				self:SetSelectedInventoryData(nil)
			end
		end
	end

	RegisterDeferredInventoryCallbacks(self, RefreshHeader, RefreshSelectedData)

	if self.RefreshKeybinds then
		self:RefreshKeybinds()
	elseif self.mainKeybindStripDescriptor then
		KEYBIND_STRIP:UpdateKeybindButtonGroup(self.mainKeybindStripDescriptor)
		if self.SetActiveKeybinds then
			self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
		end
	end

	local initialListType = GetInventoryListType("ITEM")
	if self.scene and self.scene:IsShowing() then
		self:SwitchActiveList(initialListType)
	else
		-- Do not mark a hidden list as active yet. The first visible scene show
		-- must still execute the full activation path so category and item data
		-- rebuild against live shared-inventory caches.
		self.currentListType = nil
		self.previousListType = nil
	end
end

--- Bridges BetterUI deferred setup to the inventory scene lifecycle.
--- Some native inventory flows do not call our custom OnDeferredInitialize hook,
--- so we explicitly trigger it once after giving the parent class a chance to
--- perform its own one-time work.
function BETTERUI.Inventory.Class:PerformDeferredInitialize()
	if self._betterUIDeferredInitializePerformed then
		return
	end
	self._betterUIDeferredInitializePerformed = true

	local parentPerformDeferredInitialize = ZO_GamepadInventory and ZO_GamepadInventory.PerformDeferredInitialize
	if type(parentPerformDeferredInitialize) == "function" then
		parentPerformDeferredInitialize(self)
	end

	if not self._betterUIDeferredInventoryInitialized and self.OnDeferredInitialize then
		self:OnDeferredInitialize()
	end
end

--- Clears the text search UI and internal state.
---@return nil
function BETTERUI.Inventory.Class:ClearTextSearch()
	-- Ensure internal state is cleared
	self.searchQuery = ""
	-- Prefer shared helper if available
	local searchMixin = BETTERUI.Interface and BETTERUI.Interface.SearchMixin
	if searchMixin and searchMixin.ClearSearchText then
		searchMixin.ClearSearchText(self)
	elseif self.ClearSearchText then
		self:ClearSearchText()
	end
end

--- Refreshes the footer display.
---@return nil
function BETTERUI.Inventory.Class:RefreshFooter()
	if BETTERUI.GenericFooter then
		BETTERUI.GenericFooter:Refresh()
	end
end

--- Selects the current category and switches to the appropriate list.
---@return nil
function BETTERUI.Inventory.Class:Select()
	local catTarget = BETTERUI.Inventory.Utils.SafeGetTargetData(self.categoryList)
	if catTarget and catTarget.isBagSpaceEntry then
		ZO_Dialogs_ShowGamepadDialog("BUY_BAG_SPACE_FROM_INVENTORY_GAMEPAD", { cost = GetNextBackpackUpgradePrice() })
		return
	end
	if not catTarget or not catTarget.onClickDirection then
		self:SwitchActiveList(GetInventoryListType("ITEM"))
	else
		self:SwitchActiveList(GetInventoryListType("CRAFT_BAG"))
	end
end

--- Switches between item list and craft bag list.
---@return nil
function BETTERUI.Inventory.Class:Switch()
	if self:GetCurrentList() == self.craftBagList then
		self:SwitchActiveList(GetInventoryListType("ITEM"))
	else
		self:SwitchActiveList(GetInventoryListType("CRAFT_BAG"))
	end
end

--- Creates a new parametric list for the inventory scene.
---@param name string List identifier
---@param callbackParam function|nil Selection change callback
---@param listClass table|nil List class to instantiate
---@param ... any Additional arguments passed to list constructor
---@return table list The created list instance
function BETTERUI.Inventory.Class:AddList(name, callbackParam, listClass, ...)
	local listContainer = CreateControlFromVirtual(
		"$(parent)" .. name,
		self.control.container,
		"BETTERUI_Gamepad_ParametricList_Screen_ListContainer"
	)
	local list = self.CreateAndSetupList(self, listContainer.list, callbackParam, listClass, ...)
	list.alignToScreenCenterExpectedEntryHalfHeight = 15
	self.lists[name] = list

	local CREATE_HIDDEN = true
	self:CreateListFragment(name, CREATE_HIDDEN)
	return list
end

