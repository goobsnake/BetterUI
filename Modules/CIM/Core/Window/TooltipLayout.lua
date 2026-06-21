--[[
File: Modules/CIM/Core/Window/TooltipLayout.lua
Purpose: Tooltip panel width and positioning utilities.


]]

BETTERUI.CIM = BETTERUI.CIM or {}

function BETTERUI.CIM.SetTooltipWidth(width)
    if BETTERUI.Log then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.SCENE, "set tooltip width", { width = width }) end
    -- Adjust background fragment and tooltip anchors for custom inventory width
    if not GAMEPAD_TOOLTIPS or not GAMEPAD_TOOLTIPS.tooltips or not GAMEPAD_TOOLTIPS.tooltips.GAMEPAD_LEFT_TOOLTIP or not GAMEPAD_TOOLTIPS.tooltips.GAMEPAD_LEFT_TOOLTIP.control then return end
    if not GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT or not GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT.control then return end
    local tooltipControl = GAMEPAD_TOOLTIPS.tooltips.GAMEPAD_LEFT_TOOLTIP.control
    GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT.control:SetWidth(width)
    tooltipControl:ClearAnchors()
    tooltipControl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, width + 66, 52 + BETTERUI.CIM.CONST.TOOLTIP_Y_OFFSET)
    tooltipControl:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, width + 66, -125)
end
