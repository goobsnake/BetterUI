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

-- BUI-STAB-001 Phase 5: the hidden-scene recovery (see OnSceneHidden) is
-- generation-bound. Every SHOWING/HIDING transition bumps the generation so a
-- recovery callback scheduled during a prior HIDDEN cannot fire after the scene
-- has re-entered or begun another transition -- even in a HIDING -> SHOWING
-- re-entry where the zo_callLater handle path is missed. The generation guard is
-- the authoritative invalidation; the handle removal is the fast path.
local function InvalidateBankingSceneRecovery(self)
    self._bankingSceneRecoverGeneration = (self._bankingSceneRecoverGeneration or 0) + 1
    if self._bankingSceneRecoverCallLaterId then
        zo_removeCallLater(self._bankingSceneRecoverCallLaterId)
        self._bankingSceneRecoverCallLaterId = nil
    end
end

-- Returns true when either BetterUI bank scene (personal or guild) is already
-- active (current), showing, requested (its own scene state is showing/shown), or
-- queued as the next scene. In that case a BetterUI bank scene has re-engaged and
-- the player is NOT stranded, so the hidden-scene recovery must stand down instead
-- of forcing inventory on top of a valid bank scene.
local function IsBetterUIBankSceneEngaged()
    if not SCENE_MANAGER then
        return false
    end
    local currentSceneName = SCENE_MANAGER.GetCurrentSceneName and SCENE_MANAGER:GetCurrentSceneName()
    local nextScene = SCENE_MANAGER.GetNextScene and SCENE_MANAGER:GetNextScene()
    local nextSceneName = nextScene and nextScene.GetName and nextScene:GetName() or nil
    local sceneNames = { BETTERUI_BANKING_SCENE_NAME, BETTERUI_GUILD_BANKING_SCENE_NAME }
    for _, name in ipairs(sceneNames) do
        if name and name ~= "" then
            if currentSceneName == name then
                return true
            end
            if nextSceneName == name then
                return true
            end
            if SCENE_MANAGER.IsShowing and SCENE_MANAGER:IsShowing(name) then
                return true
            end
            local scene = SCENE_MANAGER.GetScene and SCENE_MANAGER:GetScene(name)
            if scene then
                if scene.IsShowing and scene:IsShowing() then
                    return true
                end
                if scene.GetState then
                    local state = scene:GetState()
                    if state == SCENE_SHOWING or state == SCENE_SHOWN then
                        return true
                    end
                end
            end
        end
    end
    return false
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

    -- Cancel + generation-invalidate any pending scene-recovery zo_callLater from a
    -- previous hidden transition; a HIDING -> SHOWING re-entry would otherwise let
    -- the stale callback fire after the scene is active again (BUI-STAB-001 Phase 5).
    InvalidateBankingSceneRecovery(self)

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
        -- Canonical category-key resolution (BUI-CONS-004).
        local previousCategoryKey = BETTERUI.Banking.ResolveWindowCategoryKey(self)

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

--- Removes every Banking keybind group from the strip. Called on BOTH scene HIDING
--- and HIDDEN (idempotent) to match the Inventory gold-standard teardown, so banking
--- keybinds cannot be clicked during the hide animation and never leak onto the next
--- scene.
local function RemoveBankingKeybindsForSceneExit(self, phase)
    if not KEYBIND_STRIP then
        return
    end
    local keybindGroups = {
        self.textSearchKeybindStripDescriptor,
        self.withdrawDepositKeybinds,
        self.coreKeybinds,
        self.currencyKeybinds,
        self.currencySelectorKeybinds,
        self.mainKeybindStripDescriptor,
        self._activeHeaderSortKeybindDescriptor,
        self.headerSortKeybindDescriptor,
    }
    for _, group in ipairs(keybindGroups) do
        if group then
            if BETTERUI.Log then
                BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "bank scene remove keybind", {
                    fn = "Banking:OnScene" .. tostring(phase),
                    descriptor = BETTERUI.Log.DescribeKeybindDescriptor and BETTERUI.Log.DescribeKeybindDescriptor(group, "remove") or tostring(group),
                })
            end
            BETTERUI.Interface.RemoveKeybindGroupIfPresent(group)
        end
    end
    self._activeHeaderSortKeybindDescriptor = nil
end

--- Aborts any in-flight batch before cleanup, then removes keybinds + deactivates
--- list input immediately (Inventory gold-standard) so nothing on the strip is
--- clickable during the hide animation.
function BETTERUI.Banking.Class:OnSceneHiding()
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.SCENE, "scene hiding", { isBatchProcessing = self:IsBatchProcessing() })
    end
    -- Invalidate any pending hidden-scene recovery; a fresh HIDING supersedes it and
    -- OnSceneHidden will schedule a new generation-bound recovery if the exit
    -- completes (BUI-STAB-001 Phase 5).
    InvalidateBankingSceneRecovery(self)
    if self:IsBatchProcessing() then
        self:RequestBatchAbort()
    end
    RemoveBankingKeybindsForSceneExit(self, "Hiding")
    BETTERUI.CIM.SceneCleanup.DeactivateLists(self)
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

    -- Remove all keybind groups (shared helper; also runs on OnSceneHiding)
    RemoveBankingKeybindsForSceneExit(self, "Hidden")
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

    -- BUI-STAB-001 Phase 5: schedule a generation-bound recovery. If the gamepad
    -- bank is genuinely stranded (still open but the scene machinery left no valid
    -- scene showing) force gamepad inventory so the player is not stuck on a dead
    -- screen. Any SHOWING/HIDING before this fires bumps the generation (and clears
    -- the handle), neutralizing this callback.
    if self._bankingSceneRecoverCallLaterId then
        zo_removeCallLater(self._bankingSceneRecoverCallLaterId)
        self._bankingSceneRecoverCallLaterId = nil
    end
    self._bankingSceneRecoverGeneration = (self._bankingSceneRecoverGeneration or 0) + 1
    local recoverGeneration = self._bankingSceneRecoverGeneration
    local recoverCallLaterId
    recoverCallLaterId = zo_callLater(function()
        if self._bankingSceneRecoverCallLaterId == recoverCallLaterId then
            self._bankingSceneRecoverCallLaterId = nil
        end
        -- Generation guard: a scene SHOWING/HIDING after this was scheduled bumps
        -- the generation, so a stale callback that survived handle removal no-ops.
        if self._bankingSceneRecoverGeneration ~= recoverGeneration then
            return
        end
        if not IsInGamepadPreferredMode() then
            return
        end
        if not IsBankOpen() then
            return
        end
        if SCENE_MANAGER:IsShowing("gamepad_inventory_root") then
            return
        end
        -- Never hijack an intentional exit: if the player has already queued a
        -- different scene as next, let it proceed instead of forcing inventory on top.
        local nextScene = SCENE_MANAGER.GetNextScene and SCENE_MANAGER:GetNextScene()
        if nextScene and nextScene.GetName then
            local nextSceneName = nextScene:GetName()
            if nextSceneName and nextSceneName ~= "" and nextSceneName ~= "gamepad_inventory_root" then
                return
            end
        end
        -- Reject the recovery when either BetterUI bank scene is active/showing/
        -- requested/next: the bank re-engaged a BetterUI scene, so we are not
        -- stranded and must not force inventory over it.
        if IsBetterUIBankSceneEngaged() then
            return
        end

        -- Inventory is shown only for the genuinely stranded case: bank still open
        -- but the current scene is a dead/bare state, not a BetterUI bank scene.
        local currentSceneName = SCENE_MANAGER:GetCurrentSceneName()
        local shouldRecoverToInventory = (currentSceneName == nil)
            or (currentSceneName == "")
            or (currentSceneName == "hud")
            or (currentSceneName == "hudui")
            or (currentSceneName == "gamepad_banking")

        if shouldRecoverToInventory then
            SCENE_MANAGER:Show("gamepad_inventory_root")
        end
    end, 25)
    self._bankingSceneRecoverCallLaterId = recoverCallLaterId
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
