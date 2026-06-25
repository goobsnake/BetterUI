--[[
File: tools/tests/test_companions_scene_lifecycle.lua
Purpose: Regression tests for companion scene lifecycle refresh orchestration.

Usage:
  lua tools/tests/test_companions_scene_lifecycle.lua
]]

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

local function assert_true(value, label)
    assert_eq(value, true, label)
end

local registeredEvents = {}
local scheduledTasks = {}
local hideCurrentSceneCalls = 0
local tooltipWidthCalls = {}

local function noop() end

BETTERUI = {
    Companions = {
        Class = {},
        Settings = {
            RegisterPanel = function() end,
        },
        RegisterDialogs = function() end,
        Tasks = {},
        COMPANION_INTERACTION = {
            type = "Companion",
        },
    },
    CIM = {
        CONST = {
            LAYOUT = {
                PANEL = {
                    WIDTH = 100,
                    ZO_WIDTH = 80,
                },
            },
            HEADER_LAYOUT = {
                COLUMNS = {
                    NAME = 1,
                    TYPE = 2,
                    TRAIT = 3,
                    STAT = 4,
                    VALUE = 5,
                },
            },
        },
        ApplyModuleSharedSettingsStatics = function() end,
        RegisterModuleAccessors = function() end,
        InitModuleDefaults = function(_, options)
            return options
        end,
        SetTooltipWidth = function(width)
            tooltipWidthCalls[#tooltipWidthCalls + 1] = width
        end,
        SceneLifecycle = {
            Register = function(screen, callbacks)
                screen.sceneLifecycle = callbacks
            end,
        },
        PositionManager = {
            SavePosition = noop,
        },
        Narration = {},
        UI = {
            HeaderSortIntegration = {
                Install = function(instance, config)
                    return {
                        instance = instance,
                        config = config,
                    }
                end,
                EnsureController = function(integration)
                    integration.controllerEnsured = true
                end,
            },
        },
    },
    Interface = {
        SearchMixin = {},
        CreateSearchKeybindDescriptor = function()
            return {}
        end,
    },
    WindowManager = {
        CreateControl = function()
            return {
                SetHidden = noop,
            }
        end,
    },
}

BETTERUI.Companions.Tasks.Cancel = function(_, key)
    scheduledTasks[#scheduledTasks + 1] = "cancel:" .. tostring(key)
end
BETTERUI.Companions.Tasks.Schedule = function(_, key, _, callback)
    scheduledTasks[#scheduledTasks + 1] = tostring(key)
    if callback then
        callback()
    end
end

function BETTERUI.Debug(_) end
function GetString(value)
    return tostring(value)
end

BETTERUI_COMPANION_EQUIP_SCENE_NAME = "BETTERUI_CompanionScene"
INTERACTION_COMPANION_MENU = 1
SCENE_SHOWN = "shown"
SCENE_SHOWING = "showing"
SCENE_HIDING = "hiding"
SCENE_HIDDEN = "hidden"
EVENT_COMPANION_ACTIVATED = 1
EVENT_COMPANION_DEACTIVATED = 2
EVENT_INVENTORY_SINGLE_SLOT_UPDATE = 3
EVENT_INVENTORY_FULL_UPDATE = 4
CT_CONTROL = 1
GuiRoot = {}
SI_BETTERUI_COMPANIONS_TITLE = "Companions"
SI_BETTERUI_INV_HEADER_NAME = "Name"
SI_BETTERUI_INV_HEADER_TYPE = "Type"
SI_BETTERUI_INV_HEADER_TRAIT = "Trait"
SI_BETTERUI_INV_HEADER_STAT = "Stat"
SI_BETTERUI_INV_HEADER_VALUE = "Value"
FRAGMENT_GROUP = {
    GAMEPAD_DRIVEN_UI_WINDOW = {},
    FRAME_TARGET_GAMEPAD = {},
}
FRAME_EMOTE_FRAGMENT_INVENTORY = {}
GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT = {}
MINIMIZE_CHAT_FRAGMENT = {}
GAMEPAD_MENU_SOUND_FRAGMENT = {}
GAMEPAD_LEFT_TOOLTIP = "left"
GAMEPAD_RIGHT_TOOLTIP = "right"
GAMEPAD_TOOLTIPS = {
    Reset = noop,
}
BETTERUI_SharedGamepadEntry_OnSetup = noop

EVENT_MANAGER = {
    handlers = {},
}

function EVENT_MANAGER:RegisterForEvent(name, _, callback)
    self.handlers[name] = callback
    registeredEvents[name] = callback
end

SCENE_MANAGER = {
    scenes = {},
}

function SCENE_MANAGER:HideCurrentScene()
    hideCurrentSceneCalls = hideCurrentSceneCalls + 1
end

ZO_SimpleSceneFragment = {}
function ZO_SimpleSceneFragment:New(_)
    return {
        SetHideOnSceneHidden = noop,
    }
end

ZO_InteractScene = {}
function ZO_InteractScene:New(name, sceneManager, _)
    local scene = {
        name = name,
        showing = false,
        callbacks = {},
    }
    function scene:AddFragmentGroup(_) end
    function scene:AddFragment(_) end
    function scene:RegisterCallback(eventName, callback)
        self.callbacks[eventName] = callback
    end
    function scene:IsShowing()
        return self.showing
    end
    sceneManager.scenes[name] = scene
    return scene
end

local function newControlTree()
    local footerFooter = {}
    local footer = {
        GetNamedChild = function(_, name)
            if name == "Footer" then
                return footerFooter
            end
            return nil
        end,
    }
    return {
        GetNamedChild = function(_, name)
            if name == "Container" then
                return {
                    GetNamedChild = function(_, childName)
                        if childName == "Footer" then
                            return footer
                        end
                        return nil
                    end,
                }
            end
            return nil
        end,
    }
end

function BETTERUI.Companions.Class:New(_, _)
    local sceneName = BETTERUI_COMPANION_EQUIP_SCENE_NAME
    local obj = {
        refreshCategoriesCount = 0,
        refreshListCount = 0,
        refreshFooterCount = 0,
        refreshTitleCount = 0,
        ensureColumnsCount = 0,
        ensureHeaderKeybindsCount = 0,
        ensureListInputCount = 0,
        positionSearchCount = 0,
        updateTooltipCount = 0,
        deactivateListCount = 0,
        deactivateHeaderCount = 0,
        forceReleaseCount = 0,
        initFooterCount = 0,
        control = newControlTree(),
        headerGeneric = {},
        list = {
            control = {
                ClearAnchors = noop,
                SetAnchor = noop,
            },
            MovePrevious = function()
                return false
            end,
            GetTargetData = function()
                return { source = "target" }
            end,
        },
    }

    function obj:SetTitle(_) end
    function obj:SetupList(_, _) end
    function obj:InitializeListPresentation() end
    function obj:InitializeCategoryHeader() end
    function obj:AddColumn(_, _) end
    function obj:RefreshCategories()
        self.refreshCategoriesCount = self.refreshCategoriesCount + 1
    end
    function obj:EnsureColumnHeadersVisible()
        self.ensureColumnsCount = self.ensureColumnsCount + 1
    end
    function obj:RefreshList()
        self.refreshListCount = self.refreshListCount + 1
    end
    function obj:RefreshCompanionFooter()
        self.refreshFooterCount = self.refreshFooterCount + 1
    end
    function obj:RefreshCategoryTitle()
        self.refreshTitleCount = self.refreshTitleCount + 1
    end
    function obj:EnsureHeaderKeybindsActive()
        self.ensureHeaderKeybindsCount = self.ensureHeaderKeybindsCount + 1
    end
    function obj:EnsureListInputActive()
        self.ensureListInputCount = self.ensureListInputCount + 1
    end
    function obj:PositionSearchControl()
        self.positionSearchCount = self.positionSearchCount + 1
    end
    function obj:UpdateItemTooltips(_)
        self.updateTooltipCount = self.updateTooltipCount + 1
    end
    function obj:DeactivateListInput()
        self.deactivateListCount = self.deactivateListCount + 1
    end
    function obj:DeactivateHeaderKeybinds()
        self.deactivateHeaderCount = self.deactivateHeaderCount + 1
    end
    function obj:ForceReleaseDirectionalInput()
        self.forceReleaseCount = self.forceReleaseCount + 1
    end
    function obj:InitCompanionFooter()
        self.initFooterCount = self.initFooterCount + 1
    end
    function obj:IsSceneShowing()
        local scene = SCENE_MANAGER.scenes[sceneName]
        return scene and scene:IsShowing() or false
    end
    function obj:GetCurrentCategory()
        return {
            key = "all",
        }
    end
    function obj:GetTitle()
        return "Companions"
    end

    return obj
end

dofile("Modules/Companions/Core/CompanionsRuntime.lua")
dofile("Modules/Companions/Module.lua")

print("[Companions scene lifecycle]")

local originalCompanionInteraction = INTERACTION_COMPANION_MENU
INTERACTION_COMPANION_MENU = nil
local missingInteractionOk, missingInteractionErr = BETTERUI.Companions.Init()
assert_eq(missingInteractionOk, false, "missing companion interaction reports init failure")
assert_eq(missingInteractionErr, "missingInteraction", "missing companion interaction returns a retryable reason")
assert_eq(BETTERUI.Companions.initialized == true, false, "missing companion interaction does not mark the module initialized")
assert_eq(BETTERUI.Companions.instance, nil, "missing companion interaction does not create a runtime instance")

INTERACTION_COMPANION_MENU = originalCompanionInteraction
local retryOk = BETTERUI.Companions.Init()
assert_eq(retryOk, true, "companion init retries successfully after interaction appears")
local instance = BETTERUI.Companions.instance
local scene = instance.scene
scene.showing = true

local refreshCategoriesBeforeShowing = instance.refreshCategoriesCount
local refreshListBeforeShowing = instance.refreshListCount
local refreshFooterBeforeShowing = instance.refreshFooterCount
local refreshTitleBeforeShowing = instance.refreshTitleCount
local ensureColumnsBeforeShowing = instance.ensureColumnsCount
local ensureHeaderKeybindsBeforeShowing = instance.ensureHeaderKeybindsCount
local ensureListInputBeforeShowing = instance.ensureListInputCount
local positionSearchBeforeShowing = instance.positionSearchCount
local updateTooltipBeforeShowing = instance.updateTooltipCount

instance.sceneLifecycle.onShowing(instance)
assert_eq(tooltipWidthCalls[#tooltipWidthCalls], 100, "scene showing applies the companion tooltip width")
assert_eq(instance.refreshCategoriesCount, refreshCategoriesBeforeShowing + 1, "scene showing refreshes companion categories")
assert_eq(instance.refreshListCount, refreshListBeforeShowing + 1, "scene showing refreshes the companion list")
assert_eq(instance.refreshFooterCount, refreshFooterBeforeShowing + 1, "scene showing refreshes the companion footer")
assert_eq(instance.refreshTitleCount, refreshTitleBeforeShowing + 1, "scene showing refreshes the category title")
assert_eq(instance.ensureColumnsCount, ensureColumnsBeforeShowing + 1, "scene showing keeps column headers visible")
assert_eq(instance.ensureHeaderKeybindsCount, ensureHeaderKeybindsBeforeShowing + 1, "scene showing activates header keybinds")
assert_eq(instance.ensureListInputCount, ensureListInputBeforeShowing + 1, "scene showing activates list directional input")
assert_eq(instance.positionSearchCount, positionSearchBeforeShowing + 1, "scene showing repositions the search control")
assert_eq(instance.updateTooltipCount, updateTooltipBeforeShowing + 1, "scene showing refreshes the active tooltip")

local activatedCallback = registeredEvents["BetterUI_Companions_CompActivated"]
assert_true(type(activatedCallback) == "function", "companion activation callback is registered")
local refreshCategoriesBeforeActivation = instance.refreshCategoriesCount
local refreshListBeforeActivation = instance.refreshListCount
local refreshFooterBeforeActivation = instance.refreshFooterCount
activatedCallback()
assert_eq(instance.refreshCategoriesCount, refreshCategoriesBeforeActivation + 1, "activation refreshes companion categories while scene is visible")
assert_eq(instance.refreshListCount, refreshListBeforeActivation + 1, "activation refreshes the companion list while scene is visible")
assert_eq(instance.refreshFooterCount, refreshFooterBeforeActivation + 1, "activation refreshes the companion footer while scene is visible")

local inventoryCallback = registeredEvents["BetterUI_Companions_InvUpdate"]
assert_true(type(inventoryCallback) == "function", "inventory refresh callback is registered")
inventoryCallback()
assert_true(scheduledTasks[#scheduledTasks] == "listRefresh", "inventory refresh coalesces work through the task scheduler")
assert_eq(instance.refreshListCount, 3, "inventory refresh re-renders the companion list")
assert_eq(instance.updateTooltipCount, 3, "inventory refresh also updates the selected tooltip")

local deactivatedCallback = registeredEvents["BetterUI_Companions_CompDeactivated"]
assert_true(type(deactivatedCallback) == "function", "companion deactivation callback is registered")
deactivatedCallback()
assert_eq(hideCurrentSceneCalls, 1, "companion deactivation hides the scene when it is visible")

instance.sceneLifecycle.onHiding(instance)
assert_eq(tooltipWidthCalls[#tooltipWidthCalls], 80, "scene hiding restores the default tooltip width")
assert_eq(instance.deactivateListCount, 1, "scene hiding deactivates list input")
assert_eq(instance.deactivateHeaderCount, 1, "scene hiding deactivates header keybinds")
assert_eq(instance.forceReleaseCount, 1, "scene hiding force-releases directional input owners")

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
