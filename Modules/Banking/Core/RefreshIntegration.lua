-- Banking refresh-manager integration.

if not BETTERUI.Banking then BETTERUI.Banking = {} end

function BETTERUI.Banking.InitializeRefreshManager()
    if BETTERUI.CIM.Lists.ListRefreshManager then
        BETTERUI.Banking.RefreshManager = BETTERUI.CIM.Lists.ListRefreshManager:New({
            coalesceDelay = BETTERUI.CIM.CONST.TIMING.CATEGORY_REFRESH_COALESCE_MS,
            useBatching = false,
        })
        if BETTERUI.Log then BETTERUI.Log.Info(BETTERUI.Log.CATEGORY.LIFECYCLE, "[Banking] RefreshManager initialized") end
    else
        if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.LIFECYCLE, "[Banking] Warning: ListRefreshManager not available") end
    end
end
