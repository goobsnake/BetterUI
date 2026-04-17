--[[
File: Modules/TradingHouse/Core/TradingHouseRuntimeFlow.lua
Purpose: Scene ownership, dialog registration, and runtime event flow for the
         Trading House module.
]]

local TH = BETTERUI.TradingHouse
local MODE = TH.MODE
local EVENT_NS = "BetterUI_TradingHouse"
local TH_SYSTEM_NAME = rawget(_G, "ZO_TRADING_HOUSE_SYSTEM_NAME") or "tradingHouse"

---@alias TradingHouseSceneOwner {scene: table|nil}
---@alias TradingHouseCreateListingDialogData {stackCount: integer|nil, selectedStackCount: integer|nil, defaultPrice: integer|nil, selectedPrice: integer|nil}
---@alias TradingHouseResponsePayload {responseType: integer|nil, result: integer|nil}

local function SetTHSceneAlias(sceneObject)
    if not SCENE_MANAGER or not SCENE_MANAGER.scenes then
        return
    end
    SCENE_MANAGER.scenes["gamepad_trading_house"] = sceneObject
end

local function SetTHSystemGamepadRootScene(sceneObject)
    if not SYSTEMS or type(SYSTEMS.GetSystem) ~= "function" then
        return
    end
    local system = SYSTEMS:GetSystem(TH_SYSTEM_NAME)
    if not system then
        return
    end
    if TH.nativeTHSystemGamepadRootScene == nil then
        TH.nativeTHSystemGamepadRootScene = system.gamepadRootScene
    end
    system.gamepadRootScene = sceneObject
end

local function RefreshVisibleTradingHouseScene()
    if not TH.instance or not TH.instance:IsSceneShowing() then
        return
    end
    TH.instance:RefreshList()
    TH.instance:RefreshTHFooter()
end

function TH.CaptureNativeScene(sceneManager)
    if TH.nativeTHScene ~= nil then
        return
    end
    if not sceneManager or type(sceneManager.GetScene) ~= "function" then
        return
    end
    TH.nativeTHScene = sceneManager:GetScene("gamepad_trading_house")
end

function TH.SetTradingHouseSceneOwnership(sceneObject)
    if not sceneObject then
        return
    end
    SetTHSceneAlias(sceneObject)
    SetTHSystemGamepadRootScene(sceneObject)
end

function TH.RestoreNativeSceneAlias()
    if TH.nativeTHScene then
        SetTHSceneAlias(TH.nativeTHScene)
    end
    if TH.nativeTHSystemGamepadRootScene then
        SetTHSystemGamepadRootScene(TH.nativeTHSystemGamepadRootScene)
    end
end

function TH.AliasSceneToBetterUI()
    if TH.instance and TH.instance.scene then
        TH.SetTradingHouseSceneOwnership(TH.instance.scene)
    end
end

function TH.ResetBrowseState()
    if TH.BrowseComponent then
        TH.BrowseComponent.currentPage = 0
        TH.BrowseComponent.searchPending = false
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
            return
        end
        TH.AliasSceneToBetterUI()
        TH.ShowScene()
    end

    if TH.Tasks then
        TH.Tasks:Cancel("sceneOwnershipOpen")
        TH.Tasks:Schedule("sceneOwnershipOpen", 30, ReassertTradingHouseOwnership)
    elseif type(zo_callLater) == "function" then
        zo_callLater(ReassertTradingHouseOwnership, 30)
    end
end

function TH.ScheduleListRefresh()
    if not TH.instance or not TH.instance:IsSceneShowing() then
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
        return
    end

    if nativeTH.control then
        nativeTH.control:UnregisterForEvent(EVENT_OPEN_TRADING_HOUSE)
        nativeTH.control:UnregisterForEvent(EVENT_CLOSE_TRADING_HOUSE)
    end
    if ZO_TRADING_HOUSE_SYSTEM_NAME then
        EVENT_MANAGER:UnregisterForEvent(ZO_TRADING_HOUSE_SYSTEM_NAME, EVENT_OPEN_TRADING_HOUSE)
        EVENT_MANAGER:UnregisterForEvent(ZO_TRADING_HOUSE_SYSTEM_NAME, EVENT_CLOSE_TRADING_HOUSE)
    end
    if nativeTH.sceneName then
        nativeTH.sceneName = "betterui_native_th_blocked"
    end
    nativeTH.OpenTradingHouse = function(_)
        TH.OnOpenTradingHouse()
    end
    nativeTH.CloseTradingHouse = function(_)
        TH.OnCloseTradingHouse()
    end
end

function TH.RegisterCreateListingDialog()
    if ZO_Dialogs_IsDialogRegistered and ZO_Dialogs_IsDialogRegistered("BETTERUI_TRADING_HOUSE_CREATE_LISTING") then
        return
    end

    ZO_Dialogs_RegisterCustomDialog("BETTERUI_TRADING_HOUSE_CREATE_LISTING", {
        canQueue = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
        },
        title = {
            text = rawget(_G, "SI_BETTERUI_TH_LIST_ITEM") or SI_TRADING_HOUSE_POST_ITEM,
        },
        setup = function(dialog)
            dialog:setupFunc()
        end,
        parametricList = {
            {
                template = "ZO_GamepadSliderDialogTemplate",
                text = GetString(rawget(_G, "SI_TRADING_HOUSE_POSTING_QUANTITY")),
                templateData = {
                    setup = function(control, data)
                        local dialog = data.dialog or ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)
                        ---@type TradingHouseCreateListingDialogData|nil
                        local dialogData = dialog and dialog.data
                        local maxStack = dialogData and dialogData.stackCount or 1
                        control.slider:SetMinMax(1, maxStack)
                        control.slider:SetValue(dialogData and dialogData.selectedStackCount or maxStack)
                        control.slider:SetValueChangedCallback(function(_, value)
                            if dialogData then
                                dialogData.selectedStackCount = value
                            end
                        end)
                    end,
                },
            },
            {
                template = "ZO_GamepadSliderDialogTemplate",
                text = GetString(rawget(_G, "SI_BETTERUI_TH_PRICE_LABEL")),
                templateData = {
                    setup = function(control, data)
                        local dialog = data.dialog or ZO_GenericGamepadDialog_GetControl(GAMEPAD_DIALOGS.PARAMETRIC)
                        ---@type TradingHouseCreateListingDialogData|nil
                        local dialogData = dialog and dialog.data
                        local defaultPrice = dialogData and dialogData.defaultPrice or 100
                        local maxPrice = 999999999
                        control.slider:SetMinMax(1, maxPrice)
                        control.slider:SetValue(defaultPrice)
                        control.slider:SetValueChangedCallback(function(_, value)
                            if dialogData then
                                dialogData.selectedPrice = value
                            end
                        end)
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
                        return
                    end
                    if data._submitted then
                        return
                    end
                    data._submitted = true

                    local bagId = data.bagId
                    local slotIndex = data.slotIndex
                    local stackCount = data.selectedStackCount or data.stackCount or 1
                    local price = data.selectedPrice or 0

                    if price <= 0 then
                        data._submitted = false
                        BETTERUI.CIM.UserAlertText("TH:NoPrice",
                            GetString(rawget(_G, "SI_BETTERUI_TH_ENTER_PRICE")))
                        return
                    end

                    if PostItemOnTradingHouse then
                        PostItemOnTradingHouse(bagId, slotIndex, stackCount, price)
                    end
                end,
            },
            {
                text = SI_DIALOG_CANCEL,
            },
        },
    })
end

function TH.OnOpenTradingHouse()
    if not TH.instance then
        return
    end

    local interactionType = GetInteractionType and GetInteractionType() or nil
    if interactionType and interactionType ~= INTERACTION_TRADINGHOUSE then
        TH.RestoreNativeSceneAlias()
        return
    end

    TH.AliasSceneToBetterUI()
    TH.instance:SetMode(MODE.BROWSE)
    TH.instance:UpdateTabHeader()
    TH.ResetBrowseState()
    TH.ShowScene()
    TH.ScheduleOwnershipReassert()
end

function TH.OnCloseTradingHouse()
    if TH.Tasks then
        TH.Tasks:Cancel("sceneOwnershipOpen")
    end

    local sceneName = BETTERUI_TRADING_HOUSE_SCENE_NAME
    if SCENE_MANAGER then
        local scene = SCENE_MANAGER:GetScene(sceneName)
        if scene and scene.IsShowing and scene:IsShowing() then
            SCENE_MANAGER:Hide(sceneName)
        end
    end

    TH.AliasSceneToBetterUI()
end

function TH.OnSearchResultsReceived()
    if TH.BrowseComponent then
        TH.BrowseComponent:OnSearchResultsReceived(TH.instance)
    end
end

function TH.OnSearchCooldownUpdate()
    if TH.instance and TH.instance:IsSceneShowing() then
        KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
    end
end

function TH.OnTradingHouseResponse(_, responseType, result)
    ---@type TradingHouseResponsePayload
    local responsePayload = {
        responseType = responseType,
        result = result,
    }
    if not TH.instance or not TH.instance:IsSceneShowing() then
        return
    end
    if responsePayload.result == TRADING_HOUSE_RESULT_SUCCESS then
        TH.ScheduleListRefresh()
    end
end

function TH.OnGuildRosterChanged()
    if TH.instance and TH.instance:IsSceneShowing() then
        TH.instance:UpdateTabHeader()
    end
end

function TH.OnListingOperation()
    if not TH.instance or not TH.instance:IsSceneShowing() then
        return
    end
    TH.ScheduleListRefresh()
end

function TH.OnInventorySingleSlotUpdate()
    if TH.instance and TH.instance:IsSceneShowing() and
       TH.instance:GetCurrentMode() == MODE.SELL then
        TH.OnListingOperation()
    end
end

function TH.RegisterEvents(eventManager)
    if not eventManager then
        return
    end

    eventManager:RegisterForEvent(EVENT_NS .. "_Open",
        EVENT_OPEN_TRADING_HOUSE, TH.OnOpenTradingHouse)
    eventManager:RegisterForEvent(EVENT_NS .. "_Close",
        EVENT_CLOSE_TRADING_HOUSE, TH.OnCloseTradingHouse)
    eventManager:RegisterForEvent(EVENT_NS .. "_SearchResults",
        EVENT_TRADING_HOUSE_SEARCH_RESULTS_RECEIVED, TH.OnSearchResultsReceived)
    eventManager:RegisterForEvent(EVENT_NS .. "_Cooldown",
        EVENT_TRADING_HOUSE_SEARCH_COOLDOWN_UPDATE, TH.OnSearchCooldownUpdate)
    eventManager:RegisterForEvent(EVENT_NS .. "_Response",
        EVENT_TRADING_HOUSE_RESPONSE_RECEIVED, TH.OnTradingHouseResponse)
    eventManager:RegisterForEvent(EVENT_NS .. "_ListingOp",
        EVENT_TRADING_HOUSE_CONFIRM_ITEM_PURCHASE, TH.OnListingOperation)
    eventManager:RegisterForEvent(EVENT_NS .. "_GuildJoin",
        EVENT_GUILD_SELF_JOINED_GUILD, TH.OnGuildRosterChanged)
    eventManager:RegisterForEvent(EVENT_NS .. "_GuildLeave",
        EVENT_GUILD_SELF_LEFT_GUILD, TH.OnGuildRosterChanged)
    eventManager:RegisterForEvent(EVENT_NS .. "_InvUpdate",
        EVENT_INVENTORY_SINGLE_SLOT_UPDATE, TH.OnInventorySingleSlotUpdate)
end
