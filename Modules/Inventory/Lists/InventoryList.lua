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
---@param left table Left item data
---@param right table Right item data
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

local function GetEntryDataSource(data)
    return data and (data.dataSource or data) or nil
end

local function SetEntryListModuleName(target, moduleName)
    if target and moduleName then
        target.listModuleName = moduleName
    end
end

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

local function ApplyInventoryCategoryFields(itemData, categorizationFunction)
    local categoryName = categorizationFunction(itemData)
    local itemTypeName = zo_strformat(SI_INVENTORY_HEADER, GetBestItemCategoryDescription(itemData))

    itemData.bestGamepadItemCategoryName = categoryName
    itemData.bestItemCategoryName = categoryName
    itemData.itemCategoryName = categoryName
    itemData.bestItemTypeName = itemTypeName
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

--- Configures a shared gamepad inventory entry (row).
--- Purpose: The main render function. Populates all displayed data for a row.
---@param control table UI control for the entry row
---@param data table Entry data with bagId, slotIndex, cached_itemLink, etc.
---@param selected boolean Whether this entry is currently selected
---@param reselectingDuringRebuild boolean Whether reselecting during list rebuild
---@param enabled boolean Whether the entry is enabled
---@param active boolean Whether the entry is active
---@return nil
function BETTERUI_SharedGamepadEntry_OnSetup(control, data, selected, reselectingDuringRebuild, enabled, active)
    BETTERUI_SharedGamepadEntryLabelSetup(control.label, data, selected)
    local moduleName = ResolveEntryModuleName(data)
    local itemData = GetEntryDataSource(data)

    -- Use cached values for performance
    local bagId = itemData and itemData.bagId or nil
    local slotIndex = itemData and itemData.slotIndex or nil

    -- Early return for non-item entries (currency rows, headers)
    -- These have .label but no bagId/slotIndex for item data
    if bagId == nil or slotIndex == nil then
        return
    end

    local itemLink = (itemData.cached_itemLink or data.cached_itemLink)
        or (bagId and slotIndex and GetItemLink(bagId, slotIndex))
    local itemType = (itemData.cached_itemType or data.cached_itemType)
        or (itemLink and GetItemLinkItemType(itemLink))

    -- Determine which scene is active and use appropriate column font settings
    local sharedItemSupport = BETTERUI.CIM and BETTERUI.CIM.SharedItemSupport
    local columnFont = sharedItemSupport
        and sharedItemSupport.ResolveColumnFontDescriptor(moduleName, "Inventory")
        or BETTERUI.Inventory.GetColumnFontDescriptor()

    local itemTypeControl = control:GetNamedChild("ItemType")
    local traitControl = control:GetNamedChild("Trait")
    local statControl = control:GetNamedChild("Stat")
    local valueControl = control:GetNamedChild("Value")
    if not itemTypeControl or not traitControl or not statControl or not valueControl then return end

    -- Apply column font
    itemTypeControl:SetFont(columnFont)
    traitControl:SetFont(columnFont)
    statControl:SetFont(columnFont)
    valueControl:SetFont(columnFont)

    -- Set item type
    itemTypeControl:SetText(string.upper(data.bestItemTypeName))

    -- Set trait information
    local traitName = itemData.cached_traitName or data.cached_traitName
    if not traitName then
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
    end
    traitControl:SetText(traitName)

    -- Set stat information based on item type
    local statText
    if itemType == ITEMTYPE_RECIPE then
        local isUnknown = data.cached_isRecipeAndUnknown
        if isUnknown == nil then
            isUnknown = not IsItemLinkRecipeKnown(itemLink)
        end
        statText = isUnknown and GetString(rawget(_G, "SI_BETTERUI_INV_RECIPE_UNKNOWN")) or
            GetString(rawget(_G, "SI_BETTERUI_INV_RECIPE_KNOWN"))
    elseif data.cached_isBook or itemType == ITEMTYPE_BOOK or itemType == ITEMTYPE_LOREBOOK or itemType == ITEMTYPE_RACIAL_STYLE_MOTIF then
        local isKnown = data.cached_isBookKnown
        if isKnown == nil then
            isKnown = IsItemLinkBookKnown(itemLink)
        end
        statText = isKnown and GetString(rawget(_G, "SI_BETTERUI_INV_RECIPE_KNOWN")) or
            GetString(rawget(_G, "SI_BETTERUI_INV_RECIPE_UNKNOWN"))
    else
        local statValue = itemData.statValue
        if statValue == nil then
            statText = "-"
        else
            statText = (statValue == 0) and "-" or statValue
        end
    end
    statControl:SetText(statText)

    -- Handle market price display
    if ShouldShowMarketPrice() and
        (BETTERUI.Utils.IsBankingSceneShowing() or BETTERUI.Utils.IsInventorySceneShowing()) then
        local marketIntegration = BETTERUI.CIM and BETTERUI.CIM.MarketIntegration
        local marketPrice, isAverage = 0, false
        if marketIntegration and type(marketIntegration.GetMarketPrice) == "function" then
            marketPrice, isAverage = marketIntegration.GetMarketPrice(itemLink, itemData.stackCount or data.stackCount)
        end
        if marketPrice and marketPrice > 0 then
            valueControl:SetColor(isAverage and 1 or 1, isAverage and 0.5 or 0.75, isAverage and 0.5 or 0, 1)
            valueControl:SetText(BETTERUI.FormatAbbreviatedNumber(math.floor(marketPrice)))
        else
            valueControl:SetColor(1, 1, 1, 1)
            valueControl:SetText(BETTERUI.FormatAbbreviatedNumber(data.stackSellPrice))
        end
    else
        valueControl:SetColor(1, 1, 1, 1)
        valueControl:SetText(BETTERUI.FormatAbbreviatedNumber(data.stackSellPrice))
    end

    -- Setup remaining UI elements
    BETTERUI_SharedGamepadEntryIconSetup(control.icon, control.stackCountLabel, data, selected)

    -- Hide original highlight - we use our custom gradient selection bar instead
    if control.highlight then
        control.highlight:SetHidden(true)
    end

    -- Apply gradient selection bar
    BETTERUI.CIM.SelectionHighlight.Setup(control, selected)


    -- Show selection indicator for multi-selected items
    local selectionIndicator = control:GetNamedChild("SelectionIndicator")
    local selectionBar = control:GetNamedChild("SelectionBar")
    local isMultiSelected = false

    -- Check with MultiSelectManager if available
    local multiSelectManager = BETTERUI.CIM.MultiSelectManager
    if multiSelectManager and multiSelectManager.GetActiveInstance then
        local manager = multiSelectManager.GetActiveInstance()
        if manager and manager:IsActive() then
            isMultiSelected = manager:IsSelected(data)
        end
    end

    -- Handle selection indicator (checkmark)
    if selectionIndicator then
        selectionIndicator:SetHidden(not isMultiSelected)
        if isMultiSelected then
            -- Color the checkmark green for visibility
            selectionIndicator:SetColor(0.2, 0.9, 0.2, 1)
        end
    end

    -- Handle SelectionBar color based on multi-select state
    -- Reset color when NOT multi-selected to handle control recycling.
    -- Controls are pooled and reused - the green color would persist on recycled controls otherwise.
    if selectionBar then
        if isMultiSelected then
            selectionBar:SetHidden(false)
            selectionBar:SetColor(0.2, 0.8, 0.3, 0.6) -- Green tint for multi-selected
        elseif selected then
            -- Reset to default gold color for focused non-multi-selected items
            -- Default gold from XML: #C4A64D = (196/255, 166/255, 77/255) ≈ (0.77, 0.65, 0.30)
            selectionBar:SetColor(0.77, 0.65, 0.30, 0.45)
        end
        -- Note: When not selected and not multi-selected, SelectionHighlight.Setup already hides the bar
    end

    BETTERUI_CooldownSetup(control, data)
    BETTERUI_IconSetup(control:GetNamedChild("StatusIndicator"), control:GetNamedChild("EquippedMain"), data)

    -- Adjust icon dimensions based on active scene/module name font size setting
    local iconControl = control:GetNamedChild("Icon")
    local equipIconControl = control:GetNamedChild("EquippedMain")
    local fontSize = GetActiveNameFontSize(moduleName)


    -- Calculate icon dimensions based on font size (scales proportionally from default of 24px = 34px icon)
    local iconSize = math.floor(BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_ICON_SIZE *
        (fontSize / BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_FONT_SIZE) +
        0.5)
    -- Calculate equip icon dimensions (scales proportionally with font size)
    local equipIconWidth = math.floor(BETTERUI.Inventory.CONST.EQUIP_ICON_BASE_WIDTH *
        (fontSize / BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_FONT_SIZE) + 0.5)
    local equipIconHeight = math.floor(BETTERUI.Inventory.CONST.EQUIP_ICON_BASE_HEIGHT *
        (fontSize / BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_FONT_SIZE) + 0.5)
    local iconOffset = math.floor(BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_ICON_OFFSET +
        (fontSize - BETTERUI.Inventory.CONST.LIST_ENTRY_BASE_FONT_SIZE) *
        BETTERUI.Inventory.CONST.LIST_ENTRY_ICON_OFFSET_FACTOR + 0.5) -- Adjust offset as font grows

    iconControl:SetDimensions(iconSize, iconSize)
    iconControl:ClearAnchors()
    iconControl:SetAnchor(CENTER, control:GetNamedChild("Label"), LEFT, iconOffset, 0)
    equipIconControl:SetDimensions(equipIconWidth, equipIconHeight)
end

--- Determines the best display category for an item (e.g., "One-Handed", "Heavy Armor").
function GetBestItemCategoryDescription(itemData)
    local sharedItemSupport = BETTERUI.CIM and BETTERUI.CIM.SharedItemSupport
    if sharedItemSupport and sharedItemSupport.GetBestItemCategoryDescription then
        return sharedItemSupport.GetBestItemCategoryDescription(itemData)
    end
    return BETTERUI.Inventory.Categories.GetBestItemCategoryDescription(itemData)
end

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
---@return table object New list instance
function BETTERUI.Inventory.List:New(...)
    local object = ZO_GamepadInventoryList.New(self, ...)
    return object
end

--- Initializes the inventory list.
--- Purpose: Sets up the parametric scroll list, data templates, and update callbacks.
---@param control table UI control for the list container
---@param inventoryType number|table Inventory type constant(s)
---@param slotType number Slot type constant
---@param selectedDataCallback function|nil Callback for selection changes
---@param entrySetupCallback function|nil Entry setup function
---@param categoryResolver function|nil Category assignment function
---@param sortFunction function|nil Sort comparator function
---@param useTriggers boolean|nil Whether to use trigger keybinds
---@param template string|nil Entry template name
---@param templateSetupFunction function|nil Template setup function
---@return nil
function BETTERUI.Inventory.List:Initialize(control, inventoryType, slotType, selectedDataCallback, entrySetupCallback,
                                            categoryResolver, sortFunction, useTriggers, template,
                                            templateSetupFunction)
    self.control = control
    self.selectedDataCallback = selectedDataCallback
    self.entrySetupCallback = entrySetupCallback
    self.categorizationFunction = categoryResolver
    self.listModuleName = "Inventory"
    self:SetSortFunction(sortFunction)
    self.dataBySlotIndex = {}
    self.isDirty = true
    self.useTriggers = (useTriggers ~= false) -- nil => true
    self.template = template or DEFAULT_TEMPLATE

    self.inventoryTypes = NormalizeInventoryTypes(inventoryType)

    local function InventoryEntryTemplateSetup(rowControl, data, selected, selectedDuringRebuild, enabled, activated)
        ZO_Inventory_BindSlot(data, slotType, data.slotIndex, data.bagId)
        AssignEntryListModuleName(data, self.listModuleName)
        BETTERUI_SharedGamepadEntry_OnSetup(rowControl, data, selected, selectedDuringRebuild, enabled, activated)
    end

    self.list = BETTERUI_VerticalParametricScrollList:New(self.control)
    self.list:AddDataTemplate(self.template, templateSetupFunction or InventoryEntryTemplateSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction)
    self.list:AddDataTemplateWithHeader("ZO_GamepadItemSubEntryTemplate", ZO_SharedGamepadEntry_OnSetup,
        ZO_GamepadMenuEntryTemplateParametricListFunction, MenuEntryTemplateEquality, "ZO_GamepadMenuEntryHeaderTemplate")

    -- Use BetterUI custom trigger keybinds with Inventory-specific speed and enabled getters
    local leftTrigger, rightTrigger = BETTERUI.CIM.Keybinds.CreateListTriggerKeybinds(
        self.list, nil, function()
            return BETTERUI.Inventory.GetSetting("triggerSpeed")
        end, function()
            return BETTERUI.Inventory.GetSetting("useTriggersForSkip")
        end
    )
    self.triggerKeybinds = { leftTrigger, rightTrigger }

    -- Initialize scroll indicator on the list's internal control
    -- offsetX=5, offsetTopY=-8 (above list top), offsetBottomY=-10 (above footer top)
    -- Note: List BOTTOMRIGHT is anchored 10px below FooterContainerFooter's top,
    -- so offsetBottomY=-10 aligns the container bottom with the footer's top edge.
    local listScrollControl = self.list and self.list.control
    if listScrollControl then
        BETTERUI.CIM.ScrollIndicator.Initialize(listScrollControl, 5, -8, -10, self.list)
    end

    local function SelectionChangedCallback(list, selectedData)
        if self.selectedDataCallback then
            self.selectedDataCallback(list, selectedData)
        end
        if selectedData then
            BETTERUI.Inventory.NewItemTracker.PrepareFromSelectedData(selectedData)
            self:GetParametricList():RefreshVisible()
            -- Update scroll indicator position
            -- Use targetSelectedIndex (the intended final position) rather than GetSelectedIndex()
            -- (the animated intermediate) to prevent the thumb from stopping short of the bottom
            local listCtrl = self.list and self.list.control
            if listCtrl then
                local currentIndex = list.targetSelectedIndex or list:GetSelectedIndex() or 1
                local totalItems = list:GetNumEntries() or 0
                local visibleItems = 15 -- Approximate visible items in inventory list
                BETTERUI.CIM.ScrollIndicator.Update(listCtrl, currentIndex, totalItems, visibleItems)
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
        if TracksInventoryType(self, bagId) then
            self:RefreshList()
        end
    end

    local function OnSingleSlotInventoryUpdate(bagId, slotIndex)
        if TracksInventoryType(self, bagId) then
            local entry = self.dataBySlotIndex[slotIndex]
            if entry then
                local itemData = SHARED_INVENTORY:GenerateSingleSlotData(bagId, slotIndex)
                if itemData then
                    local resolvedCategoryResolver = self.categorizationFunction or
                        GetBestItemCategoryDescription
                    ApplyInventoryCategoryFields(itemData, resolvedCategoryResolver)
                    SetEntryListModuleName(itemData, self.listModuleName)
                    if bagId ~= BAG_VIRTUAL then -- virtual items don't have any champion points associated with them
                        itemData.requiredChampionPoints = GetItemLinkRequiredChampionPoints(itemData)
                    end
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

    self:SetOnSelectedDataChangedCallback(SelectionChangedCallback)

    self.control:SetHandler("OnEffectivelyShown", OnEffectivelyShown)
    self.control:SetHandler("OnEffectivelyHidden", OnEffectivelyHidden)

    SHARED_INVENTORY:RegisterCallback("FullInventoryUpdate", OnInventoryUpdated)
    SHARED_INVENTORY:RegisterCallback("SingleSlotInventoryUpdate", OnSingleSlotInventoryUpdate)
end

--- Populates the slot table with item data from the inventory.
--- Purpose: Filters and accepts items for the list.
---@param slotsTable table Array to insert slot data into
---@param inventoryType number Inventory type constant
---@param slotIndex number Slot index to query
---@return nil
function BETTERUI.Inventory.List:AddSlotDataToTable(slotsTable, inventoryType, slotIndex)
    local itemFilterFunction = self.itemFilterFunction
    local resolvedCategoryResolver = self.categorizationFunction or
        GetBestItemCategoryDescription
    local slotData = SHARED_INVENTORY:GenerateSingleSlotData(inventoryType, slotIndex)
    if slotData then
        if (not itemFilterFunction) or itemFilterFunction(slotData) then
            ApplyInventoryCategoryFields(slotData, resolvedCategoryResolver)
            SetEntryListModuleName(slotData, self.listModuleName)

            table.insert(slotsTable, slotData)
        end
    end
end

--- Refreshes the inventory list.
--- Purpose: Rebuilds the visual list from source data.
---@return nil
function BETTERUI.Inventory.List:RefreshList()
    if self.control:IsHidden() then
        self.isDirty = true
        return
    end
    self.isDirty = false

    self.list:Clear()
    self.dataBySlotIndex = {}

    local slots = self:GenerateSlotTable()
    table.sort(slots, self.sortFunction or BETTERUI_Inventory_DefaultItemSortComparator)
    local currentBestCategoryName
    for i, itemData in ipairs(slots) do
        local entry = ZO_GamepadEntryData:New(itemData.name, itemData.iconFile)
        self:SetupItemEntry(entry, itemData)
        if itemData.bestGamepadItemCategoryName ~= currentBestCategoryName then
            currentBestCategoryName = itemData.bestGamepadItemCategoryName
            entry:SetHeader(currentBestCategoryName)

            self.list:AddEntryWithHeader(ZO_GamepadItemSubEntryTemplate, entry)
        else
            self.list:AddEntry(self.template, entry)
        end

        self.dataBySlotIndex[itemData.slotIndex] = entry
    end

    self.list:Commit()

    -- Update scroll indicator after list refresh
    -- Use targetSelectedIndex for the intended position rather than animated intermediate
    local listCtrl = self.list and self.list.control
    if listCtrl then
        local currentIndex = self.list.targetSelectedIndex or self.list:GetSelectedIndex() or 1
        local totalItems = self.list:GetNumEntries() or 0
        local visibleItems = 15 -- Approximate visible items in inventory list
        BETTERUI.CIM.ScrollIndicator.Update(listCtrl, currentIndex, totalItems, visibleItems)
    end
end
