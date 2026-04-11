--[[
File: Modules/Companions/Core/CompanionItemList.lua
Purpose: Tooltip, list-refresh, and row-construction logic for companion equipment.
]]

if not BETTERUI.Companions or not BETTERUI.Companions.Class then return end

---@param bagId number
---@param slotIndex number
---@return number|nil equipSlot
local function ResolveCompanionEquipSlot(bagId, slotIndex)
    local equipType = GetItemEquipType and GetItemEquipType(bagId, slotIndex) or nil
    if equipType == nil or equipType == 0 or equipType == EQUIP_TYPE_INVALID then
        return nil
    end

    if not ZO_Character_EnumerateOrderedEquipSlots or not ZO_Character_DoesEquipSlotUseEquipType then
        return nil
    end

    local firstCompatibleSlot = nil
    for _, equipSlot in ZO_Character_EnumerateOrderedEquipSlots(BAG_COMPANION_WORN) do
        if ZO_Character_DoesEquipSlotUseEquipType(equipSlot, equipType) then
            if not firstCompatibleSlot then
                firstCompatibleSlot = equipSlot
            end
            if not HasItemInSlot or not HasItemInSlot(BAG_COMPANION_WORN, equipSlot) then
                return equipSlot
            end
        end
    end

    return firstCompatibleSlot
end

function BETTERUI.Companions.Class:UpdateTooltipEquippedIndicatorText(tooltipType, equipSlot)
    if ZO_InventoryUtils_UpdateTooltipEquippedIndicatorText then
        ZO_InventoryUtils_UpdateTooltipEquippedIndicatorText(tooltipType, equipSlot, GAMEPLAY_ACTOR_CATEGORY_COMPANION)
    end
end

function BETTERUI.Companions.Class:GetComparisonEquipSlot(selectedData)
    if not selectedData then
        return nil
    end

    local ds = selectedData.dataSource or selectedData
    if ds.bagId == BAG_COMPANION_WORN then
        return ds.slotIndex
    end

    if ds.equipSlot then
        return ds.equipSlot
    end

    return ResolveCompanionEquipSlot(ds.bagId, ds.slotIndex)
end

function BETTERUI.Companions.Class:UpdateItemTooltips(selectedData)
    if not GAMEPAD_TOOLTIPS then
        return
    end

    local ds = selectedData and (selectedData.dataSource or selectedData) or nil
    if not ds or ds.bagId == nil or ds.slotIndex == nil then
        if BETTERUI.Inventory and BETTERUI.Inventory.CleanupEnhancedTooltip then
            BETTERUI.Inventory.CleanupEnhancedTooltip(GAMEPAD_LEFT_TOOLTIP)
        end
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_RIGHT_TOOLTIP)
        return
    end

    GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, ds.bagId, ds.slotIndex)
    if ds.bagId == BAG_COMPANION_WORN then
        self:UpdateTooltipEquippedIndicatorText(GAMEPAD_LEFT_TOOLTIP, ds.slotIndex)
    else
        self:UpdateTooltipEquippedIndicatorText(GAMEPAD_LEFT_TOOLTIP, nil)
    end

    local compareSlot = self:GetComparisonEquipSlot(ds)
    if compareSlot and HasItemInSlot and HasItemInSlot(BAG_COMPANION_WORN, compareSlot) then
        GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_RIGHT_TOOLTIP, BAG_COMPANION_WORN, compareSlot)
        self:UpdateTooltipEquippedIndicatorText(GAMEPAD_RIGHT_TOOLTIP, compareSlot)
    else
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_RIGHT_TOOLTIP)
    end

    local container = GAMEPAD_TOOLTIPS:GetTooltipContainer(GAMEPAD_LEFT_TOOLTIP)
    if container and container._betterUiComparison then
        container._betterUiComparison:SetHidden(true)
    end

    -- INV-001: Stat comparison for companion backpack items (not already equipped)
    if ds.bagId ~= BAG_COMPANION_WORN and BETTERUI.Inventory.StatComparison then
        local itemLink = GetItemLink(ds.bagId, ds.slotIndex)
        local result = BETTERUI.Inventory.StatComparison.Compare(itemLink, ds.bagId, ds.slotIndex, BAG_COMPANION_WORN)
        if result and result.lines and #result.lines > 0 and container then
            if not container._betterUiComparison then
                local label = WINDOW_MANAGER:CreateControl(nil, container, CT_LABEL)
                label:SetMaxLineCount(0)
                label:SetWrapMode(TEXT_WRAP_MODE_ELLIPSIS)
                label:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
                container._betterUiComparison = label
            end
            local compLabel = container._betterUiComparison
            local fontSize = BETTERUI.GetTooltipFontSize()
            local compFontSize = math.floor(fontSize * 0.75)
            compLabel:SetFont("$(MEDIUM_FONT)|" .. compFontSize .. "|shadow")
            compLabel:SetText(BETTERUI.Inventory.StatComparison.FormatForTooltip(result))
            compLabel:ClearAnchors()
            compLabel:SetAnchor(BOTTOMLEFT, container, BOTTOMLEFT, 5, -5)
            compLabel:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, -5, -5)
            compLabel:SetHidden(false)
        elseif container and container._betterUiComparison then
            container._betterUiComparison:SetHidden(true)
        end
    end
end

function BETTERUI.Companions.Class:RefreshList()
    if not self.list then return end
    self.list:Clear()

    local currentCategory = self:GetCurrentCategory()
    local filterType = currentCategory and currentCategory.filterType or nil

    -- Section 1: Currently equipped companion items
    self:BuildEquippedItems(filterType)

    -- Section 2: Equippable companion items from backpack
    self:BuildBackpackItems(filterType)

    self.list:Commit()
    self:EnsureColumnHeadersVisible()
    self:UpdateScrollIndicator(self.list)
end

function BETTERUI.Companions.Class:BuildEquippedItems(filterType)
    local list = self.list
    if not list then return end

    if not HasActiveCompanion or not HasActiveCompanion() then return end

    local bagSize = GetBagSize(BAG_COMPANION_WORN)
    if not bagSize or bagSize == 0 then return end

    for slotIndex = 0, bagSize - 1 do
        if self:DoesSlotMatchFilterType(BAG_COMPANION_WORN, slotIndex, filterType) then
            local icon, stackCount, sellPrice, _locked, _equipType,
                _, functionalQuality, displayQuality = GetItemInfo(BAG_COMPANION_WORN, slotIndex)

            local name = GetItemName(BAG_COMPANION_WORN, slotIndex) or ""
            if name ~= "" then
                name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
                local quality = displayQuality or functionalQuality or ITEM_DISPLAY_QUALITY_NORMAL
                local itemLink = GetItemLink(BAG_COMPANION_WORN, slotIndex)
                local itemType = itemLink and GetItemLinkItemType(itemLink) or 0
                local slotData = SHARED_INVENTORY and SHARED_INVENTORY.GenerateSingleSlotData
                    and SHARED_INVENTORY:GenerateSingleSlotData(BAG_COMPANION_WORN, slotIndex)

                local entryData = {
                    name = name,
                    icon = icon,
                    stackCount = stackCount or 1,
                    sellPrice = sellPrice or 0,
                    stackSellPrice = (sellPrice or 0) * (stackCount or 1),
                    quality = quality,
                    bagId = BAG_COMPANION_WORN,
                    slotIndex = slotIndex,
                    isEquipped = true,
                    isCompanionItem = true,
                    bestGamepadItemCategoryName = GetBestItemCategoryDescription
                        and GetBestItemCategoryDescription({ bagId = BAG_COMPANION_WORN, slotIndex = slotIndex })
                        or "",
                    bestItemTypeName = GetString("SI_ITEMTYPE", itemType),
                    cached_itemLink = itemLink,
                    cached_itemType = itemType,
                    uniqueId = slotData and slotData.uniqueId or nil,
                    isPlayerLocked = slotData and slotData.isPlayerLocked or false,
                    isBoPTradeable = slotData and slotData.isBoPTradeable or false,
                    equipType = slotData and slotData.equipType or _equipType,
                    itemType = slotData and slotData.itemType or itemType,
                    equipSlot = slotIndex,
                    statValue = "",
                }

                if GetItemStatValue then
                    local statValue = GetItemStatValue(BAG_COMPANION_WORN, slotIndex)
                    if statValue and statValue > 0 then
                        entryData.statValue = statValue
                    end
                end

                local entry = ZO_GamepadEntryData:New("|cFFD700[E]|r " .. entryData.name, entryData.icon)
                entry:SetDataSource(entryData)
                entry.narrationText = function() return entryData.name end

                if quality then
                    local r, g, b = GetItemQualityColor(quality):UnpackRGBA()
                    entry:SetNameColors(ZO_ColorDef:New(r, g, b, 1), ZO_ColorDef:New(r, g, b, 0.7))
                end

                list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", entry)
            end
        end
    end
end

function BETTERUI.Companions.Class:BuildBackpackItems(filterType)
    local list = self.list
    if not list then return end

    local bagSize = GetBagSize(BAG_BACKPACK) or 0

    for slotIndex = 0, bagSize - 1 do
        local icon, stackCount, sellPrice = GetItemInfo(BAG_BACKPACK, slotIndex)
        local actorCategory = GetItemActorCategory and GetItemActorCategory(BAG_BACKPACK, slotIndex)

        if actorCategory == GAMEPLAY_ACTOR_CATEGORY_COMPANION and self:DoesSlotMatchFilterType(BAG_BACKPACK, slotIndex, filterType) then
            local name = GetItemName(BAG_BACKPACK, slotIndex) or ""
            if name ~= "" then
                name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
                local quality = GetItemDisplayQuality(BAG_BACKPACK, slotIndex) or ITEM_DISPLAY_QUALITY_NORMAL
                local itemLink = GetItemLink(BAG_BACKPACK, slotIndex)
                local itemType = itemLink and GetItemLinkItemType(itemLink) or 0
                local slotData = SHARED_INVENTORY and SHARED_INVENTORY.GenerateSingleSlotData
                    and SHARED_INVENTORY:GenerateSingleSlotData(BAG_BACKPACK, slotIndex)
                local equipSlot = ResolveCompanionEquipSlot(BAG_BACKPACK, slotIndex)

                local entryData = {
                    name = name,
                    icon = icon,
                    stackCount = stackCount or 1,
                    sellPrice = sellPrice or 0,
                    stackSellPrice = (sellPrice or 0) * (stackCount or 1),
                    quality = quality,
                    bagId = BAG_BACKPACK,
                    slotIndex = slotIndex,
                    isEquipped = false,
                    isCompanionItem = true,
                    bestGamepadItemCategoryName = GetBestItemCategoryDescription
                        and GetBestItemCategoryDescription({ bagId = BAG_BACKPACK, slotIndex = slotIndex })
                        or "",
                    bestItemTypeName = GetString("SI_ITEMTYPE", itemType),
                    cached_itemLink = itemLink,
                    cached_itemType = itemType,
                    uniqueId = slotData and slotData.uniqueId or nil,
                    isPlayerLocked = slotData and slotData.isPlayerLocked or false,
                    isBoPTradeable = slotData and slotData.isBoPTradeable or false,
                    equipType = slotData and slotData.equipType or nil,
                    itemType = slotData and slotData.itemType or itemType,
                    equipSlot = equipSlot,
                    statValue = "",
                }

                if GetItemStatValue then
                    local statValue = GetItemStatValue(BAG_BACKPACK, slotIndex)
                    if statValue and statValue > 0 then
                        entryData.statValue = statValue
                    end
                end

                local entry = ZO_GamepadEntryData:New(entryData.name, entryData.icon)
                entry:SetDataSource(entryData)
                entry.narrationText = function() return entryData.name end

                if quality then
                    local r, g, b = GetItemQualityColor(quality):UnpackRGBA()
                    entry:SetNameColors(ZO_ColorDef:New(r, g, b, 1), ZO_ColorDef:New(r, g, b, 0.7))
                end

                list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", entry)
            end
        end
    end
end
