--[[
File: tools/tests/test_companions_runtime_source.lua
Purpose: Guards the Companions root/runtime split so Module.lua stays focused on
         lifecycle wiring while runtime scene/event orchestration lives in the
         core runtime helper.
Usage:
  lua tools/tests/test_companions_runtime_source.lua
]]

if false then
    dofile("Modules/Companions/Core/CompanionListManager.lua")
    dofile("Modules/Companions/Core/CompanionsRuntime.lua")
    dofile("Modules/Companions/Module.lua")
end

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

print("test_companions_runtime_source")

local moduleSource = read_file("Modules/Companions/Module.lua")
local runtimeSource = read_file("Modules/Companions/Core/CompanionsRuntime.lua")
local listManagerSource = read_file("Modules/Companions/Core/CompanionListManager.lua")
local itemListSource = read_file("Modules/Companions/Core/CompanionItemList.lua")
local manifestSource = read_file("BetterUI.txt")

assert_contains(runtimeSource, "function Companions.InitializeRuntime()",
    "Companions runtime helper owns the single runtime bootstrap entrypoint")
assert_contains(runtimeSource, "function Companions.CreateScene(instance)",
    "Companions runtime helper owns scene creation")
assert_contains(runtimeSource, "EVENT_OPEN_COMPANION_MENU",
    "Companions runtime opens the BetterUI scene from the native companion open event")
assert_not_contains(runtimeSource, "SCENE_MANAGER.scenes[\"companionEquipmentGamepad\"] =",
    "Companions runtime leaves the native companion scene table entry untouched")
assert_not_contains(runtimeSource, "COMPANION_EQUIPMENT_GAMEPAD = instance",
    "Companions runtime leaves the native companion global object untouched")
assert_not_contains(runtimeSource, "COMPANION_EQUIPMENT_GAMEPAD_SCENE = scene",
    "Companions runtime leaves the native companion scene global untouched")
assert_contains(runtimeSource, "function Companions.RegisterSceneLifecycle(instance)",
    "Companions runtime helper owns scene lifecycle registration")
assert_contains(runtimeSource, "function Companions.RegisterEvents(eventManager)",
    "Companions runtime helper owns event registration")
assert_contains(runtimeSource, "function BETTERUI.Companions.Class:TryEquipItem(inventorySlot)",
    "Companions class runtime helper owns TryEquipItem")
assert_contains(runtimeSource, "function Companions.BuildCoreKeybinds(instance)",
    "Companions runtime helper owns keybind construction")
assert_contains(runtimeSource, "instance.sortSetupDegraded = not sortOk",
    "Companions runtime degrades sorting instead of aborting on sort setup failure")
assert_not_contains(runtimeSource, "return nil, sortErr",
    "Companions runtime no longer aborts initialization when header sort setup fails")

assert_not_contains(moduleSource, "local function CreateCompanionScene(",
    "Companions Module.lua no longer defines scene creation directly")
assert_not_contains(moduleSource, "local function RegisterCompanionSceneLifecycle(",
    "Companions Module.lua no longer defines scene lifecycle directly")
assert_not_contains(moduleSource, "local function RegisterCompanionEvents(",
    "Companions Module.lua no longer defines event registration directly")
assert_not_contains(moduleSource, "function BETTERUI.Companions.Class:TryEquipItem(inventorySlot)",
    "Companions Module.lua no longer defines TryEquipItem directly")
assert_contains(moduleSource, "Companions.InitializeRuntime()",
    "Companions Module.lua delegates runtime bootstrap to the runtime helper")
assert_not_contains(moduleSource, "Companions.instance:SetupList(",
    "Companions Module.lua no longer wires list setup directly")
assert_not_contains(moduleSource, "Companions.instance:AddSearch(",
    "Companions Module.lua no longer wires search setup directly")
assert_not_contains(moduleSource, "Companions.instance.coreKeybinds =",
    "Companions Module.lua no longer wires runtime keybinds directly")
assert_contains(manifestSource, "Modules\\Companions\\Core\\CompanionsRuntime.lua",
    "Addon manifest loads the new Companions runtime helper")
assert_contains(runtimeSource, "CallCompanionSearchLifecycle(instance, \"clear\")",
    "Companions runtime keybinds clear search through the canonical search lifecycle")
assert_contains(runtimeSource, "CallCompanionSearchLifecycle(instance, \"requestEnter\")",
    "Companions runtime keybinds enter search through the canonical search lifecycle")
assert_contains(listManagerSource, "searchMixin.CallSearchLifecycle(self, \"exit\")",
    "Companion list manager exits search through the canonical lifecycle")
assert_contains(listManagerSource, "local function EnsureListDirectionalInputRegistration(list, listRegistrationCount)",
    "Companion list manager keeps list input activation in a focused helper")
assert_contains(listManagerSource, "local function ReleaseListDirectionalInput(list)",
    "Companion list manager keeps list input release in a focused helper")
assert_contains(runtimeSource, "Companions: absorbing ZO_CompanionEquipment_Gamepad.",
    "Companions runtime logs each forwarded call on the native shim")
assert_contains(runtimeSource, "screen:TryClearNewStatusOnHidden()",
    "Companions runtime clears pending new-item timers when the scene hides")
assert_contains(itemListSource, "self:UpdateTooltipEquippedIndicatorText(GAMEPAD_LEFT_TOOLTIP, ds.slotIndex)",
    "Companion item list wires the equipped indicator into the left tooltip")
assert_contains(itemListSource, "self:UpdateTooltipEquippedIndicatorText(GAMEPAD_RIGHT_TOOLTIP, compareSlot)",
    "Companion item list wires the equipped indicator into the right tooltip")
assert_contains(itemListSource, "GetItemCooldownInfo(BAG_COMPANION_WORN, slotIndex)",
    "Companion item list reads cooldown info for equipped items")
assert_contains(itemListSource, "GetItemCooldownInfo(BAG_BACKPACK, slotIndex)",
    "Companion item list reads cooldown info for backpack items")
assert_contains(itemListSource, "entry:SetCooldown(remaining, duration)",
    "Companion item list applies cooldown overlays to list entries")
-- Companion entryData must carry slotType (matching native companionequipment_gamepad.lua,
-- which calls ZO_InventorySlot_SetType(entryData, SLOT_TYPE_GAMEPAD_INVENTORY_ITEM)) so the
-- engine destroy-eligibility probe in CIM.ProtectionPolicy.CanDestroyItem actually runs
-- instead of being skipped on a nil slotType.
assert_contains(itemListSource, "slotType = SLOT_TYPE_GAMEPAD_INVENTORY_ITEM",
    "Companion item list tags entryData with the gamepad inventory slot type for the destroy probe")
do
    local slotTypeCount = 0
    for _ in itemListSource:gmatch("slotType = SLOT_TYPE_GAMEPAD_INVENTORY_ITEM") do
        slotTypeCount = slotTypeCount + 1
    end
    if slotTypeCount ~= 2 then
        error("Both equipped and backpack companion entryData carry the gamepad inventory slot type"
            .. "\nExpected 2 occurrences of slotType = SLOT_TYPE_GAMEPAD_INVENTORY_ITEM, found " .. slotTypeCount)
    end
end

assert_contains(moduleSource, "local instance, initErr = Companions.InitializeRuntime()",
    "Companions Module.lua handles runtime bootstrap failures explicitly")
assert_contains(moduleSource, "NotifyCompanionSetupFailure(initErr)",
    "Companions Module.lua routes runtime bootstrap failures through a user-facing notifier")

print("  OK")
