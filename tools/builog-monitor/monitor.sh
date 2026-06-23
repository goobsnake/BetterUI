#!/usr/bin/env bash
#
# tools/builog-monitor/monitor.sh — tail BetterUI's live interface.log breadcrumb stream and
# emit periodic, AI-decipherable samples so an assistant can watch a play-test in real
# time. Pairs with the builog-monitor skill (tools/builog-monitor/SKILL.md, same dir).
#
# Usage:
#   tools/builog-monitor/monitor.sh [minutes] [interval_seconds] [log_path]
#
#   minutes          how long to watch (default 2). Fractional ok (e.g. 0.5).
#   interval_seconds seconds between samples (default 10). 5 to pinpoint a repro,
#                    15-20 for long/quiet sessions.
#   log_path         path to interface.log, raw smb:// URI, or "remote".
#                    Default: $BUILOG_INTERFACE_LOG, else the Proton/Steam path below.
#                    Remote alias/URI default:
#                      smb://goobers/elder%20scrolls%20online/live/Logs/interface.log
#                    Override for other OSes:
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
REMOTE_LOG="${BUILOG_REMOTE_INTERFACE_LOG:-smb://goobers/elder%20scrolls%20online/live/Logs/interface.log}"
LOG_REQUEST="${3:-${BUILOG_INTERFACE_LOG:-$DEFAULT_LOG}}"

die() {
  printf 'BUILOG MONITOR: %s\n' "$*" >&2
  exit 1
}

uri_decode() {
  local value="${1//+/ }"
  printf '%b' "${value//%/\\x}"
}

find_gvfs_smb_root() {
  local server="$1"
  local share_segment="$2"
  local share_name="$3"
  local gvfs_dir="/run/user/$(id -u)/gvfs"
  local candidate root name mounted_server mounted_share decoded_mounted_share

  for candidate in \
    "$gvfs_dir/smb-share:server=$server,share=$share_name" \
    "$gvfs_dir/smb-share:server=$server,share=$share_segment"; do
    [ -d "$candidate" ] && printf '%s\n' "$candidate" && return 0
  done

  [ -d "$gvfs_dir" ] || return 1

  for root in "$gvfs_dir"/smb-share:server="$server",share=*; do
    [ -d "$root" ] || continue
    name="${root##*/}"
    mounted_server="${name#smb-share:server=}"
    mounted_server="${mounted_server%%,share=*}"
    mounted_share="${name#*,share=}"
    decoded_mounted_share="$(uri_decode "$mounted_share")"

    if [ "${mounted_server,,}" = "${server,,}" ] && {
      [ "$mounted_share" = "$share_segment" ] || [ "$decoded_mounted_share" = "$share_name" ]
    }; then
      printf '%s\n' "$root"
      return 0
    fi
  done

  return 1
}

resolve_smb_uri() {
  local uri="$1"
  local rest server path_part share_segment share_name relative_part relative_path share_uri gvfs_root

  [ "$(uname -s)" = "Linux" ] || die "SMB URI resolution requires Linux/GVFS; mount the share and pass the filesystem path instead."

  rest="${uri#smb://}"
  [ "$rest" != "$uri" ] && [ -n "$rest" ] || die "invalid SMB URI: $uri"
  case "$rest" in
    */*) ;;
    *) die "SMB URI must include a share name: $uri" ;;
  esac

  server="${rest%%/*}"
  path_part="${rest#*/}"
  share_segment="${path_part%%/*}"
  [ -n "$server" ] && [ -n "$share_segment" ] || die "invalid SMB URI: $uri"

  share_name="$(uri_decode "$share_segment")"
  if [ "$path_part" = "$share_segment" ]; then
    relative_path=""
  else
    relative_part="${path_part#*/}"
    relative_path="$(uri_decode "$relative_part")"
  fi

  gvfs_root="$(find_gvfs_smb_root "$server" "$share_segment" "$share_name" || true)"
  if [ -z "$gvfs_root" ] && command -v gio >/dev/null 2>&1; then
    share_uri="smb://$server/$share_segment"
    printf 'BUILOG MONITOR: mounting SMB share root: %s\n' "$share_uri" >&2
    gio mount "$share_uri" >/dev/null 2>&1 || true
    gvfs_root="$(find_gvfs_smb_root "$server" "$share_segment" "$share_name" || true)"
  fi

  if [ -z "$gvfs_root" ]; then
    gvfs_root="/run/user/$(id -u)/gvfs/smb-share:server=$server,share=$share_name"
  fi

  if [ -n "$relative_path" ]; then
    printf '%s/%s\n' "$gvfs_root" "$relative_path"
  else
    printf '%s\n' "$gvfs_root"
  fi
}

resolve_log_request() {
  local request="$1"
  case "$request" in
    remote|REMOTE|--remote) request="$REMOTE_LOG" ;;
  esac

  case "$request" in
    smb://*) resolve_smb_uri "$request" ;;
    *) printf '%s\n' "$request" ;;
  esac
}

awk -v m="$MINUTES" 'BEGIN { exit !(m > 0) }' || die "minutes must be a positive number: $MINUTES"
awk -v i="$INTERVAL" 'BEGIN { exit !(i > 0) }' || die "interval_seconds must be a positive number: $INTERVAL"

LOG="$(resolve_log_request "$LOG_REQUEST")"

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
echo "[BUI]=$tb | non-BUI errors=$te | Id64=$ti | rate_limit drop-summaries=$td | parse violations=$tp"
echo "(0 non-BUI errors + 0 parse violations + 0 rate-limit drops = clean. Any non-zero -> notate above.)"
