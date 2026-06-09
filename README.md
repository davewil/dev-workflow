# dev-workflow

A shareable engineering-workflow methodology: **trunk-based development with lean git
worktrees**, plus **containerised git-hooks tooling**. One transferable description of how to
ship in small batches safely — kept separate from any one project or personal config.

## Contents

| File | What it is |
|---|---|
| [`lean-blueprint.md`](./lean-blueprint.md) | The methodology write-up: trunk-based flow, when to use a worktree vs work on your main branch, build-cache warming, branch-by-abstraction + dark shipping, and an illustrative CI pipeline. |
| [`lean-worktrees.sh`](./lean-worktrees.sh) | Worktree shell helpers for Bash/Zsh — `wtfix` / `wtsync` / `wtswitch` / `wtback`. The canonical copy. |
| [`lean-worktrees.ps1`](./lean-worktrees.ps1) | PowerShell port of the same helpers. |
| [`lefthook-docker.md`](./lefthook-docker.md) | Containerised git-hooks reference (Lefthook + Docker, images pinned by digest; cross-platform macOS + Linux). |

## Using the worktree helpers

```bash
# in ~/.zshrc or ~/.bashrc
source /path/to/dev-workflow/lean-worktrees.sh
```

Then `wtfix <name>` spawns a clean worktree off the trunk, `wtsync` rebases it onto trunk,
`wtswitch` moves between worktrees, and `wtback` tears one down. See `lean-blueprint.md` for
the model — when a worktree is the right tool versus working directly on your main branch.

## Status

Interim standalone repo, intended to roll into the `docs.davewil.dev` site so the methodology
is published rather than just stored. The artifact files have been genericised of
environment-specific detail.

## Roadmap

- **Team/org agent-config subset** — a curated rewrite of the transferable engineering rules
  (trunk-based + worktrees, shift-left-stops-at-commit, library-doc verification,
  contract-tests-in-plans, expand/contract migrations) for a team audience, authored fresh
  rather than redacted from a personal config. Not started.
