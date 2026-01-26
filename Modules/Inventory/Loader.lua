--[[
File: Modules/Inventory/Loader.lua
Purpose: Central loader for the Inventory module.
         Initializes the namespace and sets up forward declarations
         to handle cross-file dependencies in the decomposed structure.
Author: BetterUI Team
Last Modified: 2026-01-24
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
BETTERUI.Inventory._forward = {
    -- State
    SaveListPosition = nil,
    ToSavedPosition = nil,

    -- Actions
    TryEquipItem = nil,
    TryDestroyItem = nil,

    -- Lists
    RefreshItemList = nil,
    RefreshCraftBagList = nil,
    RefreshCategoryList = nil,
}

-- Registry for Class functions to be injected later
-- This allows us to define class methods in separate files before the class is fully instantiated
BETTERUI.Inventory.ClassMixins = {}

function BETTERUI.Inventory.RegisterMixin(name, func)
    BETTERUI.Inventory.ClassMixins[name] = func
end
