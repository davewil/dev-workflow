# HANDOFF — dev-workflow artifact

> What this repo is, and where it's going. Read this first if you're picking it up later.

## What this is

The **shareable engineering-workflow methodology** — trunk-based development with lean git
worktrees, plus containerised git-hooks tooling. Extracted from personal dotfiles in June 2026
to keep the transferable method separate from personal config.

| File | What it is |
|---|---|
| `lean-blueprint.md` | The methodology write-up: trunk-based flow + worktree patterns, build-cache warming, when to use a worktree vs work on `master`. |
| `lean-worktrees.sh` | The worktree shell helpers (`wtfix`/`wtsync`/`wtswitch`/`wtback`). |
| `lean-worktrees.ps1` | PowerShell port of the same helpers (for the team artifact; unused in personal Mac+Linux sync). |
| `lefthook-docker.md` | Containerised git-hooks reference (Lefthook + Docker, pinned by digest). |

## Where it's going — rolls into `docs.davewil.dev`

This is an **interim standalone repo** (`github.com/davewil/dev-workflow`), here mainly so the
artifact is backed up off-machine and cloneable. **The intended home is the `docs.davewil.dev`
site repo** — it'll fold in there "at some point" so the methodology is published, not just
stored. When that happens:

- Use `git subtree add` or a submodule if you want to preserve this repo's history; or just copy
  the files if a clean start in the site repo is fine.
- Retire this standalone remote once the site repo is the source of truth.

## Caveats for whoever folds it in

- **`lean-worktrees.sh` is duplicated.** A second, canonical *sourced* copy lives in the dotfiles
  repo at `dotfiles/shell/lean-worktrees.sh` (that's the one machines actually source via
  `~/.zshrc`/`~/.bashrc`). This repo's copy is the publishable artifact. **A change to the script
  must update both copies** until they're consolidated.
- **This remote is private on purpose.** The artifact files haven't had a deliberate
  personal-content audit yet. Do that pass before the content goes public via the site
  (homelab IPs, machine paths, anything identity-specific). Flip to public only after.
- **Team/org CLAUDE.md subset is a separate, deferred task** — a curated rewrite of the
  transferable engineering rules for a team audience, authored fresh (not sed'd from the personal
  CLAUDE.md). Not started.

## Provenance

Split out of `~/dev/dotfiles` + the personal global `CLAUDE.md` on 2026-06-08/09, alongside wiring
the worktree helpers into dotfiles' `bin/install` for cross-machine sync. The CLAUDE.md
reconciliation that prompted this is complete (both Mac and laptop symlink the canonical file).
