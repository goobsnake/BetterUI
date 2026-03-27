--[[
File: Modules/Vendor/Core/VendorClass.lua
Purpose: Core class definition, constants, and mode-routing for the Vendor module.
Authors: BUI Team
Last Modified: 2026-03-14

This file provides:
1. Scene constants and interaction tables for vendor and fence
2. Class definition extending BETTERUI.CIM.GenericWindow
3. Mode constants and routing (Buy, Sell, Repair, Buyback, FenceSell, FenceLaunder)
4. Shared utility helpers for store/fence state queries

KEY DESIGN NOTE:
  Unlike Banking (which has deposit/withdraw toggle), Vendor has a component-tab
  model — each tab is a separate "mode" with its own list builder and keybinds.
  The active mode is tracked in self.currentMode and changed via SetMode().
]]

-- ============================================================================
-- NAMESPACE & GUARD
-- ============================================================================
if not BETTERUI.Vendor then BETTERUI.Vendor = {} end

-- ============================================================================
-- SCENE CONSTANTS
-- ============================================================================

--[[
Constant: BETTERUI_VENDOR_SCENE_NAME
Description: Scene name used when registering the vendor ZO_InteractScene.
Used By: Vendor.lua (Init), VendorSceneLifecycle.lua
]]
BETTERUI_VENDOR_SCENE_NAME = "BETTERUI_VENDOR"

--[[
Table: BETTERUI.Vendor.VENDOR_INTERACTION
Description: Interaction table for creating the vendor scene.
Used By: Vendor.lua (Init)
]]
BETTERUI.Vendor.VENDOR_INTERACTION = {
    type = "Vendor",
    interactTypes = { INTERACTION_VENDOR },
}

--[[
Table: BETTERUI.Vendor.FENCE_INTERACTION
Description: Interaction table for creating the fence scene.
             The fence shares the same scene as vendor but opens with
             EVENT_OPEN_FENCE instead of EVENT_OPEN_STORE.
Used By: Vendor.lua (Init)
]]
BETTERUI.Vendor.FENCE_INTERACTION = {
    type = "Fence",
    interactTypes = { INTERACTION_VENDOR },
}

-- ============================================================================
-- MODE CONSTANTS
-- ============================================================================

--[[
Table: BETTERUI.Vendor.MODE
Description: Mode constants for tracking which vendor tab is active.
             Maps to ESO's ZO_MODE_STORE_* constants where applicable.
Used By: VendorClass, Vendor.lua, all Component files
]]
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

--[[
Class: BETTERUI.Vendor.Class
Main class for the Vendor module window.
]]
--- @class BetterUIVendorClass: BETTERUI.CIM.GenericWindow
--- @field currentMode number|nil
--- @field components table<number, table>|nil
--- @field list any
--- @field _suppressListUpdates boolean|nil
--- @field _isDirty boolean|nil
--- @field unifiedFooterController any
BETTERUI.Vendor.Class = BETTERUI.CIM.GenericWindow:Subclass()

--[[
Function: BETTERUI.Vendor.Class:New
Description: Creates a new instance of the Vendor window class.
param: ... (any) - Arguments passed to the parent constructor.
return: table - The new Vendor Class instance.
]]
--- @param ... any
--- @return BETTERUI.Vendor.Class
function BETTERUI.Vendor.Class:New(...)
    local obj = BETTERUI.CIM.GenericWindow.New(self, ...)
    return obj --[[@as BETTERUI.Vendor.Class]]
end

--[[
Function: BETTERUI.Vendor.Class:IsSceneShowing
Description: Checks if the vendor scene is currently showing.
return: boolean - True if the vendor scene is currently showing.
]]
--- @return boolean
function BETTERUI.Vendor.Class:IsSceneShowing()
    local scene = SCENE_MANAGER and SCENE_MANAGER:GetScene(BETTERUI_VENDOR_SCENE_NAME)
    if not scene then return false end
    return scene:IsShowing()
end

-- ============================================================================
-- MODE ROUTING
-- ============================================================================

--[[
Function: BETTERUI.Vendor.Class:GetCurrentMode
Description: Returns the current active mode (Buy/Sell/Repair/Buyback/FenceSell/FenceLaunder).
return: number - One of BETTERUI.Vendor.MODE constants.
]]
--- @return number
function BETTERUI.Vendor.Class:GetCurrentMode()
    return self.currentMode or BETTERUI.Vendor.MODE.BUY
end

--[[
Function: BETTERUI.Vendor.Class:SetMode
Switches the active vendor tab/mode.
param: mode (number) - One of BETTERUI.Vendor.MODE constants.
]]
--- @param mode number
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

--[[
Function: BETTERUI.Vendor.Class:GetActiveComponent
Description: Returns the component table for the current mode.
return: table|nil - The component table, or nil if not registered.
]]
--- @return table|nil
function BETTERUI.Vendor.Class:GetActiveComponent()
    if not self.components then return nil end
    return self.components[self:GetCurrentMode()]
end

--[[
Function: BETTERUI.Vendor.Class:RegisterComponent
Description: Registers a component table for a given mode.
param: mode (number) - One of BETTERUI.Vendor.MODE constants.
param: component (table) - Component table with Activate/Deactivate/BuildList/GetKeybinds methods.
]]
--- @param mode number
--- @param component table
function BETTERUI.Vendor.Class:RegisterComponent(mode, component)
    if not mode or not component then return end
    self.components = self.components or {}
    self.components[mode] = component
end

-- ============================================================================
-- LIST MANAGEMENT
-- ============================================================================

--[[
Function: BETTERUI.Vendor.Class:RefreshList
Clears and rebuilds the current list using the active component's BuildList method.
]]
--- @return nil
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

--[[
Function: BETTERUI.Vendor.Class:SuppressListUpdates
Description: Enters suppression mode — list refreshes are deferred and coalesced.
             Call FlushListUpdates() or EndSuppression() to apply pending changes.
]]
function BETTERUI.Vendor.Class:SuppressListUpdates()
    self._suppressListUpdates = true
    self._isDirty = false
end

--[[
Function: BETTERUI.Vendor.Class:FlushListUpdates
Description: Exits suppression mode and flushes any pending list updates.
]]
function BETTERUI.Vendor.Class:FlushListUpdates()
    self._suppressListUpdates = false
    if self._isDirty then
        self:RefreshList()
    end
end

-- ============================================================================
-- STORE/FENCE STATE QUERIES
-- ============================================================================

--[[
Function: BETTERUI.Vendor.Class:IsFenceMode
Description: Checks if the current mode is a fence mode (Sell Stolen or Launder).
return: boolean - True if in fence sell or launder mode.
]]
--- @return boolean
function BETTERUI.Vendor.Class:IsFenceMode()
    local mode = self:GetCurrentMode()
    return mode == BETTERUI.Vendor.MODE.FENCE_SELL
        or mode == BETTERUI.Vendor.MODE.FENCE_LAUNDER
end

--[[
Function: BETTERUI.Vendor.Class:GetStoreCurrencyTypes
Description: Returns the currency types used by the current store.
return: number, number - Primary and secondary currency types.
]]
--- @return number, number|nil
function BETTERUI.Vendor.Class:GetStoreCurrencyTypes()
    if GetStoreUsedCurrencyTypes then
        return GetStoreUsedCurrencyTypes()
    end
    return CURT_MONEY, nil
end

--[[
Function: BETTERUI.Vendor.Class:CanAfford
Description: Checks if the player can afford a purchase.
param: cost (number) - The cost of the item.
param: currencyType (number) - The currency type (defaults to CURT_MONEY).
return: boolean - True if the player can afford the item.
]]
--- @param cost number
--- @param currencyType number|nil
--- @return boolean
function BETTERUI.Vendor.Class:CanAfford(cost, currencyType)
    if not cost or cost <= 0 then return true end
    currencyType = currencyType or CURT_MONEY
    local current = GetCurrencyAmount(currencyType, CURRENCY_LOCATION_CHARACTER) or 0
    return current >= cost
end

--[[
Function: BETTERUI.Vendor.Class:HasInventorySpace
Description: Checks if the player has backpack space for an item.
return: boolean - True if there's at least 1 empty slot.
]]
--- @return boolean
function BETTERUI.Vendor.Class:HasInventorySpace()
    local numFree = GetNumBagFreeSlots(BAG_BACKPACK)
    return numFree and numFree > 0
end

--[[
Function: BETTERUI.Vendor.Class:SetupUnifiedFooter
Description: Configures the unified footer for VENDOR mode.
]]
--- @return nil
function BETTERUI.Vendor.Class:SetupUnifiedFooter()
    local footerContainer = self.control and self.control.container and
        self.control.container:GetNamedChild("FooterContainer")
    if footerContainer and footerContainer.unifiedFooter then
        self.unifiedFooterController = footerContainer.unifiedFooter
        -- Use INVENTORY mode for footer (shows gold, bag capacity)
        self.unifiedFooterController:SetMode(BETTERUI.CIM.UnifiedFooter.MODE.INVENTORY)
    end
end
