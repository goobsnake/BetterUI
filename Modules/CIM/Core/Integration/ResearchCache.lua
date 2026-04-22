--[[
File: Modules/CIM/Core/ResearchCache.lua
Purpose: Caches player's crafting research knowledge for efficient lookup.
         Avoids expensive API calls during list rendering.
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.ResearchCache = BETTERUI.CIM.ResearchCache or {}

local ResearchCache = BETTERUI.CIM.ResearchCache
local EMPTY_TRAITS = {}

---@param value any
---@return any
local function CloneValue(value)
    if type(value) ~= "table" then
        return value
    end

    local clone = {}
    for key, item in pairs(value) do
        clone[key] = CloneValue(item)
    end
    return clone
end

---@param traits table|nil
---@return table traits
local function PublishResearchTraits(traits)
    local normalized = type(traits) == "table" and traits or {}
    ResearchCache._traits = normalized
    BETTERUI.ResearchTraits = normalized
    return normalized
end

---@return table traits
local function GetCachedResearchTraitsLive()
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

--- Returns shared research traits without mutating cache state.
--- This getter is observational and returns a snapshot copy.
---@return table traits The cached research-trait matrix snapshot
function ResearchCache.GetResearch()
    return CloneValue(GetCachedResearchTraitsLive())
end

--- Returns the shared mutable research traits table.
--- Explicitly named `...Live` so callers do not mistake it for a snapshot.
---@return table traits The live cached research-trait matrix
function ResearchCache.GetResearchLive()
    return GetCachedResearchTraitsLive()
end

--- Returns shared research traits as a snapshot copy.
---@return table traits The cached research-trait matrix snapshot
function ResearchCache.GetResearchSnapshot()
    return ResearchCache.GetResearch()
end

--- Explicitly refreshes research traits from the game API.
--- This method is intentionally side-effecting and rewrites `BETTERUI.ResearchTraits`.
---@return table traits The rebuilt research-trait matrix
function ResearchCache.RefreshResearchTraits()
    return BuildResearchTraits()
end

--- Returns cached traits and keeps existing cache state.
--- Keeps existing behavior for callers that only need trait reads.
---@return table traits The cached research-trait matrix snapshot
function ResearchCache.GetTraits()
    return ResearchCache.GetResearch()
end

--- Backward-compatible read-only alias.
---@deprecated Prefer `GetResearch` for reads and `RefreshResearchTraits` for refreshes.
---@return table traits The cached research-trait matrix snapshot
function ResearchCache.GetResearchTraits()
    return ResearchCache.GetResearch()
end

BETTERUI.GetResearch = ResearchCache.GetResearch
