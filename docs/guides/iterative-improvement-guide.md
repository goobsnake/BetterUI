# Iterative Improvement Guide

This guide defines a repeatable improvement loop for BetterUI so planning, implementation, and closeout stay consistent.

## Core Artifacts

- `docs/planning/feature-requests.md`: long-horizon capability backlog.
- `docs/planning/priority-backlog.md`: active `P0/P1` execution backlog.
- `docs/planning/project-improvements.md`: current implementation plan and phase journal.
- `docs/planning/continuity-ledger.md`: short handoff state for active focus.
- `docs/publishing/changelog.txt`: user-facing release notes.

## Improvement Cycle

1. Intake and Triage
- Add or refine durable requests in `feature-requests.md`.
- Promote only critical/high items into `priority-backlog.md`.
- Keep non-critical requests in feature backlog.

2. Plan
- Convert selected priority items into concrete phased tasks in `project-improvements.md`.
- Define explicit validation steps (syntax checks and in-game verification).
- Record dependencies and non-goals.

3. Implement
- Keep changes targeted and bounded to scoped files.
- Preserve behavior unless explicitly changing behavior.
- Use existing module patterns before introducing new abstractions.

4. Validate
- Run syntax checks (`luac -p`) on changed Lua/XML-adjacent files.
- Run any available standalone test scripts.
- Perform in-game sanity checks for affected modules/scenes.

5. Closeout
- Update status in `priority-backlog.md` and `project-improvements.md`.
- Record durable lessons in `docs/reference/tribal-knowledge.md`.
- Update `docs/publishing/changelog.txt` for user-visible changes.

## Definition of Done

- Acceptance criteria met and validated.
- No known regressions introduced in core gamepad flows.
- Planning and continuity docs updated to reflect new state.
- User-facing changes documented in changelog/description as appropriate.

## Suggested Cadence

- Weekly: one focused execution pass on top priority backlog items.
- Bi-weekly: audit `feature-requests.md` and re-rank.
- Monthly: prune stale priorities and refresh improvement phases.
