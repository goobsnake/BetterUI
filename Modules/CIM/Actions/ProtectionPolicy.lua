--[[
File: Modules/CIM/Actions/ProtectionPolicy.lua
Purpose: Centralized item protection policy checks for inventory, banking, and batch operations.
         Encapsulates IsItemPlayerLocked, BOP, bound, stolen, and junk eligibility checks
         to eliminate duplication across consumer modules.
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
BETTERUI.CIM.ProtectionPolicy = {}

local Policy = BETTERUI.CIM.ProtectionPolicy

-- DENY REASON CODES
-- Returned as a second value from policy checks: allowed, reason = Policy.CanXxx(...)
-- Callers may ignore the reason (backward-compatible).

Policy.DENY = {
    NO_ITEM         = "no_item",
    PLAYER_LOCKED   = "player_locked",
    STOLEN          = "stolen",
    BOUND           = "bound",
    BOP_BACKPACK    = "bop_backpack",
    CRAFT_BAG       = "craft_bag",
    COMPANION       = "companion",
    NO_JUNK         = "no_junk",
    NO_CRAFT_ACCESS = "no_craft_access",
    NOT_CRAFTABLE   = "not_craftable",
    CROWN_GEMMABLE  = "crown_gemmable",
    GUILD_TRADEABLE = "guild_tradeable",
}

-- LOCAL HELPERS

local function HasItemAtSlot(bagId, slotIndex)
    local stackCount = GetSlotStackSize and GetSlotStackSize(bagId, slotIndex) or nil
    return (stackCount or 0) > 0
end

local function IsCompanionItem(bagId, slotIndex)
    return GetItemActorCategory(bagId, slotIndex) == GAMEPLAY_ACTOR_CATEGORY_COMPANION
end

local function IsCompanionJunkEnabled()
    return BETTERUI.GetSetting("Inventory", "enableCompanionJunk", false) == true
end

-- PROTECTION CHECKS

---@param bagId number Bag identifier
---@param slotIndex number Slot index within the bag
---@param slotType number|nil ESO slot type constant
---@return boolean allowed true if item can be destroyed
---@return string|nil reason DENY reason code on failure
function Policy.CanDestroyItem(bagId, slotIndex, slotType)
    if not bagId or not slotIndex or not HasItemAtSlot(bagId, slotIndex) then
        return false, Policy.DENY.NO_ITEM
    end
    if IsItemPlayerLocked(bagId, slotIndex) then
        return false, Policy.DENY.PLAYER_LOCKED
    end
    if ZO_InventorySlot_CanDestroyItem and slotType then
        local destroyProbe = {
            slotType = slotType,
            bagId = bagId,
            slotIndex = slotIndex,
        }
        if not ZO_InventorySlot_CanDestroyItem(destroyProbe) then
            return false, Policy.DENY.NO_ITEM
        end
    end
    return true
end

---@param bagId number
---@param slotIndex number
---@return boolean allowed
---@return string|nil reason
function Policy.CanJunkItem(bagId, slotIndex)
    if not bagId or not slotIndex then
        return false, Policy.DENY.NO_ITEM
    end
    if bagId == BAG_VIRTUAL then
        return false, Policy.DENY.CRAFT_BAG
    end
    if not CanItemBeMarkedAsJunk(bagId, slotIndex) then
        return false, Policy.DENY.NO_JUNK
    end
    if IsItemPlayerLocked(bagId, slotIndex) then
        return false, Policy.DENY.PLAYER_LOCKED
    end
    if IsCompanionItem(bagId, slotIndex) and not IsCompanionJunkEnabled() then
        return false, Policy.DENY.COMPANION
    end
    return true
end

---@param bagId number
---@param slotIndex number
---@return boolean allowed
---@return string|nil reason
function Policy.CanUnjunkItem(bagId, slotIndex)
    if not bagId or not slotIndex then
        return false, Policy.DENY.NO_ITEM
    end
    -- Craft bag items cannot be junked/unjunked
    if bagId == BAG_VIRTUAL then
        return false, Policy.DENY.CRAFT_BAG
    end
    return true
end

---@param bagId number
---@param slotIndex number
---@param targetBag number|nil Target bag for the transfer
---@return boolean allowed
---@return string|nil reason
function Policy.CanTransferItem(bagId, slotIndex, targetBag)
    if not bagId or not slotIndex or not HasItemAtSlot(bagId, slotIndex) then
        return false, Policy.DENY.NO_ITEM
    end

    -- Stolen items cannot be transferred to banks
    if IsItemStolen and IsItemStolen(bagId, slotIndex) then
        return false, Policy.DENY.STOLEN
    end

    -- Bind on Pickup (Backpack) items cannot be transferred
    if GetItemBindType then
        local bindType = GetItemBindType(bagId, slotIndex)
        if bindType == BIND_TYPE_ON_PICKUP_BACKPACK then
            return false, Policy.DENY.BOP_BACKPACK
        end
    end

    -- Guild bank specific restrictions
    if targetBag == BAG_GUILDBANK then
        if IsItemBound and IsItemBound(bagId, slotIndex) then
            return false, Policy.DENY.BOUND
        end
        if IsItemBoPAndTradeable and IsItemBoPAndTradeable(bagId, slotIndex) then
            return false, Policy.DENY.GUILD_TRADEABLE
        end
        if IsItemPlayerLocked and IsItemPlayerLocked(bagId, slotIndex) then
            return false, Policy.DENY.PLAYER_LOCKED
        end
    end

    return true
end

---@param bagId number
---@param slotIndex number
---@return boolean allowed
---@return string|nil reason
function Policy.CanDepositToFurnitureVault(bagId, slotIndex)
    if not bagId or not slotIndex then
        return false, Policy.DENY.NO_ITEM
    end
    if IsItemStolen and IsItemStolen(bagId, slotIndex) then
        return false, Policy.DENY.STOLEN
    end
    -- Crown gemmable items cannot go to furniture vault
    if CROWN_GEMIFICATION_MANAGER
        and CROWN_GEMIFICATION_MANAGER.IsItemGemmable
        and CROWN_GEMIFICATION_MANAGER.IsItemGemmable(tonumber(bagId), tonumber(slotIndex)) then
        return false, Policy.DENY.CROWN_GEMMABLE
    end
    return true
end

function Policy.CanStowToCraftBag(bagId, slotIndex)
    if not bagId or not slotIndex then
        return false, Policy.DENY.NO_ITEM
    end
    if not HasCraftBagAccess() then
        return false, Policy.DENY.NO_CRAFT_ACCESS
    end
    if not CanItemBeVirtual(bagId, slotIndex) then
        return false, Policy.DENY.NOT_CRAFTABLE
    end
    if IsItemStolen and IsItemStolen(bagId, slotIndex) then
        return false, Policy.DENY.STOLEN
    end
    return true
end

function Policy.IsItemPlayerLocked(bagId, slotIndex)
    if not bagId or not slotIndex then
        return false
    end
    return IsItemPlayerLocked(bagId, slotIndex) == true
end

function Policy.IsProtected(bagId, slotIndex)
    if not bagId or not slotIndex then
        return true, Policy.DENY.NO_ITEM
    end
    if Policy.IsItemPlayerLocked(bagId, slotIndex) then
        return true, Policy.DENY.PLAYER_LOCKED
    end
    return false
end
