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

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
