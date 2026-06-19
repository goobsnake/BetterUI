#!/bin/bash
# BetterUI Planning-Doc Hygiene Validation
#
# Ensures the open planning docs hold ONLY open/outstanding items: no item
# left marked completed or discarded *in place*. Completed work belongs in
# docs/planning/completed-improvements.md; discarded/invalid work is deleted
# (reason in the commit message). Catches: checked "[x]" items, explicit
# completed/discarded/resolved/closed/done status markers (bracketed, bold,
# or "Status:"-labelled), struck-through items, and table Status cells whose
# value starts with a terminal status word (e.g. "Resolved (2026-06-10)").
#
# Dependency-free (bash + awk). Ported from the ZFF MCP-server suite's
# planning-doc-lint "open-items-only" gate (format-agnostic subset). Exit 0 =
# clean, 1 = violations found, 2 = no planning docs found.
#
# Usage:
#   tools/tests/validate_planning.sh [planning_dir]
# Default planning_dir: <repo>/docs/planning
set -u

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/../.." && pwd)"
planning_dir="${1:-$repo_root/docs/planning}"

files=()
for name in priority-backlog.md feature-requests.md project-improvements.md; do
  [ -f "$planning_dir/$name" ] && files+=("$planning_dir/$name")
done

if [ "${#files[@]}" -eq 0 ]; then
  echo "validate_planning: no planning docs found in $planning_dir" >&2
  exit 2
fi

awk '
function trim(s){ gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
function strip(s){ gsub(/[`*~]/, "", s); return s }
BEGIN{
  split("completed done discarded resolved closed wontfix abandoned", w, " ")
  for (i in w) TERM[w[i]] = 1
  violations = 0
}
FNR==1 { header = 0; statusCol = 0 }
{
  line = $0
  low = tolower(line)
  reason = ""

  if (line ~ /^[ \t]*[-*+][ \t]+\[[xX]\]/)
    reason = "completed item (checked [x])"
  else if (low ~ /\[(completed|done|discarded|resolved|closed|wontfix|abandoned)\]/)
    reason = "completed/discarded marker"
  else if (low ~ /\*\*[ \t]*(completed|done|discarded|resolved|closed|wontfix|abandoned)[ \t]*\*\*/)
    reason = "completed/discarded marker"
  else if (low ~ /status[ \t]*[:=][ \t]*[`*]*[ \t]*(completed|done|discarded|resolved|closed|wontfix|abandoned)/)
    reason = "completed/discarded status"
  else if ((line ~ /^[ \t]*[-*+]/ || line ~ /^[ \t]*\|/) && line ~ /~~[^~]+~~/)
    reason = "struck-through (discarded) item"

  if (reason == "" && line ~ /^[ \t]*\|.*\|[ \t]*$/) {
    n = split(line, cells, "|")
    issep = 1
    for (c = 2; c < n; c++) { t = trim(cells[c]); if (t !~ /^:?-{3,}:?$/) { issep = 0; break } }
    if (issep) { next }
    if (!header) {
      header = 1; statusCol = 0
      for (c = 2; c < n; c++) { if (tolower(strip(trim(cells[c]))) == "status") { statusCol = c; break } }
      next
    }
    if (statusCol > 0 && statusCol < n) {
      val = tolower(strip(trim(cells[statusCol])))
      tok = val; sub(/[ (].*/, "", tok)
      if (tok in TERM) reason = "Status cell \"" trim(cells[statusCol]) "\""
    }
  } else if (line !~ /^[ \t]*\|/) {
    header = 0; statusCol = 0
  }

  if (reason != "") {
    violations++
    printf("%s:%d: %s\n", FILENAME, FNR, reason)
  }
}
END{
  if (violations > 0) {
    printf("\nFAIL: %d planning-doc hygiene violation(s). Migrate completed work to\n", violations)
    print  "completed-improvements.md and delete discarded items; these docs hold only open items."
    exit 1
  }
  print "[OK] Planning docs hold only open/outstanding items."
}
' "${files[@]}"
