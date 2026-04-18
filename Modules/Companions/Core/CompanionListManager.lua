--[[
File: Modules/Companions/Core/CompanionListManager.lua
Purpose: Companion list, category tabs, tooltip updates, and scroll indicator wiring.
]]

if not BETTERUI.Companions or not BETTERUI.Companions.Class then return end

local function WrapCompanionError(operation, err)
    local companions = BETTERUI and BETTERUI.Companions
    if companions and type(companions.WrapRuntimeError) == "function" then
        return companions.WrapRuntimeError(operation, err)
    end
    return string.format("[Companions] %s failed: %s", operation, tostring(err))
end

-- ---------------------------------------------------------------------------
-- Directional-Input Utilities
-- Mirrors the proven patterns from Vendor (tribal-knowledge 2026-04-11).
-- ---------------------------------------------------------------------------

---@param obj table|nil
---@return boolean
local function IsDirectionalInputListening(obj)
    if not obj or not (DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.IsListening) then
        return false
    end
    return DIRECTIONAL_INPUT:IsListening(obj)
end

---@param obj table|nil
---@return number registrationCount
local function CountDirectionalInputRegistrations(obj)
    if not obj or not (DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.inputObjects) then
        return 0
    end
    local count = 0
    for _, registered in ipairs(DIRECTIONAL_INPUT.inputObjects) do
        if registered == obj then
            count = count + 1
        end
    end
    return count
end

---@param obj table|nil
---@param includeMovementController boolean|nil
---@return number releasedCount
local function ReleaseDirectionalInputRegistrations(obj, includeMovementController)
    if not obj or not (DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.IsListening and DIRECTIONAL_INPUT.Deactivate) then
        return 0
    end
    local releasedCount = 0
    local seen = {}
    local candidates = { obj }
    if includeMovementController and obj.movementController then
        candidates[#candidates + 1] = obj.movementController
    end
    for _, candidate in ipairs(candidates) do
        if candidate and not seen[candidate] then
            seen[candidate] = true
            local safety = 0
            while DIRECTIONAL_INPUT:IsListening(candidate) and safety < 8 do
                DIRECTIONAL_INPUT:Deactivate(candidate)
                releasedCount = releasedCount + 1
                safety = safety + 1
            end
        end
    end
    return releasedCount
end

---@param header table|nil
---@param errors table|nil
local function ReleaseHeaderDirectionalInput(header, errors)
    if not header then return end
    local candidates = {
        header.headerFocus,
        header.tabBar,
        header.tabBar and header.tabBar.control,
    }
    for _, candidate in ipairs(candidates) do
        if candidate then
            if candidate.Deactivate then
                local ok, err = pcall(candidate.Deactivate, candidate)
                if not ok and errors then
                    errors[#errors + 1] = tostring(err)
                end
            end
            ReleaseDirectionalInputRegistrations(candidate, true)
        end
    end
end

local function EnsureListDirectionalInputRegistration(list, listRegistrationCount)
    local isActive = list.IsActive and list:IsActive()
    local listListening = listRegistrationCount > 0

    if isActive then
        if listListening then
            list.directionalInputEnabled = true
        elseif list.SetDirectionalInputEnabled then
            list:SetDirectionalInputEnabled(true)
        end
        return
    end

    if list.SetDirectionalInputEnabled then
        list.directionalInputEnabled = true
    end
    if list.Activate then
        list:Activate()
    end
end

local function ReleaseListDirectionalInput(list)
    if not list then
        return
    end
    if list.SetDirectionalInputEnabled then
        list:SetDirectionalInputEnabled(false)
    end
    if list.Deactivate and (not list.IsActive or list:IsActive()) then
        list:Deactivate()
    end
    ReleaseDirectionalInputRegistrations(list, true)
end

local CATEGORY_DEFINITIONS = {
    {
        key = "all",
        nameStringId = SI_BETTERUI_INV_ITEM_ALL,
        filterType = nil,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds",
    },
    {
        key = "weapons",
        nameStringId = SI_BETTERUI_INV_ITEM_WEAPONS,
        filterType = ITEMFILTERTYPE_WEAPONS,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_weapons.dds",
    },
    {
        key = "apparel",
        nameStringId = SI_BETTERUI_INV_ITEM_APPAREL,
        filterType = ITEMFILTERTYPE_ARMOR,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_apparel.dds",
    },
    {
        key = "jewelry",
        nameStringId = SI_BETTERUI_INV_ITEM_JEWELRY,
        filterType = ITEMFILTERTYPE_JEWELRY,
        iconFile = "EsoUI/Art/Crafting/Gamepad/gp_jewelry_tabicon_icon.dds",
    },
    {
        key = "consumables",
        nameStringId = SI_BETTERUI_INV_ITEM_CONSUMABLE,
        filterType = ITEMFILTERTYPE_CONSUMABLE,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_consumables.dds",
    },
    {
        key = "materials",
        nameStringId = SI_BETTERUI_INV_ITEM_MATERIALS,
        filterType = ITEMFILTERTYPE_CRAFTING,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_crafting.dds",
    },
    {
        key = "furnishing",
        nameStringId = SI_BETTERUI_INV_ITEM_FURNISHING,
        filterType = ITEMFILTERTYPE_FURNISHING,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_furnishings.dds",
    },
    {
        key = "misc",
        nameStringId = SI_BETTERUI_INV_ITEM_MISC,
        filterType = ITEMFILTERTYPE_MISCELLANEOUS,
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_misc.dds",
    },
    {
        key = "equipped",
        nameStringId = SI_BETTERUI_INV_ITEM_EQUIPPED,
        filterType = -1, -- custom handled in DoesSlotMatchFilterType
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_equipped.dds",
    },
    {
        key = "junk",
        nameStringId = SI_BETTERUI_INV_ITEM_JUNK,
        filterType = -2, -- custom
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_junk.dds",
    },
    {
        key = "stolen",
        nameStringId = SI_BETTERUI_INV_ITEM_STOLEN,
        filterType = -3, -- custom
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_stolen.dds",
    },
}

---@param callback fun(bagId:number, slotIndex:number)
local function ForEachCompanionItem(callback)
    if not callback then return end

    local wornSize = GetBagSize(BAG_COMPANION_WORN) or 0
    for slotIndex = 0, wornSize - 1 do
        local name = GetItemName(BAG_COMPANION_WORN, slotIndex) or ""
        if name ~= "" then
            callback(BAG_COMPANION_WORN, slotIndex)
        end
    end

    local backpackSize = GetBagSize(BAG_BACKPACK) or 0
    for slotIndex = 0, backpackSize - 1 do
        local actorCategory = GetItemActorCategory and GetItemActorCategory(BAG_BACKPACK, slotIndex)
        if actorCategory == GAMEPLAY_ACTOR_CATEGORY_COMPANION then
            callback(BAG_BACKPACK, slotIndex)
        end
    end
end

--- @param bagId number
--- @param slotIndex number
--- @param filterType number|nil
--- @return boolean
function BETTERUI.Companions.Class:DoesSlotMatchFilterType(bagId, slotIndex, filterType)
    if not filterType then
        return true
    end

    -- Custom filters
    if filterType == -1 then -- Equipped
        return bagId == BAG_COMPANION_WORN
    end
    if filterType == -2 then -- Junk
        if IsItemJunk then
            return IsItemJunk(bagId, slotIndex)
        end
        return false
    end
    if filterType == -3 then -- Stolen
        if IsItemStolen then
            return IsItemStolen(bagId, slotIndex)
        end
        return false
    end

    if SHARED_INVENTORY and SHARED_INVENTORY.GenerateSingleSlotData and ZO_InventoryUtils_DoesNewItemMatchFilterType then
        local slotData = SHARED_INVENTORY:GenerateSingleSlotData(bagId, slotIndex)
        if slotData then
            return ZO_InventoryUtils_DoesNewItemMatchFilterType(slotData, filterType)
        end
    end

    if GetItemFilterTypeInfo then
        return GetItemFilterTypeInfo(bagId, slotIndex) == filterType
    end

    return true
end

---@return table|nil
function BETTERUI.Companions.Class:GetCurrentCategory()
    local categories = self.companionCategories or {}
    if #categories == 0 then
        return nil
    end

    local index = zo_clamp(self.currentCategoryIndex or 1, 1, #categories)
    return categories[index]
end

---@return nil
function BETTERUI.Companions.Class:InitializeCategoryHeader()
    self.headerGeneric = (self.header and self.header:GetNamedChild("Header")) or self.header
    if not self.headerGeneric then
        return
    end

    BETTERUI.GenericHeader.Initialize(self.headerGeneric, ZO_GAMEPAD_HEADER_TABBAR_CREATE)
    self.currentCategoryIndex = self.currentCategoryIndex or 1
end

---@return nil
function BETTERUI.Companions.Class:RefreshCategoryTitle()
    if not self.headerGeneric then return end
    local cat = self:GetCurrentCategory()
    local titleText
    if cat and cat.name and cat.key ~= "all" then
        titleText = zo_strformat("<<1>>", cat.name)
    else
        titleText = GetString(rawget(_G, "SI_BETTERUI_COMPANIONS_TITLE") or "SI_BETTERUI_COMPANIONS_TITLE")
    end
    if BETTERUI.GenericHeader and BETTERUI.GenericHeader.SetTitleText then
        BETTERUI.GenericHeader.SetTitleText(self.headerGeneric, titleText)
    end
end

---@return nil
function BETTERUI.Companions.Class:RefreshCategories()
    local previousCategory = self:GetCurrentCategory()
    local previousKey = previousCategory and previousCategory.key
    local visibleCategories = {}

    for _, def in ipairs(CATEGORY_DEFINITIONS) do
        local count = 0
        ForEachCompanionItem(function(bagId, slotIndex)
            if self:DoesSlotMatchFilterType(bagId, slotIndex, def.filterType) then
                count = count + 1
            end
        end)

        if def.key == "all" or count > 0 then
            visibleCategories[#visibleCategories + 1] = {
                key = def.key,
                name = GetString(def.nameStringId),
                filterType = def.filterType,
                iconFile = def.iconFile,
                itemCount = count,
            }
        end
    end

    if #visibleCategories == 0 then
        visibleCategories[1] = {
            key = "all",
            name = GetString(SI_BETTERUI_INV_ITEM_ALL),
            filterType = nil,
            iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_all.dds",
            itemCount = 0,
        }
    end

    self.companionCategories = visibleCategories
    local selectedIndex = 1
    if previousKey then
        for i, category in ipairs(visibleCategories) do
            if category.key == previousKey then
                selectedIndex = i
                break
            end
        end
    end
    self.currentCategoryIndex = selectedIndex

    self:RebuildCategoryHeader()
end

---@return nil
function BETTERUI.Companions.Class:RebuildCategoryHeader()
    local headerGeneric = self.headerGeneric
    local categories = self.companionCategories or {}
    if not headerGeneric or #categories == 0 then
        return
    end

    self.companionHeaderData = self.companionHeaderData or {}
    self.companionHeaderData.titleText = function()
        local cat = self:GetCurrentCategory()
        if cat and cat.name and cat.key ~= "all" then
            return zo_strformat("<<1>>", cat.name)
        end
        return GetString(rawget(_G, "SI_BETTERUI_COMPANIONS_TITLE") or "SI_BETTERUI_COMPANIONS_TITLE")
    end
    self.companionHeaderData.tabBarData = { parent = self, onNext = function(_, successful) if successful then self:OnTabNext() end end, onPrev = function(_, successful) if successful then self:OnTabPrev() end end }
    self.companionHeaderData.carouselConfig = {
        enabled = true,
        startOffset = 705,
        verticalOffset = -1,
    }
    self.companionHeaderData.onSelectedChanged = function(list)
        if self._suppressCompanionHeaderSelection then
            return
        end

        local selectedIndex = list and list.selectedIndex or self.currentCategoryIndex or 1
        selectedIndex = zo_clamp(selectedIndex, 1, #categories)
        if selectedIndex == self.currentCategoryIndex then
            return
        end

        -- Save position for outgoing category
        local outgoingCategory = self:GetCurrentCategory()
        if outgoingCategory and self.list then
            BETTERUI.CIM.PositionManager.SavePosition("Companions", outgoingCategory.key, self.list)
        end

        self.currentCategoryIndex = selectedIndex
        self:RefreshList()
        self:RefreshCategoryTitle()

        if self:IsSceneShowing() then
            self:EnsureListInputActive()
            self:UpdateItemTooltips(self.list and self.list:GetTargetData())
        end
    end

    self._suppressCompanionHeaderSelection = true
    if not headerGeneric.tabBar then
        BETTERUI.GenericHeader.Refresh(headerGeneric, self.companionHeaderData, false)
    end
    if headerGeneric.tabBar then
        headerGeneric.tabBar:Clear()
    end

    for _, category in ipairs(categories) do
        local entryData = ZO_GamepadEntryData:New(category.name, category.iconFile)
        entryData.filterType = category.filterType
        entryData.itemCount = category.itemCount
        entryData:SetIconTintOnSelection(true)
        BETTERUI.GenericHeader.AddToList(headerGeneric, entryData)
    end

    BETTERUI.GenericHeader.Refresh(headerGeneric, self.companionHeaderData, false)

    if headerGeneric.tabBar then
        local selectedIndex = zo_clamp(self.currentCategoryIndex or 1, 1, #categories)
        headerGeneric.tabBar:SetSelectedIndexWithoutAnimation(selectedIndex, true, true)
    end
    self._suppressCompanionHeaderSelection = false

    self:EnsureColumnHeadersVisible()
    if self:IsSceneShowing() then
        self:EnsureHeaderKeybindsActive()
    end
end

---@param delta number
---@return nil
function BETTERUI.Companions.Class:CycleCategory(delta)
    local categories = self.companionCategories or {}
    if #categories <= 1 then
        return
    end

    local nextIndex = (self.currentCategoryIndex or 1) + delta
    if nextIndex > #categories then
        nextIndex = 1
    elseif nextIndex < 1 then
        nextIndex = #categories
    end

    self.currentCategoryIndex = nextIndex
    self:RefreshList()
    self:RefreshCategoryTitle()
    if self:IsSceneShowing() then
        self:EnsureListInputActive()
        self:UpdateItemTooltips(self.list and self.list:GetTargetData())
    end

    local tabBar = self.headerGeneric and self.headerGeneric.tabBar
    if tabBar then
        self._suppressCompanionHeaderSelection = true
        tabBar:SetSelectedIndexWithoutAnimation(nextIndex, true, true)
        self._suppressCompanionHeaderSelection = false
    end
end

function BETTERUI.Companions.Class:OnTabNext()
    self:CycleCategory(1)
end

function BETTERUI.Companions.Class:OnTabPrev()
    self:CycleCategory(-1)
end

---@return nil
function BETTERUI.Companions.Class:EnsureHeaderKeybindsActive()
    local tabBar = self.headerGeneric and self.headerGeneric.tabBar
    if not tabBar then
        return
    end

    -- Scene-gate: never activate header DI owners unless scene is showing
    -- (tribal-knowledge root cause #1: premature header activation).
    if self.scene and not self.scene:IsShowing() then
        return
    end

    if tabBar.Activate and not tabBar.active then
        tabBar:Activate()
    end

    if tabBar.keybindStripDescriptor then
        BETTERUI.Interface.EnsureKeybindGroupAdded(tabBar.keybindStripDescriptor)
    end
end

---@return nil
function BETTERUI.Companions.Class:DeactivateHeaderKeybinds()
    local tabBar = self.headerGeneric and self.headerGeneric.tabBar
    if not tabBar then return end
    if tabBar.keybindStripDescriptor and KEYBIND_STRIP then
        KEYBIND_STRIP:RemoveKeybindButtonGroup(tabBar.keybindStripDescriptor)
    end
    if tabBar.Deactivate and tabBar.active then
        tabBar:Deactivate()
    end
end

---@return nil
function BETTERUI.Companions.Class:PositionSearchControl()
    if not self.textSearchHeaderControl then return end

    self.textSearchHeaderControl:ClearAnchors()
    local anchorTarget = self.headerGeneric or self.header
    local titleContainer = nil
    if anchorTarget and anchorTarget.GetNamedChild then
        titleContainer = anchorTarget:GetNamedChild("TitleContainer") or anchorTarget:GetNamedChild("Header")
    end

    local parentForAnchor = titleContainer or anchorTarget
    local searchConst = BETTERUI.CIM.SearchBar and BETTERUI.CIM.SearchBar.GetConstants and BETTERUI.CIM.SearchBar.GetConstants("BANKING")
    local xOffset = searchConst and searchConst.X_OFFSET or 55
    local yOffset = searchConst and searchConst.Y_OFFSET or 15
    local rightInset = searchConst and searchConst.RIGHT_INSET or -8
    if parentForAnchor then
        self.textSearchHeaderControl:SetAnchor(TOPLEFT, parentForAnchor, BOTTOMLEFT, xOffset, yOffset)
        self.textSearchHeaderControl:SetAnchor(TOPRIGHT, parentForAnchor, BOTTOMRIGHT, rightInset, yOffset)
    else
        self.textSearchHeaderControl:SetAnchor(TOPLEFT, self.header, BOTTOMLEFT, 0, 8)
        self.textSearchHeaderControl:SetAnchor(TOPRIGHT, self.header, BOTTOMRIGHT, 0, 8)
    end

    self.textSearchHeaderControl:SetHidden(false)
end

---@return nil
function BETTERUI.Companions.Class:EnsureColumnHeadersVisible()
    if not (self.header and self.header.columns) then
        return
    end

    local HDR_COL = BETTERUI.CIM.CONST.HEADER_LAYOUT.COLUMNS
    local COLUMN_KEYS = { "NAME", "TYPE", "TRAIT", "STAT", "VALUE" }
    local anchorTarget = (self.header and self.header:GetNamedChild("HeaderTabBar"))
        or (self.headerGeneric and self.headerGeneric:GetNamedChild("TabBar"))
        or (self.header and self.header:GetNamedChild("HeaderColumnBar"))

    -- Companions uses a custom list anchor, so the header labels need an
    -- additional empirical offset to stay aligned with the row content.
    local COLUMN_OFFSET_DELTA = 24

    for _, label in ipairs(self.header.columns) do
        if label then
            local columnIndex = label.columnIndex
            local key = columnIndex and COLUMN_KEYS[columnIndex]
            local xOffset = key and HDR_COL[key]
            if anchorTarget and xOffset then
                label:ClearAnchors()
                label:SetAnchor(LEFT, anchorTarget, BOTTOMLEFT, xOffset + COLUMN_OFFSET_DELTA, BETTERUI.CIM.CONST.LAYOUT.COLUMN_HEADER_Y_OFFSET)
            end
            label:SetHidden(false)
            label:SetAlpha(1)
            if label.SetDrawLayer then
                label:SetDrawLayer(DL_OVERLAY)
            end
        end
    end
end

---@return nil
function BETTERUI.Companions.Class:EnsureListInputActive()
    local list = self.list
    if not list then
        return
    end

    -- Scene-gate: never activate DI owners unless the scene is actually showing.
    if self.scene and not self.scene:IsShowing() then
        return
    end

    -- Deduplicate stale DI registrations — only clear when there are DUPLICATES
    -- (tribal-knowledge root cause #4: duplicate registrations = accelerated scrolling).
    -- A single registration is the correct steady-state.
    local listRegistrationCount = CountDirectionalInputRegistrations(list)
    if listRegistrationCount > 1 then
        ReleaseDirectionalInputRegistrations(list, true)
        listRegistrationCount = 0
    end

    EnsureListDirectionalInputRegistration(list, listRegistrationCount)
end

---@return nil
function BETTERUI.Companions.Class:DeactivateListInput()
    local list = self.list
    ReleaseListDirectionalInput(list)
end

--- Full directional-input release for the Companions scene.
--- Sweeps self, list, header, tab bar, search focus — everything that could
--- be orphaned on the global DIRECTIONAL_INPUT stack.
---@return nil
function BETTERUI.Companions.Class:ForceReleaseDirectionalInput()
    if not (DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.IsListening and DIRECTIONAL_INPUT.Deactivate) then
        return
    end

    local errors = {}

    local function SafeDeactivate(obj, includeMovementController, disableDirectionalInput)
        if not obj then return end
        if disableDirectionalInput and obj.SetDirectionalInputEnabled then
            obj:SetDirectionalInputEnabled(false)
        end
        if obj.Deactivate then
            if not obj.IsActive or obj:IsActive() or IsDirectionalInputListening(obj) then
                local ok, err = pcall(obj.Deactivate, obj)
                if not ok then
                    errors[#errors + 1] = tostring(err)
                end
            end
        end
        ReleaseDirectionalInputRegistrations(obj, includeMovementController)
    end

    SafeDeactivate(self, true)
    SafeDeactivate(self.list, true, true)
    ReleaseHeaderDirectionalInput(self.headerGeneric, errors)
    ReleaseHeaderDirectionalInput(self.header, errors)
    SafeDeactivate(self.textSearchHeaderFocus, true)
    SafeDeactivate(self.textSearchHeaderControl, true)

    if #errors > 0 then
        error(WrapCompanionError("ForceReleaseDirectionalInput", table.concat(errors, "; ")), 0)
    end
end

---@return nil
function BETTERUI.Companions.Class:InitializeListPresentation()
    if not self.list then
        return
    end

    if self.list.SetFixedCenterOffset then
        self.list:SetFixedCenterOffset(-50)
    end

    if self.list.SetNoItemText then
        self.list:SetNoItemText(GetString(rawget(_G, "SI_BETTERUI_EMPTY_LIST") or "SI_BETTERUI_EMPTY_LIST"))
    end

    if self.list.SetOnSelectedDataChangedCallback then
        self.list:SetOnSelectedDataChangedCallback(function(list, selectedData)
            if self._searchModeActive and not self._isRefreshing and self.list and self.list.IsActive and self.list:IsActive() then
                local searchMixin = BETTERUI.Interface and BETTERUI.Interface.SearchMixin
                if searchMixin and searchMixin.CallSearchLifecycle then
                    searchMixin.CallSearchLifecycle(self, "exit")
                else
                    local lifecycle = self.SEARCH_LIFECYCLE
                    local exitMethodName = lifecycle and lifecycle.exit
                    local exitMethod = exitMethodName and self[exitMethodName]
                    if type(exitMethod) == "function" then
                        exitMethod(self)
                    end
                end
                return
            end
            if self:IsSceneShowing() then
                self:UpdateItemTooltips(selectedData)
                if self.coreKeybinds then
                    KEYBIND_STRIP:UpdateKeybindButtonGroup(self.coreKeybinds)
                end
            end
            self:UpdateScrollIndicator(list)
        end)
    end

    if self.list.control and BETTERUI.CIM and BETTERUI.CIM.ScrollIndicator then
        BETTERUI.CIM.ScrollIndicator.Initialize(self.list.control, 5, -8, -10, self.list)
    end
end

---@param list table|nil
---@return nil
function BETTERUI.Companions.Class:UpdateScrollIndicator(list)
    local targetList = list or self.list
    local listControl = targetList and targetList.control
    if not (listControl and BETTERUI.CIM and BETTERUI.CIM.ScrollIndicator) then
        return
    end

    local currentIndex = targetList.targetSelectedIndex
        or (targetList.GetSelectedIndex and targetList:GetSelectedIndex())
        or 1
    local totalItems = (targetList.GetNumItems and targetList:GetNumItems())
        or (targetList.dataList and #targetList.dataList)
        or 0

    BETTERUI.CIM.ScrollIndicator.Update(listControl, currentIndex, totalItems, 12)
end
