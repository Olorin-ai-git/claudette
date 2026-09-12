# Claudette

**The mobile workstation for Claude Code.**

Claudette lets you drive your Claude Code session from iOS, Android, and Apple TV — with live context usage, agent tree, voice I/O, and a full power terminal — over SSH or Olorin Relay.

| | |
|---|---|
| **iOS** | [App Store](https://apps.apple.com/us/app/claudette-mobile/id6759467788) |
| **Android** | [Google Play](https://play.google.com/store/apps/details?id=com.olorin.claudette) |
| **CLI** | `npx claudette setup` |
| **Site** | [claudettemobile.com](https://claudettemobile.com) |

> **This repo is the public front door.** Active development lives in Olorin’s private monorepo (`olorin`, under `Claudette/`). The historical iOS tree still in this repository is a frozen snapshot — do not treat it as the live app source.

## Why install it

- **See inside the session** — context gauge, token history, agent tree (not just a dumb SSH pipe)
- **Voice-native** — dictate prompts; hear summaries when the agent finishes
- **Zero-config remote** — Instant Connect / QR pairing; Relay when you’re off LAN
- **$4.99 once for Pro** — no subscription; your Anthropic key/token stays yours


## Claudette vs Termius / Blink vs chat remotes

| Need | Termius / Blink / plain SSH | Chat remotes (Happy, Remote Control, etc.) | **Claudette** |
| --- | --- | --- | --- |
| Raw shell on phone | Yes | No / limited | **Yes** — full PTY + extended keyboard |
| See inside the agent session (context, cost, agent tree) | No | Partial (chat-shaped) | **Yes** — built for the live session |
| Human ↔ agent handoff in *one* session | No | No raw shell to hand off to | **Take the Wheel** — intervene, then hand back |
| Your machine, your keys, your local tools | Yes (dumb pipe) | Often via product cloud / subscription path | **SSH / Relay / Tailscale** + Instant Connect option |
| Price | Often subscription | Bundled with Claude plan or SaaS | **Free + $4.99 one-time Pro** |

**One line:** Termius gives you a shell without agent awareness. Chat remotes give you the agent without a real `$`. Claudette is the mobile **control plane** — both in one session.

## Quick start

1. Install the app ([App Store](https://apps.apple.com/us/app/claudette-mobile/id6759467788) or [Google Play](https://play.google.com/store/apps/details?id=com.olorin.claudette))
2. On your Mac/PC: `npx claudette setup`
3. Open Claudette → Connect → scan the QR / finish pairing → done

Registration with Olorin Relay is the default (so you can connect off LAN). Use `npx claudette setup --no-register` only if you want legacy direct-SSH pairing.

## Companion CLI

Published on npm as [`claudette`](https://www.npmjs.com/package/claudette):

```bash
npx claudette setup          # recommended first run
npx claudette setup --help   # flags (--no-register, --tunnel, …)
npx claudette register       # relay registration only
```

Requires Node 18+.


## Elsewhere

- **Dev.to:** [Claudette: a mobile control plane for your AI coding agent](https://dev.to/gil_klainert_b0aa996bee02/claudette-a-mobile-control-plane-for-your-ai-coding-agent-real-shell-session-ui-2cm9)
- **X:** [@olorin_ai](https://x.com/olorin_ai/status/2098532084876804418)

## Feedback & issues

Product bugs, setup friction, and feature requests: **open an issue in this repo**.

PRs that improve this front-door docs surface are welcome. App/CLI source changes land in the private monorepo — see [CONTRIBUTING.md](./CONTRIBUTING.md).

## Not affiliated with Anthropic

Claudette is an independent Olorin product. Claude / Claude Code are trademarks of Anthropic PBC, used only to describe compatibility.
