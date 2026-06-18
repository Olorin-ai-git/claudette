# Structured Mode Hardening — Hook Sidecar

How to make Claudette's Structured Mode (and the Agent Visualizer) **authoritative**
instead of best-effort screen-scraping — without giving up the raw terminal that is
Claudette's core differentiator.

---

## Current state (verified in code)

- Claude Code is launched as a plain interactive TUI. The default `sshCommand` in
  `Configuration.plist` is `claude --continue`, passed straight to the tmux
  `initialCommand` by `SSHConnectionManager`.
- Structured Mode is reconstructed entirely from rendered terminal text:
  `ClaudetteTerminalView` → `TerminalBlockDetector.detectBlock(lines:)` and
  `AgentActivityParser`, both of which `stripANSI(...)` and regex-match Claude
  Code's printed output.
- Nothing in the repo consumes `--output-format stream-json`, `--print`, NDJSON,
  or any structured channel.

**Risk:** the TUI is a presentation layer, not an API. Parsing it breaks on output
format changes between Claude Code versions, narrow-width line wrapping, spinner /
redraw interleaving, and box-drawing — silently corrupting block detection and the
agent tree.

---

## Why not just use `stream-json`

`claude -p --output-format stream-json` is **headless/print mode**: one prompt in,
NDJSON events out, **no interactive PTY**. Adopting it as the primary transport
would destroy the raw-terminal "take the wheel" handoff — the whole reason
Claudette exists. So stream-json must not *replace* the interactive session.

---

## The design: a structured sidecar via hooks

Keep the interactive tmux pane exactly as-is. Run an **authoritative event stream
alongside it**, emitted by Claude Code's own hooks (which Claudette already
configures), and tail it over the existing SSH connection.

```
  ┌──────────────────────── your Mac ────────────────────────┐
  │                                                          │
  │   tmux session                                           │
  │   ┌───────────────────────────┐                          │
  │   │ claude --continue (TUI)    │ ── raw PTY ──┐           │
  │   └───────────────────────────┘              │           │
  │            │ fires hooks                      │           │
  │            ▼                                  │           │
  │   PreToolUse / PostToolUse / Notification /   │           │
  │   Stop / SubagentStop  ──► append JSONL ──►   │           │
  │   ~/.claudette/events/<session>.jsonl         │           │
  │                                  │            │           │
  └──────────────────────────────────┼────────────┼──────────┘
                  SSH (existing)      │            │
        ┌─────────────────────────────┴────────────┴─────────┐
        │ Claudette                                          │
        │  • Raw terminal view  ◀── PTY (unchanged)          │
        │  • Structured Mode    ◀── tail -f events.jsonl      │
        │  • Agent Visualizer   ◀── SubagentStart/Stop events │
        └────────────────────────────────────────────────────┘
```

Two channels, one session:
- **PTY channel (unchanged):** raw terminal, extended keyboard, the human-driven
  handoff. Authoritative for *interaction*.
- **Event channel (new):** structured JSONL from hooks. Authoritative for *what the
  agent did*. Replaces ANSI scraping for Structured Mode + Agent Visualizer.

---

## Hook configuration

Claudette installs these into the project's `.claude/settings.json` (it already has
a hooks editor — `HooksAutomationView` / `HookEditorFormView`). Each hook pipes its
stdin JSON to a tiny appender keyed by the Claude Code session id.

```jsonc
{
  "hooks": {
    "PreToolUse":   [{ "matcher": "*", "hooks": [{ "type": "command",
      "command": "claudette-emit pre"   }] }],
    "PostToolUse":  [{ "matcher": "*", "hooks": [{ "type": "command",
      "command": "claudette-emit post"  }] }],
    "Notification": [{                  "hooks": [{ "type": "command",
      "command": "claudette-emit notify"}] }],
    "Stop":         [{                  "hooks": [{ "type": "command",
      "command": "claudette-emit stop"  }] }],
    "SubagentStop": [{                  "hooks": [{ "type": "command",
      "command": "claudette-emit subagent" }] }]
  }
}
```

`claudette-emit` (shipped by the `claudette-setup` CLI, or inlined) is trivial:

```bash
#!/usr/bin/env bash
# claudette-emit <kind> — append one envelope line per hook event.
# Hook payload arrives as JSON on stdin; session_id is a field in it.
dir="$HOME/.claudette/events"; mkdir -p "$dir"
payload="$(cat)"
sid="$(printf '%s' "$payload" | jq -r '.session_id // "unknown"')"
printf '%s\n' "$(jq -cn --arg k "$1" --argjson p "$payload" \
  '{ts: now|todate, kind: $k, event: $p}')" >> "$dir/$sid.jsonl"
```

Notes:
- Hooks receive structured JSON on stdin (tool name, tool input, tool response,
  session id, cwd). That is the authoritative data the TUI is merely *rendering*.
- Hooks **must exit 0** and stay fast — appending a line is microseconds. Never
  block the agent.
- Keep matchers `*` for tools; Claudette filters client-side.

---

## The tail/parse contract

Claudette tails the per-session file over SSH and parses one JSON object per line.

- **Transport:** `tail -n +1 -F ~/.claudette/events/<session>.jsonl` on a dedicated
  SSH channel (separate from the PTY). `-F` survives rotation/recreation.
- **Envelope (one per line):**
  ```json
  { "ts": "2026-06-18T03:00:00Z", "kind": "post",
    "event": { "session_id": "…", "cwd": "…",
               "tool_name": "Edit", "tool_input": { … },
               "tool_response": { … } } }
  ```
- **Mapping to existing models:**
  - `pre`/`post` with `tool_name` → a tool-use block (replaces
    `TerminalBlockDetector` heuristics).
  - `Task` tool + `SubagentStop` → nodes/edges for `AgentActivityParser` /
    `AgentTreeNode` (replaces the spawn/complete regexes).
  - `notify` → permission prompts / the existing `PermissionNotificationService`.
  - `stop` → task-complete (drives the vocal summary + a real push, see below).
- **Idempotency / resume:** each line carries `ts` + a monotonic counter; on
  reconnect, re-tail from the last seen counter so backgrounding never drops or
  double-counts events.
- **Correlation with the session id:** key the file by Claude Code's `session_id`.
  Claudette already restarts with `--continue`; capture the resolved id once (e.g.
  a `SessionStart` hook that writes `session_id` to a known path) so the app tails
  the right file from the first frame.

---

## Migration path (low risk, incremental)

1. **Add the event channel behind a flag**, keep ANSI scraping as fallback. If the
   events file is present and fresh, Structured Mode uses it; otherwise it falls
   back to the current parser. No regression for un-hooked sessions.
2. **Reconcile both sources** for one release to validate parity (log mismatches in
   `--debug`). This is also the test fixture the project currently lacks.
3. **Promote the event channel to primary**; demote scraping to a "raw heuristics"
   fallback only when hooks aren't installed (e.g. user declined hook setup).

---

## Bonus wins this unlocks

- **Real push notifications** — the `Stop` / `Notification` hooks are the exact
  signal Claudette needs to fire a native push (currently a gap vs. first-party).
- **Accurate vocal summaries** — summarize from `tool_response` data instead of
  scraped text.
- **A test surface** — JSONL fixtures make `AgentActivityParser` /
  `TerminalBlockDetector` unit-testable for the first time (the repo is at 0%
  coverage).
- **Cost/context fidelity** — structured events carry better signal than parsing
  the on-screen gauge.

---

## What stays the same

The raw terminal, tmux multi-tab, extended keyboard, and the human-driven
"take the wheel" handoff are **untouched**. This change only replaces *how
Structured Mode learns what happened* — moving it from scraping the TUI to reading
Claude Code's own authoritative hook events, over the SSH connection Claudette
already holds.
