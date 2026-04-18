--[[
File: Modules/Inventory/Loader.lua
Purpose: Central loader for the Inventory module.
         Initializes the namespace and sets up forward declarations
         to handle cross-file dependencies in the decomposed structure.
]]

if not BETTERUI then BETTERUI = {} end
if not BETTERUI.Inventory then BETTERUI.Inventory = {} end

-- Initialize Sub-namespaces
BETTERUI.Inventory.Actions = {}
BETTERUI.Inventory.Lists = {}
BETTERUI.Inventory.Keybinds = {}
BETTERUI.Inventory.State = {}
BETTERUI.Inventory.Core = {}
BETTERUI.Inventory.UI = {}
BETTERUI.Inventory.Settings = {}

-- Forward declarations for cross-module communication
-- These will be populated by the respective files as they load


-- Registry for Class functions to be injected later.
-- Mixins stay registered after the first apply so late registrations can be
-- applied immediately without depending on fragile file-order assumptions.
BETTERUI.Inventory.ClassMixins = BETTERUI.Inventory.ClassMixins or {}
BETTERUI.Inventory._mixinsApplied = BETTERUI.Inventory._mixinsApplied == true

--- Registers a mixin to be applied to the Inventory class.
---@param name string Mixin function name
---@param func function Mixin function implementation
---@return nil
function BETTERUI.Inventory.RegisterMixin(name, func)
    BETTERUI.Inventory.ClassMixins = BETTERUI.Inventory.ClassMixins or {}
    BETTERUI.Inventory.ClassMixins[name] = func

    if BETTERUI.Inventory._mixinsApplied and BETTERUI.Inventory.Class then
        BETTERUI.Inventory.Class[name] = func
    end
end
