--[[
File: Modules/CIM/Actions/ProtectionPolicy.lua
Purpose: Centralized item protection policy checks for inventory, banking, and batch operations.
         Encapsulates IsItemPlayerLocked, BOP, bound, stolen, and junk eligibility checks
         to eliminate duplication across consumer modules.
Author: BetterUI Team
Last Modified: 2026-03-26
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
BETTERUI.CIM.ProtectionPolicy = {}

local Policy = BETTERUI.CIM.ProtectionPolicy

-- ============================================================================
-- LOCAL HELPERS
-- ============================================================================

--- @param bagId number
--- @param slotIndex number
--- @return boolean hasItem
local function HasItemAtSlot(bagId, slotIndex)
    local stackCount = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or nil
    return (stackCount or 0) > 0
end

--- @param bagId number
--- @param slotIndex number
--- @return boolean isCompanionItem
local function IsCompanionItem(bagId, slotIndex)
    return GetItemActorCategory(bagId, slotIndex) == GAMEPLAY_ACTOR_CATEGORY_COMPANION
end

--- @return boolean companionJunkEnabled
local function IsCompanionJunkEnabled()
    return BETTERUI.Settings.Modules["Inventory"].enableCompanionJunk == true
end

-- ============================================================================
-- PROTECTION CHECKS
-- ============================================================================

--[[
Function: Policy.CanDestroyItem
Description: Checks if an item can be destroyed.
             Requires: item exists, not player-locked, passes ZO destroy check.
Called by: InventoryBatchOps, ItemActionHandlers (indirectly via ZO)
]]
--- @param bagId number
--- @param slotIndex number
--- @param slotType? number Optional slot type for ZO validation
--- @return boolean canDestroy
function Policy.CanDestroyItem(bagId, slotIndex, slotType)
    if not bagId or not slotIndex or not HasItemAtSlot(bagId, slotIndex) then
        return false
    end
    if IsItemPlayerLocked(bagId, slotIndex) then
        return false
    end
    if ZO_InventorySlot_CanDestroyItem and slotType then
        local destroyProbe = {
            slotType = slotType,
            bagId = bagId,
            slotIndex = slotIndex,
        }
        return ZO_InventorySlot_CanDestroyItem(destroyProbe) == true
    end
    return true
end

--[[
Function: Policy.CanJunkItem
Description: Checks if an item can be marked as junk.
             Requires: item exists, can be junked by engine, not locked,
             not a craft bag item, and (if companion) companion junk enabled.
Called by: ItemActionHandlers.ToggleJunkState, ItemActionHandlers.OnSetup
]]
--- @param bagId number
--- @param slotIndex number
--- @return boolean canJunk
function Policy.CanJunkItem(bagId, slotIndex)
    if not bagId or not slotIndex then
        return false
    end
    if bagId == BAG_VIRTUAL then
        return false
    end
    if not CanItemBeMarkedAsJunk(bagId, slotIndex) then
        return false
    end
    if IsItemPlayerLocked(bagId, slotIndex) then
        return false
    end
    if IsCompanionItem(bagId, slotIndex) and not IsCompanionJunkEnabled() then
        return false
    end
    return true
end

--[[
Function: Policy.CanUnjunkItem
Description: Checks if an item can be unmarked as junk.
             Only restriction is craft bag items cannot be unjunked (they're never junk).
Called by: ItemActionHandlers.ToggleJunkState
]]
--- @param bagId number
--- @param slotIndex number
--- @return boolean canUnjunk
function Policy.CanUnjunkItem(bagId, slotIndex)
    if not bagId or not slotIndex then
        return false
    end
    -- Craft bag items cannot be junked/unjunked
    return bagId ~= BAG_VIRTUAL
end

--[[
Function: Policy.CanTransferItem
Description: Checks if an item can be transferred to a target bag.
             Validates stolen status, BOP restrictions, bound status,
             and guild bank specific restrictions.
Called by: MultiSelectActions.IsDepositSupportedForBank, TransferActions
]]
--- @param bagId number
--- @param slotIndex number
--- @param targetBag? number Optional target bag (e.g., BAG_GUILDBANK)
--- @return boolean canTransfer
function Policy.CanTransferItem(bagId, slotIndex, targetBag)
    if not bagId or not slotIndex or not HasItemAtSlot(bagId, slotIndex) then
        return false
    end
    
    -- Stolen items cannot be transferred to banks
    if IsItemStolen and IsItemStolen(bagId, slotIndex) then
        return false
    end
    
    -- Bind on Pickup (Backpack) items cannot be transferred
    if GetItemBindType then
        local bindType = GetItemBindType(bagId, slotIndex)
        if bindType == BIND_TYPE_ON_PICKUP_BACKPACK then
            return false
        end
    end
    
    -- Guild bank specific restrictions
    if targetBag == BAG_GUILDBANK then
        if IsItemBound and IsItemBound(bagId, slotIndex) then
            return false
        end
        if IsItemBoPAndTradeable and IsItemBoPAndTradeable(bagId, slotIndex) then
            return false
        end
        if IsItemPlayerLocked and IsItemPlayerLocked(bagId, slotIndex) then
            return false
        end
    end
    
    return true
end

--[[
Function: Policy.CanDepositToFurnitureVault
Description: Checks if an item can be deposited to the furniture vault.
             Gemmable crown items cannot be deposited.
Called by: InventoryBatchOps, MultiSelectActions
]]
--- @param bagId number
--- @param slotIndex number
--- @return boolean canDeposit
function Policy.CanDepositToFurnitureVault(bagId, slotIndex)
    if not bagId or not slotIndex then
        return false
    end
    if IsItemStolen and IsItemStolen(bagId, slotIndex) then
        return false
    end
    -- Crown gemmable items cannot go to furniture vault
    if CROWN_GEMIFICATION_MANAGER
        and CROWN_GEMIFICATION_MANAGER.IsItemGemmable
        and CROWN_GEMIFICATION_MANAGER.IsItemGemmable(tonumber(bagId), tonumber(slotIndex)) then
        return false
    end
    return true
end

--[[
Function: Policy.CanStowToCraftBag
Description: Checks if an item can be stowed to the craft bag.
             Requires: craft bag access, item is virtualizable, not stolen.
Called by: InventoryBatchOps.BatchStow
]]
--- @param bagId number
--- @param slotIndex number
--- @return boolean canStow
function Policy.CanStowToCraftBag(bagId, slotIndex)
    if not bagId or not slotIndex then
        return false
    end
    if not HasCraftBagAccess() then
        return false
    end
    if not CanItemBeVirtual(bagId, slotIndex) then
        return false
    end
    if IsItemStolen and IsItemStolen(bagId, slotIndex) then
        return false
    end
    return true
end

--[[
Function: Policy.IsItemPlayerLocked
Description: Wrapper for IsItemPlayerLocked with nil safety.
Called by: Any module needing lock status
]]
--- @param bagId number
--- @param slotIndex number
--- @return boolean isLocked
function Policy.IsItemPlayerLocked(bagId, slotIndex)
    if not bagId or not slotIndex then
        return false
    end
    return IsItemPlayerLocked(bagId, slotIndex) == true
end

--[[
Function: Policy.IsProtected
Description: Comprehensive protection check for UI action visibility.
             Returns true if the item has any protection that should prevent actions.
Called by: ItemActionHandlers for action filtering
]]
--- @param bagId number
--- @param slotIndex number
--- @return boolean isProtected
function Policy.IsProtected(bagId, slotIndex)
    if not bagId or not slotIndex then
        return true
    end
    if Policy.IsItemPlayerLocked(bagId, slotIndex) then
        return true
    end
    return false
end
