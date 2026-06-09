# 0002 — Split the *why* (The Case) from the *how* (The Sprint Kit)

**Status:** Accepted — 2026-06-09
**Supersedes:** the single-artifact structure in the original spec.
**Related:** [`0001-worksheet-medium.md`](0001-worksheet-medium.md)

## Context

Designing for three readers in turn — new grad, IC skeptic, Head of Engineering — kept
bolting more *why* (primer, DORA evidence, the AI-foundation thesis, the cost-of-the-queue
argument) onto the worksheets. The artifact drifted from a sprint worksheet into a manifesto.
A team mid-sprint won't read a six-page argument; a Head of Engineering won't fill in a
worksheet. One document doing both jobs does neither well.

## Decision

Two print-first artifacts, each with a clean audience and job:

| **The Case** — the *why* | **The Sprint Kit** — the *how* |
|---|---|
| Cover hook · primer (what it is + payoff) · two pillars (**DORA** + **AI-foundation**) · **the cost of the queue** (leaders' sheet). | Self-check → **ladders ①–⑤** (incl. life-of-a-flag ③) → **pledge**. |
| **Persuades.** For decision-makers + skeptics. Opens the session; hand to a Head of Eng; leave behind. Read once. | **Drives action.** For the team, with a pen, in the room. Used every sprint. |

## Consequences

- The Sprint Kit's ladders **shed their heavy explanation** (the why now lives in The Case) and
  get lean and action-first — what a sprint kit should be.
- **Decoders stay on The Sprint Kit** — the new grad *doing the work* still needs words defined
  at the point of use. That's teaching-to-do, not persuading.
- Both stay Rosé Pine Dawn, print-first, hybrid voice. Shared CSS/components.
- Files: `worksheets/the-case.html`, `worksheets/the-sprint-kit.html`.

## Deferred (captured, not lost)

- **The website (on-screen Moon edition B, ADR 0001) comes later.** When it does, **The Case is
  its natural home** — a persuasion manifesto *wants* to be a beautiful scrollable page;
  The Sprint Kit stays paper. The print artifacts must keep the ADR-0001 seams (SVG diagrams,
  semantic markup, CSS-variable theming) so The Case can grow a screen edition without a rewrite.
