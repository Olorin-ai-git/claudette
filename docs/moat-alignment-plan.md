# Claudette Hardening & Moat-Alignment Plan

**Goal:** Re-center Claudette on its one durable wedge — *the only Claude client
where a human can take the wheel* — by adding a **one-click handoff between the
first-party Claude app and Claudette (take the wheel)** and a **one-click handoff
back to the agent**, and by hardening the foundation those features sit on.

This plan is grounded in a full codebase review (see [Appendix A](#appendix-a--codebase-review-inventory)).
Every claim about current behavior cites a file and line range.

---

## 1. The wedge, restated

| | Talk to the agent | **Take the wheel** |
|---|---|---|
| Claude app (Remote Control / cloud) | ✅ | ❌ no shell to drop into |
| **Claudette** | ✅ (Structured Mode) | ✅ **real PTY, same machine** |

Anthropic deliberately won't put a human-driven raw shell inside the agent loop of
a consumer app. That gap is the moat. The product expression of the moat is a
**frictionless round-trip**: agent → *(one tap)* → human shell → *(one tap)* →
agent, in the same working tree, with the agent paused while you drive.

---

## 2. Scope & non-goals

**In scope:** one-click handoff for **local** Claude Code sessions — the agent's
`claude` process runs on a machine Claudette can SSH to (first-party Remote
Control, Desktop Cowork, or a local CLI session).

**Out of scope (state it plainly in the UI):** **Claude Code on the web** cloud
sessions run inside Anthropic-managed VMs with no inbound SSH, so Claudette cannot
attach to them. Take-the-wheel is a *local-session* feature. If a user taps it on a
cloud session, we explain why and offer "teleport this to your Mac first."

**Key architectural truth from the review:** the first-party session and Claudette
do **not** share a transport. Remote Control is an Anthropic-protocol session; the
local `claude` process is just a process. Claudette is SSH + tmux + PTY
(`SSHConnectionManager.swift:88-169`). So "same session" is achieved by
**co-locating both in one tmux session** — the agent runs in a known tmux session,
and Claudette attaches a **sibling window/pane** to it. We never fight the agent
for one PTY.

---

## 3. The handoff architecture (centerpiece)

### 3.1 Co-location model

```
                         ┌─────────────── user's Mac ───────────────┐
                         │  tmux session  "claudette-<repo>"          │
  Claude app  ──RC──►    │  ┌── window 0: claude (agent) ──────────┐  │
  (agent UI)             │  │  paused at PreToolUse gate while you  │  │
        ▲                │  │  drive (sentinel-based)               │  │
        │ hand back      │  └───────────────────────────────────────┘  │
        │ (universal     │  ┌── window 1: $ (you) ───────────────────┐ │
        │  link)         │  │  Claudette attaches here, same cwd     │ │
        ▼ take wheel     │  └────────────────────────────────────────┘ │
  Claudette ──SSH───────►│         ▲ attach new window, don't kill     │
  (real shell)           └─────────┼──────────────────────────────────┘
                                   │
                       deep link carries: host, tmux name, cwd, session id
```

Both surfaces look at the **same tmux session**: the agent in window 0, the human
in window 1. The agent is *paused*, not killed, so there's no race over files.

### 3.2 The pause/resume gate

A human "driving" must mean the agent isn't running tools underneath them. We get a
real, safe pause using a hook (hooks already install via SFTP to
`~/.claude/settings.json` — `ClaudeSettingsService.swift:15,40-53`):

- **PreToolUse "wheel gate" hook:** before each tool call, the hook checks for
  `~/.claudette/handoff/<session>.paused`. If present, it blocks (polls) or denies
  with a re-ask, so the agent waits. When Claudette clears the sentinel, the agent
  proceeds. This is the safe, supported way to hold the agent.
- Claudette sets/clears the sentinel over the existing SSH/SFTP channel.

### 3.3 Take the wheel — one click

1. **Trigger** *(decided: push primary, `/wheel` fallback)*. We don't control the
   Claude app UI, so the tap originates from an artifact the agent emits (all
   installable by `claudette-setup`):
   - **Primary — push/notification deep link:** a **`Stop`/`Notification` hook**
     fires a native push ("Claude is blocked — take the wheel?") carrying the
     `claudette://take-wheel?...` link; tapping the push opens Claudette into the
     shell. (Depends on the push sidecar, WS5 — lands Phase 2.)
   - **Fallback — `/wheel` custom slash command:** the user runs `/wheel` in the
     Claude app, which writes the handoff descriptor and emits the same link. Ships
     in Phase 1 as the MVP trigger, before push is ready, and remains available
     after.
2. **Deep link payload** (signed; see §6):
   ```
   claudette://take-wheel?host=<id>&user=<u>&cwd=<path>&tmux=<session>&sid=<claude_session_id>&sig=<hmac>
   ```
3. **Claudette handles it** (`ClaudetteApp` `.onOpenURL`, new `DeepLinkHandler`):
   - Resolve the host to an existing `ServerProfile` (match on host/user) or prompt
     to create/confirm one.
   - Write the `paused` sentinel (SFTP/exec) so the agent halts at the next gate.
   - Open a session attaching a **new tmux window** in `tmux=<session>` at
     `cwd=<path>` (see §4.2 for the small `ConnectionSettings` extension). The user
     lands at a live `$` prompt in the agent's working tree.
   - Show a persistent **"Hand back to Claude"** bar (reuse the status strip in
     `SessionView.swift`).

### 3.4 Hand back — one click

1. User taps **"Hand back to Claude."** Optional one-line note sheet.
2. Claudette: writes the note + a structured `resume` event, **clears the `paused`
   sentinel**, optionally types `continue` into the agent window
   (`tmux send-keys`), and records a handoff marker.
3. Claudette opens the **Claude app universal link** for the session
   (`https://claude.ai/code/<session>` → opens the Claude app) so the user lands
   back in the agent UI. The PreToolUse gate unblocks; the agent resumes with the
   human's note and the now-visible shell state.

This is the full round-trip, each direction one tap, agent paused throughout.

---

## 4. Workstreams

Ordered by dependency. Each lists concrete files/extension points from the review.

### WS1 — Deep-link infrastructure  *(greenfield; review found none today)*

- Register a custom scheme `claudette://` (`CFBundleURLTypes`) and
  `applinks:` associated domain. Today there is **no scheme, no `onOpenURL`, no
  associated domains**; bundle id is `com.olorin.claudette`
  (review: deep-link agent).
- Add `.onOpenURL` to the `WindowGroup` in `ClaudetteApp.swift` (~line 69) routing
  to a new `Services/DeepLinkHandler.swift`.
- Implement `UNUserNotificationCenterDelegate` so a notification tap can carry the
  same deep link (`PermissionNotificationService.swift` currently has no tap
  handler).
- Host `apple-app-site-association` at the Claudette domain for universal links.

### WS2 — Programmatic session open  *(small, enabling change)*

The review found session creation is flexible on **cwd** but hardcodes the command
and derives the tmux name from `profileId` only:

- `ConnectionSettings` (`Models/ConnectionSettings.swift`): add
  `initialCommand: String?` and `tmuxSessionName: String?` (and an
  `attachWindowOnly: Bool`).
- `SSHConnectionManager.connect()` (`:122-145`): use
  `settings.initialCommand ?? config.sshCommand`, and
  `settings.tmuxSessionName ?? tmuxService.sessionName(profileId:)`.
- `TmuxSessionService`: add `attachNewWindowCommand(sessionName:directory:)` =
  `tmux new-window -t <s> -c <cwd>; tmux attach -t <s>` so take-the-wheel joins the
  agent's session as a sibling window instead of creating a fresh one.
- Refactor `ContentView.handleFolderSelected()` (`:151-177`) into a reusable
  `openSession(descriptor:)` the `DeepLinkHandler` can call without UI.

### WS3 — Take-the-wheel flow

- `DeepLinkHandler.takeWheel(payload)` → verify signature → resolve profile →
  set `paused` sentinel → `openSession` with `tmuxSessionName`, `cwd`,
  `attachWindowOnly`.
- Add a `WheelGate` concept: a tiny `claudette-emit`/`claudette-gate` helper shipped
  by the setup CLI, plus the PreToolUse hook entry (WS6).
- Persistent **Hand-back bar** + handoff markers in `SessionView`.

### WS4 — Hand-back flow

- Hand-back action: clear sentinel, write note + `resume` event, optional
  `tmux send-keys ... 'continue' Enter`, record marker, open Claude app universal
  link via `UIApplication.shared.open` (pattern already used in
  `SessionView.swift:343`, `TerminalContainerView.swift:100`).
- Edge cases from the UX doc (`docs/claudette-shell-handoff-ux.md`): running command
  on hand-back, dirty git tree summary, connection drop (tmux preserves state).

### WS5 — Structured event sidecar + native push  *(implements `docs/structured-mode-hardening.md`)*

The review confirmed Structured Mode is **pure ANSI scraping**
(`AgentActivityParser.swift:14-27`, `TerminalBlockDetector.swift:12-22`) and there
is **no remote tail/stream** (`RemoteFileBrowserService.readFile` loads whole files,
`:120-134`). So:

- Install hooks that append authoritative tool events as JSONL to
  `~/.claudette/events/<session>.jsonl` (Pre/Post/Tool/SubagentStop/Notification/Stop).
- Build a **streaming reader**: a dedicated SSH exec channel running
  `tail -n +1 -F ~/.claudette/events/<session>.jsonl`, parsed line-by-line — a new
  capability (`SSHConnectionManager` already streams an inbound PTY loop at
  `:153-167`; generalize it for a second, non-PTY exec channel).
- Feed events into the existing `AgentTreeNode` / visualizer models, replacing the
  regexes behind a feature flag, with scraping as fallback.
- Fire **native push** off the `Stop`/`Notification` events — closes the current
  gap vs. first-party (which has push, Claudette doesn't).

### WS6 — `claudette-setup` CLI changes  *(the machine-side enablement)*

The CLI already does environment prep + QR pairing (`cli/`). Add:

- **tmux-wrap Claude (decided: enforced by default):** `claudette-setup` configures
  the user's launch so agent sessions run in a deterministic tmux session
  (`claudette-<repo>`) **by default**, enabling co-location — take-the-wheel can't
  work reliably otherwise. (Today `tmuxEnabled` defaults **false** in
  `Configuration.plist` SessionPersistence and in the app config; the setup flow and
  the app's recommended path both flip to on, with an escape hatch for users who
  decline.)
- **Install hooks:** the wheel-gate PreToolUse hook, the event-emitter hooks, and
  the `/wheel` command + deep-link emitter.
- **Register associated domain** content and print the `claudette://`/universal-link
  pairing into the QR.
- Ship `claudette-emit` and `claudette-gate` helper scripts.

### WS7 — Hardening (foundation the moat sits on)

From the review's risk findings:

| Area | Finding (cited) | Action |
|---|---|---|
| Parsing brittleness | regex/ANSI scraping, no validation (`AgentActivityParser.swift:14-27`) | replace with event sidecar (WS5); keep scraping as fallback |
| Hook-write safety | arbitrary commands written to `~/.claude/settings.json` with no validation (`ClaudeSettingsService.swift`, review §2A) | validate/allowlist Claudette-managed hooks; namespace them; warn on third-party edits |
| No remote streaming | `readFile` reads whole files; no `tail -f` (`RemoteFileBrowserService.swift:120-134`) | add exec-channel streaming reader (WS5) |
| Token/cost fidelity | naive `charCount/4`, no cost model (`ClaudeMDDashboardView.swift:244`) | derive context/cost from structured events + real counts |
| Test coverage | parsers/tmux/WoL tested; SSH, SFTP, settings, discovery untested | add unit tests for new `DeepLinkHandler`, `ConnectionSettings` command build, sentinel I/O; fixtures for event parsing |
| No CI | none | add CI (build + test). A repo **SessionStart hook** can ensure web/agent sessions run tests — use the `session-start-hook` skill |
| Reconnect/resume of event stream | n/a | monotonic counter in JSONL envelope; re-tail from last seen on reconnect (handled by `SessionViewModel` foreground resume at `SessionView.swift:375-382`) |

---

## 5. Phased roadmap

**Phase 0 — Enablers (low risk, no UX change yet)**
WS1 scheme + `.onOpenURL` router; WS2 `ConnectionSettings` extension + `openSession`
refactor; CLI flips tmux-on and installs namespaced hooks. Ships dormant behind a
flag. *Exit:* a `claudette://take-wheel` link opens a shell at the right cwd in the
agent's tmux session.

**Phase 1 — Take the wheel (MVP)**
WS3 + the wheel-gate hook + hand-back bar. One-click in works; hand-back is "clear
gate + reopen Claude app." *Exit:* full round-trip demoable on a local Remote
Control session.

**Phase 2 — Hand back polish + push**
WS4 notes/markers/edge cases; WS5 event sidecar + **native push** (also the
notification deep-link trigger for take-the-wheel). *Exit:* push-driven "Claude is
blocked — take the wheel?" → tap → shell → tap → back.

**Phase 3 — Hardening & trust**
WS7 across the board: event stream becomes primary, hook-write validation, tests +
CI, token/cost fidelity. *Exit:* Structured Mode no longer depends on scraping;
green CI.

---

## 6. Security considerations

- **Deep links are untrusted input.** HMAC-sign the payload with a per-pairing
  secret established during `claudette-setup` (the CLI already does token pairing
  with constant-time comparison). Reject unsigned/expired links. Never auto-connect
  to a host not already paired without explicit confirmation.
- **Sentinels and hooks run code on the user's machine.** Namespace Claudette's
  hooks, validate what we write to `~/.claude/settings.json`, and surface a
  human-readable diff before writing (the review flagged unvalidated hook writes as
  an RCE-shaped risk).
- **Pause must fail safe.** If the gate helper is missing or the sentinel can't be
  written, take-the-wheel must **not** silently let the agent keep running — warn
  and fall back to a read-only attach.
- **Host trust unchanged:** reuse TOFU host-key pinning (`TOFUHostKeyValidator`).

---

## 7. Open questions / decisions needed

1. ~~**Trigger surface.**~~ **Decided:** push/notification deep link is the headline
   UX (Phase 2); the `/wheel` slash command ships first as the Phase 1 MVP trigger
   and remains as a fallback.
2. ~~**tmux-always?**~~ **Decided:** `claudette-setup` enforces tmux-wrapped Claude
   by default (with an opt-out), since co-location requires it.
3. **Universal-link domain** *(open)* — which domain hosts the AASA file
   (claudettemobile.com?).
4. **Cloud sessions** *(open)* — confirm we show the "teleport to your Mac first"
   affordance rather than trying to support take-the-wheel on cloud.

---

## Appendix A — Codebase review inventory

Condensed from a three-track review (connection/session lifecycle; deep-link/entry;
structured-mode/hooks/services). Full detail in the review transcripts.

**Connection & session (`SSHConnectionManager`, `TmuxSessionService`, `SessionViewModel`)**
- Citadel/NIOSSH; PTY via `client.withPTY` (`:104-169`); auth password or Ed25519
  from Keychain (`:344-361`).
- Command sent over PTY is built at `:122-145` from `config.sshCommand`
  (`"claude --continue"`) and `settings.projectPath`.
- tmux session name = `"<prefix>-<first8 of profileId>"`
  (`TmuxSessionService.swift:14-17`); attach/create/restart logic `:37-60`; **tmux
  off by default** (`Configuration.plist` SessionPersistence).
- Each `TerminalTab` owns one `SSHConnectionManager`; tabs add/close/select in
  `SessionViewModel.swift:112-147`; auto-reconnect on foreground
  (`SessionView.swift:375-382`).
- cwd is fully parameterized via `ConnectionSettings.projectPath`; **command and
  tmux name are not** — the two fields WS2 adds.

**Deep-link / entry**
- No `CFBundleURLTypes`, no `applinks:`, no `onOpenURL`, no app/scene delegate.
- Outbound `UIApplication.shared.open` exists (`SessionView.swift:343`,
  `TerminalContainerView.swift:100`).
- `AuthURLInterceptor` scrapes claude.ai/anthropic.com auth URLs *outbound*;
  `PermissionNotificationService` posts local notifications but has **no tap
  handler**.

**Structured mode / hooks / services**
- Structured Mode = ANSI scraping (`AgentActivityParser.swift:14-27`,
  `TerminalBlockDetector.swift:12-22`); brittle, no event source.
- Hooks UI supports Pre/PostToolUse, Notification, Stop only; written via **SFTP** to
  `~/.claude/settings.json` (`ClaudeSettingsService.swift:15,40-53`,
  `RemoteFileBrowserService.writeFile:137-149`) with **no command validation**.
- Resource discovery reads `.claude/commands|skills|agents` via SFTP + regex
  frontmatter (`ClaudeResourceDiscoveryService.swift:21-88,225-257`).
- **No remote tail/stream** (`RemoteFileBrowserService.readFile:120-134`).
- Token estimate = `charCount/4` (`ClaudeMDDashboardView.swift:244`); no cost model.
- Tests exist for parsers, tmux, WoL, models; **none** for SSH/SFTP/settings/
  discovery. No CI.

---

## Appendix B — Related docs

- `docs/claudette-vs-claude-apps.md` — the comparison (merged to `main`)
- `docs/claudette-positioning-brief.md` — the wedge, one page
- `docs/claudette-shell-handoff-ux.md` — the detailed handoff UX
- `docs/structured-mode-hardening.md` — the hook-sidecar design (WS5)
- `docs/claudette-launch-copy.md` — launch messaging
