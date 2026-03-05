# Agent Collaboration Guide

This guide standardizes how to request work from coding agents for BetterUI.

## What to Include in Requests

- Goal: clear outcome in one sentence.
- Scope: files/modules that are in or out.
- Constraints: behavior that must not change.
- Validation: required checks (syntax, in-game, docs updates).

## Preferred Request Patterns

### Targeted fix
- Include: bug behavior, expected behavior, likely module path, and reproduction steps.

### Refactor
- Include: boundaries, invariants, and what is explicitly out of scope.

### Documentation update
- Include: source-of-truth files and audience (contributors, maintainers, release users).

## Execution Expectations

- Default to minimal, focused changes.
- Preserve existing behavior unless change is requested.
- Update docs in the same pass when behavior or workflow changes.
- Avoid large speculative rewrites.

## Required Planning Touchpoints

- New durable capability request: `docs/planning/feature-requests.md`
- Immediate critical/high execution item: `docs/planning/priority-backlog.md`
- Active implementation steps: `docs/planning/project-improvements.md`
- Session handoff state: `docs/planning/continuity-ledger.md`

## Validation Minimums

- Syntax: `luac -p` on changed Lua files.
- Automated checks: run any impacted local test scripts.
- Manual: in-game verification for scene/keybind/list behavior touched by the change.

## Review Checklist

- Does the change solve the requested problem directly?
- Were unrelated files avoided?
- Are edge conditions and cleanup paths covered?
- Are docs and planning artifacts synchronized?
