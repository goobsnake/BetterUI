--[[
File: Modules/Inventory/UI/TooltipUtils.lua
Purpose: specialized tooltip logic for the Inventory module.
         Extracted from Inventory.lua to reduce file size.
]]

if BETTERUI == nil then BETTERUI = {} end
BETTERUI.Inventory = BETTERUI.Inventory or {}

-- Dependencies (ensure these globals are available)

-- ZO_TOOLTIP_STYLES keys overridden by ApplyTooltipStyles; stock entries are
-- captured before the first override so RestoreTooltipStyles can undo them
-- in-session (toggling enhancements off must not require a relog).
local OVERRIDDEN_STYLE_KEYS = {
    "topSection",
    "flavorText",
    "statValuePairStat",
    "statValuePairValue",
    "title",
    "bodyDescription",
}
local stockTooltipStyles = nil
local tooltipMouseWheelState = {
    tip = nil,
    tipScroll = nil,
    tipMouseEnabled = nil,
    tipScrollMouseEnabled = nil,
}

local function SnapshotStockTooltipStyles()
    if stockTooltipStyles or ZO_TOOLTIP_STYLES == nil then
        return
    end
    stockTooltipStyles = {}
    for _, key in ipairs(OVERRIDDEN_STYLE_KEYS) do
        stockTooltipStyles[key] = ZO_TOOLTIP_STYLES[key]
    end
end

--- Restores the stock gamepad tooltip styles captured before enhancements were applied.
---@return nil
function BETTERUI.Inventory.RestoreTooltipStyles()
    if not stockTooltipStyles or ZO_TOOLTIP_STYLES == nil then
        return
    end
    for _, key in ipairs(OVERRIDDEN_STYLE_KEYS) do
        ZO_TOOLTIP_STYLES[key] = stockTooltipStyles[key]
    end
end

--- Configures the visual style of native tooltips.
---@return nil
function BETTERUI.Inventory.ApplyTooltipStyles()
    SnapshotStockTooltipStyles()
    local tooltipSize = BETTERUI.GetSetting("CIM", "tooltipSize", 24)

    -- Calculate derived sizes from base font size using centralized constants
    local baseFontSize = tooltipSize
    local fontOffsets = BETTERUI.CIM.CONST.TOOLTIP.FONT_OFFSETS
    local titleFontSize = baseFontSize + fontOffsets.TITLE -- Title is larger
    local valueFontSize = baseFontSize + fontOffsets.VALUE -- Value is larger

    -- Apply tooltip styles with size adjustments.
    -- No fixed height: stock topSection auto-sizes, and a hard height clips
    -- extra top lines (e.g. the set-collection Collected/Not Collected tag).
    ZO_TOOLTIP_STYLES["topSection"] = {
        layoutPrimaryDirection = "up",
        layoutSecondaryDirection = "right",
        widthPercent = 100,
        childSpacing = 1,
        fontSize = baseFontSize,
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

local function CaptureMouseEnabled(control)
    if control and type(control.IsMouseEnabled) == "function" then
        return control:IsMouseEnabled() == true
    end
    return nil
end

--- Enables mouse wheel scrolling for the left-side tooltip container.
function BETTERUI.Inventory.EnableTooltipMouseWheel()
    local tip = ZO_GamepadTooltipTopLevelLeftTooltipContainerTip
    local tipScroll = ZO_GamepadTooltipTopLevelLeftTooltipContainerTipScroll
    if tip and tipScroll then
        if tooltipMouseWheelState.tip ~= tip or tooltipMouseWheelState.tipScroll ~= tipScroll then
            tooltipMouseWheelState.tip = tip
            tooltipMouseWheelState.tipScroll = tipScroll
            tooltipMouseWheelState.tipMouseEnabled = CaptureMouseEnabled(tip)
            tooltipMouseWheelState.tipScrollMouseEnabled = CaptureMouseEnabled(tipScroll)
        end

        tip:SetMouseEnabled(true)
        tipScroll:SetMouseEnabled(true)
        if not tip._betteruiMouseWheelHooked then
            local function OnTooltipMouseWheel(self, delta)
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
            end

            if type(ZO_PostHookHandler) == "function" then
                ZO_PostHookHandler(tip, "OnMouseWheel", OnTooltipMouseWheel)
                tip._betteruiMouseWheelHandlerMode = "posthook"
            else
                local previousHandler = tip.GetHandler and tip:GetHandler("OnMouseWheel") or nil
                tip._betteruiPreviousMouseWheelHandler = previousHandler
                tip:SetHandler("OnMouseWheel", function(self, delta)
                    if type(previousHandler) == "function" then
                        previousHandler(self, delta)
                    end
                    OnTooltipMouseWheel(self, delta)
                end)
                tip._betteruiMouseWheelHandlerMode = "sethandler"
            end
            tip._betteruiMouseWheelHooked = true
        end
    end
end

--- Restores the native left-side tooltip mouse state captured before BetterUI enabled wheel scrolling.
--- When the client exposes only ZO_PostHookHandler the scroll callback itself stays installed, but
--- restoring the original mouse-enabled flags suppresses wheel delivery on stock tooltip controls.
---@return nil
function BETTERUI.Inventory.RestoreTooltipMouseWheel()
    local tip = tooltipMouseWheelState.tip
    local tipScroll = tooltipMouseWheelState.tipScroll
    if tip and tip.SetMouseEnabled and tooltipMouseWheelState.tipMouseEnabled ~= nil then
        tip:SetMouseEnabled(tooltipMouseWheelState.tipMouseEnabled)
    end
    if tipScroll and tipScroll.SetMouseEnabled and tooltipMouseWheelState.tipScrollMouseEnabled ~= nil then
        tipScroll:SetMouseEnabled(tooltipMouseWheelState.tipScrollMouseEnabled)
    end

    if tip and tip._betteruiMouseWheelHooked and tip._betteruiMouseWheelHandlerMode == "sethandler" and tip.SetHandler then
        tip:SetHandler("OnMouseWheel", tip._betteruiPreviousMouseWheelHandler)
        tip._betteruiMouseWheelHooked = false
        tip._betteruiMouseWheelHandlerMode = nil
    end
end

-- Stock gamepad tooltip body font. The enhancement overrides each child label
-- with "$(MEDIUM_FONT)|<size>|soft-shadow-thick" via ApplyTooltipLabelFonts; on
-- cleanup we re-apply this constant stock font so toggling enhancements off
-- restores stock fonts in-session and repeated on/off never accumulates drift.
local STOCK_TOOLTIP_BODY_FONT = "ZoFontGamepad34"

--- Re-applies the stock gamepad body font to every label child of a tooltip
--- control, reversing the per-label SetFont done by ApplyTooltipLabelFonts.
--- Idempotent: re-running converges on the same stock font.
---@param tooltipControl table|nil
---@return nil
local function RestoreStockLabelFonts(tooltipControl)
    if not tooltipControl or not tooltipControl.GetNumChildren then
        return
    end
    for i = 1, tooltipControl:GetNumChildren() do
        local child = tooltipControl:GetChild(i)
        if child and child.GetType and child:GetType() == CT_LABEL and child.SetFont then
            child:SetFont(STOCK_TOOLTIP_BODY_FONT)
        end
    end
end

--- Reverses ALL enhanced-tooltip control-instance mutations so toggling
--- enhancements off restores stock layout/fonts in-session (PB-003).
--- Total + idempotent: hides and clears the custom status label, fully resets
--- the native body/bottomRail/scroll anchors to stock (mirroring the stock
--- else-branch in TooltipEquipped.UpdateTooltipEquippedText), and re-applies the
--- stock body font to the tooltip child labels. Repeated on/off never drifts.
function BETTERUI.Inventory.CleanupEnhancedTooltip(tooltipType)
    local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(tooltipType)
    local container = GAMEPAD_TOOLTIPS:GetTooltipContainer(tooltipType)

    BETTERUI.Inventory.RestoreTooltipMouseWheel()

    if container and container._betterUiStatus then
        container._betterUiStatus:SetHidden(true)
        container._betterUiStatus:SetText("")
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
        if container._betterUiNativePriceLabel then
            container._betterUiNativePriceLabel:SetHidden(true)
            container._betterUiNativePriceLabel:SetText("")
        end
        -- Reset the bottomRail divider to its stock anchor (mirrors the stock
        -- else-branch in TooltipEquipped.UpdateTooltipEquippedText) instead of
        -- leaving it hidden/anchored under our custom status label.
        if bottomRail then
            bottomRail:ClearAnchors()
            bottomRail:SetAnchor(TOPLEFT, container, TOPLEFT, 0,
                rawget(_G, "ZO_GAMEPAD_CONTENT_HEADER_DIVIDER_OFFSET_Y") or 0)
            bottomRail:SetAnchor(TOPRIGHT, container, TOPRIGHT, 0,
                rawget(_G, "ZO_GAMEPAD_CONTENT_HEADER_DIVIDER_OFFSET_Y") or 0)
            bottomRail:SetHidden(false)
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
        -- Re-apply the stock body font to reverse ApplyTooltipLabelFonts.
        RestoreStockLabelFonts(tooltip)
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
        local fontSize = BETTERUI.GeneralInterface.Tooltips.GetTooltipFontSize()
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
