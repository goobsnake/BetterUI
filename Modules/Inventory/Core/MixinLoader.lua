--[[
File: Modules/Inventory/Core/MixinLoader.lua
Purpose: Centralized loader for applying mixins to the Inventory Class.
         Ensures mixins are applied AFTER all files have been loaded.
]]

if not BETTERUI.Inventory then BETTERUI.Inventory = {} end

-- Purpose: Apply all registered mixins to BETTERUI.Inventory.Class
-- Called during InventoryClass:Initialize after the current module load set is present.
--- Applies all registered mixins to the Inventory Class.
---@return nil
function BETTERUI.Inventory.ApplyAllMixins()
    BETTERUI.Inventory.ClassMixins = BETTERUI.Inventory.ClassMixins or {}

    if not BETTERUI.Inventory.Class then
        BETTERUI.Debug("[BetterUI] Error: Inventory Class not initialized before applying mixins")
        return
    end

    for name, func in pairs(BETTERUI.Inventory.ClassMixins) do
        BETTERUI.Inventory.Class[name] = func
    end

    if type(BETTERUI.Inventory.SEARCH_LIFECYCLE) == "table" then
        BETTERUI.Inventory.Class.SEARCH_LIFECYCLE = BETTERUI.Inventory.SEARCH_LIFECYCLE
    end

    BETTERUI.Inventory._mixinsApplied = true
end
