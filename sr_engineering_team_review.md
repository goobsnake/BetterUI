# BetterUI Sr. Engineering Team Review

**Review Date**: 2026-02-03
**Review Type**: Comprehensive Codebase Audit
**Files Reviewed**: 124 of ~124 Lua files

## Summary

This review evaluates the BetterUI codebase against the standards defined in `betterui-development-guidelines`. The Sr. Engineering Team conducted per-module reviews followed by consolidated verdicts.

---

## Per-Module Verdicts

### CIM Module

| Role | Verdict | Key Finding |
|------|---------|-------------|
| Lua Architect | PASS | CIM patterns well-established, good module boundaries |
| UI/UX Specialist | PASS | SceneLifecycleManager handles scene transitions properly |
| Code Quality Lead | FAIL | Missing nil-checks on GetNamedChild chains (GenericHeader.lua:88-94) |
| Sr. Software Developer | FAIL | Nil-checks missing in WindowClass.lua:155 |
| QA Gatekeeper | PASS | DeferredTask and EventRegistry provide good cleanup |

### Inventory Module

| Role | Verdict | Key Finding |
|------|---------|-------------|
| Lua Architect | PASS | Good separation of concerns with Core/, Lists/, Actions/ |
| UI/UX Specialist | PASS | Keybind integration follows ESO patterns |
| Code Quality Lead | FAIL | Magic numbers scattered in TooltipUtils.lua |
| Sr. Software Developer | FAIL | Batch operations lack nil-checks (InventoryClass.lua:728+) |
| QA Gatekeeper | FAIL | Silent failures in batch operations, no user feedback |

### Banking Module

| Role | Verdict | Key Finding |
|------|---------|-------------|
| Lua Architect | PASS | Minimal root pattern followed |
| UI/UX Specialist | FAIL | Aggressive RemoveAllKeyButtonGroups could break other addons |
| Code Quality Lead | FAIL | DRY violation in bag setup logic (BankListManager.lua) |
| Sr. Software Developer | FAIL | Multiple nil-check issues (FooterManager.lua:23-38) |
| QA Gatekeeper | PASS | StateManager properly tracks positions |

### ResourceOrbFrames Module

| Role | Verdict | Key Finding |
|------|---------|-------------|
| Lua Architect | FAIL | Unsafe scene manager monkey-patching (OrbEvents.lua:77-92) |
| UI/UX Specialist | PASS | Animation system well-implemented |
| Code Quality Lead | FAIL | Slot mappings duplicated 4+ times in FrontBarManager.lua |
| Sr. Software Developer | FAIL | Double initialization risk, fragment API unguarded |
| QA Gatekeeper | FAIL | Event cleanup verification missing |

### WritUnit Module

| Role | Verdict | Key Finding |
|------|---------|-------------|
| Lua Architect | PASS | Simple, focused module |
| UI/UX Specialist | PASS | Clean crafting station integration |
| Code Quality Lead | PASS | Good header compliance |
| Sr. Software Developer | PASS | Proper nil-checks in place |
| QA Gatekeeper | PASS | Control caching for performance |

---

## Consolidated Verdicts

### **Lua Architect**: FAIL
**Focus**: Module design, CIM patterns, inheritance, architecture

- CIM infrastructure is well-designed with proper patterns
- Minimal Root structure followed across modules
- **FAIL**: ResourceOrbFrames monkey-patching is architecturally risky
- **FAIL**: Missing centralized nil-check utilities

**TODO(architecture)**:
- [ ] Create CIM.Utils.SafeGetNamedChild for chained lookups (WindowClass.lua, GenericHeader.lua, etc.)
- [ ] Refactor OrbEvents.lua monkey-patching to use safer hook pattern

---

### **UI/UX Specialist**: FAIL
**Focus**: Gamepad flow, accessibility, ESO native parity

- Scene lifecycle management generally follows ESO patterns
- Keybind integration is consistent within modules
- **FAIL**: KeybindManager.lua:54 uses RemoveAllKeyButtonGroups() which is too aggressive

**TODO(refactor)**:
- [ ] Replace RemoveAllKeyButtonGroups() with specific group removal in Banking/Keybinds/KeybindManager.lua:54
- [ ] Add error feedback for batch operations in Inventory

---

### **Code Quality Lead**: FAIL
**Focus**: Standards compliance, documentation, style

- File headers present on 122+ files (excellent)
- TODO format mostly compliant
- **FAIL**: Magic numbers in 15+ locations
- **FAIL**: DRY violations in RuntimeSetup.lua, FrontBarManager.lua, BankListManager.lua
- **FAIL**: Duplicate comments in SearchManager.lua:104-105, Module.lua:71-72

**TODO(cleanup)**:
- [ ] Remove duplicate comment in Banking/Search/SearchManager.lua:104-105
- [ ] Remove duplicate comment in Inventory/Module.lua:71-72
- [ ] Remove duplicate comment in ResourceOrbFrames/Constants.lua:354-355
- [ ] Fix FUTURE: format to TODO(type): in WritUnit/Core/Writ.lua:12
- [ ] Fix FUTURE: format to TODO(type): in Inventory/Actions/SlotActions.lua:36

**TODO(refactor)**:
- [ ] Extract icon patching pattern in CIM/Core/RuntimeSetup.lua:53-116
- [ ] Extract bag setup logic in Banking/Lists/BankListManager.lua:104-116
- [ ] Use SkillBar.CONST.FRONT_BAR_SLOTS in FrontBarManager.lua
- [ ] Extract reset patterns in ResourceOrbFrames/Module.lua

---

### **Sr. Software Developer**: FAIL
**Focus**: Implementation patterns, clean code, error handling

- Error handling with SafeExecute is well-implemented
- Guard clauses used appropriately in many places
- **FAIL**: 19 CRITICAL nil-check issues across all modules
- **FAIL**: FrontBarManager.lua:517 has suspicious assignment (durationMs = remainMs)

**TODO(fix)**:
- [ ] Add nil-check in CIM/Core/WindowClass.lua:155 before GetList():RefreshVisible()
- [ ] Add nil-checks in CIM/UI/GenericHeader.lua:88-94 for chained GetNamedChild
- [ ] Add nil-check in CIM/UI/GenericHeader.lua:97-98 for tabBarControl
- [ ] Add nil-check in CIM/UI/GenericFooter.lua:68 for invSettings chain
- [ ] Add nil-check in Inventory/Core/InventoryClass.lua:728,744,759,774,792,807 for batch items
- [ ] Add nil-checks in Inventory/Lists/InventoryList.lua:387-396 for control references
- [ ] Add nil-check in Inventory/Lists/ItemListManager.lua:615-620 for tooltip access
- [ ] Add nil-check in Inventory/Keybinds/InventoryKeybinds.lua:287 for targetData
- [ ] Add nil-check in Inventory/UI/TooltipUtils.lua:284 for itemLink
- [ ] Add nil-checks in Banking/UI/FooterManager.lua:23-38 for nested footer access
- [ ] Add nil-check in Banking/Module.lua:58-59 for Settings chain
- [ ] Add nil-check in Banking/Keybinds/KeybindManager.lua:42 for ZO_GamepadBanking
- [ ] Add nil-check in Banking/Dialogs/QuantityDialog.lua:44 for setupFunc
- [ ] Fix category access in Banking/Lists/BankListManager.lua:179-181
- [ ] Add existence check in ResourceOrbFrames/Core/OrbEvents.lua:77-92 for SCENE_MANAGER methods
- [ ] Add nil-check in ResourceOrbFrames/ResourceOrbFrames.lua:301,336 for PLAYER_ATTRIBUTE_BARS_FRAGMENT
- [ ] Add initialization guard in ResourceOrbFrames/ResourceOrbFrames.lua:315-362
- [ ] Fix durationMs assignment in ResourceOrbFrames/SkillBar/FrontBarManager.lua:516-517
- [ ] Add nil-check in ResourceOrbFrames/ResourceOrbFrames.lua:72-75 for pool access

---

### **QA Gatekeeper**: FAIL
**Focus**: Testing strategy, verification, edge cases

- DeferredTask and EventRegistry provide good async cleanup
- Position persistence works correctly
- **FAIL**: Batch operations fail silently with no user feedback
- **FAIL**: Event registration cleanup not verified in ResourceOrbFrames

**TODO(architecture)**:
- [ ] Add user feedback (UI message or sound) when batch operations fail in InventoryClass.lua
- [ ] Verify event cleanup in ResourceOrbFrames/Core/OrbEvents.lua:59-74

---

## Overall: BLOCKED

19 CRITICAL issues must be addressed before deployment.

---

## Priority Issues Summary

| Priority | Issue | Module | Owner | Effort |
|----------|-------|--------|-------|--------|
| P0 | 19 nil-check crashes | All | Sr. Developer | 2-3 hours |
| P1 | DRY violations | CIM, Banking, ROF | Quality Lead | 1-2 hours |
| P1 | Magic numbers extraction | Inventory, ROF | Quality Lead | 1-2 hours |
| P2 | Duplicate comments | Multiple | Quality Lead | 15 min |
| P2 | TODO format fixes | WritUnit, Inventory | Quality Lead | 5 min |
| P2 | Aggressive keybind removal | Banking | UI/UX | 30 min |
| P3 | Test scene name | Banking | Developer | 5 min |

---

## All TODOs by Type

### TODO(architecture)
- [ ] Create CIM.Utils.SafeGetNamedChild helper for chained lookups
- [ ] Refactor OrbEvents.lua monkey-patching to safer pattern
- [ ] Add user feedback for batch operation failures

### TODO(refactor)
- [ ] Extract icon patching pattern in RuntimeSetup.lua:53-116
- [ ] Extract bag setup logic in BankListManager.lua:104-116
- [ ] Use SkillBar.CONST constants in FrontBarManager.lua
- [ ] Extract reset patterns in ResourceOrbFrames/Module.lua
- [ ] Replace RemoveAllKeyButtonGroups() in KeybindManager.lua:54

### TODO(cleanup)
- [ ] Remove duplicate comment in SearchManager.lua:104-105
- [ ] Remove duplicate comment in Module.lua (Inventory):71-72
- [ ] Remove duplicate comment in Constants.lua (ROF):354-355
- [ ] Use math.pi instead of hardcoded 3.1415 in Banking/Constants.lua:114
- [ ] Rename "BETTERUI_TestWindow" to production name in Banking/Banking.lua:717
- [ ] Move visibleItems magic number (10) to constants in Banking/Banking.lua:283
- [ ] Remove commented debug statements in WindowClass.lua:422,431
- [ ] Remove commented debug statements in RuntimeSetup.lua:207,225
- [ ] Use SI_BETTERUI_ASSIGN_QUICKSLOTS in ActionDialogHooks.lua:153
- [ ] Use BETTERUI_DEFAULT_SKILL_TEXT_SIZE constant in ResourceOrbFrames/Module.lua:40
- [ ] Move font size offsets to constants in TooltipUtils.lua:25

### TODO(doc)
- [ ] Document ORB_CONFIG table structure in OrbVisuals.lua:16-21

### TODO(fix)
- [ ] WindowClass.lua:155 - nil-check GetList()
- [ ] GenericHeader.lua:88-94 - nil-check chained GetNamedChild
- [ ] GenericHeader.lua:97-98 - nil-check tabBarControl
- [ ] GenericFooter.lua:68 - nil-check invSettings
- [ ] InventoryClass.lua:728+ - nil-check batch items (6 locations)
- [ ] InventoryList.lua:387-396 - nil-check controls
- [ ] ItemListManager.lua:615-620 - nil-check tooltip
- [ ] InventoryKeybinds.lua:287 - nil-check targetData
- [ ] TooltipUtils.lua:284 - nil-check itemLink
- [ ] FooterManager.lua:23-38 - nil-check footer chain
- [ ] Module.lua (Banking):58-59 - nil-check Settings
- [ ] KeybindManager.lua:42 - nil-check ZO_GamepadBanking
- [ ] QuantityDialog.lua:44 - nil-check setupFunc
- [ ] BankListManager.lua:179-181 - fix category access
- [ ] OrbEvents.lua:77-92 - add existence check
- [ ] ResourceOrbFrames.lua:301,336 - nil-check fragment
- [ ] ResourceOrbFrames.lua:315-362 - add init guard
- [ ] FrontBarManager.lua:516-517 - fix durationMs assignment
- [ ] ResourceOrbFrames.lua:72-75 - nil-check pool

### TODO(optimization)
- (None identified - code is reasonably performant)

---

## Recommendations

### Sprint Focus
1. **Immediate**: Fix all 19 CRITICAL nil-check issues
2. **This Sprint**: Address DRY violations and magic numbers
3. **Next Sprint**: Improve error feedback, cleanup duplicate comments

### Process Improvements
1. Add pre-commit hook for nil-check linting
2. Create code review checklist for GetNamedChild usage
3. Document batch operation error handling requirements

### Tooling Suggestions
1. Consider adding luacheck with custom rules for nil-check patterns
2. Create template for safe GetNamedChild chains
