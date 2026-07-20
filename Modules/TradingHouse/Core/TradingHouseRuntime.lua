--[[
File: Modules/TradingHouse/Core/TradingHouseRuntime.lua
Purpose: Runtime scene, dialog, ownership, and event orchestration for the
         Trading House module so TradingHouse.lua can stay focused on module
         lifecycle wiring and public API.
]]

local TH = BETTERUI.TradingHouse
local MODE = TH.MODE

local function GetTHRuntimeString(primaryIdName, fallbackIdName, fallback)
    local id = primaryIdName and rawget(_G, primaryIdName) or nil
    if id ~= nil and GetString then
        local ok, value = pcall(GetString, id)
        if ok and value and value ~= "" then return value end
    end

    id = fallbackIdName and rawget(_G, fallbackIdName) or nil
    if id ~= nil and GetString then
        local ok, value = pcall(GetString, id)
        if ok and value and value ~= "" then return value end
    end

    return fallback or ""
end

local function FormatTHRuntimeString(idName, fallback, ...)
    local id = idName and rawget(_G, idName) or nil
    if id ~= nil and zo_strformat then
        local ok, value = pcall(zo_strformat, id, ...)
        if ok and value and value ~= "" then return value end
    end
    return fallback or ""
end

local function QueueTradingHouseNarration()
    local narration = BETTERUI.CIM and BETTERUI.CIM.Narration
    local queueSceneNarration = narration and narration.QueueSceneNarration
    if type(queueSceneNarration) == "function" then
        queueSceneNarration(BETTERUI_TRADING_HOUSE_SCENE_NAME)
    end
end

---@alias THModeDef {mode: number, name: fun(): string}
---@alias TradingHouseSelectionPayload {dataSource: table|nil, bagId: integer|nil, slotIndex: integer|nil}
---@alias TradingHouseSceneLifecyclePayload {keybinds: table[], taskManager: table|nil, onShowing: fun(screen: BETTERUI.TradingHouse.Class), onHiding: fun(screen: BETTERUI.TradingHouse.Class), onHidden: fun(screen: BETTERUI.TradingHouse.Class)}
---@alias TradingHouseKeybindGroup table

---@type table<number, THModeDef>
local TH_MODE_DEFINITIONS = {
    [MODE.BROWSE] = { mode = MODE.BROWSE, name = function() return GetTHRuntimeString("SI_BETTERUI_TH_TAB_BROWSE", "SI_TRADING_HOUSE_MODE_BROWSE", "Browse") end },
    [MODE.LISTINGS] = { mode = MODE.LISTINGS, name = function() return GetTHRuntimeString("SI_BETTERUI_TH_TAB_LISTINGS", "SI_TRADING_HOUSE_MODE_LISTINGS", "My Listings") end },
    [MODE.SELL] = { mode = MODE.SELL, name = function() return GetTHRuntimeString("SI_BETTERUI_TH_TAB_SELL", "SI_TRADING_HOUSE_MODE_SELL", "Sell") end },
}

---@param mode number
---@return THModeDef|nil definition
function TH.GetModeDefinition(mode)
    return TH_MODE_DEFINITIONS[mode]
end

---@param currentMode number
---@return THModeDef|nil leftMode, THModeDef|nil rightMode
function TH.GetAlternateModeBindings(currentMode)
    if currentMode == MODE.BROWSE then
        return nil, TH_MODE_DEFINITIONS[MODE.SELL]
    elseif currentMode == MODE.SELL then
        return TH_MODE_DEFINITIONS[MODE.BROWSE], TH_MODE_DEFINITIONS[MODE.LISTINGS]
    elseif currentMode == MODE.LISTINGS then
        return TH_MODE_DEFINITIONS[MODE.BROWSE], TH_MODE_DEFINITIONS[MODE.SELL]
    end
    return nil, TH_MODE_DEFINITIONS[MODE.SELL]
end

local TraceTHRuntime = (BETTERUI.Log and BETTERUI.Log.MakeTracer)
    and BETTERUI.Log.MakeTracer{ module = "TradingHouse", feature = "trading-house", category = BETTERUI.Log.CATEGORY.ACTION }
    or function() end

local function WrapTradingHouseKeybindGroup(group)
    local keybinds = BETTERUI.CIM and BETTERUI.CIM.Keybinds
    local anchor = keybinds and keybinds.InputAnchor
    if anchor and type(anchor.WrapGroup) == "function" then
        return anchor.WrapGroup(group, "TradingHouse")
    end
    return group
end

local function GetTHCurrentMode(thInstance)
    return thInstance and thInstance.GetCurrentMode and thInstance:GetCurrentMode() or nil
end

local function GetTHListTargetData(thInstance)
    local list = thInstance and thInstance.list or nil
    local getTargetData = BETTERUI.CIM and BETTERUI.CIM.Utils
        and (BETTERUI.CIM.Utils.GetListTargetData or BETTERUI.CIM.Utils.SafeGetTargetData)
    local selectedData = (type(getTargetData) == "function") and getTargetData(list) or nil
    if not selectedData and list and list.GetTargetData then
        local ok, data = pcall(function() return list:GetTargetData() end)
        if ok then selectedData = data end
    end
    return selectedData and (selectedData.dataSource or selectedData) or nil
end

local function IsTHBrowseResultsSection(thInstance)
    if GetTHCurrentMode(thInstance) ~= MODE.BROWSE then return false end
    local data = GetTHListTargetData(thInstance)
    return data ~= nil and (data.listingIndex ~= nil or data.purchasePrice ~= nil or data.sellerName ~= nil)
end

local function IsTHBrowseFiltersSection(thInstance)
    return GetTHCurrentMode(thInstance) == MODE.BROWSE and not IsTHBrowseResultsSection(thInstance)
end

local function GetTHKeybindSection(thInstance)
    local mode = GetTHCurrentMode(thInstance)
    if mode == MODE.BROWSE then
        return IsTHBrowseResultsSection(thInstance) and "browseResults" or "browseFilters"
    elseif mode == MODE.SELL then
        return "sell"
    elseif mode == MODE.LISTINGS then
        return "listings"
    end
    return "unknown"
end

local function TraceTHKeybind(thInstance, phase, keybind, extra)
    extra = extra or {}
    extra.fn = extra.fn or "TH.BuildCoreKeybinds"
    extra.mode = GetTHCurrentMode(thInstance)
    extra.section = GetTHKeybindSection(thInstance)
    extra.keybind = keybind
    TraceTHRuntime("trading_house.keybind", phase, extra)
end

local function GetTHSelectedPurchasePriceText(thInstance, narration)
    local data = GetTHListTargetData(thInstance)
    local price = data and (data.purchasePrice or data.price or data.sellPrice) or nil
    if not price then return "" end
    if ZO_Currency_FormatGamepad and CURT_MONEY then
        local format = narration and ZO_CURRENCY_FORMAT_AMOUNT_NAME or ZO_CURRENCY_FORMAT_AMOUNT_ICON
        local ok, value = pcall(ZO_Currency_FormatGamepad, CURT_MONEY, price, format)
        if ok and value and value ~= "" then return value end
    end
    return tostring(price)
end

local function GetTHBuyItemKeybindName(thInstance, narration)
    local priceText = GetTHSelectedPurchasePriceText(thInstance, narration)
    local buyText = GetTHRuntimeString("SI_TRADING_HOUSE_BUY_ITEM", nil, "Buy Item")
    if priceText == "" then return buyText end
    return FormatTHRuntimeString("SI_GAMEPAD_TRADING_HOUSE_BUY_ITEM", buyText .. " (" .. priceText .. ")", priceText)
end

local function CanTHSubmitBrowseSearch()
    if TH.BrowseComponent and TH.BrowseComponent.searchPending then
        return false
    end
    -- The native cooldown is the authoritative submit gate after a search.
    if GetTradingHouseCooldownRemaining
        and GetTradingHouseCooldownRemaining() > 0 then
        return false
    end
    return true
end

local function ClearTHListSearch(thInstance)
    local control = thInstance.textSearchHeaderControl
    if not control or (control.IsHidden and control:IsHidden()) then
        return false
    end

    local searchMixin = BETTERUI.Interface and BETTERUI.Interface.SearchMixin
    if searchMixin and searchMixin.CallSearchLifecycle then
        searchMixin.CallSearchLifecycle(thInstance, "clear")
    elseif thInstance.ClearSearchInput then
        thInstance:ClearSearchInput()
    end

    if thInstance._searchModeActive then
        if searchMixin and searchMixin.CallSearchLifecycle then
            searchMixin.CallSearchLifecycle(thInstance, "exit")
        elseif thInstance.ExitSearchMode then
            thInstance:ExitSearchMode()
        end
    elseif TH.RefreshCurrentTradingHouseKeybinds then
        TH.RefreshCurrentTradingHouseKeybinds(
            "BuildCoreKeybinds:clearSearch", "clearSearch", true)
    end
    TraceTHKeybind(thInstance, "activated", "UI_SHORTCUT_QUATERNARY", {
        action = "clearSearch",
    })
    return true
end

local function CreateTHClearSearchKeybind(thInstance)
    local callback = function()
        ClearTHListSearch(thInstance)
    end
    local visible = function()
        return thInstance.textSearchHeaderControl ~= nil
    end
    local hasText = function()
        return thInstance.searchQuery and thInstance.searchQuery ~= ""
    end
    local factory = BETTERUI.CIM and BETTERUI.CIM.Keybinds
        and BETTERUI.CIM.Keybinds.CreateClearSearchKeybind
    if type(factory) == "function" then
        return factory(callback, visible, hasText)
    end
    return {
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        name = GetTHRuntimeString("SI_BETTERUI_CLEAR_SEARCH", nil, "Clear Search"),
        keybind = "UI_SHORTCUT_QUATERNARY",
        disabledDuringSceneHiding = true,
        visible = function()
            return visible() and hasText()
        end,
        callback = callback,
    }
end

local function CanOpenTHBrowseFilters(thInstance)
    return GetTHCurrentMode(thInstance) == MODE.BROWSE
        and TH.BrowseFilters ~= nil
        and type(TH.BrowseFilters.ShowFilterDialog) == "function"
end

local function OpenTHBrowseFilters(thInstance)
    if not CanOpenTHBrowseFilters(thInstance) then
        return false
    end
    TraceTHKeybind(thInstance, "activated", "UI_SHORTCUT_QUINARY", { action = "editFilters" })
    local ok, err = pcall(TH.BrowseFilters.ShowFilterDialog)
    if not ok and BETTERUI.Log then
        BETTERUI.Log.Error(BETTERUI.Log.CATEGORY.ACTION, "filter dialog opened", { error = err })
    end
    return ok
end

local function ChangeTradingHouseGuild(thInstance)
    if not (GetNumTradingHouseGuilds and GetNumTradingHouseGuilds() > 1) then
        return false
    end
    TraceTHKeybind(thInstance, "activated", "UI_SHORTCUT_TERTIARY", { action = "changeGuild" })
    if ZO_Dialogs_ShowPlatformDialog then
        ZO_Dialogs_ShowPlatformDialog("TRADING_HOUSE_CHANGE_ACTIVE_GUILD")
        return true
    end
    return false
end

local function SwitchTradingHouseMode(thInstance, bindingIndex, keybind)
    local leftMode, rightMode = TH.GetAlternateModeBindings(GetTHCurrentMode(thInstance))
    local target = bindingIndex == 1 and leftMode or rightMode
    if not (target and thInstance and thInstance.SetMode) then return end
    TraceTHKeybind(thInstance, "activated", keybind, {
        action = "switchMode",
        targetMode = target.mode,
        targetModeName = target.name(),
    })
    thInstance:SetMode(target.mode)
end

local function GetTHListingSortKeybindName()
    local listings = TH.ListingsComponent or {}
    local sortType = listings.currentSortType or rawget(_G, "TRADING_HOUSE_LISTING_SORT_TYPE_TIME") or 1
    local sortTypeText = "Time"
    if GetString then
        local ok, value = pcall(GetString, "SI_TRADINGHOUSELISTINGSORTTYPE", sortType)
        if ok and value and value ~= "" then sortTypeText = value end
    end

    local sortIconPath = listings.currentSortOrder == rawget(_G, "ZO_SORT_ORDER_UP")
        and rawget(_G, "ZO_ICON_SORT_ARROW_UP") or rawget(_G, "ZO_ICON_SORT_ARROW_DOWN")
    local sortIconText = (zo_iconFormat and sortIconPath) and zo_iconFormat(sortIconPath, 16, 16) or ""
    local fallback = "Change Sort (" .. sortTypeText .. sortIconText .. ")"
    return FormatTHRuntimeString("SI_GAMEPAD_TRADING_HOUSE_SORT_TIME_PRICE_TOGGLE", fallback, sortTypeText, sortIconText)
end

---@param instance BETTERUI.TradingHouse.Class
---@return nil
function TH.RegisterComponents(instance)
    if TH.BrowseComponent then
        instance:RegisterComponent(MODE.BROWSE, TH.BrowseComponent)
    end
    if TH.SellComponent then
        instance:RegisterComponent(MODE.SELL, TH.SellComponent)
    end
    if TH.ListingsComponent then
        instance:RegisterComponent(MODE.LISTINGS, TH.ListingsComponent)
    end
end

local function LayoutTradingHouseSelectionTooltip(ds)
    if not GAMEPAD_TOOLTIPS then
        return
    end
    if ds and ds.bagId and ds.slotIndex then
        GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, ds.bagId, ds.slotIndex)
    elseif ds and type(ds.itemLink) == "string" and ds.itemLink ~= ""
        and type(GAMEPAD_TOOLTIPS.LayoutItem) == "function" then
        GAMEPAD_TOOLTIPS:LayoutItem(GAMEPAD_LEFT_TOOLTIP, ds.itemLink)
    else
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
    end
    GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
end

---@param instance BETTERUI.TradingHouse.Class
---@return nil
function TH.SetupSelectionTooltip(instance)
    if instance.list and instance.list.SetOnSelectedDataChangedCallback then
        ---@param _ unknown
        ---@param selectedData TradingHouseSelectionPayload|nil
        instance.list:SetOnSelectedDataChangedCallback(function(_, selectedData)
            local ds = selectedData and (selectedData.dataSource or selectedData) or nil
            if selectedData then
                QueueTradingHouseNarration()
            end
            TraceTHRuntime("trading_house.selection", "changed", {
                fn = "TH.SetupSelectionTooltip",
                mode = instance.GetCurrentMode and instance:GetCurrentMode() or nil,
                bagId = ds and ds.bagId or nil,
                slotIndex = ds and ds.slotIndex or nil,
                itemLink = ds and ds.itemLink or nil,
                listingIndex = ds and (ds.index or ds.listingIndex) or nil,
                hasTooltips = GAMEPAD_TOOLTIPS ~= nil,
            })
            LayoutTradingHouseSelectionTooltip(ds)
        end)
    end
end

local function AddSceneFragmentIfMissing(scene, fragment)
    if not (scene and fragment) then
        return
    end
    if scene.HasFragment and scene:HasFragment(fragment) then
        TraceTHRuntime("trading_house.scene_fragment", "skipped", {
            fn = "AddSceneFragmentIfMissing",
            reason = "alreadyPresent",
            fragment = tostring(fragment),
        })
        return
    end
    scene:AddFragment(fragment)
end

---@param instance BETTERUI.TradingHouse.Class
---@return table scene
function TH.CreateScene(instance)
    instance.fragment = ZO_SimpleSceneFragment:New(instance.control)
    instance.fragment:SetHideOnSceneHidden(true)

    local thFooterDummy = BETTERUI.WindowManager:CreateControl(
        "BETTERUI_THFooterDummy", GuiRoot, CT_CONTROL)
    thFooterDummy:SetHidden(true)
    instance.footerFragment = ZO_SimpleSceneFragment:New(thFooterDummy)
    instance.footerFragment:SetHideOnSceneHidden(true)

    local scene = ZO_InteractScene:New(BETTERUI_TRADING_HOUSE_SCENE_NAME, SCENE_MANAGER, TH.TH_INTERACTION)
    instance.scene = scene

    scene:AddFragmentGroup(FRAGMENT_GROUP.GAMEPAD_DRIVEN_UI_WINDOW)
    scene:AddFragmentGroup(FRAGMENT_GROUP.FRAME_TARGET_GAMEPAD)
    AddSceneFragmentIfMissing(scene, instance.fragment)
    AddSceneFragmentIfMissing(scene, FRAME_EMOTE_FRAGMENT_INVENTORY)
    AddSceneFragmentIfMissing(scene, GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT)
    AddSceneFragmentIfMissing(scene, MINIMIZE_CHAT_FRAGMENT)
    AddSceneFragmentIfMissing(scene, GAMEPAD_MENU_SOUND_FRAGMENT)
    AddSceneFragmentIfMissing(scene, instance.footerFragment)
    return scene
end

---@param instance BETTERUI.TradingHouse.Class
---@return nil
function TH.RegisterSceneLifecycle(instance)
    ---@type TradingHouseSceneLifecyclePayload
    local lifecyclePayload = {
        -- The carousel owns its ethereal LB/RB group, just like Inventory.
        -- Registering a second Trading House shoulder group caused duplicate
        -- mode/category moves and stale input ownership after scene exit.
        keybinds = { instance.coreKeybinds },
        taskManager = TH.Tasks,
        onShowing = function(screen)
            if screen.ResetListSearch then screen:ResetListSearch() end
            BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.WIDTH)
            screen:RefreshTHFooter()
            screen:RefreshList()
            screen:UpdateTabHeader()
            local headerContainer = screen.header
            local header = headerContainer and (headerContainer.header
                or (headerContainer.GetNamedChild and headerContainer:GetNamedChild("Header")))
            if header and header.tabBar and header.tabBar.Activate then
                header.tabBar:Activate()
                local selectedIndex = header.tabBar.targetSelectedIndex
                    or header.tabBar.selectedIndex or 1
                if header.tabBar.SetSelectedIndexWithoutAnimation then
                    header.tabBar:SetSelectedIndexWithoutAnimation(selectedIndex, true, true)
                end
            end
            if screen.list and screen.list.Activate then
                screen.list:Activate()
            end
            if screen.list then
                local selectedData = screen.list:GetTargetData()
                local ds = selectedData and (selectedData.dataSource or selectedData) or nil
                LayoutTradingHouseSelectionTooltip(ds)
            end
        end,
        onHiding = function(screen)
            if screen.ResetListSearch then screen:ResetListSearch() end
            BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.ZO_WIDTH)
            local headerContainer = screen.header
            local header = headerContainer and (headerContainer.header
                or (headerContainer.GetNamedChild and headerContainer:GetNamedChild("Header")))
            if header and header.tabBar and header.tabBar.Deactivate then
                header.tabBar:Deactivate()
            end
            if screen.list and screen.list.Deactivate then
                screen.list:Deactivate()
            end
            local cleanup = BETTERUI.CIM.SceneCleanup
            if cleanup then
                cleanup.CleanupInputState(screen)
                cleanup.DeactivateLists(screen)
                cleanup.ClearSearchState(screen)
            end
        end,
        onHidden = function(screen)
            local headerContainer = screen.header
            local header = headerContainer and (headerContainer.header
                or (headerContainer.GetNamedChild and headerContainer:GetNamedChild("Header")))
            if header and header.tabBar and header.tabBar.Deactivate then
                header.tabBar:Deactivate()
            end
            if screen.list and screen.list.Deactivate then
                screen.list:Deactivate()
            end
            local component = screen:GetActiveComponent()
            if component and component.Deactivate then
                component:Deactivate(screen)
            end
            local cleanup = BETTERUI.CIM.SceneCleanup
            if cleanup then
                cleanup.CleanupInputState(screen)
                cleanup.DeactivateLists(screen)
                cleanup.ClearSearchState(screen)
            end
        end,
    }
    BETTERUI.CIM.SceneLifecycle.Register(instance, lifecyclePayload)
end

---@param thInstance BETTERUI.TradingHouse.Class
---@return TradingHouseKeybindGroup keybindGroup
function TH.BuildCoreKeybinds(thInstance)
    return WrapTradingHouseKeybindGroup({
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = function()
                if IsTHBrowseResultsSection(thInstance) then
                    return GetTHBuyItemKeybindName(thInstance, false)
                end
                local component = thInstance:GetActiveComponent()
                if component and component.GetPrimaryActionName then
                    return component:GetPrimaryActionName(thInstance)
                end
                return GetTHRuntimeString("SI_GAMEPAD_SELECT_OPTION", nil, "Select")
            end,
            narrationOverrideName = function()
                if IsTHBrowseResultsSection(thInstance) then
                    return GetTHBuyItemKeybindName(thInstance, true)
                end
                return nil
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            visible = function()
                if IsTHBrowseResultsSection(thInstance) then
                    return GetTHListTargetData(thInstance) ~= nil
                end
                if GetTHCurrentMode(thInstance) == MODE.LISTINGS then
                    return false
                end
                if GetTHCurrentMode(thInstance) == MODE.BROWSE then
                    return GetTHListTargetData(thInstance) ~= nil
                end
                local component = thInstance:GetActiveComponent()
                return component and component.OnPrimaryAction ~= nil
            end,
            callback = function()
                local component = thInstance:GetActiveComponent()
                if component and component.OnPrimaryAction then
                    TraceTHKeybind(thInstance, "activated", "UI_SHORTCUT_PRIMARY", { action = IsTHBrowseResultsSection(thInstance) and "buyItem" or "primary" })
                    component:OnPrimaryAction(thInstance)
                else
                    TraceTHKeybind(thInstance, "skipped", "UI_SHORTCUT_PRIMARY", { reason = "missingPrimaryHandler" })
                end
            end,
            enabled = function()
                local component = thInstance:GetActiveComponent()
                if component and component.IsPrimaryActionEnabled then
                    return component:IsPrimaryActionEnabled(thInstance)
                end
                return GetTHListTargetData(thInstance) ~= nil
            end,
        },
        {
            name = function()
                if GetTHCurrentMode(thInstance) == MODE.LISTINGS then
                    return GetTHRuntimeString("SI_GAMEPAD_TRADING_HOUSE_LISTING_REMOVE", nil, "Remove Listing")
                elseif IsTHBrowseFiltersSection(thInstance) then
                    return GetTHRuntimeString("SI_GAMEPAD_TRADE_SUBMIT", "SI_BETTERUI_TH_SEARCH", "Submit")
                end
                return ""
            end,
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = function()
                return IsTHBrowseFiltersSection(thInstance)
                    or (GetTHCurrentMode(thInstance) == MODE.LISTINGS and GetTHListTargetData(thInstance) ~= nil)
            end,
            enabled = function()
                if GetTHCurrentMode(thInstance) == MODE.LISTINGS then
                    return TH.ListingsComponent and TH.ListingsComponent:IsPrimaryActionEnabled(thInstance)
                end
                return CanTHSubmitBrowseSearch()
            end,
            callback = function()
                if GetTHCurrentMode(thInstance) == MODE.LISTINGS and TH.ListingsComponent then
                    TH.ListingsComponent:OnPrimaryAction(thInstance)
                elseif TH.BrowseComponent and type(TH.BrowseComponent.ExecuteSearch) == "function" then
                    TraceTHKeybind(thInstance, "activated", "UI_SHORTCUT_SECONDARY", { action = "submitSearch" })
                    TH.BrowseComponent:ExecuteSearch()
                else
                    TraceTHKeybind(thInstance, "skipped", "UI_SHORTCUT_SECONDARY", { reason = "missingSubmitHandler" })
                end
            end,
        },
        {
            name = function()
                return GetTHRuntimeString("SI_TRADING_HOUSE_GUILD_HEADER", nil, "Guild")
            end,
            keybind = "UI_SHORTCUT_TERTIARY",
            visible = function()
                return GetNumTradingHouseGuilds and GetNumTradingHouseGuilds() > 1
            end,
            callback = function()
                ChangeTradingHouseGuild(thInstance)
            end,
        },
        {
            name = function()
                if GetTHCurrentMode(thInstance) == MODE.LISTINGS then
                    return GetTHListingSortKeybindName()
                end
                return GetTHRuntimeString("SI_BETTERUI_TH_FILTER_KEYBIND", nil, "Edit Filters")
            end,
            keybind = "UI_SHORTCUT_QUINARY",
            visible = function()
                if CanOpenTHBrowseFilters(thInstance) then
                    return true
                end
                return GetTHCurrentMode(thInstance) == MODE.LISTINGS
                    and TH.ListingsComponent ~= nil
                    and type(TH.ListingsComponent.CycleSortType) == "function"
            end,
            callback = function()
                if GetTHCurrentMode(thInstance) == MODE.LISTINGS then
                    TraceTHKeybind(thInstance, "activated", "UI_SHORTCUT_QUINARY", {
                        action = "changeListingSort",
                    })
                    TH.ListingsComponent:CycleSortType(thInstance)
                    return
                end
                OpenTHBrowseFilters(thInstance)
            end,
        },
        {
            name = function()
                local leftMode = TH.GetAlternateModeBindings(GetTHCurrentMode(thInstance))
                return leftMode and leftMode.name() or ""
            end,
            keybind = "UI_SHORTCUT_LEFT_STICK",
            visible = function()
                return GetTHCurrentMode(thInstance) ~= MODE.BROWSE
            end,
            callback = function()
                SwitchTradingHouseMode(thInstance, 1, "UI_SHORTCUT_LEFT_STICK")
            end,
        },
        {
            name = function()
                local _, rightMode = TH.GetAlternateModeBindings(GetTHCurrentMode(thInstance))
                return rightMode and rightMode.name() or ""
            end,
            keybind = "UI_SHORTCUT_RIGHT_STICK",
            callback = function()
                SwitchTradingHouseMode(thInstance, 2, "UI_SHORTCUT_RIGHT_STICK")
            end,
        },
        CreateTHClearSearchKeybind(thInstance),
        {
            name = GetTHRuntimeString("SI_GAMEPAD_BACK_OPTION", nil, "Back"),
            keybind = "UI_SHORTCUT_NEGATIVE",
            callback = function()
                TraceTHKeybind(thInstance, "activated", "UI_SHORTCUT_NEGATIVE", { action = "back" })
                SCENE_MANAGER:HideCurrentScene()
            end,
        },
        {
            name = function()
                return GetTHRuntimeString("SI_TRADING_HOUSE_RESULTS_NEXT_PAGE", "SI_BETTERUI_TH_NEXT_PAGE", "Next")
            end,
            keybind = "UI_SHORTCUT_RIGHT_TRIGGER",
            visible = function()
                return IsTHBrowseResultsSection(thInstance)
                    and TH.BrowseComponent
                    and TH.BrowseComponent.hasMorePages == true
            end,
            enabled = function()
                return TH.BrowseComponent and TH.BrowseComponent.hasMorePages == true
            end,
            callback = function()
                if TH.BrowseComponent then
                    TraceTHKeybind(thInstance, "activated", "UI_SHORTCUT_QUATERNARY", { action = "nextPage" })
                    TH.BrowseComponent:NextPage(thInstance)
                end
            end,
        },
        {
            name = function()
                return GetTHRuntimeString("SI_TRADING_HOUSE_RESULTS_PREVIOUS_PAGE", "SI_BETTERUI_TH_PREV_PAGE", "Previous")
            end,
            keybind = "UI_SHORTCUT_LEFT_TRIGGER",
            visible = function()
                return IsTHBrowseResultsSection(thInstance)
                    and TH.BrowseComponent
                    and (TH.BrowseComponent.currentPage or 0) > 0
            end,
            enabled = function()
                return TH.BrowseComponent and (TH.BrowseComponent.currentPage or 0) > 0
            end,
            callback = function()
                if TH.BrowseComponent then
                    TraceTHKeybind(thInstance, "activated", "UI_SHORTCUT_QUINARY", { action = "previousPage" })
                    TH.BrowseComponent:PrevPage(thInstance)
                end
            end,
        },
    })
end

---@param thInstance BETTERUI.TradingHouse.Class
---@return TradingHouseKeybindGroup keybindGroup
function TH.BuildTabKeybinds(thInstance)
    return WrapTradingHouseKeybindGroup({
        alignment = KEYBIND_STRIP_ALIGN_LEFT,
        {
            name = nil,
            keybind = "UI_SHORTCUT_LEFT_SHOULDER",
            ethereal = true,
            callback = function()
                thInstance:CycleTabs(-1)
            end,
            enabled = function()
                return (thInstance._tradingHouseHeaderEntryCount or 0) > 1
            end,
        },
        {
            name = nil,
            keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
            ethereal = true,
            callback = function()
                thInstance:CycleTabs(1)
            end,
            enabled = function()
                return (thInstance._tradingHouseHeaderEntryCount or 0) > 1
            end,
        },
    })
end

function BETTERUI.TradingHouse.Class:CycleGuild(direction)
    local numGuilds = GetNumTradingHouseGuilds and GetNumTradingHouseGuilds() or 0
    if numGuilds <= 1 then
        return
    end

    local currentGuildId = GetSelectedTradingHouseGuildId and GetSelectedTradingHouseGuildId() or nil
    local currentIndex = 1
    for i = 1, numGuilds do
        local guildId = GetTradingHouseGuildDetails and select(1, GetTradingHouseGuildDetails(i)) or nil
        if guildId == currentGuildId then
            currentIndex = i
            break
        end
    end

    local newIndex = ((currentIndex - 1 + direction) % numGuilds) + 1
    local newGuildId = GetTradingHouseGuildDetails and select(1, GetTradingHouseGuildDetails(newIndex)) or nil
    if newGuildId and SelectTradingHouseGuildId then
        SelectTradingHouseGuildId(newGuildId)
        -- SelectTradingHouseGuildId returns nothing; confirm the switch took
        -- effect via the selected-guild getter. The actual invalidation and
        -- refresh is handled by TH.OnSelectedTradingHouseGuildChanged so that
        -- native guild switches and CycleGuild share the same path.
        if GetSelectedTradingHouseGuildId and GetSelectedTradingHouseGuildId() ~= newGuildId then
            return
        end
    end
end
