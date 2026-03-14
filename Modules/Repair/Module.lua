--[[
File: Modules/Repair/Module.lua
Purpose: Unified repair + soul gem maintenance hub scaffold for BetterUI (MNT-001).
         Foundation for urgency surfacing and batch repair operations.
]]

BETTERUI.Repair = BETTERUI.Repair or {}

function BETTERUI.Repair.Setup()
    -- Placeholder: Will intercept repair/charge dialog flows
    BETTERUI.Repair.initialized = true
end

function BETTERUI.Repair.IsInitialized()
    return BETTERUI.Repair.initialized == true
end

--- Returns items needing repair, sorted by urgency (lowest condition first).
--- @return table repairItems Array of { bagId, slotIndex, condition, name }
function BETTERUI.Repair.GetRepairableItems()
    local items = {}
    local bagSize = GetBagSize(BAG_WORN) or 0

    for slotIndex = 0, bagSize - 1 do
        local condition = GetItemCondition(BAG_WORN, slotIndex)
        if condition and condition < 100 then
            local name = GetItemName(BAG_WORN, slotIndex) or ""
            if name ~= "" then
                table.insert(items, {
                    bagId = BAG_WORN,
                    slotIndex = slotIndex,
                    condition = condition,
                    name = name,
                })
            end
        end
    end

    table.sort(items, function(a, b) return a.condition < b.condition end)
    return items
end
