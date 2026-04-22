local LIST_WITHDRAW                 = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT                  = BETTERUI.Banking.LIST_DEPOSIT
local CURRENCY_UI_REFRESH_DELAY_MS  = 40

local RuntimeState = BETTERUI.Banking.RuntimeState

local CreateSearchKeybindDescriptor = BETTERUI.Banking.CreateSearchKeybindDescriptor

local function SyncGamepadBankingSceneGlobal()
    if not SCENE_MANAGER or not SCENE_MANAGER.scenes then
        return
    end

    local targetScene = SCENE_MANAGER.scenes[BETTERUI_BANKING_SCENE_NAME]
    if not targetScene then
        return
    end

    if GAMEPAD_BANKING_SCENE ~= targetScene then
        GAMEPAD_BANKING_SCENE = targetScene
    end
end


---@param tlw_name string Top-level window name
---@param scene_name string Scene name for banking interface
---@return nil
function BETTERUI.Banking.Class:Initialize(tlw_name, scene_name)
    BETTERUI.CIM.UnifiedScreen.InitializeWindowShell(
        self,
        tlw_name,
        scene_name,
        BETTERUI.CIM.UnifiedScreen.FOOTER_MODE_BANKING
    )
    self.taskManager = BETTERUI.Banking.Tasks

    BETTERUI_BANKING_SCENE = ZO_InteractScene:New(
        BETTERUI_BANKING_SCENE_NAME,
        SCENE_MANAGER,
        BETTERUI.Banking.BANKING_INTERACTION
    )
    self:InitializeFragment()
    self:InitializeScene(BETTERUI_BANKING_SCENE)

    self:InitializeKeybind()
    self:InitializeList()
    self.itemActions = BETTERUI.CIM.Utils.CreateInventorySlotActions(KEYBIND_STRIP_ALIGN_LEFT)
    if self.itemActions then
        self.itemActions:SetUseKeybindStrip(false)
    end
    self:InitializeActionsDialog()


    self.list.maxOffset = BETTERUI_BANK_LIST_MAX_OFFSET
    self.list:SetHeaderPadding(GAMEPAD_HEADER_DEFAULT_PADDING * BETTERUI_BANK_HEADER_PADDING_SCALE,
        GAMEPAD_HEADER_SELECTED_PADDING * BETTERUI_BANK_HEADER_PADDING_SCALE)
    self.list:SetUniversalPostPadding(GAMEPAD_DEFAULT_POST_PADDING * BETTERUI_BANK_HEADER_PADDING_SCALE)

    -- Move selected item position up to align with tooltip arrow (matches Inventory)
    self.list:SetFixedCenterOffset(-50)

    BETTERUI.Banking.Class.SetupItemList(self.list)
    self:AddTemplate("BETTERUI_HeaderRow_Template", BETTERUI.Banking.Class.SetupLabelListing)

    -- offsetX=25, offsetTopY=-5 (above list top), offsetBottomY=-10 (above footer top)
    -- Note: List BOTTOMRIGHT is anchored 10px below FooterContainerFooter's top,
    -- so offsetBottomY=-10 aligns the container bottom with the footer's top edge.
    local listControl = self.list and self.list.control
    if listControl and BETTERUI.CIM.ScrollIndicator then
        BETTERUI.CIM.ScrollIndicator.Initialize(listControl, 25, -5, -10, self.list)
    end

    self.currentMode = LIST_WITHDRAW
    self.lastPositions = { [LIST_WITHDRAW] = 1, [LIST_DEPOSIT] = 1 }
    self.lastPositionsByCategory = {}

    RuntimeState.currentUsedBank = BETTERUI.Banking.GetTransferContext().interactionBag
    self.bankCategories = self:ComputeVisibleBankCategories()
    self.currentCategoryIndex = 1

    self.headerBaseTitle = GetString(rawget(_G, "SI_BETTERUI_BANK_TITLE"))

    self.headerGeneric = self.header:GetNamedChild("Header") or self.header
    BETTERUI.GenericHeader.Initialize(self.headerGeneric, ZO_GAMEPAD_HEADER_TABBAR_CREATE)
    self:RebuildHeaderCategories()

    if self.InitializeHeaderSortController then
        self:InitializeHeaderSortController()
    end

    self.textSearchKeybindStripDescriptor = CreateSearchKeybindDescriptor(self)

    if self.AddSearch then
        self:AddSearch(self.textSearchKeybindStripDescriptor, function(searchText)
            self.searchQuery = searchText
            self:SaveListPosition()
            self:RefreshList()
        end)
        if self.PositionSearchControl then
            self:PositionSearchControl()
        end
    end

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

    self.selectedDataCallback = BETTERUI.Banking.Class.OnItemSelectedChange

    local function SelectionChangedCallback(list, selectedData)
        if self._searchModeActive and self.list and self.list.IsActive and self.list:IsActive() then
            if selectedData and self.selectedDataCallback then
                local selectedControl = list:GetSelectedControl()
                self:selectedDataCallback(selectedControl, selectedData)
            end
            self:OnSearchFocusLost()
            return
        end

        local selectedControl = list:GetSelectedControl()
        if self.selectedDataCallback then
            self:selectedDataCallback(selectedControl, selectedData)
        end

        if list and list.control and BETTERUI.CIM.ScrollIndicator then
            local totalItems = list:GetNumItems() or 0
            local currentIndex = list.targetSelectedIndex or list:GetSelectedIndex() or 1
            local visibleItems = BETTERUI.CIM.CONST.UI.BANKING_VISIBLE_ITEMS
            BETTERUI.CIM.ScrollIndicator.Update(list.control, currentIndex, totalItems, visibleItems)
        end

        if selectedData then
            self:RefreshItemActions()
        end
        if selectedControl and selectedControl.bagId then
            BETTERUI.CIM.Utils.ClearTrackedInventorySlot(selectedControl.bagId, selectedControl.slotIndex)
            self:GetParametricList():RefreshList()
        end
    end

    local function UpdateCurrency_Handler()
        if not BETTERUI.Utils.IsBankingSceneShowing() then
            return
        end

        BETTERUI.Banking.Tasks:Schedule("currencyUiRefresh", CURRENCY_UI_REFRESH_DELAY_MS, function()
            if not BETTERUI.Utils.IsBankingSceneShowing() then
                return
            end

            local currentUsedBank = RuntimeState.currentUsedBank
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

    local OPEN_BANK_TRACKER_EVENT_NAME = "BETTERUI_BANKING_TRACK_OPEN_BAG"
    local CLOSE_BANK_TRACKER_EVENT_NAME = "BETTERUI_BANKING_TRACK_CLOSE_BAG"

    EVENT_MANAGER:UnregisterForEvent(OPEN_BANK_TRACKER_EVENT_NAME, EVENT_OPEN_BANK)
    EVENT_MANAGER:RegisterForEvent(OPEN_BANK_TRACKER_EVENT_NAME, EVENT_OPEN_BANK, function(_, bankBag)
        RuntimeState.lastOpenedBankBag = bankBag or BAG_BANK
    end)

    EVENT_MANAGER:UnregisterForEvent(CLOSE_BANK_TRACKER_EVENT_NAME, EVENT_CLOSE_BANK)
    EVENT_MANAGER:RegisterForEvent(CLOSE_BANK_TRACKER_EVENT_NAME, EVENT_CLOSE_BANK, function()
        if IsBankOpen and IsBankOpen() then
            RuntimeState.lastOpenedBankBag = GetBankingBag() or RuntimeState.lastOpenedBankBag
        end
    end)

    self.control:RegisterForEvent(EVENT_CARRIED_CURRENCY_UPDATE, UpdateCurrency_Handler)
    self.control:RegisterForEvent(EVENT_BANKED_CURRENCY_UPDATE, UpdateCurrency_Handler)
end

---@return nil
function BETTERUI.Banking.Init()
    BETTERUI.Banking.Window = BETTERUI.Banking.Class:New("BETTERUI_BankingWindow", BETTERUI_BANKING_SCENE_NAME)
    BETTERUI.Banking.Window:SetTitle("|c0066FF" .. GetString(rawget(_G, "SI_BETTERUI_BANK_TITLE")) .. "|r")

    BETTERUI.Banking.Window:RebuildHeaderCategories()

    local COLS = BETTERUI.CIM.CONST.HEADER_LAYOUT.COLUMNS
    BETTERUI.Banking.Window:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_NAME")), COLS.NAME)
    BETTERUI.Banking.Window:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_TYPE")), COLS.TYPE)
    BETTERUI.Banking.Window:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_TRAIT")), COLS.TRAIT)
    BETTERUI.Banking.Window:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_STAT")), COLS.STAT)
    BETTERUI.Banking.Window:AddColumn(GetString(rawget(_G, "SI_BETTERUI_BANKING_COLUMN_VALUE")), COLS.VALUE)

    if BETTERUI.Banking.Window.LinkColumnLabels then
        BETTERUI.Banking.Window:LinkColumnLabels()
    end

    BETTERUI.Banking.Window:RefreshList()

    SyncGamepadBankingSceneGlobal()

    if BETTERUI.Banking.GetSetting("enableGuildBank") ~= false then
        BETTERUI_GUILD_BANKING_SCENE = ZO_InteractScene:New(
            BETTERUI_GUILD_BANKING_SCENE_NAME,
            SCENE_MANAGER,
            BETTERUI.Banking.GUILD_BANK_INTERACTION
        )
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
        local personalScene = BETTERUI.Banking.Window.scene
        BETTERUI.Banking.Window.scene = BETTERUI_GUILD_BANKING_SCENE
        BETTERUI.CIM.SceneLifecycle.Register(BETTERUI.Banking.Window, {
            keybinds = { BETTERUI.Banking.Window.coreKeybinds },
            taskManager = BETTERUI.Banking.Tasks,
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
        -- Restore personal bank scene after registration, then remap the global guild scene key.
        BETTERUI.Banking.Window.scene = personalScene
        SCENE_MANAGER.scenes['gamepad_guild_bank'] = SCENE_MANAGER.scenes[BETTERUI_GUILD_BANKING_SCENE_NAME]
    end

    if BETTERUI.Banking.InitializeRefreshManager then
        BETTERUI.Banking.InitializeRefreshManager()
    end

    BETTERUI.Banking.InitializeQuantityDialog()

    BETTERUI.Banking.Window:SetupUnifiedFooter()

    BETTERUI.Banking.SetupSceneInterception()

    if BETTERUI.CIM.Narration and BETTERUI.CIM.Narration.RegisterListNarration then
        BETTERUI.CIM.Narration.RegisterListNarration(
            BETTERUI_BANKING_SCENE_NAME,
            function() return BETTERUI.Banking.Window and BETTERUI.Banking.Window:GetParametricList():GetTargetData() end,
            function() return BETTERUI.Banking.Window and BETTERUI.Banking.Window:GetTitle() end
        )
        BETTERUI.CIM.Narration.RegisterListNarration(
            BETTERUI_GUILD_BANKING_SCENE_NAME,
            function() return BETTERUI.Banking.Window and BETTERUI.Banking.Window:GetParametricList():GetTargetData() end,
            function() return BETTERUI.Banking.Window and BETTERUI.Banking.Window:GetTitle() end
        )
    end

end
