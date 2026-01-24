--[[
File: Modules/Banking/State/StateManager.lua
Purpose: Manages persistence and state transitions for the banking module.
         Extracted from Banking.lua.
Author: BetterUI Team
Last Modified: 2026-01-24
]]

local _

-------------------------------------------------------------------------------------------------
-- SHARED CONSTANTS
-------------------------------------------------------------------------------------------------
local LIST_WITHDRAW                  = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT                   = BETTERUI.Banking.LIST_DEPOSIT
local GAMEPAD_HEADER_DEFAULT_PADDING = 0 -- Re-defined or imported if needed, but likely global API
-- Constants assumed global or available via zos

--[[
Function: BETTERUI.Banking.Class:CurrentUsedBank
Description: Updates the 'currentUsedBank' state.
Rationale: Determines whether we are using the main bank (BAG_BANK) or a house bank.
Mechanism: Checks IsHouseBankBag(GetBankingBag()). Updates namespace.
]]
function BETTERUI.Banking.Class:CurrentUsedBank()
    local newValue
    if (IsHouseBankBag(GetBankingBag()) == false) then
        newValue = BAG_BANK
    elseif (IsHouseBankBag(GetBankingBag()) == true) then
        newValue = GetBankingBag()
    else
        newValue = BAG_BANK
    end
    -- Update namespace
    BETTERUI.Banking.currentUsedBank = newValue
end

--[[
Function: BETTERUI.Banking.Class:LastUsedBank
Description: Updates the 'lastUsedBank' state.
Mechanism: Updates namespace.
]]
function BETTERUI.Banking.Class:LastUsedBank()
    local newValue
    if (IsHouseBankBag(GetBankingBag()) == false) then
        newValue = BAG_BANK
    elseif (IsHouseBankBag(GetBankingBag()) == true) then
        newValue = GetBankingBag()
    else
        newValue = BAG_BANK
    end
    -- Update namespace
    BETTERUI.Banking.lastUsedBank = newValue
end

--[[
Function: BETTERUI.Banking.Class:SaveListPosition
Description: Saves the current scroll position of the list.
Rationale: Persists the selected index so it can be restored after a refresh or mode switch.
Mechanism:
  - Saves per-mode (Withdraw/Deposit) to `lastPositions`.
  - Saves per-category to `lastPositionsByCategory` (shared across modes).
References: Called before RefreshList, ToggleList, or Mode Switches.
]]
function BETTERUI.Banking.Class:SaveListPosition()
    if not (self.list and self.lastPositions) then return end
    -- Able to return to the current position again!
    self.lastPositions[self.currentMode] = self.list.selectedIndex
    -- Save per-category position for current category (shared across modes in session)
    if self.bankCategories and #self.bankCategories > 0 then
        local cat = self.bankCategories[self.currentCategoryIndex or 1]
        if cat then
            self.lastPositionsByCategory[cat.key] = self.list.selectedIndex
        end
    end
end

--[[
Function: BETTERUI.Banking.Class:ReturnToSaved
Description: Restores the saved list position.
Rationale: Scrolls the list back to the previously saved index.
Mechanism:
  1. Checks `_justToggledMode` flag to reset to top if needed.
  2. Prioritizes per-category saved index (if available) over per-mode index.
  3. Clamps index to valid range (1 to item count).
  4. Handles mode switching if saved position implies a different context.
References: Called at the end of RefreshList.
]]
function BETTERUI.Banking.Class:ReturnToSaved()
    self:CurrentUsedBank()
    -- If there are no entries, avoid selecting index 1 (which would error)
    local totalEntries = (self.list and self.list.dataList and #self.list.dataList) or 0
    if totalEntries == 0 then
        -- Default to item keybinds and clear tooltip
        if KEYBIND_STRIP then
            if self.currencyKeybinds then KEYBIND_STRIP:RemoveKeybindButtonGroup(self.currencyKeybinds) end
            if self.withdrawDepositKeybinds then
                KEYBIND_STRIP:AddKeybindButtonGroup(self.withdrawDepositKeybinds)
                KEYBIND_STRIP:UpdateKeybindButtonGroup(self.withdrawDepositKeybinds)
            end
        end
        if GAMEPAD_TOOLTIPS then
            GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
        end
        return
    end
    -- Skip restoration logic if we just toggled modes - category is already set correctly
    if self._justToggledMode then
        self.list:SetSelectedIndexWithoutAnimation(1, true, false)
        return
    end
    local lastPosition = self.lastPositions[self.currentMode]
    -- Prefer per-category saved index when available (shared across modes in session)
    if self.bankCategories and #self.bankCategories > 0 then
        local cat = self.bankCategories[self.currentCategoryIndex or 1]
        if cat then
            if self.lastPositionsByCategory and self.lastPositionsByCategory[cat.key] then
                lastPosition = self.lastPositionsByCategory[cat.key]
            end
        end
    end
    -- Default and clamp to valid range to avoid nil or OOB indices
    lastPosition = zo_clamp(tonumber(lastPosition) or 1, 1, totalEntries)

    local currentUsedBank = BETTERUI.Banking.currentUsedBank
    local lastUsedBank = BETTERUI.Banking.lastUsedBank

    if (self.currentMode == LIST_WITHDRAW) then
        if (lastUsedBank ~= currentUsedBank) then
            self.list:SetSelectedIndexWithoutAnimation(1, true, false)
            self:SaveListPosition()
            self.currentMode = LIST_DEPOSIT
            self.list:SetSelectedIndexWithoutAnimation(1, true, false)
            self:SaveListPosition()
            self.currentMode = LIST_WITHDRAW
            self:LastUsedBank()
            self:RefreshList()
        else
            self.list:SetSelectedIndexWithoutAnimation(lastPosition, true, false)
        end
    else
        if (lastUsedBank ~= currentUsedBank) then
            self.list:SetSelectedIndexWithoutAnimation(1, true, false)
            self:SaveListPosition()
            self:LastUsedBank()
            self.currentMode = LIST_WITHDRAW
            self:ToggleList(self.currentMode == LIST_WITHDRAW)
        else
            self.list:SetSelectedIndexWithoutAnimation(lastPosition, true, false)
        end
    end
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
    self._justToggledMode = true
    self:RebuildHeaderCategories()
    self._justToggledMode = false
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
