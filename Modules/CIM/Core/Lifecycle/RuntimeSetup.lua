-- Runtime bootstrap helpers used by BetterUI.Initialize().

if not BETTERUI.CIM then BETTERUI.CIM = {} end
BETTERUI.CIM.RuntimeSetup = {}

local RuntimeSetup = BETTERUI.CIM.RuntimeSetup


-- Track whether patches have been applied (prevents double-application)
local patchesApplied = false

local function EnsureSharedTaskManager()
    local deferredTask = BETTERUI.CIM and BETTERUI.CIM.DeferredTask
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "task manager ensured", { hasDeferredTask = type(deferredTask) == "table", hasTasks = BETTERUI.CIM.Tasks ~= nil }) end
    if type(deferredTask) ~= "table" then
        return BETTERUI.CIM and BETTERUI.CIM.Tasks or nil
    end

    if type(deferredTask.EnsureSharedManager) == "function" then
        return deferredTask.EnsureSharedManager()
    end

    local managerClass = deferredTask.Manager
    if not BETTERUI.CIM.Tasks and managerClass and type(managerClass.New) == "function" then
        BETTERUI.CIM.Tasks = managerClass:New()
    end

    return BETTERUI.CIM.Tasks
end

local function EnsureLifecycleRuntimeState()
    EnsureSharedTaskManager()

    local eventRegistry = BETTERUI.CIM and BETTERUI.CIM.EventRegistry
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "event registry ensured", { hasEventRegistry = eventRegistry ~= nil }) end
    if eventRegistry and type(eventRegistry.EnsureRuntimeState) == "function" then
        eventRegistry.EnsureRuntimeState()
    end
end

local function EnsureDebugCommandsRegistered()
    local debug = BETTERUI.CIM and BETTERUI.CIM.Debug or nil
    if type(debug) ~= "table" or type(debug.EnsureCommandsRegistered) ~= "function" then
        return
    end

    local debugEnabled = type(debug.IsEnabled) == "function" and debug.IsEnabled() or false
    local developerVisible = type(debug.ShouldShowDeveloperSettings) == "function"
        and debug.ShouldShowDeveloperSettings() or false
    local registered = debugEnabled or developerVisible
    if registered then
        debug.EnsureCommandsRegistered()
    end
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SETTINGS, "debug commands registered", { debugEnabled = debugEnabled, developerVisible = developerVisible, registered = registered }) end
end

local function ApplyAPIPatches()
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "API patches applied", { alreadyApplied = patchesApplied }) end
    if patchesApplied then return end

    -- IMPORTANT:
    -- Do not override global ESO functions (including formatting helpers or keybind/chat APIs).
    -- Global monkeypatches can taint gamepad keybind execution paths and cause protected
    -- function access failures in native callbacks.

    -- Do not hook Tamriel Tomes / DirectPurchase classes. Even narrow native-class
    -- hooks can make secure store callstacks untrusted when those scenes open.

    patchesApplied = true
end

local function RunSettingsMigrations(settings)
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SETTINGS, "settings migration started", {}) end
    if not settings or not settings.Modules then
        if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SETTINGS, "settings migration ended", { modulesCount = 0 }) end
        return
    end

    -- Phase: migration-1-tooltips-rename
    -- Migration 1: Rename "Tooltips" to "GeneralInterface" for consistency
    -- Applied since v3.03; all modules now reference GeneralInterface directly.
    --- @deprecated Legacy "Tooltips" module key is transitional; removed after migration
    if settings.Modules["Tooltips"] ~= nil then
        if settings.Modules["GeneralInterface"] == nil then
            settings.Modules["GeneralInterface"] = settings.Modules["Tooltips"]
        end
        -- Migration complete: nil the stale key so SavedVars stay clean.
        settings.Modules["Tooltips"] = nil
    end

    -- Phase: migration-5-guarantee-generalinterface
    -- Migration 5: Ensure GeneralInterface module settings exist for existing users (if migration didn't run)
    if settings.Modules["GeneralInterface"] == nil then
        settings.Modules["GeneralInterface"] = {}
    end

    -- Phase: migration-2-enabled-standardization
    -- Migration 2: Standardize 'enabled' to 'm_enabled'
    -- Migration 6: Western-only fonts migration
    -- Migration 7: Currency rename (EventTickets -> TradeBars)
    --- @deprecated Legacy "enabled" key is transitional; replaced by "m_enabled" since v2.8
    local currentLang = GetCVar("language.2") or "en"
    local isEnglish = (currentLang == "en")
    -- Canonical Western-only font list lives in FontLocalization; all files
    -- are loaded by the time migrations run from BETTERUI.Initialize().
    local fontLocalization = BETTERUI.CIM and BETTERUI.CIM.Font and BETTERUI.CIM.Font.Localization
    local westernOnlyFonts = (fontLocalization and fontLocalization.WESTERN_ONLY_FONTS) or {}

    for modName, modSettings in pairs(settings.Modules) do
        if type(modSettings) == "table" then
            -- M2: Enabled standardization
            if modSettings.enabled ~= nil and modSettings.m_enabled == nil then
                modSettings.m_enabled = modSettings.enabled
                modSettings.enabled = nil
            end

            -- M5: Legacy Font/Size/Style migrations
            if modSettings.font and modSettings.nameFont == nil then
                modSettings.nameFont = modSettings.font
                modSettings.columnFont = modSettings.font
            end
            if modSettings.skinSize and modSettings.nameFontSize == nil then
                modSettings.nameFontSize = modSettings.skinSize
                modSettings.columnFontSize = modSettings.skinSize
            end
            if modSettings.fontStyle and modSettings.nameFontStyle == nil then
                local oldStyle = modSettings.fontStyle
                if type(oldStyle) == "number" then
                    local styleMap = {
                        [0] = "",
                        [1] = "outline",
                        [2] = "thick-outline",
                        [3] = "shadow",
                        [4] = "soft-shadow-thick",
                        [5] = "soft-shadow-thin"
                    }
                    modSettings.nameFontStyle = styleMap[oldStyle] or ""
                else
                    modSettings.nameFontStyle = oldStyle
                end
                modSettings.columnFontStyle = modSettings.nameFontStyle
            end

            -- M6: Western-only fonts (Localized support)
            if not isEnglish then
                if modSettings.nameFont and westernOnlyFonts[modSettings.nameFont] then
                    modSettings.nameFont = "$(GAMEPAD_MEDIUM_FONT)"
                end
                if modSettings.columnFont and westernOnlyFonts[modSettings.columnFont] then
                    modSettings.columnFont = "$(GAMEPAD_MEDIUM_FONT)"
                end
            end

            -- M7: Currency rename (Tickets -> TradeBars)
            if modSettings.showCurrencyEventTickets ~= nil then
                modSettings.showCurrencyTradeBars = modSettings.showCurrencyEventTickets
                modSettings.showCurrencyEventTickets = nil
            end
            if modSettings.orderCurrencyEventTickets ~= nil then
                modSettings.orderCurrencyTradeBars = modSettings.orderCurrencyEventTickets
                modSettings.orderCurrencyEventTickets = nil
            end
            if type(modSettings.currencyOrder) == "string" then
                modSettings.currencyOrder = string.gsub(modSettings.currencyOrder, "tickets", "tradebars")
            end
        end
    end

    -- Phase: migration-3-marketprice-move
    -- Migration 3: Move market-price row toggle from Inventory -> GeneralInterface
    --- @deprecated Inventory.showMarketPrice is transitional; moved to GeneralInterface since v3.04
    do
        local generalInterfaceSettings = settings.Modules["GeneralInterface"]
        local inventorySettings = settings.Modules["Inventory"]

        if type(generalInterfaceSettings) == "table" and generalInterfaceSettings.showMarketPrice == nil then
            if type(inventorySettings) == "table" and inventorySettings.showMarketPrice ~= nil then
                generalInterfaceSettings.showMarketPrice = inventorySettings.showMarketPrice
            else
                generalInterfaceSettings.showMarketPrice = true
            end
        end

        -- Remove legacy key after migration to avoid split ownership.
        if type(inventorySettings) == "table" then
            inventorySettings.showMarketPrice = nil
        end
    end

    -- Phase: migration-4-marketpricepriority-init
    -- Migration 4: Ensure market source priority setting exists (new configurable order control)
    do
        local generalInterfaceSettings = settings.Modules["GeneralInterface"]
        if type(generalInterfaceSettings) == "table" and generalInterfaceSettings.marketPricePriority == nil then
            generalInterfaceSettings.marketPricePriority = "mm_att_ttc"
        end
    end

    if BETTERUI.Log then
        local modulesCount = 0
        for _ in pairs(settings.Modules) do modulesCount = modulesCount + 1 end
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SETTINGS, "settings migration ended", { modulesCount = modulesCount })
    end
end

function RuntimeSetup.Apply(settings)
    EnsureLifecycleRuntimeState()

    -- SavedVars just loaded: drop any feature-flag defaults cached pre-load so
    -- persisted flag values take effect this session.
    local featureFlags = BETTERUI.CIM and BETTERUI.CIM.FeatureFlags
    if featureFlags and type(featureFlags.InvalidateCache) == "function" then
        featureFlags.InvalidateCache()
    end

    local migrationsRan = settings and type(settings.Modules) == "table"
    ApplyAPIPatches()
    RunSettingsMigrations(settings)
    EnsureDebugCommandsRegistered()

    -- Register the framework-level scene-transition logger now that SavedVars are
    -- loaded. Belt-and-suspenders: SceneLog's file-scope EnsureRegistered already ran
    -- if SCENE_MANAGER existed at load; this covers the case where it didn't. The
    -- module's own m_registered guard keeps it to exactly one registration per session.
    local sceneLog = BETTERUI.CIM and BETTERUI.CIM.SceneLog
    if sceneLog and type(sceneLog.EnsureRegistered) == "function" then
        sceneLog.EnsureRegistered()
    end

    -- Restore persisted /builog logging state across reloads. InterfaceLog 'enabled'
    -- is session-only, but the user explicitly opted in, so resume it (and re-apply
    -- the chosen preset) now that SavedVars are loaded. SceneLog self-gates on the
    -- active memo, so it picks this up on the next scene transition.
    local interfaceLog = BETTERUI.CIM and BETTERUI.CIM.InterfaceLog
    if interfaceLog and type(BETTERUI.GetSetting) == "function" then
        local suppressPopups = BETTERUI.GetSetting("CIM", "interfaceLogSuppressPopups", nil)
        if suppressPopups ~= nil and type(interfaceLog.SetSuppressPopups) == "function" then
            interfaceLog.SetSuppressPopups(suppressPopups ~= false)
        end

        local screenshotAuto = BETTERUI.GetSetting("CIM", "interfaceLogScreenshotAutoMode", "")
        if screenshotAuto ~= "" and type(interfaceLog.SetScreenshotAutoMode) == "function" then
            interfaceLog.SetScreenshotAutoMode(screenshotAuto, false)
        end

        local chatSurface = BETTERUI.GetSetting("CIM", "interfaceLogChat", nil)
        if chatSurface ~= nil and type(interfaceLog.SetChatSurface) == "function" then
            interfaceLog.SetChatSurface(chatSurface == true, false)
        end

        if BETTERUI.GetSetting("CIM", "interfaceLogEnabled", false) then
            local logPreset = BETTERUI.GetSetting("CIM", "interfaceLogPreset", "")
            if logPreset ~= "" and BETTERUI.Log and type(BETTERUI.Log.ApplyPreset) == "function" then
                BETTERUI.Log.ApplyPreset(logPreset)
            elseif type(interfaceLog.SetEnabled) == "function" then
                interfaceLog.SetEnabled(true)
            end

            local minLevel = BETTERUI.GetSetting("CIM", "interfaceLogMinLevel", "")
            if minLevel ~= "" and type(interfaceLog.SetMinLevelSetting) == "function" then
                interfaceLog.SetMinLevelSetting(minLevel, false)
            end

            if type(interfaceLog.Write) == "function" then
                interfaceLog.Write("logging restored after /reloadui (preset=" ..
                    (logPreset ~= "" and logPreset or "on") .. ") -- /builog off to stop")
            end
        end
    end

    -- Keep cached research-trait knowledge fresh when research completes.
    local researchCache = BETTERUI.CIM and BETTERUI.CIM.ResearchCache
    if researchCache and type(researchCache.RegisterEventHandlers) == "function" then
        researchCache.RegisterEventHandlers()
    end

    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIFECYCLE, "runtime setup complete", {
            migrationsRan = migrationsRan,
            patchesApplied = patchesApplied,
            settingsVersion = settings and settings.version,
        })
    end
end

-- Export for testing/debugging
RuntimeSetup.EnsureSharedTaskManager = EnsureSharedTaskManager
RuntimeSetup.EnsureLifecycleRuntimeState = EnsureLifecycleRuntimeState
RuntimeSetup.EnsureDebugCommandsRegistered = EnsureDebugCommandsRegistered
RuntimeSetup.ApplyAPIPatches = ApplyAPIPatches
RuntimeSetup.RunSettingsMigrations = RunSettingsMigrations
