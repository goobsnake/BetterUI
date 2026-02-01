--[[
File: Modules/Banking/Banking.lua
Purpose: Implements the comprehensive banking interface for BetterUI.
Author: BetterUI Team
Last Modified: 2026-01-24

This module completely replaces the default gamepad banking interface with a feature-rich,
inventory-like experience. It supports advanced filtering, searching, custom categories,
and seamless currency transfers.

KEY MECHANICS:
1.  **List Management**:
    *   Unified `RefreshList` logic handling both Withdraw (Bank/SubBank) and Deposit (Backpack).
    *   Integrates `SHARED_INVENTORY` for optimized data retrieval.
    *   Supports "All Items" mode with dedicated currency transfer rows.
2.  **Item Movement**:
    *   `MoveItem`: Securely transfers items using `CallSecureProtected("RequestMoveItem")`.
    *   Smart Stacking: Automatically finds stackable items in the destination bag to merge stacks.
3.  **Currency Transfer**:
    *   Dedicated `ZO_CurrencySelector_Gamepad` integration for Gold, Tel Var, AP, and Vouchers.
4.  **Category System**:
    *   Tabbed navigation (All, Weapons, Apparel, Materials, etc.) mirroring the Inventory module.
    *   Dynamic filtering based on item type and "Furniture Vault" status.
5.  **Search**:
    *   Integrated text search filtering by name.




]]

zo_callLater(function() d("[BetterUI Banking] Banking.lua FILE LOADED") end, 2000)

-------------------------------------------------------------------------------------------------
-- LOCAL REFERENCES TO NAMESPACE CONSTANTS
-------------------------------------------------------------------------------------------------
-- These reference values from Core/BankingClass.lua (loaded first in manifest).
-- Using locals for performance in frequently-called functions.
-------------------------------------------------------------------------------------------------
local LIST_WITHDRAW                 = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT                  = BETTERUI.Banking.LIST_DEPOSIT

local esoSubscriber                 = BETTERUI.Banking.esoSubscriber

-------------------------------------------------------------------------------------------------
-- SHARED CATEGORY AND UTILITY REFERENCES
-------------------------------------------------------------------------------------------------
-- Use centralized category definitions from CIM module to eliminate duplication.
-- See: Modules/CIM/CategoryDefinitions.lua for the source definitions.
-------------------------------------------------------------------------------------------------
local BANK_CATEGORY_DEFS            = BETTERUI.Banking.CATEGORY_DEFS
local EnsureKeybindGroupAdded       = BETTERUI.Banking.EnsureKeybindGroupAdded
local CreateSearchKeybindDescriptor = BETTERUI.Banking.CreateSearchKeybindDescriptor



-- Class definition moved to Core/BankingClass.lua (loaded first in manifest)
-- BETTERUI.Banking.Class is already defined there via BETTERUI.Interface.Window:Subclass()
-- BETTERUI.Banking.Class:New() is also defined there

--[[
Function: BETTERUI.Banking.Class:CurrentUsedBank
Description: Updates the 'currentUsedBank' state.
Rationale: Determines whether we are using the main bank (BAG_BANK) or a house bank.
Mechanism: Checks IsHouseBankBag(GetBankingBag()). Updates both namespace and local upvalue.
]]


--[[
Function: BETTERUI.Banking.Class:LastUsedBank
Description: Updates the 'lastUsedBank' state.
Mechanism: Updates both namespace and local upvalue for backward compat.
]]


--[[
Function: BETTERUI.Banking.Class:RefreshFooter
Description: Refreshes the footer information (Space Used, Currency).
Rationale: Updates the bottom bar with current bag space and currency amounts.
Mechanism: Checks 'currentMode' to decide whether to show Bank or Backpack info.
]]


--[[
Function: BETTERUI.Banking.Class:RefreshCurrencyTooltip
Description: Updates the tooltip for currency rows.
Rationale: Shows currency balances in the tooltip when a currency row is selected.
]]
function BETTERUI.Banking.Class:RefreshCurrencyTooltip()
    if not BETTERUI.CIM.Utils.IsBankingSceneShowing() then return end
    local list = self:GetList()
    if not list or not list.selectedData or not list.selectedData.label then return end
    GAMEPAD_TOOLTIPS:LayoutBankCurrencies(GAMEPAD_LEFT_TOOLTIP, ZO_BANKABLE_CURRENCIES)
end

--[[
Function: BETTERUI.Banking.Class:Initialize
Description: Initializes the banking module components.
Rationale: Sets up the window, list, keybinds, and event listeners.
Mechanism:
  - Initializes base GenericInterface window.
  - Registers keybind descriptors (Core, Currency, Actions).
  - Sets up the Actions Dialog for item operations.
  - Hooks into EVENT_INVENTORY_SINGLE_SLOT_UPDATE for dynamic list updates.
  - Configures the text search header and its focus logic.
References: Called by BETTERUI.Banking.Init().
param: tlw_name (string) - Top level window name.
param: scene_name (string) - Scene name.
]]
--- @param tlw_name string Top level window name
--- @param scene_name string Scene name
function BETTERUI.Banking.Class:Initialize(tlw_name, scene_name)
    d("[BetterUI Banking] >>> Initialize STARTING <<<")
    -- Configuration for directional input fix timing uses centralized constant
    -- BETTERUI.CIM.CONST.TIMING.DIRECTIONAL_FIX_DELAY_MS

    BETTERUI.Interface.Window.Initialize(self, tlw_name, scene_name)

    -- Create banking scene
    BETTERUI_BANKING_SCENE = ZO_InteractScene:New(
        BETTERUI_BANKING_SCENE_NAME,
        SCENE_MANAGER,
        BETTERUI.Banking.BANKING_INTERACTION
    )
    self:InitializeFragment()
    self:InitializeScene(BETTERUI_BANKING_SCENE)

    self:InitializeKeybind()
    self:InitializeList()
    self.itemActions = BETTERUI.Inventory.SlotActions:New(KEYBIND_STRIP_ALIGN_LEFT)
    self.itemActions:SetUseKeybindStrip(false)
    self:InitializeActionsDialog()

    -- Re-anchor the list to match Inventory's offset using shared CIM constants
    local listContainer = self.control:GetNamedChild("Container"):GetNamedChild("List")
    if listContainer then
        local LIST_OFFSETS = BETTERUI.CIM.CONST.LAYOUT.LIST.CONTAINER
        listContainer:ClearAnchors()
        listContainer:SetAnchor(TOPLEFT, self.header:GetNamedChild("Header"), BOTTOMLEFT,
            LIST_OFFSETS.HEADER_X_OFFSET, LIST_OFFSETS.HEADER_Y_OFFSET)
        listContainer:SetAnchor(BOTTOMRIGHT, self.footer:GetNamedChild("Footer"), TOPRIGHT, 0,
            LIST_OFFSETS.FOOTER_Y_OFFSET)
    end

    local function CallbackSplitStackFinished()
        --refresh list
        if BETTERUI.CIM.Utils.IsBankingSceneShowing() then
            SHARED_INVENTORY:PerformFullUpdateOnBagCache(BETTERUI.Banking.currentUsedBank)
            self:RefreshList()
            self:ReturnToSaved()
        end
    end
    CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_SPLIT_STACK_DIALOG_FINISHED", CallbackSplitStackFinished)

    self.list.maxOffset = BETTERUI_BANK_LIST_MAX_OFFSET
    self.list:SetHeaderPadding(GAMEPAD_HEADER_DEFAULT_PADDING * BETTERUI_BANK_HEADER_PADDING_SCALE,
        GAMEPAD_HEADER_SELECTED_PADDING * BETTERUI_BANK_HEADER_PADDING_SCALE)
    self.list:SetUniversalPostPadding(GAMEPAD_DEFAULT_POST_PADDING * BETTERUI_BANK_HEADER_PADDING_SCALE)

    -- Setup data templates of the lists
    BETTERUI.Banking.Class.SetupItemList(self.list)
    self:AddTemplate("BETTERUI_HeaderRow_Template", BETTERUI.Banking.Class.SetupLabelListing)

    -- Initialize scroll indicator for banking list
    -- offsetX: 9 (rightward), offsetTopY: -8 (upward), offsetBottomY: -8 (up from footer)
    local listControl = self.list and self.list.control
    if listControl and BETTERUI.CIM.ScrollIndicator then
        BETTERUI.CIM.ScrollIndicator.Initialize(listControl, 9, -8, -8)
    end

    self.currentMode = LIST_WITHDRAW
    self.lastPositions = { [LIST_WITHDRAW] = 1, [LIST_DEPOSIT] = 1 }
    -- Per-category selection persistence (shared across modes in a session)
    self.lastPositionsByCategory = {}

    -- Initialize categories (Stage 1)
    self:CurrentUsedBank()
    self.bankCategories = self:ComputeVisibleBankCategories()
    self.currentCategoryIndex = 1

    -- Base header title (used as fallback); header title will show selected category like inventory
    self.headerBaseTitle = GetString(SI_BETTERUI_BANK_TITLE)

    -- Initialize the banking header with a tab bar similar to inventory
    self.headerGeneric = self.header:GetNamedChild("Header") or self.header
    BETTERUI.GenericHeader.Initialize(self.headerGeneric, ZO_GAMEPAD_HEADER_TABBAR_CREATE)
    self:RebuildHeaderCategories()

    -- Initialize Header Sort Controller for column-based sorting
    -- Must be called after headerGeneric is set (needs self.headerGeneric for column labels)
    local hasFunc = self.InitializeHeaderSortController ~= nil
    zo_callLater(function()
        d("[BetterUI Banking] Initialize - InitializeHeaderSortController exists: " .. tostring(hasFunc))
    end, 4000)

    if self.InitializeHeaderSortController then
        self:InitializeHeaderSortController()
        zo_callLater(function()
            d("[BetterUI Banking] InitializeHeaderSortController completed")
            d("[BetterUI Banking] headerSortController: " .. tostring(self.headerSortController ~= nil))
            -- Check if column labels were linked
            if self.headerSortController and self.headerSortController.columnLabels then
                local count = 0
                for _ in pairs(self.headerSortController.columnLabels) do count = count + 1 end
                d("[BetterUI Banking] columnLabels count: " .. count)
            else
                d("[BetterUI Banking] WARNING: No columnLabels table!")
            end
            -- Check headerGeneric
            d("[BetterUI Banking] headerGeneric: " ..
                tostring(self.headerGeneric and self.headerGeneric:GetName() or "nil"))
        end, 4500)
    end

    -- Add gamepad text search support; callback updates searchQuery and refreshes the list
    -- Uses the AddSearch helper added to BETTERUI.Interface.Window
    -- Provide a dedicated keybind group for the text-search header so that when
    -- the search is focused we can temporarily replace the main banking keybinds.
    self.textSearchKeybindStripDescriptor = CreateSearchKeybindDescriptor(self)

    if self.AddSearch then
        -- Register search. Pass our descriptor so AddSearch can wire keybinds appropriately.
        self:AddSearch(self.textSearchKeybindStripDescriptor, function(editOrText)
            -- Normalize the OnTextChanged argument: engine passes the editBox control, others may pass a string.
            local query = ""
            if type(editOrText) == "string" then
                query = editOrText
            elseif editOrText and type(editOrText) == "table" and editOrText.GetText then
                query = editOrText:GetText() or ""
            elseif editOrText and type(editOrText) == "userdata" then
                local txt = editOrText:GetText()
                if txt then
                    query = txt
                else
                    query = tostring(editOrText)
                end
            else
                query = tostring(editOrText or "")
            end

            self.searchQuery = query or ""
            -- When search changes, reset selection to top and refresh
            self:SaveListPosition()
            self:RefreshList()
        end)
        -- Position the search control appropriately beneath the header/title
        if self.PositionSearchControl then
            self:PositionSearchControl()
        end
    end

    -- Hook into the actual edit box to detect focus and text changes so we can swap keybinds
    -- matching Inventory behavior (Clear-only while focused).
    if self.textSearchHeaderFocus and self.textSearchHeaderFocus:GetEditBox() then
        local editBox = self.textSearchHeaderFocus:GetEditBox()
        local origOnFocusGained = editBox:GetHandler("OnFocusGained")
        local origOnFocusLost = editBox:GetHandler("OnFocusLost")
        local origOnTextChanged = editBox:GetHandler("OnTextChanged")
        local origOnKeyDown = editBox:GetHandler("OnKeyDown")

        editBox:SetHandler("OnFocusGained", function(eb)
            if origOnFocusGained then origOnFocusGained(eb) end
            -- Guard: Only process if banking scene is actually showing
            if not BETTERUI.CIM.Utils.IsBankingSceneShowing() then return end
            if self.RequestEnterHeader then
                self:RequestEnterHeader()
            else
                self:EnterSearchMode()
            end
        end)

        editBox:SetHandler("OnFocusLost", function(eb)
            if origOnFocusLost then origOnFocusLost(eb) end
            -- Guard: Only process if banking scene is actually showing
            if not BETTERUI.CIM.Utils.IsBankingSceneShowing() then return end
            self:ExitSearchFocus()
        end)

        editBox:SetHandler("OnTextChanged", function(eb)
            if origOnTextChanged then origOnTextChanged(eb) end
            -- Guard: Only process if banking scene is actually showing
            if not BETTERUI.CIM.Utils.IsBankingSceneShowing() then return end
            local txt = ""
            local t = eb:GetText()
            if t then txt = t end
            self.searchQuery = txt or ""
            -- When search changes, reset selection to top and refresh
            self:RefreshList()
        end)

        editBox:SetHandler("OnKeyDown", function(eb, key, ctrl, alt, shift, command)
            if origOnKeyDown then
                local handled = origOnKeyDown(eb, key, ctrl, alt, shift, command)
                if handled then
                    return handled
                end
            end
            -- Guard: Only process if banking scene is actually showing
            if not BETTERUI.CIM.Utils.IsBankingSceneShowing() then return end
            if command == "UI_SHORTCUT_DOWN" then
                self:ExitSearchFocus()
                return true
            end
        end)

        local origOnShortcut = editBox:GetHandler("OnShortcut")
        editBox:SetHandler("OnShortcut", function(eb, shortcut)
            if origOnShortcut then
                local handled = origOnShortcut(eb, shortcut)
                if handled then
                    return handled
                end
            end
            -- Guard: Only process if banking scene is actually showing
            if not BETTERUI.CIM.Utils.IsBankingSceneShowing() then return end
            if shortcut == "UI_SHORTCUT_DOWN" then
                self:ExitSearchFocus()
                return true
            end
        end)
    end

    -- EnsureHeaderKeybindsActive is defined on the class below; keep calls here

    self.selectedDataCallback = BETTERUI.Banking.Class.OnItemSelectedChange

    -- this is essentially a way to encapsulate a function which allows us to override "selectedDataCallback" but still keep some logic code
    -- Callback when a list item is selected via d-pad/stick.
    -- Purpose: Handles updating the footer keybinds and tooltips.
    -- Mechanics:
    -- 1. Checks if Search Focus is active (if so, maintains search keybinds).
    -- 2. Fires the `selectedDataCallback` to notify listeners (e.g., footer updates).
    -- 3. Clears "New" status on the item if applicable.
    local function SelectionChangedCallback(list, selectedData)
        if self._searchModeActive and self.list and self.list.IsActive and self.list:IsActive() then
            -- Process the keybind update for currency rows BEFORE exiting search focus
            -- This ensures the correct keybinds (currencyKeybinds or withdrawDepositKeybinds) are applied
            if selectedData then
                local selectedControl = list:GetSelectedControl()
                if self.selectedDataCallback then
                    self:selectedDataCallback(selectedControl, selectedData)
                end
            end
            -- Now exit search focus
            self:ExitSearchFocus()
            return
        end

        local selectedControl = list:GetSelectedControl()
        if self.selectedDataCallback then
            self:selectedDataCallback(selectedControl, selectedData)
        end

        -- Update scroll indicator position
        if list and list.control and BETTERUI.CIM.ScrollIndicator then
            local totalItems = list:GetNumItems() or 0
            local currentIndex = list:GetSelectedIndex() or 1
            local visibleItems = 10 -- approximate visible items in banking list
            BETTERUI.CIM.ScrollIndicator.Update(list.control, currentIndex, totalItems, visibleItems)
        end

        -- Refresh item actions so Y-menu shows correct actions for new selection
        -- Fixes caching issue when scrolling from Withdraw Gold to actual items
        if selectedData then
            self:RefreshItemActions()
        end
        if selectedControl and selectedControl.bagId then
            SHARED_INVENTORY:ClearNewStatus(selectedControl.bagId, selectedControl.slotIndex)
            self:GetParametricList():RefreshList()
        end
    end

    -- these are event handlers which are specific to the banking interface. Handling the events this way encapsulates the banking interface
    -- these local functions are essentially just router functions to other functions within this class. it is done in this way to allow for
    -- us to access this classes' members (through "self")

    -- Event handler for Single Slot Updates (Item added/removed/changed).
    -- Purpose: Refreshes the list when inventory changes occur.
    -- Mechanics:
    -- 1. Checks `_suppressListUpdates` to avoid spamming refreshes during bulk moves.
    -- 2. Calls `UpdateSingleItem` (which triggers a refresh).
    -- 3. Re-computes visible categories (e.g., if the last Weapon was removed, hide Weapon tab).
    -- 4. Handles Category auto-switching if the current category becomes empty.
    local function UpdateSingle_Handler(eventId, bagId, slotId, isNewItem, itemSound)
        -- If a coalesced refresh is in progress, skip intermediate updates to avoid UI stutter
        if self._suppressListUpdates then
            self.isDirty = true
            return
        end
        self:UpdateSingleItem(bagId, slotId)
        -- Categories can become empty/non-empty as items move; rebuild the header list
        -- Capture the current category KEY before recomputing categories
        local prevCategoryKey = nil
        if self.bankCategories and self.currentCategoryIndex and self.currentCategoryIndex <= #self.bankCategories then
            local prevCat = self.bankCategories[self.currentCategoryIndex]
            if prevCat then
                prevCategoryKey = prevCat.key
            end
        end
        self.bankCategories = self:ComputeVisibleBankCategories()
        -- Check if the captured category key still exists in the new list
        if prevCategoryKey then
            local categoryStillExists = false
            for i, cat in ipairs(self.bankCategories) do
                if cat.key == prevCategoryKey then
                    categoryStillExists = true
                    break
                end
            end
            if not categoryStillExists then
                -- Category became empty, force to All Items
                self.currentCategoryIndex = 1
            end
        end
        -- Suppress callback during rebuild when category has changed
        local state = BETTERUI.CIM.HeaderNavigation.GetOrCreateState(self)
        state.suppressHeaderCallback = true
        self:RebuildHeaderCategories()
        state.suppressHeaderCallback = false
        self:RefreshList()
        self:RefreshActiveKeybinds()
    end

    local function UpdateCurrency_Handler()
        -- Only update UI/keybinds when the banking scene is actually visible
        if not BETTERUI.CIM.Utils.IsBankingSceneShowing() then
            return
        end
        self:RefreshFooter()
        if KEYBIND_STRIP then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds)
        end
        self:RefreshCurrencyTooltip()
    end

    -- Scene showing handler moved to OnSceneShowing method.
    -- SceneLifecycleManager in base Window class calls OnSceneShowing hook.

    -- Scene hidden handler moved to OnSceneHidden method.
    -- SceneLifecycleManager in base Window class calls OnSceneHidden hook.

    local selectorContainer = self.control:GetNamedChild("Container"):GetNamedChild("InputContainer")
    self.selector = ZO_CurrencySelector_Gamepad:New(selectorContainer:GetNamedChild("Selector"))
    self.selector:SetClampValues(true)
    self.selectorCurrency = selectorContainer:GetNamedChild("CurrencyTexture")

    self.list:SetOnSelectedDataChangedCallback(SelectionChangedCallback)

    -- Monkeypatch MovePrevious to allow moving "up" from the top of the list into the header.
    -- When there is no previous entry, go to search bar (like Inventory) instead of header sort mode.
    if self.list and self.list.MovePrevious then
        local _origMovePrevious = self.list.MovePrevious
        self.list.MovePrevious = function(list, allowWrapping, suppressFailSound)
            local ok = _origMovePrevious(list, allowWrapping, suppressFailSound)

            if not ok then
                -- No previous entry; go to header/search bar (matching Inventory behavior)
                if self.OnEnterHeader then
                    self:OnEnterHeader()
                elseif self.headerGeneric and self.headerGeneric.tabBar and self.headerGeneric.tabBar.Activate then
                    self.headerGeneric.tabBar:Activate()
                end
                return true
            end
            return ok
        end
    end

    -- directionalFixDelayMs moved to top of Initialize() to fix scoping bug


    -- Always-running event listeners, these don't add much overhead
    self.control:RegisterForEvent(EVENT_CARRIED_CURRENCY_UPDATE, UpdateCurrency_Handler)
    self.control:RegisterForEvent(EVENT_BANKED_CURRENCY_UPDATE, UpdateCurrency_Handler)
end

--[[
Function: BETTERUI.Banking.Class:OnSceneShowing
Description: Scene showing handler called by SceneLifecycleManager.
Rationale: Migrated from OnEffectivelyShown to use unified scene lifecycle.
param: wasPushed (boolean) - Whether scene was pushed (not resumed).
]]
function BETTERUI.Banking.Class:OnSceneShowing(wasPushed)
    self:CurrentUsedBank()
    -- Rebuild categories on show in case bank type changed
    self.bankCategories = self:ComputeVisibleBankCategories()
    -- Always default to "All Items" and first row on first open of the scene
    self.currentCategoryIndex = 1
    self.lastPositions[self.currentMode] = 1
    self:RebuildHeaderCategories()
    -- Force header to All Items (index 1) on scene open without animation
    -- Suppress callback to avoid double refresh since we call RefreshList below
    if self.headerGeneric and self.headerGeneric.tabBar then
        self.headerGeneric.tabBar:SetSelectedIndexWithoutAnimation(1, true, true)
    end
    if self.isDirty then
        self:RefreshList()
    else
        self:RefreshActiveKeybinds()
    end
    self.list:Activate()
    -- Ensure our keybind groups and header tab bar are active on first show
    self:AddKeybinds()

    self:UpdateExternalAddons(true)

    -- Register for SHARED_INVENTORY callbacks (not raw events)
    -- These fire AFTER the cache is updated, ensuring RefreshList() gets fresh data
    local function OnInventoryUpdated(bagId, slotIndex)
        if not BETTERUI.CIM.Utils.IsBankingSceneShowing() then return end
        -- Only refresh if the bag is one we're displaying
        local currentUsedBank = BETTERUI.Banking.currentUsedBank
        local relevantBags = {}
        if self.currentMode == LIST_WITHDRAW then
            if currentUsedBank == BAG_BANK then
                relevantBags = { BAG_BANK, BAG_SUBSCRIBER_BANK }
            else
                relevantBags = { currentUsedBank }
            end
        else
            relevantBags = { BAG_BACKPACK }
        end
        -- Check if this update is for a bag we care about
        local isRelevant = (bagId == nil) -- FullInventoryUpdate has nil bagId
        for _, bag in ipairs(relevantBags) do
            if bagId == bag then
                isRelevant = true
                break
            end
        end
        if not isRelevant then return end

        BETTERUI.Banking.Tasks:Schedule("sharedInventoryUpdate", 100, function()
            if BETTERUI.CIM.Utils.IsBankingSceneShowing() then
                self.isDirty = true
                self:RefreshList()
            end
        end)
    end
    -- Store callbacks so we can unregister when scene hides
    self._inventoryFullUpdateCallback = OnInventoryUpdated
    self._inventorySingleSlotCallback = OnInventoryUpdated
    SHARED_INVENTORY:RegisterCallback("FullInventoryUpdate", self._inventoryFullUpdateCallback)
    SHARED_INVENTORY:RegisterCallback("SingleSlotInventoryUpdate", self._inventorySingleSlotCallback)
    self:RefreshList()
end

--[[
Function: BETTERUI.Banking.Class:OnSceneHidden
Description: Scene hidden handler called by SceneLifecycleManager.
Rationale: Uses shared CIM.SceneCleanup helpers for consistent cleanup.
]]
function BETTERUI.Banking.Class:OnSceneHidden()
    self:LastUsedBank()
    self:CancelWithdrawDeposit(self.list)

    -- Use shared CIM cleanup for input state (header sort, selection mode, search focus, tab bar)
    BETTERUI.CIM.SceneCleanup.CleanupInputState(self)

    -- Deactivate lists to release DIRECTIONAL_INPUT
    BETTERUI.CIM.SceneCleanup.DeactivateLists(self)
    self.confirmationMode = false

    KEYBIND_STRIP:RemoveAllKeyButtonGroups()
    GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)

    self:UpdateExternalAddons(false)

    -- Unregister SHARED_INVENTORY callbacks
    if self._inventoryFullUpdateCallback then
        SHARED_INVENTORY:UnregisterCallback("FullInventoryUpdate", self._inventoryFullUpdateCallback)
        self._inventoryFullUpdateCallback = nil
    end
    if self._inventorySingleSlotCallback then
        SHARED_INVENTORY:UnregisterCallback("SingleSlotInventoryUpdate", self._inventorySingleSlotCallback)
        self._inventorySingleSlotCallback = nil
    end

    -- Clear search state using shared helper
    BETTERUI.CIM.SceneCleanup.ClearSearchState(self)

    -- Reset category positions when leaving the bank so next visit starts fresh
    self.lastPositionsByCategory = {}
end

--[[
Function: BETTERUI.Banking.Class:RefreshItemActions
Description: Updates the context menu actions for the currently selected item.
Rationale: Refreshes the available actions (e.g., Link to Chat, Split Stack) based on selection.
]]
function BETTERUI.Banking.Class:RefreshItemActions()
    local targetData = self:GetList().selectedData
    --self:SetSelectedInventoryData(targetData) instead:
    self.itemActions:SetInventorySlot(targetData)
end

--[[
Function: BETTERUI.Banking.Class:InitializeActionsDialog
Description: Initializes the "Y Button" Actions Dialog.
Rationale: Sets up the contextual menu for banking items (e.g. Split Stack, Link to Chat).
Mechanism:
  1. Registers callbacks for dialog setup, finish, and confirmation.
  2. Filters out "Destroy" actions when in Deposit mode to prevent accidents.
  3. Populates the parametric list with valid actions from BETTERUI.Inventory.SlotActions.
  4. Handles the "Confirm" event to execute the selected action (or custom Chat Link logic).
References: Called during Initialize.
]]
function BETTERUI.Banking.Class:InitializeActionsDialog()
    local function ActionDialogSetup(dialog)
        if BETTERUI.CIM.Utils.IsBankingSceneShowing() then
            dialog.entryList:SetOnSelectedDataChangedCallback(function(list, selectedData)
                self.itemActions:SetSelectedAction(selectedData and selectedData.action)
            end)

            local parametricList = dialog.info.parametricList
            ZO_ClearNumericallyIndexedTable(parametricList)

            -- Get target data and set on itemActions before discovering actions
            -- This ensures the slot actions controller knows what item to populate actions for
            local targetData = self:GetList() and self:GetList().selectedData or nil

            if targetData then
                -- Ensure slotType is present for discovery (matches Inventory pattern)
                if not targetData.slotType then
                    if self.currentMode == LIST_WITHDRAW then
                        targetData.slotType = SLOT_TYPE_BANK_ITEM
                    else
                        targetData.slotType = SLOT_TYPE_GAMEPAD_INVENTORY_ITEM
                    end
                end

                -- Set the inventory slot on the outer controller
                self.itemActions:SetInventorySlot(targetData)

                -- Directly discover actions on the inner slotActions object (critical for action discovery)
                -- This mirrors Inventory's ItemActionsDialog lines 262-270
                if self.itemActions.slotActions then
                    local innerSlotActions = self.itemActions.slotActions
                    innerSlotActions:Clear()
                    innerSlotActions:SetInventorySlot(targetData)
                    ZO_InventorySlot_DiscoverSlotActionsFromActionList(targetData, innerSlotActions)
                end
            end

            -- Refresh item actions after discovery (matches Inventory pattern at ItemActionsDialog.lua line 273)
            self:RefreshItemActions()

            -- Use shared CIM utility for action entry population
            local actions = self.itemActions:GetSlotActions()
            local hideDestroyInDeposit = self.currentMode == LIST_DEPOSIT
            BETTERUI.CIM.PopulateActionEntries(parametricList, actions, {
                hideDestroy = hideDestroyInDeposit,
            })

            -- Add custom "Withdraw Stack" / "Deposit Stack" action for stacked items
            -- This moves the ENTIRE stack without prompting for quantity
            if targetData and targetData.stackCount and targetData.stackCount > 1 then
                local actionName = (self.currentMode == LIST_WITHDRAW)
                    and GetString(SI_BETTERUI_BANK_WITHDRAW_MAX)
                    or GetString(SI_BETTERUI_BANK_DEPOSIT_MAX)
                local stackCount = targetData.stackCount

                -- Create proper ZO_GamepadEntryData like PopulateActionEntries does
                local entryData = ZO_GamepadEntryData:New(actionName)
                entryData:SetIconTintOnSelection(true)
                entryData.setup = ZO_SharedGamepadEntry_OnSetup
                -- Mark as custom BetterUI action so confirm callback knows to handle it
                entryData.isBetterUIStackTransfer = true
                entryData.stackCount = stackCount

                local moveMaxAction = {
                    template = "ZO_GamepadItemEntryTemplate",
                    entryData = entryData,
                }
                table.insert(parametricList, 1, moveMaxAction) -- Insert at top for easy access
            end

            dialog:setupFunc()
        end
    end

    local function ActionDialogFinish()
        if BETTERUI.CIM.Utils.IsBankingSceneShowing() then
            -- make sure to wipe out the keybinds added by actions
            self:AddKeybinds()
            --restore the selected inventory item

            self:RefreshItemActions()

            -- refresh so keybinds react to newly selected item

            self:RefreshList()
        end
    end
    local function ActionDialogButtonConfirm(dialog)
        if BETTERUI.CIM.Utils.IsBankingSceneShowing() then
            -- Check if the selected entry is our custom stack transfer action
            local selectedEntry = dialog.entryList and dialog.entryList:GetTargetData()
            if selectedEntry and selectedEntry.isBetterUIStackTransfer then
                -- Handle custom stack transfer action
                local stackCount = selectedEntry.stackCount or 1
                self:SaveListPosition()
                self:MoveItem(self.list, stackCount)
                ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                return
            end

            local selectedAction = self.itemActions and self.itemActions.selectedAction or nil
            if not selectedAction then return end
            local selectedName = ZO_InventorySlotActions:GetRawActionName(selectedAction)
            if selectedName == GetString(SI_ITEM_ACTION_LINK_TO_CHAT) then
                -- Use shared CIM utility for linking to chat
                BETTERUI.CIM.HandleLinkToChat(self:GetList().selectedData)
            elseif selectedName == GetString(SI_ITEM_ACTION_BANK_WITHDRAW) or
                selectedName == GetString(SI_ITEM_ACTION_BANK_DEPOSIT) then
                -- Intercept Withdraw/Deposit to show quantity dialog for stacked items
                -- This matches the A button behavior
                local selectedData = self.list and self.list:GetSelectedData()
                if selectedData then
                    local stackCount = selectedData.stackCount or 1
                    if stackCount > 1 then
                        -- Show quantity dialog for stacked items
                        local isDeposit = (selectedName == GetString(SI_ITEM_ACTION_BANK_DEPOSIT))
                        ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                        self:SaveListPosition()
                        self:ShowQuantityDialog(isDeposit)
                    else
                        -- Single item - move directly
                        ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                        self:SaveListPosition()
                        self:MoveItem(self.list, 1)
                    end
                end
            else
                self.itemActions:DoSelectedAction()
            end
        end
    end
    CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_SETUP", ActionDialogSetup)
    CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_FINISH", ActionDialogFinish)
    CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM", ActionDialogButtonConfirm)
end

-- NOTE: ActivateSpinner and DeactivateSpinner have been removed.
-- Quantity selection now uses BETTERUI_BANK_QUANTITY_DIALOG (see Dialogs/QuantityDialog.lua)
-- which provides a consistent modal dialog experience matching ESO's native ITEM_SLIDER pattern.

--[[
Function: BETTERUI.Banking.Class:UpdateExternalAddons
Description: Handles visibility of supported external addon elements (e.g. Wykkyds Toolbar).
param: hidden (boolean) - Whether to hide the external elements.
]]
function BETTERUI.Banking.Class:UpdateExternalAddons(hidden)
    -- Wykkyds Toolbar
    if wykkydsToolbar then
        wykkydsToolbar:SetHidden(hidden)
    end
end

--[[
Function: BETTERUI.Banking.Init
Description: Global initialization for the Banking module using BetterUI.Window.
Rationale: Creates the singleton Banking Window instance.
Mechanism:
  1. Instantiates `BETTERUI.Banking.Class`.
  2. Sets the default title.
  3. Configures List Columns (Name, Trait, etc.).
  4. Registers the scene with SCENE_MANAGER.
References: Called by BETTERUI.Banking.Setup().
]]
function BETTERUI.Banking.Init()
    BETTERUI.Banking.Window = BETTERUI.Banking.Class:New("BETTERUI_TestWindow", BETTERUI_TEST_SCENE)
    BETTERUI.Banking.Window:SetTitle("|c0066FF" .. GetString(SI_BETTERUI_BANK_TITLE) .. "|r")

    -- Initialize header with categories & selection immediately
    BETTERUI.Banking.Window:RebuildHeaderCategories()


    -- Set the column headings up using shared CIM constants
    local COLS = BETTERUI.CIM.CONST.HEADER_LAYOUT.COLUMNS
    BETTERUI.Banking.Window:AddColumn(GetString(SI_BETTERUI_BANKING_COLUMN_NAME), COLS.NAME)
    BETTERUI.Banking.Window:AddColumn(GetString(SI_BETTERUI_BANKING_COLUMN_TYPE), COLS.TYPE)
    BETTERUI.Banking.Window:AddColumn(GetString(SI_BETTERUI_BANKING_COLUMN_TRAIT), COLS.TRAIT)
    BETTERUI.Banking.Window:AddColumn(GetString(SI_BETTERUI_BANKING_COLUMN_STAT), COLS.STAT)
    BETTERUI.Banking.Window:AddColumn(GetString(SI_BETTERUI_BANKING_COLUMN_VALUE), COLS.VALUE)

    -- Link column labels to sort controller AFTER columns are created
    if BETTERUI.Banking.Window.LinkColumnLabels then
        BETTERUI.Banking.Window:LinkColumnLabels()
    end

    BETTERUI.Banking.Window:RefreshList()

    SCENE_MANAGER.scenes['gamepad_banking'] = SCENE_MANAGER.scenes['BETTERUI_BANKING']

    -- Initialize the refresh manager for unified list refresh handling
    if BETTERUI.Banking.InitializeRefreshManager then
        BETTERUI.Banking.InitializeRefreshManager()
    end

    -- Initialize the quantity selection dialog (replaces inline spinner)
    BETTERUI.Banking.InitializeQuantityDialog()

    -- Configure unified footer for BANKING mode
    BETTERUI.Banking.Window:SetupUnifiedFooter()

    esoSubscriber = IsESOPlusSubscriber()
end
