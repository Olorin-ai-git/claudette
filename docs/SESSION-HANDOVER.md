# Session Handover — Claudette Moat / Hardening Work

**Date:** 2026-06-18 · **Repo:** `Olorin-ai-git/claudette` ·
**Branch:** `claude/claudette-vs-claude-apps-wdutb0`

Pick up here. This captures everything done, decided, and pending.

---

## 1. What this work is

Started as "compare Claudette vs. first-party Claude apps," evolved into a full
**strategy + hardening plan** centered on Claudette's one durable wedge:
**the only Claude client where a human can take the wheel** — a one-click handoff
from the Claude app into a real shell, and one click back to the agent.

---

## 2. Current state — PRs

| PR | Contents | State |
|---|---|---|
| **#4** | `docs/claudette-vs-claude-apps.md` (the comparison) + the SwiftTerm CI fix | ✅ **merged to `main`** (squash) |
| **#5** | the 5 strategy/plan docs below | 🔄 **open**, CI was queued at handover (docs-only; expected green) |

**Open loop:** confirm #5's checks went green and **merge #5** if approved. The
session was subscribed to #5 activity; webhooks deliver CI *failures* and review
comments but **not** CI success — so success must be checked manually.

**iOS CI fixes applied on this branch (unverified until CI re-runs):**
- **SwiftTerm pin:** `exactVersion 1.10.1` → `1.11.0` → now **`upToNextMajor >= 1.11.2`**.
  1.10.1 had a `Package.swift` manifest bug (broke dependency resolution); 1.11.0 had
  an iOS compile error in `TerminalView` SendData key handling (Codex P1, fixed in
  1.11.1/PR #473). Moving off `exactVersion` lets Xcode select patched releases.
  Updated `project.pbxproj` + `Package.resolved` (rev `b1262db…`, v1.11.2).
- **`ci.yml`:** the `macos-15`/Xcode 16 runner lacked the iOS 18 simulator runtime,
  so xcodebuild failed at destination resolution (`iOS 18.0 is not installed`) before
  compiling. Added an `xcodebuild -downloadPlatform iOS` step and dropped the brittle
  `OS=latest` pin (`-destination 'platform=iOS Simulator,name=iPhone 16'`).
  **Both fixes are best-effort and unverified — no Xcode here; watch the next CI run.**

---

## 3. Deliverables (all under `docs/`)

| File | Purpose | Status |
|---|---|---|
| `claudette-vs-claude-apps.md` | Full comparison vs Remote Control / Dispatch / Claude Code on the web | on `main` |
| `claudette-positioning-brief.md` | One-page positioning: the wedge, target user, pillars, metrics | PR #5 |
| `claudette-shell-handoff-ux.md` | Detailed agent↔human "take the wheel / hand back" UX | PR #5 |
| `structured-mode-hardening.md` | Replace ANSI scraping with a hook-emitted JSONL event sidecar | PR #5 |
| `moat-alignment-plan.md` | **The master plan** — codebase review + handoff architecture + 7 workstreams + roadmap | PR #5 |
| `claudette-launch-copy.md` | Hero copy, App Store/Play listing, social | PR #5 |

`moat-alignment-plan.md` is the source of truth; the others are referenced from it
(Appendix B).

---

## 4. The core technical idea (so you don't re-derive it)

- Claudette and the first-party Claude app **don't share a transport**: Remote
  Control is an Anthropic-protocol session; Claudette is **SSH + tmux + PTY**.
- Therefore "same session" = **co-locate both in one tmux session**: agent in
  window 0, Claudette attaches a **sibling shell in window 1**, same cwd.
- The agent is **paused, not killed**, via a **PreToolUse "wheel gate" hook** that
  blocks on a `~/.claudette/handoff/<session>.paused` sentinel Claudette writes/clears.
- **Take the wheel:** push/notification deep link (or `/wheel`) →
  `claudette://take-wheel?host&cwd&tmux&sid&sig` → `.onOpenURL` opens the shell +
  sets the sentinel.
- **Hand back:** clear sentinel, optional note + resume event, open the Claude app
  universal link.
- **Scope:** local sessions only. Cloud (Claude Code on the web) can't be attached —
  show a "teleport to your Mac first" affordance.

---

## 5. Decisions LOCKED

1. **Take-the-wheel trigger:** push/notification deep link is the headline UX
   (Phase 2); **`/wheel` slash command ships first** (Phase 1 MVP) and stays as
   fallback.
2. **tmux:** `claudette-setup` **enforces tmux-wrapped Claude by default** (opt-out
   available) — required for co-location.

## 6. Decisions STILL OPEN

3. **Universal-link domain** for the AASA file — `claudettemobile.com` or another
   host the team controls?
4. **Cloud sessions** — confirm the "teleport to your Mac first" affordance vs.
   attempting cloud support (recommend the affordance).

---

## 7. Codebase review — key findings (cited, so you can start coding)

Full inventory in `moat-alignment-plan.md` Appendix A. Highlights:

- **No deep-linking today:** no `CFBundleURLTypes`, no `applinks:`, no `onOpenURL`;
  bundle id `com.olorin.claudette`. Add scheme + `.onOpenURL` in `ClaudetteApp.swift`
  (~line 69) → new `Services/DeepLinkHandler.swift`.
- **Session command is built** in `SSHConnectionManager.swift:122-145` from
  `config.sshCommand` (`"claude --continue"`) + `settings.projectPath`. cwd is
  parameterized; **command and tmux name are not** — add `initialCommand` and
  `tmuxSessionName` to `Models/ConnectionSettings.swift`.
- **tmux name** = `"<prefix>-<first8 of profileId>"` (`TmuxSessionService.swift:14-17`);
  attach/create logic `:37-60`; **tmux off by default** (`Configuration.plist`).
  Add `attachNewWindowCommand(...)`.
- **Hooks** write via **SFTP** to `~/.claude/settings.json`
  (`ClaudeSettingsService.swift:15,40-53`), UI supports Pre/PostToolUse, Notification,
  Stop only, **no command validation** (harden this).
- **No remote tail/stream** — `RemoteFileBrowserService.readFile:120-134` loads whole
  files. The event sidecar needs a new exec-channel `tail -F` reader (generalize the
  PTY inbound loop at `SSHConnectionManager.swift:153-167`).
- **Structured Mode is pure ANSI scraping** (`AgentActivityParser.swift:14-27`,
  `TerminalBlockDetector.swift:12-22`) — brittle; replace with the sidecar behind a
  flag, keep scraping as fallback.
- **Tests:** exist for parsers/tmux/WoL/models; **none** for SSH/SFTP/settings/
  discovery. CI is `.github/workflows/ci.yml` (iOS build+test on macos-15; CLI on
  ubuntu). See §2 for the iOS CI fixes applied on this branch (SwiftTerm version
  range + simulator-runtime install) — verify they hold on the next run.

---

## 8. Recommended next steps (in order)

1. **Confirm #5 green and merge it** (docs only).
2. **Answer open decisions 3 & 4** (domain, cloud affordance).
3. **Phase 0 implementation** (low-risk, ships dormant behind a flag, no UX change):
   - URL scheme + `.onOpenURL` router + `Services/DeepLinkHandler.swift`
   - `ConnectionSettings.initialCommand` / `tmuxSessionName` (+ `attachWindowOnly`)
   - `SSHConnectionManager.connect()` to honor them; `TmuxSessionService.attachNewWindowCommand`
   - Refactor `ContentView.handleFolderSelected()` (`:151-177`) into reusable
     `openSession(descriptor:)`
   - Unit tests for the new command-build paths
4. **Spec the hooks** for `claudette-setup`: `wheel-gate` PreToolUse, event emitters,
   `/wheel` command, `claudette-emit`/`claudette-gate` helpers.
5. **Add CI** (build + test); consider a repo SessionStart hook (the
   `session-start-hook` skill) so web/agent sessions run tests.

Then Phase 1 (take-the-wheel MVP via `/wheel`), Phase 2 (push + hand-back polish +
event sidecar + native push), Phase 3 (hardening + green CI). See roadmap §5 in the
plan.

---

## 9. Environment / process notes for the next session

- **Ephemeral container** — commit & push to persist. Develop on
  `claude/claudette-vs-claude-apps-wdutb0`; push with `git push -u origin <branch>`.
- **GitHub via MCP only** — no `gh` CLI / API token; can't poll GitHub from Bash.
- **No `send_later`** in this session — couldn't schedule self check-ins; rely on
  webhooks (which miss CI success / merge conflicts) and manual re-checks.
- **iOS build can't be compiled here** (Linux, no Xcode) — verification is via CI.
- Commit trailer convention and PR body footer are already in use across this
  branch's commits; match them.
