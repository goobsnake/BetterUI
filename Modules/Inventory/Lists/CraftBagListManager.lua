--[[
File: Modules/Inventory/Lists/CraftBagListManager.lua
Purpose: Manages the Craft Bag list for the Inventory module.
Author: BetterUI Team
]]

local function MenuEntryTemplateEquality(left, right)
    return left.uniqueId == right.uniqueId
end

local function SetupCraftBagList(buiList)
    buiList.list:AddDataTemplate(
        "BETTERUI_GamepadItemSubEntryTemplate",
        BETTERUI_SharedGamepadEntry_OnSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction,
        MenuEntryTemplateEquality
    )
    buiList.list:AddDataTemplateWithHeader(
        "BETTERUI_GamepadItemSubEntryTemplate",
        BETTERUI_SharedGamepadEntry_OnSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction,
        MenuEntryTemplateEquality,
        "ZO_GamepadMenuEntryHeaderTemplate"
    )
end

-- Safe helper for GetTargetData calls (guards against lists without method)
-- Duplicated locally to avoid tight coupling
local function SafeGetTargetData(list)
    if not list then return nil end
    if list.GetTargetData and type(list.GetTargetData) == "function" then
        return list:GetTargetData()
    end
    return list.selectedData
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
                self.craftBagList:RefreshVisible()
            end
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
end

--- Refreshes the Craft Bag list content.
function BETTERUI.Inventory.Class:RefreshCraftBagList()
    -- we need to pass in our current filterType, as refreshing the craft bag list is distinct from the item list's methods (only slightly)
    local craftCategoryTarget = SafeGetTargetData(self.categoryList)
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
