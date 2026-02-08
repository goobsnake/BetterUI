# BetterUI Continuity Ledger

> **Last Updated:** 2026-02-08T21:01:18Z
> **Provenance:** [USER] Requested `sr-review-gate` execution and full fix loop for all findings after the comprehensive LAM settings audit/fix pass

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
- [2026-02-08] [CODE] Completed LAM settings integrity pass + sr-review remediation: fixed non-functional Inventory trigger toggle wiring, corrected Inventory/Banking live-refresh callbacks to use runtime window instances, fixed ResourceOrbFrames mount-setting key mismatches, added real-time tooltip style apply hooks, and gated developer-only feature flags behind `SHOW_DEVELOPER_SETTINGS`
- [2026-02-08] [CODE] Expanded feature request #20 `Console Add-On Support & Mod Browser Readiness` in `docs/FEATURE_REQUESTS.md` using `esoui/` API evidence plus official support/forum constraints; updated TOC, matrix, and recommended order
- [2026-02-08] [CODE] Feature-request follow-up: restored full `New Item` section details in `docs/FEATURE_REQUESTS.md` and reclassified #13 as `NOT WORKING - NEEDS REVIEW` (removed from closed items, moved to P1)
- [2026-02-08] [TOOL] Feature-request workflow run (`/feature-requests`, standard scope): refined existing backlog entries, marked implemented items (#13/#14) as closed, and added sections #16-#19 (guild roster/ranks, social hub, chat tooling, maintenance hub)
- [2026-02-08] [CODE] Banking tooltip icon follow-up: bank-capacity value icon switched from mount-capacity glyph to inventory bag icon (`gp_inventory_icon_all`) for better semantic fit, retaining no-space aligned-right formatting, 90% icon size, and 290 spacing
- [2026-02-08] [CODE] Banking currency-row consistency pass: currency action text now derives from Banking Name font settings (+2 size for readable emphasis), row label anchor nudged up for spacing, gold transfer amount text forced gold tint, and icon pulse standardized with alpha+scale timeline plus clean reset
- [2026-02-08] [CODE] Banking UI polish iteration on `feature/banking-currency-row-polish`: currency action rows moved left and downsized to match list typography; bank-space details now appended at bottom of left currency tooltip using native currency styles; gold transfer amount now tinted gold in custom withdraw/deposit rows

**Now:**
- LAM settings pass and `sr-review-gate` remediation are complete in code; pending in-game validation for live-apply behavior and reload prompts

**Next:**
- Run focused in-game verification matrix for each settings panel (Master, General, Inventory, Banking, Resource Orb Frames) and capture any behavior drift

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
- `BetterUI.lua`
- `Modules/CIM/Core/DeveloperDebug.lua`
- `Modules/CIM/Tooltips/Settings.lua`
- `Modules/CIM/Module.lua`
- `Modules/Inventory/Settings/SettingsPanel.lua`
- `Modules/Inventory/Inventory.lua`
- `Modules/Banking/Settings/SettingsPanel.lua`
- `Modules/ResourceOrbFrames/Module.lua`
- `Modules/ResourceOrbFrames/Core/OrbBars.lua`
- `Modules/ResourceOrbFrames/Settings/Defaults.lua`
- `lang/en.lua`

---

## Receipts (last 10-20)

| Date | Provenance | Entry |
|------|------------|-------|
| 2026-02-08 | [CODE] | LAM settings audit/fix + sr-review loop: only true reload-required controls remain in Master panel, ResourceOrbFrames custom textures now live-apply (including orb bars), mount stamina setting key mismatches fixed, Inventory trigger-skip toggle now wired to runtime behavior, Inventory/Banking settings refresh now target runtime window instances, and developer-only feature flags are hidden unless `BETTERUI.CIM.Debug.SHOW_DEVELOPER_SETTINGS = true` |
| 2026-02-08 | [CODE] | Expanded feature request #20 `Console Add-On Support & Mod Browser Readiness` with deeper `esoui` API anchors (dynamic support events, disk threshold, menu visibility gates, mod browser install/search APIs) and official external constraints (next-gen scope, no PC/Mac browser path, UI-only, no language add-ons, 100 MB cap) |
| 2026-02-08 | [CODE] | Feature requests follow-up: restored detailed #13 "New Item Visual Tracking System" content, set status to `NOT WORKING - NEEDS REVIEW`, and updated matrix/order to prioritize review |
| 2026-02-08 | [TOOL] | Feature requests audit (standard scope): updated statuses for implemented/partial features, closed #13/#14 as implemented, and added #16-#19 (guild roster/ranks, social hub, chat tooling, maintenance hub) |
| 2026-02-08 | [CODE] | Banking tooltip icon follow-up: replaced bank-capacity value icon with `gp_inventory_icon_all` (from mount-capacity icon) while retaining no-space aligned-right formatting, 90% icon size, and 290 top spacing |
| 2026-02-08 | [CODE] | Banking currency-row consistency pass: font scales with Banking Name setting (+2), row text nudged up, gold amount rendered in gold tint, and icon pulse standardized |
| 2026-02-08 | [CODE] | Banking polish iteration: switched currency rows to BetterUI template for left alignment + smaller text, moved bank-space details into styled bottom section of left currency tooltip, and tinted gold transfer amount in gold |
| 2026-02-08 | [CODE] | Banking currency-row polish prototype: iconized rows + selection pulse + right tooltip bank upgrade/capacity details |
| 2026-02-08 | [CODE] | Fixed 5 UI bugs: TTC tooltip, multi-select, empty search, icon sizing, banking currency persistence |
| 2026-02-07 | [CODE] | Fixed Seals currency: `CURT_SEALS` → `CURT_SEALS or CURT_ENDEAVOR_SEALS` compat alias (same pattern as Trade Bars) |
| 2026-02-07 | [CODE] | Fixed tooltip hiding: `zo_mixin` copies methods from class to instance at init time; must hook per-instance, not class table |
| 2026-02-07 | [CODE] | Fixed banking keyboard toggle: intercept `SCENE_MANAGER:Toggle/Show` with re-entrancy guard during active banking |
| 2026-02-07 | [CODE] | Removed `BetterUI_RecursiveHide` from TooltipUtils.lua — native labels now suppressed at source via `AddTopLinesToTopSection` hook |
| 2026-02-07 | [CODE] | Fixed Junk tab bug: `SetItemIsJunk()` is async, moved coalesced `RefreshCategoryList` outside dialog if/else in `OnInventoryUpdated` |
| 2026-02-07 | [CODE] | Finalized ScrollIndicator thumb texture (`gp_nav1_horDividerFlat.dds` center-row sampling) |
| 2026-02-07 | [CODE] | Added cleanup requirement for temporary review artifacts before commit |
| 2026-02-07 | [CODE] | Fixed profiler report shadowing bug and updated module enable documentation |
| 2026-02-07 | [CODE] | Replaced Banking keybind strip resets with targeted group removal |
| 2026-02-07 | [CODE] | Localized tooltip cleanup tokens and junk label rendering |
| 2026-02-06 | [TOOL] | Completed 7-phase agent config optimization |

