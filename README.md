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

## Feedback & issues

Product bugs, setup friction, and feature requests: **open an issue in this repo**.

PRs that improve this front-door docs surface are welcome. App/CLI source changes land in the private monorepo — see [CONTRIBUTING.md](./CONTRIBUTING.md).

## Not affiliated with Anthropic

Claudette is an independent Olorin product. Claude / Claude Code are trademarks of Anthropic PBC, used only to describe compatibility.
