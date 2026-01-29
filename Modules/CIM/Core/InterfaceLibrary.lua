--[[
File: Modules/CIM/InterfaceLibrary.lua
Purpose: Loader/namespace for CIM interface components.
         Actual implementations are in Core/ subdirectory.
Author: BetterUI Team
Last Modified: 2026-01-26

-- The implementations have been extracted to:
--   - Core/KeybindHelpers.lua  - EnsureKeybindGroupAdded utility
--   - Core/TooltipLayout.lua   - SetTooltipWidth function
--   - Core/SearchManager.lua   - Search functionality + SearchMixin
--   - Core/WindowClass.lua     - BETTERUI.Interface.Window base class

This file now serves as:
  1. A namespace initializer (backwards compatibility)
  2. A load-order verification point
]]

-- Ensure namespaces exist (may already be set in Globals.lua or earlier files)
BETTERUI.Interface = BETTERUI.Interface or {}
BETTERUI.CIM = BETTERUI.CIM or {}

-- ============================================================================
-- LOAD ORDER VERIFICATION
-- Verify that required components were loaded by the files before this one.
-- If any assertion fails, the manifest (BetterUI.txt) load order is incorrect.
-- ============================================================================

assert(BETTERUI.Interface.EnsureKeybindGroupAdded,
  "BetterUI Load Error: KeybindHelpers.lua must be loaded before InterfaceLibrary.lua")

assert(BETTERUI.CIM.SetTooltipWidth,
  "BetterUI Load Error: TooltipLayout.lua must be loaded before InterfaceLibrary.lua")

assert(BETTERUI.Interface.CreateSearchKeybindDescriptor,
  "BetterUI Load Error: SearchManager.lua must be loaded before InterfaceLibrary.lua")

assert(BETTERUI.Interface.Window,
  "BetterUI Load Error: WindowClass.lua must be loaded before InterfaceLibrary.lua")

-- ============================================================================
-- BACKWARDS COMPATIBILITY NOTES
-- ============================================================================
--[[
All public APIs remain at their original locations:
  - BETTERUI.Interface.Window                    (WindowClass.lua)
  - BETTERUI.Interface.EnsureKeybindGroupAdded   (KeybindHelpers.lua)
  - BETTERUI.Interface.CreateSearchKeybindDescriptor (SearchManager.lua)
  - BETTERUI.CIM.SetTooltipWidth                 (TooltipLayout.lua)

Scene constants moved to Banking module:
  - BETTERUI_BANKING_SCENE_NAME                  (Banking/Constants.lua)
  - BETTERUI.Banking.BANKING_INTERACTION         (Banking/Constants.lua)

Scene creation moved to Banking module:
  - BETTERUI_BANKING_SCENE creation              (Banking/Banking.lua)
]]
