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

assert_contains(vendor, "local function TraceVendorKeybind(key, phase, data)",
    "Vendor has a keybind-envelope helper")
assert_contains(vendor, "L.SetLastAction({",
    "Vendor keybind helper updates last action")
assert_contains(vendor, "TraceVendorEvent(\"vendor.keybind\", phase, data, L.CATEGORY.KEYBIND)",
    "Vendor keybind helper emits KEYBIND/vendor.keybind")
assert_contains(vendor, "local function ExecuteVendorKeybindAction(key, action, fn, endData)",
    "Vendor keybind callbacks share a terminal safe-execute wrapper")
assert_contains(vendor, "TraceVendorKeybind(key, \"failed\"",
    "Vendor keybind wrapper emits a terminal failure phase")

local primary = block_between(vendor, "keybind = \"UI_SHORTCUT_PRIMARY\",", "-- Secondary action", "primary keybind block")
local secondary = block_between(vendor, "keybind = \"UI_SHORTCUT_SECONDARY\",", "-- Quaternary action", "secondary keybind block")
local tertiary = block_between(vendor, "keybind = \"UI_SHORTCUT_TERTIARY\",", "-- Quinary:", "tertiary keybind block")

assert_contains(primary, "local key = \"UI_SHORTCUT_PRIMARY\"",
    "Primary keybind callback declares its trace key")
assert_contains(primary, "ExecuteVendorKeybindAction(key, \"multi_select_toggle\"",
    "Primary multi-select path uses the terminal keybind wrapper")
assert_contains(primary, "ExecuteVendorKeybindAction(key, \"primary\"",
    "Primary action path uses the terminal keybind wrapper")
assert_contains(primary, "TraceVendorKeybind(key, \"skipped\"",
    "Primary keybind callback emits skipped")

assert_contains(secondary, "local key = \"UI_SHORTCUT_SECONDARY\"",
    "Secondary keybind callback declares its trace key")
assert_contains(secondary, "ExecuteVendorKeybindAction(key, \"toggle_mode\"",
    "Secondary keybind callback uses the terminal keybind wrapper")
assert_contains(secondary, "TraceVendorKeybind(key, \"skipped\"",
    "Secondary keybind callback emits skipped")

assert_contains(tertiary, "local key = \"UI_SHORTCUT_TERTIARY\"",
    "Tertiary keybind callback declares its trace key")
assert_contains(tertiary, "ExecuteVendorKeybindAction(key, \"batch_abort\"",
    "Tertiary batch-abort path uses the terminal keybind wrapper")
assert_contains(tertiary, "TraceVendorKeybind(key, \"begin\", { action = \"batch_dialog\" })",
    "Tertiary batch-dialog path emits begin before dialog setup")
assert_contains(tertiary, "TraceVendorKeybind(key, \"failed\"",
    "Tertiary batch-dialog path emits failed on caught errors")
assert_contains(tertiary, "ExecuteVendorKeybindAction(key, \"sell_all_junk\"",
    "Tertiary sell-all path uses the terminal keybind wrapper")
assert_contains(tertiary, "ExecuteVendorKeybindAction(key, \"repair_all\"",
    "Tertiary repair-all path uses the terminal keybind wrapper")
assert_contains(tertiary, "TraceVendorKeybind(key, \"skipped\"",
    "Tertiary keybind callback emits skipped")

assert_contains(vendor, "ExecuteVendorKeybindAction(\"UI_SHORTCUT_LEFT_SHOULDER\", \"cycle_tabs_previous\"",
    "Left shoulder keybind callback uses the terminal keybind wrapper")
assert_contains(vendor, "ExecuteVendorKeybindAction(\"UI_SHORTCUT_RIGHT_SHOULDER\", \"cycle_tabs_next\"",
    "Right shoulder keybind callback uses the terminal keybind wrapper")
assert_contains(vendor, "ExecuteVendorKeybindAction(key, \"clear_search\"",
    "Clear-search keybind callback uses the terminal keybind wrapper")
assert_contains(vendor, "ExecuteVendorKeybindAction(key, \"multi_select_enter\"",
    "Quinary keybind callback uses the terminal keybind wrapper")
assert_contains(vendor, "ExecuteVendorKeybindAction(key, \"toggle_preview\"",
    "Preview keybind callback uses the terminal keybind wrapper")
assert_contains(vendor, "ExecuteVendorKeybindAction(\"UI_SHORTCUT_LEFT_STICK\", \"stack_all\"",
    "Fence stack-all keybind callback uses the terminal keybind wrapper")
assert_contains(vendor, "ExecuteVendorKeybindAction(\"UI_SHORTCUT_NEGATIVE\", action",
    "Back/exit keybind callback uses the terminal keybind wrapper")

assert_not_contains(block_between(primary, "keybind = \"UI_SHORTCUT_PRIMARY\",", "callback = function()", "primary pre-callback"),
    "TraceVendorKeybind", "Primary label/visible resolvers must not trace")
assert_not_contains(block_between(secondary, "keybind = \"UI_SHORTCUT_SECONDARY\",", "callback = function()", "secondary pre-callback"),
    "TraceVendorKeybind", "Secondary label/visible/enabled resolvers must not trace")
assert_not_contains(block_between(tertiary, "keybind = \"UI_SHORTCUT_TERTIARY\",", "callback = function()", "tertiary pre-callback"),
    "TraceVendorKeybind", "Tertiary label/visible/enabled resolvers must not trace")

print("ok")
