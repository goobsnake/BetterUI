---
description: End-of-session closeout workflow that enforces AGENTS compliance, zero-deferral review/integrity loops, and final commit hygiene
---

# Wrap-Up Workflow

End-of-session closeout with mandatory review and integrity checks.

## Defaults and Gate Rules

1. No deferrals for blocking findings.
2. No commit until review + integrity are clean.
3. Keep scope limited to active changes.

## Stop Conditions

- Any mandatory gate remains BLOCKED/FAILED.
- Active change scope is unclear after baseline + re-anchor checks.
- Required cleanup cannot be completed safely in current workspace state.

## Step 0: Baseline

```powershell
git rev-parse --abbrev-ref HEAD
git rev-parse --short HEAD
git status --short
```

If stale-risk is present (resume/compaction/long gap/workflow switch), run AGENTS Session Compaction Recovery Tier 1 then Tier 2 only if needed.
Optional: run `pwsh -File tools/context_health_check.ps1 -Strict` before final review/integrity loops.

## Step 1: AGENTS Compliance Pass

Validate active changes only:

- New code files follow modular-first rule.
- No fallback masking or empty catch-equivalent blocks.
- Temporary artifacts are not intended for commit.
- Docs changes remain addon-focused.

## Step 2: Sr Review Gate

```text
Follow /sr-review-gate
```

If blocked, fix findings and rerun until PASS.

## Step 3: Verify Integrity

```text
Follow /verify-integrity --full
```

If failed, fix and rerun until PASS.

## Step 4: Final Cleanup

Remove temporary workflow artifacts if present:

- `critical_code_review.md`
- `sr_engineering_team_review.md`
- `implementation_plan.md`

If this was a long session and `docs/CONTINUITY.md` is in play, apply AGENTS Continuity Health Check caps before finishing.

For troubleshooting-heavy sessions, do not backfill trial/error attempts into continuity.
If continuity needs updates per AGENTS policy, do one batched edit in this step.

## Step 5: Commit

```powershell
git add -A
git commit -m "<type(scope): concise summary>"
```

## Step 6: Closeout Report

Provide:

- AGENTS Compliance: PASS/FAIL
- Sr Review Gate: PASS/FAIL
- Verify Integrity: PASS/FAIL
- Deferrals: None
- Commit: `<hash> <message>`

## Output Contract

Return:

- gate statuses: AGENTS compliance, Sr review, integrity
- cleanup status for temporary artifacts
- commit result (`hash` + message) or explicit reason commit was not created
- any unresolved blockers requiring user decision

## Invocation

```text
/wrap-up
```
