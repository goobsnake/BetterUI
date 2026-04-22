--[[
File: tools/tests/test_cim_window_support_source.lua
Purpose: Source-level regression checks for shared CIM window, dialog, keybind,
         and batch-processing support modules.

Usage:
  lua tools/tests/test_cim_window_support_source.lua
]]

if false then
    dofile("Modules/CIM/Core/Window/GenericWindow.lua")
    dofile("Modules/CIM/Core/Window/TooltipLayout.lua")
    dofile("Modules/CIM/Core/Window/UnifiedScreen.lua")
    dofile("Modules/CIM/Core/Window/WindowClass.lua")
    dofile("Modules/CIM/Dialogs/DialogRegistry.lua")
    dofile("Modules/CIM/Keybinds/GenericKeybinds.lua")
    dofile("Modules/CIM/Lists/BatchProcessor.lua")
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

local genericWindow = read_file("Modules/CIM/Core/Window/GenericWindow.lua")
assert_true(genericWindow:find("BETTERUI%.CIM%.GenericWindow = BETTERUI%.Interface%.Window:Subclass%(%)") ~= nil,
    "GenericWindow defines the shared generic window subclass")
assert_true(genericWindow:find("function BETTERUI%.CIM%.GenericWindow:Initialize%(tlw_name, scene_name, virtualTemplate%)") ~= nil,
    "GenericWindow exposes Initialize")
assert_true(genericWindow:find("function BETTERUI%.CIM%.GenericWindow:SaveCategoryPosition%(categoryKey, position%)") ~= nil,
    "GenericWindow exposes SaveCategoryPosition")
assert_true(genericWindow:find("function BETTERUI%.CIM%.GenericWindow:SwitchToCategory%(categoryKey%)") ~= nil,
    "GenericWindow exposes SwitchToCategory")
assert_true(genericWindow:find("function BETTERUI%.CIM%.GenericWindow:EnsureHeaderKeybindsActive%(%)") ~= nil,
    "GenericWindow exposes EnsureHeaderKeybindsActive")

local tooltipLayout = read_file("Modules/CIM/Core/Window/TooltipLayout.lua")
assert_true(tooltipLayout:find("function BETTERUI%.CIM%.SetTooltipWidth%(width%)") ~= nil,
    "TooltipLayout exposes SetTooltipWidth")
assert_true(tooltipLayout:find("GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT%.control:SetWidth%(width%)") ~= nil,
    "TooltipLayout updates the tooltip background width")
assert_true(tooltipLayout:find("tooltipControl:SetAnchor%(TOPLEFT, GuiRoot, TOPLEFT, width %+ 66, 52 %+") ~= nil,
    "TooltipLayout reanchors the tooltip against the custom panel width")

local dialogRegistry = read_file("Modules/CIM/Dialogs/DialogRegistry.lua")
assert_true(dialogRegistry:find("BETTERUI%.CIM%.Dialogs%.Registry = %{%s*") ~= nil,
    "DialogRegistry defines the shared dialog registry table")
assert_true(dialogRegistry:find("function BETTERUI%.CIM%.Dialogs%.Register%(dialogName, dialogInfo, options%)") ~= nil,
    "DialogRegistry exposes Register")
assert_true(dialogRegistry:find("function BETTERUI%.CIM%.Dialogs%.IsRegistered%(dialogName%)") ~= nil,
    "DialogRegistry exposes IsRegistered")
assert_true(dialogRegistry:find("function BETTERUI%.CIM%.Dialogs%.Show%(dialogName, data%)") ~= nil,
    "DialogRegistry exposes Show")
assert_true(dialogRegistry:find("function BETTERUI%.CIM%.Dialogs%.CreateParametricActionEntry%(label, actionId%)") ~= nil,
    "DialogRegistry exposes CreateParametricActionEntry")

local genericKeybinds = read_file("Modules/CIM/Keybinds/GenericKeybinds.lua")
assert_true(genericKeybinds:find("function BETTERUI%.CIM%.Keybinds%.CreateBackKeybind%(callback%)") ~= nil,
    "GenericKeybinds exposes CreateBackKeybind")
assert_true(genericKeybinds:find("function BETTERUI%.CIM%.Keybinds%.CreateStackAllKeybind%(bagId, visibleFn%)") ~= nil,
    "GenericKeybinds exposes CreateStackAllKeybind")
assert_true(genericKeybinds:find("function BETTERUI%.CIM%.Keybinds%.CreateActionsKeybind%(showActionsFn, visibleFn%)") ~= nil,
    "GenericKeybinds exposes CreateActionsKeybind")
assert_true(genericKeybinds:find("function BETTERUI%.CIM%.Keybinds%.CreateListTriggerKeybinds%(contract%)") ~= nil,
    "GenericKeybinds exposes CreateListTriggerKeybinds")
assert_true(genericKeybinds:find('keybind = "UI_SHORTCUT_LEFT_TRIGGER"') ~= nil,
    "GenericKeybinds defines the left trigger descriptor")
assert_true(genericKeybinds:find('keybind = "UI_SHORTCUT_RIGHT_TRIGGER"') ~= nil,
    "GenericKeybinds defines the right trigger descriptor")

local batchProcessor = read_file("Modules/CIM/Lists/BatchProcessor.lua")
assert_true(batchProcessor:find("BETTERUI%.CIM%.Lists%.BatchProcessor = ZO_Object:Subclass%(%)") ~= nil,
    "BatchProcessor defines the shared batch processor class")
assert_true(batchProcessor:find("function BETTERUI%.CIM%.Lists%.BatchProcessor:Initialize%(options%)") ~= nil,
    "BatchProcessor exposes Initialize")
assert_true(batchProcessor:find("function BETTERUI%.CIM%.Lists%.BatchProcessor:Start%(data, options%)") ~= nil,
    "BatchProcessor exposes Start")
assert_true(batchProcessor:find("BetterUIBatchProcessorInitOptions") ~= nil,
    "BatchProcessor initialize docs use the shared init options type alias")
assert_true(batchProcessor:find("BetterUIBatchProcessorStartOptions") ~= nil,
    "BatchProcessor start docs use the shared runtime options type alias")
assert_true(batchProcessor:find("function BETTERUI%.CIM%.Lists%.BatchProcessor:ProcessBatch%(%)") ~= nil,
    "BatchProcessor exposes ProcessBatch")
assert_true(batchProcessor:find("function BETTERUI%.CIM%.Lists%.BatchProcessor:Cancel%(%)") ~= nil,
    "BatchProcessor exposes Cancel")
assert_true(batchProcessor:find("function BETTERUI%.CIM%.Lists%.BatchProcessor:IsActive%(%)") ~= nil,
    "BatchProcessor exposes IsActive")

if failed > 0 then
    error(string.format("test_cim_window_support_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_cim_window_support_source.lua: %d passed", passed))
