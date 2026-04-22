--[[
File: Modules/Vendor/Core/VendorComponentCatalog.lua
Purpose: Own mode-to-component wiring so Vendor.lua stays focused on runtime orchestration.
]]

BETTERUI.Vendor = BETTERUI.Vendor or {}
local Vendor = BETTERUI.Vendor

-- CATALOG TABLE
Vendor.ComponentCatalog = Vendor.ComponentCatalog or {}
local ComponentCatalog = Vendor.ComponentCatalog

local MODE = assert(Vendor.MODE, "Vendor mode constants must load before component catalog")
local COMPONENT_REGISTRATIONS = {
    { mode = MODE.BUY, componentKey = "BuyComponent", name = "Vendor.BuyComponent" },
    { mode = MODE.SELL, componentKey = "SellComponent", name = "Vendor.SellComponent" },
    { mode = MODE.SELL_VENGEANCE, componentKey = "SellVengeanceComponent", name = "Vendor.SellVengeanceComponent" },
    { mode = MODE.REPAIR, componentKey = "RepairComponent", name = "Vendor.RepairComponent" },
    { mode = MODE.STABLE, componentKey = "StableTrainingComponent", name = "Vendor.StableTrainingComponent" },
    { mode = MODE.BUYBACK, componentKey = "BuybackComponent", name = "Vendor.BuybackComponent" },
    { mode = MODE.FENCE_SELL, componentKey = "FenceSellComponent", name = "Vendor.FenceSellComponent" },
    { mode = MODE.FENCE_LAUNDER, componentKey = "FenceLaunderComponent", name = "Vendor.FenceLaunderComponent" },
}

local function LogCatalogIssue(message, componentName, mode)
    if Vendor.LogDebug then
        local context = componentName or "Vendor.ComponentCatalog"
        if mode then
            context = context .. " (mode " .. tostring(mode) .. ")"
        end
        Vendor.LogDebug("VENDOR_COMPONENT_CATALOG", context, message)
    end
end

local function IsValidRegistration(registration)
    if type(registration) ~= "table" then
        return false
    end
    if type(registration.mode) ~= "number" then
        return false
    end
    if type(registration.componentKey) ~= "string" or registration.componentKey == "" then
        return false
    end
    return true
end

---@param instance BETTERUI.Vendor.Class
---@return nil
function ComponentCatalog.Register(instance)
    if not (instance and instance.RegisterComponent and type(instance.RegisterComponent) == "function") then
        return
    end

    local seenModes = {}
    for _, registration in ipairs(COMPONENT_REGISTRATIONS) do
        if not IsValidRegistration(registration) then
            LogCatalogIssue("Skipping invalid vendor component registration entry", registration and registration.name, registration and registration.mode)
        else
            local component = Vendor[registration.componentKey]
            local mode = registration.mode
            if seenModes[mode] then
                LogCatalogIssue("Skipping duplicate vendor component mode registration", registration.name, mode)
            elseif type(component) ~= "table" then
                LogCatalogIssue("Skipping missing vendor component registration", registration.name, mode)
            else
                instance:RegisterComponent(mode, component)
                seenModes[mode] = registration.name or true
            end
        end
    end
end
