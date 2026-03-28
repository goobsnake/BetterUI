--[[
File: Modules/Banking/Banking.lua
Purpose: Implements the comprehensive banking interface for BetterUI.

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


-- LOCAL REFERENCES TO NAMESPACE CONSTANTS
-- These reference values from Core/BankingClass.lua (loaded first in manifest).
-- Using locals for performance in frequently-called functions.
local LIST_WITHDRAW                 = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT                  = BETTERUI.Banking.LIST_DEPOSIT
local CURRENCY_UI_REFRESH_DELAY_MS  = 40


local CreateSearchKeybindDescriptor = BETTERUI.Banking.CreateSearchKeybindDescriptor


---@param tlw_name string Top-level window name
---@param scene_name string Scene name for banking interface
---@return nil
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
    self.headerBaseTitle = GetString(rawget(_G, "SI_BETTERUI_BANK_TITLE"))

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
            local query
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
        isSceneShowing = BETTERUI.Utils.IsBankingSceneShowing,
        onTextChanged = function(window, txt)
            window.searchQuery = txt
            window:RefreshList()
        end,
        enterHeaderFn = function(window)
            if window.RequestHeaderFocus then
                window:RequestHeaderFocus()
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
            if selectedData and self.selectedDataCallback then
                local selectedControl = list:GetSelectedControl()
                self:selectedDataCallback(selectedControl, selectedData)
            end
            -- Now exit search focus
            self:OnSearchFocusLost()
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
            BETTERUI.Inventory.NewItemTracker.ClearImmediate(selectedControl.bagId, selectedControl.slotIndex)
            self:GetParametricList():RefreshList()
        end
    end

    -- these are event handlers which are specific to the banking interface. Handling the events this way encapsulates the banking interface
    -- these local functions are essentially just router functions to other functions within this class. it is done in this way to allow for
    -- us to access this classes' members (through "self")

    local function UpdateCurrency_Handler()
        -- Only update UI/keybinds when the banking scene is actually visible
        if not BETTERUI.Utils.IsBankingSceneShowing() then
            return
        end

        -- Currency transfers emit both carried+banked events; coalesce to one UI refresh.
        BETTERUI.Banking.Tasks:Schedule("currencyUiRefresh", CURRENCY_UI_REFRESH_DELAY_MS, function()
            if not BETTERUI.Utils.IsBankingSceneShowing() then
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
                if self.OnHeaderEntered then
                    self:OnHeaderEntered()
                elseif self.headerGeneric and self.headerGeneric.tabBar and self.headerGeneric.tabBar.Activate then
                    self.headerGeneric.tabBar:Activate()
                end
                return true
            end
            return ok
        end
    end

    -- Always-running event listeners
    self.control:RegisterForEvent(EVENT_CARRIED_CURRENCY_UPDATE, UpdateCurrency_Handler)
    self.control:RegisterForEvent(EVENT_BANKED_CURRENCY_UPDATE, UpdateCurrency_Handler)
end



--- Global initialization for the Banking module using BetterUI.Window.
---@return nil
function BETTERUI.Banking.Init()
    BETTERUI.Banking.Window = BETTERUI.Banking.Class:New("BETTERUI_BankingWindow", BETTERUI_BANKING_SCENE_NAME)
    BETTERUI.Banking.Window:SetTitle("|c0066FF" .. GetString(rawget(_G, "SI_BETTERUI_BANK_TITLE")) .. "|r")

    -- Initialize header with categories & selection immediately
    BETTERUI.Banking.Window:RebuildHeaderCategories()

    -- Set the column headings up using shared CIM constants
    local COLS = BETTERUI.CIM.CONST.HEADER_LAYOUT.COLUMNS
    BETTERUI.Banking.Window:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_NAME")), COLS.NAME)
    BETTERUI.Banking.Window:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_TYPE")), COLS.TYPE)
    BETTERUI.Banking.Window:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_TRAIT")), COLS.TRAIT)
    BETTERUI.Banking.Window:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_STAT")), COLS.STAT)
    BETTERUI.Banking.Window:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_VALUE")), COLS.VALUE)

    -- Link column labels to sort controller AFTER columns are created
    if BETTERUI.Banking.Window.LinkColumnLabels then
        BETTERUI.Banking.Window:LinkColumnLabels()
    end

    BETTERUI.Banking.Window:RefreshList()

    SCENE_MANAGER.scenes['gamepad_banking'] = SCENE_MANAGER.scenes['BETTERUI_BANKING']

    -- Register guild bank scene: reuses the same Banking Window but with
    -- INTERACTION_GUILDBANK interaction type. GuildBankAdapter handles
    -- permission checks and bag routing at runtime.
    BETTERUI_GUILD_BANKING_SCENE = ZO_InteractScene:New(
        BETTERUI_GUILD_BANKING_SCENE_NAME,
        SCENE_MANAGER,
        BETTERUI.Banking.GUILD_BANK_INTERACTION
    )
    -- Add all required fragment groups (matching InitializeScene for the personal bank).
    -- Without these the scene shows dimmed with locked input.
    BETTERUI_GUILD_BANKING_SCENE:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    BETTERUI_GUILD_BANKING_SCENE:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD)
    local bankingFragment = BETTERUI.Banking.Window.fragment
    if bankingFragment then
        BETTERUI_GUILD_BANKING_SCENE:AddFragment(bankingFragment)
    end
    BETTERUI_GUILD_BANKING_SCENE:AddFragment(FRAME_EMOTE_FRAGMENT_INVENTORY)
    BETTERUI_GUILD_BANKING_SCENE:AddFragment(GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    BETTERUI_GUILD_BANKING_SCENE:AddFragment(MINIMIZE_CHAT_FRAGMENT)
    BETTERUI_GUILD_BANKING_SCENE:AddFragment(GAMEPAD_MENU_SOUND_FRAGMENT)
    if BETTERUI.Banking.Window.footerFragment then
        BETTERUI_GUILD_BANKING_SCENE:AddFragment(BETTERUI.Banking.Window.footerFragment)
    end
    -- Register lifecycle callbacks so OnSceneShowing/OnSceneHidden fire for guild bank.
    -- We temporarily swap self.scene so SceneLifecycle.Register picks up the guild bank scene.
    local personalScene = BETTERUI.Banking.Window.scene
    BETTERUI.Banking.Window.scene = BETTERUI_GUILD_BANKING_SCENE
    BETTERUI.CIM.SceneLifecycle.Register(BETTERUI.Banking.Window, {
        keybinds = { BETTERUI.Banking.Window.coreKeybinds },
        taskManager = BETTERUI.CIM.Tasks,
        onShowing = function(screen, wasPushed)
            BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.WIDTH)
            if screen.OnSceneShowing then
                screen:OnSceneShowing(wasPushed)
            end
        end,
        onHiding = function(screen)
            BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.ZO_WIDTH)
            if screen.OnSceneHiding then
                screen:OnSceneHiding()
            end
        end,
        onHidden = function(screen)
            if screen.OnSceneHidden then
                screen:OnSceneHidden()
            end
        end,
    })
    BETTERUI.Banking.Window.scene = personalScene -- restore personal bank as the primary scene ref
    -- Alias guild bank scene: vanilla's ZO_GuildBank_Gamepad_Initialize() has
    -- already created GAMEPAD_GUILD_BANK_SCENE at "gamepad_guild_bank" (XML
    -- OnInitialized runs before addon EVENT_ADD_ON_LOADED). We just overwrite
    -- the scene entry so vanilla's EVENT_OPEN_GUILD_BANK handler shows our
    -- scene instead. This matches the exact pattern used for personal bank above.
    SCENE_MANAGER.scenes['gamepad_guild_bank'] = SCENE_MANAGER.scenes[BETTERUI_GUILD_BANKING_SCENE_NAME]

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

    -- Register narration for Banking and Guild Bank scenes (ACC-001)
    if BETTERUI.CIM.Narration and BETTERUI.CIM.Narration.RegisterListNarration then
        -- Personal bank
        BETTERUI.CIM.Narration.RegisterListNarration(
            BETTERUI_BANKING_SCENE_NAME,
            function() return BETTERUI.Banking.Window and BETTERUI.Banking.Window:GetParametricList():GetTargetData() end,
            function() return BETTERUI.Banking.Window and BETTERUI.Banking.Window:GetTitle() end
        )
        -- Guild bank
        BETTERUI.CIM.Narration.RegisterListNarration(
            BETTERUI_GUILD_BANKING_SCENE_NAME,
            function() return BETTERUI.Banking.Window and BETTERUI.Banking.Window:GetParametricList():GetTargetData() end,
            function() return BETTERUI.Banking.Window and BETTERUI.Banking.Window:GetTitle() end
        )
    end

end
