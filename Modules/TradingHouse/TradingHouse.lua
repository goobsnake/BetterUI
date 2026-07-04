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
    return BETTERUI.WatchMode.KeybindPresent(descriptor)
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

local TH_HEADER_ICONS = {
    BROWSE = "EsoUI/Art/MenuBar/Gamepad/gp_PlayerMenu_icon_store.dds",
    SELL = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_inventory.dds",
    LISTINGS = "EsoUI/Art/MenuBar/Gamepad/gp_playerMenu_icon_guilds.dds",
}

-- Results paging leaves the footer but must stay bindable: LB/RB now cycle
-- the section tabs, so page prev/next moves to the triggers, hidden from the
-- strip (ethereal) to keep the footer decluttered.
local TH_PAGE_FOOTER_KEYBIND_RETARGETS = {
    UI_SHORTCUT_QUATERNARY = "UI_SHORTCUT_RIGHT_TRIGGER",
    UI_SHORTCUT_QUINARY = "UI_SHORTCUT_LEFT_TRIGGER",
}

local TH_HEADER_SHOULDER_KEYBINDS = {
    UI_SHORTCUT_LEFT_SHOULDER = true,
    UI_SHORTCUT_RIGHT_SHOULDER = true,
}

local TH_HEADER_TAB_TEMPLATE = "ZO_GamepadTabBarTemplate"

local function GetTHCarouselConst(key)
    local carousel = BETTERUI.CIM and BETTERUI.CIM.CONST and BETTERUI.CIM.CONST.CAROUSEL or nil
    return carousel and carousel[key] or nil
end

local function GetTHString(primaryIdName, fallbackIdName, fallback)
    local id = rawget(_G, primaryIdName)
    if id ~= nil and GetString then
        local ok, value = pcall(GetString, id)
        if ok and value and value ~= "" then return value end
    end

    id = fallbackIdName and rawget(_G, fallbackIdName) or nil
    if id ~= nil and GetString then
        local ok, value = pcall(GetString, id)
        if ok and value and value ~= "" then return value end
    end

    return fallback
end

local function GetTHHeaderTabs()
    local mode = TH.MODE or {}
    local tabs = {}
    if mode.BROWSE then
        tabs[#tabs + 1] = {
            mode = mode.BROWSE,
            icon = TH_HEADER_ICONS.BROWSE,
            name = function() return GetTHString("SI_BETTERUI_TH_TAB_BROWSE", "SI_TRADING_HOUSE_MODE_BROWSE", "Browse") end,
        }
    end
    if mode.SELL then
        tabs[#tabs + 1] = {
            mode = mode.SELL,
            icon = TH_HEADER_ICONS.SELL,
            name = function() return GetTHString("SI_BETTERUI_TH_TAB_SELL", "SI_TRADING_HOUSE_MODE_SELL", "Sell") end,
        }
    end
    if mode.LISTINGS then
        tabs[#tabs + 1] = {
            mode = mode.LISTINGS,
            icon = TH_HEADER_ICONS.LISTINGS,
            name = function() return GetTHString("SI_BETTERUI_TH_TAB_LISTINGS", "SI_TRADING_HOUSE_MODE_LISTINGS", "Listings") end,
        }
    end
    return tabs
end

local function GetTHHeaderGeneric(instance)
    if not instance then return nil end
    if instance.headerGeneric then return instance.headerGeneric end

    local header = instance.header
    local headerGeneric = header and (header.header or (header.GetNamedChild and header:GetNamedChild("Header"))) or nil
    if headerGeneric then
        instance.headerGeneric = headerGeneric
    end
    return headerGeneric
end

local function EnsureTHHeaderGeneric(headerGeneric)
    if not headerGeneric then return false end
    if not headerGeneric.controls
        and BETTERUI.GenericHeader
        and BETTERUI.GenericHeader.Initialize then
        BETTERUI.GenericHeader.Initialize(headerGeneric, rawget(_G, "ZO_GAMEPAD_HEADER_TABBAR_CREATE"))
    end
    return headerGeneric.controls ~= nil
        and BETTERUI.GenericHeader ~= nil
        and BETTERUI.GenericHeader.Refresh ~= nil
end

local function FindTHHeaderTabIndex(mode, tabs)
    for i = 1, #tabs do
        if tabs[i].mode == mode then return i end
    end
    return 1
end

local function BuildTHHeaderTitle(instance, tabs)
    local currentMode = instance and instance.GetCurrentMode and instance:GetCurrentMode() or nil
    local tab = tabs[FindTHHeaderTabIndex(currentMode, tabs)]
    local tabName = tab and tab.name and tab.name() or ""
    local guildName = instance and instance.GetCurrentGuildName and instance:GetCurrentGuildName() or nil
    if guildName and guildName ~= "" then
        return "|c0066FF" .. guildName .. "|r - " .. tabName
    end
    return tabName
end

local function EnsureTHHeaderData(instance)
    if instance.tradingHouseHeaderData then return instance.tradingHouseHeaderData end

    instance.tradingHouseHeaderData = {
        titleText = function()
            return BuildTHHeaderTitle(instance, GetTHHeaderTabs())
        end,
        tabBarData = { parent = instance },
        carouselConfig = {
            enabled = (not TH.GetSetting) or (TH.GetSetting("enableCarousel") ~= false),
            startOffset = GetTHCarouselConst("startOffset"),
            verticalOffset = GetTHCarouselConst("verticalOffset"),
            itemSpacing = GetTHCarouselConst("itemSpacing"),
        },
        onSelectedChanged = function(list, selectedData)
            if instance._suppressTradingHouseHeaderSelection then return end
            local data = selectedData or (list and list.GetTargetData and list:GetTargetData()) or nil
            data = data and (data.dataSource or data) or nil
            local mode = data and data.mode or nil
            if mode and instance.GetCurrentMode and mode ~= instance:GetCurrentMode() then
                instance:SetMode(mode)
            end
        end,
    }
    return instance.tradingHouseHeaderData
end

local function RefreshTHHeaderCarouselConfig(headerData)
    headerData.carouselConfig = headerData.carouselConfig or {}
    headerData.carouselConfig.enabled = (not TH.GetSetting) or (TH.GetSetting("enableCarousel") ~= false)
    headerData.carouselConfig.startOffset = GetTHCarouselConst("startOffset")
    headerData.carouselConfig.verticalOffset = GetTHCarouselConst("verticalOffset")
    headerData.carouselConfig.itemSpacing = GetTHCarouselConst("itemSpacing")
end

local function BuildTHHeaderTabEntries(tabs)
    local entries = {}
    for i = 1, #tabs do
        local tab = tabs[i]
        local text = tab.name()
        local entryData = ZO_GamepadEntryData and ZO_GamepadEntryData:New(text, tab.icon) or { text = text, icon = tab.icon }
        entryData.mode = tab.mode
        entryData.text = text
        entryData.icon = tab.icon
        entryData.template = TH_HEADER_TAB_TEMPLATE
        entryData.canSelect = true
        if entryData.SetIconTintOnSelection then
            entryData:SetIconTintOnSelection(true)
        end
        if entryData.SetFontScaleOnSelection then
            entryData:SetFontScaleOnSelection(false)
        end
        entries[#entries + 1] = entryData
    end
    return entries
end

local function SetTHHeaderTabBarHidden(headerGeneric, hidden)
    local tabBarControl = headerGeneric and headerGeneric.GetNamedChild and headerGeneric:GetNamedChild("TabBar") or nil
    if tabBarControl and tabBarControl.SetHidden then
        tabBarControl:SetHidden(hidden == true)
    end
end

local function ScrubTHPageFooterKeybinds(group)
    if type(group) ~= "table" then return end
    for i = #group, 1, -1 do
        local descriptor = group[i]
        local retarget = type(descriptor) == "table" and TH_PAGE_FOOTER_KEYBIND_RETARGETS[descriptor.keybind]
        if retarget then
            descriptor.keybind = retarget
            descriptor.ethereal = true
        end
    end
end

local function HideTHTabFooterKeybinds(group)
    if type(group) ~= "table" then return end
    for i = 1, #group do
        local descriptor = group[i]
        if type(descriptor) == "table" and TH_HEADER_SHOULDER_KEYBINDS[descriptor.keybind] then
            descriptor.name = nil
            descriptor.ethereal = true
        end
    end
end

function BETTERUI.TradingHouse.Class:UpdateTabHeader()
    local tabs = GetTHHeaderTabs()
    if #tabs == 0 then return end

    self._tradingHouseHeaderEntryCount = #tabs
    local selectedIndex = FindTHHeaderTabIndex(self:GetCurrentMode(), tabs)
    local title = BuildTHHeaderTitle(self, tabs)
    if self.SetTitle then
        self:SetTitle(title)
    end

    local headerGeneric = GetTHHeaderGeneric(self)
    if not EnsureTHHeaderGeneric(headerGeneric) then return end
    local headerData = EnsureTHHeaderData(self)
    RefreshTHHeaderCarouselConfig(headerData)
    headerData.tabBarEntries = BuildTHHeaderTabEntries(tabs)

    self._suppressTradingHouseHeaderSelection = true
    BETTERUI.GenericHeader.Refresh(headerGeneric, headerData, true)
    SetTHHeaderTabBarHidden(headerGeneric, false)

    if headerGeneric.tabBar then
        if headerGeneric.tabBar.SetSelectedIndexWithoutAnimation then
            headerGeneric.tabBar:SetSelectedIndexWithoutAnimation(selectedIndex, true, true)
        elseif headerGeneric.tabBar.SetSelectedIndex then
            headerGeneric.tabBar:SetSelectedIndex(selectedIndex, true, true)
        end
    end
    self._suppressTradingHouseHeaderSelection = false
end

function BETTERUI.TradingHouse.Class:CycleModeTabs(direction)
    local tabs = GetTHHeaderTabs()
    if #tabs <= 1 then return end

    local currentIndex = FindTHHeaderTabIndex(self:GetCurrentMode(), tabs)
    local newIndex
    if TH.GetSetting and TH.GetSetting("enableCarousel") == false then
        newIndex = currentIndex + direction
        if newIndex < 1 or newIndex > #tabs then return end
    else
        newIndex = ((currentIndex - 1 + direction) % #tabs) + 1
    end
    self:SetMode(tabs[newIndex].mode)
end

function BETTERUI.TradingHouse.Class:CycleTabs(direction)
    local headerGeneric = GetTHHeaderGeneric(self)
    local tabBar = headerGeneric and headerGeneric.tabBar or nil
    local headerEntryCount = self._tradingHouseHeaderEntryCount or 0
    if tabBar and headerEntryCount > 1 then
        if direction < 0 then
            tabBar:MovePrevious(true)
        else
            tabBar:MoveNext(true)
        end
        return
    end

    self:CycleModeTabs(direction)
end

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
    ScrubTHPageFooterKeybinds(TH.instance.coreKeybinds)
    HideTHTabFooterKeybinds(TH.instance.tabKeybinds)
    TH.instance:UpdateTabHeader()

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
