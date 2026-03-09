--[[
File: Modules/Banking/Banking.lua
Purpose: Implements the comprehensive banking interface for BetterUI.
Author: BetterUI Team
Last Modified: 2026-02-08

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
local function BuildBankUpgradeDetailsLines()
    local BANK_CAPACITY_ICON_TEXTURE = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds"
    local BANK_CAPACITY_ICON_SIZE = "90%"

    if GetBankingBag() ~= BAG_BANK then
        return nil
    end

    local currentUnlock = GetCurrentBankUpgrade and GetCurrentBankUpgrade() or 0
    local maxUnlock = GetMaxBankUpgrade and GetMaxBankUpgrade() or currentUnlock
    local upgradesRemaining = zo_max((maxUnlock or 0) - (currentUnlock or 0), 0)
    local slotsPerUpgrade = NUM_BANK_SLOTS_PER_UPGRADE or 0
    local slotMultiplier = (IsESOPlusSubscriber and IsESOPlusSubscriber()) and 2 or 1
    local slotsRemaining = upgradesRemaining * slotsPerUpgrade * slotMultiplier

    local primaryBankSize = GetBagUseableSize(BAG_BANK) or GetBagSize(BAG_BANK) or 0
    local subscriberBankSize = GetBagUseableSize(BAG_SUBSCRIBER_BANK) or GetBagSize(BAG_SUBSCRIBER_BANK) or 0
    local currentBankSize = primaryBankSize + subscriberBankSize
    local maxPurchasableSize = currentBankSize + slotsRemaining
    local canPurchaseUpgrade = IsBankUpgradeAvailable and IsBankUpgradeAvailable()

    local details = { rows = {} }
    local bankCapacityText = zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT, currentBankSize, maxPurchasableSize)
    local bankCapacityValue = zo_iconTextFormatNoSpaceAlignedRight(
        BANK_CAPACITY_ICON_TEXTURE,
        BANK_CAPACITY_ICON_SIZE,
        BANK_CAPACITY_ICON_SIZE,
        bankCapacityText,
        false,
        true
    )
    details.rows[#details.rows + 1] = {
        stat = GetString(SI_GAMEPAD_BANK_BANK_CAPACITY_LABEL),
        value = bankCapacityValue,
    }

    if canPurchaseUpgrade then
        local cost = GetNextBankUpgradePrice and GetNextBankUpgradePrice() or 0
        local costText = ZO_Currency_FormatGamepad(CURT_MONEY, cost, ZO_CURRENCY_FORMAT_AMOUNT_ICON)
        details.rows[#details.rows + 1] = {
            stat = GetString(SI_PROMPT_TITLE_BUY_BANK_SPACE),
            value = costText,
        }
    end

    return details
end

local BANK_UPGRADE_DETAILS_TOP_SPACING = 290

local function LayoutBankUpgradeDetailsTooltip(tooltip, details)
    if not tooltip or not details or not details.rows or #details.rows == 0 then
        return
    end

    local detailsMainSection = tooltip:AcquireSection(tooltip:GetStyle("bankCurrencyMainSection"))
    local detailsSection = tooltip:AcquireSection(tooltip:GetStyle("bankCurrencySection"))
    local function AddDetailsStatValuePair(statText, valueText)
        local statValuePair = detailsSection:AcquireStatValuePair(tooltip:GetStyle("currencyStatValuePair"))
        statValuePair:SetStat(statText, tooltip:GetStyle("currencyStatValuePairStat"))
        statValuePair:SetValue(valueText or "", tooltip:GetStyle("currencyStatValuePairValue"))
        detailsSection:AddStatValuePair(statValuePair)
    end

    for i = 1, #details.rows do
        local row = details.rows[i]
        AddDetailsStatValuePair(row.stat, row.value)
    end

    -- Push the bank-upgrade block lower so it sits closer to the tooltip bottom edge.
    detailsMainSection:SetNextSpacing(BANK_UPGRADE_DETAILS_TOP_SPACING)
    detailsMainSection:AddSection(detailsSection)
    tooltip:AddSection(detailsMainSection)
end

function BETTERUI.Banking.Class:RefreshCurrencyTooltip()
    if not BETTERUI.CIM.Utils.IsBankingSceneShowing() then return end
    local list = self:GetList()
    if not list or not list.selectedData or not list.selectedData.currencyType then return end

    GAMEPAD_TOOLTIPS:ClearLines(GAMEPAD_LEFT_TOOLTIP)
    GAMEPAD_TOOLTIPS:ClearLines(GAMEPAD_RIGHT_TOOLTIP)
    GAMEPAD_TOOLTIPS:LayoutBankCurrencies(GAMEPAD_LEFT_TOOLTIP, ZO_BANKABLE_CURRENCIES)

    local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(GAMEPAD_LEFT_TOOLTIP)
    LayoutBankUpgradeDetailsTooltip(tooltip, BuildBankUpgradeDetailsLines())
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

    -- NOTE: List anchoring is handled by the BETTERUI_GenericInterface template in InterfaceLibrary.xml
    -- The template uses offsetX=-50, offsetY=-25 to match Inventory's positioning

    self.list.maxOffset = BETTERUI_BANK_LIST_MAX_OFFSET
    self.list:SetHeaderPadding(GAMEPAD_HEADER_DEFAULT_PADDING * BETTERUI_BANK_HEADER_PADDING_SCALE,
        GAMEPAD_HEADER_SELECTED_PADDING * BETTERUI_BANK_HEADER_PADDING_SCALE)
    self.list:SetUniversalPostPadding(GAMEPAD_DEFAULT_POST_PADDING * BETTERUI_BANK_HEADER_PADDING_SCALE)

    -- Move selected item position up to align with tooltip arrow (matches Inventory)
    self.list:SetFixedCenterOffset(-50)

    -- Setup data templates of the lists
    BETTERUI.Banking.Class.SetupItemList(self.list)
    self:AddTemplate("BETTERUI_HeaderRow_Template", BETTERUI.Banking.Class.SetupLabelListing)

    -- Initialize scroll indicator for banking list
    -- offsetX=25, offsetTopY=-5 (above list top), offsetBottomY=-10 (above footer top)
    -- Note: List BOTTOMRIGHT is anchored 10px below FooterContainerFooter's top,
    -- so offsetBottomY=-10 aligns the container bottom with the footer's top edge.
    local listControl = self.list and self.list.control
    if listControl and BETTERUI.CIM.ScrollIndicator then
        BETTERUI.CIM.ScrollIndicator.Initialize(listControl, 25, -5, -10, self.list)
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
    if self.InitializeHeaderSortController then
        self:InitializeHeaderSortController()
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

    -- Hook into the actual edit box using the consolidated SearchFocusMixin
    -- This replaces ~70 lines of duplicate code (previously duplicated in InventoryClass.lua)
    BETTERUI.Interface.SearchMixin.SetupEditBoxHandlers(self, {
        isSceneShowing = BETTERUI.CIM.Utils.IsBankingSceneShowing,
        onTextChanged = function(window, txt)
            window.searchQuery = txt
            window:RefreshList()
        end,
        enterHeaderFn = function(window)
            if window.RequestEnterHeader then
                window:RequestEnterHeader()
            else
                window:EnterSearchMode()
            end
        end,
    })

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
        -- Use targetSelectedIndex (the intended final position) rather than GetSelectedIndex()
        -- (the animated intermediate) to prevent the thumb from stopping short of the bottom
        if list and list.control and BETTERUI.CIM.ScrollIndicator then
            local totalItems = list:GetNumItems() or 0
            local currentIndex = list.targetSelectedIndex or list:GetSelectedIndex() or 1
            local visibleItems = BETTERUI.CIM.CONST.UI.BANKING_VISIBLE_ITEMS
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

        -- Currency transfers emit both carried+banked events; coalesce to one UI refresh.
        BETTERUI.Banking.Tasks:Schedule("currencyUiRefresh", 40, function()
            if not BETTERUI.CIM.Utils.IsBankingSceneShowing() then
                return
            end

            local currentUsedBank = BETTERUI.Banking.currentUsedBank
            local activeCategoryForHeader = (self.bankCategories and self.bankCategories[self.currentCategoryIndex or 1]) or
                nil
            local showingCurrencyRows = (currentUsedBank == BAG_BANK)
                and (not activeCategoryForHeader or activeCategoryForHeader.key == "all")

            if showingCurrencyRows then
                -- Rebuild list so withdraw/deposit currency row counts are recalculated.
                self.isDirty = true
                self:RefreshList()
            end

            self:RefreshFooter()
            if KEYBIND_STRIP then
                KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds)
            end
            self:RefreshCurrencyTooltip()
        end)
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
    -- Ensure currency selector is hidden on scene entry (prevents stale selector from previous visit)
    if self.selector and self.selector.control then
        self.selector.control:GetParent():SetHidden(true)
        self.selector:Deactivate()
    end

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

    -- Re-activate list and refresh after any gamepad dialog fully closes.
    -- The QuantityDialog sets _suppressListUpdates=true before showing, which prevents
    -- OnInventoryUpdated from triggering a RefreshList (and list:Deactivate) while the
    -- dialog is still on screen. This callback clears that suppression and schedules
    -- a deferred refresh so the list is properly updated once dialog teardown is complete.
    self._onDialogHiddenCallback = function()
        if BETTERUI.CIM.Utils.IsBankingSceneShowing() and self.list then
            -- Clear update suppression first
            self._suppressListUpdates = false
            -- Schedule a deferred refresh so the dialog fragment has fully hidden
            -- before we rebuild the list (avoids visual glitches during the slide-out)
            BETTERUI.Banking.Tasks:Schedule("dialogHiddenRefresh", 50, function()
                if BETTERUI.CIM.Utils.IsBankingSceneShowing() then
                    self.bankCategories = self:ComputeVisibleBankCategories()
                    self:RefreshList()
                end
            end)
        end
    end
    CALLBACK_MANAGER:RegisterCallback("OnGamepadDialogHidden", self._onDialogHiddenCallback)
end

--[[
Function: BETTERUI.Banking.Class:OnSceneHiding
Description: Scene hiding handler called by SceneLifecycleManager.
Rationale: Abort any in-flight batch before cleanup to prevent background processing.
]]
function BETTERUI.Banking.Class:OnSceneHiding()
    if self:IsBatchProcessing() then
        self:RequestBatchAbort()
    end
end

--[[
Function: BETTERUI.Banking.Class:OnSceneHidden
Description: Scene hidden handler called by SceneLifecycleManager.
Rationale: Uses shared CIM.SceneCleanup helpers for consistent cleanup.
]]
function BETTERUI.Banking.Class:OnSceneHidden()
    self:LastUsedBank()
    self:CancelWithdrawDeposit(self.list)

    -- Force-hide currency selector to prevent stale state on re-entry
    if self.selector and self.selector.control then
        self.selector.control:GetParent():SetHidden(true)
        self.selector:Deactivate()
    end

    -- Use shared CIM cleanup for input state (header sort, selection mode, search focus, tab bar)
    BETTERUI.CIM.SceneCleanup.CleanupInputState(self)

    -- Deactivate lists to release DIRECTIONAL_INPUT
    BETTERUI.CIM.SceneCleanup.DeactivateLists(self)
    self.confirmationMode = false

    if KEYBIND_STRIP then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.textSearchKeybindStripDescriptor)
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.withdrawDepositKeybinds)
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.coreKeybinds)
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.currencyKeybinds)
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.currencySelectorKeybinds)
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.spinnerKeybindStripDescriptor)
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.mainKeybindStripDescriptor)
        if self._activeHeaderSortKeybindDescriptor then
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self._activeHeaderSortKeybindDescriptor)
            self._activeHeaderSortKeybindDescriptor = nil
        end
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.headerSortKeybindDescriptor)
    end
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
    -- Unregister dialog hidden callback
    if self._onDialogHiddenCallback then
        CALLBACK_MANAGER:UnregisterCallback("OnGamepadDialogHidden", self._onDialogHiddenCallback)
        self._onDialogHiddenCallback = nil
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
    -- Skip itemActions updates when in header sort mode to prevent keybind flicker
    if self.isInHeaderSortMode then
        return
    end
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

            -- Add "Sort" entry for header sort mode access
            if self.list and not self.list:IsEmpty() and self.EnterHeaderSortMode then
                local sortEntry = ZO_GamepadEntryData:New(GetString(SI_BETTERUI_HEADER_SORT))
                sortEntry:SetIconTintOnSelection(true)
                sortEntry.isSortAction = true
                sortEntry.sortContext = self -- Store Banking class for callback
                sortEntry.setup = ZO_SharedGamepadEntry_OnSetup

                local listItem = {
                    template = "ZO_GamepadItemEntryTemplate",
                    entryData = sortEntry,
                }
                table.insert(parametricList, listItem)
            end

            -- Move "Get Help" to end of list (should always be last action)
            local getHelpName = GetString(SI_ITEM_ACTION_REPORT_ITEM)
            local getHelpIndex = nil
            for i, entry in ipairs(parametricList) do
                if entry.entryData and entry.entryData.GetText and entry.entryData:GetText() == getHelpName then
                    getHelpIndex = i
                    break
                end
            end
            if getHelpIndex and getHelpIndex < #parametricList then
                local getHelpEntry = table.remove(parametricList, getHelpIndex)
                table.insert(parametricList, getHelpEntry)
            end

            dialog:setupFunc()
        end
    end

    local function ActionDialogFinish()
        if BETTERUI.CIM.Utils.IsBankingSceneShowing() then
            -- Skip keybind restoration if we're entering header sort mode
            -- (EnterHeaderSortMode already set up its own keybinds)
            if not self.isInHeaderSortMode then
                -- make sure to wipe out the keybinds added by actions
                self:AddKeybinds()
            end
            --restore the selected inventory item

            self:RefreshItemActions()
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

            -- Handle "Sort" entry to enter header sort mode
            if selectedEntry and selectedEntry.isSortAction then
                ZO_Dialogs_ReleaseDialogOnButtonPress(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG)
                local sortContext = selectedEntry.sortContext or self
                if sortContext and sortContext.EnterHeaderSortMode then
                    sortContext:EnterHeaderSortMode()
                end
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
    BETTERUI.Banking.Window = BETTERUI.Banking.Class:New("BETTERUI_BankingWindow", BETTERUI_BANKING_SCENE_NAME)
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

    -- =========================================================================
    -- KEYBOARD SHORTCUT INTERCEPTION
    -- Prevents keyboard keys (I, G, M, etc.) from interrupting the banking
    -- ZO_InteractScene mid-interaction. Without this, pressing a keyboard
    -- toggle key while banking causes:
    --   1. Banking closes (interaction ends)
    --   2. InteractScene fires RequestShowLeaderBaseScene (shows HUD)
    --   3. Target scene never opens → blurry screen / broken state
    --
    -- Fix: Hook SCENE_MANAGER:Toggle and :Show while banking is active.
    -- When intercepted, close banking properly via HideCurrentScene (the same
    -- mechanism used by the Back button), then open the target scene after
    -- the banking scene fully hides.
    --
    -- IMPORTANT: HideCurrentScene() internally calls Show("hud") which would
    -- re-enter our hook. The `intercepting` guard prevents infinite recursion.
    -- =========================================================================
    local originalToggle = SCENE_MANAGER.Toggle
    local originalShow = SCENE_MANAGER.Show
    local bankingSceneName = BETTERUI_BANKING_SCENE_NAME
    local intercepting = false -- Re-entrancy guard

    --- Intercept a scene transition request issued while banking is active.
    --- Closes banking properly via the scene manager and queues the target
    --- scene to open after the banking scene has fully hidden.
    --- @param targetSceneName string The scene the keyboard shortcut wants to show
    local function InterceptSceneChange(targetSceneName)
        -- Re-entrancy guard: HideCurrentScene() internally calls Show("hud"),
        -- which would re-enter this hook. Pass through during teardown.
        if intercepting then
            return false
        end

        -- Don't intercept if the target IS the banking scene (that's just a close)
        if targetSceneName == bankingSceneName or targetSceneName == "gamepad_banking" then
            return false
        end

        -- Don't intercept base scene transitions (these are internal teardown)
        if targetSceneName == "hud" or targetSceneName == "hudui" then
            return false
        end

        local bankScene = SCENE_MANAGER:GetScene(bankingSceneName)
        if not bankScene or not bankScene:IsShowing() then
            return false
        end

        -- Register a one-shot callback: once banking is fully hidden, show the target scene
        local function OnBankHidden(oldState, newState)
            if newState == SCENE_HIDDEN then
                bankScene:UnregisterCallback("StateChange", OnBankHidden)
                -- Brief delay to let interaction cleanup finish before showing target scene
                zo_callLater(function()
                    originalShow(SCENE_MANAGER, targetSceneName)
                end, 50)
            end
        end
        bankScene:RegisterCallback("StateChange", OnBankHidden)

        -- Close banking via the scene manager (same as the Back button).
        -- This properly triggers the full scene teardown: keybind removal,
        -- fragment hiding, and ZO_InteractScene:OnSceneHidden → EndInteraction.
        intercepting = true
        SCENE_MANAGER:HideCurrentScene()
        intercepting = false
        return true
    end

    SCENE_MANAGER.Toggle = function(sm, sceneName, ...)
        if InterceptSceneChange(sceneName) then return end
        return originalToggle(sm, sceneName, ...)
    end

    SCENE_MANAGER.Show = function(sm, sceneName, ...)
        if InterceptSceneChange(sceneName) then return end
        return originalShow(sm, sceneName, ...)
    end

    esoSubscriber = IsESOPlusSubscriber()
end
