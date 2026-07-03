local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW
local SHARED_INVENTORY_UPDATE_DELAY_MS = 100

-- Guild bank events registered/unregistered as a batch during scene transitions
local GUILD_BANK_EVENTS = {
    EVENT_GUILD_BANK_SELECTED,
    EVENT_GUILD_BANK_DESELECTED,
    EVENT_GUILD_BANK_ITEMS_READY,
    EVENT_GUILD_BANK_ITEM_ADDED,
    EVENT_GUILD_BANK_ITEM_REMOVED,
    EVENT_GUILD_BANK_UPDATED_QUANTITY,
    EVENT_GUILD_BANK_OPEN_ERROR,
    EVENT_GUILD_BANKED_MONEY_UPDATE,
    EVENT_GUILD_RANKS_CHANGED,
    EVENT_GUILD_MEMBER_RANK_CHANGED,
    EVENT_GUILD_SELF_LEFT_GUILD,
}

local function RegisterGuildBankSceneEvents(GuildBank)
    if not GuildBank or not EVENT_MANAGER then
        return
    end

    GuildBank.RegisterGuildSelectorDialog()
    local ns = BETTERUI_GUILD_BANKING_SCENE_NAME or "BETTERUI_GUILD_BANKING"
    -- HIDING -> SHOWING can re-enter without OnSceneHidden running, which would
    -- leak the previous guild-bank event registrations. Unregister first.
    for _, event in ipairs(GUILD_BANK_EVENTS) do
        EVENT_MANAGER:UnregisterForEvent(ns, event)
    end
    local eventHandlers = {
        [EVENT_GUILD_BANK_SELECTED]         = GuildBank.OnGuildBankSelected,
        [EVENT_GUILD_BANK_DESELECTED]       = GuildBank.OnGuildBankDeselected,
        [EVENT_GUILD_BANK_ITEMS_READY]      = GuildBank.OnGuildBankReady,
        [EVENT_GUILD_BANK_ITEM_ADDED]       = GuildBank.OnGuildBankUpdated,
        [EVENT_GUILD_BANK_ITEM_REMOVED]     = GuildBank.OnGuildBankUpdated,
        [EVENT_GUILD_BANK_UPDATED_QUANTITY]  = GuildBank.OnGuildBankUpdated,
        [EVENT_GUILD_BANK_OPEN_ERROR]       = GuildBank.OnGuildBankOpenError,
        [EVENT_GUILD_BANKED_MONEY_UPDATE]   = GuildBank.OnGuildBankedMoneyUpdate,
        [EVENT_GUILD_RANKS_CHANGED]         = GuildBank.OnGuildRanksChanged,
        [EVENT_GUILD_MEMBER_RANK_CHANGED]   = GuildBank.OnGuildMemberRankChanged,
        [EVENT_GUILD_SELF_LEFT_GUILD]       = GuildBank.OnGuildSelfLeft,
    }
    for _, event in ipairs(GUILD_BANK_EVENTS) do
        EVENT_MANAGER:RegisterForEvent(ns, event, eventHandlers[event])
        if BETTERUI.Log then
            BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIFECYCLE, "event registered", { event = event })
        end
    end
end

local function InitializeBankSceneCategories(window)
    window.bankCategories = window:ComputeVisibleBankCategories()
    window.currentCategoryIndex = 1
    window.lastPositions[window.currentMode] = 1
    window:RebuildHeaderCategories()
    if window.headerGeneric and window.headerGeneric.tabBar then
        window.headerGeneric.tabBar:SetSelectedIndexWithoutAnimation(1, true, true)
    end
end


--- Scene showing handler called by SceneLifecycleManager.
function BETTERUI.Banking.Class:OnSceneShowing(wasPushed)
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SCENE, "scene showing", { wasPushed = wasPushed })
    end
    -- The quantity dialog sets list-update suppression; if the bank closes while
    -- the dialog is open, OnGamepadDialogHidden no-ops (scene not showing) and a
    -- HIDING -> SHOWING re-entry can skip OnSceneHidden cleanup, leaking the
    -- suppression. Always clear it on scene entry.
    self:SetListUpdatesSuppressed(false)

    -- Cancel any pending scene-recovery zo_callLater from a previous hidden
    -- transition; a HIDING -> SHOWING re-entry would otherwise let the stale
    -- callback fire after the scene is active again.
    if self._bankingSceneRecoverCallLaterId then
        zo_removeCallLater(self._bankingSceneRecoverCallLaterId)
        self._bankingSceneRecoverCallLaterId = nil
    end

    -- Ensure currency selector is hidden on scene entry
    if self.selector and self.selector.control then
        self.selector.control:GetParent():SetHidden(true)
        self.selector:Deactivate()
    end

    local transferContext = BETTERUI.Banking.ReadTransferContextSnapshot()
    BETTERUI.Banking.SetRuntimeBankBags(transferContext.interactionBag, nil)

    -- Guild bank detection: update title and check permissions
    local GuildBank = BETTERUI.Banking.GuildBank
    if GuildBank and GuildBank.IsGuildBankMode() then
        self.isGuildBankMode = true
        -- Guild bank: clear stale data before selecting because native selection
        -- can fire ITEMS_READY synchronously and populate the list immediately.
        self.list:Clear()
        self.list:Commit()
        self:SetTitle(GuildBank.GetHeaderTitle())
        -- Build categories/header before native selection because the selector
        -- can fire ITEMS_READY synchronously into GuildBank.OnGuildBankReady.
        InitializeBankSceneCategories(self)
        -- Register before selecting the guild bank; the native selector can fire
        -- ITEMS_READY synchronously, and missing that event leaves the list empty.
        RegisterGuildBankSceneEvents(GuildBank)
        -- Select the accessible guild bank and trigger data loading
        local guildId = GuildBank.GetSelectedGuildId()
        if ZO_SharedInventory_SelectAccessibleGuildBank and guildId > 0 then
            ZO_SharedInventory_SelectAccessibleGuildBank(guildId)
        end

        -- Check base permissions on scene entry
        local depositDenied = GuildBank.GetPermissionDenial(BETTERUI.Banking.LIST_DEPOSIT)
        local withdrawDenied = GuildBank.GetPermissionDenial(BETTERUI.Banking.LIST_WITHDRAW)
        if depositDenied and withdrawDenied then
            -- Cannot deposit or withdraw — show warning but allow viewing
            if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.SCENE, "Guild bank: no deposit or withdraw permission") end
        end
    else
        self.isGuildBankMode = false
        self:SetTitle("|c0066FF" .. GetString(rawget(_G, "SI_BETTERUI_BANK_TITLE")) .. "|r")
        InitializeBankSceneCategories(self)
    end

    if self.isGuildBankMode then
        -- Guild bank: list refresh is driven by EVENT_GUILD_BANK_ITEMS_READY.
        self:RefreshActiveKeybinds()
    else
        -- Always refresh on show to avoid stale rows when switching between
        -- player bank, house storage, and furniture vault contexts.
        self:RefreshList()
        self:RefreshActiveKeybinds()
    end
    self.list:Activate()
    self:AddKeybinds()

    self:UpdateExternalAddons(true)

    -- Register for SHARED_INVENTORY callbacks
    local function RebuildCategoriesAndRefreshList()
        local previousCategoryKey = nil
        if self.GetCurrentCategoryKey then
            previousCategoryKey = self:GetCurrentCategoryKey()
        elseif self.bankCategories and self.currentCategoryIndex and self.currentCategoryIndex <= #self.bankCategories then
            local prevCat = self.bankCategories[self.currentCategoryIndex]
            previousCategoryKey = prevCat and prevCat.key or nil
        end

        if self.RefreshTransferView then
            self:RefreshTransferView({
                preferredCategoryKey = previousCategoryKey,
            })
        elseif self.RefreshCategoryView then
            self:RefreshCategoryView({
                preferredCategoryKey = previousCategoryKey,
            })
        else
            self:RefreshList()
        end
    end

    local function TryRefreshAfterInventoryUpdate()
        if not BETTERUI.Utils.IsBankingSceneShowing() then
            return
        end

        if self:IsBatchProcessing() then
            BETTERUI.Banking.Tasks:Cancel("sharedInventoryUpdate")
            BETTERUI.Banking.Tasks:Schedule("sharedInventoryUpdate", SHARED_INVENTORY_UPDATE_DELAY_MS,
                TryRefreshAfterInventoryUpdate)
            return
        end

        if self:AreListUpdatesSuppressed() then
            if BETTERUI.Log then
                BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.SCENE, "refresh skipped: list updates suppressed", {
                    mode = self.currentMode,
                })
            end
            return
        end

        -- A pending moveCoalesce already covers this refresh; skip to avoid a double rebuild.
        if BETTERUI.Banking.Tasks:IsPending("moveCoalesce") then
            return
        end

        self.isDirty = true
        RebuildCategoriesAndRefreshList()
    end

    local function OnInventoryUpdated(bagId, slotIndex)
        if not BETTERUI.Utils.IsBankingSceneShowing() then return end
        local relevantBags
        if self.currentMode == LIST_WITHDRAW then
            relevantBags = BETTERUI.Banking.ReadTransferContextSnapshot().withdrawSourceBags
        else
            relevantBags = { BAG_BACKPACK }
        end
        local isRelevant = (bagId == nil)
        for _, bag in ipairs(relevantBags) do
            if bagId == bag then
                isRelevant = true
                break
            end
        end
        if not isRelevant then return end

        BETTERUI.Banking.Tasks:Cancel("sharedInventoryUpdate")
        BETTERUI.Banking.Tasks:Schedule("sharedInventoryUpdate", SHARED_INVENTORY_UPDATE_DELAY_MS,
            TryRefreshAfterInventoryUpdate)
    end
    -- HIDING -> SHOWING can re-enter without OnSceneHidden running, which would
    -- leak the previous closures; drop any stale registrations first.
    if self._inventoryFullUpdateCallback then
        SHARED_INVENTORY:UnregisterCallback("FullInventoryUpdate", self._inventoryFullUpdateCallback)
    end
    if self._inventorySingleSlotCallback then
        SHARED_INVENTORY:UnregisterCallback("SingleSlotInventoryUpdate", self._inventorySingleSlotCallback)
    end
    self._inventoryFullUpdateCallback = OnInventoryUpdated
    self._inventorySingleSlotCallback = OnInventoryUpdated
    SHARED_INVENTORY:RegisterCallback("FullInventoryUpdate", self._inventoryFullUpdateCallback)
    SHARED_INVENTORY:RegisterCallback("SingleSlotInventoryUpdate", self._inventorySingleSlotCallback)

    -- Re-activate list and refresh after any gamepad dialog fully closes
    if self._onDialogHiddenCallback then
        CALLBACK_MANAGER:UnregisterCallback("OnGamepadDialogHidden", self._onDialogHiddenCallback)
    end
    self._onDialogHiddenCallback = function()
        if BETTERUI.Utils.IsBankingSceneShowing() and self.list then
            self:SetListUpdatesSuppressed(false)
            BETTERUI.Banking.Tasks:Cancel("dialogHiddenRefresh")
            BETTERUI.Banking.Tasks:Schedule("dialogHiddenRefresh", 50, function()
                if BETTERUI.Utils.IsBankingSceneShowing() then
                    RebuildCategoriesAndRefreshList()
                end
            end)
        end
    end
    CALLBACK_MANAGER:RegisterCallback("OnGamepadDialogHidden", self._onDialogHiddenCallback)

end

--- Aborts any in-flight batch before cleanup.
function BETTERUI.Banking.Class:OnSceneHiding()
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SCENE, "scene hiding", { isBatchProcessing = self:IsBatchProcessing() })
    end
    if self:IsBatchProcessing() then
        self:RequestBatchAbort()
    end
end

--- Scene hidden handler called by SceneLifecycleManager.
function BETTERUI.Banking.Class:OnSceneHidden()
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SCENE, "scene hidden")
        local integration = self._headerSortIntegration
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.STATE, "bank scene pre-cleanup snapshot", {
            fn = "Banking:OnSceneHidden",
            headerSort = self.isInHeaderSortMode == true,
            active = integration and integration.isActive == true,
            activeKeybind = BETTERUI.Log.DescribeKeybindDescriptor and integration and BETTERUI.Log.DescribeKeybindDescriptor(integration.activeKeybindDescriptor, "active") or nil,
            suspendedCount = BETTERUI.Log.CountKeybindDescriptors and integration and BETTERUI.Log.CountKeybindDescriptors(integration.suspendedKeybindGroups) or 0,
            main = BETTERUI.Log.DescribeKeybindDescriptor and BETTERUI.Log.DescribeKeybindDescriptor(self.mainKeybindStripDescriptor, "main") or nil,
        })
    end

    -- PB-016: the Banking refresh manager lives at module scope, so the in-scope
    -- SceneCleanup teardown does not reach it. Cancel any in-flight coalesced
    -- refresh here so it cannot fire after the scene is gone.
    if BETTERUI.Banking.RefreshManager and BETTERUI.Banking.RefreshManager.Cancel then
        BETTERUI.Banking.RefreshManager:Cancel()
    end

    -- Cancel any in-flight Banking deferred tasks (stack-all refresh, currency
    -- transfer settle, etc.) so they cannot fire after the scene is hidden.
    if BETTERUI.Banking.Tasks and BETTERUI.Banking.Tasks.CancelAll then
        BETTERUI.Banking.Tasks:CancelAll()
    end

    -- Exit multi-select so the shared active-instance / global selection state is
    -- not left stale after leaving Banking.
    if self.multiSelectManager and self.multiSelectManager:IsActive() then
        self.multiSelectManager:ExitSelectionMode()
    end

    local transferContext = BETTERUI.Banking.ReadTransferContextSnapshot()
    BETTERUI.Banking.SetRuntimeBankBags(nil, transferContext.interactionBag)
    if self.confirmationMode then
        self:UpdateSpinnerConfirmation(false, self.list)
    end

    -- Force-hide currency selector
    if self.selector and self.selector.control then
        self.selector.control:GetParent():SetHidden(true)
        self.selector:Deactivate()
    end

    -- Shared CIM cleanup: input state, lists, search
    BETTERUI.CIM.SceneCleanup.CleanupInputState(self)
    BETTERUI.CIM.SceneCleanup.DeactivateLists(self)
    BETTERUI.CIM.SceneCleanup.ClearSearchState(self)
    self.confirmationMode = false

    -- Remove all keybind groups
    if KEYBIND_STRIP then
        local keybindGroups = {
            self.textSearchKeybindStripDescriptor,
            self.withdrawDepositKeybinds,
            self.coreKeybinds,
            self.currencyKeybinds,
            self.currencySelectorKeybinds,
            self.spinnerKeybindStripDescriptor,
            self.mainKeybindStripDescriptor,
            self._activeHeaderSortKeybindDescriptor,
            self.headerSortKeybindDescriptor,
        }
        for _, group in ipairs(keybindGroups) do
            if group then
                if BETTERUI.Log then
                    BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "bank scene remove keybind", {
                        fn = "Banking:OnSceneHidden",
                        descriptor = BETTERUI.Log.DescribeKeybindDescriptor and BETTERUI.Log.DescribeKeybindDescriptor(group, "remove") or tostring(group),
                    })
                end
                BETTERUI.Interface.RemoveKeybindGroupIfPresent(group)
            end
        end
        self._activeHeaderSortKeybindDescriptor = nil
    end
    GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)

    self:UpdateExternalAddons(false)

    -- Unregister all scene-scoped callbacks
    local callbacks = {
        { SHARED_INVENTORY, "FullInventoryUpdate", "_inventoryFullUpdateCallback" },
        { SHARED_INVENTORY, "SingleSlotInventoryUpdate", "_inventorySingleSlotCallback" },
        { CALLBACK_MANAGER, "OnGamepadDialogHidden", "_onDialogHiddenCallback" },
    }
    for _, entry in ipairs(callbacks) do
        local manager, event, field = entry[1], entry[2], entry[3]
        if self[field] then
            manager:UnregisterCallback(event, self[field])
            self[field] = nil
        end
    end

    -- Unregister guild bank events and reset state
    local ns = BETTERUI_GUILD_BANKING_SCENE_NAME or "BETTERUI_GUILD_BANKING"
    for _, event in ipairs(GUILD_BANK_EVENTS) do
        EVENT_MANAGER:UnregisterForEvent(ns, event)
    end
    if self.isGuildBankMode and BETTERUI.Banking.GuildBank then
        BETTERUI.Banking.GuildBank.SetLoading(false)
    end
    -- Reset category positions when leaving the bank
    self.lastPositionsByCategory = {}

    self._bankingSceneRecoverCallLaterId = zo_callLater(function()
        self._bankingSceneRecoverCallLaterId = nil
        if not IsInGamepadPreferredMode() then
            return
        end
        if not IsBankOpen() then
            return
        end
        if SCENE_MANAGER:IsShowing("gamepad_inventory_root") then
            return
        end

        local currentSceneName = SCENE_MANAGER:GetCurrentSceneName()
        local shouldRecoverToInventory = (currentSceneName == nil)
            or (currentSceneName == "")
            or (currentSceneName == "hud")
            or (currentSceneName == "hudui")
            or (currentSceneName == "gamepad_banking")
            or (currentSceneName == BETTERUI_BANKING_SCENE_NAME)

        if shouldRecoverToInventory then
            SCENE_MANAGER:Show("gamepad_inventory_root")
        end
    end, 25)
end

--- Handles visibility of supported external addon elements.
function BETTERUI.Banking.Class:UpdateExternalAddons(hidden)
    if wykkydsToolbar then
        wykkydsToolbar:SetHidden(hidden)
    end
end

-- KEYBOARD SHORTCUT INTERCEPTION (installed during Init)

--- Sets up keyboard shortcut interception hooks on SCENE_MANAGER.
--- Prevents keyboard keys (I, G, M, etc.) from interrupting the banking
--- ZO_InteractScene mid-interaction.
function BETTERUI.Banking.SetupSceneInterception()
    -- IMPORTANT:
    -- Do not replace SCENE_MANAGER methods. Global scene-manager monkeypatches
    -- taint protected gamepad execution paths (Tamriel Tomes / DirectPurchase).
    -- Keep this as a no-op to preserve secure scene transitions.
    if BETTERUI.Log then
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIFECYCLE, "banking scene interception initialized")
    end
    return
end
