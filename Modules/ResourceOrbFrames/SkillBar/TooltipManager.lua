--[[
File: Modules/ResourceOrbFrames/SkillBar/TooltipManager.lua
Purpose: Manages tooltip interactions for skill bar buttons.
]]

if not BETTERUI.ResourceOrbFrames.SkillBar then BETTERUI.ResourceOrbFrames.SkillBar = {} end
local SkillBar = BETTERUI.ResourceOrbFrames.SkillBar

local function TraceSkillTooltip(event, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.module = "ResourceOrbFrames"
    data.feature = "resourceOrbs"
    data.scene = SCENE_MANAGER and SCENE_MANAGER.GetCurrentSceneName and SCENE_MANAGER:GetCurrentSceneName() or nil
    data.gamepad = IsInGamepadPreferredMode and IsInGamepadPreferredMode() or nil
    if L.SetLastAction then
        L.SetLastAction({ flow = event, message = tostring(event) .. ":" .. tostring(phase) })
    end
    local categories = L.CATEGORY or {}
    L.TraceEvent(categories.ACTION, event, phase, data)
end

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
        TraceSkillTooltip("resource_orbs.tooltip", "slot_data_skipped", { reason = "missingControlOrSlot", slot = slotIndex, category = hotbarCategory })
        return false
    end

    local hotbar = ResolveHotbarForTooltip(hotbarCategory)
    if not hotbar or not hotbar.GetSlotData then
        TraceSkillTooltip("resource_orbs.tooltip", "slot_data_skipped", { reason = "missingHotbar", slot = slotIndex, category = hotbarCategory })
        return false
    end

    local slotData = hotbar:GetSlotData(slotIndex)
    if not slotData or not slotData.GetKeyboardTooltipControl then
        TraceSkillTooltip("resource_orbs.tooltip", "slot_data_skipped", { reason = "missingSlotData", slot = slotIndex, category = hotbarCategory })
        return false
    end

    local tooltipControl = slotData:GetKeyboardTooltipControl()
    if not tooltipControl then
        TraceSkillTooltip("resource_orbs.tooltip", "slot_data_skipped", { reason = "missingTooltipControl", slot = slotIndex, category = hotbarCategory })
        return false
    end

    InitializeTooltip(tooltipControl, control, point, offsetX, offsetY)
    if slotData.SetKeyboardTooltip then
        slotData:SetKeyboardTooltip(tooltipControl)
    end
    control.betterUIActiveTooltip = tooltipControl
    TraceSkillTooltip("resource_orbs.tooltip", "shown", { source = "slotData", slot = slotIndex, category = hotbarCategory })
    return true
end

local function InstallPostHookHandler(control, handlerName, hookFn, hookedField)
    if not control or control[hookedField] then return end

    local installed = false
    if type(ZO_PostHookHandler) == "function" then
        ZO_PostHookHandler(control, handlerName, hookFn)
        installed = true
    elseif type(control.SetHandler) == "function" then
        local previousHandler = control.GetHandler and control:GetHandler(handlerName) or nil
        control:SetHandler(handlerName, function(...)
            if type(previousHandler) == "function" then
                previousHandler(...)
            end
            hookFn(...)
        end)
        installed = true
    end

    if installed then
        control[hookedField] = true
    end
end

--- Sets up standard tooltip behavior for a button.
---@param control table Button control to attach tooltip handlers to
---@param slotIndex number Action bar slot index
---@param category number Hotbar category constant
---@param point number Anchor point constant
---@param offsetX number Tooltip X offset
---@param offsetY number Tooltip Y offset
local function SetupButtonTooltip(control, slotIndex, category, point, offsetX, offsetY)
    if not control then return end

    control:SetMouseEnabled(true)
    control._betteruiTooltipSlotIndex = slotIndex
    control._betteruiTooltipCategory = category
    control._betteruiTooltipPoint = point
    control._betteruiTooltipOffsetX = offsetX
    control._betteruiTooltipOffsetY = offsetY

    InstallPostHookHandler(control, "OnMouseEnter", function(c)
        ClearActiveTooltip(c)

        local cat = c.hotbarCategory or c._betteruiTooltipCategory or category
        local slot = c.slotIndex or c._betteruiTooltipSlotIndex or slotIndex
        local tooltipPoint = c._betteruiTooltipPoint or point
        local tooltipOffsetX = c._betteruiTooltipOffsetX or offsetX
        local tooltipOffsetY = c._betteruiTooltipOffsetY or offsetY
        TraceSkillTooltip("resource_orbs.tooltip", "enter", { slot = slot, category = cat })

        -- Highlight
        local highlight = c:GetNamedChild("MouseOverHighlight")
        if highlight then highlight:SetHidden(false) end

        if cat and slot then
            local slotType = GetSlotType(slot, cat)
            if slotType and slotType ~= ACTION_TYPE_NOTHING then
                -- Try to show Item Tooltip for Items and Collectibles (using link)
                if slotType == ACTION_TYPE_ITEM or slotType == ACTION_TYPE_COLLECTIBLE then
                    InitializeTooltip(ItemTooltip, c, tooltipPoint, tooltipOffsetX, tooltipOffsetY)
                    ItemTooltip:SetAction(slot, cat)
                    c.betterUIActiveTooltip = ItemTooltip
                    TraceSkillTooltip("resource_orbs.tooltip", "shown", { source = "item", slot = slot, category = cat, slotType = slotType })
                    return
                end

                -- Use native slot-data tooltip routing (SkillTooltip/AbilityTooltip), which includes
                -- progression rank XP bars for slotted skills.
                if TryShowSlotDataTooltip(c, slot, cat, tooltipPoint, tooltipOffsetX, tooltipOffsetY) then
                    return
                end

                InitializeTooltip(AbilityTooltip, c, tooltipPoint, tooltipOffsetX, tooltipOffsetY)
                AbilityTooltip:SetAction(slot, cat)
                c.betterUIActiveTooltip = AbilityTooltip
                TraceSkillTooltip("resource_orbs.tooltip", "shown", { source = "ability", slot = slot, category = cat, slotType = slotType })
            end
        end
    end, "_betteruiSkillTooltipEnterHooked")

    InstallPostHookHandler(control, "OnMouseExit", function(c)
        local highlight = c:GetNamedChild("MouseOverHighlight")
        if highlight then highlight:SetHidden(true) end
        ClearActiveTooltip(c)
        ClearTooltip(AbilityTooltip)
        ClearTooltip(ItemTooltip)
        if SkillTooltip then
            ClearTooltip(SkillTooltip)
        end
        TraceSkillTooltip("resource_orbs.tooltip", "exit", { slot = c.slotIndex or c._betteruiTooltipSlotIndex or slotIndex, category = c.hotbarCategory or c._betteruiTooltipCategory or category })
    end, "_betteruiSkillTooltipExitHooked")
end

-- MODULE EXPORTS
SkillBar.SetupButtonTooltip = SetupButtonTooltip
