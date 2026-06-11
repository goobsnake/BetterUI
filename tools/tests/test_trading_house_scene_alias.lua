--[[
File: tools/tests/test_trading_house_scene_alias.lua
Purpose: Regression tests for Trading House scene alias ownership lifecycle.
Usage:
  lua tools/tests/test_trading_house_scene_alias.lua
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
    function scene:GetName()
        return self.name
    end
    function scene:AddFragmentGroup(_)
    end
    function scene:AddFragment(_)
    end
    return scene
end

SCENE_MANAGER = {
    scenes = {},
    lastShown = nil,
    lastHidden = nil,
}

function SCENE_MANAGER:GetScene(name)
    return self.scenes[name]
end

function SCENE_MANAGER:Show(name)
    self.lastShown = name
    local scene = self.scenes[name]
    if scene then
        scene.showing = true
    end
end

function SCENE_MANAGER:Hide(name)
    self.lastHidden = name
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
    if entry then
        return entry.callback
    end
    return nil
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
    UpdateCurrentKeybindButtonGroups = function()
        KEYBIND_STRIP.updateCount = KEYBIND_STRIP.updateCount + 1
    end,
}

TH.MODE = {
    BROWSE = 1,
    SELL = 2,
    LISTINGS = 3,
}

TH.TH_INTERACTION = {
    type = "TradingHouse",
    interactTypes = { 1 },
}

TH.Tasks = {
    cancelCalls = {},
    scheduleCalls = {},
    Cancel = function(_, key)
        if key ~= nil then
            TH.Tasks.cancelCalls[#TH.Tasks.cancelCalls + 1] = key
        end
    end,
    Schedule = function(_, key, delayMs, callback)
        TH.Tasks.scheduleCalls[#TH.Tasks.scheduleCalls + 1] = {
            key = key,
            delayMs = delayMs,
        }
        if callback then
            callback()
        end
    end,
}

TH.BrowseComponent = {
    currentPage = 99,
    searchPending = true,
    onSearchResultsReceivedCount = 0,
    lastSearchResultsInstance = nil,
    OnSearchResultsReceived = function(self, instance)
        self.onSearchResultsReceivedCount = self.onSearchResultsReceivedCount + 1
        self.lastSearchResultsInstance = instance
    end,
}

local Class = {}

function Class:New(windowName, sceneName)
    local obj = {
        windowName = windowName,
        sceneName = sceneName,
        control = {},
        currentMode = TH.MODE.BROWSE,
        list = {
            Clear = function()
            end,
            Commit = function()
            end,
            GetTargetData = function()
                return nil
            end,
        },
    }

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
        self.refreshListCalls = (self.refreshListCalls or 0) + 1
    end
    function obj:RefreshTHFooter()
        self.refreshFooterCalls = (self.refreshFooterCalls or 0) + 1
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
EVENT_TRADING_HOUSE_SEARCH_COOLDOWN_UPDATE = 4
EVENT_TRADING_HOUSE_RESPONSE_RECEIVED = 5
EVENT_TRADING_HOUSE_CONFIRM_ITEM_PURCHASE = 6
EVENT_GUILD_SELF_JOINED_GUILD = 7
EVENT_GUILD_SELF_LEFT_GUILD = 8
EVENT_INVENTORY_SINGLE_SLOT_UPDATE = 9

TRADING_HOUSE_RESULT_SUCCESS = 1
TRADING_HOUSE_RESULT_SEARCH_PENDING = 2
INTERACTION_TRADINGHOUSE = 100
INTERACTION_VENDOR = 200
ZO_TRADING_HOUSE_SYSTEM_NAME = "tradingHouse"

local interactionType

function GetInteractionType()
    return interactionType
end

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

-- Ensure native scene exists before init so native capture is valid.
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

local openCallback = getRegisteredCallback("BetterUI_TradingHouse_Open")
local closeCallback = getRegisteredCallback("BetterUI_TradingHouse_Close")
local cooldownCallback = getRegisteredCallback("BetterUI_TradingHouse_Cooldown")
local responseCallback = getRegisteredCallback("BetterUI_TradingHouse_Response")
local listingOpCallback = getRegisteredCallback("BetterUI_TradingHouse_ListingOp")
local inventoryUpdateCallback = getRegisteredCallback("BetterUI_TradingHouse_InvUpdate")

print("[TradingHouse scene alias ownership]")

assert_eq(type(openCallback), "function", "open callback is registered")
assert_eq(type(closeCallback), "function", "close callback is registered")
assert_eq(type(cooldownCallback), "function", "cooldown callback is registered")
assert_eq(type(responseCallback), "function", "response callback is registered")
assert_eq(type(listingOpCallback), "function", "listing operation callback is registered")
assert_eq(type(inventoryUpdateCallback), "function", "inventory slot callback is registered")

assert_eq(SCENE_MANAGER.scenes["gamepad_trading_house"], TH.instance.scene,
    "init keeps BetterUI scene aliased by default")
assert_eq(SYSTEMS:GetSystem(ZO_TRADING_HOUSE_SYSTEM_NAME).gamepadRootScene, TH.instance.scene,
    "init redirects trading-house system gamepad root scene to BetterUI")

-- Non-trading interactions should restore native alias and abort BetterUI show.
interactionType = INTERACTION_VENDOR
openCallback()
assert_eq(SCENE_MANAGER.scenes["gamepad_trading_house"], nativeScene,
    "non-trading interaction restores native trading-house alias")
assert_eq(SYSTEMS:GetSystem(ZO_TRADING_HOUSE_SYSTEM_NAME).gamepadRootScene, nativeScene,
    "non-trading interaction restores native system root scene")

-- Interaction type can be nil briefly; BetterUI must still claim ownership.
interactionType = nil
openCallback()
assert_eq(SCENE_MANAGER.scenes["gamepad_trading_house"], TH.instance.scene,
    "nil interaction still aliases trading-house scene to BetterUI")
assert_eq(SYSTEMS:GetSystem(ZO_TRADING_HOUSE_SYSTEM_NAME).gamepadRootScene, TH.instance.scene,
    "nil interaction still redirects system root scene to BetterUI")
assert_eq(SCENE_MANAGER.lastShown, BETTERUI_TRADING_HOUSE_SCENE_NAME,
    "open callback shows BetterUI trading-house scene")

-- Close should keep BetterUI alias for the next open cycle.
closeCallback()
assert_eq(SCENE_MANAGER.scenes["gamepad_trading_house"], TH.instance.scene,
    "close callback keeps BetterUI alias for next open")
assert_eq(SYSTEMS:GetSystem(ZO_TRADING_HOUSE_SYSTEM_NAME).gamepadRootScene, TH.instance.scene,
    "close callback keeps BetterUI system root ownership for next open")
assert_eq(SCENE_MANAGER.lastHidden, BETTERUI_TRADING_HOUSE_SCENE_NAME,
    "close callback hides BetterUI trading-house scene when showing")

print("[TradingHouse live callbacks]")

interactionType = nil
openCallback()

-- U50: search results arrive through the response event with the
-- TRADING_HOUSE_RESULT_SEARCH_PENDING response type.
responseCallback(nil, TRADING_HOUSE_RESULT_SEARCH_PENDING, TRADING_HOUSE_RESULT_SUCCESS)
assert_eq(TH.BrowseComponent.onSearchResultsReceivedCount, 1,
    "search-pending response dispatches search results to BrowseComponent")
assert_eq(TH.BrowseComponent.lastSearchResultsInstance, TH.instance,
    "search results dispatch passes the live trading-house instance")

cooldownCallback()
assert_eq(KEYBIND_STRIP.updateCount, 1,
    "cooldown callback refreshes live keybind state while scene is showing")

local baselineRefreshListCalls = TH.instance.refreshListCalls or 0
local baselineRefreshFooterCalls = TH.instance.refreshFooterCalls or 0
responseCallback(nil, 123, TRADING_HOUSE_RESULT_SUCCESS)
assert_eq(TH.Tasks.scheduleCalls[#TH.Tasks.scheduleCalls].key, "listRefresh",
    "successful trading-house responses schedule a list refresh")
assert_eq(TH.instance.refreshListCalls, baselineRefreshListCalls + 1,
    "successful trading-house responses refresh the live list")
assert_eq(TH.instance.refreshFooterCalls, baselineRefreshFooterCalls + 1,
    "successful trading-house responses refresh the live footer")

baselineRefreshListCalls = TH.instance.refreshListCalls
responseCallback(nil, 123, 999)
assert_eq(TH.instance.refreshListCalls, baselineRefreshListCalls,
    "non-success responses do not refresh the live list")

baselineRefreshListCalls = TH.instance.refreshListCalls
listingOpCallback()
assert_eq(TH.instance.refreshListCalls, baselineRefreshListCalls + 1,
    "listing operations refresh the live list while scene is showing")

TH.instance.currentMode = TH.MODE.SELL
baselineRefreshListCalls = TH.instance.refreshListCalls
inventoryUpdateCallback()
assert_eq(TH.instance.refreshListCalls, baselineRefreshListCalls + 1,
    "inventory updates refresh listings when the sell tab is active")

TH.instance.currentMode = TH.MODE.BROWSE
baselineRefreshListCalls = TH.instance.refreshListCalls
inventoryUpdateCallback()
assert_eq(TH.instance.refreshListCalls, baselineRefreshListCalls,
    "inventory updates do not refresh listings outside the sell tab")

closeCallback()
baselineRefreshListCalls = TH.instance.refreshListCalls
cooldownCallback()
listingOpCallback()
responseCallback(nil, 123, TRADING_HOUSE_RESULT_SUCCESS)
assert_eq(KEYBIND_STRIP.updateCount, 1,
    "cooldown callback does not refresh keybinds after the scene hides")
assert_eq(TH.instance.refreshListCalls, baselineRefreshListCalls,
    "hidden scene callbacks do not refresh the live list")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
