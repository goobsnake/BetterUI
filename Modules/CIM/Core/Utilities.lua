--[[
File: Modules/CIM/Core/Utilities.lua
Purpose: Core utility functions for the BetterUI addon.
         Provides debug logging, module status checks, and icon safety wrappers.
]]

-- ============================================================================
-- DEBUG LOGGING
-- ============================================================================

--- @param str string The message string to display
--- @return any d() return value
function BETTERUI.Debug(str)
    if BETTERUI.CIM and BETTERUI.CIM.Debug and BETTERUI.CIM.Debug.IsEnabled and not BETTERUI.CIM.Debug.IsEnabled() then
        return
    end
    return d("|c0066ff[BETTERUI]|r " .. str)
end

-- ============================================================================
-- MODULE STATUS
-- ============================================================================

--[[
Function: BETTERUI.GetModuleEnabled
Checks if a specific BetterUI module is enabled.
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

    -- Session-only disable: modules that failed init/setup are skipped this session
    if BETTERUI._sessionDisabledModules and BETTERUI._sessionDisabledModules[moduleName] then
        return false
    end

    -- Canonical key (m_enabled)
    if settings.m_enabled ~= nil then
        return settings.m_enabled
    end

    return false
end

--- @param moduleName string The key of the module in BETTERUI.Settings.Modules
--- @param enabled boolean True to enable, false to disable for this session
function BETTERUI.SetModuleEnabled(moduleName, enabled)
    if not moduleName then return end
    BETTERUI._sessionDisabledModules = BETTERUI._sessionDisabledModules or {}
    BETTERUI._sessionDisabledModules[moduleName] = not enabled
end

-- ============================================================================
-- ICON UTILITIES
-- ============================================================================

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

--- @class CIM.WindowOptions
--- @field title string|nil
--- @field subtitle string|nil
--- @field width number|nil
--- @field height number|nil
--- @field anchorPoint any|nil
--- @field anchorTarget any|nil
--- @field anchorRelativePoint any|nil
--- @field anchorOffsetX number|nil
--- @field anchorOffsetY number|nil
--- @field clampToScreen boolean|nil

--- @class BETTERUI.CIM.Utils
--- Shared utility functions for the BetterUI Common Interface Module.
--- Provides scene checks, sort comparators, safe accessors, and bag helpers.
--- All functions below are individually annotated with EmmyLua param/return tags.
BETTERUI.CIM.Utils = BETTERUI.CIM.Utils or {}

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

--- @param left table The first item data
--- @param right table The second item data
--- @return boolean result True if 'left' should appear before 'right'
function BETTERUI.CIM.Utils.DefaultSortComparator(left, right)
    return ZO_TableOrderingFunction(left, right, "sortPriorityName", BETTERUI.CIM.CONST.SORT_SCHEMA,
        ZO_SORT_ORDER_UP)
end

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

--- @param hidden boolean True to hide, false to show
function BETTERUI.CIM.Utils.SetExternalToolbarHidden(hidden)
    if wykkydsToolbar then
        wykkydsToolbar:SetHidden(hidden)
    end
end

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

--- @return boolean showing True if the banking scene is showing
function BETTERUI.CIM.Utils.IsBankingSceneShowing()
    local scene = SCENE_MANAGER.scenes['gamepad_banking']
    if scene and scene:IsShowing() then return true end
    -- Also check the guild banking scene
    local guildScene = BETTERUI_GUILD_BANKING_SCENE
    return guildScene and guildScene:IsShowing()
end

--- @return boolean showing True if the inventory scene is showing
function BETTERUI.CIM.Utils.IsInventorySceneShowing()
    local scene = SCENE_MANAGER.scenes['gamepad_inventory_root']
    return scene and scene:IsShowing()
end

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

-- Root-level facade: scene-check utilities promoted out of CIM namespace.
-- Consumers should use BETTERUI.Utils.* instead of BETTERUI.CIM.Utils.* for
-- cross-module utilities that don't logically belong to CIM's scope.
BETTERUI.Utils = BETTERUI.Utils or {}
BETTERUI.Utils.IsBankingSceneShowing = BETTERUI.CIM.Utils.IsBankingSceneShowing
BETTERUI.Utils.IsInventorySceneShowing = BETTERUI.CIM.Utils.IsInventorySceneShowing
BETTERUI.Utils.SafeGetTargetData = BETTERUI.CIM.Utils.SafeGetTargetData
BETTERUI.Utils.SafeCall = BETTERUI.CIM.Utils.SafeCall
