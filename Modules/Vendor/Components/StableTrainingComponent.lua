--[[
File: Modules/Vendor/Components/StableTrainingComponent.lua
Purpose: Stable training tab component for the Vendor module.
]]

local Vendor = BETTERUI.Vendor

-- BUI-CONS-001: focused-row resolution uses BETTERUI.CIM.Utils.SafeGetTargetData.

local STABLE_TRAIN_ORDER = {
    RIDING_TRAIN_SPEED,
    RIDING_TRAIN_STAMINA,
    RIDING_TRAIN_CARRYING_CAPACITY,
}

local DEFAULT_STABLE_INTERACTION_ICON = "EsoUI/Art/Collections/Default/collections_default_mount.dds"

--- English fallback warning shown when the player has no active mount skin.
local NO_ACTIVE_MOUNT_WARNING = "No active mount skin selected."

--- Resolve the active mount collectible icon, falling back to defaultIcon when
--- no mount skin is active or the engine APIs are unavailable.
---@param defaultIcon string|nil
---@return string icon
local function ResolveActiveMountIcon(defaultIcon)
    if type(GetActiveCollectibleByType) ~= "function" then
        return defaultIcon or DEFAULT_STABLE_INTERACTION_ICON
    end

    local collectibleId = GetActiveCollectibleByType(COLLECTIBLE_CATEGORY_TYPE_MOUNT, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
    if not collectibleId or collectibleId == 0 then
        return defaultIcon or DEFAULT_STABLE_INTERACTION_ICON
    end

    if type(GetCollectibleIcon) == "function" then
        local icon = GetCollectibleIcon(collectibleId)
        if icon and icon ~= "" then
            return icon
        end
    end

    return defaultIcon or DEFAULT_STABLE_INTERACTION_ICON
end

Vendor.ResolveActiveMountIcon = Vendor.ResolveActiveMountIcon or ResolveActiveMountIcon

local function ResolveStableInteractionIcon()
    return ResolveActiveMountIcon(DEFAULT_STABLE_INTERACTION_ICON)
end

Vendor.ResolveStableInteractionIcon = Vendor.ResolveStableInteractionIcon or ResolveStableInteractionIcon

---@return string warning Localized warning when no active mount skin is set.
local function GetStableNoMountWarning()
    local stringId = rawget(_G, "SI_BETTERUI_STABLE_NO_MOUNT_WARNING")
    if stringId then
        local text = GetString(stringId)
        if text and text ~= "" then
            return text
        end
    end
    return NO_ACTIVE_MOUNT_WARNING
end

Vendor.GetStableNoMountWarning = Vendor.GetStableNoMountWarning or GetStableNoMountWarning

local function BuildStableTrainingIcon(trainingType)
    if STABLE_TRAINING_TEXTURES_GAMEPAD then
        return STABLE_TRAINING_TEXTURES_GAMEPAD[trainingType]
    end
    return nil
end

local function IsStableSkillTrainable(trainingType, bonus, maxBonus)
    if not trainingType then
        return false
    end
    if (bonus or 0) >= (maxBonus or 0) then
        return false
    end
    if type(GetTimeUntilCanBeTrained) == "function" and GetTimeUntilCanBeTrained() ~= 0 then
        return false
    end
    if STABLE_MANAGER and STABLE_MANAGER.CanAffordTraining then
        return STABLE_MANAGER:CanAffordTraining()
    end
    return false
end

local function BuildStableTrainingStateText(isAtMax, timeUntilCanTrain)
    if isAtMax then
        return "MAX"
    end
    if (timeUntilCanTrain or 0) == 0 then
        return GetString(rawget(_G, "SI_GAMEPAD_STABLE_TRAINABLE_READY") or "SI_GAMEPAD_STABLE_TRAINABLE_READY")
    end
    if ZO_FormatTimeMilliseconds then
        return ZO_FormatTimeMilliseconds(
            timeUntilCanTrain,
            TIME_FORMAT_STYLE_COLONS,
            TIME_FORMAT_PRECISION_TWELVE_HOUR
        )
    end
    return "-"
end

local function BuildStableTrainingValueText(trainingCost, canAfford, isAtMax)
    if isAtMax or (trainingCost or 0) <= 0 then
        return "-"
    end

    if ZO_Currency_FormatGamepad then
        local format = canAfford and ZO_CURRENCY_FORMAT_WHITE_AMOUNT_ICON or ZO_CURRENCY_FORMAT_ERROR_AMOUNT_ICON
        return ZO_Currency_FormatGamepad(CURT_MONEY, trainingCost, format)
    end

    return tostring(trainingCost)
end

-- COMPONENT TABLE
Vendor.StableTrainingComponent = Vendor.StableTrainingComponent or {}
local StableTraining = Vendor.StableTrainingComponent

function StableTraining:Activate(vendorInstance)
    -- Surface a warning when the player has no active mount skin so the generic
    -- fallback icon is not mistaken for a bug. First-cut: shown once per tab
    -- activation; the maintainer can move this to a tooltip/header as needed.
    if type(GetActiveCollectibleByType) == "function" then
        local collectibleId = GetActiveCollectibleByType(COLLECTIBLE_CATEGORY_TYPE_MOUNT, GAMEPLAY_ACTOR_CATEGORY_PLAYER)
        if not collectibleId or collectibleId == 0 then
            if BETTERUI.CIM and BETTERUI.CIM.UserAlertText then
                BETTERUI.CIM.UserAlertText("Stable:NoMount", GetStableNoMountWarning())
            end
        end
    end

    vendorInstance:RefreshList()
end

function StableTraining:Deactivate(_vendorInstance)
    -- No teardown required.
end

function StableTraining:GetPrimaryActionName()
    return GetString(rawget(_G, "SI_GAMEPAD_STABLE_TRAIN") or "SI_GAMEPAD_STABLE_TRAIN")
end

function StableTraining:IsPrimaryActionEnabled(vendorInstance)
    local selectedData = BETTERUI.CIM.Utils.SafeGetTargetData(vendorInstance and vendorInstance.list)
    if not selectedData then
        return false
    end
    local ds = selectedData.dataSource or selectedData
    return ds and ds.isSkillTrainable == true
end

---@param _vendorInstance BETTERUI.Vendor.Class
---@return BetterUIKeybindDescriptorGroup
function StableTraining:GetCategories(_vendorInstance)
    return {
        {
            key = "stable_all",
            name = GetString(rawget(_G, "SI_STATS_RIDING_SKILL") or "SI_STATS_RIDING_SKILL"),
            iconFile = Vendor.ResolveStableInteractionIcon(),
            itemCount = #STABLE_TRAIN_ORDER,
        },
    }
end

function StableTraining:OnPrimaryAction(vendorInstance)
    local selectedData = BETTERUI.CIM.Utils.SafeGetTargetData(vendorInstance and vendorInstance.list)
    if not selectedData then
        return
    end
    local ds = selectedData.dataSource or selectedData
    if not (ds and ds.trainingType and ds.isSkillTrainable) then
        return
    end

    local L = BETTERUI.Log
    if L and L.TraceEvent then
        L.TraceEvent(L.CATEGORY.ACTION, "vendor.stable_train", "request", {
            module = "Vendor",
            scene = BETTERUI_VENDOR_SCENE_NAME,
            feature = "vendor-stable",
            fn = "Vendor.StableTrainingComponent.OnPrimaryAction",
            ["function"] = "Vendor.StableTrainingComponent.OnPrimaryAction",
            mode = vendorInstance and vendorInstance.GetCurrentMode and vendorInstance:GetCurrentMode() or nil,
            trainingType = ds.trainingType,
            item = L.DescribeItem and L.DescribeItem(ds, "selected") or ds.name,
        })
    end

    TrainRiding(ds.trainingType)

    if L and L.TraceEvent then
        L.TraceEvent(L.CATEGORY.ACTION, "vendor.stable_train", "requested", {
            module = "Vendor",
            scene = BETTERUI_VENDOR_SCENE_NAME,
            feature = "vendor-stable",
            fn = "Vendor.StableTrainingComponent.OnPrimaryAction",
            ["function"] = "Vendor.StableTrainingComponent.OnPrimaryAction",
            mode = vendorInstance and vendorInstance.GetCurrentMode and vendorInstance:GetCurrentMode() or nil,
            trainingType = ds.trainingType,
            item = L.DescribeItem and L.DescribeItem(ds, "selected") or ds.name,
        })
    end

    vendorInstance:RefreshList()
end

function StableTraining:BuildList(vendorInstance)
    local list = vendorInstance.list
    if not list then
        return
    end

    local searchQuery = Vendor.NormalizeSearchQuery and Vendor.NormalizeSearchQuery(vendorInstance and vendorInstance.searchQuery) or nil
    local skillHeader = GetString(rawget(_G, "SI_STATS_RIDING_SKILL") or "SI_STATS_RIDING_SKILL")
    local trainingCost = (type(GetTrainingCost) == "function" and GetTrainingCost()) or 0
    local timeUntilCanTrain = (type(GetTimeUntilCanBeTrained) == "function" and GetTimeUntilCanBeTrained()) or 0
    local canAffordTraining = (STABLE_MANAGER and STABLE_MANAGER.CanAffordTraining and STABLE_MANAGER:CanAffordTraining()) or false
    local isTrainWindowOpen = timeUntilCanTrain == 0

    for _, trainingType in ipairs(STABLE_TRAIN_ORDER) do
        local bonus, maxBonus = 0, 0
        if STABLE_MANAGER and STABLE_MANAGER.GetStats then
            bonus, maxBonus = STABLE_MANAGER:GetStats(trainingType)
        end
        local isAtMax = (bonus or 0) >= (maxBonus or 0)

        local formatStringId = trainingType == RIDING_TRAIN_SPEED
            and (rawget(_G, "SI_MOUNT_ATTRIBUTE_SPEED_FORMAT") or "SI_MOUNT_ATTRIBUTE_SPEED_FORMAT")
            or (rawget(_G, "SI_MOUNT_ATTRIBUTE_SIMPLE_FORMAT") or "SI_MOUNT_ATTRIBUTE_SIMPLE_FORMAT")
        local statText = zo_strformat(formatStringId, bonus or 0)
        local trainingName = GetString("SI_RIDINGTRAINTYPE", trainingType)
        local icon = BuildStableTrainingIcon(trainingType)
        local trainable = IsStableSkillTrainable(trainingType, bonus, maxBonus)
        local stableStateText = BuildStableTrainingStateText(isAtMax, timeUntilCanTrain)
        local valueText = BuildStableTrainingValueText(trainingCost, canAffordTraining, isAtMax)
        local matchesSearch = (not Vendor.MatchesSearchQuery) or Vendor.MatchesSearchQuery(searchQuery, trainingName)

        if matchesSearch then
            local rowData = {
                name = trainingName,
                icon = icon,
                price = (isTrainWindowOpen and not isAtMax) and trainingCost or 0,
                stackCount = 1,
                stack = 1,
                trainingType = trainingType,
                bonus = bonus or 0,
                maxBonus = maxBonus or 0,
                isSkillTrainable = trainable,
                trainStateText = stableStateText,
                valueText = valueText,
                progressCurrent = bonus or 0,
                progressMax = maxBonus or 0,
                bestGamepadItemCategoryName = skillHeader,
                statValue = statText,
            }

            local entry = ZO_GamepadEntryData:New(rowData.name, rowData.icon)
            entry:SetDataSource(rowData)
            entry.narrationText = function()
                return rowData.name
            end

            list:AddEntry("BETTERUI_GamepadStableTrainingEntryTemplate", entry)
        end
    end
end
