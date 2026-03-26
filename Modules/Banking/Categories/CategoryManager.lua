--[[
---@module "Modules.Banking.Categories.CategoryManager"
File: Modules/Banking/Categories/CategoryManager.lua
Purpose: Centralizes banking category construction, matching, cycling, and header rebuilding.
Author: BetterUI Team
]]

local LIST_WITHDRAW = BETTERUI.Banking.LIST_WITHDRAW
local BANK_CATEGORY_DEFS = BETTERUI.Banking.CATEGORY_DEFS

BETTERUI.Banking.CategoryManager = BETTERUI.Banking.CategoryManager or {}
local CategoryManager = BETTERUI.Banking.CategoryManager

local function BuildAllBankCategories(isFurnitureVault)
    if isFurnitureVault then
        return {
            { key = "all",        name = GetString(SI_BETTERUI_INV_ITEM_ALL),        filterType = nil,                       iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds" },
            { key = "furnishing", name = GetString(SI_BETTERUI_INV_ITEM_FURNISHING), filterType = ITEMFILTERTYPE_FURNISHING, iconFile = "EsoUI/Art/Crafting/Gamepad/gp_crafting_menuicon_furnishings.dds" },
        }
    end

    local out = {}
    for i = 1, #BANK_CATEGORY_DEFS do
        local def = BANK_CATEGORY_DEFS[i]
        if not def.optional or (def.optional and def.filterType ~= nil) then
            out[#out + 1] = {
                key = def.key,
                name = GetString(def.nameStringId),
                filterType = def.filterType,
                special = def.special,
                iconFile = def.iconFile,
            }
        end
    end
    return out
end

local function DoesItemMatchBankCategory(itemData, category)
    return BETTERUI.Inventory.Categories.DoesItemMatchCategory(itemData, category)
end

local function ResolveBagsAndSlotType(self)
    local currentUsedBank = BETTERUI.Banking.currentUsedBank
    local GuildBank = BETTERUI.Banking.GuildBank
    if GuildBank and GuildBank.IsGuildBankMode() then
        if self.currentMode == LIST_WITHDRAW then
            return { BAG_GUILDBANK }, SLOT_TYPE_GUILD_BANK_ITEM
        else
            return { BAG_BACKPACK }, SLOT_TYPE_GAMEPAD_INVENTORY_ITEM
        end
    end
    if self.currentMode == LIST_WITHDRAW then
        local bags
        if currentUsedBank == BAG_BANK then
            bags = { BAG_BANK, BAG_SUBSCRIBER_BANK }
        else
            bags = { currentUsedBank }
        end
        return bags, SLOT_TYPE_BANK_ITEM
    else
        return { BAG_BACKPACK }, SLOT_TYPE_GAMEPAD_INVENTORY_ITEM
    end
end

function CategoryManager.ComputeVisibleBankCategories(self)
    local isFurnitureVault = IsFurnitureVault(GetBankingBag())
    local allCategories = BuildAllBankCategories(isFurnitureVault)
    local visibility = {}
    local itemCounts = {}

    for _, category in ipairs(allCategories) do
        visibility[category.key] = false
        itemCounts[category.key] = 0
    end
    visibility["all"] = true

    local bags = ResolveBagsAndSlotType(self)
    local function IsNotStolenItem(itemData)
        return not itemData.stolen
    end

    local data = SHARED_INVENTORY:GenerateFullSlotData(IsNotStolenItem, unpack(bags))
    local totalItems = 0
    for i = 1, #data do
        local itemData = data[i]
        totalItems = totalItems + 1
        for _, category in ipairs(allCategories) do
            if category.key ~= "all" and DoesItemMatchBankCategory(itemData, category) then
                visibility[category.key] = true
                itemCounts[category.key] = itemCounts[category.key] + 1
            end
        end
    end
    itemCounts["all"] = totalItems

    local visibleCategories = {}
    for _, category in ipairs(allCategories) do
        if visibility[category.key] then
            category.itemCount = itemCounts[category.key]
            visibleCategories[#visibleCategories + 1] = category
        end
    end
    return visibleCategories
end

function BETTERUI.Banking.Class.ComputeVisibleBankCategories(self)
    return CategoryManager.ComputeVisibleBankCategories(self)
end

function BETTERUI.Banking.Class:CycleCategory(delta)
    BETTERUI.CIM.HeaderNavigation.CycleCategory(self, delta, {
        categories = self.bankCategories,
        getCurrentIndex = function() return self.currentCategoryIndex or 1 end,
        setCurrentIndex = function(idx) self.currentCategoryIndex = idx end,
        tabBar = self.headerGeneric and self.headerGeneric.tabBar,
        onRefresh = function() self:RefreshList() end,
    })
end

function BETTERUI.Banking.Class:UpdateHeaderTitle()
    local cat = (self.bankCategories and self.bankCategories[self.currentCategoryIndex or 1]) or nil
    if cat and cat.name then
        self:SetTitle(zo_strformat("<<1>>", cat.name))
    else
        self.titleControl:SetText(GetString(SI_BETTERUI_BANK_TITLE))
    end
    if self.PositionSearchControl then
        self:PositionSearchControl()
    end
end

function BETTERUI.Banking.Class:EnsureHeaderKeybindsActive()
    local tabBar = self.headerGeneric and self.headerGeneric.tabBar
    if tabBar and tabBar.keybindStripDescriptor then
        tabBar:Activate()
    end
end

function BETTERUI.Banking.Class:RebuildHeaderCategories()
    if not (self.header and self.bankCategories) then return end
    self.bankHeaderData = self.bankHeaderData or {}
    self.bankHeaderData.titleText = function()
        local cat = (self.bankCategories and self.bankCategories[self.currentCategoryIndex or 1]) or nil
        return (cat and cat.name) or GetString(SI_BETTERUI_INV_ITEM_ALL)
    end
    self.bankHeaderData.tabBarData = { parent = self }
    local isCarousel = BETTERUI.Settings.Modules["Banking"].enableCarousel
    self.bankHeaderData.carouselConfig = {
        enabled = isCarousel,
        startOffset = BETTERUI.Banking.CONST.CAROUSEL.startOffset,
        verticalOffset = BETTERUI.Banking.CONST.CAROUSEL.verticalOffset,
        itemSpacing = BETTERUI.CIM.CONST.CAROUSEL.itemSpacing,
    }

    local coalescedHandler = BETTERUI.CIM.HeaderNavigation.CreateCoalescedHandler({
        delay = BETTERUI.CIM.CONST.TIMING.CATEGORY_CHANGE_DELAY_MS,
        onSave = function(instance) instance:SaveListPosition() end,
        onApply = function(instance, newIndex)
            instance.currentCategoryIndex = newIndex
            instance:UpdateHeaderTitle()
            instance:RefreshList()
        end,
        sceneCheck = function()
            return BETTERUI.CIM.Utils.IsBankingSceneShowing()
        end,
    })
    self.bankHeaderData.onSelectedChanged = function(list, selectedData)
        coalescedHandler(self, list, selectedData)
    end

    if not self.headerGeneric.tabBar then
        BETTERUI.GenericHeader.Refresh(self.headerGeneric, self.bankHeaderData, false)
    end
    if self.headerGeneric.tabBar then
        self.headerGeneric.tabBar:Clear()
    end
    for i = 1, #self.bankCategories do
        local cat = self.bankCategories[i]
        local entryData = ZO_GamepadEntryData:New(cat.name, cat.iconFile)
        entryData.filterType = cat.filterType
        entryData.itemCount = cat.itemCount
        entryData.countBadgeOffsetY = 3
        entryData:SetIconTintOnSelection(true)
        BETTERUI.GenericHeader.AddToList(self.headerGeneric, entryData)
    end
    BETTERUI.GenericHeader.Refresh(self.headerGeneric, self.bankHeaderData, false)

    if self.headerGeneric.tabBar then
        local idx = zo_clamp(self.currentCategoryIndex or 1, 1, #self.bankCategories)
        local state = BETTERUI.CIM.HeaderNavigation.GetOrCreateState(self)
        if state.justToggledMode then
            self.headerGeneric.tabBar:SetSelectedIndexWithoutAnimation(idx, true, true)
        else
            state.suppressHeaderCallback = true
            self.headerGeneric.tabBar:SetSelectedIndex(idx, true, true)
            state.suppressHeaderCallback = false
        end
    end

    self:UpdateHeaderTitle()
    if self.scene and self.scene:IsShowing() then
        self:EnsureHeaderKeybindsActive()
    end

    if ZO_GamepadGenericHeader_SetHeaderFocusControl and self.textSearchHeaderControl then
        local headerTarget
        if self.headerGeneric and self.headerGeneric.tabBar and self.headerGeneric.tabBar.control then
            headerTarget = self.headerGeneric.tabBar.control
        elseif self.headerGeneric then
            headerTarget = self.headerGeneric
        else
            headerTarget = self.header
        end
        ZO_GamepadGenericHeader_SetHeaderFocusControl(headerTarget, self.textSearchHeaderControl)
    end
end
