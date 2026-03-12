--[[
File: Modules/Inventory/InventoryTooltipUtils.lua
Purpose: specialized tooltip logic for the Inventory module.
         Extracted from Inventory.lua to reduce file size.
Author: BetterUI Team
Last Modified: 2026-02-07
]]

if BETTERUI == nil then BETTERUI = {} end
BETTERUI.Inventory = BETTERUI.Inventory or {}

-- Dependencies (ensure these globals are available)

--[[
Function: BETTERUI.Inventory.ApplyTooltipStyles
Description: Configures the visual style of native tooltips.
Rationale: Applies BetterUI's custom aesthetics (font sizes, colors, layout) to the gamepad tooltip system.
Mechanism: Modifies the global ZO_TOOLTIP_STYLES table.
References: Called by BETTERUI.Inventory.Setup
]]
function BETTERUI.Inventory.ApplyTooltipStyles()
    local tooltipSize = BETTERUI.Settings.Modules["CIM"].tooltipSize or 24

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

--[[
Function: BETTERUI.Inventory.EnableTooltipMouseWheel
Description: Enables mouse wheel scrolling for the left-side tooltip container.
Rationale: Allows users to scroll long item descriptions using the mouse wheel, improving usability.
Mechanism: Sets MouseEnabled on the tip controls and registers an OnMouseWheel handler.
References: Called by BETTERUI.Inventory.Setup
]]
function BETTERUI.Inventory.EnableTooltipMouseWheel()
    local tip = ZO_GamepadTooltipTopLevelLeftTooltipContainerTip
    local tipScroll = ZO_GamepadTooltipTopLevelLeftTooltipContainerTipScroll
    if tip and tipScroll then
        tip:SetMouseEnabled(true)
        tipScroll:SetMouseEnabled(true)
        tip:SetHandler("OnMouseWheel", function(self, delta)
            local speed = (BETTERUI.Settings.Modules["CIM"].rhScrollSpeed) or 20
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

--[[
Function: BETTERUI.Inventory.CleanupEnhancedTooltip
Description: Hides the custom BetterUI tooltip status label and resets bottomRail anchors.
Rationale: Called when navigating away from items (e.g., to action dialogs) to prevent
           visual artifacts from persisting.
param: tooltipType (string) - The type of tooltip (GAMEPAD_LEFT_TOOLTIP etc).
]]
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
    end
    if GAMEPAD_TOOLTIPS and GAMEPAD_TOOLTIPS.ClearStatusLabel then
        GAMEPAD_TOOLTIPS:ClearStatusLabel(tooltipType)
    end
end

--[[
Function: BETTERUI.Inventory.UpdateTooltipEquippedText
Description: Intercepts and customizes the 'Equipped' tooltip header.
Rationale: Native tooltips lack sufficient detail (traits, binding, collections) and layout control.
Mechanism:
- 1. Checks settings to enable/disable enhancements.
- 2. Hides native 'StatusLabel' and 'BottomRail' to take control of layout.
- 3. Injects a custom label (_betterUiStatus) with comprehensive item info (Traits, Locked, Stolen, Price).
- 4. Physically shifts the tooltip body (via Anchor) to prevent overlap with the custom header.
- 5. Supports recursive hiding of redundant text in the native body.
param: tooltipType (string) - The type of tooltip (GAMEPAD_LEFT_TOOLTIP etc).
param: equipSlot (number) - The equipment slot index.
]]
function BETTERUI.Inventory.UpdateTooltipEquippedText(tooltipType, equipSlot)
    local tooltip = GAMEPAD_TOOLTIPS:GetTooltip(tooltipType)
    local container = GAMEPAD_TOOLTIPS:GetTooltipContainer(tooltipType)

    -- Check Setting (consistent pattern: nil/missing → true, explicit false → false)
    local settings = BETTERUI.Settings.Modules["CIM"]
    local enhancementsEnabled = settings and settings.enableTooltipEnhancements ~= false

    -- Force 'false' default handled by Settings defaults, but variable initialization logic is sound.

    local fontSize = BETTERUI.GetTooltipFontSize()
    local fontStr = "$(MEDIUM_FONT)|" .. fontSize .. "|soft-shadow-thick"
    local scrollTooltip = container and container:GetNamedChild("Tip")
    local nativeBottomRail = container and (container.bottomRail or container:GetNamedChild("BottomRail"))

    if enhancementsEnabled and container and container._betterUiNativePriceLabel then
        container._betterUiNativePriceLabel:SetHidden(true)
        container._betterUiNativePriceLabel:SetText("")
    end
    if enhancementsEnabled and scrollTooltip then
        scrollTooltip:ClearAnchors()
        if nativeBottomRail then
            scrollTooltip:SetAnchor(TOPLEFT, nativeBottomRail, BOTTOMLEFT, 0, 0)
        else
            scrollTooltip:SetAnchor(TOPLEFT, container, TOPLEFT, 0, BETTERUI.CIM.CONST.TOOLTIP_SCROLL_OFFSET_Y)
        end
        scrollTooltip:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, 0, 0)
    end

    -- 1. Get BetterUI Info (Price/Trait)
    local extraText = ""
    local priceText = ""
    local traitText = ""

    if tooltip and tooltip._betterui_itemLink then
        local priceLines = BETTERUI.GetInventoryPriceInfo(tooltip._betterui_itemLink, tooltip._betterui_bagId,
            tooltip._betterui_slotIndex, tooltip._betterui_storeStackCount)
        local traitLines = BETTERUI.GetInventoryTraitInfo(tooltip._betterui_itemLink)

        for _, line in ipairs(priceLines) do priceText = priceText .. line .. "\n" end
        for _, line in ipairs(traitLines) do traitText = traitText .. line .. "\n" end

        -- Trim trailing newlines
        if priceText ~= "" then priceText = priceText:sub(1, -2) end
        if traitText ~= "" then traitText = traitText:sub(1, -2) end

        extraText = priceText
        if traitText ~= "" then
            if extraText ~= "" then extraText = extraText .. "\n" end
            extraText = extraText .. traitText
        end
    end

    -- 2. Construct "Equipped" text
    local headerText = ""
    local valueText = ""
    local equipSlotText = ""

    if equipSlot then
        ZO_InventoryUtils_UpdateTooltipEquippedIndicatorText(tooltipType, equipSlot)
        local isHidden, highestPriorityVisualLayerThatIsShowing =
            WouldEquipmentBeHidden(equipSlot, GAMEPLAY_ACTOR_CATEGORY_PLAYER)

        local equipSlotTextHidden = ""
        local equippedHeader = GetString(SI_GAMEPAD_EQUIPPED_ITEM_HEADER)

        if equipSlot == EQUIP_SLOT_MAIN_HAND then
            equipSlotText = GetString(SI_GAMEPAD_EQUIPPED_MAIN_HAND_ITEM_HEADER)
        elseif equipSlot == EQUIP_SLOT_BACKUP_MAIN then
            equipSlotText = GetString(SI_GAMEPAD_EQUIPPED_BACKUP_MAIN_ITEM_HEADER)
        elseif equipSlot == EQUIP_SLOT_OFF_HAND then
            equipSlotText = GetString(SI_GAMEPAD_EQUIPPED_OFF_HAND_ITEM_HEADER)
        elseif equipSlot == EQUIP_SLOT_BACKUP_OFF then
            equipSlotText = GetString(SI_GAMEPAD_EQUIPPED_BACKUP_OFF_ITEM_HEADER)
        end

        -- Custom Header Logic ONLY if Enabled
        if enhancementsEnabled then
            -- Calculate icon size based on font (scale icons proportionally)
            local iconSize = math.floor(fontSize * 1.0) -- Icons consistent with font size
            local iconSizeFmt = iconSize .. ":" .. iconSize

            if isHidden and equipSlotText ~= "" then
                equipSlotTextHidden = "(|t" ..
                    iconSizeFmt .. ":EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_apparel.dds|tCosmetic)"
                headerText = zo_strformat("<<1>>: ", equippedHeader)
                valueText = zo_strformat("<<1>> <<2>>", equipSlotText, equipSlotTextHidden)
            elseif isHidden then
                equipSlotTextHidden = "|t" ..
                    iconSizeFmt .. ":EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_apparel.dds|t Cosmetic"
                headerText = zo_strformat("<<1>> - <<2>>", equippedHeader, equipSlotTextHidden)
            elseif not isHidden and equipSlotText ~= "" then
                headerText = zo_strformat("<<1>>: ", equippedHeader)
                valueText = zo_strformat("<<1>>", equipSlotText)
            else
                headerText = GetString(SI_GAMEPAD_EQUIPPED_ITEM_HEADER)
                valueText = equipSlotText
            end
        else
            -- Native Standard Logic replication with dash separator
            if equipSlotText ~= "" then
                headerText = GetString(SI_GAMEPAD_EQUIPPED_ITEM_HEADER) .. " -"
            else
                headerText = GetString(SI_GAMEPAD_EQUIPPED_ITEM_HEADER)
            end
            valueText = equipSlotText
        end
    end

    -- 3. Custom Label Logic
    if container then
        local bottomRail = container.bottomRail or container:GetNamedChild("BottomRail")

        if not container._betterUiStatus then
            -- Create the label once per container
            local label = WINDOW_MANAGER:CreateControl(nil, container, CT_LABEL)
            -- MAXIMIZED WIDTH: 0 padding, user requested 60 spacing
            local yOffset = BETTERUI.CONST.LAYOUT.TOOLTIP.STATUS_LABEL_OFFSET_Y
            label:SetAnchor(TOPLEFT, container, TOPLEFT, 0, yOffset)
            label:SetAnchor(TOPRIGHT, container, TOPRIGHT, 0, yOffset) -- Spacing from top of header
            label:SetMaxLineCount(0)                                   -- Allow unlimited lines
            label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
            -- Default color (Header Color)
            label:SetColor(ZO_ColorDef:New("D5B526"):UnpackRGBA()) -- Standard Gold header color
            container._betterUiStatus = label
        end

        local customLabel = container._betterUiStatus

        if enhancementsEnabled then
            -- A. Use Custom Label
            -- Hide native labels first
            GAMEPAD_TOOLTIPS:ClearStatusLabel(tooltipType)

            -- Construct Full Text
            local fullText = ""

            -- 1. EQUIPPED text
            if headerText ~= "" or valueText ~= "" then
                -- Colorize valueText to white
                local valueColored = valueText
                if valueText ~= "" then
                    valueColored = "|cFFFFFF" .. valueText .. "|r"
                end
                fullText = headerText .. valueColored .. "\n"
            end

            -- 2. ITEM INFO (Lock | Bound | Counts | Traits | BindType | Collected)
            if tooltip and tooltip._betterui_itemLink then
                local itemLink = tooltip._betterui_itemLink
                local bagId = tooltip._betterui_bagId
                local slotIndex = tooltip._betterui_slotIndex

                -- Calculate icon size for enhanced tooltip (scale with font)
                local iconSize = math.floor(fontSize * 1.0)
                local iconSizeFmt = iconSize .. ":" .. iconSize
                -- Dense icons (stolen, bag, bank, craftbag, junk) have no internal padding
                -- in their textures, so they need a smaller size to match padded icons like lock/trait
                local denseIconSize = math.floor(fontSize * 0.8)
                local denseIconSizeFmt = denseIconSize .. ":" .. denseIconSize

                -- A. Item Type (Neck, Ring)
                local itemType = GetItemLinkItemType(itemLink)
                local typeString = GetString("SI_ITEMTYPE", itemType)
                local typeStringUpper = zo_strupper(typeString)

                -- B. Lock Icon
                local lockString = ""
                if bagId and slotIndex and IsItemPlayerLocked(bagId, slotIndex) then
                    lockString = "|t" .. iconSizeFmt .. ":EsoUI/Art/Miscellaneous/status_locked.dds|t Locked"
                end

                -- C. Bound Status
                local boundStringLocal = GetString(SI_ITEM_FORMAT_STR_BOUND)
                local boundString = ""
                if IsItemBound(bagId, slotIndex) then
                    boundString = boundStringLocal
                end

                -- D. Bind Type (e.g. Bind on Equip) that is NOT yet bound
                local bindTypeString = ""
                local bindTypeStringLocal = ""

                local bindType = GetItemLinkBindType(itemLink) -- Always check link for the nature of the item

                if bindType == BIND_TYPE_ON_EQUIP then
                    local isSet = IsItemLinkSetCollectionPiece and IsItemLinkSetCollectionPiece(itemLink)
                    local isUnlocked = isSet and IsItemSetCollectionPieceUnlocked and
                        IsItemSetCollectionPieceUnlocked(GetItemLinkItemId(itemLink))

                    if isSet and not isUnlocked then
                        bindTypeStringLocal = GetString(SI_BETTERUI_BIND_FOR_COLLECTION)
                        bindTypeString = bindTypeStringLocal
                    else
                        bindTypeStringLocal = GetString(SI_ITEM_FORMAT_STR_BIND_ON_EQUIP)
                        bindTypeString = bindTypeStringLocal
                    end
                elseif bindType == BIND_TYPE_ON_PICKUP or bindType == BIND_TYPE_ON_PICKUP_BACKPACK then
                    bindTypeStringLocal = GetString(SI_ITEM_FORMAT_STR_BIND_ON_PICKUP)
                    bindTypeString = bindTypeStringLocal
                end

                -- E. Traits (Ornate / Intricate)
                local traitType = GetItemLinkTraitInfo(itemLink)
                local traitString = ""
                local traitStringLocal = ""
                local traitIcon = ""

                if traitType == ITEM_TRAIT_TYPE_ARMOR_ORNATE or traitType == ITEM_TRAIT_TYPE_WEAPON_ORNATE or traitType == ITEM_TRAIT_TYPE_JEWELRY_ORNATE then
                    traitStringLocal = GetString("SI_ITEMTRAITTYPE", traitType)
                    traitString = traitStringLocal
                    traitIcon = "|t" .. iconSizeFmt .. ":esoui/art/inventory/inventory_trait_ornate_icon.dds|t"
                elseif traitType == ITEM_TRAIT_TYPE_ARMOR_INTRICATE or traitType == ITEM_TRAIT_TYPE_WEAPON_INTRICATE or traitType == ITEM_TRAIT_TYPE_JEWELRY_INTRICATE then
                    traitStringLocal = GetString("SI_ITEMTRAITTYPE", traitType)
                    traitString = traitStringLocal
                    traitIcon = "|t" .. iconSizeFmt .. ":esoui/art/inventory/inventory_trait_intricate_icon.dds|t"
                end

                -- E2. Stolen Status
                local isStolen = false
                if bagId and slotIndex then
                    isStolen = IsItemStolen(bagId, slotIndex)
                else
                    isStolen = IsItemLinkStolen(itemLink)
                end

                local stolenString = ""
                local stolenIcon = ""
                if isStolen then
                    stolenString = GetString(SI_GAMEPAD_ITEM_STOLEN_LABEL) -- "Stolen"
                    stolenIcon = "|t" ..
                        denseIconSizeFmt .. ":EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_stolenitem.dds|t"
                end

                -- E3. Junk Status
                local isJunk = false
                if bagId and slotIndex then
                    isJunk = IsItemJunk(bagId, slotIndex)
                end
                local junkString = ""
                if isJunk then
                    junkString = GetString(SI_ITEM_FORMAT_STR_JUNK)
                end

                -- F. Collected Status
                local isCollected = false
                if IsItemSetCollectionPiece and IsItemSetCollectionPieceUnlocked then
                    if IsItemSetCollectionPiece(itemLink) and IsItemSetCollectionPieceUnlocked(itemLink) then
                        isCollected = true
                    end
                end

                -- G. Bag/Bank Counts
                local bagCount, bankCount, craftBagCount = GetItemLinkStacks(itemLink)
                local bagIcon = "|t" .. denseIconSizeFmt .. ":EsoUI/Art/Tooltips/icon_bag.dds|t"
                local bankIcon = "|t" .. denseIconSizeFmt .. ":EsoUI/Art/Tooltips/icon_bank.dds|t"
                local craftBagIcon = "|t" .. denseIconSizeFmt .. ":EsoUI/Art/Tooltips/icon_craft_bag.dds|t"

                -- Build Info Line
                local segments = {}
                local infoLine = ""

                -- Lock
                if lockString ~= "" then
                    table.insert(segments, lockString)
                end

                -- Traits (Icon + Gold Text)
                if traitString ~= "" then
                    local tStr = ""
                    if traitIcon ~= "" then
                        tStr = tStr .. traitIcon .. " "
                    end
                    tStr = tStr .. "|cD5B526" .. traitString .. "|r"
                    table.insert(segments, tStr)
                end

                -- Bind Type (Gold) - Only show if NOT bound
                if bindTypeString ~= "" and boundString == "" then
                    table.insert(segments, "|cD5B526" .. bindTypeString .. "|r")
                end

                -- Bound (Gold)
                if boundString ~= "" then
                    table.insert(segments, "|cD5B526" .. boundString .. "|r")
                end


                if isJunk and junkString ~= "" then
                    local junkIcon = "|t" .. denseIconSizeFmt .. ":esoui/art/inventory/inventory_tabicon_junk_up.dds|t"
                    table.insert(segments, "|cD5B526" .. junkIcon .. " " .. junkString .. "|r")
                end

                -- Stolen (Red)
                if stolenString ~= "" then
                    -- Wrap both icon and text in Red
                    local sStr = "|cFF3333"
                    if stolenIcon ~= "" then
                        sStr = sStr .. stolenIcon .. " "
                    end
                    sStr = sStr .. stolenString .. "|r"
                    table.insert(segments, sStr)
                end

                -- Counts (White)
                local countString = ""
                if bagCount > 0 then countString = countString .. bagIcon .. " " .. bagCount .. " " end
                if bankCount > 0 then countString = countString .. bankIcon .. " " .. bankCount .. " " end
                if craftBagCount > 0 then countString = countString .. craftBagIcon .. " " .. craftBagCount .. " " end

                if countString ~= "" then
                    table.insert(segments, "|cFFFFFF" .. countString .. "|r")
                end

                -- Join text segments with " - "
                if #segments > 0 then
                    infoLine = table.concat(segments, " - ")
                end

                -- Append if we have anything
                if infoLine ~= "" then
                    fullText = fullText .. infoLine .. "\n"
                end

                -- NOTE: Native tooltip labels (bag/bank counts, bound, stolen, set collection)
                -- are suppressed at source via ZO_Tooltip.AddTopLinesToTopSection hook
                -- in EnhancementModule.lua. No post-hoc hiding needed.
            end

            -- 3. MARKET DATA (White Color)
            -- Only append price/trait data if available
            if extraText ~= "" then
                local extraTextWhite = "|cFFFFFF" .. extraText .. "|r"
                fullText = fullText .. extraTextWhite
            end

            -- Configure and Show Custom Label
            local statusFontSize = math.floor(fontSize * 0.80)
            local statusFontStr = "$(MEDIUM_FONT)|" .. statusFontSize .. "|shadow"

            customLabel:SetFont(statusFontStr)
            customLabel:SetText(fullText)
            customLabel:SetHidden(false)

            -- Rationale: Physically shift the tooltip body to prevent overlap with our custom header.
            -- This relies on shifting the internal Tooltip control relative to its ScrollChild parent.
            if tooltip then
                tooltip:ClearAnchors()
                tooltip:SetAnchor(TOPLEFT, nil, TOPLEFT, 0, BETTERUI.CONST.LAYOUT.TOOLTIP.BODY_OFFSET_Y_ENHANCED)
            end
            if bottomRail then
                bottomRail:ClearAnchors()
                -- Anchor below custom label with reduced padding (0) per user request
                bottomRail:SetAnchor(TOPLEFT, customLabel, BOTTOMLEFT, 0, 0)
                bottomRail:SetAnchor(TOPRIGHT, customLabel, BOTTOMRIGHT, 0, 0)
                bottomRail:SetHidden(false)
            end
        else
            -- RESET: If disabled/empty, restore native layout (0 offset)
            if tooltip then
                tooltip:ClearAnchors()
                tooltip:SetAnchor(TOPLEFT, nil, TOPLEFT, 0, 0)
            end

            customLabel:SetHidden(true)

            if bottomRail then
                bottomRail:ClearAnchors()
                bottomRail:SetAnchor(TOPLEFT, container, TOPLEFT, 0, ZO_GAMEPAD_CONTENT_HEADER_DIVIDER_OFFSET_Y or 0)
                bottomRail:SetAnchor(TOPRIGHT, container, TOPRIGHT, 0, ZO_GAMEPAD_CONTENT_HEADER_DIVIDER_OFFSET_Y or 0)
                -- We don't hide it necessarily, let native logic handle
            end
        end

        --[[
        Native Fallback: Price Display (when BetterUI tooltip enhancements are disabled)

        Rationale: When users disable tooltip enhancements, we still want to show TTC/MM/ATT
                   market pricing. This section handles displaying price info in the native
                   tooltip layout without modifying the tooltip's internal anchor structure.

        Mechanism:
        1. Creates a price label as a child of the container (not inside scroll content)
        2. Positions it just below the BottomRail divider
        3. Shifts the entire scroll tooltip (Tip) down to make room
        4. Must run for ALL items to properly reset state between tooltip switches

        Why not modify tooltip anchors directly?
        The native ZO_Tooltip uses a complex internal layout system. Modifying anchors on
        internal controls (like ScrollChild->Tooltip) causes circular reference errors.
        Instead, we add our label outside and shift the containing scroll control.
        ]]
        if not enhancementsEnabled then
            -- Get the scroll container structure
            local scrollTooltip = container and container:GetNamedChild("Tip")
            local scrollContainer = scrollTooltip and scrollTooltip:GetNamedChild("Scroll")
            local scrollChild = scrollContainer and scrollContainer:GetNamedChild("ScrollChild")

            -- Show price text for ALL items
            -- NOTE: We add the price label as a sibling to the tooltip, NOT modifying tooltip anchors
            -- This avoids anchor circular reference errors
            if priceText ~= "" and scrollChild then
                -- Create/get the price label in the container (before tooltip in visual order)
                if not container._betterUiNativePriceLabel then
                    local priceLabel = WINDOW_MANAGER:CreateControl(nil, container, CT_LABEL)
                    priceLabel:SetMaxLineCount(0)
                    priceLabel:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
                    priceLabel:SetColor(1, 1, 1, 1) -- White color for price text
                    priceLabel:SetFont("ZoFontGamepad27")
                    priceLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
                    container._betterUiNativePriceLabel = priceLabel
                end

                local priceLabel = container._betterUiNativePriceLabel
                if priceLabel then
                    local bottomRail = container.bottomRail or container:GetNamedChild("BottomRail")

                    -- Position price just below the BottomRail divider
                    priceLabel:ClearAnchors()
                    if bottomRail then
                        priceLabel:SetAnchor(TOPLEFT, bottomRail, BOTTOMLEFT, 0, 5)
                        priceLabel:SetAnchor(TOPRIGHT, bottomRail, BOTTOMRIGHT, 0, 5)
                    else
                        priceLabel:SetAnchor(TOPLEFT, container, TOPLEFT, 0, 40)
                        priceLabel:SetAnchor(TOPRIGHT, container, TOPRIGHT, 0, 40)
                    end
                    priceLabel:SetText(priceText)
                    priceLabel:SetHidden(false)

                    -- Calculate height needed for price text
                    local numPriceLines = 1
                    for _ in string.gmatch(priceText, "\n") do
                        numPriceLines = numPriceLines + 1
                    end
                    local priceHeight = numPriceLines * 32

                    -- Move the scroll tooltip (Tip) down to make room
                    if scrollTooltip then
                        scrollTooltip:ClearAnchors()
                        scrollTooltip:SetAnchor(TOPLEFT, bottomRail, BOTTOMLEFT, 0, priceHeight + 5)
                        scrollTooltip:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, 0, 0)
                    end
                end
            else
                -- No price text - hide price label and restore normal Tip position
                if container and container._betterUiNativePriceLabel then
                    container._betterUiNativePriceLabel:SetHidden(true)
                end

                -- Restore Tip to normal position
                if scrollTooltip then
                    local bottomRail = container.bottomRail or container:GetNamedChild("BottomRail")
                    scrollTooltip:ClearAnchors()
                    if bottomRail then
                        scrollTooltip:SetAnchor(TOPLEFT, bottomRail, BOTTOMLEFT, 0, 0)
                    else
                        scrollTooltip:SetAnchor(TOPLEFT, container, TOPLEFT, 0,
                            BETTERUI.CIM.CONST.TOOLTIP_SCROLL_OFFSET_Y)
                    end
                    scrollTooltip:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, 0, 0)
                end
            end

            -- Handle status label (header)
            if equipSlot then
                -- Equipped item - show EQUIPPED header with slot text (Main Hand, etc.)
                GAMEPAD_TOOLTIPS:SetStatusLabelText(tooltipType, headerText, valueText)

                -- Reduce font size of the slot text (StatusLabelValue) for cleaner appearance
                local statusLabelValue = container and container:GetNamedChild("StatusLabelValue")
                if statusLabelValue then
                    statusLabelValue:SetFont("ZoFontGamepad34")
                end
            else
                -- Non-equipped item - CLEAR the status label so it doesn't persist
                GAMEPAD_TOOLTIPS:ClearStatusLabel(tooltipType)
            end
        end
    end

    -- 4. Scale Tooltip Body Text (Always, only if Enabled)
    -- "This option will enable or disable the font scaling as well."
    if enhancementsEnabled and tooltip then
        for i = 1, tooltip:GetNumChildren() do
            local child = tooltip:GetChild(i)
            if child and child:GetType() == CT_LABEL then
                child:SetFont(fontStr)
            end
        end
    end
end
