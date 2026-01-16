---------------------------------------------------------------------------------------------------
-- BetterUI - Writ Logic
--
-- This file handles the retrieval and formatting of writ quest objectives.
-- It scans the quest journal for crafting writs, formats their completion status (color coding),
-- and updates the UI panel with the relevant information for the current crafting station.
--
-- TODO(refactor): Pattern matching uses hardcoded strings - extract to localization or constants
-- TODO(enhancement): Add support for additional crafting types as ESO adds them
-- TODO(cleanup): Magic color values ("00FF00", "CCCCCC") should use BETTERUI.CONST.COLORS
---------------------------------------------------------------------------------------------------

local _

--- Gets formatted writ conditions for a specific quest.
--- Colors the text green if the condition is met, otherwise grey.
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
				colour = "00FF00"
			else
				colour = "CCCCCC"
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
--- Populates `BETTERUI.Writs.List` with relevant writ quests indexed by crafting type.
--- Handles name matching for all crafting professions (Blacksmithing, Clothier, etc.).
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
--- Updates the writ list, finds the relevant writ quest, and populates the UI with its status.
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
function BETTERUI.Writs.Hide()
	BETTERUI_WritsPanel:SetHidden(true)
end