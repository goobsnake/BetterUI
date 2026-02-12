# BetterUI Continuity Ledger

> **Last Updated:** 2026-02-12
> **Provenance:** [CODE] Cross-module numeric settings hardening now clamps legacy out-of-range saved vars to active slider caps for Banking/Inventory font sizes, Resource Orb Frames scale/offset/text sliders, CIM tooltip/scroll settings, and Nameplates size during module init

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

**Done (recent ≤12):**
- [2026-02-12] [CODE] Numeric settings clamping audit/hardening pass: added shared font slider bounds + normalizers in `Modules/CIM/Core/FontDefinitions.lua`, wired those bounds into `Modules/CIM/Core/SettingsFactory.lua` and `Modules/Inventory/Settings/FontSettings.lua`, and now normalize persisted font sizes in `Modules/Banking/Module.lua` + `Modules/Inventory/Settings/SettingsPanel.lua`; `Modules/ResourceOrbFrames/Settings/Defaults.lua` now clamps persisted `scale`, `offsetY`, back-bar opacity, left/right orb size, orb text sizes, and bar/skill text sizes to current slider caps on `InitModule`; `Modules/CIM/Module.lua` now clamps persisted `triggerSpeed`, `rhScrollSpeed`, and `tooltipSize` to editbox/slider bounds; `Modules/CIM/Nameplates/Settings.lua` now clamps persisted nameplate `size` to slider bounds
- [2026-02-12] [CODE] Resource Orb Frames text-size + text-anchor constants pass: `Modules/ResourceOrbFrames/Constants.lua` now declares quickslot count and ultimate number text positioning constants (`BETTERUI_QUICKSLOT_COUNT_TEXT_*`, `BETTERUI_ULTIMATE_NUMBER_TEXT_*`), `Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua` now anchors quickslot count labels using those constants, `Modules/ResourceOrbFrames/SkillBar/UltimateManager.lua` now applies ultimate-number anchor/dimensions from constants, and `Modules/ResourceOrbFrames/Settings/Defaults.lua` now normalizes persisted text sizes to active slider bounds during `InitModule` (XP/Cast/Mount `5-20`, cooldown/quickslot/ultimate `12-30`)
- [2026-02-12] [CODE] Resource Orb Frames quickslot/cooldown continuity pass: `Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua` now anchors quickslot `CountText` below `ButtonText` (LB glyph line) to avoid overlap clipping, elevates cooldown/stack text draw tier above cooldown overlays, normalizes cooldown state keys to `slot/category`, and uses shared cooldown caches (`SkillBar.SharedCooldownCaches`) so front/back bar transitions reuse existing remain/duration state; `Modules/ResourceOrbFrames/SkillBar/BackBarManager.lua` now uses the same shared caches/state-key format and explicit cooldown-text draw priority; `Modules/ResourceOrbFrames/Templates/SkillBarTemplates.xml` now lowers cooldown overlay/edge tiers so countdown text renders fully opaque above the darkening layer and positions `UltimateText` as a bottom-aligned label box (`Dimensions y=32`, `BOTTOM` to parent `BOTTOM`, `offsetY -20`) so the number sits just above `LB+RB`
- [2026-02-12] [CODE] Resource Orb Frames cooldown smoothing coverage pass: `Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua` now interpolates cooldown remain time per slot for smoother edge motion (`m_cooldownVisualState`), keeps icon desaturation clamped to empty-state when quickslot count reaches `0`, and updates quickslot count text through a shared helper that now shows `0` for item slots with no remaining quantity; `Modules/ResourceOrbFrames/SkillBar/BackBarManager.lua` now applies the same per-slot remain interpolation + linear reveal-edge overlay behavior for back-bar slots including back-bar ultimate; `Modules/ResourceOrbFrames/Core/OrbEvents.lua` now runs cooldown updates for both bars on a shared `16ms` loop while leaving core status updates on `100ms`; `Modules/ResourceOrbFrames/Templates/SkillBarTemplates.xml` now defines `CooldownEdge` for back-bar buttons to render the reveal line
- [2026-02-11] [CODE] Resource Orb Frames cast-bar resource tint pass: `Modules/ResourceOrbFrames/Core/OrbBars.lua` now resolves cast-fill color using ESOUI-style cost mechanics (`GetAbilityBaseCostInfo` + `mechanicFlags` on bound/chained ability ID) and a short post-cast `EVENT_POWER_UPDATE` probe window (`450ms`) to sample actual health/magicka/stamina spend when metadata is ambiguous; cast fill now applies orb-matched two-tone styling (Fog + Fog2 equivalents from `Templates/ResourceOrbFrames.xml`: `health ff0000/4d0000`, `magicka 0066ff/000033`, `stamina 00ff00/004d00`) with default fallback for ultimate/non-resource casts
- [2026-02-11] [CODE] Resource Orb Frames cooldown reveal correction pass: `Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua` now resolves front-bar button controls directly (root child first for quickslot/companion) before fallback search, applies gamepad reveal using a native-style top-left `CooldownEdge` anchor with width tied to logical button dimensions (`cooldownRevealWidth/Height`) set during layout, drives `CooldownOverlay` height from unrevealed percent to enforce visible greyed-out state at cooldown start, and progressively restores icon saturation as cooldown completes; `Modules/ResourceOrbFrames/ResourceOrbFrames.lua` now invalidates `ControlUtils` lookup cache immediately after quickslot/companion reparent to prevent stale control bindings
- [2026-02-11] [CODE] Resource Orb Frames bar-fill tuning clarity pass: `Modules/ResourceOrbFrames/Constants.lua` now defines explicit per-bar fill controls (`BETTERUI_*_BAR_FILL_WIDTH_SCALE`, `*_FILL_HEIGHT_SCALE`, `*_FILL_OFFSET_X`, `*_FILL_OFFSET_Y`) with direction docs and derives `*_FILL_REGION` from those values for XP/Cast/Mount; `Modules/ResourceOrbFrames/Core/OrbBars.lua` now wires explicit texture constants per bar (`*_BAR_BACKDROP_TEXTURE`, `*_BAR_FILL_TEXTURE`) so all fill/backdrop graphics are centrally identified and customizable
- [2026-02-11] [CODE] Resource Orb Frames cooldown/visual polish pass: `Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua` now computes gamepad cooldown edge/overlay geometry from each button frame (`FlipCard` fallback chain) so quickslot and ultimate cooldown graphics track button dimensions across scale changes; quickslot count label now anchors centered below quickslot button (`AnchorQuickslotCountText` + template anchor update in `Modules/ResourceOrbFrames/Templates/SkillBarTemplates.xml`), XP fill strip height increased slightly in `Modules/ResourceOrbFrames/Constants.lua` (`BETTERUI_XP_BAR_FILL_REGION` top/bottom `0.42/0.585`), and shield text/overlay defaults shifted to electric blue in `Settings/Defaults.lua`, `Module.lua`, `Core/OrbVisuals.lua`, and `Templates/ResourceOrbFrames.xml`
- [2026-02-11] [CODE] Resource Orb Frames cast bar update: `Modules/ResourceOrbFrames/Core/OrbBars.lua` now starts cast-bar playback for all used slotted skills via `EVENT_ACTION_SLOT_ABILITY_USED`; true cast/channel skills retain real durations + countdown text, while instant skills use brief preview duration (`BETTERUI_CAST_BAR_INSTANT_DISPLAY_MS` in `Modules/ResourceOrbFrames/Constants.lua`) and show skill name without synthetic timer text
- [2026-02-11] [CODE] Resource Orb Frames placement correction: restored XP and mount bar heights to default-scale presentation (`BETTERUI_XP_BAR_HEIGHT 150`, `BETTERUI_MOUNT_STAMINA_BAR_HEIGHT 150`), moved visible-mode bars below ornaments (`BETTERUI_XP_BAR_OFFSET_Y 12`, `BETTERUI_MOUNT_STAMINA_BAR_OFFSET_Y 12`), and pushed bars outward toward edges (`BETTERUI_XP_BAR_OFFSET_X -90`, `BETTERUI_MOUNT_STAMINA_BAR_OFFSET_X 90`)
- [2026-02-11] [CODE] Resource Orb Frames follow-up tuning: raised mount bar toward ornament (`BETTERUI_MOUNT_STAMINA_BAR_OFFSET_Y -55 -> -85`), expanded XP/mount fill regions + slightly raised label anchors inside each bar window (`BETTERUI_XP_BAR_FILL_REGION`, `BETTERUI_MOUNT_STAMINA_BAR_FILL_REGION`, label Y `-1`), and increased ornament-visible orb border scale (`visibleScale 0.75 -> 0.80`) to better fill ornament sockets
- [2026-02-11] [CODE] Resource Orb Frames bar-layout refresh: ornaments increased by ~10% (`left 293`, `right 309`), XP/Cast/Mount bar dimensions + anchor offsets updated for current art (`55/62/62` heights; visible-mode offsets `-52 / 89 / -55`), and `Modules/ResourceOrbFrames/Core/OrbBars.lua` now applies per-bar texture crop bounds + fill regions + fill-centered label anchors (`BETTERUI_*_BAR_TEXTURE_BOUNDS`, `BETTERUI_*_BAR_FILL_REGION`) so frame/fill/text align with the new DDS assets

**Now:**
- Cross-module numeric settings clamping pass is code-complete; pending in-game validation that persisted over-cap values are rewritten to current limits on load without layout regressions

**Next:**
- In-game validation pass: confirm legacy over-max saved vars clamp to current limits for Banking/Inventory font sizes, Resource Orb Frames scale/offset/text sliders, CIM tooltip/scroll settings, and Nameplates size

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
- `Modules/CIM/Core/FontDefinitions.lua`
- `Modules/CIM/Core/SettingsFactory.lua`
- `Modules/CIM/Module.lua`
- `Modules/CIM/Nameplates/Settings.lua`
- `Modules/CIM/Tooltips/Settings.lua`
- `Modules/Banking/Module.lua`
- `Modules/Inventory/Settings/FontSettings.lua`
- `Modules/Inventory/Settings/SettingsPanel.lua`
- `Modules/ResourceOrbFrames/Settings/Defaults.lua`

---

## Receipts (last 10-20)

| Date | Provenance | Entry |
|------|------------|-------|
| 2026-02-12 | [TOOL] | Numeric-settings clamp hardening validation: `luac -p Modules/CIM/Core/FontDefinitions.lua` PASS, `luac -p Modules/CIM/Core/SettingsFactory.lua` PASS, `luac -p Modules/CIM/Module.lua` PASS, `luac -p Modules/CIM/Nameplates/Settings.lua` PASS, `luac -p Modules/CIM/Tooltips/Settings.lua` PASS, `luac -p Modules/Banking/Module.lua` PASS, `luac -p Modules/Inventory/Settings/FontSettings.lua` PASS, `luac -p Modules/Inventory/Settings/SettingsPanel.lua` PASS, `luac -p Modules/ResourceOrbFrames/Settings/Defaults.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after wiring load-time clamps for slider/editbox numeric settings across affected modules |
| 2026-02-12 | [TOOL] | Text-size migration/anchor-constant validation: `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, `luac -p Modules/ResourceOrbFrames/Settings/Defaults.lua` PASS, `luac -p Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua` PASS, `luac -p Modules/ResourceOrbFrames/SkillBar/UltimateManager.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after adding quickslot/ultimate text-position constants and normalizing persisted text-size saved vars to current slider caps during `InitModule` |
| 2026-02-12 | [TOOL] | Quickslot/cooldown continuity validation: `luac -p Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua` PASS, `luac -p Modules/ResourceOrbFrames/SkillBar/BackBarManager.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after re-anchoring quickslot count below keybind glyphs, lowering cooldown overlay tier under text, sharing cooldown smoothing/effect-duration caches across front/back bars, and finalizing `UltimateText` to a bottom-aligned anchor model (`y=32`, `BOTTOM` to `BOTTOM`, `offsetY -20`) |
| 2026-02-12 | [TOOL] | Cooldown smoothing coverage validation: `luac -p Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua` PASS, `luac -p Modules/ResourceOrbFrames/SkillBar/BackBarManager.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbEvents.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after extending remain-time interpolation + linear reveal-edge cooldown visuals to both bars and moving both cooldown loops to shared 16ms updates |
| 2026-02-11 | [TOOL] | Cast-bar resource-tint validation: `luac -p Modules/ResourceOrbFrames/Core/OrbBars.lua` PASS and `lua tools/tests/run_all_tests.lua` PASS (9/9) after aligning cast-fill classification to ESOUI cost-mechanic flags (`GetAbilityBaseCostInfo`) plus power-drop probe fallback and orb-matched two-tone fill shading, while preserving ultimate/non-resource default fallback |
| 2026-02-11 | [TOOL] | Cooldown reveal correction validation: `luac -p Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua` PASS, `luac -p Modules/ResourceOrbFrames/ResourceOrbFrames.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after direct button-resolution + native-style gamepad edge reveal update with layout-driven logical button dimensions and overlay-driven unrevealed-state darkening |
| 2026-02-11 | [TOOL] | Bar-fill tunability validation: `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbBars.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after introducing explicit per-bar fill width/height/offset constants + texture constant wiring |
| 2026-02-11 | [TOOL] | Cooldown/quickslot/shield polish validation: `luac -p Modules/ResourceOrbFrames/SkillBar/FrontBarManager.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbVisuals.lua` PASS, `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, `luac -p Modules/ResourceOrbFrames/Module.lua` PASS, `luac -p Modules/ResourceOrbFrames/Settings/Defaults.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) |
| 2026-02-11 | [TOOL] | Cast-bar instant-preview validation: `luac -p Modules/ResourceOrbFrames/Core/OrbBars.lua` PASS, `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after enabling non-cast/channel skill previews via `BETTERUI_CAST_BAR_INSTANT_DISPLAY_MS` |
| 2026-02-11 | [TOOL] | Placement-correction validation: `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbBars.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbVisuals.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after XP/mount height + visible-mode anchor corrections |
| 2026-02-11 | [TOOL] | Follow-up tuning validation: `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbBars.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbVisuals.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after mount offset direction fix + XP/mount fill-region/label updates + orb visibleScale increase |
| 2026-02-11 | [TOOL] | Bar-geometry refresh validation: `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbBars.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbVisuals.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after per-bar texture bounds/fill-region wiring |
| 2026-02-11 | [TOOL] | Ornament-fit follow-up validation: `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbVisuals.lua` PASS, `luac -p Modules/ResourceOrbFrames/Core/OrbBars.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after adding ornament-visible orb scaling |
| 2026-02-11 | [TOOL] | Graphics alignment validation: `luac -p Modules/ResourceOrbFrames/Core/OrbBars.lua` PASS, `luac -p Modules/ResourceOrbFrames/Constants.lua` PASS, and `lua tools/tests/run_all_tests.lua` PASS (9/9) after wiring cast/mount-specific bar backdrops + ornament position/size tuning |
| 2026-02-10 | [TOOL] | Updated converter profile checks to power-of-two-or-multiple-of-4 + deterministic duplicate selection; PowerShell parser check PASS for `tools/ConvertPngToDds.ps1`; README contract updated to match behavior |
| 2026-02-09 | [TOOL] | ROF custom-texture profile smoke test PASS via `tools/ConvertPngToDds.ps1 -Profile ResourceOrbFrames` against shipped textures (10/10 converted); `luac -p Modules/ResourceOrbFrames/Core/OrbVisuals.lua` and PowerShell parse check for converter both PASS |
| 2026-02-09 | [TOOL] | Banking multi-select repair review completed for `9948ca6` + `c38d0e6` (entry-path fix, multi-select target fallback, `luac -p`, tests 9/9 PASS, locale key parity verified) |
| 2026-02-09 | [TOOL] | Wrap-up gate PASS: clean status, sr-review-gate PASS, tests 9/9 PASS, debug scan clean, Lua syntax clean, locale parity clean (`lang/en,de,es,fr,jp,ru,zh.lua`) |
| 2026-02-09 | [CODE] | Settings consistency hardening: aligned defaults/resets, strict integer editbox parsing, and nil-safe settings callbacks across affected modules (`luac -p` validated) |
| 2026-02-09 | [CODE] | Resource Orb General reset scope corrected in `Modules/ResourceOrbFrames/Module.lua` to only `scale`, `offsetY`, and `useCustomTextures` (`luac -p`) |

