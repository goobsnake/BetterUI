--[[
File: Modules/TradingHouse/TradingHouse.lua
Purpose: Trading House runtime entrypoint focused on module lifecycle wiring and
         public API. Scene ownership, keybinds, dialogs, and event routing live
         in Core/TradingHouseRuntime.lua.
]]

local TH = BETTERUI.TradingHouse

--- Initializes the Trading House module.
function BETTERUI.TradingHouse.Init()
    if TH.initialized then
        return
    end

    TH.RegisterCreateListingDialog()
    TH.instance = TH.Class:New("BETTERUI_TradingHouseWindow", BETTERUI_TRADING_HOUSE_SCENE_NAME)
    TH.instance:SetTitle("|c0066FF" ..
        GetString(rawget(_G, "SI_BETTERUI_TH_TITLE")) .. "|r")

    TH.RegisterComponents(TH.instance)
    TH.instance:SetupList(
        "BETTERUI_GamepadItemSubEntryTemplate",
        BETTERUI.TradingHouse.THEntrySetup
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
end

-- PUBLIC API

--- Check if the Trading House module has been initialized.
---@return boolean initialized True if Init() has completed
function BETTERUI.TradingHouse.IsInitialized()
    return TH.initialized == true
end

--- Check if the trading house is currently open.
---@return boolean isOpen True if the TH scene is showing
function BETTERUI.TradingHouse.IsTradingHouseOpen()
    if TH.instance and TH.instance:IsSceneShowing() then
        return true
    end
    return false
end
