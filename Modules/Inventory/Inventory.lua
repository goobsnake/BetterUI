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
         - Actions/QuickslotAction.lua - Quickslot assignment
         - Actions/ItemActionsDialog.lua - Y-menu customization
         - Keybinds/InventoryKeybinds.lua - Keybind strip
         - State/PositionManager.lua - Position save/restore
         - State/ListStateManager.lua - SwitchActiveList
Author: BetterUI Team
Last Modified: 2026-01-25
]]

local _

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
BETTERUI_EQUIP_SLOT_DIALOG = "BETTERUI_EQUIP_SLOT_PROMPT"

--------------------------------------------------------------------------------
-- COMPANION EQUIP PATCH
--------------------------------------------------------------------------------
-- Patches ZO_CompanionEquipment_Gamepad:TryEquipItem for bind-on-equip handling

-- TODO(MISSING): The EnsureCompanionEquipPatched function is referenced at line 85 but not defined
-- in this file. It should either be:
--   1. Defined locally in this file, or
--   2. Imported from the file where it's defined (Actions/EquipAction.lua?)
-- Currently this will cause a nil reference error.

local CreateSearchKeybindDescriptor = BETTERUI.Interface.CreateSearchKeybindDescriptor
local COMPANION_EQUIP_PATCH_EVENT_NAME = "BETTERUI_CompanionEquipPatch"
local COMPANION_EQUIP_PATCH_RETRY_MS = 400
local companionEquipPatchQueued = false
local companionEquipPatchRetryPending = false




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

-- Expose the patch helper so other initialization flows can trigger it regardless
BETTERUI.Inventory.EnsureCompanionEquipPatched = EnsureCompanionEquipPatched

-- InitializeQuickslotAssignDialog, ShowQuickslotAssignDialog extracted to Actions/QuickslotAction.lua
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
function BETTERUI.Inventory.Class:OnStateChanged(oldState, newState)
	if newState == SCENE_SHOWING then
		self:PerformDeferredInitialize()
		BETTERUI.CIM.SetTooltipWidth(BETTERUI_GAMEPAD_DEFAULT_PANEL_WIDTH)

		-- Mark when scene showed so we can skip redundant category refreshes during initial load
		self._sceneShowedTime = GetFrameTimeSeconds and GetFrameTimeSeconds() or 0

		--figure out which list to land on
		local listToActivate = self.previousListType or INVENTORY_CATEGORY_LIST
		-- We normally do not want to enter the gamepad inventory on the item list
		-- the exception is if we are coming back to the inventory, like from looting a container
		local wasOnStack = SCENE_MANAGER:WasSceneOnStack(ZO_GAMEPAD_INVENTORY_SCENE_NAME)
		if
			listToActivate == INVENTORY_ITEM_LIST and not wasOnStack
		then
			listToActivate = INVENTORY_CATEGORY_LIST
		end

		-- If returning from stacked scene (enchant dialog, etc.), restore position
		if wasOnStack and self.ToSavedPosition then
			self:ToSavedPosition()
		end

		-- switching the active list will handle activating/refreshing header, keybinds, etc.
		self:SwitchActiveList(listToActivate)

		self:ActivateHeader()

		-- TODO(DRY): The wykkydsToolbar visibility toggle is repeated 3 times in this function.
		-- Consider extracting to a shared utility: BETTERUI.Utils.SetExternalToolbarHidden(hidden)
		-- See also: Banking.lua:UpdateExternalAddons() for a similar pattern.
		if wykkydsToolbar then
			wykkydsToolbar:SetHidden(true)
		end

		ZO_InventorySlot_SetUpdateCallback(function()
			self:RefreshItemActions()
		end)
		-- search is handled via hold callbacks on X/Y; no separate A-based keybind group required
	elseif newState == SCENE_HIDING then
		ZO_InventorySlot_SetUpdateCallback(nil)
		self:Deactivate()
		self:DeactivateHeader()

		if wykkydsToolbar then
			wykkydsToolbar:SetHidden(false)
		end

		if self.callLaterLeftToolTip ~= nil then
			EVENT_MANAGER:UnregisterForUpdate(self.callLaterLeftToolTip)
			self.callLaterLeftToolTip = nil
		end
		-- search hold behavior is part of main keybind descriptors; nothing to remove here
		-- Save the current list position so it can be restored when the scene is shown again
		self:SaveListPosition()
	elseif newState == SCENE_HIDDEN then
		self:SwitchActiveList(nil)
		BETTERUI.CIM.SetTooltipWidth(BETTERUI_ZO_GAMEPAD_DEFAULT_PANEL_WIDTH)

		self.listWaitingOnDestroyRequest = nil
		self:TryClearNewStatusOnHidden()

		self:ClearActiveKeybinds()
		ZO_SavePlayerConsoleProfile()

		if wykkydsToolbar then
			wykkydsToolbar:SetHidden(false)
		end

		if self.callLaterLeftToolTip ~= nil then
			EVENT_MANAGER:UnregisterForUpdate(self.callLaterLeftToolTip)
			self.callLaterLeftToolTip = nil
		end
		-- Clear persistent search when leaving the inventory scene so it does
		-- not persist when the player backs out and later re-enters the scene.
		-- Use centralized helper to clear persistent search state when leaving scene
		if self.ClearTextSearch then
			self:ClearTextSearch()
		end
		-- nothing to remove for search hold behavior here
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

	self:SetListsUseTriggerKeybinds(true)

	self.categoryPositions = {}
	self.categoryCraftPositions = {}
	self.populatedCategoryPos = false
	self.populatedCraftPos = false
	self.isPrimaryWeapon = true

	self:InitializeCategoryList()
	self:InitializeHeader()
	self:InitializeCraftBagList()

	self:InitializeItemList()

	self:InitializeKeybindStrip()

	self:InitializeConfirmDestroyDialog()
	self:InitializeEquipSlotDialog()

	self:InitializeItemActions()
	self:InitializeActionsDialog()
	self:InitializeQuickslotAssignDialog()

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

		local currentList = self:GetCurrentList()
		if self.scene:IsShowing() then
			-- If an action dialog is open, keep the immediate update for correctness
			if ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
				self:OnUpdate() -- immediate to keep dialog/keybinds consistent
			else
				if currentList == self.itemList then
					self:RefreshKeybinds()
				end
				RefreshSelectedData()
				self:RefreshHeader(BLOCK_TABBAR_CALLBACK)
				-- Coalesce a category refresh so new tabs (Junk/Stolen) appear promptly
				-- BUT skip if we just opened the scene (within 200ms) since SwitchActiveList already refreshed
				local timeSinceShow = GetFrameTimeSeconds and (GetFrameTimeSeconds() - (self._sceneShowedTime or 0)) or
					999
				if not self._pendingCategoryListRefresh and timeSinceShow > 0.2 then
					self._pendingCategoryListRefresh = true
					-- Coalesce category refresh to prevent spam during rapid updates
					zo_callLater(function()
						self._pendingCategoryListRefresh = false
						if self.scene:IsShowing() then
							self:RefreshCategoryList()
						end
					end, 80)
				end
			end
		end
	end

	SHARED_INVENTORY:RegisterCallback("FullInventoryUpdate", OnInventoryUpdated)
	SHARED_INVENTORY:RegisterCallback("SingleSlotInventoryUpdate", OnInventoryUpdated)

	SHARED_INVENTORY:RegisterCallback("SingleQuestUpdate", OnInventoryUpdated)

	-- Ensure keybinds (including the Clear Search prompt) are updated once
	-- deferred initialization finishes. Some UI elements become visible only
	-- after a short delay; refreshing keybinds here prevents the Clear Search
	-- button from not appearing until the player scrolls the list.
	zo_callLater(function()
		if self.RefreshKeybinds then
			self:RefreshKeybinds()
		elseif self.mainKeybindStripDescriptor then
			KEYBIND_STRIP:UpdateKeybindButtonGroup(self.mainKeybindStripDescriptor)
			-- Ensure the main group is active on initial load to prevent missing shoulder navigation.
			if self.SetActiveKeybinds then
				self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
			end
			-- Additional delay to ensure main group activation sticks
			zo_callLater(function()
				if self.SetActiveKeybinds then
					self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
				end
			end, 40)
		end
	end, 60)

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
--- @param blockCallback boolean If true, prevents tab bar callbacks (used during internal updates).

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
--- @param listDescriptor table|string The list or list ID to switch to.

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
	ZO_Dialogs_RegisterCustomDialog(ZO_GAMEPAD_SPLIT_STACK_DIALOG, {
		blockDirectionalInput = true,

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

		OnSliderValueChanged = function(dialog, sliderControl, value)
			dialog.sliderValue1:SetText(dialog.data.stackSize - value)
			dialog.sliderValue2:SetText(value)
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
					CallSecureProtected("PickupInventoryItem", dialogData.bagId, dialogData.slotIndex, quantity)
					BETTERUI_TryPlaceInventoryItemInEmptySlot(dialogData.bagId)
					CALLBACK_MANAGER:FireCallbacks("BETTERUI_EVENT_SPLIT_STACK_DIALOG_FINISHED")
				end,
			},
		},
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
	ZO_Dialogs_RegisterCustomDialog("BETTERUI_CONFIRM_DESTROY_DIALOG", {
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
					return zo_strformat("Are you sure you want to destroy <<1>>? This cannot be undone.", link)
				end
				return "Are you sure you want to destroy this item? This cannot be undone."
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
							zo_callLater(function()
								if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.RefreshItemList then
									GAMEPAD_INVENTORY:RefreshItemList()
								end
							end, 120)
						end
					end
					ZO_Dialogs_ReleaseDialogOnButtonPress("BETTERUI_CONFIRM_DESTROY_DIALOG")
				end,
			},
		},
	})
end
