--[[
File: Modules/Inventory/Core/InventoryClass.lua
Purpose: Defines the primary BETTERUI.Inventory.Class structure, initialization logic,
         header management, and high-level caching mechanisms.
Author: BetterUI Team
Last Modified: 2026-01-28
]]

-- Subclass ZO_GamepadInventory
BETTERUI.Inventory.Class = ZO_GamepadInventory:Subclass()

-- Constants
local BLOCK_TABBAR_CALLBACK = true
-- Override the scene name global so engine references find our scene
ZO_GAMEPAD_INVENTORY_SCENE_NAME = "gamepad_inventory_root"

-- Validated Globals for Core
-- NOTE: GAMEPAD_INVENTORY_ROOT_SCENE must be global because Module.lua needs to add fragments to it

-- List type identifiers sourced from BETTERUI.Inventory.CONST.LIST_TYPES (see Inventory/Constants.lua)
-- The global aliases (INVENTORY_CATEGORY_LIST, etc.) are created there for backward compatibility.

-- Apply Mixins (populated by other modules like PositionManager)
if BETTERUI.Inventory.ClassMixins then
    for name, func in pairs(BETTERUI.Inventory.ClassMixins) do
        BETTERUI.Inventory.Class[name] = func
    end
end


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
-- INITIALIZATION
--------------------------------------------------------------------------------

--- Initializes the Inventory object.
--- Purpose: Sets up the root scene, registers update loops, and hooks into visual layer changes.
--- References: Called by Module.lua.
function BETTERUI.Inventory.Class:Initialize(control)
    BETTERUI.Inventory.ApplyAllMixins()
    GAMEPAD_INVENTORY_ROOT_SCENE = ZO_Scene:New(ZO_GAMEPAD_INVENTORY_SCENE_NAME, SCENE_MANAGER)
    BETTERUI_Gamepad_ParametricList_Screen.Initialize(
        self,
        control,
        ZO_GAMEPAD_HEADER_TABBAR_CREATE,
        false,
        GAMEPAD_INVENTORY_ROOT_SCENE
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

    local function CallbackSplitStackFinished()
        --refresh list
        if self.scene:IsShowing() then
            self:ToSavedPosition()
        end
    end
    CALLBACK_MANAGER:RegisterCallback("BETTERUI_EVENT_SPLIT_STACK_DIALOG_FINISHED", CallbackSplitStackFinished)

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
        if self.PositionSearchControl then
            self:PositionSearchControl()
        end
        -- Hook into the actual edit box to detect when it gains/loses keyboard focus.
        if self.textSearchHeaderFocus and self.textSearchHeaderFocus:GetEditBox() then
            local editBox = self.textSearchHeaderFocus:GetEditBox()
            local origOnFocusGained = editBox:GetHandler("OnFocusGained")
            local origOnFocusLost = editBox:GetHandler("OnFocusLost")
            local origOnTextChanged = editBox:GetHandler("OnTextChanged")
            local origOnKeyDown = editBox:GetHandler("OnKeyDown")

            editBox:SetHandler("OnFocusGained", function(eb)
                if origOnFocusGained then origOnFocusGained(eb) end
                if not self:IsHeaderActive() then self:RequestEnterHeader() end
            end)

            editBox:SetHandler("OnFocusLost", function(eb)
                if origOnFocusLost then origOnFocusLost(eb) end
                self:ExitSearchFocus()
            end)

            editBox:SetHandler("OnTextChanged", function(eb)
                if origOnTextChanged then origOnTextChanged(eb) end

                local txt = ""
                local t = eb:GetText()
                if t then txt = t end
                self.searchQuery = txt or ""

                -- Only force a local refresh for the craft-bag when the engine
                -- will not perform background filtering (to avoid doubling work).
                local willEngineFilter = false
                if ZO_TextSearchManager and ZO_TextSearchManager.CanFilterByText then
                    willEngineFilter = ZO_TextSearchManager.CanFilterByText(self.searchQuery)
                end

                if self:GetCurrentList() == self.craftBagList and not willEngineFilter then
                    self:SaveListPosition()
                    self:RefreshCraftBagList()
                end
            end)

            editBox:SetHandler("OnKeyDown", function(eb, key, ctrl, alt, shift, command)
                if origOnKeyDown then
                    local handled = origOnKeyDown(eb, key, ctrl, alt, shift, command)
                    if handled then return handled end
                end

                if command == "UI_SHORTCUT_DOWN" then
                    self:ExitSearchFocus()
                    return true
                end
            end)
        end
    end

    -- Force a short delayed refresh of the main keybind group
    zo_callLater(function()
        if self.RefreshKeybinds then
            self:RefreshKeybinds()
        elseif self.mainKeybindStripDescriptor then
            KEYBIND_STRIP:UpdateKeybindButtonGroup(self.mainKeybindStripDescriptor)
        end
    end, BETTERUI.CIM.CONST.TIMING.DEBOUNCE_MS)
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
