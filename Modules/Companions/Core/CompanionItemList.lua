--[[
File: Modules/Companions/Core/CompanionItemList.lua
Purpose: Tooltip, list-refresh, and row-construction logic for companion equipment.
]]

if not BETTERUI.Companions or not BETTERUI.Companions.Class then return end
local Companions = BETTERUI.Companions

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
    return Companions.ResolveCompanionEquipSlot(ds.bagId, ds.slotIndex)
end

function BETTERUI.Companions.Class:UpdateItemTooltips(selectedData)
    if not GAMEPAD_TOOLTIPS then
        return
    end

    local ds = selectedData and (selectedData.dataSource or selectedData) or nil
    if BETTERUI.Log then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.GENERAL, "companionTooltipUpdate", {
            bagId = ds and ds.bagId or nil,
            slotIndex = ds and ds.slotIndex or nil,
            name = ds and ds.name or nil
        })
    end
    if not ds or ds.bagId == nil or ds.slotIndex == nil then
        if BETTERUI.CIM.SharedItemSupport and BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip then
            BETTERUI.CIM.SharedItemSupport.CleanupEnhancedTooltip(GAMEPAD_LEFT_TOOLTIP)
        end
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_LEFT_TOOLTIP)
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_RIGHT_TOOLTIP)
        return
    end

    GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_LEFT_TOOLTIP, ds.bagId, ds.slotIndex)

    -- Prevent GeneralInterface posthook from firing a second enhanced tooltip.
    -- BETTERUI.Inventory.UpdateTooltipEquippedText sets _betterui_priceRendered = true
    -- internally, which guards against the deferred LayoutItem posthook.
    if ds.bagId == BAG_COMPANION_WORN then
        self:UpdateTooltipEquippedIndicatorText(GAMEPAD_LEFT_TOOLTIP, ds.slotIndex)
        BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText(GAMEPAD_LEFT_TOOLTIP, ds.slotIndex)
    else
        if GAMEPAD_TOOLTIPS.ClearStatusLabel then
            GAMEPAD_TOOLTIPS:ClearStatusLabel(GAMEPAD_LEFT_TOOLTIP)
        end
        BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText(GAMEPAD_LEFT_TOOLTIP, nil)
    end

    if ds.bagId ~= BAG_COMPANION_WORN then
        local compareSlot = self:GetComparisonEquipSlot(ds)
        if compareSlot and HasItemInSlot and HasItemInSlot(BAG_COMPANION_WORN, compareSlot) then
            GAMEPAD_TOOLTIPS:LayoutBagItem(GAMEPAD_RIGHT_TOOLTIP, BAG_COMPANION_WORN, compareSlot)
            self:UpdateTooltipEquippedIndicatorText(GAMEPAD_RIGHT_TOOLTIP, compareSlot)
            BETTERUI.CIM.SharedItemSupport.UpdateTooltipEquippedText(GAMEPAD_RIGHT_TOOLTIP, compareSlot)
        else
            GAMEPAD_TOOLTIPS:Reset(GAMEPAD_RIGHT_TOOLTIP)
        end
    else
        GAMEPAD_TOOLTIPS:Reset(GAMEPAD_RIGHT_TOOLTIP)
    end

    local container = GAMEPAD_TOOLTIPS:GetTooltipContainer(GAMEPAD_LEFT_TOOLTIP)
    if container and container._betterUiComparison then
        container._betterUiComparison:SetHidden(true)
    end

    if ds.bagId ~= BAG_COMPANION_WORN and BETTERUI.CIM.SharedItemSupport.IsItemComparisonEnabled() then
        local itemLink = GetItemLink(ds.bagId, ds.slotIndex)
        local result = BETTERUI.CIM.SharedItemSupport.CompareItem(itemLink, ds.bagId, ds.slotIndex, BAG_COMPANION_WORN)
        BETTERUI.CIM.SharedItemSupport.ShowComparisonOnTooltip(container, result)
    else
        BETTERUI.CIM.SharedItemSupport.ShowComparisonOnTooltip(container, nil)
    end
end

-- SORT COMPARATORS

local COMPANION_SORT_COMPARATORS = {
    name = function(a, b)
        local nameA = (a.dataSource and a.dataSource.name) or a.name or ""
        local nameB = (b.dataSource and b.dataSource.name) or b.name or ""
        return nameA < nameB
    end,
    type = function(a, b)
        local typeA = (a.dataSource and a.dataSource.bestItemTypeName) or ""
        local typeB = (b.dataSource and b.dataSource.bestItemTypeName) or ""
        if typeA == typeB then
            return COMPANION_SORT_COMPARATORS.name(a, b)
        end
        return typeA < typeB
    end,
    trait = function(a, b)
        local traitA = (a.dataSource and a.dataSource.traitName) or ""
        local traitB = (b.dataSource and b.dataSource.traitName) or ""
        local blankA = traitA == "" and 1 or 0
        local blankB = traitB == "" and 1 or 0
        if blankA ~= blankB then
            return blankA < blankB
        end
        if traitA == traitB then
            return COMPANION_SORT_COMPARATORS.name(a, b)
        end
        return traitA < traitB
    end,
    stat = function(a, b)
        -- statValue is "" when no stat applies and numeric when > 0; normalize
        -- both sides so a number is never compared against a string (a mixed
        -- comparison raises an error inside table.sort).
        local statA = tonumber(a.dataSource and a.dataSource.statValue) or -math.huge
        local statB = tonumber(b.dataSource and b.dataSource.statValue) or -math.huge
        if statA ~= statB then
            return statA > statB
        end
        return COMPANION_SORT_COMPARATORS.name(a, b)
    end,
    value = function(a, b)
        local valA = (a.dataSource and a.dataSource.sellPrice) or 0
        local valB = (b.dataSource and b.dataSource.sellPrice) or 0
        if valA ~= valB then
            return valA > valB
        end
        return COMPANION_SORT_COMPARATORS.name(a, b)
    end,
}

function BETTERUI.Companions.Class:ApplySortToList()
    if not self.list or not self.list.dataList then return end
    local sortKey = "name"
    local sortOrder = ZO_SORT_ORDER_UP
    if self.sortController and self.sortController.GetActiveSortColumn then
        local column, direction = self.sortController:GetActiveSortColumn()
        if column and direction and direction ~= BETTERUI.CIM.UI.HeaderSortController.SORT_DIRECTION.NONE then
            sortKey = column.key or sortKey
            if direction == BETTERUI.CIM.UI.HeaderSortController.SORT_DIRECTION.DESCENDING then
                sortOrder = ZO_SORT_ORDER_DOWN
            end
        end
    end
    local comparator = COMPANION_SORT_COMPARATORS[sortKey] or COMPANION_SORT_COMPARATORS.name
    if sortOrder == ZO_SORT_ORDER_DOWN then
        local base = comparator
        comparator = function(a, b) return base(b, a) end
    end
    table.sort(self.list.dataList, comparator)
end

---@return boolean ok
---@return string|nil errorMessage
function BETTERUI.Companions.Class:RefreshList()
    if not self.list then
        if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.LIST, "RefreshList no-op: list missing") end
        return true
    end

    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.LIST, "companionRefreshList")
    end

    self._isRefreshing = true
    local boundary = Companions.GetBoundary()
    local ok, result = boundary.ExecuteBoundary("Companions.RefreshList", function()
        self.list:Clear()

        local currentCategory = self:GetCurrentCategory()
        local filterType = currentCategory and currentCategory.filterType or nil

        self:BuildEquippedItems(filterType)
        self:BuildBackpackItems(filterType)

        self:ApplySortToList()
        self.list:Commit()
        self:EnsureColumnHeadersVisible()
        self:UpdateScrollIndicator(self.list)

        -- Restore selection
        if currentCategory and self.list and self.list.dataList then
            local targetIndex = BETTERUI.CIM.PositionManager.RestorePosition("Companions", currentCategory.key, self.list, self.list.dataList)
            if self.list.SetSelectedIndex then
                self.list:SetSelectedIndex(targetIndex)
            end
        end

        -- Refresh multi-select visuals
        if Companions.multiSelectManager then
            Companions.multiSelectManager:RefreshSelections()
        end
    end)
    self._isRefreshing = false
    if not ok then
        return false, boundary.WrapError("RefreshList", result)
    end

    return true
end

function BETTERUI.Companions.Class:BuildEquippedItems(filterType)
    local list = self.list
    if not list then return end
    if not HasActiveCompanion or not HasActiveCompanion() then return end

    local bagSize = GetBagSize(BAG_COMPANION_WORN)
    if not bagSize or bagSize == 0 then return end

    local searchQuery = self.searchQuery
    if searchQuery and searchQuery ~= "" then
        searchQuery = zo_strlower(searchQuery)
    end

    for slotIndex = 0, bagSize - 1 do
        local matchesFilter, filterSlotData = self:DoesSlotMatchFilterType(BAG_COMPANION_WORN, slotIndex, filterType)
        if matchesFilter then
            -- GetItemInfo returns: icon, stack, sellPrice, meetsUsageRequirement,
            -- locked, equipType, itemStyleId, functionalQuality, displayQuality.
            local icon, stackCount, sellPrice, _, _,
                _equipType, _, functionalQuality, displayQuality = GetItemInfo(BAG_COMPANION_WORN, slotIndex)

            local name = GetItemName(BAG_COMPANION_WORN, slotIndex) or ""
            if name ~= "" then
                name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
                if not searchQuery or zo_strlower(name):find(searchQuery, 1, true) then
                    local quality = displayQuality or functionalQuality or ITEM_DISPLAY_QUALITY_NORMAL
                    local itemLink = GetItemLink(BAG_COMPANION_WORN, slotIndex)
                    local itemType = itemLink and GetItemLinkItemType(itemLink) or 0
                    -- Reuse the slot data the filter check generated for this
                    -- slot; regenerate only when the filter path skipped it
                    -- (never cached across inventory updates).
                    local slotData = filterSlotData
                        or (SHARED_INVENTORY and SHARED_INVENTORY.GenerateSingleSlotData
                            and SHARED_INVENTORY:GenerateSingleSlotData(BAG_COMPANION_WORN, slotIndex))

                    local entryData = {
                        name = name,
                        icon = icon,
                        stackCount = stackCount or 1,
                        sellPrice = sellPrice or 0,
                        stackSellPrice = (sellPrice or 0) * (stackCount or 1),
                        quality = quality,
                        bagId = BAG_COMPANION_WORN,
                        slotIndex = slotIndex,
                        -- Match native companionequipment_gamepad.lua (sets the slot type via
                        -- ZO_InventorySlot_SetType) so CIM.ProtectionPolicy.CanDestroyItem runs the
                        -- engine ZO_InventorySlot_CanDestroyItem eligibility probe instead of
                        -- skipping it on a nil slotType.
                        slotType = SLOT_TYPE_GAMEPAD_INVENTORY_ITEM,
                        isEquipped = true,
                        isEquippedInCurrentCategory = true,
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

                    local entry = ZO_GamepadEntryData:New(entryData.name, entryData.icon)
                    entry:SetDataSource(entryData)
                    entry.narrationText = function() return entryData.name end

                    if quality then
                        local r, g, b = GetItemQualityColor(quality):UnpackRGBA()
                        entry:SetNameColors(ZO_ColorDef:New(r, g, b, 1), ZO_ColorDef:New(r, g, b, 0.7))
                    end

                    self:ApplyMultiSelectVisual(entry, entryData)

                    local remaining, duration = GetItemCooldownInfo(BAG_COMPANION_WORN, slotIndex)
                    if remaining and remaining > 0 and duration and duration > 0 then
                        entry:SetCooldown(remaining, duration)
                    end

                    list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", entry)
                end
            end
        end
    end
end

function BETTERUI.Companions.Class:BuildBackpackItems(filterType)
    local list = self.list
    if not list then return end

    local bagSize = GetBagSize(BAG_BACKPACK) or 0
    local searchQuery = self.searchQuery
    if searchQuery and searchQuery ~= "" then
        searchQuery = zo_strlower(searchQuery)
    end

    for slotIndex = 0, bagSize - 1 do
        local icon, stackCount, sellPrice = GetItemInfo(BAG_BACKPACK, slotIndex)
        local actorCategory = GetItemActorCategory and GetItemActorCategory(BAG_BACKPACK, slotIndex)

        local matchesFilter, filterSlotData
        if actorCategory == GAMEPLAY_ACTOR_CATEGORY_COMPANION then
            matchesFilter, filterSlotData = self:DoesSlotMatchFilterType(BAG_BACKPACK, slotIndex, filterType)
        end

        if matchesFilter then
            local name = GetItemName(BAG_BACKPACK, slotIndex) or ""
            if name ~= "" then
                name = zo_strformat(SI_TOOLTIP_ITEM_NAME, name)
                if not searchQuery or zo_strlower(name):find(searchQuery, 1, true) then
                    local quality = GetItemDisplayQuality(BAG_BACKPACK, slotIndex) or ITEM_DISPLAY_QUALITY_NORMAL
                    local itemLink = GetItemLink(BAG_BACKPACK, slotIndex)
                    local itemType = itemLink and GetItemLinkItemType(itemLink) or 0
                    -- Reuse the slot data the filter check generated for this
                    -- slot; regenerate only when the filter path skipped it
                    -- (never cached across inventory updates).
                    local slotData = filterSlotData
                        or (SHARED_INVENTORY and SHARED_INVENTORY.GenerateSingleSlotData
                            and SHARED_INVENTORY:GenerateSingleSlotData(BAG_BACKPACK, slotIndex))
                    local equipSlot = Companions.ResolveCompanionEquipSlot(BAG_BACKPACK, slotIndex)

                    local entryData = {
                        name = name,
                        icon = icon,
                        stackCount = stackCount or 1,
                        sellPrice = sellPrice or 0,
                        stackSellPrice = (sellPrice or 0) * (stackCount or 1),
                        quality = quality,
                        bagId = BAG_BACKPACK,
                        slotIndex = slotIndex,
                        -- Match native companionequipment_gamepad.lua (sets the slot type via
                        -- ZO_InventorySlot_SetType) so CIM.ProtectionPolicy.CanDestroyItem runs the
                        -- engine ZO_InventorySlot_CanDestroyItem eligibility probe instead of
                        -- skipping it on a nil slotType.
                        slotType = SLOT_TYPE_GAMEPAD_INVENTORY_ITEM,
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

                    self:ApplyMultiSelectVisual(entry, entryData)

                    local remaining, duration = GetItemCooldownInfo(BAG_BACKPACK, slotIndex)
                    if remaining and remaining > 0 and duration and duration > 0 then
                        entry:SetCooldown(remaining, duration)
                    end

                    list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", entry)
                end
            end
        end
    end
end

function BETTERUI.Companions.Class:ApplyMultiSelectVisual(entry, entryData)
    local ms = Companions.multiSelectManager
    if ms and ms:IsActive() then
        local selected = ms:IsSelected(entryData)
        entry.isMultiSelected = selected
        if selected then
            entry.multiSelectBarColor = ZO_ColorDef:New(0.2, 0.8, 0.2)
        end
    else
        entry.isMultiSelected = false
    end
end
