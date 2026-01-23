--[[
File: Modules/ResourceOrbFrames/SkillBar/TooltipManager.lua
Purpose: Manages tooltip interactions for skill bar buttons.
Author: BetterUI Team
Last Modified: 2026-01-23
]]

if not BETTERUI.ResourceOrbFrames.SkillBar then BETTERUI.ResourceOrbFrames.SkillBar = {} end
local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar

--- Sets up standard tooltip behavior for a button.
--- @param control table The UI control (button).
--- @param slotIndex number|nil The slot index (can be overridden by control.slotIndex).
--- @param category number|nil The hotbar category (can be overridden by control.hotbarCategory).
--- @param point number The anchor point (e.g. TOP, RIGHT, LEFT).
--- @param offsetX number X offset.
--- @param offsetY number Y offset.
function SkillBar.SetupButtonTooltip(control, slotIndex, category, point, offsetX, offsetY)
    if not control then return end
    
    control:SetMouseEnabled(true)
    control:SetHandler("OnMouseEnter", function(c)
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
                     local link = GetSlotItemLink(slot, cat)
                     if link and link ~= "" then
                          InitializeTooltip(ItemTooltip, c, point, offsetX, offsetY)
                          ItemTooltip:SetLink(link)
                          return
                     end
                end
                
                InitializeTooltip(AbilityTooltip, c, point, offsetX, offsetY)
                AbilityTooltip:SetAction(slot, cat)
            end
        end
    end)
    
    control:SetHandler("OnMouseExit", function(c)
        local highlight = c:GetNamedChild("MouseOverHighlight")
        if highlight then highlight:SetHidden(true) end
        ClearTooltip(AbilityTooltip)
        ClearTooltip(ItemTooltip)
    end)
end
