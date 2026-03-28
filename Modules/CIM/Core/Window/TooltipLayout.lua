--[[
File: Modules/CIM/Core/TooltipLayout.lua
Purpose: Tooltip panel width and positioning utilities.


]]

BETTERUI.CIM = BETTERUI.CIM or {}

function BETTERUI.CIM.SetTooltipWidth(width)
    -- Adjust background fragment and tooltip anchors for custom inventory width
    local tooltipControl = GAMEPAD_TOOLTIPS.tooltips.GAMEPAD_LEFT_TOOLTIP.control
    GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT.control:SetWidth(width)
    tooltipControl:ClearAnchors()
    tooltipControl:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, width + 66, 52 + BETTERUI.CIM.CONST.TOOLTIP_Y_OFFSET)
    tooltipControl:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, width + 66, -125)
end
