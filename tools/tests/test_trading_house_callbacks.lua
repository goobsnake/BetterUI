--[[
File: tools/tests/test_trading_house_callbacks.lua
Purpose: Regression tests for Trading House callback-driven runtime flow using
         the production coordinator load path.
Usage:
  lua tools/tests/test_trading_house_callbacks.lua
]]

BETTERUI = {
    TradingHouse = {},
    CIM = {},
}

local TH = BETTERUI.TradingHouse

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

local function NewScene(name)
    local scene = {
        name = name,
        showing = false,
    }

    function scene:IsShowing()
        return self.showing
    end

    function scene:AddFragmentGroup(_)
    end

    function scene:AddFragment(_)
    end

    return scene
end

SCENE_MANAGER = {
    scenes = {},
}

function SCENE_MANAGER:GetScene(name)
    return self.scenes[name]
end

function SCENE_MANAGER:Show(name)
    local scene = self.scenes[name]
    if scene then
        scene.showing = true
    end
end

function SCENE_MANAGER:Hide(name)
    local scene = self.scenes[name]
    if scene then
        scene.showing = false
    end
end

function SCENE_MANAGER:HideCurrentScene()
end

EVENT_MANAGER = {
    handlers = {},
}

function EVENT_MANAGER:RegisterForEvent(name, eventCode, callback)
    self.handlers[name] = { eventCode = eventCode, callback = callback }
end

local function getRegisteredCallback(name)
    local entry = EVENT_MANAGER.handlers[name]
    return entry and entry.callback or nil
end

ZO_SimpleSceneFragment = {}

function ZO_SimpleSceneFragment:New(_)
    return {
        SetHideOnSceneHidden = function()
        end,
    }
end

ZO_InteractScene = {}

function ZO_InteractScene:New(name, sceneManager, _)
    local scene = NewScene(name)
    sceneManager.scenes[name] = scene
    return scene
end

BETTERUI.WindowManager = {
    CreateControl = function(_, _, _, _)
        return {
            SetHidden = function()
            end,
        }
    end,
}

BETTERUI.CIM.SceneLifecycle = {
    Register = function(screen, callbacks)
        screen.sceneLifecycle = callbacks
    end,
}

BETTERUI.CIM.CONST = {
    LAYOUT = {
        PANEL = {
            WIDTH = 100,
            ZO_WIDTH = 100,
        },
        COLUMNS = { 10, 20, 30, 40, 50 },
    },
}

KEYBIND_STRIP = {
    updateCount = 0,
}

function KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
    self.updateCount = self.updateCount + 1
end

TH.MODE = {
    BROWSE = 1,
    SELL = 2,
    LISTINGS = 3,
}

TH.TH_INTERACTION = {
    type = "TradingHouse",
    interactTypes = { 1 },
}

function TH.GetSetting(_, fallback)
    if fallback ~= nil then
        return fallback
    end
    return true
end

TH.Tasks = {
    scheduled = {},
    cancelled = {},
}

function TH.Tasks:Cancel(key)
    self.cancelled[#self.cancelled + 1] = key
end

function TH.Tasks:Schedule(key, delay, callback)
    self.scheduled[#self.scheduled + 1] = { key = key, delay = delay }
    if callback then
        callback()
    end
end

TH.BrowseComponent = {
    currentPage = 0,
    searchPending = false,
    searchResultsCount = 0,
    lastInstance = nil,
}

function TH.BrowseComponent:OnSearchResultsReceived(instance)
    self.searchResultsCount = self.searchResultsCount + 1
    self.lastInstance = instance
end

TH.SellComponent = {}
TH.ListingsComponent = {}
TH.THEntrySetup = function()
end

local Class = {}

function Class:New(windowName, sceneName)
    local obj = {
        windowName = windowName,
        sceneName = sceneName,
        control = {},
        currentMode = TH.MODE.BROWSE,
        refreshListCount = 0,
        refreshFooterCount = 0,
        list = {
            Clear = function()
            end,
            Commit = function()
            end,
            GetTargetData = function()
                return nil
            end,
            GetSelectedData = function()
                return nil
            end,
        },
    }
    setmetatable(obj, { __index = self })

    function obj:SetTitle(_)
    end

    function obj:RegisterComponent(_, _)
    end

    function obj:SetupList(_, _)
    end

    function obj:AddColumn(_, _)
    end

    function obj:InitTHFooter()
    end

    function obj:SetMode(mode)
        self.currentMode = mode
    end

    function obj:GetCurrentMode()
        return self.currentMode
    end

    function obj:UpdateTabHeader()
    end

    function obj:GetActiveComponent()
        return nil
    end

    function obj:RefreshList()
        self.refreshListCount = self.refreshListCount + 1
    end

    function obj:RefreshTHFooter()
        self.refreshFooterCount = self.refreshFooterCount + 1
    end

    function obj:GetTitle()
        return "Trading House"
    end

    function obj:IsSceneShowing()
        local scene = SCENE_MANAGER:GetScene(BETTERUI_TRADING_HOUSE_SCENE_NAME)
        return scene and scene:IsShowing()
    end

    return obj
end

TH.Class = Class

BETTERUI_TRADING_HOUSE_SCENE_NAME = "BETTERUI_TradingHouse"

FRAGMENT_GROUP = {
    GAMEPAD_DRIVEN_UI_WINDOW = {},
    FRAME_TARGET_GAMEPAD = {},
}

FRAME_EMOTE_FRAGMENT_INVENTORY = {}
GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT = {}
MINIMIZE_CHAT_FRAGMENT = {}
GAMEPAD_MENU_SOUND_FRAGMENT = {}

KEYBIND_STRIP_ALIGN_LEFT = 1

GAMEPAD_DIALOGS = { PARAMETRIC = 1 }
SI_DIALOG_CONFIRM = "confirm"
SI_DIALOG_CANCEL = "cancel"

GuiRoot = {}
CT_CONTROL = 1

EVENT_OPEN_TRADING_HOUSE = 1
EVENT_CLOSE_TRADING_HOUSE = 2
EVENT_TRADING_HOUSE_SEARCH_RESULTS_RECEIVED = 3
EVENT_TRADING_HOUSE_SEARCH_COOLDOWN_UPDATE = 4
EVENT_TRADING_HOUSE_RESPONSE_RECEIVED = 5
EVENT_TRADING_HOUSE_CONFIRM_ITEM_PURCHASE = 6
EVENT_GUILD_SELF_JOINED_GUILD = 7
EVENT_GUILD_SELF_LEFT_GUILD = 8
EVENT_INVENTORY_SINGLE_SLOT_UPDATE = 9

TRADING_HOUSE_RESULT_SUCCESS = 1
INTERACTION_TRADINGHOUSE = 100
ZO_TRADING_HOUSE_SYSTEM_NAME = "tradingHouse"

function GetString(stringId)
    if stringId == nil then
        return ""
    end
    return tostring(stringId)
end

function ZO_Dialogs_IsDialogRegistered(_)
    return false
end

function ZO_Dialogs_RegisterCustomDialog(_, _)
end

local nativeScene = NewScene("gamepad_trading_house")
SCENE_MANAGER.scenes["gamepad_trading_house"] = nativeScene

SYSTEMS = {
    systems = {
        [ZO_TRADING_HOUSE_SYSTEM_NAME] = {
            gamepadRootScene = nativeScene,
        },
    },
}

function SYSTEMS:GetSystem(systemName)
    local system = self.systems[systemName]
    if not system then
        system = {}
        self.systems[systemName] = system
    end
    return system
end

dofile("Modules/TradingHouse/Core/TradingHouseRuntime.lua")
dofile("Modules/TradingHouse/Core/TradingHouseRuntimeFlow.lua")
dofile("Modules/TradingHouse/TradingHouse.lua")

TH.Init()

local searchResultsCallback = getRegisteredCallback("BetterUI_TradingHouse_SearchResults")
local cooldownCallback = getRegisteredCallback("BetterUI_TradingHouse_Cooldown")
local responseCallback = getRegisteredCallback("BetterUI_TradingHouse_Response")
local listingCallback = getRegisteredCallback("BetterUI_TradingHouse_ListingOp")
local inventoryUpdateCallback = getRegisteredCallback("BetterUI_TradingHouse_InvUpdate")

local scene = SCENE_MANAGER:GetScene(BETTERUI_TRADING_HOUSE_SCENE_NAME)
scene.showing = true

print("[TradingHouse callback flow]")

assert_eq(type(searchResultsCallback), "function", "search results callback is registered")
assert_eq(type(cooldownCallback), "function", "cooldown callback is registered")
assert_eq(type(responseCallback), "function", "response callback is registered")
assert_eq(type(listingCallback), "function", "listing callback is registered")
assert_eq(type(inventoryUpdateCallback), "function", "inventory update callback is registered")

local tabsCopy = TH.GetTabs()
tabsCopy[1].mode = TH.MODE.LISTINGS
tabsCopy[2].name = function()
    return "Hijacked"
end
tabsCopy[#tabsCopy + 1] = {
    mode = 999,
    name = function()
        return "Injected"
    end,
}
local canonicalTabs = TH.GetTabs()
assert_eq(#canonicalTabs, 3, "GetTabs returns a copied tab list")
assert_eq(canonicalTabs[1].mode, TH.MODE.BROWSE, "GetTabs copy mutation does not alter canonical tab modes")
assert_eq(canonicalTabs[2].name() == "Hijacked", false, "GetTabs copy mutation does not alter canonical tab names")

TH.instance:SetMode(TH.MODE.BROWSE)
TH.instance:CycleTabs(1)
assert_eq(TH.instance:GetCurrentMode(), TH.MODE.SELL,
    "tab cycling still follows the canonical tab order after caller mutations")

searchResultsCallback()
assert_eq(TH.BrowseComponent.searchResultsCount, 1,
    "search results callback delegates to BrowseComponent")
assert_eq(TH.BrowseComponent.lastInstance, TH.instance,
    "search results callback passes the Trading House instance")

cooldownCallback()
assert_eq(KEYBIND_STRIP.updateCount, 1,
    "cooldown callback refreshes keybind state while scene is showing")

local scheduleCount = #TH.Tasks.scheduled
responseCallback(nil, 0, TRADING_HOUSE_RESULT_SUCCESS)
assert_eq(#TH.Tasks.scheduled, scheduleCount + 1,
    "successful response schedules a list refresh")
assert_eq(TH.Tasks.scheduled[#TH.Tasks.scheduled].key, "listRefresh",
    "successful response uses the listRefresh task key")
assert_eq(TH.instance.refreshListCount, 1,
    "successful response refreshes the list")
assert_eq(TH.instance.refreshFooterCount, 1,
    "successful response refreshes the footer")

scheduleCount = #TH.Tasks.scheduled
responseCallback(nil, 0, 999)
assert_eq(#TH.Tasks.scheduled, scheduleCount,
    "non-success response does not schedule a refresh")

scheduleCount = #TH.Tasks.scheduled
listingCallback()
assert_eq(#TH.Tasks.scheduled, scheduleCount + 1,
    "listing callback schedules a refresh when scene is showing")
assert_eq(TH.instance.refreshListCount, 2,
    "listing callback refreshes the list")
assert_eq(TH.instance.refreshFooterCount, 2,
    "listing callback refreshes the footer")

TH.instance:SetMode(TH.MODE.SELL)
scheduleCount = #TH.Tasks.scheduled
inventoryUpdateCallback()
assert_eq(#TH.Tasks.scheduled, scheduleCount + 1,
    "inventory updates in sell mode schedule a listing refresh")
assert_eq(TH.instance.refreshListCount, 3,
    "inventory updates in sell mode refresh the list")

TH.instance:SetMode(TH.MODE.BROWSE)
scheduleCount = #TH.Tasks.scheduled
inventoryUpdateCallback()
assert_eq(#TH.Tasks.scheduled, scheduleCount,
    "inventory updates outside sell mode do not schedule listing refresh")

scene.showing = false
scheduleCount = #TH.Tasks.scheduled
listingCallback()
cooldownCallback()
responseCallback(nil, 0, TRADING_HOUSE_RESULT_SUCCESS)
assert_eq(#TH.Tasks.scheduled, scheduleCount,
    "hidden scene blocks callback-driven refresh scheduling")
assert_eq(KEYBIND_STRIP.updateCount, 1,
    "hidden scene blocks cooldown keybind refresh")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
