--[[
File: Modules/CIM/Core/UnifiedScreen.lua
Purpose: Unified base class for Inventory and Banking screens.
         Provides common functionality including:
         - Footer mode switching (CURRENCY vs BANKING)
         - Shared initialization patterns
         - Common refresh hooks
Author: BetterUI Team
Last Modified: 2026-01-28
]]

-- ============================================================================
-- CLASS: BETTERUI.CIM.UnifiedScreen
-- Common parent for Inventory and Banking implementing shared patterns.
-- ============================================================================

---@class BETTERUI.CIM.UnifiedScreen : BETTERUI_Gamepad_ParametricList_Screen
BETTERUI.CIM.UnifiedScreen = BETTERUI_Gamepad_ParametricList_Screen:Subclass()

local MODE = BETTERUI.CIM.UnifiedFooter.MODE

--[[
Function: BETTERUI.CIM.UnifiedScreen:New
Description: Creates a new UnifiedScreen instance.
return: UnifiedScreen
]]
function BETTERUI.CIM.UnifiedScreen:New(...)
    local object = BETTERUI_Gamepad_ParametricList_Screen.New(self)
    object:Initialize(...)
    return object
end

--[[
Function: BETTERUI.CIM.UnifiedScreen:Initialize
Description: Initializes the screen with unified footer support.
param: control (Control) - The screen control.
param: createTabBar (boolean) - Whether to create tab bar.
param: activateOnShow (boolean) - Whether to activate on show.
param: scene (Scene) - The scene to associate.
param: footerMode (number) - Initial footer mode (MODE.CURRENCY or MODE.BANKING).
]]
function BETTERUI.CIM.UnifiedScreen:Initialize(control, createTabBar, activateOnShow, scene, footerMode)
    BETTERUI_Gamepad_ParametricList_Screen.Initialize(self, control, createTabBar, activateOnShow, scene)

    -- Default to CURRENCY mode if not specified
    self.footerMode = footerMode or MODE.CURRENCY

    -- Cache footer controller reference
    self.unifiedFooterController = nil

    -- Setup footer after initialization
    self:SetupUnifiedFooter()
end

--[[
Function: BETTERUI.CIM.UnifiedScreen:SetupUnifiedFooter
Description: Links to the UnifiedFooter controller and sets initial mode.
]]
function BETTERUI.CIM.UnifiedScreen:SetupUnifiedFooter()
    local footerContainer = self.control.container and self.control.container:GetNamedChild("FooterContainer")
    if footerContainer and footerContainer.unifiedFooter then
        self.unifiedFooterController = footerContainer.unifiedFooter
        self.unifiedFooterController:SetMode(self.footerMode)
    end
end

--[[
Function: BETTERUI.CIM.UnifiedScreen:SetFooterMode
Description: Changes the footer display mode.
param: mode (number) - MODE.CURRENCY or MODE.BANKING
]]
function BETTERUI.CIM.UnifiedScreen:SetFooterMode(mode)
    self.footerMode = mode
    if self.unifiedFooterController then
        self.unifiedFooterController:SetMode(mode)
    end
end

--[[
Function: BETTERUI.CIM.UnifiedScreen:GetFooterMode
Description: Returns the current footer mode.
return: number
]]
function BETTERUI.CIM.UnifiedScreen:GetFooterMode()
    return self.footerMode
end

--[[
Function: BETTERUI.CIM.UnifiedScreen:RefreshFooter
Description: Triggers a footer content refresh.
]]
function BETTERUI.CIM.UnifiedScreen:RefreshFooter()
    if self.unifiedFooterController then
        self.unifiedFooterController:Refresh()
    end
end

--[[
Function: BETTERUI.CIM.UnifiedScreen:OnShowing
Description: Called when screen is about to show. Sets footer mode.
]]
function BETTERUI.CIM.UnifiedScreen:OnShowing()
    -- Ensure footer controller is set up
    if not self.unifiedFooterController then
        self:SetupUnifiedFooter()
    end

    -- Apply footer mode when showing
    if self.unifiedFooterController then
        self.unifiedFooterController:SetMode(self.footerMode)
    end
end

--[[
Function: BETTERUI.CIM.UnifiedScreen:OnHiding
Description: Called when screen is about to hide.
             Override in subclasses for cleanup.
]]
function BETTERUI.CIM.UnifiedScreen:OnHiding()
    -- Subclasses can override for cleanup
end

-- ============================================================================
-- EXPORTED MODE CONSTANTS (Convenience)
-- ============================================================================

BETTERUI.CIM.UnifiedScreen.FOOTER_MODE_CURRENCY = MODE.CURRENCY
BETTERUI.CIM.UnifiedScreen.FOOTER_MODE_BANKING = MODE.BANKING
