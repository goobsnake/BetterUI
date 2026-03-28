--[[
File: Modules/CIM/Core/ResearchCache.lua
Purpose: Caches player's crafting research knowledge for efficient lookup.
         Avoids expensive API calls during list rendering.
]]

-- Initialize research traits table if not already present
if not BETTERUI.ResearchTraits then
    BETTERUI.ResearchTraits = {}
end

-- RESEARCH CACHE

function BETTERUI.GetResearch(forceRefresh)
    if not forceRefresh and BETTERUI.ResearchTraits and next(BETTERUI.ResearchTraits) then
        return -- Use cached data
    end

    BETTERUI.ResearchTraits = {}
    for i, craftType in pairs(BETTERUI.CIM.CONST.CraftingSkillTypes) do
        BETTERUI.ResearchTraits[craftType] = {}
        for researchIndex = 1, GetNumSmithingResearchLines(craftType) do
            local _, _, numTraits = GetSmithingResearchLineInfo(craftType, researchIndex)
            BETTERUI.ResearchTraits[craftType][researchIndex] = {}
            for traitIndex = 1, numTraits do
                local _, _, known = GetSmithingResearchLineTraitInfo(craftType, researchIndex, traitIndex)
                BETTERUI.ResearchTraits[craftType][researchIndex][traitIndex] = known
            end
        end
    end
end
