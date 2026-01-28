--[[
File: Modules/CIM/Core/Utilities.lua
Purpose: Core utility functions for the BetterUI addon.
         Provides debug logging, module status checks, and icon safety wrappers.
Author: BetterUI Team
Last Modified: 2026-01-27
]]

-- ============================================================================
-- DEBUG LOGGING
-- ============================================================================

--[[
Function: BETTERUI.Debug
Description: Prints a debug message to chat with BetterUI prefix.
Rationale: Standardized debug logging for development.
Mechanism: Prefixes the message with cyan [BETTERUI] tag and prints to chat.
References: Used globally throughout the addon for debug logging.
param: str (string) - The message string to display.
]]
function BETTERUI.Debug(str)
    return d("|c0066ff[BETTERUI]|r " .. str)
end

-- ============================================================================
-- MODULE STATUS
-- ============================================================================

--[[
Function: BETTERUI.GetModuleEnabled
Description: Checks if a specific BetterUI module is enabled.
Rationale: Uses 'm_enabled' as the canonical key. Legacy 'enabled' key support retained for backward compatibility.
Mechanism: Checks saved settings for the module's enabled state.
References: Used during module initialization to check if module should load.
param: moduleName (string) - The key of the module in BETTERUI.Settings.Modules.
return: boolean - True if the module is enabled.
]]
-- NOTE: As of v2.8, 'm_enabled' is the canonical key. The 'enabled' fallback is retained for
-- backward compatibility with older saved variables but will be removed in v3.0.
function BETTERUI.GetModuleEnabled(moduleName)
    if not BETTERUI.Settings or not BETTERUI.Settings.Modules then return false end
    local settings = BETTERUI.Settings.Modules[moduleName]
    if not settings then return false end

    -- Canonical key (m_enabled)
    if settings.m_enabled ~= nil then
        return settings.m_enabled
    end
    -- Legacy fallback (enabled) - DEPRECATED, will be removed in v3.0
    if settings.enabled ~= nil then
        return settings.enabled
    end

    return false
end

-- ============================================================================
-- ICON UTILITIES
-- ============================================================================

--[[
Function: BETTERUI.SafeIcon
Description: Safely returns an icon path string.
Rationale: Prevents crashes or errors when passing nil icon paths to ESO API functions.
Mechanism: Checks if iconPath is nil; returns empty string if so, otherwise returns original path.
References: Used by Inventory, Banking, and Writ lists to ensure icon validity.
param: iconPath (string|nil) - The path to the icon texture.
return: string - The icon path or an empty string.
]]
function BETTERUI.SafeIcon(iconPath)
    if iconPath == nil then return "" end
    return iconPath
end

-- ============================================================================
-- SHARED UTILITY FUNCTIONS (CIM.Utils namespace)
-- ============================================================================

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Utils = BETTERUI.CIM.Utils or {}

--[[
Function: BETTERUI.CIM.Utils.SafeGetTargetData
Description: Safe helper for GetTargetData calls (guards against lists without method).
Rationale: Provides a consistent way to retrieve selected data across different list types.
Mechanism: Checks for GetTargetData method, falls back to selectedData property.
References: Used by Inventory, Banking for safe list selection access.
param: list (table) - The list object to query.
return: table|nil - The target data of the list.
]]
function BETTERUI.CIM.Utils.SafeGetTargetData(list)
    if not list then return nil end
    if list.GetTargetData then
        return list:GetTargetData()
    end
    -- Fallback for basic tables or parametric lists
    return list.selectedData
end

--[[
Function: BETTERUI.CIM.Utils.WrapValue
Description: Wraps a value around min/max bounds for circular navigation.
Rationale: Provides consistent wrap-around behavior for tab/category navigation.
Mechanism: If below 1, returns maxValue; if above maxValue, returns 1.
References: Used for category cycling in header navigation.
param: newValue (number) - The value to wrap.
param: maxValue (number) - The maximum value (1 is implicit minimum).
return: number - The wrapped value.
]]
function BETTERUI.CIM.Utils.WrapValue(newValue, maxValue)
    if newValue < 1 then
        return maxValue
    end
    if newValue > maxValue then
        return 1
    end
    return newValue
end

--[[
Function: BETTERUI.CIM.Utils.DefaultSortComparator
Description: Custom comparison function for sorting gamepad inventory-style lists.
Rationale: Provides consistent sort order (Type -> Name -> Level -> CP -> Icon -> ID).
Mechanism: Uses ZO_TableOrderingFunction with CIM.CONST.SORT_SCHEMA.
References: Used by Inventory and Banking list sorting.
param: left (table) - The first item data.
param: right (table) - The second item data.
return: boolean - True if 'left' should appear before 'right'.
]]
function BETTERUI.CIM.Utils.DefaultSortComparator(left, right)
    return ZO_TableOrderingFunction(left, right, "sortPriorityName", BETTERUI.CIM.CONST.SORT_SCHEMA,
        ZO_SORT_ORDER_UP)
end

--[[
Function: BETTERUI.CIM.Utils.FindStackableSlotInBag
Description: Finds a slot with a stackable item matching the given item link that has room for more items.
Rationale: Extracted from Banking/Actions/TransferActions.lua to eliminate DRY violation.
Mechanism: Iterates through bag slots looking for matching stackable items with available stack space.
References: Used by Banking TransferActions for item stacking during transfers.
param: bagId (number) - The bag ID to search.
param: itemLink (string) - The item link to match against.
return: number|nil - The slot index of a stackable slot, or nil if none found.
]]
function BETTERUI.CIM.Utils.FindStackableSlotInBag(bagId, itemLink)
    local bagSize = GetBagSize(bagId)
    for i = 0, bagSize - 1 do
        local currentItemLink = GetItemLink(bagId, i)
        if currentItemLink == itemLink and IsItemLinkStackable(currentItemLink) then
            local stackCount, maxStack = GetSlotStackSize(bagId, i)
            if stackCount < maxStack then
                return i
            end
        end
    end
    return nil
end
