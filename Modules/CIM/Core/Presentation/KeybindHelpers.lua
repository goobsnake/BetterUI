--[[
File: Modules/CIM/Core/Presentation/KeybindHelpers.lua
Purpose: Keybind utility functions shared across BetterUI modules.


]]

BETTERUI.Interface = BETTERUI.Interface or {}

local function GetKeybindStrip()
    return rawget(_G, "KEYBIND_STRIP")
end

local function TraceKeybindHelper(event, data)
    if BETTERUI.Log and BETTERUI.Log.Trace then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.KEYBIND, event, data or {})
    end
end

local function WarnKeybindHelper(event, data)
    if BETTERUI.Log and BETTERUI.Log.Warn then
        BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.KEYBIND, event, data or {})
    end
end

--- HOT-path gate for the expensive KEYBIND diagnostics below: the membership and
--- live-strip probes issue engine calls (HasKeybindButton per button,
--- GetOrderedNarratableKeybindButtonInfo for the whole strip), so callers must
--- only build the trace payload when the log is actually active (see Log.lua
--- IsActive guidance). Fails OPEN when Log.IsActive is unavailable so behavior
--- matches an always-on logger and the unit-test harness.
---@return boolean active
local function KeybindTraceActive()
    local L = BETTERUI.Log
    if not (L and L.Trace) then return false end
    if type(L.IsActive) ~= "function" then return true end
    local ok, active = pcall(L.IsActive)
    if not ok then return true end
    return active ~= false
end

local function InvokeKeybindStrip(methodName, ...)
    local strip = GetKeybindStrip()
    local method = strip and strip[methodName]
    if type(method) ~= "function" then
        return false, nil
    end

    local ok, result = pcall(method, strip, ...)
    if not ok then
        WarnKeybindHelper("keybind strip call failed", {
            fn = "KeybindHelpers." .. tostring(methodName),
            error = tostring(result),
        })
        return false, nil
    end
    return true, result
end

local function GetActiveKeybindStateIndex()
    local strip = GetKeybindStrip()
    local method = strip and strip.GetTopKeybindStateIndex
    if type(method) ~= "function" then
        return nil
    end

    local ok, stateIndex = pcall(method, strip)
    if not ok then
        WarnKeybindHelper("keybind state read failed", {
            fn = "KeybindHelpers.GetActiveKeybindStateIndex",
            error = tostring(stateIndex),
        })
        return nil
    end
    if type(stateIndex) == "number" then
        return stateIndex
    end
    return nil
end

local function InvokeKeybindStripWithState(methodName, stateIndex, descriptor)
    if descriptor ~= nil then
        if stateIndex ~= nil then
            return InvokeKeybindStrip(methodName, descriptor, stateIndex)
        end
        return InvokeKeybindStrip(methodName, descriptor)
    end
    if stateIndex ~= nil then
        return InvokeKeybindStrip(methodName, stateIndex)
    end
    return InvokeKeybindStrip(methodName)
end

local function SafeToken(value)
    value = tostring(value or "?")
    value = value:gsub("[%c,;%[%]]", " ")
    value = value:gsub("%s+", " ")
    return value:sub(1, 40)
end

local function DescribeLiveKeybinds()
    local strip = GetKeybindStrip()
    local method = strip and strip.GetOrderedNarratableKeybindButtonInfo
    if type(method) ~= "function" then return nil end

    local ok, keybinds = pcall(method, strip)
    if not ok then return "error" end
    if type(keybinds) ~= "table" then return "n=0[]" end

    local parts = {}
    for i = 1, #keybinds do
        if #parts >= 8 then break end
        local entry = keybinds[i]
        if type(entry) == "table" then
            local keybindName = SafeToken(entry.keybindName or "?"):sub(1, 18)
            local name = SafeToken(entry.name or "?"):sub(1, 28)
            local enabled = (entry.enabled == false) and "0" or "1"
            parts[#parts + 1] = keybindName .. ":" .. name .. ":e" .. enabled
        else
            parts[#parts + 1] = SafeToken(type(entry)):sub(1, 18)
        end
    end

    return string.format("n=%d[%s]", #keybinds, table.concat(parts, ";"))
end

function BETTERUI.Interface.GetActiveKeybindStateIndex()
    return GetActiveKeybindStateIndex()
end

function BETTERUI.Interface.DescribeActiveKeybinds()
    return DescribeLiveKeybinds()
end

---@param descriptor table?
---@return boolean present
local function HasKeybindGroupInState(descriptor, stateIndex)
    if not descriptor then return false end
    local ok, present = InvokeKeybindStripWithState("HasKeybindButtonGroup", stateIndex, descriptor)
    return ok and present == true
end

---@param descriptor table?
---@return boolean present
function BETTERUI.Interface.HasKeybindGroup(descriptor)
    return HasKeybindGroupInState(descriptor, GetActiveKeybindStateIndex())
end

--- True when the group's button for `keybind` is currently ON the strip in the
--- active keybind state -- i.e. the group still OWNS that key rather than having
--- had it displaced by another group's duplicate add (see the
--- HandleDuplicateAddKeybind note on DescribeKeybindGroupMembership below). This
--- is the button-level truth HasKeybindGroup (group-level) cannot see: a group
--- can stay "present" while its buttons are evicted. Read-only; issues one
--- HasKeybindButton engine call for the matched entry.
---@param descriptor table? keybind group descriptor (array of entries)
---@param keybind string engine keybind action name, e.g. "UI_SHORTCUT_PRIMARY"
---@return boolean present
function BETTERUI.Interface.IsGroupKeybindButtonPresent(descriptor, keybind)
    if not (descriptor and keybind) then return false end
    local strip = GetKeybindStrip()
    if not (strip and type(strip.HasKeybindButton) == "function") then return false end
    local stateIndex = GetActiveKeybindStateIndex()
    for _, entry in ipairs(descriptor) do
        if type(entry) == "table" and entry.keybind == keybind then
            local ok, present = pcall(strip.HasKeybindButton, strip, entry, stateIndex)
            return (ok and present == true) or false
        end
    end
    return false
end

--- Like IsGroupKeybindButtonPresent, but IDENTITY-accurate: true only when OUR
--- descriptor entry -- not merely SOME group's button for that key -- currently owns
--- the key on the strip. ESOUI's HasKeybindButton only tests
--- state.individualButtons[key] ~= nil (ANY owner), so a native-store duplicate add
--- for the same key reads as "present" even after it displaced us
--- (HandleDuplicateAddKeybind = last-add-wins). This probes the OWNING descriptor:
--- AddKeybindButtonStack stores the descriptor itself in state.individualButtons[key],
--- and the non-state self.keybinds[key] is either the ethereal descriptor or a button
--- whose .keybindButtonDescriptor links back to it. Read-only.
---@param descriptor table? keybind group descriptor (array of entries)
---@param keybind string engine keybind action name, e.g. "UI_SHORTCUT_PRIMARY"
---@return boolean ownedBySelf
function BETTERUI.Interface.IsGroupKeybindButtonOwnedBySelf(descriptor, keybind)
    if not (descriptor and keybind) then return false end
    local strip = GetKeybindStrip()
    if not strip then return false end
    local stateIndex = GetActiveKeybindStateIndex()
    for _, entry in ipairs(descriptor) do
        if type(entry) == "table" and entry.keybind == keybind then
            local ok, owned = pcall(function()
                local state = strip.GetKeybindState and strip:GetKeybindState(stateIndex) or nil
                if state and state.individualButtons then
                    return state.individualButtons[entry.keybind] == entry
                end
                local owner = strip.keybinds and strip.keybinds[entry.keybind] or nil
                if owner == entry then
                    return true
                end
                return owner ~= nil and owner.keybindButtonDescriptor == entry
            end)
            return (ok and owned == true) or false
        end
    end
    return false
end

---@param descriptor table?
---@return boolean updated
local function UpdateKeybindGroupInState(descriptor, stateIndex)
    if not descriptor then return false end
    local ok, updated = InvokeKeybindStripWithState("UpdateKeybindButtonGroup", stateIndex, descriptor)
    return ok and updated ~= false
end

---@param descriptor table?
---@return boolean updated
function BETTERUI.Interface.UpdateKeybindGroup(descriptor)
    return UpdateKeybindGroupInState(descriptor, GetActiveKeybindStateIndex())
end

---@return boolean updated
function BETTERUI.Interface.UpdateCurrentKeybindGroups()
    local ok, updated = InvokeKeybindStripWithState("UpdateCurrentKeybindButtonGroups", GetActiveKeybindStateIndex())
    return ok and updated ~= false
end

--- Same-frame keybind-refresh coalescing primitive (shared across CIM scenes).
--- ESO's ZO_Gamepad_ParametricList_Screen re-fires a list's selection callback
--- several times WITHIN A SINGLE FRAME during a rebuild/commit, and each fire drives
--- a full keybind refresh -- the per-selection "refresh storm" (Inventory documents
--- it as "A-Button Burn"). This collapses those duplicates: it returns true (skip)
--- only when asked to refresh again in the SAME frame for the SAME fingerprint. A
--- different frame, a changed fingerprint, force=true, or a nil fingerprint always
--- returns false, so a legitimate change is never suppressed -- in particular it
--- does NOT coalesce across frames, preserving Inventory's deliberate transition-frame
--- double refresh. Callers supply a scene-specific fingerprint (selection identity
--- plus anything the keybinds depend on: mode, multi-select, etc.) and the last
--- frame/fingerprint is stashed on `owner` (the scene instance). Generalizes the
--- inline dedup in Inventory's SetSelectedInventoryData.
---@param owner table scene instance used to stash the last frame + fingerprint
---@param fingerprint string? scene-specific selection fingerprint; nil = never skip
---@param force boolean? true bypasses the dedup (scene entry, displacement reclaim, transitions)
---@return boolean skip true when this refresh is a redundant same-frame duplicate
function BETTERUI.Interface.ShouldSkipRedundantKeybindRefresh(owner, fingerprint, force)
    if not owner or fingerprint == nil then
        return false
    end
    local nowMs = (GetFrameTimeMilliseconds and GetFrameTimeMilliseconds()) or 0
    if force ~= true
        and owner._kbRefreshFrame == nowMs
        and owner._kbRefreshFingerprint == fingerprint then
        if KeybindTraceActive() then
            TraceKeybindHelper("keybind refresh coalesced", {
                fn = "KeybindHelpers.ShouldSkipRedundantKeybindRefresh",
                fingerprint = fingerprint,
                frameMs = nowMs,
            })
        end
        return true
    end
    owner._kbRefreshFrame = nowMs
    owner._kbRefreshFingerprint = fingerprint
    return false
end

--- DIAGNOSTIC (inventory->vendor keybind loss): compact string of each keyed
--- button's ACTUAL presence on the strip -- 1=present, 0=absent, ?=HasKeybindButton
--- API unavailable; a trailing "e" marks an ethereal/invisible entry. ZOS
--- HandleDuplicateAddKeybind can evict a group's button on a duplicate-key add
--- WITHOUT clearing the group entry, so group-level presence alone hides the
--- failure; this reports button-level truth. Every caller wraps the trace in
--- KeybindTraceActive(), so these engine probes are built only when logging is
--- active and logging-off players pay nothing.
---@param descriptor table?
---@return string membership
local function DescribeKeybindGroupMembership(descriptor, stateIndex)
    local strip = GetKeybindStrip()
    local hasButtonFn = strip ~= nil and type(strip.HasKeybindButton) == "function"
    local parts = {}
    if descriptor then
        for _, entry in ipairs(descriptor) do
            if type(entry) == "table" and entry.keybind ~= nil then
                local mark = "?"
                if hasButtonFn then
                    local ok, present = pcall(strip.HasKeybindButton, strip, entry, stateIndex)
                    mark = (ok and present == true) and "1" or "0"
                end
                if entry.ethereal == true then mark = mark .. "e" end
                parts[#parts + 1] = tostring(entry.keybind) .. "=" .. mark
            end
        end
    end
    return table.concat(parts, ",")
end

local function AddKeybindDiagnostics(data, descriptor, stateIndex)
    data = data or {}
    data.stateIndex = stateIndex
    data.topStateIndex = stateIndex
    data.stateSource = stateIndex ~= nil and "top" or "legacy-default"
    if type(stateIndex) == "number" then
        data.savedStateCount = math.max(0, stateIndex - 1)
    end
    if descriptor ~= nil and data.buttons == nil then
        data.buttons = DescribeKeybindGroupMembership(descriptor, stateIndex)
    end
    if data.liveKeybinds == nil then
        data.liveKeybinds = DescribeLiveKeybinds()
    end
    return data
end

---@param descriptor table?
---@return boolean addedOrUpdated
function BETTERUI.Interface.EnsureKeybindGroupAdded(descriptor)
    if not descriptor then return false end
    local stateIndex = GetActiveKeybindStateIndex()

    -- DIAGNOSTIC read-back: capture button membership on entry and after the
    -- add/update branch so an inventory->vendor repro reveals whether the vendor
    -- coreKeybinds PRIMARY/SECONDARY/TERTIARY/QUATERNARY buttons truly land. The
    -- read-back issues engine calls, so every trace is gated on KeybindTraceActive()
    -- and skipped entirely (built or emitted) when logging is off.
    if KeybindTraceActive() then
        TraceKeybindHelper("keybind group ensure enter", AddKeybindDiagnostics({
            fn = "KeybindHelpers.EnsureKeybindGroupAdded",
            groupPresent = HasKeybindGroupInState(descriptor, stateIndex),
        }, descriptor, stateIndex))
    end

    if HasKeybindGroupInState(descriptor, stateIndex) then
        UpdateKeybindGroupInState(descriptor, stateIndex)
        if KeybindTraceActive() then
            TraceKeybindHelper("keybind group ensure done", AddKeybindDiagnostics({
                fn = "KeybindHelpers.EnsureKeybindGroupAdded",
                branch = "update",
                groupPresent = HasKeybindGroupInState(descriptor, stateIndex),
            }, descriptor, stateIndex))
        end
        return true
    end

    local ok, added = InvokeKeybindStripWithState("AddKeybindButtonGroup", stateIndex, descriptor)
    if ok and added ~= false then
        UpdateKeybindGroupInState(descriptor, stateIndex)
        if KeybindTraceActive() then
            TraceKeybindHelper("keybind group ensure done", AddKeybindDiagnostics({
                fn = "KeybindHelpers.EnsureKeybindGroupAdded",
                branch = "add",
                addResult = added,
                groupPresent = HasKeybindGroupInState(descriptor, stateIndex),
            }, descriptor, stateIndex))
        end
        return true
    end

    if KeybindTraceActive() then
        TraceKeybindHelper("keybind group add skipped", AddKeybindDiagnostics({
            fn = "KeybindHelpers.EnsureKeybindGroupAdded",
            hasDescriptor = descriptor ~= nil,
            addOk = ok,
            addResult = added,
        }, descriptor, stateIndex))
    end
    return false
end

---@param descriptor table?
---@return boolean removed
function BETTERUI.Interface.RemoveKeybindGroupIfPresent(descriptor)
    if not descriptor then return false end
    local strip = GetKeybindStrip()
    local stateIndex = GetActiveKeybindStateIndex()
    if strip and type(strip.HasKeybindButtonGroup) == "function"
        and not HasKeybindGroupInState(descriptor, stateIndex) then
        return false
    end

    local ok, removed = InvokeKeybindStripWithState("RemoveKeybindButtonGroup", stateIndex, descriptor)
    return ok and removed ~= false
end

--- Removes only the caller-owned keybind groups from the strip, skipping
--- keepDescriptor. Returns the descriptors actually removed so the caller can
--- later restore exactly those via RestoreKeybindGroups. Never touches groups
--- owned by the native UI or other addons.
---@param ownedGroups table? array of keybind group descriptors owned by the calling module
---@param keepDescriptor table? descriptor that must stay on the strip
---@return table removed descriptors actually removed, in removal order
function BETTERUI.Interface.RemoveOwnedKeybindGroups(ownedGroups, keepDescriptor)
    local removed = {}
    if not ownedGroups then return removed end
    for _, group in ipairs(ownedGroups) do
        if group and group ~= keepDescriptor and BETTERUI.Interface.RemoveKeybindGroupIfPresent(group) then
            removed[#removed + 1] = group
        end
    end
    return removed
end

--- Re-adds keybind groups previously removed by RemoveOwnedKeybindGroups.
---@param removedGroups table? array of keybind group descriptors to restore
function BETTERUI.Interface.RestoreKeybindGroups(removedGroups)
    if not removedGroups then return end
    for _, group in ipairs(removedGroups) do
        BETTERUI.Interface.EnsureKeybindGroupAdded(group)
    end
end
