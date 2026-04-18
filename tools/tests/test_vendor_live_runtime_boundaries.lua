--[[
File: tools/tests/test_vendor_live_runtime_boundaries.lua
Purpose: Live regression coverage for Vendor mode-policy, selection runtime,
         SellVengeance, and stable-training row setup surfaces without
         mirroring implementation logic in source-token assertions.
Usage:
  lua tools/tests/test_vendor_live_runtime_boundaries.lua
]]

local passed = 0

local function assert_eq(actual, expected, message)
    if actual ~= expected then
        error(string.format("%s (expected=%s, actual=%s)", message, tostring(expected), tostring(actual)))
    end
    passed = passed + 1
end

local function assert_true(value, message)
    assert_eq(value == true, true, message)
end

BETTERUI = {
    Vendor = {
        MODE = {
            BUY = 1,
            SELL = 2,
            REPAIR = 3,
            BUYBACK = 4,
            FENCE_SELL = 5,
            FENCE_LAUNDER = 6,
            STABLE = 7,
            SELL_VENGEANCE = 8,
        },
        ACTION = {
            SELL_VENGEANCE = "vendor_sell_vengeance",
        },
    },
    CIM = {
        SharedItemSupport = {
            ResolveColumnFontDescriptor = function()
                return nil
            end,
        },
        SelectionHighlight = {
            Setup = function()
            end,
        },
    },
}

local Vendor = BETTERUI.Vendor
local authorizationCalls = 0

SI_BETTERUI_VENDOR_TAB_SELL_VENGEANCE = "Sell Vengeance"
SI_STATS_RIDING_SKILL = "Riding Skill"
SI_ITEM_ACTION_SELL = "Sell"
SI_TOOLTIP_ITEM_NAME = "<<1>>"
ITEM_DISPLAY_QUALITY_NORMAL = 1
ZO_MODE_STORE_BUY = 10
ZO_MODE_STORE_SELL = 20
ZO_MODE_STORE_REPAIR = 30
ZO_MODE_STORE_BUYBACK = 40
ZO_MODE_STORE_STABLE = 50
ZO_MODE_STORE_SELL_VENGEANCE = 60
BAG_VENGEANCE = 7
ZO_VENGEANCE_BAG_SELL_ENABLED = true
GAMEPAD_LEFT_TOOLTIP = 1
GAMEPAD_RIGHT_TOOLTIP = 2

function GetString(...)
    local argc = select("#", ...)
    if argc == 2 then
        local prefix, value = ...
        return string.format("%s:%s", tostring(prefix), tostring(value))
    end
    return tostring((...))
end

function zo_strformat(fmt, value)
    return tostring(fmt):gsub("<<1>>", tostring(value or ""))
end

function rawget(tableValue, key)
    return tableValue[key]
end

function zo_min(left, right)
    if left < right then
        return left
    end
    return right
end

function IsCurrentCampaignVengeanceRuleset()
    return true
end

function Vendor.AuthorizeInventoryAction(actionType, bagId, slotIndex)
    authorizationCalls = authorizationCalls + 1
    return actionType == Vendor.ACTION.SELL_VENGEANCE and bagId ~= nil and slotIndex ~= nil
end

local soldItems = {}

function SellInventoryItem(bagId, slotIndex, stackSize)
    soldItems[#soldItems + 1] = {
        bagId = bagId,
        slotIndex = slotIndex,
        stackSize = stackSize,
    }
end

function GetSlotStackSize()
    return 3
end

function GetItemSellValueWithBonuses()
    return 25
end

function GetItemQualityColor()
    return {
        UnpackRGBA = function()
            return 1, 1, 1, 1
        end,
    }
end

function GetItemLink()
    return "|H0:item:1|hItem|h"
end

function GetItemName()
    return "Vengeance Trophy"
end

function BETTERUI_SharedGamepadEntryLabelSetup()
end

function BETTERUI_SharedGamepadEntryIconSetup()
end

SHARED_INVENTORY = {
    GenerateFullSlotData = function()
        return {
            {
                bagId = BAG_VENGEANCE,
                slotIndex = 2,
                iconFile = "vengeance.dds",
                stackCount = 3,
                sellPrice = 75,
                name = "Vengeance Trophy",
                itemLink = "|H0:item:1|hItem|h",
                displayQuality = 4,
            },
        }
    end,
}

ZO_GamepadEntryData = {}

function ZO_GamepadEntryData:New(name, icon)
    local entry = {
        name = name,
        icon = icon,
    }

    function entry:SetDataSource(dataSource)
        self.dataSource = dataSource
    end

    function entry:SetNameColors(activeColor, inactiveColor)
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
    end

    return entry
end

ZO_ColorDef = {
    New = function(_, r, g, b, a)
        return { r = r, g = g, b = b, a = a }
    end,
}

dofile("Modules/Vendor/Core/VendorModePolicy.lua")
dofile("Modules/Vendor/Core/VendorSelectionRuntime.lua")

Vendor.GetModeDescriptor = function(mode)
    local descriptors = {
        [Vendor.MODE.BUY] = {
            nameStringId = "BUY",
            nativeModeGlobalKey = "ZO_MODE_STORE_BUY",
        },
        [Vendor.MODE.SELL] = {
            nameStringId = "SELL",
            nativeModeGlobalKey = "ZO_MODE_STORE_SELL",
        },
        [Vendor.MODE.BUYBACK] = {
            nameStringId = "BUYBACK",
            nativeModeGlobalKey = "ZO_MODE_STORE_BUYBACK",
        },
        [Vendor.MODE.REPAIR] = {
            nameStringId = "REPAIR",
            nativeModeGlobalKey = "ZO_MODE_STORE_REPAIR",
        },
        [Vendor.MODE.SELL_VENGEANCE] = {
            nameStringId = "SI_BETTERUI_VENDOR_TAB_SELL_VENGEANCE",
            nativeModeGlobalKey = "ZO_MODE_STORE_SELL_VENGEANCE",
        },
    }
    return descriptors[mode]
end

local vendorTabs = {
    { mode = Vendor.MODE.BUY },
    { mode = Vendor.MODE.SELL },
    { mode = Vendor.MODE.SELL_VENGEANCE },
    { mode = Vendor.MODE.BUYBACK },
}

do
    local activeTabs = Vendor.ModePolicy.GetActiveTabs({
        vendorTabs = vendorTabs,
        stableTabs = {},
        fenceTabs = {},
        isFenceInteraction = false,
        isStableInteraction = false,
        sessionHasBuyMode = false,
        isModeTabAvailable = function(mode)
            return mode ~= Vendor.MODE.SELL_VENGEANCE
        end,
        storeManager = {
            activeComponents = {
                {
                    GetStoreMode = function()
                        return ZO_MODE_STORE_SELL
                    end,
                },
                {
                    GetStoreMode = function()
                        return ZO_MODE_STORE_BUYBACK
                    end,
                },
            },
        },
    })

    assert_eq(#activeTabs, 2, "mode policy only exposes live native vendor modes")
    assert_eq(activeTabs[1].mode, Vendor.MODE.SELL, "mode policy preserves sell tab")
    assert_eq(activeTabs[2].mode, Vendor.MODE.BUYBACK, "mode policy preserves buyback tab")

    local firstMode, secondMode = Vendor.ModePolicy.GetToggleModePair({
        isFenceInteraction = false,
        isStableInteraction = false,
        sessionHasBuyMode = false,
        tabs = activeTabs,
    })
    assert_eq(firstMode, Vendor.MODE.SELL, "toggle pair starts with sell for sell+buyback stores")
    assert_eq(secondMode, Vendor.MODE.BUYBACK, "toggle pair includes buyback for sell+buyback stores")
end

dofile("Modules/Vendor/Components/SellVengeanceComponent.lua")

do
    local listEntries = {}
    local selectedData = {
        dataSource = {
            bagId = BAG_VENGEANCE,
            slotIndex = 2,
            sellPrice = 75,
        },
    }

    local vendorInstance = {
        list = {
            GetSelectedData = function()
                return selectedData
            end,
            AddEntry = function(_, template, entry)
                listEntries[#listEntries + 1] = {
                    template = template,
                    entry = entry,
                }
            end,
        },
    }

    local categories = Vendor.SellVengeanceComponent:GetCategories(vendorInstance)
    assert_eq(categories[1].itemCount, 1, "sell vengeance category count follows live bag rows")
    assert_true(Vendor.SellVengeanceComponent:IsPrimaryActionEnabled(vendorInstance),
        "sell vengeance primary action enables for the live selected row")
    assert_eq(authorizationCalls > 0, true,
        "sell vengeance primary action consults shared vendor authorization seam")

    Vendor.SellVengeanceComponent:BuildList(vendorInstance)
    assert_eq(#listEntries, 1, "sell vengeance build list emits the live row")
    assert_eq(listEntries[1].template, "BETTERUI_GamepadItemSubEntryTemplate",
        "sell vengeance build list uses the live entry template")

    Vendor.SellVengeanceComponent:OnPrimaryAction(vendorInstance)
    assert_eq(#soldItems, 1, "sell vengeance primary action sells the selected row")
    assert_eq(soldItems[1].stackSize, 3, "sell vengeance primary action uses live stack size")
end

dofile("Modules/Vendor/Core/VendorRowSetup.lua")

do
    local progressBar = {
        hidden = nil,
        min = nil,
        max = nil,
        value = nil,
        SetHidden = function(self, hidden)
            self.hidden = hidden
        end,
        SetMinMax = function(self, minValue, maxValue)
            self.min = minValue
            self.max = maxValue
        end,
        SetValue = function(self, value)
            self.value = value
        end,
        SetColor = function()
        end,
    }
    local progressBackdrop = {
        hidden = nil,
        SetHidden = function(self, hidden)
            self.hidden = hidden
        end,
    }
    local function makeLabel()
        return {
            text = nil,
            SetText = function(self, text)
                self.text = text
            end,
            SetFont = function()
            end,
            SetColor = function()
            end,
        }
    end

    local control = {
        label = {},
        children = {
            ItemType = makeLabel(),
            Trait = makeLabel(),
            Stat = makeLabel(),
            Value = makeLabel(),
            TrainingProgress = progressBar,
            TrainingProgressBackdrop = progressBackdrop,
        },
        GetNamedChild = function(self, childName)
            return self.children[childName]
        end,
    }

    BETTERUI.Vendor.VendorEntrySetup(control, {
        dataSource = {
            trainingType = 1,
            bestGamepadItemCategoryName = "Stable",
            trainStateText = "Ready",
            statValue = "+3",
            valueText = "250",
            progressCurrent = 3,
            progressMax = 5,
        },
    }, false, false, true, true)

    assert_eq(progressBackdrop.hidden, false, "stable training row shows the progress backdrop")
    assert_eq(progressBar.hidden, false, "stable training row shows the progress bar")
    assert_eq(progressBar.min, 0, "stable training row starts progress from zero")
    assert_eq(progressBar.max, 5, "stable training row uses live progress max")
    assert_eq(progressBar.value, 3, "stable training row uses live progress value")
end

do
    local stablePreviewChecks = 0
    local vendorPreviewChecks = 0
    local stablePreviewToggles = 0
    local vendorPreviewToggles = 0

    KEYBIND_STRIP = {
        updates = 0,
        UpdateCurrentKeybindButtonGroups = function(self)
            self.updates = self.updates + 1
        end,
    }

    local vendorInstance = {
        currentMode = Vendor.MODE.BUY,
        GetCurrentMode = function(self)
            return self.currentMode
        end,
        CanPreviewStableStoreEntry = function(_, selectedData)
            stablePreviewChecks = stablePreviewChecks + 1
            return selectedData == "stable-selection"
        end,
        CanPreviewVendorStoreEntry = function(_, selectedData)
            vendorPreviewChecks = vendorPreviewChecks + 1
            return selectedData == "vendor-selection"
        end,
        ToggleStablePreviewMode = function()
            stablePreviewToggles = stablePreviewToggles + 1
        end,
        ToggleVendorStorePreviewMode = function()
            vendorPreviewToggles = vendorPreviewToggles + 1
        end,
    }

    assert_true(Vendor.SelectionRuntime.CanSelectionPreview(vendorInstance, "stable-selection", true),
        "selection runtime exposes stable preview visibility through the stable preview seam")
    assert_true(not Vendor.SelectionRuntime.CanSelectionPreview(vendorInstance, "vendor-selection", true),
        "stable preview visibility does not fall through to vendor preview checks")
    assert_true(Vendor.SelectionRuntime.CanSelectionPreview(vendorInstance, "vendor-selection", false),
        "selection runtime exposes vendor preview visibility through the vendor preview seam")
    assert_eq(stablePreviewChecks, 2, "stable preview visibility checks stay on the stable seam")
    assert_eq(vendorPreviewChecks, 1, "vendor preview visibility checks stay on the vendor seam")

    Vendor.SelectionRuntime.ToggleSelectionPreview(vendorInstance, true)
    Vendor.SelectionRuntime.ToggleSelectionPreview(vendorInstance, false)
    assert_eq(stablePreviewToggles, 1, "selection runtime toggles stable preview through the stable seam")
    assert_eq(vendorPreviewToggles, 1, "selection runtime toggles vendor preview through the vendor seam")
    assert_eq(KEYBIND_STRIP.updates, 2, "selection runtime refreshes keybinds after preview toggles")
end

do
    local cleanupCalls = 0
    local equippedCalls = 0
    local leftTooltip = {}
    local rightTooltip = {}
    local tooltipState = {
        resets = {},
        clears = {},
        storeLayouts = 0,
        statusClears = 0,
    }

    BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip = function()
        cleanupCalls = cleanupCalls + 1
    end
    BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText = function()
        equippedCalls = equippedCalls + 1
    end

    GAMEPAD_TOOLTIPS = {
        Reset = function(_, panel)
            tooltipState.resets[#tooltipState.resets + 1] = panel
        end,
        ClearTooltip = function(_, panel)
            tooltipState.clears[#tooltipState.clears + 1] = panel
        end,
        ClearLines = function()
        end,
        LayoutStoreWindowItem = function(_, panel, dataSource)
            tooltipState.storeLayouts = tooltipState.storeLayouts + 1
            tooltipState.lastStoreLayout = { panel = panel, dataSource = dataSource }
        end,
        LayoutBagItem = function(_, panel, bagId, slotIndex)
            tooltipState.lastBagLayout = { panel = panel, bagId = bagId, slotIndex = slotIndex }
        end,
        LayoutRidingSkill = function(_, panel, trainingType, bonus, maxBonus)
            tooltipState.lastRidingLayout = {
                panel = panel,
                trainingType = trainingType,
                bonus = bonus,
                maxBonus = maxBonus,
            }
        end,
        GetTooltip = function(_, panel)
            if panel == GAMEPAD_LEFT_TOOLTIP then
                return leftTooltip
            end
            return rightTooltip
        end,
        ClearStatusLabel = function(_, panel)
            tooltipState.statusClears = tooltipState.statusClears + 1
            tooltipState.lastStatusPanel = panel
        end,
    }

    function GetStoreItemLink(entryIndex)
        return "store-link:" .. tostring(entryIndex)
    end

    ITEM_PREVIEW_GAMEPAD = {
        IsInteractionCameraPreviewEnabled = function()
            return false
        end,
    }

    local vendorInstance = {
        currentMode = Vendor.MODE.BUY,
        previewCalls = {},
        keybindRefreshes = 0,
        GetCurrentMode = function(self)
            return self.currentMode
        end,
        UpdateStablePreview = function(self)
            self.previewCalls[#self.previewCalls + 1] = "stable"
        end,
        UpdateVendorStorePreview = function(self, selectedData)
            self.previewCalls[#self.previewCalls + 1] = selectedData and "vendor-selection" or "vendor-empty"
            self.lastPreviewData = selectedData
        end,
        RefreshVendorActionKeybinds = function(self)
            self.keybindRefreshes = self.keybindRefreshes + 1
        end,
        list = {
            GetTargetData = function()
                return { dataSource = { entryIndex = 9 } }
            end,
        },
    }

    Vendor.SelectionRuntime.HandleSelection(vendorInstance, nil, false)
    assert_eq(vendorInstance.previewCalls[1], "vendor-empty",
        "empty vendor selection refreshes the vendor preview seam")
    assert_eq(vendorInstance.keybindRefreshes, 1,
        "empty vendor selection refreshes vendor action keybinds")
    assert_eq(#tooltipState.resets, 2,
        "empty vendor selection resets both tooltip panels")
    assert_eq(cleanupCalls, 2,
        "selection runtime cleans enhanced tooltips before empty-selection cleanup")

    tooltipState.resets = {}
    tooltipState.clears = {}
    vendorInstance.previewCalls = {}
    vendorInstance.keybindRefreshes = 0

    local storeSelection = {
        dataSource = {
            entryIndex = 4,
            stackCount = 3,
        },
    }
    Vendor.SelectionRuntime.HandleSelection(vendorInstance, storeSelection, false)
    assert_eq(tooltipState.storeLayouts, 1,
        "store-row selection lays out the live store tooltip")
    assert_eq(leftTooltip._betterui_itemLink, "store-link:4",
        "store-row selection stores the live store item link on the left tooltip")
    assert_eq(leftTooltip._betterui_storeStackCount, 3,
        "store-row selection stores the live store stack count on the left tooltip")
    assert_eq(vendorInstance.previewCalls[1], "vendor-selection",
        "store-row selection refreshes the vendor preview seam")
    assert_eq(rightTooltip._betterui_priceRendered, true,
        "store-row selection clears right-tooltip comparison state")
    assert_eq(tooltipState.statusClears, 2,
        "selection cleanup clears the right-tooltip status label")
    assert_eq(equippedCalls, 2,
        "selection cleanup updates equipped text for each handled selection")

    ITEM_PREVIEW_GAMEPAD = {
        IsInteractionCameraPreviewEnabled = function()
            return true
        end,
    }
    tooltipState.resets = {}
    tooltipState.clears = {}
    vendorInstance.previewCalls = {}
    vendorInstance.keybindRefreshes = 0
    Vendor.SelectionRuntime.HandleSelection(vendorInstance, { dataSource = { entryIndex = 8 } }, true)
    assert_eq(vendorInstance.previewCalls[1], "stable",
        "stable preview selection refreshes the stable preview seam")
    assert_eq(#tooltipState.resets, 2,
        "stable preview selection resets both tooltip panels before cleanup")
    assert_eq(vendorInstance.keybindRefreshes, 1,
        "stable preview selection refreshes keybinds through the shared final cleanup path")
end

print(string.format("test_vendor_live_runtime_boundaries.lua: %d passed", passed))
