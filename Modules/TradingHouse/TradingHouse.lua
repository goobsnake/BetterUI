-- Trading House runtime entrypoint.

local TH = BETTERUI.TradingHouse

local function GetTradingHouseSnapshotModeName(mode)
    for name, value in pairs(TH.MODE or {}) do
        if value == mode then return name end
    end
    return tostring(mode or "<none>")
end

local function CountTradingHouseSnapshotRows(list)
    if not list then return 0 end
    if list.GetNumItems then
        local ok, count = pcall(function() return list:GetNumItems() end)
        if ok and type(count) == "number" then return count end
    end
    return type(list.dataList) == "table" and #list.dataList or 0
end

local function GetTradingHouseSnapshotSelectedIndex(list)
    if not list then return 0 end
    if type(list.selectedIndex) == "number" then return list.selectedIndex end
    if list.GetSelectedIndex then
        local ok, index = pcall(function() return list:GetSelectedIndex() end)
        if ok and type(index) == "number" then return index end
    end
    return 0
end

local function GetTradingHouseSnapshotSelectionToken(list)
    if not list then return "nil" end
    local selectedOk, selected = pcall(function()
        if list.GetTargetData then
            return list:GetTargetData()
        elseif list.GetSelectedData then
            return list:GetSelectedData()
        end
        return list.selectedData
    end)
    if not selectedOk then return "error" end
    local data = selected and (selected.dataSource or selected) or nil
    return data and string.format("listing=%s,bag=%s,slot=%s,entry=%s", tostring(data.listingIndex or data.uniqueId or data.itemUniqueId or "nil"), tostring(data.bagId or "nil"), tostring(data.slotIndex or "nil"), tostring(data.entryIndex or "nil")) or "nil"
end

local function IsTradingHouseSnapshotKeybindPresent(descriptor)
    return BETTERUI.Interface.HasKeybindGroup(descriptor) and 1 or 0
end

local function RegisterTradingHouseSnapshotProvider()
    local watch = BETTERUI.CIM and BETTERUI.CIM.WatchMode
    if not watch then return end
    if watch.RegisterViewScene then watch.RegisterViewScene("th", BETTERUI_TRADING_HOUSE_SCENE_NAME or "BETTERUI_TradingHouse") end
    if not watch.RegisterSnapshotProvider then return end
    watch.RegisterSnapshotProvider("tradingHouse", function()
        local instance = TH.instance
        if not instance then
            return string.format("init=%s window=0", tostring(TH.initialized == true))
        end
        local browse = TH.BrowseComponent
        local mode = instance.GetCurrentMode and instance:GetCurrentMode() or instance.currentMode
        local visible = instance.IsSceneShowing and instance:IsSceneShowing() or false
        return string.format(
            "init=%s window=1 visible=%s mode=%s modeName=%s rows=%s selectedIndex=%s selectedId=%s suppressed=%s dirty=%s search=%d page=%s pending=%s more=%s keybindCore=%s keybindTabs=%s",
            tostring(TH.initialized == true),
            tostring(visible),
            tostring(mode),
            tostring(GetTradingHouseSnapshotModeName(mode)),
            tostring(CountTradingHouseSnapshotRows(instance.list)),
            tostring(GetTradingHouseSnapshotSelectedIndex(instance.list)),
            tostring(GetTradingHouseSnapshotSelectionToken(instance.list)),
            instance.searchQuery and #tostring(instance.searchQuery) or 0,
            tostring(browse and browse.currentPage or nil),
            tostring(browse and browse.searchPending == true or false),
            tostring(browse and browse.hasMorePages == true or false),
            tostring(IsTradingHouseSnapshotKeybindPresent(instance.coreKeybinds)),
            tostring(IsTradingHouseSnapshotKeybindPresent(instance.tabKeybinds)))
    end)
end

RegisterTradingHouseSnapshotProvider()

function BETTERUI.TradingHouse.Init()
    if TH.initialized then
        return
    end

    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.LIFECYCLE, "trading house init started")
    end

    TH.RegisterCreateListingDialog()
    TH.instance = TH.Class:New("BETTERUI_TradingHouseWindow", BETTERUI_TRADING_HOUSE_SCENE_NAME)
    TH.instance:SetTitle("|c0066FF" ..
        GetString(rawget(_G, "SI_BETTERUI_TH_TITLE")) .. "|r")

    TH.RegisterComponents(TH.instance)
    TH.instance:SetupList(
        "BETTERUI_GamepadItemSubEntryTemplate",
        BETTERUI.TradingHouse.THEntrySetup,
        "BUI_ItemRow"
    )
    TH.SetupSelectionTooltip(TH.instance)

    local COL = BETTERUI.CIM.CONST.LAYOUT.COLUMNS
    TH.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_INV_HEADER_NAME")),  COL[1])
    TH.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_INV_HEADER_TYPE")),  COL[2])
    TH.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_INV_HEADER_TRAIT")), COL[3])
    TH.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_INV_HEADER_STAT")),  COL[4])
    TH.instance:AddColumn(GetString(rawget(_G, "SI_BETTERUI_INV_HEADER_VALUE")), COL[5])

    TH.instance.coreKeybinds = TH.BuildCoreKeybinds(TH.instance)
    TH.instance.tabKeybinds = TH.BuildTabKeybinds(TH.instance)

    TH.CreateScene(TH.instance)
    TH.CaptureNativeScene(SCENE_MANAGER)
    TH.TakeOverNativeTradingHouse()
    TH.RegisterSceneLifecycle(TH.instance)
    TH.AliasSceneToBetterUI()
    TH.instance:InitTHFooter()
    TH.RegisterEvents(EVENT_MANAGER)

    if BETTERUI.CIM.Narration and BETTERUI.CIM.Narration.RegisterListNarration then
        BETTERUI.CIM.Narration.RegisterListNarration(
            BETTERUI_TRADING_HOUSE_SCENE_NAME,
            function() return TH.instance and TH.instance.list and TH.instance.list:GetTargetData() end,
            function() return TH.instance and TH.instance:GetTitle() end
        )
    end

    TH.initialized = true
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.LIFECYCLE, "trading house init ended")
    end
end
