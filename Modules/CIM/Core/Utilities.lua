--[[
File: Modules/CIM/Core/Utilities.lua
Purpose: Core utility functions for the BetterUI addon.
         Provides debug logging, module status checks, and icon safety wrappers.
]]

-- DEBUG LOGGING

function BETTERUI.Debug(str)
    if BETTERUI.CIM and BETTERUI.CIM.Debug and BETTERUI.CIM.Debug.IsEnabled and not BETTERUI.CIM.Debug.IsEnabled() then
        return
    end
    return d("|c0066ff[BETTERUI]|r " .. str)
end

-- MODULE STATUS

--[[
Function: BETTERUI.GetModuleEnabled
Checks if a specific BetterUI module is enabled.
References: Used during module initialization to check if module should load.
param: moduleName (string) - The key of the module in BETTERUI.Settings.Modules.
return: boolean - True if the module is enabled.
]]
-- As of v2.8, 'm_enabled' is the canonical key. Legacy 'enabled' fallback was removed
-- to avoid silent defaults; migrate older saved variables before v3.0.
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

function BETTERUI.SetModuleEnabled(moduleName, enabled)
    if not moduleName then return end
    BETTERUI._sessionDisabledModules = BETTERUI._sessionDisabledModules or {}
    BETTERUI._sessionDisabledModules[moduleName] = not enabled
end

-- ICON UTILITIES

function BETTERUI.SafeIcon(iconPath)
    if iconPath == nil then return "" end
    return iconPath
end

-- SHARED UTILITY FUNCTIONS (CIM.Utils namespace)

BETTERUI.CIM = BETTERUI.CIM or {}


--- Shared utility functions for the BetterUI Common Interface Module.
--- Provides scene checks, sort comparators, safe accessors, and bag helpers.
--- All functions below are individually annotated with EmmyLua param/return tags.
BETTERUI.CIM.Utils = BETTERUI.CIM.Utils or {}

function BETTERUI.CIM.Utils.SafeGetTargetData(list)
    if not list then return nil end
    if list.GetTargetData then
        return list:GetTargetData()
    end
    -- Fallback for basic tables or parametric lists
    return list.selectedData
end

function BETTERUI.CIM.Utils.WrapValue(newValue, maxValue)
    if newValue < 1 then
        return maxValue
    end
    if newValue > maxValue then
        return 1
    end
    return newValue
end

function BETTERUI.CIM.Utils.DefaultSortComparator(left, right)
    return ZO_TableOrderingFunction(left, right, "sortPriorityName", BETTERUI.CIM.CONST.SORT_SCHEMA,
        ZO_SORT_ORDER_UP)
end

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

function BETTERUI.CIM.Utils.SetExternalToolbarHidden(hidden)
    if wykkydsToolbar then
        wykkydsToolbar:SetHidden(hidden)
    end
end

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

function BETTERUI.CIM.Utils.IsBankingSceneShowing()
    local scene = SCENE_MANAGER.scenes['gamepad_banking']
    if scene and scene:IsShowing() then return true end
    -- Also check the guild banking scene
    local guildScene = BETTERUI_GUILD_BANKING_SCENE
    return guildScene and guildScene:IsShowing()
end

function BETTERUI.CIM.Utils.IsInventorySceneShowing()
    local scene = SCENE_MANAGER.scenes['gamepad_inventory_root']
    return scene and scene:IsShowing()
end

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
