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

-- NOTE: Scene lifecycle methods (OnSceneShowing, OnSceneHiding, OnSceneHidden),
-- UpdateExternalAddons, and keyboard shortcut interception have been moved to
-- Scene/BankingSceneLifecycle.lua (loaded before this file in manifest).

-- NOTE: RefreshItemActions and InitializeActionsDialog have been moved to
-- Actions/BankingActions.lua (loaded before this file in manifest).

-- NOTE: ActivateSpinner and DeactivateSpinner have been removed.
-- Quantity selection now uses BETTERUI_BANK_QUANTITY_DIALOG (see Dialogs/QuantityDialog.lua)

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

    -- Install keyboard shortcut interception (from BankingSceneLifecycle.lua)
    BETTERUI.Banking.SetupSceneInterception()

    esoSubscriber = IsESOPlusSubscriber()
end
