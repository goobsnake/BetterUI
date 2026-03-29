-- Modules/Vendor/Core/VendorClass.lua
-- Core class definition, constants, and mode-routing for the Vendor module.
--
-- Component-tab model: each tab is a separate "mode" with its own list builder
-- and keybinds. Active mode tracked in self.currentMode, changed via SetMode().

-- NAMESPACE & GUARD
if not BETTERUI.Vendor then BETTERUI.Vendor = {} end

-- SCENE CONSTANTS

BETTERUI_VENDOR_SCENE_NAME = "BETTERUI_VENDOR"

BETTERUI.Vendor.VENDOR_INTERACTION = {
    type = "Vendor",
    interactTypes = { INTERACTION_VENDOR },
}

-- Fence shares the vendor scene but opens via EVENT_OPEN_FENCE.
BETTERUI.Vendor.FENCE_INTERACTION = {
    type = "Fence",
    interactTypes = { INTERACTION_VENDOR },
}

-- MODE CONSTANTS

BETTERUI.Vendor.MODE = {
    BUY           = 1,
    SELL          = 2,
    REPAIR        = 3,
    BUYBACK       = 4,
    FENCE_SELL    = 5,
    FENCE_LAUNDER = 6,
}

-- MODULE-SCOPE TASK MANAGER (for coalescing list refreshes)
assert(BETTERUI.CIM and BETTERUI.CIM.DeferredTask, "BetterUI: CIM.DeferredTask must load before Vendor/Core/VendorClass")
BETTERUI.Vendor.Tasks = BETTERUI.CIM.DeferredTask.Manager:New()

-- CLASS DEFINITION

---@class BETTERUI.Vendor.Class : BETTERUI.CIM.GenericWindow
---@field currentMode number Current active vendor mode (see BETTERUI.Vendor.MODE)
---@field components table<number, VendorComponent> Registered mode components
---@field list table|nil Parametric list control
---@field coreKeybinds table Core keybind button group
---@field tabKeybinds table Tab navigation keybind button group
---@field header table|nil Header control with SetTitle method
---@field _keybindsAdded boolean Whether keybinds are currently registered
---@field _suppressListUpdates boolean Whether list refreshes are suppressed
---@field _isDirty boolean Whether list needs refresh after suppression ends
---@field unifiedFooterController table|nil Footer controller reference
BETTERUI.Vendor.Class = BETTERUI.CIM.GenericWindow:Subclass()

---@param ... any Arguments forwarded to GenericWindow:New
---@return BETTERUI.Vendor.Class
function BETTERUI.Vendor.Class:New(...)
    local obj = BETTERUI.CIM.GenericWindow.New(self, ...)
    return obj --[[@as BETTERUI.Vendor.Class]]
end

---@return boolean showing True if the vendor scene is currently showing
function BETTERUI.Vendor.Class:IsSceneShowing()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetScene(BETTERUI_VENDOR_SCENE_NAME)
    if not scene then return false end
    return scene:IsShowing()
end

-- MODE ROUTING

---@return number mode Current vendor mode constant
function BETTERUI.Vendor.Class:GetCurrentMode()
    return self.currentMode or BETTERUI.Vendor.MODE.BUY
end

---@param mode number Vendor mode constant from BETTERUI.Vendor.MODE
function BETTERUI.Vendor.Class:SetMode(mode)
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

---@return VendorComponent|nil component The currently active component, or nil
function BETTERUI.Vendor.Class:GetActiveComponent()
    if not self.components then return nil end
    return self.components[self:GetCurrentMode()]
end

---@param mode number Vendor mode constant from BETTERUI.Vendor.MODE
---@param component VendorComponent Component implementing Activate/Deactivate/BuildList
function BETTERUI.Vendor.Class:RegisterComponent(mode, component)
    if not mode or not component then return end
    self.components = self.components or {}
    self.components[mode] = component
end

-- LIST MANAGEMENT

--- Clears and rebuilds the list from the active component's BuildList.
---@return nil
function BETTERUI.Vendor.Class:RefreshList()
    if self._suppressListUpdates then
        self._isDirty = true
        return
    end

    if not self.list then return end

    -- Clear existing data
    self.list:Clear()

    -- Delegate to the active component's BuildList
    local component = self:GetActiveComponent()
    if component and component.BuildList then
        component:BuildList(self)
    end

    self.list:Commit()
    self._isDirty = false
end

--- Suppresses list refreshes until FlushListUpdates is called.
---@return nil
function BETTERUI.Vendor.Class:SuppressListUpdates()
    self._suppressListUpdates = true
    self._isDirty = false
end

--- Releases suppressed list updates and refreshes if dirty.
---@return nil
function BETTERUI.Vendor.Class:FlushListUpdates()
    self._suppressListUpdates = false
    if self._isDirty then
        self:RefreshList()
    end
end

-- STORE/FENCE STATE QUERIES

---@return boolean isFence True if current mode is a fence mode
function BETTERUI.Vendor.Class:IsFenceMode()
    local mode = self:GetCurrentMode()
    return mode == BETTERUI.Vendor.MODE.FENCE_SELL
        or mode == BETTERUI.Vendor.MODE.FENCE_LAUNDER
end

---@return number currencyType1 Primary currency type
---@return number|nil currencyType2 Secondary currency type, or nil
function BETTERUI.Vendor.Class:GetStoreCurrencyTypes()
    if GetStoreUsedCurrencyTypes then
        return GetStoreUsedCurrencyTypes()
    end
    return CURT_MONEY, nil
end

---@param cost number|nil Item cost to check
---@param currencyType number|nil Currency type (defaults to CURT_MONEY)
---@return boolean canAfford True if player can afford the cost
function BETTERUI.Vendor.Class:CanAfford(cost, currencyType)
    if not cost or cost <= 0 then return true end
    currencyType = currencyType or CURT_MONEY
    local current = GetCurrencyAmount(currencyType, CURRENCY_LOCATION_CHARACTER) or 0
    return current >= cost
end

---@return boolean hasSpace True if backpack has at least one free slot
function BETTERUI.Vendor.Class:HasInventorySpace()
    local numFree = GetNumBagFreeSlots(BAG_BACKPACK)
    return numFree and numFree > 0
end


--- Initializes the vendor footer by relabelling the embedded Withdraw/Deposit
--- controls to show gold and bag capacity instead of banking info.
--- Called once during Init after the window is created.
---@return nil
function BETTERUI.Vendor.Class:InitVendorFooter()
    local footerRoot = self.footer and self.footer:GetNamedChild("Footer")
    if not footerRoot then return end

    -- Hide the centre vertical divider (banking mode selector divider)
    local dividerCentre = footerRoot:GetNamedChild("DividerCentre")
    if dividerCentre then dividerCentre:SetHidden(true) end

    -- LEFT SIDE: Relabel "WITHDRAW" → Gold display
    local withdraw = footerRoot:GetNamedChild("Withdraw")
    if withdraw then
        local btn = withdraw:GetNamedChild("Button")
        if btn then
            -- Remove the banking click handler
            btn:SetHandler("OnClicked", nil)

            local label = btn:GetNamedChild("Label")
            if label then
                label:SetText(GetString(rawget(_G, "SI_BETTERUI_FOOTER_GOLD") or "SI_BETTERUI_FOOTER_GOLD"))
            end
        end
        -- Change icon to gold coin
        local icon = withdraw:GetNamedChild("Icon")
        if icon then
            icon:SetTexture("esoui/art/currency/currency_gold_64.dds")
        end
    end

    -- RIGHT SIDE: Relabel "DEPOSIT" → Bag capacity
    local deposit = footerRoot:GetNamedChild("Deposit")
    if deposit then
        local btn = deposit:GetNamedChild("Button")
        if btn then
            -- Remove the banking click handler
            btn:SetHandler("OnClicked", nil)

            local label = btn:GetNamedChild("Label")
            if label then
                label:SetText(GetString(rawget(_G, "SI_BETTERUI_FOOTER_BAG_CAPACITY") or "SI_BETTERUI_FOOTER_BAG_CAPACITY"))
                label:SetColor(1, 1, 1, 1) -- Reset to white (banking dims the inactive side)
            end
        end
        -- Change icon to inventory bag
        local icon = deposit:GetNamedChild("Icon")
        if icon then
            icon:SetTexture("esoui/art/inventory/gamepad/gp_inventory_icon_all.dds")
        end
    end

    self:RefreshVendorFooter()
end

--- Refreshes the vendor footer values (gold amount, bag capacity).
--- Called on scene showing and after inventory changes.
---@return nil
function BETTERUI.Vendor.Class:RefreshVendorFooter()
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
                    "|t24:24:/esoui/art/inventory/gamepad/gp_inventory_icon_all.dds|t " ..
                    zo_strformat(SI_GAMEPAD_INVENTORY_CAPACITY_FORMAT,
                        GetNumBagUsedSlots(BAG_BACKPACK), GetBagSize(BAG_BACKPACK)))
            end
        end
    end
end
