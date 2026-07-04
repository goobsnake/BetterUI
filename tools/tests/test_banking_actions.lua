--[[
File: tools/tests/test_banking_actions.lua
Purpose: Covers banking action dialog filtering, junk actions, and refresh scheduling.

Usage:
  lua tools/tests/test_banking_actions.lua
]]

if false then
    dofile("Modules/Banking/Actions/BankingActions.lua")
end

BAG_BANK = 2
BAG_FURNITURE_VAULT = 100
SLOT_TYPE_BANK_ITEM = 5
SLOT_TYPE_GAMEPAD_INVENTORY_ITEM = 6
SI_ITEM_ACTION_MARK_AS_JUNK = "SI_ITEM_ACTION_MARK_AS_JUNK"
SI_ITEM_ACTION_UNMARK_AS_JUNK = "SI_ITEM_ACTION_UNMARK_AS_JUNK"
SI_BETTERUI_ACTION_MARK_AS_JUNK = "SI_BETTERUI_ACTION_MARK_AS_JUNK"
SI_BETTERUI_ACTION_UNMARK_AS_JUNK = "SI_BETTERUI_ACTION_UNMARK_AS_JUNK"
SI_ITEM_ACTION_STOW_ALL_FURNITURE = "SI_ITEM_ACTION_STOW_ALL_FURNITURE"
SI_BETTERUI_HEADER_SORT = "SI_BETTERUI_HEADER_SORT"
SI_ITEM_ACTION_REPORT_ITEM = "SI_ITEM_ACTION_REPORT_ITEM"
SI_ITEM_ACTION_LINK_TO_CHAT = "SI_ITEM_ACTION_LINK_TO_CHAT"
SI_ITEM_ACTION_BANK_WITHDRAW = "SI_ITEM_ACTION_BANK_WITHDRAW"
SI_ITEM_ACTION_BANK_DEPOSIT = "SI_ITEM_ACTION_BANK_DEPOSIT"
ZO_GAMEPAD_INVENTORY_ACTION_DIALOG = "ZO_GAMEPAD_INVENTORY_ACTION_DIALOG"

local testsPassed = 0
local testsFailed = 0

local scheduledTasks = {}
local callbackHandlers = {}
local parametricPopulateCalls = 0
local discoveredActions = {}
local bankingBag = BAG_BANK
local itemLocked = false
local itemJunk = false
local canMarkAsJunk = true
local sceneShowing = true
local stowAllFurnitureCount = 0
local releasedDialogCount = 0
local setJunkCalls = {}
local linkedItems = {}

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
    scheduledTasks = {}
    callbackHandlers = {}
    parametricPopulateCalls = 0
    discoveredActions = {}
    bankingBag = BAG_BANK
    itemLocked = false
    itemJunk = false
    canMarkAsJunk = true
    sceneShowing = true
    stowAllFurnitureCount = 0
    releasedDialogCount = 0
    setJunkCalls = {}
    linkedItems = {}
end

local function findEntryByFlag(entries, flag)
    for _, entry in ipairs(entries) do
        if entry.entryData and entry.entryData[flag] then
            return entry
        end
    end
    return nil
end

function GetString(id)
    local values = {
        [SI_ITEM_ACTION_MARK_AS_JUNK] = "Mark as Junk",
        [SI_ITEM_ACTION_UNMARK_AS_JUNK] = "Unmark as Junk",
        [SI_BETTERUI_ACTION_MARK_AS_JUNK] = "Mark as Junk",
        [SI_BETTERUI_ACTION_UNMARK_AS_JUNK] = "Unmark as Junk",
        [SI_ITEM_ACTION_STOW_ALL_FURNITURE] = "Stow All Furniture",
        [SI_BETTERUI_HEADER_SORT] = "Sort",
        [SI_ITEM_ACTION_REPORT_ITEM] = "Get Help",
        [SI_ITEM_ACTION_LINK_TO_CHAT] = "Link to Chat",
        [SI_ITEM_ACTION_BANK_WITHDRAW] = "Withdraw",
        [SI_ITEM_ACTION_BANK_DEPOSIT] = "Deposit",
    }
    return values[id] or tostring(id)
end

function zo_clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

function ZO_ClearNumericallyIndexedTable(tbl)
    for i = #tbl, 1, -1 do
        table.remove(tbl, i)
    end
end

ZO_GamepadEntryData = {
    New = function(text)
        return {
            text = text,
            GetText = function(self)
                return self.text
            end,
            SetIconTintOnSelection = function() end,
        }
    end,
}

function ZO_SharedGamepadEntry_OnSetup() end

function ZO_InventorySlot_DiscoverSlotActionsFromActionList(targetData, slotActions)
    discoveredActions = { targetData = targetData, slotActions = slotActions }
end

ZO_InventorySlotActions = {
    GetRawActionName = function(action)
        return action.rawName or action.name
    end,
}

function ZO_Dialogs_ReleaseDialogOnButtonPress()
    releasedDialogCount = releasedDialogCount + 1
end

function IsFurnitureVault(bagId)
    return bagId == BAG_FURNITURE_VAULT
end

function GetBankingBag()
    return bankingBag
end

function IsItemPlayerLocked()
    return itemLocked
end

function IsItemJunk()
    return itemJunk
end

function CanItemBeMarkedAsJunk()
    return canMarkAsJunk
end

function SetItemIsJunk(bagId, slotIndex, isJunk)
    table.insert(setJunkCalls, { bagId = bagId, slotIndex = slotIndex, isJunk = isJunk })
end

function StowAllFurnitureItems()
    stowAllFurnitureCount = stowAllFurnitureCount + 1
end

CALLBACK_MANAGER = {
    RegisterCallback = function(_, name, callback)
        callbackHandlers[name] = callback
    end,
}

HOUSING_EDITOR_STATE = {
    CanDepositIntoFurnitureVault = function()
        return true
    end,
}

BETTERUI = {
    Banking = {
        LIST_WITHDRAW = 1,
        LIST_DEPOSIT = 2,
        RuntimeState = {
            currentUsedBank = BAG_BANK,
            lastUsedBank = BAG_BANK,
        },
        GetTransferContext = function()
            local sourceBag = (bankingBag == nil or bankingBag == 0) and BAG_BANK or bankingBag
            local targetBag = (BETTERUI.Banking.RuntimeState.currentUsedBank == nil or BETTERUI.Banking.RuntimeState.currentUsedBank == 0)
                and BAG_BANK
                or BETTERUI.Banking.RuntimeState.currentUsedBank
            return {
                kind = sourceBag == BAG_GUILDBANK and "guild-bank"
                    or (sourceBag == BAG_BANK and "main-bank" or "house-bank"),
                interactionBag = sourceBag,
                depositTargetBag = targetBag,
                withdrawSourceBags = targetBag == BAG_BANK and { BAG_BANK, BAG_SUBSCRIBER_BANK } or { targetBag },
                sourceIsFurnitureVault = sourceBag == BAG_FURNITURE_VAULT,
                targetIsFurnitureVault = targetBag == BAG_FURNITURE_VAULT,
            }
        end,
        IsFurnitureVaultInteraction = function()
            return BETTERUI.Banking.GetTransferContext().sourceIsFurnitureVault == true
        end,
        IsSourceFurnitureVaultTransfer = function()
            return BETTERUI.Banking.GetTransferContext().sourceIsFurnitureVault == true
        end,
        ReadTransferContextSnapshot = function()
            return BETTERUI.Banking.GetTransferContext()
        end,
        ResolveWindowCategoryKey = function(window)
            if not window then return nil end
            if window.GetCurrentCategoryKey then return window:GetCurrentCategoryKey() end
            local categories = window.bankCategories
            if not categories or #categories == 0 then return nil end
            local index = window.currentCategoryIndex or 1
            if index > #categories then return nil end
            local category = categories[index]
            return category and category.key or nil
        end,
        RefreshWindowView = function(window, options)
            window:RefreshCategoryView(options)
        end,
        Tasks = {
            Schedule = function(_, name, delayMs, callback)
                scheduledTasks[name] = { delay = delayMs, callback = callback }
            end,
        },
        Class = {},
    },
    CIM = {
        HeaderNavigation = {
            GetOrCreateState = function(self)
                self.headerNavigationState = self.headerNavigationState or {}
                return self.headerNavigationState
            end,
        },
        ProtectionPolicy = {
            CanJunkItem = function()
                return canMarkAsJunk
            end,
            CanUnjunkItem = function()
                return true
            end,
        },
        PopulateActionEntries = function(parametricList, actions, options)
            parametricPopulateCalls = parametricPopulateCalls + 1
            for _, action in ipairs(actions) do
                local actionName = action.rawName or action.name
                if not (options.hideDestroy and actionName == "Destroy") and options.filterCallback(actionName) then
                    table.insert(parametricList, {
                        template = "ZO_GamepadItemEntryTemplate",
                        entryData = ZO_GamepadEntryData:New(actionName),
                    })
                end
            end
        end,
        HandleLinkToChat = function(itemData)
            table.insert(linkedItems, itemData)
        end,
    },
    Utils = {
        IsBankingSceneShowing = function()
            return sceneShowing
        end,
    },
}

dofile("Modules/Banking/Actions/BankingActions.lua")

local function createWindow()
    local slotActions = {
        Clear = function(self)
            self.cleared = true
        end,
        SetInventorySlot = function(self, slot)
            self.target = slot
        end,
    }

    local itemActions = {
        slotActions = slotActions,
        slots = {},
        selectedAction = nil,
        SetInventorySlot = function(self, slot)
            table.insert(self.slots, slot)
        end,
        GetSlotActions = function()
            return {
                { rawName = "Destroy" },
                { rawName = GetString(SI_ITEM_ACTION_MARK_AS_JUNK) },
                { rawName = GetString(SI_ITEM_ACTION_UNMARK_AS_JUNK) },
                { rawName = GetString(SI_ITEM_ACTION_REPORT_ITEM) },
                { rawName = GetString(SI_ITEM_ACTION_BANK_DEPOSIT) },
            }
        end,
        SetSelectedAction = function(self, action)
            self.selectedAction = action
        end,
        DoSelectedAction = function(self)
            self.didSelectedAction = true
        end,
    }

    local window = {
        currentMode = BETTERUI.Banking.LIST_DEPOSIT,
        bankCategories = { { key = "all" }, { key = "junk" } },
        currentCategoryIndex = 2,
        itemActions = itemActions,
        headerNavigationState = {},
        refreshListCount = 0,
        refreshActiveKeybindsCount = 0,
        rebuildHeaderCategoriesCount = 0,
        moveItemCalls = {},
        quantityDialogCalls = {},
        addKeybindsCount = 0,
        refreshItemActionsCount = 0,
        enterHeaderSortModeCount = 0,
        saveListPositionCount = 0,
        batchProcessing = false,
        list = {
            empty = false,
            selectedData = nil,
            IsEmpty = function(self)
                return self.empty
            end,
            GetSelectedData = function(self)
                return self.selectedData
            end,
        },
        GetList = function(self)
            return self.list
        end,
        IsBatchProcessing = function(self)
            return self.batchProcessing
        end,
        ComputeVisibleBankCategories = function()
            return {
                { key = "all" },
                { key = "junk" },
                { key = "materials" },
            }
        end,
        RefreshList = function(self)
            self.refreshListCount = self.refreshListCount + 1
        end,
        RefreshActiveKeybinds = function(self)
            self.refreshActiveKeybindsCount = self.refreshActiveKeybindsCount + 1
        end,
        RebuildHeaderCategories = function(self)
            self.rebuildHeaderCategoriesCount = self.rebuildHeaderCategoriesCount + 1
        end,
        RefreshCategoryView = function(self, options)
            self.bankCategories = self:ComputeVisibleBankCategories()
            local desiredCategoryIndex = 1
            if options and options.preferredCategoryKey then
                for i, category in ipairs(self.bankCategories) do
                    if category.key == options.preferredCategoryKey then
                        desiredCategoryIndex = i
                        break
                    end
                end
            end
            self.currentCategoryIndex = desiredCategoryIndex
            self.headerNavigationState.suppressHeaderCallback = true
            self:RebuildHeaderCategories()
            self.headerNavigationState.suppressHeaderCallback = false
            self:RefreshList()
            if options and options.refreshKeybinds then
                self:RefreshActiveKeybinds()
            end
        end,
        MoveItem = function(self, _, amount)
            table.insert(self.moveItemCalls, amount)
        end,
        ShowQuantityDialog = function(self, isDeposit)
            table.insert(self.quantityDialogCalls, isDeposit)
        end,
        SaveListPosition = function(self)
            self.saveListPositionCount = self.saveListPositionCount + 1
        end,
        AddKeybinds = function(self)
            self.addKeybindsCount = self.addKeybindsCount + 1
        end,
        EnterHeaderSortMode = function(self)
            self.enterHeaderSortModeCount = self.enterHeaderSortModeCount + 1
        end,
    }

    return setmetatable(window, { __index = BETTERUI.Banking.Class })
end

print("\n=== Banking action dialog behavior ===\n")

resetState()
local window = createWindow()
window.list.selectedData = { bagId = BAG_BANK, slotIndex = 4 }
window:RefreshItemActions()
assertEqual(window.list.selectedData, window.itemActions.slots[1], "RefreshItemActions forwards the current selection")

window = createWindow()
window.isInHeaderSortMode = true
window.list.selectedData = { bagId = BAG_BANK, slotIndex = 4 }
window:RefreshItemActions()
assertEqual(0, #window.itemActions.slots, "RefreshItemActions is skipped in header sort mode")

window = createWindow()
bankingBag = BAG_FURNITURE_VAULT
assertTrue(window:IsFurnitureVaultContext(), "Furniture vault context is detected from the live interaction bag")

resetState()
window = createWindow()
window:RequestJunkCategoryRefresh(90, "materials")
assertEqual(90, scheduledTasks.junkCategoryRefresh.delay, "Junk refresh uses the requested delay")
scheduledTasks.junkCategoryRefresh.callback()
assertEqual(1, window.rebuildHeaderCategoriesCount, "Junk refresh rebuilds header categories")
assertEqual(1, window.refreshListCount, "Junk refresh refreshes the list")
assertEqual(1, window.refreshActiveKeybindsCount, "Junk refresh refreshes active keybinds")
assertEqual(3, window.currentCategoryIndex, "Junk refresh preserves the preferred category when it still exists")
assertEqual(false, window.headerNavigationState.suppressHeaderCallback, "Junk refresh releases header callback suppression")

resetState()
window = createWindow()
window.batchProcessing = true
window:RequestJunkCategoryRefresh(90, "junk")
scheduledTasks.junkCategoryRefresh.callback()
assertEqual(120, scheduledTasks.junkCategoryRefresh.delay, "Junk refresh reschedules while batch processing is active")

resetState()
window = createWindow()
window:InitializeActionsDialog()
assertTrue(callbackHandlers.BETTERUI_EVENT_ACTION_DIALOG_SETUP ~= nil, "InitializeActionsDialog registers setup callback")
assertTrue(callbackHandlers.BETTERUI_EVENT_ACTION_DIALOG_FINISH ~= nil, "InitializeActionsDialog registers finish callback")
assertTrue(callbackHandlers.BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM ~= nil, "InitializeActionsDialog registers confirm callback")

window.list.selectedData = { bagId = BAG_BANK, slotIndex = 9, stackCount = 5 }
bankingBag = BAG_FURNITURE_VAULT
local dialog
dialog = {
    info = { parametricList = {} },
    entryList = {
        SetOnSelectedDataChangedCallback = function(_, callback)
            dialog.selectionChangedCallback = callback
        end,
        GetTargetData = function()
            return dialog.selectedEntry
        end,
    },
    setupFunc = function()
        dialog.didSetup = true
    end,
}

callbackHandlers.BETTERUI_EVENT_ACTION_DIALOG_SETUP(dialog)
assertTrue(dialog.didSetup == true, "Action dialog setup delegates to dialog setup function")
assertEqual(1, parametricPopulateCalls, "Action dialog setup populates filtered actions")
assertTrue(findEntryByFlag(dialog.info.parametricList, "isBetterUIStowAllFurniture") ~= nil, "Action dialog adds stow-all furniture action")
assertTrue(findEntryByFlag(dialog.info.parametricList, "isBetterUIStackTransfer") ~= nil, "Action dialog adds stack transfer action")
assertTrue(findEntryByFlag(dialog.info.parametricList, "isSortAction") ~= nil, "Action dialog adds sort action")
assertEqual(SLOT_TYPE_GAMEPAD_INVENTORY_ITEM, window.list.selectedData.slotType, "Action discovery normalizes deposit slot type")

bankingBag = BAG_BANK
dialog.selectedEntry = {
    isBetterUIBankJunkToggle = true,
    targetData = { bagId = BAG_BANK, slotIndex = 9 },
    markAsJunk = true,
}
callbackHandlers.BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM(dialog)
assertEqual(true, setJunkCalls[1].isJunk, "Action dialog can mark an item as junk")
assertEqual(1, releasedDialogCount, "Action dialog closes after junk toggle")

dialog.selectedEntry = {
    isBetterUIStackTransfer = true,
    stackCount = 8,
}
callbackHandlers.BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM(dialog)
assertEqual(8, window.moveItemCalls[#window.moveItemCalls], "Action dialog moves the requested stack count")

dialog.selectedEntry = {
    isSortAction = true,
    sortContext = window,
}
callbackHandlers.BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM(dialog)
assertEqual(1, window.enterHeaderSortModeCount, "Action dialog can enter header sort mode")

dialog.selectedEntry = {
    isBetterUIStowAllFurniture = true,
}
callbackHandlers.BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM(dialog)
assertEqual(1, stowAllFurnitureCount, "Action dialog can stow all furniture")

sceneShowing = true
window.isInHeaderSortMode = false
callbackHandlers.BETTERUI_EVENT_ACTION_DIALOG_FINISH(dialog)
assertEqual(1, window.addKeybindsCount, "Action dialog finish restores banking keybinds")

print("\n=== Test Summary ===")
print("Passed: " .. testsPassed)
print("Failed: " .. testsFailed)

if testsFailed > 0 then
    print("\nFAILED — see above for details")
    os.exit(1)
else
    print("\nAll tests passed!")
end
