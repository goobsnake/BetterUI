---------------------------------------------------------------------------------------------------
-- BetterUI - Writ Logic
--
-- File: Modules/WritUnit/Writ.lua
-- Purpose: Handles the data retrieval and formatting for daily writ quests.
--
-- This file handles the retrieval and formatting of writ quest objectives.
-- It scans the quest journal for crafting writs, formats their completion status (color coding),
-- and updates the UI panel with the relevant information for the current crafting station.
--
-- TODO(refactor): Pattern matching uses hardcoded strings - extract to localization or constants
-- TODO(enhancement): Add support for additional crafting types as ESO adds them
---------------------------------------------------------------------------------------------------

local _

--- Gets formatted writ conditions for a specific quest.
---
--- Purpose: Formats quest objectives for display.
--- Mechanics:
--- - Iterates through all conditions of the quest.
--- - Compares `current` vs `maximum` counts.
--- - Applies **Green** (00FF00) if complete, **Grey** (CCCCCC) if incomplete.
--- - Returns a concatenated string of objectives.
---
--- @param qId number The quest ID.
--- @return string The concatenated and formatted writ conditions.
function BETTERUI.Writs.Get(qId)
	local writLines = {}
	local writConcate = ''
	for lineId = 1, GetJournalQuestNumConditions(qId,1) do
		local writLine,current,maximum,_,complete = GetJournalQuestConditionInfo(qId,1,lineId)
		local colour
		if writLine ~= '' then
			if current == maximum then
				colour = BETTERUI.Writs.CONST.COLORS.COMPLETE
			else
				colour = BETTERUI.Writs.CONST.COLORS.INCOMPLETE
			end
			writLines[lineId] = {line=zo_strformat("|c<<1>><<2>>|r",colour,writLine),cur=current,max=maximum}
		end
	end
	for key,line in pairs(writLines) do
		writConcate = zo_strformat("<<1>><<2>>\n",writConcate,line.line)
	end

	return writConcate
end

--- Scans the quest journal for active Writ quests.
---
--- Purpose: Identifies which crafting writs the player currently has.
--- Mechanics:
--- - Iterates `MAX_JOURNAL_QUESTS`.
--- - Matches Quest Name against hardcoded keywords (e.g., "blacksmith", "cloth", "witches").
--- - Maps the matching Quest ID to the corresponding `CRAFTING_TYPE_XXX` constant in `BETTERUI.Writs.List`.
---
function BETTERUI.Writs.Update()
	BETTERUI.Writs.List = {}
	for qId=1, MAX_JOURNAL_QUESTS do
		if IsValidQuestIndex(qId) then
			if GetJournalQuestType(qId) == QUEST_TYPE_CRAFTING then
				local qName,_,qDesc,_,_,qCompleted  = GetJournalQuestInfo(qId)
				local currentWrit = -1
				local q = string.lower(qName or "")
				-- Order matters: last match wins as in the original chain
				local patterns = {
					{"blacksmith", CRAFTING_TYPE_BLACKSMITHING},
					{"cloth", CRAFTING_TYPE_CLOTHIER},
					{"woodwork", CRAFTING_TYPE_WOODWORKING},
					{"enchant", CRAFTING_TYPE_ENCHANTING},
					{"provision", CRAFTING_TYPE_PROVISIONING},
					{"alchemist", CRAFTING_TYPE_ALCHEMY},
					{"jewelry", CRAFTING_TYPE_JEWELRYCRAFTING},
					{"witches", CRAFTING_TYPE_PROVISIONING},
				}
				for i = 1, #patterns do
					local pat, craft = patterns[i][1], patterns[i][2]
					if string.find(q, pat, 1, true) then
						currentWrit = craft
					end
				end

				if currentWrit ~= -1 then
					BETTERUI.Writs.List[currentWrit] = { id = qId, writLines = BETTERUI.Writs.Get(qId) }
				end
			end
		end
	end
end

--- Shows the Writ panel for a specific crafting station type.
---
--- Purpose: Displays writ requirements for the current station.
--- Mechanics:
--- - Calls `Update` to refresh data.
--- - LOOKUP: Checks `BETTERUI.Writs.List` for the given `writType` (station type).
--- - If found, updates `WritName` (Title) and `WritDesc` (Objectives).
--- - Sets Panel to Visible.
---
--- @param writType number The crafting type ID (e.g., CRAFTING_TYPE_BLACKSMITHING).
function BETTERUI.Writs.Show(writType)
	BETTERUI.Writs.Update()
	if BETTERUI.Writs.List[writType] ~= nil then
		local qName,_,activeText,_,_,completed = GetJournalQuestInfo(BETTERUI.Writs.List[writType].id)
		BETTERUI_WritsPanelSlotContainerExtractionSlotWritName:SetText(zo_strformat("|c0066ff[BETTERUI]|r <<1>>",qName))
		BETTERUI_WritsPanelSlotContainerExtractionSlotWritDesc:SetText(zo_strformat("<<1>>",BETTERUI.Writs.List[writType].writLines))
		BETTERUI_WritsPanel:SetHidden(false)
	end
end

--- Hides the Writ panel.
---
--- Purpose: Cleanly removes the UI overlay.
function BETTERUI.Writs.Hide()
	BETTERUI_WritsPanel:SetHidden(true)
end