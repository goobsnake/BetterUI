--[[
File: Modules/Banking/Core/BankingClass.lua
Purpose: Core class definition and module-scope state for the Banking module.
         Establishes the Banking class skeleton and shared constants.
Author: BetterUI Team
Last Modified: 2026-01-26

This file is part of the Banking module decomposition. It contains:
1. Module-scope constants (LIST_WITHDRAW, LIST_DEPOSIT, bank state)
2. Shared references from CIM module
3. Class definition extending BETTERUI.Interface.Window
4. Constructor (New) method

Other Banking files extend this class with additional functionality.
]]

-------------------------------------------------------------------------------------------------
-- MODULE-SCOPE CONSTANTS
-------------------------------------------------------------------------------------------------
-- These constants are shared across all Banking module files via BETTERUI.Banking namespace.

-- List mode constants for tracking Withdraw vs Deposit state
BETTERUI.Banking.LIST_WITHDRAW                 = 1
BETTERUI.Banking.LIST_DEPOSIT                  = 2

-- Module-scope state tracking (accessed via BETTERUI.Banking namespace)
BETTERUI.Banking.lastUsedBank                  = 0
BETTERUI.Banking.currentUsedBank               = 0
BETTERUI.Banking.esoSubscriber                 = nil

-------------------------------------------------------------------------------------------------
-- SHARED CATEGORY REFERENCES
-------------------------------------------------------------------------------------------------
-- Use centralized category definitions from CIM module to eliminate duplication.
-- These were previously defined locally as BANK_CATEGORY_DEFS and BANK_CATEGORY_ICONS.
-- See: Modules/CIM/CategoryDefinitions.lua for the source definitions.
-------------------------------------------------------------------------------------------------
BETTERUI.Banking.CATEGORY_DEFS                 = BETTERUI.Inventory.Categories.Bank

-- Reference to shared interface utilities
BETTERUI.Banking.EnsureKeybindGroupAdded       = BETTERUI.Interface.EnsureKeybindGroupAdded
BETTERUI.Banking.CreateSearchKeybindDescriptor = BETTERUI.Interface.CreateSearchKeybindDescriptor

-------------------------------------------------------------------------------------------------
-- CLASS DEFINITION
-------------------------------------------------------------------------------------------------

--[[
Class: BETTERUI.Banking.Class
Description: Main class for the Banking module window.
Rationale: Subclasses BETTERUI.CIM.GenericWindow to provide a custom banking experience.
Mechanism: Inherits from GenericWindow base class to leverage shared header, footer, and list functionality.
]]
BETTERUI.Banking.Class = BETTERUI.CIM.GenericWindow:Subclass()

--[[
Function: BETTERUI.Banking.Class:New
Description: Creates a new instance of the Banking window class.
Rationale: Constructor for the Banking module.
Mechanism: Inherits from BETTERUI.CIM.GenericWindow.
param: ... (any) - Arguments passed to the parent constructor.
return: table - The new Banking Class instance.
]]
function BETTERUI.Banking.Class:New(...)
    return BETTERUI.CIM.GenericWindow.New(self, ...)
end

--[[
Function: BETTERUI.Banking.Class:IsSceneShowing
Description: Checks if the banking scene is currently showing.
Rationale: Delegates to CIM utility for consistent scene checks across all modules.
return: boolean - True if the banking scene is currently showing.
]]
function BETTERUI.Banking.Class:IsSceneShowing()
    return BETTERUI.CIM.Utils.IsBankingSceneShowing()
end
