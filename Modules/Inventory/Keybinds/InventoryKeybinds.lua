--[[
File: Modules/Inventory/Keybinds/InventoryKeybinds.lua
Purpose: Defines the main inventory keybind strip and shared item-list helpers.
]]

local InventoryConst = BETTERUI.Inventory.CONST
local InventoryKeybinds = BETTERUI.Inventory.Keybinds

-- Shared implementation lives in Modules/CIM/Keybinds/ActionContext.lua (CIM loads before Inventory).
InventoryKeybinds.IsQuickslottable = BETTERUI.CIM.IsQuickslottable

local function TraceInventoryKeybind(self, keybind, phase, data)
    local L = BETTERUI.Log
    if not (L and L.TraceEvent) then return end
    data = data or {}
    data.scope = "inventory"
    data.keybind = keybind
    data.mode = self and self.actionMode
    data.headerSort = self and self.isInHeaderSortMode == true
    data.batch = self and self.IsBatchProcessing and self:IsBatchProcessing() == true
    local list = self and self.GetCurrentList and self:GetCurrentList() or nil
    data.selection = L.DescribeListSelection and L.DescribeListSelection(list, "current") or nil
    L.TraceEvent(L.CATEGORY.KEYBIND, "keybind.callback", phase, data)
end

local function RunInventoryKeybind(self, keybind, action, callback)
    TraceInventoryKeybind(self, keybind, "start", { action = action })
    local r1, r2, r3 = callback()
    TraceInventoryKeybind(self, keybind, "end", { action = action, handled = true })
    return r1, r2, r3
end

--- Initializes the main inventory keybind strip.
---@return nil
function BETTERUI.Inventory.Class:InitializeKeybindStrip()
    if BETTERUI.Log then BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.KEYBIND, "Inventory keybind strip initialized") end
    if not self.multiSelectManager then
        self.multiSelectManager = BETTERUI.CIM.MultiSelectManager.Create(
            self.itemList,
            function(selectedCount)
                self:OnSelectionCountChanged(selectedCount)
            end
        )
    end

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
                return RunInventoryKeybind(self, "UI_SHORTCUT_PRIMARY", "primary", function()
                    InventoryKeybinds.HandlePrimaryKeybind(self)
                end)
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
                return RunInventoryKeybind(self, "UI_SHORTCUT_SECONDARY", "secondary", function()
                    InventoryKeybinds.HandleSecondaryKeybind(self)
                end)
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
                return RunInventoryKeybind(self, "UI_SHORTCUT_TERTIARY", "tertiary", function()
                    InventoryKeybinds.HandleTertiaryKeybind(self)
                end)
            end,
        },
        BETTERUI.CIM.Keybinds.CreateStackAllKeybind(
            BAG_BACKPACK,
            function()
                return self.actionMode == InventoryConst.ITEM_LIST_ACTION_MODE
                    and not InventoryKeybinds.IsBagUpgradeCategorySelected(self)
                    and not self:IsBatchProcessing()
            end
        ),
        {
            name = function()
                if not self.craftBagList then return "" end
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
                    and not InventoryKeybinds.IsBagUpgradeCategorySelected(self)
            end,
            callback = function()
                return RunInventoryKeybind(self, "UI_SHORTCUT_RIGHT_STICK", "switch_inventory_craftbag", function()
                    if self:IsBatchProcessing() then
                        return
                    end
                    self:Switch()
                end)
            end,
        },
        BETTERUI.CIM.Keybinds.CreateClearSearchKeybind(
            function()
                if not (self.textSearchHeaderControl and not self.textSearchHeaderControl:IsHidden()) then
                    return
                end

                local searchMixin = BETTERUI.Interface and BETTERUI.Interface.SearchMixin
                if searchMixin and searchMixin.CallSearchLifecycle then
                    searchMixin.CallSearchLifecycle(self, "clear")
                elseif self.ClearSearchInput then
                    self:ClearSearchInput()
                end

                if self._searchModeActive then
                    if searchMixin and searchMixin.CallSearchLifecycle then
                        searchMixin.CallSearchLifecycle(self, "exit")
                    elseif self.ExitSearchMode then
                        self:ExitSearchMode()
                    end
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
            name = BETTERUI.CIM.Keybinds.GetMultiSelectLabel(),
            keybind = "UI_SHORTCUT_QUINARY",
            visible = function()
                return InventoryKeybinds.IsMultiSelectEntryVisible(self)
            end,
            callback = function()
                return RunInventoryKeybind(self, "UI_SHORTCUT_QUINARY", "multi_select", function()
                    InventoryKeybinds.HandleMultiSelectEntry(self)
                end)
            end,
        },
    }

    local leftTrigger, rightTrigger = BETTERUI.CIM.Keybinds.CreateListTriggerKeybinds({
        list = function()
            local currentList = self:GetCurrentList()
            if currentList == self.itemList or currentList == self.craftBagList then
                return currentList
            end
        end,
        getSpeed = function()
            return BETTERUI.Inventory.GetSetting("triggerSpeed")
        end,
        isEnabled = function()
            return BETTERUI.Inventory.GetSetting("useTriggersForSkip")
        end,
    })

    table.insert(self.mainKeybindStripDescriptor, leftTrigger)
    table.insert(self.mainKeybindStripDescriptor, rightTrigger)
    ZO_Gamepad_AddBackNavigationKeybindDescriptors(self.mainKeybindStripDescriptor, GAME_NAVIGATION_TYPE_BUTTON)
    if BETTERUI.Log then
        BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.KEYBIND, "inventory main keybind descriptor created", {
            fn = "Inventory:InitializeKeybindStrip",
            main = BETTERUI.Log.DescribeKeybindDescriptor and BETTERUI.Log.DescribeKeybindDescriptor(self.mainKeybindStripDescriptor, "main") or nil,
        })
    end
end
