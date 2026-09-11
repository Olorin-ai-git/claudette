# Contributing to Claudette (public front door)

Thanks for helping. This repository is the **public discovery + feedback hub** for Claudette.

## What lives here

- Install links (App Store, Google Play)
- First-run docs for the companion CLI (`npx claudette setup`)
- Issues for product feedback and setup friction

Active app, CLI, and relay source lives in Olorin’s private monorepo (`olorin` → `Claudette/`). The older iOS tree still checked into this repo is a **frozen snapshot**, not the shipping codebase.

## How to help

1. **File an issue** for bugs, confusing setup steps, or feature ideas. Include OS, app version, and the exact CLI command you ran when relevant.
2. **Docs PRs** that improve this README / CONTRIBUTING / setup clarity are welcome — keep them thin and accurate.
3. **Do not** open PRs that modify the frozen historical app source expecting them to ship.

## First-run command (important)

The live npm CLI (`claudette@1.9.0+`) registers by **default**:

```bash
npx claudette setup
```

There is **no** `--register` flag (it errors). Opt out of registration with `--no-register` only for legacy direct-SSH pairing.

## Trademark / affiliation

Claudette is independent. Claude and Claude Code are trademarks of Anthropic PBC — use them only to describe compatibility, never to imply endorsement.
