# Design — Lean Dev-Workflow Adoption Collateral

**Status:** Draft for review — 2026-06-09 (rev 3 — split into two artifacts)
**Decisions:** [`0001-worksheet-medium.md`](../../decisions/0001-worksheet-medium.md) ·
[`0002-split-the-case-from-the-kit.md`](../../decisions/0002-split-the-case-from-the-kit.md)
**Source material:** [`lean-blueprint.md`](../../../lean-blueprint.md)

## Goal

Collateral that gets an engineering team to **buy into the lean trunk-based workflow for one
sprint** — first by *winning the argument* (with decision-makers and skeptics), then by giving
the team a *practical worksheet* to locate themselves, tick what they already do, and commit
to the next step. Print-first; "shows off" the principles *and* does real work.

## Audience spectrum

The collateral must span three readers — and that spread is exactly why it splits in two:

- **New grad** — needs *what it is*. Served by plain language + per-sheet decoders (on the Kit).
- **IC skeptic** — needs *a reason*. Served by The Case.
- **Head of Engineering / EM / hiring manager** — owns the process; the PR queue is their sacred
  cow. Needs cost/throughput/risk language. Served by The Case's "cost of the queue" sheet.

## The split (ADR 0002)

| **The Case** — the *why* | **The Sprint Kit** — the *how* |
|---|---|
| Persuades. Read once. Opens the session / leave-behind for leaders. | Drives action. Worked with a pen, every sprint. |
| `worksheets/the-case.html` | `worksheets/the-sprint-kit.html` |

## Shared decisions

| | |
|---|---|
| Medium | **Print-first** → A4. On-screen "website" edition deferred (ADR 0001); The Case is its future home (ADR 0002). |
| Voice | **A+C hybrid** — editorial header band over terminal/monospace interior. |
| Palette | **Rosé Pine Dawn** via CSS custom properties. **Moon** reserved for the website edition. |
| Branch name | **`trunk`** throughout. |
| Build | Each artifact a **single self-contained HTML file** (CSS + inline SVG + subsetted latin woff2 fonts base64-embedded — Fraunces 900 display, IBM Plex Mono 400/700/400i interior). Shared CSS/components copied between the two. |
| Print | `@page{size:A4}`, `break-after:page` per sheet, `break-inside:avoid` on boxes; accents are ink/borders not fills (legible with background-graphics off). A4 default (UK); Letter is a one-line change. |

---

## Artifact 1 — The Case (the *why*)

A short, beautiful persuasion piece. Tone: confident, evidence-backed, **anti-hype** —
fundamentals-first. No control/audit/governance vocabulary (that framing makes rooms
defensive and breaks a standing rule); pure cost-and-flow. A regulated-industry audit angle,
if needed, is the facilitator's to add live — not a printed line.

**Sheets:**

1. **Cover** — warm hook ("You already do more of this than you think"), "what's inside" in
   plain words, 3-line "how to use."
2. **Why trunk-based? (primer)** — plain definition; "old way hurts" vs "the payoff"; then
   **two pillars**: (1) *it's measured* — DORA predicts elite delivery (Four Keys; the
   research, not the EU regulation); (2) *it's the foundation for AI* — applied AI amplifies
   whatever workflow you have, so the fundamentals are the rails (parallel worktrees,
   dark-ship, fast CI gate). Closes with a "worries you're thinking" mini-FAQ.
3. **The cost of the queue (for leaders)** — the "6 hours on pull requests" anchor reframed as
   a daily bill; *feels like (control) / actually is (inventory + latency)*; the hidden taxes
   (engineer hours, lead time, context-switching, rubber-stamping, throughput ceiling); the
   four objections a Head of Engineering will raise, answered in cost/flow terms; bottom line —
   optimise the flow, not the review; DORA shows speed and stability rise together.

**Facilitator space:** leave deliberate "your story here" margins — the persuasion lands
through the experienced facilitator's war stories, not the printed page (this is where their
experience matters; the page is scaffolding).

---

## Artifact 2 — The Sprint Kit (the *how*)

Lean and action-first. The why lives in The Case, so the ladders carry only what's needed to
*act*. Per-sheet **decoders** stay — the new grad doing the work needs words at the point of use.

**Sheets:**

1. **Self-check** — ~12 rows, three-state tick (no / sort-of / yes); some worded as
   antipatterns (honest "yes" = a flag). Closes with "where you land → start on this ladder"
   (a pointer, not a score).

2–6. **Ladders ①–⑤** — each: editorial header band · four-rung ladder (tick state + highlighted
next rung) · decoder · signature inline-SVG diagram · short takeaway · **one** inclusive
exercise. Lean: no long prose.

- **① Single-piece flow** — short-lived branches → no stacking → commit to `trunk` dark →
  many dark integrations/day + worktrees. Diagram: waiting-stack vs straight line to prod.
- **② Deployment ≠ Release** — can deploy without releasing → ship behind a flag off-by-default
  → PO flips in prod → release decoupled; cleanup. Diagram: commit to prod, separate flag switch.
- **③ Delivered ≠ Done — the life of a flag** — "deployed" ≠ "accepted" → feedback while dark
  (staff flag, PO trials in prod) → **the PO accepts and that flips the switch** (release is the
  PO's call) → **consolidate**: remove the flag, delete the old path (no flag debt). Diagram:
  the flag's life — born off · lives dark · flipped by the PO · then dies; the two steps teams
  skip (the PO flip, the consolidate) are the visual centre. Exercise: count your live flags /
  how many are past consolidation.
- **④ The worktree clean-room** — create a worktree → hotfix off `trunk` without touching WIP
  (`wtfix`) → rebased + pushed straight to trunk (`wtpush`), delete (`wtback`) → agents in
  their own trees (`claude --worktree`). Diagram: `wtfix → fix → wtpush → wtback`. Footnote:
  set `export LEAN_WT_TRUNK=trunk` so printed commands match the branch.
- **⑤ Ship / Show / Ask** — Ship direct / Show the commit link / Ask (pair-mob) for pivots →
  PRs retired as default; quality from visibility + CI. Diagram: three lanes → one trunk.

7. **Pledge** — pick 1–2 next rungs, write them, name an owner each, date it, "revisit — end
   of sprint," signature row.

## Components (shared)

Header band (Fraunces masthead over an Oxford rule; stroke-only ghost numeral `0N`;
"from→to" + `sheet N/total`) · ladder/rung (monospace on a visible rail; next open rung
highlighted Gold+Love) · decoder (Foam box; dictionary entries — term + italic
part-of-speech — on a `max-content` grid) · takeaway (dashed Rose) · exercise (Foam label,
monospace blanks; inclusive phrasing) · footer · print-object chrome (registration
corners, fore-edge index tabs, spine line — all ink/borders, never backgrounds) ·
certificate pledge (double rules, roundel stamp, ×-marked signature lines) · inline-SVG
diagrams (Dawn line-art, never raster — ADR 0001).

## Theming

Rosé Pine **Dawn** CSS custom properties on `:root`; **Moon** as a live-but-inert
`:root[data-theme="moon"]` override — set the attribute on `<html>` to re-theme (the
seam is proven, not just prepared). Diagram colour lives in CSS ink-token classes
(`f-*`/`s-*`), never SVG presentation attributes; derived tints use `color-mix()` against
palette variables so they track whichever theme is active. `@media print` enforces breaks,
drops screen chrome.

## Verification

Render both files in a real browser (Dawn reads well); print-preview via Chrome DevTools (one
sheet per A4 page, no clipping, boxes unsplit, legible with background graphics on *and* off);
spot-check Dawn contrast.

## Out of scope (v1)

- **Ladders 6–7** — Branch-by-Abstraction, CI gating pyramid. Same template, added later.
- **The website** — on-screen Moon edition (animation, clickable diagrams, live widgets).
  Deferred; The Case is its home; kept cheap by single-source + SVG + CSS-variable theming.

## Open question

- **Paper size** — A4 default (UK); add a Letter `@page` toggle if the audience is US.
