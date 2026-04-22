--[[
File: Modules/Banking/Keybinds/KeybindManager.lua
Purpose: Manages keybind descriptors and registration for the Banking module.
         Extracted from Banking.lua.
]]

-- SHARED CONSTANTS & STATE
local LIST_WITHDRAW           = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT            = BETTERUI.Banking.LIST_DEPOSIT
local CurrencySelector = BETTERUI.Banking.CurrencySelector or {}
---@alias BetterUIBankingKeybindGroup BetterUIKeybindDescriptorGroup
---@alias BetterUIBankingListSource table|fun(): table|nil

-- Import EnsureKeybindGroupAdded from Banking.lua (or where it lives)
local function GetEntryBagAndSlot(entryData)
    local rawData = entryData and (entryData.dataSource or entryData) or nil
    if not rawData then
        return nil, nil
    end
    return rawData.bagId, rawData.slotIndex
end

local function IsActionableListEntry(entryData)
    if not entryData then
        return false
    end
    if ZO_GamepadBanking and ZO_GamepadBanking.IsEntryDataCurrencyRelated and
        ZO_GamepadBanking.IsEntryDataCurrencyRelated(entryData) then
        return false
    end

    local bagId, slotIndex = GetEntryBagAndSlot(entryData)
    if bagId == nil or slotIndex == nil then
        return false
    end

    local stackCount = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or 0
    return stackCount > 0
end

local function IsMainBankContext()
    return BETTERUI.Banking.IsMainBankTransfer()
end

local function IsGuildBankMode()
    return BETTERUI.Banking.IsGuildBankTransfer()
end

local function GetSelectedBankEntry(self)
    local list = self.list or (self.GetList and self:GetList()) or nil
    return list and list:GetSelectedData() or nil
end

local function IsCurrencyEntry(entryData)
    return ZO_GamepadBanking and ZO_GamepadBanking.IsEntryDataCurrencyRelated and
        ZO_GamepadBanking.IsEntryDataCurrencyRelated(entryData) == true
end

local function IsSelectionToggleMode(self)
    return self.multiSelectManager and self.multiSelectManager:IsActive() or false
end

local ResolveGuildBankTransferKeybindState

local function GetPrimaryTransferLabel(self)
    if IsSelectionToggleMode(self) then
        local target = GetSelectedBankEntry(self)
        if IsCurrencyEntry(target) then
            return ""
        end
        if target and self.multiSelectManager:IsSelected(target) then
            return GetString(rawget(_G, "SI_BETTERUI_DESELECT_ITEM"))
        end
        local count = self.multiSelectManager:GetSelectedCount()
        return zo_strformat(GetString(rawget(_G, "SI_BETTERUI_SELECT_WITH_COUNT")), count)
    end

    local label = self.currentMode == LIST_WITHDRAW
        and GetString(rawget(_G, "SI_BETTERUI_BANKING_WITHDRAW"))
        or GetString(rawget(_G, "SI_BETTERUI_BANKING_DEPOSIT"))
    local allowed, denialText = ResolveGuildBankTransferKeybindState(self)
    if not allowed and denialText then
        return denialText
    end
    return label or ""
end

local function CanUsePrimaryTransfer(self)
    if self:IsBatchProcessing() then
        return false
    end
    if IsSelectionToggleMode(self) then
        local target = GetSelectedBankEntry(self)
        return target ~= nil and not IsCurrencyEntry(target)
    end

    local hasSelection = self.list and not self.list:IsEmpty() and GetSelectedBankEntry(self) ~= nil and
        GetSelectedBankEntry(self).bagId ~= nil
    if not hasSelection then
        return false
    end
    return ResolveGuildBankTransferKeybindState(self)
end

local function CreateCoreNavigationKeybinds(self)
    return {
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
        BETTERUI.CIM.Keybinds.CreateClearSearchKeybind(
            function()
                if not (self.textSearchHeaderControl and (not self.textSearchHeaderControl:IsHidden())) then return end
                local searchMixin = BETTERUI.Interface and BETTERUI.Interface.SearchMixin
                if searchMixin and searchMixin.CallSearchLifecycle then
                    searchMixin.CallSearchLifecycle(self, "clear")
                elseif self.ClearSearchInput then
                    self:ClearSearchInput()
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
                return self.searchQuery and self.searchQuery ~= ""
            end
        ),
        {
            keybind = "UI_SHORTCUT_RIGHT_STICK",
            name = function()
                if IsGuildBankMode() then
                    return GetString(rawget(_G, "SI_TRADING_HOUSE_GUILD_LABEL")) or "Select Guild"
                end
                if not IsMainBankContext() then
                    return ""
                end
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
                if IsGuildBankMode() then
                    return GetNumGuilds() > 1 and not self:IsBatchProcessing()
                end
                return IsMainBankContext() and IsBankUpgradeAvailable() and not self:IsBatchProcessing()
            end,
            enabled = function()
                if IsGuildBankMode() then
                    local GuildBank = BETTERUI.Banking.GuildBank
                    return not GuildBank.IsLoading()
                end
                if not IsMainBankContext() then
                    return false
                end
                local cost = GetNextBankUpgradePrice()
                return cost ~= nil and GetCarriedCurrencyAmount(CURT_MONEY) >= cost
            end,
            callback = function()
                if self:IsBatchProcessing() then
                    return
                end
                if IsGuildBankMode() then
                    ZO_Dialogs_ShowGamepadDialog("BETTERUI_GUILD_BANK_CHANGE_ACTIVE_GUILD")
                    return
                end
                if not IsMainBankContext() then
                    return
                end
                local cost = GetNextBankUpgradePrice()
                if not cost or cost <= 0 then
                    return
                end
                if cost > GetCarriedCurrencyAmount(CURT_MONEY) then
                    BETTERUI.CIM.UserAlertText("Banking.Keybinds", GetString(rawget(_G, "SI_BUY_BANK_SPACE_CANNOT_AFFORD")))
                else
                    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.mainKeybindStripDescriptor)
                    DisplayBankUpgrade()
                end
            end
        },
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = function()
                if self:IsBatchProcessing() then
                    return GetString(rawget(_G, "SI_BETTERUI_ABORT_ACTION"))
                end
                return GetString(rawget(_G, "SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND"))
            end,
            keybind = "UI_SHORTCUT_TERTIARY",
            visible = function()
                if self:IsBatchProcessing() then
                    return true
                end
                if IsSelectionToggleMode(self) then
                    return self.multiSelectManager:HasSelections()
                end
                return IsActionableListEntry(GetSelectedBankEntry(self))
            end,
            callback = function()
                if self:IsBatchProcessing() then
                    self:RequestBatchAbort()
                    return
                end
                if IsSelectionToggleMode(self) then
                    self:ShowBatchActionsMenu()
                    return
                end
                local selectedData = GetSelectedBankEntry(self)
                if not IsActionableListEntry(selectedData) then
                    return
                end
                self:SaveListPosition()
                self:ShowActions()
            end,
        },
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
                local transferSourceBankBag = BETTERUI.Banking.GetActiveInteractionBag()
                if self.currentMode == LIST_WITHDRAW then
                    if transferSourceBankBag == BAG_BANK then
                        StackBag(BAG_BANK)
                        StackBag(BAG_SUBSCRIBER_BANK)
                    else
                        StackBag(transferSourceBankBag)
                    end
                else
                    StackBag(BAG_BACKPACK)
                end
            end,
        },
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = GetString(rawget(_G, "SI_BETTERUI_MULTI_SELECT")),
            keybind = "UI_SHORTCUT_QUINARY",
            visible = function()
                local selectedData = GetSelectedBankEntry(self)
                if not IsActionableListEntry(selectedData) then
                    return false
                end
                return self.list and not self.list:IsEmpty()
                    and not IsSelectionToggleMode(self)
                    and not self:IsBatchProcessing()
            end,
            callback = function()
                if not self:IsBatchProcessing() and not self:IsInSelectionMode() then
                    local target = GetSelectedBankEntry(self)
                    if not target or IsCurrencyEntry(target) then
                        return
                    end
                    self:SaveListPosition()
                    self:EnterSelectionMode()
                end
            end,
        },
    }
end

local function CreateTransferKeybinds(self)
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = function()
                return GetPrimaryTransferLabel(self)
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            callback = function()
                if self:IsBatchProcessing() then
                    return
                end
                if IsSelectionToggleMode(self) then
                    local target = GetSelectedBankEntry(self)
                    if IsCurrencyEntry(target) then
                        return
                    end
                    if target then
                        self:SaveListPosition()
                        self.multiSelectManager:ToggleSelection(target)
                        self:RefreshList()
                    end
                    return
                end

                self:SaveListPosition()
                local selectedData = GetSelectedBankEntry(self)
                if selectedData then
                    local stackCount = selectedData.stackCount or 1
                    if stackCount > 1 then
                        self:ShowQuantityDialog(self.currentMode == LIST_DEPOSIT)
                    else
                        self:MoveItem(self.list, 1)
                    end
                end
            end,
            visible = function()
                if self:IsBatchProcessing() then
                    return false
                end
                if IsSelectionToggleMode(self) then
                    local target = GetSelectedBankEntry(self)
                    return target ~= nil and not IsCurrencyEntry(target)
                end
                return self.list and not self.list:IsEmpty() and GetSelectedBankEntry(self) ~= nil and
                    GetSelectedBankEntry(self).bagId ~= nil
            end,
            enabled = function()
                return CanUsePrimaryTransfer(self)
            end,
        },
    }
end

local function CreateCurrencySelectorKeybinds(self)
    return {
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
                if IsGuildBankMode() then
                    if self.currentMode == LIST_WITHDRAW then
                        TransferCurrency(currencyType, amount, CURRENCY_LOCATION_GUILD_BANK, CURRENCY_LOCATION_CHARACTER)
                    else
                        TransferCurrency(currencyType, amount, CURRENCY_LOCATION_CHARACTER, CURRENCY_LOCATION_GUILD_BANK)
                    end
                else
                    if self.currentMode == LIST_WITHDRAW then
                        WithdrawCurrencyFromBank(currencyType, amount)
                    else
                        DepositCurrencyIntoBank(currencyType, amount)
                    end
                end
                CurrencySelector.HideSelector(self)
                self:RefreshFooter()
                KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds)
            end,
        }
    }
end

local function CreateCurrencyRowKeybinds(self)
    return {
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
                CurrencySelector.DisplaySelector(self, self:GetList().selectedData.currencyType)
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
end

ResolveGuildBankTransferKeybindState = function(self)
    local selectedData = self.list and self.list:GetSelectedData()
    if not (BETTERUI.Banking.IsGuildBankTransfer() and IsActionableListEntry(selectedData)) then
        return true, nil
    end

    local transferRules = BETTERUI.Banking and BETTERUI.Banking.TransferRules or nil
    local resolveDecision = transferRules and transferRules.ResolveGuildBankTransferDecision or nil
    if type(resolveDecision) ~= "function" then
        return true, nil
    end

    local bagId, slotIndex = GetEntryBagAndSlot(selectedData)
    local mode = self.currentMode == LIST_WITHDRAW and LIST_WITHDRAW or LIST_DEPOSIT
    local allowed, _, denialText = resolveDecision(mode, bagId, slotIndex)
    return allowed, denialText
end

--[[
Function: BETTERUI.Banking.Class:CreateListTriggerKeybindDescriptors
Description: Creates trigger keybinds for fast scrolling the list.
Note: Delegates to shared CIM factory for consistency.
param: list (table) - The list control.
return: table, table - Left and Right trigger keybind descriptors.
]]
---@param self BetterUIBankingClass
---@param list BetterUIBankingListSource|nil
---@return BetterUIKeybindDescriptor leftTrigger
---@return BetterUIKeybindDescriptor rightTrigger
function BETTERUI.Banking.Class:CreateListTriggerKeybindDescriptors(list)
    return BETTERUI.CIM.Keybinds.CreateListTriggerKeybinds({
        list = list,
        getSpeed = function()
            return BETTERUI.Banking.GetSetting("triggerSpeed")
        end,
        isEnabled = function()
            return BETTERUI.Banking.GetSetting("useTriggersForSkip")
        end,
    })
end

--- Updates the active item actions based on current selection.
---@param self BetterUIBankingClass
---@return nil
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

    -- Set itemActions only for actionable inventory items.
    -- Faux rows (currency/header/empty labels) can crash ESO slot action discovery.
    if not IsActionableListEntry(targetData) then
        self.itemActions:SetInventorySlot(nil)
    else
        self.itemActions:SetInventorySlot(targetData)
    end
end

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

function BETTERUI.Banking.Class:RemoveKeybinds()
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.withdrawDepositKeybinds)
    KEYBIND_STRIP:RemoveKeybindButtonGroup(self.coreKeybinds)
end

---@param self BetterUIBankingClass
---@return nil
function BETTERUI.Banking.Class:InitializeKeybind()
    if not BETTERUI.GetModuleEnabled("Banking") then
        return
    end

    self.coreKeybinds = CreateCoreNavigationKeybinds(self)
    self.withdrawDepositKeybinds = CreateTransferKeybinds(self)
    self.currencySelectorKeybinds = CreateCurrencySelectorKeybinds(self)
    self.currencyKeybinds = CreateCurrencyRowKeybinds(self)


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
        function() CurrencySelector.HideSelector(self) end)

    local leftTrigger, rightTrigger = self:CreateListTriggerKeybindDescriptors(function() return self.list end)
    table.insert(self.coreKeybinds, leftTrigger)
    table.insert(self.coreKeybinds, rightTrigger)
end

--- Triggers the selection callback to update keybinds for the current selection.
---@param self BetterUIBankingClass
---@return nil
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
