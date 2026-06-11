--[[
File: Modules/Inventory/Core/InventoryClass.lua
Purpose: Defines the primary BETTERUI.Inventory.Class structure, initialization logic,
         header management, and high-level caching mechanisms.
]]

-- Architecture Note: BetterUI.Inventory subclasses ZO_GamepadInventory directly to:
-- 1. Leverage ESO's proven inventory management foundation and slot handling
-- 2. Override specific behaviors while maintaining API compatibility with addons
-- 3. Access protected members without re-implementing base functionality
-- Banking uses BETTERUI.Interface.Window (ZO_Object) because it requires more
-- control over the scene lifecycle. This is intentional based on module needs.
-- See: docs/ARCHITECTURE.md for inheritance diagram
--- @class BetterUI_InventoryClass : ZO_GamepadInventory
--- @field itemList table Scroll list for backpack items
--- @field craftBagList table Scroll list for craft bag items
--- @field categoryList table Scroll list for category tabs
--- @field header table Header UI control
--- @field scene table ZO_Scene instance
--- @field currentlySelectedData table|nil Currently selected entry data
--- @field isInHeaderSortMode boolean Whether header sort mode is active
--- @field headerSortControllers table<string, table> Per-list sort controllers
--- @field searchQuery string|nil Active search query
--- @field mainKeybindStripDescriptor table Keybind strip descriptor
BETTERUI.Inventory.Class = ZO_GamepadInventory:Subclass()

-- Constants
-- Scene Name Override: We replace ZO_GAMEPAD_INVENTORY_SCENE_NAME to ensure
-- BetterUI's inventory scene is registered instead of the vanilla one. This must
-- happen before any scene registration to avoid dual-scene conflicts. While modifying
-- ZOS globals is generally fragile, this is required because the engine uses this
-- global to find inventory scenes. Alternative approaches (scene name aliasing) were
-- tested in v2.x and caused more issues than this direct override.
ZO_GAMEPAD_INVENTORY_SCENE_NAME = "gamepad_inventory_root"

-- Validated Globals for Core
-- GAMEPAD_INVENTORY_ROOT_SCENE must be global because Module.lua needs to add fragments to it

-- List type identifiers sourced from BETTERUI.Inventory.CONST.LIST_TYPES (see Inventory/Constants.lua)
-- The global aliases (INVENTORY_CATEGORY_LIST, etc.) are created there for backward compatibility.

-- Module-specific TaskManager for managed deferred tasks (Phase 1.1)
-- Using module-specific instance prevents ID collisions with other modules
local InventoryDeferredTask = assert(BETTERUI.CIM and BETTERUI.CIM.DeferredTask,
    "BetterUI: CIM.DeferredTask must load before Inventory/Core/InventoryClass")
local function EnsureInventoryTaskManager()
    if not BETTERUI.Inventory._taskManager then
        BETTERUI.Inventory._taskManager = InventoryDeferredTask.CreateManager()
    end
    return BETTERUI.Inventory._taskManager
end
BETTERUI.Inventory.EnsureTaskManager = EnsureInventoryTaskManager
BETTERUI.Inventory.Tasks = BETTERUI.Inventory.Tasks or InventoryDeferredTask.CreateLazyManagerProxy(EnsureInventoryTaskManager)


-- CACHING & DATA MANAGEMENT

--- @type table<string|number, table>
local g_slotDataCache = {}
--- @type boolean
local g_slotDataCacheDirty = true

--- Invalidates the slot data cache.
function BETTERUI.Inventory.Class:InvalidateSlotDataCache()
    g_slotDataCacheDirty = true
    g_slotDataCache = {}
end

-- Per-item cached fields written directly onto slot data tables. List rows
-- write them onto SHARED_INVENTORY's persistent bag-cache tables, so they are
-- cleared alongside the meta cache: market unit price changes with vendor/MM
-- data, recipe/book/trait knowledge flips on learn events, and the
-- identity-bound link/type/set/enchant/trait fields go stale when a slot's
-- item changes.
local META_CACHED_ITEM_FIELDS = {
    "cached_marketUnitPrice",
    "cached_isRecipeAndUnknown",
    "cached_isBook",
    "cached_isBookKnown",
    "cached_isBookAndUnknown",
    "cached_isTraitResearchable",
    "cached_isUnbound",
    "cached_itemLink",
    "cached_itemType",
    "cached_setItem",
    "cached_hasEnchantment",
    "cached_traitName",
}

local function ClearCachedItemFields(slotData)
    for i = 1, #META_CACHED_ITEM_FIELDS do
        slotData[META_CACHED_ITEM_FIELDS[i]] = nil
    end
end

--- Clears cached per-item fields on SHARED_INVENTORY's live bag-cache slot
--- tables. Those tables persist across inventory updates, so the clear must
--- happen there and must not depend on the local g_slotDataCache snapshot.
---@param bagId number Bag ID
---@param slotIndex number|nil Slot index, or nil for the whole bag
local function ClearSharedBagCachedItemFields(bagId, slotIndex)
    if not (SHARED_INVENTORY and SHARED_INVENTORY.GetBagCache) then
        return
    end
    local bagCache = SHARED_INVENTORY:GetBagCache(bagId)
    if not bagCache then
        return
    end
    if slotIndex ~= nil then
        local slotData = bagCache[slotIndex]
        if slotData then
            ClearCachedItemFields(slotData)
        end
    else
        for _, slotData in pairs(bagCache) do
            ClearCachedItemFields(slotData)
        end
    end
end

--- Invalidates cached item metadata for a specific bag/slot.
--- @param bagId number|nil Bag ID, or nil to clear all
--- @param slotIndex number|nil Slot index, or nil to clear entire bag
function BETTERUI.Inventory.Class:InvalidateItemMeta(bagId, slotIndex)
    -- Clear on the live shared bag caches so visible rows cannot keep serving
    -- stale knowledge/price state. This is deliberately independent of
    -- g_slotDataCache: InvalidateSlotDataCache() empties that snapshot on
    -- every inventory update, which would make a snapshot-only clear a no-op
    -- during recipe/style-learn bursts while the persistent shared slot
    -- tables keep their stale cached_* fields.
    if bagId ~= nil then
        ClearSharedBagCachedItemFields(bagId, slotIndex)
    else
        ClearSharedBagCachedItemFields(BAG_BACKPACK, slotIndex)
        ClearSharedBagCachedItemFields(BAG_WORN, slotIndex)
    end

    -- Also clear matching entries in the local snapshot while it is populated;
    -- it normally references the same shared tables, but this covers snapshot
    -- entries whose bag has no live shared cache.
    for _, slotEntries in pairs(g_slotDataCache) do
        for i = 1, #slotEntries do
            local slotData = slotEntries[i]
            if slotData
                and (bagId == nil or slotData.bagId == bagId)
                and (slotIndex == nil or slotData.slotIndex == slotIndex) then
                ClearCachedItemFields(slotData)
            end
        end
    end
end

--- Gets cached slot data for the specified bags.
--- All internal call sites pass one or two bag IDs, so fixed parameters avoid
--- per-call vararg table allocation and sorting in this hot accessor.
--- @param bagId number Bag ID (BAG_BACKPACK, BAG_WORN, etc.)
--- @param secondBagId number|nil Optional second bag ID
--- @return table slotData Array of slot data entries
function BETTERUI.Inventory.Class:GetCachedSlotData(bagId, secondBagId)
    -- Normalize bag order so (a, b) and (b, a) share one cache entry.
    if secondBagId ~= nil and secondBagId < bagId then
        bagId, secondBagId = secondBagId, bagId
    end

    -- Single-bag keys are the bag ID itself; bag-pair keys pack both IDs into
    -- one number. Bag IDs are small enum values (far below 100000), and the
    -- +1 offset keeps BAG_WORN (0) pairs from colliding with single-bag keys.
    local cacheKey
    if secondBagId == nil then
        cacheKey = bagId
    else
        cacheKey = (bagId + 1) * 100000 + secondBagId
    end

    if g_slotDataCacheDirty then
        g_slotDataCache = {}
        g_slotDataCacheDirty = false
    end

    if not g_slotDataCache[cacheKey] then
        if SHARED_INVENTORY and SHARED_INVENTORY.GenerateFullSlotData then
            -- Fetch ALL items (no filter) for these bags to populate the cache
            if secondBagId == nil then
                g_slotDataCache[cacheKey] = SHARED_INVENTORY:GenerateFullSlotData(nil, bagId)
            else
                g_slotDataCache[cacheKey] = SHARED_INVENTORY:GenerateFullSlotData(nil, bagId, secondBagId)
            end
        else
            g_slotDataCache[cacheKey] = {}
        end
    end

    return g_slotDataCache[cacheKey]
end

-- KEYBIND MANAGEMENT (Override ESO Base Class)

--[[
Function: RefreshKeybinds (Override)
Guards keybind refresh against header sort mode.
ESO's ZO_Gamepad_ParametricList_Screen:CreateAndSetupList wraps the list's
OnSelectedDataChangedCallback with a call to self:RefreshKeybinds(). This
bypasses all our guards on individual RefreshKeybinds calls because ESO's
base class is calling RefreshKeybinds directly. By overriding the function
itself, we intercept ALL refresh calls - both from our code and ESO's base class.
References: Called by ESO base class in selection callbacks.
]]
--- Refreshes the keybind strip (override with guards).
function BETTERUI.Inventory.Class:RefreshKeybinds()
    -- Guard: Skip keybind refresh if in header sort mode to preserve header keybinds
    -- This is the critical fix for the "A-Button Burn" issue - ESO's base class calls
    -- RefreshKeybinds on every selection change, which was overwriting our header keybinds
    if self.isInHeaderSortMode then
        return
    end
    -- Guard: Skip keybind refresh during batch processing to prevent flickering
    if self:IsBatchProcessing() then
        return
    end
    local nowMs = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
    local inPrimaryActionTransition = self._primaryActionTransitionExpiresMs
        and nowMs <= self._primaryActionTransitionExpiresMs

    -- During short action transitions (especially equip/unequip), avoid full
    -- strip rebuild churn and only update labels/visibility in-place.
    -- Do not coalesce transition-frame updates: the first refresh can happen
    -- before list reselection settles, and the later same-frame refresh is what
    -- corrects stale/blank A-button labels without waiting for another input.
    if inPrimaryActionTransition then
        if self.mainKeybindStripDescriptor and KEYBIND_STRIP then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(self.mainKeybindStripDescriptor)
        end
        return
    end

    -- Update our own keybind group directly instead of calling the parent
    -- ZO_GamepadInventory.RefreshKeybinds updates ESO's base keybindStripDescriptor,
    -- which may not be the active group. BetterUI uses mainKeybindStripDescriptor
    -- set via SetActiveKeybinds, so we update that directly.
    if self.mainKeybindStripDescriptor and KEYBIND_STRIP then
        KEYBIND_STRIP:UpdateKeybindButtonGroup(self.mainKeybindStripDescriptor)
    end
end


--[[
Function: SetSelectedInventoryData (Override)
Guards itemActions:SetInventorySlot against header sort mode.
ESO's ZO_ItemSlotActionsController:SetInventorySlot calls RefreshKeybindStrip()
which DIRECTLY manipulates KEYBIND_STRIP (Add/Update/Remove). This bypasses our
RefreshKeybinds override. By guarding at the SetSelectedInventoryData level,
we prevent itemActions from updating keybinds during header sort mode.
References: Called on every selection change via selection callbacks.
]]
--- Sets the selected inventory data (override with guards).
function BETTERUI.Inventory.Class:SetSelectedInventoryData(inventoryData)
    local nowMs = GetFrameTimeMilliseconds and GetFrameTimeMilliseconds() or 0
    local inPrimaryActionTransition = self._primaryActionTransitionExpiresMs
        and nowMs <= self._primaryActionTransitionExpiresMs
    local dataSource = inventoryData and (inventoryData.dataSource or inventoryData) or nil
    local uniqueId = dataSource and dataSource.uniqueId
    local uniqueIdString = uniqueId and ((Id64ToString and Id64ToString(uniqueId)) or tostring(uniqueId)) or ""
    local selectionFingerprint = string.format(
        "%s|%s|%s|%s",
        uniqueIdString,
        tostring(dataSource and dataSource.bagId or ""),
        tostring(dataSource and dataSource.slotIndex or ""),
        tostring(dataSource and dataSource.slotType or "")
    )

    -- Skip itemActions keybind updates when in header sort mode
    -- This is the REAL fix for the "A-Button Burn" flicker - itemActions:SetInventorySlot
    -- calls RefreshKeybindStrip() which directly manipulates KEYBIND_STRIP, bypassing
    -- our RefreshKeybinds override
    if self.isInHeaderSortMode then
        -- Only update uniqueId tracking, skip itemActions entirely
        self:SetSelectedItemUniqueId(inventoryData)
        return
    end

    -- ESO can issue multiple SetSelectedInventoryData calls in the same frame for the
    -- same row during list rebuild + selection callback chains. Coalesce these duplicates
    -- so itemActions doesn't churn KEYBIND_STRIP with identical remove/re-add cycles.
    local previousFingerprint = self._lastSetSelectedInventoryDataFingerprint
    if self._lastSetSelectedInventoryDataFrame == nowMs
        and previousFingerprint == selectionFingerprint then
        self:SetSelectedItemUniqueId(inventoryData)
        return
    end
    self._lastSetSelectedInventoryDataFrame = nowMs
    self._lastSetSelectedInventoryDataFingerprint = selectionFingerprint

    -- Clear the primary action transition when the selection changes to a different
    -- item. The transition name is specific to the item that started the action and
    -- must not bleed to a newly-selected item's label (e.g., "Use" appearing for a
    -- non-consumable, or "Mark as Junk" showing on the next item after junk removal).
    if self._primaryActionTransitionExpiresMs and previousFingerprint
        and previousFingerprint ~= selectionFingerprint then
        self._primaryActionTransitionExpiresMs = nil
        self._primaryActionTransitionName = nil
        self._lastSecondaryActionName = nil
    end

    -- During short post-action windows, selection can transiently be nil while the
    -- item list is rebuilding. Avoid clearing itemActions in that transient state
    -- because it drops the A keybind and causes a visible remove/re-add flash.
    if inPrimaryActionTransition and inventoryData == nil then
        self:SetSelectedItemUniqueId(inventoryData)
        return
    end

    -- Call parent implementation (includes itemActions:SetInventorySlot)
    ZO_GamepadInventory.SetSelectedInventoryData(self, inventoryData)
end

--[[
Function: RestoreStateAfterDialog
Description: Rebuilds inventory keybind/list state after dialog transitions.
Rationale: Dialog stack transitions can temporarily leave keybind visibility and
           action data stale until another selection-change event occurs.
Mechanism: Waits until dialogs fully close, then restores active keybinds,
           refreshes item actions, and refreshes keybind strip.
param: taskName (string|nil) - Optional task identifier prefix for retries.
]]
function BETTERUI.Inventory.Class:RestoreStateAfterDialog(taskName)
    local retriesRemaining = 120
    local retryTaskName = (taskName or "inventoryDialogRestore")
        .. "_"
        .. tostring((GetGameTimeMilliseconds and GetGameTimeMilliseconds()) or 0)

    local function TryRestore()
        if ZO_Dialogs_IsShowingDialog and ZO_Dialogs_IsShowingDialog() then
            return false
        end

        local sceneShowing = (self.scene and self.scene:IsShowing())
            or (BETTERUI.CIM and BETTERUI.CIM.Utils
                and BETTERUI.CIM.Utils.IsInventorySceneShowing
                and BETTERUI.CIM.Utils.IsInventorySceneShowing())
        if not sceneShowing then
            return false
        end

        if not self.isInHeaderSortMode and self.SetActiveKeybinds and self.mainKeybindStripDescriptor then
            self:SetActiveKeybinds(self.mainKeybindStripDescriptor)
        end

        -- Preserve selection visuals while in multi-select mode.
        if self.isInCraftBagSelectionMode and self.RefreshCraftBagList then
            self:RefreshCraftBagList()
        elseif self.isInSelectionMode and self.RefreshItemList then
            self:RefreshItemList()
        end

        local selectedData = nil
        local selectedList = nil
        if self.actionMode == BETTERUI.Inventory.CONST.CRAFT_BAG_ACTION_MODE then
            selectedList = self.craftBagList
            selectedData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.craftBagList)
        elseif self.actionMode == BETTERUI.Inventory.CONST.ITEM_LIST_ACTION_MODE then
            selectedList = self.itemList
            selectedData = BETTERUI.Inventory.Utils.SafeGetTargetData(self.itemList)
        elseif self.actionMode == BETTERUI.Inventory.CONST.CATEGORY_ITEM_ACTION_MODE then
            selectedList = self:GetCurrentList()
            selectedData = selectedList and BETTERUI.Inventory.Utils.SafeGetTargetData(selectedList)
            if selectedData and selectedList == self.categoryList then
                selectedData = self:GenerateItemSlotData(selectedData)
            end
        end

        if selectedList and not selectedData then
            local innerList = selectedList.list or selectedList
            local dataList = innerList and innerList.dataList
            if dataList and #dataList > 0 then
                local selectedIndex
                if innerList.GetSelectedIndex then
                    selectedIndex = innerList:GetSelectedIndex()
                else
                    selectedIndex = innerList.selectedIndex
                end
                if type(selectedIndex) ~= "number" or selectedIndex < 1 or selectedIndex > #dataList then
                    selectedIndex = self._preserveIndex or 1
                end
                selectedIndex = zo_clamp(selectedIndex, 1, #dataList)

                if innerList.SetSelectedIndexWithoutAnimation then
                    innerList:SetSelectedIndexWithoutAnimation(selectedIndex, true, false)
                elseif selectedList.SetSelectedIndexWithoutAnimation then
                    selectedList:SetSelectedIndexWithoutAnimation(selectedIndex, true, false)
                end
                selectedData = BETTERUI.Inventory.Utils.SafeGetTargetData(selectedList)
            end
        end

        if selectedData and self.SetSelectedInventoryData then
            self:SetSelectedInventoryData(selectedData)
        end

        if self.RefreshItemActions then
            self:RefreshItemActions()
        end

        if not self.isInHeaderSortMode and self.RefreshKeybinds then
            self:RefreshKeybinds()
        end

        -- Dialogs deactivate the header tab bar; reactivate it so LB/RB keep
        -- paging the category carousel after the dialog closes.
        if not self.isInHeaderSortMode and self.EnsureHeaderKeybindsActive then
            self:EnsureHeaderKeybindsActive()
        end

        if selectedList and selectedList.IsEmpty and not selectedData and not selectedList:IsEmpty() then
            return false
        end

        return true
    end

    if TryRestore() then
        return true
    end

    local function RetryRestore()
        if TryRestore() then
            return
        end

        retriesRemaining = retriesRemaining - 1
        if retriesRemaining <= 0 then
            return
        end

        if BETTERUI.Inventory.Tasks and BETTERUI.Inventory.Tasks.Schedule then
            BETTERUI.Inventory.Tasks:Schedule(retryTaskName, 50, RetryRestore)
        else
            zo_callLater(RetryRestore, 50)
        end
    end

    RetryRestore()
    return false
end

--------------------------------------------------------------------------------
-- INITIALIZATION


--- Initializes the Inventory object.
--- Sets up the root scene, registers update loops, and hooks into visual layer changes.
--- References: Called by Module.lua.
function BETTERUI.Inventory.Class:Initialize(control)
    BETTERUI.Inventory.NativeGlobals = BETTERUI.Inventory.NativeGlobals or {}
    local native = BETTERUI.Inventory.NativeGlobals
    if native.gamepadInventoryRootScene == nil then
        native.gamepadInventoryRootScene = GAMEPAD_INVENTORY_ROOT_SCENE
    end
    -- Never replace the inventory root scene object. Secure engine flows (book/tome,
    -- direct-purchase catalog, etc.) assume the native scene chain is preserved.
    local inventoryRootScene = native.gamepadInventoryRootScene or GAMEPAD_INVENTORY_ROOT_SCENE
    if inventoryRootScene then
        GAMEPAD_INVENTORY_ROOT_SCENE = inventoryRootScene
    end
    -- Use UnifiedScreen initialization with CURRENCY footer mode
    BETTERUI.CIM.UnifiedScreen.Initialize(
        self,
        control,
        ZO_GAMEPAD_HEADER_TABBAR_CREATE,
        false,
        inventoryRootScene,
        BETTERUI.CIM.UnifiedScreen.FOOTER_MODE_CURRENCY
    )

    if BETTERUI.Inventory.InitializeSecureWheelHooks then
        BETTERUI.Inventory.InitializeSecureWheelHooks()
    end

    self:InitializeSplitStackDialog()

    -- Guard update loop so we only process while the inventory scene is visible.
    local function OnUpdate(updateControl, currentFrameTimeSeconds)
        if self.scene and self.scene:IsShowing() then
            self:OnUpdate(currentFrameTimeSeconds)
        end
    end

    self.trySetClearNewFlagCallback = function(callId)
        self:TrySetClearNewFlag(callId)
    end

    local function RefreshVisualLayer()
        if self.scene:IsShowing() then
            self:OnUpdate()
            if self.actionMode == BETTERUI.Inventory.CONST.CATEGORY_ITEM_ACTION_MODE then
                self:RefreshCategoryList()
                self:SwitchActiveList(BETTERUI.Inventory.CONST.LIST_TYPES.ITEM)
            end
        end
    end

    -- Do not intercept base destroy cancel events to avoid input blockage
    control:RegisterForEvent(EVENT_VISUAL_LAYER_CHANGED, RefreshVisualLayer)
    control:SetHandler("OnUpdate", OnUpdate)

    -- Add gamepad text search support using the shared helper
    local searchMixin = BETTERUI.Interface and BETTERUI.Interface.SearchMixin
    if searchMixin and searchMixin.AddSearch then
        self.textSearchKeybindStripDescriptor = BETTERUI.Interface.CreateSearchKeybindDescriptor(self)

        searchMixin.AddSearch(self, self.textSearchKeybindStripDescriptor, function(searchText)
            self.searchQuery = searchText
            -- When search changes, reset selection to top and refresh the active list
            self:SaveListPosition()
            -- If craft bag is currently active, refresh craft bag list so filtering is immediate
            if self:GetCurrentList() == self.craftBagList then
                self:RefreshCraftBagList()
            else
                self:RefreshItemList()
            end
        end)
        -- Use consolidated SearchFocusMixin for edit box handlers
        -- This replaces ~60 lines of duplicate code (previously duplicated in Banking.lua)
        searchMixin.SetupEditBoxHandlers(self, {
            isSceneShowing = function()
                return self.scene and self.scene:IsShowing()
            end,
            onTextChanged = function(window, txt)
                window.searchQuery = txt

                -- Only force a local refresh for the craft-bag when the engine
                -- will not perform background filtering (to avoid doubling work).
                local willEngineFilter = false
                if ZO_TextSearchManager and ZO_TextSearchManager.CanFilterByText then
                    willEngineFilter = ZO_TextSearchManager.CanFilterByText(window.searchQuery)
                end

                if window:GetCurrentList() == window.craftBagList and not willEngineFilter then
                    window:SaveListPosition()
                    window:RefreshCraftBagList()
                end
            end,
        })
    end

    -- Keybind refresh - synchronous with header mode guard
    -- Skip if in header sort mode to avoid overwriting header keybinds
    if not self.isInHeaderSortMode then
        if self.RefreshKeybinds then
            self:RefreshKeybinds()
        elseif self.mainKeybindStripDescriptor then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(self.mainKeybindStripDescriptor)
        end
    end
end

-- HELPER UTILITIES

--- Gets the equip slot for a given equip type.
function BETTERUI.Inventory.Class:GetEquipSlotForEquipType(equipType)
    -- Prefer the slot corresponding to the currently intended bar (primary/backup)
    local wantPrimary = true
    if self.isPrimaryWeapon ~= nil then
        wantPrimary = self.isPrimaryWeapon
    end

    local lastMatchingSlot = nil
    for _, testSlot in ZO_Character_EnumerateOrderedEquipSlots() do
        local locked = IsLockedWeaponSlot(testSlot)
        local isCorrectSlot = ZO_Character_DoesEquipSlotUseEquipType(testSlot, equipType)
        if not locked and isCorrectSlot then
            local isActive = IsActiveCombatRelatedEquipmentSlot(testSlot)
            if equipType == EQUIP_TYPE_MAIN_HAND
                or equipType == EQUIP_TYPE_OFF_HAND
                or equipType == EQUIP_TYPE_TWO_HAND
                or equipType == EQUIP_TYPE_POISON
            then
                if wantPrimary and isActive then
                    return testSlot
                elseif not wantPrimary and not isActive then
                    return testSlot
                end
                lastMatchingSlot = testSlot
            else
                return testSlot
            end
        end
    end
    return lastMatchingSlot
end

-- HEADER MANAGEMENT

-- REFRESH OPTIMIZATIONS

--- Checks if any items in the cached list are marked as new.
--- Optimized replacement for SHARED_INVENTORY:AreAnyItemsNew to use local cache.
--- Checks if any items in the cached list are marked as new.
function BETTERUI.Inventory.Class:AreAnyItemsNew(filterFunc, filterType, bagId)
    local items = self:GetCachedSlotData(bagId)
    if not items then return false end

    for _, itemData in ipairs(items) do
        if itemData.brandNew then
            if not filterFunc or filterFunc(itemData, filterType) then
                return true
            end
        end
    end
    return false
end

--- Refreshes the header, ensuring callbacks are preserved.
---
--- Overrides base RefreshHeader to enforce BetterUI logic.
--- Calls GenericHeader.Refresh with categoryHeaderData (which has proper titleText).
--- Re-attaches the mouse click callback (which might be wiped by Refresh).
--- Ensures scrollList link.
function BETTERUI.Inventory.Class:RefreshHeader(blockCallback)
    BETTERUI.GenericHeader.Refresh(self.header, self.categoryHeaderData, blockCallback)

    -- Ensure scrollList is explicitly linked
    local tabBarControl = self.header:GetNamedChild("TabBar")
    if tabBarControl and self.header.tabBar then
        tabBarControl.scrollList = self.header.tabBar
    end

    -- Restore Weapon Icons and Text
    BETTERUI.GenericHeader.SetEquipText(self.header, self.isPrimaryWeapon)
    BETTERUI.GenericHeader.SetBackupEquipText(self.header, self.isPrimaryWeapon)
    BETTERUI.GenericHeader.SetEquippedIcons(
        self.header,
        GetEquippedItemInfo(EQUIP_SLOT_MAIN_HAND),
        GetEquippedItemInfo(EQUIP_SLOT_OFF_HAND),
        GetEquippedItemInfo(EQUIP_SLOT_POISON)
    )
    BETTERUI.GenericHeader.SetBackupEquippedIcons(
        self.header,
        GetEquippedItemInfo(EQUIP_SLOT_BACKUP_MAIN),
        GetEquippedItemInfo(EQUIP_SLOT_BACKUP_OFF),
        GetEquippedItemInfo(EQUIP_SLOT_BACKUP_POISON)
    )
    BETTERUI.GenericFooter:Refresh()

    -- Reposition the search control so it sits under the header/title (above the list)
    if self.PositionSearchControl then
        self:PositionSearchControl()
    end
end

--- Positions the text search control in the header.
function BETTERUI.Inventory.Class:PositionSearchControl()
    if not self.textSearchHeaderControl then
        return
    end
    -- Shared anchoring lives in CIM SearchManager (loaded before this module).
    BETTERUI.Interface.PositionSearchControl(self, {
        preset = "INVENTORY",
        headerOnly = true,
        titleChildNames = { "TitleContainer", "Header", "HeaderContainer", "HeaderTitle", "HeaderBar", "ContainerHeader" },
        safeExecuteContext = "Inventory.search.anchor",
    })
end

-- Remaining class functionality is split into dedicated modules loaded after this file:
-- InventorySorting.lua      — Header sort columns, comparators, controller init
-- InventoryMultiSelect.lua  — Multi-select lifecycle and batch action menus
-- InventoryBatchOps.lua     — Batch operations (retrieve, stow, deposit, destroy)
