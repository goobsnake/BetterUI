--[[
File: Modules/Banking/Scene/BankingSceneLifecycle.lua
Purpose: Scene showing/hiding/hidden lifecycle handlers and keyboard shortcut interception.
Extracted from Banking.lua for maintainability.
]]

-- ─── Constants ───────────────────────────────────────────────────────────────
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

-- ─── Public API ──────────────────────────────────────────────────────────────

--- Scene showing handler called by SceneLifecycleManager.
--- @param wasPushed boolean
function BETTERUI.Banking.Class:OnSceneShowing(wasPushed)
    -- Ensure currency selector is hidden on scene entry
    if self.selector and self.selector.control then
        self.selector.control:GetParent():SetHidden(true)
        self.selector:Deactivate()
    end

    self:CurrentUsedBank()

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
        local depositDenied = GuildBank.GetPermissionDenialReason(BETTERUI.Banking.LIST_DEPOSIT)
        local withdrawDenied = GuildBank.GetPermissionDenialReason(BETTERUI.Banking.LIST_WITHDRAW)
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
    elseif self.isDirty then
        self:RefreshList()
    else
        self:RefreshActiveKeybinds()
    end
    self.list:Activate()
    self:AddKeybinds()

    self:UpdateExternalAddons(true)

    -- Register for SHARED_INVENTORY callbacks
    local function OnInventoryUpdated(bagId, slotIndex)
        if not BETTERUI.CIM.Utils.IsBankingSceneShowing() then return end
        local currentUsedBank = BETTERUI.Banking.currentUsedBank
        local relevantBags
        if self.currentMode == LIST_WITHDRAW then
            if GuildBank and GuildBank.IsGuildBankMode() then
                relevantBags = { BAG_GUILDBANK }
            elseif currentUsedBank == BAG_BANK then
                relevantBags = { BAG_BANK, BAG_SUBSCRIBER_BANK }
            else
                relevantBags = { currentUsedBank }
            end
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

        BETTERUI.Banking.Tasks:Schedule("sharedInventoryUpdate", SHARED_INVENTORY_UPDATE_DELAY_MS, function()
            if BETTERUI.CIM.Utils.IsBankingSceneShowing() then
                self.isDirty = true
                self:RefreshList()
            end
        end)
    end
    self._inventoryFullUpdateCallback = OnInventoryUpdated
    self._inventorySingleSlotCallback = OnInventoryUpdated
    SHARED_INVENTORY:RegisterCallback("FullInventoryUpdate", self._inventoryFullUpdateCallback)
    SHARED_INVENTORY:RegisterCallback("SingleSlotInventoryUpdate", self._inventorySingleSlotCallback)

    -- Re-activate list and refresh after any gamepad dialog fully closes
    self._onDialogHiddenCallback = function()
        if BETTERUI.CIM.Utils.IsBankingSceneShowing() and self.list then
            self._suppressListUpdates = false
            BETTERUI.Banking.Tasks:Schedule("dialogHiddenRefresh", 50, function()
                if BETTERUI.CIM.Utils.IsBankingSceneShowing() then
                    self.bankCategories = self:ComputeVisibleBankCategories()
                    self:RefreshList()
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
--- @return nil
function BETTERUI.Banking.Class:OnSceneHiding()
    if self:IsBatchProcessing() then
        self:RequestBatchAbort()
    end
end

--- Scene hidden handler called by SceneLifecycleManager.
--- @return nil
function BETTERUI.Banking.Class:OnSceneHidden()
    self:LastUsedBank()
    self:CancelWithdrawDeposit(self.list)

    -- Force-hide currency selector
    if self.selector and self.selector.control then
        self.selector.control:GetParent():SetHidden(true)
        self.selector:Deactivate()
    end

    -- Use shared CIM cleanup for input state
    BETTERUI.CIM.SceneCleanup.CleanupInputState(self)

    -- Deactivate lists to release DIRECTIONAL_INPUT
    BETTERUI.CIM.SceneCleanup.DeactivateLists(self)
    self.confirmationMode = false

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

    -- Unregister SHARED_INVENTORY callbacks
    if self._inventoryFullUpdateCallback then
        SHARED_INVENTORY:UnregisterCallback("FullInventoryUpdate", self._inventoryFullUpdateCallback)
        self._inventoryFullUpdateCallback = nil
    end
    if self._inventorySingleSlotCallback then
        SHARED_INVENTORY:UnregisterCallback("SingleSlotInventoryUpdate", self._inventorySingleSlotCallback)
        self._inventorySingleSlotCallback = nil
    end
    if self._onDialogHiddenCallback then
        CALLBACK_MANAGER:UnregisterCallback("OnGamepadDialogHidden", self._onDialogHiddenCallback)
        self._onDialogHiddenCallback = nil
    end

    -- Clear search state using shared helper
    BETTERUI.CIM.SceneCleanup.ClearSearchState(self)

    -- Unregister guild bank events
    local ns = BETTERUI_GUILD_BANKING_SCENE_NAME or "BETTERUI_GUILD_BANKING"
    for _, event in ipairs(GUILD_BANK_EVENTS) do
        EVENT_MANAGER:UnregisterForEvent(ns, event)
    end

    -- Reset guild bank loading state
    if self.isGuildBankMode and BETTERUI.Banking.GuildBank then
        BETTERUI.Banking.GuildBank.SetLoading(false)
    end
    self.loadingGuildBank = false

    -- Reset category positions when leaving the bank
    self.lastPositionsByCategory = {}
end

--- Handles visibility of supported external addon elements.
--- @param hidden boolean
function BETTERUI.Banking.Class:UpdateExternalAddons(hidden)
    if wykkydsToolbar then
        wykkydsToolbar:SetHidden(hidden)
    end
end

--------------------------------------------------------------------------------
-- KEYBOARD SHORTCUT INTERCEPTION (installed during Init)
--------------------------------------------------------------------------------

--- Sets up keyboard shortcut interception hooks on SCENE_MANAGER.
--- Prevents keyboard keys (I, G, M, etc.) from interrupting the banking
--- ZO_InteractScene mid-interaction.
--- @return nil
function BETTERUI.Banking.SetupSceneInterception()
    local originalToggle = SCENE_MANAGER.Toggle
    local originalShow = SCENE_MANAGER.Show
    local bankingSceneName = BETTERUI_BANKING_SCENE_NAME
    local guildBankSceneName = BETTERUI_GUILD_BANKING_SCENE_NAME
    local intercepting = false

    --- @param targetSceneName string
    --- @return boolean
    local function InterceptSceneChange(targetSceneName)
        if intercepting then return false end
        -- Never intercept our own banking scenes
        if targetSceneName == bankingSceneName or targetSceneName == "gamepad_banking" then
            return false
        end
        if targetSceneName == guildBankSceneName or targetSceneName == "gamepad_guild_bank" then
            return false
        end
        if targetSceneName == "hud" or targetSceneName == "hudui" then
            return false
        end

        -- Check if either banking scene is active
        local bankScene = SCENE_MANAGER:GetScene(bankingSceneName)
        local guildBankScene = SCENE_MANAGER:GetScene(guildBankSceneName)
        local activeScene = nil
        if bankScene and bankScene:IsShowing() then
            activeScene = bankScene
        elseif guildBankScene and guildBankScene:IsShowing() then
            activeScene = guildBankScene
        end
        if not activeScene then
            return false
        end

        local function OnBankHidden(oldState, newState)
            if newState == SCENE_HIDDEN then
                activeScene:UnregisterCallback("StateChange", OnBankHidden)
                zo_callLater(function()
                    originalShow(SCENE_MANAGER, targetSceneName)
                end, 50)
            end
        end
        activeScene:RegisterCallback("StateChange", OnBankHidden)

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
end
