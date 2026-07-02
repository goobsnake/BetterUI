local LIST_WITHDRAW                 = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT                  = BETTERUI.Banking.LIST_DEPOSIT
local CURRENCY_UI_REFRESH_DELAY_MS  = 40

local CreateSearchKeybindDescriptor = BETTERUI.Banking.CreateSearchKeybindDescriptor

local function TraceBankState(event, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    L.TraceEvent(L.CATEGORY.STATE, event, phase, data)
end

local GUILD_BANK_SCENE_REDIRECT_EVENT_NAME = "BETTERUI_GUILD_BANK_SCENE_REDIRECT"

local function ShowBetterUIGuildBankScene()
    if BETTERUI.Banking.GetSetting("enableGuildBank") == false then
        TraceBankState("bank.guild_scene_redirect", "bypassed", {
            reason = "guild_bank_disabled",
        })
        return
    end
    if not (SCENE_MANAGER and SCENE_MANAGER.Show and BETTERUI_GUILD_BANKING_SCENE_NAME and BETTERUI_GUILD_BANKING_SCENE) then
        TraceBankState("bank.guild_scene_redirect", "skipped", {
            reason = "missing_scene_api",
            hasSceneManager = SCENE_MANAGER ~= nil,
            hasSceneName = BETTERUI_GUILD_BANKING_SCENE_NAME ~= nil,
            hasScene = BETTERUI_GUILD_BANKING_SCENE ~= nil,
        })
        return
    end
    if SCENE_MANAGER.IsShowing and SCENE_MANAGER:IsShowing(BETTERUI_GUILD_BANKING_SCENE_NAME) then
        TraceBankState("bank.guild_scene_redirect", "skipped", {
            reason = "already_showing",
            sceneName = BETTERUI_GUILD_BANKING_SCENE_NAME,
        })
        return
    end
    TraceBankState("bank.guild_scene_redirect", "show", {
        sceneName = BETTERUI_GUILD_BANKING_SCENE_NAME,
    })
    SCENE_MANAGER:Show(BETTERUI_GUILD_BANKING_SCENE_NAME)
end

local function HideBetterUIGuildBankScene()
    if not (SCENE_MANAGER and SCENE_MANAGER.Hide and BETTERUI_GUILD_BANKING_SCENE_NAME) then
        return
    end
    if SCENE_MANAGER.IsShowing and not SCENE_MANAGER:IsShowing(BETTERUI_GUILD_BANKING_SCENE_NAME) then
        return
    end
    SCENE_MANAGER:Hide(BETTERUI_GUILD_BANKING_SCENE_NAME)
end

local function InstallGuildBankSceneRedirect()
    if not (EVENT_MANAGER and EVENT_OPEN_GUILD_BANK and EVENT_CLOSE_GUILD_BANK) then
        TraceBankState("bank.guild_scene_redirect", "skipped", { reason = "missingEvents" })
        return
    end

    EVENT_MANAGER:UnregisterForEvent(GUILD_BANK_SCENE_REDIRECT_EVENT_NAME, EVENT_OPEN_GUILD_BANK)
    EVENT_MANAGER:RegisterForEvent(GUILD_BANK_SCENE_REDIRECT_EVENT_NAME, EVENT_OPEN_GUILD_BANK, function()
        TraceBankState("bank.guild_scene_redirect", "open_event", {
            sceneName = BETTERUI_GUILD_BANKING_SCENE_NAME,
        })
        if type(zo_callLater) == "function" then
            zo_callLater(ShowBetterUIGuildBankScene, 0)
        else
            ShowBetterUIGuildBankScene()
        end
    end)

    EVENT_MANAGER:UnregisterForEvent(GUILD_BANK_SCENE_REDIRECT_EVENT_NAME, EVENT_CLOSE_GUILD_BANK)
    EVENT_MANAGER:RegisterForEvent(GUILD_BANK_SCENE_REDIRECT_EVENT_NAME, EVENT_CLOSE_GUILD_BANK, function()
        TraceBankState("bank.guild_scene_redirect", "close_event", {
            sceneName = BETTERUI_GUILD_BANKING_SCENE_NAME,
        })
        HideBetterUIGuildBankScene()
    end)
end

local function ReadCurrencyAmount(currencyType, location)
    if currencyType == nil or location == nil then return nil end
    local L = BETTERUI.Log
    if L and L.GetCurrencyAmountForLocation then
        return L.GetCurrencyAmountForLocation(currencyType, location)
    end
    if GetCurrencyAmount then
        local ok, amount = pcall(GetCurrencyAmount, currencyType, location)
        if ok then return amount end
    end
    return nil
end

local function CurrencyRefreshSnapshot(prefix)
    prefix = prefix or ""
    return {
        [prefix .. "CarriedGold"] = ReadCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER),
        [prefix .. "BankGold"] = ReadCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_BANK),
        [prefix .. "GuildBankGold"] = ReadCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_GUILD_BANK),
    }
end

local function BankCapacitySnapshot(prefix)
    prefix = prefix or ""
    local function ReadBagValue(fn, bagId)
        if type(fn) ~= "function" or bagId == nil then return nil end
        local ok, value = pcall(fn, bagId)
        if ok then return value end
        return nil
    end
    local primarySize = ReadBagValue(GetBagUseableSize, BAG_BANK)
    local subscriberSize = ReadBagValue(GetBagUseableSize, BAG_SUBSCRIBER_BANK)
    return {
        [prefix .. "BankUsed"] = ReadBagValue(GetNumBagUsedSlots, BAG_BANK),
        [prefix .. "BankSize"] = primarySize,
        [prefix .. "SubscriberBankUsed"] = ReadBagValue(GetNumBagUsedSlots, BAG_SUBSCRIBER_BANK),
        [prefix .. "SubscriberBankSize"] = subscriberSize,
        [prefix .. "TotalBankSize"] = primarySize and subscriberSize and (primarySize + subscriberSize) or nil,
        [prefix .. "CurrentUpgrade"] = GetCurrentBankUpgrade and GetCurrentBankUpgrade() or nil,
        [prefix .. "MaxUpgrade"] = GetMaxBankUpgrade and GetMaxBankUpgrade() or nil,
        [prefix .. "NextUpgradePrice"] = GetNextBankUpgradePrice and GetNextBankUpgradePrice() or nil,
    }
end

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
        TraceBankState("bank.scene_global", "skipped", { reason = "missingSceneManager" })
        return
    end

    local targetScene = SCENE_MANAGER.scenes[BETTERUI_BANKING_SCENE_NAME]
    if not targetScene then
        TraceBankState("bank.scene_global", "skipped", { reason = "missingTargetScene" })
        return
    end

    local changed = GAMEPAD_BANKING_SCENE ~= targetScene
    if GAMEPAD_BANKING_SCENE ~= targetScene then
        GAMEPAD_BANKING_SCENE = targetScene
    end
    TraceBankState("bank.scene_global", "synced", {
        changed = changed,
        sceneName = BETTERUI_BANKING_SCENE_NAME,
    })
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

    local function UpdateCurrency_Handler(eventCode)
        local beforeCurrency = CurrencyRefreshSnapshot("before")
        if not BETTERUI.Utils.IsBankingSceneShowing() then
            TraceBankState("bank.currency_ui_refresh", "skipped", {
                reason = "sceneHidden",
                eventCode = eventCode,
                beforeCarriedGold = beforeCurrency.beforeCarriedGold,
                beforeBankGold = beforeCurrency.beforeBankGold,
                beforeGuildBankGold = beforeCurrency.beforeGuildBankGold,
            })
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
        TraceBankState("bank.currency_ui_refresh", "scheduled", {
            eventCode = eventCode,
            delayMs = CURRENCY_UI_REFRESH_DELAY_MS,
            mode = self.currentMode,
            beforeCarriedGold = beforeCurrency.beforeCarriedGold,
            beforeBankGold = beforeCurrency.beforeBankGold,
            beforeGuildBankGold = beforeCurrency.beforeGuildBankGold,
        })
        BETTERUI.Banking.Tasks:Schedule("currencyUiRefresh", CURRENCY_UI_REFRESH_DELAY_MS, function()
            if not BETTERUI.Utils.IsBankingSceneShowing() then
                TraceBankState("bank.currency_ui_refresh", "skipped", {
                    reason = "sceneHiddenDeferred",
                    eventCode = eventCode,
                    mode = self.currentMode,
                    beforeCarriedGold = beforeCurrency.beforeCarriedGold,
                    beforeBankGold = beforeCurrency.beforeBankGold,
                    beforeGuildBankGold = beforeCurrency.beforeGuildBankGold,
                })
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
                BETTERUI.Interface.UpdateKeybindGroup(self.coreKeybinds)
            end
            self:RefreshCurrencyTooltip()
            local afterCurrency = CurrencyRefreshSnapshot("after")
            if BETTERUI.Log then
                BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.STATE, "bank currency UI refresh complete", {
                    mode = self.currentMode,
                    categoryKey = activeCategoryForHeader and activeCategoryForHeader.key or nil,
                    showingCurrencyRows = showingCurrencyRows,
                })
            end
            TraceBankState("bank.currency_ui_refresh", "complete", {
                eventCode = eventCode,
                mode = self.currentMode,
                categoryKey = activeCategoryForHeader and activeCategoryForHeader.key or nil,
                showingCurrencyRows = showingCurrencyRows,
                refreshedList = showingCurrencyRows,
                refreshedFooter = true,
                refreshedTooltip = true,
                keybindRefresh = KEYBIND_STRIP and self.coreKeybinds and "core" or "none",
                beforeCarriedGold = beforeCurrency.beforeCarriedGold,
                beforeBankGold = beforeCurrency.beforeBankGold,
                beforeGuildBankGold = beforeCurrency.beforeGuildBankGold,
                afterCarriedGold = afterCurrency.afterCarriedGold,
                afterBankGold = afterCurrency.afterBankGold,
                afterGuildBankGold = afterCurrency.afterGuildBankGold,
            })
        end)
    end

    local function RefreshBankCapacityUi(eventCode, reason)
        if not BETTERUI.Utils.IsBankingSceneShowing() then
            TraceBankState("bank.capacity_ui_refresh", "skipped", {
                reason = "sceneHidden",
                source = reason,
                eventCode = eventCode,
            })
            return
        end

        self.isDirty = true
        self:RefreshList()
        self:RefreshFooter()
        self:RefreshCurrencyTooltip()
        if KEYBIND_STRIP then
            BETTERUI.Interface.UpdateKeybindGroup(self.coreKeybinds)
        end
        local capacity = BankCapacitySnapshot("after")
        TraceBankState("bank.capacity_ui_refresh", "complete", {
            source = reason,
            eventCode = eventCode,
            refreshedList = true,
            refreshedFooter = true,
            refreshedTooltip = true,
            keybindRefresh = KEYBIND_STRIP and self.coreKeybinds and "core" or "none",
            afterBankUsed = capacity.afterBankUsed,
            afterBankSize = capacity.afterBankSize,
            afterSubscriberBankUsed = capacity.afterSubscriberBankUsed,
            afterSubscriberBankSize = capacity.afterSubscriberBankSize,
            afterTotalBankSize = capacity.afterTotalBankSize,
            afterCurrentUpgrade = capacity.afterCurrentUpgrade,
            afterMaxUpgrade = capacity.afterMaxUpgrade,
            afterNextUpgradePrice = capacity.afterNextUpgradePrice,
        })
    end

    local function TraceBankUpgradeEvent(phase, eventCode, data)
        local currency = CurrencyRefreshSnapshot("current")
        local capacity = BankCapacitySnapshot("current")
        data = data or {}
        data.eventCode = eventCode
        data.currentCarriedGold = currency.currentCarriedGold
        data.currentBankGold = currency.currentBankGold
        data.currentGuildBankGold = currency.currentGuildBankGold
        data.currentBankUsed = capacity.currentBankUsed
        data.currentBankSize = capacity.currentBankSize
        data.currentSubscriberBankUsed = capacity.currentSubscriberBankUsed
        data.currentSubscriberBankSize = capacity.currentSubscriberBankSize
        data.currentTotalBankSize = capacity.currentTotalBankSize
        data.currentUpgrade = capacity.currentCurrentUpgrade
        data.maxUpgrade = capacity.currentMaxUpgrade
        data.nextUpgradePrice = capacity.currentNextUpgradePrice
        TraceBankState("bank.upgrade", phase, data)
    end

    local function RegisterBankingControlEvent(eventName, eventId, handler)
        if eventId == nil then
            TraceBankState("bank.event_registration", "skipped", {
                event = eventName,
                reason = "missingEventConstant",
            })
            return
        end
        if self.control.UnregisterForEvent then
            self.control:UnregisterForEvent(eventId)
        end
        self.control:RegisterForEvent(eventId, handler)
        if BETTERUI.Log then
            BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIFECYCLE, "event registered", { event = eventName })
        end
    end

    local selectorContainer = self.control:GetNamedChild("Container"):GetNamedChild("InputContainer")
    self.selector = ZO_CurrencySelector_Gamepad:New(selectorContainer:GetNamedChild("Selector"))
    self.selector:SetClampValues(true)
    self.selectorCurrency = selectorContainer:GetNamedChild("CurrencyTexture")

    self.list:SetOnSelectedDataChangedCallback(SelectionChangedCallback)

    -- Extend this BetterUI-owned list to move "up" from the top into the header.
    -- When there is no previous entry, go to search bar (like Inventory) instead of header sort mode.
    -- Compatibility: this wrapper changes the return value, so a post-hook cannot preserve behavior.
    if self.list and self.list.MovePrevious and not self.list._betteruiMovePreviousWrapperInstalled then
        local _origMovePrevious = self.list.MovePrevious
        self.list._betteruiMovePreviousWrapperInstalled = true
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
        local openedBag = bankBag or BAG_BANK
        BETTERUI.Banking.SetLastOpenedBankBag(openedBag)
        local capacity = BankCapacitySnapshot("open")
        TraceBankState("bank.open", "event", {
            bankBag = openedBag,
            currentUsedBank = BETTERUI.Banking.GetCurrentUsedBank and BETTERUI.Banking.GetCurrentUsedBank() or nil,
            openBankUsed = capacity.openBankUsed,
            openBankSize = capacity.openBankSize,
            openSubscriberBankUsed = capacity.openSubscriberBankUsed,
            openSubscriberBankSize = capacity.openSubscriberBankSize,
            openTotalBankSize = capacity.openTotalBankSize,
            openCurrentUpgrade = capacity.openCurrentUpgrade,
            openMaxUpgrade = capacity.openMaxUpgrade,
            openNextUpgradePrice = capacity.openNextUpgradePrice,
        })
    end)
    if BETTERUI.Log then
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIFECYCLE, "event registered", { event = "EVENT_OPEN_BANK" })
    end

    EVENT_MANAGER:UnregisterForEvent(CLOSE_BANK_TRACKER_EVENT_NAME, EVENT_CLOSE_BANK)
    EVENT_MANAGER:RegisterForEvent(CLOSE_BANK_TRACKER_EVENT_NAME, EVENT_CLOSE_BANK, function()
        if IsBankOpen and IsBankOpen() then
            BETTERUI.Banking.SetLastOpenedBankBag(GetBankingBag())
        end
        TraceBankState("bank.close", "event", {
            isBankOpen = IsBankOpen and IsBankOpen() or nil,
            currentUsedBank = BETTERUI.Banking.GetCurrentUsedBank and BETTERUI.Banking.GetCurrentUsedBank() or nil,
        })
    end)
    if BETTERUI.Log then
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIFECYCLE, "event registered", { event = "EVENT_CLOSE_BANK" })
    end

    RegisterBankingControlEvent("EVENT_CARRIED_CURRENCY_UPDATE", EVENT_CARRIED_CURRENCY_UPDATE, UpdateCurrency_Handler)
    RegisterBankingControlEvent("EVENT_BANKED_CURRENCY_UPDATE", EVENT_BANKED_CURRENCY_UPDATE, UpdateCurrency_Handler)
    RegisterBankingControlEvent("EVENT_INVENTORY_BUY_BANK_SPACE", EVENT_INVENTORY_BUY_BANK_SPACE,
        function(eventCode, cost)
            TraceBankUpgradeEvent("prompted", eventCode, {
                cost = cost,
            })
        end)
    RegisterBankingControlEvent("EVENT_INVENTORY_BOUGHT_BANK_SPACE", EVENT_INVENTORY_BOUGHT_BANK_SPACE,
        function(eventCode, numberOfSlots)
            TraceBankUpgradeEvent("bought", eventCode, {
                numberOfSlots = numberOfSlots,
            })
            RefreshBankCapacityUi(eventCode, "EVENT_INVENTORY_BOUGHT_BANK_SPACE")
        end)
    RegisterBankingControlEvent("EVENT_INVENTORY_BANK_CAPACITY_CHANGED", EVENT_INVENTORY_BANK_CAPACITY_CHANGED,
        function(eventCode, previousCapacity, currentCapacity, previousUpgrade, currentUpgrade)
            TraceBankUpgradeEvent("capacity_changed", eventCode, {
                previousCapacity = previousCapacity,
                currentCapacity = currentCapacity,
                previousUpgrade = previousUpgrade,
                currentUpgrade = currentUpgrade,
            })
            RefreshBankCapacityUi(eventCode, "EVENT_INVENTORY_BANK_CAPACITY_CHANGED")
        end)

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
        -- Restore personal bank scene after registration; opening is redirected by event.
        BETTERUI.Banking.Window.scene = personalScene
        InstallGuildBankSceneRedirect()
    else
        TraceBankState("bank.guild_scene_redirect", "registration_skipped", {
            reason = "guild_bank_disabled",
        })
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
    return BETTERUI.Interface.HasKeybindGroup(descriptor) and 1 or 0
end

local function RegisterBankingWatchScenes(watch)
    if not (watch and watch.RegisterViewScene) then return end
    watch.RegisterViewScene("banking", BETTERUI_BANKING_SCENE_NAME or "gamepad_banking")
    watch.RegisterViewScene("banking", BETTERUI_GUILD_BANKING_SCENE_NAME or "BETTERUI_GUILD_BANKING")
end

local function RegisterBankingSnapshotProvider()
    local watch = BETTERUI.CIM and BETTERUI.CIM.WatchMode
    if not watch then return end
    RegisterBankingWatchScenes(watch)
    if not watch.RegisterSnapshotProvider then return end
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
