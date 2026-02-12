---
description: Perform a critical code review with diff-first defaults and optional comprehensive scope
---

# Code Review Workflow

Critical review workflow with low-quota defaults and optional deep-audit expansion.

## Defaults

- Scope default: active diff (`git diff --name-only HEAD`).
- Output default: actionable findings in chat (no file artifacts).
- Escalate to full-module/full-repo review only when requested or risk demands it.
- Continuity default: read-only during review; avoid `docs/CONTINUITY.md` edits for intermediate findings.

## Scope Modes

| Scope | Trigger | Typical Use |
|-------|---------|-------------|
| `--diff` (default) | no scope flag | Normal PR/task review |
| `--module <name>` | targeted | Focused module health check |
| `--comprehensive` | explicit | Release-level or architecture audit |

## Output Modes

| Mode | Trigger | Behavior |
|------|---------|----------|
| `--report` (default) | no output flag | Findings only |
| `--todo` | explicit | Add `TODO(type):` markers |
| `--action` | explicit | Implement fixes now via plan + gates |
| `--persist-artifacts` | optional | Write `critical_code_review.md` / `implementation_plan.md` when needed |

## Step 0: Resume Guard (if state is stale)

Use AGENTS Context Freshness Protocol:

1. Tier 1 fingerprint (`branch`, `HEAD`, `git status --short`).
2. Optional quick health snapshot: `pwsh -File tools/context_health_check.ps1`.
3. Targeted continuity scan for `Done/Now/Next`, `Working set`, and open questions.
4. Tier 2 (`git diff --name-only HEAD` + artifact discovery) only if still unclear.
5. If review scope and recovered state conflict, stop and confirm with user before continuing.

## Step 1: Build Review Scope

Default scope:

```powershell
git diff --name-only HEAD
```

For comprehensive scope:

```powershell
rg --files Modules -g "*.lua" -g "*.xml"
```

## Step 2: Run Critical Review

Review with Principal-level rigor. Prioritize:

1. Behavior regressions and crash risks
2. Architecture/pattern drift (CIM, scene lifecycle, keybind cleanup)
3. Error handling misuse and fallback masking
4. Duplication and inconsistent settings/state handling
5. Validation gaps (missing tests/syntax/runtime checks)

Use targeted pattern scans.

For `--diff` scope, run scans only on changed files:

```powershell
$changed = git diff --name-only HEAD | Where-Object { $_ -match "^(Modules/|BetterUI\\.lua$|BetterUI\\.txt$)" }
$changed = $changed | Where-Object { Test-Path -LiteralPath $_ }
if ($changed) {
    rg -n "d\\(" -- $changed
    rg -n "TODO|FIXME|HACK|XXX" -- $changed
    rg -n "pcall|xpcall|SafeExecute" -- $changed
}
```

For `--module` or `--comprehensive`, use broader scans:

```powershell
rg -n "d\\(" Modules
rg -n "TODO|FIXME|HACK|XXX" Modules
rg -n "pcall|xpcall|SafeExecute" Modules
```

## Step 3: Report Findings

Report findings ordered by severity with file references.

Required response structure:

```markdown
## Findings

### CRITICAL
- [Issue] `path/to/file.lua:line`

### MAJOR
- [Issue] `path/to/file.lua:line`

### MODERATE
- [Issue] `path/to/file.lua:line`

### MINOR
- [Issue] `path/to/file.lua:line`

## Residual Risks
- [Any unverified assumptions]
```

If no findings: explicitly state that and list residual test/coverage gaps.

## Step 4: Action Path (`--action`)

1. Build `implementation_plan.md` only if multi-step work is required.
2. Run `/sr-review-gate --plan-review`.
3. Implement fixes in phases.
4. Run `/sr-review-gate --phase-review` after each phase.
5. Run `/verify-integrity`.
6. If accepted fixes materially changed addon state, do one batched continuity update after the action loop (not per phase iteration).

## Step 5: Artifact Policy

- Do not create review artifacts unless `--persist-artifacts` is requested or work spans multiple phases.
- Remove temporary artifacts before commit.

## Invocation

```text
/code-review
/code-review --module Inventory
/code-review --comprehensive --report
/code-review --diff --action
```
