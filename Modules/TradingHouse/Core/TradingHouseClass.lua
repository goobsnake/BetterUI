--[[
File: Modules/TradingHouse/Core/TradingHouseClass.lua
Purpose: Core class definition and mode-routing for the Trading House module.

Component-tab model following the Vendor pattern: each tab is a separate
"mode" with its own list builder and primary action. The active mode is
tracked in self.currentMode, changed via SetMode().

ESO Reference: ZO_GamepadTradingHouse in
  esoui/ingame/tradinghouse/gamepad/tradinghouse_gamepad.lua
  Scene: "gamepad_trading_house", Interaction: INTERACTION_TRADINGHOUSE
]]

-- NAMESPACE & GUARD
if not BETTERUI.TradingHouse then BETTERUI.TradingHouse = {} end

-- SCENE CONSTANTS

BETTERUI_TRADING_HOUSE_SCENE_NAME = "BETTERUI_TradingHouse"

BETTERUI.TradingHouse.TH_INTERACTION = {
    type = "TradingHouse",
    interactTypes = { INTERACTION_TRADINGHOUSE },
}

-- MODE CONSTANTS

BETTERUI.TradingHouse.MODE = {
    BROWSE   = 1,
    SELL     = 2,
    LISTINGS = 3,
}

-- MODULE-SCOPE TASK MANAGER (for coalescing list refreshes)
local TradingHouseDeferredTask = assert(BETTERUI.CIM and BETTERUI.CIM.DeferredTask,
    "BetterUI: CIM.DeferredTask must load before TradingHouse/Core/TradingHouseClass")
local function EnsureTradingHouseTaskManager()
    if not BETTERUI.TradingHouse._taskManager then
        BETTERUI.TradingHouse._taskManager = TradingHouseDeferredTask.CreateManager()
    end
    return BETTERUI.TradingHouse._taskManager
end
BETTERUI.TradingHouse.EnsureTaskManager = EnsureTradingHouseTaskManager
BETTERUI.TradingHouse.Tasks = BETTERUI.TradingHouse.Tasks or TradingHouseDeferredTask.CreateLazyManagerProxy(EnsureTradingHouseTaskManager)

local function GetTHModeName(mode)
    local modeTable = BETTERUI.TradingHouse.MODE or {}
    for name, value in pairs(modeTable) do
        if value == mode then
            return name
        end
    end
    return tostring(mode or "<none>")
end

local function SetTradingHouseWatchView(mode)
    local watch = BETTERUI.CIM and BETTERUI.CIM.WatchMode
    if not (watch and type(watch.SetView) == "function") then return end
    if watch.RegisterViewScene then watch.RegisterViewScene("th", BETTERUI_TRADING_HOUSE_SCENE_NAME or "BETTERUI_TradingHouse") end
    watch.SetView("th." .. GetTHModeName(mode):lower())
end

local function CountTHList(instance)
    local dataList = instance and instance.list and instance.list.dataList
    return type(dataList) == "table" and #dataList or nil
end

local function DescribeTHSelection(instance)
    local L = BETTERUI.Log
    local list = instance and instance.list
    if not list then
        return nil
    end
    if L and L.DescribeListSelection then
        local ok, description = pcall(L.DescribeListSelection, list, "selection")
        if ok then
            return description
        end
    end
    local selectedData = nil
    if list.GetTargetData then
        selectedData = list:GetTargetData()
    elseif list.GetSelectedData then
        selectedData = list:GetSelectedData()
    end
    local dataSource = selectedData and (selectedData.dataSource or selectedData) or nil
    if L and L.DescribeItem and dataSource then
        local ok, description = pcall(L.DescribeItem, dataSource, "selection")
        if ok then
            return description
        end
    end
    return dataSource and (dataSource.name or dataSource.itemLink or tostring(dataSource.bagId or "")) or nil
end

local function TraceTH(category, event, phase, instance, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then
        return
    end
    data = data or {}
    local mode = data.mode or (instance and instance.GetCurrentMode and instance:GetCurrentMode()) or nil
    data.module = data.module or "TradingHouse"
    data.scene = data.scene or BETTERUI_TRADING_HOUSE_SCENE_NAME
    data.feature = data.feature or "trading-house"
    local fn = data.fn or data["function"] or "TradingHouse.Class"
    data.fn = fn
    data["function"] = fn
    data.mode = mode
    data.modeName = data.modeName or GetTHModeName(mode)
    data.guildId = data.guildId or (GetSelectedTradingHouseGuildId and GetSelectedTradingHouseGuildId() or nil)
    data.rowCount = data.rowCount or CountTHList(instance)
    data.selection = data.selection or DescribeTHSelection(instance)
    L.TraceEvent(category or L.CATEGORY.ACTION, event, phase, data)
end

BETTERUI.TradingHouse.Trace = BETTERUI.TradingHouse.Trace or TraceTH

-- CLASS DEFINITION

---@class BETTERUI.TradingHouse.Class : BETTERUI.CIM.GenericWindow
---@field currentMode number Current active TH mode (see BETTERUI.TradingHouse.MODE)
---@field components table<number, THComponent> Registered mode components
---@field list table|nil Parametric list control
---@field coreKeybinds table Core keybind button group
---@field tabKeybinds table Tab navigation keybind button group
BETTERUI.TradingHouse.Class = BETTERUI.CIM.GenericWindow:Subclass()

---@param ... any Arguments forwarded to GenericWindow:New
---@return BETTERUI.TradingHouse.Class
function BETTERUI.TradingHouse.Class:New(...)
    return BETTERUI.CIM.GenericWindow.New(self, ...) --[[@as BETTERUI.TradingHouse.Class]]
end

---@return boolean showing True if the trading house scene is currently showing
function BETTERUI.TradingHouse.Class:IsSceneShowing()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetScene(BETTERUI_TRADING_HOUSE_SCENE_NAME)
    if not scene then return false end
    return scene:IsShowing()
end

-- MODE ROUTING

---@return number mode Current trading house mode constant
function BETTERUI.TradingHouse.Class:GetCurrentMode()
    return self.currentMode or BETTERUI.TradingHouse.MODE.BROWSE
end

---@param mode number TH mode constant from BETTERUI.TradingHouse.MODE
function BETTERUI.TradingHouse.Class:SetMode(mode)
    local L = BETTERUI.Log
    local oldMode = self.currentMode
    if not mode then
        TraceTH(L and L.CATEGORY.LIFECYCLE, "trading_house.mode", "skipped", self, {
            reason = "missingMode",
            oldMode = oldMode,
        })
        return
    end
    if oldMode == mode then
        TraceTH(L and L.CATEGORY.LIFECYCLE, "trading_house.mode", "skipped", self, {
            reason = "sameMode",
            oldMode = oldMode,
            targetMode = mode,
        })
        SetTradingHouseWatchView(mode)
        if self.UpdateTabHeader then self:UpdateTabHeader() end
        return
    end

    TraceTH(L and L.CATEGORY.LIFECYCLE, "trading_house.mode", "begin", self, {
        oldMode = oldMode,
        oldModeName = GetTHModeName(oldMode),
        targetMode = mode,
        targetModeName = GetTHModeName(mode),
    })

    -- Deactivate the current component if any
    local oldComponent = self:GetActiveComponent()
    if oldComponent and oldComponent.Deactivate then
        TraceTH(L and L.CATEGORY.LIFECYCLE, "trading_house.component", "deactivate_before", self, {
            oldMode = oldMode,
            targetMode = mode,
        })
        oldComponent:Deactivate(self)
        TraceTH(L and L.CATEGORY.LIFECYCLE, "trading_house.component", "deactivate_after", self, {
            oldMode = oldMode,
            targetMode = mode,
        })
    end

    self.currentMode = mode
    SetTradingHouseWatchView(mode)
    TraceTH(L and L.CATEGORY.NAV, "th.mode", "changed", self, {
        old = oldMode,
        ["new"] = mode,
        oldMode = oldMode,
        targetMode = mode,
        trigger = "SetMode",
    })
    TraceTH(L and L.CATEGORY.LIFECYCLE, "trading_house.mode", "applied", self, {
        oldMode = oldMode,
        targetMode = mode,
    })

    -- Activate the new component
    local newComponent = self:GetActiveComponent()
    if newComponent and newComponent.Activate then
        TraceTH(L and L.CATEGORY.LIFECYCLE, "trading_house.component", "activate_before", self, {
            oldMode = oldMode,
        })
        newComponent:Activate(self)
        TraceTH(L and L.CATEGORY.LIFECYCLE, "trading_house.component", "activate_after", self, {
            oldMode = oldMode,
        })
    end

    -- Mode changes can originate outside the tab bar; keep header selection/title aligned.
    if self.UpdateTabHeader then self:UpdateTabHeader() end

    -- Update keybinds for new mode
    if self:IsSceneShowing() then
        TraceTH(L and L.CATEGORY.ACTION, "trading_house.keybinds", "refresh_before", self, {
            reason = "modeChanged",
            keybinds = L and L.DescribeKeybindDescriptors and L.DescribeKeybindDescriptors(self.coreKeybinds, "core") or nil,
        })
        local updateCurrentKeybinds = BETTERUI.Interface and BETTERUI.Interface.UpdateCurrentKeybindGroups
        local refreshed = updateCurrentKeybinds and updateCurrentKeybinds() or false
        TraceTH(L and L.CATEGORY.ACTION, "trading_house.keybinds", "refresh_after", self, {
            reason = "modeChanged",
            refreshed = refreshed == true,
            keybinds = L and L.DescribeKeybindDescriptors and L.DescribeKeybindDescriptors(self.coreKeybinds, "core") or nil,
        })
    end

    TraceTH(L and L.CATEGORY.LIFECYCLE, "trading_house.mode", "end", self, {
        oldMode = oldMode,
        targetMode = mode,
    })
end

---@return THComponent|nil component The currently active component, or nil
function BETTERUI.TradingHouse.Class:GetActiveComponent()
    if not self.components then return nil end
    return self.components[self:GetCurrentMode()]
end

---@param mode number TH mode constant from BETTERUI.TradingHouse.MODE
---@param component THComponent Component implementing Activate/Deactivate/BuildList
function BETTERUI.TradingHouse.Class:RegisterComponent(mode, component)
    if not mode or not component then return end
    self.components = self.components or {}
    self.components[mode] = component
end

-- LIST MANAGEMENT

--- Clears and rebuilds the list from the active component's BuildList.
function BETTERUI.TradingHouse.Class:RefreshList()
    local L = BETTERUI.Log
    if not self.list then
        TraceTH(L and L.CATEGORY.LIST, "trading_house.list_refresh", "skipped", self, {
            reason = "missingList",
        })
        if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.LIST, "TH list update skipped -> list missing") end
        return
    end

    TraceTH(L and L.CATEGORY.LIST, "trading_house.list_refresh", "begin", self, nil)
    self.list:Clear()

    local component = self:GetActiveComponent()
    if component and component.BuildList then
        TraceTH(L and L.CATEGORY.LIST, "trading_house.list_build", "before", self, nil)
        component:BuildList(self)
        TraceTH(L and L.CATEGORY.LIST, "trading_house.list_build", "after", self, {
            rowCount = CountTHList(self),
        })
    else
        TraceTH(L and L.CATEGORY.LIST, "trading_house.list_build", "skipped", self, {
            reason = "missingComponentBuildList",
        })
    end

    self.list:Commit()
    TraceTH(L and L.CATEGORY.LIST, "trading_house.list_refresh", "committed", self, {
        rowCount = CountTHList(self),
    })
    TraceTH(L and L.CATEGORY.LIST, "trading_house.list_refresh", "end", self, {
        rowCount = CountTHList(self),
    })
end

-- STORE QUERIES

---@param cost number|nil Item cost to check
---@param currencyType number|nil Currency type (defaults to CURT_MONEY)
---@return boolean canAfford True if player can afford the cost
function BETTERUI.TradingHouse.Class:CanAfford(cost, currencyType)
    if not cost or cost <= 0 then return true end
    currencyType = currencyType or CURT_MONEY
    local current = GetCurrencyAmount(currencyType, CURRENCY_LOCATION_CHARACTER) or 0
    return current >= cost
end

---@return boolean hasSpace True if backpack has at least one free slot
function BETTERUI.TradingHouse.Class:HasInventorySpace()
    local numFree = GetNumBagFreeSlots(BAG_BACKPACK)
    return numFree and numFree > 0
end

-- GUILD INFO

--- Returns the currently selected guild name for the trading house.
---@return string guildName
function BETTERUI.TradingHouse.Class:GetCurrentGuildName()
    -- Try to get guild name from the selected guild ID
    local selectedGuildId = GetSelectedTradingHouseGuildId and GetSelectedTradingHouseGuildId() or nil
    if selectedGuildId then
        local guildName = GetGuildName(selectedGuildId)
        if guildName and guildName ~= "" then
            return guildName
        end
    end
    -- Fallback: iterate guild details
    local numGuilds = GetNumTradingHouseGuilds and GetNumTradingHouseGuilds() or 0
    for i = 1, numGuilds do
        local _, guildName = GetTradingHouseGuildDetails(i)
        if guildName and guildName ~= "" then
            return guildName
        end
    end
    return GetString(rawget(_G, "SI_BETTERUI_TH_NO_GUILD") or "SI_BETTERUI_TH_NO_GUILD")
end

-- FOOTER

local function DisableFooterButtonInteraction(button)
    if button and button.SetMouseEnabled then
        button:SetMouseEnabled(false)
    end
end

--- Initializes the TH footer by relabelling the embedded Withdraw/Deposit
--- controls to show gold and bag capacity.
function BETTERUI.TradingHouse.Class:InitTHFooter()
    local footerRoot = self.footer and self.footer:GetNamedChild("Footer")
    if not footerRoot then return end

    -- Hide the centre vertical divider
    local dividerCentre = footerRoot:GetNamedChild("DividerCentre")
    if dividerCentre then dividerCentre:SetHidden(true) end

    -- LEFT SIDE: Gold display
    local withdraw = footerRoot:GetNamedChild("Withdraw")
    if withdraw then
        local btn = withdraw:GetNamedChild("Button")
        if btn then
            DisableFooterButtonInteraction(btn)
            local label = btn:GetNamedChild("Label")
            if label then
                label:SetText(GetString(rawget(_G, "SI_BETTERUI_FOOTER_GOLD") or "SI_BETTERUI_FOOTER_GOLD"))
            end
        end
        local icon = withdraw:GetNamedChild("Icon")
        if icon then
            icon:SetTexture("esoui/art/currency/currency_gold_64.dds")
        end
    end

    -- RIGHT SIDE: Bag capacity
    local deposit = footerRoot:GetNamedChild("Deposit")
    if deposit then
        local btn = deposit:GetNamedChild("Button")
        if btn then
            DisableFooterButtonInteraction(btn)
            local label = btn:GetNamedChild("Label")
            if label then
                label:SetText(GetString(rawget(_G, "SI_BETTERUI_FOOTER_BAG_CAPACITY") or "SI_BETTERUI_FOOTER_BAG_CAPACITY"))
                label:SetColor(1, 1, 1, 1)
            end
        end
        local icon = deposit:GetNamedChild("Icon")
        if icon then
            icon:SetTexture("esoui/art/inventory/gamepad/gp_inventory_icon_all.dds")
        end
    end

    self:RefreshTHFooter()
end

--- Refreshes footer values (gold amount, bag capacity).
function BETTERUI.TradingHouse.Class:RefreshTHFooter()
    local footerRoot = self.footer and self.footer:GetNamedChild("Footer")
    if not footerRoot then return end

    -- LEFT SIDE: Gold amount
    local withdraw = footerRoot:GetNamedChild("Withdraw")
    if withdraw then
        local btn = withdraw:GetNamedChild("Button")
        if btn then
            local spaceLabel = btn:GetNamedChild("SpaceLabel")
            if spaceLabel then
                local gold = GetCurrencyAmount(CURT_MONEY, CURRENCY_LOCATION_CHARACTER) or 0
                spaceLabel:SetText("|t24:24:esoui/art/currency/currency_gold_32.dds|t " ..
                    BETTERUI.DisplayNumber(gold))
            end
        end
    end

    -- RIGHT SIDE: Bag capacity
    local deposit = footerRoot:GetNamedChild("Deposit")
    if deposit then
        local btn = deposit:GetNamedChild("Button")
        if btn then
            local spaceLabel = btn:GetNamedChild("SpaceLabel")
            if spaceLabel then
                spaceLabel:SetText(
                    "|t24:24:esoui/art/inventory/gamepad/gp_inventory_icon_all.dds|t " ..
                    zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT,
                        GetNumBagUsedSlots(BAG_BACKPACK), GetBagSize(BAG_BACKPACK)))
            end
        end
    end
end
