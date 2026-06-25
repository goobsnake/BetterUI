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

local function TraceWrit(event, phase, data)
	local L = BETTERUI.Log
	if not (L and L.TraceEvent) then return end
	data = data or {}
	data.module = data.module or "Writs"
	data.scene = data.scene or (SCENE_MANAGER and SCENE_MANAGER.GetCurrentSceneName and SCENE_MANAGER:GetCurrentSceneName() or nil)
	data.feature = data.feature or "writ-panel"
	data.fn = data.fn or "Writs.Core"
	data["function"] = data["function"] or data.fn
	L.TraceEvent(L.CATEGORY.LIFECYCLE, event, phase, data)
end

local function CountWritSnapshotEntries()
	local count = 0
	for _ in pairs(Writs.List or {}) do
		count = count + 1
	end
	return count
end

local function IsWritSnapshotPanelHidden(panel)
	if not (panel and panel.IsHidden) then return nil end
	local ok, hidden = pcall(function() return panel:IsHidden() end)
	return ok and hidden or nil
end

local function RegisterWritSnapshotProvider()
	local watch = BETTERUI.CIM and BETTERUI.CIM.WatchMode
	if not (watch and watch.RegisterSnapshotProvider) then return end
	watch.RegisterSnapshotProvider("writs", function()
		local panel = m_writsPanel or rawget(_G, "BETTERUI_WritsPanel")
		return string.format(
			"writCount=%s panel=%s hidden=%s nameLabel=%s descLabel=%s scene=%s",
			tostring(CountWritSnapshotEntries()),
			tostring(panel ~= nil),
			tostring(IsWritSnapshotPanelHidden(panel)),
			tostring(m_writNameLabel ~= nil),
			tostring(m_writDescLabel ~= nil),
			tostring(SCENE_MANAGER and SCENE_MANAGER.GetCurrentSceneName and SCENE_MANAGER:GetCurrentSceneName() or nil))
	end)
end

RegisterWritSnapshotProvider()

--- Caches the writ panel controls used by Show and Hide.
---@return nil
function Writs.CacheControls()
	m_writNameLabel = BETTERUI_WritsPanelSlotContainerExtractionSlotWritName
	m_writDescLabel = BETTERUI_WritsPanelSlotContainerExtractionSlotWritDesc
	m_writsPanel = BETTERUI_WritsPanel
	TraceWrit("writ.controls", "cached", {
		hasNameLabel = m_writNameLabel ~= nil,
		hasDescLabel = m_writDescLabel ~= nil,
		hasPanel = m_writsPanel ~= nil,
	})
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
	local scanned = 0
	local matched = 0
	for questId = 1, MAX_JOURNAL_QUESTS do
		if IsValidQuestIndex(questId) and GetJournalQuestType(questId) == QUEST_TYPE_CRAFTING then
			scanned = scanned + 1
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
				matched = matched + 1
				if activeWrits[currentWrit] then
					TraceWrit("writ.lookup", "duplicate_overwrite", {
						craftType = currentWrit,
						previousQuestId = activeWrits[currentWrit].id,
						nextQuestId = questId,
						nextQuestName = questName,
					})
				end
				activeWrits[currentWrit] = {
					id = questId,
					writLines = Writs.GetFormattedObjectives(questId),
				}
			else
				TraceWrit("writ.lookup", "unmatched_quest", {
					questId = questId,
					questName = questName,
					patternCount = #patterns,
				})
			end
		end
	end
	TraceWrit("writ.lookup", "rebuilt", { scanned = scanned, matched = matched, patternCount = #patterns })
	return activeWrits
end

--- Rebuilds the active writ lookup from the quest journal.
---@return boolean ok
---@return string|nil err
function Writs.RefreshActiveWrits()
	local nextList = nil
	TraceWrit("writ.refresh", "begin")
	local ok, err = BETTERUI.CIM.SafeExecute(WRIT_CONTEXT_REFRESH, function()
		nextList = BuildActiveWritLookup()
	end)
	if ok == false then
		TraceWrit("writ.refresh", "error", { error = err })
		return false, err
	end
	Writs.List = nextList or {}
	local count = 0
	for _ in pairs(Writs.List) do count = count + 1 end
	TraceWrit("writ.refresh", "end", { activeCount = count })
	return true, nil
end

--- Shows writ progress for the current crafting station.
---@param writType number CRAFTING_TYPE_* constant for the station
---@return boolean ok
---@return string|nil err
function Writs.ShowForCraftType(writType)
	TraceWrit("writ.panel", "show_begin", { writType = writType })
	local refreshOk, refreshErr = Writs.RefreshActiveWrits()
	if not refreshOk then
		TraceWrit("writ.panel", "show_error", { writType = writType, error = refreshErr })
		return false, refreshErr
	end

	local writEntry = Writs.List[writType]
	if writEntry == nil then
		TraceWrit("writ.panel", "no_active_writ", { writType = writType })
		return false, "no_active_writ"
	end

	local ok, err = BETTERUI.CIM.SafeExecute(WRIT_CONTEXT_SHOW, function()
		local questName = GetJournalQuestInfo(writEntry.id)
		TraceWrit("writ.panel", "render", { writType = writType, questId = writEntry.id, questName = questName })
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
		TraceWrit("writ.panel", "show_error", { writType = writType, questId = writEntry.id, error = err })
		return false, err
	end
	TraceWrit("writ.panel", "shown", { writType = writType, questId = writEntry.id })
	return true, nil
end

--- Hides the writ panel.
---@return nil
function Writs.HidePanel()
	local panel = m_writsPanel or BETTERUI_WritsPanel
	if panel then
		panel:SetHidden(true)
	end
	TraceWrit("writ.panel", "hidden", { hadPanel = panel ~= nil })
end
