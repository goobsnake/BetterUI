--[[
File: Modules/CIM/Core/Types.lua
Purpose: Shared EmmyLua type definitions for BetterUI.
         Provides centralized type annotations used across all modules.

This file should be loaded early in the CIM module load order.
It defines types that are referenced by annotations throughout the codebase.
]]

BETTERUI.CIM = BETTERUI.CIM or {}
BETTERUI.CIM.Types = {}

-- ESO API TYPE STUBS
-- These definitions help the IDE understand ESO's global types


-- CORE ITEM DATA TYPES


-- CATEGORY TYPES


-- SORTING TYPES


---| "name"
---| "quality"
---| "stackCount"
---| "level"
---| "value"
---| "type"
---| "trait"
---| "status"


-- MODULE TYPES

---| "Inventory"
---| "Banking"
---| "ResourceOrbFrames"
---| "WritUnit"
---| "CIM"


-- SCENE & LIFECYCLE TYPES


-- KEYBIND TYPES


-- UI TYPES


-- CALLBACK EVENT NAMES

---| "BETTERUI_EVENT_ACTION_DIALOG_SETUP"
---| "BETTERUI_EVENT_ACTION_DIALOG_FINISH"
---| "BETTERUI_EVENT_ACTION_DIALOG_BUTTON_CONFIRM"
---| "BetterUI_ForceLayoutUpdate"
---| "BETTERUI_EVENT_INVENTORY_REFRESH"
---| "BETTERUI_EVENT_BANK_REFRESH"

-- TIMING CONSTANTS TYPE


-- FEATURE FLAGS TYPE


