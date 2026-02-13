--[[
File: Modules/ResourceOrbFrames/SkillBar/TooltipManager.lua
Purpose: Manages tooltip interactions for skill bar buttons.
Author: BetterUI Team
Last Modified: 2026-01-29
]]

if not BETTERUI.ResourceOrbFrames.SkillBar then BETTERUI.ResourceOrbFrames.SkillBar = {} end
local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar

local function ClearActiveTooltip(control)
    if not control then
        return
    end

    local activeTooltip = control.betterUIActiveTooltip
    if activeTooltip then
        ClearTooltip(activeTooltip)
        control.betterUIActiveTooltip = nil
    end
end

local function ResolveHotbarForTooltip(hotbarCategory)
    if not ACTION_BAR_ASSIGNMENT_MANAGER then
        return nil
    end

    if hotbarCategory and hotbarCategory ~= HOTBAR_CATEGORY_QUICKSLOT_WHEEL and ACTION_BAR_ASSIGNMENT_MANAGER.GetHotbar then
        local hotbar = ACTION_BAR_ASSIGNMENT_MANAGER:GetHotbar(hotbarCategory)
        if hotbar then
            return hotbar
        end
    end

    if ACTION_BAR_ASSIGNMENT_MANAGER.GetCurrentHotbar then
        return ACTION_BAR_ASSIGNMENT_MANAGER:GetCurrentHotbar()
    end

    return nil
end

local function TryShowSlotDataTooltip(control, slotIndex, hotbarCategory, point, offsetX, offsetY)
    if not control or not slotIndex then
        return false
    end

    local hotbar = ResolveHotbarForTooltip(hotbarCategory)
    if not hotbar or not hotbar.GetSlotData then
        return false
    end

    local slotData = hotbar:GetSlotData(slotIndex)
    if not slotData or not slotData.GetKeyboardTooltipControl then
        return false
    end

    local tooltipControl = slotData:GetKeyboardTooltipControl()
    if not tooltipControl then
        return false
    end

    InitializeTooltip(tooltipControl, control, point, offsetX, offsetY)
    if slotData.SetKeyboardTooltip then
        slotData:SetKeyboardTooltip(tooltipControl)
    end
    control.betterUIActiveTooltip = tooltipControl
    return true
end

--- Sets up standard tooltip behavior for a button.
--- @param control table The UI control (button).
--- @param slotIndex number|nil The slot index (can be overridden by control.slotIndex).
--- @param category number|nil The hotbar category (can be overridden by control.hotbarCategory).
--- @param point number The anchor point (e.g. TOP, RIGHT, LEFT).
--- @param offsetX number X offset.
--- @param offsetY number Y offset.
local function SetupButtonTooltip(control, slotIndex, category, point, offsetX, offsetY)
    if not control then return end

    control:SetMouseEnabled(true)
    control:SetHandler("OnMouseEnter", function(c)
        ClearActiveTooltip(c)

        local cat = c.hotbarCategory or category
        local slot = c.slotIndex or slotIndex

        -- Highlight
        local highlight = c:GetNamedChild("MouseOverHighlight")
        if highlight then highlight:SetHidden(false) end

        if cat and slot then
            local slotType = GetSlotType(slot, cat)
            if slotType and slotType ~= ACTION_TYPE_NOTHING then
                -- Try to show Item Tooltip for Items and Collectibles (using link)
                if slotType == ACTION_TYPE_ITEM or slotType == ACTION_TYPE_COLLECTIBLE then
                    InitializeTooltip(ItemTooltip, c, point, offsetX, offsetY)
                    ItemTooltip:SetAction(slot, cat)
                    c.betterUIActiveTooltip = ItemTooltip
                    return
                end

                -- Use native slot-data tooltip routing (SkillTooltip/AbilityTooltip), which includes
                -- progression rank XP bars for slotted skills.
                if TryShowSlotDataTooltip(c, slot, cat, point, offsetX, offsetY) then
                    return
                end

                InitializeTooltip(AbilityTooltip, c, point, offsetX, offsetY)
                AbilityTooltip:SetAction(slot, cat)
                c.betterUIActiveTooltip = AbilityTooltip
            end
        end
    end)

    control:SetHandler("OnMouseExit", function(c)
        local highlight = c:GetNamedChild("MouseOverHighlight")
        if highlight then highlight:SetHidden(true) end
        ClearActiveTooltip(c)
        ClearTooltip(AbilityTooltip)
        ClearTooltip(ItemTooltip)
        if SkillTooltip then
            ClearTooltip(SkillTooltip)
        end
    end)
end

-------------------------------------------------------------------------------------------------
-- MODULE EXPORTS
-------------------------------------------------------------------------------------------------
SkillBar.SetupButtonTooltip = SetupButtonTooltip
