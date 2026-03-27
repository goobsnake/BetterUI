--[[
File: Modules/CIM/Module.lua
Purpose: Core initialization for the Common Interface Module (CIM).
         CIM provides shared UI components like generic headers, footers,
         and parametric scroll lists used across BetterUI.
Author: BetterUI Team
Last Modified: 2026-02-08
]]

--- CIM (Common Interface Module) — Shared Infrastructure Layer
---
--- Architecture Overview:
--- CIM provides the shared foundation for all BetterUI gamepad interface modules.
--- It is organized into focused subsystems:
---
--- Core/       — Window framework, interfaces, settings, runtime setup, utilities
--- Actions/    — Shared action abstractions, slot actions, dialog utilities
--- Keybinds/   — Keybind management, action context tracking
--- Tooltips/   — Tooltip rendering, shared tooltip infrastructure
--- Sorting/    — Shared sorting algorithms and comparators
--- Filters/    — Filter framework and filter implementations
--- Templates/  — Shared XML template setup functions
---
--- Ownership: CIM owns cross-cutting concerns. Feature-specific concerns
--- belong in their respective modules (Banking, Inventory, Vendor).


--- @class BetterUICIMModule
--- @field CONST table
--- @field InitModule fun(m_options: table|nil): table

-- Import shared utility (canonical definition in SettingsAccessor.lua)
--- @type fun(value: any, min: number, max: number, fallback: number): number
local ClampInteger = BETTERUI.ClampInteger

--- Initializes default settings for the Common Interface Module.
---
--- Purpose: Callback for module initialization via BETTERUI.ModuleOptions().
--- Mechanics: Applies default values for CIM-specific settings (tooltip size,
---   scroll speed, etc.) and clamps values to valid ranges.
--- References: Called by BetterUI.lua during addon initialization.
---
--- INIT CONTRACT: Module InitModule functions follow the signature:
---   function InitModule(m_options) -> table
--- This matches the call in BETTERUI.ModuleOptions() which passes only m_options.
--- The module namespace (e.g., BETTERUI.CIM) is NOT passed; modules access
--- their namespace directly via the global BETTERUI table.
---
--- Standard InitModule Signature (implemented by all modules):
---   param m_options table|nil The raw settings table to be initialized
---   return table The modified options table with default values applied
---
--- Wrapper Function (caller):
---   BETTERUI.ModuleOptions(m_namespace, m_options, moduleName)
---
--- @param m_options table|nil The raw settings table to be initialized
--- @return table The modified options table with default values applied
function BETTERUI.CIM.InitModule(m_options)
    m_options = m_options or {}
    local defaults = BETTERUI.CIM.CONST.DEFAULTS

    if BETTERUI.Defaults and BETTERUI.Defaults.ApplyModuleDefaults then
        m_options = BETTERUI.Defaults.ApplyModuleDefaults("CIM", m_options)
    else
        if m_options["enhanceCompat"] == nil then m_options["enhanceCompat"] = false end
        if m_options["rhScrollSpeed"] == nil then m_options["rhScrollSpeed"] = defaults.DEFAULT_RH_SCROLL_SPEED end
        if m_options["tooltipSize"] == nil then m_options["tooltipSize"] = defaults.DEFAULT_TOOLTIP_SIZE end
        if m_options["enableTooltipEnhancements"] == nil then m_options["enableTooltipEnhancements"] = true end
    end

    local minFontSize = (BETTERUI.CIM and BETTERUI.CIM.Font and BETTERUI.CIM.Font.SIZE_MIN) or 12
    local maxFontSize = (BETTERUI.CIM and BETTERUI.CIM.Font and BETTERUI.CIM.Font.SIZE_MAX) or 48
    m_options["rhScrollSpeed"] = ClampInteger(m_options["rhScrollSpeed"], 1, 1000, defaults.DEFAULT_RH_SCROLL_SPEED)
    m_options["tooltipSize"] = ClampInteger(m_options["tooltipSize"], minFontSize, maxFontSize, defaults.DEFAULT_TOOLTIP_SIZE)

    return m_options
end
