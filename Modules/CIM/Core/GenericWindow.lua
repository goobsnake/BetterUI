--[[
File: Modules/CIM/Core/GenericWindow.lua
Purpose: A specialized base class for Inventory-like windows (Banking, Backpack).
         Inherits from BETTERUI.Interface.Window and adds shared inventory behaviors.
Author: BetterUI Team
Last Modified: 2026-01-26
]]

local _

if not BETTERUI.CIM then BETTERUI.CIM = {} end

--[[
Class: BETTERUI.CIM.GenericWindow
Description: Intermediate base class for Inventory and Banking windows.
Rationale: Shared logic for category management, list focus, and common inventory patterns.
]]
BETTERUI.CIM.GenericWindow = BETTERUI.Interface.Window:Subclass()

--[[
Function: BETTERUI.CIM.GenericWindow:New
Description: Constructor.
]]
function BETTERUI.CIM.GenericWindow:New(...)
    return BETTERUI.Interface.Window.New(self, ...)
end

--[[
Function: BETTERUI.CIM.GenericWindow:Initialize
Description: Initialize the generic inventory window.
]]
function BETTERUI.CIM.GenericWindow:Initialize(tlw_name, scene_name)
    BETTERUI.Interface.Window.Initialize(self, tlw_name, scene_name)
    -- Additional common initialization can go here
end

--[[
Function: BETTERUI.CIM.GenericWindow:UpdateHeaderTitle
Description: Placeholder for updating header title based on category.
]]
function BETTERUI.CIM.GenericWindow:UpdateHeaderTitle()
    -- Subclasses should override
end

--[[
Function: BETTERUI.CIM.GenericWindow:RefreshFooter
Description: Placeholder for updating footer info.
]]
function BETTERUI.CIM.GenericWindow:RefreshFooter()
    -- Subclasses should override
end
