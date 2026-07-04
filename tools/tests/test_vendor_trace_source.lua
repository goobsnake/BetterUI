--[[
File: tools/tests/test_vendor_trace_source.lua
Purpose: Source contract for Vendor scene, mode, and keybind trace envelopes.
]]

local function read_file(path)
    local handle, err = io.open(path, "r")
    if not handle then
        error(string.format("failed to open %s: %s", path, tostring(err)))
    end
    local content = handle:read("*a")
    handle:close()
    return content
end

local function assert_contains(haystack, needle, label)
    if not haystack:find(needle, 1, true) then
        error(label .. "\nMissing: " .. needle)
    end
end

local function assert_not_contains(haystack, needle, label)
    if haystack:find(needle, 1, true) then
        error(label .. "\nUnexpected: " .. needle)
    end
end

local function assert_before(haystack, first, second, label)
    local first_pos = haystack:find(first, 1, true)
    local second_pos = haystack:find(second, 1, true)
    if not first_pos or not second_pos or first_pos >= second_pos then
        error(label .. "\nExpected order: " .. first .. " before " .. second)
    end
end

local function assert_equals(actual, expected, label)
    if actual ~= expected then
        error(label .. "\nExpected: " .. tostring(expected) .. "\nActual: " .. tostring(actual))
    end
end

local function block_between(content, start_marker, end_marker, label)
    local start_pos = content:find(start_marker, 1, true)
    if not start_pos then
        error(label .. "\nMissing start: " .. start_marker)
    end
    local end_pos = content:find(end_marker, start_pos + #start_marker, true)
    if not end_pos then
        error(label .. "\nMissing end: " .. end_marker)
    end
    return content:sub(start_pos, end_pos - 1)
end

print("test_vendor_trace_source")

local interaction = read_file("Modules/Vendor/Core/Lifecycle/VendorInteractionRuntime.lua")
local controller = read_file("Modules/Vendor/Core/Lifecycle/VendorControllerRuntime.lua")
local mode_policy = read_file("Modules/Vendor/Core/Policy/VendorModePolicy.lua")
local vendor = read_file("Modules/Vendor/Vendor.lua")
local vendor_keybinds = read_file("Modules/Vendor/Core/VendorKeybinds.lua")
local manifest = read_file("BetterUI.txt")

assert_before(manifest, "Modules\\Vendor\\Core\\VendorKeybinds.lua", "Modules\\Vendor\\Vendor.lua",
    "Manifest loads VendorKeybinds before Vendor.lua")

assert_contains(interaction, "local function TraceVendorScene(phase, state, data)",
    "Vendor interaction runtime exposes a scene-envelope helper")
assert_contains(interaction, "L.TraceEvent(L.CATEGORY.SCENE, \"vendor.scene\", phase, data)",
    "Vendor scene envelope uses SCENE/vendor.scene")
assert_contains(interaction, "data.interactionType = data.interactionType or",
    "Vendor scene envelope carries interactionType")
assert_contains(interaction, "data.isFence = data.isFence ~= nil and data.isFence",
    "Vendor scene envelope carries isFence")
assert_contains(interaction, "data.isStable = data.isStable ~= nil and data.isStable",
    "Vendor scene envelope carries isStable")

local open_store = block_between(interaction,
    "local function OpenStoreInternal(state, deps, publishState)",
    "local function OpenFenceInternal(state, deps, enableSell, enableLaunder, publishState)",
    "OpenStoreInternal block")
assert_contains(open_store, "TraceVendorScene(\"begin\", state",
    "OpenStoreInternal emits scene begin")
assert_contains(open_store, "TraceVendorScene(\"end\", finalState",
    "OpenStoreInternal emits scene end")
assert_contains(open_store, "result = \"shown\"",
    "OpenStoreInternal records the scene result")

local open_fence = block_between(interaction,
    "local function OpenFenceInternal(state, deps, enableSell, enableLaunder, publishState)",
    "local function CloseStoreInternal(state, deps)",
    "OpenFenceInternal block")
assert_contains(open_fence, "TraceVendorScene(\"begin\", state",
    "OpenFenceInternal emits scene begin")
assert_contains(open_fence, "TraceVendorScene(\"end\", finalState",
    "OpenFenceInternal emits scene end")
assert_contains(open_fence, "interactionType = \"fence\"",
    "OpenFenceInternal marks fence interaction type")

local close_store = block_between(interaction,
    "local function CloseStoreInternal(state, deps)",
    "return state\nend",
    "CloseStoreInternal block")
assert_contains(close_store, "TraceVendorScene(\"begin\", state",
    "CloseStoreInternal emits scene begin")
assert_contains(close_store, "TraceVendorScene(\"end\", state",
    "CloseStoreInternal emits scene end")
assert_contains(close_store, "result = \"hidden\"",
    "CloseStoreInternal records the scene result")

assert_contains(controller, "TraceVendor(L and L.CATEGORY.NAV, \"vendor.mode\", \"changed\"",
    "Vendor SetMode emits NAV/vendor.mode changed")
assert_contains(controller, "old = oldMode",
    "Vendor SetMode changed payload carries old mode")
assert_contains(controller, "[\"new\"] = mode",
    "Vendor SetMode changed payload carries new mode")
assert_contains(controller, "trigger = \"SetMode\"",
    "Vendor SetMode changed payload names its trigger")

assert_contains(mode_policy, "L.TraceEvent(L.CATEGORY.NAV, \"vendor.mode\", \"changed\", {",
    "Vendor initial mode resolver emits NAV/vendor.mode changed")
assert_contains(mode_policy, "trigger = context.trigger or \"ResolveInitialStoreMode\"",
    "Vendor initial mode resolver names its trigger")
assert_contains(mode_policy, "return initialMode, shouldRememberBuyMode",
    "Vendor initial mode resolver preserves the session buy-mode return value")
assert_contains(mode_policy, "initialMode, shouldRememberBuyMode = ModePolicy.ResolveStableInitialStoreMode({",
    "Vendor stable initial mode resolver preserves the session buy-mode return value")
assert_contains(vendor, "Vendor.ModePolicy.ResolveInitialStoreMode(request)",
    "Live Vendor.ResolveInitialStoreMode routes through the traced policy wrapper")

assert_contains(vendor, "VendorKeybinds.BuildCoreKeybinds(vendorInstance",
    "Live Vendor.BuildCoreKeybinds routes through extracted keybind builder")
assert_contains(vendor_keybinds, "local function TraceVendorKeybind(ctx, key, phase, data)",
    "VendorKeybinds has a keybind-envelope helper")
assert_not_contains(vendor_keybinds, "L.SetLastAction({",
    "Vendor keybind detail helper leaves last action owned by the shared input anchor")
assert_contains(vendor_keybinds, "ctx.traceVendorEvent(\"vendor.keybind\", phase, data, L.CATEGORY.KEYBIND)",
    "Vendor keybind helper emits KEYBIND/vendor.keybind")
assert_contains(vendor_keybinds, "data._inputAnchorDetail = true",
    "Vendor keybind detail records omit fields owned by the shared input anchor")
assert_contains(vendor_keybinds, "local function UpdateCurrentKeybindGroups()",
    "VendorKeybinds guards current keybind group refreshes")
assert_not_contains(vendor_keybinds, "BETTERUI.Interface.UpdateCurrentKeybindGroups()",
    "VendorKeybinds does not call Interface.UpdateCurrentKeybindGroups unguarded")
assert_contains(vendor_keybinds, "local function ExecuteVendorKeybindAction(ctx, key, action, fn, endData)",
    "Vendor keybind callbacks share a terminal safe-execute wrapper")
assert_contains(vendor_keybinds, "TraceVendorKeybind(ctx, key, \"failed\"",
    "Vendor keybind wrapper emits a terminal failure phase")

local primary = block_between(vendor_keybinds, "keybind = \"UI_SHORTCUT_PRIMARY\",", "keybind = \"UI_SHORTCUT_SECONDARY\",", "primary keybind block")
local secondary = block_between(vendor_keybinds, "keybind = \"UI_SHORTCUT_SECONDARY\",", "BETTERUI.CIM.Keybinds.CreateClearSearchKeybind(", "secondary keybind block")
local tertiary = block_between(vendor_keybinds, "keybind = \"UI_SHORTCUT_TERTIARY\",", "keybind = \"UI_SHORTCUT_QUINARY\",", "tertiary keybind block")

assert_contains(primary, "local key = \"UI_SHORTCUT_PRIMARY\"",
    "Primary keybind callback declares its trace key")
assert_contains(primary, "ExecuteVendorKeybindAction(ctx, key, \"multi_select_toggle\"",
    "Primary multi-select path uses the terminal keybind wrapper")
assert_contains(primary, "ExecuteVendorKeybindAction(ctx, key, \"primary\"",
    "Primary action path uses the terminal keybind wrapper")
assert_contains(primary, "TraceVendorKeybind(ctx, key, \"skipped\"",
    "Primary keybind callback emits skipped")

assert_contains(secondary, "local key = \"UI_SHORTCUT_SECONDARY\"",
    "Secondary keybind callback declares its trace key")
assert_contains(secondary, "ExecuteVendorKeybindAction(ctx, key, \"toggle_mode\"",
    "Secondary keybind callback uses the terminal keybind wrapper")
assert_contains(secondary, "TraceVendorKeybind(ctx, key, \"skipped\"",
    "Secondary keybind callback emits skipped")

assert_contains(tertiary, "local key = \"UI_SHORTCUT_TERTIARY\"",
    "Tertiary keybind callback declares its trace key")
assert_contains(tertiary, "ExecuteVendorKeybindAction(ctx, key, \"batch_abort\"",
    "Tertiary batch-abort path uses the terminal keybind wrapper")
assert_contains(tertiary, "TraceVendorKeybind(ctx, key, \"begin\", { action = \"batch_dialog\" })",
    "Tertiary batch-dialog path emits begin before dialog setup")
assert_contains(tertiary, "TraceVendorKeybind(ctx, key, \"failed\"",
    "Tertiary batch-dialog path emits failed on caught errors")
assert_contains(tertiary, "ExecuteVendorKeybindAction(ctx, key, \"sell_all_junk\"",
    "Tertiary sell-all path uses the terminal keybind wrapper")
assert_contains(tertiary, "ExecuteVendorKeybindAction(ctx, key, \"repair_all\"",
    "Tertiary repair-all path uses the terminal keybind wrapper")
assert_contains(tertiary, "TraceVendorKeybind(ctx, key, \"skipped\"",
    "Tertiary keybind callback emits skipped")

assert_contains(vendor_keybinds, "ExecuteVendorKeybindAction(ctx, \"UI_SHORTCUT_LEFT_SHOULDER\", \"cycle_tabs_previous\"",
    "Left shoulder keybind callback uses the terminal keybind wrapper")
assert_contains(vendor_keybinds, "ExecuteVendorKeybindAction(ctx, \"UI_SHORTCUT_RIGHT_SHOULDER\", \"cycle_tabs_next\"",
    "Right shoulder keybind callback uses the terminal keybind wrapper")
assert_contains(vendor_keybinds, "ExecuteVendorKeybindAction(ctx, key, \"clear_search\"",
    "Clear-search keybind callback uses the terminal keybind wrapper")
assert_contains(vendor_keybinds, "ExecuteVendorKeybindAction(ctx, key, \"multi_select_enter\"",
    "Quinary keybind callback uses the terminal keybind wrapper")
assert_contains(vendor_keybinds, "ExecuteVendorKeybindAction(ctx, key, \"toggle_preview\"",
    "Preview keybind callback uses the terminal keybind wrapper")
assert_contains(vendor_keybinds, "ExecuteVendorKeybindAction(ctx, \"UI_SHORTCUT_LEFT_STICK\", \"stack_all\"",
    "Fence stack-all keybind callback uses the terminal keybind wrapper")
assert_contains(vendor_keybinds, "ExecuteVendorKeybindAction(ctx, \"UI_SHORTCUT_NEGATIVE\", action",
    "Back/exit keybind callback uses the terminal keybind wrapper")

assert_not_contains(block_between(primary, "keybind = \"UI_SHORTCUT_PRIMARY\",", "callback = function()", "primary pre-callback"),
    "TraceVendorKeybind", "Primary label/visible resolvers must not trace")
assert_not_contains(block_between(secondary, "keybind = \"UI_SHORTCUT_SECONDARY\",", "callback = function()", "secondary pre-callback"),
    "TraceVendorKeybind", "Secondary label/visible/enabled resolvers must not trace")
assert_not_contains(block_between(tertiary, "keybind = \"UI_SHORTCUT_TERTIARY\",", "callback = function()", "tertiary pre-callback"),
    "TraceVendorKeybind", "Tertiary label/visible/enabled resolvers must not trace")

local function run_vendor_keybind_anchor_behavior()
    local trace_events = {}
    local last_action = nil
    BETTERUI = {
        CIM = {
            Keybinds = {
                CreateClearSearchKeybind = function(callback, visible, enabled)
                    return {
                        keybind = "UI_SHORTCUT_QUATERNARY",
                        callback = callback,
                        visible = visible,
                        enabled = enabled,
                    }
                end,
            },
        },
        Interface = { UpdateCurrentKeybindGroups = function() end },
        Vendor = {},
    }
    BETTERUI.Log = {
        LEVEL = { TRACE = 1, INFO = 3 },
        CATEGORY = { KEYBIND = "KEYBIND" },
        EnabledFor = function(level, category)
            return category == "KEYBIND" and (level == 1 or level == 3)
        end,
        SetLastAction = function(action)
            last_action = action
        end,
        TraceEvent = function(category, event, phase, data, level)
            trace_events[#trace_events + 1] = {
                category = category,
                event = event,
                phase = phase,
                data = data,
                level = level,
            }
        end,
    }
    BETTERUI.Vendor.MODE = { BUY = 1, SELL = 2, REPAIR = 3 }
    BETTERUI.Vendor.ExecuteSafely = function(_label, fn)
        return pcall(fn)
    end
    BETTERUI.Vendor.GetSetting = function() return false end
    BETTERUI.Vendor.GetJunkSellSummary = function() return 0, 0 end
    KEYBIND_STRIP_ALIGN_LEFT = "left"
    function GetString(id) return tostring(id or "") end
    function IsInGamepadPreferredMode() return true end
    function ZO_Keybindings_GetHighestPriorityBindingStringFromAction(action)
        return "binding:" .. tostring(action)
    end

    dofile("Modules/CIM/Keybinds/InputAnchor.lua")
    dofile("Modules/Vendor/Core/VendorKeybinds.lua")

    local primary_calls = 0
    local vendor_instance = {
        _vendorHeaderEntryCount = 1,
        searchQuery = "",
        GetCurrentMode = function() return BETTERUI.Vendor.MODE.BUY end,
        GetActiveComponent = function()
            return {
                OnPrimaryAction = function()
                    primary_calls = primary_calls + 1
                end,
                IsPrimaryActionEnabled = function() return true end,
                GetPrimaryActionName = function() return "Primary" end,
            }
        end,
        SaveListPosition = function() end,
        RefreshList = function() end,
        EnsureListInputActive = function() end,
        CanAfford = function() return true end,
    }
    local group = BETTERUI.Vendor.Keybinds.BuildCoreKeybinds(vendor_instance, {
        traceVendorEvent = function(event, phase, data, category)
            trace_events[#trace_events + 1] = {
                category = category,
                event = event,
                phase = phase,
                data = data,
            }
        end,
        getActiveTabs = function() return { "buy" } end,
        getToggleModePair = function() return BETTERUI.Vendor.MODE.BUY, BETTERUI.Vendor.MODE.SELL end,
        getCurrentVendorTargetData = function() return { uniqueId = 1 } end,
        isPrimaryActionAllowed = function() return true end,
        canMultiSelectInCurrentMode = function() return false end,
        isMultiSelectAvailable = function() return false end,
        registerVendorBatchDialog = function() end,
        isFenceInteraction = function() return false end,
        isStableInteraction = function() return false end,
    })
    local primary
    local shoulder_previous
    local clear_search
    for _, entry in ipairs(group) do
        if entry.keybind == "UI_SHORTCUT_PRIMARY" then
            primary = entry
        elseif entry.keybind == "UI_SHORTCUT_LEFT_SHOULDER" then
            shoulder_previous = entry
        elseif entry.keybind == "UI_SHORTCUT_QUATERNARY" then
            clear_search = entry
        end
    end
    if not primary then error("Primary keybind entry missing from built Vendor group") end
    if not shoulder_previous then error("Left-shoulder keybind entry missing from built Vendor group") end
    if not clear_search then error("Clear-search keybind entry missing from built Vendor group") end

    primary.callback()
    assert_equals(primary_calls, 1, "Vendor primary callback invokes the component action")
    assert_equals(last_action, "Vendor.UI_SHORTCUT_PRIMARY",
        "Vendor keybind detail events preserve the shared input-anchor last action")
    assert_equals(trace_events[1] and trace_events[1].event, "input.keybind",
        "Vendor keybind callback first emits the shared input anchor")
    assert_equals(trace_events[2] and trace_events[2].event, "vendor.keybind",
        "Vendor keybind callback emits a vendor detail begin event")
    if not (trace_events[2] and trace_events[2].data and trace_events[2].data._inputAnchorDetail == true) then
        error("Vendor keybind detail event is marked as input-anchor detail")
    end

    local cycle_calls = 0
    vendor_instance._vendorHeaderEntryCount = 2
    vendor_instance._searchModeActive = false
    vendor_instance._searchHeaderActive = false
    vendor_instance.textSearchHeaderFocus = {
        IsActive = function()
            return true
        end,
    }
    vendor_instance.CycleTabs = function(_, direction)
        cycle_calls = cycle_calls + 1
        vendor_instance.lastCycleDirection = direction
    end
    shoulder_previous.callback()
    assert_equals(cycle_calls, 1,
        "Vendor shoulder cycling ignores stale focus-object active state when search lifecycle flags are clear")
    assert_equals(vendor_instance.lastCycleDirection, -1,
        "Vendor left shoulder cycles to the previous category when search is not active")

    local clear_calls = 0
    vendor_instance.textSearchHeaderControl = { IsHidden = function() return false end }
    vendor_instance.searchQuery = "sword"
    vendor_instance.ClearSearchInput = function()
        clear_calls = clear_calls + 1
    end
    BETTERUI.Interface = nil
    local clear_ok, clear_result, clear_err = pcall(clear_search.callback)
    assert_equals(clear_ok, true, "Vendor clear-search callback is safe without BETTERUI.Interface")
    assert_equals(clear_result, true, "Vendor clear-search callback reports a handled action")
    assert_equals(clear_err, nil, "Vendor clear-search callback returns no error on guarded refresh")
    assert_equals(clear_calls, 1, "Vendor clear-search callback still clears search without Interface refresh")
end

run_vendor_keybind_anchor_behavior()

print("ok")
