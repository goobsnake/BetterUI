--[[
File: tools/tests/test_cim_list_support_source.lua
Purpose: Source-level regression checks for shared CIM list, module, and
         currency support modules.

Usage:
  lua tools/tests/test_cim_list_support_source.lua
]]

if false then
    dofile("Modules/CIM/Lists/GenericListManager.lua")
    dofile("Modules/CIM/Lists/HorizontalScrollList.lua")
    dofile("Modules/CIM/Lists/ItemDataProcessor.lua")
    dofile("Modules/CIM/Lists/ListRefreshManager.lua")
    dofile("Modules/CIM/Lists/ParametricListScreen.lua")
    dofile("Modules/CIM/Lists/ParametricScrollListTemplates.lua")
    dofile("Modules/CIM/Lists/SubList.lua")
    dofile("Modules/CIM/Lists/VerticalScrollList.lua")
    dofile("Modules/CIM/Module.lua")
    dofile("Modules/CIM/UI/CurrencyManager.lua")
end

local passed = 0
local failed = 0

local function assert_true(value, label)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("Assertion failed: " .. label .. "\n")
    end
end

local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local genericListManager = read_file("Modules/CIM/Lists/GenericListManager.lua")
assert_true(genericListManager:find("BETTERUI%.CIM%.GenericListManager = ZO_Object:Subclass%(%)") ~= nil,
    "GenericListManager defines the shared list manager class")
assert_true(genericListManager:find("function BETTERUI%.CIM%.GenericListManager:SavePosition%(categoryKey, position%)") ~= nil,
    "GenericListManager exposes SavePosition")
assert_true(genericListManager:find("function BETTERUI%.CIM%.GenericListManager:CacheItemLinkData%(itemData, bagId, slotIndex%)") ~= nil,
    "GenericListManager exposes CacheItemLinkData")
assert_true(genericListManager:find("function BETTERUI%.CIM%.GenericListManager:ApplyTextFilter%(items, searchQuery%)") ~= nil,
    "GenericListManager exposes ApplyTextFilter")
assert_true(genericListManager:find("function BETTERUI%.CIM%.MenuEntryTemplateEquality%(left, right%)") ~= nil,
    "GenericListManager exposes MenuEntryTemplateEquality")

local horizontalScrollList = read_file("Modules/CIM/Lists/HorizontalScrollList.lua")
-- The dead BETTERUI_HorizontalScrollList_Gamepad class was removed; the live
-- header path uses BETTERUI_HorizontalParametricScrollList.
assert_true(horizontalScrollList:find("BETTERUI_HorizontalScrollList_Gamepad") == nil,
    "HorizontalScrollList no longer defines the dead non-parametric gamepad list class")
assert_true(horizontalScrollList:find("BETTERUI_HorizontalParametricScrollList = ZO_ParametricScrollList:Subclass%(%)") ~= nil,
    "HorizontalScrollList defines the horizontal parametric list subclass")

local itemDataProcessor = read_file("Modules/CIM/Lists/ItemDataProcessor.lua")
assert_true(itemDataProcessor:find("function BETTERUI%.CIM%.InitializeSharedItemVisualData%(row, itemData%)") ~= nil,
    "ItemDataProcessor exposes InitializeSharedItemVisualData")
assert_true(itemDataProcessor:find("function BETTERUI%.CIM%.CreateItemEntryData%(itemData, options%)") ~= nil,
    "ItemDataProcessor exposes CreateItemEntryData")
assert_true(itemDataProcessor:find("function BETTERUI%.CIM%.AddItemEntryToList%(list, data, currentCategoryName, useHeaders%)") ~= nil,
    "ItemDataProcessor exposes AddItemEntryToList")

local listRefreshManager = read_file("Modules/CIM/Lists/ListRefreshManager.lua")
assert_true(listRefreshManager:find("BETTERUI%.CIM%.Lists%.ListRefreshManager = ZO_Object:Subclass%(%)") ~= nil,
    "ListRefreshManager defines the shared refresh manager class")
assert_true(listRefreshManager:find("BetterUIListRefreshManagerOptions") ~= nil,
    "ListRefreshManager initialize docs use the shared options type alias")
assert_true(listRefreshManager:find("function BETTERUI%.CIM%.Lists%.ListRefreshManager:SavePosition%(list, options%)") ~= nil,
    "ListRefreshManager exposes SavePosition")
assert_true(listRefreshManager:find("function BETTERUI%.CIM%.Lists%.ListRefreshManager:QueueRefresh%(list, refreshFn, savePosition, options%)") ~= nil,
    "ListRefreshManager exposes QueueRefresh")
assert_true(listRefreshManager:find("function BETTERUI%.CIM%.Lists%.ListRefreshManager:IsDirty%(%)") ~= nil,
    "ListRefreshManager exposes IsDirty")

local parametricListScreen = read_file("Modules/CIM/Lists/ParametricListScreen.lua")
assert_true(parametricListScreen:find("BETTERUI_Gamepad_ParametricList_Screen = ZO_Gamepad_ParametricList_Screen:Subclass%(%)") ~= nil,
    "ParametricListScreen defines the shared gamepad parametric screen class")
assert_true(parametricListScreen:find("function BETTERUI_Gamepad_ParametricList_Screen:Initialize%(control, createTabBar, activateOnShow, scene%)") ~= nil,
    "ParametricListScreen exposes Initialize")
assert_true(parametricListScreen:find("function BETTERUI_Gamepad_ParametricList_Screen:SetListsUseTriggerKeybinds%(addListTriggerKeybinds,") ~= nil,
    "ParametricListScreen exposes SetListsUseTriggerKeybinds")

local parametricTemplates = read_file("Modules/CIM/Lists/ParametricScrollListTemplates.lua")
assert_true(parametricTemplates:find("BETTERUI%.CIM%.ListGlobals = BETTERUI%.CIM%.ListGlobals or %{%}") ~= nil,
    "ParametricScrollListTemplates initializes the shared list globals table")
assert_true(parametricTemplates:find("LIST_GLOBALS%.TABBAR_MOVEMENT_TYPES = LIST_GLOBALS%.TABBAR_MOVEMENT_TYPES or") ~= nil,
    "ParametricScrollListTemplates defines tab-bar movement types")
assert_true(parametricTemplates:find("function BETTERUI%.GamepadParametricScrollListPlaySound%(movementType%)") ~= nil,
    "ParametricScrollListTemplates exposes the shared play-sound hook")

local subList = read_file("Modules/CIM/Lists/SubList.lua")
assert_true(subList:find("BETTERUI_VerticalParametricScrollListSubList = BETTERUI_VerticalParametricScrollList:Subclass%(%)") ~= nil,
    "SubList defines the shared vertical sub-list subclass")
assert_true(subList:find("function BETTERUI_VerticalParametricScrollListSubList:Initialize%(control, parentList, parentKeybinds, onDataChosen%)") ~= nil,
    "SubList exposes Initialize")
assert_true(subList:find("function BETTERUI_VerticalParametricScrollListSubList:InitializeKeybindStrip%(%)") ~= nil,
    "SubList exposes InitializeKeybindStrip")
assert_true(subList:find("function BETTERUI_VerticalParametricScrollListSubList:Deactivate%(%)") ~= nil,
    "SubList exposes Deactivate")

local verticalScrollList = read_file("Modules/CIM/Lists/VerticalScrollList.lua")
assert_true(verticalScrollList:find("BETTERUI_VerticalParametricScrollList = ZO_ParametricScrollList:Subclass%(%)") ~= nil,
    "VerticalScrollList defines the shared vertical parametric list class")
assert_true(verticalScrollList:find("function BETTERUI_VerticalParametricScrollList:Initialize%(control%)") ~= nil,
    "VerticalScrollList exposes Initialize")
assert_true(verticalScrollList:find("BETTERUI_VerticalItemParametricScrollList = BETTERUI_VerticalParametricScrollList:Subclass%(%)") ~= nil,
    "VerticalScrollList defines the shared vertical item-list subclass")

local cimModule = read_file("Modules/CIM/Module.lua")
assert_true(cimModule:find("CIM%.ROOT_CONTRACT = %{%s*") ~= nil,
    "CIM module declares the shared root contract")
assert_true(cimModule:find("function CIM%.InitModule%(m_options%)") ~= nil,
    "CIM module exposes InitModule")
assert_true(cimModule:find('settingsOwner = ') == nil,
    "CIM module no longer hardcodes a dedicated settings-owner path")

local currencyManager = read_file("Modules/CIM/UI/CurrencyManager.lua")
assert_true(currencyManager:find("BETTERUI%.CIM%.Currency%.DEFS = %{%s*") ~= nil,
    "CurrencyManager defines the shared currency metadata table")
assert_true(currencyManager:find("BETTERUI%.CIM%.Currency%.TOKEN_TO_DEF = %{%}") ~= nil,
    "CurrencyManager builds the shared token lookup table")
assert_true(currencyManager:find("function BETTERUI%.CIM%.Currency%.GetValue%(def%)") ~= nil,
    "CurrencyManager exposes GetValue")
assert_true(currencyManager:find("function BETTERUI%.CIM%.Currency%.FormatLabel%(def, amount%)") ~= nil,
    "CurrencyManager exposes FormatLabel")
assert_true(currencyManager:find("function BETTERUI%.CIM%.Currency%.GetLabelControl%(footer, labelName%)") ~= nil,
    "CurrencyManager exposes GetLabelControl")

if failed > 0 then
    error(string.format("test_cim_list_support_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_cim_list_support_source.lua: %d passed", passed))
