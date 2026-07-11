--[[
File: tools/tests/test_companions_class_source.lua
Purpose: Source-level regression checks for the companion base-class seams.

Usage:
  lua tools/tests/test_companions_class_source.lua
]]

if false then
    dofile("Modules/Companions/Core/CompanionsClass.lua")
end

local passed = 0
local failed = 0

local function assert_true(value, label)
    if value then
        passed = passed + 1
    else
        failed = failed + 1
        io.stderr:write("Assertion failed: " .. label .. "\n")
    end
end

local function read_file(path)
    local handle = assert(io.open(path, "r"))
    local content = handle:read("*a")
    handle:close()
    return content
end

local source = read_file("Modules/Companions/Core/CompanionsClass.lua")
local companionXml = read_file("Modules/Companions/Templates/GamepadCompanionInventory.xml")

assert_true(source:find("BETTERUI%.Companions%.EnsureTaskManager = EnsureCompanionsTaskManager") ~= nil,
    "CompanionsClass exposes the shared task-manager installer")
assert_true(source:find("BETTERUI%.Companions%.Tasks = BETTERUI%.Companions%.Tasks or CompanionsDeferredTask%.CreateLazyManagerProxy%(EnsureCompanionsTaskManager%)") ~= nil,
    "CompanionsClass defines the lazy companion task proxy")
assert_true(source:find("BETTERUI%.Companions%.Class = BETTERUI%.CIM%.GenericWindow:Subclass%(%)") ~= nil,
    "CompanionsClass subclasses the shared CIM generic window")
assert_true(source:find("BETTERUI%.Companions%.Class%.SEARCH_LIFECYCLE = %{%s*") ~= nil,
    "CompanionsClass defines the shared search lifecycle contract")
assert_true(source:find("function BETTERUI%.Companions%.Class:IsSceneShowing%(%)") ~= nil,
    "CompanionsClass exposes IsSceneShowing")
assert_true(source:find("function BETTERUI%.Companions%.Class:EnterSearchMode%(%)") ~= nil,
    "CompanionsClass exposes EnterSearchMode")
assert_true(source:find("function BETTERUI%.Companions%.Class:ExitSearchMode%(%)") ~= nil,
    "CompanionsClass exposes ExitSearchMode")
assert_true(source:find("function BETTERUI%.Companions%.Class:RequestHeaderFocus%(%)") ~= nil,
    "CompanionsClass exposes RequestHeaderFocus")
assert_true(source:find("function BETTERUI%.Companions%.Class:OnHeaderEntered%(%)") ~= nil,
    "CompanionsClass exposes OnHeaderEntered")
assert_true(source:find("function BETTERUI%.Companions%.Class:AcceptSearchAndReturnToList%(%)") ~= nil,
    "CompanionsClass exposes an explicit search-accept transition")
assert_true(source:find("function BETTERUI%.Companions%.Class:SetSearchDirectionalInputUpdate%(enabled%)") ~= nil,
    "CompanionsClass owns search-only directional input")
assert_true(source:find("function BETTERUI%.Companions%.Class:UpdateSearchDirectionalInput%(%)") ~= nil,
    "CompanionsClass handles joystick-down search exit")
local directionalQuery = assert(source:find("DIRECTIONAL_INPUT.GetY", 1, true))
local rawStickQuery = assert(source:find("GetGamepadLeftStickY", 1, true))
assert_true(directionalQuery < rawStickQuery,
    "Companion search honors ESOUI directional-input arbitration before raw stick fallback")
local enterSearchStart = assert(source:find("function BETTERUI.Companions.Class:EnterSearchMode()", 1, true))
local enterSearchEnd = assert(source:find("function BETTERUI.Companions.Class:ExitSearchMode()", enterSearchStart, true))
local enterSearchSource = source:sub(enterSearchStart, enterSearchEnd - 1)
local enterFlags = assert(enterSearchSource:find("self._searchModeActive = true", 1, true))
local enterActivate = assert(enterSearchSource:find("self.textSearchHeaderFocus:Activate()", 1, true))
assert_true(enterSearchSource:find("if self._searchModeActive or self._searchHeaderActive then", 1, true) ~= nil,
    "Companion search entry is idempotent and rejects recursive focus callbacks")
assert_true(enterFlags < enterActivate,
    "Companion search marks lifecycle active before activating the edit-box focus controller")
assert_true(enterSearchSource:find("self:DeactivateListInput()", 1, true) ~= nil,
    "Companion search deactivates and dims the item list")
assert_true(enterSearchSource:find("self:EnsureHeaderKeybindsActive()", 1, true) ~= nil,
    "Companion search preserves the LB/RB category keybind group")
assert_true(enterSearchSource:find("self:SetSearchDirectionalInputUpdate(true)", 1, true) ~= nil,
    "Companion search activates its native-style directional listener")
local exitSearchStart = enterSearchEnd
local exitSearchEnd = assert(source:find("function BETTERUI.Companions.Class:ExitSearchFocus()", exitSearchStart, true))
local exitSearchSource = source:sub(exitSearchStart, exitSearchEnd - 1)
local exitFlags = assert(exitSearchSource:find("self._searchModeActive = false", 1, true))
local exitDeactivate = assert(exitSearchSource:find("self.textSearchHeaderFocus:Deactivate()", 1, true))
assert_true(exitFlags < exitDeactivate,
    "Companion search clears lifecycle state before focus loss can recursively exit")
assert_true(exitSearchSource:find("self:SetSearchDirectionalInputUpdate(false)", 1, true) ~= nil,
    "Companion search exit releases its directional listener")
assert_true(exitSearchSource:find("self:EnsureHeaderKeybindsActive()", 1, true) ~= nil,
    "Companion search exit restores LB/RB carousel ownership")
assert_true(source:find("KEYBIND_STRIP%.keybindButtonGroups") == nil,
    "CompanionsClass never reads the nonexistent keybindButtonGroups field")
assert_true(source:find("BETTERUI%.Interface%.RemoveOwnedKeybindGroups%(") ~= nil,
    "CompanionsClass search cleanup removes only companion-owned keybind groups")
assert_true(source:find("BETTERUI%.Interface%.RestoreKeybindGroups%(self%._searchRemovedKeybindGroups%)") ~= nil,
    "CompanionsClass ExitSearchMode restores exactly the groups the cleanup removed")
assert_true(source:find("function BETTERUI%.Companions%.Class:RefreshCompanionFooter%(%)") ~= nil,
    "CompanionsClass exposes RefreshCompanionFooter")
assert_true(companionXml:find('inherits="BETTERUI_Gamepad_ParametricList_Screen"', 1, true) ~= nil,
    "Companions XML materializes the Inventory parametric screen")
assert_true(source:find('"BETTERUI_Gamepad_ParametricList_Screen")', 1, true) == nil,
    "CompanionsClass never dynamically creates the hidden screen template")
assert_true(source:find('"BETTERUI_Gamepad_ParametricList_Screen_ListContainer"', 1, true) ~= nil,
    "CompanionsClass materializes Inventory's Main list container")
assert_true(source:find("BETTERUI.CIM.UnifiedFooter.MODE.CURRENCY", 1, true) ~= nil,
    "CompanionsClass selects the Inventory currency footer")
assert_true(source:find("self.unifiedFooterController:SetCapacityBagId(BAG_COMPANION_WORN)", 1, true) ~= nil,
    "CompanionsClass scopes the Bag capacity metric to the Companion worn bag")
assert_true(source:find('GetNamedChild("Withdraw")', 1, true) == nil,
    "CompanionsClass no longer repurposes Banking withdraw controls")
assert_true(source:find('GetNamedChild("Deposit")', 1, true) == nil,
    "CompanionsClass no longer repurposes Banking deposit controls")
assert_true(source:find("function BETTERUI%.Companions%.Class:RefreshCompanionWeaponHeader%(%)") ~= nil,
    "CompanionsClass refreshes companion main and off-hand header icons")
assert_true(source:find("function BETTERUI%.Companions%.Class:PrepareNextClearNewStatus%(selectedData%)") ~= nil,
    "CompanionsClass exposes PrepareNextClearNewStatus")
assert_true(source:find("function BETTERUI%.Companions%.Class:TryClearNewStatus%(%)") ~= nil,
    "CompanionsClass exposes TryClearNewStatus")
assert_true(source:find("function BETTERUI%.Companions%.Class:TryClearNewStatusOnHidden%(%)") ~= nil,
    "CompanionsClass exposes TryClearNewStatusOnHidden")
assert_true(source:find("TIME_NEW_PERSISTS_WHILE_SELECTED_MS") ~= nil,
    "CompanionsClass uses the native new-item persistence delay")

if failed > 0 then
    error(string.format("test_companions_class_source.lua failed with %d failure(s)", failed))
end

print(string.format("test_companions_class_source.lua: %d passed", passed))
