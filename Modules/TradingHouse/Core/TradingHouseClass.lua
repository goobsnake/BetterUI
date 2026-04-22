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

-- CLASS DEFINITION

---@class BETTERUI.TradingHouse.Class : BETTERUI.CIM.GenericWindow
---@field currentMode number Current active TH mode (see BETTERUI.TradingHouse.MODE)
---@field components table<number, THComponent> Registered mode components
---@field list table|nil Parametric list control
---@field coreKeybinds table Core keybind button group
---@field tabKeybinds table Tab navigation keybind button group
---@field _suppressListUpdates boolean Whether list refreshes are suppressed
---@field _isDirty boolean Whether list needs refresh after suppression ends
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
    if not mode then return end
    if self.currentMode == mode then return end

    -- Deactivate the current component if any
    local oldComponent = self:GetActiveComponent()
    if oldComponent and oldComponent.Deactivate then
        oldComponent:Deactivate(self)
    end

    self.currentMode = mode

    -- Activate the new component
    local newComponent = self:GetActiveComponent()
    if newComponent and newComponent.Activate then
        newComponent:Activate(self)
    end

    -- Update keybinds for new mode
    if self:IsSceneShowing() then
        KEYBIND_STRIP:UpdateCurrentKeybindButtonGroups()
    end
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
    if self._suppressListUpdates then
        self._isDirty = true
        return
    end

    if not self.list then return end

    self.list:Clear()

    local component = self:GetActiveComponent()
    if component and component.BuildList then
        component:BuildList(self)
    end

    self.list:Commit()
    self._isDirty = false
end

--- Suppresses list refreshes until FlushListUpdates is called.
function BETTERUI.TradingHouse.Class:SuppressListUpdates()
    self._suppressListUpdates = true
    self._isDirty = false
end

--- Releases suppressed list updates and refreshes if dirty.
function BETTERUI.TradingHouse.Class:FlushListUpdates()
    self._suppressListUpdates = false
    if self._isDirty then
        self:RefreshList()
    end
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
            btn:SetHandler("OnClicked", nil)
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
            btn:SetHandler("OnClicked", nil)
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
