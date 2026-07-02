# Project Improvements

Last Updated: 2026-07-02
Status: Active

## Purpose

This file tracks execution-ready improvement phases and tech debt items for BetterUI.
Items are phased by dependency and risk. Completed items are migrated to `completed-improvements.md`.

## Active Phases

### BUI-TRACE-002: Closeout — release-gate checkpoint

All implementation phases (1–10) and the host validation/docs/review gate are complete and archived in `completed-improvements.md` (entries dated 2026-07-01/02). One release-only item remains:

- [ ] Task: In-game monitor checkpoint (L4, user-assisted) (est: 10 min)
  - A 5-minute `/builog preset inspect` play-test with `tools/builog-monitor/monitor.sh` covering: one bank deposit+withdraw (expect `requested→confirmed→list.refresh flow=bankTransfer#N`), one vendor buy+sell (expect `requested→settled` with `goldDelta`), one Trading House search (expect `requested→completed` with a shared `opId`), one settings toggle (expect `settings.value write_before/write_after`), and one `/builog privacy on` sample (expect redacted preamble + delta-only currency).
  - This gates **release/tag only** — the branch is commit-ready on host validation alone. On success, migrate this item and close BUI-TRACE-002; on failure, record findings as a new remediation phase.

#### Deferred (recorded, deliberately not scheduled)

- Extract ESO-domain describers (`DescribeItem`, `DescribeKeybindDescriptor(s)`, `DescribeListSelection`, `GetCurrencyAmountForLocation`) from `Log.lua` into a `DomainLog.lua` — structural only; revisit if `Log.lua` grows past the ~600-line split threshold again.
- Per-line `schema=` token (preamble-only is sufficient while `sid` anchors sessions).
- Legacy phase migration: 336 approved-legacy phase tokens remain visible as lint WARNs (up from 90 once the wrapper surfaces were covered — pure visibility gain, not regression). Migrate per module opportunistically when an `EVENT_SCHEMA` bump is already planned; never as a standalone mass rename.
