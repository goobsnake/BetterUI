--[[
File: tools/tests/test_resource_orbframes_module_defaults.lua
Purpose: Regression tests for Resource Orb Frames default initialization wiring.
Usage:
  lua tools/tests/test_resource_orbframes_module_defaults.lua
]]

BETTERUI = {
    ResourceOrbFrames = {},
    CIM = {
        Settings = {},
    },
}

local passed = 0
local failed = 0
local registeredPanel = nil
local capturedSharedContracts = {}
local applySettingsCalls = 0
local moduleSettings = {}

local function assert_eq(actual, expected, label)
    if actual == expected then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected %s, got %s", label, tostring(expected), tostring(actual)))
    end
end

local function assert_true(value, label)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        print(string.format("  FAIL: %s -- expected true, got %s", label, tostring(value)))
    end
end

BETTERUI.CIM.RegisterModuleAccessors = function(_)
end

function GetString(value)
    return value or "stub-string"
end

BETTERUI.CIM.Settings.RegisterModulePanel = function(moduleId, panelData, optionsTable)
    registeredPanel = {
        moduleId = moduleId,
        panelData = panelData,
        optionsTable = optionsTable,
    }
end

BETTERUI.CIM.TryCall = function(path)
    error("ResourceOrbFrames module settings should not use TryCall for stable module-owned seams: " .. tostring(path))
end

BETTERUI.ClampInteger = function(value, _, _, fallback)
    if value == nil then
        return fallback
    end
    return value
end

BETTERUI.ClampNumber = function(value, _, _, fallback)
    if value == nil then
        return fallback
    end
    return value
end

BETTERUI.CloneColor = function(value, fallback)
    local source = value or fallback
    if type(source) ~= "table" then
        return source
    end
    return { unpack(source) }
end

BETTERUI.Init_ModulePanel = function(moduleName, title)
    return {
        moduleName = moduleName,
        title = title,
    }
end

BETTERUI.GetModuleSettings = function()
    return moduleSettings
end

BETTERUI.EnsureModuleSettings = function()
    return moduleSettings
end

BETTERUI.CreateSettingAccessors = function(_, applyFunc)
    return function(key, defaultValue)
        return function()
            local value = moduleSettings[key]
            if value == nil then
                return defaultValue
            end
            return value
        end, function(value)
            moduleSettings[key] = value
            if applyFunc then
                applyFunc()
            end
        end
    end
end

BETTERUI.CreateColorSettingAccessors = function(_, applyFunc)
    return function(key, defaultValue)
        return function()
            return moduleSettings[key] or BETTERUI.CloneColor(defaultValue)
        end, function(value)
            moduleSettings[key] = BETTERUI.CloneColor(value)
            if applyFunc then
                applyFunc()
            end
        end
    end
end

BETTERUI.ResourceOrbFrames.Utils = {
    Settings = {},
}

BETTERUI.ResourceOrbFrames.ApplySettings = function()
    applySettingsCalls = applySettingsCalls + 1
end

BETTERUI.ResourceOrbFrames.SettingsSubmenus = {
    BuildSkillBarsSubmenu = function(contracts, sharedContracts)
        capturedSharedContracts.skillBars = sharedContracts
        capturedSharedContracts.skillBarsContracts = contracts
        return { name = "skillBars" }
    end,
    BuildOrbTextSubmenu = function(contracts, sharedContracts)
        capturedSharedContracts.orbText = sharedContracts
        capturedSharedContracts.orbTextContracts = contracts
        return { name = "orbText" }
    end,
    BuildBarSubmenus = function(contracts, sharedContracts)
        capturedSharedContracts.bars = sharedContracts
        capturedSharedContracts.barContracts = contracts
        return { name = "xp" }, { name = "cast" }, { name = "mount" }
    end,
    ApplySubmenuSectionOrdering = function(optionsTable)
        capturedSharedContracts.orderedCount = #optionsTable
    end,
}

dofile("Modules/ResourceOrbFrames/Settings/Defaults.lua")
dofile("Modules/ResourceOrbFrames/Module.lua")

print("[ResourceOrbFrames.InitModule default backfill]")

do
    local options = BETTERUI.ResourceOrbFrames.InitModule({
        customFrontBar = {
            ultimate = { offsetX = 12 },
            gamepad = { ultimateSize = 80 },
        },
    })

    assert_eq(type(BETTERUI.ResourceOrbFrames.InitModule), "function", "Module.lua re-exposes InitModule")
    -- Defaults only carry m_enabled; layout values live in Constants.lua
    -- (BETTERUI_ORB_FRAMES.bars.customFrontBar) and are not backfilled.
    assert_eq(options.customFrontBar.m_enabled, true, "custom front bar m_enabled backfills default")
    assert_eq(options.customFrontBar.ultimate.offsetX, 12, "custom front bar preserves explicit legacy values")
    assert_eq(options.customFrontBar.ultimate.offsetY, nil, "custom front bar layout fields are not backfilled")
    assert_eq(options.customFrontBar.gamepad.ultimateSize, 80, "custom front bar preserves explicit legacy gamepad values")
    assert_eq(options.customFrontBar.keyboard, nil, "custom front bar keyboard layout defaults are pruned")
end

do
    local defaults = BETTERUI.ResourceOrbFrames.GetDefaults()
    assert_eq(defaults.elementPositionsUnlocked, false, "global element unlock defaults to locked")
end

do
    local options = BETTERUI.ResourceOrbFrames.InitModule({
        elementPositions = {
            leftOrb = { locked = false, offsetX = 3, offsetY = 4 },
        },
    })

    assert_eq(options.elementPositionsUnlocked, true,
        "legacy per-element unlocked saved state backfills the global unlock setting")
end

do
    local options = BETTERUI.ResourceOrbFrames.InitModule({
        enableIndependentOrbOffset = true,
        orbOffsetX = 10,
        orbOffsetY = -5,
        elementPositions = {
            leftOrb = { locked = true, offsetX = 1, offsetY = 2 },
        },
    })

    assert_eq(options.enableIndependentOrbOffset, false, "legacy independent orb setting is retired after migration")
    assert_eq(options.orbOffsetX, 0, "legacy orb X offset is consumed after migration")
    assert_eq(options.orbOffsetY, 0, "legacy orb Y offset is consumed after migration")
    assert_eq(options.elementPositions.leftOrb.offsetX, 11, "legacy orb X offset migrates into left orb position")
    assert_eq(options.elementPositions.leftOrb.offsetY, -3, "legacy orb Y offset migrates into left orb position")
    assert_eq(options.elementPositions.rightOrb.offsetX, 10, "legacy orb X offset migrates into right orb position")
    assert_eq(options.elementPositions.xpBar.offsetY, -5, "legacy orb Y offset migrates into XP bar position")
    assert_eq(options.elementPositions.mountBar.offsetX, 10, "legacy orb X offset migrates into mount bar position")
end

print("[ResourceOrbFrames.InitModule fallback when defaults init is unavailable]")

do
    local savedInitializeDefaults = BETTERUI.ResourceOrbFrames.InitializeDefaults
    BETTERUI.ResourceOrbFrames.InitializeDefaults = nil

    local emptyOptions = BETTERUI.ResourceOrbFrames.InitModule(nil)
    local passthroughOptions = { marker = true }
    local returnedOptions = BETTERUI.ResourceOrbFrames.InitModule(passthroughOptions)

    assert_eq(type(emptyOptions), "table", "InitModule creates a table when defaults init is unavailable")
    assert_eq(returnedOptions, passthroughOptions, "InitModule passes options through when defaults init is unavailable")

    BETTERUI.ResourceOrbFrames.InitializeDefaults = savedInitializeDefaults
end

print("[ResourceOrbFrames.Setup panel wiring]")

do
    moduleSettings = {
        scale = 9,
    }
    registeredPanel = nil
    capturedSharedContracts = {}
    applySettingsCalls = 0

    BETTERUI.ResourceOrbFrames.Setup()

    assert_true(registeredPanel ~= nil, "Setup registers a settings panel")
    assert_eq(registeredPanel.moduleId, "ResourceOrbFrames", "Setup registers the ResourceOrbFrames panel id")
    assert_eq(registeredPanel.panelData.title, "Resource Orb Frames Settings", "Setup uses the expected panel title")
    assert_true(capturedSharedContracts.skillBars ~= nil, "skill bar submenu receives shared contracts")
    assert_true(type(capturedSharedContracts.skillBars.getSettings) == "function", "shared contracts expose a settings getter")
    assert_true(type(capturedSharedContracts.skillBars.globalUnlock) == "table", "shared contracts expose the global position unlock")
    assert_true(type(capturedSharedContracts.skillBars.resetSettingsGroup) == "function", "shared contracts expose resetSettingsGroup")
    assert_eq(capturedSharedContracts.orderedCount, #registeredPanel.optionsTable, "submenu ordering runs on final options table")
    assert_true(#registeredPanel.optionsTable >= 5, "Setup builds multiple submenu entries")

    capturedSharedContracts.skillBars.resetSettingsGroup({
        { key = "scale", value = 1 },
    })
    assert_eq(moduleSettings.scale, BETTERUI.ResourceOrbFrames.GetDefaults().scale, "resetSettingsGroup restores default values")
    assert_eq(applySettingsCalls, 1, "resetSettingsGroup reapplies settings after reset")
end

print(string.format("\nResults: %d passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
