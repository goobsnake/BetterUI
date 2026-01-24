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

local esoSubscriber = BETTERUI.Banking.esoSubscriber

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
            SHARED_INVENTORY:PerformFullUpdateOnBagCache(BETTERUI.Banking.currentUsedBank)
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
            -- call original implementation
            local ok = _origMovePrevious(list, allowWrapping, suppressFailSound)

            if not ok then
                -- No previous entry; attempt to focus header/search like Inventory does
                -- No previous entry; attempt to focus header/search like Inventory does
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
