local LIST_WITHDRAW           = BETTERUI.Banking.LIST_WITHDRAW
local LIST_DEPOSIT            = BETTERUI.Banking.LIST_DEPOSIT
---@alias BetterUIBankingKeybindGroup BetterUIKeybindDescriptorGroup
---@alias BetterUIBankingListSource table|fun(): table|nil

--- Resolves the currency selector module at call time; CurrencySelector.lua loads after this file.
---@return table|nil
local function GetCurrencySelector()
    return BETTERUI.Banking and BETTERUI.Banking.CurrencySelector
end

local function GetSelectedBankEntry(self)
    local list = self.list or (self.GetList and self:GetList()) or nil
    return list and list:GetSelectedData() or nil
end

local function IsCurrencyEntry(entryData)
    return ZO_GamepadBanking and ZO_GamepadBanking.IsEntryDataCurrencyRelated and
        ZO_GamepadBanking.IsEntryDataCurrencyRelated(entryData) == true
end

local function GetSelectedTransferEntry(self)
    local selectedData = GetSelectedBankEntry(self)
    if not selectedData or IsCurrencyEntry(selectedData) then
        return nil
    end
    return selectedData
end

local function IsSelectionToggleMode(self)
    return self.multiSelectManager and self.multiSelectManager:IsActive() or false
end

local ResolveGuildBankTransferKeybindState

---@param self BETTERUI.Banking.Class
---@return BetterUIBankingTransferContext transferContext
---@return boolean isGuildBankMode
---@return boolean isMainBankContext
local function ResolveKeybindTransferContext(self)
    local transferContext = BETTERUI.Banking.ReadTransferContextSnapshot()
    local isGuildBankMode = transferContext.kind == BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK
    local isMainBankContext = transferContext.kind == BETTERUI.Banking.TRANSFER_MODE_MAIN_BANK
        and transferContext.interactionBag == BAG_BANK
    return transferContext, isGuildBankMode, isMainBankContext
end

local function BeginCurrencyTransferFlow(self, message, data)
    local L = BETTERUI.Log
    if L and L.IsActive and L.IsActive() and L.FlowBegin then
        data = data or {}
        data.mode = self and self.currentMode
        return L.FlowBegin("bankCurrencyTransfer", L.CATEGORY.TRANSFER, message, data)
    end
    return nil
end

local function EndCurrencyTransferFlow(flow, message, data)
    local L = BETTERUI.Log
    if flow and L and L.FlowEnd then
        L.FlowEnd(flow, L.CATEGORY.TRANSFER, message, data)
    end
end

local function LogBankKeybindState(message, data, category)
    local L = BETTERUI.Log
    if L and L.Debug then
        L.Debug(category or L.CATEGORY.STATE, message, data)
    end
end

local function TraceBankKeybind(event, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    if data.scene == nil and BETTERUI.CIM and BETTERUI.CIM.Utils and BETTERUI.CIM.Utils.GetCurrentSceneName then
        data.scene = BETTERUI.CIM.Utils.GetCurrentSceneName()
    end
    L.TraceEvent(L.CATEGORY.KEYBIND, event, phase, data)
end

local function WrapBankingKeybindGroup(group)
    local keybinds = BETTERUI.CIM and BETTERUI.CIM.Keybinds
    local anchor = keybinds and keybinds.InputAnchor
    if anchor and type(anchor.WrapGroup) == "function" then
        return anchor.WrapGroup(group, "Banking")
    end
    return group
end

local function TraceBankCurrencyAction(phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.feature = data.feature or "currencyTransfer"
    L.TraceEvent(L.CATEGORY.TRANSFER, "bank.currency_transfer", phase, data)
end

local function ReadCurrencyAmount(currencyType, location)
    local L = BETTERUI.Log
    if L and L.GetCurrencyAmountForLocation then
        return L.GetCurrencyAmountForLocation(currencyType, location)
    end
    if GetCurrencyAmount then
        local ok, amount = pcall(GetCurrencyAmount, currencyType, location)
        if ok then return amount end
    end
    return nil
end

local function CurrencySnapshot(currencyType, fromLocation, toLocation, prefix)
    prefix = prefix or ""
    return {
        [prefix .. "From"] = ReadCurrencyAmount(currencyType, fromLocation),
        [prefix .. "To"] = ReadCurrencyAmount(currencyType, toLocation),
    }
end

local function IsLogPrivacyMode()
    local L = BETTERUI.Log
    return L and L.GetPrivacyMode and L.GetPrivacyMode() == true
end

local function CurrencyAmountForLog(amount)
    if IsLogPrivacyMode() then
        return nil
    end
    return amount
end

local function CurrencyDelta(afterValue, beforeValue)
    if type(afterValue) == "number" and type(beforeValue) == "number" then
        return afterValue - beforeValue
    end
    return nil
end

local function AddCurrencySnapshotFields(payload, before, postCall, settled)
    payload = payload or {}
    before = before or {}
    postCall = postCall or {}
    settled = settled or {}
    if IsLogPrivacyMode() then
        payload.postCallFromDelta = CurrencyDelta(postCall.postCallFrom, before.beforeFrom)
        payload.postCallToDelta = CurrencyDelta(postCall.postCallTo, before.beforeTo)
        payload.settledFromDelta = CurrencyDelta(settled.settledFrom, before.beforeFrom)
        payload.settledToDelta = CurrencyDelta(settled.settledTo, before.beforeTo)
    else
        payload.beforeFrom = before.beforeFrom
        payload.beforeTo = before.beforeTo
        payload.postCallFrom = postCall.postCallFrom
        payload.postCallTo = postCall.postCallTo
        payload.settledFrom = settled.settledFrom
        payload.settledTo = settled.settledTo
    end
    return payload
end

local function GetPrimaryTransferLabel(self)
    if IsSelectionToggleMode(self) then
        local target = GetSelectedTransferEntry(self)
        if not target then
            return ""
        end
        return BETTERUI.CIM.Keybinds.GetMultiSelectToggleLabel(self.multiSelectManager, target)
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

local function TracePrimaryTransferPolicyState(self, phase, bagId, slotIndex, denyReason, targetBag)
    local traceKey = table.concat({
        phase,
        tostring(self and self.currentMode or ""),
        tostring(bagId or ""),
        tostring(slotIndex or ""),
        tostring(targetBag or ""),
        tostring(denyReason or ""),
    }, "|")

    if phase == "blocked" then
        if self._betteruiLastPrimaryTransferPolicyBlock == traceKey then
            return
        end
        self._betteruiLastPrimaryTransferPolicyBlock = traceKey
    else
        if self._betteruiLastPrimaryTransferPolicyBlock == nil then
            return
        end
        self._betteruiLastPrimaryTransferPolicyBlock = nil
    end

    TraceBankKeybind("bank.primary_transfer", phase, {
        reason = phase == "blocked" and "transferPolicy" or "transferPolicyCleared",
        denyReason = denyReason,
        mode = self and self.currentMode,
        bagId = bagId,
        slotIndex = slotIndex,
        targetBag = targetBag,
        selected = BETTERUI.Log and BETTERUI.Log.DescribeListSelection and BETTERUI.Log.DescribeListSelection(self.list, "selection") or nil,
    })
end

local function CanUseTransferPolicy(self, bagId, slotIndex)
    if self.currentMode ~= LIST_DEPOSIT then
        TracePrimaryTransferPolicyState(self, "unblocked", bagId, slotIndex)
        return true
    end

    local transferContext = BETTERUI.Banking.ReadTransferContextSnapshot()
    local targetBag = transferContext and transferContext.depositTargetBag or BAG_BANK
    local transferService = BETTERUI.Banking and BETTERUI.Banking.GetTransferService and BETTERUI.Banking.GetTransferService()
    local canDepositIntoBank = transferService and transferService.CanDepositIntoBank or nil
    if type(canDepositIntoBank) ~= "function" then
        TracePrimaryTransferPolicyState(self, "unblocked", bagId, slotIndex, nil, targetBag)
        return true
    end

    local canDeposit, denyReason = canDepositIntoBank(bagId, slotIndex, targetBag)
    if canDeposit ~= true then
        TracePrimaryTransferPolicyState(self, "blocked", bagId, slotIndex, denyReason or "deposit_denied", targetBag)
        return false, nil, denyReason
    end

    TracePrimaryTransferPolicyState(self, "unblocked", bagId, slotIndex, nil, targetBag)
    return true
end

local function CanUsePrimaryTransfer(self)
    if self:IsBatchProcessing() then
        return false
    end
    if IsSelectionToggleMode(self) then
        return GetSelectedTransferEntry(self) ~= nil
    end

    local selectedData = GetSelectedBankEntry(self)
    local bagId, slotIndex = BETTERUI.Banking.ResolveListEntrySlot(selectedData)
    local hasSelection = self.list and not self.list:IsEmpty() and selectedData ~= nil and bagId ~= nil and slotIndex ~= nil
    if not hasSelection then
        TraceBankKeybind("bank.primary_transfer", "blocked", {
            reason = "invalidSelection",
            mode = self and self.currentMode,
            bagId = bagId,
            slotIndex = slotIndex,
            selected = BETTERUI.Log and BETTERUI.Log.DescribeListSelection and BETTERUI.Log.DescribeListSelection(self.list, "selection") or nil,
        })
        return false
    end

    local allowed, denialText = ResolveGuildBankTransferKeybindState(self)
    if not allowed then
        return false, denialText
    end

    local policyAllowed, policyDenialText = CanUseTransferPolicy(self, bagId, slotIndex)
    if policyAllowed ~= true then
        return false, policyDenialText
    end

    if bagId and slotIndex
        and type(BETTERUI.Banking.IsTransferPending) == "function"
        and BETTERUI.Banking.IsTransferPending(bagId, slotIndex) then
        local pendingKey = tostring(bagId) .. ":" .. tostring(slotIndex)
        if self._betteruiLastPrimaryTransferPendingBlock ~= pendingKey then
            self._betteruiLastPrimaryTransferPendingBlock = pendingKey
            TraceBankKeybind("bank.primary_transfer", "blocked", {
                reason = "transferPending",
                mode = self.currentMode,
                bagId = bagId,
                slotIndex = slotIndex,
                selected = BETTERUI.Log and BETTERUI.Log.DescribeListSelection and BETTERUI.Log.DescribeListSelection(self.list, "selection") or nil,
            })
        end
        return false
    end
    if self._betteruiLastPrimaryTransferPendingBlock ~= nil then
        TraceBankKeybind("bank.primary_transfer", "unblocked", {
            reason = "transferPendingCleared",
            previousPendingKey = self._betteruiLastPrimaryTransferPendingBlock,
            mode = self.currentMode,
            bagId = bagId,
            slotIndex = slotIndex,
        })
        self._betteruiLastPrimaryTransferPendingBlock = nil
    end

    return true
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
                local fromMode = self.currentMode
                local toMode = self.currentMode == LIST_DEPOSIT and LIST_WITHDRAW or LIST_DEPOSIT
                TraceBankKeybind("bank.mode_toggle", "before", {
                    fromMode = fromMode,
                    toMode = toMode,
                })
                self:ToggleList(self.currentMode == LIST_DEPOSIT)
                TraceBankKeybind("bank.mode_toggle", "after", {
                    fromMode = fromMode,
                    requestedMode = toMode,
                    mode = self.currentMode,
                    core = BETTERUI.Log and BETTERUI.Log.DescribeKeybindDescriptors and BETTERUI.Log.DescribeKeybindDescriptors(self.coreKeybinds, "core") or nil,
                    transfer = BETTERUI.Log and BETTERUI.Log.DescribeKeybindDescriptors and BETTERUI.Log.DescribeKeybindDescriptors(self.withdrawDepositKeybinds, "transfer") or nil,
                })
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
                    BETTERUI.Interface.RemoveKeybindGroupIfPresent(self.textSearchKeybindStripDescriptor)
                end
                if self.coreKeybinds then
                    BETTERUI.Interface.RemoveKeybindGroupIfPresent(self.coreKeybinds)
                    BETTERUI.Interface.EnsureKeybindGroupAdded(self.coreKeybinds)
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
                local _, isGuildBankMode, isMainBankContext = ResolveKeybindTransferContext(self)

                if isGuildBankMode then
                    return GetString(rawget(_G, "SI_TRADING_HOUSE_GUILD_LABEL")) or "Select Guild"
                end
                if not isMainBankContext then
                    return ""
                end
                local cost = GetNextBankUpgradePrice()
                if not cost or cost <= 0 then
                    return ""
                end
                -- U50: SI_BANK_UPGRADE_TEXT takes a single pre-formatted currency
                -- string; mirror ZOS banking_gamepad.lua.
                local text
                if GetCarriedCurrencyAmount(CURT_MONEY) >= cost then
                    text = zo_strformat(SI_BANK_UPGRADE_TEXT,
                        ZO_Currency_FormatGamepad(CURT_MONEY, cost, ZO_CURRENCY_FORMAT_AMOUNT_ICON))
                else
                    text = zo_strformat(SI_BANK_UPGRADE_TEXT,
                        ZO_Currency_FormatGamepad(CURT_MONEY, cost, ZO_CURRENCY_FORMAT_ERROR_AMOUNT_ICON))
                end
                return text or ""
            end,
            visible = function()
                local _, isGuildBankMode, isMainBankContext = ResolveKeybindTransferContext(self)

                if isGuildBankMode then
                    return GetNumGuilds() > 1 and not self:IsBatchProcessing()
                end
                return isMainBankContext and IsBankUpgradeAvailable() and not self:IsBatchProcessing()
            end,
            enabled = function()
                local _, isGuildBankMode, isMainBankContext = ResolveKeybindTransferContext(self)

                if isGuildBankMode then
                    local GuildBank = BETTERUI.Banking.GuildBank
                    return not (GuildBank and GuildBank.IsLoading())
                end
                if not isMainBankContext then
                    return false
                end
                local cost = GetNextBankUpgradePrice()
                return cost ~= nil and GetCarriedCurrencyAmount(CURT_MONEY) >= cost
            end,
            callback = function()
                local _, isGuildBankMode, isMainBankContext = ResolveKeybindTransferContext(self)
                TraceBankKeybind("bank.upgrade", "requested", {
                    batch = self:IsBatchProcessing() == true,
                    guildBank = isGuildBankMode == true,
                    mainBank = isMainBankContext == true,
                })
                if self:IsBatchProcessing() then
                    TraceBankKeybind("bank.upgrade", "skipped", { reason = "batchProcessing" })
                    return
                end

                if isGuildBankMode then
                    TraceBankKeybind("bank.guild_selector", "dialog_show", { reason = "guildBankMode" })
                    ZO_Dialogs_ShowGamepadDialog("BETTERUI_GUILD_BANK_CHANGE_ACTIVE_GUILD")
                    return
                end
                if not isMainBankContext then
                    TraceBankKeybind("bank.upgrade", "skipped", { reason = "notMainBankContext" })
                    return
                end
                local cost = GetNextBankUpgradePrice()
                if not cost or cost <= 0 then
                    TraceBankKeybind("bank.upgrade", "skipped", { reason = "missingCost", cost = cost })
                    return
                end
                if cost > GetCarriedCurrencyAmount(CURT_MONEY) then
                    TraceBankKeybind("bank.upgrade", "blocked", {
                        reason = "cannotAfford",
                        cost = cost,
                        carriedGold = CurrencyAmountForLog(GetCarriedCurrencyAmount(CURT_MONEY)),
                    })
                    BETTERUI.CIM.UserAlertText("Banking.Keybinds", GetString(rawget(_G, "SI_BUY_BANK_SPACE_CANNOT_AFFORD")))
                else
                    -- Banking never assigns mainKeybindStripDescriptor (its groups are
                    -- coreKeybinds/withdrawDepositKeybinds/...); the upgrade dialog
                    -- manages its own keybind layer, so no teardown is needed here.
                    TraceBankKeybind("bank.upgrade", "dialog_show", {
                        cost = cost,
                        carriedGold = CurrencyAmountForLog(GetCarriedCurrencyAmount(CURT_MONEY)),
                        currentUpgrade = GetCurrentBankUpgrade and GetCurrentBankUpgrade() or nil,
                        maxUpgrade = GetMaxBankUpgrade and GetMaxBankUpgrade() or nil,
                    })
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
                return BETTERUI.Banking.IsActionableTransferEntry(GetSelectedBankEntry(self))
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
                if not BETTERUI.Banking.IsActionableTransferEntry(selectedData) then
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
                local visible = self.list and not self.list:IsEmpty() and not self:IsBatchProcessing()
                if self._betteruiLastStackAllVisible ~= visible then
                    self._betteruiLastStackAllVisible = visible
                    TraceBankKeybind("bank.stack_all", "visibility", {
                        visible = visible == true,
                        hasList = self.list ~= nil,
                        listEmpty = self.list and self.list.IsEmpty and self.list:IsEmpty() or nil,
                        batchProcessing = self.IsBatchProcessing and self:IsBatchProcessing() or nil,
                        mode = self.currentMode,
                    })
                end
                return visible
            end,
            callback = function()
                if self:IsBatchProcessing() then
                    TraceBankKeybind("bank.stack_all", "blocked", {
                        reason = "batchProcessing",
                        mode = self.currentMode,
                    })
                    return
                end
                local transferContext = BETTERUI.Banking.ReadTransferContextSnapshot()
                local transferSourceBankBag = transferContext.interactionBag or BAG_BANK
                local targetBags = {}
                if self.currentMode == LIST_WITHDRAW then
                    if transferSourceBankBag == BAG_BANK then
                        targetBags = { BAG_BANK, BAG_SUBSCRIBER_BANK }
                    else
                        targetBags = { transferSourceBankBag }
                    end
                else
                    targetBags = { BAG_BACKPACK }
                end
                if type(StackBag) ~= "function" then
                    TraceBankKeybind("bank.stack_all", "blocked", {
                        reason = "missingStackBagApi",
                        mode = self.currentMode,
                        transferKind = transferContext.kind,
                        targetBags = targetBags,
                    })
                    return
                end
                TraceBankKeybind("bank.stack_all", "before", {
                    mode = self.currentMode,
                    transferKind = transferContext.kind,
                    transferSourceBankBag = transferSourceBankBag,
                    targetBags = targetBags,
                })
                for i = 1, #targetBags do
                    StackBag(targetBags[i])
                end
                TraceBankKeybind("bank.stack_all", "after", {
                    mode = self.currentMode,
                    transferKind = transferContext.kind,
                    targetBags = targetBags,
                    requestCount = #targetBags,
                })
                if BETTERUI.Banking and BETTERUI.Banking.Tasks and BETTERUI.Banking.Tasks.Schedule then
                    BETTERUI.Banking.Tasks:Schedule("stackAllRefresh", 120, function()
                        if self.RefreshList then self:RefreshList() end
                        if self.RefreshFooter then self:RefreshFooter() end
                        if self.UpdateKeybinds then self:UpdateKeybinds() end
                        TraceBankKeybind("bank.stack_all", "refresh_task", {
                            mode = self.currentMode,
                            refreshedList = self.RefreshList ~= nil,
                            refreshedFooter = self.RefreshFooter ~= nil,
                            refreshedKeybinds = self.UpdateKeybinds ~= nil,
                        })
                    end)
                    TraceBankKeybind("bank.stack_all", "refresh_scheduled", {
                        delayMs = 120,
                        scheduler = "Banking.Tasks",
                    })
                end
            end,
        },
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = BETTERUI.CIM.Keybinds.GetMultiSelectLabel(),
            keybind = "UI_SHORTCUT_QUINARY",
            visible = function()
                local selectedData = GetSelectedBankEntry(self)
                if not BETTERUI.Banking.IsActionableTransferEntry(selectedData) then
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
                    local target = GetSelectedTransferEntry(self)
                    if target then
                        self:SaveListPosition()
                        self.multiSelectManager:ToggleSelection(target)
                        self:RefreshList()
                    end
                    return
                end

                local canTransfer, denialText = CanUsePrimaryTransfer(self)
                if canTransfer ~= true then
                    TraceBankKeybind("bank.primary_transfer", "blocked", {
                        reason = "callbackRecheckFailed",
                        denialText = denialText,
                        mode = self.currentMode,
                        selected = BETTERUI.Log and BETTERUI.Log.DescribeListSelection and BETTERUI.Log.DescribeListSelection(self.list, "selection") or nil,
                    })
                    return
                end

                self:SaveListPosition()
                local selectedData = GetSelectedBankEntry(self)
                if selectedData then
                    local stackCount = selectedData.stackCount or 1
                    local _, isGuildBankMode = ResolveKeybindTransferContext(self)
                    local bagId, slotIndex = BETTERUI.Banking.ResolveListEntrySlot(selectedData)
                    LogBankKeybindState("bank primary transfer invoked", {
                        bag = bagId,
                        slot = slotIndex,
                        mode = self.currentMode,
                        stackCount = stackCount,
                        guild = isGuildBankMode,
                    }, "TRANSFER")
                    if stackCount > 1 and not isGuildBankMode then
                        self:ShowQuantityDialog(self.currentMode == LIST_DEPOSIT)
                    else
                        -- Guild bank transfer APIs always move the whole stack,
                        -- so the quantity dialog is skipped in guild-bank mode.
                        self:MoveItem(self.list, stackCount)
                    end
                end
            end,
            visible = function()
                if self:IsBatchProcessing() then
                    return false
                end
                if IsSelectionToggleMode(self) then
                    return GetSelectedTransferEntry(self) ~= nil
                end
                local selectedData = GetSelectedBankEntry(self)
                return self.list and not self.list:IsEmpty() and selectedData ~= nil and selectedData.bagId ~= nil
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
                if not amount or amount <= 0 then
                    TraceBankCurrencyAction("blocked", {
                        reason = "invalidAmount",
                        amount = amount,
                        mode = self.currentMode,
                    })
                    LogBankKeybindState("bank currency transfer skipped", {
                        reason = "amount",
                        amount = amount,
                        mode = self.currentMode,
                    })
                    return
                end
                local currencySelector = GetCurrencySelector()
                local currencyType = currencySelector and currencySelector.GetActiveCurrencyType
                    and currencySelector.GetActiveCurrencyType(self)
                if currencyType == nil then
                    local list = self:GetList()
                    local selectedData = list and list:GetSelectedData() or nil
                    currencyType = selectedData and selectedData.currencyType or nil
                end
                if currencyType == nil then
                    TraceBankCurrencyAction("blocked", {
                        reason = "missingCurrencyType",
                        amount = amount,
                        mode = self.currentMode,
                    })
                    LogBankKeybindState("bank currency transfer skipped", {
                        reason = "currency",
                        amount = amount,
                        mode = self.currentMode,
                    })
                    return
                end
                local _, isGuildBankMode = ResolveKeybindTransferContext(self)
                local flow = BeginCurrencyTransferFlow(self, "bank currency transfer requested", {
                    currencyType = currencyType,
                    amount = amount,
                    guild = isGuildBankMode,
                })
                if isGuildBankMode then
                    local GuildBank = BETTERUI.Banking.GuildBank
                    local denial = GuildBank and GuildBank.GetGoldPermissionDenial
                        and GuildBank.GetGoldPermissionDenial(self.currentMode)
                    if denial then
                        BETTERUI.CIM.UserNotify("Banking.Keybinds:CurrencyTransfer", denial.text)
                        EndCurrencyTransferFlow(flow, "bank currency transfer denied", {
                            currencyType = currencyType,
                            amount = amount,
                            guild = true,
                            reason = "permission",
                        })
                        return
                    end
                end
                -- Re-clamp to the live maximum: balances can change while the
                -- selector is open (mail, trades, other clients).
                local liveMax = currencySelector and currencySelector.GetLiveTransferMax
                    and currencySelector.GetLiveTransferMax(self, currencyType)
                if liveMax ~= nil then
                    if liveMax <= 0 then
                        EndCurrencyTransferFlow(flow, "bank currency transfer skipped", {
                            currencyType = currencyType,
                            amount = amount,
                            guild = isGuildBankMode,
                            reason = "liveMax",
                        })
                        return
                    end
                    amount = zo_min(amount, liveMax)
                end
                local fromLocation
                local toLocation
                if isGuildBankMode then
                    if self.currentMode == LIST_WITHDRAW then
                        fromLocation, toLocation = CURRENCY_LOCATION_GUILD_BANK, CURRENCY_LOCATION_CHARACTER
                    else
                        fromLocation, toLocation = CURRENCY_LOCATION_CHARACTER, CURRENCY_LOCATION_GUILD_BANK
                    end
                else
                    if self.currentMode == LIST_WITHDRAW then
                        fromLocation, toLocation = CURRENCY_LOCATION_BANK, CURRENCY_LOCATION_CHARACTER
                    else
                        fromLocation, toLocation = CURRENCY_LOCATION_CHARACTER, CURRENCY_LOCATION_BANK
                    end
                end
                local before = CurrencySnapshot(currencyType, fromLocation, toLocation, "before")
                TraceBankKeybind("bank.currency_transfer", "before", AddCurrencySnapshotFields({
                    currencyType = currencyType, amount = amount, mode = self.currentMode,
                    from = fromLocation, to = toLocation, guild = isGuildBankMode,
                }, before))
                local okTransfer, transferResult = pcall(TransferCurrency, currencyType, amount, fromLocation, toLocation)
                local postCall = CurrencySnapshot(currencyType, fromLocation, toLocation, "postCall")
                if not okTransfer or transferResult == false then
                    EndCurrencyTransferFlow(flow, "bank currency transfer failed", AddCurrencySnapshotFields({
                        currencyType = currencyType,
                        amount = amount,
                        guild = isGuildBankMode,
                        from = fromLocation,
                        to = toLocation,
                        reason = okTransfer and "transfer_returned_false" or tostring(transferResult),
                    }, before, postCall))
                    TraceBankKeybind("bank.currency_transfer", "end", AddCurrencySnapshotFields({
                        status = "failed", currencyType = currencyType, amount = amount,
                        from = fromLocation, to = toLocation,
                    }, before, postCall))
                    TraceBankCurrencyAction("failed", AddCurrencySnapshotFields({
                        currencyType = currencyType, amount = amount, guild = isGuildBankMode,
                        from = fromLocation, to = toLocation, reason = okTransfer and "transfer_returned_false" or tostring(transferResult),
                    }, before, postCall))
                    return
                end
                if currencySelector and currencySelector.HideSelector then
                    currencySelector.HideSelector(self)
                end
                self:RefreshFooter()
                BETTERUI.Interface.UpdateKeybindGroup(self.coreKeybinds)
                EndCurrencyTransferFlow(flow, "bank currency transfer completed", AddCurrencySnapshotFields({
                    currencyType = currencyType,
                    amount = amount,
                    guild = isGuildBankMode,
                    from = fromLocation,
                    to = toLocation,
                }, before, postCall))
                TraceBankKeybind("bank.currency_transfer", "end", AddCurrencySnapshotFields({
                    status = "requested", currencyType = currencyType, amount = amount,
                    from = fromLocation, to = toLocation,
                }, before, postCall))
                TraceBankCurrencyAction("requested", AddCurrencySnapshotFields({
                    currencyType = currencyType, amount = amount, guild = isGuildBankMode,
                    from = fromLocation, to = toLocation,
                }, before, postCall))
                if BETTERUI.Banking.Tasks and BETTERUI.Banking.Tasks.Schedule then
                    BETTERUI.Banking.Tasks:Schedule("currencyTransferSettled", 100, function()
                        local settled = CurrencySnapshot(currencyType, fromLocation, toLocation, "settled")
                        local refreshedFooter = false
                        local keybindRefresh = "none"
                        local refreshOk = true
                        local refreshError = nil
                        if self.RefreshFooter then
                            local okFooter, footerErr = pcall(function() self:RefreshFooter() end)
                            refreshedFooter = okFooter == true
                            if not okFooter then
                                refreshOk = false
                                refreshError = tostring(footerErr)
                            end
                        end
                        if self.coreKeybinds then
                            local okKeybind, keybindErr = pcall(function()
                                BETTERUI.Interface.UpdateKeybindGroup(self.coreKeybinds)
                            end)
                            if okKeybind then
                                keybindRefresh = "core"
                            else
                                refreshOk = false
                                keybindRefresh = "error"
                                refreshError = refreshError or tostring(keybindErr)
                            end
                        end
                        TraceBankKeybind("bank.currency_transfer", "settled", AddCurrencySnapshotFields({
                            currencyType = currencyType, amount = amount, from = fromLocation,
                            to = toLocation,
                            refreshedFooter = refreshedFooter, refreshedTooltip = false,
                            keybindRefresh = keybindRefresh, refreshOk = refreshOk,
                            refreshError = refreshError,
                        }, before, nil, settled))
                        TraceBankCurrencyAction("completed", AddCurrencySnapshotFields({
                            currencyType = currencyType, amount = amount, guild = isGuildBankMode,
                            from = fromLocation, to = toLocation, refreshedFooter = refreshedFooter,
                            refreshedTooltip = false, keybindRefresh = keybindRefresh,
                            refreshOk = refreshOk, refreshError = refreshError,
                        }, before, nil, settled))
                    end)
                else
                    local settledFallback = { settledFrom = postCall.postCallFrom, settledTo = postCall.postCallTo }
                    TraceBankCurrencyAction("completed", AddCurrencySnapshotFields({
                        currencyType = currencyType, amount = amount, guild = isGuildBankMode,
                        from = fromLocation, to = toLocation, refreshedFooter = true,
                        refreshedTooltip = false, keybindRefresh = "core", refreshOk = true,
                        reason = "noScheduler",
                    }, before, nil, settledFallback))
                end
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
                local currencySelector = GetCurrencySelector()
                local list = self:GetList()
                local selectedData = list and list.selectedData or nil
                local currencyType = selectedData and selectedData.currencyType or nil
                TraceBankKeybind("bank.currency_selector", "requested", { currencyType = currencyType })
                if currencySelector and currencySelector.DisplaySelector and currencyType ~= nil then
                    currencySelector.DisplaySelector(self, currencyType)
                    TraceBankKeybind("bank.currency_selector", "shown", { currencyType = currencyType })
                else
                    TraceBankKeybind("bank.currency_selector", "skipped", {
                        reason = currencyType == nil and "missingCurrencyType" or "missingSelector",
                        hasSelector = currencySelector ~= nil,
                    })
                end
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
    local _, isGuildBankMode = ResolveKeybindTransferContext(self)
    if not (isGuildBankMode and BETTERUI.Banking.IsActionableTransferEntry(selectedData)) then
        return true, nil
    end

    local transferService = BETTERUI.Banking and BETTERUI.Banking.GetTransferService and BETTERUI.Banking.GetTransferService()
    local resolveDecision = transferService and transferService.ResolveGuildBankTransferDecision or nil
    if type(resolveDecision) ~= "function" then
        if BETTERUI.Log and BETTERUI.Log.Warn then
            BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.KEYBIND, "guild transfer resolver missing; treated as allowed")
        end
        return true, nil
    end

    local bagId, slotIndex = BETTERUI.Banking.ResolveListEntrySlot(selectedData)
    local mode = self.currentMode == LIST_WITHDRAW and LIST_WITHDRAW or LIST_DEPOSIT
    local allowed, _, denialText = resolveDecision(mode, bagId, slotIndex)
    return allowed, denialText
end

---@param self BETTERUI.Banking.Class
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
---@param self BETTERUI.Banking.Class
---@return nil
function BETTERUI.Banking.Class:UpdateActions()
    local function DescribeTarget(targetData)
        local rawData = targetData and (targetData.dataSource or targetData.data or targetData) or nil
        if not rawData then return nil end
        return {
            bagId = rawData.bagId,
            slotIndex = rawData.slotIndex,
            uniqueId = rawData.uniqueId and tostring(rawData.uniqueId) or nil,
            name = rawData.name,
            currencyType = rawData.currencyType,
        }
    end

    -- Skip itemActions updates when in header sort mode to prevent keybind flicker
    -- itemActions:SetInventorySlot directly manipulates KEYBIND_STRIP, bypassing guards
    if self.isInHeaderSortMode then
        TraceBankKeybind("bank.item_actions", "skipped", {
            reason = "headerSortMode",
            mode = self.currentMode,
        })
        return
    end

    if not self.itemActions then
        TraceBankKeybind("bank.item_actions", "skipped", {
            reason = "missingItemActions",
            mode = self.currentMode,
        })
        return
    end

    local list = self:GetList()
    local targetData = list and list.selectedData or nil
    if not targetData then
        self.itemActions:SetInventorySlot(nil)
        TraceBankKeybind("bank.item_actions", "cleared", {
            reason = "noSelection",
            mode = self.currentMode,
        })
        return
    end

    -- Set itemActions only for actionable inventory items.
    -- Faux rows (currency/header/empty labels) can crash ESO slot action discovery.
    if not BETTERUI.Banking.IsActionableTransferEntry(targetData) then
        self.itemActions:SetInventorySlot(nil)
        TraceBankKeybind("bank.item_actions", "cleared", {
            reason = "nonActionableSelection",
            mode = self.currentMode,
            target = DescribeTarget(targetData),
        })
    else
        self.itemActions:SetInventorySlot(targetData)
        TraceBankKeybind("bank.item_actions", "set", {
            mode = self.currentMode,
            target = DescribeTarget(targetData),
        })
    end
end

function BETTERUI.Banking.Class:AddKeybinds()
    if BETTERUI.CIM.SceneLifecycle
        and not BETTERUI.CIM.SceneLifecycle.IsOwnerShowing(self) then
        local purge = BETTERUI.Interface.RemoveKeybindGroupFromAllStates
        if type(purge) == "function" then
            purge(self.textSearchKeybindStripDescriptor)
            purge(self.withdrawDepositKeybinds)
            purge(self.coreKeybinds)
        end
        return false
    end
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "add keybinds")
    end
    TraceBankKeybind("bank.keybind_groups.keybind_add", "begin", {
        mode = self.currentMode,
        core = BETTERUI.Log and BETTERUI.Log.DescribeKeybindDescriptors and BETTERUI.Log.DescribeKeybindDescriptors(self.coreKeybinds, "core") or nil,
        transfer = BETTERUI.Log and BETTERUI.Log.DescribeKeybindDescriptors and BETTERUI.Log.DescribeKeybindDescriptors(self.withdrawDepositKeybinds, "transfer") or nil,
        search = BETTERUI.Log and BETTERUI.Log.DescribeKeybindDescriptors and BETTERUI.Log.DescribeKeybindDescriptors(self.textSearchKeybindStripDescriptor, "search") or nil,
    })
    if self.textSearchKeybindStripDescriptor then
        BETTERUI.Interface.RemoveKeybindGroupIfPresent(self.textSearchKeybindStripDescriptor)
    end
    BETTERUI.Interface.RemoveKeybindGroupIfPresent(self.withdrawDepositKeybinds)
    BETTERUI.Interface.RemoveKeybindGroupIfPresent(self.coreKeybinds)
    BETTERUI.Interface.EnsureKeybindGroupAdded(self.withdrawDepositKeybinds)
    BETTERUI.Interface.EnsureKeybindGroupAdded(self.coreKeybinds)
    self:UpdateActions()
    self:EnsureHeaderKeybindsActive()
    TraceBankKeybind("bank.keybind_groups.keybind_add", "end", {
        mode = self.currentMode,
        core = BETTERUI.Log and BETTERUI.Log.DescribeKeybindDescriptors and BETTERUI.Log.DescribeKeybindDescriptors(self.coreKeybinds, "core") or nil,
        transfer = BETTERUI.Log and BETTERUI.Log.DescribeKeybindDescriptors and BETTERUI.Log.DescribeKeybindDescriptors(self.withdrawDepositKeybinds, "transfer") or nil,
    })
    LogBankKeybindState("bank keybind groups refreshed", {
        core = self.coreKeybinds ~= nil,
        transfer = self.withdrawDepositKeybinds ~= nil,
        search = self.textSearchKeybindStripDescriptor ~= nil,
        mode = self.currentMode,
    })
end

function BETTERUI.Banking.Class:RemoveKeybinds()
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, "remove keybinds")
    end
    TraceBankKeybind("bank.keybind_groups.keybind_remove", "begin", {
        mode = self.currentMode,
        core = BETTERUI.Log and BETTERUI.Log.DescribeKeybindDescriptors and BETTERUI.Log.DescribeKeybindDescriptors(self.coreKeybinds, "core") or nil,
        transfer = BETTERUI.Log and BETTERUI.Log.DescribeKeybindDescriptors and BETTERUI.Log.DescribeKeybindDescriptors(self.withdrawDepositKeybinds, "transfer") or nil,
    })
    BETTERUI.Interface.RemoveKeybindGroupIfPresent(self.withdrawDepositKeybinds)
    BETTERUI.Interface.RemoveKeybindGroupIfPresent(self.coreKeybinds)
    TraceBankKeybind("bank.keybind_groups.keybind_remove", "end", {
        mode = self.currentMode,
        core = BETTERUI.Log and BETTERUI.Log.DescribeKeybindDescriptors and BETTERUI.Log.DescribeKeybindDescriptors(self.coreKeybinds, "core") or nil,
        transfer = BETTERUI.Log and BETTERUI.Log.DescribeKeybindDescriptors and BETTERUI.Log.DescribeKeybindDescriptors(self.withdrawDepositKeybinds, "transfer") or nil,
    })
    LogBankKeybindState("bank keybind groups removed", {
        core = self.coreKeybinds ~= nil,
        transfer = self.withdrawDepositKeybinds ~= nil,
        mode = self.currentMode,
    })
end

---@param self BETTERUI.Banking.Class
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
        function()
            local currencySelector = GetCurrencySelector()
            if currencySelector and currencySelector.HideSelector then
                currencySelector.HideSelector(self)
            end
        end)

    local leftTrigger, rightTrigger = self:CreateListTriggerKeybindDescriptors(function() return self.list end)
    table.insert(self.coreKeybinds, leftTrigger)
    table.insert(self.coreKeybinds, rightTrigger)
    WrapBankingKeybindGroup(self.coreKeybinds)
    WrapBankingKeybindGroup(self.withdrawDepositKeybinds)
    WrapBankingKeybindGroup(self.currencySelectorKeybinds)
    WrapBankingKeybindGroup(self.currencyKeybinds)
end

--- Triggers the selection callback to update keybinds for the current selection.
---@param self BETTERUI.Banking.Class
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
