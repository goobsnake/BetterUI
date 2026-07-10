--[[
File: tools/tests/test_banking_keybinds.lua
Purpose: Covers banking keybind descriptors and selection refresh behavior.

Usage:
  lua tools/tests/test_banking_keybinds.lua
]]

if false then
    dofile("Modules/Banking/Keybinds/KeybindManager.lua")
end

BAG_BACKPACK = 1
BAG_BANK = 2
BAG_GUILDBANK = 3
BAG_SUBSCRIBER_BANK = 6
CURT_MONEY = 10
CURRENCY_LOCATION_CHARACTER = 1
CURRENCY_LOCATION_BANK = 2
CURRENCY_LOCATION_GUILD_BANK = 3
KEYBIND_STRIP_ALIGN_LEFT = "left"
GAME_NAVIGATION_TYPE_BUTTON = "button"

SI_BETTERUI_BANKING_TOGGLE_LIST = "SI_BETTERUI_BANKING_TOGGLE_LIST"
SI_TRADING_HOUSE_GUILD_LABEL = "SI_TRADING_HOUSE_GUILD_LABEL"
SI_BANK_UPGRADE_TEXT = "SI_BANK_UPGRADE_TEXT"
SI_BUY_BANK_SPACE_CANNOT_AFFORD = "SI_BUY_BANK_SPACE_CANNOT_AFFORD"
SI_BETTERUI_ABORT_ACTION = "SI_BETTERUI_ABORT_ACTION"
SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND = "SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND"
SI_ITEM_ACTION_STACK_ALL = "SI_ITEM_ACTION_STACK_ALL"
SI_BETTERUI_MULTI_SELECT = "SI_BETTERUI_MULTI_SELECT"
SI_BETTERUI_DESELECT_ITEM = "SI_BETTERUI_DESELECT_ITEM"
SI_BETTERUI_SELECT_WITH_COUNT = "SI_BETTERUI_SELECT_WITH_COUNT (%d)"
SI_BETTERUI_BANKING_WITHDRAW = "SI_BETTERUI_BANKING_WITHDRAW"
SI_BETTERUI_BANKING_DEPOSIT = "SI_BETTERUI_BANKING_DEPOSIT"
SI_BETTERUI_CONFIRM_AMOUNT = "SI_BETTERUI_CONFIRM_AMOUNT"
SI_GAMEPAD_GUILD_BANK_NO_PERMISSION = "SI_GAMEPAD_GUILD_BANK_NO_PERMISSION"

local testsPassed = 0
local testsFailed = 0

local stringValues = {
    [SI_BETTERUI_BANKING_TOGGLE_LIST] = "Toggle List",
    [SI_TRADING_HOUSE_GUILD_LABEL] = "Select Guild",
    [SI_BANK_UPGRADE_TEXT] = "Upgrade %s %s",
    [SI_BUY_BANK_SPACE_CANNOT_AFFORD] = "Cannot afford",
    [SI_BETTERUI_ABORT_ACTION] = "Abort",
    [SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND] = "Actions",
    [SI_ITEM_ACTION_STACK_ALL] = "Stack All",
    [SI_BETTERUI_MULTI_SELECT] = "Multi Select",
    [SI_BETTERUI_DESELECT_ITEM] = "Deselect",
    [SI_BETTERUI_SELECT_WITH_COUNT] = "Select (%d)",
    [SI_BETTERUI_BANKING_WITHDRAW] = "Withdraw",
    [SI_BETTERUI_BANKING_DEPOSIT] = "Deposit",
    [SI_BETTERUI_CONFIRM_AMOUNT] = "Confirm Amount",
    [SI_GAMEPAD_GUILD_BANK_NO_PERMISSION] = "No guild permission",
}

local slotStacks = {}
local addedGroups = {}
local removedGroups = {}
local updatedGroups = {}
local dialogsShown = {}
local displayedUpgrades = 0
local userAlerts = {}
local stackCalls = {}
local transferCalls = {}
local withdrawCurrencyCalls = {}
local depositCurrencyCalls = {}
local logEvents = {}
local depositPolicyCalls = {}
local transferCurrencyShouldFail = false
local logPrivacyMode = false

local guildBankMode = false
local guildBankLoading = false
local currentBank = BAG_BANK
local nextBankUpgradePrice = 1000
local carriedCurrency = 5000
local currencyAmounts = {}
local guildCount = 2
local batchProcessing = false
local guildTransferAllowed = true
local guildTransferDenialText = nil
local depositAllowed = true
local depositDenialReason = nil

local function assertTrue(condition, message)
    if condition then
        testsPassed = testsPassed + 1
    else
        testsFailed = testsFailed + 1
        print("  [FAILED] " .. message)
    end
end

local function assertEqual(expected, actual, message)
    assertTrue(expected == actual, string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)))
end

local function assertTableSequence(expected, actual, message)
    local ok = #expected == #actual
    if ok then
        for i = 1, #expected do
            if expected[i] ~= actual[i] then
                ok = false
                break
            end
        end
    end
    assertTrue(ok, message)
end

local function resetGlobals()
    slotStacks = {}
    addedGroups = {}
    removedGroups = {}
    updatedGroups = {}
    dialogsShown = {}
    displayedUpgrades = 0
    userAlerts = {}
    stackCalls = {}
    transferCalls = {}
    withdrawCurrencyCalls = {}
    depositCurrencyCalls = {}
    logEvents = {}
    depositPolicyCalls = {}
    transferCurrencyShouldFail = false
    logPrivacyMode = false
    guildBankMode = false
    guildBankLoading = false
    currentBank = BAG_BANK
    nextBankUpgradePrice = 1000
    carriedCurrency = 5000
    currencyAmounts = {
        [CURRENCY_LOCATION_CHARACTER] = 1000,
        [CURRENCY_LOCATION_BANK] = 2000,
        [CURRENCY_LOCATION_GUILD_BANK] = 3000,
    }
    guildCount = 2
    batchProcessing = false
    guildTransferAllowed = true
    guildTransferDenialText = nil
    depositAllowed = true
    depositDenialReason = nil
end

function GetString(id)
    return stringValues[id] or tostring(id)
end

function zo_strformat(template, value)
    return string.format(template, value)
end

ZO_ERROR_COLOR = {
    Colorize = function(_, text)
        return "[error]" .. text
    end,
}

function ZO_CurrencyControl_FormatCurrency(value)
    return tostring(value)
end

ZO_GAMEPAD_GOLD_ICON_FORMAT_24 = "gold_icon"

function GetNextBankUpgradePrice()
    return nextBankUpgradePrice
end

function GetCarriedCurrencyAmount()
    return carriedCurrency
end

function IsBankUpgradeAvailable()
    return nextBankUpgradePrice ~= nil and nextBankUpgradePrice > 0
end

function GetNumGuilds()
    return guildCount
end

function DisplayBankUpgrade()
    displayedUpgrades = displayedUpgrades + 1
end

function ZO_Dialogs_ShowGamepadDialog(name)
    table.insert(dialogsShown, name)
end

function StackBag(bagId)
    table.insert(stackCalls, bagId)
end

function TransferCurrency(currencyType, amount, fromLocation, toLocation)
    table.insert(transferCalls, {
        currencyType = currencyType,
        amount = amount,
        fromLocation = fromLocation,
        toLocation = toLocation,
    })
    if transferCurrencyShouldFail then
        return false
    end
    currencyAmounts[fromLocation] = (currencyAmounts[fromLocation] or 0) - amount
    currencyAmounts[toLocation] = (currencyAmounts[toLocation] or 0) + amount
end

function WithdrawCurrencyFromBank(currencyType, amount)
    table.insert(withdrawCurrencyCalls, { currencyType = currencyType, amount = amount })
end

function DepositCurrencyIntoBank(currencyType, amount)
    table.insert(depositCurrencyCalls, { currencyType = currencyType, amount = amount })
end

function GetSlotStackSize(bagId, slotIndex)
    return slotStacks[bagId .. ":" .. slotIndex] or 0
end

function GetBankingBag()
    return currentBank
end

KEYBIND_STRIP = {
    AddKeybindButtonGroup = function(_, group)
        table.insert(addedGroups, group)
    end,
    RemoveKeybindButtonGroup = function(_, group)
        table.insert(removedGroups, group)
    end,
    UpdateKeybindButtonGroup = function(_, group)
        table.insert(updatedGroups, group)
    end,
}

ZO_GamepadBanking = {
    IsEntryDataCurrencyRelated = function(entryData)
        return entryData and entryData.isCurrency == true
    end,
}

ZO_Gamepad_AddBackNavigationKeybindDescriptors = function(keybinds, _, callback)
    table.insert(keybinds, {
        keybind = "UI_BACK",
        callback = callback,
    })
end

BETTERUI = {
    Interface = {
        EnsureKeybindGroupAdded = function(group)
            KEYBIND_STRIP:AddKeybindButtonGroup(group)
            return true
        end,
        RemoveKeybindGroupIfPresent = function(group)
            KEYBIND_STRIP:RemoveKeybindButtonGroup(group)
            return true
        end,
        UpdateKeybindGroup = function(group)
            KEYBIND_STRIP:UpdateKeybindButtonGroup(group)
            return true
        end,
    },
    Banking = {
        LIST_WITHDRAW = 1,
        LIST_DEPOSIT = 2,
        TRANSFER_MODE_MAIN_BANK = "main-bank",
        TRANSFER_MODE_HOUSE_BANK = "house-bank",
        TRANSFER_MODE_GUILD_BANK = "guild-bank",
        RuntimeState = {
            currentUsedBank = BAG_BANK,
            lastUsedBank = BAG_BANK,
        },
        GetTransferContext = function()
            local sourceBag = (currentBank == nil or currentBank == 0) and BAG_BANK or currentBank
            local targetBag = sourceBag == BAG_GUILDBANK and BAG_GUILDBANK or currentBank
            local kind = BETTERUI.Banking.TRANSFER_MODE_MAIN_BANK
            if guildBankMode then
                kind = BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK
            elseif sourceBag ~= BAG_BANK then
                kind = BETTERUI.Banking.TRANSFER_MODE_HOUSE_BANK
            end
            return {
                kind = kind,
                interactionBag = sourceBag,
                depositTargetBag = targetBag,
                withdrawSourceBags = targetBag == BAG_BANK and { BAG_BANK, BAG_SUBSCRIBER_BANK } or { targetBag },
                sourceIsFurnitureVault = false,
                targetIsFurnitureVault = false,
            }
        end,
        GetTransferState = function()
            return BETTERUI.Banking.GetTransferContext()
        end,
        ReadTransferContextSnapshot = function()
            return BETTERUI.Banking.GetTransferContext()
        end,
        ResolveListEntrySlot = function(entryData)
            local rawData = entryData and (entryData.dataSource or entryData) or nil
            if not rawData then return nil, nil, nil end
            local bagId = rawData.bagId
            local slotIndex = rawData.slotIndex
            if bagId == nil or slotIndex == nil then return nil, nil, rawData end
            return bagId, slotIndex, rawData
        end,
        IsActionableTransferEntry = function(entryData)
            if not entryData then return false end
            if ZO_GamepadBanking and ZO_GamepadBanking.IsEntryDataCurrencyRelated
                and ZO_GamepadBanking.IsEntryDataCurrencyRelated(entryData) then
                return false
            end
            local rawData = entryData.dataSource or entryData
            local bagId = rawData and rawData.bagId or nil
            local slotIndex = rawData and rawData.slotIndex or nil
            if bagId == nil or slotIndex == nil then return false end
            local stackCount = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or 0
            return stackCount > 0
        end,
        GetTransferService = function()
            return BETTERUI.Banking.Transfer
        end,
        GetSetting = function(key)
            local values = {
                triggerSpeed = 25,
                useTriggersForSkip = true,
            }
            return values[key]
        end,
        GuildBank = {
            IsGuildBankMode = function()
                return guildBankMode
            end,
            IsLoading = function()
                return guildBankLoading
            end,
        },
        Transfer = {
            CanDepositIntoBank = function(bagId, slotIndex, targetBag)
                depositPolicyCalls[#depositPolicyCalls + 1] = {
                    bagId = bagId,
                    slotIndex = slotIndex,
                    targetBag = targetBag,
                }
                return depositAllowed, depositDenialReason
            end,
            ResolveGuildBankTransferDecision = function()
                return guildTransferAllowed, guildTransferDenialText and "denied" or nil, guildTransferDenialText, nil
            end,
        },
        IsGuildBankTransfer = function()
            return BETTERUI.Banking.GetTransferContext().kind == BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK
        end,
        IsMainBankTransfer = function()
            return BETTERUI.Banking.GetTransferContext().kind == BETTERUI.Banking.TRANSFER_MODE_MAIN_BANK
        end,
        IsHouseBankTransfer = function()
            return BETTERUI.Banking.GetTransferContext().kind == BETTERUI.Banking.TRANSFER_MODE_HOUSE_BANK
        end,
        GetActiveInteractionBag = function()
            return BETTERUI.Banking.GetTransferContext().interactionBag
        end,
        GetActiveDepositBag = function()
            return BETTERUI.Banking.GetTransferContext().depositTargetBag
        end,
        GetWithdrawSourceBags = function()
            return BETTERUI.Banking.GetTransferContext().withdrawSourceBags
        end,
        IsGuildTransferActive = function()
            return BETTERUI.Banking.GetTransferContext().kind == BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK
        end,
        IsMainBankInteraction = function()
            return BETTERUI.Banking.GetTransferContext().kind == BETTERUI.Banking.TRANSFER_MODE_MAIN_BANK
        end,
        IsHouseBankInteraction = function()
            return BETTERUI.Banking.GetTransferContext().kind == BETTERUI.Banking.TRANSFER_MODE_HOUSE_BANK
        end,
        IsFurnitureVaultInteraction = function()
            return false
        end,
        IsFurnitureVaultDepositTarget = function()
            return false
        end,
        CurrencySelector = {
            HideSelector = function(self)
                self.hiddenSelectorCount = self.hiddenSelectorCount + 1
            end,
            DisplaySelector = function(self, currencyType)
                self.displayedCurrencyType = currencyType
            end,
        },
        Class = {},
    },
    CIM = {
        Keybinds = {
            CreateListTriggerKeybinds = function(contract)
                return {
                    keybind = "LEFT_TRIGGER",
                    speed = contract.getSpeed(),
                    enabled = contract.isEnabled(),
                }, {
                    keybind = "RIGHT_TRIGGER",
                    speed = contract.getSpeed(),
                    enabled = contract.isEnabled(),
                }
            end,
            CreateClearSearchKeybind = function(callback, visible, enabled)
                return {
                    keybind = "CLEAR_SEARCH",
                    callback = callback,
                    visible = visible,
                    enabled = enabled,
                }
            end,
            GetMultiSelectLabel = function()
                return GetString(SI_BETTERUI_MULTI_SELECT)
            end,
            GetMultiSelectToggleLabel = function(manager, target)
                if target and manager:IsSelected(target) then
                    return GetString(SI_BETTERUI_DESELECT_ITEM)
                end
                return zo_strformat(GetString(SI_BETTERUI_SELECT_WITH_COUNT), manager:GetSelectedCount())
            end,
        },
        UserAlertText = function(_, message)
            table.insert(userAlerts, message)
        end,
    },
    Log = {
        CATEGORY = { ACTION = "ACTION", TRANSFER = "TRANSFER", STATE = "STATE", KEYBIND = "KEYBIND" },
        IsActive = function() return true end,
        FlowBegin = function(kind, category, message, data)
            local flow = "flow-" .. tostring(#logEvents + 1)
            table.insert(logEvents, { kind = kind, category = category, message = message, data = data, flow = flow })
            return flow
        end,
        FlowEnd = function(flow, category, message, data)
            table.insert(logEvents, { flow = flow, category = category, message = message, data = data })
        end,
        Debug = function(category, message, data)
            table.insert(logEvents, { category = category, message = message, data = data })
        end,
        Info = function(category, message, data)
            table.insert(logEvents, { category = category, message = message, data = data })
        end,
        Trace = function(category, message, data)
            table.insert(logEvents, { category = category, message = message, data = data })
        end,
        TraceEvent = function(category, event, phase, data)
            table.insert(logEvents, { category = category, event = event, phase = phase, data = data })
        end,
        GetPrivacyMode = function()
            return logPrivacyMode
        end,
        GetCurrencyAmountForLocation = function(_, location)
            return currencyAmounts[location]
        end,
        Warn = function(category, message, data)
            table.insert(logEvents, { category = category, message = message, data = data })
        end,
    },
    GetModuleEnabled = function(moduleName)
        return moduleName == "Banking"
    end,
}

dofile("Modules/Banking/Keybinds/KeybindManager.lua")

local function createList(selectedData, selectedControl)
    return {
        selectedData = selectedData,
        selectedControl = selectedControl,
        empty = false,
        GetSelectedData = function(self)
            return self.selectedData
        end,
        GetSelectedControl = function(self)
            return self.selectedControl
        end,
        IsEmpty = function(self)
            return self.empty
        end,
    }
end

local function createWindow()
    local window = {
        currentMode = BETTERUI.Banking.LIST_WITHDRAW,
        list = createList(nil, "control"),
        textSearchHeaderControl = { IsHidden = function() return true end },
        itemActions = {
            slots = {},
            SetInventorySlot = function(self, slot)
                table.insert(self.slots, slot)
            end,
        },
        selector = {
            value = 0,
            SetMaxValue = function(self, value) self.maxValue = value end,
            SetClampValues = function(self, min, max) self.clamp = { min, max } end,
            GetValue = function(self) return self.value end,
            Activate = function(self) self.activated = true end,
            Deactivate = function(self) self.deactivated = true end,
            control = {
                GetParent = function()
                    return {
                        SetHidden = function(_, hidden)
                            window.selectorHidden = hidden
                        end,
                    }
                end,
            },
        },
        selectorCurrency = {
            SetTexture = function(_, texture)
                window.selectorTexture = texture
            end,
        },
        currencySelectorKeybinds = nil,
        movedItems = {},
        shownQuantityDialogs = {},
        toggledSelections = {},
        savedPositions = 0,
        showActionsCount = 0,
        batchAbortCount = 0,
        enterSelectionModeCount = 0,
        exitSelectionModeCount = 0,
        hiddenSelectorCount = 0,
        refreshedFooterCount = 0,
        cancelWithdrawDepositCount = 0,
        selectedDataCallbackArgs = nil,
        mainKeybindStripDescriptor = "main-group",
        GetList = function(self)
            return self.list
        end,
        IsBatchProcessing = function()
            return batchProcessing
        end,
        ToggleList = function(self, deposit)
            self.toggledToDeposit = deposit
        end,
        EnsureHeaderKeybindsActive = function(self)
            self.headerKeybindsEnsured = (self.headerKeybindsEnsured or 0) + 1
        end,
        SaveListPosition = function(self)
            self.savedPositions = self.savedPositions + 1
        end,
        ShowActions = function(self)
            self.showActionsCount = self.showActionsCount + 1
        end,
        ShowBatchActionsMenu = function(self)
            self.showBatchActionsMenuCount = (self.showBatchActionsMenuCount or 0) + 1
        end,
        RequestBatchAbort = function(self)
            self.batchAbortCount = self.batchAbortCount + 1
        end,
        MoveItem = function(self, _, amount)
            table.insert(self.movedItems, amount)
        end,
        RefreshList = function(self)
            self.refreshListCount = (self.refreshListCount or 0) + 1
        end,
        ShowQuantityDialog = function(self, isDeposit)
            table.insert(self.shownQuantityDialogs, isDeposit)
        end,
        EnterSelectionMode = function(self)
            self.enterSelectionModeCount = self.enterSelectionModeCount + 1
        end,
        ExitSelectionMode = function(self)
            self.exitSelectionModeCount = self.exitSelectionModeCount + 1
        end,
        IsInSelectionMode = function()
            return false
        end,
        RefreshFooter = function(self)
            self.refreshedFooterCount = self.refreshedFooterCount + 1
        end,
        CancelWithdrawDeposit = function(self)
            self.cancelWithdrawDepositCount = self.cancelWithdrawDepositCount + 1
        end,
    }

    window.multiSelectManager = {
        active = false,
        hasSelections = false,
        selectedCount = 0,
        selected = false,
        IsActive = function(self) return self.active end,
        HasSelections = function(self) return self.hasSelections end,
        GetSelectedCount = function(self) return self.selectedCount end,
        IsSelected = function(self) return self.selected end,
        ToggleSelection = function(self, target)
            table.insert(window.toggledSelections, target)
        end,
    }

    return setmetatable(window, { __index = BETTERUI.Banking.Class })
end

local function findDescriptor(descriptors, keybind)
    for _, descriptor in ipairs(descriptors) do
        if descriptor.keybind == keybind then
            return descriptor
        end
    end
    return nil
end

local function hasTraceEvent(event, phase, reason)
    for _, entry in ipairs(logEvents) do
        if entry.event == event and entry.phase == phase then
            if reason == nil or (entry.data and entry.data.reason == reason) then
                return true
            end
        end
    end
    return false
end

local function findTraceEvent(event, phase, reason)
    for _, entry in ipairs(logEvents) do
        if entry.event == event and entry.phase == phase then
            if reason == nil or (entry.data and entry.data.reason == reason) then
                return entry
            end
        end
    end
    return nil
end

local function hasLogMessage(message)
    for _, entry in ipairs(logEvents) do
        if entry.message == message then
            return true
        end
    end
    return false
end

print("\n=== Banking keybind behavior ===\n")

resetGlobals()
local window = createWindow()
window.list.selectedData = { bagId = BAG_BANK, slotIndex = 7 }
slotStacks["2:7"] = 3
window:UpdateActions()
assertEqual(window.list.selectedData, window.itemActions.slots[1], "UpdateActions forwards actionable entries to item actions")

window = createWindow()
window.isInHeaderSortMode = true
window.list.selectedData = { bagId = BAG_BANK, slotIndex = 7 }
slotStacks["2:7"] = 3
window:UpdateActions()
assertEqual(0, #window.itemActions.slots, "UpdateActions skips changes in header sort mode")

window = createWindow()
window.list.selectedData = { isCurrency = true, bagId = BAG_BANK, slotIndex = 7 }
window:UpdateActions()
assertEqual(nil, window.itemActions.slots[1], "UpdateActions clears item actions for currency rows")

window = createWindow()
window.list.selectedData = { bagId = BAG_BANK, slotIndex = 9 }
slotStacks["2:9"] = 0
window:UpdateActions()
assertEqual(nil, window.itemActions.slots[1], "UpdateActions clears item actions for empty slots")

resetGlobals()
window = createWindow()
window.textSearchKeybindStripDescriptor = "search-group"
window.withdrawDepositKeybinds = { "withdraw" }
window.coreKeybinds = { "core" }
window:AddKeybinds()
assertEqual("search-group", removedGroups[1], "AddKeybinds removes the search keybind group first")
assertEqual(window.withdrawDepositKeybinds, addedGroups[1], "AddKeybinds adds withdraw/deposit keybinds")
assertEqual(window.coreKeybinds, addedGroups[2], "AddKeybinds adds core keybinds")
assertEqual(1, window.headerKeybindsEnsured, "AddKeybinds re-evaluates header keybind activation")
assertTrue(hasTraceEvent("bank.keybind_groups.keybind_add", "begin"),
    "AddKeybinds traces keybind_add begin")
assertTrue(hasTraceEvent("bank.keybind_groups.keybind_add", "end"),
    "AddKeybinds traces keybind_add end")

removedGroups = {}
window:RemoveKeybinds()
assertEqual(window.withdrawDepositKeybinds, removedGroups[1], "RemoveKeybinds removes withdraw/deposit keybinds")
assertEqual(window.coreKeybinds, removedGroups[2], "RemoveKeybinds removes core keybinds")
assertTrue(hasTraceEvent("bank.keybind_groups.keybind_remove", "begin"),
    "RemoveKeybinds traces keybind_remove begin")
assertTrue(hasTraceEvent("bank.keybind_groups.keybind_remove", "end"),
    "RemoveKeybinds traces keybind_remove end")

resetGlobals()
window = createWindow()
window.list.selectedData = { bagId = BAG_BANK, slotIndex = 1, stackCount = 4 }
slotStacks["2:1"] = 4
window:InitializeKeybind()

local rightStick = findDescriptor(window.coreKeybinds, "UI_SHORTCUT_RIGHT_STICK")
local tertiary = findDescriptor(window.coreKeybinds, "UI_SHORTCUT_TERTIARY")
local leftStick = findDescriptor(window.coreKeybinds, "UI_SHORTCUT_LEFT_STICK")
local primary = findDescriptor(window.withdrawDepositKeybinds, "UI_SHORTCUT_PRIMARY")
local currencySelectorPrimary = findDescriptor(window.currencySelectorKeybinds, "UI_SHORTCUT_PRIMARY")
local currencyPrimary = findDescriptor(window.currencyKeybinds, "UI_SHORTCUT_PRIMARY")

assertTrue(rightStick ~= nil, "InitializeKeybind creates the right-stick descriptor")
assertTrue(tertiary ~= nil, "InitializeKeybind creates the actions descriptor")
assertTrue(leftStick ~= nil, "InitializeKeybind creates the stack-all descriptor")
assertTrue(primary ~= nil, "InitializeKeybind creates the primary transfer descriptor")
assertTrue(currencySelectorPrimary ~= nil, "InitializeKeybind creates the currency selector confirm descriptor")
assertTrue(currencyPrimary ~= nil, "InitializeKeybind creates the currency row descriptor")

guildBankMode = true
guildBankLoading = false
assertEqual("Select Guild", rightStick.name(), "Right-stick label switches to guild selector in guild mode")
assertTrue(rightStick.visible(), "Guild selector is visible when multiple guilds exist")
assertTrue(rightStick.enabled(), "Guild selector is enabled when guild bank is ready")
rightStick.callback()
assertEqual("BETTERUI_GUILD_BANK_CHANGE_ACTIVE_GUILD", dialogsShown[1], "Guild selector callback opens the guild bank dialog")

guildBankLoading = true
assertTrue(not rightStick.enabled(), "Guild selector is disabled while guild bank is loading")

guildBankMode = false
guildBankLoading = false
currentBank = BAG_BANK
carriedCurrency = 2000
rightStick.callback()
assertEqual(1, displayedUpgrades, "Personal bank right-stick buys an upgrade when affordable")

carriedCurrency = 100
rightStick.callback()
assertEqual("Cannot afford", userAlerts[1], "Personal bank right-stick alerts when upgrade is unaffordable")

currentBank = 99
assertTrue(not rightStick.visible(), "Bank upgrade keybind hides outside the main bank")
assertTrue(not rightStick.enabled(), "Bank upgrade keybind disables outside the main bank")

guildBankMode = true
currentBank = BAG_GUILDBANK
guildTransferAllowed = false
guildTransferDenialText = "No guild permission"
window.list.selectedData = { bagId = BAG_BACKPACK, slotIndex = 1, stackCount = 1 }
slotStacks["1:1"] = 1
assertEqual("No guild permission", primary.name(), "Primary transfer keybind reuses the shared denial text in guild-bank mode")
assertTrue(not primary.enabled(), "Primary transfer keybind disables when the shared guild-bank gate denies transfer")

guildBankMode = false
guildTransferAllowed = true
guildTransferDenialText = nil
currentBank = BAG_BANK
window.currentMode = BETTERUI.Banking.LIST_DEPOSIT
window.multiSelectManager.active = false
window.list.selectedData = { bagId = BAG_BACKPACK, slotIndex = 8, stackCount = 1 }
slotStacks["1:8"] = 1
depositAllowed = false
depositDenialReason = "bop_backpack"
logEvents = {}
assertTrue(not primary.enabled(), "Primary deposit keybind disables when the transfer policy denies the item")
assertEqual(1, #depositPolicyCalls, "Primary deposit policy receives exactly one visibility check")
assertEqual(BAG_BACKPACK, depositPolicyCalls[1].bagId, "Primary deposit policy receives the selected bag")
assertEqual(8, depositPolicyCalls[1].slotIndex, "Primary deposit policy receives the selected slot")
assertEqual(BAG_BANK, depositPolicyCalls[1].targetBag, "Primary deposit policy receives the active deposit bag")
local movedBeforeDeniedDeposit = #window.movedItems
primary.callback()
assertEqual(movedBeforeDeniedDeposit, #window.movedItems, "Primary deposit callback does not move policy-denied items")
local policyTrace = findTraceEvent("bank.primary_transfer", "blocked", "transferPolicy")
assertTrue(policyTrace ~= nil,
    "Primary deposit policy denial emits a keybind trace")
assertEqual(BAG_BACKPACK, policyTrace and policyTrace.data and policyTrace.data.bagId,
    "Primary deposit policy trace includes selected bag")
assertEqual(8, policyTrace and policyTrace.data and policyTrace.data.slotIndex,
    "Primary deposit policy trace includes selected slot")
assertEqual(BAG_BANK, policyTrace and policyTrace.data and policyTrace.data.targetBag,
    "Primary deposit policy trace includes target bag")
depositAllowed = true
depositDenialReason = nil
assertTrue(primary.enabled(), "Primary deposit keybind re-enables when transfer policy allows the item")

window.list.selectedData = { bagId = BAG_BACKPACK, stackCount = 1 }
slotStacks["1:8"] = nil
logEvents = {}
depositPolicyCalls = {}
assertTrue(not primary.enabled(), "Primary deposit keybind disables when the selected item has no slot")
assertEqual(0, #depositPolicyCalls, "Primary deposit policy is not called for missing-slot selections")
assertTrue(hasTraceEvent("bank.primary_transfer", "blocked", "invalidSelection"),
    "Primary deposit missing-slot selection emits an invalid-selection trace")

window.multiSelectManager.active = false
window.list.selectedData = { bagId = BAG_BANK, slotIndex = 1, stackCount = 4 }
slotStacks["2:1"] = 4
assertTrue(tertiary.visible(), "Actions keybind is visible for actionable selections")
tertiary.callback()
assertEqual(1, window.showActionsCount, "Actions keybind opens the action menu")

window.multiSelectManager.active = true
window.multiSelectManager.hasSelections = true
tertiary.callback()
assertEqual(1, window.showBatchActionsMenuCount, "Actions keybind opens batch actions in multi-select mode")

batchProcessing = true
tertiary.callback()
assertEqual(1, window.batchAbortCount, "Actions keybind aborts active batch work")
batchProcessing = false

currentBank = BAG_BANK
window.currentMode = BETTERUI.Banking.LIST_WITHDRAW
leftStick.callback()
assertTableSequence({ BAG_BANK, BAG_SUBSCRIBER_BANK }, stackCalls, "Stack-all withdraw stacks both personal bank bags")

stackCalls = {}
window.currentMode = BETTERUI.Banking.LIST_DEPOSIT
leftStick.callback()
assertTableSequence({ BAG_BACKPACK }, stackCalls, "Stack-all deposit stacks the backpack")

-- Quantity-dialog behavior below covers the personal bank; leave guild mode.
guildBankMode = false
window.currentMode = BETTERUI.Banking.LIST_WITHDRAW
window.multiSelectManager.active = true
window.list.selectedData = { bagId = BAG_BANK, slotIndex = 1 }
primary.callback()
assertEqual(window.list.selectedData, window.toggledSelections[1], "Primary keybind toggles multi-select entries")

window.multiSelectManager.active = false
window.list.selectedData = { bagId = BAG_BANK, slotIndex = 1, stackCount = 4 }
primary.callback()
assertEqual(false, window.shownQuantityDialogs[1], "Primary keybind opens withdraw quantity dialog for stacks")

window.currentMode = BETTERUI.Banking.LIST_DEPOSIT
window.list.selectedData = { bagId = BAG_BANK, slotIndex = 1, stackCount = 1 }
primary.callback()
assertEqual(1, window.movedItems[1], "Primary keybind moves single items immediately")

-- Guild-bank transfers always move the whole stack, so the quantity dialog is skipped.
guildBankMode = true
guildTransferAllowed = true
guildTransferDenialText = nil
window.currentMode = BETTERUI.Banking.LIST_WITHDRAW
window.list.selectedData = { bagId = BAG_GUILDBANK, slotIndex = 2, stackCount = 4 }
primary.callback()
assertEqual(4, window.movedItems[2], "Guild-bank primary transfer moves the whole stack")
assertEqual(1, #window.shownQuantityDialogs, "Guild-bank primary transfer skips the quantity dialog")
guildBankMode = false

window.list.selectedData = { currencyType = CURT_MONEY, keybindLabel = "Gold" }
currencyPrimary.callback()
assertEqual(CURT_MONEY, window.displayedCurrencyType, "Currency keybind opens the selector for the selected currency")

window.selector.value = 99
window.currentMode = BETTERUI.Banking.LIST_WITHDRAW
guildBankMode = true
logEvents = {}
currencySelectorPrimary.callback()
assertEqual(CURRENCY_LOCATION_GUILD_BANK, transferCalls[1].fromLocation, "Guild withdraw transfers from guild bank")
assertEqual(CURRENCY_LOCATION_CHARACTER, transferCalls[1].toLocation, "Guild withdraw transfers to character")
assertEqual(1, window.hiddenSelectorCount, "Currency confirmation hides the selector")
assertEqual(1, window.refreshedFooterCount, "Currency confirmation refreshes the footer")
assertEqual(window.coreKeybinds, updatedGroups[1], "Currency confirmation updates core keybinds")
assertEqual("bankCurrencyTransfer", logEvents[1].kind, "Currency confirmation begins a builog flow")
assertTrue(hasLogMessage("bank currency transfer completed"), "Currency confirmation ends with a completed flow")

transferCalls = {}
updatedGroups = {}
window.hiddenSelectorCount = 0
window.refreshedFooterCount = 0
guildBankMode = false
window.currentMode = BETTERUI.Banking.LIST_WITHDRAW
currencySelectorPrimary.callback()
-- Personal withdraw moves gold from the bank to the character via the modern
-- TransferCurrency API (the deprecated WithdrawCurrencyFromBank alias is gone).
assertEqual(CURT_MONEY, transferCalls[1].currencyType, "Personal withdraw uses TransferCurrency")
assertEqual(CURRENCY_LOCATION_BANK, transferCalls[1].fromLocation, "Personal withdraw transfers from the bank")
assertEqual(CURRENCY_LOCATION_CHARACTER, transferCalls[1].toLocation, "Personal withdraw transfers to the character")
assertEqual(0, #withdrawCurrencyCalls, "Personal withdraw no longer calls the deprecated WithdrawCurrencyFromBank alias")

transferCalls = {}
window.currentMode = BETTERUI.Banking.LIST_DEPOSIT
currencySelectorPrimary.callback()
-- Personal deposit moves gold from the character to the bank (opposite
-- direction) via TransferCurrency.
assertEqual(CURT_MONEY, transferCalls[1].currencyType, "Personal deposit uses TransferCurrency")
assertEqual(CURRENCY_LOCATION_CHARACTER, transferCalls[1].fromLocation, "Personal deposit transfers from the character")
assertEqual(CURRENCY_LOCATION_BANK, transferCalls[1].toLocation, "Personal deposit transfers to the bank")
assertEqual(0, #depositCurrencyCalls, "Personal deposit no longer calls the deprecated DepositCurrencyIntoBank alias")

transferCalls = {}
logEvents = {}
logPrivacyMode = true
currencyAmounts[CURRENCY_LOCATION_CHARACTER] = 1000
currencyAmounts[CURRENCY_LOCATION_BANK] = 2000
window.selector.value = 25
window.currentMode = BETTERUI.Banking.LIST_DEPOSIT
currencySelectorPrimary.callback()
local privateRequested = findTraceEvent("bank.currency_transfer", "requested")
assertTrue(privateRequested ~= nil, "Privacy currency transfer emits requested trace")
assertEqual(-25, privateRequested.data.postCallFromDelta, "Privacy requested trace includes from delta")
assertEqual(25, privateRequested.data.postCallToDelta, "Privacy requested trace includes to delta")
assertEqual(nil, privateRequested.data.beforeFrom, "Privacy requested trace omits beforeFrom")
assertEqual(nil, privateRequested.data.beforeTo, "Privacy requested trace omits beforeTo")
assertEqual(nil, privateRequested.data.postCallFrom, "Privacy requested trace omits postCallFrom")
assertEqual(nil, privateRequested.data.postCallTo, "Privacy requested trace omits postCallTo")
local privateCompleted = findTraceEvent("bank.currency_transfer", "completed")
assertTrue(privateCompleted ~= nil, "Privacy currency transfer emits completed trace")
assertEqual(-25, privateCompleted.data.settledFromDelta, "Privacy completed trace includes settled from delta")
assertEqual(25, privateCompleted.data.settledToDelta, "Privacy completed trace includes settled to delta")
assertEqual(nil, privateCompleted.data.settledFrom, "Privacy completed trace omits settledFrom")
assertEqual(nil, privateCompleted.data.settledTo, "Privacy completed trace omits settledTo")
logPrivacyMode = false

transferCalls = {}
logEvents = {}
transferCurrencyShouldFail = true
currencySelectorPrimary.callback()
assertEqual("bankCurrencyTransfer", logEvents[1].kind, "Failed currency transfer still begins a builog flow")
assertTrue(hasLogMessage("bank currency transfer failed"), "Failed currency transfer closes the flow with failure")
transferCurrencyShouldFail = false

window.selectedDataCallback = function(self, control, data)
    self.selectedDataCallbackArgs = { self = self, control = control, data = data }
end
window.list.selectedData = { bagId = BAG_BANK, slotIndex = 4 }
window.list.selectedControl = "selected-control"
window:RefreshActiveKeybinds()
assertEqual(window, window.selectedDataCallbackArgs.self, "RefreshActiveKeybinds passes the window to the selection callback")
assertEqual("selected-control", window.selectedDataCallbackArgs.control, "RefreshActiveKeybinds forwards the selected control")
assertEqual(window.list.selectedData, window.selectedDataCallbackArgs.data, "RefreshActiveKeybinds forwards the selected data")

-- BUI-STAB-001 Phase 3 behavior contract: keybind-operation counts must not
-- duplicate the EnsureKeybindGroupAdded refresh with an immediate UpdateKeybindGroup.
do
    local savedInterface = {
        EnsureKeybindGroupAdded = BETTERUI.Interface.EnsureKeybindGroupAdded,
        UpdateKeybindGroup = BETTERUI.Interface.UpdateKeybindGroup,
        RemoveKeybindGroupIfPresent = BETTERUI.Interface.RemoveKeybindGroupIfPresent,
        RestoreKeybindGroups = BETTERUI.Interface.RestoreKeybindGroups,
    }
    local savedBankingEnsureKeybindGroupAdded = BETTERUI.Banking.EnsureKeybindGroupAdded
    local savedBetterUIUtils = BETTERUI.Utils
    local savedSharedItemSupport = BETTERUI.CIM.SharedItemSupport
    local savedSafeExecute = BETTERUI.CIM.SafeExecute
    local savedSetTooltipWidth = BETTERUI.CIM.SetTooltipWidth
    local savedCIMConst = BETTERUI.CIM.CONST
    local savedZOColorDef = ZO_ColorDef
    local savedGamepadTooltips = GAMEPAD_TOOLTIPS
    local savedLeftTooltip = GAMEPAD_LEFT_TOOLTIP
    local savedRightTooltip = GAMEPAD_RIGHT_TOOLTIP
    local savedGetItemLink = GetItemLink
    local savedHasKeybindButtonGroup = KEYBIND_STRIP.HasKeybindButtonGroup
    local oldSceneHidden = SCENE_HIDDEN
    local oldSceneShowing = SCENE_SHOWING
    local oldSceneHiding = SCENE_HIDING

    local present = {}
    local opsAdded = {}
    local opsRemoved = {}
    local opsUpdated = {}

    KEYBIND_STRIP.HasKeybindButtonGroup = function(_, group)
        return present[group] == true
    end

    BETTERUI.Interface.EnsureKeybindGroupAdded = function(group)
        if not group then return false end
        if not present[group] then
            present[group] = true
            table.insert(opsAdded, group)
        end
        table.insert(opsUpdated, group)
        return true
    end

    BETTERUI.Interface.UpdateKeybindGroup = function(group)
        table.insert(opsUpdated, group)
        return true
    end

    BETTERUI.Interface.RemoveKeybindGroupIfPresent = function(group)
        if present[group] then
            present[group] = nil
            table.insert(opsRemoved, group)
            return true
        end
        return false
    end

    BETTERUI.Interface.RestoreKeybindGroups = function(groups)
        if not groups then return end
        for _, group in ipairs(groups) do
            BETTERUI.Interface.EnsureKeybindGroupAdded(group)
        end
    end

    SCENE_HIDDEN = SCENE_HIDDEN or "hidden"
    SCENE_SHOWING = SCENE_SHOWING or "showing"
    SCENE_HIDING = SCENE_HIDING or "hiding"

    BETTERUI.CIM.SafeExecute = function(_, fn, ...)
        return fn(...)
    end
    BETTERUI.CIM.SetTooltipWidth = function() end
    BETTERUI.CIM.CONST = BETTERUI.CIM.CONST or {}
    BETTERUI.CIM.CONST.LAYOUT = BETTERUI.CIM.CONST.LAYOUT or { PANEL = { WIDTH = 1024, ZO_WIDTH = 1024 } }

    -- BankingClass normally installs this alias before SearchManager loads.
    -- Recreate that manifest order after installing the counting seam so the
    -- module-local helper records the exact operations under test.
    BETTERUI.Banking.EnsureKeybindGroupAdded = BETTERUI.Interface.EnsureKeybindGroupAdded
    dofile("Modules/Banking/Search/SearchManager.lua")
    ZO_ColorDef = { New = function(_, hex) return { hex = hex } end }
    BETTERUI.Utils = { IsBankingSceneShowing = function() return true end }
    BETTERUI.CIM.SharedItemSupport = {
        CleanupEnhancedTooltip = function() end,
        UpdateTooltipEquippedText = function() end,
        IsItemComparisonEnabled = function() return false end,
        ShowComparisonOnTooltip = function() end,
    }
    GAMEPAD_LEFT_TOOLTIP = "left-tooltip"
    GAMEPAD_RIGHT_TOOLTIP = "right-tooltip"
    GAMEPAD_TOOLTIPS = {
        ClearLines = function() end,
        LayoutBagItem = function() return true end,
        GetTooltip = function() return {} end,
        GetTooltipContainer = function() return {} end,
        Reset = function() end,
    }
    GetItemLink = function() return "item-link" end
    dofile("Modules/Banking/Lists/BankRowSetup.lua")
    dofile("Modules/CIM/Core/Lifecycle/SceneLifecycleManager.lua")

    local function makeScene(name)
        local scene = {
            _name = name,
            _handlers = {},
        }
        function scene:RegisterCallback(event, fn)
            self._handlers[event] = self._handlers[event] or {}
            table.insert(self._handlers[event], fn)
        end
        function scene:UnregisterCallback(event, fn)
            local handlers = self._handlers[event]
            if not handlers then return end
            for i = #handlers, 1, -1 do
                if handlers[i] == fn then
                    table.remove(handlers, i)
                end
            end
        end
        function scene:triggerStateChange(oldState, newState)
            for _, fn in ipairs(self._handlers["StateChange"] or {}) do
                fn(oldState, newState)
            end
        end
        function scene:GetName()
            return self._name
        end
        return scene
    end

    local function resolveOwnedBankingCore(window)
        if not window._bankingOwnsCoreKeybinds and window.coreKeybinds then
            return { window.coreKeybinds }
        end
        return {}
    end

    local function clearOpHistory()
        for i = #opsAdded, 1, -1 do table.remove(opsAdded) end
        for i = #opsRemoved, 1, -1 do table.remove(opsRemoved) end
        for i = #opsUpdated, 1, -1 do table.remove(opsUpdated) end
    end

    local function clearPresent()
        for k in pairs(present) do present[k] = nil end
    end

    local function resetOps()
        clearPresent()
        clearOpHistory()
    end

    local function countIn(tbl, group)
        local n = 0
        for _, g in ipairs(tbl) do
            if g == group then n = n + 1 end
        end
        return n
    end

    -- SearchManager: exiting search mode must not double-refresh core keybinds.
    resetOps()
    local w = createWindow()
    w.textSearchKeybindStripDescriptor = "search-group"
    w.withdrawDepositKeybinds = { "withdraw" }
    w.coreKeybinds = { "core" }
    w._searchModeActive = true
    w._searchRemovedKeybindGroups = { w.withdrawDepositKeybinds }
    local exitSearchMode = BETTERUI.Banking.Class.SEARCH_LIFECYCLE
        and BETTERUI.Banking.Class.SEARCH_LIFECYCLE.exit
    if exitSearchMode then
        w[exitSearchMode](w)
    else
        w:ExitSearchMode()
    end
    assertEqual(1, countIn(opsUpdated, w.coreKeybinds), "ExitSearchMode updates core keybinds exactly once")
    assertEqual(1, countIn(opsUpdated, w.withdrawDepositKeybinds), "ExitSearchMode restores withdraw/deposit keybinds exactly once")

    -- KeybindManager: clear-search callback must not double-refresh core keybinds.
    resetOps()
    local w2 = createWindow()
    w2.textSearchKeybindStripDescriptor = "search-group"
    w2.textSearchHeaderControl = { IsHidden = function() return false end }
    w2:InitializeKeybind()
    local clearSearchEntry = nil
    for _, entry in ipairs(w2.coreKeybinds) do
        if entry.keybind == "CLEAR_SEARCH" then
            clearSearchEntry = entry
            break
        end
    end
    assertTrue(clearSearchEntry ~= nil, "Clear-search keybind entry exists")
    present[w2.coreKeybinds] = true
    clearSearchEntry.callback()
    assertEqual(1, countIn(opsUpdated, w2.coreKeybinds), "Clear-search callback updates core keybinds exactly once")

    -- Scene lifecycle ownership ordering: Banking-owned personal bank should not receive
    -- a resolver-owned core group, while guild mode should.
    resetOps()
    local personalScene = makeScene("betterui_banking")
    local personalWindow = createWindow()
    personalWindow.sceneName = "betterui_banking"
    personalWindow.scene = personalScene
    personalWindow.coreKeybinds = { "core-personal" }
    personalWindow.withdrawDepositKeybinds = { "transfer-personal" }
    personalWindow.textSearchKeybindStripDescriptor = { "search-personal" }
    personalWindow._bankingOwnsCoreKeybinds = true
    personalWindow.OnSceneShowing = function(self)
        self:AddKeybinds()
    end
    personalWindow.OnSceneHiding = function(self)
        self:RemoveKeybinds()
    end
    present[personalWindow.textSearchKeybindStripDescriptor] = true
    BETTERUI.CIM.SceneLifecycle.Register(personalWindow, {
        keybindsResolver = function()
            return resolveOwnedBankingCore(personalWindow)
        end,
        onShowing = function(screen, wasPushed)
            if screen.OnSceneShowing then
                screen:OnSceneShowing(wasPushed)
            end
        end,
        onHiding = function(screen)
            if screen.OnSceneHiding then
                screen:OnSceneHiding()
            end
        end,
    })
    personalScene:triggerStateChange(SCENE_HIDDEN, SCENE_SHOWING)
    assertEqual(2, #opsAdded, "personal scene entry adds exactly two keybinds")
    assertEqual(personalWindow.withdrawDepositKeybinds, opsAdded[1], "personal scene entry registers transfer before core")
    assertEqual(personalWindow.coreKeybinds, opsAdded[2], "personal scene entry registers core after transfer")
    assertEqual(1, countIn(opsAdded, personalWindow.withdrawDepositKeybinds), "personal scene entry adds transfer keybinds exactly once")
    assertEqual(1, countIn(opsAdded, personalWindow.coreKeybinds), "personal scene entry adds core keybinds exactly once")
    assertEqual(personalWindow.textSearchKeybindStripDescriptor, opsRemoved[1], "personal scene entry clears search strip before adding managed groups")
    assertTrue(present[personalWindow.textSearchKeybindStripDescriptor] == nil, "personal scene entry removes search keybind ownership")
    assertTrue(present[personalWindow.withdrawDepositKeybinds] == true, "personal scene entry leaves transfer keybind ownership present")
    assertTrue(present[personalWindow.coreKeybinds] == true, "personal scene entry leaves core keybind ownership present")

    clearOpHistory()
    personalScene:triggerStateChange(SCENE_SHOWING, SCENE_HIDING)
    assertEqual(personalWindow.withdrawDepositKeybinds, opsRemoved[1], "personal scene exit removes transfer keybinds first")
    assertEqual(personalWindow.coreKeybinds, opsRemoved[2], "personal scene exit removes core keybinds second")
    assertTrue(present[personalWindow.coreKeybinds] == nil, "personal scene exit clears final core keybind ownership")
    assertTrue(present[personalWindow.withdrawDepositKeybinds] == nil, "personal scene exit clears final transfer keybind ownership")

    resetOps()
    local guildScene = makeScene("betterui_guild_banking")
    local guildWindow = createWindow()
    guildWindow.sceneName = "betterui_guild_banking"
    guildWindow.scene = guildScene
    guildWindow.coreKeybinds = { "core-guild" }
    guildWindow.withdrawDepositKeybinds = { "transfer-guild" }
    guildWindow.textSearchKeybindStripDescriptor = { "search-guild" }
    guildWindow._bankingOwnsCoreKeybinds = true
    guildWindow.OnSceneShowing = function(self)
        self:AddKeybinds()
    end
    guildWindow.OnSceneHiding = function(self)
        self:RemoveKeybinds()
    end
    present[guildWindow.textSearchKeybindStripDescriptor] = true
    BETTERUI.CIM.SceneLifecycle.Register(guildWindow, {
        -- Banking.lua registers the guild scene with keybinds = {}; AddKeybinds is
        -- the sole owner for both personal and guild scenes.
        keybinds = {},
        onShowing = function(screen, wasPushed)
            if screen.OnSceneShowing then
                screen:OnSceneShowing(wasPushed)
            end
        end,
        onHiding = function(screen)
            if screen.OnSceneHiding then
                screen:OnSceneHiding()
            end
        end,
    })
    guildScene:triggerStateChange(SCENE_HIDDEN, SCENE_SHOWING)
    assertEqual(2, #opsAdded, "guild scene entry adds exactly two managed keybind groups")
    assertEqual(guildWindow.withdrawDepositKeybinds, opsAdded[1], "guild scene entry registers transfer before core")
    assertEqual(guildWindow.coreKeybinds, opsAdded[2], "guild scene entry registers core after transfer")
    assertEqual(1, countIn(opsAdded, guildWindow.withdrawDepositKeybinds), "guild scene entry adds transfer keybinds exactly once")
    assertEqual(1, countIn(opsAdded, guildWindow.coreKeybinds), "guild scene entry adds core keybinds exactly once")
    assertEqual(guildWindow.textSearchKeybindStripDescriptor, opsRemoved[1], "guild scene entry clears search strip before adding managed groups")
    assertTrue(present[guildWindow.textSearchKeybindStripDescriptor] == nil, "guild scene entry removes search keybind ownership")
    assertTrue(present[guildWindow.withdrawDepositKeybinds] == true, "guild scene entry leaves transfer keybind ownership present")
    assertTrue(present[guildWindow.coreKeybinds] == true, "guild scene entry leaves core keybind ownership present")

    clearOpHistory()
    guildScene:triggerStateChange(SCENE_SHOWING, SCENE_HIDING)
    assertEqual(guildWindow.withdrawDepositKeybinds, opsRemoved[1], "guild scene exit removes transfer keybinds first")
    assertEqual(guildWindow.coreKeybinds, opsRemoved[2], "guild scene exit removes core keybinds second")
    assertTrue(present[guildWindow.coreKeybinds] == nil, "guild scene exit clears final core keybind ownership")
    assertTrue(present[guildWindow.withdrawDepositKeybinds] == nil, "guild scene exit clears final transfer keybind ownership")

    -- BankRowSetup: selection changes must not double-refresh currency/transfer keybinds.
    resetOps()
    local w3 = createWindow()
    w3.bankCategories = { { key = "all" } }
    w3.currentCategoryIndex = 1
    w3.coreKeybinds = { "core" }
    w3.currencyKeybinds = { "currency" }
    w3.withdrawDepositKeybinds = { "transfer" }
    w3.textSearchHeaderControl = { IsHidden = function() return true end }
    w3.RefreshCurrencyTooltip = function() end
    local savedUpdateActions = BETTERUI.Banking.Class.UpdateActions
    local updateActionCalls = 0
    w3.UpdateActions = function(self)
        updateActionCalls = updateActionCalls + 1
        return savedUpdateActions(self)
    end
    -- Currency row
    clearPresent()
    updateActionCalls = 0
    BETTERUI.Banking.Class.OnItemSelectedChange(w3, w3.list, { isCurrency = true, currencyType = CURT_MONEY, keybindLabel = "Gold" })
    assertEqual(1, updateActionCalls, "Currency-row selection uses full UpdateActions path once")
    assertEqual(0, #w3.itemActions.slots, "Currency-row selection clears non-actionable item actions")
    assertEqual(1, countIn(opsUpdated, w3.currencyKeybinds), "Currency-row selection updates currency keybinds exactly once")
    assertEqual(0, countIn(opsUpdated, w3.withdrawDepositKeybinds), "Currency-row selection does not touch transfer keybinds")
    -- Item row
    resetOps()
    clearPresent()
    updateActionCalls = 0
    w3.itemActions.slots = {}
    w3.list.selectedData = { bagId = BAG_BANK, slotIndex = 1, stackCount = 4 }
    slotStacks["2:1"] = 4
    BETTERUI.Banking.Class.OnItemSelectedChange(w3, w3.list, w3.list.selectedData)
    assertEqual(1, updateActionCalls, "Item-row selection uses full UpdateActions path once")
    assertEqual(1, #w3.itemActions.slots, "Item-row selection updates item-actions on actionable entries")
    assertEqual(1, countIn(opsUpdated, w3.withdrawDepositKeybinds), "Item-row selection updates transfer keybinds exactly once")
    assertEqual(0, countIn(opsUpdated, w3.currencyKeybinds), "Item-row selection does not touch currency keybinds")

    -- Restore original stubs so the remainder of the harness behaves as before.
    BETTERUI.Interface.EnsureKeybindGroupAdded = savedInterface.EnsureKeybindGroupAdded
    BETTERUI.Interface.UpdateKeybindGroup = savedInterface.UpdateKeybindGroup
    BETTERUI.Interface.RemoveKeybindGroupIfPresent = savedInterface.RemoveKeybindGroupIfPresent
    BETTERUI.Interface.RestoreKeybindGroups = savedInterface.RestoreKeybindGroups
    BETTERUI.Banking.EnsureKeybindGroupAdded = savedBankingEnsureKeybindGroupAdded
    BETTERUI.Utils = savedBetterUIUtils
    BETTERUI.CIM.SharedItemSupport = savedSharedItemSupport
    BETTERUI.CIM.SafeExecute = savedSafeExecute
    BETTERUI.CIM.SetTooltipWidth = savedSetTooltipWidth
    BETTERUI.CIM.CONST = savedCIMConst
    SCENE_HIDDEN = oldSceneHidden
    SCENE_SHOWING = oldSceneShowing
    SCENE_HIDING = oldSceneHiding
    ZO_ColorDef = savedZOColorDef
    GAMEPAD_TOOLTIPS = savedGamepadTooltips
    GAMEPAD_LEFT_TOOLTIP = savedLeftTooltip
    GAMEPAD_RIGHT_TOOLTIP = savedRightTooltip
    GetItemLink = savedGetItemLink
    KEYBIND_STRIP.HasKeybindButtonGroup = savedHasKeybindButtonGroup
end

print("\n=== Test Summary ===")
print("Passed: " .. testsPassed)
print("Failed: " .. testsFailed)

if testsFailed > 0 then
    print("\nFAILED — see above for details")
    os.exit(1)
else
    print("\nAll tests passed!")
end
