--[[
File: Modules/CIM/Actions/GenericSlotActions.lua
Purpose: Shared slot action logic for Inventory and Banking modules.
         Provides abstractions for common item actions (split stack, link to chat, etc.).
Author: BetterUI Team
Last Modified: 2026-01-26
]]

local _

if not BETTERUI.CIM then BETTERUI.CIM = {} end

--[[
Class: BETTERUI.CIM.GenericSlotActions
Description: Base class for slot action management.
]]
BETTERUI.CIM.GenericSlotActions = ZO_Object:Subclass()

function BETTERUI.CIM.GenericSlotActions:New(...)
    local obj = ZO_Object.New(self)
    obj:Initialize(...)
    return obj
end

function BETTERUI.CIM.GenericSlotActions:Initialize()
    self.actions = {}
end

--[[
Function: BETTERUI.CIM.GenericSlotActions:AddAction
Description: Adds an action to the available actions list.
]]
function BETTERUI.CIM.GenericSlotActions:AddAction(name, callback)
    table.insert(self.actions, { name = name, callback = callback })
end

--[[
Function: BETTERUI.CIM.GenericSlotActions:ClearActions
Description: Clears all registered actions.
]]
function BETTERUI.CIM.GenericSlotActions:ClearActions()
    self.actions = {}
end
