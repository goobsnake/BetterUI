--[[
File: tools/tests/test_vendor_runtime_init_source.lua
Purpose: Guards the Vendor init/runtime split so setup composition and
         open-store synchronization stay behind explicit helper seams.
Usage:
  lua tools/tests/test_vendor_runtime_init_source.lua
]]

local function read_file(path)
    local handle = assert(io.open(path, "r"))
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

print("test_vendor_runtime_init_source")

local vendorSource = read_file("Modules/Vendor/Vendor.lua")
local safeExecuteSource = read_file("Modules/Vendor/Core/VendorSafeExecute.lua")
local modePolicySource = read_file("Modules/Vendor/Core/VendorModePolicy.lua")
local bridgeSource = read_file("Modules/Vendor/Core/VendorNativeStoreBridge.lua")
local bootstrapRuntimeSource = read_file("Modules/Vendor/Core/VendorBootstrapRuntime.lua")
local componentCatalogSource = read_file("Modules/Vendor/Core/VendorComponentCatalog.lua")
local eventBridgeSource = read_file("Modules/Vendor/Core/VendorEventBridge.lua")
local interactionRuntimeSource = read_file("Modules/Vendor/Core/VendorInteractionRuntime.lua")
local manifestSource = read_file("BetterUI.txt")

assert_contains(vendorSource, "local function RegisterVendorComponents(instance)",
    "Vendor init owns component wiring through a named helper")
assert_contains(vendorSource, "local function InitializeVendorSearch(instance)",
    "Vendor init owns search wiring through a named helper")
assert_contains(vendorSource, "local function CreateVendorScene(instance)",
    "Vendor init owns scene creation through a named helper")
assert_contains(vendorSource, "local function TakeOverNativeStoreScene(instance)",
    "Vendor init owns native store scene takeover through a named helper")
assert_contains(vendorSource, "local function RegisterVendorEvents(eventManager)",
    "Vendor init owns event registration through a named helper")
assert_contains(vendorSource, "local function ApplyVendorInteractionState(nextState)",
    "Vendor runtime applies interaction updates through an explicit state seam")
assert_contains(vendorSource, "local VendorLifecycleRuntime = {}",
    "Vendor runtime defines a named lifecycle runtime collaborator")
assert_contains(vendorSource, "function VendorLifecycleRuntime:ResetInteractionState(instance)",
    "Vendor lifecycle runtime owns explicit interaction reset")
assert_contains(vendorSource, "function VendorLifecycleRuntime:MarkClosingState()",
    "Vendor lifecycle runtime owns explicit close-state mutation")
assert_contains(vendorSource, "local function ResolveVendorRuntimeDependency(fieldName, label)",
    "Vendor root resolves runtime collaborators through a shared dependency helper")
assert_not_contains(vendorSource, "local function ResolveVendorRuntime()",
    "Vendor root no longer materializes one-shot runtime dependency bundles")
assert_not_contains(vendorSource, "local function GetVendorNativeStoreBridge()",
    "Vendor root no longer uses one-hop native-store bridge getters")
assert_not_contains(vendorSource, "local function GetVendorBootstrapRuntime()",
    "Vendor root no longer uses one-hop bootstrap runtime getters")
assert_not_contains(vendorSource, "local function GetVendorComponentCatalog()",
    "Vendor root no longer uses one-hop component-catalog getters")
assert_not_contains(vendorSource, "local function GetVendorEventBridge()",
    "Vendor root no longer uses one-hop event-bridge getters")
assert_not_contains(vendorSource, "local function GetVendorInteractionRuntime()",
    "Vendor root no longer uses one-hop interaction-runtime getters")
assert_not_contains(vendorSource, "local function GetVendorBatchRuntime()",
    "Vendor root no longer uses one-hop batch-runtime getters")
assert_not_contains(vendorSource, "local function GetVendorExecuteSafely()",
    "Vendor root no longer wraps ExecuteSafely behind a trivial getter")
assert_not_contains(vendorSource, "local function DefaultExecuteSafely(context, fn, ...)",
    "Vendor root no longer duplicates safe-execute fallback implementation")
assert_not_contains(vendorSource, "Vendor.BuildActiveModeSet = BuildActiveModeSet",
    "Vendor root no longer re-exports mode-set construction helpers")
assert_not_contains(vendorSource, "Vendor.IsSellBuybackOnlyModeSet = IsSellBuybackOnlyModeSet",
    "Vendor root no longer re-exports sell/buyback-only helpers")

assert_contains(manifestSource, "Modules\\Vendor\\Core\\VendorSafeExecute.lua",
    "Vendor manifest loads the shared safe-execute helper before other runtime collaborators")
assert_contains(manifestSource, "Modules\\Vendor\\Core\\VendorNativeStoreBridge.lua",
    "Vendor manifest loads the native-store bridge before runtime setup")
assert_contains(manifestSource, "Modules\\Vendor\\Core\\VendorBootstrapRuntime.lua",
    "Vendor manifest loads the bootstrap runtime collaborator before runtime setup")
assert_contains(manifestSource, "Modules\\Vendor\\Core\\VendorComponentCatalog.lua",
    "Vendor manifest loads the component catalog collaborator before runtime setup")
assert_contains(manifestSource, "Modules\\Vendor\\Core\\VendorEventBridge.lua",
    "Vendor manifest loads the event-bridge collaborator before runtime setup")
assert_contains(manifestSource, "Modules\\Vendor\\Core\\VendorInteractionRuntime.lua",
    "Vendor manifest loads the interaction runtime collaborator before runtime setup")

assert_contains(safeExecuteSource, "function Vendor.ExecuteSafely(context, fn, ...)",
    "Vendor safe-execute helper owns the shared execution wrapper")
assert_contains(safeExecuteSource, "pcall(userNotify, context, tostring(err))",
    "Vendor safe-execute helper routes fallback failures through the shared notifier without masking root errors")
assert_not_contains(safeExecuteSource, "Vendor fallback error handling requires BETTERUI.CIM.UserNotify",
    "Vendor safe-execute helper no longer replaces fallback failures with notifier contract assertions")
assert_not_contains(modePolicySource, "Vendor.BuildActiveModeSet = ModePolicy.BuildActiveModeSet",
    "Vendor mode policy no longer exports mode-set construction on the root vendor table")
assert_not_contains(modePolicySource, "Vendor.IsSellBuybackOnlyModeSet = ModePolicy.IsSellBuybackOnlyModeSet",
    "Vendor mode policy no longer exports sell/buyback helper state on the root vendor table")
assert_contains(bridgeSource, "local function GetVendorExecuteSafely()",
    "Vendor native-store bridge resolves the shared safe-execute helper through a named getter")
assert_not_contains(bridgeSource, "local function SafeCall(context, fn, ...)",
    "Vendor native-store bridge no longer duplicates a local SafeCall implementation")
assert_contains(bridgeSource, "function NativeStoreBridge.TakeOverScene(instance)",
    "Vendor native-store bridge owns scene takeover")
assert_contains(bridgeSource, "function NativeStoreBridge.EnsureComponents(searchContext)",
    "Vendor native-store bridge owns component rebuild policy")
assert_contains(bridgeSource, "function NativeStoreBridge.ResolveTargetMode()",
    "Vendor native-store bridge owns target-mode reconciliation")
assert_contains(bridgeSource, "function NativeStoreBridge.ScheduleOpenStoreSync(targetMode, delayMs)",
    "Vendor native-store bridge owns deferred open-store sync scheduling")
assert_contains(bootstrapRuntimeSource, "function BootstrapRuntime.InitializeList(instance, deps)",
    "Vendor bootstrap runtime owns list initialization plumbing")
assert_contains(bootstrapRuntimeSource, "function BootstrapRuntime.InitializeSearch(instance, _deps)",
    "Vendor bootstrap runtime owns search initialization plumbing")
assert_contains(bootstrapRuntimeSource, "function BootstrapRuntime.RegisterSceneLifecycle(instance, deps)",
    "Vendor bootstrap runtime owns scene lifecycle registration")
assert_contains(componentCatalogSource, "function ComponentCatalog.Register(instance)",
    "Vendor component catalog owns mode-to-component registration")
assert_contains(eventBridgeSource, "function EventBridge.Register(eventManager, eventNamespace, handlers)",
    "Vendor event bridge owns event registration fan-out")
assert_contains(interactionRuntimeSource, "function InteractionRuntime.OpenStore(request)",
    "Vendor interaction runtime exposes canonical request-based open-store orchestration")
assert_contains(interactionRuntimeSource, "function InteractionRuntime.OpenFence(request)",
    "Vendor interaction runtime exposes canonical request-based fence-open orchestration")
assert_contains(interactionRuntimeSource, "function InteractionRuntime.CloseStore(request)",
    "Vendor interaction runtime exposes canonical request-based close-store teardown")
assert_contains(interactionRuntimeSource, "function InteractionRuntime.OnOpenStore(",
    "Vendor interaction runtime preserves positional open-store compatibility wrappers")
assert_contains(interactionRuntimeSource, "function InteractionRuntime.OnOpenFence(",
    "Vendor interaction runtime preserves positional fence-open compatibility wrappers")
assert_contains(interactionRuntimeSource, "function InteractionRuntime.OnCloseStore(",
    "Vendor interaction runtime preserves positional close-store compatibility wrappers")

assert_contains(vendorSource, "RegisterVendorComponents(instance)",
    "Vendor.Init delegates component registration to the helper")
assert_contains(vendorSource, 'ResolveVendorRuntimeDependency("ComponentCatalog", "component catalog").Register(instance)',
    "Vendor component registration delegates to the component catalog collaborator")
assert_contains(vendorSource, "InitializeVendorList(instance)",
    "Vendor.Init delegates list setup to the helper")
assert_contains(vendorSource, 'ResolveVendorRuntimeDependency("BootstrapRuntime", "bootstrap runtime").InitializeList(instance, {',
    "Vendor list helper delegates plumbing to the bootstrap runtime collaborator")
assert_contains(vendorSource, "InitializeVendorSearch(instance)",
    "Vendor.Init delegates search setup to the helper")
assert_contains(vendorSource, 'ResolveVendorRuntimeDependency("BootstrapRuntime", "bootstrap runtime").InitializeSearch(instance, {',
    "Vendor search helper delegates plumbing to the bootstrap runtime collaborator")
assert_contains(vendorSource, "InitializeVendorInteractiveSurfaces(instance)",
    "Vendor.Init delegates keybind and sort setup to the helper")
assert_contains(vendorSource, 'ResolveVendorRuntimeDependency("BootstrapRuntime", "bootstrap runtime").InitializeInteractiveSurfaces(instance, {',
    "Vendor interactive-surface helper delegates plumbing to the bootstrap runtime collaborator")
assert_contains(vendorSource, "CreateVendorScene(instance)",
    "Vendor.Init delegates scene creation to the helper")
assert_contains(vendorSource, 'ResolveVendorRuntimeDependency("BootstrapRuntime", "bootstrap runtime").CreateScene(instance, {})',
    "Vendor scene helper delegates scene construction to the bootstrap runtime collaborator")
assert_contains(vendorSource, "TakeOverNativeStoreScene(instance)",
    "Vendor.Init delegates native store takeover to the helper")
assert_contains(vendorSource, "RegisterVendorSceneLifecycle(instance)",
    "Vendor.Init delegates scene lifecycle registration to the helper")
assert_contains(vendorSource, 'ResolveVendorRuntimeDependency("BootstrapRuntime", "bootstrap runtime").RegisterSceneLifecycle(instance, {',
    "Vendor scene lifecycle helper delegates registration to the bootstrap runtime collaborator")
assert_contains(vendorSource, "RegisterVendorEvents(EVENT_MANAGER)",
    "Vendor.Init delegates event registration to the helper")
assert_contains(vendorSource, 'ResolveVendorRuntimeDependency("EventBridge", "event bridge").Register(eventManager, EVENT_NS, {',
    "Vendor event helper delegates registration plumbing to the event-bridge collaborator")

assert_contains(interactionRuntimeSource, "resolved.resetInteractionState()",
    "OnOpenStore resets interaction state through the resolved dependency seam")
assert_contains(interactionRuntimeSource, "runtime:ResetInteractionState(instance)",
    "request-based runtime paths reset interaction state through the lifecycle runtime collaborator")
assert_contains(interactionRuntimeSource, "BuildLifecycleDeps(",
    "Vendor interaction runtime adapts the lifecycle runtime into explicit dependency seams")
assert_contains(interactionRuntimeSource, "resolved.applyResolvedMode(targetMode, false)",
    "OnOpenStore applies the target mode through the interaction-runtime dependency seams")
assert_contains(interactionRuntimeSource, "resolved.scheduleOpenStoreSync(targetMode, 120)",
    "OnOpenStore schedules deferred mode reconciliation through the interaction-runtime dependency seams")
assert_contains(vendorSource, 'ResolveVendorRuntimeDependency("InteractionRuntime", "interaction runtime")',
    "Vendor root resolves interaction runtime directly at use sites")
assert_contains(vendorSource, ".OpenStore({",
    "Vendor open-store handler delegates orchestration to the interaction runtime collaborator")
assert_contains(vendorSource, "runtime = VendorLifecycleRuntime,",
    "Vendor open/close handlers pass the explicit lifecycle runtime collaborator")
assert_contains(vendorSource, "nativeStoreBridge = ResolveVendorRuntimeDependency(\"NativeStoreBridge\", \"native store bridge\"),",
    "Vendor open/close handlers pass the native-store bridge collaborator explicitly via named dependencies")
assert_contains(vendorSource, ".OpenStore({",
    "Vendor open-store handler delegates orchestration to the interaction runtime collaborator")
assert_contains(vendorSource, ".OpenFence({",
    "Vendor fence-open handler delegates orchestration to the interaction runtime collaborator")
assert_contains(vendorSource, ".CloseStore({",
    "Vendor close-store handler delegates orchestration to the interaction runtime collaborator")
assert_contains(vendorSource, 'ResolveVendorRuntimeDependency("NativeStoreBridge", "native store bridge").TakeOverScene(instance)',
    "Vendor scene takeover delegates to the native-store bridge")
assert_contains(vendorSource, ".UpdateSceneManagerStoreAlias(Vendor.instance)",
    "Vendor scene-alias updates delegate to the native-store bridge")
assert_contains(vendorSource, 'ResolveVendorRuntimeDependency("ExecuteSafely", "safe execute helper")',
    "Vendor root routes store probes and setup steps through the shared safe-execute helper")

print("  OK")
