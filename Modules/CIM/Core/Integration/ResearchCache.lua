--[[
File: Modules/CIM/Core/ResearchCache.lua
Purpose: Caches player's crafting research knowledge for efficient lookup.
         Avoids expensive API calls during list rendering.
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.ResearchCache = BETTERUI.CIM.ResearchCache or {}

local ResearchCache = BETTERUI.CIM.ResearchCache

---@param traits table|nil
---@return table traits
local function SyncResearchTraits(traits)
    ResearchCache._traits = traits or {}
    BETTERUI.ResearchTraits = ResearchCache._traits
    return ResearchCache._traits
end

---@return table traits
local function EnsureResearchTraits()
    return SyncResearchTraits(ResearchCache._traits or BETTERUI.ResearchTraits or {})
end

---@return table traits
local function BuildResearchTraits()
    local traits = {}
    local craftTypes = BETTERUI.CIM and BETTERUI.CIM.CONST and BETTERUI.CIM.CONST.CraftingSkillTypes
    if not craftTypes then
        return SyncResearchTraits(traits)
    end

    for _, craftType in pairs(craftTypes) do
        traits[craftType] = {}
        for researchIndex = 1, GetNumSmithingResearchLines(craftType) do
            local _, _, numTraits = GetSmithingResearchLineInfo(craftType, researchIndex)
            traits[craftType][researchIndex] = {}
            for traitIndex = 1, numTraits do
                local _, _, known = GetSmithingResearchLineTraitInfo(craftType, researchIndex, traitIndex)
                traits[craftType][researchIndex][traitIndex] = known
            end
        end
    end

    return SyncResearchTraits(traits)
end

--- RESEARCH CACHE

--- Returns shared research traits and refreshes them from game data when requested.
--- When `forceRefresh` is true, this method refreshes persistent cache state and updates
--- `BETTERUI.ResearchTraits`.
---@param forceRefresh boolean|nil Forces a cache rebuild when true.
---@return table traits The cached research-trait matrix
function ResearchCache.GetResearch(forceRefresh)
    if not forceRefresh then
        local traits = EnsureResearchTraits()
        if next(traits) then
            return traits
        end
    end
    return BuildResearchTraits()
end

--- Explicitly refreshes research traits from the game API.
--- This method is intentionally side-effecting and rewrites `BETTERUI.ResearchTraits`.
---@return table traits The rebuilt research-trait matrix
function ResearchCache.RefreshResearchTraits()
    return BuildResearchTraits()
end

--- Returns cached traits and keeps existing cache state.
--- Keeps existing behavior for callers that only need trait reads.
---@return table traits The cached research-trait matrix
function ResearchCache.GetTraits()
    return EnsureResearchTraits()
end

--- Backward-compatible accessor name for cache reads/writes with explicit behavior.
---@deprecated Prefer `GetResearch` for explicit refresh semantics.
---@param forceRefresh boolean|nil Forces a cache rebuild when true.
---@return table traits The cached research-trait matrix
function ResearchCache.GetResearchTraits(forceRefresh)
    return ResearchCache.GetResearch(forceRefresh)
end

BETTERUI.GetResearch = ResearchCache.GetResearch
ResearchCache.GetTraits()
