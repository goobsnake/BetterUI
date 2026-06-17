-- Trading House runtime entrypoint.

local TH = BETTERUI.TradingHouse

function BETTERUI.TradingHouse.Init()
    if TH.initialized then
        return
    end

    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.LIFECYCLE, "tradingHouseInitStart")
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
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.LIFECYCLE, "tradingHouseInitEnd")
    end
end
