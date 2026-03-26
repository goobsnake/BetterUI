--[[
File: Modules/Vendor/Components/RepairComponent.lua
Purpose: Repair tab component for the Vendor module.
Authors: BUI Team
Last Modified: 2026-03-14

Handles listing damaged items and repairing them (individual or repair all).
Uses GetItemCondition to find damaged items, RepairItem for individual repair,
and GetRepairAllCost/RepairAll for batch repair.
]]

local Vendor = BETTERUI.Vendor

-- ============================================================================
-- COMPONENT TABLE
-- ============================================================================
Vendor.RepairComponent = {}
local Repair = Vendor.RepairComponent

-- ============================================================================
-- ACTIVATE / DEACTIVATE
-- ============================================================================

--- @param vendorInstance any Description
--- @return any Description
function Repair:Activate(vendorInstance)
    vendorInstance:RefreshList()
end

--- @param vendorInstance any Description
--- @return any Description
function Repair:Deactivate(vendorInstance)
    -- No cleanup needed
end

-- ============================================================================
-- PRIMARY ACTION
-- ============================================================================

--- @return any Description
function Repair:GetPrimaryActionName()
    return GetString(SI_ITEM_ACTION_REPAIR)
end

--- @param vendorInstance any Description
--- @return any Description
function Repair:IsPrimaryActionEnabled(vendorInstance)
    local selectedData = vendorInstance.list and vendorInstance.list:GetSelectedData()
    if not selectedData then return false end

    local repairCost = selectedData.repairCost or 0
    return repairCost > 0 and vendorInstance:CanAfford(repairCost)
end

--- @param vendorInstance any Description
--- @return any Description
function Repair:OnPrimaryAction(vendorInstance)
    local selectedData = vendorInstance.list and vendorInstance.list:GetSelectedData()
    if not selectedData then return end

    local bagId = selectedData.bagId
    local slotIndex = selectedData.slotIndex
    if bagId == nil or slotIndex == nil then return end

    local repairCost = selectedData.repairCost or 0
    if repairCost <= 0 then return end

    if not vendorInstance:CanAfford(repairCost) then
        ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil,
            GetString(SI_BETTERUI_VENDOR_CANNOT_AFFORD))
        return
    end

    RepairItem(bagId, slotIndex)
end

-- ============================================================================
-- REPAIR ALL
-- ============================================================================

--- @param vendorInstance any Description
--- @return any Description
function Repair:RepairAll(vendorInstance)
    local repairAllCost = GetRepairAllCost and GetRepairAllCost() or 0
    if repairAllCost <= 0 then return end

    if not vendorInstance:CanAfford(repairAllCost) then
        ZO_AlertNoSuppression(UI_ALERT_CATEGORY_ALERT, nil,
            GetString(SI_BETTERUI_VENDOR_CANNOT_AFFORD))
        return
    end

    -- Format cost for display
    local _ = ZO_CurrencyControl_FormatCurrencyAndAppendIcon(repairAllCost, true, CURT_MONEY, true)

    -- ESO's own store uses "REPAIR_ALL" dialog (storewindow_gamepad.lua:309)
    ZO_Dialogs_ShowGamepadDialog("REPAIR_ALL", {
        callback = function()
            RepairAll()
        end,
    })
end

-- ============================================================================
-- LIST BUILDING
-- ============================================================================

--- @param vendorInstance any Description
--- @return any Description
function Repair:BuildList(vendorInstance)
    local list = vendorInstance.list
    if not list then return end

    -- Scan equipped and backpack items for damage
    local bags = { BAG_WORN, BAG_BACKPACK }

    for _, bagId in ipairs(bags) do
        local bagSize = GetBagSize(bagId) or 0
        for slotIndex = 0, bagSize - 1 do
            local condition = GetItemCondition(bagId, slotIndex) or 100
            if condition < 100 then
                local icon, stackCount, _, _, _, _, _, quality = GetItemInfo(bagId, slotIndex)
                local name = GetItemName(bagId, slotIndex)

                if name and name ~= "" then
                    name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
                    local repairCost = GetItemRepairCost(bagId, slotIndex) or 0

                    local entryData = {
                        name             = name,
                        icon             = icon,
                        stackCount       = stackCount or 1,
                        condition        = condition,
                        repairCost       = repairCost,
                        quality          = quality or ITEM_DISPLAY_QUALITY_NORMAL,
                        bagId            = bagId,
                        slotIndex        = slotIndex,
                        itemLink         = GetItemLink(bagId, slotIndex),
                        bestGamepadItemCategoryName = "",
                        statValue        = zo_strformat(SI_BETTERUI_VENDOR_CONDITION, condition),
                    }

                    local entry = ZO_GamepadEntryData:New(entryData.name, entryData.icon)
                    entry:SetDataSource(entryData)
                    entry.narrationText = function() return entryData.name end

                    if quality then
                        local r, g, b = GetItemQualityColor(quality):UnpackRGBA()
                        entry:SetNameColors(ZO_ColorDef:New(r, g, b, 1), ZO_ColorDef:New(r, g, b, 0.7))
                    end

                    list:AddEntry("BUI_Gamepad_ItemEntry", entry)
                end
            end
        end
    end
end
