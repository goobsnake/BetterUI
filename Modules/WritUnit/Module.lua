---------------------------------------------------------------------------------------------------
-- BetterUI - Writ Module
--
-- File: Modules/WritUnit/Module.lua
-- Purpose: Entry point for the Writ tracking module.
--
-- This module displays daily writ progress when the user interacts with a crafting station.
-- It listens for crafting events and updates a custom UI panel with the current writ requirements.
--
-- KEY RESPONSIBILITIES:
-- 1.  **Lifecycle Management**: Registers event listeners for crafting station interactions.
-- 2.  **Event Handling**: Responses to interaction start/end and craft completion to toggle UI.
--

---------------------------------------------------------------------------------------------------


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
local function OnCraftStation(eventCode, craftId, sameStation)
    if BETTERUI.Settings.Modules["Writs"] and BETTERUI.Settings.Modules["Writs"].m_enabled then
        BETTERUI.Writs.Show(tonumber(craftId))
    end
end

--- Event handler for crafting station interaction (End).
---
--- Purpose: Triggered when user exits a crafting station.
--- Mechanics: Calls `BETTERUI.Writs.Hide` to remove the overlay.
---
--- @param eventCode number The event code.
local function OnCloseCraftStation(eventCode)
    BETTERUI.Writs.Hide()
end

--- Event handler for crafting completion.
---
--- Purpose: Triggered when an item is crafted.
--- Mechanics: Calls BETTERUI.Writs.Show to refresh progress (e.g., 1/3 -> 2/3).
--- Note: eventCode check removed - ESO events never pass 0.
---
--- @param eventCode number The event code (unused but required by ESO API).
--- @param craftId number The crafting ID (usually matching the station type).
local function OnCraftItem(eventCode, craftId)
    if BETTERUI.Settings.Modules["Writs"] and BETTERUI.Settings.Modules["Writs"].m_enabled then
        BETTERUI.Writs.Show(tonumber(craftId))
    end
end

-- Sets up Writs module: creates UI and registers event handlers
--- Sets up the Writs module.
---
--- Purpose: Module Entry Point.
--- Mechanics:
--- 1. Creates top-level `BETTERUI_TLW`.
--- 2. Instantiates `BETTERUI_WritsPanel` from template.
--- 3. Registers callbacks for Station Interact (Start/End) and Craft Completed.
--- 4. Hides panel initially.
--- References: Called from `BetterUI.lua` during addon initialization.
---
function BETTERUI.Writs.Setup()
    local tlw = BETTERUI.WindowManager:CreateTopLevelWindow("BETTERUI_TLW")
    local BETTERUI_WP = BETTERUI.WindowManager:CreateControlFromVirtual("BETTERUI_WritsPanel", tlw, "BETTERUI_WritsPanel")

    EVENT_MANAGER:RegisterForEvent(BETTERUI.name, EVENT_CRAFTING_STATION_INTERACT, OnCraftStation)
    EVENT_MANAGER:RegisterForEvent(BETTERUI.name, EVENT_END_CRAFTING_STATION_INTERACT, OnCloseCraftStation)
    EVENT_MANAGER:RegisterForEvent(BETTERUI.name, EVENT_CRAFT_COMPLETED, OnCraftItem)

    BETTERUI_WP:SetHidden(true)
end
