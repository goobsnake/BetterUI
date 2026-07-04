--[[
File: Modules/TradingHouse/Components/ListingsComponent.lua
Purpose: Listings tab component for the Trading House module.

Shows the player's active guild store listings and supports
cancellation via CancelTradingHouseListing.
]]

local TH = BETTERUI.TradingHouse

-- COMPONENT TABLE
TH.ListingsComponent = {}
local Listings = TH.ListingsComponent
Listings.pendingCancelTrace = nil
Listings.sortByTimeAscending = true
local cancelDialogHooksInstalled = false

local function TraceListings(event, phase, thInstance, data, category)
    if type(TH.Trace) == "function" then
        data = data or {}
        data.feature = data.feature or "trading-house-listings"
        data.fn = data.fn or "TradingHouse.ListingsComponent"
        TH.Trace(category or (BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST), event, phase, thInstance or TH.instance, data)
    end
end

local function HeaderText(stringIdName, fallback)
    local stringId = rawget(_G, stringIdName)
    if stringId ~= nil and type(GetString) == "function" then
        local text = GetString(stringId)
        if text and text ~= "" then
            return text
        end
    end
    return fallback
end

local function SafeGetIndexedString(prefix, value)
    if type(GetString) ~= "function" or value == nil then
        return ""
    end
    return GetString(prefix, value) or ""
end

local LISTINGS_COLUMNS = {
    { text = HeaderText("SI_BETTERUI_INV_HEADER_NAME", "NAME"), align = LEFT },
    { text = "TIME", align = LEFT },
    { text = "UNIT", align = RIGHT },
    { text = "", align = RIGHT },
    { text = "TOTAL", align = RIGHT },
}

local function ApplyListingsHeaders(thInstance)
    if TH.InstallTradingHouseSectionRowSetup then
        TH.InstallTradingHouseSectionRowSetup()
    end
    if TH.SetTradingHouseSectionHeaders then
        TH.SetTradingHouseSectionHeaders(thInstance, LISTINGS_COLUMNS)
    end
end

local function ClearListingsSectionState(thInstance)
    if TH.RestoreTradingHouseSectionHeaders then
        TH.RestoreTradingHouseSectionHeaders(thInstance)
    end
    if TH.SetTradingHousePermissionMessage then
        TH.SetTradingHousePermissionMessage(thInstance, false)
    end
end

local function IsListingsPermissionBlocked(thInstance)
    if not TH.IsTradingHouseSellPermittedForCurrentGuild then
        return false
    end
    local canSell, guildId, guildName, guildIndex = TH.IsTradingHouseSellPermittedForCurrentGuild()
    if canSell then
        return false
    end
    TraceListings("trading_house.listings_permission", "blocked", thInstance, {
        fn = "TradingHouse.ListingsComponent.IsListingsPermissionBlocked",
        guildId = guildId,
        guildName = guildName,
        guildIndex = guildIndex,
    }, BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST)
    return true
end

local function FormatColumnCurrency(value)
    if TH.FormatTradingHouseColumnCurrency then
        return TH.FormatTradingHouseColumnCurrency(value)
    end
    if BETTERUI and BETTERUI.FormatAbbreviatedNumber then
        return BETTERUI.FormatAbbreviatedNumber(value)
    end
    return tostring(value or 0)
end

local function FormatTimeRemaining(timeRemaining)
    if TH.FormatTradingHouseListingTimeRemaining then
        return TH.FormatTradingHouseListingTimeRemaining(timeRemaining)
    end
    return tostring(timeRemaining or 0)
end

local function NewTradingHouseOpId()
    local L = BETTERUI and BETTERUI.Log
    if L and type(L.NewFlow) == "function" then
        return L.NewFlow("thOp")
    end
    return "untracked"
end

local function TracePendingCancelDialog(phase, reason)
    local pending = Listings.pendingCancelTrace
    if not pending then return false end
    if reason ~= nil then
        pending.reason = reason
    end
    if phase == "confirm" and pending.thOperation == "cancel_listing" and type(TH.BeginPendingOperation) == "function" then
        pending.opId = TH.BeginPendingOperation("cancel_listing", "trading_house.cancel_listing", {
            fn = "TradingHouse.ListingsComponent.TracePendingCancelDialog",
            feature = "trading-house-listings",
            opId = pending.opId,
            listingIndex = pending.confirmedIndex or pending.listingIndex,
            price = pending.price,
            stackCount = pending.stackCount,
            item = pending.item,
        })
    end
    TraceListings("trading_house.cancel_listing_dialog", phase, TH.instance, pending,
        BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG)
    if phase == "cancel" and pending.thOperation and type(TH.ClearPendingOperation) == "function" then
        TH.ClearPendingOperation(pending.thOperation)
    end
    Listings.pendingCancelTrace = nil
    return true
end

local function EnsureCancelDialogHooks()
    if cancelDialogHooksInstalled then return end
    cancelDialogHooksInstalled = true
    if type(ZO_PostHook) ~= "function" then
        TraceListings("trading_house.cancel_listing_dialog", "hooks_skipped", TH.instance, {
            fn = "TradingHouse.ListingsComponent.EnsureCancelDialogHooks",
            reason = "missingZO_PostHook",
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG)
        return
    end
    if type(CancelTradingHouseListing) == "function" then
        ZO_PostHook(_G, "CancelTradingHouseListing", function(index, ...)
            local pending = Listings.pendingCancelTrace
            if pending then
                pending.confirmedIndex = index
                TracePendingCancelDialog("confirm", nil)
            end
        end)
    end
    if type(ZO_Dialogs_ReleaseDialog) == "function" then
        ZO_PostHook(_G, "ZO_Dialogs_ReleaseDialog", function(dialogName, ...)
            if dialogName == "TRADING_HOUSE_CONFIRM_REMOVE_LISTING" then
                TracePendingCancelDialog("cancel", "dialogReleased")
            end
        end)
    end
    if type(ZO_Dialogs_ReleaseDialogOnButtonPress) == "function" then
        ZO_PostHook(_G, "ZO_Dialogs_ReleaseDialogOnButtonPress", function(dialogName, ...)
            if dialogName == "TRADING_HOUSE_CONFIRM_REMOVE_LISTING" then
                TracePendingCancelDialog("cancel", "buttonPressRelease")
            end
        end)
    end
end

-- Shared narration text helper avoids a per-entry closure allocation.
local function GetEntryNarrationText(entryData)
    local ds = entryData:GetDataSource()
    return ds and ds.name or ""
end

--- Resolve the focused row through the shared CIM helper, mirroring the Vendor
--- buy component: prefer the converged GetListTargetData alias, else the
--- SafeGetTargetData base (both handle GetTargetData/GetSelectedData/.selectedData).
---@param thInstance BETTERUI.TradingHouse.Class|nil
---@return table|nil rowData
local function GetTargetRowData(thInstance)
    local list = thInstance and thInstance.list
    if not list then return nil end
    local getTargetData = BETTERUI.CIM and BETTERUI.CIM.Utils
        and (BETTERUI.CIM.Utils.GetListTargetData or BETTERUI.CIM.Utils.SafeGetTargetData)
    if type(getTargetData) ~= "function" then return nil end
    return getTargetData(list)
end

-- ACTIVATE / DEACTIVATE

---@param thInstance BETTERUI.TradingHouse.Class
function Listings:Activate(thInstance)
    ApplyListingsHeaders(thInstance)
    TraceListings("trading_house.listings", "activate", thInstance, {
        fn = "TradingHouse.ListingsComponent.Activate",
        hasRequestApi = RequestTradingHouseListings ~= nil,
    }, BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE)
    -- Request fresh listing data from server
    if type(RequestTradingHouseListings) == "function" then
        RequestTradingHouseListings()
        TraceListings("trading_house.listings", "requested", thInstance, {
            fn = "TradingHouse.ListingsComponent.Activate",
            reason = "activate",
        })
    end
    thInstance:RefreshList()
end

---@param thInstance BETTERUI.TradingHouse.Class
function Listings:Deactivate(thInstance)
    TracePendingCancelDialog("cancel", "componentDeactivated")
    ClearListingsSectionState(thInstance)
end

-- PRIMARY ACTION

---@return string name Localized action label
function Listings:GetPrimaryActionName()
    return HeaderText("SI_BETTERUI_TH_CANCEL_LISTING", HeaderText("SI_TRADING_HOUSE_CANCEL_LISTING", "Cancel Listing"))
end

---@param thInstance BETTERUI.TradingHouse.Class
---@return boolean enabled True if cancellation is possible
function Listings:IsPrimaryActionEnabled(thInstance)
    if IsListingsPermissionBlocked(thInstance) then
        return false
    end
    local selectedData = GetTargetRowData(thInstance)
    if not selectedData then return false end
    local ds = selectedData.dataSource or selectedData

    return ds.listingIndex ~= nil
end

---@param thInstance BETTERUI.TradingHouse.Class|nil
---@return boolean ascending True when the next list rebuild sorts soonest first
function Listings:ToggleSortByTime(thInstance)
    self.sortByTimeAscending = not (self.sortByTimeAscending == true)
    TraceListings("trading_house.listings_sort", "applied", thInstance, {
        fn = "TradingHouse.ListingsComponent.ToggleSortByTime",
        ascending = self.sortByTimeAscending == true,
    }, BETTERUI.Log and BETTERUI.Log.CATEGORY.ACTION)
    if thInstance and thInstance.RefreshList then
        thInstance:RefreshList()
    end
    return self.sortByTimeAscending == true
end

---@param thInstance BETTERUI.TradingHouse.Class
function Listings:OnPrimaryAction(thInstance)
    local selectedData = GetTargetRowData(thInstance)
    if not selectedData then
        TraceListings("trading_house.cancel_listing", "blocked", thInstance, {
            fn = "TradingHouse.ListingsComponent.OnPrimaryAction",
            reason = "noSelection",
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.ACTION)
        return
    end
    local ds = selectedData.dataSource or selectedData

    local listingIndex = ds.listingIndex
    if not listingIndex then
        TraceListings("trading_house.cancel_listing", "blocked", thInstance, {
            fn = "TradingHouse.ListingsComponent.OnPrimaryAction",
            reason = "missingListingIndex",
            item = BETTERUI.Log and BETTERUI.Log.DescribeItem and BETTERUI.Log.DescribeItem(ds, "selected") or ds.name,
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.ACTION)
        return
    end

    if IsListingsPermissionBlocked(thInstance) then
        TraceListings("trading_house.cancel_listing", "blocked", thInstance, {
            fn = "TradingHouse.ListingsComponent.OnPrimaryAction",
            reason = "guildCannotSell",
            listingIndex = listingIndex,
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.ACTION)
        return
    end

    local price = ds.listingPrice or ds.purchasePrice or ds.stackSellPrice or 0
    local item = BETTERUI.Log and BETTERUI.Log.DescribeItem and BETTERUI.Log.DescribeItem(ds, "selected") or ds.name
    local opId = NewTradingHouseOpId()

    TraceListings("trading_house.cancel_listing", "begin", thInstance, {
        fn = "TradingHouse.ListingsComponent.OnPrimaryAction",
        listingIndex = listingIndex,
        price = price,
        opId = opId,
        item = item,
    }, BETTERUI.Log and BETTERUI.Log.CATEGORY.ACTION)

    -- ZOS gamepad cancel flow (tradinghouse_listings_gamepad.lua): the gamepad
    -- TRADING_HOUSE_CONFIRM_REMOVE_LISTING dialog expects listingIndex/stackCount/price.
    local dialogItemData = {
        slotIndex = listingIndex,
        stackCount = ds.stackCount or 1,
        name = ds.name,
        displayQuality = ds.quality,
        currencyType = CURT_MONEY,
    }
    EnsureCancelDialogHooks()
    Listings.pendingCancelTrace = {
        fn = "TradingHouse.ListingsComponent.OnPrimaryAction",
        dialog = "TRADING_HOUSE_CONFIRM_REMOVE_LISTING",
        thOperation = "cancel_listing",
        opId = opId,
        listingIndex = listingIndex,
        price = price,
        stackCount = ds.stackCount or 1,
        item = item,
    }
    if type(ZO_GamepadTradingHouse_Dialogs_DisplayConfirmationDialog) == "function" then
        ZO_GamepadTradingHouse_Dialogs_DisplayConfirmationDialog(dialogItemData,
            "TRADING_HOUSE_CONFIRM_REMOVE_LISTING", price, ds.icon)
        TraceListings("trading_house.cancel_listing_dialog", "shown", thInstance, {
            fn = "TradingHouse.ListingsComponent.OnPrimaryAction",
            dialog = "TRADING_HOUSE_CONFIRM_REMOVE_LISTING",
            path = "nativeGamepadConfirmation",
            listingIndex = listingIndex,
            price = price,
            opId = opId,
            item = item,
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG)
    elseif type(ZO_Dialogs_ShowGamepadDialog) == "function" then
        ZO_Dialogs_ShowGamepadDialog("TRADING_HOUSE_CONFIRM_REMOVE_LISTING", {
            listingIndex = listingIndex,
            stackCount = dialogItemData.stackCount,
            price = price,
            thOperation = "cancel_listing",
            opId = opId,
        })
        TraceListings("trading_house.cancel_listing_dialog", "shown", thInstance, {
            fn = "TradingHouse.ListingsComponent.OnPrimaryAction",
            dialog = "TRADING_HOUSE_CONFIRM_REMOVE_LISTING",
            path = "fallbackDialog",
            listingIndex = listingIndex,
            price = price,
            opId = opId,
            item = item,
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG)
    else
        Listings.pendingCancelTrace = nil
        TraceListings("trading_house.cancel_listing_dialog", "blocked", thInstance, {
            fn = "TradingHouse.ListingsComponent.OnPrimaryAction",
            reason = "missingDialogApi",
            listingIndex = listingIndex,
            price = price,
            opId = opId,
            item = item,
        }, BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG)
        return
    end
    TraceListings("trading_house.cancel_listing_dialog", "awaiting_choice", thInstance, Listings.pendingCancelTrace,
        BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG)
end

-- LIST BUILDING

---@param thInstance BETTERUI.TradingHouse.Class
function Listings:BuildList(thInstance)
    local list = thInstance.list
    if not list then return end

    ApplyListingsHeaders(thInstance)
    if IsListingsPermissionBlocked(thInstance) then
        if TH.SetTradingHousePermissionMessage then
            TH.SetTradingHousePermissionMessage(thInstance, true, TH.GetTradingHouseNoPermissionText and TH.GetTradingHouseNoPermissionText())
        end
        TraceListings("th.list", "end", thInstance, {
            fn = "TradingHouse.ListingsComponent.BuildList",
            mode = thInstance.GetCurrentMode and thInstance:GetCurrentMode() or nil,
            count = 0,
            reason = "guildCannotSell",
        })
        return
    elseif TH.SetTradingHousePermissionMessage then
        TH.SetTradingHousePermissionMessage(thInstance, false)
    end

    if type(GetNumTradingHouseListings) ~= "function" or type(GetTradingHouseListingItemInfo) ~= "function" then
        TraceListings("trading_house.listings_list", "skipped", thInstance, {
            fn = "TradingHouse.ListingsComponent.BuildList",
            reason = "missingListingsApi",
        })
        return
    end

    local numListings = GetNumTradingHouseListings() or 0
    TraceListings("trading_house.listings_list", "build", thInstance, {
        fn = "TradingHouse.ListingsComponent.BuildList",
        listingCount = numListings,
        sortByTimeAscending = self.sortByTimeAscending ~= false,
    })
    if numListings == 0 then
        TraceListings("th.list", "end", thInstance, {
            fn = "TradingHouse.ListingsComponent.BuildList",
            mode = thInstance.GetCurrentMode and thInstance:GetCurrentMode() or nil,
            count = 0,
            listingCount = numListings,
        })
        return
    end

    local rows = {}
    for i = 1, numListings do
        -- API 50 return order: icon, itemName, displayQuality, stackCount,
        -- sellerName, timeRemaining, salePrice, currencyType, itemUniqueId,
        -- salePricePerUnit.
        local icon, itemName, displayQuality, stackCount, _, timeRemaining, price, _, itemUniqueId, salePricePerUnit
            = GetTradingHouseListingItemInfo(i)

        -- Cancelled/empty listings can report stackCount 0; skip them.
        if itemName and itemName ~= "" and (stackCount or 0) > 0 then
            local itemLink = type(GetTradingHouseListingItemLink) == "function" and GetTradingHouseListingItemLink(i) or nil
            local quality  = displayQuality or ITEM_DISPLAY_QUALITY_NORMAL
            local totalPrice = price or 0
            local displayStack = stackCount or 1

            -- Category
            local bestCategoryName = ""
            if itemLink and type(GetItemLinkItemType) == "function" then
                local itemType = GetItemLinkItemType(itemLink)
                if itemType and itemType ~= ITEMTYPE_NONE then
                    bestCategoryName = SafeGetIndexedString("SI_ITEMTYPE", itemType)
                end
            end

            -- Trait
            local traitName = nil
            if itemLink and type(GetItemLinkTraitInfo) == "function" then
                local traitType = GetItemLinkTraitInfo(itemLink)
                if traitType and traitType ~= ITEM_TRAIT_TYPE_NONE then
                    traitName = string.upper(SafeGetIndexedString("SI_ITEMTRAITTYPE", traitType))
                end
            end

            -- Unit price
            local unitPrice = tonumber(salePricePerUnit) or 0
            if unitPrice <= 0 and totalPrice and displayStack and displayStack > 0 then
                unitPrice = math.floor(totalPrice / displayStack)
            end
            local timeText = FormatTimeRemaining(timeRemaining)

            local itemData = {
                listingIndex   = i,
                name           = type(zo_strformat) == "function" and zo_strformat(SI_TOOLTIP_ITEM_NAME, itemName) or itemName,
                icon           = icon,
                stackCount     = displayStack,
                listingPrice   = totalPrice,
                stackSellPrice = totalPrice,
                suggestedUnitPrice = unitPrice,
                quality        = quality,
                timeRemaining  = timeRemaining,
                timeRemainingText = timeText,
                itemLink       = itemLink,
                itemUniqueId   = itemUniqueId,
                traitName      = FormatColumnCurrency(unitPrice),
                bestGamepadItemCategoryName = timeText,
                statValue      = "",
                thColumnMode   = "listings",
                thColumn1Text  = timeText,
                thColumn1Align = LEFT,
                thUnitText     = FormatColumnCurrency(unitPrice),
                thSpacerText   = "",
                thTotalText    = FormatColumnCurrency(totalPrice),
                originalTraitName = traitName,
                originalBestGamepadItemCategoryName = bestCategoryName,
            }

            rows[#rows + 1] = itemData
        end
    end

    local sortAscending = self.sortByTimeAscending ~= false
    table.sort(rows, function(left, right)
        local leftTime = tonumber(left.timeRemaining) or 0
        local rightTime = tonumber(right.timeRemaining) or 0
        if leftTime == rightTime then
            return tostring(left.name or "") < tostring(right.name or "")
        end
        if sortAscending then
            return leftTime < rightTime
        end
        return leftTime > rightTime
    end)

    local renderedCount = 0
    for _, itemData in ipairs(rows) do
        local entry = ZO_GamepadEntryData:New(itemData.name, itemData.icon)
        entry:SetDataSource(itemData)
        entry.narrationText = GetEntryNarrationText

        if itemData.quality and type(GetItemQualityColor) == "function" and ZO_ColorDef and ZO_ColorDef.New then
            local r, g, b = GetItemQualityColor(itemData.quality):UnpackRGBA()
            entry:SetNameColors(ZO_ColorDef:New(r, g, b, 1), ZO_ColorDef:New(r, g, b, 0.7))
        end

        list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", entry)
        renderedCount = renderedCount + 1
    end
    TraceListings("th.list", "end", thInstance, {
        fn = "TradingHouse.ListingsComponent.BuildList",
        mode = thInstance.GetCurrentMode and thInstance:GetCurrentMode() or nil,
        count = renderedCount,
        listingCount = numListings,
        sortByTimeAscending = sortAscending,
    })
end
