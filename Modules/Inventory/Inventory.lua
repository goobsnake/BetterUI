--[[
File: Modules/Inventory/Inventory.lua
Purpose: Core implementation of the BetterUI Inventory system.
         Subclasses ZO_GamepadInventory to overhaul the interface.
Architectural Notes:

         Decompose into smaller focused files:
           1. Inventory/Core/InventoryClass.lua - Class definition, initialization
           2. Inventory/Lists/ItemListManager.lua - Item list refresh/filter logic
           3. Inventory/Lists/CraftBagListManager.lua - Craft bag specific logic
           4. Inventory/Actions/EquipAction.lua - TryEquipItem and equip dialogs
           5. Inventory/Actions/QuickslotAction.lua - Quickslot assignment
           6. Inventory/Keybinds/InventoryKeybinds.lua - Keybind strip setup
           7. Inventory/State/PositionManager.lua - SaveListPosition/ToSavedPosition
         Target: Each file < 500 lines.
-- TODO(CRITICAL-DECOMPOSITION): This file is 4515 lines - THE WORST OFFENDER.
-- This is 9x the recommended maximum file size (500 lines).
-- NO developer can hold 4500 lines of code in their mental model.
-- Priority P0: Must decompose before adding ANY new features.
-- Proposed structure:
--   1. Inventory/Core/InventoryClass.lua (~400 lines) - Class skeleton, New, Initialize
--   2. Inventory/Lists/ItemListManager.lua (~600 lines) - RefreshItemList, sorting, filtering
--   3. Inventory/Lists/CraftBagListManager.lua (~400 lines) - Craft bag specific logic
--   4. Inventory/Lists/CategoryListManager.lua (~300 lines) - RefreshCategoryList, tab logic
--   5. Inventory/Actions/EquipAction.lua (~400 lines) - TryEquipItem, slot selection dialogs
--   6. Inventory/Actions/QuickslotAction.lua (~200 lines) - Quickslot assignment dialog
--   7. Inventory/Actions/ItemActionsDialog.lua (~300 lines) - "Y" menu customization
--   8. Inventory/Keybinds/InventoryKeybinds.lua (~500 lines) - All keybind definitions
--   9. Inventory/State/PositionManager.lua (~200 lines) - SaveListPosition, ToSavedPosition
--  10. Inventory/Tooltips/TooltipManager.lua (~200 lines) - UpdateItemLeftTooltip, etc.
-- Current violation: 4515 lines in single file.
Author: BetterUI Team
Last Modified: 2026-01-23
]]
-- gamepad inventory experience.
--
-- KEY FEATURES:
--
-- 1.  **Dual List Architecture**:
--     *   `itemList`: Handles the main backpack inventory (Weapons, Armor, Consumables, etc.).
--     *   `craftBagList`: Handles the ESO Plus Craft Bag (Alchemy, Blacksmithing, etc.).
--     *   Uses `SwitchActiveList` to toggle between them with sophisticated state management.
--
-- 2.  **Advanced List Management**:
--     *   `RefreshCategoryList`: dynamically rebuilds category tabs (including auto-hiding Junk/Stolen tabs).
--     *   `RefreshItemList` & `RefreshCraftBagList`: Rebuilds item lists with custom sorting, filtering, and caching.
--     *   **State Persistence**: `SaveListPosition` and `ToSavedPosition` ensure that when users switch
--         between categories (e.g. Weapons -> Armor -> Weapons), their scroll position and selection
--         are perfectly preserved.
--
-- 3.  **Custom Dialogs & Interactions**:
--     *   `BETTERUI_EQUIP_SLOT_DIALOG`: A smart dialog for equipping items, allowing choice between
--         Main Hand, Off Hand, Backup Main, Backup Off, and Ring slots.
--     *   `BETTERUI_QUICKSLOT_ASSIGN_DIALOG`: An embedded parametric dialog that lets users visually
--         assign items to the quickslot wheel.
--     *   `BETTERUI_CONFIRM_DESTROY_DIALOG`: A safer item destruction flow.
--     *   `HookActionDialog`: Deep integration with the Inventory Action ("Y") menu to inject custom options.
--
-- 4.  **Header Integration**:
--     *   Displays real-time currency (Gold, AP, Tel Var) and Bag Space in the header.
--     *   Integrates with `BETTERUI.GenericHeader` for tab navigation and carousel support.
--
-- 5.  **Search Integration**:
--     *   Integrates a text search input that filters both the inventory and craft bag.
--     *   Includes custom focus management to allow controller navigation to/from the search bar.
--
-- 6.  **Keybinds**:
--     *   Context-aware keybinds (`InitializeKeybindStrip`) that change based on the selected item
--         (e.g., showing "Equip", "Use", or "Assign" on the 'A' button).
--
-- 6.  **Keybinds**:
--     *   Context-aware keybinds (`InitializeKeybindStrip`) that change based on the selected item
--         (e.g., showing "Equip", "Use", or "Assign" on the 'A' button).
--
--------------------------------------------------------------------------------

local _

-------------------------------------------------------------------------------------------------
-- CONSTANTS & GLOBALS
-------------------------------------------------------------------------------------------------
-- BLOCK_TABBAR_CALLBACK: When passed to RefreshHeader(), prevents the header's tab bar
-- onSelectedChanged callback from firing. This avoids recursive refresh loops during
-- programmatic header updates (e.g., category changes, scene transitions).
--
-- ZO_GAMEPAD_INVENTORY_SCENE_NAME override: BetterUI uses its own inventory implementation,
-- but must hijack this global to ensure native scene references point to our custom scene.
-- Without this, ESO's internal GAMEPAD_INVENTORY references would route to the vanilla object.
-------------------------------------------------------------------------------------------------


-- TODO(GLOBAL-OVERRIDE): This ZO_GAMEPAD_INVENTORY_SCENE_NAME override hijacks a global.



-- Apply Class Mixins (from PositionManager, etc.)
if BETTERUI.Inventory.ClassMixins then
	for name, func in pairs(BETTERUI.Inventory.ClassMixins) do
		BETTERUI.Inventory.Class[name] = func
	end
end

-- Action mode constants for tracking inventory UI state
local CATEGORY_ITEM_ACTION_MODE = 1
local ITEM_LIST_ACTION_MODE = 2
local CRAFT_BAG_ACTION_MODE = 3

-- Timing constants for UI operations
-- Moved to BETTERUI.CONST.INVENTORY
-- local DIALOG_QUEUE_WORKAROUND_TIMEOUT_DURATION = 300
-- local INVENTORY_LEFT_TOOL_TIP_REFRESH_DELAY_MS = 300

-- List type identifiers for SwitchActiveList
local INVENTORY_CATEGORY_LIST = "categoryList"
local INVENTORY_ITEM_LIST = "itemList"
local INVENTORY_CRAFT_BAG_LIST = "craftBagList"
-- TODO(GLOBAL-DIALOG): This global dialog name could conflict with other addons.
-- Consider: BETTERUI.Inventory.EQUIP_SLOT_DIALOG = "BETTERUI_EQUIP_SLOT_PROMPT"
-- Then reference via the namespace instead of a global.
BETTERUI_EQUIP_SLOT_DIALOG = "BETTERUI_EQUIP_SLOT_PROMPT"

-- Slot data cache for GenerateFullSlotData optimization
local g_slotDataCache = {}
local g_slotDataCacheDirty = true

--[[
Function: InvalidateSlotDataCache
Description: Marks the inventory slot data cache as dirty to trigger a refresh on next access.
Rationale: Ensures UI consistency after inventory changes (loot, equip, destroy).
Mechanism: Sets g_slotDataCacheDirty to true and clears g_slotDataCache table.
]]


-- Cache methods extracted to Core/InventoryClass.lua
-- BETTERUI.Inventory.Class:InvalidateSlotDataCache
-- BETTERUI.Inventory.Class:GetCachedSlotData


-------------------------------------------------------------------------------------------------
-- HELPER FUNCTIONS
-------------------------------------------------------------------------------------------------
-- Utility functions used throughout the inventory module.
-------------------------------------------------------------------------------------------------

--- Wraps a value around min/max bounds for circular navigation.
---
--- Purpose: Utility for carousel-style index wrapping.
--- Mechanics: If value < 1, returns max. If value > max, returns 1.
--- References: Used by Tab Next/Prev handlers.
---
--- @param newValue number The value to wrap
--- @param maxValue number The maximum value (1 is implicit minimum)
--- @return number The wrapped value

-- Companion equip patch handling
local CreateSearchKeybindDescriptor = BETTERUI.Interface.CreateSearchKeybindDescriptor
local COMPANION_EQUIP_PATCH_EVENT_NAME = "BETTERUI_CompanionEquipPatch"
local COMPANION_EQUIP_PATCH_RETRY_MS = 400
local companionEquipPatchQueued = false
local companionEquipPatchRetryPending = false

-- Patches ZO_CompanionEquipment_Gamepad:TryEquipItem for bind-on-equip handling
local function AttemptCompanionEquipPatch()
	local class = _G["ZO_CompanionEquipment_Gamepad"]
	if not class then
		return false
	end
	if class._betterui_tryEquipPatched then
		return true
	end
	local orig = class.TryEquipItem
	if type(orig) ~= "function" then
		return false
	end
	class.TryEquipItem = function(self, inventorySlot)
		if self and self.selectedEquipSlot and inventorySlot then
			local sourceBag, sourceSlot = ZO_Inventory_GetBagAndIndex(inventorySlot)
			if sourceBag and sourceSlot then
				local function DoEquip()
					CallSecureProtected("RequestMoveItem", sourceBag, sourceSlot, BAG_COMPANION_WORN,
						self.selectedEquipSlot, 1)
				end
				if ZO_InventorySlot_WillItemBecomeBoundOnEquip(sourceBag, sourceSlot) then
					local itemDisplayQuality = GetItemDisplayQuality(sourceBag, sourceSlot)
					local itemDisplayQualityColor = GetItemQualityColor(itemDisplayQuality)
					ZO_Dialogs_ShowPlatformDialog("CONFIRM_EQUIP_ITEM", { onAcceptCallback = DoEquip },
						{ mainTextParams = { itemDisplayQualityColor:Colorize(GetItemName(sourceBag, sourceSlot)) } })
				else
					DoEquip()
				end
				return
			end
		end

		return orig(self, inventorySlot)
	end
	class._betterui_tryEquipPatched = true
	return true
end

local function EnsureCompanionEquipPatched()
	if AttemptCompanionEquipPatch() then
		if EVENT_MANAGER and EVENT_MANAGER.UnregisterForEvent then
			EVENT_MANAGER:UnregisterForEvent(COMPANION_EQUIP_PATCH_EVENT_NAME, EVENT_PLAYER_ACTIVATED)
		end
		companionEquipPatchQueued = false
		companionEquipPatchRetryPending = false
		return true
	end
	if EVENT_MANAGER and EVENT_MANAGER.RegisterForEvent and not companionEquipPatchQueued then
		companionEquipPatchQueued = true

		EVENT_MANAGER:RegisterForEvent(COMPANION_EQUIP_PATCH_EVENT_NAME, EVENT_PLAYER_ACTIVATED, function()
			companionEquipPatchQueued = false
			EnsureCompanionEquipPatched()
		end)
	end
	if not companionEquipPatchRetryPending and zo_callLater then
		companionEquipPatchRetryPending = true

		zo_callLater(function()
			companionEquipPatchRetryPending = false
			EnsureCompanionEquipPatched()
		end, COMPANION_EQUIP_PATCH_RETRY_MS)
	end
	return false
end

-- local function copied (and slightly edited for unequipped items!) from "inventoryutils_gamepad.lua"

-- Helper extracted to Core/InventoryClass.lua
-- BETTERUI.Inventory.Class:GetEquipSlotForEquipType


-- The below functions are included from ZO_GamepadInventory.lua








-- Helper: compute a stable key for a category entry so we can restore by key when categories are rebuilt
-- Extracted to State/PositionManager.lua
-- BETTERUI.Inventory.GetCategoryKey(categoryData)

-- Extracted to State/PositionManager.lua
-- BETTERUI.Inventory.FindCategoryIndexByKey(self, key)


-- Safe helper for GetTargetData calls (guards against lists without method)
local function SafeGetTargetData(list)
	if not list then return nil end
	if list.GetTargetData and type(list.GetTargetData) == "function" then
		return list:GetTargetData()
	end
	return list.selectedData
end

--- Restores the list position and selection from saved state.
---
--- Purpose: Handles both inventory and craft bag lists, ensuring the user returns to the exact spot they left.
--- Mechanics:
--- 1. Identifies if current category is Craft Bag vs BackPack.
--- 2. Switches valid list using SwitchActiveList logic.
--- 3. Retrieves saved index and optional UniqueID from storage.
--- 4. Restores position, giving priority to UniqueID match if the list has changed.
--- 5. Clamps index to valid bounds.
--- 6. Refreshes Tooltip.
--- References: Called by Tab Next/Prev and RefreshList.
---

-- State Management (SaveListPosition/ToSavedPosition) extracted to State/PositionManager.lua
-- Methods injected via Mixins


--- Build the category list UI and wire up selection/target callbacks
--- Responds to category selection by switching between item and craft bag lists
--- Initializes the category list (tabs) for the inventory.
--- Sets up templates, selection callbacks, and target change handlers.

-- InitializeCategoryList extracted to Lists/CategoryListManager.lua


--- Checks if the item list is empty for a given filter.
---
--- Purpose: Used to determine if a category tab should be shown.
--- Mechanics: Wraps SHARED_INVENTORY:IsFilteredSlotDataEmpty, excluding Junk items to prevent "ghost" categories.
--- References: Called during NewCategoryItem validation.
---
--- @param filteredEquipSlot number|nil The equip slot to filter by (optional).
--- @param nonEquipableFilterType number|nil The item filter type to check (optional).
--- @return boolean True if the list would be empty, false otherwise.

-- IsItemListEmpty extracted to Lists/ItemListManager.lua
-- BETTERUI.Inventory.Class:IsItemListEmpty(filteredEquipSlot, nonEquipableFilterType)


-- Robust check for any junk in the backpack using the shared inventory cache,
-- with a direct IsItemJunk fallback as a safety net.

-- HasAnyJunkInBackpack extracted to Lists/ItemListManager.lua
-- BETTERUI.Inventory.Class:HasAnyJunkInBackpack()


--- Attempts to equip the selected item.
---
--- Purpose: Handles item equipping logic with safety checks.
--- Mechanics:
--- 1. Checks BOE (Bind on Equip) status and Settings.Prompts dialog if needed.
--- 2. Determines target slot (Main/Off hand, Backup Bar) based on item type.
--- 3. Call `RequestMoveItem` via `CallSecureProtected`.
--- 4. Handles rings (Slot 1 vs 2).
--- 5. Handles Costumes vs Gear.
--- References: Called from "A" keybind (Equip).
---
--- @param inventorySlot table The data of the item to equip.
--- @param isCallingFromActionDialog boolean True if called from the actions dialog (delays dialogs slightly).


--- Adds a new category entry to the category list if it contains items.
---
--- Purpose: Dynamically populates the category bar.
--- Mechanics:
--- 1. Checks if items exist for the filter (via IsItemListEmpty).
--- 2. Checks for "New" items to tint the icon.
--- 3. Adds entry to both CategoryList (hidden logic) and Header (visual tab bar).
--- References: Called by RefreshCategoryList.
---
--- @param filterType number|nil The item filter type for the category.
--- @param iconFile string The path to the icon texture.
--- @param FilterFunct function|nil Optional custom filter function.

-- NewCategoryItem extracted to Lists/CategoryListManager.lua


--- Rebuilds the category list based on the current state (Inventory vs Craft Bag).
---
--- Purpose: Dynamically adds categories like "All", "Weapons", "Armor", enc.
--- Mechanics:
--- 1. Detects active list mode (CraftBag vs Inventory).
--- 2. For CraftBag: Adds fixed categories (Alchemy, Blacksmithing, etc.). Disables if locked.
--- 3. For Inventory: Adds categories only if they contain items (via NewCategoryItem).
--- 4. Handles "Equipped", "Stolen", "Junk", "Quest" visibility dynamically.
--- 5. Restores previous selection if possible.
--- References: Called by RefreshItemList.
---

-- RefreshCategoryList extracted to Lists/CategoryListManager.lua


--- Initializes the gamepad header, including the tab bar and currency display.
---
--- Purpose: Configures the top navigation bar.
--- Mechanics:
--- - Defines TabBar entries for "Inventory" and "Craft Bag".
--- - Sets up standard "Carousel" navigation callbacks.
--- - Initializes GenericHeader and GenericFooter components.
--- References: Called during Initialize.
---
function BETTERUI.Inventory.Class:InitializeHeader()
	local function UpdateTitleText()
		return GetString(
			self:GetCurrentList() == self.craftBagList and SI_BETTERUI_INV_ACTION_CB or SI_BETTERUI_INV_ACTION_INV
		)
	end

	local tabBarEntries = {
		{
			text = GetString(SI_GAMEPAD_INVENTORY_CATEGORY_HEADER),
			callback = function()
				self:SwitchActiveList(INVENTORY_CATEGORY_LIST)
			end,
		},
		{
			text = GetString(SI_GAMEPAD_INVENTORY_CRAFT_BAG_HEADER),
			callback = function()
				self:SwitchActiveList(INVENTORY_CRAFT_BAG_LIST)
			end,
		},
	}

	local isCarousel = BETTERUI.Settings.Modules["Inventory"].enableCarousel

	self.categoryHeaderData = {
		titleText = UpdateTitleText,
		tabBarEntries = tabBarEntries,
		-- Use onNext/onPrev callbacks instead of onSelectedChanged
		-- This pattern only fires on actual user navigation (LB/RB), not during list rebuilds
		-- which prevents keybind interference during equip operations and dialogs
		tabBarData = { parent = self, onNext = BETTERUI.Inventory.Utils.OnTabNext, onPrev = BETTERUI.Inventory.Utils.OnTabPrev },
		carouselConfig = {
			enabled = isCarousel,
		},
	}

	-- Header data will be built dynamically in RefreshHeader based on settings
	self.craftBagHeaderData = nil
	self.itemListHeaderData = nil

	BETTERUI.GenericHeader.Initialize(self.header, ZO_GAMEPAD_HEADER_TABBAR_CREATE)
	BETTERUI.GenericHeader.SetEquipText(self.header, self.isPrimaryWeapon)
	BETTERUI.GenericHeader.SetBackupEquipText(self.header, self.isPrimaryWeapon)

	BETTERUI.GenericHeader.Refresh(self.header, self.categoryHeaderData, ZO_GAMEPAD_HEADER_TABBAR_CREATE)

	-- Fix for non-clickable category icons: Ensure scrollList is explicitly linked to the UI control
	-- Even though GenericHeader.Refresh does this, we enforce it here to ensure it persists in the Inventory scene
	local tabBarControl = self.header:GetNamedChild("TabBar")
	if tabBarControl and self.header.tabBar then
		tabBarControl.scrollList = self.header.tabBar

		-- (Callback attached via categoryHeaderData now)
	end

	BETTERUI.GenericFooter.Initialize(self)
end

--[[
Function: BETTERUI.Inventory.Class:OnCategoryClicked
Description: Handles direct category icon clicks from the header.
Rationale: Bypasses the fragile scroll list callback mechanism (which fails in Inventory context) to ensure reliable category switching.
Mechanism:
1. Validates index and state.
2. Saves current position (SaveListPosition).
3. Updates categoryList state (selectedIndex, selectedData).
4. Triggers ToSavedPosition to switch content lists.
References: Called by BETTERUI_TabBar_OnCategoryIconClicked (ParametricScrollListTemplates.lua).
param: index (number) - The index of the clicked category (1-based).
]]
function BETTERUI.Inventory.Class:OnCategoryClicked(index)
	if not index or not self.categoryList then return end

	local count = #self.categoryList.dataList
	if index < 1 or index > count then return end

	-- Sync check: If we are already on this index, do nothing (or should we force refresh?)
	-- Usually clicking the active tab does nothing.
	if self.categoryList.selectedIndex == index then return end

	-- Save position of the OLD category before switching
	self:SaveListPosition()

	-- Update Inventory Class state to match the new selection
	self.categoryList.selectedIndex = index
	self.categoryList.targetSelectedIndex = index
	self.categoryList.selectedData = self.categoryList.dataList[index]
	self.categoryList.defaultSelectedIndex = index

	-- Update Title immediatley
	if self.categoryList.selectedData and self.categoryList.selectedData.text then
		BETTERUI.GenericHeader.SetTitleText(self.header, self.categoryList.selectedData.text)
	end

	-- Switch list and restore position for NEW category
	self:ToSavedPosition()
end

--- RefreshHeader extracted to Core/InventoryClass.lua
-- BETTERUI.Inventory.Class:RefreshHeader


--- RefreshCraftBagList extracted to Lists/CraftBagListManager.lua
-- BETTERUI.Inventory.Class:RefreshCraftBagList

--- Refreshes the item list based on the selected category and filter.
---
--- Purpose: Core function to populate the backpack view.
--- Mechanics:
--- 1. Checks for empty categories.
--- 2. Generates slot data from SHARED_INVENTORY based on filter (All, Weapons, etc.).
--- 3. Enhances item data with Custom Categories (e.g., "One-Handed", "Set Gear").
--- 4. Marks items as Equipped/Junk/Stolen for sorting.
--- 5. Caches expensive API calls (ItemType, SetInfo) for performance.
--- 6. Applies Text Search filtering.
--- 7. Sorts and populates the parametric list.
--- References: Called on Slot Updates and Category Changes.
---

-- RefreshItemList extracted to Lists/ItemListManager.lua


--- Configure the tooltip for the Craft Bag header.
---
--- Purpose: Shows subscription status explainers.
--- Mechanics: Checks HasCraftBagAccess() and displays relevant title/messaging.
---

-- LayoutCraftBagTooltip extracted to Lists/CraftBagListManager.lua


--- Toggles the tooltip detailed info mode.
---
--- Purpose: Switches between standard tooltip and "Comparison" or "Set info" view (if applicable).
--- Mechanics: Toggles logical flag `switchInfo` and triggers tooltip refresh.
--- References: Bound to Stick Click (usually).
---
function BETTERUI.Inventory.Class:SwitchInfo()
	self.switchInfo = not self.switchInfo
	if self.actionMode == ITEM_LIST_ACTION_MODE then
		self:UpdateItemLeftTooltip(self.itemList.selectedData)
	end
end

-- UpdateItemLeftTooltip extracted to Lists/ItemListManager.lua


--- Updates the right-side tooltip for item comparisons.
---
--- Purpose: Shows the "Equipped" item to compare against the selected item.
--- Mechanics:
--- 1. Determines the equip slot for the selected item type.
--- 2. Uses `GAMEPAD_TOOLTIPS:LayoutItemStatComparison` to render the comparison.
--- 3. Sets the "Currently Equipped" header.
--- References: Called by UpdateItemLeftTooltip.
---
--- @param selectedData table The data of the currently selected item.
-- UpdateRightTooltip extracted to Lists/ItemListManager.lua

-- UpdateRightTooltip extracted to Lists/ItemListManager.lua


-- InitializeItemList extracted to Lists/ItemListManager.lua


--- Initializes the craft bag list.
---
--- Purpose: Sets up the visual scroll list for the craft bag.
--- Mechanics:
--- - Uses specialized `BETTERUI.Inventory.CraftList` class.
--- - Configures selection callbacks to update tooltips and keybinds.
--- - Sets "No Item" text specifically for craft bag.
--- References: Called during Initialize.
---

-- InitializeCraftBagList extracted to Lists/CraftBagListManager.lua


--- Initializes the action slot manager for item interactions.
---
--- Purpose: Creates the helper object for "Y" button actions.
--- Mechanics: Instantiates `BETTERUI.Inventory.SlotActions`.
---
function BETTERUI.Inventory.Class:InitializeItemActions()
	self.itemActions = BETTERUI.Inventory.SlotActions:New(KEYBIND_STRIP_ALIGN_LEFT)
end

--- Initializes the actions dialog (Y-button menu).
---
--- Purpose: Configures the contextual action menu.
--- Mechanics:
--- 1. Registers `BETTERUI_EVENT_ACTION_DIALOG_SETUP/FINISH/CONFIRM` callbacks.
--- 2. **Setup**:
---    - Intercepts "Quickslot Assign" mode to show the wheel dialog instead.
---    - Populates standard actions (Use, Split, Link).
---    - Injects "Mark as Junk" / "Unmark as Junk" securely.
---    - Wraps engine "Lock/Unlock" actions to fix dialog release timing.
--- 3. **Confirm**:
---    - Handles Quickslot assignment logic.
---    - Handles "Destroy" logic (with custom "Quick Destroy" option).
---    - Handles "Link to Chat".
---    - Fallback to standard `DoSelectedAction`.
--- References: Called during Initialize.
---
function BETTERUI.Inventory.Class:InitializeActionsDialog()
	local function ActionDialogSetup(dialog, data)
		if self.scene:IsShowing() then
			-- If invoked for quickslot assignment, render the wheel options inside this proven parametric dialog
			if data and data.quickslotAssign and data.target then
				-- Title provided via dialog's dynamic title function; avoid overriding here
				local parametricList = dialog.info.parametricList
				ZO_ClearNumericallyIndexedTable(parametricList)

				local target = data.target
				local hasUnassign = false
				local assignedIndex = nil
				if FindActionSlotMatchingItem then
					assignedIndex =
						FindActionSlotMatchingItem(target.bagId, target.slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL)
					if assignedIndex then
						hasUnassign = true
						-- Ensure the Remove row text is visible; icon not required
						local removeText = GetString(SI_ITEM_ACTION_REMOVE)
						if not removeText or removeText == "" then
							removeText = "Remove"
						end
						local unassignEntry = ZO_GamepadEntryData:New(removeText)
						unassignEntry:SetIconTintOnSelection(true)
						local normalColor = ZO_NORMAL_TEXT or ZO_ColorDef:New(1, 1, 1, 1)
						local selectedColor = ZO_SELECTED_TEXT or ZO_ColorDef:New(1, 1, 1, 1)
						if unassignEntry.SetNameColors then
							unassignEntry:SetNameColors(normalColor, selectedColor)
						end
						unassignEntry.isUnassign = true
						unassignEntry.setup = ZO_SharedGamepadEntry_OnSetup
						table.insert(
							parametricList,
							{ template = "ZO_GamepadMenuEntryTemplate", entryData = unassignEntry }
						)
					end
				end

				local function slotLabel(idx)
					if idx == 4 then
						return "North"
					elseif idx == 5 then
						return "Northwest"
					elseif idx == 6 then
						return "West"
					elseif idx == 7 then
						return "Southwest"
					elseif idx == 8 then
						return "South"
					elseif idx == 1 then
						return "Southeast"
					elseif idx == 2 then
						return "East"
					elseif idx == 3 then
						return "Northeast"
					end
					return tostring(idx)
				end

				-- Clockwise ordering starting at North: N, NE, E, SE, S, SW, W, NW
				local orderedSlots = { 4, 3, 2, 1, 8, 7, 6, 5 }
				for _, slotIndex in ipairs(orderedSlots) do
					local icon = GetSlotTexture and GetSlotTexture(slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) or nil
					local lower = type(icon) == "string" and icon:lower() or nil
					-- Prefer a clearly visible empty-slot texture when the quickslot is unassigned
					if not icon or icon == "" or (lower and string.find(lower, "quickslot_empty", 1, true)) then
						-- Use a known-good icon that exists in this UI: the gamepad quickslot category icon
						icon = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_quickslot.dds"
					end
					local entryData = ZO_GamepadEntryData:New(slotLabel(slotIndex), icon)
					if entryData.AddIcon and icon then
						entryData:AddIcon(icon)
					end
					-- Flash all non-current slots; keep the currently assigned slot steady
					local isCurrent = assignedIndex ~= nil and (slotIndex == assignedIndex)
					local shouldFlash = not isCurrent
					entryData.alphaChangeOnSelection = shouldFlash
					entryData.showBarEvenWhenUnselected = shouldFlash
					entryData:SetIconTintOnSelection(shouldFlash)
					entryData.slotIndex = slotIndex
					entryData.setup = ZO_SharedGamepadEntry_OnSetup
					local templateName = isCurrent and "ZO_GamepadMenuEntryTemplate" or "ZO_GamepadItemEntryTemplate"
					table.insert(parametricList, { template = templateName, entryData = entryData })
				end

				dialog.quickslotTarget = target
				dialog:setupFunc()
				if dialog.entryList and dialog.entryList.SetSelectedIndexWithoutAnimation then
					local offset = hasUnassign and 1 or 0
					if assignedIndex then
						-- Map the quickslot index to its position in the ordered list
						local indexMap = {}
						for pos, idx in ipairs(orderedSlots) do
							indexMap[idx] = pos
						end
						local listPos = (indexMap[assignedIndex] or 1) + offset
						dialog.entryList:SetSelectedIndexWithoutAnimation(listPos, true, false)
					else
						dialog.entryList:SetSelectedIndexWithoutAnimation(hasUnassign and 2 or 1, true, false)
					end
				end
				return
			end

			-- Default actions list setup
			-- Title provided via dialog's dynamic title function; avoid overriding here
			dialog.entryList:SetOnSelectedDataChangedCallback(function(list, selectedData)
				self.itemActions:SetSelectedAction(selectedData and selectedData.action)
			end)

			local function MarkAsJunk()
				-- Silent junk toggle: skip craft bag and locked errors messaging
				if self.actionMode == CRAFT_BAG_ACTION_MODE then
					return
				end
				local target = SafeGetTargetData(GAMEPAD_INVENTORY.itemList)
				if not target then
					return
				end
				-- Respect engine gating: do nothing for companion items or items that cannot be marked as junk
				if IsItemPlayerLocked(target.bagId, target.slotIndex) then
					return
				end
				if not CanItemBeMarkedAsJunk(target.bagId, target.slotIndex) then
					return
				end
				local companionJunkEnabled = BETTERUI.Settings.Modules["Inventory"].enableCompanionJunk == true
				if not companionJunkEnabled and GetItemActorCategory(target.bagId, target.slotIndex) == GAMEPLAY_ACTOR_CATEGORY_COMPANION then
					return
				end
				-- Close the actions dialog to restore header/keybind focus
				if ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
					ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
				end
				SetItemIsJunk(target.bagId, target.slotIndex, true)
				-- Refresh immediately to restore UI/keybind state (avoid leaving stale focus)
				if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.RefreshItemList then
					GAMEPAD_INVENTORY:RefreshItemList()
				end
				if self and self.RefreshItemActions then
					self:RefreshItemActions()
				end
				if self and self.RefreshKeybinds then
					self:RefreshKeybinds()
				end
				-- Ensure the main keybind descriptor becomes active after toggling junk
				if self.SetActiveKeybinds and self.mainKeybindStripDescriptor then
					self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
					zo_callLater(function()
						if self.SetActiveKeybinds then
							self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
						end
					end, 40)
				end
			end
			-- Note: Lock/unlock callbacks are wrapped later (engine-provided entries are preserved)
			-- so we no longer inject or maintain synthetic lock/unlock helper functions here.
			local function UnmarkAsJunk()
				local target = SafeGetTargetData(GAMEPAD_INVENTORY.itemList)
				-- Close the actions dialog to restore header/keybind focus
				if ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
					ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
				end
				SetItemIsJunk(target.bagId, target.slotIndex, false)
				-- Refresh immediately to restore UI/keybind state (avoid leaving stale focus)
				if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.RefreshItemList then
					GAMEPAD_INVENTORY:RefreshItemList()
				end
				if self and self.RefreshItemActions then
					self:RefreshItemActions()
				end
				if self and self.RefreshKeybinds then
					self:RefreshKeybinds()
				end
				-- Ensure the main keybind descriptor becomes active after toggling junk
				if self.SetActiveKeybinds and self.mainKeybindStripDescriptor then
					self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
					zo_callLater(function()
						if self.SetActiveKeybinds then
							self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
						end
					end, 40)
				end
			end

			local parametricList = dialog.info.parametricList
			ZO_ClearNumericallyIndexedTable(parametricList)

			-- Removed injected "Assign Quickslot" action from Y menu per request

			self:RefreshItemActions()

			do
				local target = (self.actionMode == ITEM_LIST_ACTION_MODE)
					and (self.itemList and SafeGetTargetData(self.itemList))
					or nil
				local isLocked = false
				if target and target.bagId and target.slotIndex then
					isLocked = IsItemPlayerLocked(target.bagId, target.slotIndex)
				end
				local canMarkJunk = true
				if target and target.bagId and target.slotIndex then
					local companionJunkEnabled = BETTERUI.Settings.Modules["Inventory"].enableCompanionJunk == true
					canMarkJunk = CanItemBeMarkedAsJunk(target.bagId, target.slotIndex)
						and (companionJunkEnabled or GetItemActorCategory(target.bagId, target.slotIndex) ~= GAMEPLAY_ACTOR_CATEGORY_COMPANION)
				end
				-- Do not show Mark/Unmark as Junk for quest items (they are not junkable)
				local isQuestItem = false
				if target then
					-- Use the shared helper to determine if this is a quest item row
					if ZO_InventoryUtils_DoesNewItemMatchFilterType then
						isQuestItem = ZO_InventoryUtils_DoesNewItemMatchFilterType(target, ITEMFILTERTYPE_QUEST)
					else
						isQuestItem = (target.questIndex ~= nil) or (target.toolIndex ~= nil)
					end
				end

				if not isQuestItem then
					local tmpCat = SafeGetTargetData(self.categoryList)
					if tmpCat and tmpCat.showJunk ~= nil then
						-- Unmark should remain available even if locked
						self.itemActions.slotActions:AddSlotAction(SI_BETTERUI_ACTION_UNMARK_AS_JUNK, UnmarkAsJunk,
							"secondary")
					else
						-- Hide Mark as Junk when the item is locked
						if not isLocked and canMarkJunk then
							self.itemActions.slotActions:AddSlotAction(SI_BETTERUI_ACTION_MARK_AS_JUNK, MarkAsJunk,
								"secondary")
						end
					end
				end
				-- Ensure engine-provided Lock/Unlock callbacks release the dialog first.
				-- We do this by wrapping the discovered slot action callbacks rather than injecting synthetic entries.
				-- This preserves the engine entries (so they remain visible) while ensuring the dialog is released
				-- before the original behavior runs (which fixes header/keybind/tab focus issues).
				do
					local actions = self.itemActions:GetSlotActions()
					local numActions = actions:GetNumSlotActions()
					for i = 1, numActions do
						local action = actions:GetSlotAction(i)
						local actionName = actions:GetRawActionName(action)
						local isCompanionSceneShowing = SCENE_MANAGER and SCENE_MANAGER.scenes and
							SCENE_MANAGER.scenes["companionEquipmentGamepad"] and
							SCENE_MANAGER.scenes["companionEquipmentGamepad"]:IsShowing()
						if
							actionName == GetString(SI_ITEM_ACTION_MARK_AS_LOCKED)
							or actionName == GetString(SI_ITEM_ACTION_UNMARK_AS_LOCKED)
						then
							-- Find the corresponding entry inside the backing m_slotActions table and wrap its callback
							for j, slotAction in ipairs(actions.m_slotActions) do
								if slotAction and slotAction[1] == actionName then
									local origCallback = slotAction[2]
									slotAction[2] = function(...)
										if ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
											ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
										end
										-- Call original callback in protected context if it exists
										if origCallback then
											origCallback(...)
										end
										-- Immediately refresh item list and actions to restore UI/keybind state
										-- Immediately refresh item list and actions to restore UI/keybind state
										if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.RefreshItemList then
											GAMEPAD_INVENTORY:RefreshItemList()
										end
										if self and self.RefreshItemActions then
											self:RefreshItemActions()
										end
										if self and self.RefreshKeybinds then
											self:RefreshKeybinds()
										end
										-- Ensure the main keybind descriptor is active after lock/unlock flows
										if self.SetActiveKeybinds and self.mainKeybindStripDescriptor then
											self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
											zo_callLater(function()
												if self.SetActiveKeybinds then
													self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
												end
											end, 40)
										end
									end
									-- Only wrap the first matching entry (there should typically be one)
									break
								end
							end
						end
					end
				end
			end

			local actions = self.itemActions:GetSlotActions()
			local numActions = actions:GetNumSlotActions()

			for i = 1, numActions do
				local action = actions:GetSlotAction(i)
				local actionName = actions:GetRawActionName(action)

				-- In banking scenes (standard or house), hide Destroy/Delete entirely
				local hideDestroy = SCENE_MANAGER
					and SCENE_MANAGER.scenes
					and SCENE_MANAGER.scenes["gamepad_banking"]
					and SCENE_MANAGER.scenes["gamepad_banking"]:IsShowing()
				local isDestroy = (actionName == GetString(SI_ITEM_ACTION_DESTROY))
					or (SI_ITEM_ACTION_DELETE and actionName == GetString(SI_ITEM_ACTION_DELETE))
				-- Hide Mark as Junk for locked items
				local hideMarkJunk = false
				do
					local target = (self.actionMode == ITEM_LIST_ACTION_MODE)
						and (self.itemList and SafeGetTargetData(self.itemList))
						or nil
					if
						target
						and target.bagId
						and target.slotIndex
						and actionName == GetString(SI_ITEM_ACTION_MARK_AS_JUNK)
					then
						local actorCat = GetItemActorCategory(target.bagId, target.slotIndex)
						local canMark = CanItemBeMarkedAsJunk(target.bagId, target.slotIndex)
						local companionJunkEnabled = BETTERUI.Settings.Modules["Inventory"].enableCompanionJunk == true
						hideMarkJunk = IsItemPlayerLocked(target.bagId, target.slotIndex)
							or not canMark
							or (not companionJunkEnabled and actorCat == GAMEPLAY_ACTOR_CATEGORY_COMPANION)
					end
				end
				if not (hideDestroy and isDestroy) and not hideMarkJunk then
					local entryData = ZO_GamepadEntryData:New(actionName)
					-- Ensure consistent selection visuals for action rows
					entryData:SetIconTintOnSelection(true)
					entryData.action = action
					entryData.setup = ZO_SharedGamepadEntry_OnSetup

					local listItem = {
						template = "ZO_GamepadItemEntryTemplate",
						entryData = entryData,
					}
					table.insert(parametricList, listItem)
				end
			end

			dialog:setupFunc()
		end
	end
	local function ActionDialogFinish()
		if self.scene:IsShowing() then
			-- make sure to wipe out the keybinds added by
			self:SetActiveKeybinds(self.mainKeybindStripDescriptor)

			--restore the selected inventory item
			if self.actionMode == CATEGORY_ITEM_ACTION_MODE then
				--if we refresh item actions we will get a keybind conflict
				local currentList = self:GetCurrentList()
				if currentList then
					local targetData = SafeGetTargetData(currentList)
					if currentList == self.categoryList then
						targetData = self:GenerateItemSlotData(targetData)
					end
					self:SetSelectedItemUniqueId(targetData)
				end
			else
				self:RefreshItemActions()
			end
			--refresh so keybinds react to newly selected item
			self:RefreshKeybinds()

			self:OnUpdate()
			if self.actionMode == CATEGORY_ITEM_ACTION_MODE then
				self:RefreshCategoryList()
			end
		end
	end

	local function ActionDialogButtonConfirm(dialog)
		if not (self.scene and self.scene:IsShowing()) then return end

		-- Handle embedded quickslot assignment mode
		if dialog and dialog.data and dialog.data.quickslotAssign and dialog.entryList then
			local target = dialog.data.target or dialog.quickslotTarget
			if target then
				local quickslot_wheel = HOTBAR_CATEGORY_QUICKSLOT_WHEEL
				local selected = SafeGetTargetData(dialog.entryList)
				if selected and selected.isUnassign then
					local assigned = FindActionSlotMatchingItem and
						FindActionSlotMatchingItem(target.bagId, target.slotIndex, quickslot_wheel)
					if assigned then
						CallSecureProtected("ClearSlot", assigned, quickslot_wheel)
						if SOUNDS and PlaySound then
							PlaySound(SOUNDS.GAMEPAD_MENU_BACK)
						end
					end
				else
					local wheelSlotIndex = (selected and selected.slotIndex) or 4
					CallSecureProtected("SelectSlotItem", target.bagId, target.slotIndex, wheelSlotIndex, quickslot_wheel)
					if SOUNDS and PlaySound then
						PlaySound(SOUNDS.GAMEPAD_MENU_FORWARD)
					end
				end
				ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
				zo_callLater(function()
					if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.RefreshItemList then
						GAMEPAD_INVENTORY:RefreshItemList()
					end
				end, 150)
			end
			return
		end

		-- Handle BetterUI synthetic Destroy entry
		local selectedRow = dialog.entryList and SafeGetTargetData(dialog.entryList)
		if selectedRow and selectedRow.isBetterUIDestroy then
			local targetData
			if dialog and dialog.data and dialog.data.target then
				targetData = dialog.data.target
			elseif dialog.entryList and dialog.entryList.GetTargetData then
				targetData = SafeGetTargetData(dialog.entryList)
			else
				local actionMode = self and self.actionMode or nil
				if actionMode == ITEM_LIST_ACTION_MODE and self and self.itemList then
					targetData = SafeGetTargetData(self.itemList)
				elseif actionMode == CRAFT_BAG_ACTION_MODE and self and self.craftBagList then
					targetData = SafeGetTargetData(self.craftBagList)
				elseif self and self.categoryList then
					targetData = self:GenerateItemSlotData(SafeGetTargetData(self.categoryList))
				end
			end
			local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
			if bag and slot then
				ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
				local link = GetItemLink(bag, slot)
				local quick = BETTERUI and BETTERUI.Settings and BETTERUI.Settings.Modules and
					BETTERUI.Settings.Modules["Inventory"] and
					BETTERUI.Settings.Modules["Inventory"].quickDestroy == true
				if quick then
					BETTERUI.Inventory.TryDestroyItem(bag, slot, true)
				else
					ZO_Dialogs_ShowDialog("BETTERUI_CONFIRM_DESTROY_DIALOG",
						{ bagId = bag, slotIndex = slot, itemLink = link }, nil, true, true)
				end
			end
			return
		end

		-- Determine the selected action name (prefer dialog.itemActions, fallback to self.itemActions)
		local actionController = (dialog and dialog.itemActions) or (self and self.itemActions) or nil
		local selectedActionName = nil
		if actionController and actionController.selectedAction then
			selectedActionName = ZO_InventorySlotActions:GetRawActionName(actionController.selectedAction)
		end

		-- Intercept engine Destroy/Delete
		if selectedActionName == GetString(SI_ITEM_ACTION_DESTROY) or (SI_ITEM_ACTION_DELETE and selectedActionName == GetString(SI_ITEM_ACTION_DELETE)) then
			local targetData
			local actionMode = self.actionMode
			if actionMode == ITEM_LIST_ACTION_MODE then
				targetData = SafeGetTargetData(self.itemList)
			elseif actionMode == CRAFT_BAG_ACTION_MODE then
				targetData = SafeGetTargetData(self.craftBagList)
			else
				targetData = self:GenerateItemSlotData(SafeGetTargetData(self.categoryList))
			end
			local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
			if bag and slot then
				ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
				local link = GetItemLink(bag, slot)
				local quick = BETTERUI and BETTERUI.Settings and BETTERUI.Settings.Modules and
					BETTERUI.Settings.Modules["Inventory"] and
					BETTERUI.Settings.Modules["Inventory"].quickDestroy == true
				if quick then
					BETTERUI.Inventory.TryDestroyItem(bag, slot, true)
				else
					ZO_Dialogs_ShowDialog("BETTERUI_CONFIRM_DESTROY_DIALOG",
						{ bagId = bag, slotIndex = slot, itemLink = link }, nil, true, true)
				end
			end
			return
		end

		-- Link to chat handling; hide for companion scene
		if selectedActionName == GetString(SI_ITEM_ACTION_LINK_TO_CHAT) then
			local isCompanionSceneShowing = SCENE_MANAGER and SCENE_MANAGER.scenes and
				SCENE_MANAGER.scenes["companionEquipmentGamepad"] and
				SCENE_MANAGER.scenes["companionEquipmentGamepad"]:IsShowing()
			if isCompanionSceneShowing then
				return
			end
			local targetData
			local actionMode = self.actionMode
			if actionMode == ITEM_LIST_ACTION_MODE then
				targetData = SafeGetTargetData(self.itemList)
			elseif actionMode == CRAFT_BAG_ACTION_MODE then
				targetData = SafeGetTargetData(self.craftBagList)
			else
				targetData = self:GenerateItemSlotData(SafeGetTargetData(self.categoryList))
			end
			local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
			if bag and slot then
				local itemLink = GetItemLink(bag, slot)
				if itemLink then
					ZO_LinkHandler_InsertLink(zo_strformat("[<<2>>]", SI_TOOLTIP_ITEM_NAME, itemLink))
				end
			end
			return
		end

		-- Fallback to original action on the action controller (dialog or self)
		if actionController and actionController.DoSelectedAction then
			actionController:DoSelectedAction()
		end
	end
	CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_SETUP", ActionDialogSetup)
	CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_FINISH", ActionDialogFinish)
	CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM", ActionDialogButtonConfirm)
	-- Ensure our secure companion equip override is applied (with retries if needed)
	EnsureCompanionEquipPatched()
end

-- Expose the patch helper so other initialization flows can trigger it regardless
BETTERUI.Inventory.EnsureCompanionEquipPatched = EnsureCompanionEquipPatched

--- Initializes the custom dialog for visual quickslot assignment.
---
--- Purpose: Provides a visual wheel selection for assigning items to quickslots.
--- Mechanics:
--- - Defines the "Wheel" slots (N, NE, E, etc.).
--- - Checks currently assigned slot to pre-select it.
--- - Adds "Remove Assignment" option if needed.
--- References: Called during Initialize.
---


--- Displays the quickslot assignment dialog for a given item.
---
--- Purpose: Triggers the quickslot assignment flow.
--- Mechanics:
--- 1. Closes any existing Equip dialogs.
--- 2. Directly shows the "Y-Action" menu in "Quickslot Mode".
--- 3. If that fails to show after a single frame delay, falls back to the custom dialog.
---
--- @param bagId number The bag ID of the item.
--- @param slotIndex number The slot index of the item.


--- Attempts to destroy an item, dealing with junk status and user confirmation settings.
---
--- Purpose: Safer replacement for `DestroyItem`.
--- Mechanics:
--- 1. Checks if item is Junk or `force` flag is true.
--- 2. If so, destroys immediately (fixing sound and refreshing cache).
--- 3. Returns true if destroyed, false if confirmation (UI) is needed.
--- References: Called by Hooked Destroy and Action Dialog.
---
--- @param bagId number The bag ID of the item.
--- @param slotIndex number The slot index of the item.
--- @param force boolean If true, bypasses junk checks (used when user has explicitly confirmed destruction).
--- @return boolean True if the item was destroyed, false otherwise.


--- Hooks the native destroy logic (X button in some contexts).
---
--- Purpose: Redirects engine destruction calls to `TryDestroyItem`.
--- Mechanics: Overwrites `ZO_InventorySlot_InitiateDestroyItem` with a wrapper that checks `quickDestroy` settings.
--- References: Called during Initialize.
---


--- Hooks the native Y-button Action Dialog.
---
--- Purpose: Replaces or extends the `ZO_GAMEPAD_INVENTORY_ACTION_DIALOG`.
--- Mechanics:
--- - Registers a **custom** dialog with the **same name** as the engine's dialog (`ZO_GAMEPAD_INVENTORY_ACTION_DIALOG`).
--- - This effectively overrides the native dialog definition.
--- - Implements custom `setup` to handle:
---   - Quickslot Assignment (embedded).
---   - Safe "Destroy" (BetterUI replacement).
---   - "Link to Chat" (safety checks).
--- - Implements custom `buttons` (Select/Cancel) to route actions correctly.
--- References: Called during Initialize.
---


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
		if
			listToActivate == INVENTORY_ITEM_LIST and not SCENE_MANAGER:WasSceneOnStack(ZO_GAMEPAD_INVENTORY_SCENE_NAME)
		then
			listToActivate = INVENTORY_CATEGORY_LIST
		end

		-- switching the active list will handle activating/refreshing header, keybinds, etc.
		self:SwitchActiveList(listToActivate)

		self:ActivateHeader()

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
		pcall(function()
			self:SaveListPosition()
		end)
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
		pcall(function()
			self:SaveListPosition()
		end)
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
function BETTERUI.Inventory.Class:InitializeEquipSlotDialog()
	local dialog = ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.BASIC)

	local function ReleaseDialog(data, mainSlot)
		local equipType = data[1].dataSource.equipType

		local bound = IsItemBound(data[1].dataSource.bagId, data[1].dataSource.slotIndex)
		local equipItemLink = GetItemLink(data[1].dataSource.bagId, data[1].dataSource.slotIndex)
		local bindType = GetItemLinkBindType(equipItemLink)

		local equipItemCallback = function()
			if equipType == EQUIP_TYPE_ONE_HAND then
				if mainSlot then
					CallSecureProtected(
						"RequestMoveItem",
						data[1].dataSource.bagId,
						data[1].dataSource.slotIndex,
						BAG_WORN,
						data[2] and EQUIP_SLOT_MAIN_HAND or EQUIP_SLOT_BACKUP_MAIN,
						1
					)
				else
					CallSecureProtected(
						"RequestMoveItem",
						data[1].dataSource.bagId,
						data[1].dataSource.slotIndex,
						BAG_WORN,
						data[2] and EQUIP_SLOT_OFF_HAND or EQUIP_SLOT_BACKUP_OFF,
						1
					)
				end
			elseif equipType == EQUIP_TYPE_MAIN_HAND or equipType == EQUIP_TYPE_TWO_HAND then
				CallSecureProtected(
					"RequestMoveItem",
					data[1].dataSource.bagId,
					data[1].dataSource.slotIndex,
					BAG_WORN,
					data[2] and EQUIP_SLOT_MAIN_HAND or EQUIP_SLOT_BACKUP_MAIN,
					1
				)
			elseif equipType == EQUIP_TYPE_OFF_HAND then
				CallSecureProtected(
					"RequestMoveItem",
					data[1].dataSource.bagId,
					data[1].dataSource.slotIndex,
					BAG_WORN,
					data[2] and EQUIP_SLOT_OFF_HAND or EQUIP_SLOT_BACKUP_OFF,
					1
				)
			elseif equipType == EQUIP_TYPE_POISON then
				CallSecureProtected(
					"RequestMoveItem",
					data[1].dataSource.bagId,
					data[1].dataSource.slotIndex,
					BAG_WORN,
					data[2] and EQUIP_SLOT_POISON or EQUIP_SLOT_BACKUP_POISON,
					1
				)
			elseif equipType == EQUIP_TYPE_RING then
				if mainSlot then
					CallSecureProtected(
						"RequestMoveItem",
						data[1].dataSource.bagId,
						data[1].dataSource.slotIndex,
						BAG_WORN,
						EQUIP_SLOT_RING1,
						1
					)
				else
					CallSecureProtected(
						"RequestMoveItem",
						data[1].dataSource.bagId,
						data[1].dataSource.slotIndex,
						BAG_WORN,
						EQUIP_SLOT_RING2,
						1
					)
				end
			end
		end

		ZO_Dialogs_ReleaseDialogOnButtonPress(BETTERUI_EQUIP_SLOT_DIALOG)

		if
			not bound
			and bindType == BIND_TYPE_ON_EQUIP
			and BETTERUI.Settings.Modules["Inventory"].bindOnEquipProtection
		then
			zo_callLater(function()
				ZO_Dialogs_ShowPlatformDialog(
					"CONFIRM_EQUIP_BOE",
					{ callback = equipItemCallback },
					{ mainTextParams = { equipItemLink } }
				)
			end, DIALOG_QUEUE_WORKAROUND_TIMEOUT_DURATION)
		else
			equipItemCallback()
		end
	end
	local function GetDialogSwitchButtonText(isPrimary)
		return GetString(SI_BETTERUI_INV_SWITCH_EQUIPSLOT)
	end

	local function GetDialogMainText(dialog)
		local equipType = dialog.data[1].dataSource.equipType
		local itemName = GetItemName(dialog.data[1].dataSource.bagId, dialog.data[1].dataSource.slotIndex)
		local itemLink = GetItemLink(dialog.data[1].dataSource.bagId, dialog.data[1].dataSource.slotIndex)
		local itemQuality = GetItemLinkFunctionalQuality(itemLink)
		local itemColor = GetItemQualityColor(itemQuality)
		itemName = itemColor:Colorize(itemName)
		local str = ""
		local weaponChoice = GetString(SI_BETTERUI_INV_EQUIPSLOT_MAIN)
		if not dialog.data[2] then
			weaponChoice = GetString(SI_BETTERUI_INV_EQUIPSLOT_BACKUP)
		end
		if equipType == EQUIP_TYPE_ONE_HAND then
			--choose Main/Off hand, Primary/Secondary weapon
			str = zo_strformat(GetString(SI_BETTERUI_INV_EQUIP_ONE_HAND_WEAPON), itemName, weaponChoice)
		elseif
			equipType == EQUIP_TYPE_MAIN_HAND
			or equipType == EQUIP_TYPE_OFF_HAND
			or equipType == EQUIP_TYPE_TWO_HAND
			or equipType == EQUIP_TYPE_POISON
		then
			--choose Primary/Secondary weapon
			str = zo_strformat(GetString(SI_BETTERUI_INV_EQUIP_OTHER_WEAPON), itemName, weaponChoice)
		elseif equipType == EQUIP_TYPE_RING then
			--choose which rint slot
			str = zo_strformat(GetString(SI_BETTERUI_INV_EQUIP_RING), itemName)
		end
		return str
	end

	ZO_Dialogs_RegisterCustomDialog(BETTERUI_EQUIP_SLOT_DIALOG, {
		blockDialogReleaseOnPress = true,
		gamepadInfo = {
			dialogType = GAMEPAD_DIALOGS.BASIC,
			allowRightStickPassThrough = true,
		},
		setup = function()
			dialog.setupFunc(dialog)
		end,
		title = {
			text = GetString(SI_BETTERUI_INV_EQUIPSLOT_TITLE),
		},
		mainText = {
			text = function(dialog)
				return GetDialogMainText(dialog)
			end,
		},
		buttons = {
			{
				keybind = "DIALOG_PRIMARY",
				text = function(dialog)
					local equipType = dialog.data[1].dataSource.equipType
					if equipType == EQUIP_TYPE_ONE_HAND then
						--choose Main/Off hand, Primary/Secondary weapon
						return GetString(SI_BETTERUI_INV_EQUIP_PROMPT_MAIN)
					elseif
						equipType == EQUIP_TYPE_MAIN_HAND
						or equipType == EQUIP_TYPE_OFF_HAND
						or equipType == EQUIP_TYPE_TWO_HAND
						or equipType == EQUIP_TYPE_POISON
					then
						--choose Primary/Secondary weapon
						return GetString(SI_BETTERUI_INV_EQUIP)
					elseif equipType == EQUIP_TYPE_RING then
						--choose which ring slot
						return GetString(SI_BETTERUI_INV_FIRST_SLOT)
					end
					return ""
				end,
				callback = function()
					ReleaseDialog(dialog.data, true)
				end,
			},
			{
				keybind = "DIALOG_SECONDARY",
				text = function(dialog)
					local equipType = dialog.data[1].dataSource.equipType
					if equipType == EQUIP_TYPE_ONE_HAND then
						--choose Main/Off hand, Primary/Secondary weapon
						return GetString(SI_BETTERUI_INV_EQUIP_PROMPT_BACKUP)
					elseif
						equipType == EQUIP_TYPE_MAIN_HAND
						or equipType == EQUIP_TYPE_OFF_HAND
						or equipType == EQUIP_TYPE_TWO_HAND
						or equipType == EQUIP_TYPE_POISON
					then
						--choose Primary/Secondary weapon
						return ""
					elseif equipType == EQUIP_TYPE_RING then
						--choose which rint slot
						return GetString(SI_BETTERUI_INV_SECOND_SLOT)
					end
					return ""
				end,
				visible = function(dialog)
					local equipType = dialog.data[1].dataSource.equipType
					if equipType == EQUIP_TYPE_ONE_HAND or equipType == EQUIP_TYPE_RING then
						return true
					end
					return false
				end,
				callback = function(dialog)
					ReleaseDialog(dialog.data, false)
				end,
			},
			{
				keybind = "DIALOG_TERTIARY",
				text = function(dialog)
					return GetDialogSwitchButtonText(dialog.data[2])
				end,
				visible = function(dialog)
					-- Hide switch bar button if player hasn't unlocked weapon swap
					if not (GetUnitLevel("player") >= GetWeaponSwapUnlockedLevel()) then
						return false
					end
					local equipType = dialog.data[1].dataSource.equipType
					return equipType ~= EQUIP_TYPE_RING
				end,
				callback = function(dialog)
					--switch weapon
					dialog.data[2] = not dialog.data[2]

					--update inventory window's header
					GAMEPAD_INVENTORY.isPrimaryWeapon = dialog.data[2]

					GAMEPAD_INVENTORY:RefreshHeader()

					--update dialog
					ZO_GenericGamepadDialog_RefreshText(
						dialog,
						dialog.headerData.titleText,
						GetDialogMainText(dialog),
						warningText
					)
					ZO_GenericGamepadDialog_RefreshKeybinds(dialog)
				end,
			},
			{
				keybind = "DIALOG_NEGATIVE",
				alignment = KEYBIND_STRIP_ALIGN_RIGHT,
				text = SI_DIALOG_CANCEL,
				callback = function()
					ZO_Dialogs_ReleaseDialogOnButtonPress(BETTERUI_EQUIP_SLOT_DIALOG)
				end,
			},
		},
	})
end

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

		if self.actionMode == ITEM_LIST_ACTION_MODE then
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
		elseif self.actionMode == CRAFT_BAG_ACTION_MODE then
			self:RefreshCraftBagList()
			self:RefreshItemActions()
		else -- CATEGORY_ITEM_ACTION_MODE
			self:UpdateCategoryLeftTooltip(SafeGetTargetData(self.categoryList))
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

	self:SetSelectedItemUniqueId(self:GenerateItemSlotData(SafeGetTargetData(self.categoryList)))
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
		pcall(function()
			BETTERUI.Interface.Window.ClearSearchText(self)
		end)
	elseif self.ClearSearchText then
		pcall(function()
			self:ClearSearchText()
		end)
	end
end

function BETTERUI.Inventory.Class:RefreshFooter()
	if BETTERUI.GenericFooter then
		BETTERUI.GenericFooter:Refresh()
	end
end

function BETTERUI.Inventory.Class:Select()
	local catTarget = SafeGetTargetData(self.categoryList)
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
function BETTERUI.Inventory.Class:SwitchActiveList(listDescriptor)
	if listDescriptor == self.currentListType then
		return
	end

	-- Save the current list position before switching so positions are restored correctly later
	if self.currentListType then
		pcall(function()
			self:SaveListPosition()
		end)
	end

	self.previousListType = self.currentListType
	self.currentListType = listDescriptor

	if self.previousListType then
		self.listWaitingOnDestroyRequest = nil
		self:TryClearNewStatusOnHidden()
		-- Note: ZO_SavePlayerConsoleProfile removed here; only called on scene hide for performance
	end

	GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
	GAMEPAD_TOOLTIPS:Reset(GAMEPAD_RIGHT_TOOLTIP)

	if listDescriptor == INVENTORY_CATEGORY_LIST then
		listDescriptor = INVENTORY_ITEM_LIST
	elseif listDescriptor ~= INVENTORY_ITEM_LIST and listDescriptor ~= INVENTORY_CATEGORY_LIST then
		listDescriptor = INVENTORY_CRAFT_BAG_LIST
	end
	if self.scene:IsShowing() then
		if listDescriptor == INVENTORY_ITEM_LIST then
			self:SetCurrentList(self.itemList)
			self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
			self:RefreshCategoryList()

			-- ALWAYS restore saved inventory category when switching to inventory
			local targetIndex = 1
			if self.savedInventoryCategoryKey then
				local idx = BETTERUI.Inventory.FindCategoryIndexByKey(self, self.savedInventoryCategoryKey)
				if idx then targetIndex = idx end
			end
			-- Validate target is an inventory category, otherwise find first inventory category
			if not self.categoryList.dataList[targetIndex] or self.categoryList.dataList[targetIndex].onClickDirection then
				for i, d in ipairs(self.categoryList.dataList) do
					if not d.onClickDirection then
						targetIndex = i
						break
					end
				end
			end
			self.categoryList:SetSelectedIndexWithoutAnimation(zo_clamp(targetIndex, 1, #self.categoryList.dataList),
				true, false)

			-- Sync header tab - pass true for dontCallSelectedDataChangedCallback to avoid double refresh
			if self.header and self.header.tabBar then
				self.header.tabBar:SetSelectedIndexWithoutAnimation(self.categoryList.selectedIndex or 1, true, true)
				-- Force carousel to update visual positions
				if self.header.tabBar.UpdateAnchors then
					self.header.tabBar:UpdateAnchors(self.categoryList.selectedIndex or 1, true, false)
				end
			end

			-- Refresh and restore item position
			self:RefreshItemList()
			local key = BETTERUI.Inventory.GetCategoryKey(self.categoryList.selectedData)
			local itemIndex = 1
			-- Only restore saved position if one exists for this category
			if key and self.savedInventoryPositionsByKey and self.savedInventoryPositionsByKey[key] then
				itemIndex = self.savedInventoryPositionsByKey[key]
				-- Prefer unique ID restoration
				if self.savedInventorySelectedItemUniqueByKey and self.savedInventorySelectedItemUniqueByKey[key] then
					local uid = self.savedInventorySelectedItemUniqueByKey[key]
					local dataList = self.itemList.list and self.itemList.list.dataList or self.itemList.dataList
					if dataList then
						for i, entry in ipairs(dataList) do
							if entry and entry.uniqueId == uid then
								itemIndex = i
								break
							end
						end
					end
				end
			end
			local invDataList = self.itemList.list and self.itemList.list.dataList or self.itemList.dataList
			if invDataList and #invDataList > 0 then
				self.itemList:SetSelectedIndexWithoutAnimation(zo_clamp(itemIndex, 1, #invDataList), true, false)
			end

			self:SetSelectedItemUniqueId(SafeGetTargetData(self.itemList))
			self.actionMode = ITEM_LIST_ACTION_MODE
			self:RefreshItemActions()
			self:RefreshHeader(BLOCK_TABBAR_CALLBACK)

			-- Update header title to match the restored category (AFTER RefreshHeader which sets generic title)
			local selectedCatData = self.categoryList.selectedData
			if selectedCatData and selectedCatData.text then
				BETTERUI.GenericHeader.SetTitleText(self.header, selectedCatData.text)
			end

			self:UpdateItemLeftTooltip(self.itemList.selectedData)
		elseif listDescriptor == INVENTORY_CRAFT_BAG_LIST then
			self:SetCurrentList(self.craftBagList)
			self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
			self:RefreshCategoryList()

			-- ALWAYS restore saved craft bag category when switching to craft bag
			local targetIndex = 1
			if self.savedCraftBagCategoryKey then
				local idx = BETTERUI.Inventory.FindCategoryIndexByKey(self, self.savedCraftBagCategoryKey)
				if idx then targetIndex = idx end
			end
			-- Validate target is a craft bag category, otherwise find first craft bag category
			if not self.categoryList.dataList[targetIndex] or not self.categoryList.dataList[targetIndex].onClickDirection then
				for i, d in ipairs(self.categoryList.dataList) do
					if d.onClickDirection then
						targetIndex = i
						break
					end
				end
			end
			self.categoryList:SetSelectedIndexWithoutAnimation(zo_clamp(targetIndex, 1, #self.categoryList.dataList),
				true, false)

			-- Sync header tab - pass true for dontCallSelectedDataChangedCallback to avoid double refresh
			if self.header and self.header.tabBar then
				local headerTabBar = self.header.tabBar
				local idx = self.categoryList.selectedIndex or 1
				headerTabBar:SetSelectedIndexWithoutAnimation(idx, true, true)
				-- Force carousel to update visual positions
				if headerTabBar.UpdateAnchors then
					headerTabBar:UpdateAnchors(idx, true, false)
				end
			end

			-- Refresh and restore item position
			self:RefreshCraftBagList()
			local key = BETTERUI.Inventory.GetCategoryKey(self.categoryList.selectedData)
			local itemIndex = 1
			-- Only restore saved position if one exists for this category
			if key and self.savedCraftBagPositionsByKey and self.savedCraftBagPositionsByKey[key] then
				itemIndex = self.savedCraftBagPositionsByKey[key]
				-- Prefer unique ID restoration
				if self.savedCraftBagSelectedItemUniqueByKey and self.savedCraftBagSelectedItemUniqueByKey[key] then
					local uid = self.savedCraftBagSelectedItemUniqueByKey[key]
					local dataList = self.craftBagList.list and self.craftBagList.list.dataList or
						self.craftBagList.dataList
					if dataList then
						for i, entry in ipairs(dataList) do
							if entry and entry.uniqueId == uid then
								itemIndex = i
								break
							end
						end
					end
				end
			end
			local craftDataList = self.craftBagList.list and self.craftBagList.list.dataList or
				self.craftBagList.dataList
			if craftDataList and #craftDataList > 0 then
				-- craftBagList wraps an inner list; call SetSelectedIndexWithoutAnimation on the inner list
				local innerList = self.craftBagList.list or self.craftBagList
				if innerList.SetSelectedIndexWithoutAnimation then
					innerList:SetSelectedIndexWithoutAnimation(zo_clamp(itemIndex, 1, #craftDataList), true, false)
				end
			end

			self:SetSelectedItemUniqueId(SafeGetTargetData(self.craftBagList))
			self.actionMode = CRAFT_BAG_ACTION_MODE
			self:RefreshItemActions()
			self:RefreshHeader()

			-- Update header title to match the restored category (AFTER RefreshHeader which sets generic title)
			local selectedCatData = self.categoryList.selectedData
			if selectedCatData and selectedCatData.text then
				BETTERUI.GenericHeader.SetTitleText(self.header, selectedCatData.text)
			end

			self:LayoutCraftBagTooltip(GAMEPAD_LEFT_TOOLTIP)
		end
		self:RefreshKeybinds()
	else
		self.actionMode = nil
	end
end

--- Activates the generic header control.
---
--- Purpose: Sets focus to the header.
--- Mechanics: Calls `ZO_GamepadGenericHeader_Activate` and syncs the tab bar selection.
---
function BETTERUI.Inventory.Class:ActivateHeader()
	ZO_GamepadGenericHeader_Activate(self.header)
	self.header.tabBar:SetSelectedIndexWithoutAnimation(self.categoryList.selectedIndex, true, false)
end

--- Override header-enter lifecycle to auto-focus the text search when the header is entered.
---
--- Purpose: Provides seamless search interaction.
--- Mechanics:
--- - Activates `textSearchHeaderFocus` if present.
--- - Updates BetterUI Search state.
---
function BETTERUI.Inventory.Class:OnEnterHeader()
	if ZO_GamepadInventory and ZO_GamepadInventory.OnEnterHeader then
		ZO_GamepadInventory.OnEnterHeader(self)
	else
		ZO_Gamepad_ParametricList_Screen.OnEnterHeader(self)
	end

	if self.textSearchHeaderControl and not self.textSearchHeaderControl:IsHidden() then
		if self.textSearchHeaderFocus and not self.textSearchHeaderFocus:IsActive() then
			self.textSearchHeaderFocus:Activate()
		end
		if self.SetTextSearchFocused then
			self:SetTextSearchFocused(true)
		end
	end
end

--- Override header-leave lifecycle.
---
--- Purpose: Clean up search focus and restore context.
--- Mechanics:
--- - Deactivates `textSearchHeaderFocus`.
--- - Dequeues callbacks to restore header keybinds.
---
function BETTERUI.Inventory.Class:OnLeaveHeader()
	if ZO_GamepadInventory and ZO_GamepadInventory.OnLeaveHeader then
		ZO_GamepadInventory.OnLeaveHeader(self)
	else
		ZO_Gamepad_ParametricList_Screen.OnLeaveHeader(self)
	end

	if self.textSearchHeaderFocus and self.textSearchHeaderFocus:IsActive() then
		self.textSearchHeaderFocus:Deactivate()
	end

	zo_callLater(function()
		if self.scene and self.scene:IsShowing() then
			pcall(function()
				self:EnsureHeaderKeybindsActive()
			end)
		end
	end, 0)
end

function BETTERUI.Inventory.Class:EnsureHeaderKeybindsActive()
	local tabBar = self.header and self.header.tabBar
	if tabBar then
		-- Ensure the tabBar is active so LB/RB navigation works
		if tabBar.Activate and not tabBar.active then
			tabBar:Activate()
		end
		-- Ensure keybinds are registered
		if tabBar.keybindStripDescriptor then
			BETTERUI.Interface.EnsureKeybindGroupAdded(tabBar.keybindStripDescriptor)
		end
	end
end

--- Exits the text search focus mode.
---
--- Purpose: Returns control to the main list navigation.
--- Mechanics:
--- 1. Removes Search Keybinds.
--- 2. Restores Main Keybinds.
--- 3. Deactivates Search Focus.
--- 4. Activates Current List.
--- 5. Optionally selects top result if configured.
---
function BETTERUI.Inventory.Class:ExitSearchFocus()
	-- Remove search keybinds first (like Banking does)
	pcall(function()
		if self.textSearchKeybindStripDescriptor and KEYBIND_STRIP then
			KEYBIND_STRIP:RemoveKeybindButtonGroup(self.textSearchKeybindStripDescriptor)
		end
	end)

	-- Add back main keybinds
	pcall(function()
		if self.mainKeybindStripDescriptor then
			BETTERUI.Interface.EnsureKeybindGroupAdded(self.mainKeybindStripDescriptor)
			KEYBIND_STRIP:UpdateKeybindButtonGroup(self.mainKeybindStripDescriptor)
		end
	end)

	-- Deactivate the search header focus
	if self.textSearchHeaderFocus and self.textSearchHeaderFocus.Deactivate then
		if self.textSearchHeaderFocus:IsActive() then
			pcall(function() self.textSearchHeaderFocus:Deactivate() end)
		end
	end

	-- Leave header if active
	if self:IsHeaderActive() then
		self:RequestLeaveHeader()
	end

	-- Activate the current list so it receives input
	local currentList = self:GetCurrentList()
	if currentList then
		if currentList.Activate and (not currentList.IsActive or not currentList:IsActive()) then
			pcall(function() currentList:Activate() end)
		end
	end

	-- Optionally select top result
	if selectTopResult and self.searchQuery and tostring(self.searchQuery) ~= "" then
		if currentList and currentList.SetSelectedIndexWithoutAnimation then
			local count = 0
			if currentList.GetNumItems then
				count = currentList:GetNumItems()
			elseif currentList.GetNumEntries then
				count = currentList:GetNumEntries()
			elseif currentList.dataList then
				count = #currentList.dataList
			end
			if count > 0 then
				pcall(function()
					currentList:SetSelectedIndexWithoutAnimation(1, true, false)
				end)
			end
		end
	end

	-- Ensure proper keybinds are restored after a short delay
	zo_callLater(function()
		if self.scene and self.scene:IsShowing() then
			self:EnsureHeaderKeybindsActive()
			self:RefreshKeybinds()
		end
	end, 0)
end

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

--------------
-- Keybinds --
--------------
--- Initializes the main keybind strip.
---
--- Purpose: Defines the interactable buttons at the bottom of the screen.
--- Mechanics:
--- - Defines **Secondary (X)**: Context-aware (Equip, Use, Assign Quickslot).
--- - Defines **Tertiary (Y)**: Actions Menu.
--- - Defines **Left Stick**: Stack All.
--- - Defines **Right Stick**: Switch to Craft Bag/Backpack.
--- - Defines **Quaternary**: Clear Search (Dynamic visibility).
--- References: Called by Initialize.
---
function BETTERUI.Inventory.Class:InitializeKeybindStrip()
	-- Helper used by X-button name/callback to decide if an item is quickslottable
	local function IsQuickslottable(sd)
		if not sd or not sd.bagId or not sd.slotIndex then
			return false
		end
		local bag, slot = sd.bagId, sd.slotIndex
		-- Already assigned is always eligible
		if FindActionSlotMatchingItem and FindActionSlotMatchingItem(bag, slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) then
			return true
		end
		-- Exclude quest items explicitly
		if
			ZO_InventoryUtils_DoesNewItemMatchFilterType
			and ZO_InventoryUtils_DoesNewItemMatchFilterType(sd, ITEMFILTERTYPE_QUEST)
		then
			return false
		end
		-- Prefer the UI's own quickslot filter (captures true quickslottables reliably)
		if
			ZO_InventoryUtils_DoesNewItemMatchFilterType
			and ZO_InventoryUtils_DoesNewItemMatchFilterType(sd, ITEMFILTERTYPE_QUICKSLOT)
		then
			return true
		end
		-- Engine validation as a secondary check
		if IsValidItemForSlot and IsValidItemForSlot(bag, slot, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) then
			return true
		end
		return false
	end

	self.mainKeybindStripDescriptor = {
		-- Primary (A) reserved for item primary actions (equip/use/etc.).
		--X Button for Quick Action
		{
			alignment = KEYBIND_STRIP_ALIGN_LEFT,
			name = function()
				local n = ""
				if self.actionMode == ITEM_LIST_ACTION_MODE then
					--bag mode
					local isQuestItem =
						ZO_InventoryUtils_DoesNewItemMatchFilterType(self.itemList.selectedData, ITEMFILTERTYPE_QUEST)
					local target = self.itemList.selectedData
					local ft = (target and target.bagId and target.slotIndex)
						and GetItemFilterTypeInfo(target.bagId, target.slotIndex)
						or nil
					if IsQuickslottable(target) then
						--assign
						n = GetString(SI_BETTERUI_INV_ACTION_QUICKSLOT_ASSIGN)
					elseif
						not isQuestItem
						and (ft == ITEMFILTERTYPE_WEAPONS or ft == ITEMFILTERTYPE_ARMOR or ft == ITEMFILTERTYPE_JEWELRY)
					then
						--switch compare
						n = GetString(SI_BETTERUI_INV_SWITCH_INFO)
					elseif isQuestItem and target.meetsUsageRequirement then
						-- Use
						n = GetString(SI_ITEM_ACTION_USE)
					else
						n = GetString(SI_ITEM_ACTION_LINK_TO_CHAT)
					end
				elseif self.actionMode == CRAFT_BAG_ACTION_MODE then
					--craftbag mode
					n = GetString(SI_ITEM_ACTION_LINK_TO_CHAT)
				else
					n = ""
				end
				return n or ""
			end,
			keybind = "UI_SHORTCUT_SECONDARY",
			-- (no hold callbacks here; tap behavior preserved)
			visible = function()
				if self.actionMode == ITEM_LIST_ACTION_MODE then
					if self.itemList.selectedData then
						local isQuestItem = ZO_InventoryUtils_DoesNewItemMatchFilterType(
							self.itemList.selectedData,
							ITEMFILTERTYPE_QUEST
						)
						-- Show "A" if it's NOT a quest item OR if it IS a quest item that is usable
						if not isQuestItem then
							return true
						else
							return self.itemList.selectedData.meetsUsageRequirement
						end
					end
					return false
				elseif self.actionMode == CRAFT_BAG_ACTION_MODE then
					return true
				end
			end,
			callback = function()
				if self.actionMode == ITEM_LIST_ACTION_MODE then
					--bag mode
					local target = self.itemList.selectedData
					local ft = (target and target.bagId and target.slotIndex)
						and GetItemFilterTypeInfo(target.bagId, target.slotIndex)
						or nil
					if IsQuickslottable(target) then
						-- Open BetterUI quickslot assignment dialog to let user pick the wheel slot visually
						self:ShowQuickslotAssignDialog(target.bagId, target.slotIndex)
					else
						-- If it's gear categories, toggle compare; otherwise link to chat
						if
							not ZO_InventoryUtils_DoesNewItemMatchFilterType(target, ITEMFILTERTYPE_QUEST)
							and (
								ft == ITEMFILTERTYPE_WEAPONS
								or ft == ITEMFILTERTYPE_ARMOR
								or ft == ITEMFILTERTYPE_JEWELRY
							)
						then
							self:SwitchInfo()
						elseif ZO_InventoryUtils_DoesNewItemMatchFilterType(target, ITEMFILTERTYPE_QUEST) and target.meetsUsageRequirement then
							-- Use the item (this handles scene transitions natively for books/maps)
							-- Access dataSource for quest-specific properties
							local ds = target.dataSource or target
							-- Hide inventory scene to allow native scene transition
							SCENE_MANAGER:Hide("gamepad_inventory_root")
							if ds.toolIndex then
								CallSecureProtected("UseQuestTool", ds.questIndex, ds.toolIndex)
							elseif ds.stepIndex and ds.conditionIndex then
								CallSecureProtected("UseQuestItem", ds.questIndex, ds.stepIndex, ds.conditionIndex)
							else
								-- Fallback for items without tool/step info (shouldn't happen but safe)
								local bag, slot = ZO_Inventory_GetBagAndIndex(ds)
								if bag and slot then
									CallSecureProtected("UseItem", bag, slot)
								end
							end
						else
							local itemLink = GetItemLink(target.bagId, target.slotIndex)
							if itemLink then
								ZO_LinkHandler_InsertLink(zo_strformat("[<<2>>]", SI_TOOLTIP_ITEM_NAME, itemLink))
							end
						end
					end
				elseif self.actionMode == CRAFT_BAG_ACTION_MODE then
					--craftbag mode
					local targetData = SafeGetTargetData(self.craftBagList)
					local itemLink
					local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
					if bag and slot then
						itemLink = GetItemLink(bag, slot)
					end
					if itemLink then
						ZO_LinkHandler_InsertLink(zo_strformat("[<<2>>]", SI_TOOLTIP_ITEM_NAME, itemLink))
					end
				end
			end,
		},
		--Y Button for Actions
		{
			name = GetString(SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND),
			alignment = KEYBIND_STRIP_ALIGN_LEFT,
			keybind = "UI_SHORTCUT_TERTIARY",
			-- (no hold callbacks here; tap behavior preserved)
			order = 1000,
			visible = function()
				if self.actionMode == ITEM_LIST_ACTION_MODE then
					return self.selectedItemUniqueId ~= nil or SafeGetTargetData(self.itemList) ~= nil
				elseif self.actionMode == CRAFT_BAG_ACTION_MODE then
					return self.selectedItemUniqueId ~= nil
				end
			end,

			callback = function()
				self:SaveListPosition()
				self:ShowActions()
			end,
		},
		--L Stick for Stacking Items
		{
			name = GetString(SI_ITEM_ACTION_STACK_ALL),
			alignment = KEYBIND_STRIP_ALIGN_LEFT,
			keybind = "UI_SHORTCUT_LEFT_STICK",
			disabledDuringSceneHiding = true,
			visible = function()
				return self.actionMode == ITEM_LIST_ACTION_MODE
			end,
			callback = function()
				StackBag(BAG_BACKPACK)
			end,
		},
		--R Stick for Switching Bags
		{
			name = function()
				local s = zo_strformat(
					GetString(SI_BETTERUI_INV_ACTION_TO_TEMPLATE),
					GetString(
						self:GetCurrentList() == self.craftBagList and SI_BETTERUI_INV_ACTION_INV
						or SI_BETTERUI_INV_ACTION_CB
					)
				)
				return s or ""
			end,
			alignment = KEYBIND_STRIP_ALIGN_RIGHT,
			keybind = "UI_SHORTCUT_RIGHT_STICK",
			disabledDuringSceneHiding = true,
			callback = function()
				self:Switch()
			end,
		},
		-- Support QUATERNARY as a quick Clear Search key when the header search control is visible.
		{
			name = function()
				return GetString(SI_BETTERUI_CLEAR_SEARCH) or GetString(SI_GAMEPAD_SELECT_OPTION) or "Clear"
			end,
			alignment = KEYBIND_STRIP_ALIGN_LEFT,
			keybind = "UI_SHORTCUT_QUATERNARY",
			disabledDuringSceneHiding = true,
			visible = function()
				return self.textSearchHeaderControl ~= nil
			end,
			callback = function()
				if not (self.textSearchHeaderControl and (not self.textSearchHeaderControl:IsHidden())) then
					return
				end
				-- Use centralized helper to clear the search and restore keybinds
				if self.ClearTextSearch then
					self:ClearTextSearch()
				end
				if self._searchModeActive then
					self:ExitSearchFocus()
				else
					pcall(function()
						self:RefreshActiveKeybinds()
					end)
					pcall(function()
						self:UpdateActions()
					end)
				end
			end,
		},
	}

	ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.mainKeybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON)
end

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
