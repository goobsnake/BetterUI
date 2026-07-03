# Project Improvements

Last Updated: 2026-07-02
Status: Active

## Purpose

This file tracks execution-ready improvement phases and tech debt items for BetterUI.
Items are phased by dependency and risk. Completed items are migrated to `completed-improvements.md`.

## Active Phases

### BUI-TRACE-002: Closeout — release-gate checkpoint

All implementation phases (1–10) and the host validation/docs/review gate are complete and archived in `completed-improvements.md`. One release-only item remains (extended by BUI-TRACE-003 Phase 6.3):

- [ ] Task: In-game monitor checkpoint (L4, user-assisted) (est: 10 min)
  - A 5-minute `/builog preset inspect` play-test with `tools/builog-monitor/monitor.sh` covering:
    - one bank deposit+withdraw (expect `requested→confirmed→list.refresh flow=bankTransfer#N`);
    - one vendor buy+sell (expect `requested→settled` with `goldDelta`);
    - one Trading House search (expect `requested→completed` with a shared `opId`);
    - one settings toggle (expect `settings.value write_before/write_after`);
    - one `/builog privacy on` sample (expect redacted preamble + delta-only currency);
    - one keybind press in each touched module showing `event=input.keybind phase=fired` (keyboard mode and gamepad mode when available);
    - one forced anomaly, such as a blocked/stalled bank or list-refresh flow, showing `WARN STATE | event=anomaly phase=detected`;
    - one combat/HUD sample showing `resource_orbs.ultimate`, `resource_orbs.bar_swap`, and `resource_orbs.cast` records when those in-game actions are available;
    - one `tools/builog-monitor/monitor.sh digest --last <n>` run over the session, reviewed by the user's AI assistant before release/tag.
  - Gates **release/tag only** — the branch is commit-ready on host validation alone. On success, migrate this item; on failure, record findings as a remediation phase.

