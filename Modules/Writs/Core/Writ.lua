-- BetterUI - Writs quest helpers
--
-- File: Modules/Writs/Core/Writ.lua
-- Purpose: Tracks active crafting writs and formats the panel text shown at stations.
--
-- Cached control references (populated by CacheControls during addon init)
local m_writNameLabel = nil
local m_writDescLabel = nil
local m_writsPanel = nil
local WRIT_CONTEXT_UPDATE = "Writs:Update"
local WRIT_CONTEXT_SHOW = "Writs:Show"
local Writs = BETTERUI.Writs

--- Caches the writ panel controls used by Show and Hide.
---@return nil
function Writs.CacheControls()
	m_writNameLabel = BETTERUI_WritsPanelSlotContainerExtractionSlotWritName
	m_writDescLabel = BETTERUI_WritsPanelSlotContainerExtractionSlotWritDesc
	m_writsPanel = BETTERUI_WritsPanel
end

--- Returns the formatted objective lines for a writ quest.
---@param questId number Quest journal index
---@return string writConcate Formatted color-coded objectives string
function Writs.Get(questId)
	local writLines = {}
	local writConcate = ''
	for lineId = 1, GetJournalQuestNumConditions(questId, 1) do
		local writLine, current, maximum, isFailCondition, complete, _, isVisible = GetJournalQuestConditionInfo(questId, 1, lineId)
		-- Skip empty, invisible, or fail conditions
		if writLine ~= '' and isVisible ~= false and not isFailCondition then
			local colour
			if complete then
				colour = Writs.CONST.COLORS.COMPLETE
			else
				colour = Writs.CONST.COLORS.INCOMPLETE
			end
			writLines[#writLines + 1] = { line = zo_strformat("|c<<1>><<2>>|r", colour, writLine), cur = current, max = maximum }
		end
	end
	-- Sequential insertion ensures deterministic ordering via ipairs
	for _, line in ipairs(writLines) do
		writConcate = zo_strformat("<<1>><<2>>\n", writConcate, line.line)
	end

	return writConcate
end

--- Rebuilds the active writ lookup from the quest journal.
---@return nil
function Writs.Update()
	Writs.List = {}
	BETTERUI.CIM.SafeExecute(WRIT_CONTEXT_UPDATE, function()
		-- Resolve localized patterns once per scan (not per quest) — avoids
		-- repeated GetCVar("language.2") calls inside a hot loop
		local patterns = Writs.CONST.GetLocalizedPatterns()
		for questId = 1, MAX_JOURNAL_QUESTS do
			if IsValidQuestIndex(questId) then
				if GetJournalQuestType(questId) == QUEST_TYPE_CRAFTING then
				local questName, _, _, _, _, _ = GetJournalQuestInfo(questId)
					local currentWrit = -1
					local questNameLower = string.lower(questName or "")
					-- Use patterns from Constants.lua for maintainability
					-- Order matters: last match wins as in the original chain
					for i = 1, #patterns do
						local patternStr = patterns[i].pattern
						local craft = patterns[i].craftType
						if string.find(questNameLower, patternStr, 1, true) then
							currentWrit = craft
						end
					end

					if currentWrit ~= -1 then
						Writs.List[currentWrit] = { id = questId, writLines = Writs.Get(questId) }
					end
				end
			end
		end
	end)
end

--- Shows writ progress for the current crafting station.
---@param writType number CRAFTING_TYPE_* constant for the station
---@return nil
function Writs.Show(writType)
	BETTERUI.CIM.SafeExecute(WRIT_CONTEXT_SHOW, function()
		Writs.Update()
		if Writs.List[writType] == nil then return end

		local questName, _, _, _, _, _ = GetJournalQuestInfo(Writs.List[writType].id)
		-- Use cached control references for performance
		if m_writNameLabel then
			m_writNameLabel:SetText(zo_strformat("|c0066ff[BETTERUI]|r <<1>>", questName))
		end
		if m_writDescLabel then
			m_writDescLabel:SetText(zo_strformat("<<1>>", Writs.List[writType].writLines))
		end
		if m_writsPanel then
			m_writsPanel:SetHidden(false)
		end
	end)
end

--- Hides the writ panel.
---@return nil
function Writs.Hide()
	if m_writsPanel then
		m_writsPanel:SetHidden(true)
	else
		BETTERUI_WritsPanel:SetHidden(true)
	end
end
