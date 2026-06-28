---
name: builog-monitor
description: >
  Watch BetterUI's live in-game debug stream (interface.log) during an ESO play-test and
  report bugs, errors, and anything that looks wrong. Use when the user wants you to
  monitor a play-test for N minutes, verify a fix in-game, or interpret BetterUI's
  [BUI] log lines. Covers the /builog presets (inspect/trace/watch/debug), local and
  remote SMB log locations, how to decipher each line, and the timed monitor loop.
---

# BetterUI live-log monitor (`/builog` + interface.log)

**TL;DR** — the user runs `/builog preset inspect` in-game; you run
`tools/builog-monitor/monitor.sh <minutes>` and read each printed sample, flagging — live, as it
appears — any non-BUI `Lua Error:`, parse-contract violation, or behavior that doesn't match
what the user just did; then summarize. Everything below is detail on that loop.

BetterUI streams its own debug breadcrumbs into ESO's `interface.log` in real time, so an
AI assistant can tail that file **while the user plays** and call out problems as they
happen. This skill is the procedure for that back-and-forth: the user enables a preset,
plays, you sample the log on a timer, and between samples you notate bugs / errors /
anything that looks off.

This skill is platform-neutral — Claude, Codex, Copilot, and Kimi can all follow it. The
hard dependency is a native shell that can run [`monitor.sh`](monitor.sh) (POSIX `bash` +
`grep`/`sed`/`awk`).

**Execution surface:** use MCP tools for reading/searching these instructions, but run
`monitor.sh` with the platform's native terminal/shell execution. Do **not** try MCP
`process_run` for `bash`, `sh`, or `monitor.sh`; this environment's process MCP allowlist does
not include shell interpreters. Native shell fallback is the intended path for live monitoring.

## How it works (why an in-game addon can write to a log)

Retail ESO exposes **no** API to write arbitrary text to a file. BetterUI exploits the one
thing the engine *does* write in real time: **uncaught Lua errors** go straight to
`interface.log`. So each breadcrumb is a deliberately-raised, *deferred*, *popup-suppressed*
throwaway error tagged `[BUI]`. The engine logs the line but (because suppression is set) no
error dialog appears. Consequence: every `[BUI]` line on disk is wrapped as a "Lua Error:"
with a short stack traceback after it — **ignore those tracebacks**; they are noise. Untagged
`Lua Error:` blocks (no `[BUI]`) are *real* game/addon errors and matter.

## Step 1 — pick a preset (the user runs this in-game)

`/builog preset <name>` then play. For AI monitoring use **inspect** (richest):

| Preset | Depth | Enrichment | Budget (frame/sec) | Use for |
|---|---|---|---|---|
| `off` | — | — | — | stop; restores the player's real error popups |
| `info` | INFO+ | no | 8 / 100 | always-on, FPS-safe milestones only |
| `watch` | DEBUG+ | **yes** | 300 / 6000 | AI-enriched live stream (no TRACE spam) |
| `debug` | DEBUG+ | no | 1000 / 20000 | "what is it doing" developer flow |
| `trace` | TRACE+ | no | 2000 / 40000 | every step, no enrichment |
| `inspect` | TRACE+ | **yes** | 2000 / 40000 | **richest live-AI stream — default for this skill** |

"Enrichment" = each line gets `scene=… view=… flow=… lastAction=…` context + a startup
preamble + periodic state snapshots. `inspect` = `trace` depth + `watch` enrichment.

Other useful in-game commands: `/builog status` (preset + counters incl. `dropped` /
`suppressed`), `/buihealth` (one-line health), `/builog mark <text>` (drop a labeled marker
into the stream — ask the user to mark "about to test X" so you can find it),
`/builog screenshot [label]` (manual visual capture), `/builog screenshot auto
error|warn|off` (session-only opt-in auto capture), `/builog off`.
Auto capture can include private UI/chat/account context; keep it off outside the
current play-test window. Saved markers are emitted only for screenshots BetterUI requested.
Full surface: `/builog on|off | preset … | chat on|off | popups on|off | level <lvl> |
mark <text> | recent [n] | errors [n] | capture [secs] | screenshot [label] |
screenshot auto off|error|warn | snapshot | test | status`.

## Step 2 — find interface.log

Default (this user's Proton/Steam install):
```
/mnt/steamstorage/SteamLibrary/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live/Logs/interface.log
```

Use the **remote** log instead of the local Proton log when the user says they are testing
on another computer, asks for remote monitoring, or the local log is not changing during the
reported play-test. The remote Live log URI is:
```
smb://goobers/elder%20scrolls%20online/live/Logs/interface.log
```

The helper script resolves this for you on Linux/GVFS: it accepts `remote`, the raw
`smb://...` URI, a mounted filesystem path, or `BUILOG_INTERFACE_LOG`. Prefer the `remote`
alias for AI monitoring on the shared test machine:
```
tools/builog-monitor/monitor.sh <minutes> [interval_seconds] remote
```
Use `BUILOG_REMOTE_INTERFACE_LOG` only when the remote URI changes. On non-Linux hosts, mount
or open the share first and pass the resulting filesystem path.

If the helper cannot find the remote log, manually verify the GVFS mount/path:
```
gio mount 'smb://goobers/elder%20scrolls%20online' 2>/dev/null || true
for root in /run/user/$(id -u)/gvfs/smb-share:server=goobers,share=elder*; do
  log="$root/live/Logs/interface.log"
  [ -f "$log" ] && printf '%s\n' "$log" && break
done
```
GVFS may expose either decoded or URI-encoded share names; both are valid:
```
/run/user/$(id -u)/gvfs/smb-share:server=goobers,share=elder scrolls online/live/Logs/interface.log
/run/user/$(id -u)/gvfs/smb-share:server=goobers,share=elder%20scrolls%20online/live/Logs/interface.log
```

If no path prints, the share is not mounted for this user, the remote ESO client has not
created `interface.log` yet, or the remote machine/share is unavailable. Ask the user to run
`/builog preset inspect` on the test machine, then retry after ESO writes at least one line.
Always quote the discovered path because the share name may contain spaces.

Other installs:
- Windows: `<Documents>\Elder Scrolls Online\live\Logs\interface.log`
- macOS: `~/Documents/Elder Scrolls Online/live/Logs/interface.log`

Note the lowercase `interface.log` under the `live/` subtree (the PTS client logs to `pts/`
instead). The file may sit **outside** sandbox/MCP roots — read it with a plain shell, and
override the path via the script's 3rd arg or `BUILOG_INTERFACE_LOG`. It only exists once ESO
has written at least one line this session (any Lua error, or `/builog on`).

## Step 3 — run the timed monitor

The user gives a duration in **minutes**. Run:
```
tools/builog-monitor/monitor.sh <minutes> [interval_seconds] [log_path] [screenshot_dir]
```
Run that command through native terminal/shell execution, not MCP `process_run`.

Remote example for the shared test machine:
```
tools/builog-monitor/monitor.sh <minutes> [interval_seconds] remote
```
Raw remote URI also works:
```
tools/builog-monitor/monitor.sh <minutes> [interval_seconds] 'smb://goobers/elder%20scrolls%20online/live/Logs/interface.log'
```
Manual fallback after discovering the mounted path:
```
LOG="$(for root in /run/user/$(id -u)/gvfs/smb-share:server=goobers,share=elder*; do
  log="$root/live/Logs/interface.log"
  [ -f "$log" ] && printf '%s\n' "$log" && break
done)"
[ -n "$LOG" ] || { echo "remote interface.log not found"; exit 1; }
BUILOG_INTERFACE_LOG="$LOG" tools/builog-monitor/monitor.sh <minutes> [interval_seconds]
```
- `minutes` — how long to watch (the user's number; fractional ok).
- `interval_seconds` — **default 10** (a good back-and-forth cadence). Drop to **5** to pin a
  specific repro; raise to **15–20** for long (>10 min) or quiet sessions, because `inspect`
  can emit hundreds of lines/second during list rebuilds and 10s samples stay readable.
- `screenshot_dir` — optional path/URI to `<ESO live>/Screenshots`. Defaults to
  `BUILOG_SCREENSHOT_DIR` or a path derived from `log_path`; pass `remote` to use the remote
  shared-machine screenshot folder.

The monitor reads only lines appended **after** it starts, so confirm a preset is already
active (Step 1) before launching; for earlier history `grep '\[BUI\]'` the file directly. Have
the user `/builog mark <text>` (or just tell you) what they're about to test, so you can find
that action's `seq` window in the stream.

Run it in the background if your platform supports it; otherwise it blocks for the duration.
Each `----- sample N -----` block reports: new `[BUI]` count, level mix, **real (non-BUI)
errors with messages**, rate-limit dropped-record totals, parse-contract violations, your
own `WARN`/`ERROR` breadcrumbs, `SCREENSHOT` markers plus latest screenshot files when
available, and a 10-line trail. A `===== totals =====` footer closes it.

The helper prints both `requested log:` and resolved `log:` when it is resolving `remote` or
an `smb://` URI. If it errors, do not silently fall back to the local Proton log; fix the
remote mount/path or ask the user to create the remote log with `/builog preset inspect`.

**Between samples, notate.** As each sample prints, write down anything that looks wrong (see
Step 4). Don't wait for the end — the value is catching issues live so the user can react.
After the run, summarize: what was clean, what wasn't, and any hypotheses with the `seq`/line
evidence.

## Step 4 — decipher a line

Schema (logfmt, never JSON):
```
[BUI] <gameMs> sid=<sid> seq=<seq> <LEVEL> <CATEGORY> | <event> [key=value …] scene=<s> …
```
Example — `[BUI] 818059 sid=51c180d4 seq=796 INFO SCENE | scene gamepad_inventory_root shown
wasPushed=false scene=gamepad_inventory_root` reads as: at game-ms 818059 (session 51c180d4,
record 796) the inventory scene finished showing; the trailing `scene=` is the enrichment
context suffix appended to every line.

- **Parse boundary is the FIRST ` | `**: left of it is `[BUI] <ms> sid=… seq=… <LEVEL> <CATEGORY>`, right is the human event + `key=value` pairs. A correct line has exactly **one** ` | `.
- `sid` = session id, new each UI load (changes on `/reloadui` — a natural discontinuity).
  `seq` = monotonic counter; **gaps mean dropped or suppressed lines**, not lost events.
- `LEVEL` ∈ TRACE/DEBUG/INFO/WARN/ERROR. `CATEGORY` ∈ SCENE, LIST, NAV, KEYBIND, ACTION,
  BATCH, LIFECYCLE, SORT, STATE, SCREENSHOT, GENERAL, LOG, …
- Filter the stream with `grep '\[BUI\]'`. The engine wraps each line as
  `<ISO-ts> |cff0000Lua Error: [BUI] …|r` followed by a `stack traceback:` block — strip the
  color codes and ignore the traceback.

### What to flag

| Signal | Meaning | Action |
|---|---|---|
| `Lua Error:` **without** `[BUI]` | a real game/addon error | investigate; capture the message + traceback |
| `Checking type on argument id failed in Id64ToString_lua` | a known class of quest-item bug | should be **0** now; if seen, regression |
| `WARN LOG \| dropped=<n> reason=rate_limit` | sink shed `n` lines (budget hit) | usually fine at inspect during bursts; only worry if huge/constant |
| `>1` ` | ` in a `[BUI]` line | a value injected the field separator | parse-contract bug — report the line |
| `WARN`/`ERROR` `[BUI]` lines | BetterUI flagging its own problem | read the event; often the real lead |
| `SCREENSHOT` markers | manual/auto capture request, suppression, or saved filename | inspect the listed screenshot file when troubleshooting visual state |
| `seq` jumps with no `dropped=` summary | suppression-guard drops (e.g. mid-reloadui) | check `/builog status` `suppressed=` counter |
| behavior the user reports ≠ what the log shows | e.g. a keybind that "does nothing" | search for the action's CATEGORY/ACTION line near that `seq`; absence of a line often *is* the bug |

When the user describes a symptom, correlate it to the stream: find the `seq` window where it
happened (use `/builog mark`), then read the surrounding `ACTION`/`STATE` lines and the
nearest `snapshot`. In `watch`, no categories are muted by default; if the user temporarily
mutes high-volume categories, skipped or incomplete keybind/list outcomes should still surface
through compact `STATE` lines, and the inventory/banking snapshot provider fields include
`visible=0/1` so hidden singleton UI state is not mistaken for the active screen. A missing
expected line is as diagnostic as an error.

For common UI-flow bugs, look for these landmarks in the marked `seq` window:

| Symptom | Expected evidence |
|---|---|
| Action/keybind did nothing | `ACTION | inventory primary action resolved`, `ACTION | inventory primary action invoked`, `ACTION | bank primary transfer invoked`, or `ACTION | bank action dialog shown`. |
| Keybind strip stale | `STATE | inventory keybind groups refreshed` or `STATE | bank keybind groups refreshed/removed`. |
| Item deposit/withdraw list stale | transfer flow end followed by `STATE | bank list refresh scheduled/refreshed` or `STATE | inventory category list refresh scheduled/refreshed updates=<n>`. |
| Junk/category did not refresh | junk/dialog `ACTION` confirmation followed by the inventory category refresh scheduled/refreshed pair. |
| Currency transfer failed silently | `ACTION | bank currency transfer failed` with `amount`, `currency`, and `reason`; success should say `bank currency transfer completed`. |
| Transfer blocked | `WARN ACTION | bank transfer blocked` with `reason`, `fromBag`, `toBag`, `slot`, and item context. |

## How each platform uses this skill

This is plain markdown + a shell script — nothing platform-specific. Point any agent at
`tools/builog-monitor/SKILL.md` and have it run `tools/builog-monitor/monitor.sh <minutes>`
for local monitoring or `tools/builog-monitor/monitor.sh <minutes> [interval_seconds] remote`
for the shared remote test machine, using native terminal/shell execution. Then interpret the
samples per *Step 4*. It works the same for Claude, Codex, Copilot, and Kimi — no MCP or
vendor execution tooling required, only a shell.

## Reference

- `docs/reference/logging-playbook.md` — full preset/command playbook.
- `docs/reference/logging-host-tail-parse.md` — exact host parse contract + meta-line schema.
- `docs/reference/logging-observability-strategy.md` — design rationale.
- [`monitor.sh`](monitor.sh) — the sampler this skill drives.
