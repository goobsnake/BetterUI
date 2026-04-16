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

--- @class StatComparisonResult
--- @field equipSlot number EQUIP_SLOT_* constant
--- @field equippedLink string|nil Currently equipped item link
--- @field deltas table Stat differences {armorRating, weaponDamage, level, quality}
--- @field lines string[] Color-coded display lines
--- @field isUpgrade boolean Whether the candidate is an upgrade
--- @field candidateEnchant string|nil Candidate enchantment description
--- @field equippedEnchant string|nil Equipped enchantment description
--- @field candidateSet string|nil Candidate set name
--- @field equippedSet string|nil Equipped set name

--- @class StatComparisonModule
--- @field Compare fun(candidateLink: string, candidateBagId: number, candidateSlotIndex: number, equipBagId?: number): StatComparisonResult|nil
--- @field FormatForTooltip fun(result: StatComparisonResult|nil): string
BETTERUI.Inventory.StatComparison = {}

local StatComparison = BETTERUI.Inventory.StatComparison

-- COLOR CONSTANTS

local COLOR_POSITIVE = "|c00FF00"  -- Green for upgrades
local COLOR_NEGATIVE = "|cFF3333"  -- Red for downgrades
local COLOR_NEUTRAL  = "|cCCCCCC"  -- Gray for no change
local COLOR_WHITE    = "|cFFFFFF"  -- White for labels
local COLOR_RESET    = "|r"

-- ARROW ICONS (inline textures — Unicode arrows are not in the gamepad font)
-- The :inheritcolor suffix makes the texture pick up the surrounding |cRRGGBB text color.
local ARROW_UP   = "|t16:16:EsoUI/Art/Buttons/Gamepad/gp_upArrow.dds:inheritcolor|t"
local ARROW_DOWN = "|t16:16:EsoUI/Art/Buttons/Gamepad/gp_downArrow.dds:inheritcolor|t"

-- HELPERS

--- Strip embedded ESO color codes from API-returned text so our colors take precedence.
local function StripColorCodes(text)
    if not text then return text end
    return text:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
end

--- Determines the equip slot for an item link.
--- Returns the primary equip slot, handling main-hand / off-hand / two-hand logic.
--- @param itemLink string
--- @return number|nil equipSlot EQUIP_SLOT_* constant or nil
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

--- Checks if the currently equipped main-hand item is a two-handed weapon.
--- @param equipBagId number Bag ID to check (BAG_WORN or BAG_COMPANION_WORN)
--- @return boolean isTwoHanded True if a two-handed weapon is equipped
local function IsEquippedMainHandTwoHanded(equipBagId)
    local mainHandLink = GetItemLink(equipBagId, EQUIP_SLOT_MAIN_HAND)
    if not mainHandLink or mainHandLink == "" then return false end
    local equipType = GetItemLinkEquipType(mainHandLink)
    return equipType == EQUIP_TYPE_TWO_HAND
end

--- Formats a stat delta with color coding.
--- Label is white, value is green (positive) or red (negative) with arrow.
--- @param delta number The stat difference
--- @param label string Display label for the stat
--- @param isHigherBetter boolean Whether a positive delta is an improvement
--- @return string coloredText Color-coded formatted text
local function FormatDelta(delta, label, isHigherBetter)
    if delta == 0 then
        return COLOR_WHITE .. label .. ": " .. COLOR_RESET .. COLOR_NEUTRAL .. "0" .. COLOR_RESET
    end

    local color, arrow
    if isHigherBetter then
        color = delta > 0 and COLOR_POSITIVE or COLOR_NEGATIVE
        arrow = delta > 0 and ARROW_UP or ARROW_DOWN
    else
        color = delta < 0 and COLOR_POSITIVE or COLOR_NEGATIVE
        arrow = delta < 0 and ARROW_UP or ARROW_DOWN
    end

    return COLOR_WHITE .. label .. ": " .. COLOR_RESET .. color .. tostring(math.abs(delta)) .. arrow .. COLOR_RESET
end

-- STAT EXTRACTION

--- Extracts key stats from an item link for comparison.
--- @param itemLink string
--- @return {armorRating: number, weaponDamage: number, weaponSpeed: number, level: number, quality: number}
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

-- ENCHANTMENT EXTRACTION

--- Extracts enchantment name (header) from an item link.
--- Uses the header (2nd return) rather than the full description (3rd return)
--- so the tooltip shows a concise glyph name instead of the effect text.
--- @param itemLink string
--- @return string|nil enchantName Short enchant name or nil
local function GetEnchantmentSummary(itemLink)
    if not itemLink or itemLink == "" then return nil end
    local hasEnchant, enchantHeader = GetItemLinkEnchantInfo(itemLink)
    if hasEnchant and enchantHeader and enchantHeader ~= "" then
        return StripColorCodes(enchantHeader)
    end
    return nil
end

-- SET BONUS EXTRACTION

--- Extracts set name from an item link.
--- @param itemLink string
--- @return string|nil setName Set name or nil
local function GetSetName(itemLink)
    if not itemLink or itemLink == "" then return nil end
    local hasSet, setName = GetItemLinkSetInfo(itemLink)
    if hasSet and setName and setName ~= "" then
        return StripColorCodes(setName)
    end
    return nil
end

-- MAIN COMPARISON

--- Compare a candidate item against the currently equipped item in the same slot.
--- @param candidateLink string Item link of the candidate item
--- @param candidateBagId number Bag ID of the candidate
--- @param candidateSlotIndex number Slot index of the candidate
--- @param equipBagId number|nil Bag to compare against (default: BAG_WORN; use BAG_COMPANION_WORN for companions)
--- @return StatComparisonResult|nil result Comparison result or nil if not applicable
function StatComparison.Compare(candidateLink, candidateBagId, candidateSlotIndex, equipBagId)
    equipBagId = equipBagId or BAG_WORN
    if not candidateLink or candidateLink == "" then return nil end

    -- 1. Determine the equip slot
    local equipSlot = GetEquipSlotForItem(candidateLink)
    if not equipSlot then return nil end

    -- 2. Get the currently equipped item
    local equippedLink = GetItemLink(equipBagId, equipSlot)
    if not equippedLink or equippedLink == "" then
        -- Nothing equipped in this slot — but check for 2H weapon blocking off-hand
        if equipSlot == EQUIP_SLOT_OFF_HAND and IsEquippedMainHandTwoHanded(equipBagId) then
            -- Player has a 2H weapon equipped; off-hand slot is not truly empty
            return nil
        end
        -- Genuinely empty slot
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
        local equippedUniqueId = GetItemUniqueId(equipBagId, equipSlot)
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
        local qualityName = StripColorCodes(GetString("SI_ITEMDISPLAYQUALITY", candidateStats.quality))
        local color = deltas.quality > 0 and COLOR_POSITIVE or COLOR_NEGATIVE
        local arrow = deltas.quality > 0 and ARROW_UP or ARROW_DOWN
        table.insert(lines, COLOR_WHITE .. "Quality: " .. COLOR_RESET .. color .. qualityName .. arrow .. COLOR_RESET)
    end

    -- Set bonus change
    local candidateSet = GetSetName(candidateLink)
    local equippedSet = GetSetName(equippedLink)
    if candidateSet ~= equippedSet then
        if candidateSet and equippedSet then
            table.insert(lines, COLOR_WHITE .. "Set: " .. COLOR_RESET .. COLOR_NEUTRAL .. equippedSet .. " → " .. candidateSet .. COLOR_RESET)
        elseif candidateSet then
            table.insert(lines, COLOR_WHITE .. "Set: " .. COLOR_RESET .. COLOR_POSITIVE .. candidateSet .. ARROW_UP .. COLOR_RESET)
        elseif equippedSet then
            table.insert(lines, COLOR_WHITE .. "Set: " .. COLOR_RESET .. COLOR_NEGATIVE .. equippedSet .. ARROW_DOWN .. COLOR_RESET)
        end
    end

    -- Enchantment change
    local candidateEnchant = GetEnchantmentSummary(candidateLink)
    local equippedEnchant = GetEnchantmentSummary(equippedLink)
    if candidateEnchant ~= equippedEnchant then
        if candidateEnchant and equippedEnchant then
            table.insert(lines, COLOR_WHITE .. "Enchant: " .. COLOR_RESET .. COLOR_NEUTRAL .. "changed" .. COLOR_RESET)
        elseif candidateEnchant then
            table.insert(lines, COLOR_WHITE .. "Enchant: " .. COLOR_RESET .. COLOR_POSITIVE .. candidateEnchant .. ARROW_UP .. COLOR_RESET)
        elseif equippedEnchant then
            table.insert(lines, COLOR_WHITE .. "Enchant: " .. COLOR_RESET .. COLOR_NEGATIVE .. equippedEnchant .. ARROW_DOWN .. COLOR_RESET)
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
--- @param result StatComparisonResult|nil Comparison result from Compare()
--- @return string formattedText Concatenated display lines
function StatComparison.FormatForTooltip(result)
    if not result or not result.lines then return "" end
    return table.concat(result.lines, "  ")
end
