--[[
File: Modules/CIM/Core/Utilities.lua
Purpose: Core utility functions for the BetterUI addon.
         Provides debug logging, module status checks, and icon safety wrappers.
]]

-- DEBUG LOGGING

---@param str string Message to display in chat with [BETTERUI] prefix
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
local researchableTraitMatcher = function()
    return 0
end
local IsBankingSceneShowing

function BETTERUI.CIM.Utils.RegisterResearchableTraitMatcher(matcher)
    if type(matcher) == "function" then
        researchableTraitMatcher = matcher
    else
        researchableTraitMatcher = function()
            return 0
        end
    end
end

---@param list table|nil List control with GetTargetData method or selectedData field
---@return table|nil data The target data from the list, or nil
function BETTERUI.CIM.Utils.SafeGetTargetData(list)
    if not list then return nil end
    if list.GetTargetData then
        return list:GetTargetData()
    end
    -- Fallback for basic tables or parametric lists
    return list.selectedData
end

---@param newValue number Value to wrap
---@param maxValue number Upper bound (wraps to 1)
---@return number wrapped Value clamped to [1, maxValue] with wrap-around
function BETTERUI.CIM.Utils.WrapValue(newValue, maxValue)
    if newValue < 1 then
        return maxValue
    end
    if newValue > maxValue then
        return 1
    end
    return newValue
end

--- Handles nil values in sort comparators.
--- Returns a boolean if either value is nil, or nil when both are non-nil.
---@param leftVal any
---@param rightVal any
---@param nilGoesLast boolean When true, nil sorts after non-nil values
---@return boolean|nil
function BETTERUI.CIM.Utils.CompareNils(leftVal, rightVal, nilGoesLast)
    if leftVal == nil and rightVal == nil then return false end
    if leftVal == nil then return not nilGoesLast end
    if rightVal == nil then return nilGoesLast end
    return nil
end

function BETTERUI.CIM.Utils.DefaultSortComparator(left, right)
    return ZO_TableOrderingFunction(left, right, "sortPriorityName", BETTERUI.CIM.CONST.SORT_SCHEMA,
        ZO_SORT_ORDER_UP)
end

---@param bagId number Bag to search
---@param itemLink string Item link to find a stackable slot for
---@return number|nil slotIndex Index of a stackable slot, or nil if none found
function BETTERUI.CIM.Utils.FindStackableSlotInBag(bagId, itemLink)
    if not itemLink or itemLink == "" or not IsItemLinkStackable(itemLink) then
        return nil
    end
    local bagSize = GetBagSize(bagId)
    for i = 0, bagSize - 1 do
        local currentItemLink = GetItemLink(bagId, i)
        if currentItemLink == itemLink then
            local stackCount, maxStack = GetSlotStackSize(bagId, i)
            if stackCount < maxStack then
                return i
            end
        end
    end
    return nil
end

---@param fromBagId number Source bag
---@param fromSlotIndex number Source slot
---@param toBagId number Destination bag
---@return number|nil slotIndex Best destination slot (stackable or empty), or nil
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

---@return table|nil context Shared banking sort context with list and owner, or nil when unavailable
function BETTERUI.CIM.Utils.GetBankingSortEntryContext()
    if not IsBankingSceneShowing() then
        return nil
    end

    local banking = BETTERUI.Banking
    local bankingWindow = banking and banking.Window or nil
    if bankingWindow and bankingWindow.list then
        return {
            list = bankingWindow.list,
            sortContext = bankingWindow,
        }
    end

    local bankingClass = banking and banking.Class or nil
    if bankingClass and bankingClass.list then
        return {
            list = bankingClass.list,
            sortContext = bankingClass,
        }
    end

    return nil
end

function BETTERUI.CIM.Utils.CreateInventorySlotActions(alignment)
    local inventory = BETTERUI.Inventory
    local slotActions = inventory and inventory.SlotActions or nil
    if slotActions and slotActions.New then
        return slotActions:New(alignment)
    end
    return nil
end

function BETTERUI.CIM.Utils.ClearTrackedInventorySlot(bagId, slotIndex)
    local inventory = BETTERUI.Inventory
    local tracker = inventory and inventory.NewItemTracker or nil
    if tracker and tracker.ClearImmediate then
        tracker.ClearImmediate(bagId, slotIndex)
    end
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
        total = total + researchableTraitMatcher(itemLink, bagId)
    end
    return total
end

IsBankingSceneShowing = function()
    local scene = SCENE_MANAGER.scenes['gamepad_banking']
    if scene and scene:IsShowing() then return true end
    -- Also check the guild banking scene
    local guildScene = BETTERUI_GUILD_BANKING_SCENE
    return guildScene and guildScene:IsShowing()
end

local function IsInventorySceneShowing()
    local scene = SCENE_MANAGER.scenes['gamepad_inventory_root']
    return scene and scene:IsShowing()
end

-- Canonical helper ownership moved to BETTERUI.Utils first.
BETTERUI.CIM.Utils.IsBankingSceneShowing = IsBankingSceneShowing
BETTERUI.CIM.Utils.IsInventorySceneShowing = IsInventorySceneShowing

BETTERUI.Utils = BETTERUI.Utils or {}
BETTERUI.Utils.IsBankingSceneShowing = IsBankingSceneShowing
BETTERUI.Utils.IsInventorySceneShowing = IsInventorySceneShowing
BETTERUI.Utils.SafeGetTargetData = BETTERUI.CIM.Utils.SafeGetTargetData
