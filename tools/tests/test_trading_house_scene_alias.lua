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
    UpdateCurrentKeybindButtonGroups = function()
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
    Cancel = function()
    end,
    Schedule = function(_, _, _, callback)
        if callback then
            callback()
        end
    end,
}

TH.BrowseComponent = {
    currentPage = 99,
    searchPending = true,
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
    end
    function obj:RefreshTHFooter()
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

dofile("Modules/TradingHouse/TradingHouse.lua")

TH.Init()

local openCallback = getRegisteredCallback("BetterUI_TradingHouse_Open")
local closeCallback = getRegisteredCallback("BetterUI_TradingHouse_Close")

print("[TradingHouse scene alias ownership]")

assert_eq(type(openCallback), "function", "open callback is registered")
assert_eq(type(closeCallback), "function", "close callback is registered")

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

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
