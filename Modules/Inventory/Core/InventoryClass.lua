--[[
File: Modules/Inventory/Core/InventoryClass.lua
Purpose: Defines the primary BETTERUI.Inventory.Class structure, initialization logic,
         header management, and high-level caching mechanisms.
Author: BetterUI Team
Last Modified: 2026-01-28
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
local BLOCK_TABBAR_CALLBACK = true
-- Scene Name Override: We replace ZO_GAMEPAD_INVENTORY_SCENE_NAME to ensure
-- BetterUI's inventory scene is registered instead of the vanilla one. This must
-- happen before any scene registration to avoid dual-scene conflicts. While modifying
-- ZOS globals is generally fragile, this is required because the engine uses this
-- global to find inventory scenes. Alternative approaches (scene name aliasing) were
-- tested in v2.x and caused more issues than this direct override.
ZO_GAMEPAD_INVENTORY_SCENE_NAME = "gamepad_inventory_root"

-- Validated Globals for Core
-- NOTE: GAMEPAD_INVENTORY_ROOT_SCENE must be global because Module.lua needs to add fragments to it

-- List type identifiers sourced from BETTERUI.Inventory.CONST.LIST_TYPES (see Inventory/Constants.lua)
-- The global aliases (INVENTORY_CATEGORY_LIST, etc.) are created there for backward compatibility.

-- Apply Mixins (populated by other modules like PositionManager)
-- Note: Consider creating BETTERUI.CIM.ApplyMixin() helper in a future refactor to DRY this pattern.
-- Deferred: Low priority since the pattern only exists in 2-3 locations currently.
if BETTERUI.Inventory.ClassMixins then
    for name, func in pairs(BETTERUI.Inventory.ClassMixins) do
        BETTERUI.Inventory.Class[name] = func
    end
end

-- Module-specific TaskManager for managed deferred tasks (Phase 1.1)
-- Using module-specific instance prevents ID collisions with other modules
BETTERUI.Inventory.Tasks = BETTERUI.CIM.DeferredTask.Manager:New()


--------------------------------------------------------------------------------
-- CACHING & DATA MANAGEMENT
--------------------------------------------------------------------------------

local g_slotDataCache = {}
local g_slotDataCacheDirty = true

function BETTERUI.Inventory.Class:InvalidateSlotDataCache()
    g_slotDataCacheDirty = true
    g_slotDataCache = {}
end

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

--------------------------------------------------------------------------------
-- KEYBIND MANAGEMENT (Override ESO Base Class)
--------------------------------------------------------------------------------

--[[
Function: RefreshKeybinds (Override)
Description: Guards keybind refresh against header sort mode.
Rationale: ESO's ZO_Gamepad_ParametricList_Screen:CreateAndSetupList wraps the list's
           OnSelectedDataChangedCallback with a call to self:RefreshKeybinds(). This
           bypasses all our guards on individual RefreshKeybinds calls because ESO's
           base class is calling RefreshKeybinds directly. By overriding the function
           itself, we intercept ALL refresh calls - both from our code and ESO's base class.
Mechanism: Check isInHeaderSortMode; if true, skip refresh entirely. Otherwise, call
           the parent implementation via ZO_GamepadInventory.RefreshKeybinds.
References: Called by ESO base class in selection callbacks.
]]
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
Description: Guards itemActions:SetInventorySlot against header sort mode.
Rationale: ESO's ZO_ItemSlotActionsController:SetInventorySlot calls RefreshKeybindStrip()
           which DIRECTLY manipulates KEYBIND_STRIP (Add/Update/Remove). This bypasses our
           RefreshKeybinds override. By guarding at the SetSelectedInventoryData level,
           we prevent itemActions from updating keybinds during header sort mode.
References: Called on every selection change via selection callbacks.
]]
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

--------------------------------------------------------------------------------
-- INITIALIZATION
--------------------------------------------------------------------------------


--- Initializes the Inventory object.
--- Purpose: Sets up the root scene, registers update loops, and hooks into visual layer changes.
--- References: Called by Module.lua.
--- @param control Control The root control for the inventory
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

    -- Note: We no longer call ToSavedPosition here after split stack.
    -- The inventory update events (SingleSlotInventoryUpdate) will trigger refreshes naturally,
    -- and the existing position restoration in RefreshItemList handles keeping the selection.
    -- Calling ToSavedPosition here was causing redundant refreshes and flickering.

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
                self:SwitchActiveList(INVENTORY_ITEM_LIST)
            end
        end
    end

    -- Do not intercept base destroy cancel events to avoid input blockage
    control:RegisterForEvent(EVENT_VISUAL_LAYER_CHANGED, RefreshVisualLayer)
    control:SetHandler("OnUpdate", OnUpdate)

    -- Add gamepad text search support using the shared helper
    if BETTERUI and BETTERUI.Interface and BETTERUI.Interface.Window and BETTERUI.Interface.Window.AddSearch then
        self.textSearchKeybindStripDescriptor = BETTERUI.Interface.CreateSearchKeybindDescriptor(self)

        BETTERUI.Interface.Window.AddSearch(self, self.textSearchKeybindStripDescriptor, function(editOrText)
            -- Normalize the OnTextChanged argument like Banking does
            local query = ""
            if type(editOrText) == "string" then
                query = editOrText
            elseif editOrText and type(editOrText) == "table" and editOrText.GetText then
                query = editOrText:GetText() or ""
            elseif editOrText and type(editOrText) == "userdata" then
                local ok, txt = pcall(function() return editOrText:GetText() end)
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

--------------------------------------------------------------------------------
-- HELPER UTILITIES
--------------------------------------------------------------------------------

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

--------------------------------------------------------------------------------
-- HEADER MANAGEMENT
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- REFRESH OPTIMIZATIONS
--------------------------------------------------------------------------------

--- Checks if any items in the cached list are marked as new.
--- Optimized replacement for SHARED_INVENTORY:AreAnyItemsNew to use local cache.
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
--- Purpose: Overrides base RefreshHeader to enforce BetterUI logic.
--- Mechanics:
--- - Calls GenericHeader.Refresh with categoryHeaderData (which has proper titleText).
--- - Re-attaches the mouse click callback (which might be wiped by Refresh).
--- - Ensures scrollList link.
--- @param blockCallback boolean Whether to block the tab bar callback during refresh.
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
            local ok, c = pcall(function() return anchorTarget:GetNamedChild(name) end)
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
            BETTERUI.Inventory.CONST.SEARCH_Y_OFFSET or 10)
        self.textSearchHeaderControl:SetAnchor(TOPRIGHT, self.header, BOTTOMRIGHT, 0,
            BETTERUI.Inventory.CONST.SEARCH_Y_OFFSET or 10)
    end
    self.textSearchHeaderControl:SetHidden(false)
end

--------------------------------------------------------------------------------
-- HEADER SORT MODE
--------------------------------------------------------------------------------
-- Column definitions for header sort navigation
-- Each column has a name (for display), key (internal), sortKey, and optional defaultDirection
local INVENTORY_SORT_COLUMNS = {
    { name = "NAME",  key = "name",  sortKey = "name" },
    { name = "TYPE",  key = "type",  sortKey = "bestGamepadItemCategoryName" },
    { name = "TRAIT", key = "trait", sortKey = "trait" },                                                       -- Special handling for alphabetical sort
    { name = "STAT",  key = "stat",  sortKey = "stat" },                                                        -- Special handling for mixed alpha/numeric
    { name = "VALUE", key = "value", sortKey = "value",                      defaultDirection = "descending" }, -- Market price, default high-to-low
}

--- Helper: Get trait display name for sorting (alphabetical with blanks last)
--- Returns uppercase trait name for consistent sorting
--- @param data table Item data
--- @return string|nil Trait name (uppercase) or nil if no trait
local function GetTraitSortValue(data)
    if not data then return nil end

    -- Check for dataSource (ZO_GamepadEntryData wraps item data)
    local itemData = data.dataSource or data

    -- Use cached trait name if available and not blank
    local cachedTrait = itemData.cached_traitName or data.cached_traitName
    if cachedTrait and cachedTrait ~= "-" and cachedTrait ~= "" then
        return cachedTrait:upper() -- Normalize to uppercase
    end

    -- Try to get trait type from stored data first
    local traitType = itemData.traitType or itemData.traitInformation or data.traitType

    -- If no cached traitType, get it directly from the API using bagId/slotIndex
    if not traitType or traitType == 0 then
        local bagId = itemData.bagId or data.bagId
        local slotIndex = itemData.slotIndex or data.slotIndex
        if bagId and slotIndex and GetItemTrait then
            traitType = GetItemTrait(bagId, slotIndex)
        end
    end

    -- Convert trait type to name
    if traitType and traitType ~= ITEM_TRAIT_TYPE_NONE and traitType ~= 0 then
        local traitName = GetString("SI_ITEMTRAITTYPE", traitType)
        if traitName and traitName ~= "" then
            return traitName:upper() -- Normalize to uppercase
        end
    end

    return nil -- Return nil for blanks (sorted last)
end

--- Helper: Get stat sort value (alphabetical first, then numeric, blanks last)
--- Returns: sortPriority (1=alpha, 2=numeric, 3=blank), sortValue
--- @param data table Item data
--- @return number priority Sort priority (1=alpha, 2=numeric, 3=blank)
--- @return string|number value Value to compare within priority
local function GetStatSortValue(data)
    if not data then return 3, "" end

    local statValue = data.statValue
    if statValue == nil or statValue == "" or statValue == 0 or statValue == "-" then
        return 3, "" -- Blank - lowest priority
    end

    -- Convert to string for analysis
    local statStr = tostring(statValue)

    -- Check if purely numeric
    local numVal = tonumber(statStr)
    if numVal then
        return 2, numVal -- Numeric - medium priority
    end

    -- Check if starts with letter (alphabetical)
    if statStr:match("^%a") then
        return 1, statStr:upper() -- Alphabetical - highest priority
    end

    -- Special characters
    return 2.5, statStr -- After numeric, before blank
end

--- Helper: Get value sort value (market price first, then vendor price)
--- @param data table Item data
--- @return number price Best available price
local function GetValueSortValue(data)
    if not data then return 0 end

    -- Try to get market price first
    if BETTERUI.GetMarketPrice then
        local itemLink = data.itemLink or (data.bagId and data.slotIndex and GetItemLink(data.bagId, data.slotIndex))
        if itemLink then
            local marketPrice = BETTERUI.GetMarketPrice(itemLink, data.stackCount or 1)
            if marketPrice and marketPrice > 0 then
                return marketPrice
            end
        end
    end

    -- Fall back to vendor price
    return data.stackSellPrice or 0
end

--- Creates sort comparator for a column with the specified direction
--- Handles special cases: TRAIT (alphabetical, blanks last), STAT (alpha/numeric/blank),
--- VALUE (market price priority)
--- @param sortKey string The key to sort by
--- @param ascending boolean True for ascending, false for descending
local function CreateColumnSortComparator(sortKey, ascending)
    -- TRAIT: Alphabetical with blanks after "z"
    if sortKey == "trait" then
        return function(left, right)
            local leftVal = GetTraitSortValue(left)
            local rightVal = GetTraitSortValue(right)

            -- Blanks (nil) always sort last regardless of direction
            if leftVal == nil and rightVal == nil then return false end
            if leftVal == nil then return false end -- left is blank, goes after right
            if rightVal == nil then return true end -- right is blank, left goes first

            -- Alphabetical comparison (already uppercase from helper)
            if ascending then
                return leftVal < rightVal
            else
                return leftVal > rightVal
            end
        end
    end

    -- STAT: Alphabetical first, then numeric by value, special chars, blanks last
    if sortKey == "stat" then
        return function(left, right)
            local leftPrio, leftVal = GetStatSortValue(left)
            local rightPrio, rightVal = GetStatSortValue(right)

            -- Blanks (priority 3) always sort last regardless of direction
            if leftPrio == 3 and rightPrio == 3 then return false end
            if leftPrio == 3 then return false end -- left is blank, goes after right
            if rightPrio == 3 then return true end -- right is blank, left goes first

            -- Different priorities: sort by priority (alpha < numeric < special)
            if leftPrio ~= rightPrio then
                if ascending then
                    return leftPrio < rightPrio
                else
                    return leftPrio > rightPrio
                end
            end

            -- Same priority: compare values
            if ascending then
                return leftVal < rightVal
            else
                return leftVal > rightVal
            end
        end
    end

    -- VALUE: Market price first, then vendor price
    -- Descending: highest first, 0 last
    -- Ascending: 0 first (lowest), then lowest to highest
    if sortKey == "value" then
        return function(left, right)
            local leftVal = GetValueSortValue(left)
            local rightVal = GetValueSortValue(right)

            -- Handle zero values based on sort direction
            if ascending then
                -- Ascending: 0 comes first (lowest value)
                if leftVal == 0 and rightVal == 0 then return false end
                if leftVal == 0 then return true end   -- left is 0, goes before right
                if rightVal == 0 then return false end -- right is 0, left goes after right
            else
                -- Descending: 0 comes last (after highest values)
                if leftVal == 0 and rightVal == 0 then return false end
                if leftVal == 0 then return false end -- left is 0, goes after right
                if rightVal == 0 then return true end -- right is 0, left goes first
            end

            if ascending then
                return leftVal < rightVal
            else
                return leftVal > rightVal
            end
        end
    end

    -- Default comparator for NAME, TYPE, and other columns
    return function(left, right)
        local leftVal = left[sortKey]
        local rightVal = right[sortKey]

        -- Handle nil values
        if leftVal == nil and rightVal == nil then return false end
        if leftVal == nil then return not ascending end
        if rightVal == nil then return ascending end

        -- String comparison for text columns
        if type(leftVal) == "string" and type(rightVal) == "string" then
            if ascending then
                return leftVal < rightVal
            else
                return leftVal > rightVal
            end
        end

        -- Numeric comparison
        if ascending then
            return leftVal < rightVal
        else
            return leftVal > rightVal
        end
    end
end

--- Initializes the header sort controller for this inventory instance
function BETTERUI.Inventory.Class:InitializeHeaderSortController()
    if self.headerSortController then return end

    local controllerClass = BETTERUI.CIM.UI.HeaderSortController
    if not controllerClass then return end

    -- Create controller with column definitions and sort callback
    self.headerSortController = controllerClass:New(
        self.itemList,
        INVENTORY_SORT_COLUMNS,
        function(columnKey, direction, sortFn)
            self:OnHeaderSortChanged(columnKey, direction)
        end
    )

    -- Initialize horizontal movement controller for L/R navigation
    self.horizontalMovementController = ZO_MovementController:New(MOVEMENT_CONTROLLER_DIRECTION_HORIZONTAL)

    -- Apply CIM mixin to inject EnterHeaderSortMode and ExitHeaderSortMode methods
    local HeaderSortIntegration = BETTERUI.CIM.UI.HeaderSortIntegration
    if HeaderSortIntegration and HeaderSortIntegration.ApplyMixin then
        HeaderSortIntegration.ApplyMixin(self, {
            -- Use a function to get the current list dynamically (supports itemList and craftBagList)
            listFn = function() return self:GetCurrentList() end,
            keybindDescriptor = self.mainKeybindStripDescriptor,
            headerControllerFn = function() return self.headerSortController end,
            initControllerFn = function() self:InitializeHeaderSortController() end,
        })
    end

    -- Link column labels now (Inventory uses different header than Banking)
    self:LinkColumnLabels()
end

--- Links column header labels to the sort controller for visual feedback
--- Inventory uses GetNamedChild since it doesn't call AddColumn like Banking does
function BETTERUI.Inventory.Class:LinkColumnLabels()
    if not self.headerSortController then return end
    if not self.headerSortController.SetColumnLabel then return end

    -- Column labels are defined in GenericHeader.xml: Column1Label...Column6Label
    -- Map column index (1-5) to the XML label names
    local COLUMN_LABEL_NAMES = {
        "Column1Label", -- NAME (index 1)
        "Column2Label", -- TYPE (index 2)
        "Column4Label", -- TRAIT (index 3)
        "Column6Label", -- STAT (index 4)
        "Column5Label", -- VALUE (index 5)
    }

    -- Try using header.columns first (if AddColumn was called, like in Banking)
    if self.header and self.header.columns and #self.header.columns > 0 then
        for i, labelControl in ipairs(self.header.columns) do
            if labelControl then
                self.headerSortController:SetColumnLabel(i, labelControl)
            end
        end
        return
    end

    -- Fallback: Find labels using GetNamedChild from header or ColumnBar
    -- This is needed because Inventory doesn't use WindowClass:AddColumn
    if self.header then
        local columnBar = self.header:GetNamedChild("ColumnBar")
        for i, labelName in ipairs(COLUMN_LABEL_NAMES) do
            -- Try header first (where $(parent) resolves to)
            local labelControl = self.header:GetNamedChild(labelName)
            -- Fallback to columnBar if not found on header
            if not labelControl and columnBar then
                labelControl = columnBar:GetNamedChild(labelName)
            end
            if labelControl then
                self.headerSortController:SetColumnLabel(i, labelControl)
            end
        end
    end
end

--- Called when sort direction changes on a column
--- @param columnKey string The column key that changed
--- @param direction number Sort direction constant
function BETTERUI.Inventory.Class:OnHeaderSortChanged(columnKey, direction)
    local SORT_DIRECTION = BETTERUI.CIM.UI.HeaderSortController.SORT_DIRECTION

    -- Find the column definition
    local column = nil
    for _, col in ipairs(INVENTORY_SORT_COLUMNS) do
        if col.key == columnKey then
            column = col
            break
        end
    end

    if not column then return end

    -- Get the current active list (could be itemList or craftBagList)
    local currentList = self:GetCurrentList()
    if not currentList then return end

    -- Update the list sort function
    if direction == SORT_DIRECTION.NONE then
        -- Reset to default sort
        self.currentSortComparator = nil
        if currentList.SetSortFunction then
            currentList:SetSortFunction(BETTERUI.Inventory.DefaultSortComparator)
        end
    else
        local ascending = (direction == SORT_DIRECTION.ASCENDING)
        self.currentSortComparator = CreateColumnSortComparator(column.sortKey, ascending)
        if currentList.SetSortFunction then
            currentList:SetSortFunction(self.currentSortComparator)
        end
    end

    -- Refresh the appropriate list to apply new sort
    -- NOTE: Keybinds are protected by SetSelectedInventoryData override which skips
    -- itemActions:SetInventorySlot() when isInHeaderSortMode is true
    if currentList == self.itemList then
        self:RefreshItemList()
    elseif currentList == self.craftBagList then
        self:RefreshCraftBagList()
    end
end

--- Enters header sort navigation mode.
--- Called when user presses D-pad Up at the first item in the list.
--- Deactivates the item list and switches input to header column navigation.
-- NOTE: EnterHeaderSortMode and ExitHeaderSortMode are injected by CIM mixin.
-- See InitializeHeaderSortController where ApplyMixin is called.


--------------------------------------------------------------------------------
-- MULTI-SELECT MODE
--------------------------------------------------------------------------------

--- Enters multi-selection mode.
--- Called when user holds the A button for 0.5s.
function BETTERUI.Inventory.Class:EnterSelectionMode()
    if self.isInSelectionMode then return end
    if not self.multiSelectManager then return end

    self.isInSelectionMode = true
    self.multiSelectManager:EnterSelectionMode()

    -- Select the current item automatically
    local target = self.itemList.selectedData
    if target then
        self.multiSelectManager:ToggleSelection(target)
    end

    -- Update keybinds for selection mode (skip if in header sort mode)
    if not self.isInHeaderSortMode then
        self:RefreshKeybinds()
    end

    -- Refresh list to show selection visuals
    self:RefreshItemList()
end

--- Exits multi-selection mode.
--- Called when user presses B or completes a batch action.
function BETTERUI.Inventory.Class:ExitSelectionMode()
    if not self.isInSelectionMode then return end

    self.isInSelectionMode = false
    if self.multiSelectManager then
        self.multiSelectManager:ExitSelectionMode()
    end

    -- Update keybinds to normal mode (skip if in header sort mode)
    if not self.isInHeaderSortMode then
        self:RefreshKeybinds()
    end

    -- Refresh list to remove selection visuals
    self:RefreshItemList()
end

--- Called when the selection count changes.
--- Used to update the title bar or any selection count display.
--- @param selectedCount number The number of currently selected items
function BETTERUI.Inventory.Class:OnSelectionCountChanged(selectedCount)
    -- Update title to show selection count if in selection mode
    if self.isInSelectionMode and selectedCount > 0 then
        local countText = zo_strformat(GetString(SI_BETTERUI_SELECTED_COUNT), selectedCount)
        -- Could update header title here if needed
        self.selectedCount = selectedCount
    else
        self.selectedCount = 0
    end

    -- Refresh keybinds to update Y-button batch actions visibility (skip if in header sort mode)
    if not self.isInHeaderSortMode then
        self:RefreshKeybinds()
    end
end

--- Gets whether selection mode is currently active.
--- @return boolean isActive
function BETTERUI.Inventory.Class:IsInSelectionMode()
    return self.isInSelectionMode or false
end

--- Shows the batch actions menu for multi-selected items.
--- Displays context-appropriate batch operations based on selected items' states.
function BETTERUI.Inventory.Class:ShowBatchActionsMenu()
    if not self.multiSelectManager or not self.multiSelectManager:IsActive() then
        return
    end

    local selectedItems = self.multiSelectManager:GetSelectedItems()
    local selectedCount = #selectedItems

    if selectedCount == 0 then
        return
    end

    -- Analyze selected items to determine which actions are applicable
    -- Use counts instead of booleans so we can display "Lock (40)" etc.
    local lockedCount = 0
    local unlockedCount = 0      -- Items not locked (used for Destroy)
    local canLockCount = 0       -- Items that CAN be locked AND are not already locked
    -- Track junk status for eligible items only
    local canMarkJunkCount = 0   -- Can be junked AND not locked AND not already junk
    local canUnmarkJunkCount = 0 -- Can be junked AND not locked AND is junk

    for _, itemData in ipairs(selectedItems) do
        local rawData = itemData.dataSource or itemData
        local bagId = rawData.bagId or itemData.bagId
        local slotIndex = rawData.slotIndex or itemData.slotIndex

        if bagId and slotIndex then
            -- Check lock status and lockability
            local isLocked = IsItemPlayerLocked(bagId, slotIndex)
            local canBeLocked = CanItemBePlayerLocked(bagId, slotIndex)

            if isLocked then
                lockedCount = lockedCount + 1
            else
                unlockedCount = unlockedCount + 1
            end

            -- Lock: only count items that CAN be locked AND are not already locked
            if canBeLocked and not isLocked then
                canLockCount = canLockCount + 1
            end

            -- Check junk status and junkability
            local isJunk = IsItemJunk(bagId, slotIndex)
            local canBeJunked = CanItemBeMarkedAsJunk(bagId, slotIndex)

            -- Junk: must be junkable, not locked
            if canBeJunked and not isLocked then
                if isJunk then
                    canUnmarkJunkCount = canUnmarkJunkCount + 1
                else
                    canMarkJunkCount = canMarkJunkCount + 1
                end
            end
        end
    end

    -- Build batch actions dialog
    local dialogName = "BETTERUI_BATCH_ACTIONS_DIALOG"

    -- Create dialog if it doesn't exist
    if not ESO_Dialogs[dialogName] then
        ESO_Dialogs[dialogName] = {
            gamepadInfo = {
                dialogType = GAMEPAD_DIALOGS.PARAMETRIC,
            },
            title = {
                -- Use dialog.data.selectedCount for fresh value each time
                text = function(dialog)
                    local count = dialog and dialog.data and dialog.data.selectedCount or 0
                    return zo_strformat(GetString(SI_BETTERUI_SELECTED_COUNT), count)
                end,
            },
            mainText = {
                text = GetString(SI_BETTERUI_BATCH_ACTIONS_DESC),
            },
            setup = function(dialog)
                dialog:setupFunc()
            end,
            parametricList = {},
            buttons = {
                {
                    keybind = "DIALOG_PRIMARY",
                    text = GetString(SI_GAMEPAD_SELECT_OPTION),
                    callback = function(dialog)
                        local selected = dialog.entryList and
                            BETTERUI.Inventory.Utils.SafeGetTargetData(dialog.entryList)
                        if selected and selected.callback then
                            selected.callback()
                        end
                    end,
                },
                {
                    keybind = "DIALOG_NEGATIVE",
                    text = GetString(SI_GAMEPAD_BACK_OPTION),
                    callback = function()
                        -- Refresh keybinds after dialog closes to restore A-button action
                        -- Use zo_callLater to ensure dialog fully closes first
                        zo_callLater(function()
                            if GAMEPAD_INVENTORY and GAMEPAD_INVENTORY.RefreshKeybinds then
                                GAMEPAD_INVENTORY:RefreshKeybinds()
                            end
                        end, 50)
                    end,
                },
            },
        }
    end

    -- Build the parametric list with applicable batch actions
    local parametricList = {}

    -- Add Select All (to select all items in current category) - always at top
    local selectAllEntry = ZO_GamepadEntryData:New(GetString(SI_BETTERUI_SELECT_ALL))
    selectAllEntry:SetIconTintOnSelection(true)
    selectAllEntry.setup = ZO_SharedGamepadEntry_OnSetup
    selectAllEntry.callback = function()
        self:SelectAllItems()
    end
    table.insert(parametricList, {
        template = "ZO_GamepadItemEntryTemplate",
        entryData = selectAllEntry,
    })

    -- Add Lock (only if lockable unlocked items exist) - show count
    if canLockCount > 0 then
        local label = zo_strformat("<<1>> (<<2>>)", GetString(SI_ITEM_ACTION_MARK_AS_LOCKED), canLockCount)
        local lockEntry = ZO_GamepadEntryData:New(label)
        lockEntry:SetIconTintOnSelection(true)
        lockEntry.setup = ZO_SharedGamepadEntry_OnSetup
        lockEntry.callback = function()
            self:BatchLock()
        end
        table.insert(parametricList, {
            template = "ZO_GamepadItemEntryTemplate",
            entryData = lockEntry,
        })
    end

    -- Add Unlock (only if any locked items exist) - show count
    if lockedCount > 0 then
        local label = zo_strformat("<<1>> (<<2>>)", GetString(SI_ITEM_ACTION_UNMARK_AS_LOCKED), lockedCount)
        local unlockEntry = ZO_GamepadEntryData:New(label)
        unlockEntry:SetIconTintOnSelection(true)
        unlockEntry.setup = ZO_SharedGamepadEntry_OnSetup
        unlockEntry.callback = function()
            self:BatchUnlock()
        end
        table.insert(parametricList, {
            template = "ZO_GamepadItemEntryTemplate",
            entryData = unlockEntry,
        })
    end

    -- Add Mark as Junk (only if unlocked non-junk items exist) - show count
    if canMarkJunkCount > 0 then
        local label = zo_strformat("<<1>> (<<2>>)", GetString(SI_ITEM_ACTION_MARK_AS_JUNK), canMarkJunkCount)
        local junkEntry = ZO_GamepadEntryData:New(label)
        junkEntry:SetIconTintOnSelection(true)
        junkEntry.setup = ZO_SharedGamepadEntry_OnSetup
        junkEntry.callback = function()
            self:BatchMarkAsJunk()
        end
        table.insert(parametricList, {
            template = "ZO_GamepadItemEntryTemplate",
            entryData = junkEntry,
        })
    end

    -- Add Unmark as Junk (only if unlocked junk items exist) - show count
    if canUnmarkJunkCount > 0 then
        local label = zo_strformat("<<1>> (<<2>>)", GetString(SI_ITEM_ACTION_UNMARK_AS_JUNK), canUnmarkJunkCount)
        local unjunkEntry = ZO_GamepadEntryData:New(label)
        unjunkEntry:SetIconTintOnSelection(true)
        unjunkEntry.setup = ZO_SharedGamepadEntry_OnSetup
        unjunkEntry.callback = function()
            self:BatchUnmarkAsJunk()
        end
        table.insert(parametricList, {
            template = "ZO_GamepadItemEntryTemplate",
            entryData = unjunkEntry,
        })
    end

    -- Add Destroy (only if unlocked items exist) - show count
    -- Only unlocked items can be destroyed
    if unlockedCount > 0 then
        local label = zo_strformat("<<1>> (<<2>>)", GetString(SI_ITEM_ACTION_DESTROY), unlockedCount)
        local destroyEntry = ZO_GamepadEntryData:New(label)
        destroyEntry:SetIconTintOnSelection(true)
        destroyEntry.setup = ZO_SharedGamepadEntry_OnSetup
        destroyEntry.callback = function()
            self:BatchDestroy()
        end
        table.insert(parametricList, {
            template = "ZO_GamepadItemEntryTemplate",
            entryData = destroyEntry,
        })
    end

    -- Add Deselect All (always at bottom)
    local deselectEntry = ZO_GamepadEntryData:New(GetString(SI_BETTERUI_DESELECT_ALL))
    deselectEntry:SetIconTintOnSelection(true)
    deselectEntry.setup = ZO_SharedGamepadEntry_OnSetup
    deselectEntry.callback = function()
        self:ExitSelectionMode()
    end
    table.insert(parametricList, {
        template = "ZO_GamepadItemEntryTemplate",
        entryData = deselectEntry,
    })

    ESO_Dialogs[dialogName].parametricList = parametricList

    -- Pass selectedCount in dialog data so title function uses fresh value
    ZO_Dialogs_ShowGamepadDialog(dialogName, { selectedCount = selectedCount })
end

-- ============================================================================
-- THROTTLED BATCH PROCESSING
-- ============================================================================

-- Use centralized constants from CIM
local BATCH_THROTTLE_DELAY_MS = BETTERUI.CIM.CONST.TIMING.BATCH_ACTION_DELAY_MS
local BATCH_PROGRESS_THRESHOLD = BETTERUI.CIM.CONST.TIMING.BATCH_PROGRESS_THRESHOLD

--- Checks if batch processing is currently in progress.
--- Used by refresh functions to skip updates during batch operations.
--- @return boolean True if batch processing is active
function BETTERUI.Inventory.Class:IsBatchProcessing()
    return self.isBatchProcessing == true
end

--- Processes items with staggered delays to prevent rate-limiting.
--- Suppresses list/keybind refreshes during processing to prevent flickering.
--- @param items table Array of items to process
--- @param actionFn fun(bagId: number, slotIndex: number, itemData: table) Function to execute per item
--- @param onComplete fun()? Optional callback when all items processed
--- @param actionName string? Name of the action for notifications
function BETTERUI.Inventory.Class:ProcessBatchThrottled(items, actionFn, onComplete, actionName)
    local index = 0
    local totalItems = #items
    local showProgress = totalItems >= BATCH_PROGRESS_THRESHOLD
    local self_ref = self

    -- Set batch processing flag to suppress refreshes
    self.isBatchProcessing = true

    -- Get display name for notifications (needed in completion handler too)
    local displayName = actionName or GetString(SI_BETTERUI_BATCH_ACTIONS)

    -- Show start notification for large batches
    if showProgress then
        -- Use CENTER_SCREEN_ANNOUNCE for a non-blocking notification (LARGE_TEXT for bigger font)
        local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT)
        messageParams:SetText(displayName,
            zo_strformat(GetString(SI_BETTERUI_BATCH_PROCESSING_START), totalItems))
        messageParams:SetLifespanMS(3000)
        CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
    end

    local function processNext()
        index = index + 1

        if index > totalItems then
            -- Clear batch processing flag
            self_ref.isBatchProcessing = false

            -- Show completion notification for large batches
            if showProgress then
                local messageParams = CENTER_SCREEN_ANNOUNCE:CreateMessageParams(CSA_CATEGORY_LARGE_TEXT)
                local completeText = zo_strformat(GetString(SI_BETTERUI_BATCH_PROCESSING_COMPLETE), totalItems)
                messageParams:SetText(displayName, completeText)
                messageParams:SetLifespanMS(2000)
                CENTER_SCREEN_ANNOUNCE:AddMessageWithParams(messageParams)
            end

            -- Now call completion handler (which will do refresh)
            if onComplete then onComplete() end
            return
        end

        local itemData = items[index]
        local rawData = itemData.dataSource or itemData
        local bagId = rawData.bagId or itemData.bagId
        local slotIndex = rawData.slotIndex or itemData.slotIndex

        if bagId and slotIndex then
            actionFn(bagId, slotIndex, itemData)
        end

        -- Schedule next item with delay
        zo_callLater(processNext, BATCH_THROTTLE_DELAY_MS)
    end

    -- Start processing
    processNext()
end

-- ============================================================================
-- BATCH INVENTORY ACTIONS
-- ============================================================================

--- Performs batch deposit on all selected items (throttled).
function BETTERUI.Inventory.Class:BatchDeposit()
    if not self.multiSelectManager then return end
    local items = self.multiSelectManager:GetSelectedItems()
    if not items then return end

    self:ProcessBatchThrottled(items, function(bagId, slotIndex, itemData)
        -- Request bank transfer
        CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_BANK, nil,
            itemData.stackCount or 1)
    end, function()
        self:ExitSelectionMode()
    end, "Depositing")
end

--- Performs batch lock on all selected items (throttled).
function BETTERUI.Inventory.Class:BatchLock()
    if not self.multiSelectManager then return end
    local items = self.multiSelectManager:GetSelectedItems()

    self:ProcessBatchThrottled(items, function(bagId, slotIndex)
        if CanItemBePlayerLocked(bagId, slotIndex) then
            SetItemIsPlayerLocked(bagId, slotIndex, true)
        end
    end, function()
        self:ExitSelectionMode()
        self:RefreshItemList()
    end, "Locking")
end

--- Performs batch unlock on all selected items (throttled).
function BETTERUI.Inventory.Class:BatchUnlock()
    if not self.multiSelectManager then return end
    local items = self.multiSelectManager:GetSelectedItems()

    self:ProcessBatchThrottled(items, function(bagId, slotIndex)
        SetItemIsPlayerLocked(bagId, slotIndex, false)
    end, function()
        self:ExitSelectionMode()
        self:RefreshItemList()
    end, "Unlocking")
end

--- Performs batch mark-as-junk on all selected items (throttled).
function BETTERUI.Inventory.Class:BatchMarkAsJunk()
    if not self.multiSelectManager then return end
    local items = self.multiSelectManager:GetSelectedItems()

    self:ProcessBatchThrottled(items, function(bagId, slotIndex)
        if CanItemBeMarkedAsJunk(bagId, slotIndex) then
            SetItemIsJunk(bagId, slotIndex, true)
        end
    end, function()
        self:ExitSelectionMode()
        self:RefreshItemList()
    end, "Marking as Junk")
end

--- Performs batch unmark-as-junk on all selected items (throttled).
function BETTERUI.Inventory.Class:BatchUnmarkAsJunk()
    if not self.multiSelectManager then return end
    local items = self.multiSelectManager:GetSelectedItems()

    self:ProcessBatchThrottled(items, function(bagId, slotIndex)
        SetItemIsJunk(bagId, slotIndex, false)
    end, function()
        self:ExitSelectionMode()
        self:RefreshItemList()
    end, "Unmarking as Junk")
end

--- Performs batch destroy on all selected items (with confirmation).
--- Always shows confirmation dialog for multi-select (quickDestroy setting is ignored for safety).
function BETTERUI.Inventory.Class:BatchDestroy()
    if not self.multiSelectManager then return end

    local items = self.multiSelectManager:GetSelectedItems()
    local itemCount = #items

    if itemCount == 0 then return end

    -- Build list of items to destroy (extract bag/slot info)
    local itemsToDestroy = {}
    for _, itemData in ipairs(items) do
        local rawData = itemData.dataSource or itemData
        local bagId = rawData.bagId or itemData.bagId
        local slotIndex = rawData.slotIndex or itemData.slotIndex
        if bagId and slotIndex then
            table.insert(itemsToDestroy, { bagId = bagId, slotIndex = slotIndex })
        end
    end

    if #itemsToDestroy == 0 then return end

    -- Always show confirmation dialog for multi-select (ignore quickDestroy setting for safety)
    ZO_Dialogs_ShowGamepadDialog("BETTERUI_BATCH_DESTROY_DIALOG", {
        itemCount = #itemsToDestroy,
        itemsToDestroy = itemsToDestroy,
        inventoryInstance = self,
    })
end

--- Selects all items in the current item list category.
--- Reopens the batch actions dialog to reflect the updated selection.
function BETTERUI.Inventory.Class:SelectAllItems()
    if not self.multiSelectManager then return end

    -- Get the current active list (could be itemList or craftBagList)
    local currentList = self:GetCurrentList()
    if not currentList then return end

    -- Use the built-in SelectAll method with the current list
    -- (the stored list reference may be stale if user switched between bags)
    self.multiSelectManager:SelectAll(currentList)

    -- Refresh the list to show selection highlights
    self:RefreshItemList()
    -- Refresh keybinds to update count display
    self:RefreshKeybinds()

    -- Close current dialog and reopen with updated selection
    -- This ensures action visibility and item count are accurate
    ZO_Dialogs_ReleaseDialog("BETTERUI_BATCH_ACTIONS_DIALOG")
    zo_callLater(function()
        self:ShowBatchActionsMenu()
    end, 100)
end

--- Initializes the batch destroy confirmation dialog.
--- Called during deferred initialization to register the dialog.
function BETTERUI.Inventory.Class:InitializeBatchDestroyDialog()
    BETTERUI.CIM.Dialogs.Register("BETTERUI_BATCH_DESTROY_DIALOG", {
        blockDirectionalInput = true,
        canQueue = true,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.BASIC,
            allowRightStickPassThrough = true,
        },
        title = {
            text = function(dialog)
                return GetString(SI_DESTROY_ITEM_PROMPT_TITLE) or "Destroy Items"
            end,
        },
        mainText = {
            text = function(dialog)
                local count = dialog and dialog.data and dialog.data.itemCount or 0
                return zo_strformat("Are you sure you want to destroy <<1>> selected items? This cannot be undone.",
                    count)
            end,
        },
        buttons = {
            { keybind = "DIALOG_NEGATIVE", text = GetString(SI_DIALOG_CANCEL) },
            {
                keybind = "DIALOG_PRIMARY",
                text = GetString(SI_GAMEPAD_SELECT_OPTION),
                callback = function(dialog)
                    local d = dialog and dialog.data
                    if d and d.itemsToDestroy and d.inventoryInstance then
                        -- Use throttled processing to prevent rate-limit kicks
                        local index = 0
                        local items = d.itemsToDestroy
                        local inventoryInstance = d.inventoryInstance
                        local DELAY_MS = 50

                        local function processNext()
                            index = index + 1
                            if index > #items then
                                inventoryInstance:ExitSelectionMode()
                                return
                            end

                            local item = items[index]
                            BETTERUI.Inventory.TryDestroyItem(item.bagId, item.slotIndex, true)
                            zo_callLater(processNext, DELAY_MS)
                        end

                        processNext()
                    end
                    ZO_Dialogs_ReleaseDialogOnButtonPress("BETTERUI_BATCH_DESTROY_DIALOG")
                end,
            },
        },
    })

    -- Register progress dialog for batch operations
    BETTERUI.CIM.Dialogs.Register("BETTERUI_BATCH_PROGRESS_DIALOG", {
        blockDirectionalInput = true,
        canQueue = false,
        gamepadInfo = {
            dialogType = GAMEPAD_DIALOGS.BASIC,
            allowRightStickPassThrough = false,
        },
        title = {
            text = function(dialog)
                local d = dialog and dialog.data
                local actionName = d and d.actionName or "Processing"
                return actionName
            end,
        },
        mainText = {
            text = function(dialog)
                local d = dialog and dialog.data
                local current = d and d.current or 0
                local total = d and d.total or 0
                -- Show progress and explanation
                return zo_strformat("<<1>> of <<2>> items...\n\nProcessing slowly to prevent spam logout.\nPlease wait!",
                    current, total)
            end,
        },
        -- Must have at least one button for BASIC dialogs to display
        buttons = {
            {
                keybind = "DIALOG_NEGATIVE",
                text = GetString(SI_DIALOG_CANCEL),
                callback = function(dialog)
                    -- User cancelled - stop processing by not calling processNext
                    -- The dialog will close and processing stops
                    ZO_Dialogs_ReleaseDialogOnButtonPress("BETTERUI_BATCH_PROGRESS_DIALOG")
                end,
            },
        },
    })
end
