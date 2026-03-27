--[[
File: Modules/WritUnit/Module.lua
Purpose: Entry point for the Writ tracking module.
         Displays daily writ progress when the user interacts with a crafting station.
Author: BetterUI Team
Last Modified: 2026-01-28

Key Responsibilities:
  1. Lifecycle Management: Registers event listeners for crafting station interactions.
  2. Event Handling: Responds to interaction start/end and craft completion to toggle UI.
]]


local function SafeExecuteWrits(context, fn, ...)
    local safeExecute = BETTERUI and BETTERUI.CIM and BETTERUI.CIM.SafeExecute
    if safeExecute then
        return safeExecute(context, fn, ...)
    end
    return fn(...)
end

local function IsWritsModuleEnabled()
    local modules = BETTERUI and BETTERUI.Settings and BETTERUI.Settings.Modules
    local writsSettings = modules and modules["Writs"]
    return writsSettings and writsSettings.m_enabled == true
end

--- Initializes the Writs module settings.
---
--- Purpose: Callback for module initialization.
--- Mechanics: Pass-through; module is controlled by Master Settings m_enabled.
---
--- @param m_options table The module options table.
--- @return table The initialized options table.
function BETTERUI.Writs.InitModule(m_options)
    return m_options
end

--- Event handler for crafting station interaction (Start).
---
--- Purpose: Triggered when user enters a crafting station.
--- Mechanics: Calls BETTERUI.Writs.Show with the station's craft ID.
--- Note: eventCode check removed - ESO events never pass 0.
---
--- @param eventCode number The event code (unused but required by ESO API).
--- @param craftId number The crafting station ID (e.g., CRAFTING_TYPE_BLACKSMITHING).
--- @param sameStation boolean Whether interacting with same station type.
--- @return nil
local function OnCraftStation(eventCode, craftId, sameStation)
    if not IsWritsModuleEnabled() then return end

    local id = craftId and tonumber(craftId)
    if not id then return end

    SafeExecuteWrits("Writs:OnCraftStation", BETTERUI.Writs.Show, id)
end

--- Event handler for crafting station interaction (End).
---
--- Purpose: Triggered when user exits a crafting station.
--- Mechanics: Calls `BETTERUI.Writs.Hide` to remove the overlay.
---
--- @param eventCode number The event code.
--- @return nil
local function OnCloseCraftStation(eventCode)
    SafeExecuteWrits("Writs:OnCloseCraftStation", BETTERUI.Writs.Hide)
end

--- Event handler for crafting completion.
---
--- Purpose: Triggered when an item is crafted.
--- Mechanics: Calls BETTERUI.Writs.Show to refresh progress (e.g., 1/3 -> 2/3).
--- Note: eventCode check removed - ESO events never pass 0.
---
--- @param eventCode number The event code (unused but required by ESO API).
--- @param craftId number The crafting ID (usually matching the station type).
--- @return nil
local function OnCraftItem(eventCode, craftId)
    if not IsWritsModuleEnabled() then return end

    local id = craftId and tonumber(craftId)
    if not id then return end

    SafeExecuteWrits("Writs:OnCraftItem", BETTERUI.Writs.Show, id)
end

-- Sets up Writs module: creates UI and registers event handlers
--- Sets up the Writs module.
---
--- Purpose: Module Entry Point.
--- Mechanics:
--- 1. Creates top-level `BETTERUI_Writs_TLW`.
--- 2. Instantiates `BETTERUI_WritsPanel` from template.
--- 3. Registers callbacks for Station Interact (Start/End) and Craft Completed.
--- 4. Hides panel initially.
--- References: Called from `BetterUI.lua` during addon initialization.
--- @return nil
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
