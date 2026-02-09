--[[
File: Modules/Banking/State/StateManager.lua
Purpose: Manages persistence and state transitions for the banking module.
         Delegates position persistence to CIM.PositionManager.
Author: BetterUI Team
Last Modified: 2026-01-28
]]

-------------------------------------------------------------------------------------------------
-- SHARED CONSTANTS
-------------------------------------------------------------------------------------------------
local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT  = BETTERUI.Banking.LIST_DEPOSIT
-- Module identifier constants from CIM
local MODULES       = BETTERUI.CIM.CONST.MODULES

-------------------------------------------------------------------------------------------------
-- HELPER FUNCTIONS (local)
-------------------------------------------------------------------------------------------------

--[[
Function: GetCurrentBankBag (local)
Description: Determines the current bank bag ID.
Rationale: Extracts common bank-determination logic used by multiple functions.
return: number - BAG_BANK or the specific house bank bag ID.
]]
local function GetCurrentBankBag()
    if IsHouseBankBag(GetBankingBag()) then
        return GetBankingBag()
    end
    return BAG_BANK
end

--[[
Function: GetModeKey (local)
Description: Returns the mode string key for CIM PositionManager namespacing.
param: mode (number) - LIST_WITHDRAW or LIST_DEPOSIT.
return: string - "Withdraw" or "Deposit".
]]
local function GetModeModuleKey(mode)
    return mode == LIST_WITHDRAW and MODULES.BANKING_WITHDRAW or MODULES.BANKING_DEPOSIT
end

-------------------------------------------------------------------------------------------------
-- BANK STATE TRACKING
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.Banking.Class:CurrentUsedBank
Description: Updates the 'currentUsedBank' state.
Rationale: Determines whether we are using the main bank (BAG_BANK) or a house bank.
Mechanism: Uses helper to determine bag, updates namespace.
]]
function BETTERUI.Banking.Class:CurrentUsedBank()
    BETTERUI.Banking.currentUsedBank = GetCurrentBankBag()
end

--[[
Function: BETTERUI.Banking.Class:LastUsedBank
Description: Updates the 'lastUsedBank' state.
Mechanism: Uses helper to determine bag, updates namespace.
]]
function BETTERUI.Banking.Class:LastUsedBank()
    BETTERUI.Banking.lastUsedBank = GetCurrentBankBag()
end

-------------------------------------------------------------------------------------------------
-- POSITION PERSISTENCE
-------------------------------------------------------------------------------------------------

--[[
Function: BETTERUI.Banking.Class:SaveListPosition
Description: Saves the current scroll position of the list.
Rationale: Delegates to CIM.PositionManager for shared position persistence.
Mechanism: Uses category key from current category to store position.
References: Called before RefreshList, ToggleList, or Mode Switches.
]]
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

--[[
Function: BETTERUI.Banking.Class:HandleEmptyList (helper)
Description: Manages keybind and tooltip state when list is empty.
Rationale: Extracted from ReturnToSaved to separate keybind management concern.
return: boolean - True if list was empty and handled, false otherwise.
]]
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

--[[
Function: BETTERUI.Banking.Class:GetRestoredPosition
Description: Retrieves the saved position for the current category/mode.
Rationale: Extracted from ReturnToSaved for cleaner position lookup.
return: number - The position to restore (1 if none saved).
]]
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

--[[
Function: BETTERUI.Banking.Class:HandleBankSwitch
Description: Handles the case where the player switched to a different bank.
Rationale: Extracted from ReturnToSaved to isolate bank-switching logic.
return: boolean - True if bank switch was handled, false if no switch occurred.
]]
function BETTERUI.Banking.Class:HandleBankSwitch()
    local currentUsedBank = BETTERUI.Banking.currentUsedBank
    local lastUsedBank = BETTERUI.Banking.lastUsedBank

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
        self:LastUsedBank()
        self:RefreshList()
    else
        -- Switch to withdraw mode
        self:LastUsedBank()
        self.currentMode = LIST_WITHDRAW
        self:ToggleList(true)
    end
    return true
end

--[[
Function: BETTERUI.Banking.Class:ReturnToSaved
Description: Restores the saved list position.
Rationale: Uses CIM.PositionManager for position restoration with uniqueId lookup.
Mechanism:
  1. Updates current bank state.
  2. Handles empty list case with keybind management.
  3. Handles mode toggle case (skip to top).
  4. Handles bank switch case.
  5. Restores normal position from CIM.
References: Called at the end of RefreshList.
]]
function BETTERUI.Banking.Class:ReturnToSaved()
    self:CurrentUsedBank()

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

--[[
Function: BETTERUI.Banking.Class:UpdateSingleItem
Description: Handles single slot updates (item add/remove/change).
Rationale: Triggers a list refresh when a specific slot changes.
param: bagId (number) - The bag ID.
param: slotIndex (number) - The slot index.
]]
function BETTERUI.Banking.Class:UpdateSingleItem(bagId, slotIndex)
    -- Rebuild the list from the shared inventory cache rather than mutating
    -- the parametric list internals while it's animating/moving.
    self:RefreshList()
end

--[[
Function: BETTERUI.Banking.Class:RemoveItemStack
Description: Handles item stack removal.
param: itemIndex (number) - The index of the item being removed.
]]
function BETTERUI.Banking.Class:RemoveItemStack(itemIndex)
    -- Avoid directly mutating the parametric list while it may be moving; just refresh.
    self:RefreshList()
end

--[[
Function: BETTERUI.Banking.Class:ToggleList
Description: Toggles between Withdraw and Deposit modes.
Rationale: Switches the banking context and refreshes the UI.
Mechanism:
  1. Saves current list position.
  2. Captures current category key to attempt restoration in new mode.
  3. Updates `currentMode` (LIST_WITHDRAW <-> LIST_DEPOSIT).
  4. Recomputes visible categories for the new mode.
  5. Updates Header Title and Footer Colors/Rotation.
  6. Refreshes Keybinds.
References: Called by "Y" Keybind (Secondary).
param: toWithdraw (boolean) - True if switching to Withdraw mode, False for Deposit.
]]
function BETTERUI.Banking.Class:ToggleList(toWithdraw)
    -- Exit multi-select mode when switching between Withdraw/Deposit
    -- Selections are mode-specific and should not carry over
    if self.isInSelectionMode then
        self:ExitSelectionMode()
    end

    self:SaveListPosition()

    -- Capture the category KEY from CURRENT mode before switching
    local prevCategoryKey = nil
    local prevCategoryIndex = self.currentCategoryIndex or 1
    if self.bankCategories and prevCategoryIndex <= #self.bankCategories then
        local prevCat = self.bankCategories[prevCategoryIndex]
        if prevCat then
            prevCategoryKey = prevCat.key
        end
    end

    self.currentMode = toWithdraw and LIST_WITHDRAW or LIST_DEPOSIT
    -- Rebuild categories for the NEW mode
    self.bankCategories = self:ComputeVisibleBankCategories()

    -- Try to find the same category key in the new mode; if not found, default to All Items (index 1)
    local newCategoryIndex = 1 -- Default to All Items
    local categoryFound = false
    if prevCategoryKey then
        for i, cat in ipairs(self.bankCategories) do
            if cat.key == prevCategoryKey then
                newCategoryIndex = i
                categoryFound = true
                break
            end
        end
    end
    -- If category doesn't exist in new mode, ensure we default to All Items
    if not categoryFound then
        newCategoryIndex = 1
    end
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
    if (self.currentMode == LIST_WITHDRAW) then
        footer:GetNamedChild("SelectBg"):SetTextureRotation(0)

        footer:GetNamedChild("DepositButtonLabel"):SetColor(unpack(BETTERUI_BANK_INACTIVE_LABEL_COLOR))
        footer:GetNamedChild("WithdrawButtonLabel"):SetColor(1, 1, 1, 1)
    else
        footer:GetNamedChild("SelectBg"):SetTextureRotation(BETTERUI_BANK_DEPOSIT_ARROW_ROTATION)

        footer:GetNamedChild("DepositButtonLabel"):SetColor(1, 1, 1, 1)
        footer:GetNamedChild("WithdrawButtonLabel"):SetColor(unpack(BETTERUI_BANK_INACTIVE_LABEL_COLOR))
    end
    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds)
    --KEYBIND_STRIP:UpdateKeybindButtonGroup(self.spinnerKeybindStripDescriptor)
    self:RefreshList()
end
