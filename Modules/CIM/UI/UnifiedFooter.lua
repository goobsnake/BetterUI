--[[
File: Modules/CIM/UI/UnifiedFooter.lua
Purpose: Unified footer controller with mode switching.
         Extends GenericFooter to support different display modes for Inventory vs Banking.
Author: BetterUI Team
Last Modified: 2026-01-28
]]

-- ============================================================================
-- CONSTANTS
-- ============================================================================

---@class BETTERUI.CIM.UnifiedFooter
---@field MODE table<string, number> Footer display modes
BETTERUI.CIM.UnifiedFooter = BETTERUI.CIM.UnifiedFooter or {}

--- Footer display modes
BETTERUI.CIM.UnifiedFooter.MODE = {
    CURRENCY = 1, -- Default mode: Shows capacity + currencies (Inventory)
    BANKING = 2,  -- Banking mode: Shows capacity + currencies + bank-specific info
}

-- ============================================================================
-- CLASS DEFINITION
-- ============================================================================

---@class UnifiedFooterController
---@field control Control The XML control reference
---@field footer Control The footer container
---@field mode number Current display mode
local UnifiedFooterController = ZO_Object:Subclass()

--[[
Function: UnifiedFooterController:New
Description: Creates a new UnifiedFooterController instance.
param: control (Control) - The XML control to manage.
return: UnifiedFooterController
]]
--- @param control Control The XML control to manage
--- @return table UnifiedFooterController instance
function UnifiedFooterController:New(control)
    local obj = ZO_Object.New(self)
    obj:Initialize(control)
    return obj
end

--[[
Function: UnifiedFooterController:Initialize
Description: Initializes the footer controller.
param: control (Control) - The XML control to manage.
]]
function UnifiedFooterController:Initialize(control)
    self.control = control
    self.footer = nil
    self.mode = BETTERUI.CIM.UnifiedFooter.MODE.CURRENCY
    self._initialized = false
end

--[[
Function: UnifiedFooterController:SetupFooter
Description: Links the Lua controller to the XML footer control.
param: footerControl (Control) - The footer container control.
]]
function UnifiedFooterController:SetupFooter(footerControl)
    self.footer = footerControl
    self._initialized = true
end

--[[
Function: UnifiedFooterController:SetMode
Description: Sets the footer display mode and refreshes if needed.
param: mode (number) - One of BETTERUI.CIM.UnifiedFooter.MODE values.
]]
--- @param mode number One of BETTERUI.CIM.UnifiedFooter.MODE values
function UnifiedFooterController:SetMode(mode)
    if self.mode ~= mode then
        self.mode = mode
        self:Refresh()
    end
end

--[[
Function: UnifiedFooterController:GetMode
Description: Returns the current footer display mode.
return: number - Current mode value.
]]
--- @return number mode Current mode value
function UnifiedFooterController:GetMode()
    return self.mode
end

--[[
Function: UnifiedFooterController:Refresh
Description: Refreshes the footer based on current mode.
             Delegates to GenericFooter for currency/capacity updates.
]]
function UnifiedFooterController:Refresh()
    if not self._initialized or not self.footer then return end

    -- Delegate to existing GenericFooter refresh logic
    -- The GenericFooter:Refresh already handles all capacity and currency updates
    local footerData = {
        footer = self.footer,
        control = self.control,
        container = self.control.container or self.control,
    }

    -- Reuse GenericFooter's refresh implementation
    if BETTERUI.GenericFooter and BETTERUI.GenericFooter.Refresh then
        setmetatable(footerData, { __index = BETTERUI.GenericFooter })
        BETTERUI.GenericFooter.Refresh(footerData)
    end

    -- Apply mode-specific visibility/styling if needed
    self:ApplyModeStyles()
end

--[[
Function: UnifiedFooterController:ApplyModeStyles
Description: Applies mode-specific styling or visibility changes.
             Currently both modes show the same elements, but this provides
             an extension point for future differentiation.
]]
function UnifiedFooterController:ApplyModeStyles()
    if not self.footer then return end

    local mode = self.mode
    local MODE = BETTERUI.CIM.UnifiedFooter.MODE

    -- Currently, both modes display the same footer elements.
    -- This function provides an extension point for future mode-specific styling.
    -- For example, Banking mode could highlight bank capacity, or
    -- Inventory mode could show different currency priorities.

    if mode == MODE.BANKING then
        -- Banking-specific styling (if any)
        -- Future: Could emphasize bank capacity or show withdraw/deposit hints
    elseif mode == MODE.CURRENCY then
        -- Currency/Inventory mode styling (if any)
        -- Future: Could prioritize player-relevant currencies
    end
end

--[[
Function: UnifiedFooterController:IsInitialized
Description: Returns whether the footer has been set up.
return: boolean
]]
function UnifiedFooterController:IsInitialized()
    return self._initialized
end

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

BETTERUI.CIM.UnifiedFooter.Controller = UnifiedFooterController

--[[
Function: BETTERUI.CIM.UnifiedFooter.Create
Description: Factory function to create a UnifiedFooterController.
param: control (Control) - The XML control to manage.
return: UnifiedFooterController
]]
--- @param control Control The XML control to manage
--- @return table UnifiedFooterController instance
function BETTERUI.CIM.UnifiedFooter.Create(control)
    return UnifiedFooterController:New(control)
end
