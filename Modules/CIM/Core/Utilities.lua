-- Core utility helpers shared across BetterUI modules.

---@param str string Message to display in chat with [BETTERUI] prefix
function BETTERUI.Debug(str)
    -- Mirror into Interface.log via the unified logger (file sink, suppressed by default).
    -- Falls back to the raw InterfaceLog bridge if the logger is not loaded yet.
    if BETTERUI.Log then
        BETTERUI.Log.Debug(BETTERUI.Log.CATEGORY.GENERAL, str)
    elseif BETTERUI.CIM and BETTERUI.CIM.InterfaceLog and BETTERUI.CIM.InterfaceLog.Write then
        BETTERUI.CIM.InterfaceLog.Write(str)
    end
    if BETTERUI.CIM and BETTERUI.CIM.Debug and BETTERUI.CIM.Debug.IsEnabled and not BETTERUI.CIM.Debug.IsEnabled() then
        return
    end
    return d("|c0066ff[BETTERUI]|r " .. str)
end

--- Ungated diagnostic output for error/recovery reporting.
--- Unlike BETTERUI.Debug this is never suppressed by the debug flag, so
--- failures stay visible to users even with debugging disabled.
---@param str string Message to display in chat with [BETTERUI] prefix
function BETTERUI.DebugError(str)
    -- Also stream to Interface.log (ERROR level) when logging is active.
    if BETTERUI.Log then
        BETTERUI.Log.Error(BETTERUI.Log.CATEGORY.GENERAL, tostring(str))
    end
    local message = "|c0066ff[BETTERUI]|r " .. tostring(str)
    local chatPrint = rawget(_G, "d")
    if type(chatPrint) == "function" then
        return chatPrint(message)
    end
    local chatRouter = rawget(_G, "CHAT_ROUTER")
    if chatRouter and type(chatRouter.AddSystemMessage) == "function" then
        return chatRouter:AddSystemMessage(message)
    end
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

--- Marks a module as disabled for the current session only; nothing is persisted.
--- (Renamed from SetModuleEnabled, which misleadingly implied persistence.)
---@param moduleName string Module name key
---@param disabled boolean True to hide the module for this session
function BETTERUI.SetModuleSessionDisabled(moduleName, disabled)
    if not moduleName then return end
    BETTERUI._sessionDisabledModules = BETTERUI._sessionDisabledModules or {}
    BETTERUI._sessionDisabledModules[moduleName] = disabled and true or nil
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
    if list.targetData ~= nil then
        return list.targetData
    end
    return list.selectedData
end
BETTERUI.CIM.Utils.SafeGetTargetData = SafeGetTargetData
local getListTargetData = BETTERUI.CIM.Utils.GetListTargetData
if type(getListTargetData) ~= "function" then
    getListTargetData = SafeGetTargetData
end
BETTERUI.CIM.Utils.GetListTargetData = getListTargetData

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

-- SLOT IDENTITY
-- Shared item-identity capture/validation used by batch operations to confirm
-- the live bag slot still holds the same item selected/queued earlier. Items can
-- move into a freed slotIndex mid-batch; identity revalidation prevents acting on
-- the wrong item. Self-contained (own normalize + resolve-data-source locals).

---@param value any Raw uniqueId (Id64 or other); normalized to a stable string
---@return string|nil normalized
local function NormalizeSlotIdentityValue(value)
    if value == nil then
        return nil
    end
    if Id64ToString and type(value) ~= "string" then
        local ok, normalized = pcall(Id64ToString, value)
        if ok and normalized ~= nil then
            return tostring(normalized)
        end
    end
    return tostring(value)
end
BETTERUI.CIM.Utils.NormalizeIdentityValue = NormalizeSlotIdentityValue

---@param slotData table|nil Entry data (may wrap raw data in dataSource)
---@return table|nil dataSource
local function ResolveSlotIdentityDataSource(slotData)
    return slotData and (slotData.dataSource or slotData) or nil
end

--- Captures the stable item identity for a bag slot at selection/dialog-open time.
---@param bagId number|nil
---@param slotIndex number|nil
---@param slotData table|nil
---@return table|nil identity
function BETTERUI.CIM.Utils.CaptureSlotIdentity(bagId, slotIndex, slotData)
    if bagId == nil or slotIndex == nil then
        return nil
    end

    local dataSource = ResolveSlotIdentityDataSource(slotData)
    local uniqueId = dataSource and (dataSource.uniqueId or slotData.uniqueId) or nil
    if uniqueId == nil and GetItemUniqueId then
        uniqueId = GetItemUniqueId(bagId, slotIndex)
    end
    if uniqueId == nil and SHARED_INVENTORY and type(SHARED_INVENTORY.GetItemUniqueId) == "function" then
        uniqueId = SHARED_INVENTORY:GetItemUniqueId(bagId, slotIndex)
    end

    local itemLink = (dataSource and (dataSource.cached_itemLink or dataSource.itemLink))
        or (slotData and (slotData.cached_itemLink or slotData.itemLink))
    if itemLink == nil and GetItemLink then
        itemLink = GetItemLink(bagId, slotIndex)
    end

    return {
        bagId = bagId,
        slotIndex = slotIndex,
        uniqueId = NormalizeSlotIdentityValue(uniqueId),
        itemLink = itemLink,
    }
end

--- Returns whether the live bag slot still contains the item captured earlier.
---@param identity table|nil
---@param bagId number|nil
---@param slotIndex number|nil
---@return boolean current
function BETTERUI.CIM.Utils.IsSlotIdentityCurrent(identity, bagId, slotIndex)
    if not identity then
        return true
    end
    if bagId == nil or slotIndex == nil then
        return false
    end
    if identity.bagId ~= nil and identity.bagId ~= bagId then
        return false
    end
    if identity.slotIndex ~= nil and identity.slotIndex ~= slotIndex then
        return false
    end

    if identity.uniqueId ~= nil then
        local liveIdentity = BETTERUI.CIM.Utils.CaptureSlotIdentity(bagId, slotIndex)
        return liveIdentity and liveIdentity.uniqueId == identity.uniqueId
    end

    if identity.itemLink ~= nil and GetItemLink then
        return GetItemLink(bagId, slotIndex) == identity.itemLink
    end

    return true
end

function BETTERUI.CIM.Utils.SetExternalToolbarHidden(hidden)
    if wykkydsToolbar then
        wykkydsToolbar:SetHidden(hidden)
    end
end

-- House bank bag ids (ESO constants exist before addon load); built once
-- instead of per call, since this runs per row/tooltip.
local HOUSE_BANK_BAG_IDS = {
    BAG_HOUSE_BANK_ONE, BAG_HOUSE_BANK_TWO, BAG_HOUSE_BANK_THREE,
    BAG_HOUSE_BANK_FOUR, BAG_HOUSE_BANK_FIVE, BAG_HOUSE_BANK_SIX,
    BAG_HOUSE_BANK_SEVEN, BAG_HOUSE_BANK_EIGHT, BAG_HOUSE_BANK_NINE,
    BAG_HOUSE_BANK_TEN
}

function BETTERUI.CIM.Utils.GetHouseBankTraitMatches(itemLink)
    if not itemLink then return 0 end
    local total = 0
    for _, bagId in ipairs(HOUSE_BANK_BAG_IDS) do
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
if type(BETTERUI.Utils.GetListTargetData) ~= "function" then
    BETTERUI.Utils.GetListTargetData = getListTargetData
end
