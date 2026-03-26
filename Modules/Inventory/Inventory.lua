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

-- Dialog names (namespaced to avoid global collision)
if not BETTERUI.Inventory.Dialogs then BETTERUI.Inventory.Dialogs = {} end
BETTERUI.Inventory.Dialogs.EQUIP_SLOT = "BETTERUI_EQUIP_SLOT_DIALOG"
-- Backward compatibility alias
BETTERUI_EQUIP_SLOT_DIALOG = BETTERUI.Inventory.Dialogs.EQUIP_SLOT

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
--- Initializes secure wheel hooks for the assignable utility wheel.
--- @return nil
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
--- @return nil
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



-- OnStateChanged extracted to Scene/InventorySceneLifecycle.lua
-- BETTERUI.Inventory.Class:OnStateChanged(oldState, newState)

--- Initializes the custom dialog for selecting equipment slots (e.g., Ring 1 vs Ring 2).
---
--- Purpose: Prompts the user when equipping items where the target slot is ambiguous.
--- Mechanics:
--- - Registers `BETTERUI.Inventory.Dialogs.EQUIP_SLOT`.
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
--- @return nil
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

	--- @return nil
	local function RefreshHeader()
		if not self.control:IsHidden() then
			self:RefreshHeader(BLOCK_TABBAR_CALLBACK)
		end
	end

	--- @return nil
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

	--- @param bagId number
	--- @param slotIndex number
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
--- Clears the text search UI and internal state.
--- @return nil
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

--- Refreshes the footer display.
--- @return nil
function BETTERUI.Inventory.Class:RefreshFooter()
	if BETTERUI.GenericFooter then
		BETTERUI.GenericFooter:Refresh()
	end
end

--- Selects the current category and switches to the appropriate list.
--- @return nil
function BETTERUI.Inventory.Class:Select()
	local catTarget = BETTERUI.Inventory.Utils.SafeGetTargetData(self.categoryList)
	if not catTarget or not catTarget.onClickDirection then
		self:SwitchActiveList(INVENTORY_ITEM_LIST)
	else
		self:SwitchActiveList(INVENTORY_CRAFT_BAG_LIST)
	end
end

--- Switches between item list and craft bag list.
--- @return nil
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
--- Creates a new parametric list for the inventory scene.
--- @param name string The name of the list
--- @param callbackParam any The callback parameter for list setup
--- @param listClass any The list class to use
--- @return table list The created list
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

--- Checks if the given inventory slot is locked.
--- @param inventorySlot table The inventory slot to check
--- @return boolean isLocked True if the slot is locked
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

-- BETTERUI_TryPlaceInventoryItemInEmptySlot, InitializeSplitStackDialog,
-- InitializeConfirmDestroyDialog, InitializeConfirmDestroyArmoryItemDialog
-- extracted to Dialogs/InventoryDialogs.lua


