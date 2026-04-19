--[[
File: Modules/Vendor/Core/VendorComponentCatalog.lua
Purpose: Own mode-to-component wiring so Vendor.lua stays focused on runtime orchestration.
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}
local Vendor = BETTERUI.Vendor
Vendor.ComponentCatalog = Vendor.ComponentCatalog or {}
local ComponentCatalog = Vendor.ComponentCatalog

local MODE = assert(Vendor.MODE, "Vendor mode constants must load before component catalog")

---@return table[]
function ComponentCatalog.BuildComponentRegistrations()
    return {
        { mode = MODE.BUY, component = Vendor.BuyComponent },
        { mode = MODE.SELL, component = Vendor.SellComponent },
        { mode = MODE.SELL_VENGEANCE, component = Vendor.SellVengeanceComponent },
        { mode = MODE.REPAIR, component = Vendor.RepairComponent },
        { mode = MODE.STABLE, component = Vendor.StableTrainingComponent },
        { mode = MODE.BUYBACK, component = Vendor.BuybackComponent },
        { mode = MODE.FENCE_SELL, component = Vendor.FenceSellComponent },
        { mode = MODE.FENCE_LAUNDER, component = Vendor.FenceLaunderComponent },
    }
end

---@param instance BETTERUI.Vendor.Class
---@return nil
function ComponentCatalog.Register(instance)
    if not (instance and instance.RegisterComponent) then
        return
    end

    for _, registration in ipairs(ComponentCatalog.BuildComponentRegistrations()) do
        if registration.component then
            instance:RegisterComponent(registration.mode, registration.component)
        end
    end
end
