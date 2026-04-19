if BETTERUI == nil then BETTERUI = {} end
if BETTERUI.GeneralInterface == nil then BETTERUI.GeneralInterface = {} end

local GeneralInterface = BETTERUI.GeneralInterface

local function GetNameplatesNamespace()
    local nameplates = GeneralInterface.Nameplates
    if nameplates == nil then
        nameplates = BETTERUI.Nameplates or {}
        GeneralInterface.Nameplates = nameplates
    end
    BETTERUI.Nameplates = nameplates
    return nameplates
end

GeneralInterface.GetNameplatesNamespace = GetNameplatesNamespace
GetNameplatesNamespace()

local MODULE_NAME = "GeneralInterface"
GeneralInterface.ARCHETYPE = "thin-entrypoint"
---@type BetterUIModuleRootContract
GeneralInterface.ROOT_CONTRACT = {
    name = MODULE_NAME,
    archetype = GeneralInterface.ARCHETYPE,
    init = true,
    setup = true,
}

---@type BetterUIModuleInitHook
function GeneralInterface.InitModule(m_options)
    m_options = m_options or {}
    ---@cast m_options BetterUIModuleOptions
    local defaultsApi = BETTERUI.Defaults
    if defaultsApi and type(defaultsApi.ApplyModuleDefaults) == "function" then
        m_options = defaultsApi.ApplyModuleDefaults("GeneralInterface", m_options)
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
