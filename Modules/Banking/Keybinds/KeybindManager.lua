--[[
File: Modules/Banking/Keybinds/KeybindManager.lua
Purpose: Manages keybind descriptors and registration for the Banking module.
         Extracted from Banking.lua.
Author: BetterUI Team
Last Modified: 2026-01-27
]]

local _

-------------------------------------------------------------------------------------------------
-- SHARED CONSTANTS & STATE
-------------------------------------------------------------------------------------------------
local LIST_WITHDRAW           = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT            = BETTERUI.Banking.LIST_DEPOSIT

-- Import EnsureKeybindGroupAdded from Banking.lua (or where it lives)
local EnsureKeybindGroupAdded = BETTERUI.Banking.EnsureKeybindGroupAdded

--[[
Function: BETTERUI.Banking.Class:CreateListTriggerKeybindDescriptors
Description: Creates trigger keybinds for fast scrolling the list.
Note: Delegates to shared CIM factory for consistency.
param: list (table) - The list control.
return: table, table - Left and Right trigger keybind descriptors.
]]
function BETTERUI.Banking.Class:CreateListTriggerKeybindDescriptors(list)
    -- Use shared CIM factory to avoid code duplication
    return BETTERUI.CIM.Keybinds.CreateListTriggerKeybinds(list)
end

--[[
Function: BETTERUI.Banking.Class:UpdateActions
Description: Updates the active item actions based on current selection.
]]
function BETTERUI.Banking.Class:UpdateActions()
    local targetData = self:GetList() and self:GetList().selectedData or nil
    if not targetData then
        self.itemActions:SetInventorySlot(nil)
        return
    end
    -- since SetInventorySlot also adds/removes keybinds, the order which we call these 2 functions is important
    -- based on whether we are looking at an item or a faux-item
    if ZO_GamepadBanking.IsEntryDataCurrencyRelated(targetData) then
        self.itemActions:SetInventorySlot(nil)
    else
        self.itemActions:SetInventorySlot(targetData)
    end
end

--[[
Function: BETTERUI.Banking.Class:AddKeybinds
Description: Registers the banking keybind groups.
]]
function BETTERUI.Banking.Class:AddKeybinds()
    KEYBIND_STRIP:RemoveAllKeyButtonGroups()
    KEYBIND_STRIP:AddKeybindButtonGroup(self.withdrawDepositKeybinds)
    KEYBIND_STRIP:AddKeybindButtonGroup(self.coreKeybinds)
    self:UpdateActions()
    self:EnsureHeaderKeybindsActive()
end

--[[
Function: BETTERUI.Banking.Class:RemoveKeybinds
Description: Unregisters the banking keybind groups.
]]
function BETTERUI.Banking.Class:RemoveKeybinds()
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.withdrawDepositKeybinds)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.coreKeybinds)
end

--[[
Function: BETTERUI.Banking.Class:InitializeKeybind
Description: Initializes the keybind descriptors for the banking module.
Rationale: Defines all keybinds for the banking interface.
Mechanism:
  - `coreKeybinds`: Navigation (Triggers), List Toggle (Y), Search Clear (Quaternary).
  - `withdrawDepositKeybinds`: Primary Action (A) for moving items.
  - `currencyKeybinds`: Primary Action (A) for opening currency selector.
  - `spinnerKeybinds`: Confirm/Cancel for partial stack moves.
References: Called during Initialize.
]]
function BETTERUI.Banking.Class:InitializeKeybind()
    if not BETTERUI.Settings.Modules["Banking"].m_enabled then
        return
    end

    self.coreKeybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = GetString(SI_BETTERUI_BANKING_TOGGLE_LIST),
            keybind = "UI_SHORTCUT_SECONDARY",
            callback = function()
                self:ToggleList(self.currentMode == LIST_DEPOSIT)
            end,
            visible = function()
                return true
            end,
            enabled = true,
        },

        -- Support QUATERNARY as a quick Clear Search key when the header search control is visible.
        {
            name = function()
                return GetString(SI_BETTERUI_CLEAR_SEARCH) or GetString(SI_GAMEPAD_SELECT_OPTION) or "Clear"
            end,
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            keybind = "UI_SHORTCUT_QUATERNARY",
            disabledDuringSceneHiding = true,
            visible = function()
                return self.textSearchHeaderControl ~= nil and not self.textSearchHeaderControl:IsHidden()
            end,
            callback = function()
                if not (self.textSearchHeaderControl and (not self.textSearchHeaderControl:IsHidden())) then return end
                -- Use centralized helper to clear the search and restore keybinds
                if self.ClearTextSearch then
                    self:ClearTextSearch()
                end
                -- After clearing search, restore the standard banking keybinds
                if self.textSearchKeybindStripDescriptor then
                    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.textSearchKeybindStripDescriptor)
                end
                if self.coreKeybinds then
                    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.coreKeybinds)
                    KEYBIND_STRIP:AddKeybindButtonGroup(self.coreKeybinds)
                    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds)
                end
                -- Restore keybinds based on current selection (handles currency rows properly)
                self:RefreshActiveKeybinds()
            end,
        },
        {
            keybind = "UI_SHORTCUT_RIGHT_STICK",
            name = function()
                local cost = GetNextBankUpgradePrice()
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
                return IsBankUpgradeAvailable()
            end,
            enabled = function()
                return GetCarriedCurrencyAmount(CURT_MONEY) >= GetNextBankUpgradePrice()
            end,
            callback = function()
                if GetNextBankUpgradePrice() > GetCarriedCurrencyAmount(CURT_MONEY) then
                    ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil, GetString(SI_BUY_BANK_SPACE_CANNOT_AFFORD))
                else
                    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.mainKeybindStripDescriptor)
                    DisplayBankUpgrade()
                end
            end
        },
        -- Y-button Actions menu using CIM factory
        BETTERUI.CIM.Keybinds.CreateActionsKeybind(
            function()
                self:SaveListPosition()
                self:ShowActions()
            end,
            function()
                -- Hide Y-button for currency rows - they don't have valid inventory slots
                local selectedData = self:GetList() and self:GetList().selectedData
                if not selectedData then return false end
                if ZO_GamepadBanking.IsEntryDataCurrencyRelated(selectedData) then
                    return false
                end
                return self.selectedItemUniqueId ~= nil or selectedData ~= nil
            end
        ),
        -- L-Stick Stack All using custom logic for dual-bank stacking
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = GetString(SI_ITEM_ACTION_STACK_ALL),
            keybind = "UI_SHORTCUT_LEFT_STICK",
            order = 1500,
            disabledDuringSceneHiding = true,
            visible = function()
                return self.list and not self.list:IsEmpty()
            end,
            callback = function()
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
            end,
        },
    }
    self.withdrawDepositKeybinds = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = function()
                local n = (self.currentMode == LIST_WITHDRAW) and GetString(SI_BETTERUI_BANKING_WITHDRAW) or
                    GetString(SI_BETTERUI_BANKING_DEPOSIT)
                return n or ""
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
                self:SaveListPosition()
                self:MoveItem(self.list)
            end,
            visible = function()
                return self.list and not self.list:IsEmpty() and self.list:GetSelectedData() ~= nil and
                    self.list:GetSelectedData().bagId ~= nil
            end,
            enabled = function()
                return self.list and not self.list:IsEmpty() and self.list:GetSelectedData() ~= nil and
                    self.list:GetSelectedData().bagId ~= nil
            end,
        },
    }

    self.currencySelectorKeybinds =
    {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = GetString(SI_BETTERUI_CONFIRM_AMOUNT),
            keybind = "UI_SHORTCUT_PRIMARY",
            visible = function()
                return true
            end,
            callback = function()
                local amount = self.selector:GetValue()
                local currencyType = self:GetList().selectedData.currencyType
                if (self.currentMode == LIST_WITHDRAW) then
                    WithdrawCurrencyFromBank(currencyType, amount)
                else
                    DepositCurrencyIntoBank(currencyType, amount)
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
                    lbl = list.selectedData.label
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
            enabled = true,
        },
    }


    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.coreKeybinds, GAME_NAVIGATION_TYPE_BUTTON) -- "Back"
    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.currencySelectorKeybinds, GAME_NAVIGATION_TYPE_BUTTON,
        function() self:HideSelector() end)

    -- removed unused self.triggerSpinnerBinds placeholder
    local leftTrigger, rightTrigger = self:CreateListTriggerKeybindDescriptors(self.list)
    table.insert(self.coreKeybinds, leftTrigger)
    table.insert(self.coreKeybinds, rightTrigger)


    self.spinnerKeybindStripDescriptor = {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = GetString(SI_BETTERUI_CONFIRM),
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
                self:SaveListPosition()
                self:MoveItem(self.list, self.spinner:GetValue())
            end,
            visible = function()
                return true
            end,
            enabled = true,
        },
    }
    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.spinnerKeybindStripDescriptor,
        GAME_NAVIGATION_TYPE_BUTTON,
        function()
            local list = self.list
            self:CancelWithdrawDeposit(list)
            KEYBIND_STRIP:RemoveKeybindButtonGroup(self.coreKeybinds)
            KEYBIND_STRIP:AddKeybindButtonGroup(self.coreKeybinds)
        end)
end

--[[
Function: BETTERUI.Banking.Class:RefreshActiveKeybinds
Description: Manually triggers the selection callback to update keybinds.
]]
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
