--[[
File: Modules/Banking/Scene/BankingSceneLifecycle.lua
Purpose: Scene showing/hiding/hidden lifecycle handlers and keyboard shortcut interception.
Extracted from Banking.lua for maintainability.
]]

local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT  = BETTERUI.Banking.LIST_DEPOSIT

--[[
Function: BETTERUI.Banking.Class:OnSceneShowing
Description: Scene showing handler called by SceneLifecycleManager.
]]
function BETTERUI.Banking.Class:OnSceneShowing(wasPushed)
    -- Ensure currency selector is hidden on scene entry
    if self.selector and self.selector.control then
        self.selector.control:GetParent():SetHidden(true)
        self.selector:Deactivate()
    end

    self:CurrentUsedBank()
    self.bankCategories = self:ComputeVisibleBankCategories()
    self.currentCategoryIndex = 1
    self.lastPositions[self.currentMode] = 1
    self:RebuildHeaderCategories()
    if self.headerGeneric and self.headerGeneric.tabBar then
        self.headerGeneric.tabBar:SetSelectedIndexWithoutAnimation(1, true, true)
    end
    if self.isDirty then
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
        local isRelevant = (bagId == nil)
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
end

--[[
Function: BETTERUI.Banking.Class:OnSceneHiding
Description: Abort any in-flight batch before cleanup.
]]
function BETTERUI.Banking.Class:OnSceneHiding()
    if self:IsBatchProcessing() then
        self:RequestBatchAbort()
    end
end

--[[
Function: BETTERUI.Banking.Class:OnSceneHidden
Description: Scene hidden handler called by SceneLifecycleManager.
]]
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
    if self._onDialogHiddenCallback then
        CALLBACK_MANAGER:UnregisterCallback("OnGamepadDialogHidden", self._onDialogHiddenCallback)
        self._onDialogHiddenCallback = nil
    end

    -- Clear search state using shared helper
    BETTERUI.CIM.SceneCleanup.ClearSearchState(self)

    -- Reset category positions when leaving the bank
    self.lastPositionsByCategory = {}
end

--[[
Function: BETTERUI.Banking.Class:UpdateExternalAddons
Description: Handles visibility of supported external addon elements.
]]
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
function BETTERUI.Banking.SetupSceneInterception()
    local originalToggle = SCENE_MANAGER.Toggle
    local originalShow = SCENE_MANAGER.Show
    local bankingSceneName = BETTERUI_BANKING_SCENE_NAME
    local intercepting = false

    local function InterceptSceneChange(targetSceneName)
        if intercepting then return false end
        if targetSceneName == bankingSceneName or targetSceneName == "gamepad_banking" then
            return false
        end
        if targetSceneName == "hud" or targetSceneName == "hudui" then
            return false
        end

        local bankScene = SCENE_MANAGER:GetScene(bankingSceneName)
        if not bankScene or not bankScene:IsShowing() then
            return false
        end

        local function OnBankHidden(oldState, newState)
            if newState == SCENE_HIDDEN then
                bankScene:UnregisterCallback("StateChange", OnBankHidden)
                zo_callLater(function()
                    originalShow(SCENE_MANAGER, targetSceneName)
                end, 50)
            end
        end
        bankScene:RegisterCallback("StateChange", OnBankHidden)

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
