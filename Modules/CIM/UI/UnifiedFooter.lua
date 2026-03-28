--[[
File: Modules/CIM/UI/UnifiedFooter.lua
Purpose: Unified footer controller with mode switching.
         Extends GenericFooter to support different display modes for Inventory vs Banking.
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

--- @param control Control The XML control to manage
--- @return table UnifiedFooterController instance
function UnifiedFooterController:New(control)
    local obj = ZO_Object.New(self)
    obj:Initialize(control)
    return obj
end

--- @param control Control The XML control to manage
function UnifiedFooterController:Initialize(control)
    self.control = control
    self.footer = nil
    self.mode = BETTERUI.CIM.UnifiedFooter.MODE.CURRENCY
    self._initialized = false
end

--- @param footerControl Control The footer container control
function UnifiedFooterController:SetupFooter(footerControl)
    self.footer = footerControl
    self._initialized = true
end

--- @param mode number One of BETTERUI.CIM.UnifiedFooter.MODE values
function UnifiedFooterController:SetMode(mode)
    if self.mode ~= mode then
        self.mode = mode
        self:Refresh()
    end
end

--- @return number mode Current mode value
function UnifiedFooterController:GetMode()
    return self.mode
end

--- Refreshes the footer based on current mode.
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

--- Applies mode-specific styling or visibility changes.
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

--- @return boolean initialized Whether the footer has been set up
function UnifiedFooterController:IsInitialized()
    return self._initialized
end

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

BETTERUI.CIM.UnifiedFooter.Controller = UnifiedFooterController

--- @param control Control The XML control to manage
--- @return table UnifiedFooterController instance
function BETTERUI.CIM.UnifiedFooter.Create(control)
    return UnifiedFooterController:New(control)
end
