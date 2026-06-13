--[[
File: tools/tests/test_inventory_junk_carousel_keybinds.lua
Purpose: Regression test for PB-002. The gamepad action dialog wraps its lifetime
         in KEYBIND_STRIP:PushKeybindGroupState() (show) / PopKeybindGroupState()
         (hide). A single-item "Mark as Junk" used to run keybind/list restoration
         SYNCHRONOUSLY while the dialog's pushed state was still the top state,
         corrupting the snapshot so the ethereal LB/RB carousel keybind group
         (BETTERUI_TabBarScrollList.keybindStripDescriptor) was lost after Pop --
         killing L1/R1 category paging.

         This test mocks a faithful KEYBIND_STRIP Push/Pop/Add/Remove/Has state
         stack plus a mock tabBar(active/Activate/Deactivate) and verifies:
           1. The OLD (synchronous-restore) behavior loses the carousel group.
           2. The NEW behavior (defer restore to OnFinish, after Pop) keeps it.
           3. EnsureHeaderKeybindsActive recovers even when tabBar.active is
              stale-true and the carousel group is missing from the strip.

Mirrors the source change in:
  - Modules/Inventory/Actions/ItemActionHandlers.lua (ToggleJunkState)
  - Modules/Inventory/Core/HeaderManager.lua (EnsureHeaderKeybindsActive)
]]

-- ---------------------------------------------------------------------------
-- Faithful mock of ZO_KeybindStrip Push/Pop group-state semantics.
-- Modeled on esoui/libraries/zo_keybindstrip/zo_keybindstrip.lua:
--   PushKeybindGroupState() copies the live keybindGroups into a saved state and
--   clears the live strip; PopKeybindGroupState() clears the live (top) strip and
--   restores the saved state's groups. HasKeybindButtonGroup() reports membership
--   of the live (top) state.
-- ---------------------------------------------------------------------------
local function MakeKeybindStrip()
    local strip = {
        keybindGroups = {}, -- live (top) state: descriptor -> true
        stateStack = {},    -- saved snapshots pushed under the live state
    }

    function strip:AddKeybindButtonGroup(descriptor)
        if descriptor then
            self.keybindGroups[descriptor] = true
        end
    end

    function strip:RemoveKeybindButtonGroup(descriptor)
        if descriptor then
            self.keybindGroups[descriptor] = nil
        end
    end

    function strip:UpdateKeybindButtonGroup(_descriptor)
        -- no-op for membership purposes
    end

    function strip:HasKeybindButtonGroup(descriptor)
        return self.keybindGroups[descriptor] ~= nil
    end

    function strip:PushKeybindGroupState()
        -- Snapshot the live groups, then clear the live strip.
        local saved = {}
        for descriptor in pairs(self.keybindGroups) do
            saved[descriptor] = true
        end
        table.insert(self.stateStack, saved)
        self.keybindGroups = {}
    end

    function strip:PopKeybindGroupState()
        local n = #self.stateStack
        if n == 0 then
            return
        end
        -- Clear the live (top) state, then restore the saved snapshot.
        self.keybindGroups = {}
        local saved = table.remove(self.stateStack, n)
        for descriptor in pairs(saved) do
            self.keybindGroups[descriptor] = true
        end
    end

    return strip
end

-- ---------------------------------------------------------------------------
-- Mock BETTERUI_TabBarScrollList: SetDirectionalInputEnabled(false) at creation,
-- so Activate only adds the carousel keybind group (no DIRECTIONAL_INPUT touch).
-- ---------------------------------------------------------------------------
local function MakeTabBar(strip)
    local tabBar = {
        active = false,
        keybindStripDescriptor = { "LB", "RB" }, -- stand-in carousel descriptor
        activateCount = 0,
        deactivateCount = 0,
    }

    function tabBar:Activate()
        self.activateCount = self.activateCount + 1
        strip:AddKeybindButtonGroup(self.keybindStripDescriptor)
        self.active = true
    end

    function tabBar:Deactivate()
        self.deactivateCount = self.deactivateCount + 1
        strip:RemoveKeybindButtonGroup(self.keybindStripDescriptor)
        self.active = false
    end

    return tabBar
end

-- EnsureKeybindGroupAdded mirror (Modules/CIM/Core/Presentation/KeybindHelpers.lua).
local function EnsureKeybindGroupAdded(strip, descriptor)
    if not descriptor or not strip then return end
    if strip:HasKeybindButtonGroup(descriptor) then
        strip:UpdateKeybindButtonGroup(descriptor)
        return
    end
    strip:AddKeybindButtonGroup(descriptor)
    strip:UpdateKeybindButtonGroup(descriptor)
end

-- ---------------------------------------------------------------------------
-- NEW EnsureHeaderKeybindsActive logic (mirrors HeaderManager.lua after fix).
-- Robust to stale-true tabBar.active: when the carousel group is missing from
-- the strip, force a guarded Deactivate/Activate cycle.
-- ---------------------------------------------------------------------------
local function EnsureHeaderKeybindsActive(strip, tabBar)
    if not tabBar then return end
    local descriptor = tabBar.keybindStripDescriptor
    local carouselMissing = descriptor and strip
        and not strip:HasKeybindButtonGroup(descriptor)

    if carouselMissing and tabBar.Deactivate and tabBar.Activate then
        tabBar:Deactivate()
        tabBar:Activate()
    elseif tabBar.Activate and not tabBar.active then
        tabBar:Activate()
    end

    if descriptor then
        EnsureKeybindGroupAdded(strip, descriptor)
    end
end

-- ---------------------------------------------------------------------------
-- OLD (buggy) synchronous restoration mirror: runs while the dialog's pushed
-- state is the live top state. In real ZO_KeybindStrip, Add/Remove with a nil
-- stateIndex default to the BASE state (index 1) -- i.e. the snapshot Push saved,
-- NOT the live pushed top state. So the synchronous SetActiveKeybinds/RefreshKeybinds
-- churn removes the carousel group from the SAVED snapshot; Pop then restores a
-- snapshot that no longer contains it, killing LB/RB paging.
-- ---------------------------------------------------------------------------
local function SyncRestoreWhileDialogPushed_OLD(strip, tabBar)
    -- Default-stateIndex keybind ops target the base state (the saved snapshot
    -- under the pushed dialog state). The SetActiveKeybinds churn removes the
    -- carousel descriptor from that snapshot -- so Pop never restores it.
    local savedSnapshot = strip.stateStack[#strip.stateStack]
    if savedSnapshot then
        savedSnapshot[tabBar.keybindStripDescriptor] = nil
    end
end

-- ===========================================================================
-- Test harness
-- ===========================================================================
local tests_passed = 0
local tests_failed = 0

local function assert_equal(expected, actual, message)
    if expected == actual then
        tests_passed = tests_passed + 1
        print("  [OK] " .. message)
    else
        tests_failed = tests_failed + 1
        print("  [X] " .. message)
        print("       Expected: " .. tostring(expected))
        print("       Actual:   " .. tostring(actual))
    end
end

local function assert_true(value, message)
    assert_equal(true, value, message)
end

print("=== PB-002: Junk toggle must not kill LB/RB carousel paging ===")

-- ---------------------------------------------------------------------------
-- Scenario 1 (characterizes the BUG): synchronous restore corrupts the snapshot.
-- add carousel -> Push (dialog open) -> SYNC restore -> Pop (dialog close):
-- carousel group is LOST.
-- ---------------------------------------------------------------------------
do
    local strip = MakeKeybindStrip()
    local tabBar = MakeTabBar(strip)

    -- Carousel active before the dialog opens.
    tabBar:Activate()
    assert_true(strip:HasKeybindButtonGroup(tabBar.keybindStripDescriptor),
        "precondition: carousel group present before dialog")

    -- Dialog opens: snapshot+clear live strip. tabBar.active stays stale-true
    -- (the parametric action dialog never calls tabBar:Deactivate()).
    strip:PushKeybindGroupState()
    assert_true(not strip:HasKeybindButtonGroup(tabBar.keybindStripDescriptor),
        "after Push, carousel group is removed from the live strip")
    assert_true(tabBar.active, "after Push, tabBar.active is left stale-true")

    -- OLD behavior: junk toggle restores keybinds synchronously while pushed.
    SyncRestoreWhileDialogPushed_OLD(strip, tabBar)

    -- Dialog closes: Pop restores the saved snapshot (which never received the
    -- synchronous re-add) and wipes the live (pushed) state.
    strip:PopKeybindGroupState()

    assert_true(not strip:HasKeybindButtonGroup(tabBar.keybindStripDescriptor),
        "OLD/buggy: carousel group is LOST after Pop (regression characterized)")
end

-- ---------------------------------------------------------------------------
-- Scenario 2 (the FIX): defer restoration to OnFinish, which runs AFTER Pop.
-- add carousel -> Push -> (no sync restore) -> Pop -> deferred OnFinish restore.
-- carousel group present AND tabBar.active true afterwards.
-- ---------------------------------------------------------------------------
do
    local strip = MakeKeybindStrip()
    local tabBar = MakeTabBar(strip)

    tabBar:Activate()
    assert_true(strip:HasKeybindButtonGroup(tabBar.keybindStripDescriptor),
        "precondition: carousel group present before dialog (fix scenario)")

    -- Dialog opens.
    strip:PushKeybindGroupState()
    -- NEW behavior: ToggleJunkState performs NO synchronous keybind restoration.

    -- Dialog closes: Pop. Force the adversarial case where the snapshot lost the
    -- carousel group and tabBar.active is stale-true to prove recovery.
    strip:PopKeybindGroupState()
    strip:RemoveKeybindButtonGroup(tabBar.keybindStripDescriptor)
    tabBar.active = true
    assert_true(not strip:HasKeybindButtonGroup(tabBar.keybindStripDescriptor),
        "adversarial setup: carousel missing after Pop with stale-true active")

    -- Deferred OnFinish -> RestoreInventoryAfterDialog -> EnsureHeaderKeybindsActive.
    EnsureHeaderKeybindsActive(strip, tabBar)

    assert_true(strip:HasKeybindButtonGroup(tabBar.keybindStripDescriptor),
        "FIX: carousel group present after deferred OnFinish restore")
    assert_true(tabBar.active,
        "FIX: tabBar.active is true after deferred OnFinish restore")
    assert_true(tabBar.deactivateCount >= 1,
        "FIX: forced guarded Deactivate ran to clear the stale active flag")
    assert_true(tabBar.activateCount >= 2,
        "FIX: forced guarded Activate ran to re-add the carousel group")
end

-- ---------------------------------------------------------------------------
-- Scenario 3: when the carousel group is already present, do NOT churn it with
-- an unnecessary Deactivate/Activate cycle (avoids visual flicker / DI risk).
-- ---------------------------------------------------------------------------
do
    local strip = MakeKeybindStrip()
    local tabBar = MakeTabBar(strip)
    tabBar:Activate()
    local activatesBefore = tabBar.activateCount
    local deactivatesBefore = tabBar.deactivateCount

    EnsureHeaderKeybindsActive(strip, tabBar)

    assert_true(strip:HasKeybindButtonGroup(tabBar.keybindStripDescriptor),
        "no-op path: carousel group stays present")
    assert_equal(activatesBefore, tabBar.activateCount,
        "no-op path: no extra Activate when group already present and active")
    assert_equal(deactivatesBefore, tabBar.deactivateCount,
        "no-op path: no Deactivate when group already present")
end

print("\n=== Summary ===")
print(string.format("Passed: %d", tests_passed))
print(string.format("Failed: %d", tests_failed))
print("")

if tests_failed > 0 then
    os.exit(1)
end
