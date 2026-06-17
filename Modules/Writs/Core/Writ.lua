-- BetterUI - Writs quest helpers
--
-- File: Modules/Writs/Core/Writ.lua
-- Purpose: Tracks active crafting writs and formats the panel text shown at stations.
--
-- Cached control references (populated by CacheControls during addon init)
local m_writNameLabel = nil
local m_writDescLabel = nil
local m_writsPanel = nil
local WRIT_CONTEXT_REFRESH = "Writs:RefreshActiveWrits"
local WRIT_CONTEXT_SHOW = "Writs:ShowForCraftType"
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
function Writs.GetFormattedObjectives(questId)
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

local function BuildActiveWritLookup()
	local activeWrits = {}
	-- Resolve localized patterns once per scan (not per quest) — avoids
	-- repeated GetCVar("language.2") calls inside a hot loop
	local patterns = Writs.CONST.GetLocalizedPatterns()
	for questId = 1, MAX_JOURNAL_QUESTS do
		if IsValidQuestIndex(questId) and GetJournalQuestType(questId) == QUEST_TYPE_CRAFTING then
			local questName = GetJournalQuestInfo(questId)
			local currentWrit = -1
			local questNameLower = string.lower(questName or "")
			-- Order matters: last match wins as in the original chain.
			for i = 1, #patterns do
				local patternStr = patterns[i].pattern
				local craft = patterns[i].craftType
				if string.find(questNameLower, patternStr, 1, true) then
					currentWrit = craft
				end
			end

			if currentWrit ~= -1 then
				activeWrits[currentWrit] = {
					id = questId,
					writLines = Writs.GetFormattedObjectives(questId),
				}
			end
		end
	end
	return activeWrits
end

--- Rebuilds the active writ lookup from the quest journal.
---@return boolean ok
---@return string|nil err
function Writs.RefreshActiveWrits()
	local nextList = nil
	local ok, err = BETTERUI.CIM.SafeExecute(WRIT_CONTEXT_REFRESH, function()
		nextList = BuildActiveWritLookup()
	end)
	if ok == false then
		return false, err
	end
	Writs.List = nextList or {}
	return true, nil
end

--- Shows writ progress for the current crafting station.
---@param writType number CRAFTING_TYPE_* constant for the station
---@return boolean ok
---@return string|nil err
function Writs.ShowForCraftType(writType)
	if BETTERUI.Log then
		BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.LIFECYCLE, "writShowForCraftType", { writType = writType })
	end
	local refreshOk, refreshErr = Writs.RefreshActiveWrits()
	if not refreshOk then
		return false, refreshErr
	end

	local writEntry = Writs.List[writType]
	if writEntry == nil then
		return false, "no_active_writ"
	end

	local ok, err = BETTERUI.CIM.SafeExecute(WRIT_CONTEXT_SHOW, function()
		local questName = GetJournalQuestInfo(writEntry.id)
		if m_writNameLabel then
			m_writNameLabel:SetText(zo_strformat("|c0066ff[BETTERUI]|r <<1>>", questName))
		end
		if m_writDescLabel then
			m_writDescLabel:SetText(zo_strformat("<<1>>", writEntry.writLines))
		end
		if m_writsPanel then
			m_writsPanel:SetHidden(false)
		end
	end)
	if ok == false then
		return false, err
	end
	return true, nil
end

--- Hides the writ panel.
---@return nil
function Writs.HidePanel()
	if BETTERUI.Log then
		BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.LIFECYCLE, "writHidePanel")
	end
	local panel = m_writsPanel or BETTERUI_WritsPanel
	if panel then
		panel:SetHidden(true)
	end
end
