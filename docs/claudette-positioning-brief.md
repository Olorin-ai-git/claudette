# Claudette Positioning Brief

**One page. One wedge. One sentence you can put on the landing page.**

---

## Thesis

> **Claudette is the only Claude client where you can grab the wheel.**
> Every Anthropic surface lets you *talk to* the agent. Claudette lets you drop
> into a real shell mid-session, do the thing yourself, and hand control back.

The single missing first-party feature worth building around is a **raw,
interactive terminal on mobile** — and, more precisely, the **seamless handoff
between the agent and a human at a live prompt.**

---

## Why this wedge, and why now

Anthropic has closed almost every gap Claudette originally opened:

| Original Claudette advantage | First-party status (June 2026) |
|---|---|
| Drive Claude Code on *your own machine* from your phone | ✅ Closed — **Remote Control** (full local FS, MCP, tools) |
| Run work while away from your desk | ✅ Closed — **Dispatch**, **Claude Code on the web** |
| Push when a task finishes | ✅ Closed — and now a *Claudette* gap (no native push) |
| Voice in / out | ✅ Closed — Voice Mode, 5 voices |
| No account / no cloud / open source | ⚠️ A *stance*, not an acquisition feature (you still need a Claude plan or API key to run Claude Code at all) |

Subtract all of that and **one structural difference remains: every first-party
surface is an agent-mediated chat.** Remote Control, Dispatch, and Claude Code on
the web never expose a `$` prompt. Anthropic won't add a raw shell to the consumer
Claude app — it's a deliberate product-surface and security decision. That's what
makes the wedge **durable** instead of a feature they ship next month.

---

## The moment it sells

> **Claude is blocked, or you need to do something by hand — and you're not at
> your laptop.**

- A migration half-applied; you need to `psql` in and fix one row.
- A merge conflict Claude can't resolve; you want to `git rebase -i` yourself.
- A stuck process to `kill`, a service to restart, a log to `tail -f`.
- You just want to run a command *now*, without narrating it to an agent.

On every Anthropic surface, that moment sends you back to your desk. On Claudette,
you tap into a real shell and finish it from your phone.

---

## Target user

**Terminal-fluent developers and operators** who already run Claude Code and are
regularly away from their main machine. This is a **niche wedge, not mass-market**
— the realistic strategy is to *own the pro-terminal segment*, not to out-polish
Anthropic for everyone.

---

## The feature to actually build

The terminal alone isn't the differentiator — Claudette already has one. The
differentiator is the **agent ↔ human handoff** in a single shared session, which
no first-party app can offer because none has both surfaces in one place:

1. Watch Claude work in Structured Mode.
2. Claude gets blocked (or you choose to intervene) → **one tap drops you into the
   live shell, same tmux session, same cwd, mid-context.**
3. You run your manual commands.
4. **Hand control back** — "continue from here" — with the shell state Claude can
   now see.

Pitch: *Remote Control lets you talk to the driver. Claudette lets you take the
wheel and hand it back.*

(See `claudette-shell-handoff-ux.md` for the detailed flow.)

---

## Messaging pillars

1. **Take the wheel** — the only Claude client with a real shell *and* the agent,
   in one session.
2. **Never stuck at "I'll fix it when I'm back at my desk."**
3. **Zero abstraction** — it's your machine, your tmux, your prompt.

---

## Risks & prerequisites (close these first)

- **Native push** — first-party has it; Claudette doesn't. A wedge feature won't
  retain users on top of a missing table-stakes capability.
- **Tests / CI** — currently 0% coverage, no pipeline. Don't ship a flagship
  feature on an unverified base.
- **Niche ceiling** — be honest that this wins power users, not the mainstream.

---

## How to know it's working (validation metrics)

- % of sessions that use the shell-handoff at least once.
- Handoffs per active user per week (frequency = real need).
- Retention delta for users who used handoff vs. those who didn't.
- Qualitative: "I'd have had to wait until I got home" testimonials.
