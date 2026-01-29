--[[
File: Modules/CIM/Core/ResearchCache.lua
Purpose: Caches player's crafting research knowledge for efficient lookup.
         Avoids expensive API calls during list rendering.
Author: BetterUI Team
Last Modified: 2026-01-27
]]

-- Initialize research traits table if not already present
if not BETTERUI.ResearchTraits then
    BETTERUI.ResearchTraits = {}
end

-- ============================================================================
-- RESEARCH CACHE
-- ============================================================================

--[[
Function: BETTERUI.GetResearch
Description: Populates the ResearchTraits cache.
Rationale: Caches player's research knowledge to avoid expensive API calls during list rendering.
Mechanism: Iterates through all crafting types, research lines, and traits.
           Stores boolean status (known/unknown) in BETTERUI.ResearchTraits.
References: Called on initialization and when research completes.
param: forceRefresh (boolean) - If true, ignores existing cache and rebuilds data.
]]
--- @param forceRefresh boolean|nil If true, ignores existing cache and rebuilds data
function BETTERUI.GetResearch(forceRefresh)
    if not forceRefresh and BETTERUI.ResearchTraits and next(BETTERUI.ResearchTraits) then
        return -- Use cached data
    end

    BETTERUI.ResearchTraits = {}
    for i, craftType in pairs(BETTERUI.CIM.CONST.CraftingSkillTypes) do
        BETTERUI.ResearchTraits[craftType] = {}
        for researchIndex = 1, GetNumSmithingResearchLines(craftType) do
            local name, icon, numTraits, timeRequiredForNextResearchSecs = GetSmithingResearchLineInfo(craftType,
                researchIndex)
            BETTERUI.ResearchTraits[craftType][researchIndex] = {}
            for traitIndex = 1, numTraits do
                local traitType, _, known = GetSmithingResearchLineTraitInfo(craftType, researchIndex, traitIndex)
                BETTERUI.ResearchTraits[craftType][researchIndex][traitIndex] = known
            end
        end
    end
end
