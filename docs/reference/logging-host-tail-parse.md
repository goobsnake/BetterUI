# Host tail / parse contract — BetterUI `[BUI]` live log

How an external host (an AI assistant, a `tail -f` watcher, a parser) reads BetterUI's
real-time breadcrumb stream out of the game's `Interface.log`. This is the **only**
handoff: there is no SavedVars export — everything is live in `Interface.log`.

See also: [logging-observability-strategy.md](logging-observability-strategy.md) (the
canonical design).

## Where

`<ESO live dir>/Logs/Interface.log`. On this dev machine (Steam/Proton, appid 306130):

```
/mnt/steamstorage/SteamLibrary/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live/Logs/Interface.log
```

The engine appends; reopen/seek-to-end to tail. Enable with `/builog preset watch`
(live-AI stream) or `/builog on` then `/builog preset debug|trace`. `/builog preset inspect`
is `watch` enrichment at `trace` verbosity — the deepest live stream.

## Line shape

Each breadcrumb is emitted as a deferred, popup-suppressed `error()`, so the engine
wraps it. One on-disk record looks like:

```
<ISO-8601 ts> |cff0000Lua Error: [BUI] <gameMs> sid=<sid> seq=<seq> <LEVEL> <CATEGORY> | <event> [k=v ...] [scene=.. view=.. flow=.. lastAction=".."]|r
<stack traceback block — IGNORE for [BUI] lines>
```

- **Filter to the clean stream:** keep only lines containing `[BUI]`; drop the
  `stack traceback:` block that follows each one.
- **A `Lua Error:` line WITHOUT `[BUI]` is a real game/addon error** — keep its
  traceback; that is signal, not BetterUI noise.

### Fields (after the `[BUI]` tag)

| Field | Meaning |
|---|---|
| `<gameMs>` | `GetGameTimeMilliseconds()` at emit (uptime ms; monotonic within a load). |
| `sid=<sid>` | Session id — one UI load. Changes on `/reloadui`. Group records by `sid`. |
| `seq=<seq>` | Monotonic per-record counter. **Order by `seq`**, not by ISO ts (ts has 1s resolution). |
| `<LEVEL>` | `TRACE` < `DEBUG` < `INFO` < `WARN` < `ERROR`. |
| `<CATEGORY>` | `SCENE LIST NAV KEYBIND FOOTER CATEGORY SEARCH SORT BATCH ACTION LIFECYCLE SAFE SETTINGS CONTROL PERF STATE GENERAL` — plus `LOG`, the logger's own meta-lines: the startup header, the `disabled` marker, `/builog test` breadcrumbs, and the `dropped=` rate-limit summary. Every line, meta or not, carries a `<LEVEL> <CATEGORY>` pair, so one regex parses the whole stream. |
| `\| <event>` | Everything after the first ` \| ` is the human message + `k=v` payload. The ` \| ` is the parse boundary. |

The ISO-8601 timestamp at line start is authoritative **wall-clock**; `<gameMs>` is
uptime. Use `seq` for ordering, ISO ts for wall-clock correlation.

### Context suffix (watch preset only)

In `watch`, every line self-anchors with the parts that are set:

```
scene=<sceneName> view=<subView> flow=<flowId> lastAction="<last user action>"
```

So a host reading a single mid-stream line knows where the player is (`scene`/`view`),
which multi-step operation it belongs to (`flow`), and what the player last did
(`lastAction`). `scene/view/flow` are bare tokens (internal whitespace is collapsed to
`_` and any `|` to `/` so they stay single tokens); `lastAction` is quoted with `"` and
backslash-escaped.

## Watch-stream landmarks

- **`STATE | watch session started ...`** — startup preamble: `schema preset sid api
  world player zone`, followed by `STATE | active addons count=.. names=..`. An AI
  joining mid-stream should scan back to the most recent one to anchor the session.
- **`STATE | snapshot scene=.. <provider fields>`** — periodic heartbeat (~10s) + live
  state. Built-in provider fields include `inventory="window=1 visible=1 ... itemRows=.. keybindMain=.."`
  and `banking="window=1 visible=1 ... rows=.. pending=.. keybindCore=.."`; hidden windows report
  compact `window=1 visible=0` instead of stale rows. Absence for ≫10s while
  the client is up suggests a freeze/hang.
- **`... [flow begin]` / `... [flow end]`** carrying `flow=<kind>#<n>` — bracket one
  multi-step operation; correlate everything sharing that `flow` id.
- **Inventory/banking action landmarks** — `ACTION | inventory primary action resolved`, `ACTION | inventory
  primary action invoked`, `ACTION | inventory dialog action confirmed`, `ACTION | bank primary transfer
  invoked`, `ACTION | bank currency transfer completed/failed`, and `WARN ACTION | bank transfer blocked`
  explain why a keybind, item move, currency transfer, or dialog action progressed or stopped.
- **Refresh landmarks** — `STATE | inventory category list refresh scheduled/refreshed updates=<n>` and
  `STATE | bank list refresh scheduled/refreshed` are the expected follow-ups after item mutation flows.
- **`STATE | mark: <text>`** — a user annotation placed with `/builog mark "<text>"`.
- **`WARN LOG | dropped=<n> reason=rate_limit`** — the file-sink budget shed `n`
  records in a burst. Coverage gap, not an error. Sum `dropped=<n>` values; do not count
  drop-summary lines as the dropped-record total.

## Minimal recipes

Clean stream, ordered by seq within the current session:

```sh
grep -a '\[BUI\]' Interface.log
```

Field extraction (POSIX ERE — `grep -oE`, or feed to any PCRE engine). Anchor on the
literal `[BUI] ` then the first ` | `. The engine wraps each record in a `|cff0000…`
colour and appends a trailing `|r` reset, so capture the event greedily and strip a
trailing `|r` in post:

```
\[BUI\] ([0-9]+) sid=([0-9a-f]+) seq=([0-9]+) ([A-Z]+) ([A-Z]+) \| (.*)$
        gameMs┘    sid┘            seq┘        LEVEL┘   CAT┘        event┘  (strip trailing |r)
```

Tail loop (host): seek to EOF, read appended lines, keep those matching `[BUI]`, parse
per the ERE above, strip a trailing `|r` colour reset from the event, then sort a window
by `seq`.
