--[[
File: Modules/Inventory/InventoryTooltipUtils.lua
Purpose: specialized tooltip logic for the Inventory module.
         Extracted from Inventory.lua to reduce file size.
]]

if BETTERUI == nil then BETTERUI = {} end
BETTERUI.Inventory = BETTERUI.Inventory or {}

-- Dependencies (ensure these globals are available)

--- Configures the visual style of native tooltips.
---@return nil
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
function BETTERUI.Inventory.CleanupEnhancedTooltip(tooltipType)
    local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(tooltipType)
    local container = GAMEPAD_TOOLTIPS:GetTooltipContainer(tooltipType)

    if container and container._betterUiStatus then
        container._betterUiStatus:SetHidden(true)
    end

    if container then
        if container._betterUiComparison then
            container._betterUiComparison:SetHidden(true)
            container._betterUiComparison:SetText("")
        end
        if container._betterUiComparisonDivider then
            container._betterUiComparisonDivider:SetHidden(true)
        end
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

--- Returns true if item stat comparison is enabled (requires both enhanced tooltips and the comparison toggle).
--- @return boolean
function BETTERUI.Inventory.IsItemComparisonEnabled()
    local enhancementsEnabled = BETTERUI.GetSetting("CIM", "enableTooltipEnhancements", true) ~= false
    if not enhancementsEnabled then return false end
    local comparisonEnabled = BETTERUI.GetSetting("GeneralInterface", "showItemComparison", true) ~= false
    return comparisonEnabled
end

--- Displays stat comparison with a divider on the given tooltip container.
--- Hides comparison controls if result is nil or empty.
--- The comparison section sits at the very bottom of the container with a divider
--- above it (mirroring the header divider at the top). The scroll tooltip body is
--- shortened so its content never overlaps past the divider.
--- @param container userdata Tooltip container control
--- @param result StatComparisonResult|nil Comparison result from StatComparison.Compare()
function BETTERUI.Inventory.ShowComparisonOnTooltip(container, result)
    if not container then return end

    local scrollTooltip = container:GetNamedChild("Tip")

    if result and result.lines and #result.lines > 0 then
        -- Create label if needed (created first so divider can anchor relative to it)
        if not container._betterUiComparison then
            local label = WINDOW_MANAGER:CreateControl(nil, container, CT_LABEL)
            label:SetMaxLineCount(0)
            label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
            label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
            container._betterUiComparison = label
        end

        -- Create 3-part divider matching GenericHeader.xml (left cap + center + right cap)
        if not container._betterUiComparisonDivider then
            local divHeight = BETTERUI_DIVIDER_HEIGHT or 8
            local tex = "EsoUI/Art/Windows/Gamepad/gp_nav1_horDivider.dds"

            local dividerContainer = WINDOW_MANAGER:CreateControl(nil, container, CT_CONTROL)
            dividerContainer:SetHeight(divHeight)
            dividerContainer:SetDrawLayer(DL_OVERLAY)
            dividerContainer:SetDrawTier(DT_LOW)
            dividerContainer:SetDrawLevel(1)

            local left = WINDOW_MANAGER:CreateControl(nil, dividerContainer, CT_TEXTURE)
            left:SetTexture(tex)
            left:SetDimensions(0, divHeight)
            left:SetTextureCoords(0, 0.29296875, 0, 1)
            left:SetDrawLayer(DL_OVERLAY)
            left:SetDrawTier(DT_LOW)
            left:SetDrawLevel(2)
            left:SetAnchor(TOPLEFT, dividerContainer, TOPLEFT, 0, 0)
            left:SetAnchor(BOTTOMLEFT, dividerContainer, BOTTOMLEFT, 0, 0)

            local right = WINDOW_MANAGER:CreateControl(nil, dividerContainer, CT_TEXTURE)
            right:SetTexture(tex)
            right:SetDimensions(0, divHeight)
            right:SetTextureCoords(0.70703125, 1, 0, 1)
            right:SetDrawLayer(DL_OVERLAY)
            right:SetDrawTier(DT_LOW)
            right:SetDrawLevel(2)
            right:SetAnchor(TOPRIGHT, dividerContainer, TOPRIGHT, 0, 0)
            right:SetAnchor(BOTTOMRIGHT, dividerContainer, BOTTOMRIGHT, 0, 0)

            local center = WINDOW_MANAGER:CreateControl(nil, dividerContainer, CT_TEXTURE)
            center:SetTexture(tex)
            center:SetTextureCoords(0.29296875, 0.70703125, 0, 1)
            center:SetDrawLayer(DL_OVERLAY)
            center:SetDrawTier(DT_LOW)
            center:SetDrawLevel(2)
            center:SetAnchor(TOPLEFT, left, TOPRIGHT, 0, 0)
            center:SetAnchor(BOTTOMRIGHT, right, BOTTOMLEFT, 0, 0)

            container._betterUiComparisonDivider = dividerContainer
        end

        local compLabel = container._betterUiComparison
        local compDivider = container._betterUiComparisonDivider
        local fontSize = BETTERUI.GetTooltipFontSize()
        local compFontSize = math.floor(fontSize * 0.75)
        compLabel:SetFont("$(MEDIUM_FONT)|" .. compFontSize .. "|shadow")
        compLabel:SetText(BETTERUI.Inventory.StatComparison.FormatForTooltip(result))

        -- Anchor label at the very bottom of the container (text grows upward)
        compLabel:ClearAnchors()
        compLabel:SetAnchor(BOTTOMLEFT, container, BOTTOMLEFT, 5, -5)
        compLabel:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, -5, -5)
        compLabel:SetHidden(false)

        -- Position divider directly above the comparison label
        compDivider:ClearAnchors()
        compDivider:SetAnchor(BOTTOMLEFT, compLabel, TOPLEFT, 0, -4)
        compDivider:SetAnchor(BOTTOMRIGHT, compLabel, TOPRIGHT, 0, -4)
        compDivider:SetHidden(false)

        -- Shrink scroll tooltip body so it stops above the divider
        if scrollTooltip then
            scrollTooltip:ClearAnchors()
            local bottomRail = container.bottomRail or container:GetNamedChild("BottomRail")
            if bottomRail and not bottomRail:IsHidden() then
                scrollTooltip:SetAnchor(TOPLEFT, bottomRail, BOTTOMLEFT, 0, 0)
            else
                scrollTooltip:SetAnchor(TOPLEFT, container, TOPLEFT, 0, BETTERUI.CIM.CONST.TOOLTIP_SCROLL_OFFSET_Y)
            end
            scrollTooltip:SetAnchor(BOTTOMRIGHT, compDivider, TOPRIGHT, 0, -4)
        end
    else
        if container._betterUiComparison then
            container._betterUiComparison:SetHidden(true)
        end
        if container._betterUiComparisonDivider then
            container._betterUiComparisonDivider:SetHidden(true)
        end
        -- Restore scroll tooltip to full height when no comparison is shown
        if scrollTooltip then
            scrollTooltip:ClearAnchors()
            local bottomRail = container.bottomRail or container:GetNamedChild("BottomRail")
            if bottomRail and not bottomRail:IsHidden() then
                scrollTooltip:SetAnchor(TOPLEFT, bottomRail, BOTTOMLEFT, 0, 0)
            else
                scrollTooltip:SetAnchor(TOPLEFT, container, TOPLEFT, 0, BETTERUI.CIM.CONST.TOOLTIP_SCROLL_OFFSET_Y)
            end
            scrollTooltip:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, 0, 0)
        end
    end
end

