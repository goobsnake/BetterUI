---
description: Update docs/ChangeLog.txt for the upcoming release by auditing all commits since the last changelog update and filtering internal dev-cycle fix churn
---

# Update ChangeLog Workflow

Use this workflow to keep `docs/ChangeLog.txt` accurate for the **next upcoming release**.

## Prerequisites

See `AGENTS.md` for project context and `docs/CONTINUITY.md` for session state.
If resumed/compacted, execute `AGENTS.md` → **Session Compaction Recovery (Required)** and **Quota Efficiency Defaults** first.

---

## Goal

1. Review **all commits** from the commit where `docs/ChangeLog.txt` was last changed through `HEAD` on the current branch.
2. Update `docs/ChangeLog.txt` to reflect final, user-facing release notes.
3. Exclude internal stabilization churn (fixes for bugs introduced and resolved during the same unreleased cycle).

---

## Step 1: Determine Audit Range

Identify branch, anchor commit, and commit range:

```powershell
$branch = git rev-parse --abbrev-ref HEAD
$changelogAnchor = git log -n 1 --format="%H" -- docs/ChangeLog.txt
$range = "$changelogAnchor..HEAD"
$commitCount = git rev-list --count $range
Write-Host "Branch: $branch"
Write-Host "Anchor: $changelogAnchor"
Write-Host "Range: $range"
Write-Host "Commits in range: $commitCount"
```

If `commitCount` is `0`, stop: no changelog update is needed.

---

## Step 2: Build Comprehensive Commit Ledger

Capture every commit (including merge commits) in the range:

```powershell
$summaryOut = Join-Path $env:TEMP "betterui_changelog_commit_summary.txt"
$detailOut = Join-Path $env:TEMP "betterui_changelog_commit_detail.txt"

git log --reverse --date=short --format="%H|%ad|%s|%an" $range | Out-File -FilePath $summaryOut -Encoding UTF8
git log --reverse --date=short --name-only --format="---%n%H|%ad|%s|%an" $range | Out-File -FilePath $detailOut -Encoding UTF8

Write-Host "Summary: $summaryOut"
Write-Host "Detail:  $detailOut"
```

Then review both files end-to-end before editing `docs/ChangeLog.txt`.

---

## Step 3: Classify Commits

Classify each commit into one of these buckets:

1. **User-Facing Release Notes**: New features, improvements, behavior changes, or fixes users can experience.
2. **Internal Stabilization**: Follow-up corrections to in-cycle development issues.
3. **Non-Release-Note Noise**: Agent/workflow/docs-only changes, refactors without user impact, formatting-only edits.

Use commit subject + touched files + final code state to decide.

Runtime eligibility rule (required):
- A changelog bullet is valid only if backed by one or more commits that touch BetterUI runtime addon paths:
  - `Modules/**`
  - `lang/**`
  - `BetterUI.lua`
  - `BetterUI.txt`
- Commits that only touch `.agent/**`, `.claude/**`, `AGENTS.md`, `CLAUDE.md`, or `docs/**` are never valid sources for release-note bullets.

---

## Step 4: Filter Internal Dev-Cycle Fixes (Required)

Do **not** list a bug fix as a standalone changelog item when all are true:

1. The bug was introduced by a commit inside the same audited range, and
2. The fix also happened inside the same audited range, and
3. There is no evidence users saw that broken state in a public release.

When this happens:
- Fold the correction into the final feature/improvement note, or
- Omit it entirely if it was purely internal churn.

Keep a bug-fix entry only when it clearly impacted released/user-visible behavior (for example: longstanding issue, user-reported live issue, or pre-existing regression from older releases).

If uncertain whether users were impacted, mark as `UNCONFIRMED` and ask the user.

---

## Step 5: Update docs/ChangeLog.txt

Edit the upcoming release section at the top of `docs/ChangeLog.txt`:

1. Add missing release-note items from the audited range.
2. Edit inaccurate/outdated bullets to match final shipped behavior.
3. Remove bullets that are internal churn or no longer true after follow-up commits/reverts.

Formatting rules:
- Preserve existing changelog style (`Current Release - vX.XX Changes:`, `[INDENT] ... [/INDENT]`, numbered list).
- Keep numbering contiguous.
- Prefer concise user-impact language.

---

## Step 6: Verification

Before finishing:

1. Every changelog bullet maps to one or more commits in `$range`.
2. No internal-only stabilization fix is listed as user-facing.
3. No obvious user-facing commit is missing.
4. Changelog text reflects final post-range code state (not intermediate broken states).
5. Every bullet maps to runtime addon code paths, not agent/workflow/docs-only commits.

Helpful checks:

```powershell
git diff -- docs/ChangeLog.txt
git log --reverse --oneline $range
```

---

## Step 7: Optional Gate + Commit

For major changelog rewrites, optionally run:

```text
Follow /sr-review-gate
```

Then commit:

```powershell
git add docs/ChangeLog.txt
git commit -m "docs(changelog): update notes for upcoming release"
```

---

## Quick Invocation

```text
/update-changelog
```
