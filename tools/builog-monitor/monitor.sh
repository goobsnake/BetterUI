#!/usr/bin/env bash
#
# tools/builog-monitor/monitor.sh — tail BetterUI's live interface.log breadcrumb stream and
# emit periodic, AI-decipherable samples so an assistant can watch a play-test in real
# time. Pairs with the builog-monitor skill (tools/builog-monitor/SKILL.md, same dir).
#
# Usage:
#   tools/builog-monitor/monitor.sh [minutes] [interval_seconds] [log_path] [screenshot_dir]
#   tools/builog-monitor/monitor.sh digest [--since <ISO>] [--last <n-lines>] [--jsonl] [log_path|remote]
#
#   minutes          how long to watch (default 2). Fractional ok (e.g. 0.5).
#   interval_seconds seconds between samples (default 10). 5 to pinpoint a repro,
#                    15-20 for long/quiet sessions.
#   log_path         path to interface.log, a mounted filesystem path, or "remote".
#                    Default: $BUILOG_INTERFACE_LOG, else the Proton/Steam path below.
#                    Remote alias default (goobers CIFS mount at /mnt/eso):
#                      /mnt/eso/live/Logs/interface.log
#                    Override for other OSes:
#                      Windows: <Documents>/Elder Scrolls Online/live/Logs/interface.log
#                      macOS:   ~/Documents/Elder Scrolls Online/live/Logs/interface.log
#   screenshot_dir   path to live/Screenshots, or "remote". Default: derived from
#                    log_path, or $BUILOG_SCREENSHOT_DIR when set. "remote" uses
#                    $BUILOG_REMOTE_SCREENSHOT_DIR (default /mnt/eso/live/Screenshots).
#                    Local default:
#                      /mnt/steamstorage/SteamLibrary/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live/Screenshots
#                    Remote default:
#                      /mnt/eso/live/Screenshots
#   digest           parse an existing log window into timelines, anomalies, real Lua
#                    errors, drop summaries, screenshots, and optional JSONL records.
#
# Prerequisite in-game: /builog preset inspect   (richest stream: trace depth + watch
# enrichment). Lighter options: watch | debug | trace. /builog status shows counters.
#
# Output: one "----- sample N -----" block per interval (BUI line count, level mix,
# real game errors with messages, normal/priority rate-limit drops, parse-contract violations, our own
# WARN/ERROR breadcrumbs, and a short trail), then a "===== totals =====" footer.
# Replay-critical economy records may appear under ACTION or TRANSFER.
# Exit 0 normally, 1 if the log file cannot be found.

set -u

MODE="watch"
if [ "${1:-}" = "digest" ]; then
  MODE="digest"
  shift
fi

MINUTES="${1:-2}"
INTERVAL="${2:-10}"
DEFAULT_LOG="/mnt/steamstorage/SteamLibrary/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live/Logs/interface.log"
REMOTE_LOG="${BUILOG_REMOTE_INTERFACE_LOG:-/mnt/eso/live/Logs/interface.log}"
LOG_REQUEST="${3:-${BUILOG_INTERFACE_LOG:-$DEFAULT_LOG}}"
DEFAULT_SCREENSHOT_DIR="/mnt/steamstorage/SteamLibrary/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live/Screenshots"
REMOTE_SCREENSHOT_DIR="${BUILOG_REMOTE_SCREENSHOT_DIR:-/mnt/eso/live/Screenshots}"
SCREENSHOT_REQUEST="${4:-${BUILOG_SCREENSHOT_DIR:-}}"

die() {
  printf 'BUILOG MONITOR: %s\n' "$*" >&2
  exit 1
}

resolve_log_request() {
  local request="$1"
  case "$request" in
    remote|REMOTE|--remote) request="$REMOTE_LOG" ;;
  esac
  printf '%s\n' "$request"
}

derive_screenshot_dir() {
  local log_path="$1"
  case "$log_path" in
    */Logs/interface.log|*/Logs/Interface.log|*/logs/interface.log)
      printf '%s/Screenshots\n' "${log_path%/*/*}"
      return 0
      ;;
  esac

  case "$LOG_REQUEST" in
    remote|REMOTE|--remote)
      printf '%s\n' "$REMOTE_SCREENSHOT_DIR"
      ;;
    *)
      printf '%s\n' "$DEFAULT_SCREENSHOT_DIR"
      ;;
  esac
}

resolve_screenshot_request() {
  local request="$1"
  case "$request" in
    remote|REMOTE|--remote) request="$REMOTE_SCREENSHOT_DIR" ;;
  esac

  case "$request" in
    "") derive_screenshot_dir "$LOG" ;;
    *) printf '%s\n' "$request" ;;
  esac
}

run_digest() {
  local jsonl=0
  local since=""
  local last_lines=""
  local log_request="${BUILOG_INTERFACE_LOG:-$DEFAULT_LOG}"
  local log_path
  local iso_ts_re='^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}([.][0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})?$'

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --jsonl)
        jsonl=1
        ;;
      --since)
        shift
        [ "$#" -gt 0 ] || die "digest --since requires an ISO timestamp"
        since="$1"
        ;;
      --last)
        shift
        [ "$#" -gt 0 ] || die "digest --last requires a line count"
        last_lines="$1"
        awk -v n="$last_lines" 'BEGIN { exit !(n ~ /^[0-9]+$/ && n > 0) }' || die "digest --last must be a positive integer: $last_lines"
        ;;
      --help|-h)
        cat <<'EOF'
Usage:
  tools/builog-monitor/monitor.sh digest [--since <ISO>] [--last <n-lines>] [--jsonl] [log_path|remote]

Reads an existing interface.log window and prints a flow-oriented digest. With --jsonl,
prints one JSON object per parsed [BUI] record for machine ingestion.
EOF
        return 0
        ;;
      *)
        log_request="$1"
        ;;
    esac
    shift
  done

  if [ -n "$since" ] && [[ ! "$since" =~ $iso_ts_re ]]; then
    die "digest --since must be an ISO-8601 timestamp, for example 2026-07-02T06:00:00Z: $since"
  fi

  log_path="$(resolve_log_request "$log_request")"
  [ -f "$log_path" ] || die "interface.log not found at: $log_path"

  if [ -n "$last_lines" ]; then
    tail -n "$last_lines" "$log_path"
  else
    sed -n '1,$p' "$log_path"
  fi | awk -v since="$since" -v jsonl="$jsonl" '
function esc(s) {
  gsub(/\\/,"\\\\",s)
  gsub(/"/,"\\\"",s)
  gsub(/\t/,"\\t",s)
  gsub(/\r/,"",s)
  return s
}
function clean_line(s) {
  gsub(/\|c[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]/, "", s)
  gsub(/\|r/, "", s)
  return s
}
function add_line(name, value) {
  if (value == "") value = "none"
  return name ": " value
}
function remember_group(corr, summary, event, phase) {
  if (corr == "") return
  if (!(corr in seenGroup)) {
    groupOrder[++groupCount] = corr
    seenGroup[corr] = 1
  }
  groupLines[corr] = groupLines[corr] "\n    " summary
  if (event == "input.keybind") groupCause[corr] = summary
  if (phase ~ /^(completed|confirmed|settled|end|skipped|failed|blocked|expired)$/) groupOutcome[corr] = summary
}
function build_kv_json(    k, sep, kvjson) {
  kvjson = "{"
  sep = ""
  for (k in kv) {
    kvjson = kvjson sep "\"" esc(k) "\":\"" esc(kv[k]) "\""
    sep = ","
  }
  kvjson = kvjson "}"
  return kvjson
}
function make_json_record(ts, gameMs, sid, seq, level, category, event, phase, context, kvjson) {
  return sprintf("{\"ts\":\"%s\",\"gameMs\":\"%s\",\"sid\":\"%s\",\"seq\":%s,\"level\":\"%s\",\"category\":\"%s\",\"event\":\"%s\",\"phase\":\"%s\",\"kv\":%s,\"context\":\"%s\"}",
    esc(ts), esc(gameMs), esc(sid), (seq ~ /^[0-9]+$/ ? seq : 0), esc(level), esc(category), esc(event), esc(phase), kvjson, esc(context))
}
function parse_kv(parts, n,    i, eq, key, value) {
  for (key in kv) delete kv[key]
  for (i = 1; i <= n; i++) {
    eq = index(parts[i], "=")
    if (eq <= 1) continue
    key = substr(parts[i], 1, eq - 1)
    value = substr(parts[i], eq + 1)
    gsub(/^"/, "", value)
    gsub(/"$/, "", value)
    kv[key] = value
  }
}
function store_record(ts, gameMs, sid, seq, level, category, event, phase, body, context, corr, summary,    r) {
  r = ++recordCount
  recordOrder[r] = r
  recordTs[r] = ts
  recordGameMs[r] = gameMs
  recordSid[r] = sid
  recordSeq[r] = seq
  recordLevel[r] = level
  recordCategory[r] = category
  recordEvent[r] = event
  recordPhase[r] = phase
  recordBody[r] = body
  recordContext[r] = context
  recordCorr[r] = corr
  recordSummary[r] = summary
  recordJson[r] = make_json_record(ts, gameMs, sid, seq, level, category, event, phase, context, build_kv_json())
}
function compare_records(a, b) {
  if (recordSid[a] < recordSid[b]) return -1
  if (recordSid[a] > recordSid[b]) return 1
  if ((recordSeq[a] + 0) < (recordSeq[b] + 0)) return -1
  if ((recordSeq[a] + 0) > (recordSeq[b] + 0)) return 1
  return a - b
}
function sort_records(    i, j, current) {
  for (i = 2; i <= recordCount; i++) {
    current = recordOrder[i]
    j = i - 1
    while (j >= 1 && compare_records(recordOrder[j], current) > 0) {
      recordOrder[j + 1] = recordOrder[j]
      j--
    }
    recordOrder[j + 1] = current
  }
}
function track_sequence(sid, seq,    numericSeq, expected, missingEnd, missingRange) {
  if (sid == "" || seq !~ /^[0-9]+$/) return
  numericSeq = seq + 0
  if (!(sid in lastSeqBySid)) {
    lastSeqBySid[sid] = numericSeq
    return
  }
  expected = lastSeqBySid[sid] + 1
  if (numericSeq > expected) {
    missingEnd = numericSeq - 1
    missingRange = expected
    if (missingEnd > expected) missingRange = missingRange ".." missingEnd
    sequenceGaps[++sequenceGapCount] = "sid=" sid " missing=" missingRange " beforeSeq=" numericSeq
  }
  if (numericSeq > lastSeqBySid[sid]) lastSeqBySid[sid] = numericSeq
}
function process_record(r,    corr, summary, event, phase, body, level, category, dropped) {
  corr = recordCorr[r]
  summary = recordSummary[r]
  event = recordEvent[r]
  phase = recordPhase[r]
  body = recordBody[r]
  level = recordLevel[r]
  category = recordCategory[r]

  track_sequence(recordSid[r], recordSeq[r])
  remember_group(corr, summary, event, phase)

  if (event == "anomaly") anomalies[++anomalyCount] = summary
  if (level == "WARN" || level == "ERROR") warnErrors[++warnErrorCount] = summary
  if ((event == "drop" || body ~ /reason=(rate_limit|priority_rate_limit)/) && body ~ /dropped=[0-9][0-9]*/) {
    drops[++dropCount] = summary
    if (body ~ /dropped=[0-9][0-9]*/) {
      dropped = body
      sub(/^.*dropped=/, "", dropped)
      sub(/[^0-9].*$/, "", dropped)
      droppedRecords += dropped + 0
    }
  }
  if (category == "SCREENSHOT" || event ~ /screenshot/) screenshots[++screenshotCount] = summary
  if (event == "session" && phase == "report") sessionReports[++sessionReportCount] = summary
  if ((event == "session" && phase != "report") || body ~ /preamble|schema|preset/) preamble[++preambleCount] = summary
}
function parse_bui(raw,    line, ts, bui, sep, header, body, h, hn, parts, pn, i, sid, seq, gameMs, level, category, event, phase, corr, context, summary) {
  line = clean_line(raw)

  ts = line
  sub(/[[:space:]]*Lua Error:.*$/, "", ts)
  if (ts == line || index(ts, "[BUI]") > 0) ts = ""
  if (since != "" && (ts == "" || ts < since)) return

  if (index(line, "[BUI]") == 0) {
    if (line ~ /Lua Error:/) realErrors[++realErrorCount] = line
    return
  }

  bui = line
  sub(/^.*\[BUI\][[:space:]]*/, "", bui)
  sep = index(bui, " | ")
  if (sep <= 0) {
    parseViolations[++parseViolationCount] = line
    return
  }

  header = substr(bui, 1, sep - 1)
  body = substr(bui, sep + 3)
  hn = split(header, h, /[[:space:]]+/)
  if (hn < 5) {
    parseViolations[++parseViolationCount] = line
    return
  }

  gameMs = h[1]
  level = h[hn - 1]
  category = h[hn]
  sid = "unknown"
  seq = "0"
  for (i = 2; i <= hn - 2; i++) {
    if (h[i] ~ /^sid=/) sid = substr(h[i], 5)
    if (h[i] ~ /^seq=/) seq = substr(h[i], 5)
  }

  pn = split(body, parts, /[[:space:]]+/)
  parse_kv(parts, pn)
  event = (("event" in kv) && kv["event"] != "") ? kv["event"] : (pn >= 1 ? parts[1] : "unknown")
  phase = (("phase" in kv) && kv["phase"] != "") ? kv["phase"] : (pn >= 2 ? parts[2] : "state")

  context = ""
  if (("flow" in kv) && kv["flow"] != "") context = context "flow=" kv["flow"] " "
  if (("opId" in kv) && kv["opId"] != "") context = context "opId=" kv["opId"] " "
  if (("batchId" in kv) && kv["batchId"] != "") context = context "batchId=" kv["batchId"] " "
  if (("scene" in kv) && kv["scene"] != "") context = context "scene=" kv["scene"] " "
  gsub(/[[:space:]]+$/, "", context)

  corr = ("flow" in kv) ? kv["flow"] : ""
  if (corr == "" && ("opId" in kv)) corr = kv["opId"]
  if (corr == "" && ("batchId" in kv)) corr = kv["batchId"]
  summary = "seq=" seq " " level " " category " | " event " " phase
  if (context != "") summary = summary " " context
  store_record(ts, gameMs, sid, seq, level, category, event, phase, body, context, corr, summary)
}
{
  parse_bui($0)
}
END {
  sort_records()
  if (jsonl == 1) {
    for (i = 1; i <= recordCount; i++) print recordJson[recordOrder[i]]
    exit
  }
  for (i = 1; i <= recordCount; i++) process_record(recordOrder[i])
  print "=== builog digest ==="
  print "records=" (recordCount + 0) " groups=" (groupCount + 0) " anomalies=" (anomalyCount + 0) " warnings=" (warnErrorCount + 0) " realLuaErrors=" (realErrorCount + 0) " droppedRecords=" (droppedRecords + 0) " sequenceGaps=" (sequenceGapCount + 0)

  print ""
  print "session preamble info:"
  if (preambleCount == 0) print "  none"
  for (i = 1; i <= preambleCount; i++) print "  " preamble[i]

  print ""
  print "session reports:"
  if (sessionReportCount == 0) print "  none"
  for (i = 1; i <= sessionReportCount; i++) print "  " sessionReports[i]

  print ""
  print "sequence gaps:"
  if (sequenceGapCount == 0) print "  none"
  for (i = 1; i <= sequenceGapCount; i++) print "  " sequenceGaps[i]

  print ""
  print "timelines:"
  if (groupCount == 0) print "  none"
  for (i = 1; i <= groupCount; i++) {
    corr = groupOrder[i]
    print "  " corr
    print "    cause=" (groupCause[corr] != "" ? groupCause[corr] : "unknown")
    print "    outcome=" (groupOutcome[corr] != "" ? groupOutcome[corr] : "UNRESOLVED")
    printf "%s\n", groupLines[corr]
  }

  print ""
  print "anomalies:"
  if (anomalyCount == 0) print "  none"
  for (i = 1; i <= anomalyCount; i++) print "  " anomalies[i]

  print ""
  print "WARN/ERROR records:"
  if (warnErrorCount == 0) print "  none"
  for (i = 1; i <= warnErrorCount; i++) print "  " warnErrors[i]

  print ""
  print "real Lua errors:"
  if (realErrorCount == 0) print "  none"
  for (i = 1; i <= realErrorCount; i++) print "  " clean_line(realErrors[i])

  print ""
  print "drop summaries:"
  if (dropCount == 0) print "  none"
  for (i = 1; i <= dropCount; i++) print "  " drops[i]

  print ""
  print "screenshot markers:"
  if (screenshotCount == 0) print "  none"
  for (i = 1; i <= screenshotCount; i++) print "  " screenshots[i]
}
'
}

if [ "$MODE" = "digest" ]; then
  run_digest "$@"
  exit $?
fi

list_recent_screenshots() {
  local dir="$1"

  if find "$dir" -maxdepth 0 -printf '' >/dev/null 2>&1; then
    find "$dir" -maxdepth 1 -type f -printf '%T@ %TY-%Tm-%Td %TH:%TM:%TS %p\n' 2>/dev/null \
      | sort -nr | head -5 | cut -d' ' -f2-
    return 0
  fi

  find "$dir" -maxdepth 1 -type f -print 2>/dev/null | while IFS= read -r file; do
    if stat -c '%Y %y %n' "$file" >/dev/null 2>&1; then
      stat -c '%Y %y %n' "$file"
    elif stat -f '%m %Sm %N' -t '%Y-%m-%d %H:%M:%S' "$file" >/dev/null 2>&1; then
      stat -f '%m %Sm %N' -t '%Y-%m-%d %H:%M:%S' "$file"
    else
      printf '0 %s\n' "$file"
    fi
  done | sort -nr | head -5 | cut -d' ' -f2-
}

awk -v m="$MINUTES" 'BEGIN { exit !(m > 0) }' || die "minutes must be a positive number: $MINUTES"
awk -v i="$INTERVAL" 'BEGIN { exit !(i > 0) }' || die "interval_seconds must be a positive number: $INTERVAL"

LOG="$(resolve_log_request "$LOG_REQUEST")"
SCREENSHOT_DIR="$(resolve_screenshot_request "$SCREENSHOT_REQUEST")"

if [ ! -f "$LOG" ]; then
  echo "BUILOG MONITOR: interface.log not found at:" >&2
  echo "  $LOG" >&2
  if [ "$LOG_REQUEST" != "$LOG" ]; then
    echo "Resolved from:" >&2
    echo "  $LOG_REQUEST" >&2
  fi
  echo "Pass the path/URI as arg 3, set BUILOG_INTERFACE_LOG, or pass 'remote' for:" >&2
  echo "  $REMOTE_LOG" >&2
  echo "The file appears once ESO has logged at least one line this session" >&2
  echo "(any Lua error, or /builog on). For remote logs, make sure the SMB share is" >&2
  echo "mounted for this user and the remote test machine has written interface.log." >&2
  exit 1
fi

# Number of samples = ceil(minutes*60 / interval), at least 1.
SAMPLES=$(awk -v m="$MINUTES" -v i="$INTERVAL" 'BEGIN{ n=(m*60)/i; n=(n==int(n))?n:int(n)+1; if(n<1)n=1; print n }')

start_lines=$(wc -l < "$LOG")
last=$start_lines
tb=0; te=0; ti=0; td=0; tp=0   # totals: BUI, non-BUI errs, Id64 errs, drop-summaries, parse violations

echo "=== builog monitor: ${MINUTES}min @ ${INTERVAL}s ($SAMPLES samples) | start line=$start_lines @ $(date +%H:%M:%S) ==="
if [ "$LOG_REQUEST" != "$LOG" ]; then
  echo "    requested log: $LOG_REQUEST"
fi
echo "    log: $LOG"
echo "    screenshots: $SCREENSHOT_DIR"

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
  drop=$(printf '%s\n' "$chunk" | awk '
    /reason=rate_limit/ || /reason=priority_rate_limit/ {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^dropped=[0-9][0-9]*$/) {
          split($i, a, "="); sum += a[2]
        }
      }
    }
    END { print sum + 0 }
  ')
  # parse-contract: a valid [BUI] line has exactly ONE " | " (level/cat -> event). >1 means
  # a value injected the field separator and would corrupt a logfmt parser.
  parse=$(printf '%s\n' "$chunk" | grep '\[BUI\]' | awk -F' \\| ' 'NF>2' | head -5)
  parsec=$(printf '%s\n' "$parse" | grep -c .)
  # level mix across this window's [BUI] lines
  levels=$(printf '%s\n' "$chunk" | grep -oE '\[BUI\][^|]* (TRACE|DEBUG|INFO|WARN|ERROR) ' \
            | grep -oE '(TRACE|DEBUG|INFO|WARN|ERROR)' | sort | uniq -c \
            | awk '{printf "%s=%s ", $2, $1}')

  tb=$((tb+bui)); te=$((te+errc)); ti=$((ti+id64)); td=$((td+drop)); tp=$((tp+parsec))
  echo "----- sample $i [$(date +%H:%M:%S)] +$bui BUI, +$errc non-BUI-err, id64=$id64, dropped=$drop -----"
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
  shots=$(printf '%s\n' "$chunk" | grep '\[BUI\]' | grep ' SCREENSHOT | ')
  if [ -n "$shots" ]; then
    echo "  screenshot markers:"
    printf '%s\n' "$shots" | sed 's/.*\[BUI\]/[BUI]/; s/|r$//' | head -8 | sed 's/^/     /'
    if [ -d "$SCREENSHOT_DIR" ]; then
      echo "  screenshot files (latest 5 by mtime):"
      list_recent_screenshots "$SCREENSHOT_DIR" | sed 's/^/     /'
    else
      echo "  screenshot dir unavailable: $SCREENSHOT_DIR"
    fi
  fi
  echo "  trail (last 10 BUI):"
  printf '%s\n' "$chunk" | grep '\[BUI\]' | tail -10 | sed 's/.*\[BUI\]/[BUI]/; s/|r$//' | sed 's/^/     /'
  last=$cur
done

end=$(wc -l < "$LOG")
echo "===== totals ====="
echo "file lines: start=$start_lines end=$end (+$((end-start_lines)))"
echo "[BUI]=$tb | non-BUI errors=$te | Id64=$ti | rate_limit/priority_rate_limit dropped-records=$td | parse violations=$tp"
if [ "$te" -eq 0 ] && [ "$tp" -eq 0 ] && [ "$td" -eq 0 ]; then
  echo "status: clean (0 non-BUI errors, 0 parse violations, 0 rate-limit dropped records)"
else
  echo "status: NOT CLEAN - nonzero error/parse/drop totals above must be investigated"
fi
