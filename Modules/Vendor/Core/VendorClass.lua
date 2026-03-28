-- Modules/Vendor/Core/VendorClass.lua
-- Core class definition, constants, and mode-routing for the Vendor module.
--
-- Component-tab model: each tab is a separate "mode" with its own list builder
-- and keybinds. Active mode tracked in self.currentMode, changed via SetMode().

-- ============================================================================
-- NAMESPACE & GUARD
-- ============================================================================
if not BETTERUI.Vendor then BETTERUI.Vendor = {} end

-- ============================================================================
-- SCENE CONSTANTS
-- ============================================================================

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

-- ============================================================================
-- MODE CONSTANTS
-- ============================================================================

BETTERUI.Vendor.MODE = {
    BUY           = 1,
    SELL          = 2,
    REPAIR        = 3,
    BUYBACK       = 4,
    FENCE_SELL    = 5,
    FENCE_LAUNDER = 6,
}

-- ============================================================================
-- MODULE-SCOPE TASK MANAGER (for coalescing list refreshes)
-- ============================================================================
BETTERUI.Vendor.Tasks = BETTERUI.CIM.DeferredTask.Manager:New()

-- ============================================================================
-- CLASS DEFINITION
-- ============================================================================

--- @class BetterUIVendorClass: BETTERUI.CIM.GenericWindow
--- @field currentMode number|nil
--- @field components table<number, table>|nil
--- @field list any
--- @field _suppressListUpdates boolean|nil
--- @field _isDirty boolean|nil
--- @field unifiedFooterController any
BETTERUI.Vendor.Class = BETTERUI.CIM.GenericWindow:Subclass()

--- @param ... any
--- @return BETTERUI.Vendor.Class
function BETTERUI.Vendor.Class:New(...)
    local obj = BETTERUI.CIM.GenericWindow.New(self, ...)
    return obj --[[@as BETTERUI.Vendor.Class]]
end

--- @return boolean
function BETTERUI.Vendor.Class:IsSceneShowing()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetScene(BETTERUI_VENDOR_SCENE_NAME)
    if not scene then return false end
    return scene:IsShowing()
end

-- ============================================================================
-- MODE ROUTING
-- ============================================================================

--- @return number mode One of BETTERUI.Vendor.MODE constants
function BETTERUI.Vendor.Class:GetCurrentMode()
    return self.currentMode or BETTERUI.Vendor.MODE.BUY
end

--- @param mode number One of BETTERUI.Vendor.MODE constants
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

--- @return table|nil
function BETTERUI.Vendor.Class:GetActiveComponent()
    if not self.components then return nil end
    return self.components[self:GetCurrentMode()]
end

--- @param mode number One of BETTERUI.Vendor.MODE constants
--- @param component table Component with Activate/Deactivate/BuildList/GetKeybinds methods
function BETTERUI.Vendor.Class:RegisterComponent(mode, component)
    if not mode or not component then return end
    self.components = self.components or {}
    self.components[mode] = component
end

-- ============================================================================
-- LIST MANAGEMENT
-- ============================================================================


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

function BETTERUI.Vendor.Class:SuppressListUpdates()
    self._suppressListUpdates = true
    self._isDirty = false
end

function BETTERUI.Vendor.Class:FlushListUpdates()
    self._suppressListUpdates = false
    if self._isDirty then
        self:RefreshList()
    end
end

-- ============================================================================
-- STORE/FENCE STATE QUERIES
-- ============================================================================

--- @return boolean
function BETTERUI.Vendor.Class:IsFenceMode()
    local mode = self:GetCurrentMode()
    return mode == BETTERUI.Vendor.MODE.FENCE_SELL
        or mode == BETTERUI.Vendor.MODE.FENCE_LAUNDER
end

--- @return number, number|nil
function BETTERUI.Vendor.Class:GetStoreCurrencyTypes()
    if GetStoreUsedCurrencyTypes then
        return GetStoreUsedCurrencyTypes()
    end
    return CURT_MONEY, nil
end

--- @param cost number
--- @param currencyType number|nil Defaults to CURT_MONEY
--- @return boolean
function BETTERUI.Vendor.Class:CanAfford(cost, currencyType)
    if not cost or cost <= 0 then return true end
    currencyType = currencyType or CURT_MONEY
    local current = GetCurrencyAmount(currencyType, CURRENCY_LOCATION_CHARACTER) or 0
    return current >= cost
end

--- @return boolean
function BETTERUI.Vendor.Class:HasInventorySpace()
    local numFree = GetNumBagFreeSlots(BAG_BACKPACK)
    return numFree and numFree > 0
end


function BETTERUI.Vendor.Class:SetupUnifiedFooter()
    local footerContainer = self.control and self.control.container and
        self.control.container:GetNamedChild("FooterContainer")
    if footerContainer and footerContainer.unifiedFooter then
        self.unifiedFooterController = footerContainer.unifiedFooter
        -- Use INVENTORY mode for footer (shows gold, bag capacity)
        self.unifiedFooterController:SetMode(BETTERUI.CIM.UnifiedFooter.MODE.INVENTORY)
    end
end
