--[[
File: Modules/CIM/Core/SettingsFactory.lua
Purpose: Factory functions for creating standardized settings panels.
         Ensures consistent LAM panel appearance across modules.
Author: BetterUI Team
Last Modified: 2026-01-27
]]

-- ============================================================================
-- NAMESPACE INITIALIZATION
-- ============================================================================

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.Settings then BETTERUI.CIM.Settings = {} end

-- ============================================================================
-- SETTINGS METADATA REGISTRY
-- ============================================================================

local SETTINGS_METADATA_REGISTRY = {
    Shared = {
        showIconUnboundItem = {
            labelStringId = SI_BETTERUI_ICON_UNBOUND,
            tooltipStringId = SI_BETTERUI_ICON_UNBOUND_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "iconCustomization",
            resetGroup = "iconCustomization",
        },
        showIconEnchantment = {
            labelStringId = SI_BETTERUI_ICON_ENCHANTMENT,
            tooltipStringId = SI_BETTERUI_ICON_ENCHANTMENT_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "iconCustomization",
            resetGroup = "iconCustomization",
        },
        showIconSetGear = {
            labelStringId = SI_BETTERUI_ICON_SET_GEAR,
            tooltipStringId = SI_BETTERUI_ICON_SET_GEAR_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "iconCustomization",
            resetGroup = "iconCustomization",
        },
        showIconResearchableTrait = {
            labelStringId = SI_BETTERUI_ICON_RESEARCHABLE_TRAIT,
            tooltipStringId = SI_BETTERUI_ICON_RESEARCHABLE_TRAIT_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "iconCustomization",
            resetGroup = "iconCustomization",
        },
        showIconUnknownRecipe = {
            labelStringId = SI_BETTERUI_ICON_UNKNOWN_RECIPE,
            tooltipStringId = SI_BETTERUI_ICON_UNKNOWN_RECIPE_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "iconCustomization",
            resetGroup = "iconCustomization",
        },
        showIconUnknownBook = {
            labelStringId = SI_BETTERUI_ICON_UNKNOWN_BOOK,
            tooltipStringId = SI_BETTERUI_ICON_UNKNOWN_BOOK_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "iconCustomization",
            resetGroup = "iconCustomization",
        },
    },

    Inventory = {
        quickDestroy = {
            labelStringId = SI_BETTERUI_QUICK_DESTROY,
            tooltipStringId = SI_BETTERUI_QUICK_DESTROY_TOOLTIP,
            defaultValue = false,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        enableBatchDestroy = {
            labelStringId = SI_BETTERUI_ENABLE_BATCH_DESTROY,
            tooltipStringId = SI_BETTERUI_ENABLE_BATCH_DESTROY_TOOLTIP,
            defaultValue = false,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        enableCarousel = {
            labelStringId = SI_BETTERUI_ENABLE_CAROUSEL_NAV,
            tooltipStringId = SI_BETTERUI_ENABLE_CAROUSEL_NAV_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        useTriggersForSkip = {
            labelStringId = SI_BETTERUI_TRIGGER_SKIP_TYPE,
            tooltipStringId = SI_BETTERUI_TRIGGER_SKIP_TYPE_TOOLTIP,
            defaultValue = false,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        triggerSpeed = {
            labelStringId = SI_BETTERUI_TRIGGER_SKIP,
            tooltipStringId = SI_BETTERUI_TRIGGER_SKIP_TOOLTIP,
            defaultValue = 10,
            dependency = {
                module = "Inventory",
                key = "useTriggersForSkip",
            },
            sortGroup = "general",
            resetGroup = "general",
        },
        bindOnEquipProtection = {
            labelStringId = SI_BETTERUI_BOE_PROTECTION,
            tooltipStringId = SI_BETTERUI_BOE_PROTECTION_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        enableCompanionJunk = {
            labelStringId = SI_BETTERUI_ENABLE_COMPANION_JUNK,
            tooltipStringId = SI_BETTERUI_ENABLE_COMPANION_JUNK_TOOLTIP,
            defaultValue = false,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
    },

    Banking = {
        enableCarousel = {
            labelStringId = SI_BETTERUI_ENABLE_CAROUSEL_NAV,
            tooltipStringId = SI_BETTERUI_ENABLE_CAROUSEL_NAV_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        useTriggersForSkip = {
            labelStringId = SI_BETTERUI_TRIGGER_SKIP_TYPE,
            tooltipStringId = SI_BETTERUI_TRIGGER_SKIP_TYPE_TOOLTIP,
            defaultValue = false,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        triggerSpeed = {
            labelStringId = SI_BETTERUI_TRIGGER_SKIP,
            tooltipStringId = SI_BETTERUI_TRIGGER_SKIP_TOOLTIP,
            defaultValue = 10,
            dependency = {
                module = "Banking",
                key = "useTriggersForSkip",
            },
            sortGroup = "general",
            resetGroup = "general",
        },
    },

    GeneralInterface = {
        chatHistory = {
            labelStringId = SI_BETTERUI_CHAT_HISTORY,
            tooltipStringId = SI_BETTERUI_CHAT_HISTORY_TOOLTIP,
            defaultValue = 200,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        removeDeleteDialog = {
            labelStringId = SI_BETTERUI_REMOVE_DELETE_MAIL_CONFIRM,
            tooltipStringId = nil,
            defaultValue = false,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
        showMarketPrice = {
            labelStringId = SI_BETTERUI_SHOW_MARKET_PRICE,
            tooltipStringId = SI_BETTERUI_SHOW_MARKET_PRICE_TOOLTIP,
            defaultValue = true,
            dependency = {
                addons = { "MasterMerchant", "ArkadiusTradeTools", "TamrielTradeCentre" },
            },
            sortGroup = "marketIntegration",
            resetGroup = "marketIntegration",
        },
        guildStoreErrorSuppress = {
            labelStringId = SI_BETTERUI_GS_ERROR_SUPPRESS,
            tooltipStringId = SI_BETTERUI_GS_ERROR_SUPPRESS_TOOLTIP,
            defaultValue = true,
            dependency = {
                addons = { "MasterMerchant", "ArkadiusTradeTools" },
            },
            sortGroup = "marketIntegration",
            resetGroup = "marketIntegration",
        },
        attIntegration = {
            labelStringId = SI_BETTERUI_ATT_INTEGRATION,
            tooltipStringId = SI_BETTERUI_ATT_INTEGRATION_TOOLTIP,
            defaultValue = true,
            dependency = {
                addons = { "ArkadiusTradeTools" },
            },
            sortGroup = "marketIntegration",
            resetGroup = "marketIntegration",
        },
        mmIntegration = {
            labelStringId = SI_BETTERUI_MM_INTEGRATION,
            tooltipStringId = SI_BETTERUI_MM_INTEGRATION_TOOLTIP,
            defaultValue = true,
            dependency = {
                addons = { "MasterMerchant" },
            },
            sortGroup = "marketIntegration",
            resetGroup = "marketIntegration",
        },
        ttcIntegration = {
            labelStringId = SI_BETTERUI_TTC_INTEGRATION,
            tooltipStringId = SI_BETTERUI_TTC_INTEGRATION_TOOLTIP,
            defaultValue = true,
            dependency = {
                addons = { "TamrielTradeCentre" },
            },
            sortGroup = "marketIntegration",
            resetGroup = "marketIntegration",
        },
        marketPricePriority = {
            labelStringId = SI_BETTERUI_MARKET_PRICE_PRIORITY,
            tooltipStringId = SI_BETTERUI_MARKET_PRICE_PRIORITY_TOOLTIP,
            defaultValue = "mm_att_ttc",
            dependency = nil,
            sortGroup = "marketIntegration",
            resetGroup = "marketIntegration",
        },
        showStyleTrait = {
            labelStringId = SI_BETTERUI_SHOW_STYLE_TRAIT,
            tooltipStringId = SI_BETTERUI_SHOW_STYLE_TRAIT_TOOLTIP,
            defaultValue = true,
            dependency = {
                module = "CIM",
                key = "enableTooltipEnhancements",
            },
            sortGroup = "enhancedTooltips",
            resetGroup = "enhancedTooltips",
        },
    },

    CIM = {
        rhScrollSpeed = {
            labelStringId = SI_BETTERUI_MOUSE_SCROLL_SPEED,
            tooltipStringId = SI_BETTERUI_MOUSE_SCROLL_SPEED_TOOLTIP,
            defaultValue = 50,
            dependency = nil,
            sortGroup = "generalInterfaceGeneral",
            resetGroup = "generalInterfaceGeneral",
        },
        enableTooltipEnhancements = {
            labelStringId = SI_BETTERUI_ENABLE_TOOLTIP_ENHANCEMENTS,
            tooltipStringId = SI_BETTERUI_ENABLE_TOOLTIP_ENHANCEMENTS_TOOLTIP,
            defaultValue = true,
            dependency = nil,
            sortGroup = "enhancedTooltips",
            resetGroup = "enhancedTooltips",
        },
        tooltipSize = {
            labelStringId = SI_BETTERUI_TOOLTIP_FONT_SIZE,
            tooltipStringId = SI_BETTERUI_TOOLTIP_FONT_SIZE_TOOLTIP,
            defaultValue = 24,
            dependency = {
                module = "CIM",
                key = "enableTooltipEnhancements",
            },
            sortGroup = "enhancedTooltips",
            resetGroup = "enhancedTooltips",
        },
    },

    Nameplates = {
        m_enabled = {
            labelStringId = SI_BETTERUI_NAMEPLATES_ENABLED,
            tooltipStringId = SI_BETTERUI_NAMEPLATES_ENABLED_TOOLTIP,
            defaultValue = false,
            dependency = nil,
            sortGroup = "general",
            resetGroup = "general",
        },
    },
}

local function CloneDefaultValue(value)
    if type(value) ~= "table" then
        return value
    end

    local clone = {}
    for key, item in pairs(value) do
        if type(item) == "table" then
            clone[key] = CloneDefaultValue(item)
        else
            clone[key] = item
        end
    end
    return clone
end

--- Returns centralized metadata for a module setting key.
--- Falls back to Shared metadata when module-specific metadata is unavailable.
--- @param moduleName string Module namespace key
--- @param settingKey string Setting key within module SavedVars
--- @return table|nil metadata Metadata descriptor or nil
function BETTERUI.CIM.Settings.GetSettingMetadata(moduleName, settingKey)
    if type(settingKey) ~= "string" then
        return nil
    end

    local moduleRegistry = SETTINGS_METADATA_REGISTRY[moduleName]
    if type(moduleRegistry) == "table" and moduleRegistry[settingKey] then
        return moduleRegistry[settingKey]
    end

    local sharedRegistry = SETTINGS_METADATA_REGISTRY.Shared
    if type(sharedRegistry) == "table" then
        return sharedRegistry[settingKey]
    end

    return nil
end

--- Returns the default value for a module setting using metadata first, then DefaultsRegistry.
--- @param moduleName string Module namespace key
--- @param settingKey string Setting key within module SavedVars
--- @param fallback any Optional fallback value
--- @return any defaultValue Default value or provided fallback
function BETTERUI.CIM.Settings.GetSettingDefault(moduleName, settingKey, fallback)
    local metadata = BETTERUI.CIM.Settings.GetSettingMetadata(moduleName, settingKey)
    if metadata and metadata.defaultValue ~= nil then
        return CloneDefaultValue(metadata.defaultValue)
    end

    if BETTERUI.Defaults and BETTERUI.Defaults.GetDefault then
        local registryDefault = BETTERUI.Defaults.GetDefault(moduleName, settingKey)
        if registryDefault ~= nil then
            return CloneDefaultValue(registryDefault)
        end
    end

    return fallback
end

--- Resets module settings that belong to the requested reset group.
--- @param moduleName string Module namespace key
--- @param resetGroup string Logical reset bucket from metadata schema
function BETTERUI.CIM.Settings.ResetModuleSettingsByGroup(moduleName, resetGroup)
    if type(moduleName) ~= "string" or type(resetGroup) ~= "string" then
        return
    end

    local settings = BETTERUI.Settings and BETTERUI.Settings.Modules and BETTERUI.Settings.Modules[moduleName]
    if type(settings) ~= "table" then
        return
    end

    local function applyRegistryReset(registryTable)
        if type(registryTable) ~= "table" then
            return
        end

        for settingKey, metadata in pairs(registryTable) do
            if type(metadata) == "table" and metadata.resetGroup == resetGroup then
                local defaultValue = BETTERUI.CIM.Settings.GetSettingDefault(moduleName, settingKey, nil)
                if defaultValue ~= nil then
                    settings[settingKey] = defaultValue
                end
            end
        end
    end

    -- Shared metadata first, then module metadata to allow module-specific overrides.
    applyRegistryReset(SETTINGS_METADATA_REGISTRY.Shared)
    applyRegistryReset(SETTINGS_METADATA_REGISTRY[moduleName])
end

-- ============================================================================
-- SETTINGS SORT HELPERS
-- ============================================================================

local function NormalizeSubmenuSortName(name)
    if type(name) ~= "string" then
        return ""
    end

    local normalized = name
    normalized = normalized:gsub("|c%x%x%x%x%x%x", "")
    normalized = normalized:gsub("|r", "")
    normalized = normalized:gsub("|t[^|]+|t", "")
    normalized = normalized:gsub("%s+", " ")
    normalized = normalized:gsub("^%s+", "")
    normalized = normalized:gsub("%s+$", "")

    if zo_strlower then
        return zo_strlower(normalized)
    end
    return string.lower(normalized)
end

local function SortSubmenuRangeByName(controls, startIndex, endIndex)
    local range = {}
    for i = startIndex, endIndex do
        range[#range + 1] = controls[i]
    end

    table.sort(range, function(left, right)
        local leftKey = NormalizeSubmenuSortName(left.name)
        local rightKey = NormalizeSubmenuSortName(right.name)
        if leftKey == rightKey then
            return tostring(left.name) < tostring(right.name)
        end
        return leftKey < rightKey
    end)

    for i = 1, #range do
        controls[startIndex + i - 1] = range[i]
    end
end

--- Sorts contiguous top-level submenu rows alphabetically by display name.
--- Non-submenu controls remain in-place.
--- @param controls table LAM controls array
--- @return table controls The same table reference, sorted in place
function BETTERUI.CIM.Settings.SortTopLevelSubmenusAlphabetically(controls)
    if type(controls) ~= "table" then
        return controls
    end

    local index = 1
    while index <= #controls do
        local control = controls[index]
        local isSubmenu = type(control) == "table" and control.type == "submenu" and type(control.name) == "string"

        if isSubmenu then
            local startIndex = index
            local endIndex = index
            while endIndex + 1 <= #controls do
                local nextControl = controls[endIndex + 1]
                local nextIsSubmenu = type(nextControl) == "table" and nextControl.type == "submenu" and
                    type(nextControl.name) == "string"
                if not nextIsSubmenu then
                    break
                end
                endIndex = endIndex + 1
            end

            if endIndex > startIndex then
                SortSubmenuRangeByName(controls, startIndex, endIndex)
            end
            index = endIndex + 1
        else
            index = index + 1
        end
    end

    return controls
end

local SORTABLE_SETTING_TYPES = {
    checkbox = true,
    colorpicker = true,
    dropdown = true,
    editbox = true,
    slider = true,
    -- Intentionally exclude "button" so reset controls stay in authored bottom position.
}

local function NormalizeSettingSortName(name)
    if type(name) ~= "string" then
        return ""
    end

    local normalized = name
    normalized = normalized:gsub("|c%x%x%x%x%x%x", "") -- Color tags
    normalized = normalized:gsub("|r", "")
    normalized = normalized:gsub("|t[^|]+|t", "")      -- Texture tags
    normalized = normalized:gsub("^%s*⚠️%s*", "")
    normalized = normalized:gsub("^%s*⚠%s*", "")
    normalized = normalized:gsub("%s+", " ")
    normalized = normalized:gsub("^%s+", "")
    normalized = normalized:gsub("%s+$", "")

    if zo_strlower then
        return zo_strlower(normalized)
    end
    return string.lower(normalized)
end

local function IsSortableSettingControl(control)
    if type(control) ~= "table" then
        return false
    end
    local controlType = control.type
    if not controlType or not SORTABLE_SETTING_TYPES[controlType] then
        return false
    end
    return type(control.name) == "string"
end

local function SortSettingControlRange(controls, startIndex, endIndex)
    local range = {}
    for i = startIndex, endIndex do
        range[#range + 1] = controls[i]
    end

    local function GetSortWeight(control)
        if type(control) ~= "table" then
            return 1
        end
        if control.sortAlwaysFirst then
            return 0
        end
        if control.sortAlwaysLast then
            return 2
        end
        return 1
    end

    table.sort(range, function(left, right)
        local leftWeight = GetSortWeight(left)
        local rightWeight = GetSortWeight(right)
        if leftWeight ~= rightWeight then
            return leftWeight < rightWeight
        end

        local leftKey = NormalizeSettingSortName(left.name)
        local rightKey = NormalizeSettingSortName(right.name)
        if leftKey == rightKey then
            return tostring(left.name) < tostring(right.name)
        end
        return leftKey < rightKey
    end)

    for i = 1, #range do
        controls[startIndex + i - 1] = range[i]
    end
end

--- Sorts setting controls alphabetically by display name.
--- Behavior:
--- 1. Sorts only contiguous runs of setting controls (checkbox/dropdown/slider/etc.).
--- 2. Leaves structural controls (header/description/divider/submenu) in place.
--- 3. Optionally recurses into submenu controls.
--- @param controls table LAM controls array
--- @param recursive boolean|nil Recurse into submenus (default: true)
--- @return table controls The same table reference, sorted in place
function BETTERUI.CIM.Settings.SortSettingsAlphabetically(controls, recursive)
    if type(controls) ~= "table" then
        return controls
    end

    if recursive == nil then
        recursive = true
    end

    local index = 1
    while index <= #controls do
        local control = controls[index]

        if recursive and type(control) == "table" and control.type == "submenu" and type(control.controls) == "table" then
            if not control.disableAutoSort then
                BETTERUI.CIM.Settings.SortSettingsAlphabetically(control.controls, true)
            end
        end

        if IsSortableSettingControl(control) then
            local startIndex = index
            local endIndex = index
            while endIndex + 1 <= #controls and IsSortableSettingControl(controls[endIndex + 1]) do
                endIndex = endIndex + 1
            end
            if endIndex > startIndex then
                SortSettingControlRange(controls, startIndex, endIndex)
            end
            index = endIndex + 1
        else
            index = index + 1
        end
    end

    return controls
end

-- ============================================================================
-- SETTINGS PANEL FACTORY
-- ============================================================================

--[[
Function: BETTERUI.Init_ModulePanel
Description: Creates a standardized module configuration panel for LibAddonMenu.
Rationale: Ensures consistent settings menu appearance across modules.
Mechanism: Returns a table matching LAM's panel specification.
References: Used by all Modules (Inventory, Banking, etc.) in their Initialization.
param: moduleName (string) - The display name of the module.
param: moduleDesc (string) - The description text.
return: table - The LAM panel configuration table.
]]
function BETTERUI.Init_ModulePanel(moduleName, moduleDesc)
    return {
        type = "panel",
        name = "|t24:24:/esoui/art/buttons/gamepad/xbox/nav_xbone_b.dds|t " .. BETTERUI.name .. " (" .. moduleName .. ")",
        displayName = "|c0066ffBETTERUI|r :: " .. moduleDesc,
        author = "prasoc, RockingDice, Goobsnake",
        version = BETTERUI.version,
        slashCommand = "/betterui",
        registerForRefresh = true,
        registerForDefaults = true
    }
end

-- ============================================================================
-- FONT SETTINGS FACTORY
-- ============================================================================

--[[
Function: BETTERUI.CIM.Settings.CreateFontSubmenuOptions
Description: Creates LAM submenu options for font customization.
Rationale: Consolidates identical font settings structure from Banking and Inventory.
Mechanism:
  1. Creates "Name Font" submenu with dropdown, size slider, style dropdown, reset button
  2. Creates "Column Font" submenu with dropdown, size slider, style dropdown, reset button
  3. Uses shared BETTERUI.CIM.Font definitions
param: moduleName (string) - The module name key (e.g., "Banking", "Inventory")
param: defaults (table) - Module-specific defaults with nameFont, nameFontSize, nameFontStyle, columnFont, columnFontSize, columnFontStyle
param: fontChoices (table) - Font name choices array
param: fontValues (table) - Font path values array
param: styleChoices (table) - Font style choices array
param: styleValues (table) - Font style values array
param: strings (table) - Localization string IDs { header, desc, nameSubmenu, nameFont, nameFontTooltip, nameFontSize, nameFontSizeTooltip, nameFontStyle, nameFontStyleTooltip, nameReset, nameResetTooltip, columnSubmenu, columnFont, columnFontTooltip, columnFontSize, columnFontSizeTooltip, columnFontStyle, columnFontStyleTooltip, columnReset, columnResetTooltip }
param: refreshFn (function|nil) - Optional live refresh callback
return: table - Array of LAM options (header, description, 2 submenus)
]]
function BETTERUI.CIM.Settings.CreateFontSubmenuOptions(moduleName, defaults, fontChoices, fontValues, styleChoices,
                                                        styleValues, strings, refreshFn)
    -- Apply language-based font filtering (non-English users only see compatible fonts)
    local Localization = BETTERUI.CIM.Font.Localization
    local filteredChoices, filteredValues = Localization.GetFilteredFontArrays(fontChoices, fontValues)

    local function getSettings()
        local modules = BETTERUI and BETTERUI.Settings and BETTERUI.Settings.Modules
        if not modules then
            return nil
        end
        return modules[moduleName]
    end

    local function ensureSettings()
        if not BETTERUI or not BETTERUI.Settings then
            return nil
        end
        BETTERUI.Settings.Modules = BETTERUI.Settings.Modules or {}
        if type(BETTERUI.Settings.Modules[moduleName]) ~= "table" then
            BETTERUI.Settings.Modules[moduleName] = {}
        end
        return BETTERUI.Settings.Modules[moduleName]
    end

    local function isCIMDisabled()
        return not (
            BETTERUI
            and BETTERUI.Settings
            and BETTERUI.Settings.Modules
            and BETTERUI.Settings.Modules["CIM"]
            and BETTERUI.Settings.Modules["CIM"].m_enabled
        )
    end

    local minFontSize = BETTERUI.CIM.Font.SIZE_MIN or 12
    local maxFontSize = BETTERUI.CIM.Font.SIZE_MAX or 48

    local options = {
        -- Font Customization Header
        {
            type = "header",
            name = GetString(strings.header),
            width = "full",
        },
        {
            type = "description",
            text = GetString(strings.desc),
            width = "full",
        },
        -- Name Font Submenu
        {
            type = "submenu",
            name = GetString(strings.nameSubmenu),
            controls = {
                {
                    type = "dropdown",
                    name = GetString(strings.nameFont),
                    tooltip = GetString(strings.nameFontTooltip),
                    choices = filteredChoices,
                    choicesValues = filteredValues,
                    getFunc = function()
                        local s = getSettings()
                        if not s then return defaults.nameFont end
                        return s.nameFont or defaults.nameFont
                    end,
                    setFunc = function(value)
                        local s = ensureSettings()
                        if s then s.nameFont = value end
                        if refreshFn then refreshFn() end
                    end,
                    disabled = isCIMDisabled,
                    width = "full",
                    scrollable = true,
                    default = defaults.nameFont,
                },
                {
                    type = "slider",
                    name = GetString(strings.nameFontSize),
                    tooltip = GetString(strings.nameFontSizeTooltip),
                    min = minFontSize,
                    max = maxFontSize,
                    step = 1,
                    getFunc = function()
                        local s = getSettings()
                        return BETTERUI.CIM.Font.GetSizeValue((s and s.nameFontSize) or defaults.nameFontSize)
                    end,
                    setFunc = function(value)
                        local s = ensureSettings()
                        if s then s.nameFontSize = value end
                        if refreshFn then refreshFn() end
                    end,
                    disabled = isCIMDisabled,
                    width = "full",
                    default = defaults.nameFontSize,
                },
                {
                    type = "dropdown",
                    name = GetString(strings.nameFontStyle),
                    tooltip = GetString(strings.nameFontStyleTooltip),
                    choices = styleChoices,
                    choicesValues = styleValues,
                    getFunc = function()
                        local s = getSettings()
                        if not s then return defaults.nameFontStyle end
                        return s.nameFontStyle or defaults.nameFontStyle
                    end,
                    setFunc = function(value)
                        local s = ensureSettings()
                        if s then s.nameFontStyle = value end
                        if refreshFn then refreshFn() end
                    end,
                    disabled = isCIMDisabled,
                    width = "full",
                    default = defaults.nameFontStyle,
                },
                {
                    type = "button",
                    name = GetString(strings.nameReset),
                    tooltip = GetString(strings.nameResetTooltip),
                    func = function()
                        local s = ensureSettings()
                        if s then
                            s.nameFont = defaults.nameFont
                            s.nameFontSize = defaults.nameFontSize
                            s.nameFontStyle = defaults.nameFontStyle
                        end
                        if refreshFn then refreshFn() end
                    end,
                    disabled = isCIMDisabled,
                    width = "half",
                },
            },
        },
        -- Column Font Submenu
        {
            type = "submenu",
            name = GetString(strings.columnSubmenu),
            controls = {
                {
                    type = "dropdown",
                    name = GetString(strings.columnFont),
                    tooltip = GetString(strings.columnFontTooltip),
                    choices = filteredChoices,
                    choicesValues = filteredValues,
                    getFunc = function()
                        local s = getSettings()
                        if not s then return defaults.columnFont end
                        return s.columnFont or defaults.columnFont
                    end,
                    setFunc = function(value)
                        local s = ensureSettings()
                        if s then s.columnFont = value end
                        if refreshFn then refreshFn() end
                    end,
                    disabled = isCIMDisabled,
                    width = "full",
                    scrollable = true,
                    default = defaults.columnFont,
                },
                {
                    type = "slider",
                    name = GetString(strings.columnFontSize),
                    tooltip = GetString(strings.columnFontSizeTooltip),
                    min = minFontSize,
                    max = maxFontSize,
                    step = 1,
                    getFunc = function()
                        local s = getSettings()
                        return BETTERUI.CIM.Font.GetSizeValue((s and s.columnFontSize) or defaults.columnFontSize)
                    end,
                    setFunc = function(value)
                        local s = ensureSettings()
                        if s then s.columnFontSize = value end
                        if refreshFn then refreshFn() end
                    end,
                    disabled = isCIMDisabled,
                    width = "full",
                    default = defaults.columnFontSize,
                },
                {
                    type = "dropdown",
                    name = GetString(strings.columnFontStyle),
                    tooltip = GetString(strings.columnFontStyleTooltip),
                    choices = styleChoices,
                    choicesValues = styleValues,
                    getFunc = function()
                        local s = getSettings()
                        if not s then return defaults.columnFontStyle end
                        return s.columnFontStyle or defaults.columnFontStyle
                    end,
                    setFunc = function(value)
                        local s = ensureSettings()
                        if s then s.columnFontStyle = value end
                        if refreshFn then refreshFn() end
                    end,
                    disabled = isCIMDisabled,
                    width = "full",
                    default = defaults.columnFontStyle,
                },
                {
                    type = "button",
                    name = GetString(strings.columnReset),
                    tooltip = GetString(strings.columnResetTooltip),
                    func = function()
                        local s = ensureSettings()
                        if s then
                            s.columnFont = defaults.columnFont
                            s.columnFontSize = defaults.columnFontSize
                            s.columnFontStyle = defaults.columnFontStyle
                        end
                        if refreshFn then refreshFn() end
                    end,
                    disabled = isCIMDisabled,
                    width = "half",
                },
            },
        },
    }

    return options
end
