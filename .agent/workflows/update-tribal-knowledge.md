---
description: Structured session to capture API quirks, gotchas, and lessons learned into TRIBAL_KNOWLEDGE.md
---

# Update Tribal Knowledge Workflow

A guided introspection session to document ESO API behaviors, BetterUI gotchas, and lessons learned.

## Prerequisites

See `AGENTS.md` for project context and `docs/CONTINUITY.md` for session state.

---

## Purpose

`docs/TRIBAL_KNOWLEDGE.md` captures hard-won knowledge that:
- Isn't documented in ESO API references
- Would cause future developers to waste time rediscovering
- Represents non-obvious behavior or edge cases

This workflow ensures we don't lose learnings from each development session.

---

## Step 1: Review Current Knowledge

Read the existing tribal knowledge to avoid duplicates:

```powershell
type docs\TRIBAL_KNOWLEDGE.md
```

---

## Step 2: Reflect on Recent Work

Consider the last development session and identify:

### API Discoveries
- Did you discover any ESO API behavior that wasn't obvious?
- Did an API behave differently than expected?
- Did you find an undocumented parameter or return value?

### Gotchas Encountered
- What tripped you up during implementation?
- What would you warn a future developer about?
- Were there any timing-sensitive operations?

### Pattern Clarifications
- Did you clarify when to use one pattern over another?
- Did you discover why existing code was written a certain way?

### Debugging Insights
- What was hard to debug and why?
- What logging or tooling would have helped?

---

## Step 3: Format New Entries

For each item worth documenting, format as:

```markdown
### [Brief Title]

**Context**: [When/where this applies]

**The Gotcha**: [What the non-obvious behavior is]

**Solution**: [How to handle it correctly]

**Example** (if applicable):
```lua
-- Code demonstrating the correct approach
```
```

---

## Step 4: Append to Document

Add the new entries to the appropriate section of `TRIBAL_KNOWLEDGE.md`:

| Section | What Goes Here |
|---------|----------------|
| ESO API Behaviors | Undocumented API quirks |
| Scene & Fragment Gotchas | Scene lifecycle issues |
| Gamepad Input | Controller-specific behaviors |
| List & Scroll Behaviors | ZO_ParametricScrollList quirks |
| Keybind System | KEYBIND_STRIP gotchas |
| Performance | Timing and optimization learnings |
| Debugging | Useful debugging techniques |

---

## Step 5: Update Timestamp

Update the "Last Updated" field at the top of the file:

```markdown
> **Last Updated**: {YYYY-MM-DD}
```

---

## Step 6: Commit

```powershell
git add docs/TRIBAL_KNOWLEDGE.md && git commit -m "docs: update tribal knowledge with session learnings"
```

---

## Quick Invocation

At the end of a development session:
```
/update-tribal-knowledge
```

Or:
> "Let's capture what we learned about [topic] in tribal knowledge"

---

## Tips

1. **Be specific** - Include line numbers, function names, and exact behaviors
2. **Include the "why"** - Explain why the behavior is counterintuitive
3. **Add examples** - Code snippets are more valuable than prose
4. **Cross-reference** - Link to related sections or source files
5. **Timestamp discoveries** - Note when each item was learned (helps assess if still relevant)

---

## Questions to Ask After Each Session

Use these prompts to surface tribal knowledge:

1. "What surprised me today?"
2. "What took longer than expected and why?"
3. "If I had to do this again, what would I do differently?"
4. "What did I have to discover through trial and error?"
5. "What would I tell a new developer about this area?"

