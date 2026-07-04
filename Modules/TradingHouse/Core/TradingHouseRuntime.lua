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

---@alias THTabDef {mode: number, name: fun(): string}
---@alias TradingHouseSelectionPayload {dataSource: table|nil, bagId: integer|nil, slotIndex: integer|nil}
---@alias TradingHouseSceneLifecyclePayload {keybinds: table[], taskManager: table|nil, onShowing: fun(screen: BETTERUI.TradingHouse.Class), onHiding: fun(screen: BETTERUI.TradingHouse.Class), onHidden: fun(screen: BETTERUI.TradingHouse.Class)}
---@alias TradingHouseKeybindGroup table

---@type THTabDef[]
local TH_TABS = {
    { mode = MODE.BROWSE,   name = function() return GetTHRuntimeString("SI_BETTERUI_TH_TAB_BROWSE", "SI_TRADING_HOUSE_MODE_BROWSE", "Browse") end },
    { mode = MODE.SELL,     name = function() return GetTHRuntimeString("SI_BETTERUI_TH_TAB_SELL", "SI_TRADING_HOUSE_MODE_SELL", "Sell") end },
    { mode = MODE.LISTINGS, name = function() return GetTHRuntimeString("SI_BETTERUI_TH_TAB_LISTINGS", "SI_TRADING_HOUSE_MODE_LISTINGS", "Listings") end },
}

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

local function SearchForSelectedTHItem(thInstance)
    local data = GetTHListTargetData(thInstance)
    local itemLink = data and data.itemLink or nil
    if not itemLink or itemLink == "" then
        TraceTHKeybind(thInstance, "skipped", "UI_SHORTCUT_SECONDARY", { reason = "missingItemLink" })
        return
    end

    if TH.BrowseComponent and type(TH.BrowseComponent.SearchForItemLink) == "function" then
        TH.BrowseComponent:SearchForItemLink(itemLink)
    elseif type(TH.SearchForItemLink) == "function" then
        TH.SearchForItemLink(itemLink)
    elseif type(thInstance.SearchForItemLink) == "function" then
        thInstance:SearchForItemLink(itemLink)
    elseif TRADING_HOUSE_GAMEPAD and type(TRADING_HOUSE_GAMEPAD.SearchForItemLink) == "function" then
        TRADING_HOUSE_GAMEPAD:SearchForItemLink(itemLink)
    else
        TraceTHKeybind(thInstance, "skipped", "UI_SHORTCUT_SECONDARY", { reason = "missingSearchForItemHandler" })
        return
    end
    TraceTHKeybind(thInstance, "activated", "UI_SHORTCUT_SECONDARY", { action = "searchForItem" })
end

local function CanTHResetBrowseSearch()
    local browse = TH.BrowseComponent or {}
    local filters = TH.BrowseFilters or {}
    return type(browse.ResetSearch) == "function"
        or type(browse.ResetFilterValuesToDefaults) == "function"
        or type(filters.ResetSearch) == "function"
        or type(filters.ResetFilterValuesToDefaults) == "function"
end

local function ResetTHBrowseSearch(thInstance)
    if TH.BrowseComponent and type(TH.BrowseComponent.ResetSearch) == "function" then
        TH.BrowseComponent:ResetSearch(thInstance)
    elseif TH.BrowseComponent and type(TH.BrowseComponent.ResetFilterValuesToDefaults) == "function" then
        TH.BrowseComponent:ResetFilterValuesToDefaults(thInstance)
    elseif TH.BrowseFilters and type(TH.BrowseFilters.ResetSearch) == "function" then
        TH.BrowseFilters.ResetSearch(thInstance)
    elseif TH.BrowseFilters and type(TH.BrowseFilters.ResetFilterValuesToDefaults) == "function" then
        TH.BrowseFilters.ResetFilterValuesToDefaults(thInstance)
    else
        TraceTHKeybind(thInstance, "skipped", "UI_SHORTCUT_RIGHT_STICK", { reason = "missingResetHandler" })
        return
    end
    TraceTHKeybind(thInstance, "activated", "UI_SHORTCUT_RIGHT_STICK", { action = "resetSearch" })
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

---@param instance BETTERUI.TradingHouse.Class
---@return nil
function TH.SetupSelectionTooltip(instance)
    if instance.list and instance.list.SetOnSelectedDataChangedCallback then
        ---@param _ unknown
        ---@param selectedData TradingHouseSelectionPayload|nil
        instance.list:SetOnSelectedDataChangedCallback(function(_, selectedData)
            local ds = selectedData and (selectedData.dataSource or selectedData) or nil
            TraceTHRuntime("trading_house.selection", "changed", {
                fn = "TH.SetupSelectionTooltip",
                mode = instance.GetCurrentMode and instance:GetCurrentMode() or nil,
                bagId = ds and ds.bagId or nil,
                slotIndex = ds and ds.slotIndex or nil,
                itemLink = ds and ds.itemLink or nil,
                listingIndex = ds and (ds.index or ds.listingIndex) or nil,
                hasTooltips = GAMEPAD_TOOLTIPS ~= nil,
            })
            if not GAMEPAD_TOOLTIPS then
                return
            end
            if ds and ds.bagId and ds.slotIndex then
                GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, ds.bagId, ds.slotIndex)
            else
                GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
            end
            GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
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
        keybinds = { instance.coreKeybinds, instance.tabKeybinds },
        taskManager = TH.Tasks,
        onShowing = function(screen)
            BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.WIDTH)
            screen:RefreshTHFooter()
            screen:RefreshList()
            screen:UpdateTabHeader()
            if screen.list and GAMEPAD_TOOLTIPS then
                local selectedData = screen.list:GetTargetData()
                local ds = selectedData and (selectedData.dataSource or selectedData) or nil
                if ds and ds.bagId and ds.slotIndex then
                    GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, ds.bagId, ds.slotIndex)
                else
                    GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
                end
                GAMEPAD_TOOLTIPS:ClearTooltip(GAMEPAD_RIGHT_TOOLTIP)
            end
        end,
        onHiding = function(screen)
            BETTERUI.CIM.SetTooltipWidth(BETTERUI.CIM.CONST.LAYOUT.PANEL.ZO_WIDTH)
        end,
        onHidden = function(screen)
            local component = screen:GetActiveComponent()
            if component and component.Deactivate then
                component:Deactivate(screen)
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
                if IsTHBrowseResultsSection(thInstance) then
                    return GetTHRuntimeString("SI_TRADING_HOUSE_SEARCH_FROM_ITEM", nil, "Search For Item")
                elseif IsTHBrowseFiltersSection(thInstance) then
                    return GetTHRuntimeString("SI_GAMEPAD_TRADE_SUBMIT", "SI_BETTERUI_TH_SEARCH", "Submit")
                end
                return ""
            end,
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = function()
                return IsTHBrowseFiltersSection(thInstance)
                    or (IsTHBrowseResultsSection(thInstance) and (GetTHListTargetData(thInstance) or {}).itemLink ~= nil)
            end,
            enabled = function()
                if IsTHBrowseResultsSection(thInstance) then
                    return (GetTHListTargetData(thInstance) or {}).itemLink ~= nil
                end
                return CanTHSubmitBrowseSearch()
            end,
            callback = function()
                if IsTHBrowseResultsSection(thInstance) then
                    SearchForSelectedTHItem(thInstance)
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
                if IsTHBrowseFiltersSection(thInstance) then
                    return GetTHRuntimeString("SI_BETTERUI_TH_PRESETS", nil, "Presets")
                end
                return ""
            end,
            keybind = "UI_SHORTCUT_TERTIARY",
            visible = function()
                return IsTHBrowseFiltersSection(thInstance)
                    and TH.SearchPresets ~= nil
                    and type(TH.SearchPresets.ShowLoadDialog) == "function"
            end,
            callback = function()
                TraceTHKeybind(thInstance, "activated", "UI_SHORTCUT_TERTIARY", { action = "loadPreset" })
                TH.SearchPresets.ShowLoadDialog()
            end,
        },
        {
            name = function()
                if not IsTHBrowseFiltersSection(thInstance) then return "" end
                if CanTHResetBrowseSearch() then
                    return GetTHRuntimeString("SI_TRADING_HOUSE_RESET_SEARCH", nil, "Reset Search")
                end
                return GetTHRuntimeString("SI_BETTERUI_TH_SAVE_PRESET", nil, "Save Preset")
            end,
            keybind = "UI_SHORTCUT_RIGHT_STICK",
            visible = function()
                return IsTHBrowseFiltersSection(thInstance)
                    and (CanTHResetBrowseSearch()
                        or (TH.SearchPresets ~= nil and type(TH.SearchPresets.ShowSaveDialog) == "function"))
            end,
            callback = function()
                if CanTHResetBrowseSearch() then
                    ResetTHBrowseSearch(thInstance)
                else
                    TraceTHKeybind(thInstance, "activated", "UI_SHORTCUT_RIGHT_STICK", { action = "savePreset" })
                    TH.SearchPresets.ShowSaveDialog()
                end
            end,
        },
        {
            name = function()
                local id = rawget(_G, "SI_BETTERUI_TH_FILTER_KEYBIND")
                if id and GetString then
                    local ok, value = pcall(GetString, id)
                    if ok and value and value ~= "" then return value end
                end
                return "Edit Filters"
            end,
            keybind = rawget(_G, "UI_SHORTCUT_LEFT_STICK") or "UI_SHORTCUT_LEFT_STICK",
            visible = function()
                return IsTHBrowseFiltersSection(thInstance)
                    and TH.BrowseFilters ~= nil
                    and type(TH.BrowseFilters.ShowFilterDialog) == "function"
            end,
            callback = function()
                TraceTHKeybind(thInstance, "activated", rawget(_G, "UI_SHORTCUT_LEFT_STICK") or "UI_SHORTCUT_LEFT_STICK", { action = "editFilters" })
                local ok, err = pcall(TH.BrowseFilters.ShowFilterDialog)
                if not ok and BETTERUI.Log then
                    BETTERUI.Log.Error(BETTERUI.Log.CATEGORY.ACTION, "filter dialog opened", { error = err })
                end
            end,
        },
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
                return GetTHRuntimeString("SI_BETTERUI_TH_GUILD_PREV", nil, "Previous Guild")
            end,
            keybind = "UI_SHORTCUT_LEFT_TRIGGER",
            ethereal = true,
            visible = function()
                return GetNumTradingHouseGuilds and GetNumTradingHouseGuilds() > 1
            end,
            callback = function()
                TraceTHKeybind(thInstance, "activated", "UI_SHORTCUT_LEFT_TRIGGER", { action = "previousGuild" })
                thInstance:CycleGuild(-1)
            end,
        },
        {
            name = function()
                return GetTHRuntimeString("SI_BETTERUI_TH_GUILD_NEXT", nil, "Next Guild")
            end,
            keybind = "UI_SHORTCUT_RIGHT_TRIGGER",
            ethereal = true,
            visible = function()
                return GetNumTradingHouseGuilds and GetNumTradingHouseGuilds() > 1
            end,
            callback = function()
                TraceTHKeybind(thInstance, "activated", "UI_SHORTCUT_RIGHT_TRIGGER", { action = "nextGuild" })
                thInstance:CycleGuild(1)
            end,
        },
        {
            name = GetTHListingSortKeybindName,
            keybind = "UI_SHORTCUT_RIGHT_STICK",
            visible = function()
                return GetTHCurrentMode(thInstance) == MODE.LISTINGS
                    and TH.ListingsComponent ~= nil
                    and type(TH.ListingsComponent.CycleSortType) == "function"
            end,
            callback = function()
                TraceTHKeybind(thInstance, "activated", "UI_SHORTCUT_RIGHT_STICK", { action = "changeListingSort" })
                TH.ListingsComponent:CycleSortType(thInstance)
            end,
        },
        {
            name = function()
                return GetTHRuntimeString("SI_TRADING_HOUSE_RESULTS_NEXT_PAGE", "SI_BETTERUI_TH_NEXT_PAGE", "Next")
            end,
            keybind = "UI_SHORTCUT_QUATERNARY",
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
            keybind = "UI_SHORTCUT_QUINARY",
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
            name = GetTHRuntimeString("SI_GAMEPAD_PAGED_LIST_PAGE_LEFT_NARRATION", nil, "Previous"),
            keybind = "UI_SHORTCUT_LEFT_SHOULDER",
            callback = function()
                thInstance:CycleTabs(-1)
            end,
            enabled = function()
                return #TH_TABS > 1
            end,
        },
        {
            name = GetTHRuntimeString("SI_GAMEPAD_PAGED_LIST_PAGE_RIGHT_NARRATION", nil, "Next"),
            keybind = "UI_SHORTCUT_RIGHT_SHOULDER",
            callback = function()
                thInstance:CycleTabs(1)
            end,
            enabled = function()
                return #TH_TABS > 1
            end,
        },
    })
end

function BETTERUI.TradingHouse.Class:CycleTabs(direction)
    if #TH_TABS <= 1 then
        return
    end

    local currentMode = self:GetCurrentMode()
    local currentIndex = 1
    for i, tab in ipairs(TH_TABS) do
        if tab.mode == currentMode then
            currentIndex = i
            break
        end
    end

    local newIndex
    if TH.GetSetting("enableCarousel") == false then
        newIndex = currentIndex + direction
        if newIndex < 1 or newIndex > #TH_TABS then
            return
        end
    else
        newIndex = ((currentIndex - 1 + direction) % #TH_TABS) + 1
    end
    self:SetMode(TH_TABS[newIndex].mode)
    self:UpdateTabHeader()
end

function BETTERUI.TradingHouse.Class:UpdateTabHeader()
    local currentMode = self:GetCurrentMode()

    for _, tab in ipairs(TH_TABS) do
        if tab.mode == currentMode then
            local tabName = tab.name()
            local guildName = self:GetCurrentGuildName()
            local title = "|c0066FF" .. guildName .. "|r - " .. tabName
            if self.header and self.header.SetTitle then
                self.header:SetTitle(title)
            end
            break
        end
    end
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
