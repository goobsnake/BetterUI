--[[
File: Modules/CIM/Core/NarrationHelper.lua
Purpose: Centralized gamepad narration helper for all BetterUI custom screens.
         Provides screen-reader accessible narration for list entries,
         category headers, footer currency, and action context.

ACC-001: Narration parity for custom BetterUI screens.

USAGE:
    -- Register a parametric list for narration:
    BETTERUI.CIM.Narration.RegisterListNarration(sceneName, listControl, getNarrationFn)

    -- Build narration for a selected item entry:
    local narrations = BETTERUI.CIM.Narration.NarrateItemEntry(selectedData)
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Narration = {}

local Narration = BETTERUI.CIM.Narration

-- HELPERS

--- Safely creates a narratable object from text.
local function SafeNarrate(text)
    if not text or text == "" or text == "-" then return nil end
    if not SCREEN_NARRATION_MANAGER then return nil end
    return SCREEN_NARRATION_MANAGER:CreateNarratableObject(text)
end

-- ITEM ENTRY NARRATION

--- Builds narration text for an inventory/banking item entry.
--- Narrates: name, quality, stack count, category, equipped/junk status, value.
function Narration.NarrateItemEntry(selectedData)
    local narrations = {}
    if not selectedData then return narrations end

    -- Item name
    local name = selectedData.name or (selectedData.dataSource and selectedData.dataSource.name)
    ZO_AppendNarration(narrations, SafeNarrate(name))

    -- Quality
    local quality = selectedData.quality or (selectedData.dataSource and selectedData.dataSource.quality)
    if quality and quality > ITEM_DISPLAY_QUALITY_TRASH then
        local qualityString = GetString("SI_ITEMDISPLAYQUALITY", quality)
        ZO_AppendNarration(narrations, SafeNarrate(qualityString))
    end

    -- Stack count
    local stackCount = selectedData.stackCount or (selectedData.dataSource and selectedData.dataSource.stackCount)
    if stackCount and stackCount > 1 then
        ZO_AppendNarration(narrations, SafeNarrate(zo_strformat(SI_SCREEN_NARRATION_STACK_COUNT_FORMATTER, stackCount)))
    end

    -- Category
    local category = selectedData.bestItemCategoryName or selectedData.bestGamepadItemCategoryName
    ZO_AppendNarration(narrations, SafeNarrate(category))

    -- Equipped status
    if selectedData.isEquippedInCurrentCategory or selectedData.isEquippedInAnotherCategory then
        ZO_AppendNarration(narrations, SafeNarrate(GetString(rawget(_G, "SI_SCREEN_NARRATION_EQUIPPED"))))
    end

    -- Junk status
    if selectedData.isJunk then
        ZO_AppendNarration(narrations, SafeNarrate(GetString(rawget(_G, "SI_ITEM_ACTION_MARK_AS_NOT_JUNK"))))
    end

    -- New item status
    if selectedData.brandNew then
        ZO_AppendNarration(narrations, SafeNarrate(GetString(rawget(_G, "SI_INVENTORY_NEW_ICON_TOOLTIP"))))
    end

    return narrations
end

-- SCENE TITLE NARRATION

--- Builds narration for a scene title (e.g., "Bank", "Guild Bank: Guildname").
function Narration.NarrateSceneTitle(titleText)
    local narrations = {}
    -- Strip color codes for narration
    if titleText then
        local cleanTitle = titleText:gsub("|c%x%x%x%x%x%x", ""):gsub("|r", "")
        ZO_AppendNarration(narrations, SafeNarrate(cleanTitle))
    end
    return narrations
end

-- CATEGORY NARRATION

--- Builds narration for a category header change.
function Narration.NarrateCategory(categoryName, itemCount)
    local narrations = {}
    ZO_AppendNarration(narrations, SafeNarrate(categoryName))
    if itemCount and itemCount > 0 then
        ZO_AppendNarration(narrations, SafeNarrate(tostring(itemCount) .. " items"))
    end
    return narrations
end

-- FOOTER/CURRENCY NARRATION

--- Builds narration for currency display in footer.
function Narration.NarrateCurrency(currencyType, amount)
    local narrations = {}
    if not currencyType or not amount then return narrations end

    local currencyName = GetCurrencyName(currencyType, amount ~= 1, true)
    ZO_AppendNarration(narrations, SafeNarrate(tostring(amount) .. " " .. currencyName))
    return narrations
end

-- MODE NARRATION

--- Builds narration for deposit/withdraw mode in Banking.
function Narration.NarrateBankingMode(mode)
    local narrations = {}
    if mode == BETTERUI.Banking.LIST_DEPOSIT then
        ZO_AppendNarration(narrations, SafeNarrate(GetString(rawget(_G, "SI_BANK_DEPOSIT"))))
    elseif mode == BETTERUI.Banking.LIST_WITHDRAW then
        ZO_AppendNarration(narrations, SafeNarrate(GetString(rawget(_G, "SI_BANK_WITHDRAW"))))
    end
    return narrations
end

-- REGISTRATION HELPERS

--- Registers a parametric list with SCREEN_NARRATION_MANAGER for item narration.
function Narration.RegisterListNarration(sceneName, getSelectedDataFn, getTitleFn)
    if not SCREEN_NARRATION_MANAGER then return end
    if not sceneName or not getSelectedDataFn then return end

    local narrationInfo = {
        canNarrate = function()
            return SCENE_MANAGER:GetCurrentSceneName() == sceneName
        end,
        selectedNarrationFunction = function()
            local narrations = {}
            -- Title
            if getTitleFn then
                local title = getTitleFn()
                local titleNarrations = Narration.NarrateSceneTitle(title)
                for _, n in ipairs(titleNarrations) do
                    ZO_AppendNarration(narrations, n)
                end
            end
            -- Selected item
            local selectedData = getSelectedDataFn()
            if selectedData then
                local itemNarrations = Narration.NarrateItemEntry(selectedData)
                for _, n in ipairs(itemNarrations) do
                    ZO_AppendNarration(narrations, n)
                end
            end
            return narrations
        end,
    }

    -- Phase: register-narration
    BETTERUI.CIM.SafeExecute("NarrationHelper:RegisterListNarration:" .. sceneName, function()
        SCREEN_NARRATION_MANAGER:RegisterCustomObject(sceneName, narrationInfo)
    end)
end
