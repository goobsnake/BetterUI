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

assertTrue(type(BETTERUI.Banking.ResolveBankBag) == "function", "ResolveBankBag helper is exposed")
assertTrue(type(BETTERUI.Banking.GetCurrentBank) == "function", "GetCurrentBank helper is exposed")
assertEqual(BAG_BANK, BETTERUI.Banking.lastUsedBank, "lastUsedBank starts aligned with the normalized default bank")

if type(BETTERUI.Banking.ResolveBankBag) == "function" then
    assertEqual(BAG_BANK, BETTERUI.Banking.ResolveBankBag(nil), "ResolveBankBag falls back from nil")
    assertEqual(BAG_BANK, BETTERUI.Banking.ResolveBankBag(0), "ResolveBankBag falls back from zero sentinel")
    assertEqual(BAG_SUBSCRIBER_BANK, BETTERUI.Banking.ResolveBankBag(BAG_SUBSCRIBER_BANK),
        "ResolveBankBag preserves explicit bank bags")
end

BETTERUI.Banking.currentUsedBank = 0
assertEqual(BAG_BANK, BETTERUI.Banking.GetCurrentBank(), "GetCurrentBank hides the zero sentinel")

BETTERUI.Banking.currentUsedBank = BAG_GUILDBANK
assertEqual(BAG_GUILDBANK, BETTERUI.Banking.GetCurrentBank(), "GetCurrentBank preserves active non-default banks")

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
assertTrue(multiSelectActions:match("local currentUsedBank = GetCurrentBank%(%)") ~= nil,
    "MultiSelectActions uses GetCurrentBank for banking transfers and menus")
assertTrue(multiSelectActions:match("currentUsedBank or BAG_BANK") == nil,
    "MultiSelectActions no longer bypasses the normalized bank helper")

local bankListManager = readFile("Modules/Banking/Lists/BankListManager.lua")
assertTrue(bankListManager:match("local currentUsedBank = BETTERUI%.Banking%.GetCurrentBank%(%)") ~= nil,
    "BankListManager resolves bank bags through GetCurrentBank")
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
