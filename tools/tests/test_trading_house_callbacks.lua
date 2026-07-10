--[[
File: tools/tests/test_trading_house_callbacks.lua
Purpose: Regression tests for Trading House callback-driven runtime flow using
         the production coordinator load path.
Usage:
  lua tools/tests/test_trading_house_callbacks.lua
]]

BETTERUI = {
    TradingHouse = {},
    Interface = {
        UpdateCurrentKeybindGroups = function()
            if KEYBIND_STRIP and KEYBIND_STRIP.UpdateCurrentKeybindButtonGroups then
                KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
                return true
            end
            return false
        end,
    },
    CIM = {},
}

local keybindFrame = 1
local keybindRefreshStates = {}
local keybindRefreshFingerprints = {}
BETTERUI.Interface.ShouldSkipRedundantKeybindRefresh = function(owner, fingerprint, force)
    keybindRefreshFingerprints[#keybindRefreshFingerprints + 1] = fingerprint
    local previous = keybindRefreshStates[owner]
    keybindRefreshStates[owner] = { frame = keybindFrame, fingerprint = fingerprint }
    return force ~= true
        and previous ~= nil
        and previous.frame == keybindFrame
        and previous.fingerprint == fingerprint
end

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

function EVENT_MANAGER:UnregisterForEvent(name, eventCode)
    local entry = self.handlers[name]
    if entry and entry.eventCode == eventCode then
        self.handlers[name] = nil
    end
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
    resultsInvalidated = false,
    InvalidateResults = function(self)
        self.resultsInvalidated = true
    end,
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
        updateTabHeaderCount = 0,
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
        self.updateTabHeaderCount = self.updateTabHeaderCount + 1
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
EVENT_TRADING_HOUSE_SEARCH_COOLDOWN_UPDATE = 4
EVENT_TRADING_HOUSE_RESPONSE_RECEIVED = 5
EVENT_TRADING_HOUSE_CONFIRM_ITEM_PURCHASE = 6
EVENT_GUILD_SELF_JOINED_GUILD = 7
EVENT_GUILD_SELF_LEFT_GUILD = 8
EVENT_INVENTORY_SINGLE_SLOT_UPDATE = 9
EVENT_TRADING_HOUSE_RESPONSE_TIMEOUT = 10
EVENT_TRADING_HOUSE_OPERATION_TIME_OUT = 11
EVENT_TRADING_HOUSE_SELECTED_GUILD_CHANGED = 12
EVENT_TRADING_HOUSE_STATUS_RECEIVED = 13
EVENT_MONEY_UPDATE = 14

TRADING_HOUSE_RESULT_SUCCESS = 1
TRADING_HOUSE_RESULT_SEARCH_PENDING = 2
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

-- Mock native gamepad browse object and search singleton for feature association.
local associatedFeatures = nil
local disassociated = false
GAMEPAD_TRADING_HOUSE_BROWSE = {
    features = { nameSearchFeature = {} },
    GetFeatures = function(self)
        return self.features
    end,
}
TRADING_HOUSE_SEARCH = {
    features = nil,
    AssociateWithSearchFeatures = function(self, features)
        self.features = features
        associatedFeatures = features
    end,
    DisassociateWithSearchFeatures = function(self)
        self.features = nil
        disassociated = true
    end,
}

-- Guild selection mocks.
local selectedGuildId = nil
local currentInteractionType = INTERACTION_TRADINGHOUSE
function GetInteractionType()
    return currentInteractionType
end
function GetSelectedTradingHouseGuildId()
    return selectedGuildId
end
function SelectTradingHouseGuildId(guildId)
    selectedGuildId = guildId
end
function GetGuildId(index)
    return 100 + index
end
function GetNumTradingHouseGuilds()
    return 2
end
function GetTradingHouseGuildDetails(index)
    return 100 + index, "Guild " .. tostring(index)
end
function GetGuildName(guildId)
    return "Guild " .. tostring(guildId - 100)
end
local requestListingsCount = 0
function RequestTradingHouseListings()
    requestListingsCount = requestListingsCount + 1
end
function GetCurrencyAmount()
    return 1000
end

local nativeOpenCount = 0
local nativeCloseCount = 0
local nativeOpenFails = false
local nativeCloseFails = false
TRADING_HOUSE_GAMEPAD = {
    sceneName = "gamepad_trading_house",
    OpenTradingHouse = function()
        nativeOpenCount = nativeOpenCount + 1
        if nativeOpenFails then
            error("native open failed")
        end
        nativeScene.showing = true
    end,
    CloseTradingHouse = function()
        nativeCloseCount = nativeCloseCount + 1
        if nativeCloseFails then
            error("native close failed")
        end
        nativeScene.showing = false
    end,
}

dofile("Modules/TradingHouse/Core/TradingHouseRuntime.lua")
dofile("Modules/TradingHouse/Core/TradingHouseRuntimeFlow.lua")
dofile("Modules/TradingHouse/TradingHouse.lua")

TH.Init()
local cooldownCallback = getRegisteredCallback("BetterUI_TradingHouse_Cooldown")
local responseCallback = getRegisteredCallback("BetterUI_TradingHouse_Response")
local responseTimeoutCallback = getRegisteredCallback("BetterUI_TradingHouse_ResponseTimeout")
local operationTimeoutCallback = getRegisteredCallback("BetterUI_TradingHouse_OperationTimeout")
local listingCallback = getRegisteredCallback("BetterUI_TradingHouse_ListingOp")
local selectedGuildChangedCallback = getRegisteredCallback("BetterUI_TradingHouse_SelectedGuildChanged")
local statusReceivedCallback = getRegisteredCallback("BetterUI_TradingHouse_StatusReceived")
local moneyUpdateCallback = getRegisteredCallback("BetterUI_TradingHouse_MoneyUpdate")
local inventoryUpdateCallback = getRegisteredCallback("BetterUI_TradingHouse_InvUpdate")

local scene = SCENE_MANAGER:GetScene(BETTERUI_TRADING_HOUSE_SCENE_NAME)
scene.showing = true

print("[TradingHouse callback flow]")
assert_eq(type(cooldownCallback), "function", "cooldown callback is registered")
assert_eq(type(responseCallback), "function", "response callback is registered")
assert_eq(type(responseTimeoutCallback), "function", "response timeout callback is registered")
assert_eq(type(operationTimeoutCallback), "function", "operation timeout callback is registered")
assert_eq(type(listingCallback), "function", "listing callback is registered")
assert_eq(type(selectedGuildChangedCallback), "function", "selected guild changed callback is registered")
assert_eq(type(statusReceivedCallback), "function", "status received callback is registered")
assert_eq(type(moneyUpdateCallback), "function", "money update callback is registered")
assert_eq(type(inventoryUpdateCallback), "function", "inventory update callback is registered")

TH.instance:SetMode(TH.MODE.BROWSE)
TH.instance:CycleTabs(1)
assert_eq(TH.instance:GetCurrentMode(), TH.MODE.SELL,
    "tab cycling follows the canonical tab order")

-- U50: search results arrive through the response event with the
-- TRADING_HOUSE_RESULT_SEARCH_PENDING response type.
responseCallback(nil, TRADING_HOUSE_RESULT_SEARCH_PENDING, TRADING_HOUSE_RESULT_SUCCESS)
assert_eq(TH.BrowseComponent.searchResultsCount, 1,
    "search-pending response dispatches search results to BrowseComponent")
assert_eq(TH.BrowseComponent.lastInstance, TH.instance,
    "search results dispatch passes the Trading House instance")

cooldownCallback()
assert_eq(KEYBIND_STRIP.updateCount, 1,
    "cooldown callback refreshes keybind state while scene is showing")

-- Same-frame global refreshes coalesce only while their state fingerprint is
-- equivalent. A distinct pending-state transition must refresh immediately.
local burstStart = KEYBIND_STRIP.updateCount
cooldownCallback()
assert_eq(KEYBIND_STRIP.updateCount, burstStart,
    "same-frame equivalent Trading House keybind refresh burst is coalesced")
local equivalentFingerprint = keybindRefreshFingerprints[#keybindRefreshFingerprints]
TH.BrowseComponent.searchPending = true
cooldownCallback()
assert_eq(KEYBIND_STRIP.updateCount, burstStart + 1,
    "same-frame Trading House pending-state change refreshes immediately")
local changedFingerprint = keybindRefreshFingerprints[#keybindRefreshFingerprints]
assert_eq(equivalentFingerprint == changedFingerprint, false,
    "Trading House keybind fingerprint changes with label-relevant pending state")
TH.BrowseComponent.searchPending = false

local scheduleCount = #TH.Tasks.scheduled
responseCallback(nil, 0, TRADING_HOUSE_RESULT_SUCCESS)
assert_eq(#TH.Tasks.scheduled, scheduleCount + 1,
    "successful response schedules a list refresh")
assert_eq(TH.Tasks.scheduled[#TH.Tasks.scheduled].key, "listRefresh",
    "successful response uses the listRefresh task key")
assert_eq(TH.instance.refreshListCount, 2,
    "successful response refreshes the list")
assert_eq(TH.instance.refreshFooterCount, 2,
    "successful response refreshes the footer")

scheduleCount = #TH.Tasks.scheduled
responseCallback(nil, 0, 999)
assert_eq(#TH.Tasks.scheduled, scheduleCount,
    "non-success response does not schedule a refresh")

scheduleCount = #TH.Tasks.scheduled
listingCallback()
assert_eq(#TH.Tasks.scheduled, scheduleCount + 1,
    "listing callback schedules a refresh when scene is showing")
assert_eq(TH.instance.refreshListCount, 3,
    "listing callback refreshes the list")
assert_eq(TH.instance.refreshFooterCount, 3,
    "listing callback refreshes the footer")

TH.instance:SetMode(TH.MODE.SELL)
scheduleCount = #TH.Tasks.scheduled
inventoryUpdateCallback()
assert_eq(#TH.Tasks.scheduled, scheduleCount + 1,
    "inventory updates in sell mode schedule a listing refresh")
assert_eq(TH.instance.refreshListCount, 4,
    "inventory updates in sell mode refresh the list")

TH.instance:SetMode(TH.MODE.BROWSE)
scheduleCount = #TH.Tasks.scheduled
inventoryUpdateCallback()
assert_eq(#TH.Tasks.scheduled, scheduleCount,
    "inventory updates outside sell mode do not schedule listing refresh")

scene.showing = false
scheduleCount = #TH.Tasks.scheduled
local visibleKeybindRefreshCount = KEYBIND_STRIP.updateCount
listingCallback()
cooldownCallback()
responseCallback(nil, 0, TRADING_HOUSE_RESULT_SUCCESS)
assert_eq(#TH.Tasks.scheduled, scheduleCount,
    "hidden scene blocks callback-driven refresh scheduling")
assert_eq(KEYBIND_STRIP.updateCount, visibleKeybindRefreshCount,
    "hidden scene blocks cooldown keybind refresh")

-- Open/close search-feature association contract.
scene.showing = true
TH.BrowseComponent.searchPending = false
TH.OnOpenTradingHouse()
assert_eq(associatedFeatures, GAMEPAD_TRADING_HOUSE_BROWSE.features,
    "OnOpenTradingHouse associates TRADING_HOUSE_SEARCH with gamepad browse features")
assert_eq(selectedGuildId, GetGuildId(1),
    "OnOpenTradingHouse selects the first guild when none was selected")
TH.OnCloseTradingHouse()
assert_eq(disassociated, true,
    "OnCloseTradingHouse disassociates search features")

local savedInstance = TH.instance
TH.instance = nil
nativeOpenCount = 0
nativeCloseCount = 0
disassociated = false
TH.OnOpenTradingHouse()
assert_eq(nativeOpenCount, 1,
    "OnOpenTradingHouse hands off to native trading house when BetterUI has no instance")
assert_eq(TH.nativeHandoffActive, true,
    "Native handoff remains active until the matching close event")
TH.OnCloseTradingHouse()
assert_eq(nativeCloseCount, 1,
    "OnCloseTradingHouse drives native close after a native handoff")
assert_eq(TH.nativeHandoffActive, false,
    "Native handoff flag clears after native close")
assert_eq(disassociated, false,
    "Native-only handoff skips BetterUI search cleanup")

nativeOpenFails = true
nativeOpenCount = 0
TH.OnOpenTradingHouse()
assert_eq(nativeOpenCount, 1,
    "OnOpenTradingHouse attempts native open when BetterUI has no instance")
assert_eq(TH.nativeHandoffActive, false,
    "Failed native open does not leave handoff active")
nativeOpenFails = false
TH.instance = savedInstance

currentInteractionType = 999
nativeOpenCount = 0
TH.OnOpenTradingHouse()
assert_eq(nativeOpenCount, 1,
    "OnOpenTradingHouse hands off to native trading house on interaction mismatch")
currentInteractionType = INTERACTION_TRADINGHOUSE
TH.OnCloseTradingHouse()

local savedShowScene = TH.ShowScene
TH.ShowScene = function()
    return false, "forcedShowFailure"
end
disassociated = false
associatedFeatures = nil
nativeOpenCount = 0
nativeCloseCount = 0
nativeCloseFails = true
TH.OnOpenTradingHouse()
assert_eq(nativeOpenCount, 1,
    "OnOpenTradingHouse hands off after a BetterUI show failure")
assert_eq(TH.nativeHandoffActive, true,
    "Successful native open remains active after BetterUI show failure")
TH.OnCloseTradingHouse()
assert_eq(nativeCloseCount, 1,
    "OnCloseTradingHouse attempts native close after BetterUI show failure")
assert_eq(disassociated, true,
    "OnCloseTradingHouse runs BetterUI cleanup when native close fails after show failure")
assert_eq(TH.nativeHandoffActive, false,
    "Native handoff flag clears after failed native close")
nativeCloseFails = false
TH.ShowScene = savedShowScene

-- Timeout handlers clear pending search state.
TH.BrowseComponent.searchPending = true
responseTimeoutCallback()
assert_eq(TH.BrowseComponent.searchPending, false,
    "response timeout clears searchPending")
TH.BrowseComponent.searchPending = true
operationTimeoutCallback()
assert_eq(TH.BrowseComponent.searchPending, false,
    "operation timeout clears searchPending")

-- Guild change invalidation refreshes header and list.
scene.showing = true
TH.BrowseComponent.resultsInvalidated = false
TH.instance.updateTabHeaderCount = 0
selectedGuildChangedCallback()
assert_eq(TH.BrowseComponent.resultsInvalidated, true,
    "selected-guild-changed invalidates browse results")
assert_eq(TH.instance.updateTabHeaderCount, 1,
    "selected-guild-changed updates tab header")

-- In LISTINGS mode while the scene is showing, the guild change requests
-- fresh server listings.
TH.instance:SetMode(TH.MODE.LISTINGS)
requestListingsCount = 0
selectedGuildChangedCallback()
assert_eq(requestListingsCount, 1,
    "selected-guild-changed requests listings when showing in listings mode")
TH.instance:SetMode(TH.MODE.BROWSE)

-- Off-scene guard: the guild selector UI calls SelectTradingHouseGuildId
-- globally, so EVENT_TRADING_HOUSE_SELECTED_GUILD_CHANGED can fire while our
-- scene is hidden. The handler must return early -- no server listings
-- request and no header rebuild -- just like the sibling handlers.
scene.showing = false
TH.instance:SetMode(TH.MODE.LISTINGS)
TH.BrowseComponent.resultsInvalidated = false
TH.instance.updateTabHeaderCount = 0
requestListingsCount = 0
selectedGuildChangedCallback()
assert_eq(requestListingsCount, 0,
    "off-scene selected-guild-changed does not request listings")
assert_eq(TH.instance.updateTabHeaderCount, 0,
    "off-scene selected-guild-changed does not rebuild the header")
assert_eq(TH.BrowseComponent.resultsInvalidated, false,
    "off-scene selected-guild-changed does not invalidate browse results")
scene.showing = true
TH.instance:SetMode(TH.MODE.BROWSE)

-- Status received refreshes listings when in listings mode.
TH.instance:SetMode(TH.MODE.LISTINGS)
statusReceivedCallback()
-- The mock RequestTradingHouseListings is a no-op; the test verifies no error.

-- Money update refreshes footer and keybind enabled states while showing.
-- Row data does not depend on wallet state, so no full list refresh is scheduled.
TH.instance:SetMode(TH.MODE.BROWSE)
local footerCount = TH.instance.refreshFooterCount
local keybindCount = KEYBIND_STRIP.updateCount
scheduleCount = #TH.Tasks.scheduled
moneyUpdateCallback()
assert_eq(TH.instance.refreshFooterCount, footerCount + 1,
    "money update refreshes footer directly while scene is showing")
assert_eq(KEYBIND_STRIP.updateCount, keybindCount + 1,
    "money update refreshes keybind enabled states while scene is showing")
assert_eq(#TH.Tasks.scheduled, scheduleCount,
    "money update does not schedule a full list refresh")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
