--[[
File: tools/lint/lint_log_messages.lua
Purpose: Static convention check for the logging message contract. Flags TERSE log
         messages -- a string literal that is a single identifier token (camelCase /
         snake_case, no spaces, e.g. "enterSearch", "savePosition") -- which read as
         function names rather than self-describing events. Self-describing messages
         carry a space (a phrase) or a structured separator (": ", " -> ", " | ").

         The message contract (docs/reference/logging-observability-strategy.md):
           <area>: <what happened> [-> <named value>]
         e.g. "category change started -> index 3", not "startCategoryChange".

Usage:
  lua tools/lint/lint_log_messages.lua <file.lua> [<file.lua> ...]
  # from repo root, scan all module sources:
  lua tools/lint/lint_log_messages.lua $(find Modules -name '*.lua')

Exit code: 0 = clean, 1 = terse messages found (CI-friendly).

A literal that is genuinely a fine short message (rare) can be allow-listed in ALLOW.
]]

-- Messages that are intentionally short + acceptable (state verbs, etc.).
local ALLOW = {
    showing = true, shown = true, hiding = true, hidden = true,
}

local CANONICAL_PHASE = {
    requested = true,
    begin = true,
    ["end"] = true,
    completed = true,
    confirmed = true,
    fired = true,
    settled = true,
    blocked = true,
    failed = true,
    skipped = true,
    pending = true,
    changed = true,
    snapshot = true,
    queued = true,
    executed = true,
    expired = true,
    detected = true,
    overflow = true,
    report = true,
    step = true,
    abort = true,
}

-- Existing event tokens that remain accepted until their owning module phase migrates.
-- They still print WARN lines so a repo-wide lint keeps the remaining migration visible.
local APPROVED_LEGACY_PHASE = {
    -- BUI-TRACE-003 Phase 7: combat/HUD and GeneralInterface wrapper families.
    ability_used = true,
    ability_used_skipped = true,
    apply = true,
    apply_disabled = true,
    apply_enabled = true,
    alive = true,
    apply_from_settings = true,
    descriptor_rebuilt = true,
    gamepad_mode_changed = true,
    hud_showing_task = true,
    hud_state = true,
    localized_font_fallback = true,
    loot_exit = true,
    refresh_attempt_success = true,
    refresh_requested = true,
    register = true,
    reset = true,
    restored_original = true,
    settings_loaded = true,
    setter_failed = true,
    stop_skipped = true,
    unregister = true,
    attach_begin = true,
    attach_call = true,
    attach_skipped = true,
    attached = true,
    button_begin = true,
    button_end = true,
    button_error = true,
    cast_start = true,
    cast_start_skipped = true,
    cast_stop = true,
    cast_stop_skipped = true,
    click_refresh = true,
    combat_state = true,
    dead = true,
    death_fragment = true,
    delta_applied = true,
    delta_skipped = true,
    detach_skipped = true,
    detached = true,
    direct_delete_dispatched = true,
    direct_delete_failed = true,
    disable_requested = true,
    disabled = true,
    enable_requested = true,
    enabled = true,
    events_registered = true,
    events_skipped = true,
    getter_failed = true,
    global_reset = true,
    hide_enforce = true,
    hide_enforce_rescheduled = true,
    hide_enforce_scheduled = true,
    hide_enforce_task = true,
    hook_installed = true,
    hook_requested = true,
    hook_skipped = true,
    initialized = true,
    invalidate_skipped = true,
    keybind_fired = true,
    layout_applied = true,
    layout_begin = true,
    layout_end = true,
    main_begin = true,
    main_end = true,
    main_skipped = true,
    migration_skipped = true,
    native_allowed = true,
    native_callback_dispatched = true,
    native_callback_failed = true,
    not_ready = true,
    offsets_applied = true,
    player_activated = true,
    play = true,
    positions_begin = true,
    positions_end = true,
    positions_skipped = true,
    posthook_installed = true,
    power_probe_applied = true,
    power_probe_skipped = true,
    prehook_installed = true,
    ready = true,
    ready_animation_started = true,
    reattach = true,
    refresh = true,
    refresh_attempt = true,
    refresh_attempt_failed = true,
    refresh_attempt_skipped = true,
    refresh_result = true,
    rejected = true,
    reset_element = true,
    retry_exhausted = true,
    retry_scheduled = true,
    set_begin = true,
    set_end = true,
    set_error = true,
    setup_begin = true,
    setup_end = true,
    setup_retry = true,
    setup_skipped = true,
    special_scene_sync = true,
    start = true,
    state_changed = true,
    state_skipped = true,
    stopped = true,
    suppression_decision = true,
    system_skipped = true,
    template_error = true,
    timeline_created = true,
    toggled = true,
    updated = true,
    updated_ready = true,
    window_skipped = true,

    aborted = true,
    abort_requested = true,
    abort_skipped = true,
    activate = true,
    activate_after = true,
    activate_before = true,
    alert_shown = true,
    applied = true,
    apply_begin = true,
    apply_end = true,
    apply_skipped = true,
    after = true,
    add_after = true,
    add_before = true,
    awaiting_choice = true,
    batch_begin = true,
    batch_end = true,
    before = true,
    build = true,
    built = true,
    cached = true,
    cancel = true,
    capture_skipped = true,
    captured = true,
    close_complete = true,
    close_received = true,
    close_requested = true,
    close_skipped = true,
    closed = true,
    coalesced = true,
    complete_reached = true,
    committed = true,
    confirm = true,
    confirm_begin = true,
    confirm_rejected = true,
    continue = true,
    cleared = true,
    deactivate = true,
    deactivate_after = true,
    deactivate_before = true,
    deferred = true,
    deferred_scheduled = true,
    deferred_skipped = true,
    deferred_timeout = true,
    deferred_timeout_skipped = true,
    deselect_all = true,
    dialog_show = true,
    duplicate_overwrite = true,
    end_error = true,
    enter_attempted = true,
    enter_skipped = true,
    error = true,
    finished = true,
    flushed = true,
    footer_refreshed = true,
    guard_exit = true,
    guild_requested = true,
    guild_slot_update = true,
    handoff_cleanup = true,
    header_refreshed = true,
    hidden = true,
    hidden_begin = true,
    hidden_end = true,
    hiding_begin = true,
    hiding_end = true,
    hooks_skipped = true,
    ignored = true,
    invoked = true,
    invalidated = true,
    list_refreshed = true,
    list_refresh_skipped = true,
    move_requested = true,
    no_active_writ = true,
    next_skipped = true,
    open_event = true,
    open_received = true,
    open_requested = true,
    open_shown = true,
    open_skipped = true,
    opened = true,
    pending_cleared = true,
    pending_expired = true,
    pending_mark_skipped = true,
    pending_marked = true,
    pending_set = true,
    pickup_after = true,
    pickup_before = true,
    place_after = true,
    place_before = true,
    prev_skipped = true,
    quick_execute = true,
    reassert_aborted = true,
    reassert_cancelled = true,
    reassert_scheduled = true,
    reassert_skipped = true,
    reasserted = true,
    received = true,
    rebuilt = true,
    refresh_after = true,
    refresh_before = true,
    refresh_begin = true,
    refresh_complete = true,
    refresh_end = true,
    refreshed = true,
    refresh_skipped = true,
    register_skipped = true,
    registered = true,
    remove_after = true,
    remove_before = true,
    render = true,
    request = true,
    refresh_decision = true,
    refresh_scheduled = true,
    refresh_task = true,
    release_dialog = true,
    reset_begin = true,
    reset_end = true,
    reset_skipped = true,
    restore_begin = true,
    restore_end = true,
    restore_skipped = true,
    restored = true,
    result = true,
    route = true,
    rollback = true,
    saved = true,
    schedule_skipped = true,
    scheduled = true,
    scheduled_next = true,
    scene_hide_requested = true,
    scene_lifecycle_register = true,
    select_all = true,
    selected_changed = true,
    selected_changed_skipped = true,
    setting_changed = true,
    set = true,
    setup = true,
    show = true,
    show_begin = true,
    show_error = true,
    show_skipped = true,
    shown = true,
    showing_begin = true,
    showing_complete = true,
    showing_end = true,
    slot_update = true,
    stale_callback_skipped = true,
    start_skipped = true,
    started = true,
    state = true,
    stopping = true,
    succeeded = true,
    suppressed = true,
    timeout = true,
    unmatched_quest = true,
    unblocked = true,
    unregister_skipped = true,
    unregistered = true,
    visible = true,
    visibility = true,
    waiting = true,
    waiting_for_close = true,
    waiting_dialog = true,
    write = true,
}

-- Log.<Level>(<category>, "<message>"  -- capture the message literal (2nd positional).
-- Levels that take (category, message, ...): Trace/Debug/Info/Warn/Error.
local CALL = '[Ll]og%.[TDIWE][a-z]+%s*%(%s*[%w_%.]+%s*,%s*"([^"]*)"'
local TRACE_EVENT_PHASE = 'TraceEvent%s*%(%s*[^,]+%s*,%s*"[^"]*"%s*,%s*"([^"]+)"'
local PHASE_PATTERNS = {
    { label = "TraceEvent", pattern = TRACE_EVENT_PHASE },
    { label = "TraceBankTransfer", pattern = 'TraceBankTransfer%s*%(%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceBankKeybind", pattern = 'TraceBankKeybind%s*%(%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceBankingActionDialog", pattern = 'TraceBankingActionDialog%s*%(%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceListTrigger", pattern = 'TraceListTrigger%s*%(%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceKeybind", pattern = 'TraceKeybind%s*%(%s*[^,]+%s*,%s*[^,]+%s*,%s*"([^"]+)"' },
    { label = "TraceBankCurrencyAction", pattern = 'TraceBankCurrencyAction%s*%(%s*"([^"]+)"' },
    { label = "TraceVendorEvent", pattern = 'TraceVendorEvent%s*%(%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceVendor", pattern = 'TraceVendor%s*%(%s*[^,]+%s*,%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceVendorBatch", pattern = 'TraceVendorBatch%s*%(%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceVendorBootstrap", pattern = 'TraceVendorBootstrap%s*%(%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceBrowse", pattern = 'TraceBrowse%s*%(%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceSell", pattern = 'TraceSell%s*%(%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceListings", pattern = 'TraceListings%s*%(%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceTH", pattern = 'TraceTH%s*%(%s*[^,]+%s*,%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceTHFlow", pattern = 'TraceTHFlow%s*%(%s*[^,]+%s*,%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceWrit", pattern = 'TraceWrit%s*%(%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceWritEvent", pattern = 'TraceWritEvent%s*%(%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceCompanionRuntime", pattern = 'TraceCompanionRuntime%s*%(%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceCompanionRuntime", pattern = 'TraceCompanionRuntime%s*%(%s*"[^"]+"%s*,%s*[^,]-and%s*"([^"]+)"' },
    { label = "TraceCompanionRuntime", pattern = 'TraceCompanionRuntime%s*%(%s*"[^"]+"%s*,%s*[^,]-or%s*"([^"]+)"' },
    { label = "TraceCompanionDialog", pattern = 'TraceCompanionDialog%s*%(%s*[^,]+%s*,%s*"([^"]+)"' },
    { label = "TraceTHFlow", pattern = 'TraceTHFlow%s*%(%s*[^,]+%s*,%s*"[^"]+"%s*,%s*[^,]-and%s*"([^"]+)"' },
    { label = "TraceTHFlow", pattern = 'TraceTHFlow%s*%(%s*[^,]+%s*,%s*"[^"]+"%s*,%s*[^,]-or%s*"([^"]+)"' },
    { label = "TraceUltimate", pattern = 'TraceUltimate%s*%(%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceUltimate", pattern = 'TraceUltimate%s*%(%s*"[^"]+"%s*,%s*[^,]-and%s*"([^"]+)"' },
    { label = "TraceUltimate", pattern = 'TraceUltimate%s*%(%s*"[^"]+"%s*,%s*[^,]-or%s*"([^"]+)"' },
    { label = "TraceCoordinator", pattern = 'TraceCoordinator%s*%(%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceCoordinator", pattern = 'TraceCoordinator%s*%(%s*"[^"]+"%s*,%s*[^,]-and%s*"([^"]+)"' },
    { label = "TraceCoordinator", pattern = 'TraceCoordinator%s*%(%s*"[^"]+"%s*,%s*[^,]-or%s*"([^"]+)"' },
    { label = "TraceCastBar", pattern = 'TraceCastBar%s*%(%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceOrbEvents", pattern = 'TraceOrbEvents%s*%(%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceOrbEvents", pattern = 'TraceOrbEvents%s*%(%s*"[^"]+"%s*,%s*[^,]-and%s*"([^"]+)"' },
    { label = "TraceOrbEvents", pattern = 'TraceOrbEvents%s*%(%s*"[^"]+"%s*,%s*[^,]-or%s*"([^"]+)"' },
    { label = "TraceNameplates", pattern = 'TraceNameplates%s*%(%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceNameplates", pattern = 'TraceNameplates%s*%(%s*"[^"]+"%s*,%s*[^,]-and%s*"([^"]+)"' },
    { label = "TraceNameplates", pattern = 'TraceNameplates%s*%(%s*"[^"]+"%s*,%s*[^,]-or%s*"([^"]+)"' },
    { label = "TraceGeneralInterface", pattern = 'TraceGeneralInterface%s*%(%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceGeneralSetting", pattern = 'TraceGeneralSetting%s*%(%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceDrag", pattern = 'TraceDrag%s*%(%s*"[^"]+"%s*,%s*"([^"]+)"' },
    { label = "TraceDrag", pattern = 'TraceDrag%s*%(%s*"[^"]+"%s*,%s*[^,]-and%s*"([^"]+)"' },
    { label = "TraceDrag", pattern = 'TraceDrag%s*%(%s*"[^"]+"%s*,%s*[^,]-or%s*"([^"]+)"' },
}

-- A "terse" message: a single identifier token (letters/digits/underscore), no space,
-- no sentence punctuation. "enterSearch" matches; "filter list by 'x'" does not.
local function isTerse(msg)
    if msg == "" then return false end
    if ALLOW[msg] then return false end
    if msg:find("%s") then return false end          -- has a space -> a phrase
    if msg:find("[:|>]") then return false end        -- structured separator
    return msg:match("^[%a_][%w_]*$") ~= nil          -- a bare identifier token
end

local files = {}
for i = 1, #arg do files[#files + 1] = arg[i] end
if #files == 0 then
    -- No args: default to scanning all module sources (so CI / the test harness can run
    -- it with no arguments). Falls back to a usage error if the shell scan is unavailable.
    local ok, pipe = pcall(io.popen, "find Modules -name '*.lua' 2>/dev/null")
    if ok and pipe then
        for p in pipe:lines() do files[#files + 1] = p end
        pipe:close()
    end
end
if #files == 0 then
    io.stderr:write("usage: lua tools/lint/lint_log_messages.lua <file.lua> [...]\n")
    os.exit(2)
end

local total = 0
local phaseTotal = 0
local legacyPhaseTotal = 0
local byDir = {}
local function dirOf(path)
    local d = path:match("^Modules/([^/]+)") or path:match("([^/]+)/[^/]+$") or path
    return d
end

local function checkPhase(path, lineNo, phase, label)
    if CANONICAL_PHASE[phase] then return end
    if APPROVED_LEGACY_PHASE[phase] then
        legacyPhaseTotal = legacyPhaseTotal + 1
        print(string.format("%s:%d: WARN legacy %s phase %q -- migrate when this module's event schema changes",
            path, lineNo, label, phase))
    else
        phaseTotal = phaseTotal + 1
        byDir[dirOf(path)] = (byDir[dirOf(path)] or 0) + 1
        print(string.format("%s:%d: non-canonical %s phase %q -- use the EVENT_SCHEMA phase vocabulary",
            path, lineNo, label, phase))
    end
end

for _, path in ipairs(files) do
    local fh = io.open(path, "r")
    if fh then
        local lineNo = 0
        local inBlock = false
        for line in fh:lines() do
            lineNo = lineNo + 1
            -- Strip comments so example Log calls in docs aren't flagged. Crude but fine
            -- for a lint: handle --[[ ]] block comments + -- line comments.
            local scan = line
            if inBlock then
                local close = scan:find("%]%]")
                if close then inBlock = false; scan = scan:sub(close + 2) else scan = "" end
            end
            local open = scan:find("%-%-%[%[")
            if open then
                local rest = scan:sub(open)
                if rest:find("%]%]") then scan = scan:sub(1, open - 1)
                else scan = scan:sub(1, open - 1); inBlock = true end
            end
            scan = scan:gsub("%-%-.*$", "") -- line comment
            for msg in scan:gmatch(CALL) do
                if isTerse(msg) then
                    total = total + 1
                    byDir[dirOf(path)] = (byDir[dirOf(path)] or 0) + 1
                    print(string.format("%s:%d: terse log message %q -- make it self-describing", path, lineNo, msg))
                end
            end
            for _, phasePattern in ipairs(PHASE_PATTERNS) do
                for phase in scan:gmatch(phasePattern.pattern) do
                    checkPhase(path, lineNo, phase, phasePattern.label)
                end
            end
        end
        fh:close()
    end
end

if total > 0 or phaseTotal > 0 then
    local dirs = {}
    for d in pairs(byDir) do dirs[#dirs + 1] = d end
    table.sort(dirs, function(a, b) return byDir[a] > byDir[b] end)
    print("\n-- per top-level module dir --")
    for _, d in ipairs(dirs) do print(string.format("  %4d  %s", byDir[d], d)) end
end

if total > 0 or phaseTotal > 0 then
    if total > 0 then
        print(string.format("\n%d terse log message(s) found. Messages should be self-describing phrases.", total))
    end
    if phaseTotal > 0 then
        print(string.format("\n%d non-canonical TraceEvent phase(s) found.", phaseTotal))
    end
    os.exit(1)
else
    if legacyPhaseTotal > 0 then
        print(string.format("WARN: %d approved legacy TraceEvent phase(s) remain.", legacyPhaseTotal))
    end
    print("OK: no terse log messages found.")
    os.exit(0)
end
