--[[
File: Modules/Inventory/Core/StatComparison.lua
Purpose: Item stat comparison engine for Inventory, Banking, and Companion surfaces.
         Calculates armor/weapon stat differences between a candidate item and the
         currently equipped item in the same slot.

INV-001: Stat comparison parity across all item surfaces.

USAGE:
    local comparison = BETTERUI.Inventory.StatComparison.Compare(candidateLink, candidateBagId, candidateSlotIndex)
    -- Returns a table with stat deltas and formatted display strings.
    -- Returns nil if comparison is not applicable (non-equippable items, etc.)
]]

BETTERUI.Inventory = BETTERUI.Inventory or {}
BETTERUI.Inventory.StatComparison = {}

local StatComparison = BETTERUI.Inventory.StatComparison

-------------------------------------------------------------------------------------------------
-- COLOR CONSTANTS
-------------------------------------------------------------------------------------------------

local COLOR_POSITIVE = "|c00FF00"  -- Green for upgrades
local COLOR_NEGATIVE = "|cFF3333"  -- Red for downgrades
local COLOR_NEUTRAL  = "|cCCCCCC"  -- Gray for no change
local COLOR_RESET    = "|r"

-------------------------------------------------------------------------------------------------
-- HELPERS
-------------------------------------------------------------------------------------------------

--- Determines the equip slot for an item link.
--- Returns the primary equip slot, handling main-hand / off-hand / two-hand logic.
--- @param itemLink string
--- @return number|nil equipSlot
local function GetEquipSlotForItem(itemLink)
    if not itemLink or itemLink == "" then return nil end

    local equipType = GetItemLinkEquipType(itemLink)
    if not equipType or equipType == EQUIP_TYPE_INVALID then return nil end

    -- Map equip types to slots
    if equipType == EQUIP_TYPE_HEAD then return EQUIP_SLOT_HEAD end
    if equipType == EQUIP_TYPE_CHEST then return EQUIP_SLOT_CHEST end
    if equipType == EQUIP_TYPE_SHOULDERS then return EQUIP_SLOT_SHOULDERS end
    if equipType == EQUIP_TYPE_WAIST then return EQUIP_SLOT_WAIST end
    if equipType == EQUIP_TYPE_LEGS then return EQUIP_SLOT_LEGS end
    if equipType == EQUIP_TYPE_FEET then return EQUIP_SLOT_FEET end
    if equipType == EQUIP_TYPE_HAND then return EQUIP_SLOT_HAND end
    if equipType == EQUIP_TYPE_NECK then return EQUIP_SLOT_NECK end
    if equipType == EQUIP_TYPE_RING then return EQUIP_SLOT_RING1 end
    if equipType == EQUIP_TYPE_MAIN_HAND or equipType == EQUIP_TYPE_TWO_HAND then
        return EQUIP_SLOT_MAIN_HAND
    end
    if equipType == EQUIP_TYPE_OFF_HAND or equipType == EQUIP_TYPE_ONE_HAND then
        return EQUIP_SLOT_OFF_HAND
    end

    return nil
end

--- Formats a stat delta with color coding.
--- @param delta number The difference (positive = upgrade)
--- @param label string Display label (e.g., "Armor")
--- @param isHigherBetter boolean If true, positive = green. If false, positive = red.
--- @return string formatted Colored formatted string
local function FormatDelta(delta, label, isHigherBetter)
    if delta == 0 then
        return COLOR_NEUTRAL .. label .. ": " .. "0" .. COLOR_RESET
    end

    local sign = delta > 0 and "+" or ""
    local color
    if isHigherBetter then
        color = delta > 0 and COLOR_POSITIVE or COLOR_NEGATIVE
    else
        color = delta < 0 and COLOR_POSITIVE or COLOR_NEGATIVE
    end

    return color .. label .. ": " .. sign .. tostring(delta) .. COLOR_RESET
end

-------------------------------------------------------------------------------------------------
-- STAT EXTRACTION
-------------------------------------------------------------------------------------------------

--- Extracts key stats from an item link for comparison.
--- @param itemLink string
--- @return table stats { armorRating, weaponDamage, weaponSpeed, level, quality }
local function ExtractStats(itemLink)
    if not itemLink or itemLink == "" then
        return { armorRating = 0, weaponDamage = 0, weaponSpeed = 0, level = 0, quality = 0 }
    end

    local armorRating = GetItemLinkArmorRating(itemLink, false) or 0
    local weaponDamage = 0
    local weaponSpeed = 0

    local weaponType = GetItemLinkWeaponType(itemLink)
    if weaponType and weaponType ~= WEAPONTYPE_NONE then
        local minDmg = GetItemLinkWeaponPower(itemLink) or 0
        weaponDamage = minDmg
    end

    local quality = GetItemLinkDisplayQuality(itemLink) or 0
    local level = GetItemLinkRequiredLevel(itemLink) or 0

    return {
        armorRating = armorRating,
        weaponDamage = weaponDamage,
        weaponSpeed = weaponSpeed,
        level = level,
        quality = quality,
    }
end

-------------------------------------------------------------------------------------------------
-- ENCHANTMENT EXTRACTION
-------------------------------------------------------------------------------------------------

--- Extracts enchantment summary from an item link.
--- @param itemLink string
--- @return string|nil enchantmentDesc A brief description of the enchantment
local function GetEnchantmentSummary(itemLink)
    if not itemLink or itemLink == "" then return nil end
    local hasEnchant, enchantHeader, enchantDesc = GetItemLinkEnchantInfo(itemLink)
    if hasEnchant and enchantDesc and enchantDesc ~= "" then
        return enchantDesc
    end
    return nil
end

-------------------------------------------------------------------------------------------------
-- SET BONUS EXTRACTION
-------------------------------------------------------------------------------------------------

--- Extracts set name from an item link.
--- @param itemLink string
--- @return string|nil setName
local function GetSetName(itemLink)
    if not itemLink or itemLink == "" then return nil end
    local hasSet, setName = GetItemLinkSetInfo(itemLink)
    if hasSet and setName and setName ~= "" then
        return setName
    end
    return nil
end

-------------------------------------------------------------------------------------------------
-- MAIN COMPARISON
-------------------------------------------------------------------------------------------------

--- Compare a candidate item against the currently equipped item in the same slot.
--- @param candidateLink string Item link of the candidate
--- @param candidateBagId number Bag ID of the candidate
--- @param candidateSlotIndex number Slot index in the bag
--- @return table|nil result Comparison result with fields:
---   - equipSlot: number
---   - equippedLink: string
---   - deltas: table { armorRating, weaponDamage, level, quality }
---   - lines: string[] Formatted comparison lines for display
---   - isUpgrade: boolean Overall upgrade assessment
--- Compare a candidate item against the currently equipped item in the same slot.
--- @param candidateLink string Item link of the candidate
--- @param candidateBagId number Bag ID of the candidate
--- @param candidateSlotIndex number Slot index in the bag
--- @return table|nil result Comparison result with deltas and display lines
function StatComparison.Compare(candidateLink, candidateBagId, candidateSlotIndex)
    if not candidateLink or candidateLink == "" then return nil end

    -- 1. Determine the equip slot
    local equipSlot = GetEquipSlotForItem(candidateLink)
    if not equipSlot then return nil end

    -- 2. Get the currently equipped item
    local equippedLink = GetItemLink(BAG_WORN, equipSlot)
    if not equippedLink or equippedLink == "" then
        -- Nothing equipped in this slot — show as pure upgrade
        local candidateStats = ExtractStats(candidateLink)
        return {
            equipSlot = equipSlot,
            equippedLink = nil,
            deltas = candidateStats,
            lines = { COLOR_POSITIVE .. "Empty slot — equip to gain stats" .. COLOR_RESET },
            isUpgrade = true,
            candidateEnchant = GetEnchantmentSummary(candidateLink),
            candidateSet = GetSetName(candidateLink),
        }
    end

    -- 3. Skip if comparing same item
    if GetItemLinkItemId(candidateLink) == GetItemLinkItemId(equippedLink) then
        -- Same base item — check if same specific instance
        local candidateUniqueId = candidateBagId and candidateSlotIndex and
            GetItemUniqueId(candidateBagId, candidateSlotIndex)
        local equippedUniqueId = GetItemUniqueId(BAG_WORN, equipSlot)
        if candidateUniqueId and equippedUniqueId and
            Id64ToString(candidateUniqueId) == Id64ToString(equippedUniqueId) then
            return nil -- Same exact item
        end
    end

    -- 4. Extract stats
    local candidateStats = ExtractStats(candidateLink)
    local equippedStats = ExtractStats(equippedLink)

    -- 5. Calculate deltas
    local deltas = {
        armorRating = candidateStats.armorRating - equippedStats.armorRating,
        weaponDamage = candidateStats.weaponDamage - equippedStats.weaponDamage,
        level = candidateStats.level - equippedStats.level,
        quality = candidateStats.quality - equippedStats.quality,
    }

    -- 6. Build display lines
    local lines = {}

    -- Armor rating (for armor pieces)
    if candidateStats.armorRating > 0 or equippedStats.armorRating > 0 then
        if deltas.armorRating ~= 0 then
            table.insert(lines, FormatDelta(deltas.armorRating, "Armor", true))
        end
    end

    -- Weapon damage (for weapons)
    if candidateStats.weaponDamage > 0 or equippedStats.weaponDamage > 0 then
        if deltas.weaponDamage ~= 0 then
            table.insert(lines, FormatDelta(deltas.weaponDamage, "Damage", true))
        end
    end

    -- Level difference
    if deltas.level ~= 0 then
        table.insert(lines, FormatDelta(deltas.level, "Level", true))
    end

    -- Quality change
    if deltas.quality ~= 0 then
        local qualityName = GetString("SI_ITEMDISPLAYQUALITY", candidateStats.quality)
        local sign = deltas.quality > 0 and COLOR_POSITIVE or COLOR_NEGATIVE
        table.insert(lines, sign .. "Quality: " .. qualityName .. COLOR_RESET)
    end

    -- Set bonus change
    local candidateSet = GetSetName(candidateLink)
    local equippedSet = GetSetName(equippedLink)
    if candidateSet ~= equippedSet then
        if candidateSet and equippedSet then
            table.insert(lines, COLOR_NEUTRAL .. "Set: " .. equippedSet .. " → " .. candidateSet .. COLOR_RESET)
        elseif candidateSet then
            table.insert(lines, COLOR_POSITIVE .. "Set: +" .. candidateSet .. COLOR_RESET)
        elseif equippedSet then
            table.insert(lines, COLOR_NEGATIVE .. "Set: -" .. equippedSet .. COLOR_RESET)
        end
    end

    -- Enchantment change
    local candidateEnchant = GetEnchantmentSummary(candidateLink)
    local equippedEnchant = GetEnchantmentSummary(equippedLink)
    if candidateEnchant ~= equippedEnchant then
        if candidateEnchant and equippedEnchant then
            table.insert(lines, COLOR_NEUTRAL .. "Enchant changed" .. COLOR_RESET)
        elseif candidateEnchant then
            table.insert(lines, COLOR_POSITIVE .. "Enchant: +" .. COLOR_RESET)
        elseif equippedEnchant then
            table.insert(lines, COLOR_NEGATIVE .. "Enchant: -" .. COLOR_RESET)
        end
    end

    -- 7. Determine overall upgrade status
    local isUpgrade = (deltas.armorRating > 0) or (deltas.weaponDamage > 0) or
        (deltas.quality > 0) or (deltas.level > 0)

    if #lines == 0 then
        table.insert(lines, COLOR_NEUTRAL .. "No stat change" .. COLOR_RESET)
    end

    return {
        equipSlot = equipSlot,
        equippedLink = equippedLink,
        deltas = deltas,
        lines = lines,
        isUpgrade = isUpgrade,
        candidateEnchant = candidateEnchant,
        equippedEnchant = equippedEnchant,
        candidateSet = candidateSet,
        equippedSet = equippedSet,
    }
end

--- Format the comparison result as a single string for tooltip display.
--- @param result table The result from Compare()
--- @return string text Formatted comparison text
--- Format the comparison result as a single string for tooltip display.
--- @param result table The result from Compare()
--- @return string text Formatted comparison text
function StatComparison.FormatForTooltip(result)
    if not result or not result.lines then return "" end
    return table.concat(result.lines, "  ")
end
