# Claudette: Agent ↔ Shell Handoff UX

The flagship interaction: hand control back and forth between Claude and a human
at a **live shell**, inside one shared session. This is the thing no first-party
Claude surface can do, because none exposes a real terminal alongside the agent.

---

## Core principle

**One session, two drivers, shared state.** Claude and the human operate the *same*
tmux session and working directory. Whatever one does, the other sees. The handoff
is a change of *who is typing*, not a context switch, a new shell, or a copy-paste
bridge.

---

## The three states

```
        ┌──────────────────────────────────────────────────────────┐
        │                                                          │
        ▼                                                          │
┌───────────────┐   tap "Take the wheel"   ┌───────────────┐       │
│  AGENT DRIVING │ ───────────────────────▶ │  HUMAN DRIVING │      │
│ (Structured)   │                          │  (live shell)  │      │
│  Claude runs   │ ◀─────────────────────── │  you type      │ ─────┘
│  tools, you    │   tap "Hand back" +      │  any command   │
│  watch/steer   │   optional note          │                │
└───────────────┘                          └───────────────┘
        │                                          │
        │           both can see                   │
        └──────────  the same tmux  ───────────────┘
                     session + cwd + scrollback
```

| State | Who types | What Claude does | What the human does |
|---|---|---|---|
| **Agent driving** | Claude | Runs tools, edits, executes | Watches Structured Mode; can interject |
| **Human driving** | You | **Paused, observing** the same pane | Runs any shell command directly |
| **Handing back** | — | Re-reads shell state, resumes | Adds an optional note ("fixed the migration, continue") |

---

## Happy-path flow

1. **Claude hits a wall.** In Structured Mode, a tool fails or Claude says it
   needs a manual step (e.g., interactive `git rebase`, a credential prompt, a
   stuck service). A banner appears: **"Claude is blocked — take the wheel?"**

2. **Take the wheel (one tap).** The view flips from the structured conversation
   to the **raw terminal** for the *same tmux session*. The extended keyboard row
   (Esc, Tab, Ctrl-C, pipe, brackets) is right there. Claude is now paused, not
   gone — a thin status strip reads **"Claude paused · you're driving."**

3. **Do the thing.** You run whatever you need:
   ```
   $ git rebase --continue
   $ service postgresql restart
   $ tail -f /var/log/app.log
   ```
   Full scrollback, real PTY, your actual environment.

4. **Hand back (one tap + optional note).** Tap **"Hand back to Claude."** A small
   sheet lets you type a one-line note (optional): *"Resolved the conflict in
   auth.ts, continue the refactor."* You can also pick what Claude sees:
   - **Auto** (default): Claude reads the new terminal scrollback since you took
     over, plus `git status` / cwd.
   - **Just my note**: only your message, no raw scrollback.

5. **Claude resumes.** It re-orients from the shared state and your note, then
   continues the original task. The Structured view returns with an inline marker:
   **"— human took the wheel: 3 commands —"** so the transcript stays honest.

---

## UI surface

- **Mode toggle** already exists (Structured ↔ raw terminal). The handoff *reuses
  it* but adds intent: entering the terminal while Claude is mid-task is an
  explicit "take the wheel," not a passive view switch.
- **Persistent status strip** (one line, top of terminal): who's driving + a
  "Hand back" button. Always visible so you never get stuck "in" the shell.
- **Block markers** in the Structured transcript record each handoff (who, how
  many commands, optional note) — auditability and so Claude has context.
- **Quick-actions** in human mode: a small row of common interventions
  (`git status`, `git rebase --continue`, restart service) sourced from the
  existing Snippet Drawer, scoped to "intervention" snippets.

---

## What makes it *safe* and trustworthy

- **Claude is paused, not killed.** It does not run tools while you drive, so you
  never race the agent for the same files.
- **Explicit re-sync on handback.** Claude is told exactly what changed (scrollback
  diff + your note), so it never silently assumes stale state.
- **Honest transcript.** Every handoff is marked, so a later reviewer (or Claude
  itself) can see a human intervened and what they did.
- **Confirm on destructive handoff.** If you took the wheel and then hand back
  after commands that changed git state, surface a one-line summary before resuming
  ("you committed 2 files and switched branches — continue?").

---

## Edge cases to design for

| Case | Handling |
|---|---|
| Claude was waiting on its *own* command when you grab the wheel | Offer to Ctrl-C it first, or attach to the running process |
| You break the working tree, then hand back | Show a git-state summary; let Claude re-plan rather than assume |
| Connection drops while you're driving | tmux keeps the session; on reconnect you're still "driving," nothing lost |
| You take the wheel but do nothing, then hand back | No-op marker; Claude continues unchanged |
| Long-running command still streaming on handback | Warn: "a command is still running — hand back anyway / wait" |

---

## Why this is the moat, in one line

> **Remote Control lets you talk to the driver. Claudette lets you take the wheel
> and hand it back — on your phone, in the same session, with the agent watching.**

Anthropic can match any single Claudette feature. They will not put a raw,
human-driven shell *into the agent loop* of a consumer app — so this specific
handoff is the one place Claudette can stand alone.
