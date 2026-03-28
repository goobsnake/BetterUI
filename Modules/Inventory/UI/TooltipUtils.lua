--[[
File: Modules/Inventory/InventoryTooltipUtils.lua
Purpose: specialized tooltip logic for the Inventory module.
         Extracted from Inventory.lua to reduce file size.
]]

if BETTERUI == nil then BETTERUI = {} end
BETTERUI.Inventory = BETTERUI.Inventory or {}

-- Dependencies (ensure these globals are available)

--- Configures the visual style of native tooltips.
function BETTERUI.Inventory.ApplyTooltipStyles()
    local tooltipSize = BETTERUI.GetSetting("CIM", "tooltipSize", 24)

    -- Calculate derived sizes from base font size using centralized constants
    local baseFontSize = tooltipSize
    local fontOffsets = BETTERUI.CIM.CONST.TOOLTIP.FONT_OFFSETS
    local titleFontSize = baseFontSize + fontOffsets.TITLE -- Title is larger
    local valueFontSize = baseFontSize + fontOffsets.VALUE -- Value is larger

    -- Apply tooltip styles with size adjustments
    ZO_TOOLTIP_STYLES["topSection"] = {
        layoutPrimaryDirection = "up",
        layoutSecondaryDirection = "right",
        widthPercent = 100,
        childSpacing = 1,
        fontSize = baseFontSize,
        height = 64,
        uppercase = true,
        fontColorField = GENERAL_COLOR_OFF_WHITE,
    }
    ZO_TOOLTIP_STYLES["flavorText"] = {
        fontSize = baseFontSize,
    }
    ZO_TOOLTIP_STYLES["statValuePairStat"] = {
        fontSize = baseFontSize,
        uppercase = true,
        fontColorField = GENERAL_COLOR_OFF_WHITE,
    }
    ZO_TOOLTIP_STYLES["statValuePairValue"] = {
        fontSize = valueFontSize,
        fontColorField = GENERAL_COLOR_WHITE,
    }
    ZO_TOOLTIP_STYLES["title"] = {
        fontSize = titleFontSize,
        customSpacing = 8,
        widthPercent = 100,
        uppercase = true,
        fontColorField = GENERAL_COLOR_WHITE,
    }
    ZO_TOOLTIP_STYLES["bodyDescription"] = {
        fontSize = baseFontSize,
    }
end

--- Enables mouse wheel scrolling for the left-side tooltip container.
function BETTERUI.Inventory.EnableTooltipMouseWheel()
    local tip = ZO_GamepadTooltipTopLevelLeftTooltipContainerTip
    local tipScroll = ZO_GamepadTooltipTopLevelLeftTooltipContainerTipScroll
    if tip and tipScroll then
        tip:SetMouseEnabled(true)
        tipScroll:SetMouseEnabled(true)
        tip:SetHandler("OnMouseWheel", function(self, delta)
            local speed = BETTERUI.GetSetting("CIM", "rhScrollSpeed", 20)
            local newScrollValue
            if delta > 0 then
                newScrollValue = (self.scrollValue or 0) - speed
            else
                newScrollValue = (self.scrollValue or 0) + speed
            end
            self.scrollValue = newScrollValue
            if self.scroll and self.scroll.SetVerticalScroll then
                self.scroll:SetVerticalScroll(newScrollValue)
            end
        end)
    end
end

--- Hides the custom BetterUI tooltip status label and resets bottomRail anchors.
--- @param tooltipType string The type of tooltip (GAMEPAD_LEFT_TOOLTIP etc)
function BETTERUI.Inventory.CleanupEnhancedTooltip(tooltipType)
    local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(tooltipType)
    local container = GAMEPAD_TOOLTIPS:GetTooltipContainer(tooltipType)

    if container and container._betterUiStatus then
        container._betterUiStatus:SetHidden(true)
    end

    if container then
        local bottomRail = container.bottomRail or container:GetNamedChild("BottomRail")
        local scrollTooltip = container:GetNamedChild("Tip")
        if bottomRail then
            bottomRail:SetHidden(true)
        end
        if container._betterUiNativePriceLabel then
            container._betterUiNativePriceLabel:SetHidden(true)
            container._betterUiNativePriceLabel:SetText("")
        end
        if scrollTooltip then
            scrollTooltip:ClearAnchors()
            if bottomRail then
                scrollTooltip:SetAnchor(TOPLEFT, bottomRail, BOTTOMLEFT, 0, 0)
            else
                scrollTooltip:SetAnchor(TOPLEFT, container, TOPLEFT, 0, BETTERUI.CIM.CONST.TOOLTIP_SCROLL_OFFSET_Y)
            end
            scrollTooltip:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, 0, 0)
        end
    end

    if tooltip then
        tooltip:ClearAnchors()
        tooltip:SetAnchor(TOPLEFT, nil, TOPLEFT, 0, 0)
        -- Clear cached item data
        tooltip._betterui_itemLink = nil
        tooltip._betterui_bagId = nil
        tooltip._betterui_slotIndex = nil
        tooltip._betterui_storeStackCount = nil
        tooltip._betterui_priceRendered = nil
    end
    if GAMEPAD_TOOLTIPS and GAMEPAD_TOOLTIPS.ClearStatusLabel then
        GAMEPAD_TOOLTIPS:ClearStatusLabel(tooltipType)
    end
end

-- NOTE: BETTERUI.Inventory.UpdateTooltipEquippedText has been moved to
-- Modules/Inventory/UI/TooltipEquipped.lua for maintainability.

