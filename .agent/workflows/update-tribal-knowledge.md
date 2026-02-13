---
description: Structured session to capture API quirks, gotchas, and lessons learned into TRIBAL_KNOWLEDGE.md
---

# Update Tribal Knowledge Workflow

Capture durable, non-obvious BetterUI/ESO learnings with minimal overhead.

## Defaults

- Write only durable findings (not trial-and-error logs).
- Prefer concise entries with concrete evidence pointers.
- Skip updates when there is no new durable knowledge.

## Stop Conditions

- No new API quirks, gotchas, or reusable patterns were discovered.
- Finding is transient or superseded by recent code without stable evidence.

## Step 0: Context Guard

If session context may be stale (resume/compaction/long gap), run AGENTS Session Compaction Recovery Tier 1 first.

## Step 1: Check for Existing Coverage

Read and search for potential duplicate topics:

```powershell
type docs\TRIBAL_KNOWLEDGE.md
rg -n "keyword|function|api_name" docs/TRIBAL_KNOWLEDGE.md
```

## Step 2: Select Durable Learnings

Include only items that are likely to matter again:

- ESO API behavior that is undocumented/counterintuitive
- BetterUI-specific lifecycle or input gotcha
- Reusable debugging/mitigation pattern

## Step 3: Add Entry Using Compact Template

```markdown
### [Title]
**Context**: [Where this applies]
**Gotcha**: [Non-obvious behavior]
**Mitigation**: [Reliable handling pattern]
**Evidence**: [file/path or command pointer]
```

Add code snippets only when they materially reduce ambiguity.

## Step 4: Maintain Top Metadata

Update the `Last Updated` date at the top of `docs/TRIBAL_KNOWLEDGE.md`.

## Step 5: Optional Commit

```powershell
git add docs/TRIBAL_KNOWLEDGE.md
git commit -m "docs: update tribal knowledge with session learnings"
```

## Output Contract

Return:

- `Added`: titles of new entries (or `None`)
- `Skipped`: reason if no update was made
- `Diff`: confirmation that only intended doc paths changed

## Invocation

```text
/update-tribal-knowledge
```

