---
description: Create a new BetterUI module with the standard Minimal Root folder structure and boilerplate files
---

# Scaffold Module Workflow

Automates creation of a new BetterUI module following the **Minimal Root** organizational pattern.

## Prerequisites

See `AGENTS.md` for project context and `docs/ARCHITECTURE.md` Section 3 for Minimal Root structure.

---

## Parameters

- **ModuleName**: The name of the new module (e.g., `QuestTracker`, `GuildStore`)
  - Usage: `/scaffold-module QuestTracker`
  - Must be PascalCase
  - Will be used for folder name and namespace

---

## Step 1: Create Directory Structure

Create the standard Minimal Root structure under `Modules/{ModuleName}/`:

```
{ModuleName}/
├── Constants.lua          # Module-specific constants
├── Module.lua             # Entry point, settings registration
├── Core/                  # Core logic, utilities
├── UI/                    # Visual components
├── Lists/                 # List management (if applicable)
├── Actions/               # Action handlers (if applicable)
├── Keybinds/              # Keybind definitions (if applicable)
├── State/                 # State management (if applicable)
├── Settings/              # LAM settings panels (if applicable)
├── Templates/             # XML templates
└── Images/                # UI assets (.dds files)
```

> [!NOTE]
> Not all subfolders are required. Create only what the module needs.
> At minimum: `Constants.lua`, `Module.lua`, and `Core/` folder.

---

## Step 2: Generate Constants.lua

Create the constants file with the standard header:

```lua
--[[
    BetterUI {ModuleName} Module Constants
    --------------------------------------
    Module-specific constants and configuration values.
    
    @module     {ModuleName}
    @file       Constants.lua
    @created    {YYYY-MM-DD}
    @updated    {YYYY-MM-DD}
]]--

BETTERUI.{ModuleName} = BETTERUI.{ModuleName} or {}
BETTERUI.{ModuleName}.CONST = {}

local CONST = BETTERUI.{ModuleName}.CONST

-- ============================================================================
-- MODULE IDENTIFICATION
-- ============================================================================

CONST.MODULE_NAME = "{ModuleName}"
CONST.MODULE_VERSION = "1.0.0"

-- ============================================================================
-- TIMING CONSTANTS
-- ============================================================================

CONST.TIMING = {
    REFRESH_DELAY_MS = 100,
}

-- ============================================================================
-- UI CONSTANTS
-- ============================================================================

CONST.UI = {
    -- Add UI-specific constants here
}
```

---

## Step 3: Generate Module.lua

Create the module entry point:

```lua
--[[
    BetterUI {ModuleName} Module
    ----------------------------
    Entry point and settings registration for the {ModuleName} module.
    
    @module     {ModuleName}
    @file       Module.lua
    @created    {YYYY-MM-DD}
    @updated    {YYYY-MM-DD}
]]--

local CONST = BETTERUI.{ModuleName}.CONST

-- ============================================================================
-- MODULE SETUP
-- ============================================================================

---Setup function called by BetterUI.lua during addon initialization.
---Registers settings panel and initializes module components.
function BETTERUI.{ModuleName}.Setup()
    -- Register settings panel
    local Init, AddElement, HideElement, AddCategory, GetSet = BETTERUI.SettingsAccessor()
    Init(CONST.MODULE_NAME, "{Module Display Name}")
    
    -- Add settings here
    -- local getSetting, setSetting = GetSet("settingName", defaultValue)
    -- AddElement("slider", "Setting Name", "Description", min, max, step, getSetting, setSetting)
    
    -- Initialize module
    BETTERUI.{ModuleName}.Init()
end

---Initialize module components after settings are loaded.
function BETTERUI.{ModuleName}.Init()
    -- Module initialization logic here
end
```

---

## Step 4: Update Manifest

Add entries to `BetterUI.txt` in the correct load order:

```
## After CIM, before other feature modules

; {ModuleName} Module
Modules/{ModuleName}/Constants.lua
Modules/{ModuleName}/Module.lua
; Add Core/*.lua files here as they are created
```

> [!IMPORTANT]
> Manifest order matters! Ensure `Constants.lua` loads before `Module.lua`.

---

## Step 5: Register in BetterUI.lua

Add the module's Setup() call in `BetterUI.lua`:

```lua
-- In the initialization function, after other module setups:
if BETTERUI.{ModuleName} then
    BETTERUI.{ModuleName}.Setup()
end
```

---

## Step 6: Verify

1. Load the game with the addon enabled
2. Check for Lua errors in chat
3. Verify the settings panel appears (if registered)

---

## Quick Invocation

```
/scaffold-module ModuleName
```

Example:
```
/scaffold-module QuestTracker
```

---

## Output

After running this workflow, you'll have:

| File | Purpose |
|------|---------|
| `Modules/{ModuleName}/Constants.lua` | Module constants with header |
| `Modules/{ModuleName}/Module.lua` | Entry point with Setup() |
| `Modules/{ModuleName}/Core/` | Empty folder ready for utilities |
| Updated `BetterUI.txt` | Manifest entries |
| Updated `BetterUI.lua` | Module registration |

---

## Next Steps

After scaffolding:
1. Implement core logic in `Core/` files
2. Add UI components in `UI/` if needed
3. Create XML templates in `Templates/` if needed
4. Expand settings in `Module.lua` as features are added

