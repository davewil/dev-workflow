# dev-workflow

A shareable engineering-workflow methodology: **trunk-based development with lean git
worktrees**, plus **containerised git-hooks tooling**. One transferable description of how to
ship in small batches safely — kept separate from any one project or personal config.

## Contents

### Methodology

| File | What it is |
|---|---|
| [`lean-blueprint.md`](./lean-blueprint.md) | The methodology write-up: trunk-based flow, when to use a worktree vs work on your main branch, build-cache warming, branch-by-abstraction + dark shipping, and an illustrative CI pipeline. |
| [`lean-worktrees.sh`](./lean-worktrees.sh) | Worktree shell helpers for Bash/Zsh — `wtfix` / `wtsync` / `wtswitch` / `wtback`. The canonical copy. |
| [`lean-worktrees.ps1`](./lean-worktrees.ps1) | PowerShell port of the same helpers. |
| [`lefthook-docker.md`](./lefthook-docker.md) | Containerised git-hooks reference (Lefthook + Docker, images pinned by digest; cross-platform macOS + Linux). |
| [`tests/lean-worktrees-test.sh`](./tests/lean-worktrees-test.sh) · [`.ps1`](./tests/lean-worktrees-test.ps1) | Regression suite for the worktree helpers — same four scenarios in both ports, run in CI under bash, zsh, and pwsh. |

### Worksheets — print-first session collateral

| File | What it is |
|---|---|
| [`worksheets/the-case.html`](./worksheets/the-case.html) | **The Case** — the *why*. A three-sheet persuasion piece: cover hook, trunk-based primer (DORA + AI-foundation pillars), and "the cost of the queue" for whoever owns the process. Read once; leave behind. |
| [`worksheets/the-sprint-kit.html`](./worksheets/the-sprint-kit.html) | **The Sprint Kit** — the *how*. Self-check, five practice ladders (single-piece flow, deploy≠release, life of a flag, worktree clean-room, ship/show/ask), and a one-sprint pledge. Worked with a pen, every sprint. |

Both are single self-contained HTML files designed to print to A4 (open in a browser →
print). Screen view is a live preview of the printed sheets.

### Decisions & design

| File | What it is |
|---|---|
| [`docs/decisions/0001-worksheet-medium.md`](./docs/decisions/0001-worksheet-medium.md) | ADR: print-first worksheets now, interactive on-screen edition deferred — and the constraints that keep the deferred option cheap. |
| [`docs/decisions/0002-split-the-case-from-the-kit.md`](./docs/decisions/0002-split-the-case-from-the-kit.md) | ADR: split the persuasion piece (The Case) from the working kit (The Sprint Kit) — one document doing both jobs did neither well. |
| [`docs/superpowers/specs/2026-06-09-lean-flow-worksheets-design.md`](./docs/superpowers/specs/2026-06-09-lean-flow-worksheets-design.md) | The worksheets' design spec: audiences, sheet-by-sheet content, shared components, theming, and verification checklist. |

## Using the worktree helpers

```bash
# in ~/.zshrc or ~/.bashrc
source /path/to/dev-workflow/lean-worktrees.sh
```

Then `wtfix <name>` spawns a clean worktree off the trunk, `wtlist` shows what exists
(with branch + age), `wtsync` rebases the active worktree onto trunk, `wtpush` rebases and
then pushes the worktree's HEAD straight to the trunk, `wtswitch` moves between worktrees,
and `wtback` tears one down — refusing if the worktree still holds uncommitted *or unpushed*
work. See `lean-blueprint.md` for the model — when a worktree is the right tool versus
working directly on your main branch.

## Status

Interim standalone repo, intended to roll into the `docs.davewil.dev` site so the methodology
is published rather than just stored. The artifact files have been genericised of
environment-specific detail.

The repo practices what it documents: commits are gated by its own digest-pinned
[`lefthook.yml`](./lefthook.yml), CI ([`checks.yml`](./.github/workflows/checks.yml)) mirrors
that gate and adds full external-link checking, and [`renovate.json`](./renovate.json) keeps
the pinned digests fresh — the guide's §5 and §7, running live. [MIT licensed](./LICENSE).

## Roadmap

- **Team/org agent-config subset** — a curated rewrite of the transferable engineering rules
  (trunk-based + worktrees, shift-left-stops-at-commit, library-doc verification,
  contract-tests-in-plans, expand/contract migrations) for a team audience, authored fresh
  rather than redacted from a personal config. Not started.
