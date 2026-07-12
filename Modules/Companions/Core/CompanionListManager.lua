if not BETTERUI.Companions or not BETTERUI.Companions.Class then return end

local Companions = BETTERUI.Companions

-- Shared companion keybind-group wrapper, owned by CompanionsRuntime (BUI-CONS-010).
local WrapCompanionHeaderKeybindGroup = Companions.WrapKeybindGroup
    or function(group) return group end

local function QueueCompanionNarration()
    local narration = BETTERUI.CIM and BETTERUI.CIM.Narration
    local queueSceneNarration = narration and narration.QueueSceneNarration
    if type(queueSceneNarration) == "function" then
        queueSceneNarration(BETTERUI_COMPANION_EQUIP_SCENE_NAME)
    end
end

local function IsDirectionalInputListening(obj)
    if not obj or not (DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.IsListening) then
        return false
    end
    return DIRECTIONAL_INPUT:IsListening(obj)
end

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

local function ReleaseHeaderDirectionalInput(header, errors)
    if not header then return end
    local boundary = Companions.GetBoundary()
    local candidates = {
        header.headerFocus,
        header.tabBar,
        header.tabBar and header.tabBar.control,
    }
    for _, candidate in ipairs(candidates) do
        if candidate then
            local candidateLabel = candidate == header.headerFocus and "headerFocus" or candidate == header.tabBar and "tabBar" or "tabBarControl"
            local ok, err = boundary.ExecuteBoundary("Companions.ForceReleaseDirectionalInput." .. candidateLabel .. ".Deactivate", function()
                if candidate.Deactivate and (not candidate.IsActive or candidate:IsActive()) then
                    candidate:Deactivate()
                end
            end)
            if not ok and errors then
                errors[#errors + 1] = boundary.WrapError(candidateLabel, err)
            end

            ok, err = boundary.ExecuteBoundary("Companions.ForceReleaseDirectionalInput." .. candidateLabel .. ".ReleaseRegistrations", function()
                ReleaseDirectionalInputRegistrations(candidate, true)
            end)
            if not ok and errors then
                errors[#errors + 1] = boundary.WrapError(candidateLabel, err)
            end
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
        -- List is inactive here. The method must NOT be called while inactive:
        -- ZO_ParametricScrollList:SetDirectionalInputEnabled(true) registers with
        -- DIRECTIONAL_INPUT immediately (regardless of active state), and the
        -- Activate() below would register a second time — DirectionalInput keeps
        -- duplicate entries and Deactivate removes only one. Write the flag
        -- directly so Activate() performs the only registration.
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
        key = "equipped",
        nameStringId = SI_BETTERUI_INV_ITEM_EQUIPPED,
        filterType = -1, -- custom handled in DoesSlotMatchFilterType
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_equipped.dds",
    },
    {
        key = "junk",
        nameStringId = SI_BETTERUI_INV_ITEM_JUNK,
        filterType = -2, -- custom
        iconFile = "esoui/art/inventory/inventory_tabicon_junk_up.dds",
    },
    {
        key = "stolen",
        nameStringId = SI_BETTERUI_INV_ITEM_STOLEN,
        filterType = -3, -- custom
        iconFile = "EsoUI/Art/Inventory/Gamepad/gp_inventory_icon_stolenitem.dds",
    },
}

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

---@param bagId number
---@param slotIndex number
---@param filterType number|nil
---@return boolean matches
---@return table|nil slotData Slot data generated for the filter check, returned
--- so callers in the same refresh pass can reuse it instead of regenerating it
--- (never cache it across inventory updates).
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
            return ZO_InventoryUtils_DoesNewItemMatchFilterType(slotData, filterType), slotData
        end
    end

    if GetItemFilterTypeInfo then
        return GetItemFilterTypeInfo(bagId, slotIndex) == filterType
    end

    if BETTERUI.Log then BETTERUI.Log.Warn(BETTERUI.Log.CATEGORY.LIST, "companion filter fallback: over-including") end
    return true
end

function BETTERUI.Companions.Class:GetCurrentCategory()
    local categories = self.companionCategories or {}
    if #categories == 0 then
        return nil
    end

    local index = zo_clamp(self.currentCategoryIndex or 1, 1, #categories)
    return categories[index]
end

function BETTERUI.Companions.Class:InitializeCategoryHeader()
    self.headerGeneric = (self.header and self.header:GetNamedChild("Header")) or self.header
    if not self.headerGeneric then
        return
    end

    BETTERUI.GenericHeader.Initialize(self.headerGeneric, ZO_GAMEPAD_HEADER_TABBAR_CREATE)
    self.currentCategoryIndex = self.currentCategoryIndex or 1
end

-- Category header title: the current category name, or the module title for the
-- "all" category / no selection. Single source for RefreshCategoryTitle and the
-- RebuildCategoryHeader titleText closure (BUI-CONS-010).
local function ComputeCategoryTitle(instance)
    local cat = instance:GetCurrentCategory()
    if cat and cat.name and cat.key ~= "all" then
        return zo_strformat("<<1>>", cat.name)
    end
    return GetString(rawget(_G, "SI_BETTERUI_COMPANIONS_TITLE") or "SI_BETTERUI_COMPANIONS_TITLE")
end

function BETTERUI.Companions.Class:RefreshCategoryTitle()
    if not self.headerGeneric then return end
    local titleText = ComputeCategoryTitle(self)
    if BETTERUI.GenericHeader and BETTERUI.GenericHeader.SetTitleText then
        BETTERUI.GenericHeader.SetTitleText(self.headerGeneric, titleText)
    end
end

--- Captures the per-slot data each category filter needs, so a slot is only
--- queried once per refresh instead of once per category.
local function BuildSlotFilterFacts(bagId, slotIndex)
    local facts = {
        bagId = bagId,
        isJunk = (IsItemJunk and IsItemJunk(bagId, slotIndex)) == true,
        isStolen = (IsItemStolen and IsItemStolen(bagId, slotIndex)) == true,
        slotData = nil,
        firstFilterType = nil,
    }
    if SHARED_INVENTORY and SHARED_INVENTORY.GenerateSingleSlotData and ZO_InventoryUtils_DoesNewItemMatchFilterType then
        facts.slotData = SHARED_INVENTORY:GenerateSingleSlotData(bagId, slotIndex)
    end
    if not facts.slotData and GetItemFilterTypeInfo then
        facts.firstFilterType = GetItemFilterTypeInfo(bagId, slotIndex)
    end
    return facts
end

--- Cached-data twin of Class:DoesSlotMatchFilterType. Keep the filter
--- semantics of both functions in sync.
local function DoesCachedSlotMatchFilterType(facts, filterType)
    if not filterType then
        return true
    end
    if filterType == -1 then -- Equipped
        return facts.bagId == BAG_COMPANION_WORN
    end
    if filterType == -2 then -- Junk
        return facts.isJunk
    end
    if filterType == -3 then -- Stolen
        return facts.isStolen
    end
    if facts.slotData then
        return ZO_InventoryUtils_DoesNewItemMatchFilterType(facts.slotData, filterType)
    end
    if facts.firstFilterType ~= nil then
        return facts.firstFilterType == filterType
    end
    return true
end

function BETTERUI.Companions.Class:RefreshCategories()
    local previousCategory = self:GetCurrentCategory()
    local previousKey = previousCategory and previousCategory.key
    local visibleCategories = {}

    -- Single pass over the companion items: build per-slot facts once, then
    -- count every category for that slot (was O(categories x slots) with a
    -- GenerateSingleSlotData call per pair).
    local countsByKey = {}
    for _, def in ipairs(CATEGORY_DEFINITIONS) do
        countsByKey[def.key] = 0
    end
    ForEachCompanionItem(function(bagId, slotIndex)
        local facts = BuildSlotFilterFacts(bagId, slotIndex)
        for _, def in ipairs(CATEGORY_DEFINITIONS) do
            if DoesCachedSlotMatchFilterType(facts, def.filterType) then
                countsByKey[def.key] = countsByKey[def.key] + 1
            end
        end
    end)

    for _, def in ipairs(CATEGORY_DEFINITIONS) do
        local count = countsByKey[def.key]
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

    local newCategory = visibleCategories[selectedIndex]
    local newKey = newCategory and newCategory.key
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.CATEGORY, "companion categories built", {
            prevKey = previousKey,
            newKey = newKey,
            visibleCount = #visibleCategories,
            selectedIndex = selectedIndex,
            itemCount = newCategory and newCategory.itemCount or nil,
        })
    end

    self:RebuildCategoryHeader()
end

function BETTERUI.Companions.Class:RebuildCategoryHeader()
    local headerGeneric = self.headerGeneric
    local categories = self.companionCategories or {}
    if not headerGeneric or #categories == 0 then
        return
    end

    self.companionHeaderData = self.companionHeaderData or {}
    self.companionHeaderData.titleText = function()
        return ComputeCategoryTitle(self)
    end
    self.companionHeaderData.tabBarData = { parent = self, onNext = function(_, successful) if successful then self:OnTabNext() end end, onPrev = function(_, successful) if successful then self:OnTabPrev() end end }
    local isCarousel = (not Companions.GetSetting) or (Companions.GetSetting("enableCarousel") ~= false)
    self.companionHeaderData.carouselConfig = {
        enabled = isCarousel,
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

        local outgoingCategory = self:GetCurrentCategory()
        if outgoingCategory and self.list then
            BETTERUI.CIM.PositionManager.SavePosition("Companions", outgoingCategory.key, self.list)
        end

        self.currentCategoryIndex = selectedIndex
        self:RefreshList()
        self:RefreshCategoryTitle()

        if self:IsSceneShowing() then
            if self._searchModeActive then
                self:DeactivateListInput()
                self:EnsureHeaderKeybindsActive()
            else
                self:EnsureListInputActive()
            end
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
    self:RefreshCompanionWeaponHeader()

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

function BETTERUI.Companions.Class:CycleCategory(delta)
    local categories = self.companionCategories or {}
    if #categories <= 1 then
        if BETTERUI.Log and BETTERUI.Log.IsActive() then
            BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.CATEGORY, "companion category cycle skipped", {
                reason = "notEnoughCategories",
                categoryCount = #categories,
                delta = delta,
            })
        end
        return
    end

    local previousIndex = self.currentCategoryIndex or 1
    local previousCategory = categories[previousIndex]
    local previousTarget = self.list and self.list.GetTargetData and self.list:GetTargetData() or nil
    local previousDs = previousTarget and (previousTarget.dataSource or previousTarget) or nil
    local nextIndex = previousIndex + delta
    if Companions.GetSetting and Companions.GetSetting("enableCarousel") == false then
        if nextIndex < 1 or nextIndex > #categories then
            return
        end
    elseif nextIndex > #categories then
        nextIndex = 1
    elseif nextIndex < 1 then
        nextIndex = #categories
    end

    if previousCategory and self.list then
        BETTERUI.CIM.PositionManager.SavePosition("Companions", previousCategory.key, self.list)
    end

    self.currentCategoryIndex = nextIndex
    self:RefreshList()
    self:RefreshCategoryTitle()
    if self:IsSceneShowing() then
        if self._searchModeActive then
            -- Category cycling remains available through the header carousel, but
            -- search keeps ownership of directional input and the list stays dimmed.
            self:DeactivateListInput()
            self:EnsureHeaderKeybindsActive()
        else
            self:EnsureListInputActive()
        end
        self:UpdateItemTooltips(self.list and self.list:GetTargetData())
    end

    local tabBar = self.headerGeneric and self.headerGeneric.tabBar
    if tabBar then
        self._suppressCompanionHeaderSelection = true
        tabBar:SetSelectedIndexWithoutAnimation(nextIndex, true, true)
        self._suppressCompanionHeaderSelection = false
    end
    local nextCategory = categories[nextIndex]
    local nextTarget = self.list and self.list.GetTargetData and self.list:GetTargetData() or nil
    local nextDs = nextTarget and (nextTarget.dataSource or nextTarget) or nil
    if BETTERUI.Log and BETTERUI.Log.IsActive() then
        BETTERUI.Log.Trace(BETTERUI.Log.CATEGORY.CATEGORY, "companion category cycled", {
            delta = delta,
            previousIndex = previousIndex,
            nextIndex = nextIndex,
            previousKey = previousCategory and previousCategory.key or nil,
            nextKey = nextCategory and nextCategory.key or nil,
            categoryCount = #categories,
            selectedBagIdBefore = previousDs and previousDs.bagId or nil,
            selectedSlotIndexBefore = previousDs and previousDs.slotIndex or nil,
            selectedBagIdAfter = nextDs and nextDs.bagId or nil,
            selectedSlotIndexAfter = nextDs and nextDs.slotIndex or nil,
        })
    end
end

function BETTERUI.Companions.Class:OnTabNext()
    self:CycleCategory(1)
end

function BETTERUI.Companions.Class:OnTabPrev()
    self:CycleCategory(-1)
end

function BETTERUI.Companions.Class:EnsureHeaderKeybindsActive(forceReactivate)
    local tabBar = self.headerGeneric and self.headerGeneric.tabBar
    if not tabBar then
        return
    end

    if self.scene and not self.scene:IsShowing() then
        return
    end

    local carouselMissing = tabBar.keybindStripDescriptor
        and not BETTERUI.Interface.HasKeybindGroup(tabBar.keybindStripDescriptor)
    if tabBar.active and (carouselMissing or forceReactivate) and tabBar.Deactivate then
        -- A focus-loss callback can leave the visual active flag set after the
        -- keybind group was removed. Search clear can also leave the registered
        -- group stale even though it still appears present. Reset the carousel
        -- before reactivation in either case.
        tabBar:Deactivate()
    end
    if tabBar.Activate and (not tabBar.active or carouselMissing) then
        tabBar:Activate()
    end

    if tabBar.keybindStripDescriptor then
        WrapCompanionHeaderKeybindGroup(tabBar.keybindStripDescriptor)
        BETTERUI.Interface.EnsureKeybindGroupAdded(tabBar.keybindStripDescriptor)
    end
end

function BETTERUI.Companions.Class:DeactivateHeaderKeybinds()
    local tabBar = self.headerGeneric and self.headerGeneric.tabBar
    if not tabBar then return end
    if tabBar.keybindStripDescriptor and KEYBIND_STRIP then
        BETTERUI.Interface.RemoveKeybindGroupIfPresent(tabBar.keybindStripDescriptor)
    end
    if tabBar.Deactivate and tabBar.active then
        tabBar:Deactivate()
    end
end

function BETTERUI.Companions.Class:PositionSearchControl()
    if not self.textSearchHeaderControl then return end

    -- Shared anchoring lives in CIM SearchManager (loaded before this module).
    BETTERUI.Interface.PositionSearchControl(self, {
        preset = "INVENTORY",
        headerOnly = false,
        titleChildNames = { "TitleContainer", "Header", "HeaderContainer", "HeaderTitle", "HeaderBar", "ContainerHeader" },
        safeExecuteContext = "Companions.search.anchor",
    })
end

function BETTERUI.Companions.Class:EnsureColumnHeadersVisible()
    if not (self.header and self.header.columns) then return end
    for _, label in ipairs(self.header.columns) do
        if label then
            label:SetHidden(false)
            label:SetAlpha(1)
        end
    end
end

function BETTERUI.Companions.Class:EnsureListInputActive()
    local list = self.list
    if not list then
        return
    end

    if self.scene and not self.scene:IsShowing() then
        return
    end

    -- Clear only duplicate registrations; a single registration is the expected steady-state.
    local listRegistrationCount = CountDirectionalInputRegistrations(list)
    if listRegistrationCount > 1 then
        ReleaseDirectionalInputRegistrations(list, true)
        listRegistrationCount = 0
    end

    EnsureListDirectionalInputRegistration(list, listRegistrationCount)
end

function BETTERUI.Companions.Class:DeactivateListInput()
    local list = self.list
    ReleaseListDirectionalInput(list)
end

function BETTERUI.Companions.Class:ForceReleaseDirectionalInput()
    if not (DIRECTIONAL_INPUT and DIRECTIONAL_INPUT.IsListening and DIRECTIONAL_INPUT.Deactivate) then
        return true
    end

    local errors = {}
    local boundary = Companions.GetBoundary()

    local function SafeDeactivate(context, obj, includeMovementController, disableDirectionalInput)
        if not obj then return end
        if disableDirectionalInput and obj.SetDirectionalInputEnabled then
            obj:SetDirectionalInputEnabled(false)
        end
        local ok, err = boundary.ExecuteBoundary("Companions.ForceReleaseDirectionalInput." .. context .. ".Deactivate", function()
            if obj.Deactivate and (not obj.IsActive or obj:IsActive() or IsDirectionalInputListening(obj)) then
                obj:Deactivate()
            end
        end)
        if not ok then
            errors[#errors + 1] = boundary.WrapError(context, err)
        end

        ok, err = boundary.ExecuteBoundary("Companions.ForceReleaseDirectionalInput." .. context .. ".ReleaseRegistrations", function()
            ReleaseDirectionalInputRegistrations(obj, includeMovementController)
        end)
        if not ok then
            errors[#errors + 1] = boundary.WrapError(context, err)
        end
    end

    SafeDeactivate("self", self, true)
    SafeDeactivate("list", self.list, true, true)
    SafeDeactivate("searchDirectionalInput", self._companionSearchDirectionalInputObject, true)
    ReleaseHeaderDirectionalInput(self.headerGeneric, errors)
    ReleaseHeaderDirectionalInput(self.header, errors)
    SafeDeactivate("textSearchHeaderFocus", self.textSearchHeaderFocus, true)
    SafeDeactivate("textSearchHeaderControl", self.textSearchHeaderControl, true)

    if #errors > 0 then
        return false, boundary.WrapError("ForceReleaseDirectionalInput", table.concat(errors, "; "))
    end

    return true
end

function BETTERUI.Companions.Class:InitializeListPresentation()
    if not self.list then
        return
    end

    if self.list.SetFixedCenterOffset then
        self.list:SetFixedCenterOffset(-50)
    end

    self.list.maxOffset = 30

    local headerPaddingScale = 0.75
    if self.list.SetHeaderPadding and GAMEPAD_HEADER_DEFAULT_PADDING and GAMEPAD_HEADER_SELECTED_PADDING then
        self.list:SetHeaderPadding(
            GAMEPAD_HEADER_DEFAULT_PADDING * headerPaddingScale,
            GAMEPAD_HEADER_SELECTED_PADDING * headerPaddingScale
        )
    end
    if self.list.SetUniversalPostPadding and GAMEPAD_DEFAULT_POST_PADDING then
        self.list:SetUniversalPostPadding(GAMEPAD_DEFAULT_POST_PADDING * headerPaddingScale)
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
                self:PrepareNextClearNewStatus(selectedData)
                if selectedData then
                    QueueCompanionNarration()
                end
                if self.coreKeybinds then
                    BETTERUI.Interface.UpdateKeybindGroup(self.coreKeybinds)
                end
            end
            self:UpdateScrollIndicator(list)
        end)
    end

    if self.list.control and BETTERUI.CIM and BETTERUI.CIM.ScrollIndicator then
        BETTERUI.CIM.ScrollIndicator.Setup(self.list.control, {
            listObject = self.list,
            offsetX = 25,
            offsetTopY = -5,
            offsetBottomY = -10,
            visibleItems = BETTERUI.CIM.CONST.UI.BANKING_VISIBLE_ITEMS or 10,
        })
    end
end

function BETTERUI.Companions.Class:UpdateScrollIndicator(list)
    local targetList = list or self.list
    local listControl = targetList and targetList.control
    if not (listControl and BETTERUI.CIM and BETTERUI.CIM.ScrollIndicator) then
        return
    end

    BETTERUI.CIM.ScrollIndicator.Update(listControl)
end
