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

DECOMPOSITION STATUS:
    Phase 1 Complete: Core/BankingClass.lua contains class skeleton and module constants.
    Remaining decomposition phases pending.
]]

local _

-------------------------------------------------------------------------------------------------
-- LOCAL REFERENCES TO NAMESPACE CONSTANTS
-------------------------------------------------------------------------------------------------
-- These reference values from Core/BankingClass.lua (loaded first in manifest).
-- Using locals for performance in frequently-called functions.
-------------------------------------------------------------------------------------------------
local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT  = BETTERUI.Banking.LIST_DEPOSIT

-- Module-scope state accessors (read/write through namespace)
local function getLastUsedBank() return BETTERUI.Banking.lastUsedBank end
local function setLastUsedBank(v) BETTERUI.Banking.lastUsedBank = v end
local function getCurrentUsedBank() return BETTERUI.Banking.currentUsedBank end
local function setCurrentUsedBank(v) BETTERUI.Banking.currentUsedBank = v end

-- Note: These locals are initialized from namespace for file-scope access
-- The setter methods (CurrentUsedBank, LastUsedBank) update BOTH the namespace
-- AND these locals. This dual-write ensures:
--   1. Local reads remain fast (no table lookup)
--   2. Namespace values stay in sync for cross-file access in future phases
local esoSubscriber = BETTERUI.Banking.esoSubscriber
local lastUsedBank = BETTERUI.Banking.lastUsedBank or 0
local currentUsedBank = BETTERUI.Banking.currentUsedBank or 0

-------------------------------------------------------------------------------------------------
-- SHARED CATEGORY AND UTILITY REFERENCES
-------------------------------------------------------------------------------------------------
-- Use centralized category definitions from CIM module to eliminate duplication.
-- See: Modules/CIM/CategoryDefinitions.lua for the source definitions.
-------------------------------------------------------------------------------------------------
local BANK_CATEGORY_DEFS = BETTERUI.Banking.CATEGORY_DEFS
local EnsureKeybindGroupAdded = BETTERUI.Banking.EnsureKeybindGroupAdded
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
function BETTERUI.Banking.Class:CurrentUsedBank()
    local newValue
    if (IsHouseBankBag(GetBankingBag()) == false) then
        newValue = BAG_BANK
    elseif (IsHouseBankBag(GetBankingBag()) == true) then
        newValue = GetBankingBag()
    else
        newValue = BAG_BANK
    end
    -- Update both namespace and local upvalue for backward compat
    BETTERUI.Banking.currentUsedBank = newValue
    currentUsedBank = newValue
end

--[[
Function: BETTERUI.Banking.Class:LastUsedBank
Description: Updates the 'lastUsedBank' state.
Mechanism: Updates both namespace and local upvalue for backward compat.
]]
function BETTERUI.Banking.Class:LastUsedBank()
    local newValue
    if (IsHouseBankBag(GetBankingBag()) == false) then
        newValue = BAG_BANK
    elseif (IsHouseBankBag(GetBankingBag()) == true) then
        newValue = GetBankingBag()
    else
        newValue = BAG_BANK
    end
    -- Update both namespace and local upvalue for backward compat
    BETTERUI.Banking.lastUsedBank = newValue
    lastUsedBank = newValue
end

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
    if SCENE_MANAGER.scenes['gamepad_banking']:IsShowing() and self:GetList().selectedData.label ~= nil then
        GAMEPAD_TOOLTIPS:LayoutBankCurrencies(GAMEPAD_LEFT_TOOLTIP, ZO_BANKABLE_CURRENCIES)
    end
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
function BETTERUI.Banking.Class:Initialize(tlw_name, scene_name)
    BETTERUI.Interface.Window.Initialize(self, tlw_name, scene_name)

    self:InitializeKeybind()
    self:InitializeList()
    self.itemActions = BETTERUI.Inventory.SlotActions:New(KEYBIND_STRIP_ALIGN_LEFT)
    self.itemActions:SetUseKeybindStrip(false)
    self:InitializeActionsDialog()

    -- Re-anchor the list to match Inventory's offset (-50) to align columns with header
    local listContainer = self.control:GetNamedChild("Container"):GetNamedChild("List")
    if listContainer then
        listContainer:ClearAnchors()
        listContainer:SetAnchor(TOPLEFT, self.header:GetNamedChild("Header"), BOTTOMLEFT, -35, 0)
        listContainer:SetAnchor(BOTTOMRIGHT, self.footer:GetNamedChild("Footer"), TOPRIGHT, 0, 10)
    end

    local function CallbackSplitStackFinished()
        --refresh list
        if SCENE_MANAGER.scenes['gamepad_banking']:IsShowing() then
            SHARED_INVENTORY:PerformFullUpdateOnBagCache(currentUsedBank)
            self:RefreshList()
            self:ReturnToSaved()
        end
    end
    CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_SPLIT_STACK_DIALOG_FINISHED", CallbackSplitStackFinished)

    -- TODO(MAGIC-NUMBER): Extract these padding values to BetterUI.CONST.lua
    -- self.list.maxOffset = 30 -> BETTERUI.CONST.BANKING.LIST_MAX_OFFSET
    -- 0.75 multiplier -> BETTERUI.CONST.UI.HEADER_PADDING_SCALE
    -- This improves readability and makes UI tuning easier across modules.
    self.list.maxOffset = 30
    self.list:SetHeaderPadding(GAMEPAD_HEADER_DEFAULT_PADDING * 0.75, GAMEPAD_HEADER_SELECTED_PADDING * 0.75)
    self.list:SetUniversalPostPadding(GAMEPAD_DEFAULT_POST_PADDING * 0.75)

    -- Setup data templates of the lists
    BETTERUI.Banking.Class.SetupItemList(self.list)
    self:AddTemplate("BETTERUI_HeaderRow_Template", BETTERUI.Banking.Class.SetupLabelListing)

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
            if self.RequestEnterHeader then
                self:RequestEnterHeader()
            else
                self:EnterSearchMode()
            end
        end)

        editBox:SetHandler("OnFocusLost", function(eb)
            if origOnFocusLost then origOnFocusLost(eb) end
            self:ExitSearchFocus()
        end)

        editBox:SetHandler("OnTextChanged", function(eb)
            if origOnTextChanged then origOnTextChanged(eb) end
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
        self._suppressHeaderCallback = true
        self:RebuildHeaderCategories()
        self._suppressHeaderCallback = false
        self:RefreshList()
        self:RefreshActiveKeybinds()
    end

    local function UpdateCurrency_Handler()
        -- Only update UI/keybinds when the banking scene is actually visible
        if not (SCENE_MANAGER.scenes['gamepad_banking'] and SCENE_MANAGER.scenes['gamepad_banking']:IsShowing()) then
            return
        end
        self:RefreshFooter()
        if KEYBIND_STRIP then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds)
        end
        self:RefreshCurrencyTooltip()
    end

    -- Event handler when the Banking scene is shown.
    -- Purpose: Initializes the UI state for banking.
    -- Mechanics:
    -- 1. Updates current bank type (Bank vs Sub Bank).
    -- 2. Defaults to "All Items" category.
    -- 3. Activates the list and adds keybinds.
    -- 4. Registers for inventory update events.
    local function OnEffectivelyShown()
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

        if wykkydsToolbar then
            wykkydsToolbar:SetHidden(true)
        end

        self.control:RegisterForEvent(EVENT_INVENTORY_SINGLE_SLOT_UPDATE, UpdateSingle_Handler)
        self:RefreshList()
        -- OnEffectivelyShown: initialize list and keybinds; no debug logging.
    end

    -- Event handler when the Banking scene is hidden.
    -- Purpose: Cleans up UI state and unregisters events.
    -- Mechanics:
    -- 1. Deactivates Lists and Selectors.
    -- 2. Removes Keybinds and Tooltips.
    -- 3. Unregisters inventory update events.
    -- 4. Exits Search Mode (restoring normal input).
    -- 5. Performs aggressive cleanup of Directional Input to prevent focus lock issues.
    local function OnEffectivelyHidden()
        self:LastUsedBank()
        self:CancelWithdrawDeposit(self.list)
        self.list:Deactivate()
        self.selector:Deactivate()
        self.confirmationMode = false
        -- Release focus from header tab bar and clear any update suppression flags
        if self.headerGeneric and self.headerGeneric.tabBar then
            self.headerGeneric.tabBar:Deactivate()
        end
        self._suppressListUpdates = false
        self._suppressListUpdatesToken = nil

        KEYBIND_STRIP:RemoveAllKeyButtonGroups()
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)

        if wykkydsToolbar then
            wykkydsToolbar:SetHidden(false)
        end

        self.control:UnregisterForEvent(EVENT_INVENTORY_FULL_UPDATE)
        self.control:UnregisterForEvent(EVENT_INVENTORY_SINGLE_SLOT_UPDATE)

        -- Ensure we exit any active search mode so keybinds/focus are restored
        -- Ensure we exit any active search mode so keybinds/focus are restored
        if self.LeaveSearchMode then
            self:LeaveSearchMode()
        elseif self.ExitSearchFocus then
            -- fallback
            self:ExitSearchFocus()
        end

        -- Check KEYBIND_STRIP groups (no debug output)
        if self.textSearchKeybindStripDescriptor and KEYBIND_STRIP then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.textSearchKeybindStripDescriptor)
        end

        local list = self:GetList()
        if list and list.SetDirectionalInputEnabled then
            list:SetDirectionalInputEnabled(true)
        elseif self.list and self.list.SetDirectionalInputEnabled then
            self.list:SetDirectionalInputEnabled(true)
        end

        -- Fallback: sometimes input ownership changes slightly after hide due to queued operations.
        -- Schedule a short delayed re-enable of directional input and keybind restoration to handle races.
        zo_callLater(function()
            local listDelayed = self:GetList()
            if listDelayed and listDelayed.SetDirectionalInputEnabled then
                listDelayed:SetDirectionalInputEnabled(true)
            elseif self.list and self.list.SetDirectionalInputEnabled then
                self.list:SetDirectionalInputEnabled(true)
            end
        end, directionalFixDelayMs)

        -- Clear search text when exiting the banking scene
        self.searchQuery = ""
        if self.textSearchHeaderFocus and self.textSearchHeaderFocus:GetEditBox() then
            self.textSearchHeaderFocus:GetEditBox():SetText("")
        end

        -- Reset category positions when leaving the bank so next visit starts fresh
        self.lastPositionsByCategory = {}
    end

    local selectorContainer = self.control:GetNamedChild("Container"):GetNamedChild("InputContainer")
    self.selector = ZO_CurrencySelector_Gamepad:New(selectorContainer:GetNamedChild("Selector"))
    self.selector:SetClampValues(true)
    self.selectorCurrency = selectorContainer:GetNamedChild("CurrencyTexture")

    self.list:SetOnSelectedDataChangedCallback(SelectionChangedCallback)

    -- Monkeypatch MovePrevious to allow moving "up" from the top of the list into the header.
    -- Some list implementations return false when there is no previous entry; intercept
    -- that case and programmatically enter the header (focus the search control).
    if self.list and self.list.MovePrevious then
        local _origMovePrevious = self.list.MovePrevious
        self.list.MovePrevious = function(list, allowWrapping, suppressFailSound)
            local ok = false
            -- TODO(OVER-DEFENSIVE): Remove excessive pcall wrapping throughout this file.
            -- pcall here is unnecessary - _origMovePrevious is our own code, not external.
            -- pcall should only be used for:
            --   1. Calling APIs that may not exist (version compatibility)
            --   2. User-provided callbacks
            --   3. External addon integration
            -- NOT for: Our own code, standard ESO API calls.
            -- This file has 25+ unnecessary pcalls that hide bugs and hurt performance.
            -- call original implementation in protected call
            local status, res = pcall(function() return _origMovePrevious(list, allowWrapping, suppressFailSound) end)
            if status then ok = res end
            if not ok then
                -- No previous entry; attempt to focus header/search like Inventory does
                pcall(function()
                    if self.textSearchHeaderControl and not self.textSearchHeaderControl:IsHidden() then
                        if self.OnEnterHeader then
                            self:OnEnterHeader()
                        elseif BETTERUI and BETTERUI.Interface and BETTERUI.Interface.Window and BETTERUI.Interface.Window.SetTextSearchFocused then
                            BETTERUI.Interface.Window.SetTextSearchFocused(self, true)
                        else
                            if self.headerGeneric and self.headerGeneric.tabBar and self.headerGeneric.tabBar.Activate then
                                self.headerGeneric.tabBar:Activate()
                            end
                        end
                    end
                end)
                return true
            end
            return ok
        end
    end

    -- Configuration for directional input fix timing (ms)
    local directionalFixDelayMs = 60

    -- Diagnostics removed in production: kept stub for manual debugging if needed.
    local function DumpDirectionalInputDiagnostics()
        -- intentionally left blank
    end

    -- Expose helpers on self for calls inside handlers
    self.DumpDirectionalInputDiagnostics = DumpDirectionalInputDiagnostics
    self.AggressiveDirectionalCleanup = function()
        -- Deprecated: Aggressive cleanup removed in favor of explicit state management.
        -- Kept as no-op stub to prevent errors if external code calls it.
    end

    self.control:SetHandler("OnEffectivelyShown", OnEffectivelyShown)
    self.control:SetHandler("OnEffectivelyHidden", OnEffectivelyHidden)

    -- Always-running event listeners, these don't add much overhead
    self.control:RegisterForEvent(EVENT_CARRIED_CURRENCY_UPDATE, UpdateCurrency_Handler)
    self.control:RegisterForEvent(EVENT_BANKED_CURRENCY_UPDATE, UpdateCurrency_Handler)
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
        if SCENE_MANAGER.scenes['gamepad_banking']:IsShowing() then
            dialog.entryList:SetOnSelectedDataChangedCallback(function(list, selectedData)
                self.itemActions:SetSelectedAction(selectedData and selectedData.action)
            end)

            local parametricList = dialog.info.parametricList
            ZO_ClearNumericallyIndexedTable(parametricList)

            self:RefreshItemActions()

            local actions = self.itemActions:GetSlotActions()
            local numActions = actions:GetNumSlotActions()

            for i = 1, numActions do
                local action = actions:GetSlotAction(i)
                local actionName = actions:GetRawActionName(action)

                -- Hide Destroy/Delete in deposit mode (banker and house bank)
                local isDestroy = (actionName == GetString(SI_ITEM_ACTION_DESTROY)) or
                    (SI_ITEM_ACTION_DELETE and actionName == GetString(SI_ITEM_ACTION_DELETE))
                if not (self.currentMode == LIST_DEPOSIT and isDestroy) then
                    local entryData = ZO_GamepadEntryData:New(actionName)
                    entryData:SetIconTintOnSelection(true)
                    entryData.action = action
                    entryData.setup = ZO_SharedGamepadEntry_OnSetup

                    local listItem =
                    {
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
        if SCENE_MANAGER.scenes['gamepad_banking']:IsShowing() then
            -- make sure to wipe out the keybinds added by actions
            self:AddKeybinds()
            --restore the selected inventory item

            self:RefreshItemActions()

            -- refresh so keybinds react to newly selected item

            self:RefreshList()
        end
    end
    local function ActionDialogButtonConfirm(dialog)
        if SCENE_MANAGER.scenes['gamepad_banking']:IsShowing() then
            local selectedAction = self.itemActions and self.itemActions.selectedAction or nil
            if not selectedAction then return end
            local selectedName = ZO_InventorySlotActions:GetRawActionName(selectedAction)
            if selectedName == GetString(SI_ITEM_ACTION_LINK_TO_CHAT) then
                -- Link to chat
                local targetData = self:GetList().selectedData
                local itemLink
                local bag, slot = ZO_Inventory_GetBagAndIndex(targetData)
                if bag and slot then
                    itemLink = GetItemLink(bag, slot)
                end
                if itemLink then
                    ZO_LinkHandler_InsertLink(zo_strformat("[<<2>>]", SI_TOOLTIP_ITEM_NAME, itemLink))
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

--[[
Function: BETTERUI.Banking.Class:ActivateSpinner
Description: Activates the quantity spinner.
Rationale: Shows the spinner for partial stack moves (withdraw/deposit X amount).
]]
function BETTERUI.Banking.Class:ActivateSpinner()
    self.spinner:SetHidden(false)
    self.spinner:Activate()
    if (self:GetList() ~= nil) then
        self:GetList():Deactivate()
        -- Only manipulate keybinds if our banking scene is visible
        if SCENE_MANAGER.scenes['gamepad_banking'] and SCENE_MANAGER.scenes['gamepad_banking']:IsShowing() then
            KEYBIND_STRIP:RemoveAllKeyButtonGroups()
            KEYBIND_STRIP:AddKeybindButtonGroup(self.spinnerKeybindStripDescriptor)
        end
    end
end

--[[
Function: BETTERUI.Banking.Class:DeactivateSpinner
Description: Deactivates the quantity spinner and restores list focus.
Rationale: Called when spinner is canceled or confirmed.
]]
function BETTERUI.Banking.Class:DeactivateSpinner()
    self.spinner:SetValue(1)
    self.spinner:SetHidden(true)
    self.spinner:Deactivate()
    if (self:GetList() ~= nil) then
        self:GetList():Activate()
        -- Only restore keybinds/header when the banking scene is visible
        if SCENE_MANAGER.scenes['gamepad_banking'] and SCENE_MANAGER.scenes['gamepad_banking']:IsShowing() then
            KEYBIND_STRIP:RemoveAllKeyButtonGroups()
            KEYBIND_STRIP:AddKeybindButtonGroup(self.withdrawDepositKeybinds)
            KEYBIND_STRIP:AddKeybindButtonGroup(self.coreKeybinds)
            self:EnsureHeaderKeybindsActive()
        end
    end
end

--[[
Function: BETTERUI.Banking.Class:SaveListPosition
Description: Saves the current scroll position of the list.
Rationale: Persists the selected index so it can be restored after a refresh or mode switch.
Mechanism:
  - Saves per-mode (Withdraw/Deposit) to `lastPositions`.
  - Saves per-category to `lastPositionsByCategory` (shared across modes).
References: Called before RefreshList, ToggleList, or Mode Switches.
]]
function BETTERUI.Banking.Class:SaveListPosition()
    -- Able to return to the current position again!
    self.lastPositions[self.currentMode] = self.list.selectedIndex
    -- Save per-category position for current category (shared across modes in session)
    if self.bankCategories and #self.bankCategories > 0 then
        local cat = self.bankCategories[self.currentCategoryIndex or 1]
        if cat then
            self.lastPositionsByCategory[cat.key] = self.list.selectedIndex
        end
    end
end

--[[
Function: BETTERUI.Banking.Class:ReturnToSaved
Description: Restores the saved list position.
Rationale: Scrolls the list back to the previously saved index.
Mechanism:
  1. Checks `_justToggledMode` flag to reset to top if needed.
  2. Prioritizes per-category saved index (if available) over per-mode index.
  3. Clamps index to valid range (1 to item count).
  4. Handles mode switching if saved position implies a different context.
References: Called at the end of RefreshList.
]]
function BETTERUI.Banking.Class:ReturnToSaved()
    self:CurrentUsedBank()
    -- If there are no entries, avoid selecting index 1 (which would error)
    local totalEntries = (self.list and self.list.dataList and #self.list.dataList) or 0
    if totalEntries == 0 then
        -- Default to item keybinds and clear tooltip
        if KEYBIND_STRIP then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.currencyKeybinds)
            KEYBIND_STRIP:AddKeybindButtonGroup(self.withdrawDepositKeybinds)
            KEYBIND_STRIP:UpdateKeybindButtonGroup(self.withdrawDepositKeybinds)
        end
        if GAMEPAD_TOOLTIPS then
            GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
        end
        return
    end
    -- Skip restoration logic if we just toggled modes - category is already set correctly
    if self._justToggledMode then
        self.list:SetSelectedIndexWithoutAnimation(1, true, false)
        return
    end
    local lastPosition = self.lastPositions[self.currentMode]
    -- Prefer per-category saved index when available (shared across modes in session)
    if self.bankCategories and #self.bankCategories > 0 then
        local cat = self.bankCategories[self.currentCategoryIndex or 1]
        if cat then
            if self.lastPositionsByCategory and self.lastPositionsByCategory[cat.key] then
                lastPosition = self.lastPositionsByCategory[cat.key]
            end
        end
    end
    -- Default and clamp to valid range to avoid nil or OOB indices
    lastPosition = zo_clamp(tonumber(lastPosition) or 1, 1, totalEntries)
    if (self.currentMode == LIST_WITHDRAW) then
        if (lastUsedBank ~= currentUsedBank) then
            self.list:SetSelectedIndexWithoutAnimation(1, true, false)
            self:SaveListPosition()
            self.currentMode = LIST_DEPOSIT
            self.list:SetSelectedIndexWithoutAnimation(1, true, false)
            self:SaveListPosition()
            self.currentMode = LIST_WITHDRAW
            self:LastUsedBank()
            self:RefreshList()
        else
            self.list:SetSelectedIndexWithoutAnimation(lastPosition, true, false)
        end
    else
        if (lastUsedBank ~= currentUsedBank) then
            self.list:SetSelectedIndexWithoutAnimation(1, true, false)
            self:SaveListPosition()
            self:LastUsedBank()
            self.currentMode = LIST_WITHDRAW
            self:ToggleList(self.currentMode == LIST_WITHDRAW)
        else
            self.list:SetSelectedIndexWithoutAnimation(lastPosition, true, false)
        end
    end
end

--[[
Function: BETTERUI.Banking.Class:UpdateSingleItem
Description: Handles single slot updates (item add/remove/change).
Rationale: Triggers a list refresh when a specific slot changes.
param: bagId (number) - The bag ID.
param: slotIndex (number) - The slot index.
]]
function BETTERUI.Banking.Class:UpdateSingleItem(bagId, slotIndex)
    -- Rebuild the list from the shared inventory cache rather than mutating
    -- the parametric list internals while it's animating/moving.
    self:RefreshList()
end

--[[
Function: BETTERUI.Banking.Class:RemoveItemStack
Description: Handles item stack removal.
param: itemIndex (number) - The index of the item being removed.
]]
function BETTERUI.Banking.Class:RemoveItemStack(itemIndex)
    -- Avoid directly mutating the parametric list while it may be moving; just refresh.
    self:RefreshList()
end

--[[
Function: BETTERUI.Banking.Class:ToggleList
Description: Toggles between Withdraw and Deposit modes.
Rationale: Switches the banking context and refreshes the UI.
Mechanism:
  1. Saves current list position.
  2. Captures current category key to attempt restoration in new mode.
  3. Updates `currentMode` (LIST_WITHDRAW <-> LIST_DEPOSIT).
  4. Recomputes visible categories for the new mode.
  5. Updates Header Title and Footer Colors/Rotation.
  6. Refreshes Keybinds.
References: Called by "Y" Keybind (Secondary).
param: toWithdraw (boolean) - True if switching to Withdraw mode, False for Deposit.
]]
function BETTERUI.Banking.Class:ToggleList(toWithdraw)
    self:SaveListPosition()

    -- Capture the category KEY from CURRENT mode before switching
    local prevCategoryKey = nil
    local prevCategoryIndex = self.currentCategoryIndex or 1
    if self.bankCategories and prevCategoryIndex <= #self.bankCategories then
        local prevCat = self.bankCategories[prevCategoryIndex]
        if prevCat then
            prevCategoryKey = prevCat.key
        end
    end

    self.currentMode = toWithdraw and LIST_WITHDRAW or LIST_DEPOSIT
    -- Rebuild categories for the NEW mode
    self.bankCategories = self:ComputeVisibleBankCategories()

    -- Try to find the same category key in the new mode; if not found, default to All Items (index 1)
    local newCategoryIndex = 1 -- Default to All Items
    local categoryFound = false
    if prevCategoryKey then
        for i, cat in ipairs(self.bankCategories) do
            if cat.key == prevCategoryKey then
                newCategoryIndex = i
                categoryFound = true
                break
            end
        end
    end
    -- If category doesn't exist in new mode, ensure we default to All Items
    if not categoryFound then
        newCategoryIndex = 1
    end
    -- Clamp the index to valid range BEFORE setting it
    self.currentCategoryIndex = zo_clamp(newCategoryIndex, 1, #self.bankCategories)

    -- Reset list position to first item in the new mode
    self.lastPositions[self.currentMode] = 1
    -- Flag that we just toggled so RebuildHeaderCategories uses animation-free selection
    self._justToggledMode = true
    self:RebuildHeaderCategories()
    self._justToggledMode = false
    local footer = self.footer:GetNamedChild("Footer")
    if (self.currentMode == LIST_WITHDRAW) then
        footer:GetNamedChild("SelectBg"):SetTextureRotation(0)

        footer:GetNamedChild("DepositButtonLabel"):SetColor(0.26, 0.26, 0.26, 1)
        footer:GetNamedChild("WithdrawButtonLabel"):SetColor(1, 1, 1, 1)
    else
        footer:GetNamedChild("SelectBg"):SetTextureRotation(3.1415)

        footer:GetNamedChild("DepositButtonLabel"):SetColor(1, 1, 1, 1)
        footer:GetNamedChild("WithdrawButtonLabel"):SetColor(0.26, 0.26, 0.26, 1)
    end
    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds)
    --KEYBIND_STRIP:UpdateKeybindButtonGroup(self.spinnerKeybindStripDescriptor)
    self:RefreshList()
end

--[[
Function: BETTERUI.Banking.Class:CycleCategory
Description: Cycles the selected category via shoulder buttons (Left/Right).
param: delta (number) - Direction (+1 or -1).
]]


--[[
Function: BETTERUI.Banking.Class:UpdateHeaderTitle
Description: Updates the header title text to match the current category.
]]


--[[
Function: BETTERUI.Banking.Class:ClearTextSearch
Description: Clears the text search input and resets the query.
]]
function BETTERUI.Banking.Class:ClearTextSearch()
    self.searchQuery = ""
    if BETTERUI and BETTERUI.Interface and BETTERUI.Interface.Window and BETTERUI.Interface.Window.ClearSearchText then
        pcall(function() BETTERUI.Interface.Window.ClearSearchText(self) end)
    elseif self.ClearSearchText then
        pcall(function() self:ClearSearchText() end)
    end
end

--[[
Function: BETTERUI.Banking.Class:IsHeaderActive
Description: Checks if the header (or search field) is currently focused.
return: boolean - True if header or search is active.
]]
function BETTERUI.Banking.Class:IsHeaderActive()
    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.IsActive then
        local ok, active = pcall(function() return self.textSearchHeaderFocus:IsActive() end)
        if ok then
            return active
        end
    end
    return self._searchModeActive == true
end

--[[
Function: BETTERUI.Banking.Class:RequestEnterHeader
Description: Requests focus for the header/search control.
]]
function BETTERUI.Banking.Class:RequestEnterHeader()
    if self.OnEnterHeader then
        self:OnEnterHeader()
    else
        self:EnterSearchMode()
    end
end

--[[
Function: BETTERUI.Banking.Class:EnterSearchMode
Description: Enters text search mode, showing the search field and updating keybinds.
]]
function BETTERUI.Banking.Class:EnterSearchMode()
    if self._searchModeActive then return end
    self._searchModeActive = true


    pcall(function()
        if self.coreKeybinds then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.coreKeybinds)
        end
        if self.withdrawDepositKeybinds then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.withdrawDepositKeybinds)
        end
    end)

    if self.textSearchKeybindStripDescriptor then
        pcall(function() EnsureKeybindGroupAdded(self.textSearchKeybindStripDescriptor) end)
    end

    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.Activate then
        if not self.textSearchHeaderFocus:IsActive() then
            pcall(function() self.textSearchHeaderFocus:Activate() end)
        end
    end

    if self.SetTextSearchFocused then
        pcall(function() self:SetTextSearchFocused(true) end)
    end
end

--[[
Function: BETTERUI.Banking.Class:LeaveSearchMode
Description: Exits text search mode, hiding the search field and restoring standard keybinds.
]]
function BETTERUI.Banking.Class:LeaveSearchMode()
    if not self._searchModeActive then return end
    self._searchModeActive = false
    -- LeaveSearchMode: restore keybinds and header focus. No debug logging in production.
    pcall(function()
        if self.textSearchKeybindStripDescriptor then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.textSearchKeybindStripDescriptor)
        end
    end)

    -- Add back core keybinds and ensure coreKeybinds group is added
    pcall(function()
        if self.coreKeybinds then
            EnsureKeybindGroupAdded(self.coreKeybinds)
            KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds)
        end
    end)

    -- Call RefreshActiveKeybinds to determine and add the correct withdraw/deposit keybinds
    -- based on current selection (currency rows get currencyKeybinds, items get withdrawDepositKeybinds)
    pcall(function()
        self:RefreshActiveKeybinds()
    end)

    if self.textSearchHeaderFocus and self.textSearchHeaderFocus.Deactivate then
        if self.textSearchHeaderFocus:IsActive() then
            pcall(function() self.textSearchHeaderFocus:Deactivate() end)
        end
    end

    if self.SetTextSearchFocused then
        pcall(function() self:SetTextSearchFocused(false) end)
    end

    pcall(function() self:EnsureHeaderKeybindsActive() end)

    pcall(function() self:UpdateActions() end)

    -- No extra teardown required; leaving search mode handles restoring keybinds/list focus.
end

--[[
Function: BETTERUI.Banking.Class:PositionSearchControl
Description: Positions the search control beneath the header title.
Rationale: Ensures the search bar is visible and correctly aligned with the list.
]]
function BETTERUI.Banking.Class:PositionSearchControl()
    if not self.textSearchHeaderControl then return end
    -- Clear existing anchors then attach below the visible header area
    self.textSearchHeaderControl:ClearAnchors()
    local anchorTarget = self.headerGeneric or self.header
    -- Try to anchor under the header's TitleContainer if present, otherwise under the header itself
    local titleContainer = nil
    if anchorTarget and anchorTarget.GetNamedChild then
        titleContainer = anchorTarget:GetNamedChild("TitleContainer") or anchorTarget:GetNamedChild("Header")
    end
    local parentForAnchor = titleContainer or anchorTarget
    if parentForAnchor then
        -- Search bar position configured in BetterUI.CONST.lua
        local xOffset = BETTERUI_BANK_SEARCH_X_OFFSET
        local yOffset = BETTERUI_BANK_SEARCH_Y_OFFSET
        local rightInset = BETTERUI_BANK_SEARCH_RIGHT_INSET
        -- Anchor left with an X offset, and inset the right anchor slightly so control width remains reasonable
        self.textSearchHeaderControl:SetAnchor(TOPLEFT, parentForAnchor, BOTTOMLEFT, xOffset, yOffset)
        self.textSearchHeaderControl:SetAnchor(TOPRIGHT, parentForAnchor, BOTTOMRIGHT, rightInset, yOffset)
    else
        -- Fallback: anchor to header control bottom
        self.textSearchHeaderControl:SetAnchor(TOPLEFT, self.header, BOTTOMLEFT, 0, 8)
        self.textSearchHeaderControl:SetAnchor(TOPRIGHT, self.header, BOTTOMRIGHT, 0, 8)
    end
    self.textSearchHeaderControl:SetHidden(false)
end

--[[
Function: BETTERUI.Banking.Class:ExitSearchFocus
Description: Callback when search focus is lost.
]]
function BETTERUI.Banking.Class:ExitSearchFocus()
    self:LeaveSearchMode()
end

--[[
Function: BETTERUI.Banking.Class:OnEnterHeader
Description: Callback when the header is entered (navigating up from list).
Rationale: Auto-focuses the search field if appropriate.
]]
function BETTERUI.Banking.Class:OnEnterHeader()
    if self.textSearchHeaderControl and (not self.textSearchHeaderControl:IsHidden()) then
        self:EnterSearchMode()

        -- Call base implementation if present
        if BETTERUI and BETTERUI.Interface and BETTERUI.Interface.Window and BETTERUI.Interface.Window.OnEnterHeader then
            pcall(function() BETTERUI.Interface.Window.OnEnterHeader(self) end)
        end

        -- Ensure only the Clear keybind group remains visible shortly after entering header
        zo_callLater(function()
            if not self._searchModeActive then return end
            if not KEYBIND_STRIP then return end

            pcall(function()
                local keybindGroups = KEYBIND_STRIP.keybindButtonGroups
                if keybindGroups then
                    for i = #keybindGroups, 1, -1 do
                        local group = keybindGroups[i]
                        if group and group ~= self.textSearchKeybindStripDescriptor then
                            KEYBIND_STRIP:RemoveKeybindButtonGroup(group)
                        end
                    end
                end
            end)

            if not self._searchModeActive then return end

            if self.textSearchKeybindStripDescriptor then
                pcall(function()
                    EnsureKeybindGroupAdded(self.textSearchKeybindStripDescriptor)
                end)
            end
        end, 20)
    else
        -- Fallback to base behavior if no text search available
        if BETTERUI and BETTERUI.Interface and BETTERUI.Interface.Window and BETTERUI.Interface.Window.OnEnterHeader then
            pcall(function() BETTERUI.Interface.Window.OnEnterHeader(self) end)
        end
    end
end

--[[
Function: BETTERUI.Banking.Class:EnsureHeaderKeybindsActive
Description: Activates the category tab bar keybinds.
]]


--[[
Function: BETTERUI.Banking.Class:RebuildHeaderCategories
Description: Rebuilds the banking category header.
Rationale: Refresh the tab bar with icons for the current bank mode.
Mechanism:
  1. Configures the generic header data (Title, Carousel Config).
  2. Defines the `onSelectedChanged` callback to handle tab navigation with coalescence.
  3. Clears and Repopulates the Generic Header list with `bankCategories`.
  4. Selects the current category (handling animation suppression if needed).
  5. Updates Keybinds.
  6. Links the Text Search control to the Header Focus chain.
References: Called on Initialize, ToggleList, and Slot Updates.
]]


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
    BETTERUI.Banking.Window:SetTitle("|c0066FFAdvanced Banking|r")
    -- Initialize header with categories & selection immediately
    BETTERUI.Banking.Window:RebuildHeaderCategories()


    -- Set the column headings up, maybe put them into a table?
    BETTERUI.Banking.Window:AddColumn(GetString(SI_BETTERUI_BANKING_COLUMN_NAME), 87)
    BETTERUI.Banking.Window:AddColumn(GetString(SI_BETTERUI_BANKING_COLUMN_TYPE), 637)
    BETTERUI.Banking.Window:AddColumn(GetString(SI_BETTERUI_BANKING_COLUMN_TRAIT), 897)
    BETTERUI.Banking.Window:AddColumn(GetString(SI_BETTERUI_BANKING_COLUMN_STAT), 1067)
    BETTERUI.Banking.Window:AddColumn(GetString(SI_BETTERUI_BANKING_COLUMN_VALUE), 1187)

    BETTERUI.Banking.Window:RefreshList()

    SCENE_MANAGER.scenes['gamepad_banking'] = SCENE_MANAGER.scenes['BETTERUI_BANKING']

    esoSubscriber = IsESOPlusSubscriber()
end
