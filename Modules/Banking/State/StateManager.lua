local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT  = BETTERUI.Banking.LIST_DEPOSIT
local MODULES       = BETTERUI.CIM.CONST.MODULES

local function GetModeModuleKey(mode)
    return mode == LIST_WITHDRAW and MODULES.BANKING_WITHDRAW or MODULES.BANKING_DEPOSIT
end

-- POSITION PERSISTENCE

--- Saves the current scroll position of the list.
function BETTERUI.Banking.Class:SaveListPosition()
    if not self.list then return end
    -- Save per-mode position (for legacy compatibility)
    if self.lastPositions then
        self.lastPositions[self.currentMode] = self.list.selectedIndex
    end
    -- Save per-category position using CIM PositionManager
    if self.bankCategories and #self.bankCategories > 0 then
        local cat = self.bankCategories[self.currentCategoryIndex or 1]
        if cat and cat.key then
            BETTERUI.CIM.PositionManager.SavePosition(
                GetModeModuleKey(self.currentMode),
                cat.key,
                self.list
            )
        end
    end
end

--- Manages keybind and tooltip state when list is empty.
function BETTERUI.Banking.Class:HandleEmptyList()
    local totalEntries = (self.list and self.list.dataList and #self.list.dataList) or 0
    if totalEntries == 0 then
        if KEYBIND_STRIP then
            if self.currencyKeybinds then
                KEYBIND_STRIP:RemoveKeybindButtonGroup(self.currencyKeybinds)
            end
            if self.withdrawDepositKeybinds then
                KEYBIND_STRIP:AddKeybindButtonGroup(self.withdrawDepositKeybinds)
                KEYBIND_STRIP:UpdateKeybindButtonGroup(self.withdrawDepositKeybinds)
            end
        end
        if GAMEPAD_TOOLTIPS then
            GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
        end
        return true
    end
    return false
end

--- Retrieves the saved position for the current category/mode.
function BETTERUI.Banking.Class:GetRestoredPosition()
    if not self.bankCategories or #self.bankCategories == 0 then
        return 1
    end
    local cat = self.bankCategories[self.currentCategoryIndex or 1]
    if not cat or not cat.key then
        return 1
    end
    return BETTERUI.CIM.PositionManager.RestorePosition(
        GetModeModuleKey(self.currentMode),
        cat.key,
        self.list,
        self.list.dataList
    )
end

--- Handles the case where the player switched to a different bank.
function BETTERUI.Banking.Class:HandleBankSwitch()
    local currentUsedBank = BETTERUI.Banking.GetCurrentUsedBank()
    local lastUsedBank = BETTERUI.Banking.GetLastUsedBank()
    local activeSourceBag = BETTERUI.Banking.GetActiveInteractionBag()

    if lastUsedBank == currentUsedBank then
        return false -- No switch, handled by caller
    end

    -- Bank changed - reset positions for both modes
    self.list:SetSelectedIndexWithoutAnimation(1, true, false)
    self:SaveListPosition()

    if self.currentMode == LIST_WITHDRAW then
        -- Also reset deposit mode
        self.currentMode = LIST_DEPOSIT
        self.list:SetSelectedIndexWithoutAnimation(1, true, false)
        self:SaveListPosition()
        self.currentMode = LIST_WITHDRAW
        BETTERUI.Banking.SetRuntimeBankBags(nil, activeSourceBag)
        self:RefreshList()
    else
        -- Switch to withdraw mode
        BETTERUI.Banking.SetRuntimeBankBags(nil, activeSourceBag)
        self.currentMode = LIST_WITHDRAW
        self:ToggleList(true)
    end
    return true
end

--- Restores the saved list position.
function BETTERUI.Banking.Class:ReturnToSaved()
    BETTERUI.Banking.SetRuntimeBankBags(BETTERUI.Banking.GetActiveInteractionBag(), nil)

    -- Handle empty list
    if self:HandleEmptyList() then
        return
    end

    -- Skip restoration if we just toggled modes
    local state = BETTERUI.CIM.HeaderNavigation.GetOrCreateState(self)
    if state.justToggledMode then
        self.list:SetSelectedIndexWithoutAnimation(1, true, false)
        return
    end

    -- Handle bank switch (player visited different bank)
    if self:HandleBankSwitch() then
        return
    end

    -- Normal restoration
    local lastPosition = self:GetRestoredPosition()
    self.list:SetSelectedIndexWithoutAnimation(lastPosition, true, false)
end

function BETTERUI.Banking.Class:UpdateSingleItem(bagId, slotIndex)
    -- Rebuild the list from the shared inventory cache rather than mutating
    -- the parametric list internals while it's animating/moving.
    self:RefreshList()
end

function BETTERUI.Banking.Class:RemoveItemStack(itemIndex)
    -- Avoid directly mutating the parametric list while it may be moving; just refresh.
    self:RefreshList()
end

function BETTERUI.Banking.Class:ToggleList(toWithdraw)
    -- Exit multi-select mode when switching between Withdraw/Deposit
    -- Selections are mode-specific and should not carry over
    if self.isInSelectionMode then
        self:ExitSelectionMode()
    end

    self:SaveListPosition()

    -- Capture the category KEY from CURRENT mode before switching
    local prevCategoryKey = nil
    if self.GetCurrentCategoryKey then
        prevCategoryKey = self:GetCurrentCategoryKey()
    else
        local prevCategoryIndex = self.currentCategoryIndex or 1
        if self.bankCategories and prevCategoryIndex <= #self.bankCategories then
            local prevCat = self.bankCategories[prevCategoryIndex]
            if prevCat then
                prevCategoryKey = prevCat.key
            end
        end
    end

    self.currentMode = toWithdraw and LIST_WITHDRAW or LIST_DEPOSIT
    -- Rebuild categories for the NEW mode
    self.bankCategories = self:ComputeVisibleBankCategories()

    -- Try to find the same category key in the new mode; if not found, default to All Items (index 1)
    local newCategoryIndex = self.ResolveCategoryIndex and self:ResolveCategoryIndex(prevCategoryKey) or 1
    -- Clamp the index to valid range BEFORE setting it
    self.currentCategoryIndex = zo_clamp(newCategoryIndex, 1, #self.bankCategories)

    -- Reset list position to first item in the new mode
    self.lastPositions[self.currentMode] = 1
    -- Flag that we just toggled so RebuildHeaderCategories uses animation-free selection
    -- (Use NavigationState instead of inline flag)
    local state = BETTERUI.CIM.HeaderNavigation.GetOrCreateState(self)
    state.justToggledMode = true
    self:RebuildHeaderCategories()
    state.justToggledMode = false
    local footer = self.footer:GetNamedChild("Footer")
    local isWithdraw = (self.currentMode == LIST_WITHDRAW)
    local activeColor = { 1, 1, 1, 1 }
    footer:GetNamedChild("SelectBg"):SetTextureRotation(isWithdraw and 0 or BETTERUI_BANK_DEPOSIT_ARROW_ROTATION)
    footer:GetNamedChild("DepositButtonLabel"):SetColor(unpack(isWithdraw and BETTERUI_BANK_INACTIVE_LABEL_COLOR or activeColor))
    footer:GetNamedChild("WithdrawButtonLabel"):SetColor(unpack(isWithdraw and activeColor or BETTERUI_BANK_INACTIVE_LABEL_COLOR))
    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds)
    --KEYBIND_STRIP:UpdateKeybindButtonGroup(self.spinnerKeybindStripDescriptor)
    self:RefreshList()
end
