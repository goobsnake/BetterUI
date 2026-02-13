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
-- Writ detection patterns are defined in Constants.lua for centralized maintenance.
-- TODO(refactor): Add support for additional crafting types as ESO adds them
-- Last Modified: 2026-01-28
---------------------------------------------------------------------------------------------------


-- Cached control references (populated by CacheControls during addon init)
local m_writNameLabel = nil
local m_writDescLabel = nil
local m_writsPanel = nil

--- Caches control references for performance.
---
--- Purpose: Avoids repeated global lookups in Show() each time panel is displayed.
--- Mechanics: Stores references to UI controls at startup.
--- References: Called during addon initialization.
function BETTERUI.Writs.CacheControls()
	m_writNameLabel = BETTERUI_WritsPanelSlotContainerExtractionSlotWritName
	m_writDescLabel = BETTERUI_WritsPanelSlotContainerExtractionSlotWritDesc
	m_writsPanel = BETTERUI_WritsPanel
end

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
	for lineId = 1, GetJournalQuestNumConditions(qId, 1) do
		-- TODO(bug): 'complete' (5th return) is captured but never used; current==maximum is wrong for edge cases (fail conditions, multi-step). Use 'complete' flag per ESO reference code. Also: isFailCondition (4th) and isVisible (7th) are not checked, so fail/hidden conditions display incorrectly
		local writLine, current, maximum, _, complete = GetJournalQuestConditionInfo(qId, 1, lineId)
		local colour
		if writLine ~= '' then
			if current == maximum then
				colour = BETTERUI.Writs.CONST.COLORS.COMPLETE
			else
				colour = BETTERUI.Writs.CONST.COLORS.INCOMPLETE
			end
			writLines[lineId] = { line = zo_strformat("|c<<1>><<2>>|r", colour, writLine), cur = current, max = maximum }
		end
	end
	-- TODO(bug): pairs() on sparse numeric table produces non-deterministic iteration order; writ objectives may appear in random order. Use sequential insertion (writLines[#writLines+1]) and ipairs()
	for key, line in pairs(writLines) do
		writConcate = zo_strformat("<<1>><<2>>\n", writConcate, line.line)
	end

	return writConcate
end

--- Scans the quest journal for active Writ quests.
---
--- Purpose: Identifies which crafting writs the player currently has.
--- Mechanics:
--- - Iterates `MAX_JOURNAL_QUESTS`.
--- - Matches Quest Name against patterns defined in Constants.lua.
--- - Maps the matching Quest ID to the corresponding `CRAFTING_TYPE_XXX` constant in `BETTERUI.Writs.List`.
---
function BETTERUI.Writs.Update()
	BETTERUI.Writs.List = {}
	for qId = 1, MAX_JOURNAL_QUESTS do
		if IsValidQuestIndex(qId) then
			if GetJournalQuestType(qId) == QUEST_TYPE_CRAFTING then
				-- TODO(cleanup): Replace unused qDesc, qCompleted with _ placeholders
			local qName, _, qDesc, _, _, qCompleted = GetJournalQuestInfo(qId)
				local currentWrit                       = -1
				local q                                 = string.lower(qName or "")
				-- Use patterns from Constants.lua for maintainability
				-- Order matters: last match wins as in the original chain
				-- TODO(fix): Use BETTERUI.Writs.CONST.GetLocalizedPatterns() instead of CONST.PATTERNS for i18n support (German/French users affected)
				local patterns                          = BETTERUI.Writs.CONST.PATTERNS
				for i = 1, #patterns do
					local pat = patterns[i].pattern
					local craft = patterns[i].craftType
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
--- - If found, updates cached controls with quest name and objectives.
--- - Sets Panel to Visible.
---
--- @param writType number The crafting type ID (e.g., CRAFTING_TYPE_BLACKSMITHING).
function BETTERUI.Writs.Show(writType)
	BETTERUI.Writs.Update()
	if BETTERUI.Writs.List[writType] ~= nil then
		-- TODO(cleanup): Replace unused activeText, completed with _ placeholders
		local qName, _, activeText, _, _, completed = GetJournalQuestInfo(BETTERUI.Writs.List[writType].id)
		-- Use cached control references for performance
		if m_writNameLabel then
			m_writNameLabel:SetText(zo_strformat("|c0066ff[BETTERUI]|r <<1>>", qName))
		end
		if m_writDescLabel then
			m_writDescLabel:SetText(zo_strformat("<<1>>", BETTERUI.Writs.List[writType].writLines))
		end
		if m_writsPanel then
			m_writsPanel:SetHidden(false)
		end
	end
end

--- Hides the Writ panel.
---
--- Purpose: Cleanly removes the UI overlay.
function BETTERUI.Writs.Hide()
	if m_writsPanel then
		m_writsPanel:SetHidden(true)
	else
		BETTERUI_WritsPanel:SetHidden(true)
	end
end
