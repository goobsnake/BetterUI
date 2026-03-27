--[[
File: Modules/Banking/Keybinds/KeybindManager.lua
Purpose: Manages keybind descriptors and registration for the Banking module.
         Extracted from Banking.lua.
Author: BetterUI Team
Last Modified: 2026-02-07
]]

-------------------------------------------------------------------------------------------------
-- SHARED CONSTANTS & STATE
-------------------------------------------------------------------------------------------------
local LIST_WITHDRAW           = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT            = BETTERUI.Banking.LIST_DEPOSIT

-- Import EnsureKeybindGroupAdded from Banking.lua (or where it lives)

--[[
Function: BETTERUI.Banking.Class:CreateListTriggerKeybindDescriptors
Description: Creates trigger keybinds for fast scrolling the list.
Note: Delegates to shared CIM factory for consistency.
param: list (table) - The list control.
return: table, table - Left and Right trigger keybind descriptors.
]]
--- @param list table
--- @return table leftTrigger
--- @return table rightTrigger
function BETTERUI.Banking.Class:CreateListTriggerKeybindDescriptors(list)
    -- Pass Banking-specific speed getter and enabled getter so the saved settings are used
    return BETTERUI.CIM.Keybinds.CreateListTriggerKeybinds(list, nil, function()
        return BETTERUI.Banking.GetSetting("triggerSpeed")
    end, function()
        return BETTERUI.Banking.GetSetting("useTriggersForSkip")
    end)
end

--[[
Function: BETTERUI.Banking.Class:UpdateActions
Description: Updates the active item actions based on current selection.
]]
--- Updates the active item actions based on current selection.
--- @return nil
function BETTERUI.Banking.Class:UpdateActions()
    -- Skip itemActions updates when in header sort mode to prevent keybind flicker
    -- itemActions:SetInventorySlot directly manipulates KEYBIND_STRIP, bypassing guards
    if self.isInHeaderSortMode then
        return
    end

    local targetData = self:GetList() and self:GetList().selectedData or nil
    if not targetData then
        self.itemActions:SetInventorySlot(nil)
        return
    end

    -- since SetInventorySlot also adds/removes keybinds, the order which we call these 2 functions is important
    -- based on whether we are looking at an item or a faux-item
    if ZO_GamepadBanking and ZO_GamepadBanking.IsEntryDataCurrencyRelated(targetData) then
        self.itemActions:SetInventorySlot(nil)
    else
        self.itemActions:SetInventorySlot(targetData)
    end
end

--[[
Function: BETTERUI.Banking.Class:AddKeybinds
Description: Registers the banking keybind groups.
]]
--- Registers the banking keybind groups.
--- @return nil
function BETTERUI.Banking.Class:AddKeybinds()
    if self.textSearchKeybindStripDescriptor then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(self.textSearchKeybindStripDescriptor)
    end
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.withdrawDepositKeybinds)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.coreKeybinds)
    KEYBIND_STRIP:AddKeybindButtonGroup(self.withdrawDepositKeybinds)
    KEYBIND_STRIP:AddKeybindButtonGroup(self.coreKeybinds)
    self:UpdateActions()
    self:EnsureHeaderKeybindsActive()
end

--[[
Function: BETTERUI.Banking.Class:RemoveKeybinds
Description: Unregisters the banking keybind groups.
]]
--- Unregisters the banking keybind groups.
--- @return nil
function BETTERUI.Banking.Class:RemoveKeybinds()
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.withdrawDepositKeybinds)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.coreKeybinds)
end

--[[
Function: BETTERUI.Banking.Class:InitializeKeybind
Description: Initializes the keybind descriptors for the banking module.
  - `coreKeybinds`: Navigation (Triggers), List Toggle (Y), Search Clear (Quaternary).
  - `withdrawDepositKeybinds`: Primary Action (A) for moving items.
  - `currencyKeybinds`: Primary Action (A) for opening currency selector.
  - `spinnerKeybinds`: Confirm/Cancel for partial stack moves.
References: Called during Initialize.
]]
--- Initializes the keybind descriptors for the banking module.
--- @return nil
function BETTERUI.Banking.Class:InitializeKeybind()
    if not BETTERUI.Settings.Modules["Banking"].m_enabled then
        return
    end

    self.coreKeybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = GetString(rawget(_G, "SI_BETTERUI_BANKING_TOGGLE_LIST")),
            keybind = "UI_SHORTCUT_SECONDARY",
            callback = function()
                if self:IsBatchProcessing() then
                    return
                end
                self:ToggleList(self.currentMode == LIST_DEPOSIT)
            end,
            visible = function()
                return not self:IsBatchProcessing()
            end,
            enabled = true,
        },

        -- Quaternary for Clear Search (CIM Factory)
        -- Only visible when search has text
        BETTERUI.CIM.Keybinds.CreateClearSearchKeybind(
            function()
                if not (self.textSearchHeaderControl and (not self.textSearchHeaderControl:IsHidden())) then return end
                if self.ClearTextSearch then
                    self:ClearTextSearch()
                end
                if self.textSearchKeybindStripDescriptor then
                    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.textSearchKeybindStripDescriptor)
                end
                if self.coreKeybinds then
                    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.coreKeybinds)
                    KEYBIND_STRIP:AddKeybindButtonGroup(self.coreKeybinds)
                    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds)
                end
                self:RefreshActiveKeybinds()
            end,
            function()
                return self.textSearchHeaderControl ~= nil and not self.textSearchHeaderControl:IsHidden()
            end,
            function()
                -- Only show Clear Search when there is actually text to clear
                return self.searchQuery and self.searchQuery ~= ""
            end
        ),
        {
            keybind = "UI_SHORTCUT_RIGHT_STICK",
            name = function()
                -- Guild bank mode: show guild selector
                local GuildBank = BETTERUI.Banking.GuildBank
                if GuildBank and GuildBank.IsGuildBankMode() then
                    return GetString(rawget(_G, "SI_TRADING_HOUSE_GUILD_LABEL")) or "Select Guild"
                end
                -- Personal bank: show bank upgrade
                local cost = GetNextBankUpgradePrice()
                if not cost or cost <= 0 then
                    return ""
                end
                local text
                if GetCarriedCurrencyAmount(CURT_MONEY) >= cost then
                    text = zo_strformat(SI_BANK_UPGRADE_TEXT, ZO_CurrencyControl_FormatCurrency(cost),
                        ZO_GAMEPAD_GOLD_ICON_FORMAT_24)
                else
                    text = zo_strformat(SI_BANK_UPGRADE_TEXT,
                        ZO_ERROR_COLOR:Colorize(ZO_CurrencyControl_FormatCurrency(cost)), ZO_GAMEPAD_GOLD_ICON_FORMAT_24)
                end
                return text or ""
            end,
            visible = function()
                local GuildBank = BETTERUI.Banking.GuildBank
                if GuildBank and GuildBank.IsGuildBankMode() then
                    return GetNumGuilds() > 1 and not self:IsBatchProcessing()
                end
                return IsBankUpgradeAvailable() and not self:IsBatchProcessing()
            end,
            enabled = function()
                local GuildBank = BETTERUI.Banking.GuildBank
                if GuildBank and GuildBank.IsGuildBankMode() then
                    return not GuildBank.IsLoading()
                end
                local cost = GetNextBankUpgradePrice()
                return cost ~= nil and GetCarriedCurrencyAmount(CURT_MONEY) >= cost
            end,
            callback = function()
                if self:IsBatchProcessing() then
                    return
                end
                local GuildBank = BETTERUI.Banking.GuildBank
                if GuildBank and GuildBank.IsGuildBankMode() then
                    ZO_Dialogs_ShowGamepadDialog("BETTERUI_GUILD_BANK_CHANGE_ACTIVE_GUILD")
                    return
                end
                local cost = GetNextBankUpgradePrice()
                if not cost or cost <= 0 then
                    return
                end
                if cost > GetCarriedCurrencyAmount(CURT_MONEY) then
                    ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, GetString(rawget(_G, "SI_BUY_BANK_SPACE_CANNOT_AFFORD")))
                else
                    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.mainKeybindStripDescriptor)
                    DisplayBankUpgrade()
                end
            end
        },
        -- Y-button Actions menu (or Batch Actions in multi-select mode)
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = function()
                if self:IsBatchProcessing() then
                    return GetString(rawget(_G, "SI_BETTERUI_ABORT_ACTION"))
                end

                -- Always show "Actions" label - selection count is on A button
                return GetString(rawget(_G, "SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND"))
            end,
            keybind = "UI_SHORTCUT_TERTIARY",
            visible = function()
                if self:IsBatchProcessing() then
                    return true
                end

                -- In multi-select mode, show when items are selected
                if self.multiSelectManager and self.multiSelectManager:IsActive() then
                    return self.multiSelectManager:HasSelections()
                end
                -- Normal mode: hide for currency rows
                local selectedData = self:GetList() and self:GetList().selectedData
                if not selectedData then return false end
                if ZO_GamepadBanking.IsEntryDataCurrencyRelated(selectedData) then
                    return false
                end
                return self.selectedItemUniqueId ~= nil or selectedData ~= nil
            end,
            callback = function()
                if self:IsBatchProcessing() then
                    self:RequestBatchAbort()
                    return
                end

                if self.multiSelectManager and self.multiSelectManager:IsActive() then
                    -- Show batch actions dialog in multi-select mode
                    self:ShowBatchActionsMenu()
                else
                    -- Normal Y menu
                    self:SaveListPosition()
                    self:ShowActions()
                end
            end,
        },
        -- L-Stick Stack All using custom logic for dual-bank stacking
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = GetString(rawget(_G, "SI_ITEM_ACTION_STACK_ALL")),
            keybind = "UI_SHORTCUT_LEFT_STICK",
            order = 1500,
            disabledDuringSceneHiding = true,
            visible = function()
                return self.list and not self.list:IsEmpty() and not self:IsBatchProcessing()
            end,
            callback = function()
                if self:IsBatchProcessing() then
                    return
                end
                local currentUsedBank = BETTERUI.Banking.currentUsedBank
                if self.currentMode == LIST_WITHDRAW then
                    if currentUsedBank == BAG_BANK then
                        StackBag(BAG_BANK)
                        StackBag(BAG_SUBSCRIBER_BANK)
                    else
                        StackBag(currentUsedBank)
                    end
                else
                    StackBag(BAG_BACKPACK)
                end
                -- No manual refresh needed - SHARED_INVENTORY callbacks will
                -- automatically refresh the list when the cache is updated
            end,
        },
        -- Y-Hold (QUINARY) for Multi-Select Mode
        -- Dedicated entry point for multi-select functionality
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = GetString(rawget(_G, "SI_BETTERUI_MULTI_SELECT")),
            keybind = "UI_SHORTCUT_QUINARY",
            visible = function()
                -- Must have items available.
                -- Hide when already in multi-select mode or batch processing.
                local selectedData = self.list and self.list:GetSelectedData()
                if not selectedData or ZO_GamepadBanking.IsEntryDataCurrencyRelated(selectedData) then
                    return false
                end

                local managerActive = self.multiSelectManager and self.multiSelectManager:IsActive()
                return self.list and not self.list:IsEmpty()
                    and not managerActive
                    and not self:IsBatchProcessing()
            end,
            callback = function()
                if not self:IsBatchProcessing() and not self:IsInSelectionMode() then
                    local target = self.list and self.list:GetSelectedData()
                    if not target or ZO_GamepadBanking.IsEntryDataCurrencyRelated(target) then
                        return
                    end
                    self:SaveListPosition()
                    self:EnterSelectionMode()
                end
            end,
        },
    }
    self.withdrawDepositKeybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = function()
                -- In multi-select mode, show "Deselect" or "Select (count)"
                if self.multiSelectManager and self.multiSelectManager:IsActive() then
                    local target = self.list and self.list:GetSelectedData()
                    -- Skip currency rows
                    if target and ZO_GamepadBanking.IsEntryDataCurrencyRelated(target) then
                        return ""
                    end
                    if target and self.multiSelectManager:IsSelected(target) then
                        return GetString(rawget(_G, "SI_BETTERUI_DESELECT_ITEM"))
                    else
                        local count = self.multiSelectManager:GetSelectedCount()
                        return zo_strformat(GetString(rawget(_G, "SI_BETTERUI_SELECT_WITH_COUNT")), count)
                    end
                end

                local n = (self.currentMode == LIST_WITHDRAW) and GetString(rawget(_G, "SI_BETTERUI_BANKING_WITHDRAW")) or
                    GetString(rawget(_G, "SI_BETTERUI_BANKING_DEPOSIT"))
                return n or ""
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
                if self:IsBatchProcessing() then
                    return
                end

                -- In multi-select mode, toggle selection
                if self.multiSelectManager and self.multiSelectManager:IsActive() then
                    local target = self.list and self.list:GetSelectedData()
                    -- Skip currency rows
                    if target and ZO_GamepadBanking.IsEntryDataCurrencyRelated(target) then
                        return
                    end
                    if target then
                        self:SaveListPosition()
                        self.multiSelectManager:ToggleSelection(target)
                        self:RefreshList()
                    end
                    return
                end

                -- Normal mode: withdraw/deposit
                self:SaveListPosition()
                local selectedData = self.list and self.list:GetSelectedData()
                if selectedData then
                    local stackCount = selectedData.stackCount or 1
                    if stackCount > 1 then
                        -- For stacked items, show quantity dialog
                        local isDeposit = (self.currentMode == LIST_DEPOSIT)
                        self:ShowQuantityDialog(isDeposit)
                    else
                        -- For single items, move directly
                        self:MoveItem(self.list, 1)
                    end
                end
            end,
            visible = function()
                if self:IsBatchProcessing() then
                    return false
                end
                -- In multi-select mode, hide for currency rows
                if self.multiSelectManager and self.multiSelectManager:IsActive() then
                    local target = self.list and self.list:GetSelectedData()
                    if target and ZO_GamepadBanking.IsEntryDataCurrencyRelated(target) then
                        return false
                    end
                    return target ~= nil
                end
                return self.list and not self.list:IsEmpty() and self.list:GetSelectedData() ~= nil and
                    self.list:GetSelectedData().bagId ~= nil
            end,
            enabled = function()
                if self:IsBatchProcessing() then
                    return false
                end
                -- In multi-select mode, always enabled for valid targets
                if self.multiSelectManager and self.multiSelectManager:IsActive() then
                    local target = self.list and self.list:GetSelectedData()
                    return target ~= nil and not ZO_GamepadBanking.IsEntryDataCurrencyRelated(target)
                end
                return self.list and not self.list:IsEmpty() and self.list:GetSelectedData() ~= nil and
                    self.list:GetSelectedData().bagId ~= nil
            end,
        },
    }

    self.currencySelectorKeybinds =
    {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = GetString(rawget(_G, "SI_BETTERUI_CONFIRM_AMOUNT")),
            keybind = "UI_SHORTCUT_PRIMARY",
            visible = function()
                return true
            end,
            callback = function()
                local amount = self.selector:GetValue()
                local currencyType = self:GetList().selectedData.currencyType
                local GuildBank = BETTERUI.Banking.GuildBank
                if GuildBank and GuildBank.IsGuildBankMode() then
                    -- Guild bank: use TransferCurrency with guild bank locations
                    if self.currentMode == LIST_WITHDRAW then
                        TransferCurrency(currencyType, amount, CURRENCY_LOCATION_GUILD_BANK, CURRENCY_LOCATION_CHARACTER)
                    else
                        TransferCurrency(currencyType, amount, CURRENCY_LOCATION_CHARACTER, CURRENCY_LOCATION_GUILD_BANK)
                    end
                else
                    -- Personal bank: use standard bank currency functions
                    if (self.currentMode == LIST_WITHDRAW) then
                        WithdrawCurrencyFromBank(currencyType, amount)
                    else
                        DepositCurrencyIntoBank(currencyType, amount)
                    end
                end
                self:HideSelector()
                self:RefreshFooter()
                KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds)
            end,
        }
    }

    self.currencyKeybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = function()
                local lbl = nil
                local list = self:GetList()
                if list and list.selectedData then
                    local selectedData = list.selectedData
                    if selectedData.keybindLabel then
                        lbl = selectedData.keybindLabel
                    elseif selectedData.label then
                        lbl = selectedData.label
                    elseif selectedData.GetText then
                        lbl = selectedData:GetText()
                    else
                        lbl = selectedData.text
                    end
                end
                return lbl or ""
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
                self:SaveListPosition()
                self:DisplaySelector(self:GetList().selectedData.currencyType)
            end,
            visible = function()
                return true
            end,
            enabled = function()
                local list = self:GetList()
                local selectedData = list and list:GetSelectedData()
                if not selectedData then
                    return false
                end
                if selectedData.IsEnabled then
                    return selectedData:IsEnabled()
                end
                if selectedData.enabled ~= nil then
                    return selectedData.enabled
                end
                return true
            end,
        },
    }


    -- Custom Back button: Exit multi-select mode first, then normal back behavior
    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.coreKeybinds, GAME_NAVIGATION_TYPE_BUTTON,
        function()
            -- If in multi-select mode, exit that instead of closing the scene
            if self.multiSelectManager and self.multiSelectManager:IsActive() then
                self:ExitSelectionMode()
                return
            end
            -- Normal back: cancel withdraw/deposit or close scene
            self:CancelWithdrawDeposit(self.list)
        end
    ) -- "Back"
    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.currencySelectorKeybinds, GAME_NAVIGATION_TYPE_BUTTON,
        function() self:HideSelector() end)

    -- removed unused self.triggerSpinnerBinds placeholder
    local leftTrigger, rightTrigger = self:CreateListTriggerKeybindDescriptors(function() return self.list end)
    table.insert(self.coreKeybinds, leftTrigger)
    table.insert(self.coreKeybinds, rightTrigger)

    -- NOTE: spinnerKeybindStripDescriptor has been removed.
    -- Quantity selection now uses BETTERUI_BANK_QUANTITY_DIALOG modal dialog.
end

--[[
Function: BETTERUI.Banking.Class:RefreshActiveKeybinds
Description: Manually triggers the selection callback to update keybinds.
]]
--- Manually triggers the selection callback to update keybinds.
--- @return nil
function BETTERUI.Banking.Class:RefreshActiveKeybinds()
    if not (self.selectedDataCallback and self.list) then return end
    local selectedControl = nil
    if self.list.GetSelectedControl then
        selectedControl = self.list:GetSelectedControl()
    end
    local selectedData = nil
    if self.list.GetSelectedData then
        selectedData = self.list:GetSelectedData()
    end
    -- Call the callback with self as the context so OnItemSelectedChange receives it properly
    self.selectedDataCallback(self, selectedControl, selectedData)
end
