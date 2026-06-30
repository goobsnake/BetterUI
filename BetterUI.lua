---@class BETTERUI

local LAM = LibAddonMenu2
local ZO_STRLOWER = rawget(_G, "zo_strlower")

local function GetStringByName(globalName)
	local stringId = rawget(_G, globalName)
	if stringId ~= nil then
		return GetString(stringId)
	end
	return globalName
end

if BETTERUI == nil then BETTERUI = {} end

if BETTERUI.RaiseNativeError == nil then
	function BETTERUI.RaiseNativeError(str)
		local message = "[BETTERUI] " .. tostring(str)
		local defer = rawget(_G, "zo_callLater")
		if type(defer) == "function" then
			defer(function() error(message, 0) end, 0)
			return true
		end
		return false
	end
end

-- Bootstrap error channel: BetterUI.lua loads before CIM Utilities, which
-- replaces this with the full ungated implementation. Kept minimal so error
-- reporting works even if CIM never loads.
if BETTERUI.DebugError == nil then
	function BETTERUI.DebugError(str)
		if type(BETTERUI.RaiseNativeError) == "function" then
			BETTERUI.RaiseNativeError(str)
		end
	end
end

local SAVED_VARS_SCHEMA_VERSION = 2.89

---@class ModuleRegistryEntry
---@field name string The unique name of the module (used for settings keys)
---@field namespace string The namespace key in BETTERUI table
---@field required boolean|nil Whether this module is required (always enabled)
---@field dependsOnCIM boolean|nil Whether the module requires the CIM shared platform
---@field condition function|nil Optional condition function that must return true to load
---@field preSetup function|nil Optional function to call before Setup (e.g., for hooks)
---@field depends string|nil Name of another module that must be enabled for this to load

---@type ModuleRegistryEntry[]
local MODULE_REGISTRY = {
	-- Core infrastructure (required by other modules)
	{ name = "CIM", namespace = "CIM", required = true },

	-- CIM-dependent modules (require CIM to be enabled)
	{
		name = "Inventory",
		namespace = "Inventory",
		dependsOnCIM = true,
		preSetup = function()
			if BETTERUI.Inventory and BETTERUI.Inventory.HookDestroyItem then
				BETTERUI.Inventory.HookDestroyItem()
			end
			if BETTERUI.Inventory and BETTERUI.Inventory.HookActionDialog then
				BETTERUI.Inventory.HookActionDialog()
			end
			return true
		end
	},
	{ name = "Banking", namespace = "Banking", dependsOnCIM = true },
	{ name = "Vendor", namespace = "Vendor", dependsOnCIM = true },
	{ name = "TradingHouse", namespace = "TradingHouse", dependsOnCIM = true },
	{ name = "Companions", namespace = "Companions", dependsOnCIM = true },

	-- CIM-dependent interface and feature modules
	{ name = "Writs", namespace = "Writs", dependsOnCIM = true },
	{ name = "GeneralInterface", namespace = "GeneralInterface", dependsOnCIM = true },
	{
		name = "Nameplates",
		namespace = "Nameplates",
		dependsOnCIM = true,
	},
	{ name = "ResourceOrbFrames", namespace = "ResourceOrbFrames", dependsOnCIM = true },
}

local function ModuleDependsOnCIM(moduleName)
	for _, entry in ipairs(MODULE_REGISTRY) do
		if entry.name == moduleName then
			return entry.dependsOnCIM == true
		end
	end

	return false
end

BETTERUI.name = "BetterUI"
BETTERUI.version = "3.07"

BETTERUI.Inventory = BETTERUI.Inventory or {}
BETTERUI.Banking = BETTERUI.Banking or {}
BETTERUI.Vendor = BETTERUI.Vendor or {}
BETTERUI.TradingHouse = BETTERUI.TradingHouse or {}
BETTERUI.Companions = BETTERUI.Companions or {}
BETTERUI.Writs = BETTERUI.Writs or {}
BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.GeneralInterface = BETTERUI.GeneralInterface or {}
BETTERUI.Nameplates = BETTERUI.Nameplates or {}
BETTERUI.ResourceOrbFrames = BETTERUI.ResourceOrbFrames or {}

BETTERUI.GenericHeader = BETTERUI.GenericHeader or {}
BETTERUI.GenericFooter = BETTERUI.GenericFooter or {}
BETTERUI.Interface = BETTERUI.Interface or {}

---@type userdata
BETTERUI.WindowManager = GetWindowManager()
---@type userdata
BETTERUI.EventManager = GetEventManager()

BETTERUI.ResearchTraits = BETTERUI.ResearchTraits or {}

-- Default settings structure
BETTERUI.DefaultSettings = {
	firstInstall = true,
	useAccountWide = false,
	Modules = {}
}


--- Update CIM enabled state from dependent module settings.
function BETTERUI.UpdateCIMState()
	local shouldEnable = false
	for _, entry in ipairs(MODULE_REGISTRY) do
		if entry.dependsOnCIM and BETTERUI.GetModuleEnabled(entry.name) then
			shouldEnable = true
			break
		end
	end
	BETTERUI.SetSetting("CIM", "m_enabled", shouldEnable)
end

---@class ModuleToggleBlueprint
---@field moduleName string
---@field nameStringId string
---@field tooltipStringId string
---@field updatesCIM boolean|nil

---@type ModuleToggleBlueprint[]
local MODULE_TOGGLE_BLUEPRINTS = {
	{ moduleName = "Banking", nameStringId = "SI_BETTERUI_ENABLE_BANKING", tooltipStringId = "SI_BETTERUI_ENABLE_BANKING_TOOLTIP", updatesCIM = true },
	{ moduleName = "Vendor", nameStringId = "SI_BETTERUI_ENABLE_VENDOR", tooltipStringId = "SI_BETTERUI_ENABLE_VENDOR_TOOLTIP", updatesCIM = true },
	{ moduleName = "Companions", nameStringId = "SI_BETTERUI_ENABLE_COMPANIONS", tooltipStringId = "SI_BETTERUI_ENABLE_COMPANIONS_TOOLTIP", updatesCIM = true },
	{ moduleName = "TradingHouse", nameStringId = "SI_BETTERUI_ENABLE_TRADING_HOUSE", tooltipStringId = "SI_BETTERUI_ENABLE_TRADING_HOUSE_TOOLTIP", updatesCIM = true },
	{ moduleName = "GeneralInterface", nameStringId = "SI_BETTERUI_ENABLE_TOOLTIPS", tooltipStringId = "SI_BETTERUI_ENABLE_TOOLTIPS_TOOLTIP", updatesCIM = true },
	{ moduleName = "Nameplates", nameStringId = "SI_BETTERUI_NAMEPLATES_ENABLED", tooltipStringId = "SI_BETTERUI_NAMEPLATES_ENABLED_TOOLTIP", updatesCIM = true },
	{ moduleName = "Inventory", nameStringId = "SI_BETTERUI_ENABLE_INVENTORY", tooltipStringId = "SI_BETTERUI_ENABLE_INVENTORY_TOOLTIP", updatesCIM = true },
	{ moduleName = "ResourceOrbFrames", nameStringId = "SI_BETTERUI_ENABLE_ORBS", tooltipStringId = "SI_BETTERUI_ENABLE_ORBS_TOOLTIP", updatesCIM = true },
	{ moduleName = "Writs", nameStringId = "SI_BETTERUI_ENABLE_WRITS", tooltipStringId = "SI_BETTERUI_ENABLE_WRITS_TOOLTIP", updatesCIM = true },
}

local MODULE_TOGGLE_BLUEPRINT_BY_NAME = {}
for _, blueprint in ipairs(MODULE_TOGGLE_BLUEPRINTS) do
	MODULE_TOGGLE_BLUEPRINT_BY_NAME[blueprint.moduleName] = blueprint
end

local MODULE_TAB_LABEL_STRING_IDS = {
	Banking = "SI_BETTERUI_SETTINGS_TAB_BANKING",
	Vendor = "SI_BETTERUI_SETTINGS_TAB_VENDOR",
	Companions = "SI_BETTERUI_SETTINGS_TAB_COMPANIONS",
	TradingHouse = "SI_BETTERUI_SETTINGS_TAB_TRADING",
	GeneralInterface = "SI_BETTERUI_SETTINGS_TAB_INTERFACE",
	Nameplates = "SI_BETTERUI_SETTINGS_TAB_NAMEPLATES",
	Inventory = "SI_BETTERUI_SETTINGS_TAB_INVENTORY",
	ResourceOrbFrames = "SI_BETTERUI_SETTINGS_TAB_RESOURCE_ORBS",
	Writs = "SI_BETTERUI_SETTINGS_TAB_WRITS",
}

local function GetModuleTabLabel(moduleName)
	local stringIdName = MODULE_TAB_LABEL_STRING_IDS[moduleName]
	if stringIdName then
		return GetStringByName(stringIdName)
	end
	return moduleName or "Module"
end

local SETTINGS_TAB_CONTROL_REFERENCE = "BetterUISettingsTabWindows"
local SETTINGS_TAB_STATE = {
	selectedKey = "General",
}
local RefreshActiveSettingsTabs

local function SetModuleToggleEnabled(moduleName, value, updatesCIM)
	BETTERUI.SetSetting(moduleName, "m_enabled", value)
	if updatesCIM then
		BETTERUI.UpdateCIMState()
	end
	if RefreshActiveSettingsTabs then
		RefreshActiveSettingsTabs()
	end
end

--- Normalizes a module toggle name for sorting by removing color codes, textures,
--- whitespace, and language-specific "Enable" prefixes.
--- @param name string|nil The raw toggle name to normalize
--- @return string normalized The normalized sort key
local function NormalizeModuleToggleSortName(name)
	if type(name) ~= "string" then
		return ""
	end

	local normalized = name
	normalized = normalized:gsub("|c%x%x%x%x%x%x", "")
	normalized = normalized:gsub("|r", "")
	normalized = normalized:gsub("|t[^|]+|t", "")
	normalized = normalized:gsub("^%s+", "")
	normalized = normalized:gsub("%s+$", "")

	-- Sort by the feature wording after "Enable ..." for consistency.
	normalized = normalized:gsub("^Enable%s+", "")
	normalized = normalized:gsub("^Activer%s+", "")
	normalized = normalized:gsub("^Activar%s+", "")
	normalized = normalized:gsub("^Aktivieren%s+", "")
	normalized = normalized:gsub("^Включить%s+", "")
	normalized = normalized:gsub("^启用", "")
	normalized = normalized:gsub("^有効にする%s*", "")

	if ZO_STRLOWER then
		return ZO_STRLOWER(normalized)
	end
	return string.lower(normalized)
end

local function GetModuleToggleBlueprint(moduleName)
	return MODULE_TOGGLE_BLUEPRINT_BY_NAME[moduleName]
end

local function BuildModuleMasterToggleOption(moduleName)
	local blueprint = GetModuleToggleBlueprint(moduleName) or {}
	local updatesCIM = blueprint.updatesCIM
	if updatesCIM == nil then
		updatesCIM = ModuleDependsOnCIM(moduleName)
	end
	local tabName = GetModuleTabLabel(moduleName)
	local toggleName = blueprint.nameStringId and GetStringByName(blueprint.nameStringId) or ("Enable " .. tabName)
	local tooltip = blueprint.tooltipStringId and GetStringByName(blueprint.tooltipStringId) or toggleName

	return {
		type = "checkbox",
		name = toggleName,
		tooltip = tooltip,
		getFunc = function()
			return BETTERUI.GetModuleEnabled(moduleName)
		end,
		setFunc = function(value)
			SetModuleToggleEnabled(moduleName, value, updatesCIM)
		end,
		width = "full",
		requiresReload = true,
	}
end

local function BuildModuleGeneralHeaderOption()
	return {
		type = "header",
		name = GetStringByName("SI_BETTERUI_SETTINGS_TAB_GENERAL"),
		width = "full",
	}
end

local function InsertModuleMasterToggleInGeneralSection(moduleName, controls)
	controls = type(controls) == "table" and controls or {}
	local insertIndex = 1

	if controls[1] and controls[1].type == "header" then
		insertIndex = 2
		if controls[2] and controls[2].type == "description" then
			insertIndex = 3
		end
	else
		table.insert(controls, 1, BuildModuleGeneralHeaderOption())
		insertIndex = 2
	end

	table.insert(controls, insertIndex, BuildModuleMasterToggleOption(moduleName))
	return controls
end

local MODULE_PANEL_ID_ALIASES = {
	Bank = "Banking",
}

local MODULE_SETTINGS_GATE_STRING_IDS = {
	Nameplates = {
		"SI_BETTERUI_NAMEPLATES_ENABLED",
	},
}

local function ResolveCapturedModuleName(panel)
	if type(panel) ~= "table" then
		return nil
	end
	if type(panel.moduleName) == "string" and panel.moduleName ~= "" then
		return panel.moduleName
	end
	local panelId = type(panel.panelId) == "string" and panel.panelId or ""
	local moduleName = panelId:gsub("^BETTERUI_", "")
	return MODULE_PANEL_ID_ALIASES[moduleName] or moduleName
end

local function NormalizeModuleSettingsTabName(panel, moduleName)
	if type(panel) == "table" then
		if type(panel.moduleLabel) == "string" and panel.moduleLabel ~= "" then
			return panel.moduleLabel
		end
		local panelData = panel.panelData
		if type(panelData) == "table" and type(panelData.name) == "string" then
			local name = panelData.name:gsub("^|t[^|]+|t%s*", "")
			local captured = name:match("^" .. BETTERUI.name .. "%s*%((.-)%)$")
			return captured or name
		end
	end
	return moduleName or "Module"
end

local function ResolveControlName(control)
	if type(control) ~= "table" then
		return nil
	end

	local name = control.name
	if type(name) == "function" then
		local ok, value = pcall(name)
		name = ok and value or nil
	end
	if type(name) == "number" then
		return GetString(name)
	end
	if type(name) == "string" then
		return name
	end
	return nil
end

local function ControlNameMatchesStringId(control, stringIdName)
	local stringId = rawget(_G, stringIdName)
	if stringId == nil then
		return false
	end
	return ResolveControlName(control) == GetString(stringId)
end

local function IsRedundantModuleGateControl(moduleName, control)
	if type(control) ~= "table" or control.type ~= "checkbox" then
		return false
	end
	if control.key == "m_enabled" or control.setting == "m_enabled" then
		return true
	end

	local gateStringIds = MODULE_SETTINGS_GATE_STRING_IDS[moduleName]
	if type(gateStringIds) ~= "table" then
		return false
	end
	for _, stringIdName in ipairs(gateStringIds) do
		if ControlNameMatchesStringId(control, stringIdName) then
			return true
		end
	end
	return false
end

local function EvaluateSettingDisabled(disabled)
	if type(disabled) == "function" then
		local ok, value = pcall(disabled)
		return ok and value == true
	end
	return disabled == true
end

local function CombineModuleDisabled(moduleName, existingDisabled)
	return function()
		return not BETTERUI.GetModuleEnabled(moduleName) or EvaluateSettingDisabled(existingDisabled)
	end
end

local function CloneControlForModuleTab(moduleName, control)
	if type(control) ~= "table" then
		return control
	end

	local clone = {}
	for key, value in pairs(control) do
		if key ~= "controls" then
			clone[key] = value
		end
	end

	if type(control.controls) == "table" then
		clone.controls = {}
		for index, child in ipairs(control.controls) do
			clone.controls[index] = CloneControlForModuleTab(moduleName, child)
		end
	end

	if clone.type == "submenu" then
		-- Keep submenus openable while greying their labels when the module is off.
		clone.disabledLabel = CombineModuleDisabled(moduleName, clone.disabledLabel)
	elseif clone.type == "editbox" then
		if clone.isExtraWide == nil then
			clone.isExtraWide = true
		end
		clone.disabled = CombineModuleDisabled(moduleName, clone.disabled)
	elseif clone.type ~= "header" and clone.type ~= "divider" then
		clone.disabled = CombineModuleDisabled(moduleName, clone.disabled)
	end

	return clone
end

local function TraceSettingsPanel(event, phase, data)
	local L = BETTERUI.Log
	if not (L and L.TraceEvent) then return end
	L.TraceEvent(L.CATEGORY.SETTINGS, event, phase, data or {}, L.LEVEL.INFO)
end

local function BuildModuleSettingsTabControls(moduleName, optionsData)
	local controls = {}
	local redundantGateControls = 0
	if type(optionsData) ~= "table" then
		return controls, redundantGateControls
	end

	for _, control in ipairs(optionsData) do
		if IsRedundantModuleGateControl(moduleName, control) then
			redundantGateControls = redundantGateControls + 1
		else
			controls[#controls + 1] = CloneControlForModuleTab(moduleName, control)
		end
	end
	return controls, redundantGateControls
end

local function AppendControls(target, controls)
	if type(target) ~= "table" or type(controls) ~= "table" then
		return
	end
	for _, control in ipairs(controls) do
		target[#target + 1] = control
	end
end

local function ResolveModuleSettingsTabLabel(panel, moduleName)
	local stringIdName = MODULE_TAB_LABEL_STRING_IDS[moduleName]
	if stringIdName then
		return GetStringByName(stringIdName)
	end
	return NormalizeModuleSettingsTabName(panel, moduleName)
end

local function BuildRegisteredModulePanelMap(modulePanels)
	local panelByModuleName = {}
	local skippedCore = 0
	local skippedUnknown = 0
	if type(modulePanels) ~= "table" then
		return panelByModuleName, skippedCore, skippedUnknown
	end

	for _, panel in ipairs(modulePanels) do
		local moduleName = ResolveCapturedModuleName(panel)
		if moduleName == nil or moduleName == "" then
			skippedUnknown = skippedUnknown + 1
		elseif moduleName == "CIM" then
			skippedCore = skippedCore + 1
		else
			panelByModuleName[moduleName] = panel
		end
	end

	return panelByModuleName, skippedCore, skippedUnknown
end

local function BuildModuleSettingsTabPages()
	local settingsApi = BETTERUI.CIM and BETTERUI.CIM.Settings
	local getRegisteredPanels = settingsApi and settingsApi.GetRegisteredModulePanels
	local modulePanels = {}
	if type(getRegisteredPanels) ~= "function" then
		TraceSettingsPanel("settings.module_tabs", "skipped", {
			reason = "missing_registered_panel_api",
		})
	else
		modulePanels = getRegisteredPanels()
	end

	local panelByModuleName, skippedCore, skippedUnknown = BuildRegisteredModulePanelMap(modulePanels)
	local pages = {}
	local pagesWithoutSubSettings = 0
	local redundantGateControls = 0

	for _, blueprint in ipairs(MODULE_TOGGLE_BLUEPRINTS) do
		local moduleName = blueprint.moduleName
		local panel = panelByModuleName[moduleName]
		local moduleControls, gateControlCount = BuildModuleSettingsTabControls(moduleName, panel and panel.optionsData or {})
		redundantGateControls = redundantGateControls + (gateControlCount or 0)

		if #moduleControls == 0 then
			pagesWithoutSubSettings = pagesWithoutSubSettings + 1
		end
		local controls = InsertModuleMasterToggleInGeneralSection(moduleName, moduleControls)

		pages[#pages + 1] = {
			key = moduleName,
			moduleName = moduleName,
			name = ResolveModuleSettingsTabLabel(panel, moduleName),
			controls = controls,
		}
	end

	table.sort(pages, function(left, right)
		local leftKey = NormalizeModuleToggleSortName(left.name)
		local rightKey = NormalizeModuleToggleSortName(right.name)
		if leftKey == rightKey then
			return tostring(left.name) < tostring(right.name)
		end
		return leftKey < rightKey
	end)

	TraceSettingsPanel("settings.module_tabs", "registered", {
		registeredPanels = type(modulePanels) == "table" and #modulePanels or 0,
		tabs = #pages,
		skippedCore = skippedCore,
		skippedUnknown = skippedUnknown,
		pagesWithoutSubSettings = pagesWithoutSubSettings,
		redundantGateControls = redundantGateControls,
	})

	return pages
end

local GetSettingsTabControlWidth
local ReflowSettingsPageLayout
local RefreshSettingsWidgetTree
local SETTINGS_TAB_DEFAULT_WIDTH = 510
local SETTINGS_TAB_MIN_USABLE_WIDTH = 320
local SETTINGS_TAB_CREATE_DELAY_MS = 50
local SETTINGS_SIMULATED_SUBMENU_TYPE = "betterui_submenu"
local SETTINGS_SUBMENU_HEADER_HEIGHT = 38
local SETTINGS_SUBMENU_ARROW_DOWN_TEXTURE = "EsoUI\\Art\\Miscellaneous\\list_sortdown.dds"
local SETTINGS_SUBMENU_ARROW_UP_TEXTURE = "EsoUI\\Art\\Miscellaneous\\list_sortup.dds"
local SETTINGS_EDITBOX_HEIGHT = 30
local SETTINGS_EDITBOX_MULTILINE_HEIGHT = 86

local function ReadMeasuredWidth(control)
	if control and type(control.GetWidth) == "function" then
		local ok, width = pcall(control.GetWidth, control)
		width = ok and tonumber(width) or 0
		if width and width > 0 then
			return width
		end
	end
	return 0
end

local function GetControlHeight(control)
	if control and type(control.GetHeight) == "function" then
		local ok, height = pcall(control.GetHeight, control)
		height = ok and tonumber(height) or 0
		if height and height > 0 then
			return height
		end
	end
	return 26
end

local function ReadControlField(control, fieldName)
	if not control then return nil end
	local ok, value = pcall(function()
		return control[fieldName]
	end)
	return ok and value or nil
end

local function IsLamPanelControl(control)
	local data = ReadControlField(control, "data")
	return type(data) == "table"
		and (data.type == "panel" or data.registerForRefresh ~= nil or data.registerForDefaults ~= nil)
end

local function ResolveLamPanel(control)
	local current = control
	for _ = 1, 8 do
		if not current then break end
		if IsLamPanelControl(current) then
			return current
		end

		local panel = ReadControlField(current, "panel")
		if not panel or panel == current then
			break
		end
		current = panel
	end

	return ReadControlField(control, "panel") or control
end

local function SetControlHidden(control, hidden)
	if control and control.SetHidden then
		pcall(function() control:SetHidden(hidden) end)
	end
end

local function RefreshSettingsPanelScroll(control)
	local panel = ResolveLamPanel(control)
	local scroll = ReadControlField(panel, "scroll")
	for _, candidate in ipairs({ scroll, panel }) do
		if candidate then
			for _, methodName in ipairs({ "UpdateScroll", "UpdateScrollBar", "RefreshLayout" }) do
				local okMethod, method = pcall(function() return candidate[methodName] end)
				if okMethod and type(method) == "function" then
					pcall(method, candidate)
				end
			end
		end
	end
end

local function ResolveSettingsWidgetWidth(parent)
	local width = ReadMeasuredWidth(parent)
	if width < SETTINGS_TAB_MIN_USABLE_WIDTH then
		width = ReadMeasuredWidth(ReadControlField(parent, "panel")) - 60
	end
	if width < SETTINGS_TAB_MIN_USABLE_WIDTH then
		width = SETTINGS_TAB_DEFAULT_WIDTH
	end
	return width
end

local function EnableResizeToFitY(control)
	if not control then return end
	if control.SetResizeToFitDescendents then
		control:SetResizeToFitDescendents(true)
	end
	if control.SetResizeToFitConstrains and rawget(_G, "ANCHOR_CONSTRAINS_Y") then
		control:SetResizeToFitConstrains(ANCHOR_CONSTRAINS_Y)
	end
end

local function SafeSetDrawLayer(control, layer)
	if control and layer and control.SetDrawLayer then
		pcall(function() control:SetDrawLayer(layer) end)
	end
end

local function SafeSetDrawTier(control, tier)
	if control and tier and control.SetDrawTier then
		pcall(function() control:SetDrawTier(tier) end)
	end
end

local function ApplySettingsDropdownGeometry(widget)
	local container = ReadControlField(widget, "container")
	local combobox = ReadControlField(widget, "combobox")
	if not container or not combobox then
		return
	end

	local width = ReadMeasuredWidth(container)
	local height = GetControlHeight(container)
	if width > 0 and height > 0 and combobox.SetDimensions then
		pcall(function() combobox:SetDimensions(width, height) end)
	elseif width > 0 and combobox.SetWidth then
		pcall(function() combobox:SetWidth(width) end)
	end

	local dropdown = ReadControlField(widget, "dropdown")
	if dropdown and width > 0 then
		dropdown.m_containerWidth = width
	end
end

local function ApplySettingsEditboxGeometry(parent, widget, widgetData)
	local container = ReadControlField(widget, "container")
	local editbox = ReadControlField(widget, "editbox")
	if not container or not editbox then
		return
	end

	local width = ResolveSettingsWidgetWidth(parent)
	if widgetData.width == "half" then
		width = ReadMeasuredWidth(widget)
	end
	if width < SETTINGS_TAB_MIN_USABLE_WIDTH and widgetData.width ~= "half" then
		width = SETTINGS_TAB_DEFAULT_WIDTH
	end
	local height = widgetData.isMultiline and SETTINGS_EDITBOX_MULTILINE_HEIGHT or SETTINGS_EDITBOX_HEIGHT

	if widget.SetWidth and width > 0 then
		pcall(function() widget:SetWidth(width) end)
	end
	if container.ClearAnchors then
		pcall(function() container:ClearAnchors() end)
	end
	if container.SetAnchor then
		pcall(function()
			container:SetAnchor(BOTTOMLEFT, widget, BOTTOMLEFT, 0, 0)
			container:SetAnchor(BOTTOMRIGHT, widget, BOTTOMRIGHT, 0, 0)
		end)
	end
	if container.SetHeight then
		pcall(function() container:SetHeight(height) end)
	end

	local bg = ReadControlField(widget, "bg")
	if bg and bg.ClearAnchors then
		pcall(function() bg:ClearAnchors() end)
	end
	if bg and bg.SetAnchor then
		pcall(function()
			bg:SetAnchor(TOPLEFT, container, TOPLEFT, 0, 0)
			bg:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, 0, 0)
		end)
	end
	if editbox.ClearAnchors then
		pcall(function() editbox:ClearAnchors() end)
	end
	if editbox.SetAnchor then
		pcall(function()
			editbox:SetAnchor(TOPLEFT, container, TOPLEFT, 4, 2)
			editbox:SetAnchor(BOTTOMRIGHT, container, BOTTOMRIGHT, -4, -2)
		end)
	end
end


local function ApplySettingsWidgetDrawLayers(widget, inSubmenu)
	local controlsLayer = rawget(_G, "DL_CONTROLS")
	local overlayLayer = rawget(_G, "DL_OVERLAY")
	local layer = inSubmenu and overlayLayer or controlsLayer
	local tier = rawget(_G, "DT_HIGH")

	SafeSetDrawTier(widget, tier)
	SafeSetDrawLayer(widget, layer)
	for _, childName in ipairs({ "container", "combobox", "slider", "slidervalue", "editbox", "bg", "button", "texture", "warning", "color", "thumb", "checkbox", "arrow", "label" }) do
		local child = ReadControlField(widget, childName)
		SafeSetDrawLayer(child, layer)
		local okLabel, label = pcall(function()
			return child and child.GetLabelControl and child:GetLabelControl()
		end)
		if okLabel then
			SafeSetDrawLayer(label, layer)
		end
	end
end

local function ApplySettingsWidgetLayoutFixes(parent, widget, widgetData, inSubmenu)
	if type(widgetData) ~= "table" or not widget then
		return
	end
	ApplySettingsWidgetDrawLayers(widget, inSubmenu)
	if widgetData.type == "dropdown" then
		ApplySettingsDropdownGeometry(widget)
	elseif widgetData.type == "editbox" then
		ApplySettingsEditboxGeometry(parent, widget, widgetData)
	end
end

local function GetWidgetCreationParent(parent)
	return ReadControlField(parent, "scroll") or parent
end

local function CreateSettingsTwinContainer(parent, leftWidget, rightWidget)
	local wm = BETTERUI.WindowManager or (GetWindowManager and GetWindowManager())
	local creationParent = GetWidgetCreationParent(parent)
	if not wm or not creationParent or not leftWidget or not rightWidget then
		return rightWidget
	end

	local container = wm:CreateControl(nil, creationParent, CT_CONTROL)
	container.panel = ResolveLamPanel(parent)
	container.data = { type = "container" }
	EnableResizeToFitY(container)

	if leftWidget.GetAnchor then
		local ok = pcall(function()
			container:SetAnchor(select(2, leftWidget:GetAnchor(0)))
		end)
		if not ok then
			container:SetAnchor(TOPLEFT, leftWidget, TOPLEFT, 0, 0)
		end
	else
		container:SetAnchor(TOPLEFT, leftWidget, TOPLEFT, 0, 0)
	end

	if leftWidget.ClearAnchors then leftWidget:ClearAnchors() end
	leftWidget:SetAnchor(TOPLEFT, container, TOPLEFT, 0, 0)
	rightWidget:SetAnchor(TOPLEFT, leftWidget, TOPRIGHT, 5, 0)

	if leftWidget.SetParent then leftWidget:SetParent(container) end
	if rightWidget.SetParent then rightWidget:SetParent(container) end
	if leftWidget.GetWidth and leftWidget.SetWidth then
		local okWidth, width = pcall(leftWidget.GetWidth, leftWidget)
		width = okWidth and tonumber(width) or nil
		if width and width > 5 then
			leftWidget:SetWidth(width - 2.5)
		end
	end
	if rightWidget.GetWidth and rightWidget.SetWidth then
		local okWidth, width = pcall(rightWidget.GetWidth, rightWidget)
		width = okWidth and tonumber(width) or nil
		if width and width > 5 then
			rightWidget:SetWidth(width - 2.5)
		end
	end
	if container.SetHeight then
		container:SetHeight(math.max(GetControlHeight(leftWidget), GetControlHeight(rightWidget)))
	end

	return container
end

local function AttachSettingsControlTooltip(control)
	if not control or not control.SetHandler then
		return
	end
	control:SetHandler("OnMouseEnter", function(current)
		local data = ReadControlField(current, "data")
		local tooltip = type(data) == "table" and data.tooltip or nil
		if tooltip == nil or tooltip == "" then
			return
		end
		local lam = rawget(_G, "LibAddonMenu2")
		local util = type(lam) == "table" and lam.util or nil
		if util and type(util.ShowTooltip) == "function" then
			pcall(util.ShowTooltip, current, tooltip)
		end
	end)
	control:SetHandler("OnMouseExit", function(current)
		local lam = rawget(_G, "LibAddonMenu2")
		local util = type(lam) == "table" and lam.util or nil
		if util and type(util.HideTooltip) == "function" then
			pcall(util.HideTooltip, current)
		end
	end)
end

local function UpdateSettingsSimulatedSubmenuHeader(header)
	local state = ReadControlField(header, "__betterUiSubmenuState")
	if type(state) ~= "table" then
		return
	end
	local arrow = ReadControlField(header, "arrow")
	if arrow and arrow.SetTexture then
		pcall(function()
			arrow:SetTexture(state.expanded and SETTINGS_SUBMENU_ARROW_UP_TEXTURE or SETTINGS_SUBMENU_ARROW_DOWN_TEXTURE)
		end)
	end
	local label = ReadControlField(header, "label")
	if label and label.SetColor then
		local data = ReadControlField(header, "data")
		local labelDisabled = type(data) == "table"
			and (EvaluateSettingDisabled(data.disabledLabel) or EvaluateSettingDisabled(data.disabled))
		pcall(function()
			if labelDisabled then
				label:SetColor(0.55, 0.55, 0.55, 1)
			else
				label:SetColor(1, 1, 1, 1)
			end
		end)
	end
end

local function CreateSettingsSimulatedSubmenuHeader(parent, widgetData)
	local wm = BETTERUI.WindowManager or (GetWindowManager and GetWindowManager())
	local creationParent = GetWidgetCreationParent(parent)
	if not wm or not creationParent then
		return nil
	end

	local header = wm:CreateControl(nil, creationParent, CT_CONTROL)
	if not header then
		return nil
	end

	local width = ResolveSettingsWidgetWidth(parent)
	header.panel = ResolveLamPanel(parent)
	header.data = {
		type = SETTINGS_SIMULATED_SUBMENU_TYPE,
		name = widgetData.name,
		tooltip = widgetData.tooltip,
		disabledLabel = widgetData.disabledLabel,
		disabled = widgetData.disabled,
	}
	header.__betterUiSimulatedSubmenuHeader = true
	header.__betterUiSubmenuState = {
		expanded = widgetData.defaultOpen == true,
		name = widgetData.name,
	}
	if header.SetDimensions then
		header:SetDimensions(width, SETTINGS_SUBMENU_HEADER_HEIGHT)
	end
	if header.SetMouseEnabled then
		header:SetMouseEnabled(true)
	end

	local blockBackdrop = wm:CreateControl(nil, creationParent, CT_BACKDROP)
	if blockBackdrop then
		if blockBackdrop.SetCenterColor then
			pcall(function() blockBackdrop:SetCenterColor(0.015, 0.015, 0.015, 0.82) end)
		end
		if blockBackdrop.SetEdgeColor then
			pcall(function() blockBackdrop:SetEdgeColor(0.48, 0.48, 0.48, 0.92) end)
		end
		SafeSetDrawTier(blockBackdrop, rawget(_G, "DT_MEDIUM"))
		SafeSetDrawLayer(blockBackdrop, rawget(_G, "DL_CONTROLS"))
		SetControlHidden(blockBackdrop, true)
	end
	header.blockBackdrop = blockBackdrop

	local backdrop = wm:CreateControl(nil, header, CT_BACKDROP)
	if backdrop then
		if backdrop.SetAnchorFill then
			backdrop:SetAnchorFill(header)
		else
			backdrop:SetAnchor(TOPLEFT, header, TOPLEFT, 0, 0)
			backdrop:SetAnchor(BOTTOMRIGHT, header, BOTTOMRIGHT, 0, 0)
		end
		if backdrop.SetCenterColor then
			pcall(function() backdrop:SetCenterColor(0.02, 0.02, 0.02, 0.90) end)
		end
		if backdrop.SetEdgeColor then
			pcall(function() backdrop:SetEdgeColor(0.64, 0.64, 0.64, 0.95) end)
		end
	end
	header.backdrop = backdrop

	local arrow = wm:CreateControl(nil, header, CT_TEXTURE)
	if arrow then
		if arrow.SetDimensions then arrow:SetDimensions(26, 26) end
		if arrow.SetAnchor then arrow:SetAnchor(RIGHT, header, RIGHT, -10, 0) end
		if arrow.SetColor then
			pcall(function() arrow:SetColor(1, 1, 1, 1) end)
		end
	end
	header.arrow = arrow

	local label = wm:CreateControl(nil, header, CT_LABEL)
	if label then
		if label.SetAnchor then
			label:SetAnchor(LEFT, header, LEFT, 12, 0)
			label:SetAnchor(RIGHT, arrow or header, arrow and LEFT or RIGHT, arrow and -8 or -12, 0)
		end
		if label.SetFont then pcall(function() label:SetFont("ZoFontWinH3") end) end
		if label.SetText then pcall(function() label:SetText(tostring(widgetData.name or "")) end) end
		if label.SetVerticalAlignment and rawget(_G, "TEXT_ALIGN_CENTER") then
			label:SetVerticalAlignment(TEXT_ALIGN_CENTER)
		end
	end
	header.label = label

	if header.SetHandler then
		header:SetHandler("OnMouseUp", function(control, button, upInside)
			if upInside == false then return end
			local leftButton = rawget(_G, "MOUSE_BUTTON_INDEX_LEFT")
			if leftButton ~= nil and button ~= nil and button ~= leftButton then
				return
			end
			local state = ReadControlField(control, "__betterUiSubmenuState")
			if type(state) ~= "table" then return end
			state.expanded = not state.expanded
			UpdateSettingsSimulatedSubmenuHeader(control)
			local layoutParent = ReadControlField(control, "__betterUiLayoutParent") or parent
			ReflowSettingsPageLayout(layoutParent)
			if RefreshSettingsWidgetTree then
				RefreshSettingsWidgetTree(layoutParent)
			end
			RefreshSettingsPanelScroll(layoutParent)
		end)
	end

	AttachSettingsControlTooltip(header)
	UpdateSettingsSimulatedSubmenuHeader(header)
	return header
end

local function CopySettingsSubmenuStates(submenuStates, appendedState)
	local copy = {}
	for index, state in ipairs(submenuStates or {}) do
		copy[index] = state
	end
	if appendedState then
		copy[#copy + 1] = appendedState
	end
	return copy
end

local function AreSettingsEntryStatesExpanded(submenuStates)
	for _, state in ipairs(submenuStates or {}) do
		if type(state) == "table" and not state.expanded then
			return false
		end
	end
	return true
end

local function SettingsEntryContainsSubmenuState(entry, targetState)
	if type(entry) ~= "table" or type(targetState) ~= "table" then
		return false
	end
	for _, state in ipairs(entry.submenuStates or {}) do
		if state == targetState then
			return true
		end
	end
	return false
end

local function RefreshSettingsSubmenuBlockBackground(entries, width)
	if type(entries) ~= "table" then
		return
	end

	for index, entry in ipairs(entries) do
		local control = entry.control
		if control and control.__betterUiSimulatedSubmenuHeader then
			local blockBackdrop = ReadControlField(control, "blockBackdrop")
			if blockBackdrop then
				local visible = AreSettingsEntryStatesExpanded(entry.submenuStates)
				if not visible then
					SetControlHidden(blockBackdrop, true)
				else
					local state = ReadControlField(control, "__betterUiSubmenuState")
					local height = SETTINGS_SUBMENU_HEADER_HEIGHT
					if type(state) == "table" and state.expanded then
						for childIndex = index + 1, #entries do
							local childEntry = entries[childIndex]
							if not SettingsEntryContainsSubmenuState(childEntry, state) then
								break
							end
							if AreSettingsEntryStatesExpanded(childEntry.submenuStates) then
								height = height + (childEntry.spacing or 15) + GetControlHeight(childEntry.control)
							end
						end
					end
					if blockBackdrop.ClearAnchors then
						pcall(function() blockBackdrop:ClearAnchors() end)
					end
					if blockBackdrop.SetAnchor then
						pcall(function() blockBackdrop:SetAnchor(TOPLEFT, control, TOPLEFT, -9, 0) end)
					end
					if blockBackdrop.SetDimensions then
						pcall(function() blockBackdrop:SetDimensions(width + 18, height + 4) end)
					end
					SetControlHidden(blockBackdrop, false)
				end
			end
		end
	end
end

local function AddSettingsLayoutEntry(parent, context, control, widgetData, submenuStates, inSubmenu)
	local entry = {
		control = control,
		widgetData = widgetData,
		submenuStates = CopySettingsSubmenuStates(submenuStates),
		inSubmenu = inSubmenu or #(submenuStates or {}) > 0,
		spacing = 15,
	}
	context.entries[#context.entries + 1] = entry
	if control then
		control.__betterUiTabParent = parent
		control.__betterUiLayoutParent = parent
		control.__betterUiInSimulatedSubmenu = entry.inSubmenu
	end
	return entry
end

ReflowSettingsPageLayout = function(parent)
	if not parent then return end
	local entries = ReadControlField(parent, "__betterUiLayoutEntries")
	if type(entries) ~= "table" then
		return
	end

	local anchorTarget = nil
	local width = ResolveSettingsWidgetWidth(parent)
	for _, entry in ipairs(entries) do
		local control = entry.control
		if control then
			local visible = AreSettingsEntryStatesExpanded(entry.submenuStates)
			SetControlHidden(control, not visible)
			if visible then
				if control.__betterUiSimulatedSubmenuHeader then
					if control.SetDimensions then control:SetDimensions(width, SETTINGS_SUBMENU_HEADER_HEIGHT) end
					UpdateSettingsSimulatedSubmenuHeader(control)
				elseif entry.widgetData and entry.widgetData.width ~= "half" and control.SetWidth then
					pcall(function() control:SetWidth(width) end)
				end
				if type(entry.widgetData) == "table" then
					ApplySettingsWidgetLayoutFixes(parent, control, entry.widgetData, entry.inSubmenu)
				end
				if control.ClearAnchors then control:ClearAnchors() end
				if control.SetAnchor then
					if anchorTarget then
						control:SetAnchor(TOPLEFT, anchorTarget, BOTTOMLEFT, 0, entry.spacing or 15)
					else
						control:SetAnchor(TOPLEFT)
					end
				end
				anchorTarget = control
			end
		end
	end

	RefreshSettingsSubmenuBlockBackground(entries, width)
	EnableResizeToFitY(parent)
	RefreshSettingsPanelScroll(parent)
end

local function CreateSettingsPageWidgets(parent, controls, inSubmenu, context, submenuStates)
	if not parent or type(controls) ~= "table" then
		return
	end

	context = context or { entries = {} }
	submenuStates = submenuStates or {}
	parent.__betterUiLayoutEntries = context.entries

	local pendingHalfEntry = nil
	for _, widgetData in ipairs(controls) do
		if type(widgetData) == "table" and widgetData.type then
			if widgetData.type == "submenu" then
				pendingHalfEntry = nil
				local header = CreateSettingsSimulatedSubmenuHeader(parent, widgetData)
				if header then
					AddSettingsLayoutEntry(parent, context, header, header.data, submenuStates, inSubmenu)
					if type(widgetData.controls) == "table" then
						local childStates = CopySettingsSubmenuStates(submenuStates, header.__betterUiSubmenuState)
						CreateSettingsPageWidgets(parent, widgetData.controls, true, context, childStates)
					end
				else
					BETTERUI.DebugError("Settings tab submenu failed: " .. tostring(widgetData.name))
				end
			else
				local isHalf = widgetData.width == "half"
				if widgetData.type == "editbox" and widgetData.isExtraWide == nil then
					widgetData.isExtraWide = true
				end
				local creator = rawget(_G, "LAMCreateControl") and LAMCreateControl[widgetData.type]
				if type(creator) == "function" then
					local ok, widget = pcall(creator, parent, widgetData)
					if ok and widget then
						widget.__betterUiTabParent = parent
						widget.__betterUiInSimulatedSubmenu = inSubmenu or #submenuStates > 0
						ApplySettingsWidgetLayoutFixes(parent, widget, widgetData, widget.__betterUiInSimulatedSubmenu)
						if pendingHalfEntry and isHalf then
							widget.lineControl = pendingHalfEntry.control
							local twinContainer = CreateSettingsTwinContainer(parent, pendingHalfEntry.control, widget)
							pendingHalfEntry.control = twinContainer
							pendingHalfEntry.widgetData = { type = "container" }
							if twinContainer then
								twinContainer.__betterUiTabParent = parent
								twinContainer.__betterUiLayoutParent = parent
								twinContainer.__betterUiInSimulatedSubmenu = pendingHalfEntry.inSubmenu
							end
							pendingHalfEntry = nil
						else
							local entry = AddSettingsLayoutEntry(parent, context, widget, widgetData, submenuStates, inSubmenu)
							pendingHalfEntry = isHalf and entry or nil
						end
					else
						BETTERUI.DebugError("Settings tab control failed: " .. tostring(widgetData.type) .. " " .. tostring(widget))
					end
				else
					BETTERUI.DebugError("Settings tab control unavailable: " .. tostring(widgetData.type))
				end
			end
		end
	end

	if not inSubmenu then
		ReflowSettingsPageLayout(parent)
	end
end

RefreshSettingsWidgetTree = function(control, inSubmenu)
	if not control then return false end
	local refreshed = false
	local data = ReadControlField(control, "data")
	local simulatedSubmenu = ReadControlField(control, "__betterUiInSimulatedSubmenu") or false
	local nestedInSubmenu = inSubmenu or simulatedSubmenu
	if type(data) == "table" then
		ApplySettingsWidgetLayoutFixes(ReadControlField(control, "__betterUiTabParent") or ReadControlField(control, "panel"), control, data, nestedInSubmenu)
	end
	for _, methodName in ipairs({ "UpdateValue", "UpdateDisabled" }) do
		local okMethod, method = pcall(function() return control[methodName] end)
		if okMethod and type(method) == "function" then
			local ok = pcall(method, control)
			refreshed = ok or refreshed
		end
	end

	local okCount, childCount = pcall(function()
		return control.GetNumChildren and control:GetNumChildren() or 0
	end)
	if okCount and type(childCount) == "number" then
		for index = 1, childCount do
			local okChild, child = pcall(function() return control:GetChild(index) end)
			if okChild and child then
				refreshed = RefreshSettingsWidgetTree(child, nestedInSubmenu or (type(data) == "table" and data.type == SETTINGS_SIMULATED_SUBMENU_TYPE)) or refreshed
			end
		end
	end
	return refreshed
end

local function EnsureSettingsTabPageCreated(tabControl, pageIndex)
	local page = tabControl.__betterUiTabPages and tabControl.__betterUiTabPages[pageIndex]
	if not page or page.container then
		return
	end

	local wm = BETTERUI.WindowManager or (GetWindowManager and GetWindowManager())
	if not wm then
		return
	end

	local lamPanel = tabControl.__betterUiLamPanel or ResolveLamPanel(tabControl)
	local pageParent = ReadControlField(lamPanel, "scroll") or lamPanel or tabControl
	local container = wm:CreateControl(nil, pageParent, CT_CONTROL)
	container.panel = lamPanel or tabControl
	container:SetWidth(GetSettingsTabControlWidth(tabControl))
	container:SetAnchor(TOPLEFT, tabControl, BOTTOMLEFT, 0, 10)
	EnableResizeToFitY(container)

	CreateSettingsPageWidgets(container, page.controls)
	page.container = container
end

local function RefreshSettingsTabButtonStates(tabControl)
	local selectedIndex = tabControl.__betterUiSelectedTabIndex or 1
	local normalState = rawget(_G, "BSTATE_NORMAL") or 0
	local selectedState = rawget(_G, "BSTATE_PRESSED") or 1
	for index, buttonControl in ipairs(tabControl.__betterUiTabButtons or {}) do
		local button = ReadControlField(buttonControl, "button") or buttonControl
		if button.SetState then
			button:SetState(index == selectedIndex and selectedState or normalState, index == selectedIndex)
		end
	end
end

local function SelectSettingsTabPage(tabControl, pageIndex)
	local pages = tabControl.__betterUiTabPages
	if type(pages) ~= "table" or not pages[pageIndex] then
		return
	end

	EnsureSettingsTabPageCreated(tabControl, pageIndex)
	for index, page in ipairs(pages) do
		if page.container then
			page.container:SetHidden(index ~= pageIndex)
		end
	end
	if pages[pageIndex].container then
		ReflowSettingsPageLayout(pages[pageIndex].container)
		RefreshSettingsWidgetTree(pages[pageIndex].container)
		RefreshSettingsPanelScroll(pages[pageIndex].container)
	end
	tabControl.__betterUiSelectedTabIndex = pageIndex
	SETTINGS_TAB_STATE.selectedKey = pages[pageIndex].key or "General"
	RefreshSettingsTabButtonStates(tabControl)

	TraceSettingsPanel("settings.tab", "selected", {
		tab = SETTINGS_TAB_STATE.selectedKey,
		index = pageIndex,
	})
end

local function GetInitialSettingsTabIndex(pages)
	local selectedKey = SETTINGS_TAB_STATE.selectedKey
	for index, page in ipairs(pages or {}) do
		if page.key == selectedKey then
			return index
		end
	end
	return 1
end

GetSettingsTabControlWidth = function(tabControl)
	local lamPanel = tabControl and tabControl.__betterUiLamPanel or ResolveLamPanel(tabControl)
	local width = ReadMeasuredWidth(lamPanel)
	local contentWidth = width - 60
	if contentWidth >= SETTINGS_TAB_MIN_USABLE_WIDTH then
		return contentWidth
	end

	local scroll = ReadControlField(lamPanel, "scroll")
	width = ReadMeasuredWidth(scroll)
	if width >= SETTINGS_TAB_MIN_USABLE_WIDTH then
		return width
	end

	return SETTINGS_TAB_DEFAULT_WIDTH
end

local function GetSettingsTabButtonsPerRow(pageCount, width, buttonGap)
	local minButtonWidth = 150
	local maxButtonsPerRow = pageCount > 6 and 3 or math.min(4, pageCount)
	local widthLimitedCount = math.floor((width + buttonGap) / (minButtonWidth + buttonGap))
	widthLimitedCount = math.max(1, widthLimitedCount)
	return math.max(1, math.min(maxButtonsPerRow, widthLimitedCount, pageCount))
end

local function GetSettingsTabButtonPanelHeight(pageCount, width)
	local buttonHeight = 30
	local buttonGap = 4
	local buttonsPerRow = GetSettingsTabButtonsPerRow(pageCount, width or SETTINGS_TAB_DEFAULT_WIDTH, buttonGap)
	local rows = math.ceil(pageCount / buttonsPerRow)
	return math.max(buttonHeight, rows * buttonHeight + math.max(0, rows - 1) * buttonGap)
end

local function ResolveSettingsTabHeightLimit(tabControl, key, fallback)
	local data = tabControl and tabControl.data or nil
	local value = data and data[key] or nil
	if type(value) == "function" then
		local ok, resolved = pcall(value)
		value = ok and resolved or nil
	end
	value = tonumber(value)
	return value or fallback
end

local function ApplySettingsTabDimensions(tabControl, width, height)
	if not tabControl then return end
	width = tonumber(width) or SETTINGS_TAB_DEFAULT_WIDTH
	height = tonumber(height)
	local minHeight = height or ResolveSettingsTabHeightLimit(tabControl, "minHeight", 260)
	local maxHeight = height or ResolveSettingsTabHeightLimit(tabControl, "maxHeight", 4000)
	if tabControl.SetDimensionConstraints then
		tabControl:SetDimensionConstraints(width, minHeight, width, maxHeight)
	end
	if tabControl.SetWidth then
		tabControl:SetWidth(width)
	end
	if height and tabControl.SetHeight then
		tabControl:SetHeight(height)
	end
end

local function LayoutSettingsTabButtons(tabControl, width)
	local pages = tabControl and tabControl.__betterUiTabPages or nil
	local pageCount = type(pages) == "table" and #pages or 0
	if pageCount == 0 then return end
	width = tonumber(width) or GetSettingsTabControlWidth(tabControl)
	local buttonHeight = 30
	local buttonGap = 4
	local buttonsPerRow = GetSettingsTabButtonsPerRow(pageCount, width, buttonGap)
	local buttonWidth = math.floor((width - (buttonGap * (buttonsPerRow - 1))) / buttonsPerRow)
	for index, buttonControl in ipairs(tabControl.__betterUiTabButtons or {}) do
		local row = math.floor((index - 1) / buttonsPerRow)
		local col = (index - 1) % buttonsPerRow
		if buttonControl.ClearAnchors then buttonControl:ClearAnchors() end
		if buttonControl.SetDimensions then buttonControl:SetDimensions(buttonWidth, buttonHeight) end
		if buttonControl.SetAnchor then
			buttonControl:SetAnchor(TOPLEFT, tabControl, TOPLEFT, col * (buttonWidth + buttonGap), row * (buttonHeight + buttonGap))
		end
		local button = ReadControlField(buttonControl, "button")
		if button and button.SetWidth then
			button:SetWidth(buttonWidth)
		end
	end
end

local function CreateSettingsTabsControlNow(tabControl)
	if tabControl.__betterUiTabsCreated then
		return
	end

	local pages = tabControl.data and tabControl.data.pages or {}
	tabControl.__betterUiTabPages = pages
	if #pages == 0 then
		return
	end

	local wm = BETTERUI.WindowManager or (GetWindowManager and GetWindowManager())
	if not wm then
		return
	end

	EnableResizeToFitY(tabControl)

	local lamPanel = ResolveLamPanel(tabControl)
	tabControl.__betterUiLamPanel = lamPanel

	local width = GetSettingsTabControlWidth(tabControl)
	local buttonHeight = 30
	local buttonGap = 4
	local buttonsPerRow = GetSettingsTabButtonsPerRow(#pages, width, buttonGap)
	local rows = math.ceil(#pages / buttonsPerRow)
	local buttonWidth = math.floor((width - (buttonGap * (buttonsPerRow - 1))) / buttonsPerRow)
	local buttonPanelHeight = GetSettingsTabButtonPanelHeight(#pages, width)
	ApplySettingsTabDimensions(tabControl, width, buttonPanelHeight)

	tabControl.__betterUiTabButtons = {}
	for index, page in ipairs(pages) do
		local buttonControl
		local buttonCreator = rawget(_G, "LAMCreateControl") and LAMCreateControl.button
		if type(buttonCreator) == "function" then
			buttonControl = buttonCreator(tabControl, {
				type = "button",
				name = page.name or tostring(page.key or index),
				func = function()
					SelectSettingsTabPage(tabControl, index)
				end,
			})
		else
			buttonControl = wm:CreateControlFromVirtual(nil, tabControl, "ZO_DefaultButton")
			buttonControl:SetText(page.name or tostring(page.key or index))
			buttonControl:SetHandler("OnClicked", function()
				SelectSettingsTabPage(tabControl, index)
			end)
		end
		local row = math.floor((index - 1) / buttonsPerRow)
		local col = (index - 1) % buttonsPerRow
		buttonControl:SetDimensions(buttonWidth, buttonHeight)
		buttonControl:SetAnchor(TOPLEFT, tabControl, TOPLEFT, col * (buttonWidth + buttonGap), row * (buttonHeight + buttonGap))
		local button = ReadControlField(buttonControl, "button")
		if button and button.SetWidth then
			button:SetWidth(buttonWidth)
		end
		tabControl.__betterUiTabButtons[index] = buttonControl
	end

	tabControl.__betterUiTabsCreated = true

	SelectSettingsTabPage(tabControl, GetInitialSettingsTabIndex(pages))
end

local function CreateSettingsTabsControl(tabControl)
	if tabControl.__betterUiTabsCreated or tabControl.__betterUiTabsPending then
		return
	end

	local defer = rawget(_G, "zo_callLater")
	if type(defer) ~= "function" then
		CreateSettingsTabsControlNow(tabControl)
		return
	end

	tabControl.__betterUiTabsPending = true
	defer(function()
		tabControl.__betterUiTabsPending = false
		CreateSettingsTabsControlNow(tabControl)
	end, SETTINGS_TAB_CREATE_DELAY_MS)
end

local function RefreshSettingsTabsControl(tabControl)
	if not tabControl.__betterUiTabsCreated then
		CreateSettingsTabsControl(tabControl)
		return
	end
	local width = GetSettingsTabControlWidth(tabControl)
	local buttonPanelHeight = GetSettingsTabButtonPanelHeight(#(tabControl.__betterUiTabPages or {}), width)
	ApplySettingsTabDimensions(tabControl, width, buttonPanelHeight)
	LayoutSettingsTabButtons(tabControl, width)
	for _, page in ipairs(tabControl.__betterUiTabPages or {}) do
		if page.container and page.container.SetWidth then
			page.container:SetWidth(width)
		end
		if page.container and page.container.SetAnchor then
			if page.container.ClearAnchors then page.container:ClearAnchors() end
			page.container:SetAnchor(TOPLEFT, tabControl, BOTTOMLEFT, 0, 10)
		end
	end
	SelectSettingsTabPage(tabControl, tabControl.__betterUiSelectedTabIndex or GetInitialSettingsTabIndex(tabControl.__betterUiTabPages))
end

RefreshActiveSettingsTabs = function()
	local tabControl = rawget(_G, SETTINGS_TAB_CONTROL_REFERENCE)
	if tabControl and tabControl.__betterUiTabsCreated then
		RefreshSettingsTabsControl(tabControl)
	end
end

local function AttachSettingsTabsToLamPanel(controlPanel, pages)
	local tabControl = rawget(_G, SETTINGS_TAB_CONTROL_REFERENCE)
	if not tabControl then
		return false
	end

	tabControl.__betterUiLamPanel = controlPanel or ResolveLamPanel(tabControl)
	tabControl.__betterUiTabPages = pages or (tabControl.data and tabControl.data.pages) or {}
	CreateSettingsTabsControlNow(tabControl)
	RefreshSettingsTabsControl(tabControl)
	return true
end

local function RegisterSettingsTabsLamCallbacks(controlPanel, pages)
	local callbacks = rawget(_G, "CALLBACK_MANAGER")
	if not controlPanel or not callbacks or type(callbacks.RegisterCallback) ~= "function" then
		return false
	end
	if controlPanel.__betterUiTabCallbacksRegistered then
		return true
	end
	controlPanel.__betterUiTabCallbacksRegistered = true

	callbacks:RegisterCallback("LAM-PanelControlsCreated", function(panel)
		if panel ~= controlPanel then
			return
		end
		AttachSettingsTabsToLamPanel(controlPanel, pages)
	end)
	callbacks:RegisterCallback("LAM-PanelOpened", function(panel)
		if panel ~= controlPanel then
			return
		end
		AttachSettingsTabsToLamPanel(controlPanel, pages)
	end)
	return true
end

local function InitializeRegisteredModuleSettings()
	for _, entry in ipairs(MODULE_REGISTRY) do
		local moduleName, moduleNamespace = entry.name, BETTERUI[entry.namespace]
		if moduleNamespace then
			local moduleSettings = BETTERUI.EnsureModuleSettings(moduleName)
			local moduleInitResult = BETTERUI.ModuleOptions(moduleNamespace, moduleSettings, moduleName)
			if not moduleInitResult then
				BETTERUI.DebugError("[Warning] Skipping broken module: " .. moduleName)
			end
		end
	end
end

local BUILOG_PRESET_CHOICES = { "off", "info", "watch", "debug", "trace", "inspect", "custom" }
local BUILOG_PRESET_VALUES = { "off", "info", "watch", "debug", "trace", "inspect", "custom" }
local BUILOG_PRESET_VALUE_SET = { off = true, info = true, watch = true, debug = true, trace = true, inspect = true, custom = true }
local BUILOG_LEVEL_CHOICES = { "TRACE", "DEBUG", "INFO", "WARN", "ERROR" }
local BUILOG_LEVEL_VALUES = { "trace", "debug", "info", "warn", "error" }
local BUILOG_SCREENSHOT_CHOICES = { "off", "error", "warn" }
local BUILOG_SCREENSHOT_VALUES = { "off", "error", "warn" }

local function GetBetterUISettingsString(idName)
	local id = rawget(_G, idName)
	if id ~= nil then return GetString(id) end
	return idName
end

local function GetBuilogInterfaceLog()
	return BETTERUI.CIM and BETTERUI.CIM.InterfaceLog or nil
end

local function GetBuilogPreset()
	local L = BETTERUI.Log
	local preset = L and L.GetPreset and L.GetPreset() or "custom"
	preset = type(preset) == "string" and preset:lower() or "custom"
	if preset == "verbose" then return "trace" end
	if preset == "ai" then return "watch" end
	return BUILOG_PRESET_VALUE_SET[preset] and preset or "custom"
end

local function AppendBuilogSettingsPanel(optionsTable)
	optionsTable[#optionsTable + 1] = {
		type = "submenu",
		name = GetBetterUISettingsString("SI_BETTERUI_BUILOG_SETTINGS_HEADER"),
		controls = {
			{
				type = "description",
				text = GetBetterUISettingsString("SI_BETTERUI_BUILOG_SETTINGS_DESC"),
				width = "full",
			},
			{
				type = "checkbox",
				name = GetBetterUISettingsString("SI_BETTERUI_BUILOG_ENABLED"),
				tooltip = GetBetterUISettingsString("SI_BETTERUI_BUILOG_ENABLED_TOOLTIP"),
				getFunc = function()
					local interfaceLog = GetBuilogInterfaceLog()
					return interfaceLog and interfaceLog.IsEnabled and interfaceLog.IsEnabled() or false
				end,
				setFunc = function(value)
					local interfaceLog = GetBuilogInterfaceLog()
					if interfaceLog and interfaceLog.SetLoggingEnabled then interfaceLog.SetLoggingEnabled(value) end
				end,
				width = "full",
			},
			{
				type = "dropdown",
				name = GetBetterUISettingsString("SI_BETTERUI_BUILOG_PRESET"),
				tooltip = GetBetterUISettingsString("SI_BETTERUI_BUILOG_PRESET_TOOLTIP"),
				choices = BUILOG_PRESET_CHOICES,
				choicesValues = BUILOG_PRESET_VALUES,
				getFunc = GetBuilogPreset,
				setFunc = function(value)
					if value == "custom" then return end
					local interfaceLog = GetBuilogInterfaceLog()
					if interfaceLog and interfaceLog.ApplyLogPreset then interfaceLog.ApplyLogPreset(value) end
				end,
				width = "full",
			},
			{
				type = "dropdown",
				name = GetBetterUISettingsString("SI_BETTERUI_BUILOG_MIN_LEVEL"),
				tooltip = GetBetterUISettingsString("SI_BETTERUI_BUILOG_MIN_LEVEL_TOOLTIP"),
				choices = BUILOG_LEVEL_CHOICES,
				choicesValues = BUILOG_LEVEL_VALUES,
				getFunc = function()
					local interfaceLog = GetBuilogInterfaceLog()
					return interfaceLog and interfaceLog.GetMinLevelName and interfaceLog.GetMinLevelName() or "info"
				end,
				setFunc = function(value)
					local interfaceLog = GetBuilogInterfaceLog()
					if interfaceLog and interfaceLog.SetMinLevelSetting then interfaceLog.SetMinLevelSetting(value) end
				end,
				width = "full",
			},
			{
				type = "dropdown",
				name = GetBetterUISettingsString("SI_BETTERUI_BUILOG_SCREENSHOT_AUTO"),
				tooltip = GetBetterUISettingsString("SI_BETTERUI_BUILOG_SCREENSHOT_AUTO_TOOLTIP"),
				choices = BUILOG_SCREENSHOT_CHOICES,
				choicesValues = BUILOG_SCREENSHOT_VALUES,
				getFunc = function()
					local interfaceLog = GetBuilogInterfaceLog()
					return interfaceLog and interfaceLog.GetScreenshotAutoMode and interfaceLog.GetScreenshotAutoMode() or "off"
				end,
				setFunc = function(value)
					local interfaceLog = GetBuilogInterfaceLog()
					if interfaceLog and interfaceLog.SetScreenshotAutoMode then interfaceLog.SetScreenshotAutoMode(value) end
				end,
				width = "full",
			},
		},
	}
end

function BETTERUI.InitModuleOptions()
	local panelData = BETTERUI.Init_ModulePanel("Master", GetStringByName("SI_BETTERUI_MASTER_SETTINGS_TITLE"))
	local panelId = "BETTERUI_" .. "Modules"
	local settingsApi = BETTERUI.CIM and BETTERUI.CIM.Settings
	local controlPanel

	local generalControls = {
		{
			type = "header",
			name = GetStringByName("SI_BETTERUI_MASTER_SETTINGS_HEADER"),
			width = "full",
		},
		{
			type = "description",
			text = GetStringByName("SI_BETTERUI_ENABLED_MODULE_SETTINGS_DESC"),
			width = "full",
		},
		{
			type = "checkbox",
			name = GetStringByName("SI_BETTERUI_ENABLE_GLOBAL_SETTINGS"),
			tooltip = GetStringByName("SI_BETTERUI_ENABLE_GLOBAL_TOOLTIP"),
			getFunc = function() return BETTERUI.SavedVars.useAccountWide end,
			setFunc = function(value)
				BETTERUI.SavedVars.useAccountWide = value
			end,
			width = "full",
			requiresReload = true,
		},
	}

	local cimDebug = BETTERUI.CIM and BETTERUI.CIM.Debug
	local showDeveloperSettings = cimDebug
		and cimDebug.ShouldShowDeveloperSettings
		and cimDebug.ShouldShowDeveloperSettings()
		or false

	if showDeveloperSettings then
		local featureFlags = BETTERUI.CIM and BETTERUI.CIM.FeatureFlags
		local allFlags = featureFlags and featureFlags.GetAllFlags and featureFlags.GetAllFlags()
		if allFlags then
			local flagControls = {
				{
					type = "header",
					name = GetStringByName("SI_BETTERUI_FEATURE_FLAGS_HEADER"),
					width = "full",
				},
				{
					type = "description",
					text = GetStringByName("SI_BETTERUI_FEATURE_FLAGS_DESC"),
					width = "full",
				},
			}

			local sortedFlags = {}
			for name in pairs(allFlags) do
				table.insert(sortedFlags, name)
			end
			table.sort(sortedFlags)

			for _, flagName in ipairs(sortedFlags) do
				local flagData = allFlags[flagName]
				local def = (flagData and flagData.definition) or {}
				table.insert(flagControls, {
					type = "checkbox",
					name = def.name or flagName,
					tooltip = (def.description or flagName) .. " | Version " .. (def.version or "?"),
					getFunc = function()
						return BETTERUI.CIM.FeatureFlags.IsEnabled(flagName)
					end,
					setFunc = function(value)
						BETTERUI.CIM.FeatureFlags.SetEnabled(flagName, value)
					end,
					width = "full",
					requiresReload = (flagName == "ENHANCED_TOOLTIPS"),
				})
			end

			for _, control in ipairs(flagControls) do
				table.insert(generalControls, control)
			end
		end
	end

	table.insert(generalControls, {
		type = "divider",
		width = "full",
	})
	AppendBuilogSettingsPanel(generalControls)

	table.insert(generalControls, {
		type = "button",
		name = GetStringByName("SI_BETTERUI_MASTER_RESET_ALL"),
		tooltip = GetStringByName("SI_BETTERUI_MASTER_RESET_ALL_TOOLTIP"),
		func = function()
			local settingsApi = BETTERUI.CIM and BETTERUI.CIM.Settings
			if settingsApi and settingsApi.ResetAllSettingsToDefaults then
				settingsApi.ResetAllSettingsToDefaults()
			end
		end,
		width = "full",
	})

	local pages = {
		{
			key = "General",
			name = GetStringByName("SI_BETTERUI_SETTINGS_TAB_GENERAL"),
			controls = generalControls,
		},
	}
	AppendControls(pages, BuildModuleSettingsTabPages())

	if settingsApi and settingsApi.InstrumentSettingControls then
		for _, page in ipairs(pages) do
			settingsApi.InstrumentSettingControls(page.controls, panelId .. "." .. tostring(page.key or "tab"))
		end
	end

	local optionsTable = {
		{
			type = "custom",
			reference = SETTINGS_TAB_CONTROL_REFERENCE,
			width = "full",
			minHeight = function() return GetSettingsTabButtonPanelHeight(#pages, SETTINGS_TAB_DEFAULT_WIDTH) end,
			maxHeight = function() return GetSettingsTabButtonPanelHeight(#pages, SETTINGS_TAB_DEFAULT_WIDTH) end,
			pages = pages,
			createFunc = function(tabControl)
				tabControl.__betterUiLamPanel = controlPanel or ResolveLamPanel(tabControl)
				if not controlPanel or not rawget(_G, "CALLBACK_MANAGER") then
					CreateSettingsTabsControl(tabControl)
				end
			end,
			refreshFunc = RefreshSettingsTabsControl,
		},
	}

	if settingsApi and settingsApi.InstrumentSettingControls then
		settingsApi.InstrumentSettingControls(optionsTable, panelId)
		TraceSettingsPanel("settings.panel", "instrumented", {
			panel = panelId,
			stage = "master",
			controls = #optionsTable,
			tabs = #pages,
		})
	end
	if BETTERUI.Log and BETTERUI.Log.TraceEvent then
		BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.SETTINGS, "settings.panel", "register_before", {
			panel = panelId,
			stage = "master",
			controls = #optionsTable,
			tabs = #pages,
		}, BETTERUI.Log.LEVEL.INFO)
	end
	controlPanel = LAM:RegisterAddonPanel(panelId, panelData)
	LAM:RegisterOptionControls(panelId, optionsTable)
	RegisterSettingsTabsLamCallbacks(controlPanel, pages)
	if BETTERUI.Log and BETTERUI.Log.TraceEvent then
		BETTERUI.Log.TraceEvent(BETTERUI.Log.CATEGORY.SETTINGS, "settings.panel", "registered", {
			panel = panelId,
			stage = "master",
			controls = #optionsTable,
			tabs = #pages,
		}, BETTERUI.Log.LEVEL.INFO)
	end
end

local function TraceModuleLifecycle(event, phase, data)
	local L = BETTERUI.Log
	if not (L and L.TraceEvent) then return end
	L.TraceEvent(L.CATEGORY.LIFECYCLE, event, phase, data or {}, L.LEVEL.INFO)
end

--- Wrap module initialization and isolate failures.
---@param m_namespace table Module namespace.
---@param m_options table Module settings table.
---@param moduleName string|nil Module name for diagnostics.
---@return table|nil Module namespace table on success, nil on failure.
function BETTERUI.ModuleOptions(m_namespace, m_options, moduleName)
	local moduleContract = type(m_namespace) == "table" and type(m_namespace.ROOT_CONTRACT) == "table" and m_namespace.ROOT_CONTRACT or nil
	local shouldCallInit = moduleContract == nil or moduleContract.init ~= false
	TraceModuleLifecycle("module.init", "begin", {
		module = moduleName or "unknown",
		hasNamespace = type(m_namespace) == "table",
		shouldCallInit = shouldCallInit == true,
	})
	if shouldCallInit then
		if not (m_namespace and m_namespace.InitModule) then
			local name = moduleName or "unknown"
			TraceModuleLifecycle("module.init", "failed", {
				module = name,
				reason = "missing_InitModule",
			})
			BETTERUI.DebugError("[Validation] Module has no InitModule: " .. name)
			if moduleName then
				BETTERUI._sessionDisabledModules = BETTERUI._sessionDisabledModules or {}
				BETTERUI._sessionDisabledModules[moduleName] = true
				BETTERUI.DebugError("[Recovery] Module skipped for this session (will retry on reload): " .. name)
			end
			return nil
		end
		local success, result = pcall(m_namespace.InitModule, m_options)
		if success then
			if type(result) == "table" and moduleName and result ~= m_options then
				BETTERUI.Settings = BETTERUI.Settings or {}
				BETTERUI.Settings.Modules = BETTERUI.Settings.Modules or {}
				BETTERUI.Settings.Modules[moduleName] = result
			end
			TraceModuleLifecycle("module.init", "end", {
				module = moduleName or "unknown",
				resultType = type(result),
				replacedSettings = type(result) == "table" and moduleName ~= nil and result ~= m_options,
			})
		else
			local name = moduleName or "unknown"
			TraceModuleLifecycle("module.init", "failed", {
				module = name,
				reason = tostring(result),
			})
			BETTERUI.DebugError("[Error] InitModule failed for " .. name .. ": " .. tostring(result))
			if moduleName then
				BETTERUI._sessionDisabledModules = BETTERUI._sessionDisabledModules or {}
				BETTERUI._sessionDisabledModules[moduleName] = true
				BETTERUI.DebugError("[Recovery] Module skipped for this session (will retry on reload): " .. name)
			end
			return nil
		end
	end
	if not shouldCallInit then
		TraceModuleLifecycle("module.init", "skipped", {
			module = moduleName or "unknown",
			reason = "contract_init_false",
		})
	end
	return m_namespace
end

local function RecordModuleSetupFailure(failedModules, moduleName, moduleNamespace)
	if moduleNamespace then
		moduleNamespace._setupComplete = nil
	end

	if type(BETTERUI.SetModuleSessionDisabled) == "function" then
		BETTERUI.SetModuleSessionDisabled(moduleName, true)
	else
		BETTERUI._sessionDisabledModules = BETTERUI._sessionDisabledModules or {}
		BETTERUI._sessionDisabledModules[moduleName] = true
	end

	if failedModules then
		failedModules._seen = failedModules._seen or {}
		if not failedModules._seen[moduleName] then
			failedModules._seen[moduleName] = true
			failedModules[#failedModules + 1] = moduleName
		end
	end
end
local function ValidateAndSetupModule(moduleName, moduleNamespace, failedModules)
	TraceModuleLifecycle("module.setup", "begin", {
		module = moduleName,
		hasNamespace = type(moduleNamespace) == "table",
	})
	if not moduleNamespace then
		BETTERUI.Debug(string.format("[Validation] Module '%s' namespace is nil", moduleName))
		RecordModuleSetupFailure(failedModules, moduleName, moduleNamespace)
		TraceModuleLifecycle("module.setup", "failed", {
			module = moduleName,
			reason = "missing_namespace",
		})
		return false
	end

	-- Prevent double Setup (LAM:RegisterAddonPanel will crash with "Duplicate name")
	if moduleNamespace._setupComplete then
		TraceModuleLifecycle("module.setup", "skipped", {
			module = moduleName,
			reason = "already_complete",
		})
		return true
	end

	-- Validate using CIM interface validation if available
	local interfaces = BETTERUI.CIM and BETTERUI.CIM.Interfaces
	local validateFn = interfaces and interfaces.ValidateModule
	local moduleContract = type(moduleNamespace.ROOT_CONTRACT) == "table" and moduleNamespace.ROOT_CONTRACT or nil
	local shouldCallSetup = moduleContract == nil or moduleContract.setup ~= false
	if validateFn then
		local valid, err = validateFn(moduleNamespace, nil, moduleName)
		if not valid then
			BETTERUI.Debug(string.format("[Validation] Module '%s' failed validation: %s", moduleName, tostring(err)))
			RecordModuleSetupFailure(failedModules, moduleName, moduleNamespace)
			TraceModuleLifecycle("module.setup", "failed", {
				module = moduleName,
				reason = "interface_validation_failed",
				detail = tostring(err),
			})
			return false
		end
	else
		-- Fallback: basic Setup check for modules that opt into setup.
		if shouldCallSetup and type(moduleNamespace.Setup) ~= "function" then
			BETTERUI.Debug(string.format("[Validation] Module '%s' has no Setup function", moduleName))
			RecordModuleSetupFailure(failedModules, moduleName, moduleNamespace)
			TraceModuleLifecycle("module.setup", "failed", {
				module = moduleName,
				reason = "missing_Setup",
			})
			return false
		end
	end

	if not shouldCallSetup then
		moduleNamespace._setupComplete = true
		TraceModuleLifecycle("module.setup", "skipped", {
			module = moduleName,
			reason = "contract_setup_false",
		})
		return true
	end

	-- Wrap Setup in pcall so one module failure does not cascade into later modules.
	local success, setupResult, setupDetail = pcall(moduleNamespace.Setup)
	if not success then
		BETTERUI.DebugError(string.format("[Error] Setup() failed for '%s': %s", moduleName, tostring(setupResult)))
		RecordModuleSetupFailure(failedModules, moduleName, moduleNamespace)
		TraceModuleLifecycle("module.setup", "failed", {
			module = moduleName,
			reason = tostring(setupResult),
		})
		return false
	end

	if setupResult == false then
		local detail = setupDetail ~= nil and tostring(setupDetail) or "setup returned false"
		BETTERUI.DebugError(string.format("[Error] Setup() returned false for '%s': %s", moduleName, detail))
		RecordModuleSetupFailure(failedModules, moduleName, moduleNamespace)
		TraceModuleLifecycle("module.setup", "failed", {
			module = moduleName,
			reason = "setup_returned_false",
			detail = detail,
		})
		return false
	end
	moduleNamespace._setupComplete = true
	TraceModuleLifecycle("module.setup", "end", {
		module = moduleName,
		resultType = type(setupResult),
	})
	return true
end

local function ReportModuleSetupFailures(failedModules, contextLabel)
	if not failedModules or #failedModules == 0 then
		return false
	end

	BETTERUI.DebugError(string.format("[Recovery] Modules disabled after setup failure (%s): %s",
		contextLabel,
		table.concat(failedModules, ", ")))
	return true
end

local function DeepCopySettingsTable(source)
	local copy = {}
	for key, value in pairs(source) do
		if type(value) == "table" then
			copy[key] = DeepCopySettingsTable(value)
		else
			copy[key] = value
		end
	end
	return copy
end

-- Schema-version key stamped onto loaded saved-vars tables so the migration
-- gate can detect pre-migration data. Kept distinct from ZO_SavedVars' own
-- internal "version" field so the two version mechanisms never collide.
local SAVED_VARS_SCHEMA_VERSION_KEY = "_schemaVersion"

--- Validate a loaded saved-vars value and normalize it into a usable table so
--- downstream indexing (useAccountWide/firstInstall/Modules) can never fault on
--- nil or malformed (non-table) saved data.
---@param result any The raw value returned by the loader.
---@return table normalized A guaranteed table with a Modules sub-table.
local function NormalizeSavedVars(result)
	-- On nil/malformed data substitute an independent deep copy so SavedVars and
	-- GlobalVars never alias the same DefaultSettings table.
	if type(result) ~= "table" then
		result = DeepCopySettingsTable(BETTERUI.DefaultSettings)
	end
	if type(result.Modules) ~= "table" then
		result.Modules = {}
	end
	return result
end

--- Migration gate: backfill defaults and stamp the current schema version when
--- the saved table is absent a version or predates SAVED_VARS_SCHEMA_VERSION.
--- Structured extension point — future schema changes branch on storedVersion
--- here; the default-merge below keeps newly added default keys present on
--- previously saved tables. Operates on an already-normalized table.
---@param savedVars table The validated saved-vars table to migrate in place.
---@return table savedVars The same table, migrated and version-stamped.
local function MigrateSavedVars(savedVars)
	local storedVersion = savedVars[SAVED_VARS_SCHEMA_VERSION_KEY]
	if type(storedVersion) == "number" and storedVersion >= SAVED_VARS_SCHEMA_VERSION then
		return savedVars
	end

	-- (no-op for now — slot ordered migration steps here, gated on storedVersion)

	-- Default-merge: fill any keys present in DefaultSettings but missing from
	-- the saved table, without overwriting existing user state.
	for key, value in pairs(BETTERUI.DefaultSettings) do
		if savedVars[key] == nil then
			if type(value) == "table" then
				savedVars[key] = DeepCopySettingsTable(value)
			else
				savedVars[key] = value
			end
		end
	end

	savedVars[SAVED_VARS_SCHEMA_VERSION_KEY] = SAVED_VARS_SCHEMA_VERSION
	return savedVars
end

local function LoadSavedVarsWithFallback(loaderName, loader)
	local ok, result = pcall(loader, ZO_SavedVars, "BetterUISavedVars", SAVED_VARS_SCHEMA_VERSION, nil, BETTERUI.DefaultSettings)
	if not ok then
		BETTERUI.DebugError(string.format("[SavedVars] %s failed, using defaults: %s", loaderName, tostring(result)))
		result = nil
	elseif type(result) ~= "table" then
		BETTERUI.DebugError(string.format("[SavedVars] %s returned %s, using defaults", loaderName, type(result)))
		result = nil
	end
	-- Validate/normalize before use, then run the migration gate so the returned
	-- table is always a usable, version-stamped settings store.
	return MigrateSavedVars(NormalizeSavedVars(result))
end

local function ShouldSetupKeyboardModeModule(entry)
	if entry.name == "CIM" then
		return false
	end

	if not BETTERUI.GetModuleEnabled(entry.name) then
		return false
	end

	if not BETTERUI[entry.namespace] then
		return false
	end

	return true
end

local function SetupKeyboardModeModules()
	local failedModules = {}
	local allModulesLoaded = true
	TraceModuleLifecycle("module.keyboard_setup", "begin", {
		moduleCount = #MODULE_REGISTRY,
	})
	for _, entry in ipairs(MODULE_REGISTRY) do
		if ShouldSetupKeyboardModeModule(entry) then
			local setupSucceeded = ValidateAndSetupModule(entry.name, BETTERUI[entry.namespace], failedModules)
			if not setupSucceeded then
				allModulesLoaded = false
			end
		end
	end
	TraceModuleLifecycle("module.keyboard_setup", "end", {
		success = allModulesLoaded == true,
		failedCount = #failedModules,
	})
	return allModulesLoaded, failedModules
end

---@param entry ModuleRegistryEntry The registry entry to evaluate
---@return boolean Whether the module should be loaded
local function ShouldLoadModule(entry)
	local moduleNamespace = BETTERUI[entry.namespace]

	if not moduleNamespace then
		return false
	end

	if entry.required then
		return true
	end

	if not BETTERUI.GetModuleEnabled(entry.name) then
		return false
	end

	if entry.condition and not entry.condition() then
		return false
	end

	if entry.depends and not BETTERUI.GetModuleEnabled(entry.depends) then
		return false
	end

	if entry.dependsOnCIM and not BETTERUI.GetModuleEnabled("CIM") then
		return false
	end

	return true
end

local function LoadConfiguredModules()
	local failedModules = {}
	local allModulesLoaded = true
	TraceModuleLifecycle("module.load", "begin", {
		moduleCount = #MODULE_REGISTRY,
		gamepad = IsInGamepadPreferredMode and IsInGamepadPreferredMode() == true or nil,
	})
	for _, entry in ipairs(MODULE_REGISTRY) do
		if ShouldLoadModule(entry) then
			local moduleLoaded = true
			local moduleNamespace = BETTERUI[entry.namespace]
			if entry.preSetup then
				TraceModuleLifecycle("module.pre_setup", "begin", {
					module = entry.name,
				})
				local preSetupSucceeded, preSetupErr = pcall(entry.preSetup)
				if not preSetupSucceeded then
					TraceModuleLifecycle("module.pre_setup", "failed", {
						module = entry.name,
						reason = tostring(preSetupErr),
					})
					BETTERUI.DebugError(string.format("[Error] preSetup() failed for '%s': %s", entry.name, tostring(preSetupErr)))
					RecordModuleSetupFailure(failedModules, entry.name, moduleNamespace)
					moduleLoaded = false
				else
					TraceModuleLifecycle("module.pre_setup", "end", {
						module = entry.name,
						result = preSetupErr,
					})
				end
			end
			if moduleLoaded then
				moduleLoaded = ValidateAndSetupModule(entry.name, moduleNamespace, failedModules)
			end
			if not moduleLoaded then
				allModulesLoaded = false
			end
		else
			TraceModuleLifecycle("module.load", "skipped", {
				module = entry.name,
				namespace = entry.namespace,
				required = entry.required == true,
				enabled = entry.required == true or BETTERUI.GetModuleEnabled(entry.name) == true,
				dependsOnCIM = entry.dependsOnCIM == true,
				cimEnabled = BETTERUI.GetModuleEnabled("CIM") == true,
				depends = entry.depends,
				dependencyEnabled = entry.depends and BETTERUI.GetModuleEnabled(entry.depends) == true or nil,
			})
		end
	end
	TraceModuleLifecycle("module.load", "end", {
		success = allModulesLoaded == true,
		failedCount = #failedModules,
	})
	return allModulesLoaded, failedModules
end

--- Load enabled modules for active mode.
function BETTERUI.LoadModules()
	if BETTERUI._initialized then return true end

	BETTERUI.Debug("Initializing BETTERUI...")

	local researchCache = BETTERUI.CIM and BETTERUI.CIM.ResearchCache
	if researchCache and type(researchCache.RefreshResearchTraits) == "function" then
		researchCache.RefreshResearchTraits()
	end

	local allModulesLoaded, failedModules = LoadConfiguredModules()
	ReportModuleSetupFailures(failedModules, "load")

	BETTERUI.Debug("Finished! BETTERUI is loaded")
	BETTERUI._initialized = true
	return allModulesLoaded
end

---@param event number The event ID.
---@param addon string The name of the addon being loaded.
function BETTERUI.Initialize(event, addon)
	if addon ~= BETTERUI.name then return end

	BETTERUI.SavedVars = LoadSavedVarsWithFallback("ZO_SavedVars.New", ZO_SavedVars.New)
	BETTERUI.GlobalVars = LoadSavedVarsWithFallback("ZO_SavedVars.NewAccountWide", ZO_SavedVars.NewAccountWide)

	if BETTERUI.SavedVars.useAccountWide then
		BETTERUI.Settings = BETTERUI.GlobalVars
	else
		BETTERUI.Settings = BETTERUI.SavedVars
	end

	local runtimeSetup = BETTERUI.CIM and BETTERUI.CIM.RuntimeSetup
	if runtimeSetup and runtimeSetup.Apply then
		runtimeSetup.Apply(BETTERUI.Settings)
	end

	InitializeRegisteredModuleSettings()

	if BETTERUI.Settings.firstInstall then
		if BETTERUI.Defaults and BETTERUI.Defaults.ApplyFirstInstallDefaults then
			BETTERUI.Defaults.ApplyFirstInstallDefaults(BETTERUI.Settings)
		end
		BETTERUI.Debug("First install detected - applied default module states")
		BETTERUI.Settings.firstInstall = false
	end

	BETTERUI.EventManager:UnregisterForEvent(BETTERUI.name, EVENT_ADD_ON_LOADED)

	BETTERUI.UpdateCIMState()

	local function SetupInitialModuleState()
		if IsInGamepadPreferredMode() then
			return BETTERUI.LoadModules()
		end

		BETTERUI._initialized = false
		local keyboardSetupSucceeded, failedModules = SetupKeyboardModeModules()
		ReportModuleSetupFailures(failedModules, "keyboard")
		return keyboardSetupSucceeded
	end

	local setupSucceeded = SetupInitialModuleState()
	BETTERUI.InitModuleOptions()

	if BETTERUI.Inventory and BETTERUI.Inventory.EnsureCompanionEquipPatched then
		BETTERUI.Inventory.EnsureCompanionEquipPatched()
	end
	return setupSucceeded
end

BETTERUI.EventManager:RegisterForEvent(BETTERUI.name, EVENT_ADD_ON_LOADED, function(...) BETTERUI.Initialize(...) end)
BETTERUI.EventManager:RegisterForEvent(BETTERUI.name .. "_Gamepad", EVENT_GAMEPAD_PREFERRED_MODE_CHANGED,
	function(code, inGamepad)
		if inGamepad then
			BETTERUI.LoadModules()
		end
	end)
