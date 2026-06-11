---@type BetterUIModuleRoot
BETTERUI.Writs = BETTERUI.Writs or {}
local Writs = BETTERUI.Writs
local ARCHETYPES = BETTERUI.CIM and BETTERUI.CIM.ARCHETYPES or {}
local THIN_ENTRYPOINT = ARCHETYPES.THIN_ENTRYPOINT or "thin-entrypoint"

---@type BetterUIModuleArchetypeThinEntrypoint
Writs.ARCHETYPE = THIN_ENTRYPOINT
---@type BetterUIModuleRootContract
Writs.ROOT_CONTRACT = {
    name = "Writs",
    archetype = Writs.ARCHETYPE,
    init = true,
    setup = true,
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
    d("[BetterUI] Writs: SafeExecute unavailable for " .. tostring(context))
    return false, "safe_execute_unavailable"
end

local function IsWritsModuleEnabled()
    return BETTERUI.GetModuleEnabled("Writs")
end

local function OnCraftStation(_, craftId)
    if not IsWritsModuleEnabled() then return end

    local id = craftId and tonumber(craftId)
    if not id then return end

    SafeExecuteWrits("Writs:OnCraftStation", BETTERUI.Writs.ShowForCraftType, id)
end

local function OnCloseCraftStation(_)
    SafeExecuteWrits("Writs:OnCloseCraftStation", BETTERUI.Writs.HidePanel)
end

local function OnCraftItem(_, craftId)
    if not IsWritsModuleEnabled() then return end

    local id = craftId and tonumber(craftId)
    if not id then return end

    SafeExecuteWrits("Writs:OnCraftItem", BETTERUI.Writs.ShowForCraftType, id)
end

---@param m_options BetterUIModuleOptions|nil Module options table
---@return BetterUIModuleOptions m_options Initialized options with defaults applied
---@type BetterUIModuleInitHook
function Writs.InitModule(m_options)
    m_options = m_options or {}
    ---@cast m_options BetterUIModuleOptions
    return ApplyWritsDefaults(m_options)
end

---@type BetterUIModuleSetupHook
function Writs.Setup()
    local tlw = BETTERUI.WindowManager:CreateTopLevelWindow("BETTERUI_Writs_TLW")
    local BETTERUI_WP = BETTERUI.WindowManager:CreateControlFromVirtual("BETTERUI_WritsPanel", tlw, "BETTERUI_WritsPanel")

    local writsNamespace = BETTERUI.name .. "_Writs"
    BETTERUI.CIM.EventRegistry.Register("Writs", writsNamespace, EVENT_CRAFTING_STATION_INTERACT, OnCraftStation)
    BETTERUI.CIM.EventRegistry.Register("Writs", writsNamespace, EVENT_END_CRAFTING_STATION_INTERACT, OnCloseCraftStation)
    BETTERUI.CIM.EventRegistry.Register("Writs", writsNamespace, EVENT_CRAFT_COMPLETED, OnCraftItem)

    Writs.CacheControls()

    BETTERUI_WP:SetHidden(true)
end
