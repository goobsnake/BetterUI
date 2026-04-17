--[[
File: Modules/Vendor/Components/SellComponent.lua
Purpose: Sell tab component for the Vendor module.

Handles listing inventory items that can be sold and selling them.
Includes batch junk sell support (Sell All Junk keybind).
]]

local Vendor = BETTERUI.Vendor

-- COMPONENT TABLE
Vendor.SellComponent = {}
local Sell = Vendor.SellComponent

local SELL_CATEGORY_DEFS = BETTERUI.CIM.ItemTaxonomy.VENDOR_SELL_CATEGORY_DEFS

local function BuildSellableBagItems()
    local rows = {}
    local bagItems = SHARED_INVENTORY and SHARED_INVENTORY:GenerateFullSlotData(nil, BAG_BACKPACK)
    if not bagItems then
        return rows
    end

    for _, itemData in pairs(bagItems) do
        local slot = itemData
        local sellPrice = slot.sellPrice or (slot.stackSellPrice and slot.stackSellPrice) or 0
        local isStolen = IsItemStolen and IsItemStolen(slot.bagId, slot.slotIndex)
        if sellPrice > 0 and not isStolen then
            rows[#rows + 1] = slot
        end
    end

    return rows
end

local function MatchesCategory(slotData, category)
    if not category or category.key == "all" then
        return true
    end

    local sharedItemSupport = BETTERUI.CIM and BETTERUI.CIM.SharedItemSupport
    if sharedItemSupport and sharedItemSupport.DoesItemMatchCategory then
        return sharedItemSupport.DoesItemMatchCategory(slotData, category)
    end

    if category.special == "junk" then
        return slotData.isJunk == true
    end

    if category.filterType then
        return ZO_InventoryUtils_DoesNewItemMatchFilterType(slotData, category.filterType)
    end

    return true
end

---@param itemCount number
---@return table[]
local function BuildAllOnlyCategory(itemCount)
    return {
        {
            key = "all",
            name = GetString(rawget(_G, "SI_BETTERUI_INV_ITEM_ALL") or "SI_BETTERUI_INV_ITEM_ALL"),
            iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds",
            itemCount = itemCount or 0,
        },
    }
end

---@param _vendorInstance BETTERUI.Vendor.Class
---@return table[]
function Sell:GetCategories(vendorInstance)
    local rows = BuildSellableBagItems()
    local totalCount = #rows

    if vendorInstance and vendorInstance.IsSellBuybackOnlyStore and vendorInstance:IsSellBuybackOnlyStore() then
        return BuildAllOnlyCategory(totalCount)
    end

    local categories = {}

    for _, def in ipairs(SELL_CATEGORY_DEFS) do
        local count = 0
        if def.key == "all" then
            count = totalCount
        else
            for _, row in ipairs(rows) do
                if MatchesCategory(row, def) then
                    count = count + 1
                end
            end
        end

        if def.key == "all" or count > 0 then
            categories[#categories + 1] = {
                key = def.key,
                name = GetString(rawget(_G, def.nameStringId) or def.nameStringId),
                iconFile = def.iconFile,
                filterType = def.filterType,
                special = def.special,
                itemCount = count,
            }
        end
    end

    if #categories == 0 then
        return BuildAllOnlyCategory(0)
    end

    return categories
end

-- ACTIVATE / DEACTIVATE

---@param vendorInstance BETTERUI.Vendor.Class
function Sell:Activate(vendorInstance)
    vendorInstance:RefreshList()
end

---@param vendorInstance BETTERUI.Vendor.Class
function Sell:Deactivate(vendorInstance)
    -- No cleanup needed
end

-- PRIMARY ACTION

---@return string name Localized sell action label
function Sell:GetPrimaryActionName()
    return GetString(rawget(_G, "SI_ITEM_ACTION_SELL"))
end

---@param vendorInstance BETTERUI.Vendor.Class
---@return boolean enabled True if the selected item can be sold
function Sell:IsPrimaryActionEnabled(vendorInstance)
    local selectedData = vendorInstance.list and vendorInstance.list:GetSelectedData()
    if not selectedData then return false end
    local ds = selectedData.dataSource or selectedData

    -- Cannot sell stolen items to a regular vendor
    local isStolen = ds.stolen == true
    if isStolen then return false end

    -- Check that item has a sell price
    local sellPrice = ds.sellPrice or ds.stackSellPrice or 0
    return sellPrice > 0
end

---@param vendorInstance BETTERUI.Vendor.Class
function Sell:OnPrimaryAction(vendorInstance)
    local selectedData = vendorInstance.list and vendorInstance.list:GetSelectedData()
    if not selectedData then return end
    local ds = selectedData.dataSource or selectedData

    local bagId = ds.bagId
    local slotIndex = ds.slotIndex
    if bagId == nil or slotIndex == nil then return end

    -- Validate the slot still has items
    local stackSize = GetSlotStackSize(bagId, slotIndex) or 0
    if stackSize <= 0 then return end

    -- Use full stack for sell
    SellInventoryItem(bagId, slotIndex, stackSize)
end

-- BATCH JUNK SELL

---@param vendorInstance BETTERUI.Vendor.Class
function Sell:SellAllJunk(vendorInstance)
    local _, itemCount = Vendor.GetJunkSellSummary()
    if itemCount <= 0 then
        BETTERUI.CIM.UserAlertText("Sell:NoJunk",
            GetString(rawget(_G, "SI_BETTERUI_VENDOR_NO_JUNK")))
        return
    end

    -- Suppress list updating during batch sell, then flush
    vendorInstance:SuppressListUpdates()

    local bagSize = GetBagSize(BAG_BACKPACK) or 0
    for slot = 0, bagSize - 1 do
        if IsItemJunk(BAG_BACKPACK, slot) then
            local stack = GetSlotStackSize(BAG_BACKPACK, slot) or 1
            if stack > 0 then
                SellInventoryItem(BAG_BACKPACK, slot, stack)
            end
        end
    end

    vendorInstance:FlushListUpdates()
end


-- LIST BUILDING

---@param vendorInstance BETTERUI.Vendor.Class
function Sell:BuildList(vendorInstance)
    local list = vendorInstance.list
    if not list then return end

    local rows = BuildSellableBagItems()
    if #rows == 0 then return end

    local activeCategory = vendorInstance:GetCurrentCategory()
    local searchQuery = Vendor.GetNormalizedSearchQuery and Vendor.GetNormalizedSearchQuery(vendorInstance) or nil
    for _, slot in ipairs(rows) do
        local searchName = slot.name or GetItemName(slot.bagId, slot.slotIndex)
        if MatchesCategory(slot, activeCategory)
            and (not Vendor.MatchesSearchQuery or Vendor.MatchesSearchQuery(searchQuery, searchName))
        then
            local sellPrice = slot.sellPrice or (slot.stackSellPrice and slot.stackSellPrice) or 0

            local name = slot.name or zo_strformat(SI_TOOLTIP_ITEM_NAME,
                GetItemName(slot.bagId, slot.slotIndex))
            local icon = slot.iconFile
            if not icon then
                icon = GetItemInfo(slot.bagId, slot.slotIndex)
            end
            local quality = slot.displayQuality or slot.quality or ITEM_DISPLAY_QUALITY_NORMAL
            local perItemSellPrice = GetItemSellValueWithBonuses(slot.bagId, slot.slotIndex) or sellPrice or 0

            local entryData = {
                name             = name,
                icon             = icon,
                stackCount       = slot.stackCount or 1,
                sellPrice        = sellPrice,
                stackSellPrice   = perItemSellPrice * (slot.stackCount or 1),
                quality          = quality,
                bagId            = slot.bagId,
                slotIndex        = slot.slotIndex,
                stolen           = false,
                isJunk           = IsItemJunk(slot.bagId, slot.slotIndex),
                itemLink         = GetItemLink(slot.bagId, slot.slotIndex),
                bestGamepadItemCategoryName = slot.bestGamepadItemCategoryName or "",
                statValue        = slot.statValue or "",
            }

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
