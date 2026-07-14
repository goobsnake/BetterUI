--[[
File: tools/tests/test_trading_house_runtime_source.lua
Purpose: Guards the Trading House root/runtime split so TradingHouse.lua stays
         focused on lifecycle wiring while the core runtime helper owns scene
         ownership, keybinds, dialogs, and event routing.
Usage:
  lua tools/tests/test_trading_house_runtime_source.lua
]]

if false then
    dofile("Modules/TradingHouse/Core/TradingHouseRuntime.lua")
    dofile("Modules/TradingHouse/Core/TradingHouseRuntimeFlow.lua")
    dofile("Modules/TradingHouse/TradingHouse.lua")
end

local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local function assert_contains(haystack, needle, label)
    if not haystack:find(needle, 1, true) then
        error(label .. "\nMissing: " .. needle)
    end
end

local function assert_not_contains(haystack, needle, label)
    if haystack:find(needle, 1, true) then
        error(label .. "\nUnexpected: " .. needle)
    end
end

local function count_literal(haystack, needle)
    local count = 0
    local startIndex = 1
    while true do
        local foundAt = haystack:find(needle, startIndex, true)
        if not foundAt then return count end
        count = count + 1
        startIndex = foundAt + #needle
    end
end

print("test_trading_house_runtime_source")

local entrySource = read_file("Modules/TradingHouse/TradingHouse.lua")
local runtimeSource = read_file("Modules/TradingHouse/Core/TradingHouseRuntime.lua")
local flowSource = read_file("Modules/TradingHouse/Core/TradingHouseRuntimeFlow.lua")
local classSource = read_file("Modules/TradingHouse/Core/TradingHouseClass.lua")
local settingsSource = read_file("Modules/TradingHouse/Settings/SettingsPanel.lua")
local browseSource = read_file("Modules/TradingHouse/Components/BrowseComponent.lua")
local sellSource = read_file("Modules/TradingHouse/Components/SellComponent.lua")
local listingsSource = read_file("Modules/TradingHouse/Components/ListingsComponent.lua")
local priceEntrySource = read_file("Modules/TradingHouse/Core/PriceEntry.lua")
local manifestSource = read_file("BetterUI.txt")

assert_contains(runtimeSource, "function TH.RegisterSceneLifecycle(instance)",
    "Trading House runtime helper owns scene lifecycle registration")
assert_not_contains(runtimeSource, "function TH.GetTabs(",
    "Trading House runtime helper no longer exposes the dead test-only GetTabs export")
assert_contains(runtimeSource, "---@param instance BETTERUI.TradingHouse.Class",
    "Trading House runtime helper annotates exported helpers with the trading house instance type")
assert_contains(runtimeSource, "---@return nil",
    "Trading House runtime helper annotates side-effect exports with explicit nil returns")
assert_contains(runtimeSource, "function TH.BuildCoreKeybinds(thInstance)",
    "Trading House runtime helper owns core keybind construction")
assert_contains(runtimeSource, "function TH.BuildTabKeybinds(thInstance)",
    "Trading House runtime helper owns tab keybind construction")
local combinedHeaderSource = entrySource .. "\n" .. runtimeSource
if count_literal(combinedHeaderSource,
        "function BETTERUI.TradingHouse.Class:UpdateTabHeader()") ~= 1 then
    error("Trading House must have exactly one UpdateTabHeader implementation")
end
if count_literal(combinedHeaderSource,
        "function BETTERUI.TradingHouse.Class:CycleTabs(direction)") ~= 1 then
    error("Trading House must have exactly one CycleTabs implementation")
end
assert_contains(flowSource, "function TH.TakeOverNativeTradingHouse()",
    "Trading House flow helper owns native scene takeover")
assert_not_contains(flowSource, "SCENE_MANAGER.scenes[\"gamepad_trading_house\"] =",
    "Trading House does not replace the shared gamepad_trading_house scene table entry")
assert_not_contains(flowSource, "nativeTH.OpenTradingHouse = function",
    "Trading House leaves the native OpenTradingHouse method untouched")
assert_not_contains(flowSource, "nativeTH.CloseTradingHouse = function",
    "Trading House leaves the native CloseTradingHouse method untouched")
assert_not_contains(flowSource, "nativeTH.sceneName =",
    "Trading House leaves native sceneName metadata intact")
assert_contains(flowSource, "local function AssociateSearchFeatures()",
    "Trading House flow helper owns search-feature association")
assert_contains(flowSource, "local function DisassociateSearchFeatures()",
    "Trading House flow helper owns search-feature disassociation")
assert_contains(flowSource, "function TH.OnTradingHouseResponseTimeout()",
    "Trading House flow helper owns response timeout handler")
assert_contains(flowSource, "function TH.OnTradingHouseOperationTimeout()",
    "Trading House flow helper owns operation timeout handler")
assert_contains(flowSource, "function TH.GetKeybindRefreshFingerprint()",
    "Trading House flow helper owns the label-relevant keybind state fingerprint")
assert_contains(flowSource, "iface.ShouldSkipRedundantKeybindRefresh(TH.instance, fingerprint, force == true)",
    "Trading House global keybind refreshes use same-frame state-equivalence coalescing")
assert_not_contains(classSource, "BETTERUI.Interface.UpdateCurrentKeybindGroups",
    "Trading House mode changes route global refreshes through the coalescing helper")
assert_contains(classSource, "BETTERUI.TradingHouse.RefreshCurrentTradingHouseKeybinds",
    "Trading House mode changes use the shared fingerprinted keybind refresh")
assert_not_contains(settingsSource, "BETTERUI.Interface.UpdateCurrentKeybindGroups",
    "Trading House settings do not bypass the shared keybind refresh helper")
assert_contains(settingsSource, 'TH.RefreshCurrentTradingHouseKeybinds("TradingHouse.Settings:RefreshTHWindow", "settingsChanged", true)',
    "Trading House settings force their distinct external state refresh")
assert_contains(flowSource, "function TH.OnSelectedTradingHouseGuildChanged()",
    "Trading House flow helper owns selected-guild-changed handler")
assert_contains(flowSource, "function TH.OnTradingHouseStatusReceived()",
    "Trading House flow helper owns status-received handler")
assert_contains(flowSource, "function TH.OnMoneyUpdate()",
    "Trading House flow helper owns money-update handler")
assert_contains(flowSource, "EVENT_TRADING_HOUSE_RESPONSE_TIMEOUT",
    "Trading House registers response timeout event")
assert_contains(flowSource, "EVENT_TRADING_HOUSE_OPERATION_TIME_OUT",
    "Trading House registers operation timeout event")
assert_contains(flowSource, "EVENT_TRADING_HOUSE_SELECTED_GUILD_CHANGED",
    "Trading House registers selected-guild-changed event")
assert_contains(flowSource, "EVENT_TRADING_HOUSE_STATUS_RECEIVED",
    "Trading House registers status-received event")
assert_contains(flowSource, "EVENT_MONEY_UPDATE",
    "Trading House registers money-update event")
assert_contains(browseSource, "TRADING_HOUSE_SEARCH.features",
    "Trading House guards ApplyFilters with features table")
assert_not_contains(flowSource, "UserAlertText(\"TH:SearchFailed\"",
    "Trading House flow helper no longer duplicates ZOS search-failure alert")
assert_contains(flowSource, "function TH.RegisterCreateListingDialog()",
    "Trading House flow helper owns dialog registration")
assert_contains(flowSource, "function TH.RegisterEvents(eventManager)",
    "Trading House flow helper owns event registration")
assert_contains(flowSource, "function TH.OnOpenTradingHouse()",
    "Trading House flow helper owns open callback routing")
assert_contains(flowSource, "function TH.TakeOverNativeTradingHouse()",
    "Trading House flow helper owns native scene takeover")

assert_not_contains(entrySource, "local function RegisterCreateListingDialog(",
    "TradingHouse.lua no longer defines dialog registration locally")
assert_not_contains(entrySource, "local function RegisterTradingHouseSceneLifecycle(",
    "TradingHouse.lua no longer defines scene lifecycle locally")
assert_not_contains(entrySource, "local function RegisterTradingHouseEvents(",
    "TradingHouse.lua no longer defines event registration locally")
assert_not_contains(entrySource, "local function TakeOverNativeTradingHouse(",
    "TradingHouse.lua no longer defines native scene takeover locally")
assert_not_contains(entrySource, "local function BuildCoreKeybinds(",
    "TradingHouse.lua no longer defines keybind builders locally")
assert_contains(entrySource, "TH.RegisterCreateListingDialog()",
    "TradingHouse.lua delegates dialog registration to the runtime helper")
assert_contains(entrySource, "TH.BuildCoreKeybinds(TH.instance)",
    "TradingHouse.lua delegates core keybind construction to the runtime helper")
assert_contains(entrySource, "TH.instance:InitializeListSearch()",
    "TradingHouse.lua initializes per-list search during scene construction")
assert_contains(entrySource, "self:PositionListSearchControl()",
    "Trading House header refresh repositions the per-list search box")
assert_not_contains(entrySource, "TH.BuildTabKeybinds(TH.instance)",
    "TradingHouse.lua leaves LB/RB ownership exclusively with the generic carousel")
assert_contains(runtimeSource, "ethereal = true",
    "Trading House keeps carousel LB/RB functional but ethereal outside the footer strip")
assert_contains(runtimeSource, "keybinds = { instance.coreKeybinds }",
    "Trading House does not register a duplicate shoulder-navigation group")
assert_contains(runtimeSource, "header.tabBar:Activate()",
    "Trading House activates the header carousel for full-bright selected visuals")
assert_contains(runtimeSource, "header.tabBar:Deactivate()",
    "Trading House releases carousel keybind ownership when its scene closes")
assert_contains(runtimeSource, "function TH.ReleaseForeignCarouselKeybinds()",
    "Trading House explicitly purges stale foreign carousel ownership")
assert_contains(runtimeSource, "BETTERUI.Interface.RemoveKeybindGroupFromAllStates",
    "Trading House removes a restored Inventory carousel from saved keybind states")
assert_contains(read_file("Modules/TradingHouse/Core/BrowseFilterDialog.lua"),
    "TH.ReleaseForeignCarouselKeybinds()",
    "Edit Filters teardown reasserts Trading House shoulder ownership")
assert_contains(entrySource, "local function GetTHHeaderCategories(instance)",
    "Trading House builds the LB/RB carousel from the active list only")
assert_contains(entrySource, "activeComponent:GetCategories()",
    "Trading House asks the active component for its own categories")
assert_contains(entrySource, "activeComponent:SetCategory(categoryKey, instance)",
    "Shoulder category changes route back to the active component")
assert_not_contains(entrySource, "entryData.mode = tab.mode",
    "Browse, Sell, and My Listings no longer occupy category-carousel entries")
assert_contains(entrySource, "SetFixedCenterOffset(-50)",
    "Trading House aligns its selected row with the tooltip-side selection chevron")
assert_contains(entrySource, "tradingHousePostPadding = 15",
    "Trading House uses the requested fifteen-pixel base row spacing")
assert_contains(entrySource, "SetUniversalPostPadding(tradingHousePostPadding)",
    "Trading House rows retain readable vertical separation")
assert_contains(browseSource, 'entry, nil, nil, 30, 30)',
    "Trading House Browse adds pronounced selected-row separation")
assert_contains(sellSource, 'entry, nil, nil, 30, 30)',
    "Trading House Sell adds pronounced selected-row separation")
assert_contains(priceEntrySource, 'GetMarketPriceInfo(itemLink, quantity)',
    "Trading House columns reuse the tooltip market-price integration")
assert_contains(priceEntrySource, 'return unitPrice, unitPrice * quantity, true',
    "Trading House calculates quantity-adjusted total market value")
assert_contains(read_file("Modules/TradingHouse/Settings/SettingsPanel.lua"), 'useMarketPricesInSellList',
    "Trading House settings expose the market-price column toggle")
assert_contains(listingsSource, 'entry, nil, nil, 30, 30)',
    "Trading House Listings adds pronounced selected-row separation")
assert_contains(entrySource, "entryData.filterType = category.filterType",
    "Trading House preserves the All Items gold tint and filter-category white tint")
assert_contains(priceEntrySource, "align == RIGHT",
    "Trading House normalizes legacy anchor alignment constants for section row values")
assert_contains(priceEntrySource, "TEXT_ALIGN_RIGHT",
    "Trading House right-aligns Sell quantity and price values with their headers")
assert_contains(priceEntrySource, "ApplyTradingHouseColumnGeometry(control, hasMarketPrice)",
    "Trading House applies the finalized Sell geometry to all Trading House section rows")
assert_contains(priceEntrySource, "Trait = { offset = 795, width = 180 }",
    "Trading House centers unit prices between quantity or time and total")
assert_contains(priceEntrySource, "Stat = { offset = 965, width = 140 }",
    "Trading House places native totals in the fourth column")
assert_contains(priceEntrySource, "Value = { offset = 1165, width = 140 }",
    "Trading House places market totals in the fifth column")
assert_contains(priceEntrySource, 'local marketText = ds.thMarketText or "-"',
    "Trading House displays a dash when market pricing is unavailable")
assert_contains(priceEntrySource, 'if childName == "Value" and hasMarketPrice then',
    "Trading House shifts populated market values left without moving the centered dash")
assert_contains(priceEntrySource, "offset = offset - 20",
    "Trading House aligns populated market values with the MARKET header")
assert_contains(priceEntrySource, "child:SetColor(1, 0.749019, 0, 1)",
    "Trading House renders populated market values gold while unavailable dashes remain white")
assert_contains(priceEntrySource, "return FormatColumnNumber(marketTotal)",
    "Trading House market values omit currency markup so its icon and inline color cannot override the Market column")
assert_contains(sellSource, "TH.FormatTradingHouseMarketValue(marketTotalPrice, usesMarketPrice)",
    "Sell uses the same icon-free Market formatter as Browse and My Listings")
assert_contains(browseSource, 'thColumnMode     = "browse"',
    "Browse rows opt into the shared Trading House column geometry")
assert_contains(browseSource, '{ text = "TIME", align = TEXT_ALIGN_RIGHT, offset = 516, width = 100 }',
    "Browse TIME uses the finalized right-aligned Sell quantity lane")
assert_contains(browseSource, 'offset = 719, width = 180',
    "Browse compensates its sortable UNIT label to match the Sell header placement")
assert_contains(browseSource, '{ text = "TOTAL", align = TEXT_ALIGN_RIGHT, offset = 922, width = 140 }',
    "Browse compensates its TOTAL header to align with row data")
assert_contains(browseSource, '{ text = "MARKET", align = TEXT_ALIGN_RIGHT, offset = 1117, width = 140 }',
    "Browse exposes the fifth Market column")
assert_contains(sellSource, '{ text = "TOTAL", align = TEXT_ALIGN_RIGHT, offset = 922, width = 140 }',
    "Sell compensates its TOTAL header to align with row data")
assert_contains(sellSource, '{ text = "MARKET", align = TEXT_ALIGN_RIGHT, offset = 1117, width = 140 }',
    "Sell exposes the fifth Market column")
assert_contains(listingsSource, '{ text = "TOTAL", align = TEXT_ALIGN_RIGHT, offset = 922, width = 140 }',
    "My Listings compensates its TOTAL header to align with row data")
assert_contains(listingsSource, '{ text = "MARKET", align = TEXT_ALIGN_RIGHT, offset = 1117, width = 140 }',
    "My Listings exposes the fifth Market column")
assert_contains(listingsSource,
    '{ text = "TIME", align = TEXT_ALIGN_RIGHT, offset = 516, width = 100 }',
    "Listings TIME uses the finalized right-aligned Sell quantity lane")
assert_contains(priceEntrySource, 'child:SetHidden(text == nil or text == "")',
    "Trading House unhides populated shared price controls and hides empty spacer controls")
assert_contains(runtimeSource, "GAMEPAD_TOOLTIPS:LayoutItem(GAMEPAD_LEFT_TOOLTIP, ds.itemLink)",
    "Trading House lays out item-link tooltips for Browse and Listings rows")
assert_contains(runtimeSource, "local function LayoutTradingHouseSelectionTooltip(ds)",
    "Trading House shares one tooltip path between scene entry and selection changes")
assert_contains(browseSource, "TH.InstallTradingHouseSectionRowSetup()",
    "Browse installs shared Trading House row geometry even when it is the first mode opened")
assert_contains(entrySource, "BETTERUI.GenericHeader.Refresh(headerGeneric, headerData, false)",
    "Trading House keeps the category selection callback installed after header refresh")
assert_contains(browseSource, 'Browse.selectedCategoryKey = "__all"',
    "Each received result page resets the local category selection to All Items")
assert_contains(browseSource, "TH.ListCategories.Prepare(Browse, rows)",
    "Browse publishes and applies its mode-owned categories")
assert_contains(sellSource, "TH.ListCategories.Prepare(Sell, rows)",
    "Sell publishes and applies independent categories")
assert_contains(listingsSource, "TH.ListCategories.Prepare(Listings, rows)",
    "My Listings publishes and applies independent categories")
local categoriesSource = read_file("Modules/TradingHouse/Core/ListCategories.lua")
assert_contains(categoriesSource, "GetItemLinkFilterTypeInfo(itemLink)",
    "Shared Trading House categories use the ESO item-link filter API")
assert_contains(categoriesSource, "taxonomy.BANK_CATEGORY_DEFS",
    "Trading House lists reuse the shared inventory and banking taxonomy")
assert_contains(categoriesSource, "itemData.listCategoryIcon = definition.iconFile",
    "Mode-owned categories use stable taxonomy artwork")
assert_not_contains(browseSource, "icon = itemData.icon",
    "Browse category icons never inherit arbitrary first-result item artwork")
assert_contains(runtimeSource, "screen.list:Activate()",
    "Trading House activates its item list once when the scene is shown")
assert_not_contains(browseSource, "thInstance.list:Activate()",
    "Category changes do not repeatedly reacquire directional input")
assert_contains(entrySource, "TH.TakeOverNativeTradingHouse()",
    "TradingHouse.lua delegates native scene takeover to the runtime helper")
assert_contains(entrySource, "TH.RegisterSceneLifecycle(TH.instance)",
    "TradingHouse.lua delegates scene lifecycle registration to the runtime helper")
assert_contains(entrySource, "TH.RegisterEvents(EVENT_MANAGER)",
    "TradingHouse.lua delegates event registration to the runtime helper")
assert_contains(manifestSource, "Modules\\TradingHouse\\Core\\TradingHouseRuntime.lua",
    "Addon manifest loads the new Trading House runtime helper")
assert_contains(manifestSource, "Modules\\TradingHouse\\Core\\TradingHouseRuntimeFlow.lua",
    "Addon manifest loads the new Trading House flow helper")
assert_contains(manifestSource, "Modules\\TradingHouse\\Core\\ListCategories.lua",
    "Addon manifest loads shared mode-owned categories before components")

assert_contains(runtimeSource, "function TH.GetAlternateModeBindings(currentMode)",
    "Trading House exposes deterministic inactive-list bindings")
assert_contains(runtimeSource, 'keybind = "UI_SHORTCUT_LEFT_STICK"',
    "L3 switches to the first inactive list")
assert_contains(runtimeSource, 'keybind = "UI_SHORTCUT_RIGHT_STICK"',
    "R3 switches to the second inactive list")
assert_not_contains(runtimeSource, "handlesKeyUp = true",
    "Guild selection and Edit Filters use independent keybind descriptors")
assert_not_contains(runtimeSource, "BeginEditFiltersHold",
    "Trading House no longer multiplexes Guild and Edit Filters through hold state")
assert_contains(runtimeSource,
    'TraceTHKeybind(thInstance, "activated", "UI_SHORTCUT_QUINARY", { action = "editFilters" })',
    "Edit Filters uses the same Quinary action as BetterUI multi-select")
assert_not_contains(runtimeSource, "SI_BINDING_NAME_GAMEPAD_HOLD_LEFT",
    "Edit Filters uses a standalone keybind label without inline hold formatting")
assert_contains(browseSource, "function Browse:SearchForItemLink(itemLink, thInstance)",
    "BetterUI owns selected-item search inside its custom scene")
assert_contains(browseSource, "TRADING_HOUSE_SEARCH:LoadSearchItem(itemLink)",
    "Selected-item search loads the native item search features")
assert_contains(browseSource, "Browse:ExecuteSearch()",
    "Selected-item search dispatches through BetterUI Browse")
assert_contains(flowSource, "TH.BrowseFilters.ResetSearch()",
    "Trading House entry clears persistent edit-filter search state")

print("  OK")
