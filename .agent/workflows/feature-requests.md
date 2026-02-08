---
description: Scan esoui reference folder for gamepad QoL features BetterUI lacks, then update docs/FEATURE_REQUESTS.md
---

# Feature Requests Workflow

Comprehensive scan of the `esoui/` gamepad reference folder cross-referenced against BetterUI's current modules. Identifies QoL features, UI patterns, and enhancement opportunities that BetterUI does not yet implement, then updates `docs/FEATURE_REQUESTS.md` with new findings.

## Prerequisites

See `AGENTS.md` for project context, skills, and workflows.

---

## Step 0: Resume Guard (Required on resumed/compacted sessions)

1. Execute `AGENTS.md` → **Session Compaction Recovery (Required)**.
2. Apply `AGENTS.md` → **Quota Efficiency Defaults** before starting scans.

---

## Scope Configuration

| Scope | esoui Coverage | BetterUI Comparison | Use When |
|-------|----------------|---------------------|----------|
| `--quick` | ~20 key gamepad folders | Current modules only | Fast gap check |
| `--standard` | ~60 gamepad folders (default) | Current + adjacent modules | Regular feature audit |
| `--comprehensive` | All 130+ gamepad folders | Full codebase | Major roadmap planning |

If user doesn't specify, use **Standard** scope.

---

## Output Mode

| Mode | Action | Use When |
|------|--------|----------|
| (none) | Update `docs/FEATURE_REQUESTS.md` | Default — refresh the feature request doc |
| `--report-only` | Print findings without writing | Discovery, discussion |
| `--diff` | Show only new/changed items vs. existing doc | Incremental updates |

---

## Phase 1: Inventory Current BetterUI Capabilities

Before scanning esoui, establish what BetterUI already does.

### 1.1 Map Current Modules

Scan the module structure to understand coverage:

```
rg --files Modules -g "*.lua" | head -20
```

Build a capability table:

| Module | Scope | Key Features |
|--------|-------|--------------|
| CIM | Shared framework | Lists, headers, footers, search, sort, settings, tooltips, keybinds |
| Banking | Personal/house bank | Categories, currency transfer, column sort, search, multi-currency |
| Inventory | Backpack/craft bag | Categories, multi-select, search, sort, actions, junk |
| ResourceOrbFrames | Combat UI | Resource orbs, skill bars, ultimate, cast bar, XP bar |
| WritUnit | Crafting writs | Writ progress display at crafting stations |

### 1.2 Read Existing Feature Requests

Read `docs/FEATURE_REQUESTS.md` to understand what's already documented:

```
Read docs/FEATURE_REQUESTS.md
```

Note the existing recommendations and their priority assignments. New findings should be merged, not duplicated.

---

## Phase 2: Scan esoui Gamepad Systems

Systematically explore the `esoui/` reference folder for gamepad-specific features.

### 2.1 Map Gamepad Directory Structure

Get a high-level view of all gamepad-specific directories:

```
find esoui -type d -name "gamepad" | sort
```

This reveals the full scope of gamepad subsystems.

### 2.2 Categorized Deep Scan

Scan each category in order of relevance to BetterUI's mission:

#### Category A: Item Management (Highest Priority)
Directly adjacent to BetterUI's current scope.

| esoui Path | What to Look For |
|------------|-----------------|
| `esoui/ingame/inventory/gamepad/` | Stat comparison, new item tracking, stack consolidation, companion items |
| `esoui/ingame/banking/gamepad/` | Guild bank features, currency handling, permission systems |
| `esoui/ingame/zo_loot/gamepad/` | Loot window features, loot history, quality indicators |
| `esoui/ingame/quickslot/gamepad/` | Radial wheel, quickslot management |
| `esoui/ingame/storewindow/gamepad/` | Vendor buy/sell/repair, price display, batch operations |
| `esoui/ingame/fence/gamepad/` | Stolen goods laundering |
| `esoui/ingame/tradinghouse/gamepad/` | Guild store search, listing, autocomplete |
| `esoui/ingame/repair/gamepad/` | Repair UI |

**For each directory:** Read the main `*_gamepad.lua` file, note features, keybinds, and UI patterns.

#### Category B: Crafting & Production (High Priority)
Extends WritUnit's domain.

| esoui Path | What to Look For |
|------------|-----------------|
| `esoui/ingame/crafting/gamepad/` | All crafting station UIs, craft advisor, set stations |
| `esoui/ingame/retrait/gamepad/` | Trait changing |
| `esoui/ingame/restyle/gamepad/` | Outfit management |
| `esoui/ingame/dyeing/gamepad/` | Dye system |

#### Category C: Social & Communication (Medium Priority)
New territory for BetterUI.

| esoui Path | What to Look For |
|------------|-----------------|
| `esoui/ingame/mail/gamepad/` | Mail inbox/compose, attachments, COD |
| `esoui/ingame/guild/gamepad/` | Guild roster, management, selector |
| `esoui/ingame/contacts/gamepad/` | Friends list, ignore list |
| `esoui/ingame/chatsystem/gamepad/` | Chat improvements |
| `esoui/ingame/tradinghouse/gamepad/` | (covered in Category A) |

#### Category D: Navigation & Progression (Medium Priority)

| esoui Path | What to Look For |
|------------|-----------------|
| `esoui/ingame/map/gamepad/` | Map filters, quest tracking, zone stories |
| `esoui/ingame/skills/gamepad/` | Skill management, action bar assignment |
| `esoui/ingame/champion/gamepad/` | Champion point allocation |
| `esoui/ingame/collections/gamepad/` | Collectibles, item sets, outfit selector |
| `esoui/ingame/companion/gamepad/` | Companion equipment and skills |

#### Category E: Group & PvP (Lower Priority)

| esoui Path | What to Look For |
|------------|-----------------|
| `esoui/ingame/groupfinder/gamepad/` | Group finder, role selection |
| `esoui/ingame/lfg/gamepad/` | Activity finder, queue status |
| `esoui/ingame/campaign/gamepad/` | PvP campaigns |

#### Category F: Infrastructure Patterns (Cross-Cutting)

| esoui Path | What to Look For |
|------------|-----------------|
| `esoui/common/gamepad/` | Parametric lists, grids, quadrants, headers |
| `esoui/libraries/zo_focus/gamepad/` | Focus management |
| `esoui/libraries/zo_radialmenu/` | Radial menu system |
| `esoui/common/zo_tooltip/gamepad/` | Tooltip infrastructure |

**For infrastructure:** Focus on patterns and APIs that BetterUI's CIM doesn't yet leverage.

### 2.3 Efficient Scanning Strategy

For **Standard** scope, prioritize Categories A-C and F. For **Quick**, Category A and F only. For **Comprehensive**, all categories.

**Per-file review approach:**
1. Read file header and class definition (first ~50 lines)
2. Scan for keybind definitions (search `keybind`)
3. Scan for feature-defining functions (search `function.*:Initialize`, `function.*:Setup`)
4. Scan for unique patterns not in BetterUI (search for API calls, dialog types, animation systems)
5. Note QoL features with specific line references

**Use targeted search to find features efficiently:**

```
rg -n "GAMEPAD_TOOLTIPS:Layout" esoui/ingame/inventory/gamepad/
rg -n "UI_SHORTCUT" esoui/ingame/inventory/gamepad/
rg -n "ZO_Dialogs_ShowGamepadDialog" esoui/ingame/
rg -n "SCREEN_NARRATION_MANAGER" esoui/ingame/ --files-with-matches
rg -n "ZO_RadialMenu" esoui/ --files-with-matches
```

---

## Phase 3: Cross-Reference and Identify Gaps

### 3.1 Build Gap Matrix

For each esoui feature discovered, check if BetterUI implements it:

```markdown
| esoui Feature | esoui File | BetterUI Module | Status |
|---------------|-----------|-----------------|--------|
| Stat comparison tooltip | gamepadinventory.lua:2050 | Inventory | MISSING |
| Stack All keybind | gamepadinventory.lua:804 | Inventory | MISSING |
| Guild bank permissions | guildbank_gamepad.lua | Banking | MISSING |
| Screen narration | (300+ files) | CIM | MISSING |
| ... | ... | ... | ... |
```

Status values:
- **MISSING** — esoui has it, BetterUI doesn't
- **PARTIAL** — BetterUI has a basic version, esoui has more
- **IMPLEMENTED** — BetterUI already covers this (skip)
- **IMPROVED** — BetterUI's version is better than stock (skip)

### 3.2 Classify New Findings

For each MISSING or PARTIAL item, classify:

| Field | Description |
|-------|-------------|
| **Feature name** | Short descriptive title |
| **esoui source** | File path and line references |
| **What the base game has** | Detailed description of the feature |
| **What BetterUI lacks** | Specific gap analysis |
| **Implementation notes** | How to build it, which CIM patterns to reuse |
| **User impact** | Low / Medium / High / Very High |
| **Dev effort** | Very Low / Low / Medium / High |
| **CIM synergy** | How well existing infrastructure supports it |

### 3.3 Assign Priority

Use the priority scheme from `docs/FEATURE_REQUESTS.md`:

| Priority | Criteria |
|----------|----------|
| **P0** | Low effort, fixes a regression or critical gap |
| **P1** | High value, achievable quickly — quick wins or natural extensions |
| **P2** | High value, moderate effort — new modules leveraging CIM |
| **P3** | Medium value, higher effort — worthwhile but can wait |
| **P4** | Medium value, high effort — long-term roadmap items |

---

## Phase 4: Update Feature Requests Document

### 4.1 Merge Strategy

When updating `docs/FEATURE_REQUESTS.md`:

1. **Keep existing entries** that are still valid (not yet implemented)
2. **Remove entries** for features that have since been implemented
3. **Update entries** whose priority or details have changed
4. **Add new entries** discovered in this scan
5. **Preserve the document structure**: Overview, TOC, numbered sections, Priority Matrix

### 4.2 For Each New Feature

Add a section following the established format:

```markdown
## N. Feature Title

**esoui source:** `esoui/path/to/file.lua` (lines ~X-Y)

### What the base game has

[Detailed description with bullet points]

### What BetterUI lacks

[Gap analysis — what's missing and why it matters]

### Implementation notes

- [Technical approach]
- [CIM patterns to reuse]
- [New files/modules needed]
- [Effort estimate]
```

### 4.3 Update Priority Matrix

Rebuild the priority matrix table at the bottom of the doc, incorporating both existing and new entries. Re-evaluate priorities based on:

- Current module state (has anything changed since last audit?)
- New CIM capabilities that lower effort for previously hard items
- User feedback or community demand shifts
- Dependencies between features (e.g., stat comparison benefits companion equipment)

### 4.4 Update Recommended Implementation Order

Refresh the ordered implementation sequence based on updated priorities.

---

## Phase 5: Summary and Next Steps

### 5.1 Print Change Summary

After updating the document, print a concise summary:

```markdown
## Feature Requests Update Summary

**Date**: {YYYY-MM-DD}
**Scope**: [quick / standard / comprehensive]

### Changes
- **Added**: X new feature requests
- **Updated**: Y existing entries (priority/detail changes)
- **Removed**: Z entries (now implemented)
- **Unchanged**: W entries

### New Additions
1. [Feature name] — [Priority] — [One-line description]
2. ...

### Priority Shifts
- [Feature name]: P3 → P2 (reason)
- ...
```

### 5.2 Update Continuity Ledger

If meaningful changes were made, update `docs/CONTINUITY.md` with a receipt entry:

```
| {date} | [TOOL] | Feature requests audit ({scope}): added X new, updated Y, removed Z implemented items |
```

---

## Command Reference

| Command | Scope | Output | Typical Duration |
|---------|-------|--------|------------------|
| `/feature-requests` | Standard (~60 folders) | Updates FEATURE_REQUESTS.md | ~20-30 min |
| `/feature-requests --quick` | ~20 key folders | Updates FEATURE_REQUESTS.md | ~10-15 min |
| `/feature-requests --comprehensive` | All 130+ folders | Updates FEATURE_REQUESTS.md | ~45-60 min |
| `/feature-requests --report-only` | Default scope | Print only, no file changes | Varies |
| `/feature-requests --diff` | Default scope | Show only new/changed items | Varies |

---

## Tips

1. **Use parallel sub-agents** for comprehensive scans — split by category (A-F) for speed
2. **Read headers first** — most gamepad files declare their features in the first 50 lines
3. **Search for keybinds** — `UI_SHORTCUT_*` patterns quickly reveal user-facing features
4. **Check for narration** — `SCREEN_NARRATION_MANAGER` presence indicates accessibility features
5. **Cross-reference CIM** — many "missing" features may be easy to add if CIM already has the infrastructure
6. **Don't duplicate** — always read existing `docs/FEATURE_REQUESTS.md` before adding entries
7. **Prioritize adjacency** — features closest to existing modules (Banking, Inventory) have highest CIM synergy
