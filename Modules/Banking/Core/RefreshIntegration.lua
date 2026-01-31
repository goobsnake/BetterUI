--[[
File: Modules/Banking/Core/RefreshIntegration.lua
Purpose: Integrates ListRefreshManager with Banking module for unified refresh handling.
Author: BetterUI Team
Last Modified: 2026-01-31

Used By: Banking.lua, BankListManager.lua
Dependencies: CIM/Lists/ListRefreshManager.lua
]]

if not BETTERUI.Banking then BETTERUI.Banking = {} end

-- ============================================================================
-- REFRESH MANAGER INITIALIZATION
-- ============================================================================

--[[
Function: BETTERUI.Banking.InitializeRefreshManager
Description: Creates and configures a ListRefreshManager instance for Banking.
Rationale: Centralizes refresh logic, enables coalescing, and position restoration.
Mechanism:
  - Creates instance with Banking-specific coalesce delay
  - Stores in BETTERUI.Banking.RefreshManager for access by other Banking files
]]
function BETTERUI.Banking.InitializeRefreshManager()
    if BETTERUI.CIM.Lists.ListRefreshManager then
        BETTERUI.Banking.RefreshManager = BETTERUI.CIM.Lists.ListRefreshManager:New({
            coalesceDelay = BETTERUI.CIM.CONST.TIMING.CATEGORY_REFRESH_COALESCE_MS,
            useBatching = false, -- Banking lists are typically smaller, no batching needed
        })
        BETTERUI.Debug("[Banking] RefreshManager initialized")
    else
        BETTERUI.Debug("[Banking] Warning: ListRefreshManager not available")
    end
end
