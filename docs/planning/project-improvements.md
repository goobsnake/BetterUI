# Project Improvements

Last Updated: 2026-07-06
Status: Active

## Purpose

This file tracks execution-ready improvement phases and tech debt items for BetterUI.
Items are phased by dependency and risk. Completed items are migrated to `completed-improvements.md`.

## Active Phases

### BUI-CONS-012: Extract the settings layout engine from BetterUI.lua

`BetterUI.lua:535-1663` (~1130 lines) is a self-contained custom LAM widget-geometry + tabbed-submenu rendering engine with no dependency on the surrounding module-toggle/saved-vars logic. A 2026-07-03 dependency-mapping pass produced the execution-ready plan below but deliberately did NOT execute it: the settings panel has no runtime test coverage (host validation is source-shape + luac only), so a missed coupling would pass every host check yet silently break the in-game settings panel. **Execute as a solo slice (no concurrent BetterUI.lua edits) and follow with an in-game settings-panel smoke check.**

Execution plan (mapped against the tree at commit `4e773a50`; re-verify line anchors before editing):

- Move BetterUI.lua lines 535-1663 (3 forward-decls `GetSettingsTabControlWidth`/`ReflowSettingsPageLayout`/`RefreshSettingsWidgetTree` at 535-537, the 24 `SETTINGS_*` layout constants 538-561, and 44 `local function`s 563-1663) plus the `SETTINGS_TAB_STATE` table (186-188) into new `Modules/CIM/Core/Settings/SettingsPanelLayout.lua`, exposing `BETTERUI.CIM.SettingsPanelLayout = {}`. Manifest: insert next to `Modules\CIM\Core\Settings\SettingsFactory.lua`; note it loads AFTER `BetterUI.lua`, so all cross-references must be runtime namespace calls.
- Cross-boundary couplings (3): (1) `TraceSettingsPanel` (BetterUI.lua:416, stays — used by retained code at 483/523/1924): export as `BETTERUI.CIM.SettingsPanelTrace` and consume via a call-time forwarder in the new file. (2) `SETTINGS_TAB_CONTROL_REFERENCE` (185) and `SETTINGS_TAB_DEFAULT_WIDTH` (538) are read by retained `InitModuleOptions` (1907-1910) — keep local copies in BetterUI.lua so the exact-literal test pins (test lines 578/587/588) hold. (3) `RefreshActiveSettingsTabs` reverse-coupling — fwd-decl at 189 is assigned inside the moved block (1620) and called at 196-197: expose as `BETTERUI.CIM.SettingsPanelLayout.RefreshActiveSettingsTabs`, delete the fwd-decl, repoint 196-197 to a guarded namespaced call. **This is the silent-failure risk: if missed, toggle-driven tab refresh dies with no test failure.**
- Inbound forwarders (5): keep bare-named thin local forwarders in BetterUI.lua for `ResolveLamPanel`, `GetSettingsTabButtonPanelHeight`, `CreateSettingsTabsControl`, `RefreshSettingsTabsControl`, `RegisterSettingsTabsLamCallbacks` so call sites 1907-1941 and their source pins stay intact.
- Source-pin repoints (~45): `tools/tests/test_bootstrap_orchestration.lua` (positive `:find` assertions targeting moved content) and `tools/tests/test_settings_panel_registration.lua` (210/212/214) must read the new file; negative pins and call-site literal pins stay valid given the forwarders + constant copies.
- Related but separate (do NOT bundle): unifying the three near-identical markup-strip sort helpers (`NormalizeModuleToggleSortName` BetterUI.lua:205-231 + two siblings in `SettingsFactory.lua:20-38,105-125`) is behavior-sensitive (sort order) — no function named `StripUIMarkupForSort` exists.

- [ ] Task: Execute the extraction per the plan above as a solo slice; host runs full suite + luac + pins, then an in-game settings-panel smoke check (open settings, switch tabs, toggle a module, confirm tab refresh). (est: 60 min + in-game check)

### ACC-010: Finish gamepad screen-narration in-game acceptance

ACC-010 source Phases 1-3 are implemented and archived in `completed-improvements.md`. User in-game acceptance now confirms Vendor, Banking, and Inventory narrate per item scrolled after the Inventory scene-name follow-up. Remaining work is manual acceptance for the two custom screens not yet confirmed in-game: Trading House and Companions. Phase 4 native parametric-list migration remains optional/deferred and is not required to close the minimal trigger patch.

- [ ] Task: In-game acceptance: open Trading House and Companions with gamepad screen narration enabled, scroll their main lists, and confirm each narrates per item scrolled without fast-scroll spam. If both pass, remove this ACC-010 remainder from `project-improvements.md`; if either fails, reopen only the failing screen path in `accessibility-narration-plan.md`. (est: 1 in-game session)
