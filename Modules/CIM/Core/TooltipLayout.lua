--[[
File: Modules/CIM/Core/TooltipLayout.lua
Purpose: Tooltip panel width and positioning utilities.
Author: BetterUI Team
Last Modified: 2026-01-26

Extracted from InterfaceLibrary.lua as part of Phase 3 refactoring.
]]

local _

BETTERUI.CIM = BETTERUI.CIM or {}

--[[
Function: BETTERUI.CIM.SetTooltipWidth
Description: Sets tooltip panel width and repositions the left tooltip.
Rationale: Adjusts the UI layout to accommodate wider or narrower lists dynamically.
Mechanism: Resizes GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT and anchors the tooltip relative to it.
param: width (number) - The new width of the background fragment.
References: Called during scene state changes (SceneStateChange) in WindowClass.
]]
function BETTERUI.CIM.SetTooltipWidth(width)
    -- Adjust background fragment and tooltip anchors for custom inventory width
    GAMEPAD_NAV_QUADRANT_1_BACKGROUND_FRAGMENT.control:SetWidth(width)
    GAMEPAD_TOOLTIPS.tooltips.GAMEPAD_LEFT_TOOLTIP.control:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, width + 66, 52)
    GAMEPAD_TOOLTIPS.tooltips.GAMEPAD_LEFT_TOOLTIP.control:SetAnchor(BOTTOMLEFT, GuiRoot, BOTTOMLEFT, width + 66, -125)
end
