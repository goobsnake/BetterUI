--[[
File: tools/tests/test_inventory_icon_setup.lua
Purpose: Regression tests for BETTERUI_IconSetup nil-guard handling.
Usage:
  lua tools/tests/test_inventory_icon_setup.lua
]]

BETTERUI = {
    Inventory = {
        CONST = {
            ICON_SIZE_SMALL = 16,
        },
        Utils = {
            -- Mirrors BETTERUI.Inventory.Utils.HasQuestItemMarkers (Core/Utils.lua): the
            -- intrinsic quest-marker predicate BETTERUI_IconSetup now delegates to. Base
            -- markers only, so it never touches the native filter (asserted below).
            HasQuestItemMarkers = function(itemData)
                if type(itemData) ~= "table" then return false end
                local source = itemData.dataSource or itemData
                if type(source) ~= "table" then return false end
                local function isQuestUid(u) return type(u) == "string" and u:find("^quest:") ~= nil end
                return itemData.isQuestItem == true
                    or source.isQuestItem == true
                    or source.questIndex ~= nil
                    or (SLOT_TYPE_QUEST_ITEM ~= nil and itemData.slotType == SLOT_TYPE_QUEST_ITEM)
                    or (SLOT_TYPE_QUEST_ITEM ~= nil and source.slotType == SLOT_TYPE_QUEST_ITEM)
                    or isQuestUid(itemData.uniqueId)
                    or isQuestUid(source.uniqueId)
            end,
        },
    },
    CIM = {
        CONST = {
            ICONS = {
                NEW_ITEM = "new",
                EQUIP_BACKUP = "backup",
                EQUIP_MAIN = "main",
                EQUIP_SLOT = "slot",
            },
        },
    },
    Utils = {
        IsBankingSceneShowing = function()
            return false
        end,
    },
}

local warnings = {}
BETTERUI.Log = {
    CATEGORY = { LIST = "LIST" },
    Warn = function(_, message, data)
        warnings[#warnings + 1] = { message = message, data = data }
    end,
}

local passed = 0
local failed = 0

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, label)
    assert_eq(value == true, true, label)
end

EQUIP_SLOT_BACKUP_MAIN = 1
EQUIP_SLOT_BACKUP_OFF = 2
EQUIP_SLOT_RING2 = 3
EQUIP_SLOT_TRINKET2 = 4
EQUIP_SLOT_BACKUP_POISON = 5
EQUIP_TYPE_INVALID = 99
SLOT_TYPE_QUEST_ITEM = 101
ZO_InventoryUtils_DoesNewItemMatchFilterType = function()
    error("BETTERUI_IconSetup must not call native filter matching with shared row data")
end

dofile("Modules/Inventory/Lists/InventoryEntryFormatting.lua")

local function CreateStatusIndicator()
    return {
        clearCount = 0,
        hidden = true,
        texture = nil,
        ClearIcons = function(self)
            self.clearCount = self.clearCount + 1
        end,
        SetHidden = function(self, hidden)
            self.hidden = hidden
        end,
        IsHidden = function(self)
            return self.hidden
        end,
        SetTexture = function(self, texture)
            self.texture = texture
        end,
    }
end

local function CreateEquippedIcon()
    return {
        hidden = true,
        texture = nil,
        SetHidden = function(self, hidden)
            self.hidden = hidden
        end,
        IsHidden = function(self)
            return self.hidden
        end,
        SetTexture = function(self, texture)
            self.texture = texture
        end,
    }
end

print("[BETTERUI_IconSetup guards]")

do
    local statusIndicator = CreateStatusIndicator()
    local equippedIcon = CreateEquippedIcon()
    BETTERUI_IconSetup(statusIndicator, equippedIcon, nil)
    assert_eq(statusIndicator.clearCount, 1, "nil data clears the status indicator when present")
    assert_eq(statusIndicator.hidden, true, "nil data hides the status indicator when present")
    assert_eq(equippedIcon.hidden, true, "nil data hides the equipped icon when present")
end

do
    local equippedIcon = CreateEquippedIcon()
    local ok = pcall(BETTERUI_IconSetup, nil, equippedIcon, {
        dataSource = {
            slotIndex = EQUIP_SLOT_BACKUP_MAIN,
            equipType = 1,
        },
        brandNew = true,
        enabled = true,
        isEquippedInCurrentCategory = true,
    })
    assert_true(ok, "missing status indicator does not raise an error")
    assert_eq(equippedIcon.texture, BETTERUI.CIM.CONST.ICONS.EQUIP_BACKUP,
        "equipped icon still updates when status indicator is missing")
end

do
    local statusIndicator = CreateStatusIndicator()
    local ok = pcall(BETTERUI_IconSetup, statusIndicator, nil, {
        dataSource = {
            slotIndex = 10,
            equipType = EQUIP_TYPE_INVALID,
        },
        brandNew = true,
        enabled = true,
        isEquippedInCurrentCategory = true,
    })
    assert_true(ok, "missing equipped icon does not raise an error")
    assert_eq(statusIndicator.texture, BETTERUI.CIM.CONST.ICONS.NEW_ITEM,
        "status indicator still updates when equipped icon is missing")
    assert_eq(statusIndicator.hidden, false,
        "status indicator remains visible for new items when equipped icon is missing")
end

do
    local statusIndicator = CreateStatusIndicator()
    local equippedIcon = CreateEquippedIcon()
    local ok = pcall(BETTERUI_IconSetup, statusIndicator, equippedIcon, {
        dataSource = {
            slotIndex = 10,
            equipType = EQUIP_TYPE_INVALID,
        },
        brandNew = false,
        enabled = true,
    })
    assert_true(ok, "shared non-quest rows do not call unsafe native quest filter helpers")
end

do
    local statusIndicator = CreateStatusIndicator()
    local equippedIcon = CreateEquippedIcon()
    statusIndicator.hidden = false
    statusIndicator.texture = "recycled_status"
    equippedIcon.hidden = false
    equippedIcon.texture = "recycled_equipped"
    warnings = {}
    local ok = pcall(BETTERUI_IconSetup, statusIndicator, equippedIcon, {
        dataSource = {
            questIndex = 42,
            slotIndex = EQUIP_SLOT_BACKUP_MAIN,
            equipType = 1,
        },
        enabled = true,
        isQuestItem = true,
        isEquippedInCurrentCategory = true,
    })
    assert_true(ok, "quest rows with stale equipped metadata do not raise an error")
    assert_eq(equippedIcon.hidden, true,
        "quest rows suppress equipped/quickslot-style icons even if stale metadata is present")
    assert_eq(statusIndicator.hidden, true,
        "quest rows suppress recycled status icons before they can display")
    assert_eq(equippedIcon.texture, nil,
        "quest rows do not assign an equipment texture")
    assert_eq(warnings[1] and warnings[1].message, "quest item equipment icon suppressed",
        "quest rows with impossible equipment metadata emit a monitor-visible warning")
    assert_eq(warnings[2] and warnings[2].message, "quest item recycled status icon suppressed",
        "quest rows with recycled status/equipment controls emit a monitor-visible warning")
end

do
    local statusIndicator = CreateStatusIndicator()
    local equippedIcon = CreateEquippedIcon()
    statusIndicator.hidden = false
    equippedIcon.hidden = false
    warnings = {}
    local ok = pcall(BETTERUI_IconSetup, statusIndicator, equippedIcon, {
        dataSource = {
            slotType = SLOT_TYPE_QUEST_ITEM,
            uniqueId = "quest:7:1",
        },
        enabled = true,
    })
    assert_true(ok, "quest slot-type rows suppress recycled visuals without native filter matching")
    assert_eq(statusIndicator.hidden, true, "quest slot-type rows hide recycled status icons")
    assert_eq(equippedIcon.hidden, true, "quest slot-type rows hide recycled equipped icons")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
