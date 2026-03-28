--[[
File: Modules/Inventory/Keybinds/InventoryKeybinds.lua
Purpose: Defines the main inventory keybind strip and shared item-list helpers.
]]

local InventoryConst = BETTERUI.Inventory.CONST
local InventoryKeybinds = BETTERUI.Inventory.Keybinds

--- @param slotData table
--- @return boolean
local function IsQuickslottable(slotData)
    if not slotData or not slotData.bagId or not slotData.slotIndex then
        return false
    end

    local bagId, slotIndex = slotData.bagId, slotData.slotIndex
    if FindActionSlotMatchingItem
        and FindActionSlotMatchingItem(bagId, slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) then
        return true
    end

    if ZO_InventoryUtils_DoesNewItemMatchFilterType then
        if ZO_InventoryUtils_DoesNewItemMatchFilterType(slotData, ITEMFILTERTYPE_QUICKSLOT) then
            return true
        end

        if ITEMFILTERTYPE_QUEST_QUICKSLOT
            and ZO_InventoryUtils_DoesNewItemMatchFilterType(slotData, ITEMFILTERTYPE_QUEST_QUICKSLOT) then
            return true
        end
    end

    if IsValidItemForSlot and IsValidItemForSlot(bagId, slotIndex, HOTBAR_CATEGORY_QUICKSLOT_WHEEL) then
        return true
    end

    return false
end

--- @param self Control
--- @return table|nil
local function GetXButtonActionContext(self)
    if self.actionMode ~= InventoryConst.ITEM_LIST_ACTION_MODE then
        return nil
    end

    local target = self.itemList.selectedData
    if not target then
        return nil
    end

    local filterType
    if target.bagId and target.slotIndex then
        filterType = GetItemFilterTypeInfo(target.bagId, target.slotIndex)
    end

    local isQuestItem = ZO_InventoryUtils_DoesNewItemMatchFilterType
        and ZO_InventoryUtils_DoesNewItemMatchFilterType(target, ITEMFILTERTYPE_QUEST)
        or false

    local isEquipment = filterType == ITEMFILTERTYPE_WEAPONS
        or filterType == ITEMFILTERTYPE_ARMOR
        or filterType == ITEMFILTERTYPE_JEWELRY

    return {
        target = target,
        isQuestItem = isQuestItem,
        isQuickslottable = IsQuickslottable(target),
        filterType = filterType,
        isEquipment = isEquipment,
        isUsableQuest = isQuestItem and target.meetsUsageRequirement or false,
    }
end

InventoryKeybinds.IsQuickslottable = IsQuickslottable
InventoryKeybinds.GetXButtonActionContext = GetXButtonActionContext

--- Initializes the main inventory keybind strip.
function BETTERUI.Inventory.Class:InitializeKeybindStrip()
    if not self.multiSelectManager then
        self.multiSelectManager = BETTERUI.CIM.MultiSelectManager.Create(
            self.itemList,
            function(selectedCount)
                self:OnSelectionCountChanged(selectedCount)
            end
        )

        BETTERUI.CIM.MultiSelectMixin.Apply(self, {
            getList = function(s)
                return s.itemList
            end,
            refreshList = function(s)
                s:RefreshItemList()
            end,
            isSceneShowing = function()
                return BETTERUI.Utils.IsInventorySceneShowing()
            end,
            getSceneExitLabel = function()
                return GetString(rawget(_G, "SI_BETTERUI_SCENE_INVENTORY"))
            end,
            refreshKeybinds = function(s)
                if s.isInHeaderSortMode then
                    return
                end

                if s:IsBatchProcessing() then
                    if s.mainKeybindStripDescriptor then
                        KEYBIND_STRIP:UpdateKeybindButtonGroup(s.mainKeybindStripDescriptor)
                    end
                    return
                end

                s:RefreshKeybinds()
            end,
        })
    end

    self.mainKeybindStripDescriptor = {
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = function()
                return InventoryKeybinds.GetPrimaryKeybindName(self)
            end,
            keybind = "UI_SHORTCUT_PRIMARY",
            visible = function()
                return InventoryKeybinds.IsPrimaryKeybindVisible(self)
            end,
            callback = function()
                InventoryKeybinds.HandlePrimaryKeybind(self)
            end,
        },
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = function()
                return InventoryKeybinds.GetSecondaryKeybindName(self)
            end,
            keybind = "UI_SHORTCUT_SECONDARY",
            visible = function()
                return InventoryKeybinds.IsSecondaryKeybindVisible(self)
            end,
            callback = function()
                InventoryKeybinds.HandleSecondaryKeybind(self)
            end,
        },
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = function()
                if self:IsBatchProcessing() then
                    return GetString(rawget(_G, "SI_BETTERUI_ABORT_ACTION"))
                end

                return GetString(rawget(_G, "SI_GAMEPAD_INVENTORY_ACTION_LIST_KEYBIND"))
            end,
            keybind = "UI_SHORTCUT_TERTIARY",
            visible = function()
                return InventoryKeybinds.IsTertiaryKeybindVisible(self)
            end,
            callback = function()
                InventoryKeybinds.HandleTertiaryKeybind(self)
            end,
        },
        BETTERUI.CIM.Keybinds.CreateStackAllKeybind(
            BAG_BACKPACK,
            function()
                return self.actionMode == InventoryConst.ITEM_LIST_ACTION_MODE
                    and not self:IsBatchProcessing()
            end
        ),
        {
            name = function()
                local targetStringId = self:GetCurrentList() == self.craftBagList
                    and SI_BETTERUI_INV_ACTION_INV
                    or SI_BETTERUI_INV_ACTION_CB

                return zo_strformat(
                    GetString(rawget(_G, "SI_BETTERUI_INV_ACTION_TO_TEMPLATE")),
                    GetString(targetStringId)
                ) or ""
            end,
            alignment = KEYBIND_STRIP_ALIGN_RIGHT,
            keybind = "UI_SHORTCUT_RIGHT_STICK",
            disabledDuringSceneHiding = true,
            visible = function()
                return not self:IsBatchProcessing()
            end,
            callback = function()
                if self:IsBatchProcessing() then
                    return
                end
                self:Switch()
            end,
        },
        BETTERUI.CIM.Keybinds.CreateClearSearchKeybind(
            function()
                if not (self.textSearchHeaderControl and not self.textSearchHeaderControl:IsHidden()) then
                    return
                end

                if self.ClearTextSearch then
                    self:ClearTextSearch()
                end

                if self._searchModeActive then
                    self:ExitSearchFocus()
                elseif not self.isInHeaderSortMode then
                    self:RefreshKeybinds()
                end
            end,
            function()
                return self.textSearchHeaderControl ~= nil
            end,
            function()
                return self.searchQuery and self.searchQuery ~= ""
            end
        ),
        {
            alignment = KEYBIND_STRIP_ALIGN_LEFT,
            name = GetString(rawget(_G, "SI_BETTERUI_MULTI_SELECT")),
            keybind = "UI_SHORTCUT_QUINARY",
            visible = function()
                return InventoryKeybinds.IsMultiSelectEntryVisible(self)
            end,
            callback = function()
                InventoryKeybinds.HandleMultiSelectEntry(self)
            end,
        },
    }

    local leftTrigger, rightTrigger = BETTERUI.CIM.Keybinds.CreateListTriggerKeybinds(
        function()
            local currentList = self:GetCurrentList()
            if currentList == self.itemList or currentList == self.craftBagList then
                return currentList
            end
        end,
        nil,
        function()
            return BETTERUI.Inventory.GetSetting("triggerSpeed")
        end,
        function()
            return BETTERUI.Inventory.GetSetting("useTriggersForSkip")
        end
    )

    table.insert(self.mainKeybindStripDescriptor, leftTrigger)
    table.insert(self.mainKeybindStripDescriptor, rightTrigger)
    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.mainKeybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON)
end
