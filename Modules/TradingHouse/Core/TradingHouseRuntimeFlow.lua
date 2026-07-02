--[[
File: Modules/TradingHouse/Core/TradingHouseRuntimeFlow.lua
Purpose: Scene ownership, dialog registration, and runtime event flow for the
         Trading House module.
]]

local TH = BETTERUI.TradingHouse
local MODE = TH.MODE
local EVENT_NS = "BetterUI_TradingHouse"
---@alias TradingHouseSceneOwner {scene: table|nil}
---@alias TradingHouseCreateListingDialogData {stackCount: integer|nil, selectedStackCount: integer|nil, defaultPrice: integer|nil, selectedPrice: integer|nil}
---@alias TradingHouseResponsePayload {responseType: integer|nil, result: integer|nil}

local function TraceTHFlow(category, event, phase, data)
    local tracer = TH.Trace
    if type(tracer) == "function" then
        tracer(category, event, phase, TH.instance, data)
    elseif BETTERUI.Log and BETTERUI.Log.TraceEvent then
        data = data or {}
        data.module = data.module or "TradingHouse"
        data.scene = data.scene or BETTERUI_TRADING_HOUSE_SCENE_NAME
        data.feature = data.feature or "trading-house"
        local fn = data.fn or data["function"] or "TradingHouse.RuntimeFlow"
        data.fn = fn
        data["function"] = fn
        BETTERUI.Log.TraceEvent(category or BETTERUI.Log.CATEGORY.SCENE, event, phase, data)
    end
end

TH._pendingOperations = TH._pendingOperations or {}

local function CopyTracePayload(data)
    local payload = {}
    if type(data) == "table" then
        for key, value in pairs(data) do
            payload[key] = value
        end
    end
    return payload
end

local function GetCurrentDialogInfo(dialogName)
    local dialogs = BETTERUI.CIM and BETTERUI.CIM.Dialogs
    if dialogs and type(dialogs.GetCurrentInfo) == "function" then
        return dialogs.GetCurrentInfo(dialogName)
    end
    return nil
end

local function RegisterTradingHouseDialog(dialogName, dialogInfo)
    local dialogs = BETTERUI.CIM and BETTERUI.CIM.Dialogs
    if not (dialogs and type(dialogs.Register) == "function") then
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG, "trading_house.dialog", "register_skipped", {
            fn = "RegisterTradingHouseDialog",
            feature = "trading-house-dialogs",
            dialogName = dialogName,
            reason = "missingDialogRegistry",
        })
        return false
    end
    return dialogs.Register(dialogName, dialogInfo, { overwrite = true })
end

local function WatchdogExpectOperation(operation, timeoutMs, context)
    local watchdog = BETTERUI.CIM and BETTERUI.CIM.Watchdog
    if watchdog and type(watchdog.Expect) == "function" then
        pcall(watchdog.Expect, "th.op", operation, timeoutMs or 30000, context)
    end
end

local function WatchdogResolveOperation(operation, outcome)
    local watchdog = BETTERUI.CIM and BETTERUI.CIM.Watchdog
    if watchdog and type(watchdog.Resolve) == "function" then
        pcall(watchdog.Resolve, "th.op", operation, outcome)
    end
end

local function ReadSelectedTradingHouseGuildId()
    return GetSelectedTradingHouseGuildId and GetSelectedTradingHouseGuildId() or nil
end

---@param operation string
---@param event string
---@param data table|nil
---@param emitRequested boolean|nil
---@return string opId
function TH.BeginPendingOperation(operation, event, data, emitRequested)
    local L = BETTERUI and BETTERUI.Log
    local opId = data and data.opId or nil
    if not opId and L and type(L.NewFlow) == "function" then
        opId = L.NewFlow("thOp")
    end
    opId = opId or "untracked"

    local payload = CopyTracePayload(data)
    payload.opId = opId
    payload.operation = operation
    payload.guildId = payload.guildId or ReadSelectedTradingHouseGuildId()
    payload.fn = payload.fn or "TradingHouse.BeginPendingOperation"
    payload.feature = payload.feature or "trading-house-operation"

    TH._pendingOperations[operation] = {
        opId = opId,
        event = event,
        operation = operation,
        guildId = payload.guildId,
    }
    WatchdogExpectOperation(operation, 30000, {
        opId = opId,
        operation = operation,
        event = event,
        guildId = payload.guildId,
    })
    if emitRequested ~= false then
        TraceTHFlow(L and L.CATEGORY.ACTION, event, "requested", payload)
    end
    return opId
end

---@param operation string
---@return table|nil pending
function TH.ClearPendingOperation(operation)
    local pending = TH._pendingOperations and TH._pendingOperations[operation] or nil
    if TH._pendingOperations then
        TH._pendingOperations[operation] = nil
    end
    if pending then
        WatchdogResolveOperation(operation, "cleared")
    end
    return pending
end

local function ResolveTradingHouseResponseOperation(responseType)
    if TRADING_HOUSE_RESULT_SEARCH_PENDING ~= nil and responseType == TRADING_HOUSE_RESULT_SEARCH_PENDING then
        return "search"
    end
    if TRADING_HOUSE_RESULT_PURCHASE_PENDING ~= nil and responseType == TRADING_HOUSE_RESULT_PURCHASE_PENDING then
        return "buy"
    end
    if TRADING_HOUSE_RESULT_POST_PENDING ~= nil and responseType == TRADING_HOUSE_RESULT_POST_PENDING then
        return "create_listing"
    end
    if TRADING_HOUSE_RESULT_QUEUED_POST ~= nil and responseType == TRADING_HOUSE_RESULT_QUEUED_POST then
        return "create_listing"
    end
    if TRADING_HOUSE_RESULT_CANCEL_SALE_PENDING ~= nil and responseType == TRADING_HOUSE_RESULT_CANCEL_SALE_PENDING then
        return "cancel_listing"
    end
    if TRADING_HOUSE_RESULT_LISTINGS_PENDING ~= nil and responseType == TRADING_HOUSE_RESULT_LISTINGS_PENDING then
        return "listings"
    end
    return nil
end

local function ResolveTradingHouseResultText(result)
    if result == nil or type(GetString) ~= "function" then
        return nil
    end
    local ok, value = pcall(GetString, "SI_TRADINGHOUSERESULT", result)
    if ok and value and value ~= "" then
        return value
    end
    return nil
end

local function TraceTradingHouseOperationResponse(responseType, result, guildId, mode)
    local L = BETTERUI and BETTERUI.Log
    local operation = ResolveTradingHouseResponseOperation(responseType)
    local pending = operation and TH.ClearPendingOperation(operation) or nil
    local success = TRADING_HOUSE_RESULT_SUCCESS ~= nil and result == TRADING_HOUSE_RESULT_SUCCESS
    local payload = {
        fn = "TradingHouse.OnTradingHouseResponse",
        feature = "trading-house-operation",
        opId = pending and pending.opId or "untracked",
        operation = operation or "untracked",
        requestedEvent = pending and pending.event or nil,
        guildId = (pending and pending.guildId) or guildId,
        mode = mode,
        responseType = responseType,
        result = result,
        errorText = success and nil or ResolveTradingHouseResultText(result),
    }
    TraceTHFlow(L and L.CATEGORY.ACTION, "trading_house.response", success and "completed" or "failed", payload)
end

local function TracePendingOperationFailure(failureType, errorText)
    if type(TH._pendingOperations) ~= "table" then
        return
    end
    local L = BETTERUI and BETTERUI.Log
    local operations = {}
    for operation in pairs(TH._pendingOperations) do
        operations[#operations + 1] = operation
    end
    for _, operation in ipairs(operations) do
        local pending = TH.ClearPendingOperation and TH.ClearPendingOperation(operation) or TH._pendingOperations[operation]
        if TH._pendingOperations then
            TH._pendingOperations[operation] = nil
        end
        TraceTHFlow(L and L.CATEGORY.ACTION, "trading_house.response", "failed", {
            fn = "TradingHouse.TracePendingOperationFailure",
            feature = "trading-house-operation",
            opId = pending and pending.opId or "untracked",
            operation = operation,
            requestedEvent = pending and pending.event or nil,
            guildId = pending and pending.guildId or ReadSelectedTradingHouseGuildId(),
            failureType = failureType,
            timeoutType = failureType == "timeout" and errorText or nil,
            errorText = errorText or failureType,
        })
    end
end

local function TracePendingOperationTimeout(timeoutType)
    TracePendingOperationFailure("timeout", timeoutType)
end

local function RefreshCurrentTradingHouseKeybinds(fn, reason)
    local sceneShowing = TH.instance and TH.instance.IsSceneShowing and TH.instance:IsSceneShowing() or false
    if not sceneShowing then
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.KEYBIND, "trading_house.keybinds", "refresh_skipped", {
            fn = fn,
            feature = "trading-house-keybinds",
            reason = reason,
            skipReason = "sceneHidden",
            hasInstance = TH.instance ~= nil,
            sceneShowing = sceneShowing,
            searchPending = TH.BrowseComponent and TH.BrowseComponent.searchPending == true,
        })
        return false
    end

    local updateCurrentKeybinds = BETTERUI.Interface and BETTERUI.Interface.UpdateCurrentKeybindGroups
    if type(updateCurrentKeybinds) ~= "function" then
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.KEYBIND, "trading_house.keybinds", "refresh_skipped", {
            fn = fn,
            feature = "trading-house-keybinds",
            reason = "missingKeybindHelper",
            requestedReason = reason,
            searchPending = TH.BrowseComponent and TH.BrowseComponent.searchPending == true,
        })
        return false
    end

    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.KEYBIND, "trading_house.keybinds", "refresh_before", {
        fn = fn,
        feature = "trading-house-keybinds",
        reason = reason,
        searchPending = TH.BrowseComponent and TH.BrowseComponent.searchPending == true,
    })
    if not updateCurrentKeybinds() then
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.KEYBIND, "trading_house.keybinds", "refresh_skipped", {
            fn = fn,
            feature = "trading-house-keybinds",
            reason = "missingKeybindStrip",
            requestedReason = reason,
            searchPending = TH.BrowseComponent and TH.BrowseComponent.searchPending == true,
        })
        return false
    end
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.KEYBIND, "trading_house.keybinds", "refresh_after", {
        fn = fn,
        feature = "trading-house-keybinds",
        reason = reason,
        searchPending = TH.BrowseComponent and TH.BrowseComponent.searchPending == true,
    })
    return true
end

local function AssociateSearchFeatures()
    local browse = rawget(_G, "GAMEPAD_TRADING_HOUSE_BROWSE")
    local search = rawget(_G, "TRADING_HOUSE_SEARCH")
    if browse and search and search.AssociateWithSearchFeatures then
        local features = browse.GetFeatures and browse:GetFeatures()
        if features then
            search:AssociateWithSearchFeatures(features)
        end
    end
end

local function DisassociateSearchFeatures()
    local search = rawget(_G, "TRADING_HOUSE_SEARCH")
    if search and search.DisassociateWithSearchFeatures then
        search:DisassociateWithSearchFeatures()
    end
end

local function ComputeListingPriceBreakdown(price)
    if not GetTradingHousePostPriceInfo then
        return nil, nil, nil
    end
    local listingFee, tradingHouseCut, profit = GetTradingHousePostPriceInfo(price)
    return listingFee or 0, tradingHouseCut or 0, profit or 0
end

local CREATE_LISTING_DIALOG_NAME = "BETTERUI_TRADING_HOUSE_CREATE_LISTING"

local function ChainPriorDialogSetup(priorDialog, setup)
    return function(dialog, ...)
        if priorDialog and type(priorDialog.setup) == "function" then
            priorDialog.setup(dialog, ...)
        end
        return setup(dialog, ...)
    end
end

local function SetTHSceneAlias(sceneObject)
    TH.activeTHSceneObject = sceneObject
end

local function SetTHSystemGamepadRootScene(sceneObject)
    if not SYSTEMS or type(SYSTEMS.GetSystem) ~= "function" then
        return
    end
    -- "tradingHouse" matches ZO_TRADING_HOUSE_SYSTEM_NAME (tradinghouse_shared.lua).
    local systemName = ZO_TRADING_HOUSE_SYSTEM_NAME or "tradingHouse"
    local system = SYSTEMS:GetSystem(systemName)
    if not system then
        return
    end
    local currentRootScene = system.gamepadRootScene
    if TH.nativeTHSystemGamepadRootScene == nil then
        TH.nativeTHSystemGamepadRootScene = currentRootScene
    end
    local betterUIRootScene = TH.instance and TH.instance.scene or nil
    if sceneObject == betterUIRootScene and currentRootScene ~= sceneObject then
        TH.previousTHSystemGamepadRootScene = currentRootScene
    elseif sceneObject ~= betterUIRootScene
        and betterUIRootScene ~= nil
        and currentRootScene ~= betterUIRootScene then
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene_ownership", "restore_skipped", {
            fn = "TradingHouse.SetTHSystemGamepadRootScene",
            feature = "trading-house-scene",
            reason = "externalOwnerChanged",
        })
        return
    end
    -- This is an exclusive scene-owner slot; restore only while BetterUI still
    -- owns it so another addon's later owner is not overwritten.
    system.gamepadRootScene = sceneObject
end

local function RefreshVisibleTradingHouseScene()
    if not TH.instance or not TH.instance:IsSceneShowing() then
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST, "trading_house.list_refresh", "skipped", {
            fn = "TradingHouse.RefreshVisibleTradingHouseScene",
            feature = "trading-house-list",
            hasInstance = TH.instance ~= nil,
            sceneShowing = TH.instance and TH.instance.IsSceneShowing and TH.instance:IsSceneShowing() or false,
        })
        return
    end
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST, "trading_house.list_refresh", "begin", {
        fn = "TradingHouse.RefreshVisibleTradingHouseScene",
        feature = "trading-house-list",
        searchPending = TH.BrowseComponent and TH.BrowseComponent.searchPending == true,
    })
    TH.instance:RefreshList()
    TH.instance:RefreshTHFooter()
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST, "trading_house.list_refresh", "end", {
        fn = "TradingHouse.RefreshVisibleTradingHouseScene",
        feature = "trading-house-list",
        searchPending = TH.BrowseComponent and TH.BrowseComponent.searchPending == true,
    })
end

function TH.CaptureNativeScene(sceneManager)
    if TH.nativeTHScene ~= nil then
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene_ownership", "capture_skipped", {
            fn = "TradingHouse.CaptureNativeScene",
            feature = "trading-house-scene",
            reason = "alreadyCaptured",
            hasNativeScene = TH.nativeTHScene ~= nil,
        })
        return
    end
    if not sceneManager or type(sceneManager.GetScene) ~= "function" then
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene_ownership", "capture_skipped", {
            fn = "TradingHouse.CaptureNativeScene",
            feature = "trading-house-scene",
            reason = "missingSceneManager",
        })
        return
    end
    TH.nativeTHScene = sceneManager:GetScene("gamepad_trading_house")
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene_ownership", "captured", {
        fn = "TradingHouse.CaptureNativeScene",
        feature = "trading-house-scene",
        hasNativeScene = TH.nativeTHScene ~= nil,
    })
end

function TH.SetTradingHouseSceneOwnership(sceneObject)
    if not sceneObject then
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene_ownership", "apply_skipped", {
            fn = "TradingHouse.SetTradingHouseSceneOwnership",
            feature = "trading-house-scene",
            reason = "missingScene",
        })
        return
    end
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene_ownership", "apply_begin", {
        fn = "TradingHouse.SetTradingHouseSceneOwnership",
        feature = "trading-house-scene",
        hasSceneManager = SCENE_MANAGER ~= nil,
        hasSceneTable = SCENE_MANAGER and SCENE_MANAGER.scenes ~= nil or false,
        hasSystems = SYSTEMS ~= nil,
        hadNativeSystemRoot = TH.nativeTHSystemGamepadRootScene ~= nil,
    })
    SetTHSceneAlias(sceneObject)
    SetTHSystemGamepadRootScene(sceneObject)
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene_ownership", "apply_end", {
        fn = "TradingHouse.SetTradingHouseSceneOwnership",
        feature = "trading-house-scene",
        sceneRecorded = TH.activeTHSceneObject == sceneObject,
        capturedNativeSystemRoot = TH.nativeTHSystemGamepadRootScene ~= nil,
    })
end

function TH.RestoreNativeSceneAlias()
    if not TH.nativeTHScene and not TH.nativeTHSystemGamepadRootScene then
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene_ownership", "restore_skipped", {
            fn = "TradingHouse.RestoreNativeSceneAlias",
            feature = "trading-house-scene",
            reason = "nothingCaptured",
        })
        return
    end
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene_ownership", "restore_begin", {
        fn = "TradingHouse.RestoreNativeSceneAlias",
        feature = "trading-house-scene",
        hasNativeScene = TH.nativeTHScene ~= nil,
        hasNativeSystemRoot = TH.nativeTHSystemGamepadRootScene ~= nil,
    })
    if TH.nativeTHScene then
        SetTHSceneAlias(TH.nativeTHScene)
    end
    local rootScene = TH.previousTHSystemGamepadRootScene or TH.nativeTHSystemGamepadRootScene
    if rootScene then
        SetTHSystemGamepadRootScene(rootScene)
        TH.previousTHSystemGamepadRootScene = nil
    end
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene_ownership", "restore_end", {
        fn = "TradingHouse.RestoreNativeSceneAlias",
        feature = "trading-house-scene",
        sceneRecorded = TH.activeTHSceneObject == TH.nativeTHScene,
    })
end

function TH.AliasSceneToBetterUI()
    if TH.instance and TH.instance.scene then
        TH.SetTradingHouseSceneOwnership(TH.instance.scene)
    else
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene_ownership", "apply_skipped", {
            fn = "TradingHouse.AliasSceneToBetterUI",
            feature = "trading-house-scene",
            reason = "missingInstanceScene",
            hasInstance = TH.instance ~= nil,
        })
    end
end

function TH.ResetBrowseState()
    if TH.BrowseComponent then
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SEARCH, "trading_house.browse_state", "reset_begin", {
            fn = "TradingHouse.ResetBrowseState",
            feature = "trading-house-search",
            pageBefore = TH.BrowseComponent.currentPage,
            searchPendingBefore = TH.BrowseComponent.searchPending == true,
            hasMorePagesBefore = TH.BrowseComponent.hasMorePages == true,
            resultsInvalidatedBefore = TH.BrowseComponent.resultsInvalidated == true,
            deferredTokenBefore = TH.BrowseComponent.deferredSearchToken,
        })
        TH.BrowseComponent.currentPage = 0
        TH.BrowseComponent.searchPending = false
        TH.BrowseComponent.hasMorePages = false
        TH.BrowseComponent.resultsInvalidated = false
        TH.BrowseComponent.deferredSearchToken = (TH.BrowseComponent.deferredSearchToken or 0) + 1
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SEARCH, "trading_house.browse_state", "reset_end", {
            fn = "TradingHouse.ResetBrowseState",
            feature = "trading-house-search",
            pageAfter = TH.BrowseComponent.currentPage,
            searchPendingAfter = TH.BrowseComponent.searchPending == true,
            hasMorePagesAfter = TH.BrowseComponent.hasMorePages == true,
            resultsInvalidatedAfter = TH.BrowseComponent.resultsInvalidated == true,
            deferredTokenAfter = TH.BrowseComponent.deferredSearchToken,
        })
    else
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SEARCH, "trading_house.browse_state", "reset_skipped", {
            fn = "TradingHouse.ResetBrowseState",
            feature = "trading-house-search",
            reason = "missingBrowseComponent",
        })
    end
end

function TH.ShowScene()
    if SCENE_MANAGER then
        SCENE_MANAGER:Show(BETTERUI_TRADING_HOUSE_SCENE_NAME)
    end
end

function TH.ScheduleOwnershipReassert()
    local function ReassertTradingHouseOwnership()
        local currentInteraction = GetInteractionType and GetInteractionType() or nil
        if currentInteraction and currentInteraction ~= INTERACTION_TRADINGHOUSE then
            TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene_ownership", "reassert_aborted", {
                fn = "TradingHouse.ScheduleOwnershipReassert",
                feature = "trading-house-scene",
                reason = "interactionTypeMismatch",
                interactionType = currentInteraction,
            })
            return
        end
        if not TH.instance or not TH.instance.scene then
            TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene_ownership", "reassert_skipped", {
                fn = "TradingHouse.ScheduleOwnershipReassert",
                feature = "trading-house-scene",
                reason = "missingInstanceScene",
                hasInstance = TH.instance ~= nil,
            })
            return
        end
        TH.AliasSceneToBetterUI()
        TH.ShowScene()
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene_ownership", "reasserted", {
            fn = "TradingHouse.ScheduleOwnershipReassert",
            feature = "trading-house-scene",
            interactionType = currentInteraction,
            sceneShowing = TH.instance and TH.instance.IsSceneShowing and TH.instance:IsSceneShowing() or false,
        })
    end

    if TH.Tasks then
        TH.Tasks:Cancel("sceneOwnershipOpen")
        TH.Tasks:Schedule("sceneOwnershipOpen", 30, ReassertTradingHouseOwnership)
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene_ownership", "reassert_scheduled", {
            fn = "TradingHouse.ScheduleOwnershipReassert",
            feature = "trading-house-scene",
            scheduler = "tasks",
            delayMs = 30,
        })
    elseif type(zo_callLater) == "function" then
        zo_callLater(ReassertTradingHouseOwnership, 30)
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene_ownership", "reassert_scheduled", {
            fn = "TradingHouse.ScheduleOwnershipReassert",
            feature = "trading-house-scene",
            scheduler = "zo_callLater",
            delayMs = 30,
        })
    else
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene_ownership", "reassert_skipped", {
            fn = "TradingHouse.ScheduleOwnershipReassert",
            feature = "trading-house-scene",
            reason = "missingScheduler",
        })
    end
end

function TH.ScheduleListRefresh()
    local guildId = GetSelectedTradingHouseGuildId and GetSelectedTradingHouseGuildId() or nil
    local mode = TH.instance and TH.instance.GetCurrentMode and TH.instance:GetCurrentMode() or nil
    local searchPending = TH.BrowseComponent and TH.BrowseComponent.searchPending == true
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST, "trading_house.list_refresh", "scheduled", {
        fn = "TradingHouse.ScheduleListRefresh",
        feature = "trading-house-list",
        guildId = guildId,
        mode = mode,
        searchPending = searchPending,
        delayMs = TH.Tasks and 100 or 0,
    })
    if not TH.instance or not TH.instance:IsSceneShowing() then
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST, "trading_house.list_refresh", "schedule_skipped", {
            fn = "TradingHouse.ScheduleListRefresh",
            feature = "trading-house-list",
            guildId = guildId,
            mode = mode,
            searchPending = searchPending,
            hasInstance = TH.instance ~= nil,
            sceneShowing = TH.instance and TH.instance.IsSceneShowing and TH.instance:IsSceneShowing() or false,
        })
        return
    end

    if TH.Tasks then
        TH.Tasks:Cancel("listRefresh")
        TH.Tasks:Schedule("listRefresh", 100, RefreshVisibleTradingHouseScene)
    else
        RefreshVisibleTradingHouseScene()
    end
end

function TH.TakeOverNativeTradingHouse()
    local nativeTH = rawget(_G, "TRADING_HOUSE_GAMEPAD")
    if not nativeTH then
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.native_takeover", "skipped", {
            fn = "TradingHouse.TakeOverNativeTradingHouse",
            feature = "trading-house-scene",
            reason = "missingNativeTradingHouse",
        })
        return
    end

    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.native_takeover", "begin", {
        fn = "TradingHouse.TakeOverNativeTradingHouse",
        feature = "trading-house-scene",
        hasControl = nativeTH.control ~= nil,
        hadSceneName = nativeTH.sceneName,
    })
    if nativeTH.control then
        nativeTH.control:UnregisterForEvent(EVENT_OPEN_TRADING_HOUSE)
        nativeTH.control:UnregisterForEvent(EVENT_CLOSE_TRADING_HOUSE)
    end
    if ZO_TRADING_HOUSE_SYSTEM_NAME then
        EVENT_MANAGER:UnregisterForEvent(ZO_TRADING_HOUSE_SYSTEM_NAME, EVENT_OPEN_TRADING_HOUSE)
        EVENT_MANAGER:UnregisterForEvent(ZO_TRADING_HOUSE_SYSTEM_NAME, EVENT_CLOSE_TRADING_HOUSE)
    end
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.native_takeover", "end", {
        fn = "TradingHouse.TakeOverNativeTradingHouse",
        feature = "trading-house-scene",
        sceneName = nativeTH.sceneName,
        nativeMethodsUntouched = true,
    })
end

function TH.RegisterCreateListingDialog()
    local priorDialog = GetCurrentDialogInfo(CREATE_LISTING_DIALOG_NAME)
    if priorDialog and priorDialog._betteruiTradingHouseCreateListing then
        return
    end

    -- U50: "ZO_GamepadSliderDialogTemplate" does not exist in the game UI.
    -- ZO_GamepadGuildStoreBrowseSliderTemplate is the live template that wires
    -- control.label and control.slider (a ZO_GamepadConstrainedSlider).
    -- The slider only receives directional input while activated, so track the
    -- selected entry's slider on the dialog data and (de)activate accordingly.
    local function UpdateSliderActivation(control, dialogData, selected)
        if not (control.slider and control.slider.Activate) then
            return
        end
        if selected then
            if dialogData and dialogData._activeSlider and dialogData._activeSlider ~= control.slider then
                dialogData._activeSlider:Deactivate()
            end
            control.slider:Activate()
            if dialogData then
                dialogData._activeSlider = control.slider
            end
        else
            if dialogData and dialogData._activeSlider == control.slider then
                dialogData._activeSlider = nil
            end
            control.slider:Deactivate()
        end
    end

    -- The live template wires control.label/control.slider, but its
    -- $(parent)SliderValue label is populated by the owning screen; mirror
    -- that here so the chosen quantity/price stays visible while sliding.
    local function UpdateSliderValueLabel(control, value, isCurrency, isPrice)
        local valueLabel = control.GetNamedChild and control:GetNamedChild("SliderValue") or nil
        if not valueLabel then
            return
        end
        local text
        if isCurrency and ZO_Currency_FormatGamepad then
            text = ZO_Currency_FormatGamepad(CURT_MONEY, value, ZO_CURRENCY_FORMAT_AMOUNT_ICON)
        elseif ZO_CommaDelimitNumber then
            text = ZO_CommaDelimitNumber(value)
        else
            text = tostring(value)
        end
        -- For the price slider, append the listing fee, house cut, and
        -- expected profit so the player sees the full invoice before posting.
        if isPrice then
            local listingFee, tradingHouseCut, profit = ComputeListingPriceBreakdown(value)
            local feeText, cutText, profitText
            if ZO_Currency_FormatGamepad then
                feeText = ZO_Currency_FormatGamepad(CURT_MONEY, listingFee, ZO_CURRENCY_FORMAT_AMOUNT_ICON)
                cutText = ZO_Currency_FormatGamepad(CURT_MONEY, tradingHouseCut, ZO_CURRENCY_FORMAT_AMOUNT_ICON)
                profitText = ZO_Currency_FormatGamepad(CURT_MONEY, profit, ZO_CURRENCY_FORMAT_AMOUNT_ICON)
            else
                feeText = tostring(listingFee)
                cutText = tostring(tradingHouseCut)
                profitText = tostring(profit)
            end
            text = text .. "  |cAAAAAA(Fee " .. feeText .. ", Cut " .. cutText .. ", Profit " .. profitText .. ")|r"
        end
        valueLabel:SetText(text)
    end

    local dialogInfo = {
        _betteruiTradingHouseCreateListing = true,
        canQueue = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
        },
        finishedCallback = function(dialog)
            local dialogData = dialog and dialog.data
            TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG, "trading_house.create_listing_dialog", "finished", {
                fn = "TradingHouse.RegisterCreateListingDialog.finishedCallback",
                feature = "trading-house-create-listing",
                submitted = dialogData and dialogData._submitted == true or false,
                bagId = dialogData and dialogData.bagId or nil,
                slotIndex = dialogData and dialogData.slotIndex or nil,
                selectedStackCount = dialogData and dialogData.selectedStackCount or nil,
                selectedPrice = dialogData and dialogData.selectedPrice or nil,
                operation = dialogData and dialogData.thOperation or nil,
                opId = dialogData and dialogData.opId or nil,
            })
            if dialogData and dialogData._activeSlider then
                dialogData._activeSlider:Deactivate()
                dialogData._activeSlider = nil
            end
            -- Mirror the native flow (tradinghouse_keyboard.lua): drop any
            -- staged pending post when the dialog closes without submitting.
            -- A successful confirm keeps the staged post for the in-flight
            -- RequestPostItemOnTradingHouse.
            if dialogData and not dialogData._submitted and SetPendingItemPost then
                SetPendingItemPost(BAG_BACKPACK, 0, 0)
                TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.ACTION, "trading_house.pending_post", "cleared", {
                    fn = "TradingHouse.RegisterCreateListingDialog.finishedCallback",
                    feature = "trading-house-create-listing",
                    reason = "dialogClosedWithoutSubmit",
                })
            end
            if dialogData and not dialogData._submitted and dialogData.thOperation and TH.ClearPendingOperation then
                TH.ClearPendingOperation(dialogData.thOperation)
            end
        end,
        title = {
            text = rawget(_G, "SI_BETTERUI_TH_LIST_ITEM") or SI_TRADING_HOUSE_POST_ITEM,
        },
        setup = ChainPriorDialogSetup(priorDialog, function(dialog)
            dialog:setupFunc()
        end),
        parametricList = {
            {
                template = "ZO_GamepadGuildStoreBrowseSliderTemplate",
                text = GetString(rawget(_G, "SI_TRADING_HOUSE_POSTING_QUANTITY")),
                templateData = {
                    setup = function(control, data, selected)
                        local dialog = data.dialog or ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)
                        ---@type TradingHouseCreateListingDialogData|nil
                        local dialogData = dialog and dialog.data
                        local maxStack = dialogData and dialogData.stackCount or 1
                        if dialogData and dialogData.selectedStackCount == nil then
                            -- Initialize before handlers attach so confirm sees
                            -- a value even when the slider is never moved.
                            dialogData.selectedStackCount = maxStack
                        end
                        control.label:SetText(data.text)
                        control.slider:SetMinMax(1, maxStack)
                        control.slider:SetValueStep(1)
                        control.slider:SetValue(dialogData and dialogData.selectedStackCount or maxStack)
                        UpdateSliderValueLabel(control, dialogData and dialogData.selectedStackCount or maxStack, false)
                        control.slider:SetHandler("OnValueChanged", function(_, value)
                            if dialogData then
                                dialogData.selectedStackCount = value
                            end
                            UpdateSliderValueLabel(control, value, false)
                        end)
                        UpdateSliderActivation(control, dialogData, selected)
                    end,
                },
            },
            {
                template = "ZO_GamepadGuildStoreBrowseSliderTemplate",
                text = GetString(rawget(_G, "SI_BETTERUI_TH_PRICE_LABEL")),
                templateData = {
                    setup = function(control, data, selected)
                        local dialog = data.dialog or ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)
                        ---@type TradingHouseCreateListingDialogData|nil
                        local dialogData = dialog and dialog.data
                        local defaultPrice = dialogData and dialogData.defaultPrice or 100
                        if dialogData and dialogData.selectedPrice == nil then
                            -- Initialize before handlers attach so confirm sees
                            -- a value even when the slider is never moved.
                            dialogData.selectedPrice = defaultPrice
                        end
                        local maxPrice = 999999999
                        control.label:SetText(data.text)
                        control.slider:SetMinMax(1, maxPrice)
                        -- Use a fine step (1) for low/mid-value items so exact
                        -- prices are reachable; only switch to a coarse step for
                        -- genuinely large prices so the slider stays usable
                        -- across the full 1..999,999,999 range. The threshold
                        -- must test the item's price, not the fixed ceiling
                        -- (which is constant and would make the coarse branch
                        -- always taken, stranding mid-value exact prices).
                        local step = 1
                        if defaultPrice > 10000 then
                            step = math.max(1, math.floor(defaultPrice / 20))
                        end
                        control.slider:SetValueStep(step)
                        control.slider:SetValue(dialogData and dialogData.selectedPrice or defaultPrice)
                        UpdateSliderValueLabel(control, dialogData and dialogData.selectedPrice or defaultPrice, true, true)
                        control.slider:SetHandler("OnValueChanged", function(_, value)
                            if dialogData then
                                dialogData.selectedPrice = value
                            end
                            UpdateSliderValueLabel(control, value, true, true)
                        end)
                        UpdateSliderActivation(control, dialogData, selected)
                    end,
                },
            },
            {
                template = "ZO_GamepadGuildStoreBrowseSelectableEntryTemplate",
                text = GetString(rawget(_G, "SI_BETTERUI_TH_DIGIT_PRICE") or "Enter Exact Price"),
                templateData = {
                    labelText = GetString(rawget(_G, "SI_BETTERUI_TH_DIGIT_PRICE") or "Enter Exact Price"),
                    isSelectableEntry = true,
                    onSelectedCallback = function()
                        local dialog = ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)
                        local dialogData = dialog and dialog.data
                        if not dialogData then
                            return
                        end
                        local currentPrice = dialogData.selectedPrice or dialogData.defaultPrice or 100
                        if TH.PriceEntry and TH.PriceEntry.ShowDigitPriceDialog then
                            TH.PriceEntry.ShowDigitPriceDialog(currentPrice, 1, 999999999, function(newPrice)
                                dialogData.selectedPrice = newPrice
                            end)
                        end
                    end,
                    setup = function(control, data, selected)
                        if control.label then
                            control.label:SetText(data.labelText)
                        end
                    end,
                },
            },
        },
        buttons = {
            {
                text = SI_DIALOG_CONFIRM,
                callback = function(dialog)
                    local data = dialog.data
                    if not data then
                        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG, "trading_house.create_listing_dialog", "confirm_rejected", {
                            fn = "TradingHouse.RegisterCreateListingDialog.confirm",
                            feature = "trading-house-create-listing",
                            reason = "missingDialogData",
                        })
                        return
                    end
                    if data._submitted then
                        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG, "trading_house.create_listing_dialog", "confirm_rejected", {
                            fn = "TradingHouse.RegisterCreateListingDialog.confirm",
                            feature = "trading-house-create-listing",
                            reason = "alreadySubmitted",
                            bagId = data.bagId,
                            slotIndex = data.slotIndex,
                        })
                        return
                    end
                    data._submitted = true

                    local bagId = data.bagId
                    local slotIndex = data.slotIndex
                    local stackCount = data.selectedStackCount or data.stackCount or 1
                    local price = data.selectedPrice or data.defaultPrice or 0
                    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG, "trading_house.create_listing_dialog", "confirm_begin", {
                        fn = "TradingHouse.RegisterCreateListingDialog.confirm",
                        feature = "trading-house-create-listing",
                        bagId = bagId,
                        slotIndex = slotIndex,
                        stackCount = stackCount,
                        price = price,
                        opId = data.opId,
                        item = data.itemName,
                    })

                    if price <= 0 then
                        data._submitted = false
                        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG, "trading_house.create_listing_dialog", "confirm_rejected", {
                            fn = "TradingHouse.RegisterCreateListingDialog.confirm",
                            feature = "trading-house-create-listing",
                            reason = "invalidPrice",
                            bagId = bagId,
                            slotIndex = slotIndex,
                            price = price,
                        })
                        BETTERUI.CIM.UserAlertText("TH:NoPrice",
                            GetString(rawget(_G, "SI_BETTERUI_TH_ENTER_PRICE")))
                        return
                    end

                    -- Re-validate against the live stack size; the bag can
                    -- change while the dialog is open.
                    local currentStack = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or 0
                    if currentStack <= 0 then
                        data._submitted = false
                        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG, "trading_house.create_listing_dialog", "confirm_rejected", {
                            fn = "TradingHouse.RegisterCreateListingDialog.confirm",
                            feature = "trading-house-create-listing",
                            reason = "slotEmpty",
                            bagId = bagId,
                            slotIndex = slotIndex,
                            currentStack = currentStack,
                        })
                        BETTERUI.CIM.UserAlertText("TH:ListingUnavailable",
                            GetString(rawget(_G, "SI_BETTERUI_TH_ITEM_UNAVAILABLE")) or "Item is no longer available")
                        return
                    end
                    stackCount = zo_min(stackCount, currentStack)

                    -- The dialog captured itemLink at open; abort when the
                    -- slot now holds a different item (bag re-sorted/shifted
                    -- while the dialog was open), or the wrong item would be
                    -- listed at this price.
                    if data.itemLink and GetItemLink then
                        local currentItemLink = GetItemLink(bagId, slotIndex)
                        if currentItemLink ~= data.itemLink then
                            data._submitted = false
                            TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG, "trading_house.create_listing_dialog", "confirm_rejected", {
                                fn = "TradingHouse.RegisterCreateListingDialog.confirm",
                                feature = "trading-house-create-listing",
                                reason = "itemChanged",
                                bagId = bagId,
                                slotIndex = slotIndex,
                                originalItem = data.itemLink,
                                currentItem = currentItemLink,
                            })
                            BETTERUI.CIM.UserAlertText("TH:ListingUnavailable",
                                GetString(rawget(_G, "SI_BETTERUI_TH_ITEM_UNAVAILABLE")) or "Item is no longer available")
                            return
                        end
                    end

                    -- Validate listing-fee affordability before posting.
                    if GetTradingHousePostPriceInfo and GetCurrencyAmount then
                        local listingFee = GetTradingHousePostPriceInfo(price)
                        local gold = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) or 0
                        if (listingFee or 0) > gold then
                            data._submitted = false
                            TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG, "trading_house.create_listing_dialog", "confirm_rejected", {
                                fn = "TradingHouse.RegisterCreateListingDialog.confirm",
                                feature = "trading-house-create-listing",
                                reason = "cannotAffordListingFee",
                                bagId = bagId,
                                slotIndex = slotIndex,
                                price = price,
                                listingFee = listingFee,
                                carriedGold = gold,
                            })
                            BETTERUI.CIM.UserAlertText("TH:CannotAffordFee",
                                GetString(rawget(_G, "SI_BETTERUI_VENDOR_CANNOT_AFFORD")))
                            return
                        end
                    end

                    -- Mirror ZO_GamepadTradingHouse_CreateListing:ShowListItemConfirmation
                    -- (tradinghouse_createlisting_gamepad.lua): stage the pending
                    -- item post before requesting the listing.
                    if SetPendingItemPost then
                        SetPendingItemPost(bagId, slotIndex, stackCount)
                        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.ACTION, "trading_house.pending_post", "set", {
                            fn = "TradingHouse.RegisterCreateListingDialog.confirm",
                            feature = "trading-house-create-listing",
                            bagId = bagId,
                            slotIndex = slotIndex,
                            stackCount = stackCount,
                            price = price,
                            opId = data.opId,
                        })
                    end

                    -- API 50: PostItemOnTradingHouse was removed; posting now
                    -- goes through RequestPostItemOnTradingHouse.
                    if RequestPostItemOnTradingHouse then
                        data.opId = TH.BeginPendingOperation and TH.BeginPendingOperation("create_listing", "trading_house.create_listing", {
                            fn = "TradingHouse.RegisterCreateListingDialog.confirm",
                            feature = "trading-house-create-listing",
                            opId = data.opId,
                            bagId = bagId,
                            slotIndex = slotIndex,
                            stackCount = stackCount,
                            price = price,
                            item = data.itemName,
                        }, false) or data.opId
                        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.ACTION, "trading_house.create_listing", "begin", {
                            fn = "TradingHouse.RegisterCreateListingDialog.confirm",
                            feature = "trading-house-create-listing",
                            bagId = bagId,
                            slotIndex = slotIndex,
                            stackCount = stackCount,
                            price = price,
                            item = data.itemName,
                            opId = data.opId,
                        })
                        RequestPostItemOnTradingHouse(bagId, slotIndex, stackCount, price)
                        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.ACTION, "trading_house.create_listing", "requested", {
                            fn = "TradingHouse.RegisterCreateListingDialog.confirm",
                            feature = "trading-house-create-listing",
                            bagId = bagId,
                            slotIndex = slotIndex,
                            stackCount = stackCount,
                            price = price,
                            item = data.itemName,
                            opId = data.opId,
                        })
                    else
                        data._submitted = false
                        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.ACTION, "trading_house.create_listing", "blocked", {
                            fn = "TradingHouse.RegisterCreateListingDialog.confirm",
                            feature = "trading-house-create-listing",
                            reason = "missingRequestPostItemOnTradingHouse",
                            bagId = bagId,
                            slotIndex = slotIndex,
                            stackCount = stackCount,
                            price = price,
                            opId = data.opId,
                        })
                    end
                end,
            },
            {
                text = SI_DIALOG_CANCEL,
            },
        },
    }
    RegisterTradingHouseDialog(CREATE_LISTING_DIALOG_NAME, dialogInfo)
end

function TH.OnOpenTradingHouse()
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene", "open_received", {
        fn = "TradingHouse.OnOpenTradingHouse",
        feature = "trading-house-scene",
        hasInstance = TH.instance ~= nil,
        interactionType = GetInteractionType and GetInteractionType() or nil,
    })
    if not TH.instance then
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene", "open_skipped", {
            fn = "TradingHouse.OnOpenTradingHouse",
            feature = "trading-house-scene",
            reason = "noInstance",
        })
        return
    end

    local interactionType = GetInteractionType and GetInteractionType() or nil
    if interactionType and interactionType ~= INTERACTION_TRADINGHOUSE then
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene", "open_skipped", {
            fn = "TradingHouse.OnOpenTradingHouse",
            feature = "trading-house-scene",
            reason = "interactionTypeMismatch",
            interactionType = interactionType,
        })
        TH.RestoreNativeSceneAlias()
        return
    end

    -- Mirror native guild default selection (tradinghouse_shared.lua:86-101):
    -- if no trading house guild is selected, select the player's first guild.
    if GetSelectedTradingHouseGuildId and SelectTradingHouseGuildId and GetGuildId then
        local selectedGuild = GetSelectedTradingHouseGuildId()
        if not selectedGuild then
            SelectTradingHouseGuildId(GetGuildId(1))
        end
    end

    -- Mirror native open flow (tradinghouse_gamepad.lua:499): associate the
    -- search singleton with the gamepad browse features so filters/presets work.
    AssociateSearchFeatures()

    TH.AliasSceneToBetterUI()
    TH.instance:SetMode(MODE.BROWSE)
    TH.instance:UpdateTabHeader()
    TH.ResetBrowseState()
    TH.ShowScene()
    TH.ScheduleOwnershipReassert()
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene", "open_shown", {
        fn = "TradingHouse.OnOpenTradingHouse",
        feature = "trading-house-scene",
        searchPending = TH.BrowseComponent and TH.BrowseComponent.searchPending == true,
    })
end

function TH.OnCloseTradingHouse()
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene", "close_received", {
        fn = "TradingHouse.OnCloseTradingHouse",
        feature = "trading-house-scene",
        sceneShowing = TH.instance and TH.instance.IsSceneShowing and TH.instance:IsSceneShowing() or false,
    })
    if TH.Tasks then
        TH.Tasks:Cancel("sceneOwnershipOpen")
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene_ownership", "reassert_cancelled", {
            fn = "TradingHouse.OnCloseTradingHouse",
            feature = "trading-house-scene",
            scheduler = "tasks",
        })
    end

    local sceneName = BETTERUI_TRADING_HOUSE_SCENE_NAME
    if SCENE_MANAGER then
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene and scene.IsShowing and scene:IsShowing() then
            SCENE_MANAGER:Hide(sceneName)
        end
    end

    -- Mirror native close flow (tradinghouse_gamepad.lua:509): disassociate
    -- search features and reset the search singleton's pending state.
    DisassociateSearchFeatures()
    TH.ResetBrowseState()

    TH.AliasSceneToBetterUI()
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.scene", "close_complete", {
        fn = "TradingHouse.OnCloseTradingHouse",
        feature = "trading-house-scene",
        searchPending = TH.BrowseComponent and TH.BrowseComponent.searchPending == true,
    })
end

function TH.OnSearchResultsReceived()
    if TH.BrowseComponent then
        TH.BrowseComponent:OnSearchResultsReceived(TH.instance)
    else
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SEARCH, "trading_house.search_results", "skipped", {
            fn = "TradingHouse.OnSearchResultsReceived",
            feature = "trading-house-search",
            reason = "missingBrowseComponent",
            sceneShowing = TH.instance and TH.instance.IsSceneShowing and TH.instance:IsSceneShowing() or false,
        })
    end
end

function TH.OnSearchCooldownUpdate()
    if TH.instance and TH.instance:IsSceneShowing() then
        RefreshCurrentTradingHouseKeybinds("TradingHouse.OnSearchCooldownUpdate", "searchCooldownUpdate")
    else
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.KEYBIND, "trading_house.keybinds", "refresh_skipped", {
            fn = "TradingHouse.OnSearchCooldownUpdate",
            feature = "trading-house-keybinds",
            reason = "searchCooldownUpdate",
            hasInstance = TH.instance ~= nil,
            sceneShowing = TH.instance and TH.instance.IsSceneShowing and TH.instance:IsSceneShowing() or false,
        })
    end
end

function TH.OnTradingHouseResponse(_, responseType, result)
    ---@type TradingHouseResponsePayload
    local responsePayload = {
        responseType = responseType,
        result = result,
    }

    -- U50: search results arrive via EVENT_TRADING_HOUSE_RESPONSE_RECEIVED
    -- with responseType TRADING_HOUSE_RESULT_SEARCH_PENDING (the dedicated
    -- search-results event was removed from the API).
    local isSearchResponse = responsePayload.responseType == TRADING_HOUSE_RESULT_SEARCH_PENDING

    -- Clear the pending-search flag on ANY search-type response (error,
    -- cooldown, off-scene) so Search is never permanently disabled.
    if isSearchResponse and TH.BrowseComponent then
        TH.BrowseComponent.searchPending = false
    end

    local guildId = GetSelectedTradingHouseGuildId and GetSelectedTradingHouseGuildId() or nil
    local mode = TH.instance and TH.instance.GetCurrentMode and TH.instance:GetCurrentMode() or nil
    local searchPending = TH.BrowseComponent and TH.BrowseComponent.searchPending == true
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SEARCH, "trading_house.response", "received", {
        fn = "TradingHouse.OnTradingHouseResponse",
        feature = "trading-house-search",
        guildId = guildId,
        mode = mode,
        searchPending = searchPending,
        responseType = responseType,
        result = result,
        isSearchResponse = isSearchResponse,
    })
    TraceTradingHouseOperationResponse(responseType, result, guildId, mode)

    if not TH.instance or not TH.instance:IsSceneShowing() then
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SEARCH, "trading_house.response", "skipped", {
            fn = "TradingHouse.OnTradingHouseResponse",
            feature = "trading-house-search",
            guildId = guildId,
            mode = mode,
            searchPending = searchPending,
            responseType = responseType,
            result = result,
            reason = "sceneHidden",
        })
        return
    end

    if responsePayload.result == TRADING_HOUSE_RESULT_SUCCESS then
        if isSearchResponse then
            TH.OnSearchResultsReceived()
        end
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SEARCH, "trading_house.response", "succeeded", {
            fn = "TradingHouse.OnTradingHouseResponse",
            feature = "trading-house-search",
            guildId = guildId,
            mode = mode,
            responseType = responseType,
            result = result,
            isSearchResponse = isSearchResponse,
            searchPendingAfter = TH.BrowseComponent and TH.BrowseComponent.searchPending == true,
            listRefreshScheduled = true,
        })
        TH.ScheduleListRefresh()
    elseif isSearchResponse then
        if TH.BrowseComponent then
            TH.BrowseComponent.searchPending = false
            TH.BrowseComponent.deferredSearchToken = (TH.BrowseComponent.deferredSearchToken or 0) + 1
        end
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SEARCH, "trading_house.response", "failed", {
            fn = "TradingHouse.OnTradingHouseResponse",
            feature = "trading-house-search",
            guildId = guildId,
            mode = mode,
            responseType = responseType,
            result = result,
            searchPendingAfter = TH.BrowseComponent and TH.BrowseComponent.searchPending == true,
            deferredToken = TH.BrowseComponent and TH.BrowseComponent.deferredSearchToken or nil,
        })
        RefreshCurrentTradingHouseKeybinds("TradingHouse.OnTradingHouseResponse", "searchResponseFailed")
    end
    -- Failed search responses are already alerted by ZOS (alerthandlers.lua
    -- listens to EVENT_TRADING_HOUSE_RESPONSE_RECEIVED); avoid a duplicate.
end

function TH.OnGuildRosterChanged()
    local sceneShowing = TH.instance and TH.instance.IsSceneShowing and TH.instance:IsSceneShowing() or false
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.guild_roster", "received", {
        fn = "TradingHouse.OnGuildRosterChanged",
        feature = "trading-house-guild",
        sceneShowing = sceneShowing,
        guildId = GetSelectedTradingHouseGuildId and GetSelectedTradingHouseGuildId() or nil,
        searchPending = TH.BrowseComponent and TH.BrowseComponent.searchPending == true,
    })
    if sceneShowing then
        TH.instance:UpdateTabHeader()
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.guild_roster", "header_refreshed", {
            fn = "TradingHouse.OnGuildRosterChanged",
            feature = "trading-house-guild",
        })
    else
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.guild_roster", "skipped", {
            fn = "TradingHouse.OnGuildRosterChanged",
            feature = "trading-house-guild",
            reason = "sceneHidden",
        })
    end
end

function TH.OnTradingHouseError(_, errorCode)
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SEARCH, "trading_house.error", "received", {
        fn = "TradingHouse.OnTradingHouseError",
        feature = "trading-house-search",
        errorCode = errorCode,
        searchPendingBefore = TH.BrowseComponent and TH.BrowseComponent.searchPending == true,
        sceneShowing = TH.instance and TH.instance.IsSceneShowing and TH.instance:IsSceneShowing() or false,
    })
    TracePendingOperationFailure("error", errorCode and tostring(errorCode) or "tradingHouseError")
    if TH.BrowseComponent then
        TH.BrowseComponent.searchPending = false
        TH.BrowseComponent.deferredSearchToken = (TH.BrowseComponent.deferredSearchToken or 0) + 1
    end
    if TH.instance and TH.instance:IsSceneShowing() and KEYBIND_STRIP then
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.KEYBIND, "trading_house.keybinds", "refresh_before", {
            fn = "TradingHouse.OnTradingHouseError",
            feature = "trading-house-keybinds",
            reason = "tradingHouseError",
            searchPending = TH.BrowseComponent and TH.BrowseComponent.searchPending == true,
        })
        local updateCurrentKeybinds = BETTERUI.Interface and BETTERUI.Interface.UpdateCurrentKeybindGroups
        if updateCurrentKeybinds then
            updateCurrentKeybinds()
        end
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.KEYBIND, "trading_house.keybinds", "refresh_after", {
            fn = "TradingHouse.OnTradingHouseError",
            feature = "trading-house-keybinds",
            reason = "tradingHouseError",
            searchPending = TH.BrowseComponent and TH.BrowseComponent.searchPending == true,
        })
    end
end

function TH.OnListingOperation()
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST, "trading_house.listing_operation", "received", {
        fn = "TradingHouse.OnListingOperation",
        feature = "trading-house-listings",
        sceneShowing = TH.instance and TH.instance.IsSceneShowing and TH.instance:IsSceneShowing() or false,
    })
    if not TH.instance or not TH.instance:IsSceneShowing() then
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST, "trading_house.listing_operation", "skipped", {
            fn = "TradingHouse.OnListingOperation",
            feature = "trading-house-listings",
            reason = "sceneHidden",
        })
        return
    end
    TH.ScheduleListRefresh()
end

function TH.OnInventorySingleSlotUpdate()
    local isSellMode = TH.instance and TH.instance.GetCurrentMode and TH.instance:GetCurrentMode() == MODE.SELL
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST, "trading_house.inventory_slot_update", "received", {
        fn = "TradingHouse.OnInventorySingleSlotUpdate",
        feature = "trading-house-sell",
        sceneShowing = TH.instance and TH.instance.IsSceneShowing and TH.instance:IsSceneShowing() or false,
        isSellMode = isSellMode == true,
    })
    if TH.instance and TH.instance:IsSceneShowing() and isSellMode then
        TH.OnListingOperation()
    end
end

function TH.OnTradingHouseResponseTimeout()
    -- EVENT_TRADING_HOUSE_RESPONSE_TIMEOUT: the server did not return a
    -- response in time. Clear the pending flag so Search/paging can retry.
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SEARCH, "trading_house.response", "timeout", {
        fn = "TradingHouse.OnTradingHouseResponseTimeout",
        feature = "trading-house-search",
        timeoutType = "response",
        searchPendingBefore = TH.BrowseComponent and TH.BrowseComponent.searchPending == true,
    })
    if TH.BrowseComponent then
        TH.BrowseComponent.searchPending = false
        TH.BrowseComponent.deferredSearchToken = (TH.BrowseComponent.deferredSearchToken or 0) + 1
    end
    TracePendingOperationTimeout("responseTimeout")
    RefreshCurrentTradingHouseKeybinds("TradingHouse.OnTradingHouseResponseTimeout", "responseTimeout")
end

function TH.OnTradingHouseOperationTimeout()
    -- EVENT_TRADING_HOUSE_OPERATION_TIME_OUT: a general operation timed out.
    -- Treat it like a response timeout for browse pending state.
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SEARCH, "trading_house.response", "timeout", {
        fn = "TradingHouse.OnTradingHouseOperationTimeout",
        feature = "trading-house-search",
        timeoutType = "operation",
        searchPendingBefore = TH.BrowseComponent and TH.BrowseComponent.searchPending == true,
    })
    if TH.BrowseComponent then
        TH.BrowseComponent.searchPending = false
        TH.BrowseComponent.deferredSearchToken = (TH.BrowseComponent.deferredSearchToken or 0) + 1
    end
    TracePendingOperationTimeout("operationTimeout")
    RefreshCurrentTradingHouseKeybinds("TradingHouse.OnTradingHouseOperationTimeout", "operationTimeout")
end

function TH.OnSelectedTradingHouseGuildChanged()
    -- EVENT_TRADING_HOUSE_SELECTED_GUILD_CHANGED can fire from native guild
    -- selection as well as from our CycleGuild; invalidate stale browse state
    -- and refresh the header/list just like CycleGuild does.
    -- Guard on IsSceneShowing() like the sibling handlers: the guild selector
    -- UI calls SelectTradingHouseGuildId globally, so this event can fire
    -- off-scene and must not trigger a server RequestTradingHouseListings call
    -- or a list rebuild while our scene is hidden.
    if not TH.instance or not TH.instance:IsSceneShowing() then
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.guild", "selected_changed_skipped", {
            fn = "TradingHouse.OnSelectedTradingHouseGuildChanged",
            feature = "trading-house-guild",
            reason = "sceneHidden",
            hasInstance = TH.instance ~= nil,
            guildId = GetSelectedTradingHouseGuildId and GetSelectedTradingHouseGuildId() or nil,
            searchPending = TH.BrowseComponent and TH.BrowseComponent.searchPending == true,
        })
        return
    end
    local guildId = GetSelectedTradingHouseGuildId and GetSelectedTradingHouseGuildId() or nil
    local mode = TH.instance and TH.instance.GetCurrentMode and TH.instance:GetCurrentMode() or nil
    local searchPending = TH.BrowseComponent and TH.BrowseComponent.searchPending == true
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.guild", "selected_changed", {
        fn = "TradingHouse.OnSelectedTradingHouseGuildChanged",
        feature = "trading-house-guild",
        guildId = guildId,
        mode = mode,
        searchPending = searchPending,
    })
    TH.ResetBrowseState()
    if TH.BrowseComponent and TH.BrowseComponent.InvalidateResults then
        TH.BrowseComponent:InvalidateResults()
    end
    if TH.instance:GetCurrentMode() == MODE.LISTINGS and RequestTradingHouseListings then
        RequestTradingHouseListings()
    end
    TH.instance:UpdateTabHeader()
    TH.instance:RefreshList()
    if TH.instance.RefreshTHFooter then
        TH.instance:RefreshTHFooter()
    end
end

function TH.OnTradingHouseStatusReceived()
    -- EVENT_TRADING_HOUSE_STATUS_RECEIVED: refresh listings when the listings
    -- tab is active so counts stay current.
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE, "trading_house.status", "received", {
        fn = "TradingHouse.OnTradingHouseStatusReceived",
        feature = "trading-house-status",
        sceneShowing = TH.instance and TH.instance.IsSceneShowing and TH.instance:IsSceneShowing() or false,
    })
    if not TH.instance or not TH.instance:IsSceneShowing() then
        return
    end
    if TH.instance:GetCurrentMode() == MODE.LISTINGS and RequestTradingHouseListings then
        RequestTradingHouseListings()
        TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST, "trading_house.listings", "requested", {
            fn = "TradingHouse.OnTradingHouseStatusReceived",
            feature = "trading-house-listings",
            reason = "statusReceived",
        })
    end
end

function TH.OnMoneyUpdate()
    -- EVENT_MONEY_UPDATE: refresh the gold footer and schedule a list refresh
    -- while the trading house scene is showing.
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.CURRENCY, "trading_house.money_update", "received", {
        fn = "TradingHouse.OnMoneyUpdate",
        feature = "trading-house-currency",
        carriedGold = BETTERUI.Log and BETTERUI.Log.GetCurrencyAmountForLocation and BETTERUI.Log.GetCurrencyAmountForLocation(rawget(_G, "CURT_MONEY"), rawget(_G, "CURRENCY_LOCATION_CHARACTER")) or nil,
        bankGold = BETTERUI.Log and BETTERUI.Log.GetCurrencyAmountForLocation and BETTERUI.Log.GetCurrencyAmountForLocation(rawget(_G, "CURT_MONEY"), rawget(_G, "CURRENCY_LOCATION_BANK")) or nil,
        sceneShowing = TH.instance and TH.instance.IsSceneShowing and TH.instance:IsSceneShowing() or false,
    })
    if not TH.instance or not TH.instance:IsSceneShowing() then
        return
    end
    if TH.instance.RefreshTHFooter then
        TH.instance:RefreshTHFooter()
    end
    TraceTHFlow(BETTERUI.Log and BETTERUI.Log.CATEGORY.CURRENCY, "trading_house.money_update", "footer_refreshed", {
        fn = "TradingHouse.OnMoneyUpdate",
        feature = "trading-house-currency",
        carriedGold = BETTERUI.Log and BETTERUI.Log.GetCurrencyAmountForLocation and BETTERUI.Log.GetCurrencyAmountForLocation(rawget(_G, "CURT_MONEY"), rawget(_G, "CURRENCY_LOCATION_CHARACTER")) or nil,
        bankGold = BETTERUI.Log and BETTERUI.Log.GetCurrencyAmountForLocation and BETTERUI.Log.GetCurrencyAmountForLocation(rawget(_G, "CURT_MONEY"), rawget(_G, "CURRENCY_LOCATION_BANK")) or nil,
    })
    TH.ScheduleListRefresh()
end

function TH.RegisterEvents(eventManager)
    if not eventManager then
        return
    end

    eventManager:RegisterForEvent(EVENT_NS .. "_Open",
        EVENT_OPEN_TRADING_HOUSE, TH.OnOpenTradingHouse)
    eventManager:RegisterForEvent(EVENT_NS .. "_Close",
        EVENT_CLOSE_TRADING_HOUSE, TH.OnCloseTradingHouse)
    eventManager:RegisterForEvent(EVENT_NS .. "_Cooldown",
        EVENT_TRADING_HOUSE_SEARCH_COOLDOWN_UPDATE, TH.OnSearchCooldownUpdate)
    eventManager:RegisterForEvent(EVENT_NS .. "_Response",
        EVENT_TRADING_HOUSE_RESPONSE_RECEIVED, TH.OnTradingHouseResponse)
    eventManager:RegisterForEvent(EVENT_NS .. "_ResponseTimeout",
        EVENT_TRADING_HOUSE_RESPONSE_TIMEOUT, TH.OnTradingHouseResponseTimeout)
    eventManager:RegisterForEvent(EVENT_NS .. "_OperationTimeout",
        EVENT_TRADING_HOUSE_OPERATION_TIME_OUT, TH.OnTradingHouseOperationTimeout)
    if EVENT_TRADING_HOUSE_ERROR then
        eventManager:RegisterForEvent(EVENT_NS .. "_Error",
            EVENT_TRADING_HOUSE_ERROR, TH.OnTradingHouseError)
    end
    eventManager:RegisterForEvent(EVENT_NS .. "_ListingOp",
        EVENT_TRADING_HOUSE_CONFIRM_ITEM_PURCHASE, TH.OnListingOperation)
    eventManager:RegisterForEvent(EVENT_NS .. "_GuildJoin",
        EVENT_GUILD_SELF_JOINED_GUILD, TH.OnGuildRosterChanged)
    eventManager:RegisterForEvent(EVENT_NS .. "_GuildLeave",
        EVENT_GUILD_SELF_LEFT_GUILD, TH.OnGuildRosterChanged)
    eventManager:RegisterForEvent(EVENT_NS .. "_SelectedGuildChanged",
        EVENT_TRADING_HOUSE_SELECTED_GUILD_CHANGED, TH.OnSelectedTradingHouseGuildChanged)
    eventManager:RegisterForEvent(EVENT_NS .. "_StatusReceived",
        EVENT_TRADING_HOUSE_STATUS_RECEIVED, TH.OnTradingHouseStatusReceived)
    eventManager:RegisterForEvent(EVENT_NS .. "_MoneyUpdate",
        EVENT_MONEY_UPDATE, TH.OnMoneyUpdate)
    eventManager:RegisterForEvent(EVENT_NS .. "_InvUpdate",
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE, TH.OnInventorySingleSlotUpdate)
end
