-- Guild-bank deposit categories must count only items the list can display.

local passed, failed = 0, 0
local function assertEqual(expected, actual, message)
    if expected == actual then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  [FAILED] %s (expected %s, got %s)", message, tostring(expected), tostring(actual)))
    end
end

BAG_BACKPACK = 1
BAG_BANK = 2
BAG_SUBSCRIBER_BANK = 3
SLOT_TYPE_GAMEPAD_INVENTORY_ITEM = 10
SLOT_TYPE_BANK_ITEM = 11
SLOT_TYPE_GUILD_BANK_ITEM = 12
ITEMFILTERTYPE_FURNISHING = 20

local transferContext = { kind = "guild", targetIsFurnitureVault = false }
local slotData = {}
local playerLocked = {}

function GetString(id) return tostring(id) end
function GetFrameTimeMilliseconds() return 100 end
function IsItemBound() return false end
function IsItemBoPAndTradeable() return false end
function IsItemPlayerLocked(_, slotIndex) return playerLocked[slotIndex] == true end

BETTERUI = {
    Banking = {
        LIST_WITHDRAW = 1,
        TRANSFER_MODE_GUILD_BANK = "guild",
        ReadTransferContextSnapshot = function() return transferContext end,
        Class = {},
    },
    CIM = {
        CONST = { MODULES = { BANKING = "Banking" } },
        ItemTaxonomy = {
            BANK_CATEGORY_DEFS = {
                { key = "all", nameStringId = "All" },
                { key = "jewelry", nameStringId = "Jewelry", filterType = 77 },
            },
        },
        SharedItemSupport = {
            DoesItemMatchCategory = function(itemData, category)
                return category.key == "all" or itemData.category == category.key
            end,
            GetBestItemCategoryDescription = function() return "item" end,
        },
    },
}

SHARED_INVENTORY = {
    GenerateFullSlotData = function(_, predicate, ...)
        local copy = {}
        for i = 1, #slotData do
            if not predicate or predicate(slotData[i]) then
                copy[#copy + 1] = slotData[i]
            end
        end
        return copy
    end,
}

dofile("Modules/Banking/Lists/BankListManager.lua")
dofile("Modules/Banking/Categories/CategoryManager.lua")

local window = setmetatable({ currentMode = 2 }, { __index = BETTERUI.Banking.Class })

slotData = {
    { bagId = BAG_BACKPACK, slotIndex = 1, category = "jewelry", stolen = false },
    { bagId = BAG_BACKPACK, slotIndex = 2, category = "jewelry", stolen = false },
    { bagId = BAG_BACKPACK, slotIndex = 3, category = "jewelry", stolen = false },
}
playerLocked = { [1] = true, [2] = true, [3] = true }
local categories = window:ComputeVisibleBankCategories()
assertEqual(1, #categories, "Locked-only guild deposit category is hidden")
assertEqual("all", categories[1].key, "Synthetic All category remains visible")
assertEqual(0, categories[1].itemCount, "All category excludes unsupported locked items")

playerLocked[3] = false
categories = window:ComputeVisibleBankCategories()
assertEqual(2, #categories, "Category returns when it has an eligible deposit item")
assertEqual("jewelry", categories[2].key, "Eligible Jewelry category is visible")
assertEqual(1, categories[2].itemCount, "Category count includes only eligible items")

print(string.format("Passed: %d", passed))
print(string.format("Failed: %d", failed))
if failed > 0 then os.exit(1) end
