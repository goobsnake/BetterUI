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

local guildBankMode = false
local guildBankLoading = false
local currentBank = BAG_BANK
local nextBankUpgradePrice = 1000
local carriedCurrency = 5000
local guildCount = 2
local batchProcessing = false
local guildTransferAllowed = true
local guildTransferDenialText = nil
local transferSupport = {
    ResolveGuildBankTransferDecision = function()
        return guildTransferAllowed, guildTransferDenialText and "denied" or nil, guildTransferDenialText, nil
    end,
}

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
    guildBankMode = false
    guildBankLoading = false
    currentBank = BAG_BANK
    nextBankUpgradePrice = 1000
    carriedCurrency = 5000
    guildCount = 2
    batchProcessing = false
    guildTransferAllowed = true
    guildTransferDenialText = nil
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
    Banking = {
        LIST_WITHDRAW = 1,
        LIST_DEPOSIT = 2,
        currentUsedBank = BAG_BANK,
        GetTransferTargetBag = function()
            return currentBank
        end,
        GetTransferSourceBag = function()
            return (currentBank == nil or currentBank == 0) and BAG_BANK or currentBank
        end,
        GetActiveTransferContext = function()
            local sourceBag = BETTERUI.Banking.GetTransferSourceBag()
            local targetBag = BETTERUI.Banking.GetTransferTargetBag()
            return {
                sourceBag = sourceBag,
                targetBag = targetBag,
                withdrawSourceBags = targetBag == BAG_BANK and { BAG_BANK, BAG_SUBSCRIBER_BANK } or { targetBag },
                isMainBank = sourceBag == BAG_BANK,
                isSourceMainBank = sourceBag == BAG_BANK,
                isTargetMainBank = targetBag == BAG_BANK,
                isGuildBank = guildBankMode or sourceBag == BAG_GUILDBANK,
            }
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
        GetTransferSupport = function()
            return transferSupport
        end,
        RequireTransferSupport = function()
            return transferSupport
        end,
        IsGuildBankTransferMode = function()
            return guildBankMode
        end,
        IsMainBankTransferSource = function()
            return BETTERUI.Banking.GetTransferSourceBag() == BAG_BANK
        end,
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
        },
        UserAlertText = function(_, message)
            table.insert(userAlerts, message)
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
        HideSelector = function(self)
            self.hiddenSelectorCount = self.hiddenSelectorCount + 1
        end,
        RefreshFooter = function(self)
            self.refreshedFooterCount = self.refreshedFooterCount + 1
        end,
        CancelWithdrawDeposit = function(self)
            self.cancelWithdrawDepositCount = self.cancelWithdrawDepositCount + 1
        end,
        DisplaySelector = function(self, currencyType)
            self.displayedCurrencyType = currencyType
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

removedGroups = {}
window:RemoveKeybinds()
assertEqual(window.withdrawDepositKeybinds, removedGroups[1], "RemoveKeybinds removes withdraw/deposit keybinds")
assertEqual(window.coreKeybinds, removedGroups[2], "RemoveKeybinds removes core keybinds")

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

window.list.selectedData = { currencyType = CURT_MONEY, keybindLabel = "Gold" }
currencyPrimary.callback()
assertEqual(CURT_MONEY, window.displayedCurrencyType, "Currency keybind opens the selector for the selected currency")

window.selector.value = 99
window.currentMode = BETTERUI.Banking.LIST_WITHDRAW
guildBankMode = true
currencySelectorPrimary.callback()
assertEqual(CURRENCY_LOCATION_GUILD_BANK, transferCalls[1].fromLocation, "Guild withdraw transfers from guild bank")
assertEqual(CURRENCY_LOCATION_CHARACTER, transferCalls[1].toLocation, "Guild withdraw transfers to character")
assertEqual(1, window.hiddenSelectorCount, "Currency confirmation hides the selector")
assertEqual(1, window.refreshedFooterCount, "Currency confirmation refreshes the footer")
assertEqual(window.coreKeybinds, updatedGroups[1], "Currency confirmation updates core keybinds")

transferCalls = {}
updatedGroups = {}
window.hiddenSelectorCount = 0
window.refreshedFooterCount = 0
guildBankMode = false
window.currentMode = BETTERUI.Banking.LIST_WITHDRAW
currencySelectorPrimary.callback()
assertEqual(CURT_MONEY, withdrawCurrencyCalls[1].currencyType, "Personal withdraw uses WithdrawCurrencyFromBank")

window.currentMode = BETTERUI.Banking.LIST_DEPOSIT
currencySelectorPrimary.callback()
assertEqual(CURT_MONEY, depositCurrencyCalls[1].currencyType, "Personal deposit uses DepositCurrencyIntoBank")

window.selectedDataCallback = function(self, control, data)
    self.selectedDataCallbackArgs = { self = self, control = control, data = data }
end
window.list.selectedData = { bagId = BAG_BANK, slotIndex = 4 }
window.list.selectedControl = "selected-control"
window:RefreshActiveKeybinds()
assertEqual(window, window.selectedDataCallbackArgs.self, "RefreshActiveKeybinds passes the window to the selection callback")
assertEqual("selected-control", window.selectedDataCallbackArgs.control, "RefreshActiveKeybinds forwards the selected control")
assertEqual(window.list.selectedData, window.selectedDataCallbackArgs.data, "RefreshActiveKeybinds forwards the selected data")

print("\n=== Test Summary ===")
print("Passed: " .. testsPassed)
print("Failed: " .. testsFailed)

if testsFailed > 0 then
    print("\nFAILED — see above for details")
    os.exit(1)
else
    print("\nAll tests passed!")
end
