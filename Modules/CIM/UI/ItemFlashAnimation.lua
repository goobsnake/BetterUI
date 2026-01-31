--[[
File: Modules/CIM/UI/ItemFlashAnimation.lua
Purpose: Provides animation utilities for highlighting recently moved items.
         Creates a brief gold pulse effect on items that were just deposited or withdrawn.
Author: BetterUI Team
Last Modified: 2026-01-30

KEY RESPONSIBILITIES:
    * Tracks recently moved item uniqueIds
    * Provides flash animation via color manipulation
    * Auto-clears items from tracking after animation completes
]]

if not BETTERUI.CIM then BETTERUI.CIM = {} end
if not BETTERUI.CIM.UI then BETTERUI.CIM.UI = {} end

-------------------------------------------------------------------------------------------------
-- CONSTANTS
-------------------------------------------------------------------------------------------------

local FLASH_DURATION_MS = 500                                 -- Total duration of flash effect (0.5 seconds)
local FLASH_COLOR = { r = 0.77, g = 0.65, b = 0.30, a = 1.0 } -- Gold color (#C4A64D)
local CLEAR_DELAY_MS = 1000                                   -- Time to keep item in tracking before clearing

-------------------------------------------------------------------------------------------------
-- MODULE STATE
-------------------------------------------------------------------------------------------------

local ItemFlashAnimation = {
    -- Set of uniqueIds for items that should flash
    recentlyMovedItems = {},
    -- Timer references for cleanup
    timers = {},
}

BETTERUI.CIM.UI.ItemFlashAnimation = ItemFlashAnimation

-------------------------------------------------------------------------------------------------
-- PUBLIC API
-------------------------------------------------------------------------------------------------

--[[
Function: ItemFlashAnimation.RegisterMovedItem
Description: Marks an item as recently moved so it will flash when displayed.
             Automatically unregisters after CLEAR_DELAY_MS.
param: uniqueId (number|string) - The item's unique identifier.
]]
--- @param uniqueId number|string The item's unique identifier
function ItemFlashAnimation.RegisterMovedItem(uniqueId)
    if not uniqueId then return end

    -- Convert to string for consistent key lookup
    local key = tostring(uniqueId)
    ItemFlashAnimation.recentlyMovedItems[key] = true

    -- Schedule auto-cleanup
    local timerName = "ItemFlash_" .. key
    ItemFlashAnimation.timers[key] = timerName

    zo_callLater(function()
        ItemFlashAnimation.ClearFlash(uniqueId)
    end, CLEAR_DELAY_MS)
end

--[[
Function: ItemFlashAnimation.IsMarkedForFlash
Description: Checks if an item is marked for flash animation.
param: uniqueId (number|string) - The item's unique identifier.
return: boolean - True if item should flash.
]]
--- @param uniqueId number|string The item's unique identifier
--- @return boolean shouldFlash True if item should flash
function ItemFlashAnimation.IsMarkedForFlash(uniqueId)
    if not uniqueId then return false end
    return ItemFlashAnimation.recentlyMovedItems[tostring(uniqueId)] == true
end

--[[
Function: ItemFlashAnimation.ClearFlash
Description: Removes an item from the flash tracking.
param: uniqueId (number|string) - The item's unique identifier.
]]
--- @param uniqueId number|string The item's unique identifier
function ItemFlashAnimation.ClearFlash(uniqueId)
    if not uniqueId then return end
    local key = tostring(uniqueId)
    ItemFlashAnimation.recentlyMovedItems[key] = nil
    ItemFlashAnimation.timers[key] = nil
end

--[[
Function: ItemFlashAnimation.ClearAll
Description: Clears all flash tracking. Call when leaving scene.
]]
function ItemFlashAnimation.ClearAll()
    ItemFlashAnimation.recentlyMovedItems = {}
    ItemFlashAnimation.timers = {}
end

--[[
Function: ItemFlashAnimation.ApplyFlash
Description: Applies the flash animation to a list row control if the item is marked.
             Uses the SelectionBar child for the flash effect.
param: control (table) - The list row control.
param: uniqueId (number|string) - The item's unique identifier.
return: boolean - True if flash was applied.
]]
--- @param control table The list row control
--- @param uniqueId number|string The item's unique identifier
--- @return boolean applied True if flash was applied
function ItemFlashAnimation.ApplyFlash(control, uniqueId)
    if not control or not uniqueId then return false end
    if not ItemFlashAnimation.IsMarkedForFlash(uniqueId) then return false end

    -- Find the SelectionBar child control for the flash effect
    local selectionBar = control:GetNamedChild("SelectionBar")
    if not selectionBar then return false end

    -- Show the selection bar with gold color
    selectionBar:SetHidden(false)
    selectionBar:SetColor(FLASH_COLOR.r, FLASH_COLOR.g, FLASH_COLOR.b, FLASH_COLOR.a)
    selectionBar:SetAlpha(1.0)

    -- Start the fade-out animation
    local startTime = GetFrameTimeMilliseconds()
    local function AnimateFlash()
        local elapsed = GetFrameTimeMilliseconds() - startTime
        if elapsed >= FLASH_DURATION_MS then
            -- Animation complete, reset the bar
            selectionBar:SetAlpha(0.45) -- Normal alpha for selection bar
            selectionBar:SetHidden(true)
            -- Clear from tracking
            ItemFlashAnimation.ClearFlash(uniqueId)
            return
        end

        -- Calculate fade progress (0.0 to 1.0)
        local progress = elapsed / FLASH_DURATION_MS
        -- Ease-out curve for smooth fade
        local alpha = 1.0 - (progress * progress)

        selectionBar:SetAlpha(alpha)

        -- Continue animation on next frame
        zo_callLater(AnimateFlash, 16) -- ~60fps
    end

    AnimateFlash()
    return true
end

--[[
Function: ItemFlashAnimation.ApplyFlashToRow
Description: Simplified version that extracts uniqueId from entry data.
param: control (table) - The list row control.
param: entryData (table) - The entry data containing uniqueId.
return: boolean - True if flash was applied.
]]
--- @param control table The list row control
--- @param entryData table The entry data containing uniqueId
--- @return boolean applied True if flash was applied
function ItemFlashAnimation.ApplyFlashToRow(control, entryData)
    if not entryData then return false end

    -- Extract uniqueId from various data structures
    local uniqueId = nil
    if entryData.dataSource and entryData.dataSource.uniqueId then
        uniqueId = entryData.dataSource.uniqueId
    elseif entryData.uniqueId then
        uniqueId = entryData.uniqueId
    elseif entryData.bagId and entryData.slotIndex then
        -- Fallback: get uniqueId from bag/slot
        uniqueId = GetItemUniqueId(entryData.bagId, entryData.slotIndex)
    end

    return ItemFlashAnimation.ApplyFlash(control, uniqueId)
end
