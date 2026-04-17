--[[
File: Modules/CIM/Core/ResearchCache.lua
Purpose: Caches player's crafting research knowledge for efficient lookup.
         Avoids expensive API calls during list rendering.
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.ResearchCache = BETTERUI.CIM.ResearchCache or {}

local ResearchCache = BETTERUI.CIM.ResearchCache

local function SyncResearchTraits(traits)
    ResearchCache._traits = traits or {}
    BETTERUI.ResearchTraits = ResearchCache._traits
    return ResearchCache._traits
end

local function EnsureResearchTraits()
    return SyncResearchTraits(ResearchCache._traits or BETTERUI.ResearchTraits or {})
end

-- RESEARCH CACHE

function ResearchCache.GetResearch(forceRefresh)
    local traits = EnsureResearchTraits()
    if not forceRefresh and next(traits) then
        return traits
    end

    traits = {}
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

function ResearchCache.GetTraits()
    return EnsureResearchTraits()
end

BETTERUI.GetResearch = ResearchCache.GetResearch
EnsureResearchTraits()
