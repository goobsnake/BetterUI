--[[
File: Modules/Inventory/Inventory.lua
Purpose: Orchestration layer for BetterUI Inventory system.
         Routes to extracted modules for specific functionality.

         Module Structure (POST-DECOMPOSITION):
         - Core/InventoryClass.lua - Initialize, caching, header
         - Lists/ItemListManager.lua - Item list refresh, tooltips
         - Lists/CraftBagListManager.lua - Craft bag logic
         - Lists/CategoryListManager.lua - Category tabs
         - Actions/EquipAction.lua - TryEquipItem, equip dialogs
         - Actions/ItemActionsDialog.lua - Y-menu customization

         - Keybinds/InventoryKeybinds.lua - Keybind strip
         - State/PositionManager.lua - Position save/restore
         - State/ListStateManager.lua - SwitchActiveList
Author: BetterUI Team
Last Modified: 2026-02-08
]]


--------------------------------------------------------------------------------
-- CONSTANTS & GLOBALS
--------------------------------------------------------------------------------

-- Apply Class Mixins (from PositionManager, etc.)
-- Mixins are now applied in Initialize() via MixinLoader

-- Action mode constants
-- Action mode constants (must match other files)
-- Replaced by BETTERUI.Inventory.CONST equivalents

-- List type identifiers
local INVENTORY_CATEGORY_LIST = "categoryList"
local INVENTORY_ITEM_LIST = "itemList"
local INVENTORY_CRAFT_BAG_LIST = "craftBagList"

-- Global dialog name
-- TODO(fix): Namespace global dialog name to BETTERUI.Inventory.Dialogs.EQUIP_SLOT
BETTERUI_EQUIP_SLOT_DIALOG = "BETTERUI_EQUIP_SLOT_DIALOG"

--------------------------------------------------------------------------------
-- COMPANION EQUIP PATCH
--------------------------------------------------------------------------------
-- Patches ZO_CompanionEquipment_Gamepad:TryEquipItem for bind-on-equip handling
-- NOTE: EnsureCompanionEquipPatched is defined and exported in Actions/EquipAction.lua

--------------------------------------------------------------------------------
-- SECURE SYSTEM HOOKS
--------------------------------------------------------------------------------
local ZO_AssignableUtilityWheel_Gamepad = ZO_AssignableUtilityWheel_Gamepad
-- Globally hooks the assignable utility wheel to ensure untrusted callstacks
-- from our add-on keybinds don't crash when they reach protected assignment CAPI.
function BETTERUI.Inventory.InitializeSecureWheelHooks()
	if ZO_AssignableUtilityWheel_Gamepad and not BETTERUI._secureWheelHooked then
		ZO_PreHook(ZO_AssignableUtilityWheel_Gamepad, "TryAssignPendingToSelectedEntry", function(self, clearPending)
			local selectedEntry = self:GetSelectedRadialEntry()
			local pendingSlotData = self.pendingSlotData
			if self.radialMenu:IsShown() and pendingSlotData and selectedEntry then
				local actionSlotIndex = selectedEntry.data.slotIndex
				local hotbarCategory = self:GetHotbarCategory()
				if pendingSlotData.actionId then
					CallSecureProtected("SelectSlotSimpleAction", pendingSlotData.slotType, pendingSlotData.actionId,
						actionSlotIndex, hotbarCategory)
				elseif pendingSlotData.bagId and pendingSlotData.itemSlotIndex then
					CallSecureProtected("SelectSlotItem", pendingSlotData.bagId, pendingSlotData.itemSlotIndex,
						actionSlotIndex, hotbarCategory)
				end

				if clearPending then
					self.pendingSlotData = nil
				end
				if SOUNDS and PlaySound then
					PlaySound(SOUNDS.RADIAL_MENU_SELECTION)
				end

				if self.data and self.data.customNarrationObjectName and SCREEN_NARRATION_MANAGER then
					SCREEN_NARRATION_MANAGER:QueueCustomEntry(self.data.customNarrationObjectName)
				end

				if self.data and self.data.showPendingIcon then
					self:RefreshPendingIcon()
				end
			end
			-- Always return true to cancel the original unprotected native execution
			return true
		end)
		BETTERUI._secureWheelHooked = true
	end
end

-- GetEquipSlotForEquipType extracted to Core/InventoryClass.lua
-- GetCategoryKey, FindCategoryIndexByKey extracted to State/PositionManager.lua
-- SafeGetTargetData moved to InventoryUtils.lua
-- SaveListPosition, ToSavedPosition extracted to State/PositionManager.lua (injected via Mixins)
-- InitializeCategoryList, NewCategoryItem, RefreshCategoryList extracted to Lists/CategoryListManager.lua
-- IsItemListEmpty, HasAnyJunkInBackpack, RefreshItemList extracted to Lists/ItemListManager.lua
-- TryEquipItem, InitializeEquipSlotDialog extracted to Actions/EquipAction.lua
-- RefreshCraftBagList, LayoutCraftBagTooltip extracted to Lists/CraftBagListManager.lua
-- InitializeHeader, OnCategoryClicked extracted to Core/HeaderManager.lua
-- RefreshHeader, PositionSearchControl extracted to Core/InventoryClass.lua

--------------------------------------------------------------------------------
-- REMAINING CLASS METHODS
--------------------------------------------------------------------------------

--- Toggles the tooltip detailed info mode.

function BETTERUI.Inventory.Class:SwitchInfo()
	self.switchInfo = not self.switchInfo
	if self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
		self:UpdateItemLeftTooltip(self.itemList.selectedData)
	end
end

-- UpdateItemLeftTooltip, UpdateRightTooltip, InitializeItemList extracted to Lists/ItemListManager.lua
-- InitializeCraftBagList extracted to Lists/CraftBagListManager.lua
-- InitializeItemActions, InitializeActionsDialog extracted to Actions/ItemActionsDialog.lua
-- TryDestroyItem, HookDestroyItem, HookActionDialog extracted to Actions/ItemActionsDialog.lua



--- Handles scene state changes (SHOWING, HIDING, HIDDEN).
---
--- Purpose: Manages initialization deferral, visualization layers, list activation, and state cleanup.
--- Mechanics:
--- - **SHOWING**: Defers Init if needed. Configures Tooltip Width. Switches to correct list (Backpack vs Category). Activates Header/Toolbar.
--- - **HIDING**: Deactivates Header. Restores Toolbar. Saves List Position.
--- - **HIDDEN**: Clears Active Keybinds. Clears Text Search. Saves Console Profile.
--- References: Registered as Scene State Change callback.
---
--- @param oldState integer The previous scene state
--- @param newState integer The new scene state
function BETTERUI.Inventory.Class:OnStateChanged(oldState, newState)
	if newState == SCENE_SHOWING then
		self:PerformDeferredInitialize()
		BETTERUI.CIM.SetTooltipWidth(BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH)

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
		BETTERUI.CIM.SetTooltipWidth(BETTERUI_ZO_GAMEPAD_DEFAULT_PANEL_WIDTH)

		self.listWaitingOnDestroyRequest = nil
		self:TryClearNewStatusOnHidden()

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

--- Initializes the custom dialog for selecting equipment slots (e.g., Ring 1 vs Ring 2).
---
--- Purpose: Prompts the user when equipping items where the target slot is ambiguous.
--- Mechanics:
--- - Registers `BETTERUI_EQUIP_SLOT_DIALOG`.
--- - Uses `GAMEPAD_DIALOGS.BASIC` style.
--- - Dynamic Main Text updates based on item type (One-Handed, Ring, etc.).
--- - Provides two primary buttons (e.g. "Main Hand" / "Off Hand").
--- References: Called during `TryEquipItem`.
---

-- InitializeEquipSlotDialog moved to Actions/EquipAction.lua


--- Per-frame update handler.
---
--- Purpose: Manages delayed list refreshes and visual updates.
--- Mechanics:
--- - Checks `nextUpdateTimeSeconds` to throttle updates.
--- - Refreshes the active list (Item vs Craft Bag) if dirty.
--- - Updates tooltips if in "Category Action" mode.
--- References: Called by native `OnUpdate` handler.
---
--- @param currentFrameTimeSeconds number|nil The current game time (or nil if forced).
function BETTERUI.Inventory.Class:OnUpdate(currentFrameTimeSeconds)
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
				self:SwitchActiveList(INVENTORY_CATEGORY_LIST)
			else
				-- don't refresh item actions if we are switching back to the category view
				-- otherwise we get keybindstrip errors (Item actions will try to add an "A" keybind
				-- and we already have an "A" keybind)

				self:RefreshItemActions()
			end
		elseif self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
			self:RefreshCraftBagList()
			self:RefreshItemActions()
		else -- CATEGORY_ITEM_ACTION_MODE
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
function BETTERUI.Inventory.Class:OnDeferredInitialize()
	if self.isDeferredInitialized then return end
	self.isDeferredInitialized = true

	local SAVED_VAR_DEFAULTS = {
		useStatComparisonTooltip = true,
	}
	self.savedVars = ZO_SavedVars:NewAccountWide("ZO_Ingame_SavedVariables", 2, "GamepadInventory", SAVED_VAR_DEFAULTS)
	self.switchInfo = false

	-- Inventory uses custom trigger keybinds on the active list instead of
	-- the screen-level native header-jump triggers.
	self:SetListsUseTriggerKeybinds(false)

	self.categoryPositions = {}
	self.categoryCraftPositions = {}
	self.populatedCategoryPos = false
	self.populatedCraftPos = false
	self.isPrimaryWeapon = true

	self:InitializeCategoryList()
	self:InitializeHeader()
	self:InitializeCraftBagList()

	self:InitializeItemList()

	-- Initialize Header Sort Controller for column-based sorting
	-- Must be called after InitializeItemList (needs self.itemList) and InitializeHeader (needs self.header)
	if self.InitializeHeaderSortController then
		self:InitializeHeaderSortController()
	end

	self:InitializeKeybindStrip()

	self:InitializeConfirmDestroyDialog()
	self:InitializeConfirmDestroyArmoryItemDialog()
	self:InitializeBatchDestroyDialog()
	self:InitializeEquipSlotDialog()

	self:InitializeItemActions()
	self:InitializeActionsDialog()


	-- Initialize Footer using shared GenericFooter
	if BETTERUI.GenericFooter then
		BETTERUI.GenericFooter.control = self.control
		BETTERUI.GenericFooter:Initialize()
	end

	local function RefreshHeader()
		if not self.control:IsHidden() then
			self:RefreshHeader(BLOCK_TABBAR_CALLBACK)
		end
	end

	local function RefreshSelectedData()
		if not self.control:IsHidden() then
			self:SetSelectedInventoryData(self.currentlySelectedData)
		end
	end

	self:RefreshCategoryList()
	-- Initialize saved category indices and keys for inventory and craft bag
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

	self.control:RegisterForEvent(EVENT_MONEY_UPDATE, RefreshHeader)
	self.control:RegisterForEvent(EVENT_ALLIANCE_POINT_UPDATE, RefreshHeader)
	self.control:RegisterForEvent(EVENT_TELVAR_STONE_UPDATE, RefreshHeader)
	if EVENT_CURRENCY_UPDATE then
		self.control:RegisterForEvent(EVENT_CURRENCY_UPDATE, RefreshHeader)
	end
	self.control:RegisterForEvent(EVENT_PLAYER_DEAD, RefreshSelectedData)
	self.control:RegisterForEvent(EVENT_PLAYER_REINCARNATED, RefreshSelectedData)

	local function OnInventoryUpdated(bagId, slotIndex)
		-- POSITION PRESERVATION: Capture current uniqueId AND index BEFORE any callbacks overwrite data
		-- This is a global fix that works for all inventory actions (Use, Equip, Split, etc.)
		-- When item leaves list (equip to BAG_WORN, consume), uniqueId fails so index is fallback
		if not self._preserveUniqueId then
			local currentData = self.currentlySelectedData
			if currentData then
				-- Extract uniqueId from wrapped data or direct property
				local uid = (currentData.dataSource and currentData.dataSource.uniqueId) or currentData.uniqueId
				if uid then
					self._preserveUniqueId = uid
				end
			end
			-- Also save current index for fallback when item is removed from list
			if self.itemList and self.itemList.selectedIndex then
				self._preserveIndex = self.itemList.selectedIndex
			end
		end

		self:InvalidateSlotDataCache()
		if self.InvalidateItemMeta then
			self:InvalidateItemMeta(bagId, slotIndex)
		end
		self:MarkDirty()
		-- Debounce heavy updates to the next frame to batch rapid changes
		if GetFrameTimeSeconds then
			self.nextUpdateTimeSeconds = GetFrameTimeSeconds() + 0.05
		else
			self.nextUpdateTimeSeconds = nil
		end

		-- Batch destroy can trigger one slot-update callback per item. During that flow,
		-- skip per-item UI refresh churn and rely on the final post-batch refresh.
		if self:IsBatchProcessing() and self.batchSuppressUiUpdates then
			return
		end

		local currentList = self:GetCurrentList()
		if self.scene:IsShowing() then
			-- If an action dialog is open, keep the immediate update for correctness
			if ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
				self:OnUpdate() -- immediate to keep dialog/keybinds consistent
			else
				-- RefreshKeybinds() is protected by InventoryClass override
				if currentList == self.itemList then
					self:RefreshKeybinds()
				end
				RefreshSelectedData()
				self:RefreshHeader(BLOCK_TABBAR_CALLBACK)
			end
			-- Coalesce a category refresh so new tabs (Junk/Stolen) appear promptly.
			-- This runs OUTSIDE the dialog if/else because SetItemIsJunk is asynchronous:
			-- IsItemJunk() returns false immediately after SetItemIsJunk(), so any
			-- immediate RefreshCategoryList call in MarkAsJunk/UnmarkAsJunk finds 0 junk.
			-- The engine only updates IsItemJunk after processing EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
			-- which fires this OnInventoryUpdated callback. At that point, IsItemJunk is correct
			-- and the coalesced RefreshCategoryList will create/remove the Junk tab.
			-- Skip if we just opened the scene (within 200ms) since SwitchActiveList already refreshed.
			local timeSinceShow = GetFrameTimeSeconds and (GetFrameTimeSeconds() - (self._sceneShowedTime or 0)) or
				999
			if not self._pendingCategoryListRefresh and timeSinceShow > 0.2 then
				self._pendingCategoryListRefresh = true
				BETTERUI.Inventory.Tasks:Schedule("categoryRefreshCoalesce",
					BETTERUI.CIM.CONST.TIMING.CATEGORY_REFRESH_COALESCE_MS, function()
						self._pendingCategoryListRefresh = false
						if self.scene:IsShowing() then
							self:RefreshCategoryList()
						end
					end)
			end
		end
	end

	-- Store callback reference for scene-based registration/unregistration
	-- Actual registration happens in OnStateChanged SCENE_SHOWING
	self._inventoryUpdateCallback = OnInventoryUpdated
	-- Initial registration (will be unregistered on SCENE_HIDDEN and re-registered on SCENE_SHOWING)
	SHARED_INVENTORY:RegisterCallback("FullInventoryUpdate", self._inventoryUpdateCallback)
	SHARED_INVENTORY:RegisterCallback("SingleSlotInventoryUpdate", self._inventoryUpdateCallback)
	SHARED_INVENTORY:RegisterCallback("SingleQuestUpdate", self._inventoryUpdateCallback)

	-- Keybind refresh - protected by RefreshKeybinds() override
	if self.RefreshKeybinds then
		self:RefreshKeybinds()
	elseif self.mainKeybindStripDescriptor then
		KEYBIND_STRIP:UpdateKeybindButtonGroup(self.mainKeybindStripDescriptor)
		-- Ensure the main group is active on initial load to prevent missing shoulder navigation.
		if self.SetActiveKeybinds then
			self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
		end
	end

	-- Set the active list to ItemList by default
	self:SwitchActiveList(INVENTORY_ITEM_LIST)
end

--- Initializes the Inventory object.
---
--- Purpose: Sets up the root scene, registers update loops, and hooks into visual layer changes.
--- Mechanics:
--- - Creates `ZO_Scene` ("gamepad_inventory_root").
--- - Initializes Parametric List logic.
--- - hooks `OnUpdate` and `EVENT_VISUAL_LAYER_CHANGED`.
--- - Sets up the "Search" control logic (Focus hooks, Key handlers).
--- References: Called by Module.lua.
---

-- Initialize extracted to Core/InventoryClass.lua
-- BETTERUI.Inventory.Class:Initialize


--- Refreshes the header information (Money, AP, Tel Var, Capacity).
---
--- Purpose: Updates the top bar with current currency and bag space.
--- Mechanics:
--- - Builds header data dynamically based on Settings (can hide currencies).
--- - Refreshes GenericHeader.
--- - Updates Equipment Slot indicators (Main/Backup).
--- - Repositions Search Control.
--- References: Called on Currency Update or List Switch.
---
-- RefreshHeader extracted to Core/InventoryClass.lua
-- BETTERUI.Inventory.Class:RefreshHeader


--- Positions the text search control in the header.
---
--- Purpose: Ensures the search input sits correctly within the custom header geometry.
--- Mechanics: Finds the "TitleContainer" or equivalent anchor and offsets the control.
--- References: Called by RefreshHeader.
---

-- PositionSearchControl extracted to Core/InventoryClass.lua
-- BETTERUI.Inventory.Class:PositionSearchControl


--- Centralized helper to clear the text search UI and internal state.
---
--- Purpose: Resets search query and UI.
--- Mechanics: Clears `self.searchQuery` and calls `BETTERUI.Interface.Window.ClearSearchText`.
--- References: Called when hiding scene or when "Clear" keybind is pressed.
---
function BETTERUI.Inventory.Class:ClearTextSearch()
	-- Ensure internal state is cleared
	self.searchQuery = ""
	-- Prefer shared helper if available
	if BETTERUI and BETTERUI.Interface and BETTERUI.Interface.Window and BETTERUI.Interface.Window.ClearSearchText then
		BETTERUI.Interface.Window.ClearSearchText(self)
	elseif self.ClearSearchText then
		self:ClearSearchText()
	end
end

function BETTERUI.Inventory.Class:RefreshFooter()
	if BETTERUI.GenericFooter then
		BETTERUI.GenericFooter:Refresh()
	end
end

function BETTERUI.Inventory.Class:Select()
	local catTarget = BETTERUI.Inventory.Utils.SafeGetTargetData(self.categoryList)
	if not catTarget or not catTarget.onClickDirection then
		self:SwitchActiveList(INVENTORY_ITEM_LIST)
	else
		self:SwitchActiveList(INVENTORY_CRAFT_BAG_LIST)
	end
end

function BETTERUI.Inventory.Class:Switch()
	if self:GetCurrentList() == self.craftBagList then
		self:SwitchActiveList(INVENTORY_ITEM_LIST)
	else
		self:SwitchActiveList(INVENTORY_CRAFT_BAG_LIST)
	end
end

--- Switches the active list between Inventory and Craft Bag.
---
--- Purpose: Core context switcher.
--- Mechanics:
--- 1. **Snapshot**: Saves current list position and selection unique ID.
--- 2. **Switch**: Updates `currentListType` (Item List vs Craft Bag).
--- 3. **Restore**:
---    - Sets Active List.
---    - Restores Category Tab from saved state.
---    - Restores Item Selection from saved state (Index or UniqueID).
--- 4. **Refresh**: Triggers Header and Keybind updates.
--- References: Called by Tab Navigation and Scene Entry.
---
-- SwitchActiveList moved to State/ListStateManager.lua


--- Activates the generic header control.
---
--- Purpose: Sets focus to the header.
--- Mechanics: Calls `ZO_GamepadGenericHeader_Activate` and syncs the tab bar selection.
---

-- Header and Search focus overrides moved to Core/HeaderManager.lua


--- Creates a new parametric list for the inventory scene.
---
--- Purpose: Helper to instantiate `BETTERUI_VerticalParametricScrollList`.
--- Mechanics:
--- - Creates control from virtual template.
--- - Initializes and setups list logic.
--- - Adds to `self.lists`.
---
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

function BETTERUI.Inventory.Class:BETTERUI_IsSlotLocked(inventorySlot)
	if not inventorySlot then
		return false
	end

	local slot = PLAYER_INVENTORY:SlotForInventoryControl(inventorySlot)
	if slot then
		return slot.locked
	end
end

-- InitializeKeybindStrip extracted to Keybinds/InventoryKeybinds.lua

local function BETTERUI_TryPlaceInventoryItemInEmptySlot(targetBag)
	local emptySlotIndex, bagId
	if targetBag == BAG_BANK or targetBag == BAG_SUBSCRIBER_BANK then
		--should find both in bank and subscriber bank
		emptySlotIndex = FindFirstEmptySlotInBag(BAG_BANK)
		if emptySlotIndex ~= nil then
			bagId = BAG_BANK
		else
			emptySlotIndex = FindFirstEmptySlotInBag(BAG_SUBSCRIBER_BANK)
			if emptySlotIndex ~= nil then
				bagId = BAG_SUBSCRIBER_BANK
			end
		end
	else
		--just find the bag
		emptySlotIndex = FindFirstEmptySlotInBag(targetBag)
		if emptySlotIndex ~= nil then
			bagId = targetBag
		end
	end

	if bagId ~= nil then
		CallSecureProtected("PlaceInInventory", bagId, emptySlotIndex)
	else
		local errorStringId = (targetBag == BAG_BACKPACK) and SI_INVENTORY_ERROR_INVENTORY_FULL
			or SI_INVENTORY_ERROR_BANK_FULL
		ZO_Alert(UI_ALERT_CATEGORY_ERROR, SOUNDS.NEGATIVE_CLICK, errorStringId)
	end
end

--- Initializes the split stack dialog for moving items.
---
--- Purpose: Allows splitting stacks when moving to/from bank.
--- Mechanics: Registers `ZO_GAMEPAD_SPLIT_STACK_DIALOG` with custom callback to `PickupInventoryItem`.
--- References: Called by Initialize.
---
function BETTERUI.Inventory.Class:InitializeSplitStackDialog()
	BETTERUI.CIM.Dialogs.Register(ZO_GAMEPAD_SPLIT_STACK_DIALOG, {
		canQueue = true,

		gamepadInfo = {
			dialogType = GAMEPAD_DIALOGS.ITEM_SLIDER,
		},

		setup = function(dialog, data)
			dialog:setupFunc()
		end,

		title = {
			text = SI_GAMEPAD_INVENTORY_SPLIT_STACK_TITLE,
		},

		mainText = {
			text = SI_GAMEPAD_INVENTORY_SPLIT_STACK_PROMPT,
		},

		-- ESO passes: sliderMin=1, sliderMax=stackSize-1, sliderStartValue=stackSize/2, stackSize
		-- The slider value represents how many to move to the NEW stack
		-- Display: left shows remaining (stackSize - value), right shows moving (value)
		OnSliderValueChanged = function(dialog, sliderControl, value)
			if dialog and dialog.data and value then
				local stackSize = dialog.data.stackSize or 0
				dialog.sliderValue1:SetText(stackSize - value)
				dialog.sliderValue2:SetText(value)
			end
		end,

		narrationText = function(dialog, itemName)
			if not dialog or not dialog.slider then return nil end
			local stack2 = dialog.slider:GetValue()
			local stack1 = (dialog.data.stackSize or 0) - stack2
			return SCREEN_NARRATION_MANAGER:CreateNarratableObject(
				zo_strformat(SI_GAMEPAD_INVENTORY_SPLIT_STACK_NARRATION_FORMATTER, itemName, stack1, stack2)
			)
		end,

		additionalInputNarrationFunction = function()
			return ZO_GetHorizontalDirectionalInputNarrationData(
				GetString(SI_GAMEPAD_INVENTORY_SPLIT_STACK_LEFT_NARRATION),
				GetString(SI_GAMEPAD_INVENTORY_SPLIT_STACK_RIGHT_NARRATION)
			)
		end,

		buttons = {
			{
				keybind = "DIALOG_NEGATIVE",
				text = GetString(SI_DIALOG_CANCEL),
			},
			{
				keybind = "DIALOG_PRIMARY",
				text = GetString(SI_GAMEPAD_SELECT_OPTION),
				callback = function(dialog)
					local dialogData = dialog.data
					local quantity = ZO_GenericGamepadItemSliderDialogTemplate_GetSliderValue(dialog)

					-- Save the uniqueId BEFORE split so inventory refresh restores position
					-- Store in dedicated field to survive list selection callback overwriting currentlySelectedData
					local uniqueId = GetItemUniqueId(dialogData.bagId, dialogData.slotIndex)
					if uniqueId and GAMEPAD_INVENTORY then
						GAMEPAD_INVENTORY._splitStackUniqueId = uniqueId
					end

					CallSecureProtected("PickupInventoryItem", dialogData.bagId, dialogData.slotIndex, quantity)
					BETTERUI_TryPlaceInventoryItemInEmptySlot(dialogData.bagId)
				end,
			},
		},
		-- OnHiddenCallback clears the lock set by the hooked ZO_StackSplit_SplitItem
		-- This must fire BEFORE keybinds are restored to prevent re-triggering
		OnHiddenCallback = function(dialog)
			BETTERUI.Inventory._splitStackLock = nil
		end,
	})
end

--- Initializes the confirmation dialog for item destruction.
---
--- Purpose: Safety prompt before destroying items.
--- Mechanics:
--- - Registers `BETTERUI_CONFIRM_DESTROY_DIALOG`.
--- - Shows item link in main text.
--- - Calls `TryDestroyItem(..., true)` on confirmation.
---
function BETTERUI.Inventory.Class:InitializeConfirmDestroyDialog()
	BETTERUI.CIM.Dialogs.Register("BETTERUI_CONFIRM_DESTROY_DIALOG", {
		blockDirectionalInput = true,
		canQueue = true,
		gamepadInfo = {
			dialogType = GAMEPAD_DIALOGS.BASIC,
			allowRightStickPassThrough = true,
		},
		title = {
			text = function(dialog)
				return GetString(SI_DESTROY_ITEM_PROMPT_TITLE) or "Destroy Item"
			end,
		},
		mainText = {
			text = function(dialog)
				local link = dialog and dialog.data and dialog.data.itemLink
				if link and link ~= "" then
					return zo_strformat(GetString(SI_BETTERUI_DESTROY_CONFIRM_FORMAT), link)
				end
				return GetString(SI_BETTERUI_DESTROY_CONFIRM_GENERIC)
			end,
		},
		buttons = {
			{ keybind = "DIALOG_NEGATIVE", text = GetString(SI_DIALOG_CANCEL) },
			{
				keybind = "DIALOG_PRIMARY",
				text = GetString(SI_GAMEPAD_SELECT_OPTION),
				callback = function(dialog)
					local d = dialog and dialog.data
					if d and d.bagId and d.slotIndex then
						-- Force destruction on explicit user confirmation
						local destroyed = BETTERUI.Inventory.TryDestroyItem(d.bagId, d.slotIndex, true)
						-- Refresh lists shortly after to reflect removal
						if destroyed then
							BETTERUI.Inventory.Tasks:Schedule("destroyRefresh",
								BETTERUI.CIM.CONST.TIMING.LIST_DESTRUCTION_DELAY_MS, function()
									if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.RefreshItemList then
										GAMEPAD_INVENTORY:RefreshItemList()
									end
								end)
						end
					end
					ZO_Dialogs_ReleaseDialogOnButtonPress("BETTERUI_CONFIRM_DESTROY_DIALOG")
				end,
			},
		},
	})
end

--- Initializes the confirmation dialog for armory item destruction.
---
--- Purpose: Safety prompt before destroying armory-related items with 2-second cooldown.
--- Mechanics:
--- - Registers `ZO_GAMEPAD_CONFIRM_DESTROY_ARMORY_ITEM_DIALOG`.
--- - Uses native `RespondToDestroyRequest()` API.
--- - Includes 2-second cooldown on confirm button for safety.
---
function BETTERUI.Inventory.Class:InitializeConfirmDestroyArmoryItemDialog()
	local function ReleaseDialog(destroyItem)
		RespondToDestroyRequest(destroyItem == true)
		ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_CONFIRM_DESTROY_ARMORY_ITEM_DIALOG)
	end

	BETTERUI.CIM.Dialogs.Register(ZO_GAMEPAD_CONFIRM_DESTROY_ARMORY_ITEM_DIALOG, {
		blockDialogReleaseOnPress = true,
		canQueue = true,
		gamepadInfo = {
			dialogType = GAMEPAD_DIALOGS.BASIC,
			allowRightStickPassThrough = true,
		},
		setup = function(dialog)
			self.destroyConfirmText = nil
			dialog:setupFunc()
		end,
		noChoiceCallback = function(dialog)
			RespondToDestroyRequest(false)
		end,
		title = {
			text = SI_DIALOG_DESTROY_ARMORY_ITEM_TITLE,
		},
		mainText = {
			text = SI_GAMEPAD_ARMORY_CONFIRM_DESTROY_ITEM_BODY,
		},
		buttons = {
			{
				onShowCooldown = 2000,
				keybind = "DIALOG_PRIMARY",
				text = GetString(SI_YES),
				callback = function()
					ReleaseDialog(true)
				end,
			},
			{
				keybind = "DIALOG_NEGATIVE",
				text = GetString(SI_NO),
				callback = function()
					ReleaseDialog()
				end,
			},
		}
	})
end
