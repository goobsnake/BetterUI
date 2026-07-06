--[[
File: Modules/CIM/Core/Integration/NarrationHelper.lua
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
-- Preserve an existing namespace across reload / load-order variance instead of
-- clobbering it (SEC-L1: global hygiene).
BETTERUI.CIM.Narration = BETTERUI.CIM.Narration or {}

local Narration = BETTERUI.CIM.Narration
local bankingModeLabels = {}

local function GetUIScreenNarrationType()
    return rawget(_G, "NARRATION_TYPE_UI_SCREEN")
end

function Narration.RegisterBankingModeLabels(labelsByMode)
    bankingModeLabels = {}
    if type(labelsByMode) ~= "table" then
        return
    end

    for mode, stringId in pairs(labelsByMode) do
        bankingModeLabels[mode] = stringId
    end
end

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
---@param selectedData table?
---@return table[] narrations
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
        ZO_AppendNarration(narrations, SafeNarrate(GetString(SI_ITEM_FORMAT_STR_EQUIPPED)))
    end

    -- Junk status
    if selectedData.isJunk then
        ZO_AppendNarration(narrations, SafeNarrate(GetString("SI_ITEMFILTERTYPE", ITEMFILTERTYPE_JUNK)))
    end

    -- New item status
    if selectedData.brandNew then
        ZO_AppendNarration(narrations, SafeNarrate(GetString(SI_INVENTORY_NEW_ITEM_TOOLTIP)))
    end

    return narrations
end

-- SCENE TITLE NARRATION

--- Builds narration for a scene title (e.g., "Bank", "Guild Bank: Guildname").
---@param titleText string?
---@return table[] narrations
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
---@param categoryName string?
---@param itemCount integer?
---@return table[] narrations
function Narration.NarrateCategory(categoryName, itemCount)
    local narrations = {}
    ZO_AppendNarration(narrations, SafeNarrate(categoryName))
    if itemCount and itemCount > 0 then
        local itemCountFormat = GetString(rawget(_G, "SI_BETTERUI_NARRATION_ITEM_COUNT_FORMAT")) or "<<1>> items"
        ZO_AppendNarration(narrations, SafeNarrate(zo_strformat(itemCountFormat, itemCount)))
    end
    return narrations
end

-- FOOTER/CURRENCY NARRATION

--- Builds narration for currency display in footer.
---@param currencyType integer?
---@param amount integer?
---@return table[] narrations
function Narration.NarrateCurrency(currencyType, amount)
    local narrations = {}
    if not currencyType or not amount then return narrations end

    local currencyName = GetCurrencyName(currencyType, amount ~= 1, true)
    ZO_AppendNarration(narrations, SafeNarrate(tostring(amount) .. " " .. currencyName))
    return narrations
end

-- MODE NARRATION

--- Builds narration for deposit/withdraw mode in Banking.
---@param mode integer?
---@return table[] narrations
function Narration.NarrateBankingMode(mode)
    local narrations = {}
    local stringId = bankingModeLabels[mode]
    if stringId ~= nil then
        ZO_AppendNarration(narrations, SafeNarrate(GetString(stringId)))
    end
    return narrations
end

--- Builds narration for the available action/keybind labels on the focused row.
---@param actionLabels string[]? Array of action label strings (e.g. { "Equip", "Preview" })
---@return table narrations
function Narration.NarrateActionKeybinds(actionLabels)
    local narrations = {}
    if type(actionLabels) ~= "table" then return narrations end
    for _, label in ipairs(actionLabels) do
        if type(label) == "string" and label ~= "" then
            ZO_AppendNarration(narrations, SafeNarrate(label))
        end
    end
    return narrations
end

-- REGISTRATION HELPERS

--- Appends every narration entry from source into target.
local function AppendNarrations(target, source)
    if type(source) ~= "table" then return end
    for _, n in ipairs(source) do
        ZO_AppendNarration(target, n)
    end
end

--- PLT-006: appends optional category / footer-currency / mode / keybind
--- narration from a providers table. Each getter is independently pcall-guarded
--- so a throwing or nil provider can never break selected-item narration.
---@param narrations table Narration list to append into
---@param providers table Optional getters: getCategory, getCurrency, getMode, getKeybinds
local function AppendProviderNarrations(narrations, providers)
    if providers.getCategory then
        local ok, name, count = pcall(providers.getCategory)
        if ok and name then AppendNarrations(narrations, Narration.NarrateCategory(name, count)) end
    end
    if providers.getCurrency then
        local ok, currencyType, amount = pcall(providers.getCurrency)
        if ok and currencyType then AppendNarrations(narrations, Narration.NarrateCurrency(currencyType, amount)) end
    end
    if providers.getMode then
        local ok, mode = pcall(providers.getMode)
        if ok and mode ~= nil then AppendNarrations(narrations, Narration.NarrateBankingMode(mode)) end
    end
    if providers.getKeybinds then
        local ok, labels = pcall(providers.getKeybinds)
        if ok then AppendNarrations(narrations, Narration.NarrateActionKeybinds(labels)) end
    end
end

--- Queues the custom narration object registered for a BetterUI scene.
---@param sceneName string
---@param narrateHeader boolean?
---@return boolean queued True when the engine queue call was attempted successfully.
function Narration.QueueSceneNarration(sceneName, narrateHeader)
    if not sceneName or not SCREEN_NARRATION_MANAGER then return false end

    local queueCustomEntry = SCREEN_NARRATION_MANAGER.QueueCustomEntry
    if type(queueCustomEntry) ~= "function" then return false end

    local registry = SCREEN_NARRATION_MANAGER.customObjectNarrationInfo
    if type(registry) == "table" and registry[sceneName] == nil then
        return false
    end

    local ok = pcall(queueCustomEntry, SCREEN_NARRATION_MANAGER, sceneName, narrateHeader)
    return ok == true
end

--- Registers a parametric list with SCREEN_NARRATION_MANAGER for item narration.
---@param sceneName string
---@param getSelectedDataFn fun(): table?
---@param getTitleFn fun(): string?
---@param providers table? Optional getters (getCategory/getCurrency/getMode/getKeybinds) that broaden coverage to category/footer-currency/mode/keybind labels (PLT-006)
---@return nil
function Narration.RegisterListNarration(sceneName, getSelectedDataFn, getTitleFn, providers)
    if not SCREEN_NARRATION_MANAGER then return end
    if not sceneName or not getSelectedDataFn then return end

    local narrationInfo = {
        narrationType = GetUIScreenNarrationType(),
        canNarrate = function()
            local ok, result = pcall(function()
                return SCENE_MANAGER:GetCurrentSceneName() == sceneName
            end)
            return ok and result or false
        end,
        selectedNarrationFunction = function()
            local ok, result = pcall(function()
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
                -- PLT-006: optional category / footer-currency / mode / keybind coverage
                if type(providers) == "table" then
                    AppendProviderNarrations(narrations, providers)
                end
                return narrations
            end)
            if ok then return result end
            return {}
        end,
    }

    -- Phase: register-narration
    BETTERUI.CIM.SafeExecute("NarrationHelper:RegisterListNarration:" .. sceneName, function()
        SCREEN_NARRATION_MANAGER:RegisterCustomObject(sceneName, narrationInfo)
    end)
end
