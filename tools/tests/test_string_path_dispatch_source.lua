--[[
File: tools/tests/test_string_path_dispatch_source.lua
Purpose: Guard stable internal BetterUI seams against string-path TryCall/TryResolve dispatch.

Usage:
  lua tools/tests/test_string_path_dispatch_source.lua
]]

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
    local handle, err = io.open(path, "r")
    assert_true(handle ~= nil, string.format("opens source file: %s (%s)", path, tostring(err)))
    if not handle then
        return ""
    end

    local content = handle:read("*a")
    handle:close()
    return content or ""
end

local sourceChecks = {
    {
        path = "Modules/Banking/Core/MultiSelectActions.lua",
        forbidden = 'TryResolve%("Banking%.Window"%)',
        required = "BETTERUI%.Banking%.GetWindow%(",
        label = "banking multi-select uses direct Banking.Window seam",
    },
    {
        path = "Modules/Banking/Dialogs/QuantityDialog.lua",
        forbidden = 'TryResolve%("Banking%.Window"%)',
        required = "BETTERUI%.Banking%.GetWindow%(",
        label = "banking quantity dialog uses direct Banking.Window seam",
    },
    {
        path = "Modules/CIM/Actions/GenericSlotActions.lua",
        forbidden = 'TryCall%("Inventory%.Dialogs%.TryStowWithQuantity"',
        required = "BETTERUI%.CIM%.InvokeInventoryDialog",
        label = "generic slot actions use the shared CIM inventory dialog seam",
    },
    {
        path = "Modules/CIM/UI/UnifiedFooter.lua",
        forbidden = 'TryResolve%("GenericFooter%.Refresh"%)',
        required = "BETTERUI%.GenericFooter%s+and%s+BETTERUI%.GenericFooter%.Refresh",
        label = "unified footer binds GenericFooter.Refresh directly",
    },
    {
        path = "Modules/Inventory/Actions/ItemActionHandlers.lua",
        forbidden = 'TryCall%("Inventory%.Dialogs%.StowFullStack"',
        required = "BETTERUI%.Inventory%.InvokeDialog",
        label = "item action handlers use shared inventory dialog dispatch",
    },
    {
        path = "Modules/Inventory/Actions/SlotActions.lua",
        forbidden = 'TryCall%("Inventory%.Dialogs%.TryRetrieveWithQuantity"',
        required = "BETTERUI%.Inventory%s+and%s+BETTERUI%.Inventory%.InvokeDialog",
        label = "slot actions use shared inventory dialog dispatch",
    },
    {
        path = "Modules/Inventory/Module.lua",
        forbidden = 'TryCall%("Inventory%.Dialogs%.InitializeCraftBagQuantityDialog"',
        required = "local%s+function%s+TryInitializeCraftBagQuantityDialog%(",
        label = "inventory module initializes craft-bag dialog through direct helper",
    },
    {
        path = "Modules/Inventory/Module.lua",
        forbidden = 'TryCall%("CIM%.Narration%.RegisterListNarration"',
        required = "local%s+function%s+TryRegisterInventoryNarration%(",
        label = "inventory module registers narration through direct helper",
    },
    {
        path = "Modules/Inventory/Settings/FontSettings.lua",
        forbidden = 'TryCall%("CIM%.Utils%.IsInventorySceneShowing"%)',
        required = "BETTERUI%.Utils%s+and%s+BETTERUI%.Utils%.IsInventorySceneShowing",
        label = "font settings read inventory scene visibility directly",
    },
    {
        path = "Modules/ResourceOrbFrames/ResourceOrbFrames.lua",
        forbidden = 'TryCall%("ControlUtils%.InvalidateControlCache"%)',
        required = "BETTERUI%.ControlUtils%s+and%s+BETTERUI%.ControlUtils%.InvalidateControlCache",
        label = "resource orb frames invalidate control cache directly",
    },
}

for _, check in ipairs(sourceChecks) do
    local source = read_file(check.path)
    assert_true(source:find(check.forbidden) == nil, check.label .. " removes string-path dispatch")
    assert_true(source:find(check.required) ~= nil, check.label .. " keeps direct seam helper")
end

if failed > 0 then
    error(string.format("test_string_path_dispatch_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_string_path_dispatch_source.lua: %d passed", passed))
