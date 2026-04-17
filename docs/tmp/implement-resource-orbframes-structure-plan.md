# Implementation Plan: `resource-orbframes-structure` Cluster

## 1. Desloppify Commands & Current Queue State

**Cluster ID:** `resource-orbframes-structure`  
**Status:** `active` (first-wave, priority 4)  
**Issue Count:** 5 open review defects  
**Execution Policy:** `planned_only` (manual fix required)

### Relevant desloppify commands
```bash
# Show all open review issues for this cluster
desloppify show review --status open

# Show cluster details from plan
desloppify plan --cluster resource-orbframes-structure

# Revalidate after changes
desloppify scan
```

### Queued Items (Exact Issue IDs)
| Issue ID | Dimension | Tier | File Focus |
|---|---|---|---|
| `review::.::holistic::abstraction_fitness::rof-settings-callback-bag` | abstraction_fitness | 1 | `Module.lua`, `SettingsSubmenus.lua` |
| `review::.::holistic::abstraction_fitness::rof-utils-dumping-ground` | abstraction_fitness | 2 | `Core/Utils.lua` |
| `review::.::holistic::convention_outlier::resource-orbframes-init-protocol-split` | convention_outlier | 1 | `Module.lua`, `Settings/Defaults.lua` |
| `review::.::holistic::mid_level_elegance::resource_orb_accessor_bundle` | mid_level_elegance | 1 | `Module.lua`, `SettingsSubmenus.lua` |
| `review::.::holistic::naming_quality::resource_orb_offset_y_accessor_asymmetry` | naming_quality | 1 | `Module.lua` |

---

## 2. Specific Code Structure Problems to Fix

### Problem A: `getOffset` / `setOffset` naming asymmetry (`resource_orb_offset_y_accessor_asymmetry`)
**Location:** `Modules/ResourceOrbFrames/Module.lua:76`, `:168-169`

`offsetX` uses `getOffsetX` / `setOffsetX`, but `offsetY` uses `getOffset` / `setOffset`.

**Fix:**
- Rename `local getOffset, setOffset = GetSet("offsetY", ...)` → `local getOffsetY, setOffsetY = GetSet("offsetY", ...)`
- Update the offset-Y slider at lines 168–169 to use `getFunc = getOffsetY`, `setFunc = setOffsetY`
- No other files reference these locals.

---

### Problem B: `InitModule` located in `Settings/Defaults.lua` instead of root `Module.lua` (`resource-orbframes-init-protocol-split`)
**Location:** `Modules/ResourceOrbFrames/Settings/Defaults.lua:119`  
**Contrast:** Sibling modules (`Inventory`, `Banking`, `Vendor`, `Companions`, `TradingHouse`) all expose `InitModule` from their root `Module.lua`.

**Fix:**
1. Move the `BETTERUI.ResourceOrbFrames.InitModule(m_options)` function body from `Settings/Defaults.lua` to `Module.lua`.
2. In `Module.lua`, place it alongside `BETTERUI.ResourceOrbFrames.Setup()` (or immediately above/below).
3. Keep `GetDefaults()` and `NormalizeNumericSettings()` in `Defaults.lua` — they are settings helpers.
4. In `Defaults.lua`, replace the moved function with:
   ```lua
   -- InitModule is defined in the root Module.lua for protocol consistency
   ```
   or simply remove it and re-export `GetDefaults` as before.
5. Update `BetterUI.txt` load order if necessary (it is not — `Module.lua` already loads after `Defaults.lua`).

---

### Problem C: Monolithic `submenuAccessors` callback bag (`rof-settings-callback-bag`, `resource_orb_accessor_bundle`)
**Location:** `Modules/ResourceOrbFrames/Module.lua:202-247` and `Settings/SettingsSubmenus.lua`

`Module.lua` builds a flat table of ~38 closures and passes it to three submenu builders. Adding one setting requires touching declaration, bag assembly, and submenu consumer.

**Fix (minimal, preserves behavior):**
Replace the flat `submenuAccessors` bag with **section-scoped descriptor tables**. The individual `getX`/`setX` closures can stay (they are cheap), but group them by semantic section before passing to builders.

**Before (simplified):**
```lua
local submenuAccessors = {
    getCooldownSize = getCooldownSize, setCooldownSize = setCooldownSize,
    getHealthSize = getHealthSize, setHealthSize = setHealthSize,
    -- ... 36 more entries
}
BuildSubmenus.BuildSkillBarsSubmenu(submenuAccessors)
```

**After:**
```lua
local sections = {
    skillBars = {
        getCooldownSize = getCooldownSize, setCooldownSize = setCooldownSize,
        -- ... skill-bar only accessors
    },
    orbText = {
        getHealthSize = getHealthSize, setHealthSize = setHealthSize,
        -- ... orb-text only accessors
    },
    bars = {
        getXpEnabled = getXpEnabled, setXpEnabled = setXpEnabled,
        -- ... xp/cast/mount accessors
    },
    helpers = {
        GetSettings = GetResourceOrbSettings,
        ResetSettingsGroup = ResetSettingsGroup,
    },
}

optionsTable[#optionsTable + 1] = BuildSubmenus.BuildSkillBarsSubmenu(sections.skillBars, sections.helpers)
optionsTable[#optionsTable + 1] = BuildSubmenus.BuildOrbTextSubmenu(sections.orbText, sections.helpers)
local xpSub, castSub, mountSub = BuildSubmenus.BuildBarSubmenus(sections.bars, sections.helpers)
```

Then update `SettingsSubmenus.lua` signatures:
- `BuildSkillBarsSubmenu(skillAccessors, helpers)`
- `BuildOrbTextSubmenu(orbAccessors, helpers)`
- `BuildBarSubmenus(barAccessors, helpers)`

Inside each builder, prefix accessor references:
- `a.getCooldownSize` → `skill.getCooldownSize` (or keep `a = skillAccessors` alias)
- `a.GetSettings()` → `helpers.GetSettings()`
- `a.ResetSettingsGroup({...})` → `helpers.ResetSettingsGroup({...})`

This eliminates the wide bag without changing LAM control definitions or behavior.

---

### Problem D: `Core/Utils.lua` is a low-cohesion dumping ground (`rof-utils-dumping-ground`)
**Location:** `Modules/ResourceOrbFrames/Core/Utils.lua`

The file mixes:
- Text-size clamping (`ClampTextSize`)
- Settings access (`GetSettings`)
- Tooltip attachment (`AddOrbTooltip`)
- Border/fill layout math (`CalculateBorderSizes`, `CalculateFillDimensions`, `ScaleForBorder`)
- Overlay resizing (`UpdateOverlaySize`)
- Control lookup (`FindControl` alias, `GetNamedChildDirect`, `GetFrontBarButtonControl`)

**Fix (minimal, preserves all external references):**
Split by role into new files, but **keep `Utils.lua` as a compatibility re-export hub** so existing callers (9+ files) do not break.

1. Create `Modules/ResourceOrbFrames/Core/LayoutMath.lua`
   - `ClampTextSize`, `ScaleForBorder`, `CalculateBorderSizes`, `CalculateFillDimensions`
2. Create `Modules/ResourceOrbFrames/Core/ControlHelpers.lua`
   - `GetNamedChildDirect`, `GetFrontBarButtonControl`, `AddOrbTooltip`, `UpdateOverlaySize`
3. Keep `Utils.lua` as a thin proxy:
   ```lua
   local LayoutMath = BETTERUI.ResourceOrbFrames.LayoutMath
   local ControlHelpers = BETTERUI.ResourceOrbFrames.ControlHelpers
   
   Utils.ClampTextSize = LayoutMath.ClampTextSize
   Utils.ScaleForBorder = LayoutMath.ScaleForBorder
   Utils.CalculateBorderSizes = LayoutMath.CalculateBorderSizes
   Utils.CalculateFillDimensions = LayoutMath.CalculateFillDimensions
   Utils.GetNamedChildDirect = ControlHelpers.GetNamedChildDirect
   Utils.GetFrontBarButtonControl = ControlHelpers.GetFrontBarButtonControl
   Utils.AddOrbTooltip = ControlHelpers.AddOrbTooltip
   Utils.UpdateOverlaySize = ControlHelpers.UpdateOverlaySize
   Utils.FindControl = BETTERUI.ControlUtils.FindControl
   Utils.GetSettings = BETTERUI.GetModuleSettings("ResourceOrbFrames")
   ```
4. Update `BetterUI.txt` to load the two new files **before** `Utils.lua`:
   ```
   Modules\ResourceOrbFrames\Core\LayoutMath.lua
   Modules\ResourceOrbFrames\Core\ControlHelpers.lua
   Modules\ResourceOrbFrames\Core\Utils.lua
   ```

This satisfies the "split by role" suggestion without touching every caller.

---

## 3. Minimal Validation Commands to Run After Changes

```bash
# 1. Syntax check all touched Lua files
find Modules/ResourceOrbFrames -name '*.lua' -exec luac -p {} \;

# 2. Run the existing unit-test suite (includes settings reset and orb-bars tests)
cd /workspace && lua tools/tests/run_all_tests.lua

# 3. If available, run MCP test validation for Lua syntax
test_validate luac_syntax --workDir /workspace \
  Modules/ResourceOrbFrames/Module.lua \
  Modules/ResourceOrbFrames/Settings/Defaults.lua \
  Modules/ResourceOrbFrames/Settings/SettingsSubmenus.lua \
  Modules/ResourceOrbFrames/Core/Utils.lua \
  Modules/ResourceOrbFrames/Core/LayoutMath.lua \
  Modules/ResourceOrbFrames/Core/ControlHelpers.lua

# 4. Rescan with desloppify to confirm issues close
desloppify scan
```

---

## 4. Risks About Preserving Behavior

| Risk | Mitigation |
|---|---|
| **InitModule move** breaks `test_settings_reset.lua` mock or `DefaultsRegistry` expectations. | `test_settings_reset.lua:142` defines its own stub `BETTERUI.ResourceOrbFrames.InitModule`. Moving the real implementation to `Module.lua` does not affect the test stub because the test sets up its own globals. Verify `test_defaults_registry.lua` still sees `BETTERUI.Defaults.Modules.ResourceOrbFrames` populated. |
| **Utils split** breaks 9+ callers that reference `BETTERUI.ResourceOrbFrames.Utils.*`. | Keep `Utils.lua` as a **read-only proxy** (no behavior change). Do not remove any exported field. |
| **Accessor bag refactor** accidentally drops a setting closure. | The `getX`/`setX` locals in `Module.lua` remain identical; only the *packaging* changes. Do a line-count match before/after to ensure no accessor is lost. |
| **SettingsSubmenus signature change** breaks other callers. | `BuildSkillBarsSubmenu`, `BuildOrbTextSubmenu`, and `BuildBarSubmenus` are private to `Module.lua`. No external file calls them. |
| **Rename `getOffset` → `getOffsetY`** misses a reference. | Only `Module.lua:76` and `:168-169` use these locals. `OrbAnimations.lua` uses `targetOffsetY` as a parameter name, not as a reference to the accessor. |
| **Load order regression** from adding `LayoutMath.lua` / `ControlHelpers.lua`. | Insert them immediately before `Utils.lua` in `BetterUI.txt`. `Utils.lua` must load after them so it can index their tables. |

---

## 5. Suggested Edit Order (Cluster-Scoped)

1. **Rename accessors** (`getOffset` → `getOffsetY`) in `Module.lua`
2. **Move `InitModule`** from `Settings/Defaults.lua` to `Module.lua`
3. **Create `LayoutMath.lua` and `ControlHelpers.lua`**, thin out `Utils.lua`
4. **Update `BetterUI.txt`** load order for the two new files
5. **Refactor `submenuAccessors`** into section tables in `Module.lua`
6. **Update `SettingsSubmenus.lua`** signatures and internal references
7. **Run validation commands** (syntax + tests + scan)
