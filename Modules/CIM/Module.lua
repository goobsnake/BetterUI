--[[
File: Modules/CIM/Module.lua
Purpose: Core initialization for the Common Interface Module (CIM).
         CIM provides shared UI components like generic headers, footers,
         and parametric scroll lists used across BetterUI.
Author: BetterUI Team
Last Modified: 2026-01-16
]]

local _
local LAM = LibAddonMenu2

--[[
Function: BETTERUI.CIM.InitModule
Description: Initializes default settings for the Common Interface Module.
Rationale: Ensures all critical configuration values exist before the module is used.
Mechanism: Checks for nil values in the provided options table and assigns defaults.
param: m_options (table) - The raw settings/options table to be initialized.
return: table - The modified options table with default values applied.
References: Called by BetterUI.lua during addon initialization.
TODO: Move magic numbers (10, 50, 24) to a constants file.
]]
function BETTERUI.CIM.InitModule(m_options)
    if m_options["triggerSpeed"] == nil then m_options["triggerSpeed"] = 10 end
    if m_options["enhanceCompat"] == nil then m_options["enhanceCompat"] = false end
    if m_options["rhScrollSpeed"] == nil then m_options["rhScrollSpeed"] = 50 end
    if m_options["tooltipSize"] == nil then m_options["tooltipSize"] = 24 end
    return m_options
end
