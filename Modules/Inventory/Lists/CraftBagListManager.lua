--[[
File: Modules/Inventory/Lists/CraftBagListManager.lua
Purpose: Manages the Craft Bag list for the Inventory module.
Author: BetterUI Team
]]

local function MenuEntryTemplateEquality(left, right)
    return left.uniqueId == right.uniqueId
end

--- Setup function wrapper that binds SLOT_TYPE_CRAFT_BAG_ITEM before rendering.
--- Without this, ZO_InventorySlot_GetType returns nil and IsSlotInCraftBag fails,
--- causing the "Retrieve" action to never appear.
local function CraftBagEntrySetup(control, data, selected, selectedDuringRebuild, enabled, activated)
    -- Bind the slot type BEFORE rendering so action discovery works correctly
    ZO_Inventory_BindSlot(data, SLOT_TYPE_CRAFT_BAG_ITEM, data.slotIndex, data.bagId)
    BETTERUI_SharedGamepadEntry_OnSetup(control, data, selected, selectedDuringRebuild, enabled, activated)
end

local function SetupCraftBagList(buiList)
    buiList.list:AddDataTemplate(
        "BETTERUI_GamepadItemSubEntryTemplate",
        CraftBagEntrySetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction,
        MenuEntryTemplateEquality
    )
    buiList.list:AddDataTemplateWithHeader(
        "BETTERUI_GamepadItemSubEntryTemplate",
        CraftBagEntrySetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction,
        MenuEntryTemplateEquality,
        "ZO_GamepadMenuEntryHeaderTemplate"
    )
end




--- Initializes the craft bag list.
--- Purpose: Sets up the visual scroll list for the craft bag.
function BETTERUI.Inventory.Class:InitializeCraftBagList()
    local function OnSelectedDataCallback(list, selectedData)
        if selectedData ~= nil and self.scene:IsShowing() then
            self.currentlySelectedData = selectedData
            self:UpdateItemLeftTooltip(selectedData)

            local currentList = self:GetCurrentList()
            if currentList == self.craftBagList or ZO_Dialogs_IsShowing(ZO_GAMEPAD_INVENTORY_ACTION_DIALOG) then
                self:SetSelectedInventoryData(selectedData)
                -- Ensure selectedItemUniqueId is set for craftbag items (needed for Y-button visibility)
                self:SetSelectedItemUniqueId(selectedData)
                self.craftBagList:RefreshVisible()
            end
            -- Keybind Refresh - protected by RefreshKeybinds() override
            self:RefreshKeybinds()
        end
    end

    self.craftBagList = self:AddList(
        "CraftBag",
        SetupCraftBagList,
        BETTERUI.Inventory.CraftList,
        BAG_VIRTUAL,
        SLOT_TYPE_CRAFT_BAG_ITEM,
        OnSelectedDataCallback,
        nil,
        nil,
        nil,
        false,
        "BETTERUI_GamepadItemSubEntryTemplate"
    )
    self.craftBagList:SetNoItemText(GetString(SI_GAMEPAD_INVENTORY_CRAFT_BAG_EMPTY))
    self.craftBagList:SetAlignToScreenCenter(true, 30)

    self.craftBagList:SetSortFunction(BETTERUI_CraftList_DefaultItemSortComparator)

    -- Initialize craftbag multi-select manager
    if not self.craftBagMultiSelectManager then
        self.craftBagMultiSelectManager = BETTERUI.CIM.MultiSelectManager.Create(
            self.craftBagList,
            function(selectedCount)
                self:OnCraftBagSelectionCountChanged(selectedCount)
            end
        )
    end
end

--- Refreshes the Craft Bag list content.
function BETTERUI.Inventory.Class:RefreshCraftBagList()
    if self:IsBatchProcessing() and self.batchSuppressUiUpdates then
        return
    end

    -- we need to pass in our current filterType, as refreshing the craft bag list is distinct from the item list's methods (only slightly)
    local craftCategoryTarget = BETTERUI.Inventory.Utils.SafeGetTargetData(self.categoryList)
    local craftFilter = craftCategoryTarget and craftCategoryTarget.filterType or nil
    self.craftBagList:RefreshList(craftFilter, self.searchQuery)
end

--- Configure the tooltip for the Craft Bag header.
function BETTERUI.Inventory.Class:LayoutCraftBagTooltip()
    local title
    local description
    if HasCraftBagAccess() then
        title = GetString(SI_ESO_PLUS_STATUS_UNLOCKED)
        description = GetString(SI_CRAFT_BAG_STATUS_ESO_PLUS_UNLOCKED_DESCRIPTION)
    else
        title = GetString(SI_ESO_PLUS_STATUS_LOCKED)
        description = GetString(SI_CRAFT_BAG_STATUS_LOCKED_DESCRIPTION)
    end

    GAMEPAD_TOOLTIPS:LayoutTitleAndDescriptionTooltip(GAMEPAD_LEFT_TOOLTIP, title, description)
end

--- Counts items in the Craft Bag matching a filter type for category badge display.
--- @param filterType number|nil The crafting filter type (nil = All)
--- @return number count The number of matching items
function BETTERUI.Inventory.Class:GetCraftBagCategoryItemCount(filterType)
    local count = 0
    local virtualItems = SHARED_INVENTORY:GetBagCache(BAG_VIRTUAL)
    if virtualItems then
        for _, itemData in pairs(virtualItems) do
            if filterType == nil then
                -- "All" category - count everything
                count = count + 1
            elseif ZO_InventoryUtils_DoesNewItemMatchFilterType(itemData, filterType) then
                count = count + 1
            end
        end
    end
    return count
end
