--[[
File: Modules/ResourceOrbFrames/ResourceOrbFrames.lua
Purpose: Core Orchestrator for the Resource Orb Frames module.
         Coordinates Visuals, Bars, Skills, and Events.
]]

if not BETTERUI.ResourceOrbFrames then BETTERUI.ResourceOrbFrames = {} end
local ResourceOrbFrames = BETTERUI.ResourceOrbFrames

-- Sub-modules
local Visuals = nil
local Bars = nil
local SkillBar = nil
local Events = nil

local NAME = "ResourceOrbFrames"
local BARS  -- resolved after Constants.lua loads (in Initialize)
local XP_NO_ORNAMENT_FALLBACK_OFFSET_X = -350
local MOUNT_NO_ORNAMENT_FALLBACK_OFFSET_X = 350
local BAR_FALLBACK_OFFSET_Y = -20

local m_rootFrame = nil
local m_isInitialized = false
local m_updateDeathFragment = nil

-- Cached Control References (avoid repeated FindControl lookups in hot paths)
local m_bgMiddle = nil
local m_frontBarContainer = nil
local m_backBarContainer = nil
local m_leftOrnament = nil
local m_rightOrnament = nil

-- State Containers
local m_pools = {}
local m_shieldBar = nil
local m_experienceBar = nil
local m_castBar = nil
local m_mountStaminaBar = nil
local m_traceLastActionSuppressionDepth = 0
local m_sceneHandlersRegistered = false
local SuppressNativeBars

local LAST_ACTION_SUPPRESSED_EVENTS = {
    ["resource_orbs.force_layout"] = true,
}

local function GetElemOffset(settings, key)
    local ep = settings and settings.elementPositions
    if not ep or not ep[key] then return 0, 0 end
    return ep[key].offsetX or 0, ep[key].offsetY or 0
end

local ELEMENT_OFFSET_TRACE_KEYS = {
    "leftOrb",
    "rightOrb",
    "skillBars",
    "xpBar",
    "mountBar",
    "castBar",
    "quickslot",
    "companionUltimate",
}

local function BuildElementOffsetSummary(settings)
    local parts = {}
    for _, key in ipairs(ELEMENT_OFFSET_TRACE_KEYS) do
        local x, y = GetElemOffset(settings, key)
        parts[#parts + 1] = key .. ":" .. tostring(x) .. "," .. tostring(y)
    end
    return table.concat(parts, ";")
end

local function GetCurrentSceneName()
    if SCENE_MANAGER and SCENE_MANAGER.GetCurrentScene then
        local scene = SCENE_MANAGER:GetCurrentScene()
        if scene and scene.GetName then
            return scene:GetName()
        end
    end
    return nil
end

local function CapturePowerState()
    local state = {}
    if type(GetUnitPower) ~= "function" then
        return state
    end
    if POWERTYPE_HEALTH ~= nil then
        state.health, state.healthMax = GetUnitPower("player", POWERTYPE_HEALTH)
    end
    if POWERTYPE_MAGICKA ~= nil then
        state.magicka, state.magickaMax = GetUnitPower("player", POWERTYPE_MAGICKA)
    end
    if POWERTYPE_STAMINA ~= nil then
        state.stamina, state.staminaMax = GetUnitPower("player", POWERTYPE_STAMINA)
    end
    if POWERTYPE_ULTIMATE ~= nil then
        state.ultimate, state.ultimateMax = GetUnitPower("player", POWERTYPE_ULTIMATE)
    end
    return state
end

local function TraceROF(event, phase, data, category)
    if not (BETTERUI and BETTERUI.Log and BETTERUI.Log.TraceEvent) then
        return
    end
    data = data or {}
    local updateLastAction = data.updateLastAction
    data.updateLastAction = nil
    local updatesLastAction = updateLastAction == true or (
        updateLastAction == nil
        and m_traceLastActionSuppressionDepth <= 0
        and not LAST_ACTION_SUPPRESSED_EVENTS[event]
    )
    data.updatesLastAction = updatesLastAction
    data.module = data.module or "ResourceOrbFrames"
    data.feature = data.feature or "resource_orbs"
    data.scene = data.scene or GetCurrentSceneName()
    if data.initialized == nil then data.initialized = m_isInitialized end
    if data.hasRootFrame == nil then data.hasRootFrame = m_rootFrame ~= nil end
    if data.gamepadMode == nil and type(IsInGamepadPreferredMode) == "function" then
        data.gamepadMode = IsInGamepadPreferredMode()
    end
    if data.inCombat == nil and type(IsUnitInCombat) == "function" then
        data.inCombat = IsUnitInCombat("player")
    end
    if updatesLastAction and BETTERUI.Log.SetLastAction then
        BETTERUI.Log.SetLastAction({ flow = event, message = event .. ":" .. phase })
    end
    local categories = BETTERUI.Log.CATEGORY or {}
    BETTERUI.Log.TraceEvent(category or categories.STATE, event, phase, data)
end

local function TraceDrag(event, phase, data)
    local L = BETTERUI and BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = data.module or "ResourceOrbFrames"
    data.feature = data.feature or "element-drag"
    data.fn = data.fn or "ElementDrag"
    data["function"] = data["function"] or data.fn
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.STATE or categories.GENERAL, event, phase, data)
end

local function RunTraceWithoutLastAction(callback)
    m_traceLastActionSuppressionDepth = m_traceLastActionSuppressionDepth + 1
    local ok, err = pcall(callback)
    m_traceLastActionSuppressionDepth = m_traceLastActionSuppressionDepth - 1
    if not ok then
        error(err)
    end
end

local function GetControlTraceName(control)
    if not control then return nil end
    local controlType = type(control)
    if controlType ~= "table" and controlType ~= "userdata" then
        return tostring(control)
    end
    local okGetName, getName = pcall(function() return control.GetName end)
    if okGetName and type(getName) == "function" then
        local ok, name = pcall(getName, control)
        if ok and name ~= nil then return tostring(name) end
    end
    local okName, name = pcall(function() return control.name end)
    if okName and name ~= nil then return tostring(name) end
    return tostring(control)
end

local function CallControlNumber(control, methodName)
    if not control then return nil end
    local controlType = type(control)
    if controlType ~= "table" and controlType ~= "userdata" then return nil end
    local okMethod, method = pcall(function() return control[methodName] end)
    if not okMethod then return nil end
    if type(method) ~= "function" then return nil end
    local ok, value = pcall(method, control)
    if ok then return value end
    return nil
end

local function DescribeControlForTrace(control, label)
    if not control then
        return tostring(label) .. ":missing"
    end
    local controlType = type(control)
    if controlType ~= "table" and controlType ~= "userdata" then
        return tostring(label) .. "=" .. tostring(control)
    end
    local parts = { tostring(label) .. "=" .. tostring(GetControlTraceName(control)) }
    local okIsHidden, isHidden = pcall(function() return control.IsHidden end)
    if okIsHidden and type(isHidden) == "function" then
        local ok, hidden = pcall(isHidden, control)
        if ok then parts[#parts + 1] = "hidden:" .. tostring(hidden) end
    end
    local left = CallControlNumber(control, "GetLeft")
    local top = CallControlNumber(control, "GetTop")
    if left ~= nil or top ~= nil then
        parts[#parts + 1] = "xy:" .. tostring(left) .. "," .. tostring(top)
    end
    local width = CallControlNumber(control, "GetWidth")
    local height = CallControlNumber(control, "GetHeight")
    if width ~= nil or height ~= nil then
        parts[#parts + 1] = "wh:" .. tostring(width) .. "," .. tostring(height)
    end
    local okGetScale, getScale = pcall(function() return control.GetScale end)
    if okGetScale and type(getScale) == "function" then
        local ok, scale = pcall(getScale, control)
        if ok then parts[#parts + 1] = "scale:" .. tostring(scale) end
    end
    local okGetAnchor, getAnchor = pcall(function() return control.GetAnchor end)
    if okGetAnchor and type(getAnchor) == "function" then
        local ok, first, second, third, fourth, fifth, sixth = pcall(getAnchor, control, 0)
        local point, relativeTo, relativePoint, offsetX, offsetY
        if ok and type(first) == "boolean" then
            point, relativeTo, relativePoint, offsetX, offsetY = second, third, fourth, fifth, sixth
        elseif ok then
            point, relativeTo, relativePoint, offsetX, offsetY = first, second, third, fourth, fifth
        end
        if ok and point ~= nil then
            parts[#parts + 1] = "anchor:" .. tostring(point) .. ">" .. tostring(GetControlTraceName(relativeTo)) ..
                ":" .. tostring(relativePoint) .. ":" .. tostring(offsetX) .. "," .. tostring(offsetY)
        end
    end
    return table.concat(parts, ";")
end

-- Module-specific TaskManager for managed deferred tasks (Phase 1.1)
-- Using module-specific instance prevents ID collisions with other modules
local function GetROFDeferredTaskRuntime()
    local deferredTask = BETTERUI.CIM and BETTERUI.CIM.DeferredTask
    assert(deferredTask, "BetterUI: CIM.DeferredTask must load before ResourceOrbFrames runtime use")
    return deferredTask
end

local function EnsureResourceOrbFramesTaskManager()
    if not ResourceOrbFrames._taskManager then
        ResourceOrbFrames._taskManager = GetROFDeferredTaskRuntime().CreateManager()
    end
    return ResourceOrbFrames._taskManager
end

local function GetROFTasks()
    ResourceOrbFrames.Tasks = ResourceOrbFrames.Tasks or GetROFDeferredTaskRuntime().CreateLazyManagerProxy(EnsureResourceOrbFramesTaskManager)
    return ResourceOrbFrames.Tasks
end

ResourceOrbFrames.EnsureTaskManager = EnsureResourceOrbFramesTaskManager

local Utils = BETTERUI.ResourceOrbFrames.Utils
local SettingsUtils = Utils.Settings
local ControlUtils = Utils.Controls

local GetSettings = SettingsUtils.Get
local GetLiveSettings = SettingsUtils.GetLive or GetSettings
local GetFrontBarConfig = SettingsUtils.GetCustomFrontBar
local FindControl = ControlUtils.Find

local function IsResourceOrbFramesEnabled()
    local settings = GetSettings and GetSettings() or nil
    return settings and settings.m_enabled == true
end

ResourceOrbFrames.IsEnabled = IsResourceOrbFramesEnabled

local function DescribeActiveWeaponBar()
    if type(GetActiveWeaponPairInfo) ~= "function" then return nil end
    local pair = GetActiveWeaponPairInfo()
    if pair == ACTIVE_WEAPON_PAIR_MAIN then return "main" end
    if pair == ACTIVE_WEAPON_PAIR_BACKUP then return "backup" end
    return tostring(pair)
end

local function IsUltimateReady()
    if not (type(GetSlotAbilityCost) == "function" and type(GetUnitPower) == "function") then return nil end
    local slotIndex = ACTION_BAR_ULTIMATE_SLOT_INDEX and (ACTION_BAR_ULTIMATE_SLOT_INDEX + 1) or nil
    if slotIndex == nil then return nil end
    local hotbar = type(GetActiveHotbarCategory) == "function" and GetActiveHotbarCategory() or nil
    local cost = GetSlotAbilityCost(slotIndex, COMBAT_MECHANIC_FLAGS_ULTIMATE or POWERTYPE_ULTIMATE, hotbar)
    local current = GetUnitPower("player", POWERTYPE_ULTIMATE) or 0
    if not cost or cost <= 0 then return false end
    return current >= cost
end

local function SkipDisabledCallback(fn, event)
    if IsResourceOrbFramesEnabled() then
        return false
    end
    TraceROF(event or "resource_orbs.callback", "skipped_disabled", {
        fn = fn,
        reason = "moduleDisabled",
    })
    return true
end

local function RegisterResourceOrbSnapshotProvider()
    local watch = BETTERUI.CIM and BETTERUI.CIM.WatchMode
    if not (watch and watch.RegisterSnapshotProvider) then
        return
    end
    watch.RegisterSnapshotProvider("resourceOrbs", function()
        local power = CapturePowerState()
        local frontBarCfg = GetFrontBarConfig and GetFrontBarConfig()
        local settings = GetSettings and GetSettings() or {}
        return string.format("init=%s root=%s combat=%s bar=%s ultReady=%s gp=%s hp=%s/%s mag=%s/%s stam=%s/%s front=%s swap=%s scale=%s offset=%s,%s orbOffset=%s,%s linked=%s",
            tostring(m_isInitialized),
            tostring(m_rootFrame ~= nil),
            tostring(type(IsUnitInCombat) == "function" and IsUnitInCombat("player") or nil),
            tostring(DescribeActiveWeaponBar()),
            tostring(IsUltimateReady()),
            tostring(type(IsInGamepadPreferredMode) == "function" and IsInGamepadPreferredMode() or nil),
            tostring(power.health), tostring(power.healthMax),
            tostring(power.magicka), tostring(power.magickaMax),
            tostring(power.stamina), tostring(power.staminaMax),
            tostring(frontBarCfg and frontBarCfg.m_enabled),
            tostring(SkillBar and SkillBar.IsWeaponSwapAnimating and SkillBar.IsWeaponSwapAnimating() or false),
            tostring(settings.scale),
            tostring(settings.offsetX), tostring(settings.offsetY),
            tostring(settings.orbOffsetX), tostring(settings.orbOffsetY),
            DescribeControlForTrace(m_bgMiddle, "bg"))
    end)
end

-- UPDATE HELPERS

local function RefreshAllData()
    if not m_isInitialized then
        TraceROF("resource_orbs.refresh_all", "skipped", {
            fn = "ResourceOrbFrames.RefreshAllData",
            reason = "notInitialized",
        })
        return
    end
    TraceROF("resource_orbs.refresh_all", "begin", {
        fn = "ResourceOrbFrames.RefreshAllData",
        hasDeathFragment = m_updateDeathFragment ~= nil,
        poolCount = m_pools and NonContiguousCount and NonContiguousCount(m_pools) or nil,
        hasShieldBar = m_shieldBar ~= nil,
        hasExperienceBar = m_experienceBar ~= nil,
        hasCastBar = m_castBar ~= nil,
        hasMountStaminaBar = m_mountStaminaBar ~= nil,
        power = CapturePowerState(),
    })
    if m_updateDeathFragment then m_updateDeathFragment() end

    -- Update Power Pools
    for powerType, pool in pairs(m_pools) do
        local powerValue, powerMax = GetUnitPower("player", powerType)
        ZO_StatusBar_SmoothTransition(pool, powerValue, powerMax)
    end

    if m_shieldBar then
        local healthMax = m_pools[POWERTYPE_HEALTH] and m_pools[POWERTYPE_HEALTH]:GetMax() or 1
        m_shieldBar:SetRange(0, healthMax)
        if BETTERUI.CIM.Debug.FLAGS.SHIELD_OVERLAY then
            m_shieldBar:UpdateValue(math.floor(healthMax * 0.65)) -- Debug: show 65% shield for visual tuning
        else
            -- Re-query the live shield value instead of zeroing it. Zeroing
            -- blanked an active ward on every refresh until the next
            -- EVENT_UNIT_ATTRIBUTE_VISUAL_* event arrived.
            local shieldValue = 0
            if type(GetUnitAttributeVisualizerEffectInfo) == "function" then
                shieldValue = GetUnitAttributeVisualizerEffectInfo("player",
                    ATTRIBUTE_VISUAL_POWER_SHIELDING, STAT_MITIGATION,
                    ATTRIBUTE_HEALTH, COMBAT_MECHANIC_FLAGS_HEALTH) or 0
            end
            m_shieldBar:UpdateValue(shieldValue)
        end
    end

    if m_experienceBar then m_experienceBar:Update() end
    if m_castBar then m_castBar:Update() end
    if m_mountStaminaBar then m_mountStaminaBar:Update() end
    TraceROF("resource_orbs.refresh_all", "end", {
        fn = "ResourceOrbFrames.RefreshAllData",
        hasShieldBar = m_shieldBar ~= nil,
        hasExperienceBar = m_experienceBar ~= nil,
        hasCastBar = m_castBar ~= nil,
        hasMountStaminaBar = m_mountStaminaBar ~= nil,
        power = CapturePowerState(),
    })
end

---@param updateOrbs boolean Whether to update orb frame layout
---@param updateSkills boolean Whether to update skill bar layout
local function ApplyLayout(updateOrbs, updateSkills)
    if not m_rootFrame or not m_isInitialized then
        TraceROF("resource_orbs.layout", "skipped", {
            fn = "ResourceOrbFrames.ApplyLayout",
            reason = not m_rootFrame and "missingRootFrame" or "notInitialized",
            updateOrbs = updateOrbs,
            updateSkills = updateSkills,
        })
        return
    end

    local frontBarCfg = GetFrontBarConfig()
    TraceROF("resource_orbs.layout", "begin", {
        fn = "ResourceOrbFrames.ApplyLayout",
        updateOrbs = updateOrbs,
        updateSkills = updateSkills,
        frontBarEnabled = frontBarCfg and frontBarCfg.m_enabled,
        weaponSwapAnimating = SkillBar.IsWeaponSwapAnimating and SkillBar.IsWeaponSwapAnimating() or nil,
        hasBgMiddle = m_bgMiddle ~= nil,
        hasFrontBarContainer = m_frontBarContainer ~= nil,
        hasBackBarContainer = m_backBarContainer ~= nil,
        hasLeftOrnament = m_leftOrnament ~= nil,
        hasRightOrnament = m_rightOrnament ~= nil,
    })

    if updateSkills then
        -- Update Skill Bar Layouts
        SkillBar.UpdateBackBar(m_rootFrame)
        SkillBar.UpdateBackBarLayout(m_rootFrame)
        SkillBar.UpdateMainBarLayout(m_rootFrame)
        if not SkillBar.IsWeaponSwapAnimating() then
            SkillBar.UpdateBarPositions(m_rootFrame)
        end

        -- Custom Front Bar Updates
        local frontBarCfg = GetFrontBarConfig()
        if frontBarCfg and frontBarCfg.m_enabled then
            if not SkillBar.IsWeaponSwapAnimating() then
                SkillBar.UpdateFrontBarLayout(m_rootFrame)
            end
            SkillBar.UpdateFrontBar(m_rootFrame)
            SkillBar.UpdateFrontBarQuickslot(m_rootFrame)
            SkillBar.UpdateFrontBarCompanion(m_rootFrame)
            SkillBar.UpdateFrontBarUltimateMeter(m_rootFrame)
        end
    end

    if updateOrbs then
        -- Update Visuals Layouts
        Visuals.UpdateFrameDimensions(m_rootFrame)
        Visuals.ApplyThemeVisuals(m_rootFrame)
        Visuals.UpdateOrbLayout(m_rootFrame, m_pools, m_shieldBar)
    end

    -- Update Bar Frames Layout (Anchoring) - use cached control references
    local settings = GetLiveSettings() or {}
    local exX, exY = GetElemOffset(settings, "xpBar")
    local moX, moY = GetElemOffset(settings, "mountBar")
    local caX, caY = GetElemOffset(settings, "castBar")
    local loX, loY = GetElemOffset(settings, "leftOrb")
    local roX, roY = GetElemOffset(settings, "rightOrb")
    local sbX, sbY = GetElemOffset(settings, "skillBars")
    if exX ~= 0 or exY ~= 0 or moX ~= 0 or moY ~= 0 or caX ~= 0 or caY ~= 0 or loX ~= 0 or loY ~= 0 or roX ~= 0 or roY ~= 0 or sbX ~= 0 or sbY ~= 0 then
        TraceDrag("resource_orbs.element_offsets", "layout_applied", {
            fn = "ResourceOrbFrames.ApplyLayout",
            exX = exX,
            exY = exY,
            moX = moX,
            moY = moY,
            caX = caX,
            caY = caY,
            loX = loX,
            loY = loY,
            roX = roX,
            roY = roY,
            sbX = sbX,
            sbY = sbY,
            decoupledAnchors = true,
        })
    end

    -- Independent orb offset: ornament-anchored branches follow the ornaments
    -- automatically; bgMiddle-anchored branches must add the offset themselves
    -- so the XP/mount bars stay with the orb composite.
    local orbOffsetX = settings.enableIndependentOrbOffset and (settings.orbOffsetX or 0) or 0
    local orbOffsetY = settings.enableIndependentOrbOffset and (settings.orbOffsetY or 0) or 0
    local elementOffsetSummary = BuildElementOffsetSummary(settings)

    TraceROF("resource_orbs.layout_offsets", "applied", {
        fn = "ResourceOrbFrames.ApplyLayout",
        updateOrbs = updateOrbs,
        updateSkills = updateSkills,
        offsets = elementOffsetSummary,
        independentOrbOffset = settings.enableIndependentOrbOffset == true,
        orbOffsetX = orbOffsetX,
        orbOffsetY = orbOffsetY,
    })

    -- Lazily resolve BARS reference (Constants.lua loads before this runs)
    if not BARS then BARS = BETTERUI.ResourceOrbFrames.CONST.BARS end

    if m_experienceBar and m_experienceBar.control then
        m_experienceBar.control:ClearAnchors()
        if settings.hideLeftOrnament then
            local nx = (BARS.XP.NO_ORNAMENT_OFFSET_X or -350) + orbOffsetX + exX
            local ny = (BARS.XP.NO_ORNAMENT_OFFSET_Y or 108) + orbOffsetY + exY
            m_experienceBar.control:SetAnchor(CENTER, m_bgMiddle, CENTER, nx, ny)
        else
            if m_leftOrnament then
                m_experienceBar.control:SetAnchor(TOP, m_leftOrnament, BOTTOM, BARS.XP.OFFSET_X + exX - loX,
                    BARS.XP.OFFSET_Y + exY - loY)
            else
                m_experienceBar.control:SetAnchor(BOTTOM, m_bgMiddle, BOTTOM, XP_NO_ORNAMENT_FALLBACK_OFFSET_X + orbOffsetX + exX,
                    BAR_FALLBACK_OFFSET_Y + orbOffsetY + exY)
            end
        end
        m_experienceBar:Update()
    end

    if m_mountStaminaBar and m_mountStaminaBar.control then
        m_mountStaminaBar.control:ClearAnchors()
        if settings.hideRightOrnament then
            local nx = (BARS.MOUNT.NO_ORNAMENT_OFFSET_X or 375) + orbOffsetX + moX
            local ny = (BARS.MOUNT.NO_ORNAMENT_OFFSET_Y or 108) + orbOffsetY + moY
            m_mountStaminaBar.control:SetAnchor(CENTER, m_bgMiddle, CENTER, nx, ny)
        else
            if m_rightOrnament then
                m_mountStaminaBar.control:SetAnchor(TOP, m_rightOrnament, BOTTOM, BARS.MOUNT.OFFSET_X + moX - roX,
                    BARS.MOUNT.OFFSET_Y + moY - roY)
            else
                m_mountStaminaBar.control:SetAnchor(BOTTOM, m_bgMiddle, BOTTOM, MOUNT_NO_ORNAMENT_FALLBACK_OFFSET_X + orbOffsetX + moX, BAR_FALLBACK_OFFSET_Y + orbOffsetY + moY)
            end
        end
        m_mountStaminaBar:Update()
    end

    if m_castBar and m_castBar.control then
        m_castBar.control:ClearAnchors()
        if settings.hideBackBar or not m_backBarContainer then
            -- When back bar is hidden (e.g. Oakensoul builds), anchor cast bar to the front bar instead
            if m_frontBarContainer then
                m_castBar.control:SetAnchor(BOTTOM, m_frontBarContainer, TOP, BARS.CAST.OFFSET_X + caX - sbX, BARS.CAST.OFFSET_Y + caY - sbY)
            else
                m_castBar.control:SetAnchor(CENTER, m_bgMiddle, CENTER, BARS.CAST.OFFSET_X + caX, -200 + caY)
            end
        else
            m_castBar.control:SetAnchor(BOTTOM, m_backBarContainer, TOP, BARS.CAST.OFFSET_X + caX - sbX,
                BARS.CAST.OFFSET_Y + caY - sbY)
        end
        m_castBar:Update()
    end
    TraceROF("resource_orbs.layout", "end", {
        fn = "ResourceOrbFrames.ApplyLayout",
        updateOrbs = updateOrbs,
        updateSkills = updateSkills,
        offsets = elementOffsetSummary,
        scale = settings.scale,
        offsetX = settings.offsetX,
        offsetY = settings.offsetY,
        independentOrbOffset = settings.enableIndependentOrbOffset,
        orbOffsetX = orbOffsetX,
        orbOffsetY = orbOffsetY,
        hideLeftOrnament = settings.hideLeftOrnament,
        hideRightOrnament = settings.hideRightOrnament,
        hideBackBar = settings.hideBackBar,
        hasExperienceBar = m_experienceBar ~= nil,
        hasMountStaminaBar = m_mountStaminaBar ~= nil,
        hasCastBar = m_castBar ~= nil,
        rootControl = DescribeControlForTrace(m_rootFrame, "root"),
        bgMiddleControl = DescribeControlForTrace(m_bgMiddle, "bg"),
        frontBarControl = DescribeControlForTrace(m_frontBarContainer, "frontBar"),
        backBarControl = DescribeControlForTrace(m_backBarContainer, "backBar"),
        leftOrnamentControl = DescribeControlForTrace(m_leftOrnament, "leftOrnament"),
        rightOrnamentControl = DescribeControlForTrace(m_rightOrnament, "rightOrnament"),
        xpControl = DescribeControlForTrace(m_experienceBar and m_experienceBar.control, "xp"),
        mountControl = DescribeControlForTrace(m_mountStaminaBar and m_mountStaminaBar.control, "mount"),
        castControl = DescribeControlForTrace(m_castBar and m_castBar.control, "cast"),
    })
end

local function ApplyFullLayout()
    ApplyLayout(true, true)
    if SuppressNativeBars then
        SuppressNativeBars("ApplyFullLayout")
    end
end

local function AttachElementDragHandles()
    if not m_rootFrame then
        TraceROF("resource_orbs.element_drag_handles", "skipped", {
            fn = "ResourceOrbFrames.AttachElementDragHandles",
            reason = "missingRootFrame",
        })
        return
    end
    local drag = ResourceOrbFrames.Drag
    if not (drag and drag.AttachDragHandle) then
        TraceROF("resource_orbs.element_drag_handles", "skipped", {
            fn = "ResourceOrbFrames.AttachElementDragHandles",
            reason = "missingDragApi",
        })
        return
    end

    local attachedCount = 0
    local skippedCount = 0
    local function attach(hostControl, elemKey)
        TraceDrag("resource_orbs.element_drag_handles", "attach_call", { fn = "ResourceOrbFrames.AttachElementDragHandles", elemKey = elemKey, hasHostControl = hostControl ~= nil })
        if not hostControl then
            skippedCount = skippedCount + 1
            TraceROF("resource_orbs.element_drag_handles", "attach_skipped", {
                fn = "ResourceOrbFrames.AttachElementDragHandles",
                elemKey = elemKey,
                reason = "missingHostControl",
            })
            return
        end
        if drag.GetHandle and drag.GetHandle(elemKey) then
            skippedCount = skippedCount + 1
            TraceROF("resource_orbs.element_drag_handles", "attach_skipped", {
                fn = "ResourceOrbFrames.AttachElementDragHandles",
                elemKey = elemKey,
                reason = "alreadyAttached",
                hostControl = DescribeControlForTrace(hostControl, elemKey),
            })
            return
        end
        local handle = drag.AttachDragHandle(hostControl, elemKey, GetLiveSettings, ApplyFullLayout)
        if handle then
            attachedCount = attachedCount + 1
        else
            skippedCount = skippedCount + 1
        end
        TraceROF("resource_orbs.element_drag_handles", handle and "attached" or "attach_failed", {
            fn = "ResourceOrbFrames.AttachElementDragHandles",
            elemKey = elemKey,
            hostControl = DescribeControlForTrace(hostControl, elemKey),
            handleControl = DescribeControlForTrace(handle, elemKey .. "Handle"),
        })
    end

    TraceROF("resource_orbs.element_drag_handles", "begin", {
        fn = "ResourceOrbFrames.AttachElementDragHandles",
    })
    local actionBarContainer = FindControl(m_rootFrame, 'ActionBarContainer')

    local function resolveCustomFrontBarButton(buttonName)
        local getDirect = ControlUtils.GetNamedChildDirect
        local button = getDirect and getDirect(m_frontBarContainer, buttonName) or nil
        if button then return button, "frontBarChild" end
        button = getDirect and getDirect(m_rootFrame, buttonName) or nil
        if button then return button, "rootChild" end
        local cache = SkillBar and SkillBar._frontBarButtonCache and SkillBar._frontBarButtonCache[buttonName] or nil
        if cache and cache.control then return cache.control, "frontBarCache" end
        return nil, "missingCustomControl"
    end
    local quickslotButton, quickslotResolvedVia = resolveCustomFrontBarButton("QuickslotButton")
    local companionButton, companionResolvedVia = resolveCustomFrontBarButton("CompanionButton")
    TraceROF("resource_orbs.element_drag_handles", "custom_buttons_resolved", {
        fn = "ResourceOrbFrames.AttachElementDragHandles",
        quickslotResolvedVia = quickslotResolvedVia,
        companionResolvedVia = companionResolvedVia,
        hasQuickslot = quickslotButton ~= nil,
        hasCompanion = companionButton ~= nil,
    })

    attach(FindControl(m_rootFrame, 'OrbHealth'), "leftOrb")
    attach(FindControl(m_rootFrame, 'OrbResource'), "rightOrb")
    attach(m_frontBarContainer or actionBarContainer, "skillBars")
    attach(m_experienceBar and m_experienceBar.control, "xpBar")
    attach(m_mountStaminaBar and m_mountStaminaBar.control, "mountBar")
    attach(m_castBar and m_castBar.control, "castBar")
    attach(quickslotButton, "quickslot")
    attach(companionButton, "companionUltimate")
    TraceROF("resource_orbs.element_drag_handles", "end", {
        fn = "ResourceOrbFrames.AttachElementDragHandles",
        attachedCount = attachedCount,
        skippedCount = skippedCount,
    })
end

-- INITIALIZATION HELPERS

local function GetSkillBarModule()
    return SkillBar or BETTERUI.ResourceOrbFrames.SkillBar
end

--- Replays front bar handlers (keybinds, press feedback, tooltips).
---@param control table Root ResourceOrbFrames control
local function SetupFrontBarHandlers(control)
    local skillBar = GetSkillBarModule()
    TraceROF("resource_orbs.front_bar_handlers", "begin", {
        fn = "ResourceOrbFrames.SetupFrontBarHandlers",
        hasControl = control ~= nil,
        hasKeybindSetup = skillBar and skillBar.SetupFrontBarKeybinds ~= nil,
        hasPressFeedbackSetup = skillBar and skillBar.SetupFrontBarPressFeedbackHooks ~= nil,
        hasTooltipSetup = skillBar and skillBar.SetupFrontBarTooltips ~= nil,
    })
    if skillBar.SetupFrontBarKeybinds then
        skillBar.SetupFrontBarKeybinds(control)
    end
    if skillBar.SetupFrontBarPressFeedbackHooks then
        skillBar.SetupFrontBarPressFeedbackHooks(control)
    end
    if skillBar.SetupFrontBarTooltips then
        skillBar.SetupFrontBarTooltips(control)
    end
    TraceROF("resource_orbs.front_bar_handlers", "end", {
        fn = "ResourceOrbFrames.SetupFrontBarHandlers",
        hasControl = control ~= nil,
    })
end

--- Suppresses native action bar and attribute bars.
SuppressNativeBars = function(source)
    local skillBar = GetSkillBarModule()
    TraceROF("resource_orbs.native_bars", "suppress_begin", {
        fn = "ResourceOrbFrames.SuppressNativeBars",
        source = source,
        updateLastAction = source ~= "ApplyFullLayout",
        hasHideNativeActionBar = skillBar and skillBar.HideNativeActionBar ~= nil,
        hasAttributeBarsFragment = PLAYER_ATTRIBUTE_BARS_FRAGMENT ~= nil,
    })
    if skillBar and skillBar.HideNativeActionBar then
        skillBar.HideNativeActionBar(source)
    end
    if PLAYER_ATTRIBUTE_BARS_FRAGMENT then
        PLAYER_ATTRIBUTE_BARS_FRAGMENT:SetHiddenForReason('ResourceOrbFrames', true)
    end
    TraceROF("resource_orbs.native_bars", "suppress_end", {
        fn = "ResourceOrbFrames.SuppressNativeBars",
        source = source,
        updateLastAction = source ~= "ApplyFullLayout",
        hiddenReason = "ResourceOrbFrames",
    })
end

--- Restores native action bar and attribute bars when the module is disabled.
local function RestoreNativeBars()
    local skillBar = GetSkillBarModule()
    TraceROF("resource_orbs.native_bars", "restore_begin", {
        fn = "ResourceOrbFrames.RestoreNativeBars",
        hasRestoreNativeActionBar = skillBar and skillBar.RestoreNativeActionBar ~= nil,
        hasAttributeBarsFragment = PLAYER_ATTRIBUTE_BARS_FRAGMENT ~= nil,
    })
    if PLAYER_ATTRIBUTE_BARS_FRAGMENT then
        PLAYER_ATTRIBUTE_BARS_FRAGMENT:SetHiddenForReason('ResourceOrbFrames', false)
    end
    if skillBar and skillBar.RestoreNativeActionBar then
        skillBar.RestoreNativeActionBar()
    end
    -- Restore the native cast-bar controls that OrbBars suppressed.
    if Bars and Bars.RestoreDefaultCastBar then
        Bars.RestoreDefaultCastBar()
    end
    TraceROF("resource_orbs.native_bars", "restore_end", {
        fn = "ResourceOrbFrames.RestoreNativeBars",
        hiddenReason = "ResourceOrbFrames",
    })
end

--- Registers all dynamic event callbacks after initial component setup.
---@param control table Root ResourceOrbFrames control
local function RegisterDynamicEvents(control)
    TraceROF("resource_orbs.events", "register_begin", {
        fn = "ResourceOrbFrames.RegisterDynamicEvents",
        hasControl = control ~= nil,
    })    
    -- Layout force update (skip during weapon swap animation to prevent orb shifting)
    -- P2(compatibility): This callback stays registered while the module is
    -- disabled; it early-exits via SkipDisabledCallback, but it still runs on
    -- every BetterUI_ForceLayoutUpdate broadcast. If other modules fire this
    -- callback frequently, consider unregistering when disabled.
    CALLBACK_MANAGER:RegisterCallback("BetterUI_ForceLayoutUpdate", function()
        RunTraceWithoutLastAction(function()
            if SkipDisabledCallback("ResourceOrbFrames.BetterUI_ForceLayoutUpdate", "resource_orbs.force_layout") then return end
            local isAnimating = SkillBar.IsWeaponSwapAnimating and SkillBar.IsWeaponSwapAnimating()
            TraceROF("resource_orbs.force_layout", isAnimating and "skipped" or "received", {
                fn = "ResourceOrbFrames.BetterUI_ForceLayoutUpdate",
                reason = isAnimating and "weaponSwapAnimating" or nil,
                hasRefreshCombatIndicators = Events.RefreshCombatIndicators ~= nil,
            })
            if not isAnimating then
                ApplyFullLayout()
                if Events.RefreshCombatIndicators then
                    Events.RefreshCombatIndicators(control)
                end
                TraceROF("resource_orbs.force_layout", "end", {
                    fn = "ResourceOrbFrames.BetterUI_ForceLayoutUpdate",
                    refreshedCombatIndicators = Events.RefreshCombatIndicators ~= nil,
                })
            end
        end)
    end)

    -- Gamepad switch (dynamic re-skin instead of ReloadUI)
    BETTERUI.CIM.EventRegistry.Register("BETTERUI_ResourceOrbFrames", NAME, EVENT_GAMEPAD_PREFERRED_MODE_CHANGED, function()
        if SkipDisabledCallback("ResourceOrbFrames.EVENT_GAMEPAD_PREFERRED_MODE_CHANGED", "resource_orbs.gamepad_mode") then return end
        if not m_isInitialized or not m_rootFrame then
            TraceROF("resource_orbs.gamepad_mode", "skipped", {
                fn = "ResourceOrbFrames.EVENT_GAMEPAD_PREFERRED_MODE_CHANGED",
                reason = not m_rootFrame and "missingRootFrame" or "notInitialized",
            })
            return
        end

        TraceROF("resource_orbs.gamepad_mode", "begin", {
            fn = "ResourceOrbFrames.EVENT_GAMEPAD_PREFERRED_MODE_CHANGED",
            stoppingWeaponSwapAnimation = SkillBar.StopWeaponSwapAnimation ~= nil,
            frontBarControlsCached = SkillBar.CacheFrontBarControls ~= nil,
            backBarControlsCached = SkillBar.CacheBackBarControls ~= nil,
        })

        if SkillBar.StopWeaponSwapAnimation then
            SkillBar.StopWeaponSwapAnimation(m_rootFrame)
        end

        -- Re-apply mode-specific XML template and action bar skin.
        local isGP = IsInGamepadPreferredMode()
        local gpLayout = isGP and BETTERUI.ResourceOrbFrames.CONST.LAYOUT_CONFIG.GAMEPAD or BETTERUI.ResourceOrbFrames.CONST.LAYOUT_CONFIG.KEYBOARD
        SkillBar.ApplyActionBarSkin(m_rootFrame, gpLayout)

        -- Re-cache button children after the re-skin so the cooldown loops
        -- keep using cached controls.
        if SkillBar.CacheFrontBarControls then
            SkillBar.CacheFrontBarControls(m_rootFrame)
        end
        if SkillBar.CacheBackBarControls then
            SkillBar.CacheBackBarControls(m_rootFrame)
        end

        -- Replay the post-skin setup sequence. SetParent is intentionally NOT repeated:
        -- ApplyTemplateToControl does not destroy/recreate controls.
        local cfg = GetFrontBarConfig()
        if cfg and cfg.m_enabled then
            SkillBar.UpdateFrontBar(m_rootFrame)
            SkillBar.UpdateFrontBarQuickslot(m_rootFrame)
            SkillBar.UpdateFrontBarCompanion(m_rootFrame)
            SkillBar.UpdateFrontBarUltimateMeter(m_rootFrame)
            SetupFrontBarHandlers(m_rootFrame)
        end

        ApplyFullLayout()
        RefreshAllData()
        SuppressNativeBars()

        if Events.RefreshCombatIndicators then
            Events.RefreshCombatIndicators(m_rootFrame)
        end
        TraceROF("resource_orbs.gamepad_mode", "end", {
            fn = "ResourceOrbFrames.EVENT_GAMEPAD_PREFERRED_MODE_CHANGED",
            frontBarEnabled = cfg and cfg.m_enabled,
            refreshedCombatIndicators = Events.RefreshCombatIndicators ~= nil,
            power = CapturePowerState(),
        })
    end)

    -- Dynamic bar updates
    BETTERUI.CIM.EventRegistry.Register("BETTERUI_ResourceOrbFrames", NAME .. "_BackBar", EVENT_ACTIVE_WEAPON_PAIR_CHANGED,
        function()
            if SkipDisabledCallback("ResourceOrbFrames.EVENT_ACTIVE_WEAPON_PAIR_CHANGED", "resource_orbs.weapon_pair") then return end
            TraceROF("resource_orbs.weapon_pair", "changed", {
                fn = "ResourceOrbFrames.EVENT_ACTIVE_WEAPON_PAIR_CHANGED",
                delayMs = BETTERUI.CIM.CONST.TIMING.WEAPON_SWAP_LAYOUT_DELAY_MS,
            })
            SkillBar.WeaponSwapAnimation(control)
            TraceROF("resource_orbs.weapon_pair", "layout_scheduled", {
                fn = "ResourceOrbFrames.EVENT_ACTIVE_WEAPON_PAIR_CHANGED",
                task = "weaponSwapLayout",
                delayMs = BETTERUI.CIM.CONST.TIMING.WEAPON_SWAP_LAYOUT_DELAY_MS,
            })
            GetROFTasks():Schedule("weaponSwapLayout", BETTERUI.CIM.CONST.TIMING.WEAPON_SWAP_LAYOUT_DELAY_MS,
                function()
                    if SkipDisabledCallback("ResourceOrbFrames.weaponSwapLayout", "resource_orbs.weapon_pair") then return end
                    TraceROF("resource_orbs.weapon_pair", "layout_task", {
                        fn = "ResourceOrbFrames.weaponSwapLayout",
                    })
                    ApplyLayout(false, true)
                    if SuppressNativeBars then
                        SuppressNativeBars("weaponSwapLayout")
                    end
                end)
        end)

    BETTERUI.CIM.EventRegistry.Register("BETTERUI_ResourceOrbFrames", NAME .. "_BackBarSlots", EVENT_ACTION_SLOTS_FULL_UPDATE,
        function()
            if SkipDisabledCallback("ResourceOrbFrames.EVENT_ACTION_SLOTS_FULL_UPDATE", "resource_orbs.action_slots") then return end
            local cfg = GetFrontBarConfig()
            TraceROF("resource_orbs.action_slots", "full_update", {
                fn = "ResourceOrbFrames.EVENT_ACTION_SLOTS_FULL_UPDATE",
                frontBarEnabled = cfg and cfg.m_enabled,
            })
            SkillBar.UpdateBackBar(control)
            if cfg and cfg.m_enabled then SkillBar.UpdateFrontBar(control) end
            ApplyLayout(false, true)
            if SuppressNativeBars then
                SuppressNativeBars("EVENT_ACTION_SLOTS_FULL_UPDATE")
            end
            TraceROF("resource_orbs.action_slots", "full_update_end", {
                fn = "ResourceOrbFrames.EVENT_ACTION_SLOTS_FULL_UPDATE",
                frontBarUpdated = cfg and cfg.m_enabled,
            })
        end)

    BETTERUI.CIM.EventRegistry.Register("BETTERUI_ResourceOrbFrames", NAME .. "_BackBarSlot", EVENT_ACTION_SLOT_UPDATED,
        function(_, slotIndex)
            if SkipDisabledCallback("ResourceOrbFrames.EVENT_ACTION_SLOT_UPDATED", "resource_orbs.action_slot") then return end
            local cfg = GetFrontBarConfig()
            TraceROF("resource_orbs.action_slot", "updated", {
                fn = "ResourceOrbFrames.EVENT_ACTION_SLOT_UPDATED",
                slotIndex = slotIndex,
                frontBarEnabled = cfg and cfg.m_enabled,
            })
            SkillBar.UpdateBackBar(control)
            if cfg and cfg.m_enabled then SkillBar.UpdateFrontBar(control) end
            if SuppressNativeBars then
                SuppressNativeBars("EVENT_ACTION_SLOT_UPDATED")
            end
            TraceROF("resource_orbs.action_slot", "updated_end", {
                fn = "ResourceOrbFrames.EVENT_ACTION_SLOT_UPDATED",
                slotIndex = slotIndex,
                frontBarUpdated = cfg and cfg.m_enabled,
            })
        end)

    BETTERUI.CIM.EventRegistry.Register("BETTERUI_ResourceOrbFrames", NAME .. "_CompanionState",
        EVENT_ACTIVE_COMPANION_STATE_CHANGED, function()
            if SkipDisabledCallback("ResourceOrbFrames.EVENT_ACTIVE_COMPANION_STATE_CHANGED", "resource_orbs.companion") then return end
            local cfg = GetFrontBarConfig()
            TraceROF("resource_orbs.companion", "state_changed", {
                fn = "ResourceOrbFrames.EVENT_ACTIVE_COMPANION_STATE_CHANGED",
                frontBarEnabled = cfg and cfg.m_enabled,
                delayMs = BETTERUI.CIM.CONST.TIMING.SCENE_HANDLER_DELAY_MS,
            })
            if cfg and cfg.m_enabled then
                SkillBar.UpdateFrontBarCompanion(control)
            end
            TraceROF("resource_orbs.companion", "layout_scheduled", {
                fn = "ResourceOrbFrames.EVENT_ACTIVE_COMPANION_STATE_CHANGED",
                task = "companionLayout",
                frontBarUpdated = cfg and cfg.m_enabled,
                delayMs = BETTERUI.CIM.CONST.TIMING.SCENE_HANDLER_DELAY_MS,
            })
            GetROFTasks():Schedule("companionLayout", BETTERUI.CIM.CONST.TIMING.SCENE_HANDLER_DELAY_MS, function()
                if SkipDisabledCallback("ResourceOrbFrames.companionLayout", "resource_orbs.companion") then return end
                TraceROF("resource_orbs.companion", "layout_task", {
                    fn = "ResourceOrbFrames.companionLayout",
                })
                ApplyFullLayout()
            end)
        end)

    BETTERUI.CIM.EventRegistry.Register("BETTERUI_ResourceOrbFrames", NAME .. "_Quickslot", EVENT_ACTIVE_QUICKSLOT_CHANGED,
        function()
            if SkipDisabledCallback("ResourceOrbFrames.EVENT_ACTIVE_QUICKSLOT_CHANGED", "resource_orbs.quickslot") then return end
            local cfg = GetFrontBarConfig()
            TraceROF("resource_orbs.quickslot", "changed", {
                fn = "ResourceOrbFrames.EVENT_ACTIVE_QUICKSLOT_CHANGED",
                frontBarEnabled = cfg and cfg.m_enabled,
            })
            if cfg and cfg.m_enabled then
                SkillBar.UpdateFrontBarQuickslot(control)
            end
            TraceROF("resource_orbs.quickslot", "changed_end", {
                fn = "ResourceOrbFrames.EVENT_ACTIVE_QUICKSLOT_CHANGED",
                frontBarUpdated = cfg and cfg.m_enabled,
            })
        end)

    BETTERUI.CIM.EventRegistry.RegisterFiltered("BETTERUI_ResourceOrbFrames", NAME .. "_FrontBarPressFeedbackAbilityUsed",
        EVENT_ACTION_SLOT_ABILITY_USED, function(_, slotIndex)
            if SkipDisabledCallback("ResourceOrbFrames.EVENT_ACTION_SLOT_ABILITY_USED", "resource_orbs.press_feedback") then return end
            if not slotIndex then
                TraceROF("resource_orbs.press_feedback", "skipped", {
                    fn = "ResourceOrbFrames.EVENT_ACTION_SLOT_ABILITY_USED",
                    reason = "missingSlotIndex",
                })
                return
            end
            local frontBarSettings = GetFrontBarConfig()
            if not frontBarSettings or not frontBarSettings.m_enabled then
                TraceROF("resource_orbs.press_feedback", "skipped", {
                    fn = "ResourceOrbFrames.EVENT_ACTION_SLOT_ABILITY_USED",
                    reason = "frontBarDisabled",
                    slotIndex = slotIndex,
                })
                return
            end
            if SkillBar.PlayFrontBarPressFeedbackForSlot then
                TraceROF("resource_orbs.press_feedback", "play", {
                    fn = "ResourceOrbFrames.EVENT_ACTION_SLOT_ABILITY_USED",
                    slotIndex = slotIndex,
                    fromAbilityUsedEvent = true,
                })
                SkillBar.PlayFrontBarPressFeedbackForSlot(control, slotIndex, nil, true)
            else
                TraceROF("resource_orbs.press_feedback", "skipped", {
                    fn = "ResourceOrbFrames.EVENT_ACTION_SLOT_ABILITY_USED",
                    reason = "handlerMissing",
                    slotIndex = slotIndex,
                })
            end
        end, REGISTER_FILTER_UNIT_TAG, "player")

    -- Zone change cleanup (for subsequent zones after initial setup)
    BETTERUI.CIM.EventRegistry.Register("BETTERUI_ResourceOrbFrames", NAME .. "_PlayerActivated", EVENT_PLAYER_ACTIVATED,
        function()
            if SkipDisabledCallback("ResourceOrbFrames.EVENT_PLAYER_ACTIVATED", "resource_orbs.player_activated") then return end
            TraceROF("resource_orbs.player_activated", "received", {
                fn = "ResourceOrbFrames.EVENT_PLAYER_ACTIVATED",
                delayMs = BETTERUI.CIM.CONST.TIMING.PLAYER_ACTIVATED_INIT_MS,
            })
            GetROFTasks():Schedule("playerActivatedRefresh", BETTERUI.CIM.CONST.TIMING.PLAYER_ACTIVATED_INIT_MS, function()
                if SkipDisabledCallback("ResourceOrbFrames.playerActivatedRefresh", "resource_orbs.player_activated") then return end
                TraceROF("resource_orbs.player_activated", "refresh_task", {
                    fn = "ResourceOrbFrames.playerActivatedRefresh",
                    hasRefreshCombatIndicators = Events.RefreshCombatIndicators ~= nil,
                })
                SuppressNativeBars()
                ApplyFullLayout()
                RefreshAllData()
                if Events.RefreshCombatIndicators then
                    Events.RefreshCombatIndicators(control)
                end
                TraceROF("resource_orbs.player_activated", "refresh_end", {
                    fn = "ResourceOrbFrames.playerActivatedRefresh",
                    refreshedCombatIndicators = Events.RefreshCombatIndicators ~= nil,
                    power = CapturePowerState(),
                })
            end)
        end)
    TraceROF("resource_orbs.events", "register_end", {
        fn = "ResourceOrbFrames.RegisterDynamicEvents",
        hasControl = control ~= nil,
    })
end

-- INITIALIZATION

-- Latches so a retried SetupModule (e.g. after a partial SafeExecute failure
-- in ApplySettings) never double-creates components or double-registers
-- events. Component creation also reuses any controls that already exist.
local m_dynamicEventsRegistered = false

---@param control table Root ResourceOrbFrames control
local function SetupModule(control)
    m_rootFrame = control
    TraceROF("resource_orbs.setup", "begin", {
        fn = "ResourceOrbFrames.SetupModule",
        hasControl = control ~= nil,
        alreadyInitialized = m_isInitialized,
        dynamicEventsRegistered = m_dynamicEventsRegistered,
    })
    RegisterResourceOrbSnapshotProvider()

    -- 1. Load Sub-modules (ensure they are ready)
    Visuals = BETTERUI.ResourceOrbFrames.Visuals
    Bars = BETTERUI.ResourceOrbFrames.Bars
    SkillBar = BETTERUI.ResourceOrbFrames.SkillBar
    Events = BETTERUI.ResourceOrbFrames.Events

    -- 2. Cache Control References (avoid repeated FindControl lookups in ApplyLayout)
    m_bgMiddle = FindControl(control, 'BgMiddle')
    m_frontBarContainer = FindControl(control, 'FrontBarContainer')
    m_backBarContainer = FindControl(control, 'BackBarContainer')
    m_leftOrnament = FindControl(control, 'OrnamentLeft')
    m_rightOrnament = FindControl(control, 'OrnamentRight')
    TraceROF("resource_orbs.setup", "controls_cached", {
        fn = "ResourceOrbFrames.SetupModule",
        hasBgMiddle = m_bgMiddle ~= nil,
        hasFrontBarContainer = m_frontBarContainer ~= nil,
        hasBackBarContainer = m_backBarContainer ~= nil,
        hasLeftOrnament = m_leftOrnament ~= nil,
        hasRightOrnament = m_rightOrnament ~= nil,
    })

    -- 3. Setup Visual Components (reuse instances on retried setup)
    if not next(m_pools) then
        m_pools = Visuals.SetupPowerPools(control)
    end
    m_shieldBar = m_shieldBar or Visuals.SetupShieldBar(control, m_pools)
    m_experienceBar = m_experienceBar or Bars.CreateExperienceBar(control)
    m_castBar = m_castBar or Bars.CreateCastBar(control)
    m_mountStaminaBar = m_mountStaminaBar or Bars.CreateMountStaminaBar(control)
    TraceROF("resource_orbs.setup", "components_ready", {
        fn = "ResourceOrbFrames.SetupModule",
        poolCount = m_pools and NonContiguousCount and NonContiguousCount(m_pools) or nil,
        hasShieldBar = m_shieldBar ~= nil,
        hasExperienceBar = m_experienceBar ~= nil,
        hasCastBar = m_castBar ~= nil,
        hasMountStaminaBar = m_mountStaminaBar ~= nil,
    })

    -- 4. Setup Events & Visibility (latched: fragments register callbacks once)
    if not m_updateDeathFragment then
        m_updateDeathFragment = Events.SetupVisibilityFragments(control)
    end

    -- 5. Apply Initial Skin & Layout
    local isGamePad = IsInGamepadPreferredMode()
    local layout = isGamePad and BETTERUI.ResourceOrbFrames.CONST.LAYOUT_CONFIG.GAMEPAD or BETTERUI.ResourceOrbFrames.CONST.LAYOUT_CONFIG.KEYBOARD
    SkillBar.ApplyActionBarSkin(control, layout)
    TraceROF("resource_orbs.setup", "skin_applied", {
        fn = "ResourceOrbFrames.SetupModule",
        gamepadMode = isGamePad,
        hasLayout = layout ~= nil,
    })

    local frontBarCfg = GetFrontBarConfig()
    TraceROF("resource_orbs.setup", "front_bar_config", {
        fn = "ResourceOrbFrames.SetupModule",
        frontBarEnabled = frontBarCfg and frontBarCfg.m_enabled,
    })
    if frontBarCfg and frontBarCfg.m_enabled then
        local frontBarContainer = FindControl(control, 'FrontBarContainer')
        if frontBarContainer then
            local qsBtn = FindControl(frontBarContainer, 'QuickslotButton')
            if qsBtn then qsBtn:SetParent(control) end
            local compBtn = FindControl(frontBarContainer, 'CompanionButton')
            if compBtn then compBtn:SetParent(control) end
            local invalidateControlCache = BETTERUI.ControlUtils and BETTERUI.ControlUtils.InvalidateControlCache
            if type(invalidateControlCache) == "function" then
                invalidateControlCache()
            end
        end
        SkillBar.UpdateFrontBar(control)
        SetupFrontBarHandlers(control)
    end

    -- Cache front/back bar control references after the skin is applied and
    -- the quickslot/companion buttons are reparented, so the 16ms cooldown
    -- loops read cached children instead of GetNamedChild fallbacks.
    if SkillBar.CacheFrontBarControls then
        SkillBar.CacheFrontBarControls(control)
    end
    if SkillBar.CacheBackBarControls then
        SkillBar.CacheBackBarControls(control)
    end

    AttachElementDragHandles()
    Visuals.UpdateOrbLayout(control, m_pools, m_shieldBar)
    RefreshAllData()

    -- 6. Setup Event Loops
    Events.SetupLoopEvents(control, m_pools, m_shieldBar, m_castBar)
    Events.SetupSceneHandlers(control)
    if Events.SetupCombatIndicators then
        Events.SetupCombatIndicators(control)
    end

    m_isInitialized = true

    -- 7. Register Dynamic Events (latched against retried setup)
    if not m_dynamicEventsRegistered then
        m_dynamicEventsRegistered = true
        RegisterDynamicEvents(control)
    end
end

-- PUBLIC INTERFACE

--- Initializes the ResourceOrbFrames module from the XML OnInitialized handler.
---@param control table Root UI control created from XML template
function ResourceOrbFrames.Initialize(control)
    m_rootFrame = control
    TraceROF("resource_orbs.initialize", "begin", {
        fn = "ResourceOrbFrames.Initialize",
        hasControl = control ~= nil,
    })

    -- Defer full setup until player is actually in the world
    -- This ensures all ESO UI fragments and systems are ready
    -- Guard: m_isInitialized check in DeferredTask callback (L331) prevents double SetupModule()
    BETTERUI.CIM.EventRegistry.Register("BETTERUI_ResourceOrbFrames", NAME .. "_InitSetup", EVENT_PLAYER_ACTIVATED, function()
        TraceROF("resource_orbs.initialize", "player_activated", {
            fn = "ResourceOrbFrames.EVENT_PLAYER_ACTIVATED:init",
        })
        -- Unregister through the registry so its bookkeeping stays accurate.
        BETTERUI.CIM.EventRegistry.Unregister("ResourceOrbFrames", NAME .. "_InitSetup", EVENT_PLAYER_ACTIVATED)

        GetROFTasks():Schedule("initModuleSetup", BETTERUI.CIM.CONST.TIMING.DEFERRED_INIT_MS, function()
            local settings = GetSettings()
            if not settings or not settings.m_enabled then
                m_rootFrame:SetHidden(true)
                TraceROF("resource_orbs.initialize", "setup_skipped", {
                    fn = "ResourceOrbFrames.initModuleSetup",
                    reason = not settings and "missingSettings" or "moduleDisabled",
                })
                return
            end

            if not m_isInitialized then
                TraceROF("resource_orbs.initialize", "setup_begin", {
                    fn = "ResourceOrbFrames.initModuleSetup",
                })
                local ok = BETTERUI.CIM.SafeExecute("ResourceOrbFrames:Initialize:SetupModule", SetupModule, control)
                if not ok then
                    TraceROF("resource_orbs.initialize", "setup_failed", {
                        fn = "ResourceOrbFrames.initModuleSetup",
                        error = "SafeExecuteFailed",
                    })
                    return
                end
            end

            -- Enforce state after setup
            SkillBar.HideNativeActionBar()
            if PLAYER_ATTRIBUTE_BARS_FRAGMENT then
                PLAYER_ATTRIBUTE_BARS_FRAGMENT:SetHiddenForReason('ResourceOrbFrames', true)
            end
            ApplyFullLayout()
            RefreshAllData()
            if Events.RefreshCombatIndicators then
                Events.RefreshCombatIndicators(control)
            end
            TraceROF("resource_orbs.initialize", "end", {
                fn = "ResourceOrbFrames.initModuleSetup",
                initialized = m_isInitialized,
                refreshedCombatIndicators = Events.RefreshCombatIndicators ~= nil,
            })
        end)
    end)
end

--- Applies current settings to the orb frames, toggling visibility and layout.
---@return nil
function ResourceOrbFrames.ApplySettings()
    local settings = GetSettings()
    local lifecycleCategory = BETTERUI.Log and BETTERUI.Log.CATEGORY and BETTERUI.Log.CATEGORY.LIFECYCLE or nil
    if not m_rootFrame then
        TraceROF("resource_orbs.apply_settings", "skipped", {
            fn = "ResourceOrbFrames.ApplySettings",
            reason = "missingRootFrame",
        }, lifecycleCategory)
        if BETTERUI.Log then
            BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.LIFECYCLE, "orb setup aborted", { reason = "rootFrame" })
        end
        return
    end
    if not settings then
        TraceROF("resource_orbs.apply_settings", "skipped", {
            fn = "ResourceOrbFrames.ApplySettings",
            reason = "missingSettings",
        }, lifecycleCategory)
        if BETTERUI.Log then
            BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.LIFECYCLE, "orb setup aborted", { reason = "settings" })
        end
        return
    end

    TraceROF("resource_orbs.apply_settings", "begin", {
        fn = "ResourceOrbFrames.ApplySettings",
        enabled = settings.m_enabled == true,
    }, lifecycleCategory)
    if settings.m_enabled then
        if not m_isInitialized then
            -- Attempt initialization; if it fails, bail out
            local ok = BETTERUI.CIM.SafeExecute("ResourceOrbFrames:SetupModule", SetupModule, m_rootFrame)
            if not ok then
                TraceROF("resource_orbs.apply_settings", "setup_failed", {
                    fn = "ResourceOrbFrames.ApplySettings",
                }, lifecycleCategory)
                if BETTERUI.Log then
                    BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.LIFECYCLE, "orb setup aborted", { reason = "setupFailed" })
                end
                return
            end
        end
        -- Double-check initialization succeeded before proceeding
        if not m_isInitialized then
            TraceROF("resource_orbs.apply_settings", "skipped", {
                fn = "ResourceOrbFrames.ApplySettings",
                reason = "setupDidNotInitialize",
            }, lifecycleCategory)
            return
        end
        if BETTERUI.Log then
            BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.LIFECYCLE, "orb apply settings enabled")
        end
        m_rootFrame:SetHidden(false)
        -- Re-register the periodic update loops on enable.
        if Events.SetLoopsEnabled then
            Events.SetLoopsEnabled(true)
        end
        -- Guard scene-handler registration so repeated enable toggles do not
        -- accumulate SCENE_MANAGER callbacks if Events.SetupSceneHandlers is not
        -- internally idempotent.
        if Events.SetupSceneHandlers and not m_sceneHandlersRegistered then
            Events.SetupSceneHandlers(m_rootFrame)
            m_sceneHandlersRegistered = true
        end
        ApplyFullLayout()
        RefreshAllData()
        if Events.RefreshCombatIndicators then
            Events.RefreshCombatIndicators(m_rootFrame)
        end
        TraceROF("resource_orbs.apply_settings", "enabled", {
            fn = "ResourceOrbFrames.ApplySettings",
            loopsRegistered = Events.SetLoopsEnabled ~= nil,
            sceneHandlersRequested = Events.SetupSceneHandlers ~= nil,
            refreshedCombatIndicators = Events.RefreshCombatIndicators ~= nil,
        }, lifecycleCategory)
    else
        if BETTERUI.Log then
            BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.LIFECYCLE, "orb apply settings disabled")
        end
        m_rootFrame:SetHidden(true)
        -- Stop the periodic update loops so a disabled module pays no
        -- per-tick cost (re-registered on enable above).
        local events = Events or BETTERUI.ResourceOrbFrames.Events
        if events and events.SetLoopsEnabled then
            events.SetLoopsEnabled(false)
        end
        RestoreNativeBars()
        TraceROF("resource_orbs.apply_settings", "disabled", {
            fn = "ResourceOrbFrames.ApplySettings",
            loopsDisabled = events and events.SetLoopsEnabled ~= nil,
            callbacksGuarded = true,
            nativeBarsRestored = true,
        }, lifecycleCategory)
    end
end

--- Global XML Handler (Bridge)
---@param control table Root UI control from XML
function ResourceOrbFrames_Initialize(control)
    ResourceOrbFrames.Initialize(control)
end

ResourceOrbFrames._Internals = {
    SetupFrontBarHandlers = SetupFrontBarHandlers,
    SuppressNativeBars = SuppressNativeBars,
    RestoreNativeBars = RestoreNativeBars,
}
