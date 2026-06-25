local LIST_WITHDRAW                 = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT                  = BETTERUI.Banking.LIST_DEPOSIT
local CURRENCY_UI_REFRESH_DELAY_MS  = 40

local CreateSearchKeybindDescriptor = BETTERUI.Banking.CreateSearchKeybindDescriptor

local function CreateBankingItemActions(alignment)
    local createItemActions = BETTERUI.Banking and BETTERUI.Banking.CreateItemActions or nil
    if type(createItemActions) == "function" then
        return createItemActions(alignment)
    end
    return nil
end

local function ClearSelectedItemNewStatus(bagId, slotIndex)
    local clearItemNewStatus = BETTERUI.Banking and BETTERUI.Banking.ClearItemNewStatus or nil
    if type(clearItemNewStatus) == "function" then
        clearItemNewStatus(bagId, slotIndex)
    end
end

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

local function SetInitialBankingWatchView(mode)
    local watch = BETTERUI.CIM and BETTERUI.CIM.WatchMode
    if not (watch and type(watch.SetView) == "function") then return end
    watch.SetView(mode == LIST_DEPOSIT and "banking.deposit" or "banking.withdraw")
end

---@return table|nil
function BETTERUI.Banking.GetSortEntryContext()
    local window = BETTERUI.Banking and BETTERUI.Banking.Window or nil
    if window and window.list then
        return {
            list = window.list,
            sortContext = window,
        }
    end
    return nil
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
    self.itemActions = CreateBankingItemActions(KEYBIND_STRIP_ALIGN_LEFT)
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
        BETTERUI.CIM.ScrollIndicator.Setup(listControl, {
            listObject = self.list,
            visibleItems = BETTERUI.CIM.CONST.UI.BANKING_VISIBLE_ITEMS,
            offsetX = 25,
            offsetTopY = -5,
            offsetBottomY = -10,
        })
    end

    self.currentMode = LIST_WITHDRAW
    SetInitialBankingWatchView(self.currentMode)
    self.lastPositions = { [LIST_WITHDRAW] = 1, [LIST_DEPOSIT] = 1 }
    self.lastPositionsByCategory = {}

    local transferContext = BETTERUI.Banking.ReadTransferContextSnapshot()
    BETTERUI.Banking.SetRuntimeBankBags(transferContext.interactionBag, nil)
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
            BETTERUI.CIM.ScrollIndicator.Update(list.control)
        end

        if selectedData then
            self:RefreshItemActions()
        end
        if selectedControl and selectedControl.bagId then
            ClearSelectedItemNewStatus(selectedControl.bagId, selectedControl.slotIndex)
            self:GetParametricList():RefreshList()
        end
    end

    local function UpdateCurrency_Handler()
        if not BETTERUI.Utils.IsBankingSceneShowing() then
            if BETTERUI.Log and BETTERUI.Log.Trace then
                BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.STATE, "bank currency UI refresh skipped", {
                    reason = "sceneHidden",
                })
            end
            return
        end

        if BETTERUI.Log then
            BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.STATE, "bank currency UI refresh scheduled", {
                delayMs = CURRENCY_UI_REFRESH_DELAY_MS,
                mode = self.currentMode,
            })
        end
        BETTERUI.Banking.Tasks:Schedule("currencyUiRefresh", CURRENCY_UI_REFRESH_DELAY_MS, function()
            if not BETTERUI.Utils.IsBankingSceneShowing() then
                if BETTERUI.Log and BETTERUI.Log.Trace then
                    BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.STATE, "bank currency UI refresh skipped", {
                        reason = "sceneHiddenDeferred",
                        mode = self.currentMode,
                    })
                end
                return
            end

            local currentUsedBank = BETTERUI.Banking.GetCurrentUsedBank()
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
            if BETTERUI.Log then
                BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.STATE, "bank currency UI refresh complete", {
                    mode = self.currentMode,
                    categoryKey = activeCategoryForHeader and activeCategoryForHeader.key or nil,
                    showingCurrencyRows = showingCurrencyRows,
                })
            end
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
        BETTERUI.Banking.SetLastOpenedBankBag(bankBag or BAG_BANK)
    end)
    if BETTERUI.Log then
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIFECYCLE, "event registered", { event = "EVENT_OPEN_BANK" })
    end

    EVENT_MANAGER:UnregisterForEvent(CLOSE_BANK_TRACKER_EVENT_NAME, EVENT_CLOSE_BANK)
    EVENT_MANAGER:RegisterForEvent(CLOSE_BANK_TRACKER_EVENT_NAME, EVENT_CLOSE_BANK, function()
        if IsBankOpen and IsBankOpen() then
            BETTERUI.Banking.SetLastOpenedBankBag(GetBankingBag())
        end
    end)
    if BETTERUI.Log then
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIFECYCLE, "event registered", { event = "EVENT_CLOSE_BANK" })
    end

    self.control:RegisterForEvent(EVENT_CARRIED_CURRENCY_UPDATE, UpdateCurrency_Handler)
    if BETTERUI.Log then
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIFECYCLE, "event registered", { event = "EVENT_CARRIED_CURRENCY_UPDATE" })
    end
    self.control:RegisterForEvent(EVENT_BANKED_CURRENCY_UPDATE, UpdateCurrency_Handler)
    if BETTERUI.Log then
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIFECYCLE, "event registered", { event = "EVENT_BANKED_CURRENCY_UPDATE" })
    end

    if BETTERUI.Log then
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIFECYCLE, "banking class initialized", { scene = scene_name })
    end
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

    if BETTERUI.Log then
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIFECYCLE, "banking initialized", {
            guildBank = BETTERUI.Banking.GetSetting("enableGuildBank") ~= false,
        })
    end
end

local function CountBankingSnapshotRows(list)
    local dataList = list and (list.dataList or (list.list and list.list.dataList))
    return type(dataList) == "table" and #dataList or 0
end

local function BankingSnapshotToken(value)
    local token = tostring(value or "none")
    return (token:gsub("|", "/"):gsub("%s+", "_"))
end

local function BankingSnapshotCategoryKey(window)
    local cat = window and window.bankCategories and window.bankCategories[window.currentCategoryIndex or 1]
    return BankingSnapshotToken(cat and (cat.key or cat.name) or "none")
end

local function BankingSnapshotControlVisible(control)
    if not control then return false end
    if control.IsHidden then
        local ok, hidden = pcall(function() return control:IsHidden() end)
        if ok then return hidden ~= true end
    end
    return false
end

local function BankingSnapshotVisible(window)
    if BETTERUI.Utils and type(BETTERUI.Utils.IsBankingSceneShowing) == "function" then
        local ok, showing = pcall(BETTERUI.Utils.IsBankingSceneShowing)
        -- Personal banking uses this utility as the fastest true signal. Guild-bank
        -- windows can be visible through their own scene/control path while the
        -- personal-bank utility returns false, so false falls through to the broader
        -- checks below.
        if ok and showing == true then return true end
    end
    if window.scene and window.scene.IsShowing then
        local ok, showing = pcall(function() return window.scene:IsShowing() end)
        if ok then return showing == true end
    end
    return BankingSnapshotControlVisible(window.control)
end

local function BankingSnapshotKeybindPresent(descriptor)
    if descriptor and KEYBIND_STRIP and KEYBIND_STRIP.HasKeybindButtonGroup then
        local ok, hasGroup = pcall(function()
            return KEYBIND_STRIP:HasKeybindButtonGroup(descriptor)
        end)
        return (ok and hasGroup) and 1 or 0
    end
    return 0
end

local function RegisterBankingSnapshotProvider()
    local watch = BETTERUI.CIM and BETTERUI.CIM.WatchMode
    if not (watch and watch.RegisterSnapshotProvider) then return end
    watch.RegisterSnapshotProvider("banking", function()
        local window = BETTERUI.Banking and BETTERUI.Banking.Window or nil
        if not window then return "window=0" end
        if not BankingSnapshotVisible(window) then return "window=1 visible=0" end
        local pending = 0
        if BETTERUI.Banking.CountPendingTransfers then
            local ok, count = pcall(BETTERUI.Banking.CountPendingTransfers)
            if ok and type(count) == "number" then pending = count end
        end
        local integration = window._headerSortIntegration
        local headerSortController = window.headerSortController
        local keybindCore = BankingSnapshotKeybindPresent(window.coreKeybinds)
        local keybindHeader = BankingSnapshotKeybindPresent(
            (headerSortController and headerSortController._headerSortKeybindDescriptor)
            or (integration and integration.activeKeybindDescriptor)
            or window.headerSortKeybindDescriptor)
        local headerActive = (window.isInHeaderSortMode == true or (integration and integration.isActive == true)) and 1 or 0
        return string.format(
            "window=1 visible=1 mode=%s category=%s rows=%d suppressed=%d dirty=%d pending=%d search=%d keybindCore=%d keybindHeader=%d headerActive=%d",
            tostring(window.currentMode or "?"),
            tostring(BankingSnapshotCategoryKey(window)),
            CountBankingSnapshotRows(window.list),
            window._suppressListUpdates and 1 or 0,
            window.isDirty and 1 or 0,
            pending,
            window.searchQuery and #tostring(window.searchQuery) or 0,
            keybindCore,
            keybindHeader,
            headerActive)
    end)
end

RegisterBankingSnapshotProvider()
