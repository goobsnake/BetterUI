--[[
File: Modules/Inventory/Lists/InventoryList.lua
Purpose: Main item row render function (OnSetup) and the BETTERUI.Inventory.List class.
         Entry formatting functions (label, icon, cooldown) live in InventoryEntryFormatting.lua.

KEY RESPONSIBILITIES:
1.  Item Setup (BETTERUI_SharedGamepadEntry_OnSetup):
    *   The main "render" function called for every row in the inventory.
    *   Populates columns: Item Type, Trait, Stat (Damage/Armor/Recipe), and Value.
    *   Handles dynamic icon sizing based on user font settings.

2.  List Class (BETTERUI.Inventory.List):
    *   A subclass of ZO_GamepadInventoryList tailored for BetterUI.
    *   Uses BETTERUI_VerticalParametricScrollList for the actual scrolling mechanic.
    *   Handles list refreshes, data binding, and trigger keybinds.
]]


-- Default template for inventory list entries
local DEFAULT_TEMPLATE = "BETTERUI_GamepadItemSubEntryTemplate"

local DEFAULT_GAMEPAD_ITEM_SORT =
{
    bestGamepadItemCategoryName = { tiebreaker = "name" },
    name = { tiebreaker = "requiredLevel" },
    requiredLevel = { tiebreaker = "requiredChampionPoints", isNumeric = true },
    requiredChampionPoints = { tiebreaker = "iconFile", isNumeric = true },
    iconFile = { tiebreaker = "uniqueId" },
    uniqueId = { isId64 = true },
}

--- Default item sort comparator for gamepad inventory.
--- Purpose: Sorts items based on Best Category Name -> Name -> Level -> Champion Points -> Icon -> ID.
---@param left BetterUIInventoryRowData Left item data
---@param right BetterUIInventoryRowData Right item data
---@return boolean result True if left should come before right
function BETTERUI_Inventory_DefaultItemSortComparator(left, right)
    return ZO_TableOrderingFunction(left, right, "bestGamepadItemCategoryName", DEFAULT_GAMEPAD_ITEM_SORT,
        ZO_SORT_ORDER_UP)
end

-- Import shared helpers from InventoryEntryFormatting.lua (loaded before this file)
local _fmt = BETTERUI.Inventory._EntryFormatting
local GetActiveListModuleName = _fmt.GetActiveListModuleName
local ResolveEntryModuleName = _fmt.ResolveEntryModuleName or GetActiveListModuleName
local ShouldShowMarketPrice = _fmt.ShouldShowMarketPrice
local GetActiveNameFontSize = _fmt.GetActiveNameFontSize

---@param data BetterUIInventoryEntryLike|nil
---@return BetterUIInventoryRowData|BetterUIInventoryEntryData|nil
local function GetEntryDataSource(data)
    return data and (data.dataSource or data) or nil
end

---@param target BetterUIInventoryEntryLike|nil
---@param moduleName BetterUIListModuleName|nil
local function SetEntryListModuleName(target, moduleName)
    if target and moduleName then
        target.listModuleName = moduleName
    end
end

---@param data BetterUIInventoryEntryLike|nil
---@param moduleName BetterUIListModuleName|nil
local function AssignEntryListModuleName(data, moduleName)
    if not data or not moduleName then
        return
    end

    SetEntryListModuleName(data, moduleName)

    local itemData = GetEntryDataSource(data)
    if itemData and itemData ~= data then
        SetEntryListModuleName(itemData, moduleName)
    end
end

---@param itemData BetterUIInventoryRowData
---@param categorizationFunction fun(itemData: BetterUIInventoryRowData): string
local function ApplyInventoryCategoryFields(itemData, categorizationFunction)
    local categoryName = categorizationFunction(itemData)
    local itemTypeName = zo_strformat(SI_INVENTORY_HEADER, BETTERUI.Inventory.GetBestItemCategoryDescription(itemData))

    itemData.bestGamepadItemCategoryName = categoryName
    itemData.bestItemCategoryName = categoryName
    itemData.itemCategoryName = categoryName
    itemData.bestItemTypeName = itemTypeName
end

---@param value any uniqueId (id64 userdata, number, or string)
---@return string|nil normalized
local function NormalizeEntryUniqueId(value)
    if value == nil then
        return nil
    end
    local normalize = BETTERUI.Inventory.Utils and BETTERUI.Inventory.Utils.NormalizeIdentityValue
    if normalize then
        return normalize(value)
    end
    return tostring(value)
end

--- Nil-safe uniqueId equality (mirrors ItemListManager.MenuEntryTemplateEquality):
--- raw == would return true when both ids are nil and can mis-compare distinct
--- id64 userdata instances.
local function MenuEntryTemplateEquality(left, right)
    local leftId = left and NormalizeEntryUniqueId(left.uniqueId)
    local rightId = right and NormalizeEntryUniqueId(right.uniqueId)
    return leftId ~= nil and leftId == rightId
end

local function NormalizeInventoryTypes(inventoryType)
    if type(inventoryType) == "table" then
        return inventoryType
    end
    return { inventoryType }
end

local function TracksInventoryType(list, bagId)
    if bagId == nil then
        return false
    end

    for _, inventoryType in ipairs(list.inventoryTypes or {}) do
        if inventoryType == bagId then
            return true
        end
    end

    return false
end

local function ResolveEntryContext(data)
    local itemData = GetEntryDataSource(data)
    if not itemData then
        return nil
    end

    local bagId = itemData.bagId
    local slotIndex = itemData.slotIndex
    if bagId == nil or slotIndex == nil then
        return nil
    end

    local itemLink = (itemData.cached_itemLink or data.cached_itemLink)
        or GetItemLink(bagId, slotIndex)
    local itemType = (itemData.cached_itemType or data.cached_itemType)
        or (itemLink and GetItemLinkItemType(itemLink))

    return {
        moduleName = ResolveEntryModuleName(data),
        itemData = itemData,
        bagId = bagId,
        slotIndex = slotIndex,
        itemLink = itemLink,
        itemType = itemType,
    }
end

local function ResolveColumnFont(moduleName)
    local sharedItemSupport = BETTERUI.CIM and BETTERUI.CIM.SharedItemSupport
    if sharedItemSupport and sharedItemSupport.ResolveColumnFontDescriptor then
        return sharedItemSupport.ResolveColumnFontDescriptor(moduleName, "Inventory")
    end
    return BETTERUI.Inventory.GetColumnFontDescriptor()
end

local function ResolveEntryColumnControls(control, columnFont)
    local itemTypeControl = control:GetNamedChild("ItemType")
    local traitControl = control:GetNamedChild("Trait")
    local statControl = control:GetNamedChild("Stat")
    local valueControl = control:GetNamedChild("Value")
    if not itemTypeControl or not traitControl or not statControl or not valueControl then
        return nil
    end

    itemTypeControl:SetFont(columnFont)
    traitControl:SetFont(columnFont)
    statControl:SetFont(columnFont)
    valueControl:SetFont(columnFont)

    return {
        itemType = itemTypeControl,
        trait = traitControl,
        stat = statControl,
        value = valueControl,
    }
end

local function ResolveTraitText(itemData, data, bagId, slotIndex)
    local traitName = itemData.cached_traitName or data.cached_traitName
    if traitName then
        return traitName
    end

    local traitType = GetItemTrait(bagId, slotIndex)
    if traitType ~= ITEM_TRAIT_TYPE_NONE then
        traitName = string.upper(GetString("SI_ITEMTRAITTYPE", traitType))
    else
        traitName = "-"
    end

    itemData.cached_traitName = traitName
    if itemData ~= data then
        data.cached_traitName = traitName
    end

    return traitName
end

local function ResolveStatText(data, itemData, itemType, itemLink)
    if itemType == ITEMTYPE_RECIPE then
        local isUnknown = data.cached_isRecipeAndUnknown
        if isUnknown == nil then
            isUnknown = not IsItemLinkRecipeKnown(itemLink)
        end
        return isUnknown and GetString(rawget(_G, "SI_BETTERUI_INV_RECIPE_UNKNOWN"))
            or GetString(rawget(_G, "SI_BETTERUI_INV_RECIPE_KNOWN"))
    end

    if data.cached_isBook or itemType == ITEMTYPE_RACIAL_STYLE_MOTIF then
        local isKnown = data.cached_isBookKnown
        if isKnown == nil then
            isKnown = IsItemLinkBookKnown(itemLink)
        end
        return isKnown and GetString(rawget(_G, "SI_BETTERUI_INV_RECIPE_KNOWN"))
            or GetString(rawget(_G, "SI_BETTERUI_INV_RECIPE_UNKNOWN"))
    end

    local statValue = itemData.statValue
    if statValue == nil or statValue == 0 then
        return "-"
    end
    return statValue
end

local function ApplyValueText(valueControl, data, itemData, itemLink)
    if ShouldShowMarketPrice() and
        (BETTERUI.Utils.IsBankingSceneShowing() or BETTERUI.Utils.IsInventorySceneShowing()) then
        local marketIntegration = BETTERUI.CIM and BETTERUI.CIM.MarketIntegration
        local marketPrice, isAverage = 0, false
        if marketIntegration and type(marketIntegration.GetMarketPrice) == "function" then
            marketPrice, isAverage = marketIntegration.GetMarketPrice(itemLink, itemData.stackCount or data.stackCount)
        end
        if marketPrice and marketPrice > 0 then
            -- Gold (ESO currency color, FFBF00 = 1, 0.749, 0) for market-price values, restoring
            -- the prior look. (Previously average prices were tinted salmon/red, which read as
            -- "value column turned red".)
            valueControl:SetColor(1, 0.749019, 0, 1)
            valueControl:SetText(BETTERUI.FormatAbbreviatedNumber(math.floor(marketPrice)))
            return
        end
    end

    valueControl:SetColor(1, 1, 1, 1)
    valueControl:SetText(BETTERUI.FormatAbbreviatedNumber(data.stackSellPrice))
end

local function ResolveIsMultiSelected(data)
    local multiSelectManager = BETTERUI.CIM.MultiSelectManager
    if not (multiSelectManager and multiSelectManager.GetActiveInstance) then
        return false
    end

    local manager = multiSelectManager.GetActiveInstance()
    if not (manager and manager:IsActive()) then
        return false
    end

    return manager:IsSelected(data)
end

local function ApplySelectionVisualState(control, data, selected)
    -- Suppress the stock highlight so CIM's custom gradient bar is the only active selection UI.
    if control.highlight then
        control.highlight:SetHidden(true)
    end

    BETTERUI.CIM.SelectionHighlight.Setup(control, selected, data)

    local selectionIndicator = control:GetNamedChild("SelectionIndicator")
    local selectionBar = control:GetNamedChild("SelectionBar")
    local isMultiSelected = ResolveIsMultiSelected(data)

    if selectionIndicator then
        selectionIndicator:SetHidden(not isMultiSelected)
        if isMultiSelected then
            selectionIndicator:SetColor(0.2, 0.9, 0.2, 1)
        end
    end

    -- Controls are pooled/reused; always restore the non-multiselect color path to prevent green bleed-through.
    if selectionBar then
        if isMultiSelected then
            selectionBar:SetHidden(false)
            selectionBar:SetColor(0.2, 0.8, 0.3, 0.6)
        elseif selected then
            -- Match the template's gold highlight color (XML #C4A64D) when focused but not multi-selected.
            selectionBar:SetColor(0.77, 0.65, 0.30, 0.45)
        end
    end
end

local function ApplyDynamicIconSizing(control, moduleName)
    local iconControl = control:GetNamedChild("Icon")
    local equipIconControl = control:GetNamedChild("EquippedMain")
    if not iconControl or not equipIconControl then
        return
    end

    local fontSize = GetActiveNameFontSize(moduleName)
    local iconSize = math.floor(BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_ICON_SIZE *
        (fontSize / BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_FONT_SIZE) +
        0.5)
    local equipIconWidth = math.floor(BETTERUI.Inventory.CONST.EQUIP_ICON_BASE_WIDTH *
        (fontSize / BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_FONT_SIZE) + 0.5)
    local equipIconHeight = math.floor(BETTERUI.Inventory.CONST.EQUIP_ICON_BASE_HEIGHT *
        (fontSize / BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_FONT_SIZE) + 0.5)
    local iconOffset = math.floor(BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_ICON_OFFSET +
        (fontSize - BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_FONT_SIZE) *
        BETTERUI.Inventory.CONST.LIST_ENTRY_ICON_OFFSET_FACTOR + 0.5)

    iconControl:SetDimensions(iconSize, iconSize)
    iconControl:ClearAnchors()
    iconControl:SetAnchor(CENTER, control:GetNamedChild("Label"), LEFT, iconOffset, 0)
    equipIconControl:SetDimensions(equipIconWidth, equipIconHeight)
end

--- Configures a shared gamepad inventory entry (row).
--- Purpose: The main render function. Populates all displayed data for a row.
---@param control table UI control for the entry row
---@param data BetterUIInventoryEntryData Entry data with bagId, slotIndex, cached_itemLink, etc.
---@param selected boolean Whether this entry is currently selected
---@param reselectingDuringRebuild boolean Whether reselecting during list rebuild
---@param enabled boolean Whether the entry is enabled
---@param active boolean Whether the entry is active
---@return nil
function BETTERUI_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
    BETTERUI_SharedGamepadEntryLabelSetup(control.label, data, selected)

    local entryContext = ResolveEntryContext(data)
    if not entryContext then
        local columnControls = ResolveEntryColumnControls(control, ResolveColumnFont(ResolveEntryModuleName(data)))
        if columnControls then
            columnControls.itemType:SetText(data.bestItemTypeName or "")
            columnControls.trait:SetText("-")
            columnControls.stat:SetText("-")
            columnControls.value:SetText("-")
        end
        return
    end

    local columnControls = ResolveEntryColumnControls(control, ResolveColumnFont(entryContext.moduleName))
    if not columnControls then
        return
    end

    columnControls.itemType:SetText(string.upper(data.bestItemTypeName))
    columnControls.trait:SetText(ResolveTraitText(entryContext.itemData, data, entryContext.bagId, entryContext.slotIndex))
    columnControls.stat:SetText(ResolveStatText(data, entryContext.itemData, entryContext.itemType, entryContext.itemLink))
    ApplyValueText(columnControls.value, data, entryContext.itemData, entryContext.itemLink)

    BETTERUI_SharedGamepadEntryIconSetup(control.icon, control.stackCountLabel, data, selected)
    ApplySelectionVisualState(control, data, selected)

    BETTERUI_CooldownSetup(control, data)
    BETTERUI_IconSetup(control:GetNamedChild("StatusIndicator"), control:GetNamedChild("EquippedMain"), data)
    ApplyDynamicIconSizing(control, entryContext.moduleName)
end

--- Determines the best display category for an item (e.g., "One-Handed", "Heavy Armor").
function BETTERUI.Inventory.GetBestItemCategoryDescription(itemData)
    local sharedItemSupport = BETTERUI.CIM and BETTERUI.CIM.SharedItemSupport
    if sharedItemSupport and sharedItemSupport.GetBestItemCategoryDescription then
        return sharedItemSupport.GetBestItemCategoryDescription(itemData)
    end
    return BETTERUI.Inventory.Categories.GetBestItemCategoryDescription(itemData)
end

-- Compatibility alias: call sites outside this module (e.g. Companions) still
-- reference the historical bare global.
GetBestItemCategoryDescription = BETTERUI.Inventory.GetBestItemCategoryDescription

-- Class: BETTERUI.Inventory.List (extends ZO_GamepadInventoryList)
BETTERUI.Inventory.List = ZO_GamepadInventoryList:Subclass()

--- Sets the list sort function, falling back to the standard inventory comparator.
---@param sortFunction function|nil Sort comparator function
---@return nil
function BETTERUI.Inventory.List:SetSortFunction(sortFunction)
    self.sortFunction = sortFunction or BETTERUI_Inventory_DefaultItemSortComparator
end

--- Creates a new Inventory List instance.
---@param ... any Arguments forwarded to ZO_GamepadInventoryList.New
---@return BETTERUI.Inventory.List object New list instance
function BETTERUI.Inventory.List:New(...)
    return ZO_GamepadInventoryList.New(self, ...)
end

---@class BetterUIInventoryListInitOptions
---@field inventoryType number|number[] Inventory type constant(s)
---@field slotType number Slot type constant
---@field selectedDataCallback function|nil Callback for selection changes
---@field entrySetupCallback function|nil Optional row setup hook; return true to skip default setup
---@field categoryResolver function|nil Category assignment function
---@field sortFunction function|nil Sort comparator function
---@field useTriggers boolean|nil Whether to use trigger keybinds
---@field template string|nil Entry template name
---@field templateSetupFunction function|nil Full template setup override
---@field listModuleName string|nil Owning list module name

--- Initializes the inventory list.
--- Purpose: Sets up the parametric scroll list, data templates, and update callbacks.
---@param control table UI control for the list container
---@param options BetterUIInventoryListInitOptions Explicit list initializer contract
---@return nil
function BETTERUI.Inventory.List:Initialize(control, options)
    if type(options) ~= "table" then
        error("BETTERUI.Inventory.List:Initialize expects options table", 2)
    end

    self.control = control
    self.selectedDataCallback = options.selectedDataCallback
    self.entrySetupCallback = options.entrySetupCallback
    self.categorizationFunction = options.categoryResolver
    self.listModuleName = options.listModuleName or "Inventory"
    self:SetSortFunction(options.sortFunction)
    self.dataBySlotIndex = {}
    self.isDirty = true
    self.useTriggers = (options.useTriggers ~= false) -- nil => true
    self.template = options.template or DEFAULT_TEMPLATE

    self.inventoryTypes = NormalizeInventoryTypes(options.inventoryType)
    local resolvedSlotType = options.slotType

    ---@param rowControl table
    ---@param data BetterUIInventoryEntryData
    local function InventoryEntryTemplateSetup(rowControl, data, selected, selectedDuringRebuild, enabled, activated)
        if resolvedSlotType ~= nil then
            ZO_Inventory_BindSlot(data, resolvedSlotType, data.slotIndex, data.bagId)
        end
        AssignEntryListModuleName(data, self.listModuleName)

        local didHandleSetup = false
        if self.entrySetupCallback then
            didHandleSetup = self.entrySetupCallback(rowControl, data, selected, selectedDuringRebuild, enabled, activated,
                self) == true
        end

        if not didHandleSetup then
            BETTERUI_SharedGamepadEntry_OnSetup(rowControl, data, selected, selectedDuringRebuild, enabled, activated)
        end
    end

    self.list = BETTERUI_VerticalParametricScrollList:New(self.control)
    -- Short controlPoolPrefix keeps pooled-control names under the engine limit.
    local controlPoolPrefix = self.template == DEFAULT_TEMPLATE and "BUI_ItemRow" or nil
    self.list:AddDataTemplate(self.template, options.templateSetupFunction or InventoryEntryTemplateSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction, nil, controlPoolPrefix)
    self.list:AddDataTemplateWithHeader(self.template, options.templateSetupFunction or InventoryEntryTemplateSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction, MenuEntryTemplateEquality,
        "ZO_GamepadMenuEntryHeaderTemplate", nil, controlPoolPrefix)

    local leftTrigger, rightTrigger = BETTERUI.CIM.Keybinds.CreateListTriggerKeybinds({
        list = self.list,
        getSpeed = function()
            return BETTERUI.Inventory.GetSetting("triggerSpeed")
        end,
        isEnabled = function()
            return BETTERUI.Inventory.GetSetting("useTriggersForSkip")
        end,
    })
    self.triggerKeybinds = { leftTrigger, rightTrigger }

    -- The bottom offset compensates for the list anchor sitting 10px below the footer container.
    local listScrollControl = self.list and self.list.control
    if listScrollControl then
        BETTERUI.CIM.ScrollIndicator.Setup(listScrollControl, {
            listObject = self.list,
            offsetX = 5,
            offsetTopY = -8,
            offsetBottomY = -10,
            visibleItems = 15,
        })
    end

    local function SelectionChangedCallback(list, selectedData)
        if self.selectedDataCallback then
            self.selectedDataCallback(list, selectedData)
        end
        if selectedData then
            BETTERUI.Inventory.NewItemTracker.PrepareFromSelectedData(selectedData)
            self:GetParametricList():RefreshVisible()
            local listCtrl = self.list and self.list.control
            if listCtrl then
                BETTERUI.CIM.ScrollIndicator.Update(listCtrl)
            end
        end
    end

    local function OnEffectivelyShown()
        if self.isDirty then
            self:RefreshList()
        elseif self.selectedDataCallback then
            self.selectedDataCallback(self.list, self.list:GetTargetData())
        end
        self:Activate()
    end

    local function OnEffectivelyHidden()
        BETTERUI.Inventory.NewItemTracker.CommitPendingClears()
        self:Deactivate()
    end

    local function OnInventoryUpdated(bagId)
        if BETTERUI.Log and BETTERUI.Log.IsActive() then BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "OnInventoryUpdated callback", {bagId = bagId}) end
        -- Skip work while this list is off-screen (inactive list, or inventory scene
        -- hidden); mark dirty so OnEffectivelyShown refreshes once on return. Mirrors
        -- RefreshList's own IsHidden() guard, keeping these lifetime-registered
        -- SHARED_INVENTORY callbacks as cheap no-ops instead of rebuilding hidden lists.
        if self.control:IsHidden() or not (BETTERUI.Utils and BETTERUI.Utils.IsInventorySceneShowing()) then
            self.isDirty = true
            return
        end
        if TracksInventoryType(self, bagId) then
            self:RefreshList()
        end
    end

    local function OnSingleSlotInventoryUpdate(bagId, slotIndex)
        -- Off-screen guard: see OnInventoryUpdated. Without this the incremental update
        -- path below (SetupItemEntry + RefreshVisible) runs on a hidden / off-scene list.
        if self.control:IsHidden() or not (BETTERUI.Utils and BETTERUI.Utils.IsInventorySceneShowing()) then
            self.isDirty = true
            return
        end
        if TracksInventoryType(self, bagId) then
            -- Keyed by bag AND slot: lists can track multiple bags, and slot
            -- indices repeat across bags. Two-level numeric keys avoid
            -- per-lookup key-string concatenation.
            local entriesByBag = self.dataBySlotIndex[bagId]
            local entry = entriesByBag and entriesByBag[slotIndex]
            if entry then
                local itemData = SHARED_INVENTORY:GenerateSingleSlotData(bagId, slotIndex)
                if itemData then
                    local resolvedItemCategoryResolver = self.categorizationFunction or
                        BETTERUI.Inventory.GetBestItemCategoryDescription
                    ApplyInventoryCategoryFields(itemData, resolvedItemCategoryResolver)
                    SetEntryListModuleName(itemData, self.listModuleName)
                    -- requiredChampionPoints is already populated by GenerateSingleSlotData
                    -- (GetItemRequiredChampionPoints); no link-API re-fetch needed here.
                    self:SetupItemEntry(entry, itemData)
                    self.list:RefreshVisible()
                else -- The item was removed.
                    self:RefreshList()
                end
            else -- The item is new.
                self:RefreshList()
            end
        end
    end

    local shouldRegisterSharedInventoryCallbacks = true
    local previousSharedInventoryCallbacks = self._betteruiSharedInventoryCallbacks
    if previousSharedInventoryCallbacks then
        if SHARED_INVENTORY.UnregisterCallback then
            SHARED_INVENTORY:UnregisterCallback("FullInventoryUpdate", previousSharedInventoryCallbacks.full)
            SHARED_INVENTORY:UnregisterCallback("SingleSlotInventoryUpdate", previousSharedInventoryCallbacks.single)
        else
            shouldRegisterSharedInventoryCallbacks = false
        end
    end

    self:SetOnSelectedDataChangedCallback(SelectionChangedCallback)

    self.control:SetHandler("OnEffectivelyShown", OnEffectivelyShown)
    self.control:SetHandler("OnEffectivelyHidden", OnEffectivelyHidden)

    if shouldRegisterSharedInventoryCallbacks then
        self._betteruiSharedInventoryCallbacks = {
            full = OnInventoryUpdated,
            single = OnSingleSlotInventoryUpdate,
        }
        SHARED_INVENTORY:RegisterCallback("FullInventoryUpdate", OnInventoryUpdated)
        SHARED_INVENTORY:RegisterCallback("SingleSlotInventoryUpdate", OnSingleSlotInventoryUpdate)
    end
end

--- Populates the slot table with accepted item data for the list.
---@param slotsTable BetterUIInventoryRowData[] Array to insert slot data into
---@param inventoryType number Inventory type constant
---@param slotIndex number Slot index to query
---@return nil
function BETTERUI.Inventory.List:AddSlotDataToTable(slotsTable, inventoryType, slotIndex)
    local itemFilterFunction = self.itemFilterFunction
    local resolvedCategoryResolver = self.categorizationFunction or
        BETTERUI.Inventory.GetBestItemCategoryDescription
    local slotData = SHARED_INVENTORY:GenerateSingleSlotData(inventoryType, slotIndex)
    if slotData then
        if (not itemFilterFunction) or itemFilterFunction(slotData) then
            ApplyInventoryCategoryFields(slotData, resolvedCategoryResolver)
            SetEntryListModuleName(slotData, self.listModuleName)

            table.insert(slotsTable, slotData)
        end
    end
end

local function TraceInventoryListRefresh(phase, data)
    if not (BETTERUI.Log and BETTERUI.Log.IsActive and BETTERUI.Log.IsActive()) then
        return
    end
    data = data or {}
    data.phase = phase
    BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.LIST, "inventory list refresh", data)
end

local function DescribeInventorySlotForTrace(itemData, index)
    local rawData = GetEntryDataSource(itemData)
    if not rawData then
        return nil
    end
    return {
        index = index,
        bagId = rawData.bagId,
        slotIndex = rawData.slotIndex,
        name = rawData.name,
        category = rawData.bestGamepadItemCategoryName or rawData.bestItemCategoryName,
        uniqueId = NormalizeEntryUniqueId(rawData.uniqueId),
        stackCount = rawData.stackCount,
        isEquipped = rawData.equipType ~= nil and rawData.equipType ~= EQUIP_TYPE_INVALID,
    }
end

local function BuildInventorySlotSample(slots, maxItems)
    local sample = {}
    local limit = math.min(#slots, maxItems or 10)
    for i = 1, limit do
        sample[#sample + 1] = DescribeInventorySlotForTrace(slots[i], i)
    end
    return sample
end

local function BuildInventoryTargetSnapshot(list)
    if not (list and list.GetTargetData) then
        return nil
    end
    local targetData = list:GetTargetData()
    local rawData = GetEntryDataSource(targetData)
    if not rawData then
        return nil
    end
    return DescribeInventorySlotForTrace(rawData, targetData and targetData.sortIndex)
end

--- Refreshes the inventory list from current source data.
---@return nil
function BETTERUI.Inventory.List:RefreshList()
    local isHidden = self.control:IsHidden()
    TraceInventoryListRefresh("begin", {
        listModuleName = self.listModuleName,
        hidden = isHidden,
        dirty = self.isDirty == true,
        inventoryTypes = self.inventoryTypes,
    })
    if isHidden then
        self.isDirty = true
        TraceInventoryListRefresh("skipped", { listModuleName = self.listModuleName, reason = "hidden" })
        return
    end
    self.isDirty = false

    self.list:Clear()
    self.dataBySlotIndex = {}

    local slots = self:GenerateSlotTable()
    TraceInventoryListRefresh("generated", {
        listModuleName = self.listModuleName,
        rowCount = #slots,
        sample = BuildInventorySlotSample(slots, 10),
    })
    table.sort(slots, self.sortFunction or BETTERUI_Inventory_DefaultItemSortComparator)
    TraceInventoryListRefresh("sorted", {
        listModuleName = self.listModuleName,
        rowCount = #slots,
        hasCustomSort = self.sortFunction ~= nil and self.sortFunction ~= BETTERUI_Inventory_DefaultItemSortComparator,
        sample = BuildInventorySlotSample(slots, 10),
    })
    local currentBestCategoryName
    for i, itemData in ipairs(slots) do
        local entry = ZO_GamepadEntryData:New(itemData.name, itemData.iconFile)
        self:SetupItemEntry(entry, itemData)
        if itemData.bestGamepadItemCategoryName ~= currentBestCategoryName then
            currentBestCategoryName = itemData.bestGamepadItemCategoryName
            entry:SetHeader(currentBestCategoryName)

            -- Template names are strings; the matching header template is
            -- registered in Initialize via AddDataTemplateWithHeader.
            self.list:AddEntryWithHeader(self.template, entry)
        else
            self.list:AddEntry(self.template, entry)
        end

        -- Keyed by bag AND slot (see OnSingleSlotInventoryUpdate); two-level
        -- numeric keys avoid per-item key-string concatenation.
        local entriesByBag = self.dataBySlotIndex[itemData.bagId]
        if not entriesByBag then
            entriesByBag = {}
            self.dataBySlotIndex[itemData.bagId] = entriesByBag
        end
        entriesByBag[itemData.slotIndex] = entry
    end

    self.list:Commit()
    TraceInventoryListRefresh("committed", {
        listModuleName = self.listModuleName,
        rowCount = #slots,
        selected = BuildInventoryTargetSnapshot(self.list),
        sample = BuildInventorySlotSample(slots, 10),
    })

    local listCtrl = self.list and self.list.control
    if listCtrl then
        BETTERUI.CIM.ScrollIndicator.Update(listCtrl)
    end
end
