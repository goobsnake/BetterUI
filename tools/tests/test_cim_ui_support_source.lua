--[[
File: tools/tests/test_cim_ui_support_source.lua
Purpose: Source-level regression checks for shared CIM UI support modules.

Usage:
  lua tools/tests/test_cim_ui_support_source.lua
]]

if false then
    dofile("Modules/CIM/UI/GenericFooter.lua")
    dofile("Modules/CIM/UI/GenericHeader.lua")
    dofile("Modules/CIM/UI/HeaderNavigation.lua")
    dofile("Modules/CIM/UI/HeaderSortController.lua")
    dofile("Modules/CIM/UI/HeaderSortKeybinds.lua")
    dofile("Modules/CIM/UI/ScrollIndicator.lua")
    dofile("Modules/CIM/UI/SelectionHighlight.lua")
    dofile("Modules/CIM/UI/UnifiedFooter.lua")
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

local genericFooter = read_file("Modules/CIM/UI/GenericFooter.lua")
assert_true(genericFooter:find("function BETTERUI%.GenericFooter:Initialize%(%)") ~= nil,
    "GenericFooter exposes Initialize")
assert_true(genericFooter:find("function BETTERUI%.GenericFooter:Refresh%(%)") ~= nil,
    "GenericFooter exposes Refresh")
assert_true(genericFooter:find("CurrencyMgr%.UpdateLabels%(footer, invSettings%)") ~= nil,
    "GenericFooter delegates currency updates to CurrencyManager")
assert_true(genericFooter:find("CurrencyMgr%.PositionLabels%(footer, invSettings%)") ~= nil,
    "GenericFooter delegates currency label positioning to CurrencyManager")

local genericHeader = read_file("Modules/CIM/UI/GenericHeader.lua")
assert_true(genericHeader:find("function BETTERUI%.GenericHeader%.Initialize%(control, createTabBar, layout%)") ~= nil,
    "GenericHeader exposes Initialize")
assert_true(genericHeader:find("function BETTERUI%.GenericHeader%.AddToList%(control, data%)") ~= nil,
    "GenericHeader exposes AddToList")
assert_true(genericHeader:find("function BETTERUI%.GenericHeader%.SetTitleText%(control, titleText%)") ~= nil,
    "GenericHeader exposes SetTitleText")
assert_true(genericHeader:find("function BETTERUI%.GenericHeader%.Refresh%(control, data, blockTabBarCallbacks%)") ~= nil,
    "GenericHeader exposes Refresh")

local headerNavigation = read_file("Modules/CIM/UI/HeaderNavigation.lua")
assert_true(headerNavigation:find("BETTERUI%.CIM%.HeaderNavigation = BETTERUI%.CIM%.HeaderNavigation or %{%}") ~= nil,
    "HeaderNavigation initializes the shared navigation table")
assert_true(headerNavigation:find("function BETTERUI%.CIM%.HeaderNavigation%.GetOrCreateState%(instance%)") ~= nil,
    "HeaderNavigation exposes GetOrCreateState")
assert_true(headerNavigation:find("function BETTERUI%.CIM%.HeaderNavigation%.CycleCategory%(instance, delta, options%)") ~= nil,
    "HeaderNavigation exposes CycleCategory")
assert_true(headerNavigation:find("function BETTERUI%.CIM%.HeaderNavigation%.CreateCoalescedHandler%(options%)") ~= nil,
    "HeaderNavigation exposes CreateCoalescedHandler")

local headerSortController = read_file("Modules/CIM/UI/HeaderSortController.lua")
assert_true(headerSortController:find("BETTERUI%.CIM%.UI%.HeaderSortController = ZO_Object:Subclass%(%)") ~= nil,
    "HeaderSortController defines the shared sort controller class")
assert_true(headerSortController:find("function BETTERUI%.CIM%.UI%.HeaderSortController:EnterHeaderMode%(%)") ~= nil,
    "HeaderSortController exposes EnterHeaderMode")
assert_true(headerSortController:find("function BETTERUI%.CIM%.UI%.HeaderSortController:ToggleSort%(%)") ~= nil,
    "HeaderSortController exposes ToggleSort")
assert_true(headerSortController:find("function BETTERUI%.CIM%.UI%.HeaderSortController:ToggleSortForColumn%(columnIndex%)") ~= nil,
    "HeaderSortController exposes ToggleSortForColumn")

local headerSortKeybinds = read_file("Modules/CIM/UI/HeaderSortKeybinds.lua")
assert_true(headerSortKeybinds:find("function BETTERUI%.CIM%.UI%.HeaderSortController:GetSortComparator%(%)") ~= nil,
    "HeaderSortKeybinds exposes GetSortComparator on the controller")
assert_true(headerSortKeybinds:find("function BETTERUI%.CIM%.UI%.HeaderSortController:CreateKeybindDescriptor%(exitCallback, navigateUpCallback%)") ~= nil,
    "HeaderSortKeybinds exposes CreateKeybindDescriptor")
assert_true(headerSortKeybinds:find('keybind = "UI_SHORTCUT_LEFT_SHOULDER"') ~= nil,
    "HeaderSortKeybinds defines the previous-column shoulder keybind")
assert_true(headerSortKeybinds:find('keybind = "UI_SHORTCUT_RIGHT_SHOULDER"') ~= nil,
    "HeaderSortKeybinds defines the next-column shoulder keybind")

local scrollIndicator = read_file("Modules/CIM/UI/ScrollIndicator.lua")
assert_true(scrollIndicator:find("BETTERUI%.CIM%.ScrollIndicator = %{%}") ~= nil
        or scrollIndicator:find("BETTERUI%.CIM%.ScrollIndicator = BETTERUI%.CIM%.ScrollIndicator or %{%}") ~= nil,
    "ScrollIndicator initializes the shared scroll indicator table")
assert_true(scrollIndicator:find("function ScrollIndicator%.Ensure%(listControl, options%)") ~= nil,
    "ScrollIndicator exposes Ensure")
assert_true(scrollIndicator:find("function ScrollIndicator%.BindListObject%(listControl, listObject%)") ~= nil,
    "ScrollIndicator exposes BindListObject")
assert_true(scrollIndicator:find("function ScrollIndicator%.Update%(listControl, currentIndex, totalItems, visibleItems%)") ~= nil,
    "ScrollIndicator exposes Update")
assert_true(scrollIndicator:find("function ScrollIndicator%.Hide%(listControl%)") ~= nil,
    "ScrollIndicator exposes Hide")

local selectionHighlight = read_file("Modules/CIM/UI/SelectionHighlight.lua")
assert_true(selectionHighlight:find("BETTERUI%.CIM%.SelectionHighlight = %{%}") ~= nil
        or selectionHighlight:find("BETTERUI%.CIM%.SelectionHighlight = BETTERUI%.CIM%.SelectionHighlight or %{%}") ~= nil,
    "SelectionHighlight initializes the shared selection-highlight table")
assert_true(selectionHighlight:find("function SelectionHighlight%.Setup%(control, selected%)") ~= nil,
    "SelectionHighlight exposes Setup")

local unifiedFooter = read_file("Modules/CIM/UI/UnifiedFooter.lua")
assert_true(unifiedFooter:find("BETTERUI%.CIM%.UnifiedFooter%.MODE = %{%s*") ~= nil,
    "UnifiedFooter defines the shared footer modes")
assert_true(unifiedFooter:find("function UnifiedFooterController:SetupFooter%(footerControl%)") ~= nil,
    "UnifiedFooter exposes SetupFooter")
assert_true(unifiedFooter:find("function UnifiedFooterController:SetMode%(mode%)") ~= nil,
    "UnifiedFooter exposes SetMode")
assert_true(unifiedFooter:find("function UnifiedFooterController:Refresh%(%)") ~= nil,
    "UnifiedFooter exposes Refresh")
assert_true(unifiedFooter:find("function BETTERUI%.CIM%.UnifiedFooter%.Create%(control%)") ~= nil,
    "UnifiedFooter exposes the shared controller factory")

if failed > 0 then
    error(string.format("test_cim_ui_support_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_cim_ui_support_source.lua: %d passed", passed))
