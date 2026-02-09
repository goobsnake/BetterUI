# BetterUI Continuity Ledger

> **Last Updated:** 2026-02-09
> **Provenance:** [TOOL] Wrap-up gate execution confirmed sr-review + verify-integrity pass for settings architecture/defaults hardening and nil-guard safety updates

**Reference:** For ESO API quirks, patterns, and lessons learned see [TRIBAL_KNOWLEDGE.md](TRIBAL_KNOWLEDGE.md).

---

## Snapshot (≤25 lines)

**Goal:** Maintain high-quality ESO addon with gamepad-first UI modernization

**Success Criteria:**
- All modules follow CIM patterns
- Consistent gamepad navigation across scenes
- Clean code with comprehensive documentation
- No regressions in existing functionality

**Invariants:**
- Never modify `esoui/` reference folder
- All code must load without errors in-game
- Follow `betterui-development-guidelines` for all changes
- Shared code goes in `Modules/CIM/`, never new "Shared" folders

---

## State

**Done (recent ≤7):**
- [2026-02-09] [CODE] Added centralized settings metadata registry in `Modules/CIM/Core/SettingsFactory.lua` (schema includes label/tooltip/default/dependency/sortGroup/resetGroup) and replaced duplicated top-level submenu sorting helpers with shared utilities to reduce drift
- [2026-02-09] [CODE] `IconSettingsFactory` now fully localized: removed remaining hardcoded English names/tooltips/submenu copy; wired icon labels/defaults through metadata registry and added localized keys across `lang/en/de/es/fr/jp/ru/zh.lua`
- [2026-02-09] [CODE] General Interface `Market Price Integration` now includes configurable source order dropdown (`marketPricePriority`), with `MarketIntegration.lua` honoring selected provider order for `BETTERUI.GetMarketPrice`; defaults/migration added in `DefaultsRegistry` + `RuntimeSetup`
- [2026-02-09] [CODE] Disabled integration controls now append explicit localized addon-missing reason text in tooltips (`SI_BETTERUI_ADDON_NOT_DETECTED_TOOLTIP`) and TTC disabled rows now also render `OFF` when addon is unavailable
- [2026-02-09] [CODE] Added user-facing feedback when currency visibility cap blocks enable action (`SI_BETTERUI_CURRENCY_ENABLE_LIMIT_WARNING`) via chat warning + negative click sound in `CurrencySettings.lua`
- [2026-02-09] [CODE] Layout/label follow-up: Inventory+Banking font reset labels now use requested wording (`Reset Name Font Settings`, `Reset Other Font Settings`), Currency submenu now opts out of recursive alphabetical sorting to preserve paired visibility/order row layout, Currency reset text shortened to `Reset Currency Settings`, Resource Orb Frames offset label updated to `Offset (Up/Down)`, and settings sorter now supports `sortAlwaysLast` (applied to `Use Custom Textures` so it remains bottom in General)
- [2026-02-09] [CODE] Resource Orb Frames top-level `Reset General Settings` button now resets only General controls (`scale`, `offsetY`, `useCustomTextures`), no longer resetting orb/skill/text settings

**Now:**
- Wrap-up quality gates are complete: adhoc sr-review (all 5 reviewer lenses PASS) and verify-integrity checks (tests/debug scan/syntax) passed with no outstanding findings

**Next:**
- User in-game verification pass for settings UX and reset/default parity (Nameplates, Inventory Currency, General Interface numeric editboxes, Resource Orb General defaults, and scene-gated reset stability)

---

## Decisions

| ID | Status | Date | Decision |
|----|--------|------|----------|
| D001 | ACTIVE | 2026-02-06 | Two-file approach: CONTINUITY.md for session state, TRIBAL_KNOWLEDGE.md for permanent learnings |

---

## Open Questions

(None currently)

---

## Working Set (≤12 paths)

- `docs/CONTINUITY.md`
- `Modules/CIM/Core/IconSettingsFactory.lua`
- `Modules/Inventory/Settings/FontSettings.lua`
- `Modules/CIM/Tooltips/Settings.lua`
- `Modules/Banking/Settings/SettingsPanel.lua`
- `Modules/CIM/Nameplates/Settings.lua`
- `lang/*.lua`

---

## Receipts (last 10-20)

| Date | Provenance | Entry |
|------|------------|-------|
| 2026-02-09 | [TOOL] | Wrap-up workflow gate run: `git status --short` baseline + no temporary artifact files, adhoc sr-review-gate completed with PASS across Lua Architect/UI-UX/Code Quality/Sr Dev/QA perspectives, `lua tools/tests/run_all_tests.lua` passed (9/9), debug scan returned clean, Lua syntax validation passed for all changed `.lua` files, and localization key parity check across `lang/en,de,es,fr,jp,ru,zh.lua` reported no missing `SI_BETTERUI_*` keys |
| 2026-02-09 | [CODE] | Comprehensive settings consistency pass for user-reported review findings: aligned reset/fresh-install defaults for Nameplates (including first-install state) and Resource Orb General (`scale=1.0`, `offsetY=0`), switched Inventory currency seeding to canonical `BETTERUI.CURRENCY_PRESETS.default`, hardened General Interface numeric editboxes with strict integer parsing (chat history/scroll speed/trigger speed), and applied nil-safe module-setting helpers across settings callbacks (`Tooltips`, `Nameplates`, `Inventory Font/Currency`, `ResourceOrbFrames`, `IconSettingsFactory`, `SettingsFactory`, `Master` toggles); validated with `luac -p` on all touched files |
| 2026-02-09 | [CODE] | Fixed Resource Orb Frames General reset scope in `Modules/ResourceOrbFrames/Module.lua`: top-level reset button now only resets `scale`, `offsetY`, and `useCustomTextures`; removed unintended resets for cooldown/quickslot/orb ornament settings; validated with `luac -p` |
| 2026-02-09 | [CODE] | User-requested naming/layout fixes: added per-submenu `disableAutoSort` support in `SettingsFactory.SortSettingsAlphabetically` and applied it to Inventory Currency submenu to stop pair drift; added `sortAlwaysLast` support and flagged Resource Orb `Use Custom Textures` so it remains the bottom General setting; renamed EN labels to `Reset Name Font Settings`, `Reset Other Font Settings`, `Reset Currency Settings`, and `Offset (Up/Down)`; validated touched files with `luac -p` |
| 2026-02-09 | [CODE] | Final reset UX + stability pass: added `Item Icon Customization` submenu reset buttons/default metadata wiring for Inventory+Banking (`SI_BETTERUI_ICON_SUBMENU_RESET*` + shared factory reset handler), scene-gated inventory/tooltip/banking settings refresh helpers to avoid hidden-scene nil crashes during reset actions, restored Nameplates reset to standard half-width, and renamed reset labels to requested wording (`Reset Nameplate/Tooltip/Market/Exp Bar/Mount Bar/General`) across `lang/en/de/es/fr/jp/ru/zh.lua`; validated targeted files with `luac -p` |
| 2026-02-09 | [CODE] | Addressed four setting regressions/UX gaps: fixed Inventory General reset crash by scene-gating `RefreshItemActions`/refresh helpers; introduced sorter support for `sortAlwaysFirst` dependency toggles and applied it to cast/xp/mount + enhanced-tooltips enable controls; widened Nameplates reset button to full width to avoid truncation; and added dedicated reset buttons/default wiring for `Market Price Integration` and `Enhanced Tooltips` submenus plus localized reset strings (`SI_BETTERUI_MARKET_INTEGRATION_RESET*`, `SI_BETTERUI_ENHANCED_TOOLTIPS_RESET*`) across all locale files; validated with `luac -p` |
| 2026-02-09 | [CODE] | Settings UX follow-up: replaced generic submenu reset labels with explicit scope labels (`Reset <submenu> Settings`) for Currency Visibility, Enhanced Nameplates, Name/Column font submenus, and Resource Orb Frames submenus; added new localized Resource Orb reset keys (`SI_BETTERUI_ORB_TEXT_RESET`, `SI_BETTERUI_XP_BAR_RESET`, `SI_BETTERUI_CAST_BAR_RESET`, `SI_BETTERUI_MOUNT_STAMINA_BAR_RESET`) and wired submenu buttons accordingly in `Module.lua`; validated syntax with `luac -p` |
| 2026-02-09 | [CODE] | Follow-up fixes: Resource Orb Frames now sorts Skill Bars section groups alphabetically by section header (while preserving reset button placement), Orb Settings now includes localized grouped headers (`Orb Visuals` and `Orb Text`), Master module toggles now sort by displayed `Enable ...` wording while keeping `Use Global Settings` at top, and missing orb-header locale keys were added to `lang/es/fr/jp/ru/zh.lua`; validated with `luac -p` |
| 2026-02-09 | [CODE] | Implemented selected recommendations: centralized settings metadata registry + shared submenu sorter utility, market source priority control with runtime order handling (`marketPricePriority`), localized icon customization strings for new icon toggles/submenu copy, addon-missing tooltip messaging on disabled integration rows, currency cap warning feedback on blocked enables, and top-level General reset buttons for Inventory/Banking/General Interface; validated syntax via `luac -p` on all touched Lua/locale files |
| 2026-02-09 | [CODE] | Renamed `SI_BETTERUI_NAMEPLATES_SIZE` label values from localized `Font Size` equivalents to localized `Size` equivalents across `lang/en/de/es/fr/jp/ru/zh.lua` so shared alphabetical sorting places this control below `Font Style` in Enhanced Nameplates; verified syntax with `luac -p` |
| 2026-02-09 | [CODE] | Fixed Market Price Integration ATT/MM state rendering in `Modules/CIM/Tooltips/Settings.lua`: disabled rows now display `OFF` when addon APIs are unavailable, but preserve saved/default `ON` behavior when addons are available |
| 2026-02-09 | [CODE] | Added shared settings sorter `BETTERUI.CIM.Settings.SortSettingsAlphabetically` and applied it to Inventory/Banking/GeneralInterface/ResourceOrbFrames panel builds to alphabetize General settings and submenu controls |
| 2026-02-09 | [CODE] | Master panel module toggles are now sorted alphabetically after `Use Global Settings`; Nameplates font setting label changed from `Nameplate Font` to `Font` across all locale files |
| 2026-02-09 | [CODE] | Mail-delete confirmation settings row no longer uses an emoji name prefix and uses shorter localized labels (`SI_BETTERUI_REMOVE_DELETE_MAIL_CONFIRM`) to avoid overlap with warning/value columns in the gamepad settings list |
| 2026-02-09 | [CODE] | General Interface settings layout normalization: replaced nested `General` submenu with a top-level `General` header+description and flat controls; removed redundant inner Nameplates header; changed Resource Orb Frames top header string to localized `General`; and clarified `showStyleTrait` as tooltip-specific (icon preview + disabled unless Tooltip Enhancements are active) |
| 2026-02-08 | [CODE] | Added localized `General` section header/description strings for Inventory/Banking across all language files, inserted General sections at the top of both settings panels, and moved Inventory `Item Icon Customization` submenu below `Currency Visibility & Order` |
| 2026-02-08 | [CODE] | Added shared icon customization submenu and three new toggles (`Researchable Trait`, `Unknown Recipe`, `Unknown Book`) for Inventory/Banking; row rendering now supports these icon states with active-scene settings and font-scaled sizing |
| 2026-02-08 | [CODE] | Follow-up tuning: increased shared icon-toggle `Unbound` preview size from 22 to 24 in `IconSettingsFactory` to compensate for texture padding and match the enchant/set preview visual weight |
| 2026-02-08 | [CODE] | Fixed shared Inventory/Banking row-icon behavior: icon toggles now read active scene module settings (Banking toggles now disable banking list icons correctly), inline status icons now scale from active name font size with per-icon weight tuning, and shared icon-toggle settings now include matching inline icon previews |
| 2026-02-08 | [CODE] | LAM settings audit/fix + sr-review loop: only true reload-required controls remain in Master panel, ResourceOrbFrames custom textures now live-apply (including orb bars), mount stamina setting key mismatches fixed, Inventory trigger-skip toggle now wired to runtime behavior, Inventory/Banking settings refresh now target runtime window instances, and developer-only feature flags are hidden unless `BETTERUI.CIM.Debug.SHOW_DEVELOPER_SETTINGS = true` |
| 2026-02-08 | [CODE] | Expanded feature request #20 `Console Add-On Support & Mod Browser Readiness` with deeper `esoui` API anchors (dynamic support events, disk threshold, menu visibility gates, mod browser install/search APIs) and official external constraints (next-gen scope, no PC/Mac browser path, UI-only, no language add-ons, 100 MB cap) |
| 2026-02-08 | [CODE] | Feature requests follow-up: restored detailed #13 "New Item Visual Tracking System" content, set status to `NOT WORKING - NEEDS REVIEW`, and updated matrix/order to prioritize review |

