--[[
File: Modules/Inventory/Core/MixinLoader.lua
Purpose: Centralized loader for applying mixins to the Inventory Class.
         Ensures mixins are applied AFTER all files have been loaded.
]]

if not BETTERUI.Inventory then BETTERUI.Inventory = {} end

-- Purpose: Apply all registered mixins to BETTERUI.Inventory.Class
-- Called via BetterUI.txt load order AFTER all mixin files
--- Applies all registered mixins to the Inventory Class.
--- @return nil
function BETTERUI.Inventory.ApplyAllMixins()
    if not BETTERUI.Inventory.ClassMixins then return end

    if not BETTERUI.Inventory.Class then
        BETTERUI.Debug("[BetterUI] Error: Inventory Class not initialized before applying mixins")
        return
    end

    for name, func in pairs(BETTERUI.Inventory.ClassMixins) do
        BETTERUI.Inventory.Class[name] = func
    end

    -- Clear to prevent double-application
    BETTERUI.Inventory.ClassMixins = nil
end
