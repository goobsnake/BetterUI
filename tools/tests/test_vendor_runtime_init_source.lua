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
assert_contains(vendorSource, "local function ApplyVendorResolvedMode(targetMode, refreshList)",
    "Vendor runtime owns mode application through a shared helper")
assert_contains(vendorSource, "ScheduleVendorOpenStoreSync = function(targetMode, delayMs)",
    "Vendor runtime schedules open-store retries through a named helper")
assert_contains(vendorSource, "local function BuildVendorOpenStoreDeps()",
    "Vendor runtime builds open-store workflow deps through a named helper")
assert_contains(vendorSource, "local function BuildVendorOpenFenceDeps()",
    "Vendor runtime builds fence-open workflow deps through a named helper")
assert_contains(vendorSource, "local function BuildVendorCloseStoreDeps()",
    "Vendor runtime builds close-store workflow deps through a named helper")
assert_contains(vendorSource, "local function ResolveVendorRuntimeDependency(fieldName, label)",
    "Vendor root resolves runtime collaborators through a shared dependency helper")
assert_contains(vendorSource, "local function GetVendorNativeStoreBridge()",
    "Vendor root exposes a lazy getter for the native-store bridge")
assert_contains(vendorSource, "local function GetVendorBootstrapRuntime()",
    "Vendor root exposes a lazy getter for the bootstrap runtime")
assert_contains(vendorSource, "local function GetVendorComponentCatalog()",
    "Vendor root exposes a lazy getter for the component catalog")
assert_contains(vendorSource, "local function GetVendorEventBridge()",
    "Vendor root exposes a lazy getter for the event bridge")
assert_contains(vendorSource, "local function GetVendorInteractionRuntime()",
    "Vendor root exposes a lazy getter for the interaction runtime")
assert_contains(vendorSource, "local function GetVendorBatchRuntime()",
    "Vendor root exposes a lazy getter for the batch runtime")
assert_contains(vendorSource, "local function GetVendorExecuteSafely()",
    "Vendor root resolves its safe-execute helper through a named getter")
assert_not_contains(vendorSource, "local function DefaultExecuteSafely(context, fn, ...)",
    "Vendor root no longer duplicates safe-execute fallback implementation")
assert_not_contains(vendorSource, "SafeCall = type(Vendor.ExecuteSafely) == \"function\" and Vendor.ExecuteSafely or DefaultExecuteSafely",
    "Vendor root no longer rebinds a local SafeCall wrapper around Vendor.ExecuteSafely")
assert_not_contains(vendorSource, "local NativeStoreBridge = assert(Vendor.NativeStoreBridge",
    "Vendor root no longer asserts the native-store bridge at import time")
assert_not_contains(vendorSource, "local VendorBootstrapRuntime = assert(Vendor.BootstrapRuntime",
    "Vendor root no longer asserts the bootstrap runtime at import time")
assert_not_contains(vendorSource, "local VendorComponentCatalog = assert(Vendor.ComponentCatalog",
    "Vendor root no longer asserts the component catalog at import time")
assert_not_contains(vendorSource, "local VendorEventBridge = assert(Vendor.EventBridge",
    "Vendor root no longer asserts the event bridge at import time")
assert_not_contains(vendorSource, "local VendorInteractionRuntime = assert(Vendor.InteractionRuntime",
    "Vendor root no longer asserts the interaction runtime at import time")
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
assert_contains(safeExecuteSource, 'BETTERUI.CIM.UserNotify(context, tostring(result))',
    "Vendor safe-execute helper routes fallback failures through the shared notifier")
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
assert_contains(interactionRuntimeSource, "function InteractionRuntime.OnOpenStore(state, deps)",
    "Vendor interaction runtime owns open-store orchestration")
assert_contains(interactionRuntimeSource, "function InteractionRuntime.OnOpenFence(state, deps, enableSell, enableLaunder)",
    "Vendor interaction runtime owns fence-open orchestration")
assert_contains(interactionRuntimeSource, "function InteractionRuntime.OnCloseStore(state, deps)",
    "Vendor interaction runtime owns close-store teardown")

assert_contains(vendorSource, "RegisterVendorComponents(instance)",
    "Vendor.Init delegates component registration to the helper")
assert_contains(vendorSource, "GetVendorComponentCatalog().Register(instance)",
    "Vendor component registration delegates to the component catalog collaborator")
assert_contains(vendorSource, "InitializeVendorList(instance)",
    "Vendor.Init delegates list setup to the helper")
assert_contains(vendorSource, "GetVendorBootstrapRuntime().InitializeList(instance, {",
    "Vendor list helper delegates plumbing to the bootstrap runtime collaborator")
assert_contains(vendorSource, "InitializeVendorSearch(instance)",
    "Vendor.Init delegates search setup to the helper")
assert_contains(vendorSource, "GetVendorBootstrapRuntime().InitializeSearch(instance, {",
    "Vendor search helper delegates plumbing to the bootstrap runtime collaborator")
assert_contains(vendorSource, "InitializeVendorInteractiveSurfaces(instance)",
    "Vendor.Init delegates keybind and sort setup to the helper")
assert_contains(vendorSource, "GetVendorBootstrapRuntime().InitializeInteractiveSurfaces(instance, {",
    "Vendor interactive-surface helper delegates plumbing to the bootstrap runtime collaborator")
assert_contains(vendorSource, "CreateVendorScene(instance)",
    "Vendor.Init delegates scene creation to the helper")
assert_contains(vendorSource, "GetVendorBootstrapRuntime().CreateScene(instance, {",
    "Vendor scene helper delegates scene construction to the bootstrap runtime collaborator")
assert_contains(vendorSource, "TakeOverNativeStoreScene(instance)",
    "Vendor.Init delegates native store takeover to the helper")
assert_contains(vendorSource, "RegisterVendorSceneLifecycle(instance)",
    "Vendor.Init delegates scene lifecycle registration to the helper")
assert_contains(vendorSource, "GetVendorBootstrapRuntime().RegisterSceneLifecycle(instance, {",
    "Vendor scene lifecycle helper delegates registration to the bootstrap runtime collaborator")
assert_contains(vendorSource, "RegisterVendorEvents(EVENT_MANAGER)",
    "Vendor.Init delegates event registration to the helper")
assert_contains(vendorSource, "GetVendorEventBridge().Register(eventManager, EVENT_NS, {",
    "Vendor event helper delegates registration plumbing to the event-bridge collaborator")

assert_contains(vendorSource, "ResetVendorInteractionState()",
    "Vendor open handlers share the interaction reset helper")
assert_contains(vendorSource, "resetRuntimeState = ResetActiveVendorRuntimeState,",
    "Vendor open handlers share the runtime reset helper")
assert_contains(vendorSource, "local targetMode = ResolveVendorTargetMode()",
    "OnOpenStore resolves target mode through the shared helper")
assert_contains(interactionRuntimeSource, "deps.applyVendorResolvedMode(targetMode, false)",
    "OnOpenStore applies the target mode through the shared helper")
assert_contains(vendorSource, "ScheduleVendorOpenStoreSync(targetMode, 120)",
    "OnOpenStore schedules native-store resync through the shared helper")
assert_contains(vendorSource, "ApplyVendorInteractionState(GetVendorInteractionRuntime().OnOpenStore(SnapshotVendorInteractionState(), BuildVendorOpenStoreDeps()))",
    "Vendor open-store handler delegates orchestration to the interaction runtime collaborator")
assert_contains(vendorSource, "ApplyVendorInteractionState(GetVendorInteractionRuntime().OnOpenFence(SnapshotVendorInteractionState(), BuildVendorOpenFenceDeps(), enableSell, enableLaunder))",
    "Vendor fence-open handler delegates orchestration to the interaction runtime collaborator")
assert_contains(vendorSource, "ApplyVendorInteractionState(GetVendorInteractionRuntime().OnCloseStore(SnapshotVendorInteractionState(), BuildVendorCloseStoreDeps()))",
    "Vendor close-store handler delegates orchestration to the interaction runtime collaborator")
assert_contains(vendorSource, "GetVendorNativeStoreBridge().TakeOverScene(instance)",
    "Vendor scene takeover delegates to the native-store bridge")
assert_contains(vendorSource, "GetVendorNativeStoreBridge().ScheduleOpenStoreSync(targetMode, delayMs)",
    "Vendor deferred store sync delegates scheduling to the native-store bridge")
assert_contains(vendorSource, "GetVendorNativeStoreBridge().ResolveTargetMode()",
    "Vendor target-mode resolution delegates to the native-store bridge")
assert_contains(vendorSource, "GetVendorNativeStoreBridge().ApplyResolvedMode(targetMode, refreshList)",
    "Vendor mode application delegates to the native-store bridge")
assert_contains(vendorSource, "GetVendorNativeStoreBridge().UpdateSceneManagerStoreAlias(Vendor.instance)",
    "Vendor scene-alias updates delegate to the native-store bridge")
assert_contains(vendorSource, "GetVendorExecuteSafely()(context .. \":IsStoreEmpty\", IsStoreEmpty)",
    "Vendor root routes store-availability probes through the shared safe-execute helper")
assert_contains(vendorSource, "GetVendorExecuteSafely()(\"Vendor.Init:\" .. tostring(stepName), setupFn)",
    "Vendor setup steps route through the shared safe-execute helper")

print("  OK")
