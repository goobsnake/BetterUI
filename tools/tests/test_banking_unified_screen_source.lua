--[[
File: tools/tests/test_banking_unified_screen_source.lua
Purpose: Guards the staged Banking migration onto the shared UnifiedScreen bootstrap seam.

Usage:
  lua tools/tests/test_banking_unified_screen_source.lua
]]

if false then
    dofile("Modules/Banking/Banking.lua")
end

local function read_file(path)
    local file = assert(io.open(path, "r"))
    local content = file:read("*a")
    file:close()
    return content
end

local function assert_contains(haystack, needle, message)
    if not haystack:find(needle, 1, true) then
        error(message .. "\nMissing: " .. needle)
    end
end

print("test_banking_unified_screen_source")

local bankingSource = read_file("Modules/Banking/Banking.lua")
local unifiedScreenSource = read_file("Modules/CIM/Core/Window/UnifiedScreen.lua")

assert_contains(
    unifiedScreenSource,
    "function BETTERUI.CIM.UnifiedScreen.InitializeWindowShell(screen, tlwName, sceneName, footerMode, virtualTemplate)",
    "UnifiedScreen exposes the shared window-shell bootstrap helper"
)

assert_contains(
    unifiedScreenSource,
    "BETTERUI.Interface.Window.Initialize(screen, tlwName, sceneName, virtualTemplate)",
    "UnifiedScreen window-shell helper delegates through the legacy window initializer"
)

assert_contains(
    unifiedScreenSource,
    "screen.footerMode = footerMode or MODE.CURRENCY",
    "UnifiedScreen window-shell helper sets the shared footer mode contract"
)

assert_contains(
    bankingSource,
    "BETTERUI.CIM.UnifiedScreen.InitializeWindowShell(",
    "Banking initialization bootstraps through the shared UnifiedScreen seam"
)

assert_contains(
    bankingSource,
    "BETTERUI.CIM.UnifiedScreen.FOOTER_MODE_BANKING",
    "Banking initialization selects the BANKING footer mode through UnifiedScreen"
)

print("  OK")
