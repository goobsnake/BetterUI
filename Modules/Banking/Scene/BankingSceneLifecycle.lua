--[[
File: Modules/Banking/Scene/BankingSceneLifecycle.lua
Purpose: Scene showing/hiding/hidden lifecycle handlers and keyboard shortcut interception.
Extracted from Banking.lua for maintainability.
]]

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


--- Scene showing handler called by SceneLifecycleManager.
function BETTERUI.Banking.Class:OnSceneShowing(wasPushed)
    -- Ensure currency selector is hidden on scene entry
    if self.selector and self.selector.control then
        self.selector.control:GetParent():SetHidden(true)
        self.selector:Deactivate()
    end

    BETTERUI.Banking.SetCurrentUsedBank(BETTERUI.Banking.ResolveInteractionBankBag())

    -- Guild bank detection: update title and check permissions
    local GuildBank = BETTERUI.Banking.GuildBank
    if GuildBank and GuildBank.IsGuildBankMode() then
        self.isGuildBankMode = true
        -- Select the accessible guild bank and trigger data loading
        local guildId = GuildBank.GetSelectedGuildId()
        if ZO_SharedInventory_SelectAccessibleGuildBank and guildId > 0 then
            ZO_SharedInventory_SelectAccessibleGuildBank(guildId)
        end
        self.loadingGuildBank = true
        self:SetTitle(GuildBank.GetHeaderTitle())

        -- Check base permissions on scene entry
        local depositDenied = GuildBank.GetPermissionDenial(BETTERUI.Banking.LIST_DEPOSIT)
        local withdrawDenied = GuildBank.GetPermissionDenial(BETTERUI.Banking.LIST_WITHDRAW)
        if depositDenied and withdrawDenied then
            -- Cannot deposit or withdraw — show warning but allow viewing
            BETTERUI.CIM.Debug.Log("Guild bank: no deposit or withdraw permission", "GuildBank")
        end
    else
        self.isGuildBankMode = false
        self:SetTitle("|c0066FF" .. GetString(rawget(_G, "SI_BETTERUI_BANK_TITLE")) .. "|r")
    end

    self.bankCategories = self:ComputeVisibleBankCategories()
    self.currentCategoryIndex = 1
    self.lastPositions[self.currentMode] = 1
    self:RebuildHeaderCategories()
    if self.headerGeneric and self.headerGeneric.tabBar then
        self.headerGeneric.tabBar:SetSelectedIndexWithoutAnimation(1, true, true)
    end
    if self.isGuildBankMode then
        -- Guild bank: clear stale data and defer list refresh until
        -- EVENT_GUILD_BANK_ITEMS_READY fires via OnGuildBankReady.
        self.list:Clear()
        self.list:Commit()
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
        if self.bankCategories and self.currentCategoryIndex and self.currentCategoryIndex <= #self.bankCategories then
            local prevCat = self.bankCategories[self.currentCategoryIndex]
            if prevCat then
                previousCategoryKey = prevCat.key
            end
        end

        self.bankCategories = self:ComputeVisibleBankCategories()
        if not self.bankCategories or #self.bankCategories == 0 then
            self.currentCategoryIndex = 1
            self:RefreshList()
            return
        end

        local desiredCategoryIndex = 1
        if previousCategoryKey then
            for i, cat in ipairs(self.bankCategories) do
                if cat.key == previousCategoryKey then
                    desiredCategoryIndex = i
                    break
                end
            end
        end
        self.currentCategoryIndex = zo_clamp(desiredCategoryIndex, 1, #self.bankCategories)

        local state = BETTERUI.CIM.HeaderNavigation.GetOrCreateState(self)
        state.suppressHeaderCallback = true
        self:RebuildHeaderCategories()
        state.suppressHeaderCallback = false
        self:RefreshList()
    end

    local function TryRefreshAfterInventoryUpdate()
        if not BETTERUI.Utils.IsBankingSceneShowing() then
            return
        end

        if self:IsBatchProcessing() then
            BETTERUI.Banking.Tasks:Schedule("sharedInventoryUpdate", SHARED_INVENTORY_UPDATE_DELAY_MS,
                TryRefreshAfterInventoryUpdate)
            return
        end

        if self._suppressListUpdates then
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
            relevantBags = BETTERUI.Banking.ResolveWithdrawSources()
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

        BETTERUI.Banking.Tasks:Schedule("sharedInventoryUpdate", SHARED_INVENTORY_UPDATE_DELAY_MS,
            TryRefreshAfterInventoryUpdate)
    end
    self._inventoryFullUpdateCallback = OnInventoryUpdated
    self._inventorySingleSlotCallback = OnInventoryUpdated
    SHARED_INVENTORY:RegisterCallback("FullInventoryUpdate", self._inventoryFullUpdateCallback)
    SHARED_INVENTORY:RegisterCallback("SingleSlotInventoryUpdate", self._inventorySingleSlotCallback)

    -- Re-activate list and refresh after any gamepad dialog fully closes
    self._onDialogHiddenCallback = function()
        if BETTERUI.Utils.IsBankingSceneShowing() and self.list then
            self._suppressListUpdates = false
            BETTERUI.Banking.Tasks:Schedule("dialogHiddenRefresh", 50, function()
                if BETTERUI.Utils.IsBankingSceneShowing() then
                    RebuildCategoriesAndRefreshList()
                end
            end)
        end
    end
    CALLBACK_MANAGER:RegisterCallback("OnGamepadDialogHidden", self._onDialogHiddenCallback)

    -- Register guild bank events when in guild bank mode
    if self.isGuildBankMode and GuildBank then
        GuildBank.RegisterGuildSelectorDialog()
        local ns = BETTERUI_GUILD_BANKING_SCENE_NAME or "BETTERUI_GUILD_BANKING"
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
        end
    end
end

--- Aborts any in-flight batch before cleanup.
function BETTERUI.Banking.Class:OnSceneHiding()
    if self:IsBatchProcessing() then
        self:RequestBatchAbort()
    end
end

--- Scene hidden handler called by SceneLifecycleManager.
function BETTERUI.Banking.Class:OnSceneHidden()
    BETTERUI.Banking.SetLastUsedBank(BETTERUI.Banking.ResolveInteractionBankBag())
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
                KEYBIND_STRIP:RemoveKeybindButtonGroup(group)
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
    self.loadingGuildBank = false

    -- Reset category positions when leaving the bank
    self.lastPositionsByCategory = {}

    zo_callLater(function()
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
    return
end
