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

local function TraceWrit(event, phase, data, category)
	local L = BETTERUI.Log
	if not (L and L.TraceEvent) then return end
	data = data or {}
	data.module = data.module or "Writs"
	data.scene = data.scene or (SCENE_MANAGER and SCENE_MANAGER.GetCurrentSceneName and SCENE_MANAGER:GetCurrentSceneName() or nil)
	data.feature = data.feature or "writ-panel"
	data.fn = data.fn or "Writs.Core"
	data["function"] = data["function"] or data.fn
	L.TraceEvent(category or L.CATEGORY.LIFECYCLE, event, phase, data)
end

local function CurrentWritSceneName()
	return SCENE_MANAGER and SCENE_MANAGER.GetCurrentSceneName and SCENE_MANAGER:GetCurrentSceneName() or nil
end

local function SetWritWatchView(label)
	local watch = BETTERUI.CIM and BETTERUI.CIM.WatchMode
	if not watch then return end
	if label and watch.RegisterViewScene then
		local sceneName = CurrentWritSceneName()
		if sceneName then watch.RegisterViewScene("writs", sceneName) end
	end
	if label and watch.SetView then
		watch.SetView(label)
	elseif not label and watch.ClearView then
		watch.ClearView("writs")
	elseif not label and watch.SetView then
		watch.SetView(nil)
	end
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

local function CountCompletedWritObjectives()
	local count = 0
	for _, writEntry in pairs(Writs.List or {}) do
		local summary = writEntry and writEntry.objectiveSummary
		if type(summary) == "table" and type(summary.completeCount) == "number" then
			count = count + summary.completeCount
		end
	end
	return count
end

local function IsWritPanelVisible()
	local panel = m_writsPanel or rawget(_G, "BETTERUI_WritsPanel")
	local hidden = IsWritSnapshotPanelHidden(panel)
	if hidden == nil then return nil end
	return hidden ~= true
end

local function TraceWritState(trigger, craftType, data)
	data = data or {}
	data.craftType = data.craftType or craftType
	data.activeWritCount = data.activeWritCount or CountWritSnapshotEntries()
	data.completedCount = data.completedCount or CountCompletedWritObjectives()
	if data.panelVisible == nil then
		data.panelVisible = IsWritPanelVisible()
	end
	data.trigger = data.trigger or trigger
	data.feature = data.feature or "writ-state"
	TraceWrit("writs.state", "changed", data, BETTERUI.Log and BETTERUI.Log.CATEGORY.STATE)
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
	local summary = {
		questId = questId,
		stepCount = 1,
		visibleCount = 0,
		completeCount = 0,
		incompleteCount = 0,
		hiddenCount = 0,
		failCount = 0,
		readErrorCount = 0,
		objectives = {},
	}
	if type(GetJournalQuestNumSteps) == "function" then
		local okSteps, numSteps = pcall(GetJournalQuestNumSteps, questId)
		if okSteps and type(numSteps) == "number" and numSteps > 0 then
			summary.stepCount = numSteps
		end
	end
	for stepIndex = 1, summary.stepCount do
		local okConditionCount, conditionCount = pcall(GetJournalQuestNumConditions, questId, stepIndex)
		if not okConditionCount then
			summary.readErrorCount = summary.readErrorCount + 1
			summary.objectives[#summary.objectives + 1] = {
				stepIndex = stepIndex,
				error = "GetJournalQuestNumConditionsFailed",
			}
			conditionCount = 0
		end
		conditionCount = conditionCount or 0
		for lineId = 1, conditionCount do
			local okConditionInfo, writLine, current, maximum, isFailCondition, complete, _, isVisible =
				pcall(GetJournalQuestConditionInfo, questId, stepIndex, lineId)
			if not okConditionInfo then
				summary.readErrorCount = summary.readErrorCount + 1
				summary.objectives[#summary.objectives + 1] = {
					stepIndex = stepIndex,
					lineId = lineId,
					error = "GetJournalQuestConditionInfoFailed",
				}
				writLine = ''
			end
			if isFailCondition then
				summary.failCount = summary.failCount + 1
			elseif isVisible == false then
				summary.hiddenCount = summary.hiddenCount + 1
			end
			-- Skip empty, invisible, or fail conditions
			if writLine ~= '' and isVisible ~= false and not isFailCondition then
				local colour
				if complete then
					colour = Writs.CONST.COLORS.COMPLETE
					summary.completeCount = summary.completeCount + 1
				else
					colour = Writs.CONST.COLORS.INCOMPLETE
					summary.incompleteCount = summary.incompleteCount + 1
				end
				summary.visibleCount = summary.visibleCount + 1
				summary.objectives[#summary.objectives + 1] = {
					text = writLine,
					current = current,
					maximum = maximum,
					complete = complete == true,
					stepIndex = stepIndex,
					lineId = lineId,
				}
				writLines[#writLines + 1] = {
					line = zo_strformat("|c<<1>><<2>>|r", colour, writLine),
					cur = current,
					max = maximum,
					stepIndex = stepIndex,
					lineId = lineId,
				}
			end
		end
	end
	-- Sequential insertion ensures deterministic ordering via ipairs
	for _, line in ipairs(writLines) do
		writConcate = zo_strformat("<<1>><<2>>\n", writConcate, line.line)
	end

	TraceWrit("writ.objectives", "built", summary)
	return writConcate, summary
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
				local writLines, objectiveSummary = Writs.GetFormattedObjectives(questId)
				activeWrits[currentWrit] = {
					id = questId,
					writLines = writLines,
					objectiveSummary = objectiveSummary,
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
function Writs.RefreshActiveWrits(context)
	local nextList = nil
	context = context or {}
	TraceWrit("writ.refresh", "begin", {
		source = context.source,
		craftId = context.craftId,
		event = context.event,
	})
	local ok, err = BETTERUI.CIM.SafeExecute(WRIT_CONTEXT_REFRESH, function()
		nextList = BuildActiveWritLookup()
	end)
	if ok == false then
		TraceWrit("writ.refresh", "error", { error = err })
		TraceWritState("refresh_active_writs", context.craftId, {
			source = context.source,
			event = context.event,
			result = "error",
			error = err,
		})
		return false, err
	end
	Writs.List = nextList or {}
	local count = 0
	for _ in pairs(Writs.List) do count = count + 1 end
	TraceWritState("refresh_active_writs", context.craftId, {
		activeWritCount = count,
		source = context.source,
		event = context.event,
		result = "refreshed",
	})
	TraceWrit("writ.refresh", "end", {
		activeCount = count,
		source = context.source,
		craftId = context.craftId,
		event = context.event,
	})
	return true, nil
end

--- Shows writ progress for the current crafting station.
---@param writType number CRAFTING_TYPE_* constant for the station
---@return boolean ok
---@return string|nil err
function Writs.ShowForCraftType(writType, context)
	context = context or {}
	local normalizedCraftId = tonumber(context.craftId) or tonumber(writType) or writType
	context.craftId = normalizedCraftId
	writType = normalizedCraftId
	TraceWrit("writ.panel", "show_begin", { writType = writType, source = context.source, event = context.event })
	local refreshOk, refreshErr = Writs.RefreshActiveWrits(context)
	if not refreshOk then
		Writs.HidePanel()
		TraceWrit("writ.panel", "show_error", { writType = writType, error = refreshErr, panelHidden = true })
		TraceWritState("show_for_craft_type", writType, {
			source = context.source,
			event = context.event,
			panelVisible = false,
			result = "refresh_error",
			error = refreshErr,
		})
		return false, refreshErr
	end

	local writEntry = Writs.List[writType]
	if writEntry == nil then
		Writs.HidePanel()
		TraceWrit("writ.panel", "no_active_writ", { writType = writType, source = context.source, event = context.event, panelHidden = true })
		TraceWritState("show_for_craft_type", writType, {
			source = context.source,
			event = context.event,
			panelVisible = false,
			result = "no_active_writ",
		})
		return false, "no_active_writ"
	end

	local ok, err = BETTERUI.CIM.SafeExecute(WRIT_CONTEXT_SHOW, function()
		local questName = GetJournalQuestInfo(writEntry.id)
		TraceWrit("writ.panel", "render", {
			writType = writType,
			questId = writEntry.id,
			questName = questName,
			source = context.source,
			objectiveSummary = writEntry.objectiveSummary,
		})
		if m_writNameLabel then
			m_writNameLabel:SetText(zo_strformat("|c0066ff[BETTERUI]|r <<1>>", questName))
		end
		if m_writDescLabel then
			m_writDescLabel:SetText(zo_strformat("<<1>>", writEntry.writLines))
		end
		if m_writsPanel then
			m_writsPanel:SetHidden(false)
			SetWritWatchView("writs.panel")
		end
	end)
	if ok == false then
		Writs.HidePanel()
		TraceWrit("writ.panel", "show_error", { writType = writType, questId = writEntry.id, error = err })
		TraceWritState("show_for_craft_type", writType, {
			source = context.source,
			event = context.event,
			panelVisible = false,
			result = "render_error",
			error = err,
		})
		return false, err
	end
	TraceWrit("writ.panel", "shown", { writType = writType, questId = writEntry.id, source = context.source })
	TraceWritState("show_for_craft_type", writType, {
		source = context.source,
		event = context.event,
		panelVisible = true,
		result = "shown",
	})
	return true, nil
end

--- Hides the writ panel.
---@return nil
function Writs.HidePanel()
	local panel = m_writsPanel or BETTERUI_WritsPanel
	if panel then
		panel:SetHidden(true)
	end
	SetWritWatchView(nil)
	TraceWrit("writ.panel", "hidden", { hadPanel = panel ~= nil })
end
