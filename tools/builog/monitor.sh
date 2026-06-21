#!/usr/bin/env bash
#
# tools/builog/monitor.sh — tail BetterUI's live interface.log breadcrumb stream and
# emit periodic, AI-decipherable samples so an assistant can watch a play-test in real
# time. Pairs with the builog-monitor skill (tools/builog/SKILL.md, same dir).
#
# Usage:
#   tools/builog/monitor.sh [minutes] [interval_seconds] [log_path]
#
#   minutes          how long to watch (default 2). Fractional ok (e.g. 0.5).
#   interval_seconds seconds between samples (default 10). 5 to pinpoint a repro,
#                    15-20 for long/quiet sessions.
#   log_path         path to interface.log. Default: $BUILOG_INTERFACE_LOG, else the
#                    Proton/Steam path below. Override for other OSes:
#                      Windows: <Documents>/Elder Scrolls Online/live/Logs/interface.log
#                      macOS:   ~/Documents/Elder Scrolls Online/live/Logs/interface.log
#
# Prerequisite in-game: /builog preset inspect   (richest stream: trace depth + watch
# enrichment). Lighter options: watch | debug | trace. /builog status shows counters.
#
# Output: one "----- sample N -----" block per interval (BUI line count, level mix,
# real game errors with messages, rate-limit drops, parse-contract violations, our own
# WARN/ERROR breadcrumbs, and a short trail), then a "===== totals =====" footer.
# Exit 0 normally, 1 if the log file cannot be found.

set -u

MINUTES="${1:-2}"
INTERVAL="${2:-10}"
DEFAULT_LOG="/mnt/steamstorage/SteamLibrary/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live/Logs/interface.log"
LOG="${3:-${BUILOG_INTERFACE_LOG:-$DEFAULT_LOG}}"

if [ ! -f "$LOG" ]; then
  echo "BUILOG MONITOR: interface.log not found at:" >&2
  echo "  $LOG" >&2
  echo "Pass the path as arg 3 or set BUILOG_INTERFACE_LOG. The file appears once ESO has" >&2
  echo "logged at least one line this session (any Lua error, or /builog on)." >&2
  exit 1
fi

# Number of samples = ceil(minutes*60 / interval), at least 1.
SAMPLES=$(awk -v m="$MINUTES" -v i="$INTERVAL" 'BEGIN{ n=(m*60)/i; n=(n==int(n))?n:int(n)+1; if(n<1)n=1; print n }')

start_lines=$(wc -l < "$LOG")
last=$start_lines
tb=0; te=0; ti=0; td=0; tp=0   # totals: BUI, non-BUI errs, Id64 errs, drop-summaries, parse violations

echo "=== builog monitor: ${MINUTES}min @ ${INTERVAL}s ($SAMPLES samples) | start line=$start_lines @ $(date +%H:%M:%S) ==="
echo "    log: $LOG"

for i in $(seq 1 "$SAMPLES"); do
  sleep "$INTERVAL"
  cur=$(wc -l < "$LOG")
  if [ "$cur" -le "$last" ]; then
    echo "----- sample $i [$(date +%H:%M:%S)] +0 lines -----"
    last=$cur
    continue
  fi
  chunk=$(sed -n "$((last+1)),${cur}p" "$LOG")

  bui=$(printf '%s\n' "$chunk" | grep -c '\[BUI\]')
  errs=$(printf '%s\n' "$chunk" | grep 'Lua Error:' | grep -v '\[BUI\]')
  errc=$(printf '%s\n' "$errs" | grep -c .)
  id64=$(printf '%s\n' "$chunk" | grep -c 'Id64ToString_lua')
  drop=$(printf '%s\n' "$chunk" | grep -c 'reason=rate_limit')
  # parse-contract: a valid [BUI] line has exactly ONE " | " (level/cat -> event). >1 means
  # a value injected the field separator and would corrupt a logfmt parser.
  parse=$(printf '%s\n' "$chunk" | grep '\[BUI\]' | awk -F' \\| ' 'NF>2' | head -5)
  parsec=$(printf '%s\n' "$parse" | grep -c .)
  # level mix across this window's [BUI] lines
  levels=$(printf '%s\n' "$chunk" | grep -oE '\[BUI\][^|]* (TRACE|DEBUG|INFO|WARN|ERROR) ' \
            | grep -oE '(TRACE|DEBUG|INFO|WARN|ERROR)' | sort | uniq -c \
            | awk '{printf "%s=%s ", $2, $1}')

  tb=$((tb+bui)); te=$((te+errc)); ti=$((ti+id64)); td=$((td+drop)); tp=$((tp+parsec))
  echo "----- sample $i [$(date +%H:%M:%S)] +$bui BUI, +$errc non-BUI-err, id64=$id64, drops=$drop -----"
  [ -n "$levels" ] && echo "  levels: $levels"
  if [ "$errc" -gt 0 ]; then
    echo "  !! NON-BUI errors (real game/addon — investigate):"
    printf '%s\n' "$errs" | sed 's/|c[0-9a-fA-F]*//g; s/|r//g; s/^[0-9T:.+-]* //' \
      | sort | uniq -c | sort -rn | head -10 | sed 's/^/     /'
  fi
  if [ "$parsec" -gt 0 ]; then
    echo "  !! PARSE-CONTRACT violation (>1 field separator):"
    printf '%s\n' "$parse" | sed 's/^/     /'
  fi
  warns=$(printf '%s\n' "$chunk" | grep '\[BUI\]' | grep -E ' (WARN|ERROR) ')
  if [ -n "$warns" ]; then
    echo "  !! BUI WARN/ERROR:"
    printf '%s\n' "$warns" | sed 's/.*\[BUI\]/[BUI]/; s/|r$//' | head -8 | sed 's/^/     /'
  fi
  echo "  trail (last 10 BUI):"
  printf '%s\n' "$chunk" | grep '\[BUI\]' | tail -10 | sed 's/.*\[BUI\]/[BUI]/; s/|r$//' | sed 's/^/     /'
  last=$cur
done

end=$(wc -l < "$LOG")
echo "===== totals ====="
echo "file lines: start=$start_lines end=$end (+$((end-start_lines)))"
echo "[BUI]=$tb | non-BUI errors=$ti(Id64) of $te total | rate_limit drop-summaries=$td | parse violations=$tp"
echo "(0 non-BUI errors + 0 parse violations + 0 drops = clean. Any non-zero -> notate above.)"
