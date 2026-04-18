--[[
File: tools/tests/test_named_shared_contracts_source.lua
Purpose: Guard shared search/window/vendor contracts against anonymous table annotations.

Usage:
  lua tools/tests/test_named_shared_contracts_source.lua
]]

if false then
    dofile("Modules/CIM/Core/Data/SearchManager.lua")
    dofile("Modules/CIM/Core/Window/UnifiedScreen.lua")
    dofile("Modules/CIM/Core/Window/WindowClass.lua")
    dofile("Modules/Vendor/Vendor.lua")
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
    local handle, err = io.open(path, "r")
    assert_true(handle ~= nil, string.format("opens source file: %s (%s)", path, tostring(err)))
    if not handle then
        return ""
    end

    local content = handle:read("*a")
    handle:close()
    return content or ""
end

local files = {
    {
        path = "Modules/CIM/Core/Data/SearchManager.lua",
        required = {
            "---@class BetterUISearchContext",
            "---@alias BetterUIKeybindDescriptorGroup BetterUIKeybindDescriptor%[%]",
            "---@param context BetterUISearchContext",
            "---@return BetterUIKeybindDescriptorGroup",
            "---@param textSearchKeybindStripDescriptor BetterUIKeybindDescriptorGroup",
        },
        forbidden = {
            "---@param context table",
            "---@return table%[%]",
            "---@param self table",
        },
    },
    {
        path = "Modules/CIM/Core/Window/UnifiedScreen.lua",
        required = {
            "---@class BetterUIUnifiedScreen",
            "---@return BetterUIUnifiedScreen",
            "---@param keybindDescriptor BetterUIKeybindDescriptorGroup%?",
            "---@param searchKeybindDescriptor BetterUIKeybindDescriptorGroup",
        },
        forbidden = {
            "---@return table",
            "---@param searchKeybindDescriptor table",
        },
    },
    {
        path = "Modules/CIM/Core/Window/WindowClass.lua",
        required = {
            "---@class BetterUIWindow",
            "---@return BetterUIWindow",
        },
        forbidden = {
            "---@return table",
        },
    },
    {
        path = "Modules/Vendor/Vendor.lua",
        required = {
            "---@alias BetterUIVendorModeSet table<number, boolean>",
            "---@class BetterUIVendorBatchItem",
            "---@class BetterUIVendorSellAllJunkComponent",
            "---@param items BetterUIVendorBatchItem%[%]",
            "---@param component BetterUIVendorSellAllJunkComponent",
            "---@return BetterUIKeybindDescriptorGroup keybindGroup",
        },
        forbidden = {
            "---@return table<number, boolean>",
            "---@param items table%[%]",
            "---@param component table",
            "---@return table keybindGroup",
        },
    },
}

for _, entry in ipairs(files) do
    local source = read_file(entry.path)
    for _, pattern in ipairs(entry.required) do
        assert_true(source:find(pattern) ~= nil, entry.path .. " includes " .. pattern)
    end
    for _, pattern in ipairs(entry.forbidden) do
        assert_true(source:find(pattern) == nil, entry.path .. " removes " .. pattern)
    end
end

if failed > 0 then
    error(string.format("test_named_shared_contracts_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_named_shared_contracts_source.lua: %d passed", passed))
