---@type BetterUIModuleRoot
BETTERUI.Writs = BETTERUI.Writs or {}
local Writs = BETTERUI.Writs
local ARCHETYPES = BETTERUI.CIM and BETTERUI.CIM.ARCHETYPES or {}
local THIN_ENTRYPOINT = ARCHETYPES.THIN_ENTRYPOINT or "thin-entrypoint"
local currentCraftingType = nil

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

local function TraceWritEvent(event, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = data.module or "Writs"
    data.scene = data.scene or (SCENE_MANAGER and SCENE_MANAGER.GetCurrentSceneName and SCENE_MANAGER:GetCurrentSceneName() or nil)
    data.feature = data.feature or "writ-events"
    data.fn = data.fn or "Writs.Module"
    data["function"] = data["function"] or data.fn
    L.TraceEvent(L.CATEGORY.LIFECYCLE, event, phase, data)
end

local function OnCraftStation(_, craftId)
    TraceWritEvent("writ.station", "opened", { craftId = craftId })
    if not IsWritsModuleEnabled() then
        TraceWritEvent("writ.station", "skipped", { craftId = craftId, reason = "moduleDisabled" })
        return
    end

    local id = craftId and tonumber(craftId)
    if not id then
        TraceWritEvent("writ.station", "skipped", { craftId = craftId, reason = "invalidCraftId" })
        return
    end

    currentCraftingType = id
    SafeExecuteWrits("Writs:OnCraftStation", BETTERUI.Writs.ShowForCraftType, id, {
        source = "station_opened",
        craftId = craftId,
        event = "EVENT_CRAFTING_STATION_INTERACT",
    })
end

local function OnCloseCraftStation(_)
    TraceWritEvent("writ.station", "closed")
    currentCraftingType = nil
    SafeExecuteWrits("Writs:OnCloseCraftStation", BETTERUI.Writs.HidePanel)
end

local function ScheduleCraftCompletionRefresh(id, craftId)
    local later = rawget(_G, "zo_callLater")
    if type(later) ~= "function" then
        TraceWritEvent("writ.craft", "deferred_skipped", {
            craftId = craftId,
            reason = "missingTimer",
        })
        return
    end
    TraceWritEvent("writ.craft", "deferred_scheduled", {
        craftId = craftId,
        delayMs = 150,
    })
    later(function()
        if not IsWritsModuleEnabled() then
            TraceWritEvent("writ.craft", "deferred_skipped", {
                craftId = craftId,
                reason = "moduleDisabled",
            })
            return
        end
        SafeExecuteWrits("Writs:OnCraftItemDeferred", BETTERUI.Writs.ShowForCraftType, id, {
            source = "craft_completed_deferred",
            craftId = craftId,
            event = "EVENT_CRAFT_COMPLETED",
        })
    end, 150)
end

local function OnCraftItem(_, craftId)
    TraceWritEvent("writ.craft", "completed", { craftId = craftId })
    if not IsWritsModuleEnabled() then
        TraceWritEvent("writ.craft", "skipped", { craftId = craftId, reason = "moduleDisabled" })
        return
    end

    local id = craftId and tonumber(craftId)
    if not id then
        TraceWritEvent("writ.craft", "skipped", { craftId = craftId, reason = "invalidCraftId" })
        return
    end

    SafeExecuteWrits("Writs:OnCraftItem", BETTERUI.Writs.ShowForCraftType, id, {
        source = "craft_completed_immediate",
        craftId = craftId,
        event = "EVENT_CRAFT_COMPLETED",
    })
    ScheduleCraftCompletionRefresh(id, craftId)
end

local function OnQuestJournalChanged(eventCode, questIndex)
    local cachedWritsBefore = 0
    for _ in pairs(Writs.List or {}) do
        cachedWritsBefore = cachedWritsBefore + 1
    end
    TraceWritEvent("writ.quest", "invalidated", {
        eventCode = eventCode,
        questIndex = questIndex,
        activeCraftingType = currentCraftingType,
        cachedWritsBefore = cachedWritsBefore,
    })
    Writs.List = {}
    if currentCraftingType and IsWritsModuleEnabled() then
        SafeExecuteWrits("Writs:OnQuestJournalChanged", BETTERUI.Writs.ShowForCraftType, currentCraftingType, {
            source = "quest_journal_event",
            event = eventCode,
            questIndex = questIndex,
        })
    end
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
    TraceWritEvent("writ.setup", "begin")
    local tlw = BETTERUI.WindowManager:CreateTopLevelWindow("BETTERUI_Writs_TLW")
    local BETTERUI_WP = BETTERUI.WindowManager:CreateControlFromVirtual("BETTERUI_WritsPanel", tlw, "BETTERUI_WritsPanel")

    local writsNamespace = BETTERUI.name .. "_Writs"
    BETTERUI.CIM.EventRegistry.Register("Writs", writsNamespace, EVENT_CRAFTING_STATION_INTERACT, OnCraftStation)
    BETTERUI.CIM.EventRegistry.Register("Writs", writsNamespace, EVENT_END_CRAFTING_STATION_INTERACT, OnCloseCraftStation)
    BETTERUI.CIM.EventRegistry.Register("Writs", writsNamespace, EVENT_CRAFT_COMPLETED, OnCraftItem)
    if EVENT_QUEST_ADDED then
        BETTERUI.CIM.EventRegistry.Register("Writs", writsNamespace, EVENT_QUEST_ADDED, OnQuestJournalChanged)
    end
    if EVENT_QUEST_REMOVED then
        BETTERUI.CIM.EventRegistry.Register("Writs", writsNamespace, EVENT_QUEST_REMOVED, OnQuestJournalChanged)
    end
    if EVENT_QUEST_CONDITION_COUNTER_CHANGED then
        BETTERUI.CIM.EventRegistry.Register("Writs", writsNamespace, EVENT_QUEST_CONDITION_COUNTER_CHANGED, OnQuestJournalChanged)
    end

    Writs.CacheControls()

    BETTERUI_WP:SetHidden(true)
    TraceWritEvent("writ.setup", "end", { hidden = true })
end
