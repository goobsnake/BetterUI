--[[
File: Modules/CIM/Module.lua
Purpose: Core initialization for the Common Interface Module (CIM).
         CIM provides the shared UI framework that domain modules build upon.

Internal organization:
  Core/Data/          - Data models, navigation state, multi-select, search
  Core/Diagnostics/   - SafeExecute, feature flags, debug tools, profiler
  Core/Integration/   - Hook factory, market price, research cache, narration
  Core/Lifecycle/     - Deferred tasks, event registry, scene management
  Core/Presentation/  - Font definitions, number formatting, keybind helpers
  Core/Settings/      - Defaults registry, settings factory, accessor, reset
  Core/Window/        - Control utils, window classes, tooltip layout
  Actions/            - Slot actions, protection policy, dialog utils
  Keybinds/           - Generic keybind descriptors
  Dialogs/            - Dialog registry
  Lists/              - Scroll list templates, list managers, batch processor
  UI/                 - Headers, footers, sort controls, currency manager
  Templates/          - XML UI templates (headers, footers, scroll lists)

Domain-specific features (Tooltips, Nameplates) have been extracted to
Modules/GeneralInterface/ — CIM provides only cross-cutting infrastructure.
]]

local ClampInteger = BETTERUI.ClampInteger

---@param m_options table|nil Raw settings table to initialize
---@return table Modified options with defaults applied
function BETTERUI.CIM.InitModule(m_options)
    m_options = m_options or {}
    local defaults = BETTERUI.CIM.CONST.DEFAULTS

    local ok, result = BETTERUI.CIM.TryCall("Defaults.ApplyModuleDefaults", "CIM", m_options)
    if ok then
        m_options = result
    else
        if m_options["enhanceCompat"] == nil then m_options["enhanceCompat"] = false end
        if m_options["rhScrollSpeed"] == nil then m_options["rhScrollSpeed"] = defaults.DEFAULT_RH_SCROLL_SPEED end
        if m_options["tooltipSize"] == nil then m_options["tooltipSize"] = defaults.DEFAULT_TOOLTIP_SIZE end
        if m_options["enableTooltipEnhancements"] == nil then m_options["enableTooltipEnhancements"] = true end
    end

    local minFontSize = BETTERUI.CIM.TryResolve("CIM.Font.SIZE_MIN") or 12
    local maxFontSize = BETTERUI.CIM.TryResolve("CIM.Font.SIZE_MAX") or 48
    m_options["rhScrollSpeed"] = ClampInteger(m_options["rhScrollSpeed"], 1, 1000, defaults.DEFAULT_RH_SCROLL_SPEED)
    m_options["tooltipSize"] = ClampInteger(m_options["tooltipSize"], minFontSize, maxFontSize, defaults.DEFAULT_TOOLTIP_SIZE)

    return m_options
end
