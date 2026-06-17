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
    -- "tradingHouse" matches ZO_TRADING_HOUSE_SYSTEM_NAME (tradinghouse_shared.lua).
    local systemName = ZO_TRADING_HOUSE_SYSTEM_NAME or "tradingHouse"
    local system = SYSTEMS:GetSystem(systemName)
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
    local guildId = GetSelectedTradingHouseGuildId and GetSelectedTradingHouseGuildId() or nil
    local mode = TH.instance and TH.instance.GetCurrentMode and TH.instance:GetCurrentMode() or nil
    local searchPending = TH.BrowseComponent and TH.BrowseComponent.searchPending == true
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "scheduleListRefresh",
            { guildId = guildId, mode = mode, searchPending = searchPending })
    end
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

    ZO_Dialogs_RegisterCustomDialog("BETTERUI_TRADING_HOUSE_CREATE_LISTING", {
        canQueue = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
        },
        finishedCallback = function(dialog)
            local dialogData = dialog and dialog.data
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
            end
        end,
        title = {
            text = rawget(_G, "SI_BETTERUI_TH_LIST_ITEM") or SI_TRADING_HOUSE_POST_ITEM,
        },
        setup = function(dialog)
            dialog:setupFunc()
        end,
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
                    local price = data.selectedPrice or data.defaultPrice or 0

                    if price <= 0 then
                        data._submitted = false
                        BETTERUI.CIM.UserAlertText("TH:NoPrice",
                            GetString(rawget(_G, "SI_BETTERUI_TH_ENTER_PRICE")))
                        return
                    end

                    -- Re-validate against the live stack size; the bag can
                    -- change while the dialog is open.
                    local currentStack = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or 0
                    if currentStack <= 0 then
                        data._submitted = false
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
                    end

                    -- API 50: PostItemOnTradingHouse was removed; posting now
                    -- goes through RequestPostItemOnTradingHouse.
                    if RequestPostItemOnTradingHouse then
                        RequestPostItemOnTradingHouse(bagId, slotIndex, stackCount, price)
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

    -- Mirror native close flow (tradinghouse_gamepad.lua:509): disassociate
    -- search features and reset the search singleton's pending state.
    DisassociateSearchFeatures()

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
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SEARCH, "tradingHouseResponse",
            { guildId = guildId, mode = mode, searchPending = searchPending })
    end

    if not TH.instance or not TH.instance:IsSceneShowing() then
        return
    end

    if responsePayload.result == TRADING_HOUSE_RESULT_SUCCESS then
        if isSearchResponse then
            TH.OnSearchResultsReceived()
        end
        TH.ScheduleListRefresh()
    end
    -- Failed search responses are already alerted by ZOS (alerthandlers.lua
    -- listens to EVENT_TRADING_HOUSE_RESPONSE_RECEIVED); avoid a duplicate.
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

function TH.OnTradingHouseResponseTimeout()
    -- EVENT_TRADING_HOUSE_RESPONSE_TIMEOUT: the server did not return a
    -- response in time. Clear the pending flag so Search/paging can retry.
    if TH.BrowseComponent then
        TH.BrowseComponent.searchPending = false
    end
    if TH.instance and TH.instance:IsSceneShowing() then
        KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
    end
end

function TH.OnTradingHouseOperationTimeout()
    -- EVENT_TRADING_HOUSE_OPERATION_TIME_OUT: a general operation timed out.
    -- Treat it like a response timeout for browse pending state.
    if TH.BrowseComponent then
        TH.BrowseComponent.searchPending = false
    end
    if TH.instance and TH.instance:IsSceneShowing() then
        KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
    end
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
        return
    end
    local guildId = GetSelectedTradingHouseGuildId and GetSelectedTradingHouseGuildId() or nil
    local mode = TH.instance and TH.instance.GetCurrentMode and TH.instance:GetCurrentMode() or nil
    local searchPending = TH.BrowseComponent and TH.BrowseComponent.searchPending == true
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SCENE, "selectedTradingHouseGuildChanged",
            { guildId = guildId, mode = mode, searchPending = searchPending })
    end
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
    if not TH.instance or not TH.instance:IsSceneShowing() then
        return
    end
    if TH.instance:GetCurrentMode() == MODE.LISTINGS and RequestTradingHouseListings then
        RequestTradingHouseListings()
    end
end

function TH.OnMoneyUpdate()
    -- EVENT_MONEY_UPDATE: refresh the gold footer and schedule a list refresh
    -- while the trading house scene is showing.
    if not TH.instance or not TH.instance:IsSceneShowing() then
        return
    end
    if TH.instance.RefreshTHFooter then
        TH.instance:RefreshTHFooter()
    end
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
