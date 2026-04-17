--[[
    Module: General Interface
    Purpose: Tooltip enhancements, market price integration, and nameplate customization.

    Structure:
      Tooltips/     - Market price hooks (TTC/MM/ATT), research trait display, settings
      Nameplates/   - Font customization for ESO nameplates
      Setup.lua     - Module Setup() lifecycle and LAM panel aggregation

    Namespaces: BETTERUI.GeneralInterface (tooltips), BETTERUI.Nameplates (font hooks)
    Dependencies: CIM (cross-cutting utilities via TryCall/TryResolve)
]]

if BETTERUI == nil then BETTERUI = {} end
if BETTERUI.GeneralInterface == nil then BETTERUI.GeneralInterface = {} end

local GeneralInterface = BETTERUI.GeneralInterface

GeneralInterface.ARCHETYPE = "thin-entrypoint"
---@type BetterUIModuleRootContract
GeneralInterface.ROOT_CONTRACT = {
    name = "GeneralInterface",
    archetype = GeneralInterface.ARCHETYPE,
    initOwner = "Modules/GeneralInterface/Module.lua",
    setupOwner = "Modules/GeneralInterface/Setup.lua",
    runtimeOwner = "Modules/GeneralInterface/Tooltips/ + Modules/GeneralInterface/Nameplates/",
    settingsOwner = "Modules/GeneralInterface/Module.lua + Modules/GeneralInterface/Setup.lua",
    notes = "Module.lua owns defaults, while Setup.lua aggregates settings and runtime hooks from Tooltips/ and Nameplates/.",
}

--- Initializes General Interface default settings.
---@param m_options BetterUIModuleOptions|nil The raw settings table to populate with defaults
---@return BetterUIModuleOptions m_options The modified options table with defaults applied
---@type BetterUIModuleInitHook
function GeneralInterface.InitModule(m_options)
    m_options = m_options or {}
    ---@cast m_options BetterUIModuleOptions
    local ok2, result = BETTERUI.CIM.TryCall("Defaults.ApplyModuleDefaults", "GeneralInterface", m_options)
    if ok2 then
        m_options = result
    else
        if m_options["chatHistory"] == nil then m_options["chatHistory"] = 200 end
        if m_options["showMarketPrice"] == nil then m_options["showMarketPrice"] = true end
        if m_options["marketPricePriority"] == nil then m_options["marketPricePriority"] = "mm_att_ttc" end
        if m_options["showStyleTrait"] == nil then m_options["showStyleTrait"] = true end
        if m_options["showKnowledgeStatus"] == nil then m_options["showKnowledgeStatus"] = true end
        if m_options["removeDeleteDialog"] == nil then m_options["removeDeleteDialog"] = false end
        if m_options["guildStoreErrorSuppress"] == nil then m_options["guildStoreErrorSuppress"] = true end
        if m_options["attIntegration"] == nil then m_options["attIntegration"] = true end
        if m_options["mmIntegration"] == nil then m_options["mmIntegration"] = true end
        if m_options["ttcIntegration"] == nil then m_options["ttcIntegration"] = true end
    end
    return m_options
end
