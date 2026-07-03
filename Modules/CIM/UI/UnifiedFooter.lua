--[[
File: Modules/CIM/UI/UnifiedFooter.lua
Purpose: Unified footer controller with mode switching.
         Extends GenericFooter to support different display modes for Inventory vs Banking.
]]

-- CONSTANTS

BETTERUI.CIM.UnifiedFooter = BETTERUI.CIM.UnifiedFooter or {}

--- Footer display modes
BETTERUI.CIM.UnifiedFooter.MODE = {
    CURRENCY = 1, -- Default mode: Shows capacity + currencies (Inventory)
    BANKING = 2,  -- Banking mode: Shows capacity + currencies + bank-specific info
}

-- CLASS DEFINITION

local UnifiedFooterController = ZO_Object:Subclass()

---@param control table
---@return table
function UnifiedFooterController:New(control)
    local obj = ZO_Object.New(self)
    obj:Initialize(control)
    return obj
end

---@param control table
---@return nil
function UnifiedFooterController:Initialize(control)
    self.control = control
    self.footer = nil
    self.mode = BETTERUI.CIM.UnifiedFooter.MODE.CURRENCY
    self._initialized = false
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.FOOTER, "unified footer init", { controlName = control and control.GetName and control:GetName() or "nil" })
    end
end

---@param footerControl table
---@return nil
function UnifiedFooterController:SetupFooter(footerControl)
    self.footer = footerControl
    self._initialized = true
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.FOOTER, "unified footer setup", { controlName = footerControl and footerControl.GetName and footerControl:GetName() or "nil" })
    end
end

---@param mode integer
---@return nil
function UnifiedFooterController:SetMode(mode)
    if self.mode ~= mode then
        local oldMode = self.mode
        self.mode = mode
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.FOOTER, "unified footer set mode", { oldMode = oldMode, newMode = mode })
        end
        self:Refresh()
    end
end

--- Refreshes the footer based on current mode.
function UnifiedFooterController:Refresh()
    if not self._initialized or not self.footer then
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.FOOTER, "unified footer refresh skipped", { initialized = self._initialized == true, hasFooter = self.footer ~= nil })
        end
        return
    end

    -- Delegate to existing GenericFooter refresh logic
    -- The GenericFooter:Refresh already handles all capacity and currency updates
    local footerData = {
        footer = self.footer,
        control = self.control,
        container = self.control.container or self.control,
    }

    -- Reuse GenericFooter's refresh implementation
    local refreshFn = BETTERUI.GenericFooter and BETTERUI.GenericFooter.Refresh
    if type(refreshFn) == "function" then
        setmetatable(footerData, { __index = BETTERUI.GenericFooter })
        refreshFn(footerData)
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.FOOTER, "unified footer refresh", { mode = self.mode })
        end
    else
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.FOOTER, "unified footer refresh no fn")
        end
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

-- MODULE REGISTRATION

BETTERUI.CIM.UnifiedFooter.Controller = UnifiedFooterController

---@param control table
---@return table
function BETTERUI.CIM.UnifiedFooter.Create(control)
    return UnifiedFooterController:New(control)
end
