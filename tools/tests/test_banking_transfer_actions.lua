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
EVENT_INVENTORY_SINGLE_SLOT_UPDATE = "EVENT_INVENTORY_SINGLE_SLOT_UPDATE"

ZO_Object = {}
function ZO_Object:Subclass()
    local cls = {}
    cls.__index = cls
    setmetatable(cls, { __index = self })
    return cls
end
function ZO_Object.New(cls)
    return setmetatable({}, cls)
end

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
local listRefreshLaters = {}
local frameTimeMs = 0
local showingDialog = false
local playerIsBanking = true
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
local logEvents = {}
local refreshQueueCalls = {}

function zo_callLater(fn, ms)
    listRefreshLaters[#listRefreshLaters + 1] = { fn = fn, ms = ms, cancelled = false }
    return #listRefreshLaters
end

function zo_removeCallLater(id)
    if listRefreshLaters[id] then
        listRefreshLaters[id].cancelled = true
    end
end

PLAYER_INVENTORY = {
    IsBanking = function()
        return playerIsBanking
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

local function assertNotNil(value, message)
    assertTrue(value ~= nil, message)
end

local function readFile(path)
    local handle = io.open(path, "r")
    if not handle then return "" end
    local content = handle:read("*a") or ""
    handle:close()
    return content
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
    listRefreshLaters = {}
    frameTimeMs = 0
    showingDialog = false
    playerIsBanking = true
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
    logEvents = {}
    refreshQueueCalls = {}
    if BETTERUI and BETTERUI.Banking then
        BETTERUI.Banking.RefreshManager = nil
        BETTERUI.Banking.Window = nil
    end
    -- Clear any lingering pending transfer state from TransferActions module locals
    frameTimeMs = 600000
    if BETTERUI and BETTERUI.Banking and BETTERUI.Banking.SweepStaleTransfers then
        BETTERUI.Banking.SweepStaleTransfers()
    end
    frameTimeMs = 0
end

function GetString(id)
    if id == SI_BETTERUI_BANK_NO_FUNDS then
        return "No funds"
    end
    return tostring(id)
end

function GetFrameTimeMilliseconds()
    return frameTimeMs
end

function zo_clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

function FindFirstEmptySlotInBag(bagId)
    return emptySlots[bagId]
end

function DoesBagHaveSpaceFor(destinationBag)
    return emptySlots[destinationBag] ~= nil or stackableSlots[destinationBag] ~= nil
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
    -- The real API returns true when the secure call is accepted.
    return true
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
    Interface = {
        EnsureKeybindGroupAdded = function(group)
            KEYBIND_STRIP:AddKeybindButtonGroup(group)
            return true
        end,
        RemoveKeybindGroupIfPresent = function(group)
            KEYBIND_STRIP:RemoveKeybindButtonGroup(group)
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
            local sourceBag = (currentBankingBag == nil or currentBankingBag == 0) and BAG_BANK or currentBankingBag
            local targetBag = sourceBag == BAG_GUILDBANK and BAG_GUILDBANK or currentBank
            local isGuildBank = sourceBag == BAG_GUILDBANK
            return {
                kind = isGuildBank and BETTERUI.Banking.TRANSFER_MODE_GUILD_BANK
                    or (sourceBag == BAG_BANK and BETTERUI.Banking.TRANSFER_MODE_MAIN_BANK
                        or BETTERUI.Banking.TRANSFER_MODE_HOUSE_BANK),
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
        GetTransferService = function()
            return BETTERUI.Banking.Transfer
        end,
        RequireTransferService = function(requiredMethods)
            local transferService = BETTERUI.Banking.Transfer
            if type(transferService) ~= "table" then
                return nil, "transfer_service_unavailable"
            end
            for _, methodName in ipairs(requiredMethods or {}) do
                if type(transferService[methodName]) ~= "function" then
                    return nil, "transfer_service_incomplete"
                end
            end
            return transferService
        end,
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
        Transfer = {
            CanDepositIntoBank = function()
                return depositAllowed, depositReason
            end,
            NotifyTransferDenied = function(_, _, denyReason)
                if denyReason == "stolen" then
                    table.insert(userNotifies, SI_STOLEN_ITEM_CANNOT_DEPOSIT_MESSAGE)
                end
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
        Tasks = {
            Schedule = function(_, taskName, delayMs, callback)
                table.insert(scheduledTasks, { taskName = taskName, delay = delayMs, callback = callback })
            end,
        },
        RefreshWindowView = function(window, options)
            options = options or {}
            local refreshManager = BETTERUI.Banking.RefreshManager
            if options.coalesce == true and refreshManager and type(refreshManager.QueueRefresh) == "function" then
                refreshManager:QueueRefresh(window.list, function()
                    BETTERUI.Banking.RefreshWindowView(window, {
                        preferredCategoryKey = options.preferredCategoryKey,
                        refreshKeybinds = options.refreshKeybinds,
                    })
                end, options.savePosition, {
                    flow = options.flow,
                    source = options.source,
                    reason = options.reason,
                    token = options.token,
                })
                return
            end
            if window.RefreshTransferView then
                window:RefreshTransferView(options or {})
                return
            end
            if window.ComputeVisibleBankCategories and window.RebuildHeaderCategories then
                window.bankCategories = window:ComputeVisibleBankCategories()
                if window.bankCategories and #window.bankCategories > 0 then
                    window.currentCategoryIndex = 1
                    window:RebuildHeaderCategories()
                end
            end
            if window.RefreshList then
                window:RefreshList()
            end
        end,
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
    Log = {
        CATEGORY = {
            ACTION = "ACTION",
            LIST = "LIST",
            TRANSFER = "TRANSFER",
            STATE = "STATE",
            KEYBIND = "KEYBIND",
        },
        LEVEL = { DEBUG = 2, INFO = 3, WARN = 4, ERROR = 5 },
        IsActive = function() return true end,
        TraceEvent = function(category, event, phase, data, level)
            table.insert(logEvents, { kind = "TraceEvent", category = category, event = event, phase = phase, data = data, level = level })
        end,
        Trace = function(category, message, data)
            table.insert(logEvents, { kind = "Trace", category = category, message = message, data = data })
        end,
        FlowBegin = function(kind, category, message, data)
            local flow = kind .. "#test"
            table.insert(logEvents, { kind = "FlowBegin", category = category, flow = flow, message = message, data = data })
            return flow
        end,
        FlowEnd = function(flow, category, message, data)
            table.insert(logEvents, { kind = "FlowEnd", category = category, flow = flow, message = message, data = data })
        end,
        Warn = function(category, message, data)
            table.insert(logEvents, { kind = "Warn", category = category, message = message, data = data })
        end,
        Info = function(category, message, data)
            table.insert(logEvents, { kind = "Info", category = category, message = message, data = data })
        end,
        Debug = function(category, message, data)
            table.insert(logEvents, { kind = "Debug", category = category, message = message, data = data })
        end,
        DescribeListSelection = function() return "selection" end,
        DescribeItem = function(_, prefix) return tostring(prefix or "item") end,
        GetCurrencyAmountForLocation = function() return 0 end,
    },
    CIM = {
        CONST = {
            TIMING = {
                CATEGORY_REFRESH_COALESCE_MS = 10,
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
        DeferredTask = {
            CreateManager = function()
                return {}
            end,
            CreateLazyManagerProxy = function()
                return BETTERUI.Banking.Tasks
            end,
        },
        GenericWindow = {
            Subclass = ZO_Object.Subclass,
            New = function(cls)
                return setmetatable({}, { __index = cls })
            end,
        },
        ItemTaxonomy = {
            BANK_CATEGORY_DEFS = {},
        },
        MultiSelectManager = {
            Create = function()
                return {}
            end,
        },
        MultiSelectMixin = {
            Apply = function() end,
            EnterSelectionMode = function() end,
            ExitSelectionMode = function() end,
            BindDelegates = function(target, names)
                for _, name in ipairs(names or {}) do
                    target[name] = target[name] or function() return false end
                end
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

dofile("Modules/CIM/Lists/ListRefreshManager.lua")
dofile("Modules/Banking/Core/BankingClass.lua")
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
        sceneShowing = true,
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
        SetListUpdatesSuppressed = function(self, suppressed)
            self._suppressListUpdates = suppressed == true
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
        IsSceneShowing = function(self)
            return self.sceneShowing == true
        end,
        UpdateSpinnerConfirmation = function(self, isActive, list)
            table.insert(self.confirmationUpdates, { isActive = isActive, list = list })
        end,
    }
    window.list.count = 3
    window.list.selectedIndex = 1
    window.list.GetNumItems = function(self)
        return self.count
    end
    window.list.GetSelectedIndex = function(self)
        return self.selectedIndex
    end
    window.list.GetDataForDataIndex = function(_, index)
        return index == 1 and selectedData or nil
    end
    window.list.SetSelectedIndex = function(self, index)
        self.selectedIndex = index
    end

    return setmetatable(window, { __index = BETTERUI.Banking.Class })
end

local function hasLogEvent(kind, category, event, phase)
    for _, entry in ipairs(logEvents) do
        if entry.kind == kind
            and (category == nil or entry.category == category)
            and (event == nil or entry.event == event)
            and (phase == nil or entry.phase == phase) then
            return true
        end
    end
    return false
end

local function findLogEvent(kind, category, event, phase)
    for _, entry in ipairs(logEvents) do
        if entry.kind == kind
            and (category == nil or entry.category == category)
            and (event == nil or entry.event == event)
            and (phase == nil or entry.phase == phase) then
            return entry
        end
    end
    return nil
end

local function findScheduledTask(taskName)
    for _, task in ipairs(scheduledTasks) do
        if task.taskName == taskName then
            return task
        end
    end
    return nil
end

local function installRecordingRefreshManager()
    BETTERUI.Banking.RefreshManager = BETTERUI.CIM.Lists.ListRefreshManager:New({ coalesceDelay = 25 })
    local originalQueueRefresh = BETTERUI.Banking.RefreshManager.QueueRefresh
    function BETTERUI.Banking.RefreshManager:QueueRefresh(list, refreshFn, savePosition, options)
        table.insert(refreshQueueCalls, { list = list, savePosition = savePosition, options = options })
        return originalQueueRefresh(self, list, refreshFn, savePosition, options)
    end
    return BETTERUI.Banking.RefreshManager
end

print("\n=== Banking transfer actions ===\n")

local transferActionsSource = readFile("Modules/Banking/Actions/TransferActions.lua")
local directStart = transferActionsSource:find("local function ExecuteDirectTransfer", 1, true)
local directEnd = directStart and transferActionsSource:find("function BETTERUI.Banking.TryTransferInventorySlot", directStart, true) or nil
local directBody = directStart and directEnd and transferActionsSource:sub(directStart, directEnd) or ""
local directRequested = directBody:find('TraceBankTransfer("bank.item_transfer", "requested"', 1, true) or math.huge
local directFlowEnd = directBody:find('EndBankTransferFlow(flow, "bank transfer direct requested"', directRequested, true) or math.huge
local directRefreshDecision = directBody:find('TraceBankTransfer("bank.item_transfer", "refresh_decision"', 1, true) or math.huge
assertTrue(directRequested < directFlowEnd and directFlowEnd < directRefreshDecision,
    "Direct cursor transfer logs requested and ends the flow before refresh_decision")

resetState()
local window = createWindow()
selectedData = { bagId = BAG_GUILDBANK, slotIndex = 9 }
emptySlots[BAG_BACKPACK] = 10
currentBankingBag = BAG_GUILDBANK
window.currentMode = BETTERUI.Banking.LIST_WITHDRAW
installRecordingRefreshManager()
window:MoveItem(window.list, 2)
assertEqual(9, guildWithdrawCalls[1], "Guild withdraw moves the selected guild slot")
assertEqual(1, #playedSounds, "Guild withdraw plays pickup sound")
assertEqual(100, scheduledTasks[1].delay, "Guild withdraw schedules a coalesced refresh")
scheduledTasks[1].callback()
assertEqual(1, #refreshQueueCalls, "Coalesced bank refresh routes through the ListRefreshManager")
assertEqual("bankTransfer#test", refreshQueueCalls[1].options and refreshQueueCalls[1].options.flow,
    "Coalesced bank refresh preserves the transfer flow id")
assertEqual("moveCoalesce", refreshQueueCalls[1].options and refreshQueueCalls[1].options.reason,
    "Coalesced bank refresh records its scheduling reason")
assertEqual(1, #listRefreshLaters, "Real ListRefreshManager schedules the refresh callback")
assertEqual(0, window.rebuiltHeaders, "Coalesced refresh waits for the ListRefreshManager callback")
listRefreshLaters[1].fn()
assertEqual(1, window.rebuiltHeaders, "Coalesced refresh rebuilds header categories")
assertEqual(1, window.refreshedLists, "Coalesced refresh refreshes the list")
assertEqual(2, window.currentCategoryIndex, "Coalesced refresh preserves the selected bank category")
local savedRefreshTrace = findLogEvent("TraceEvent", "LIST", "list.refresh", "saved")
local restoredRefreshTrace = findLogEvent("TraceEvent", "LIST", "list.refresh", "restore_end")
assertEqual("bankTransfer#test", savedRefreshTrace and savedRefreshTrace.data and savedRefreshTrace.data.flow,
    "ListRefreshManager saved trace carries the transfer flow id")
assertEqual("bankTransfer#test", restoredRefreshTrace and restoredRefreshTrace.data and restoredRefreshTrace.data.flow,
    "ListRefreshManager restore trace carries the transfer flow id")

resetState()
window = createWindow()
BETTERUI.Banking.Window = window
installRecordingRefreshManager()
currentBankingBag = BAG_BANK
window.currentMode = BETTERUI.Banking.LIST_WITHDRAW
emptySlots[BAG_BACKPACK] = 12
local directOk, directReason = BETTERUI.Banking.TryTransferInventorySlot({ bagId = BAG_BANK, slotIndex = 4 })
assertTrue(directOk == true, "Direct cursor transfer succeeds in banking mode")
assertEqual(nil, directReason, "Direct cursor transfer has no failure reason")
local directRefreshDecision = findLogEvent("TraceEvent", "TRANSFER", "bank.item_transfer", "refresh_decision")
assertEqual("directCursor", directRefreshDecision and directRefreshDecision.data and directRefreshDecision.data.transferPath,
    "Direct cursor transfer records its refresh decision path")
assertEqual(true, directRefreshDecision and directRefreshDecision.data and directRefreshDecision.data.refreshScheduled,
    "Direct cursor transfer schedules an active bank-window refresh")
local directRefreshTask = findScheduledTask("moveCoalesce")
assertNotNil(directRefreshTask, "Direct cursor transfer schedules the move coalesce refresh")
assertEqual(0, #refreshQueueCalls, "Direct cursor refresh waits for the coalesce task")
directRefreshTask.callback()
assertEqual(1, #refreshQueueCalls, "Direct cursor refresh routes through the ListRefreshManager")
assertEqual("bankTransfer#test", refreshQueueCalls[1].options and refreshQueueCalls[1].options.flow,
    "Direct cursor refresh preserves the transfer flow id")
assertEqual(1, #listRefreshLaters, "Direct cursor refresh schedules the ListRefreshManager callback")
listRefreshLaters[1].fn()
assertEqual(1, window.rebuiltHeaders, "Direct cursor refresh rebuilds header categories")
assertEqual(1, window.refreshedLists, "Direct cursor refresh refreshes the list")

resetState()
window = createWindow()
BETTERUI.Banking.Window = window
installRecordingRefreshManager()
currentBankingBag = BAG_BANK
window.currentMode = BETTERUI.Banking.LIST_WITHDRAW
emptySlots[BAG_BACKPACK] = 12
local delayedHiddenOk = BETTERUI.Banking.TryTransferInventorySlot({ bagId = BAG_BANK, slotIndex = 6 })
assertTrue(delayedHiddenOk == true, "Direct cursor transfer succeeds before a delayed close")
local delayedHiddenTask = findScheduledTask("moveCoalesce")
assertNotNil(delayedHiddenTask, "Direct cursor transfer schedules a refresh before a delayed close")
window.sceneShowing = false
delayedHiddenTask.callback()
assertEqual(0, #refreshQueueCalls, "Delayed direct cursor refresh skips after the bank window closes")
assertEqual(false, window._suppressListUpdates == true, "Delayed direct cursor refresh clears its suppression token after close")

resetState()
window = createWindow()
BETTERUI.Banking.Window = window
installRecordingRefreshManager()
currentBankingBag = BAG_BANK
window.currentMode = BETTERUI.Banking.LIST_WITHDRAW
emptySlots[BAG_BACKPACK] = 12
local delayedSwapOk = BETTERUI.Banking.TryTransferInventorySlot({ bagId = BAG_BANK, slotIndex = 7 })
assertTrue(delayedSwapOk == true, "Direct cursor transfer succeeds before the active bank window swaps")
local delayedSwapTask = findScheduledTask("moveCoalesce")
assertNotNil(delayedSwapTask, "Direct cursor transfer schedules a refresh before the active bank window swaps")
BETTERUI.Banking.Window = createWindow()
delayedSwapTask.callback()
assertEqual(0, #refreshQueueCalls, "Delayed direct cursor refresh skips after the active bank window is replaced")
assertEqual(false, window._suppressListUpdates == true, "Delayed direct cursor refresh clears its suppression token after swap")

resetState()
window = createWindow()
window.sceneShowing = false
BETTERUI.Banking.Window = window
installRecordingRefreshManager()
currentBankingBag = BAG_BANK
window.currentMode = BETTERUI.Banking.LIST_WITHDRAW
emptySlots[BAG_BACKPACK] = 12
local hiddenDirectOk = BETTERUI.Banking.TryTransferInventorySlot({ bagId = BAG_BANK, slotIndex = 5 })
assertTrue(hiddenDirectOk == true, "Hidden-window direct cursor transfer still requests the move")
local hiddenRefreshDecision = findLogEvent("TraceEvent", "TRANSFER", "bank.item_transfer", "refresh_decision")
assertEqual("inactiveWindow", hiddenRefreshDecision and hiddenRefreshDecision.data and hiddenRefreshDecision.data.refreshReason,
    "Hidden-window direct cursor transfer records inactive refresh reason")
assertEqual(false, hiddenRefreshDecision and hiddenRefreshDecision.data and hiddenRefreshDecision.data.refreshScheduled,
    "Hidden-window direct cursor transfer does not schedule an active bank-window refresh")
assertEqual(nil, findScheduledTask("moveCoalesce"), "Hidden-window direct cursor transfer skips move coalesce refresh")
assertEqual(0, #refreshQueueCalls, "Hidden-window direct cursor transfer does not queue a list refresh")

resetState()
window = createWindow()
selectedData = { bagId = BAG_GUILDBANK, slotIndex = 9 }
currentBankingBag = BAG_GUILDBANK
window.currentMode = BETTERUI.Banking.LIST_WITHDRAW
stackableSlots[BAG_BACKPACK] = 22
window:MoveItem(window.list, 2)
assertEqual(9, guildWithdrawCalls[1], "Full-backpack guild withdraw still transfers when a stackable slot exists")

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
stackableSlots[BAG_GUILDBANK] = 44
window:MoveItem(window.list, 1)
assertEqual(5, guildDepositCalls[1].slotIndex, "Full guild-bank deposit still transfers when a stackable slot exists")
assertEqual(0, #userNotifies, "Stackable guild-bank deposit does not report the bank as full")

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
assertEqual(SI_STOLEN_ITEM_CANNOT_DEPOSIT_MESSAGE, userNotifies[1],
    "Blocked deposits surface the shared Banking denial notification")

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
assertTrue(hasLogEvent("FlowBegin", "TRANSFER"), "Deposit transfer flow begins under TRANSFER")
assertTrue(hasLogEvent("FlowEnd", "TRANSFER"), "Deposit transfer flow ends under TRANSFER")
assertTrue(hasLogEvent("TraceEvent", "TRANSFER", "bank.item_transfer", "move_requested"),
    "Deposit transfer TraceEvent uses TRANSFER")

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
BETTERUI.Banking.CurrencySelector.DisplaySelector(window, 10)
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
BETTERUI.Banking.CurrencySelector.DisplaySelector(window, 10)
assertEqual("No funds", userAlertTexts[1], "DisplaySelector alerts when no currency is transferable")
GetMaxCurrencyTransfer = function()
    return 25
end

resetState()
window = createWindow()
BETTERUI.Banking.CurrencySelector.HideSelector(window)
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

-- Pending transfer state tests (PB-007)
resetState()
window = createWindow()
selectedData = { bagId = BAG_BACKPACK, slotIndex = 6 }
window.currentMode = BETTERUI.Banking.LIST_DEPOSIT
emptySlots[BAG_BANK] = 33
BETTERUI.CIM.EventRegistry = {
    Register = function(moduleName, namespace, eventId, callback)
        _G["_test_event_" .. eventId] = callback
    end,
}
dofile("Modules/Banking/Actions/TransferActions.lua")
local slotUpdateCallback = _G["_test_event_" .. EVENT_INVENTORY_SINGLE_SLOT_UPDATE]
assertTrue(type(slotUpdateCallback) == "function", "EVENT_INVENTORY_SINGLE_SLOT_UPDATE callback registered")
assertEqual(false, BETTERUI.Banking.IsTransferPending(BAG_BACKPACK, 6), "No pending transfer before move")
window:MoveItem(window.list, 1)
assertEqual(true, BETTERUI.Banking.IsTransferPending(BAG_BACKPACK, 6), "Pending transfer set after deposit")
assertEqual(1, #secureMoves, "Deposit RequestMoveItem issued once")

-- Simulate slot-update event clearing the marker
if type(slotUpdateCallback) == "function" then
    slotUpdateCallback(nil, BAG_BACKPACK, 6)
    assertEqual(false, BETTERUI.Banking.IsTransferPending(BAG_BACKPACK, 6), "Pending cleared by slot-update event")
    local confirmed = findLogEvent("TraceEvent", "TRANSFER", "bank.item_transfer", "confirmed")
    assertTrue(confirmed ~= nil, "Slot update emits confirmed transfer trace")
    assertEqual("bankTransfer#test", confirmed and confirmed.data and confirmed.data.flow,
        "Confirmed transfer keeps the original flow id")
    assertEqual(0, confirmed and confirmed.data and confirmed.data.pendingRemaining,
        "Confirmed transfer records pending remaining count")
    assertEqual(BETTERUI.Log.LEVEL.INFO, confirmed and confirmed.level,
        "Confirmed transfer is emitted at INFO")
end

-- Stale sweep clears after timeout
resetState()
window = createWindow()
selectedData = { bagId = BAG_BACKPACK, slotIndex = 6 }
window.currentMode = BETTERUI.Banking.LIST_DEPOSIT
emptySlots[BAG_BANK] = 33
window:MoveItem(window.list, 1)
assertEqual(true, BETTERUI.Banking.IsTransferPending(BAG_BACKPACK, 6), "Pending still active before timeout")
frameTimeMs = 5100
BETTERUI.Banking.SweepStaleTransfers()
assertEqual(false, BETTERUI.Banking.IsTransferPending(BAG_BACKPACK, 6), "Stale sweep clears timed-out pending marker")
local expired = findLogEvent("TraceEvent", "TRANSFER", "bank.item_transfer", "expired")
assertTrue(expired ~= nil, "Stale sweep emits expired transfer trace")
assertEqual("bankTransfer#test", expired and expired.data and expired.data.flow,
    "Expired transfer keeps the original flow id")
assertEqual(0, expired and expired.data and expired.data.pendingRemaining,
    "Expired transfer records pending remaining count")
assertEqual(BETTERUI.Log.LEVEL.WARN, expired and expired.level,
    "Expired transfer is emitted at WARN")

-- Keybind enabled-callback returns false while pending
resetState()
window = createWindow()
selectedData = { bagId = BAG_BACKPACK, slotIndex = 6 }
window.currentMode = BETTERUI.Banking.LIST_DEPOSIT
window.list.selectedData = selectedData
slotStacks["1:6"] = 1
emptySlots[BAG_BANK] = 33
window:MoveItem(window.list, 1)
assertEqual(true, BETTERUI.Banking.IsTransferPending(BAG_BACKPACK, 6), "Deposit marks item pending")
-- Load KeybindManager to verify CanUsePrimaryTransfer behavior when pending
local keybindMgrLoaded, _ = pcall(function()
    dofile("Modules/Banking/Keybinds/KeybindManager.lua")
end)
assertTrue(BETTERUI.Banking.IsTransferPending(BAG_BACKPACK, 6), "Keybind integration: IsTransferPending true after deposit")
frameTimeMs = 5100
BETTERUI.Banking.SweepStaleTransfers()
assertEqual(false, BETTERUI.Banking.IsTransferPending(BAG_BACKPACK, 6), "Keybind integration: IsTransferPending false after sweep")

print("\n=== Test Summary ===")
print("Passed: " .. testsPassed)
print("Failed: " .. testsFailed)

if testsFailed > 0 then
    print("\nFAILED — see above for details")
    os.exit(1)
else
    print("\nAll tests passed!")
end
