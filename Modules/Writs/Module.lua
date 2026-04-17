--[[
File: Modules/Writs/Module.lua
Purpose: Entry point for the Writs module.
         Displays daily writ progress when the user interacts with a crafting station.

Key Responsibilities:
  1. Lifecycle Management: Registers event listeners for crafting station interactions.
  2. Event Handling: Responds to interaction start/end and craft completion to toggle UI.
]]


---@type BetterUIModuleRoot
BETTERUI.Writs = BETTERUI.Writs or {}
local Writs = BETTERUI.Writs

Writs.ARCHETYPE = "thin-entrypoint"
---@type BetterUIModuleRootContract
Writs.ROOT_CONTRACT = {
    name = "Writs",
    archetype = Writs.ARCHETYPE,
    initOwner = "Modules/Writs/Module.lua",
    setupOwner = "Modules/Writs/Module.lua",
    runtimeOwner = "Modules/Writs/Module.lua + Modules/Writs/Core/Writ.lua",
    settingsOwner = "Modules/CIM/Core/Settings/DefaultsRegistry.lua",
    notes = "Module.lua owns the Writs entrypoint contract and crafting-station event wiring, while Core/Writ.lua formats active writ state and DefaultsRegistry remains the canonical settings owner.",
}

local function ApplyWritsDefaults(m_options)
    local defaultsApi = BETTERUI.Defaults
    if defaultsApi and type(defaultsApi.ApplyModuleDefaults) == "function" then
        return defaultsApi.ApplyModuleDefaults("Writs", m_options)
    end

    local moduleDefaults = defaultsApi and type(defaultsApi.GetModuleDefaults) == "function"
        and defaultsApi.GetModuleDefaults("Writs") or nil
    if type(moduleDefaults) == "table" then
        for key, value in pairs(moduleDefaults) do
            if m_options[key] == nil then
                m_options[key] = value
            end
        end
    end

    return m_options
end

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

--- Initializes defaults and migrates legacy settings for the Writs module.
---
--- INIT CONTRACT: This function implements the standard InitModule signature.
--- It is called by BETTERUI.ModuleOptions() via pcall with only m_options.
---
---@param m_options BetterUIModuleOptions|nil Module options table
---@return BetterUIModuleOptions m_options Initialized options with defaults applied
---@type BetterUIModuleInitHook
function Writs.InitModule(m_options)
    m_options = m_options or {}
    ---@cast m_options BetterUIModuleOptions
    return ApplyWritsDefaults(m_options)
end

--- Creates the writ panel and registers its station event handlers.
---@return nil
---@type BetterUIModuleSetupHook
function Writs.Setup()
    local tlw = BETTERUI.WindowManager:CreateTopLevelWindow("BETTERUI_Writs_TLW")
    local BETTERUI_WP = BETTERUI.WindowManager:CreateControlFromVirtual("BETTERUI_WritsPanel", tlw, "BETTERUI_WritsPanel")

    -- Use module-scoped namespace to avoid collision with other modules registering for the same events
    local writsNamespace = BETTERUI.name .. "_Writs"
    EVENT_MANAGER:RegisterForEvent(writsNamespace, EVENT_CRAFTING_STATION_INTERACT, OnCraftStation)
    EVENT_MANAGER:RegisterForEvent(writsNamespace, EVENT_END_CRAFTING_STATION_INTERACT, OnCloseCraftStation)
    EVENT_MANAGER:RegisterForEvent(writsNamespace, EVENT_CRAFT_COMPLETED, OnCraftItem)

    -- Cache control references so Show()/Hide() can use fast local vars
    Writs.CacheControls()

    BETTERUI_WP:SetHidden(true)
end
