-- Core utility helpers shared across BetterUI modules.

---@param str string Message to display in chat with [BETTERUI] prefix
function BETTERUI.Debug(str)
    if BETTERUI.CIM and BETTERUI.CIM.Debug and BETTERUI.CIM.Debug.IsEnabled and not BETTERUI.CIM.Debug.IsEnabled() then
        return
    end
    return d("|c0066ff[BETTERUI]|r " .. str)
end

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

function BETTERUI.SafeIcon(iconPath)
    if iconPath == nil then return "" end
    return iconPath
end

BETTERUI.CIM = BETTERUI.CIM or {}

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

---@param list table|nil List control with GetTargetData/GetSelectedData or selectedData
---@return table|nil data The target data from the list, or nil
local function SafeGetTargetData(list)
    if not list then return nil end
    if list.GetTargetData then
        return list:GetTargetData()
    end
    if list.GetSelectedData then
        return list:GetSelectedData()
    end
    return list.selectedData
end
BETTERUI.CIM.Utils.SafeGetTargetData = SafeGetTargetData
BETTERUI.CIM.Utils.GetListTargetData = BETTERUI.CIM.Utils.GetListTargetData or SafeGetTargetData

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

local function IsSceneShowing(sceneName)
    if type(sceneName) ~= "string" or sceneName == "" then
        return false
    end
    local scenes = SCENE_MANAGER and SCENE_MANAGER.scenes
    local scene = scenes and scenes[sceneName]
    return scene and scene.IsShowing and scene:IsShowing() or false
end

local function IsAnySceneShowing(sceneNames)
    for _, sceneName in ipairs(sceneNames or {}) do
        if IsSceneShowing(sceneName) then
            return true
        end
    end
    return false
end

IsBankingSceneShowing = function()
    if IsAnySceneShowing({ "gamepad_banking" }) then
        return true
    end
    local guildScene = BETTERUI_GUILD_BANKING_SCENE
    return guildScene and guildScene:IsShowing() or false
end

local function IsInventorySceneShowing()
    return IsSceneShowing("gamepad_inventory_root")
end

BETTERUI.CIM.Utils.IsBankingSceneShowing = IsBankingSceneShowing
BETTERUI.CIM.Utils.IsInventorySceneShowing = IsInventorySceneShowing
BETTERUI.CIM.Utils.IsSceneShowing = IsSceneShowing
BETTERUI.CIM.Utils.IsAnySceneShowing = IsAnySceneShowing

BETTERUI.Utils = BETTERUI.Utils or {}
if type(BETTERUI.Utils.IsBankingSceneShowing) ~= "function" then
    BETTERUI.Utils.IsBankingSceneShowing = IsBankingSceneShowing
end
if type(BETTERUI.Utils.IsInventorySceneShowing) ~= "function" then
    BETTERUI.Utils.IsInventorySceneShowing = IsInventorySceneShowing
end
if type(BETTERUI.Utils.SafeGetTargetData) ~= "function" then
    BETTERUI.Utils.SafeGetTargetData = SafeGetTargetData
end
