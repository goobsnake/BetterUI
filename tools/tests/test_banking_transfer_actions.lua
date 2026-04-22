--[[
File: tools/tests/test_banking_transfer_actions.lua
Purpose: Covers transfer execution, selector behavior, and action dialog launch.

Usage:
  lua tools/tests/test_banking_transfer_actions.lua
]]

if false then
    dofile("Modules/Banking/Currency/CurrencySelector.lua")
    dofile("Modules/Banking/Actions/TransferActions.lua")
end

BAG_BACKPACK = 1
BAG_BANK = 2
BAG_GUILDBANK = 3
BAG_SUBSCRIBER_BANK = 6
ITEM_SOUND_ACTION_PICKUP = "pickup"
UI_ALERT_CATEGORY_ERROR = "error"
SI_INVENTORY_ERROR_INVENTORY_FULL = "inventory_full"
SI_INVENTORY_ERROR_BANK_FULL = "bank_full"
SI_STOLEN_ITEM_CANNOT_DEPOSIT_MESSAGE = "stolen_item"
SI_FURNITURE_VAULT_ERROR_STOLEN_FURNITURE = "stolen_furniture"
SI_FURNITURE_VAULT_ERROR_GEMMABLE_FURNITURE = "gemmable_furniture"
SI_FURNITURE_VAULT_ERROR_NEED_COLLECTIBLE = "need_collectible"
SI_FURNITURE_VAULT_ERROR_NEED_ESO_PLUS = "need_eso_plus"
SI_BETTERUI_BANK_NO_FUNDS = "SI_BETTERUI_BANK_NO_FUNDS"
ZO_GAMEPAD_INVENTORY_ACTION_DIALOG = "ZO_GAMEPAD_INVENTORY_ACTION_DIALOG"
CURRENCY_LOCATION_CHARACTER = 1
CURRENCY_LOCATION_BANK = 2
CURRENCY_LOCATION_GUILD_BANK = 3

local testsPassed = 0
local testsFailed = 0

local selectedData = nil
local slotStacks = {}
local emptySlots = {}
local stackableSlots = {}
local bagFreeSlots = {}
local bagUsedSlots = {}
local bagSizes = {}
local secureMoves = {}
local userNotifies = {}
local alerts = {}
local playedSounds = {}
local guildWithdrawCalls = {}
local guildDepositCalls = {}
local scheduledTasks = {}
local showingDialog = false
local currentBank = BAG_BANK
local currentBankingBag = BAG_BANK
local depositAllowed = true
local depositReason = nil
local guildTransferAllowed = true
local guildTransferReason = nil
local guildTransferNotifyWithText = false
local sceneHiddenCount = 0
local platformDialogsShown = {}
local keybindOps = {}
local userAlertTexts = {}

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

local function resetState()
    selectedData = nil
    slotStacks = {}
    emptySlots = {}
    stackableSlots = {}
    bagFreeSlots = {}
    bagUsedSlots = {}
    bagSizes = {}
    secureMoves = {}
    userNotifies = {}
    alerts = {}
    playedSounds = {}
    guildWithdrawCalls = {}
    guildDepositCalls = {}
    scheduledTasks = {}
    showingDialog = false
    currentBank = BAG_BANK
    currentBankingBag = BAG_BANK
    depositAllowed = true
    depositReason = nil
    guildTransferAllowed = true
    guildTransferReason = nil
    guildTransferNotifyWithText = false
    sceneHiddenCount = 0
    platformDialogsShown = {}
    keybindOps = {}
    userAlertTexts = {}
end

function GetString(id)
    if id == SI_BETTERUI_BANK_NO_FUNDS then
        return "No funds"
    end
    return tostring(id)
end

function zo_clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

function FindFirstEmptySlotInBag(bagId)
    return emptySlots[bagId]
end

function IsESOPlusSubscriber()
    return false
end

function ZO_Inventory_GetBagAndIndex(data)
    return data.bagId, data.slotIndex
end

function GetItemLink(bagId, slotIndex)
    return string.format("item:%d:%d", bagId, slotIndex)
end

function GetSlotStackSize(bagId, slotIndex)
    return slotStacks[bagId .. ":" .. slotIndex] or 0
end

function GetNumBagFreeSlots(bagId)
    return bagFreeSlots[bagId] or 0
end

function GetNumBagUsedSlots(bagId)
    return bagUsedSlots[bagId] or 0
end

function GetBagSize(bagId)
    return bagSizes[bagId] or 0
end

function GetItemSoundCategory()
    return "item_sound"
end

function PlayItemSound(category, action)
    table.insert(playedSounds, { category = category, action = action })
end

function TransferFromGuildBank(slotIndex)
    table.insert(guildWithdrawCalls, slotIndex)
end

function TransferToGuildBank(bagId, slotIndex)
    table.insert(guildDepositCalls, { bagId = bagId, slotIndex = slotIndex })
end

function CallSecureProtected(name, ...)
    table.insert(secureMoves, { name = name, args = { ... } })
end

function IsHouseBankBag(bagId)
    return bagId == 99
end

function GetBankingBag()
    return currentBankingBag
end

function ZO_Dialogs_IsShowingDialog()
    return showingDialog
end

function ZO_Alert(_, _, errorStringId)
    table.insert(alerts, errorStringId)
end

function GetMaxCurrencyTransfer()
    return 25
end

function GetCarriedCurrencyAmount()
    return 0
end

function GetBankedCurrencyAmount()
    return 0
end

function ZO_Dialogs_ShowPlatformDialog(name, dialogData)
    table.insert(platformDialogsShown, { name = name, dialogData = dialogData })
end

KEYBIND_STRIP = {
    AddKeybindButtonGroup = function(_, group)
        table.insert(keybindOps, { op = "add", group = group })
    end,
    RemoveKeybindButtonGroup = function(_, group)
        table.insert(keybindOps, { op = "remove", group = group })
    end,
}

SCENE_MANAGER = {
    HideCurrentScene = function()
        sceneHiddenCount = sceneHiddenCount + 1
    end,
}

ZO_GamepadBanking = {
    IsEntryDataCurrencyRelated = function(entryData)
        return entryData and entryData.isCurrency == true
    end,
}

GAMEPAD_LEFT_TOOLTIP = {}
SOUNDS = { NEGATIVE_CLICK = "negative" }

BETTERUI = {
    Banking = {
        LIST_WITHDRAW = 1,
        LIST_DEPOSIT = 2,
        currentUsedBank = BAG_BANK,
        ResolveInteractionBankBag = function()
            return (currentBankingBag == nil or currentBankingBag == 0) and BAG_BANK or currentBankingBag
        end,
        ResolveDepositTarget = function()
            return currentBank
        end,
        ResolveActiveTransferMode = function()
            local sourceBag = BETTERUI.Banking.ResolveInteractionBankBag()
            local targetBag = BETTERUI.Banking.ResolveDepositTarget()
            local isGuildBank = sourceBag == BAG_GUILDBANK
            return {
                kind = isGuildBank and "guild-bank" or (sourceBag == BAG_BANK and "main-bank" or "house-bank"),
                interactionBag = sourceBag,
                depositTargetBag = targetBag,
                withdrawSourceBags = targetBag == BAG_BANK and { BAG_BANK, BAG_SUBSCRIBER_BANK } or { targetBag },
                sourceIsFurnitureVault = false,
                targetIsFurnitureVault = false,
            }
        end,
        ResolveWithdrawSources = function()
            return BETTERUI.Banking.ResolveActiveTransferMode().withdrawSourceBags
        end,
        IsGuildTransferActive = function()
            return BETTERUI.Banking.ResolveActiveTransferMode().kind == "guild-bank"
        end,
        IsMainBankInteraction = function()
            return BETTERUI.Banking.ResolveActiveTransferMode().kind == "main-bank"
        end,
        IsHouseBankInteraction = function()
            return BETTERUI.Banking.ResolveActiveTransferMode().kind == "house-bank"
        end,
        IsFurnitureVaultInteraction = function()
            return false
        end,
        IsFurnitureVaultDepositTarget = function()
            return false
        end,
        transferSupport = {
            IsDepositSupportedForBank = function()
                return depositAllowed, depositReason
            end,
            ResolveTransferDeniedStringId = function(_, denyReason)
                if denyReason == "stolen" then
                    return SI_STOLEN_ITEM_CANNOT_DEPOSIT_MESSAGE
                end
                return nil
            end,
            NotifyGuildBankTransferDenied = function(_, _, _, _)
                if guildTransferAllowed then
                    return true, nil
                end
                if guildTransferNotifyWithText then
                    BETTERUI.CIM.UserAlertText("GuildTransfer", guildTransferReason)
                else
                    BETTERUI.CIM.UserNotify("GuildTransfer", guildTransferReason)
                end
                return false, guildTransferReason
            end,
        },
        GetTransferSupport = function()
            return BETTERUI.Banking.transferSupport
        end,
        RequireTransferSupport = function()
            return BETTERUI.Banking.transferSupport
        end,
        ResolveTransferSupport = function()
            return BETTERUI.Banking.transferSupport
        end,
        Tasks = {
            Schedule = function(_, _, delayMs, callback)
                table.insert(scheduledTasks, { delay = delayMs, callback = callback })
            end,
        },
        CONST = {
            CURRENCY_TEXTURES = {
                [10] = "gold_texture",
            },
        },
        GuildBank = {
            IsGuildBankMode = function()
                return currentBankingBag == BAG_GUILDBANK
            end,
        },
        Class = {},
    },
    CIM = {
        CONST = {
            TIMING = {
                MOVE_COALESCE_DELAY_MS = 80,
            },
        },
        ProtectionPolicy = {
            DENY = {
                STOLEN = "stolen",
                CROWN_GEMMABLE = "crown_gemmable",
            },
        },
        HeaderNavigation = {
            GetOrCreateState = function(self)
                self.headerNavigationState = self.headerNavigationState or {}
                return self.headerNavigationState
            end,
        },
        Utils = {
            FindStackableSlotInBag = function(bagId)
                return stackableSlots[bagId]
            end,
        },
        UserNotify = function(_, messageId)
            table.insert(userNotifies, messageId)
        end,
        UserAlertText = function(_, message)
            table.insert(userAlertTexts, message)
        end,
    },
    Inventory = {
        CleanupEnhancedTooltip = function()
            -- no-op for tests
        end,
    },
}

dofile("Modules/Banking/Currency/CurrencySelector.lua")
dofile("Modules/Banking/Actions/TransferActions.lua")

local function createWindow()
    local window
    window = {
        currentMode = BETTERUI.Banking.LIST_WITHDRAW,
        bankCategories = { { key = "all" }, { key = "junk" } },
        currentCategoryIndex = 2,
        selectorHidden = true,
        moved = {},
        removeKeybindsCount = 0,
        confirmationUpdates = {},
        quantityDialogs = {},
        savePositions = 0,
        refreshedLists = 0,
        rebuiltHeaders = 0,
        list = {
            Activate = function() window.listActivated = true end,
            Deactivate = function() window.listDeactivated = true end,
            GetSelectedData = function()
                return selectedData
            end,
        },
        selector = {
            value = 7,
            maxValue = nil,
            clamp = nil,
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
        currencyKeybinds = { "currency" },
        currencySelectorKeybinds = { "currencySelector" },
        coreKeybinds = { "core" },
        GetList = function(self)
            return self.list
        end,
        ComputeVisibleBankCategories = function(self)
            return self.bankCategories
        end,
        RebuildHeaderCategories = function(self)
            self.rebuiltHeaders = self.rebuiltHeaders + 1
        end,
        RefreshList = function(self)
            self.refreshedLists = self.refreshedLists + 1
        end,
        RemoveKeybinds = function(self)
            self.removeKeybindsCount = self.removeKeybindsCount + 1
        end,
        SaveListPosition = function(self)
            self.savePositions = self.savePositions + 1
        end,
        UpdateSpinnerConfirmation = function(self, isActive, list)
            table.insert(self.confirmationUpdates, { isActive = isActive, list = list })
        end,
    }

    return setmetatable(window, { __index = BETTERUI.Banking.Class })
end

print("\n=== Banking transfer actions ===\n")

resetState()
local window = createWindow()
selectedData = { bagId = BAG_GUILDBANK, slotIndex = 9 }
bagFreeSlots[BAG_BACKPACK] = 10
currentBankingBag = BAG_GUILDBANK
window.currentMode = BETTERUI.Banking.LIST_WITHDRAW
window:MoveItem(window.list, 2)
assertEqual(9, guildWithdrawCalls[1], "Guild withdraw moves the selected guild slot")
assertEqual(1, #playedSounds, "Guild withdraw plays pickup sound")
assertEqual(100, scheduledTasks[1].delay, "Guild withdraw schedules a coalesced refresh")
scheduledTasks[1].callback()
assertEqual(1, window.rebuiltHeaders, "Coalesced refresh rebuilds header categories")
assertEqual(1, window.refreshedLists, "Coalesced refresh refreshes the list")

resetState()
window = createWindow()
selectedData = { bagId = BAG_BACKPACK, slotIndex = 7 }
currentBankingBag = BAG_GUILDBANK
window.currentMode = BETTERUI.Banking.LIST_DEPOSIT
guildTransferAllowed = false
guildTransferReason = SI_STOLEN_ITEM_CANNOT_DEPOSIT_MESSAGE
window:MoveItem(window.list, 1)
assertEqual(0, #guildDepositCalls, "Denied guild-bank deposits do not call TransferToGuildBank")
assertEqual(SI_STOLEN_ITEM_CANNOT_DEPOSIT_MESSAGE, userNotifies[1], "Denied guild-bank deposits use the shared denial notifier")

resetState()
window = createWindow()
selectedData = { bagId = BAG_BACKPACK, slotIndex = 5 }
currentBankingBag = BAG_GUILDBANK
window.currentMode = BETTERUI.Banking.LIST_DEPOSIT
bagUsedSlots[BAG_GUILDBANK] = 10
bagSizes[BAG_GUILDBANK] = 10
window:MoveItem(window.list, 1)
assertEqual(SI_INVENTORY_ERROR_BANK_FULL, userNotifies[1], "Guild deposit reports a full guild bank")

resetState()
window = createWindow()
selectedData = { bagId = BAG_BACKPACK, slotIndex = 4 }
window.currentMode = BETTERUI.Banking.LIST_DEPOSIT
depositAllowed = false
depositReason = "stolen"
window:MoveItem(window.list, 1)
assertEqual(SI_STOLEN_ITEM_CANNOT_DEPOSIT_MESSAGE, alerts[1], "Blocked deposits surface the correct alert")

resetState()
window = createWindow()
selectedData = { bagId = BAG_BACKPACK, slotIndex = 6 }
window.currentMode = BETTERUI.Banking.LIST_DEPOSIT
emptySlots[BAG_BANK] = 33
window:MoveItem(window.list, 5)
assertEqual("RequestMoveItem", secureMoves[1].name, "Deposit uses RequestMoveItem when an empty slot exists")
assertEqual(BAG_BANK, secureMoves[1].args[3], "Deposit targets the current bank bag")
assertEqual(33, secureMoves[1].args[4], "Deposit uses the resolved empty bank slot")
assertEqual(5, secureMoves[1].args[5], "Deposit forwards the requested quantity")

resetState()
window = createWindow()
selectedData = { bagId = BAG_BACKPACK, slotIndex = 6 }
window.currentMode = BETTERUI.Banking.LIST_DEPOSIT
stackableSlots[BAG_BANK] = 44
window:MoveItem(window.list, 3)
assertEqual(44, secureMoves[1].args[4], "Deposit falls back to a stackable slot when no empty slot exists")

resetState()
window = createWindow()
window.currentMode = BETTERUI.Banking.LIST_WITHDRAW
window:DisplaySelector(10)
assertEqual(25, window.selector.maxValue, "DisplaySelector applies the transferable currency maximum")
assertEqual("gold_texture", window.selectorTexture, "DisplaySelector swaps the selector icon")
assertTrue(window.selector.activated == true, "DisplaySelector activates the selector")
assertTrue(window.listDeactivated == true, "DisplaySelector deactivates the list")
assertEqual("remove", keybindOps[1].op, "DisplaySelector swaps out existing keybind groups")
assertEqual("add", keybindOps[#keybindOps].op, "DisplaySelector adds selector keybinds")

resetState()
window = createWindow()
GetMaxCurrencyTransfer = function()
    return 0
end
window:DisplaySelector(10)
assertEqual("No funds", userAlertTexts[1], "DisplaySelector alerts when no currency is transferable")
GetMaxCurrencyTransfer = function()
    return 25
end

resetState()
window = createWindow()
window:HideSelector()
assertTrue(window.selector.deactivated == true, "HideSelector deactivates the selector")
assertTrue(window.listActivated == true, "HideSelector reactivates the list")
assertEqual("add", keybindOps[#keybindOps - 1].op, "HideSelector restores currency keybinds")
assertEqual("add", keybindOps[#keybindOps].op, "HideSelector restores core keybinds")

resetState()
window = createWindow()
selectedData = { bagId = BAG_BANK, slotIndex = 2 }
window.list.selectedData = selectedData
slotStacks["2:2"] = 1
window:ShowActions()
assertEqual(1, window.removeKeybindsCount, "ShowActions removes banking keybinds before showing the action dialog")
assertEqual("ZO_GAMEPAD_INVENTORY_ACTION_DIALOG", platformDialogsShown[1].name, "ShowActions opens the inventory action dialog")
assertEqual(selectedData, platformDialogsShown[1].dialogData.targetData, "ShowActions forwards the selected row as dialog target")

resetState()
window = createWindow()
selectedData = { isCurrency = true }
window.list.selectedData = selectedData
window:ShowActions()
assertEqual(0, #platformDialogsShown, "ShowActions ignores non-actionable rows")

resetState()
window = createWindow()
window.scene = {
    IsShowing = function()
        return true
    end,
}
window:CancelWithdrawDeposit(window.list)
assertEqual(1, sceneHiddenCount, "CancelWithdrawDeposit closes the scene outside confirmation mode")

window.confirmationMode = true
window:CancelWithdrawDeposit(window.list)
assertEqual(false, window.confirmationUpdates[1].isActive, "CancelWithdrawDeposit disables confirmation mode through spinner update")

print("\n=== Test Summary ===")
print("Passed: " .. testsPassed)
print("Failed: " .. testsFailed)

if testsFailed > 0 then
    print("\nFAILED — see above for details")
    os.exit(1)
else
    print("\nAll tests passed!")
end
