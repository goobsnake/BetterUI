--[[
File: Modules/Inventory/Settings/FontSettings.lua
Purpose: Manages font definitions and the font customization UI.
Last Modified: 2026-02-08
]]

BETTERUI.Inventory = BETTERUI.Inventory or {}
BETTERUI.Inventory.Settings = BETTERUI.Inventory.Settings or {}

-- Font choices/values now use CIM shared definitions (see CIM/Core/FontDefinitions.lua)
BETTERUI.Inventory.FONT_CHOICES = BETTERUI.CIM.Font.CHOICES
BETTERUI.Inventory.FONT_VALUES = BETTERUI.CIM.Font.VALUES
BETTERUI.Inventory.FONTSTYLE_CHOICES = BETTERUI.CIM.Font.STYLE_CHOICES
BETTERUI.Inventory.FONTSTYLE_VALUES = BETTERUI.CIM.Font.STYLE_VALUES
BETTERUI.Inventory.DEFAULTS = BETTERUI.CIM.Font.DEFAULTS

local function GetInventorySettings()
    local modules = BETTERUI and BETTERUI.Settings and BETTERUI.Settings.Modules
    if not modules then
        return nil
    end
    if type(modules["Inventory"]) ~= "table" then
        modules["Inventory"] = {}
    end
    return modules["Inventory"]
end

local function IsCIMEnabled()
    local modules = BETTERUI and BETTERUI.Settings and BETTERUI.Settings.Modules
    local cimSettings = modules and modules["CIM"]
    return cimSettings and cimSettings.m_enabled == true
end

local function RefreshInventoryList()
    local inv = GAMEPAD_INVENTORY
    if not inv or not inv.RefreshItemList then
        return
    end

    if BETTERUI.CIM and BETTERUI.CIM.Utils and BETTERUI.CIM.Utils.IsInventorySceneShowing then
        if not BETTERUI.CIM.Utils.IsInventorySceneShowing() then
            return
        end
    elseif inv.scene and inv.scene.IsShowing and not inv.scene:IsShowing() then
        return
    end

    if inv.itemList == nil or inv.categoryList == nil then
        return
    end

    if inv.categoryList.IsEmpty and inv.categoryList:IsEmpty() then
        return
    end

    local targetCategoryData = inv.categoryList.selectedData or inv.categoryList.targetData
    if not targetCategoryData then
        return
    end

    if inv.itemList.SetNoItemText == nil then
        return
    end

    if inv.RefreshItemList then
        inv:RefreshItemList()
    end
end

--- Returns the ESO font descriptor for the Name column.
function BETTERUI.Inventory.GetNameFontDescriptor()
    return BETTERUI.CIM.Font.GetModuleFontDescriptor("Inventory", "name")
end

--- Returns the ESO font descriptor for other columns (Type, Trait, Stat, Value).
function BETTERUI.Inventory.GetColumnFontDescriptor()
    return BETTERUI.CIM.Font.GetModuleFontDescriptor("Inventory", "column")
end

--- Returns the LAM control list for Font Customization.
function BETTERUI.Inventory.Settings.GetFontOptions()
    -- Apply language-based font filtering (non-English users only see compatible fonts)
    local Localization = BETTERUI.CIM.Font.Localization
    local filteredChoices, filteredValues = Localization.GetFilteredFontArrays(
        BETTERUI.Inventory.FONT_CHOICES,
        BETTERUI.Inventory.FONT_VALUES
    )
    local minFontSize = BETTERUI.CIM.Font.SIZE_MIN or 12
    local maxFontSize = BETTERUI.CIM.Font.SIZE_MAX or 48

    return {
        {
            type = "header",
            name = GetString(SI_BETTERUI_INV_FONT_HEADER),
            width = "full",
        },
        {
            type = "description",
            text = GetString(SI_BETTERUI_INV_FONT_DESC),
            width = "full",
        },
        {
            type = "submenu",
            name = GetString(SI_BETTERUI_INV_NAME_FONT_SUBMENU),
            controls = {
                {
                    type = "dropdown",
                    name = GetString(SI_BETTERUI_INV_NAME_FONT),
                    tooltip = GetString(SI_BETTERUI_INV_NAME_FONT_TOOLTIP),
                    choices = filteredChoices,
                    choicesValues = filteredValues,
                    getFunc = function()
                        local settings = GetInventorySettings()
                        if not settings then
                            return BETTERUI.Inventory.DEFAULTS.nameFont
                        end
                        return settings.nameFont or BETTERUI.Inventory.DEFAULTS.nameFont
                    end,
                    setFunc = function(value)
                        local settings = GetInventorySettings()
                        if settings then
                            settings.nameFont = value
                        end
                        RefreshInventoryList()
                    end,
                    disabled = function() return not IsCIMEnabled() end,
                    width = "full",
                    scrollable = true,
                    default = BETTERUI.Inventory.DEFAULTS.nameFont,
                },
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_INV_NAME_FONT_SIZE),
                    tooltip = GetString(SI_BETTERUI_INV_NAME_FONT_SIZE_TOOLTIP),
                    min = minFontSize,
                    max = maxFontSize,
                    step = 1,
                    getFunc = function()
                        local settings = GetInventorySettings()
                        local val = BETTERUI.Inventory.DEFAULTS.nameFontSize
                        if settings then
                            val = settings.nameFontSize or val
                        end
                        return BETTERUI.CIM.Font.GetSizeValue(val)
                    end,
                    setFunc = function(value)
                        local settings = GetInventorySettings()
                        if settings then
                            settings.nameFontSize = value
                        end
                        RefreshInventoryList()
                    end,
                    disabled = function() return not IsCIMEnabled() end,
                    width = "full",
                    default = BETTERUI.Inventory.DEFAULTS.nameFontSize,
                },
                {
                    type = "dropdown",
                    name = GetString(SI_BETTERUI_INV_NAME_FONT_STYLE),
                    tooltip = GetString(SI_BETTERUI_INV_NAME_FONT_STYLE_TOOLTIP),
                    choices = BETTERUI.Inventory.FONTSTYLE_CHOICES,
                    choicesValues = BETTERUI.Inventory.FONTSTYLE_VALUES,
                    getFunc = function()
                        local settings = GetInventorySettings()
                        if not settings then
                            return BETTERUI.Inventory.DEFAULTS.nameFontStyle
                        end
                        return settings.nameFontStyle or BETTERUI.Inventory.DEFAULTS.nameFontStyle
                    end,
                    setFunc = function(value)
                        local settings = GetInventorySettings()
                        if settings then
                            settings.nameFontStyle = value
                        end
                        RefreshInventoryList()
                    end,
                    disabled = function() return not IsCIMEnabled() end,
                    width = "full",
                    default = BETTERUI.Inventory.DEFAULTS.nameFontStyle,
                },
                {
                    type = "button",
                    name = GetString(SI_BETTERUI_NAME_FONT_RESET),
                    tooltip = GetString(SI_BETTERUI_NAME_FONT_RESET_TOOLTIP),
                    func = function()
                        local d = BETTERUI.Inventory.DEFAULTS
                        local s = GetInventorySettings()
                        if not s then
                            return
                        end
                        s.nameFont = d.nameFont
                        s.nameFontSize = d.nameFontSize
                        s.nameFontStyle = d.nameFontStyle
                        RefreshInventoryList()
                    end,
                    disabled = function() return not IsCIMEnabled() end,
                    width = "half",
                },
            },
        },
        {
            type = "submenu",
            name = GetString(SI_BETTERUI_INV_COLUMN_FONT_SUBMENU),
            controls = {
                {
                    type = "dropdown",
                    name = GetString(SI_BETTERUI_INV_COLUMN_FONT),
                    tooltip = GetString(SI_BETTERUI_INV_COLUMN_FONT_TOOLTIP),
                    choices = filteredChoices,
                    choicesValues = filteredValues,
                    getFunc = function()
                        local settings = GetInventorySettings()
                        if not settings then
                            return BETTERUI.Inventory.DEFAULTS.columnFont
                        end
                        return settings.columnFont or BETTERUI.Inventory.DEFAULTS.columnFont
                    end,
                    setFunc = function(value)
                        local settings = GetInventorySettings()
                        if settings then
                            settings.columnFont = value
                        end
                        RefreshInventoryList()
                    end,
                    disabled = function() return not IsCIMEnabled() end,
                    width = "full",
                    scrollable = true,
                    default = BETTERUI.Inventory.DEFAULTS.columnFont,
                },
                {
                    type = "slider",
                    name = GetString(SI_BETTERUI_INV_COLUMN_FONT_SIZE),
                    tooltip = GetString(SI_BETTERUI_INV_COLUMN_FONT_SIZE_TOOLTIP),
                    min = minFontSize,
                    max = maxFontSize,
                    step = 1,
                    getFunc = function()
                        local settings = GetInventorySettings()
                        local val = BETTERUI.Inventory.DEFAULTS.columnFontSize
                        if settings then
                            val = settings.columnFontSize or val
                        end
                        return BETTERUI.CIM.Font.GetSizeValue(val)
                    end,
                    setFunc = function(value)
                        local settings = GetInventorySettings()
                        if settings then
                            settings.columnFontSize = value
                        end
                        RefreshInventoryList()
                    end,
                    disabled = function() return not IsCIMEnabled() end,
                    width = "full",
                    default = BETTERUI.Inventory.DEFAULTS.columnFontSize,
                },
                {
                    type = "dropdown",
                    name = GetString(SI_BETTERUI_INV_COLUMN_FONT_STYLE),
                    tooltip = GetString(SI_BETTERUI_INV_COLUMN_FONT_STYLE_TOOLTIP),
                    choices = BETTERUI.Inventory.FONTSTYLE_CHOICES,
                    choicesValues = BETTERUI.Inventory.FONTSTYLE_VALUES,
                    getFunc = function()
                        local settings = GetInventorySettings()
                        if not settings then
                            return BETTERUI.Inventory.DEFAULTS.columnFontStyle
                        end
                        return settings.columnFontStyle or BETTERUI.Inventory.DEFAULTS.columnFontStyle
                    end,
                    setFunc = function(value)
                        local settings = GetInventorySettings()
                        if settings then
                            settings.columnFontStyle = value
                        end
                        RefreshInventoryList()
                    end,
                    disabled = function() return not IsCIMEnabled() end,
                    width = "full",
                    default = BETTERUI.Inventory.DEFAULTS.columnFontStyle,
                },
                {
                    type = "button",
                    name = GetString(SI_BETTERUI_COLUMN_FONT_RESET),
                    tooltip = GetString(SI_BETTERUI_COLUMN_FONT_RESET_TOOLTIP),
                    func = function()
                        local d = BETTERUI.Inventory.DEFAULTS
                        local s = GetInventorySettings()
                        if not s then
                            return
                        end
                        s.columnFont = d.columnFont
                        s.columnFontSize = d.columnFontSize
                        s.columnFontStyle = d.columnFontStyle
                        RefreshInventoryList()
                    end,
                    disabled = function() return not IsCIMEnabled() end,
                    width = "half",
                },
            },
        },
    }
end
