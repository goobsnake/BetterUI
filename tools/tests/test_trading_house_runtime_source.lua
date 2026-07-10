--[[
File: tools/tests/test_trading_house_runtime_source.lua
Purpose: Guards the Trading House root/runtime split so TradingHouse.lua stays
         focused on lifecycle wiring while the core runtime helper owns scene
         ownership, keybinds, dialogs, and event routing.
Usage:
  lua tools/tests/test_trading_house_runtime_source.lua
]]

if false then
    dofile("Modules/TradingHouse/Core/TradingHouseRuntime.lua")
    dofile("Modules/TradingHouse/Core/TradingHouseRuntimeFlow.lua")
    dofile("Modules/TradingHouse/TradingHouse.lua")
end

local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local function assert_contains(haystack, needle, label)
    if not haystack:find(needle, 1, true) then
        error(label .. "\nMissing: " .. needle)
    end
end

local function assert_not_contains(haystack, needle, label)
    if haystack:find(needle, 1, true) then
        error(label .. "\nUnexpected: " .. needle)
    end
end

print("test_trading_house_runtime_source")

local entrySource = read_file("Modules/TradingHouse/TradingHouse.lua")
local runtimeSource = read_file("Modules/TradingHouse/Core/TradingHouseRuntime.lua")
local flowSource = read_file("Modules/TradingHouse/Core/TradingHouseRuntimeFlow.lua")
local classSource = read_file("Modules/TradingHouse/Core/TradingHouseClass.lua")
local settingsSource = read_file("Modules/TradingHouse/Settings/SettingsPanel.lua")
local browseSource = read_file("Modules/TradingHouse/Components/BrowseComponent.lua")
local manifestSource = read_file("BetterUI.txt")

assert_contains(runtimeSource, "function TH.RegisterSceneLifecycle(instance)",
    "Trading House runtime helper owns scene lifecycle registration")
assert_not_contains(runtimeSource, "function TH.GetTabs(",
    "Trading House runtime helper no longer exposes the dead test-only GetTabs export")
assert_contains(runtimeSource, "---@param instance BETTERUI.TradingHouse.Class",
    "Trading House runtime helper annotates exported helpers with the trading house instance type")
assert_contains(runtimeSource, "---@return nil",
    "Trading House runtime helper annotates side-effect exports with explicit nil returns")
assert_contains(runtimeSource, "function TH.BuildCoreKeybinds(thInstance)",
    "Trading House runtime helper owns core keybind construction")
assert_contains(runtimeSource, "function TH.BuildTabKeybinds(thInstance)",
    "Trading House runtime helper owns tab keybind construction")
assert_contains(flowSource, "function TH.TakeOverNativeTradingHouse()",
    "Trading House flow helper owns native scene takeover")
assert_not_contains(flowSource, "SCENE_MANAGER.scenes[\"gamepad_trading_house\"] =",
    "Trading House does not replace the shared gamepad_trading_house scene table entry")
assert_not_contains(flowSource, "nativeTH.OpenTradingHouse = function",
    "Trading House leaves the native OpenTradingHouse method untouched")
assert_not_contains(flowSource, "nativeTH.CloseTradingHouse = function",
    "Trading House leaves the native CloseTradingHouse method untouched")
assert_not_contains(flowSource, "nativeTH.sceneName =",
    "Trading House leaves native sceneName metadata intact")
assert_contains(flowSource, "local function AssociateSearchFeatures()",
    "Trading House flow helper owns search-feature association")
assert_contains(flowSource, "local function DisassociateSearchFeatures()",
    "Trading House flow helper owns search-feature disassociation")
assert_contains(flowSource, "function TH.OnTradingHouseResponseTimeout()",
    "Trading House flow helper owns response timeout handler")
assert_contains(flowSource, "function TH.OnTradingHouseOperationTimeout()",
    "Trading House flow helper owns operation timeout handler")
assert_contains(flowSource, "function TH.GetKeybindRefreshFingerprint()",
    "Trading House flow helper owns the label-relevant keybind state fingerprint")
assert_contains(flowSource, "iface.ShouldSkipRedundantKeybindRefresh(TH.instance, fingerprint, force == true)",
    "Trading House global keybind refreshes use same-frame state-equivalence coalescing")
assert_not_contains(classSource, "BETTERUI.Interface.UpdateCurrentKeybindGroups",
    "Trading House mode changes route global refreshes through the coalescing helper")
assert_contains(classSource, "BETTERUI.TradingHouse.RefreshCurrentTradingHouseKeybinds",
    "Trading House mode changes use the shared fingerprinted keybind refresh")
assert_not_contains(settingsSource, "BETTERUI.Interface.UpdateCurrentKeybindGroups",
    "Trading House settings do not bypass the shared keybind refresh helper")
assert_contains(settingsSource, 'TH.RefreshCurrentTradingHouseKeybinds("TradingHouse.Settings:RefreshTHWindow", "settingsChanged", true)',
    "Trading House settings force their distinct external state refresh")
assert_contains(flowSource, "function TH.OnSelectedTradingHouseGuildChanged()",
    "Trading House flow helper owns selected-guild-changed handler")
assert_contains(flowSource, "function TH.OnTradingHouseStatusReceived()",
    "Trading House flow helper owns status-received handler")
assert_contains(flowSource, "function TH.OnMoneyUpdate()",
    "Trading House flow helper owns money-update handler")
assert_contains(flowSource, "EVENT_TRADING_HOUSE_RESPONSE_TIMEOUT",
    "Trading House registers response timeout event")
assert_contains(flowSource, "EVENT_TRADING_HOUSE_OPERATION_TIME_OUT",
    "Trading House registers operation timeout event")
assert_contains(flowSource, "EVENT_TRADING_HOUSE_SELECTED_GUILD_CHANGED",
    "Trading House registers selected-guild-changed event")
assert_contains(flowSource, "EVENT_TRADING_HOUSE_STATUS_RECEIVED",
    "Trading House registers status-received event")
assert_contains(flowSource, "EVENT_MONEY_UPDATE",
    "Trading House registers money-update event")
assert_contains(browseSource, "TRADING_HOUSE_SEARCH.features",
    "Trading House guards ApplyFilters with features table")
assert_not_contains(flowSource, "UserAlertText(\"TH:SearchFailed\"",
    "Trading House flow helper no longer duplicates ZOS search-failure alert")
assert_contains(flowSource, "function TH.RegisterCreateListingDialog()",
    "Trading House flow helper owns dialog registration")
assert_contains(flowSource, "function TH.RegisterEvents(eventManager)",
    "Trading House flow helper owns event registration")
assert_contains(flowSource, "function TH.OnOpenTradingHouse()",
    "Trading House flow helper owns open callback routing")
assert_contains(flowSource, "function TH.TakeOverNativeTradingHouse()",
    "Trading House flow helper owns native scene takeover")

assert_not_contains(entrySource, "local function RegisterCreateListingDialog(",
    "TradingHouse.lua no longer defines dialog registration locally")
assert_not_contains(entrySource, "local function RegisterTradingHouseSceneLifecycle(",
    "TradingHouse.lua no longer defines scene lifecycle locally")
assert_not_contains(entrySource, "local function RegisterTradingHouseEvents(",
    "TradingHouse.lua no longer defines event registration locally")
assert_not_contains(entrySource, "local function TakeOverNativeTradingHouse(",
    "TradingHouse.lua no longer defines native scene takeover locally")
assert_not_contains(entrySource, "local function BuildCoreKeybinds(",
    "TradingHouse.lua no longer defines keybind builders locally")
assert_contains(entrySource, "TH.RegisterCreateListingDialog()",
    "TradingHouse.lua delegates dialog registration to the runtime helper")
assert_contains(entrySource, "TH.BuildCoreKeybinds(TH.instance)",
    "TradingHouse.lua delegates core keybind construction to the runtime helper")
assert_contains(entrySource, "TH.BuildTabKeybinds(TH.instance)",
    "TradingHouse.lua delegates tab keybind construction to the runtime helper")
assert_contains(entrySource, "TH.TakeOverNativeTradingHouse()",
    "TradingHouse.lua delegates native scene takeover to the runtime helper")
assert_contains(entrySource, "TH.RegisterSceneLifecycle(TH.instance)",
    "TradingHouse.lua delegates scene lifecycle registration to the runtime helper")
assert_contains(entrySource, "TH.RegisterEvents(EVENT_MANAGER)",
    "TradingHouse.lua delegates event registration to the runtime helper")
assert_contains(manifestSource, "Modules\\TradingHouse\\Core\\TradingHouseRuntime.lua",
    "Addon manifest loads the new Trading House runtime helper")
assert_contains(manifestSource, "Modules\\TradingHouse\\Core\\TradingHouseRuntimeFlow.lua",
    "Addon manifest loads the new Trading House flow helper")

print("  OK")
