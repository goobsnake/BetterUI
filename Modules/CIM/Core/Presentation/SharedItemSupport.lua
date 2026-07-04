--[[
File: Modules/CIM/Core/Presentation/SharedItemSupport.lua
Purpose: Neutral shared seams for item presentation and tooltip behavior.
         Lets sibling modules consume shared item helpers without reaching
         through Inventory-owned namespaces.
]]

BETTERUI = BETTERUI or {}
BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.SharedItemSupport = BETTERUI.CIM.SharedItemSupport or {}

local SharedItemSupport = BETTERUI.CIM.SharedItemSupport

local categorySupport = {}
local tooltipSupport = {}

local function GetModuleNamespace(moduleName)
    if type(moduleName) ~= "string" or moduleName == "" then
        return nil
    end
    return BETTERUI[moduleName]
end

local function ResolveDescriptor(moduleName, descriptorName)
    local namespace = GetModuleNamespace(moduleName)
    local descriptor = namespace and namespace[descriptorName]
    if type(descriptor) == "function" then
        return descriptor()
    end
    return nil
end

function SharedItemSupport.RegisterCategorySupport(support)
    if type(support) ~= "table" then
        return
    end

    if type(support.doesItemMatchCategory) == "function" then
        categorySupport.doesItemMatchCategory = support.doesItemMatchCategory
    end
    if type(support.getBestItemCategoryDescription) == "function" then
        categorySupport.getBestItemCategoryDescription = support.getBestItemCategoryDescription
    end
end

function SharedItemSupport.DoesItemMatchCategory(itemData, category)
    if not category or category.key == "all" then
        return true
    end

    local matcher = categorySupport.doesItemMatchCategory
    if type(matcher) == "function" then
        return matcher(itemData, category)
    end

    if category.special == "junk" then
        return itemData and itemData.isJunk == true
    end

    if category.filterType and type(ZO_InventoryUtils_DoesNewItemMatchFilterType) == "function" then
        return ZO_InventoryUtils_DoesNewItemMatchFilterType(itemData, category.filterType)
    end

    return false
end

function SharedItemSupport.GetBestItemCategoryDescription(itemData)
    local describer = categorySupport.getBestItemCategoryDescription
    if type(describer) == "function" then
        return describer(itemData)
    end

    return itemData and (itemData.bestGamepadItemCategoryName
        or itemData.bestItemCategoryName
        or itemData.categoryDescription
        or itemData.name) or ""
end

function SharedItemSupport.ResolveNameFontDescriptor(moduleName, fallbackModuleName)
    return ResolveDescriptor(moduleName, "GetNameFontDescriptor")
        or ResolveDescriptor(fallbackModuleName, "GetNameFontDescriptor")
end

function SharedItemSupport.ResolveColumnFontDescriptor(moduleName, fallbackModuleName)
    return ResolveDescriptor(moduleName, "GetColumnFontDescriptor")
        or ResolveDescriptor(fallbackModuleName, "GetColumnFontDescriptor")
end

function SharedItemSupport.RegisterTooltipSupport(support)
    if type(support) ~= "table" then
        return
    end

    local supportedKeys = {
        "applyTooltipStyles",
        "restoreTooltipStyles",
        "cleanupEnhancedTooltip",
        "updateTooltipEquippedText",
        "isItemComparisonEnabled",
        "compareItem",
        "showComparisonOnTooltip",
    }

    for _, key in ipairs(supportedKeys) do
        if support[key] ~= nil then
            tooltipSupport[key] = support[key]
        end
    end
end

function SharedItemSupport.ApplyTooltipStyles()
    local applyTooltipStyles = tooltipSupport.applyTooltipStyles
    if type(applyTooltipStyles) == "function" then
        return applyTooltipStyles()
    end
end

function SharedItemSupport.RestoreTooltipStyles()
    local restoreTooltipStyles = tooltipSupport.restoreTooltipStyles
    if type(restoreTooltipStyles) == "function" then
        return restoreTooltipStyles()
    end
end

function SharedItemSupport.CleanupEnhancedTooltip(tooltipType, preserveItemData)
    local cleanupEnhancedTooltip = tooltipSupport.cleanupEnhancedTooltip
    if type(cleanupEnhancedTooltip) == "function" then
        return cleanupEnhancedTooltip(tooltipType, preserveItemData)
    end
end

function SharedItemSupport.UpdateTooltipEquippedText(tooltipType, equipSlot)
    local updateTooltipEquippedText = tooltipSupport.updateTooltipEquippedText
    if type(updateTooltipEquippedText) == "function" then
        return updateTooltipEquippedText(tooltipType, equipSlot)
    end
end

function SharedItemSupport.IsItemComparisonEnabled()
    local isItemComparisonEnabled = tooltipSupport.isItemComparisonEnabled
    return type(isItemComparisonEnabled) == "function" and isItemComparisonEnabled() == true or false
end

--- Delegates item comparison to registered tooltip support.
--- Signature intentionally matches inventory/banking/companion callsites.
--- @param candidateLink string
--- @param candidateBagId number
--- @param candidateSlotIndex number
--- @param equippedBagId number|nil
--- @return table|nil
function SharedItemSupport.CompareItem(candidateLink, candidateBagId, candidateSlotIndex, equippedBagId)
    local compareItem = tooltipSupport.compareItem
    if type(compareItem) == "function" then
        return compareItem(candidateLink, candidateBagId, candidateSlotIndex, equippedBagId)
    end
    return nil
end

function SharedItemSupport.ShowComparisonOnTooltip(container, result)
    local showComparisonOnTooltip = tooltipSupport.showComparisonOnTooltip
    if type(showComparisonOnTooltip) == "function" then
        return showComparisonOnTooltip(container, result)
    end
end
