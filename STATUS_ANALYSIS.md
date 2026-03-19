# Claudette — Status Analysis

**Date:** 2026-03-19
**Branch:** `claude/analyze-claudette-status-793Jk`

## Overview

Claudette is a mobile workstation app (iOS/Android) for driving Claude Code sessions over SSH. Developed by Gil Klainert (Olorin-ai-git), licensed under MIT.

## Project Composition

| Component | Tech | Version | Status |
|-----------|------|---------|--------|
| iOS App | Swift / SwiftUI | 2.0 | TestFlight / App Store pending review |
| CLI (`claudette-setup`) | TypeScript / Node.js | 1.0.0 | Published |
| Android App | Separate repo | — | Available on Google Play |

## Architecture

**Pattern:** MVVM + Service Layer

- **14 data models** — ServerProfile, AuthMethod, ConnectionState, TerminalTab, KnownHost, BonjourHost, etc.
- **19+ services** — SSH, SFTP, Bonjour/mDNS, tmux, Wake-on-LAN, speech recognition, Claude resource discovery, agent activity parsing, etc.
- **6 view models** — Session, ProfileList, ProfileEditor, RemoteFileBrowser, RemoteFileEditor, SnippetDrawer
- **20+ SwiftUI views** — SessionView, ProfileListView, TerminalContainerView, AgentVisualizerView, HooksAutomationView, etc.
- **6 CLI services** — Environment detection, pairing server, SSH key installer, host key reader, QR generator, issue resolver

## Implemented Features

- Full terminal emulation with extended keyboard (Esc, Tab, Ctrl+C, Ctrl+T, pipes, brackets)
- Multi-tab tmux sessions with auto-reconnect
- Ed25519 SSH keys generated on-device, stored in Keychain
- TOFU host key verification with fingerprint pinning
- SFTP file browser and remote file editor
- Bonjour/mDNS local Mac auto-discovery
- Wake-on-LAN for remote Mac startup
- Claude Code integration (command palette, skills, agents, hooks)
- Voice input (speech recognition) and voice output (TTS summaries)
- Live token usage monitoring and cost tracking
- Claude.md project instructions viewer
- Prompt snippets drawer with categories
- Claude Code event hooks (PreToolUse, PostToolUse, Notification, Stop)
- Olorin Relay WebSocket support for remote access without VPN
- Session export and copy-to-clipboard

## Git Activity

- **17 commits** on main branch
- **1 merged PR** (#1 — fix auth redirect UI)
- Most recent commit: `b44fdd9` — README documentation update
- Working tree: clean

## Metrics

| Metric | Value |
|--------|-------|
| Primary Languages | Swift (iOS) + TypeScript (CLI) |
| Total Source Files | ~90 |
| Services (Swift) | 2,555+ lines |
| npm Dependencies | 5 production packages |
| Test Coverage | 0% |
| CI/CD | None |
| Documentation | Excellent (12.8 KB README + privacy policy) |

## Gaps & Recommendations

### Critical

1. **No automated tests** — 0% coverage. The 19+ service classes are ideal candidates for unit testing. Priority targets: SSHConnectionManager, SSHKeyService, ProfileStore, AgentActivityParser.
2. **No CI/CD pipeline** — Builds and TestFlight uploads are manual. A GitHub Actions workflow for build verification and TestFlight deployment would reduce risk.

### Recommended

3. **No linting/formatting** — No SwiftLint or ESLint configuration. Adding these would enforce code consistency.
4. **CLI test coverage** — The pairing server and environment detector have testable logic with no tests.
5. **Error handling audit** — Services use varied error handling patterns; standardizing would improve reliability.

### Low Priority

6. **No CHANGELOG** — Version history is only in git log.
7. **Android parity tracking** — No mechanism to track feature parity between iOS and Android apps.

## Security Posture

- Ed25519 key generation (CryptoKit)
- TOFU host key verification
- Keychain storage for credentials
- Constant-time token comparison in pairing server
- No telemetry or analytics
- Privacy policy maintained and up-to-date

## Conclusion

Claudette is a feature-rich, well-architected mobile SSH client purpose-built for Claude Code workflows. The codebase is clean with no outstanding TODOs. The highest-impact improvements would be adding automated tests and a CI/CD pipeline.
