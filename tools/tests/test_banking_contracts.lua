--[[
File: tools/tests/test_banking_contracts.lua
Purpose: Verifies the banking bag contract and structural cleanup invariants for
         the banking contract cleanup cluster.

Usage:
  lua tools/tests/test_banking_contracts.lua
]]

if false then
    dofile("Modules/Banking/Core/BankingClass.lua")
end

BAG_BANK = 2
BAG_SUBSCRIBER_BANK = 6
BAG_GUILDBANK = 3

local sceneShowing = true

BETTERUI = {
    Banking = {},
    Inventory = {
        Categories = {
            Bank = {},
        },
    },
    CIM = {
        ItemTaxonomy = {
            BANK_CATEGORY_DEFS = {},
        },
        DeferredTask = {
            Manager = {
                New = function()
                    return {}
                end,
            },
            CreateManager = function()
                return {}
            end,
            CreateLazyManagerProxy = function(factory)
                return {
                    __factory = factory,
                }
            end,
        },
        Utils = {
            CompareNils = function()
                return nil
            end,
        },
        GenericWindow = {
            Subclass = function()
                return {}
            end,
            New = function(self, ...)
                return setmetatable({
                    _newArgs = { ... },
                }, { __index = self })
            end,
        },
        UnifiedFooter = {
            MODE = {
                BANKING = "banking",
            },
        },
        UI = {
            HeaderSortController = {
                SORT_DIRECTION = {
                    NONE = "none",
                    ASCENDING = "ascending",
                    DESCENDING = "descending",
                },
            },
        },
        MultiSelectMixin = {
            Apply = function() end,
            BindDelegates = function(target, methodNames)
                for _, methodName in ipairs(methodNames or {}) do
                    target[methodName] = BETTERUI.CIM.MultiSelectMixin[methodName]
                end
            end,
            EnterSelectionMode = function() end,
            ExitSelectionMode = function() end,
            OnSelectionCountChanged = function() end,
            IsInSelectionMode = function()
                return false
            end,
            IsBatchProcessing = function()
                return false
            end,
            CanAbortBatch = function()
                return false
            end,
            RequestBatchAbort = function()
                return false
            end,
            ProcessBatchThrottled = function() end,
            BatchLock = function() end,
            BatchUnlock = function() end,
            BatchMarkAsJunk = function() end,
            BatchUnmarkAsJunk = function() end,
        },
    },
    Interface = {
        EnsureKeybindGroupAdded = function() end,
        CreateSearchKeybindDescriptor = function() end,
    },
    Utils = {
        IsBankingSceneShowing = function()
            return sceneShowing
        end,
    },
}

local testsPassed = 0
local testsFailed = 0

local function assertTrue(condition, message)
    if condition then
        testsPassed = testsPassed + 1
        print("  [OK] " .. message)
    else
        testsFailed = testsFailed + 1
        print("  [FAILED] " .. message)
    end
end

local function assertEqual(expected, actual, message)
    assertTrue(expected == actual, string.format("%s (expected %s, got %s)", message, tostring(expected), tostring(actual)))
end

local function readFile(path)
    local file = assert(io.open(path, "r"))
    local content = file:read("*a")
    file:close()
    return content
end

local function asWindow(window)
    return setmetatable(window, { __index = BETTERUI.Banking.Class })
end

print("\n=== Banking contract cleanup tests ===\n")

dofile("Modules/Banking/Core/BankingClass.lua")

assertTrue(BETTERUI.Banking.ResolveBankBag == nil, "ResolveBankBag is no longer a public banking helper")
assertTrue(type(BETTERUI.Banking.GetTransferSourceBag) == "function",
    "GetTransferSourceBag is the explicit transfer source helper")
assertTrue(type(BETTERUI.Banking.GetTransferTargetBag) == "function",
    "GetTransferTargetBag is the explicit transfer destination helper")
assertTrue(type(BETTERUI.Banking.GetTransferWithdrawSourceBags) == "function",
    "GetTransferWithdrawSourceBags is the explicit transfer-source bag helper")
assertTrue(type(BETTERUI.Banking.GetActiveTransferContext) == "function", "GetActiveTransferContext helper is exposed")
assertTrue(BETTERUI.Banking.GetTransferSourceBankBag == nil,
    "Deprecated GetTransferSourceBankBag wrapper has been removed")
assertTrue(BETTERUI.Banking.GetTransferDestinationBankBag == nil,
    "Deprecated GetTransferDestinationBankBag wrapper has been removed")
assertTrue(BETTERUI.Banking.IsFurnitureVaultTransferSource == nil,
    "Deprecated IsFurnitureVaultTransferSource wrapper has been removed")
assertTrue(BETTERUI.Banking.ResolveTransferSupport == nil,
    "ResolveTransferSupport wrapper has been removed in favor of RequireTransferSupport")
assertEqual(BAG_BANK, BETTERUI.Banking.lastUsedBank, "lastUsedBank starts aligned with the normalized default bank")
assertEqual(BETTERUI.CIM.MultiSelectMixin.OnSelectionCountChanged, BETTERUI.Banking.Class.OnSelectionCountChanged,
    "BankingClass aliases OnSelectionCountChanged directly to the shared multi-select mixin")
assertEqual(BETTERUI.CIM.MultiSelectMixin.IsInSelectionMode, BETTERUI.Banking.Class.IsInSelectionMode,
    "BankingClass aliases IsInSelectionMode directly to the shared multi-select mixin")
assertEqual(BETTERUI.CIM.MultiSelectMixin.IsBatchProcessing, BETTERUI.Banking.Class.IsBatchProcessing,
    "BankingClass aliases IsBatchProcessing directly to the shared multi-select mixin")
assertEqual(BETTERUI.CIM.MultiSelectMixin.CanAbortBatch, BETTERUI.Banking.Class.CanAbortBatch,
    "BankingClass aliases CanAbortBatch directly to the shared multi-select mixin")
assertEqual(BETTERUI.CIM.MultiSelectMixin.RequestBatchAbort, BETTERUI.Banking.Class.RequestBatchAbort,
    "BankingClass aliases RequestBatchAbort directly to the shared multi-select mixin")
assertEqual(BETTERUI.CIM.MultiSelectMixin.ProcessBatchThrottled, BETTERUI.Banking.Class.ProcessBatchThrottled,
    "BankingClass aliases ProcessBatchThrottled directly to the shared multi-select mixin")
assertEqual(BETTERUI.CIM.MultiSelectMixin.BatchLock, BETTERUI.Banking.Class.BatchLock,
    "BankingClass aliases BatchLock directly to the shared multi-select mixin")
assertEqual(BETTERUI.CIM.MultiSelectMixin.BatchUnlock, BETTERUI.Banking.Class.BatchUnlock,
    "BankingClass aliases BatchUnlock directly to the shared multi-select mixin")

BETTERUI.Banking.currentUsedBank = 0
local normalizedMainContext = BETTERUI.Banking.GetActiveTransferContext()
assertEqual(BAG_BANK, normalizedMainContext.targetBag, "GetActiveTransferContext hides the zero sentinel on the target bag")

BETTERUI.Banking.currentUsedBank = BAG_GUILDBANK
local guildFallbackContext = BETTERUI.Banking.GetActiveTransferContext()
assertEqual(BAG_GUILDBANK, guildFallbackContext.targetBag,
    "GetActiveTransferContext preserves active non-default target banks")
assertEqual(BAG_GUILDBANK, guildFallbackContext.sourceBag,
    "GetActiveTransferContext falls back to current banking state when GetBankingBag is unavailable")

local originalGetBankingBag = GetBankingBag
GetBankingBag = function()
    return 0
end
local normalizedSourceContext = BETTERUI.Banking.GetActiveTransferContext()
assertEqual(BAG_BANK, normalizedSourceContext.sourceBag, "GetActiveTransferContext normalizes a zero banking bag")
GetBankingBag = function()
    return BAG_GUILDBANK
end
local liveSourceContext = BETTERUI.Banking.GetActiveTransferContext()
assertEqual(BAG_GUILDBANK, liveSourceContext.sourceBag,
    "GetActiveTransferContext uses the live banking bag when available")
GetBankingBag = originalGetBankingBag

local transferContext = BETTERUI.Banking.GetActiveTransferContext()
assertEqual(BAG_GUILDBANK, transferContext.sourceBag, "GetActiveTransferContext exposes the normalized source bag")
assertEqual(BAG_GUILDBANK, transferContext.targetBag, "GetActiveTransferContext exposes the normalized target bag")
assertEqual(false, transferContext.isMainBank, "GetActiveTransferContext tracks when banking is not in personal-bank mode")
assertEqual(true, transferContext.isGuildBank, "GetActiveTransferContext tracks guild-bank mode from the active source bag")

local newWindow = BETTERUI.Banking.Class:New("BETTERUI_BankingWindow", "betterui_banking")
assertEqual("BETTERUI_BankingWindow", newWindow._newArgs[1], "BankingClass:New forwards the top-level window name")
assertEqual("betterui_banking", newWindow._newArgs[2], "BankingClass:New forwards the scene name")

sceneShowing = false
assertEqual(false, BETTERUI.Banking.Class.IsSceneShowing({}), "IsSceneShowing delegates to BetterUI.Utils")
sceneShowing = true
assertEqual(true, BETTERUI.Banking.Class.IsSceneShowing({}), "IsSceneShowing tracks the live banking scene state")

local footerController = {
    SetMode = function(self, mode)
        self.mode = mode
    end,
}
local footerWindow = asWindow({
    control = {
        container = {
            GetNamedChild = function(_, name)
                assertEqual("FooterContainer", name, "SetupUnifiedFooter requests the footer container")
                return {
                    unifiedFooter = footerController,
                }
            end,
        },
    },
})
footerWindow:SetupUnifiedFooter()
assertEqual(footerController, footerWindow.unifiedFooterController, "SetupUnifiedFooter stores the resolved unified footer controller")
assertEqual(BETTERUI.CIM.UnifiedFooter.MODE.BANKING, footerController.mode, "SetupUnifiedFooter selects BANKING footer mode")

local linkedColumns = {}
local labelWindow = asWindow({
    header = {
        columns = { "nameLabel", "typeLabel", "valueLabel" },
    },
    headerSortController = {
        SetColumnLabel = function(_, index, label)
            linkedColumns[index] = label
        end,
    },
})
labelWindow:LinkColumnLabels()
assertEqual("nameLabel", linkedColumns[1], "LinkColumnLabels links the first column label")
assertEqual("valueLabel", linkedColumns[3], "LinkColumnLabels links the last column label")

local sortWindow = asWindow({
    list = {
        dataList = {
            { uniqueId = "alpha", name = "Alpha" },
            { uniqueId = "omega", name = "Omega" },
        },
        GetSelectedData = function(self)
            return self.selectedData
        end,
        SetSelectedIndexWithoutAnimation = function(self, index)
            self.selectedIndex = index
        end,
        selectedData = { uniqueId = "omega", name = "Omega" },
    },
    RefreshList = function(self)
        self.refreshListCount = (self.refreshListCount or 0) + 1
    end,
})
sortWindow:OnHeaderSortChanged("name", BETTERUI.CIM.UI.HeaderSortController.SORT_DIRECTION.ASCENDING)
assertTrue(type(sortWindow.itemSortComparator) == "function", "OnHeaderSortChanged installs a comparator for active sort columns")
assertEqual(1, sortWindow.refreshListCount, "OnHeaderSortChanged refreshes the list")
assertEqual(2, sortWindow.list.selectedIndex, "OnHeaderSortChanged restores the selected row after refresh")
sortWindow:OnHeaderSortChanged("name", BETTERUI.CIM.UI.HeaderSortController.SORT_DIRECTION.NONE)
assertEqual(nil, sortWindow.itemSortComparator, "OnHeaderSortChanged clears the comparator when sort is disabled")

local manifest = readFile("BetterUI.txt")
assertTrue(manifest:match("Modules\\Banking\\Keybinds\\KeybindManager%.lua") ~= nil,
    "Manifest still loads the live keybind manager")
assertTrue(manifest:match("Modules\\Banking\\Keybinds\\KeybindSetup%.lua") == nil,
    "Manifest no longer loads the stale keybind shim")

local categoryManager = readFile("Modules/Banking/Categories/CategoryManager.lua")
assertTrue(categoryManager:match("function BETTERUI%.Banking%.Class:CycleCategory") == nil,
    "CategoryManager no longer redefines CycleCategory")
assertTrue(categoryManager:match("function BETTERUI%.Banking%.Class:UpdateHeaderTitle") == nil,
    "CategoryManager no longer redefines UpdateHeaderTitle")
assertTrue(categoryManager:match("function BETTERUI%.Banking%.Class:EnsureHeaderKeybindsActive") == nil,
    "CategoryManager no longer redefines EnsureHeaderKeybindsActive")
assertTrue(categoryManager:match("function BETTERUI%.Banking%.Class:RebuildHeaderCategories") == nil,
    "CategoryManager no longer redefines RebuildHeaderCategories")

local headerManager = readFile("Modules/Banking/UI/HeaderManager.lua")
assertTrue(headerManager:match("function BETTERUI%.Banking%.Class:CycleCategory") ~= nil,
    "HeaderManager owns CycleCategory")
assertTrue(headerManager:match("function BETTERUI%.Banking%.Class:UpdateHeaderTitle") ~= nil,
    "HeaderManager owns UpdateHeaderTitle")
assertTrue(headerManager:match("function BETTERUI%.Banking%.Class:EnsureHeaderKeybindsActive") ~= nil,
    "HeaderManager owns EnsureHeaderKeybindsActive")
assertTrue(headerManager:match("function BETTERUI%.Banking%.Class:RebuildHeaderCategories") ~= nil,
    "HeaderManager owns RebuildHeaderCategories")

local multiSelectActions = readFile("Modules/Banking/Core/MultiSelectActions.lua")
assertTrue(multiSelectActions:match("GetTransferTargetBag") ~= nil,
    "MultiSelectActions uses dedicated transfer target helper")
assertTrue(multiSelectActions:match("GetActiveTransferContext") == nil,
    "MultiSelectActions no longer resolves transfer context inline")
assertTrue(multiSelectActions:match("transferTargetBankBag or BAG_BANK") == nil,
    "MultiSelectActions no longer bypasses the transfer context helper")

local bankListManager = readFile("Modules/Banking/Lists/BankListManager.lua")
assertTrue(bankListManager:match("GetTransferWithdrawSourceBags") ~= nil,
    "BankListManager resolves withdraw sources through the dedicated Banking seam")
assertTrue(bankListManager:match("GetTransferSourceBag") ~= nil,
    "BankListManager resolves source bag through the dedicated Banking seam")
assertTrue(bankListManager:match("GetActiveTransferContext") == nil,
    "BankListManager no longer reads the shared transfer context bag directly")
assertTrue(bankListManager:match("BETTERUI%.Banking%.currentUsedBank") == nil,
    "BankListManager no longer reads the raw currentUsedBank field directly")
assertTrue(bankListManager:match("BETTERUI%.CIM%.Utils%.DefaultSortComparator") ~= nil,
    "BankListManager sorts through the neutral CIM comparator")
assertTrue(bankListManager:match("BETTERUI%.Inventory%.DefaultSortComparator") == nil,
    "BankListManager no longer reaches through Inventory for sort comparison")
assertTrue(bankListManager:match("BETTERUI%.CIM%.InitializeSharedItemVisualData") ~= nil,
    "BankListManager uses the neutral shared item visual initializer")
assertTrue(bankListManager:match("BETTERUI%.Inventory%.Class%.InitializeInventoryVisualData") == nil,
    "BankListManager no longer reaches through Inventory for row visual setup")

local bankingActions = readFile("Modules/Banking/Actions/BankingActions.lua")
assertTrue(bankingActions:match("IsTransferSourceFurnitureVault") ~= nil,
    "BankingActions resolves furniture-vault checks through the canonical Banking helper")
assertTrue(bankingActions:match("IsFurnitureVaultTransferSource") == nil,
    "BankingActions no longer depends on the deprecated furniture-vault alias")
assertTrue(bankingActions:match("BETTERUI%.Banking%.currentUsedBank") == nil,
    "BankingActions no longer reads the raw currentUsedBank field directly")
assertTrue(bankingActions:match("GetBankingBag%(") == nil,
    "BankingActions no longer bypasses bank-state helpers via GetBankingBag")

local bankingSceneLifecycle = readFile("Modules/Banking/Scene/BankingSceneLifecycle.lua")
assertTrue(bankingSceneLifecycle:match("GetTransferSourceBag") ~= nil,
    "BankingSceneLifecycle initializes runtime state through the dedicated source-bag seam")
assertTrue(bankingSceneLifecycle:match("GetTransferWithdrawSourceBags") ~= nil,
    "BankingSceneLifecycle refreshes inventory from the dedicated withdraw-source seam")
assertTrue(bankingSceneLifecycle:match("GetActiveTransferContext") == nil,
    "BankingSceneLifecycle no longer reads the shared transfer context bag directly")
assertTrue(bankingSceneLifecycle:match("BETTERUI%.Banking%.currentUsedBank") == nil,
    "BankingSceneLifecycle no longer reads the raw currentUsedBank field directly")

local bankRowSetup = readFile("Modules/Banking/Lists/BankRowSetup.lua")
assertTrue(bankRowSetup:match("BETTERUI%.Banking%.GetTransferTargetBag") ~= nil,
    "BankRowSetup resolves selection context through GetTransferTargetBag")
assertTrue(bankRowSetup:match("BETTERUI%.Banking%.GetActiveTransferContext") == nil,
    "BankRowSetup no longer reads the shared transfer context bag directly")
assertTrue(bankRowSetup:match("BETTERUI%.Banking%.currentUsedBank") == nil,
    "BankRowSetup no longer reads the raw currentUsedBank field directly")

local currencySelector = readFile("Modules/Banking/Currency/CurrencySelector.lua")
assertTrue(currencySelector:match("GetTransferSourceBag") ~= nil,
    "CurrencySelector uses the dedicated transfer source seam")
assertTrue(currencySelector:match("GetBankingBag%(") == nil,
    "CurrencySelector no longer bypasses bank-state helpers via GetBankingBag")

local guildBankAdapter = readFile("Modules/Banking/Core/GuildBankAdapter.lua")
assertTrue(guildBankAdapter:match("BETTERUI%.Banking%.GetActiveTransferContext") == nil,
    "GuildBankAdapter no longer reads transfer context inline")
assertTrue(guildBankAdapter:match("IsGuildBankTransferMode") ~= nil,
    "GuildBankAdapter uses the explicit guild-bank transfer-mode helper")
assertTrue(guildBankAdapter:match("BETTERUI%.Banking%.currentUsedBank") == nil,
    "GuildBankAdapter no longer reads the raw currentUsedBank field directly")
assertTrue(guildBankAdapter:match("GetBankingBag%(") == nil,
    "GuildBankAdapter no longer bypasses bank-state helpers via GetBankingBag")

local itemDataProcessor = readFile("Modules/CIM/Lists/ItemDataProcessor.lua")
assertTrue(itemDataProcessor:match("function BETTERUI%.CIM%.InitializeSharedItemVisualData") ~= nil,
    "CIM exposes the shared item visual initializer")

local inventoryListManager = readFile("Modules/Inventory/Lists/ItemListManager.lua")
assertTrue(inventoryListManager:match("BETTERUI%.CIM%.InitializeSharedItemVisualData%(self, itemData%)") ~= nil,
    "Inventory visual initialization delegates to the shared CIM helper")

print("\n=== Test Summary ===")
print("Passed: " .. testsPassed)
print("Failed: " .. testsFailed)

if testsFailed > 0 then
    print("\nFAILED — see above for details")
    os.exit(1)
else
    print("\nAll tests passed!")
end
