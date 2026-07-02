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
local cancelDialogHooksInstalled = false

local function TraceListings(event, phase, thInstance, data, category)
    if type(TH.Trace) == "function" then
        data = data or {}
        data.feature = data.feature or "trading-house-listings"
        data.fn = data.fn or "TradingHouse.ListingsComponent"
        TH.Trace(category or (BETTERUI.Log and BETTERUI.Log.CATEGORY.LIST), event, phase, thInstance or TH.instance, data)
    end
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
    if phase == "confirm" and pending.thOperation == "cancel_listing" and TH.BeginPendingOperation then
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
    if phase == "cancel" and pending.thOperation and TH.ClearPendingOperation then
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

--- Resolve the focused row the same way the Vendor keybind strip does
--- (GetTargetData when available, falling back to GetSelectedData).
---@param thInstance BETTERUI.TradingHouse.Class|nil
---@return table|nil rowData
local function GetTargetRowData(thInstance)
    local list = thInstance and thInstance.list
    if not list then return nil end
    if list.GetTargetData then
        return list:GetTargetData()
    end
    return list:GetSelectedData()
end

-- ACTIVATE / DEACTIVATE

---@param thInstance BETTERUI.TradingHouse.Class
function Listings:Activate(thInstance)
    TraceListings("trading_house.listings", "activate", thInstance, {
        fn = "TradingHouse.ListingsComponent.Activate",
        hasRequestApi = RequestTradingHouseListings ~= nil,
    }, BETTERUI.Log and BETTERUI.Log.CATEGORY.SCENE)
    -- Request fresh listing data from server
    if RequestTradingHouseListings then
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
end

-- PRIMARY ACTION

---@return string name Localized action label
function Listings:GetPrimaryActionName()
    return GetString(rawget(_G, "SI_BETTERUI_TH_CANCEL_LISTING") or "SI_TRADING_HOUSE_CANCEL_LISTING")
end

---@param thInstance BETTERUI.TradingHouse.Class
---@return boolean enabled True if cancellation is possible
function Listings:IsPrimaryActionEnabled(thInstance)
    local selectedData = GetTargetRowData(thInstance)
    if not selectedData then return false end
    local ds = selectedData.dataSource or selectedData

    return ds.listingIndex ~= nil
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

    local price = ds.purchasePrice or 0
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
    if ZO_GamepadTradingHouse_Dialogs_DisplayConfirmationDialog then
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
    else
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
    end
    TraceListings("trading_house.cancel_listing_dialog", "awaiting_choice", thInstance, Listings.pendingCancelTrace,
        BETTERUI.Log and BETTERUI.Log.CATEGORY.DIALOG)
end

-- LIST BUILDING

---@param thInstance BETTERUI.TradingHouse.Class
function Listings:BuildList(thInstance)
    local list = thInstance.list
    if not list then return end

    local numListings = GetNumTradingHouseListings and GetNumTradingHouseListings() or 0
    TraceListings("trading_house.listings_list", "build", thInstance, {
        fn = "TradingHouse.ListingsComponent.BuildList",
        listingCount = numListings,
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

    local renderedCount = 0
    for i = 1, numListings do
        -- API 50 return order: icon, itemName, displayQuality, stackCount,
        -- sellerName, timeRemaining, salePrice, currencyType, itemUniqueId,
        -- salePricePerUnit.
        local icon, itemName, displayQuality, stackCount, _, timeRemaining, price, _, itemUniqueId
            = GetTradingHouseListingItemInfo(i)

        -- Cancelled/empty listings can report stackCount 0; skip them.
        if itemName and itemName ~= "" and (stackCount or 0) > 0 then
            local itemLink = GetTradingHouseListingItemLink and GetTradingHouseListingItemLink(i) or nil
            local quality  = displayQuality or ITEM_DISPLAY_QUALITY_NORMAL

            -- Category
            local bestCategoryName = ""
            if itemLink and GetItemLinkItemType then
                local itemType = GetItemLinkItemType(itemLink)
                if itemType and itemType ~= ITEMTYPE_NONE then
                    bestCategoryName = GetString("SI_ITEMTYPE", itemType)
                end
            end

            -- Trait
            local traitName = nil
            if itemLink and GetItemLinkTraitInfo then
                local traitType = GetItemLinkTraitInfo(itemLink)
                if traitType and traitType ~= ITEM_TRAIT_TYPE_NONE then
                    traitName = string.upper(GetString("SI_ITEMTRAITTYPE", traitType))
                end
            end

            -- Unit price
            local unitPrice = 0
            if price and stackCount and stackCount > 0 then
                unitPrice = math.floor(price / stackCount)
            end

            local itemData = {
                listingIndex   = i,
                name           = zo_strformat(SI_TOOLTIP_ITEM_NAME, itemName),
                icon           = icon,
                stackCount     = stackCount or 1,
                purchasePrice  = price or 0,
                unitPrice      = unitPrice,
                quality        = quality,
                timeRemaining  = timeRemaining,
                itemLink       = itemLink,
                itemUniqueId   = itemUniqueId,
                traitName      = traitName,
                bestGamepadItemCategoryName = bestCategoryName,
                statValue      = "",
            }

            local entry = ZO_GamepadEntryData:New(itemData.name, itemData.icon)
            entry:SetDataSource(itemData)
            entry.narrationText = GetEntryNarrationText

            if quality then
                local r, g, b = GetItemQualityColor(quality):UnpackRGBA()
                entry:SetNameColors(ZO_ColorDef:New(r, g, b, 1), ZO_ColorDef:New(r, g, b, 0.7))
            end

            list:AddEntry("BETTERUI_GamepadItemSubEntryTemplate", entry)
            renderedCount = renderedCount + 1
        end
    end
    TraceListings("th.list", "end", thInstance, {
        fn = "TradingHouse.ListingsComponent.BuildList",
        mode = thInstance.GetCurrentMode and thInstance:GetCurrentMode() or nil,
        count = renderedCount,
        listingCount = numListings,
    })
end
