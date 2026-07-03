# Project Improvements

Last Updated: 2026-07-03
Status: Active

## Purpose

This file tracks execution-ready improvement phases and tech debt items for BetterUI.
Items are phased by dependency and risk. Completed items are migrated to `completed-improvements.md`.

## Active Phases

### BUI-TRACE-002A: Closeout — monitor core flows

All implementation phases (1–10) and the host validation/docs/review gate are complete and archived in `completed-improvements.md`. Release-only monitor checks remain and are user-assisted.

- [ ] Task: Run `/builog preset inspect` for one bank deposit+withdraw, one vendor buy+sell, one Trading House search, one settings toggle, and one `/builog privacy on` sample. (est: 5 min)
  - Expected traces include bank `requested→confirmed→list.refresh flow=bankTransfer#N`, vendor `requested→settled` with `goldDelta`, Trading House `requested→completed` with a shared `opId`, `settings.value write_before/write_after`, and redacted privacy output.

### BUI-TRACE-002B: Closeout — monitor input, combat, and digest

- [ ] Task: Run keybind, anomaly, combat/HUD, and digest checks over the same monitor session. (est: 5 min)
  - Expected traces include `event=input.keybind phase=fired` in each touched module, one forced `WARN STATE | event=anomaly phase=detected`, `resource_orbs.ultimate`, `resource_orbs.bar_swap`, `resource_orbs.cast`, and one `tools/builog-monitor/monitor.sh digest --last <n>` reviewed before release/tag.
  - Gates **release/tag only** — the branch is commit-ready on host validation alone. On success, migrate this item; on failure, record findings as a remediation phase.

### BUI-REGR-L4-VERIFY-001A: Live regression verification — bank and guild store

The host-fixable source work for guild bank, guild store, stablemaster, vendor/banking search keybinds, vendor category icon refresh, default/enhanced tooltips, quickslot placement, resource-orb global unlock, nameplate positioning, and builog flow/noise handling has been implemented and archived in `completed-improvements.md`. Remaining work is live ESO verification only.

- [ ] Task: L4 verify guild bank opens BetterUI and emits `bank.guild_scene_redirect` with either `show_fallback` or a concrete rejected-interaction reason; if no redirect trace appears, capture install-time redirect state. (est: 5 min)
- [ ] Task: L4 verify guild trader opens either BetterUI or native guild store after BetterUI bail paths; capture `trading_house.native_handoff` and `trading_house.scene` phases. (est: 5 min)

### BUI-REGR-L4-VERIFY-001B: Live regression verification — vendor flows

- [ ] Task: L4 verify stablemaster opens the BetterUI vendor scene; capture `vendor.stable_event` and final shown scene. (est: 5 min)
- [ ] Task: L4 verify vendor search retains focus while typing, scroll-exit restores full merchant category icon brightness, and Banking/Vendor sort/search exits restore the full keybind strip without needing item navigation. (est: 5 min)

### BUI-REGR-L4-VERIFY-001C: Live regression verification — tooltip and quickslot

- [ ] Task: L4 verify default-tooltip mode no longer strips the native top/equipped area after initial paint; confirm `general_interface.tooltip_stock_relayout nativeTopAreaPreserved=true`. (est: 5 min)
- [ ] Task: L4 verify quickslot default placement with both skill bars visible. (est: 5 min)

### BUI-REGR-L4-VERIFY-001D: Live regression verification — builog and nameplates

- [ ] Task: Re-scan a fresh builog session to confirm stale `nameplates.init` flow attribution is gone and `settings.control` no longer dominates default verbosity. (est: 5 min)
- [ ] Task: L4 verify compass/reticle positioning survives keyboard/gamepad switches and interact/non-interact prompt swaps without stale offsets or duplicate drag handles. (est: 5 min)
