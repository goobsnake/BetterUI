--[[
File: tools/tests/test_inventory_primary_action_inplace_update.lua
Purpose: Regression test for PB-006. An in-place SingleSlotInventoryUpdate (e.g. a
         container opened/replaced by its contents at the same bag+slot) updates the
         row data WITHOUT firing the selection-change callback. The cached primary
         action (itemActions.actionName) is only recomputed on a selection change,
         and the same-frame fingerprint dedup in SetSelectedInventoryData (keyed on
         uniqueId|bagId|slotIndex|slotType) can skip re-resolution -- so the primary
         keybind kept showing the previous item's action (e.g. "Use" for the consumed
         container instead of "Mark as Junk" for the replacement item).

         The fix forces a re-resolution for the currently-selected slot on the
         non-dialog in-place update path, BEFORE RefreshKeybinds reads the cached
         actionName. This test models the SetSelectedInventoryData fingerprint dedup,
         the itemActions.actionName cache, RefreshItemActions, and the
         ResolvePrimaryActionState read path, and asserts:
           1. Without the fix (dedup skips), the resolved primary stays stale.
           2. With the fix (fingerprint cleared + RefreshItemActions), the resolved
              primary matches the new item B's real primary.

Mirrors the source change in Modules/Inventory/Inventory.lua (OnInventoryUpdated).
]]

-- ---------------------------------------------------------------------------
-- Minimal inventory-class model: just enough to exercise the dedup + re-resolve.
-- ---------------------------------------------------------------------------
local function MakeInventory()
    local inv = {
        itemActions = { actionName = nil, slotActions = {} },
        _selectedTarget = nil,
        _lastSetSelectedInventoryDataFingerprint = nil,
        _lastSetSelectedInventoryDataFrame = nil,
        _frameMs = 1000, -- fixed "current frame" so dedup can trigger
    }

    -- Mirror: ResolvePrimaryActionState reads the cached itemActions.actionName.
    function inv:ResolvePrimaryActionName()
        return self.itemActions.actionName
    end

    -- Mirror of BETTERUI.Inventory.Class:SetSelectedInventoryData fingerprint dedup.
    -- On a non-deduped call, itemActions.actionName is regenerated from the target's
    -- real primary action (itemActions:SetInventorySlot semantics).
    function inv:SetSelectedInventoryData(target)
        local fingerprint = string.format(
            "%s|%s|%s|%s",
            tostring(target and target.uniqueId or ""),
            tostring(target and target.bagId or ""),
            tostring(target and target.slotIndex or ""),
            tostring(target and target.slotType or "")
        )
        if self._lastSetSelectedInventoryDataFrame == self._frameMs
            and self._lastSetSelectedInventoryDataFingerprint == fingerprint then
            -- Same-frame duplicate: skip re-resolution (the coalescing guard).
            return false
        end
        self._lastSetSelectedInventoryDataFrame = self._frameMs
        self._lastSetSelectedInventoryDataFingerprint = fingerprint
        -- Re-resolve: regenerate the cached primary action for the target.
        self.itemActions.actionName = target and target.primaryAction or nil
        return true
    end

    -- Mirror of ZO_GamepadInventory:RefreshItemActions: re-reads the freshly
    -- selected target and routes it through SetSelectedInventoryData.
    function inv:RefreshItemActions()
        self:SetSelectedInventoryData(self._selectedTarget)
    end

    -- Mirror of the relevant OnInventoryUpdated non-dialog in-place-update branch.
    -- forceResolve=true reproduces the FIX; false reproduces the OLD behavior.
    function inv:OnInPlaceUpdate(forceResolve)
        -- refreshSelectedData(): selects the (already row-updated) target. In the
        -- same frame the fingerprint may already match, so this can be deduped.
        self:SetSelectedInventoryData(self._selectedTarget)
        if forceResolve then
            -- PB-006 fix: clear dedup fingerprint and force re-resolution before
            -- the keybind label is read.
            self._lastSetSelectedInventoryDataFingerprint = nil
            self._lastSetSelectedInventoryDataFrame = nil
            self:RefreshItemActions()
        end
    end

    return inv
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

print("=== PB-006: in-place update must re-resolve the primary action ===")

-- Container A and junkable replacement B occupy the SAME bag+slot. A container is
-- consumed and replaced; the engine reuses the slot, and here the in-place update
-- path leaves a matching same-frame fingerprint that triggers the dedup.
local SLOT = { bagId = 1, slotIndex = 7, slotType = 1 }
local containerA = { uniqueId = "uid-A", bagId = SLOT.bagId, slotIndex = SLOT.slotIndex,
                     slotType = SLOT.slotType, primaryAction = "Use" }
-- Worst case for the dedup: replacement shares the SAME fingerprint key fields as A
-- (same uniqueId|bag|slot|slotType) but a different real primary action.
local itemB = { uniqueId = "uid-A", bagId = SLOT.bagId, slotIndex = SLOT.slotIndex,
                slotType = SLOT.slotType, primaryAction = "Mark as Junk" }

-- ---------------------------------------------------------------------------
-- Scenario 1 (characterizes the BUG): without the forced re-resolution the dedup
-- skips and the primary stays stale ("Use").
-- ---------------------------------------------------------------------------
do
    local inv = MakeInventory()
    -- Seed selection on container A (resolves primary "Use") in the current frame.
    inv._selectedTarget = containerA
    inv:SetSelectedInventoryData(containerA)
    assert_equal("Use", inv:ResolvePrimaryActionName(),
        "seed: primary resolves to container A's 'Use'")

    -- In-place update replaces A with B at the same slot (row data updated). The
    -- fingerprint matches A's, so refreshSelectedData's call is deduped.
    inv._selectedTarget = itemB
    inv:OnInPlaceUpdate(false) -- OLD behavior

    assert_equal("Use", inv:ResolvePrimaryActionName(),
        "OLD/buggy: primary stays stale as 'Use' after in-place update")
end

-- ---------------------------------------------------------------------------
-- Scenario 2 (the FIX): forced re-resolution regenerates the primary for item B.
-- ---------------------------------------------------------------------------
do
    local inv = MakeInventory()
    inv._selectedTarget = containerA
    inv:SetSelectedInventoryData(containerA)
    assert_equal("Use", inv:ResolvePrimaryActionName(),
        "seed: primary resolves to container A's 'Use' (fix scenario)")

    inv._selectedTarget = itemB
    inv:OnInPlaceUpdate(true) -- FIX behavior

    assert_equal("Mark as Junk", inv:ResolvePrimaryActionName(),
        "FIX: primary re-resolves to item B's real primary 'Mark as Junk'")
end

-- ---------------------------------------------------------------------------
-- Scenario 3: when the replacement carries a distinct uniqueId, the dedup never
-- triggers and the primary resolves correctly with OR without the fix (the fix
-- must not regress this case).
-- ---------------------------------------------------------------------------
do
    local itemC = { uniqueId = "uid-C", bagId = SLOT.bagId, slotIndex = SLOT.slotIndex,
                    slotType = SLOT.slotType, primaryAction = "Equip" }
    local inv = MakeInventory()
    inv._selectedTarget = containerA
    inv:SetSelectedInventoryData(containerA)
    inv._selectedTarget = itemC
    inv:OnInPlaceUpdate(true)
    assert_equal("Equip", inv:ResolvePrimaryActionName(),
        "FIX: distinct-uniqueId replacement still resolves correctly")
end

print("\n=== Summary ===")
print(string.format("Passed: %d", tests_passed))
print(string.format("Failed: %d", tests_failed))
print("")

if tests_failed > 0 then
    os.exit(1)
end
