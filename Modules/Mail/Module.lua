--[[
File: Modules/Mail/Module.lua
Purpose: Mail inbox/attachments UX scaffold for BetterUI (MAIL-001).
         Foundation for bulk flows and clearer COD handling.
]]

BETTERUI.Mail = BETTERUI.Mail or {}

function BETTERUI.Mail.Setup()
    -- Placeholder: Will enhance gamepad mail interface
    BETTERUI.Mail.initialized = true
end

function BETTERUI.Mail.IsInitialized()
    return BETTERUI.Mail.initialized == true
end
