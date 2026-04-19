--[[
File: Modules/CIM/Core/ResearchCache.lua
Purpose: Caches player's crafting research knowledge for efficient lookup.
         Avoids expensive API calls during list rendering.
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.ResearchCache = BETTERUI.CIM.ResearchCache or {}

local ResearchCache = BETTERUI.CIM.ResearchCache
local EMPTY_TRAITS = {}

---@param traits table|nil
---@return table traits
local function PublishResearchTraits(traits)
    local normalized = type(traits) == "table" and traits or {}
    ResearchCache._traits = normalized
    BETTERUI.ResearchTraits = normalized
    return normalized
end

---@return table traits
local function GetCachedResearchTraits()
    if type(ResearchCache._traits) == "table" then
        return ResearchCache._traits
    end
    if type(BETTERUI.ResearchTraits) == "table" then
        return BETTERUI.ResearchTraits
    end
    return EMPTY_TRAITS
end

---@return table traits
local function BuildResearchTraits()
    local traits = {}
    local craftTypes = BETTERUI.CIM and BETTERUI.CIM.CONST and BETTERUI.CIM.CONST.CraftingSkillTypes
    if not craftTypes then
        return PublishResearchTraits(traits)
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

    return PublishResearchTraits(traits)
end

--- RESEARCH CACHE

--- Returns shared research traits and refreshes them from game data when requested.
--- When `forceRefresh` is true, this method refreshes persistent cache state and updates
--- `BETTERUI.ResearchTraits`.
---@param forceRefresh boolean|nil Forces a cache rebuild when true.
---@return table traits The cached research-trait matrix
function ResearchCache.GetResearch(forceRefresh)
    if forceRefresh then
        return BuildResearchTraits()
    end
    return GetCachedResearchTraits()
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
    return GetCachedResearchTraits()
end

--- Backward-compatible accessor name for cache reads/writes with explicit behavior.
---@deprecated Prefer `GetResearch` for explicit refresh semantics.
---@param forceRefresh boolean|nil Forces a cache rebuild when true.
---@return table traits The cached research-trait matrix
function ResearchCache.GetResearchTraits(forceRefresh)
    return ResearchCache.GetResearch(forceRefresh)
end

BETTERUI.GetResearch = ResearchCache.GetResearch
