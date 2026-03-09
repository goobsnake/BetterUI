--[[
File: Modules/CIM/Core/Utilities.lua
Purpose: Core utility functions for the BetterUI addon.
         Provides debug logging, module status checks, and icon safety wrappers.
Author: BetterUI Team
Last Modified: 2026-02-07
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
--- @param str string The message string to display
--- @return any d() return value
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
-- NOTE: As of v2.8, 'm_enabled' is the canonical key. Legacy 'enabled' fallback was removed
-- to avoid silent defaults; migrate older saved variables before v3.0.
--- @param moduleName string The key of the module in BETTERUI.Settings.Modules
--- @return boolean enabled True if the module is enabled
function BETTERUI.GetModuleEnabled(moduleName)
    if not BETTERUI.Settings or not BETTERUI.Settings.Modules then return false end
    local settings = BETTERUI.Settings.Modules[moduleName]
    if not settings then return false end

    -- Canonical key (m_enabled)
    if settings.m_enabled ~= nil then
        return settings.m_enabled
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
--- @param iconPath string|nil The path to the icon texture
--- @return string path The icon path or empty string
function BETTERUI.SafeIcon(iconPath)
    if iconPath == nil then return "" end
    return iconPath
end

-- ============================================================================
-- SHARED UTILITY FUNCTIONS (CIM.Utils namespace)
-- ============================================================================

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Utils = BETTERUI.CIM.Utils or {}
-- TODO(doc): P3 - Add EmmyLua type annotations to all functions in BETTERUI.CIM.Utils namespace
-- Functions to annotate: IsEnabled, SafeIcon, SafeGetTargetData, SortComparator,
-- FindStackableSlotInBag, CountResearchableInHouseBanks, IsBankingSceneShowing,
-- IsInventorySceneShowing, SafeCall
-- See SafeExecute.lua for the annotation pattern to follow
-- Estimated effort: 2 hours

--[[
Function: BETTERUI.CIM.Utils.SafeGetTargetData
Description: Safe helper for GetTargetData calls (guards against lists without method).
Rationale: Provides a consistent way to retrieve selected data across different list types.
Mechanism: Checks for GetTargetData method, falls back to selectedData property.
References: Used by Inventory, Banking for safe list selection access.
param: list (table) - The list object to query.
return: table|nil - The target data of the list.
]]
--- @param list table|nil The list object to query
--- @return table|nil targetData The target data of the list
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
--- @param newValue number The value to wrap
--- @param maxValue number The maximum value (1 is implicit minimum)
--- @return number wrappedValue The wrapped value within [1, maxValue]
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
--- @param left table The first item data
--- @param right table The second item data
--- @return boolean result True if 'left' should appear before 'right'
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
--- @param bagId number The bag ID to search
--- @param itemLink string The item link to match against
--- @return number|nil slotIndex The slot index of a stackable slot, or nil
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

--[[
Function: BETTERUI.CIM.Utils.ResolveMoveDestinationSlot
Description: Resolves an explicit destination slot for inventory moves.
Rationale: Batch RequestMoveItem calls must provide concrete destination slots to
           avoid nil-slot transfer behavior under throttled processing.
Mechanism:
  1) Prefer first empty slot in destination bag.
  2) If none, try stackable slot matching source item link.
References: Used by Banking/Inventory multi-select batch move paths.
param: fromBagId (number) - Source bag id.
param: fromSlotIndex (number) - Source slot index.
param: toBagId (number) - Destination bag id.
return: number|nil - Destination slot index or nil when unresolved.
]]
--- @param fromBagId number Source bag id
--- @param fromSlotIndex number Source slot index
--- @param toBagId number Destination bag id
--- @return number|nil slotIndex Destination slot index or nil
function BETTERUI.CIM.Utils.ResolveMoveDestinationSlot(fromBagId, fromSlotIndex, toBagId)
    if not fromBagId or not fromSlotIndex or not toBagId then
        return nil
    end

    local itemLink = GetItemLink(fromBagId, fromSlotIndex)
    if itemLink and itemLink ~= "" then
        local stackSlot = BETTERUI.CIM.Utils.FindStackableSlotInBag(toBagId, itemLink)
        if stackSlot ~= nil then
            return stackSlot
        end
    end

    return FindFirstEmptySlotInBag(toBagId)
end

--[[
Function: BETTERUI.CIM.Utils.SetExternalToolbarHidden
Description: Toggles visibility of external addon toolbars (e.g., wykkydsToolbar).
Rationale: Centralized helper to avoid duplicating toolbar visibility toggles across modules.
Mechanism: Checks if wykkydsToolbar exists and sets its hidden state.
References: Used by Inventory, Banking during scene state changes.
param: hidden (boolean) - True to hide, false to show.
]]
--- @param hidden boolean True to hide, false to show
function BETTERUI.CIM.Utils.SetExternalToolbarHidden(hidden)
    if wykkydsToolbar then
        wykkydsToolbar:SetHidden(hidden)
    end
end

--[[
Function: BETTERUI.CIM.Utils.GetHouseBankTraitMatches
Description: Returns the total count of researchable trait matches across all house banks.
Rationale: Centralizes house bank iteration to avoid verbose 10-bank repetition in Tooltips.
Mechanism: Iterates BAG_HOUSE_BANK_ONE through BAG_HOUSE_BANK_TEN and sums matches.
References: Used by CIM/Tooltips/Tooltips.lua for research status display.
param: itemLink (string) - The item link to check.
return: number - Total count of matching researchable items across all house banks.
]]
--- @param itemLink string The item link to check
--- @return number total Total count of matching items across house banks
function BETTERUI.CIM.Utils.GetHouseBankTraitMatches(itemLink)
    if not itemLink then return 0 end
    local houseBanks = {
        BAG_HOUSE_BANK_ONE, BAG_HOUSE_BANK_TWO, BAG_HOUSE_BANK_THREE,
        BAG_HOUSE_BANK_FOUR, BAG_HOUSE_BANK_FIVE, BAG_HOUSE_BANK_SIX,
        BAG_HOUSE_BANK_SEVEN, BAG_HOUSE_BANK_EIGHT, BAG_HOUSE_BANK_NINE,
        BAG_HOUSE_BANK_TEN
    }
    local total = 0
    for _, bagId in ipairs(houseBanks) do
        total = total + BETTERUI.GeneralInterface.GetCachedResearchableTraitMatches(itemLink, bagId)
    end
    return total
end

--[[
Function: BETTERUI.CIM.Utils.IsBankingSceneShowing
Description: Checks if the gamepad banking scene is currently visible.
Rationale: Centralizes fragile scene check pattern used 24+ times across Banking and Inventory modules.
Mechanism: Safely checks for scene existence before calling IsShowing().
References: Used by Banking, Inventory for scene-guarded operations.
return: boolean - True if the banking scene is showing.
]]
--- @return boolean showing True if the banking scene is showing
function BETTERUI.CIM.Utils.IsBankingSceneShowing()
    local scene = SCENE_MANAGER.scenes['gamepad_banking']
    return scene and scene:IsShowing()
end

--[[
Function: BETTERUI.CIM.Utils.IsInventorySceneShowing
Description: Checks if the gamepad inventory root scene is currently visible.
Rationale: Provides consistent scene checking for inventory operations.
Mechanism: Safely checks for scene existence before calling IsShowing().
References: Used by Inventory module for scene-guarded operations.
return: boolean - True if the inventory scene is showing.
]]
--- @return boolean showing True if the inventory scene is showing
function BETTERUI.CIM.Utils.IsInventorySceneShowing()
    local scene = SCENE_MANAGER.scenes['gamepad_inventory_root']
    return scene and scene:IsShowing()
end

--[[
Function: BETTERUI.CIM.Utils.SafeCall
Description: Safely calls a method on an object if both exist.
Rationale: For cases where nil is legitimately possible (e.g., optional controls,
           scene state transitions). NOT for masking bugs - investigate and fix root causes.
Mechanism: Checks obj and method existence before calling.
References: Used for defensive coding in scene transitions and optional UI elements.
param: obj (table|nil) - The object to call the method on.
param: methodName (string) - The name of the method to call.
param: ... (any) - Additional arguments to pass to the method.
return: any|nil - The return value of the method, or nil if not called.

Usage Guidelines:
  ✅ Use for optional UI controls that may not exist in all contexts
  ✅ Use during scene transitions where state is uncertain
  ❌ Do NOT use to hide bugs - investigate and fix root causes instead

Example:
  -- Good: Optional control may not exist
  BETTERUI.CIM.Utils.SafeCall(self.optionalButton, "SetHidden", true)

  -- Bad: Hiding a nil error that should be fixed upstream
  BETTERUI.CIM.Utils.SafeCall(self.requiredList, "RefreshList") -- Fix why list is nil!
]]
--- @param obj table|nil The object to call the method on
--- @param methodName string The name of the method to call
--- @param ... any Additional arguments to pass to the method
--- @return any|nil result The method return value, or nil if not called
function BETTERUI.CIM.Utils.SafeCall(obj, methodName, ...)
    if obj and type(obj[methodName]) == "function" then
        return obj[methodName](obj, ...)
    end
    return nil
end
