--[[
---@module "Modules.Banking.Categories.CategoryManager"
File: Modules/Banking/Categories/CategoryManager.lua
Purpose: Centralizes banking category construction, matching, cycling, and header rebuilding.
]]

BETTERUI.Banking.CategoryManager = BETTERUI.Banking.CategoryManager or {}
local CategoryManager = BETTERUI.Banking.CategoryManager

local function DoesItemMatchBankCategory(itemData, category)
    return BETTERUI.CIM.SharedItemSupport.DoesItemMatchCategory(itemData, category)
end

function CategoryManager.ComputeVisibleBankCategories(self)
    local isFurnitureVault = BETTERUI.Banking.IsTransferTargetFurnitureVault()
    local allCategories = BETTERUI.Banking.BuildAllBankCategories(isFurnitureVault)
    local visibility = {}
    local itemCounts = {}

    for _, category in ipairs(allCategories) do
        visibility[category.key] = false
        itemCounts[category.key] = 0
    end
    if visibility["all"] ~= nil then
        visibility["all"] = true
    end

    local bags = BETTERUI.Banking.ResolveBagsAndSlotType(self)
    local function IsNotStolenItem(itemData)
        return not itemData.stolen
    end

    local data = SHARED_INVENTORY:GenerateFullSlotData(IsNotStolenItem, unpack(bags))
    local function IsJunkCategory(category)
        return category and (category.special == "junk" or category.furnitureVaultJunk == true)
    end

    local totalNonJunkItems = 0
    for i = 1, #data do
        local itemData = data[i]
        local isJunkItem = itemData and itemData.isJunk == true
        if not isJunkItem then
            totalNonJunkItems = totalNonJunkItems + 1
        end

        for _, category in ipairs(allCategories) do
            if category.key ~= "all" and DoesItemMatchBankCategory(itemData, category) then
                local categoryIsJunk = IsJunkCategory(category)
                local categoryCanMatchItem = (isJunkItem and categoryIsJunk) or ((not isJunkItem) and (not categoryIsJunk))
                if categoryCanMatchItem then
                    visibility[category.key] = true
                    itemCounts[category.key] = itemCounts[category.key] + 1
                end
            end
        end
    end
    if itemCounts["all"] ~= nil then
        itemCounts["all"] = totalNonJunkItems
    end

    local visibleCategories = {}
    for _, category in ipairs(allCategories) do
        if visibility[category.key] then
            category.itemCount = itemCounts[category.key]
            visibleCategories[#visibleCategories + 1] = category
        end
    end

    if isFurnitureVault and #visibleCategories == 0 and #allCategories > 0 then
        local furnishingCategory = allCategories[1]
        furnishingCategory.itemCount = 0
        visibleCategories[1] = furnishingCategory
    end

    return visibleCategories
end

function BETTERUI.Banking.Class.ComputeVisibleBankCategories(self)
    return CategoryManager.ComputeVisibleBankCategories(self)
end
