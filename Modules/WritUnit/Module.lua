--[[
File: Modules/WritUnit/Module.lua
Purpose: Entry point for the Writs module.
         Displays daily writ progress when the user interacts with a crafting station.

Key Responsibilities:
  1. Lifecycle Management: Registers event listeners for crafting station interactions.
  2. Event Handling: Responds to interaction start/end and craft completion to toggle UI.
]]


local function SafeExecuteWrits(context, fn, ...)
    local safeExecute = BETTERUI and BETTERUI.CIM and BETTERUI.CIM.SafeExecute
    if safeExecute then
        return safeExecute(context, fn, ...)
    end
    -- CIM.SafeExecute unavailable — fail safely instead of calling fn() unprotected
    d("[BetterUI] Writs: SafeExecute unavailable for " .. tostring(context))
    return false, "safe_execute_unavailable"
end

local function IsWritsModuleEnabled()
    return BETTERUI.GetModuleEnabled("Writs")
end

--- Shows the writ overlay when the player enters a crafting station.
local function OnCraftStation(_, craftId)
    if not IsWritsModuleEnabled() then return end

    local id = craftId and tonumber(craftId)
    if not id then return end

    SafeExecuteWrits("Writs:OnCraftStation", BETTERUI.Writs.Show, id)
end

--- Hides the writ overlay when the player leaves a crafting station.
local function OnCloseCraftStation(_)
    SafeExecuteWrits("Writs:OnCloseCraftStation", BETTERUI.Writs.Hide)
end

--- Refreshes writ progress after an item is crafted.
local function OnCraftItem(_, craftId)
    if not IsWritsModuleEnabled() then return end

    local id = craftId and tonumber(craftId)
    if not id then return end

    SafeExecuteWrits("Writs:OnCraftItem", BETTERUI.Writs.Show, id)
end

--- Creates the writ panel and registers its station event handlers.
---@return nil
function BETTERUI.Writs.Setup()
    local tlw = BETTERUI.WindowManager:CreateTopLevelWindow("BETTERUI_Writs_TLW")
    local BETTERUI_WP = BETTERUI.WindowManager:CreateControlFromVirtual("BETTERUI_WritsPanel", tlw, "BETTERUI_WritsPanel")

    -- Use module-scoped namespace to avoid collision with other modules registering for the same events
    local writsNamespace = BETTERUI.name .. "_Writs"
    EVENT_MANAGER:RegisterForEvent(writsNamespace, EVENT_CRAFTING_STATION_INTERACT, OnCraftStation)
    EVENT_MANAGER:RegisterForEvent(writsNamespace, EVENT_END_CRAFTING_STATION_INTERACT, OnCloseCraftStation)
    EVENT_MANAGER:RegisterForEvent(writsNamespace, EVENT_CRAFT_COMPLETED, OnCraftItem)

    -- Cache control references so Show()/Hide() can use fast local vars
    BETTERUI.Writs.CacheControls()

    BETTERUI_WP:SetHidden(true)
end
