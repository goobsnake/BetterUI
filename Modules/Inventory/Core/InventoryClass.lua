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

-- Apply Mixins (populated by other modules like PositionManager)
if BETTERUI.Inventory.ClassMixins then
    for name, func in pairs(BETTERUI.Inventory.ClassMixins) do
        BETTERUI.Inventory.Class[name] = func
    end
end

-- Module-specific TaskManager for managed deferred tasks (Phase 1.1)
-- Using module-specific instance prevents ID collisions with other modules
assert(BETTERUI.CIM and BETTERUI.CIM.DeferredTask, "BetterUI: CIM.DeferredTask must load before Inventory/Core/InventoryClass")
BETTERUI.Inventory.Tasks = BETTERUI.CIM.DeferredTask.Manager:New()


-- CACHING & DATA MANAGEMENT

local g_slotDataCache = {}
local g_slotDataCacheDirty = true

--- Invalidates the slot data cache.
function BETTERUI.Inventory.Class:InvalidateSlotDataCache()
    g_slotDataCacheDirty = true
    g_slotDataCache = {}
end

--- Invalidates cached item metadata for a specific bag/slot.
function BETTERUI.Inventory.Class:InvalidateItemMeta(bagId, slotIndex)
    if not self.itemMetaCache then self.itemMetaCache = {} end
    if not bagId then
        self.itemMetaCache = {}
    elseif not slotIndex then
        self.itemMetaCache[bagId] = nil
    else
        if self.itemMetaCache[bagId] then
            self.itemMetaCache[bagId][slotIndex] = nil
        end
    end
end

local function GetBagCacheKey(bags)
    if #bags == 1 then return bags[1] end
    return table.concat(bags, ",")
end

--- Gets cached slot data for the specified bags.
function BETTERUI.Inventory.Class:GetCachedSlotData(...)
    local bags = { ... }
    table.sort(bags) -- Ensure consistent key
    local cacheKey = GetBagCacheKey(bags)

    if g_slotDataCacheDirty then
        g_slotDataCache = {}
        g_slotDataCacheDirty = false
    end

    if not g_slotDataCache[cacheKey] then
        if SHARED_INVENTORY and SHARED_INVENTORY.GenerateFullSlotData then
            -- Fetch ALL items (no filter) for these bags to populate the cache
            g_slotDataCache[cacheKey] = SHARED_INVENTORY:GenerateFullSlotData(nil, unpack(bags))
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
    -- Call parent implementation
    ZO_GamepadInventory.RefreshKeybinds(self)
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
    -- Skip itemActions keybind updates when in header sort mode
    -- This is the REAL fix for the "A-Button Burn" flicker - itemActions:SetInventorySlot
    -- calls RefreshKeybindStrip() which directly manipulates KEYBIND_STRIP, bypassing
    -- our RefreshKeybinds override
    if self.isInHeaderSortMode then
        -- Only update uniqueId tracking, skip itemActions entirely
        self:SetSelectedItemUniqueId(inventoryData)
        return
    end
    -- Call parent implementation (includes itemActions:SetInventorySlot)
    ZO_GamepadInventory.SetSelectedInventoryData(self, inventoryData)
end

-- INITIALIZATION


--- Initializes the Inventory object.
--- Sets up the root scene, registers update loops, and hooks into visual layer changes.
--- References: Called by Module.lua.
function BETTERUI.Inventory.Class:Initialize(control)
    BETTERUI.Inventory.ApplyAllMixins()
    GAMEPAD_INVENTORY_ROOT_SCENE = ZO_Scene:New(ZO_GAMEPAD_INVENTORY_SCENE_NAME, SCENE_MANAGER)
    -- Use UnifiedScreen initialization with CURRENCY footer mode
    BETTERUI.CIM.UnifiedScreen.Initialize(
        self,
        control,
        ZO_GAMEPAD_HEADER_TABBAR_CREATE,
        false,
        GAMEPAD_INVENTORY_ROOT_SCENE,
        BETTERUI.CIM.UnifiedScreen.FOOTER_MODE_CURRENCY
    )

    if BETTERUI.Inventory.InitializeSecureWheelHooks then
        BETTERUI.Inventory.InitializeSecureWheelHooks()
    end

    -- Initialize the actions object (using BetterUI custom subclass if available)
    if self.InitializeItemActions then
        self:InitializeItemActions()
    else
        self.itemActions = ZO_InventorySlotActions:New(KEYBIND_STRIP_ALIGN_LEFT)
    end

    -- Hook the Action Dialog (Y-Menu) logic
    if self.InitializeActionsDialog then
        self:InitializeActionsDialog()
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
    local addSearch = BETTERUI.CIM.TryResolve("Interface.Window.AddSearch")
    if addSearch then
        self.textSearchKeybindStripDescriptor = BETTERUI.Interface.CreateSearchKeybindDescriptor(self)

        addSearch(self, self.textSearchKeybindStripDescriptor, function(editOrText)
            -- Normalize the OnTextChanged argument like Banking does
            local query
            if type(editOrText) == "string" then
                query = editOrText
            elseif editOrText and type(editOrText) == "table" and editOrText.GetText then
                query = editOrText:GetText() or ""
            elseif editOrText and type(editOrText) == "userdata" then
                local ok, txt = BETTERUI.CIM.SafeExecute("Inventory.search.getText", function() return editOrText:GetText() end)
                if ok and txt then query = txt else query = tostring(editOrText) end
            else
                query = tostring(editOrText or "")
            end

            self.searchQuery = query or ""
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
        BETTERUI.Interface.SearchMixin.SetupEditBoxHandlers(self, {
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
    self:RefreshCategoryList()
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
    self.textSearchHeaderControl:ClearAnchors()
    local anchorTarget = self.header
    local titleContainer = nil
    if anchorTarget and anchorTarget.GetNamedChild then
        local candidates = { "TitleContainer", "Header", "HeaderContainer", "HeaderTitle", "HeaderBar", "ContainerHeader" }
        for _, name in ipairs(candidates) do
            local ok, c = BETTERUI.CIM.SafeExecute("Inventory.search.anchor", function() return anchorTarget:GetNamedChild(name) end)
            if ok and c then
                titleContainer = c
                break
            end
        end
    end

    local parentForAnchor = titleContainer or self.header
    if parentForAnchor then
        -- Search bar position configured in BetterUI.Constants.lua
        local xOffset = BETTERUI.Inventory.CONST.SEARCH_X_OFFSET
        local yOffset = BETTERUI.Inventory.CONST.SEARCH_Y_OFFSET
        local rightInset = BETTERUI.Inventory.CONST.SEARCH_RIGHT_INSET
        -- TOPLEFT uses xOffset, TOPRIGHT uses rightInset so the control width is constrained
        self.textSearchHeaderControl:SetAnchor(TOPLEFT, parentForAnchor, BOTTOMLEFT, xOffset, yOffset)
        self.textSearchHeaderControl:SetAnchor(TOPRIGHT, parentForAnchor, BOTTOMRIGHT, rightInset, yOffset)
    else
        self.textSearchHeaderControl:SetAnchor(TOPLEFT, self.header, BOTTOMLEFT, 0,
            BETTERUI.Inventory.CONST.SEARCH_Y_OFFSET)
        self.textSearchHeaderControl:SetAnchor(TOPRIGHT, self.header, BOTTOMRIGHT, 0,
            BETTERUI.Inventory.CONST.SEARCH_Y_OFFSET)
    end
    self.textSearchHeaderControl:SetHidden(false)
end

-- Remaining class functionality is split into dedicated modules loaded after this file:
-- InventorySorting.lua      — Header sort columns, comparators, controller init
-- InventoryMultiSelect.lua  — Multi-select lifecycle and batch action menus
-- InventoryBatchOps.lua     — Batch operations (retrieve, stow, deposit, destroy)
