# Lefthook with Docker-based hooks — setup guide

> Goal: git hooks that run **inside containers**, pinned by **digest**, so the
> same checks produce the same outputs on Mac, Arch Linux, and CI. The container
> is the unit of reproducibility; the host only needs Docker and Lefthook.
>
> Primary tool: [Lefthook](https://github.com/evilmartian/lefthook).
> Pre-commit covered as an alternative in section 9.

Last reviewed: 2026-05-23.

---

## 0. End state

Every machine that touches the repo runs the same checks the same way:

- **Mac** — OrbStack provides the Docker socket. No Docker Desktop.
- **Arch Linux** — native Linux Docker. lazydocker for ad-hoc inspection.
- **CI** — GitHub Actions runner with native Docker, Lefthook installed per job.
- **Hook images** — pinned by SHA256 digest, not by tag. Updates managed by Renovate.

When a new dev joins, the only prerequisites are: a git client, a Docker runtime, and the `lefthook` binary. Everything else (linter versions, formatter rules, secrets scanners) is supplied by the pinned hook images.

---

## 1. Mac: swap Docker Desktop for OrbStack

```bash
# Drain Docker Desktop cleanly first
open -a "Docker"                            # let it finish whatever it was doing
# In Docker Desktop: Troubleshoot → Uninstall (removes the privileged helpers properly)

# Or, fully scripted uninstall:
/Applications/Docker.app/Contents/MacOS/uninstall

# Install OrbStack
brew install --cask orbstack

# Launch it once so it sets up the socket + LinuxKit equivalent
open -a OrbStack

# Verify the docker CLI now talks to OrbStack
docker context ls                           # should show 'orbstack' as default
docker info | grep -i orbstack              # confirms server is OrbStack
docker run --rm hello-world                 # smoke test
```

**Notes:**

- OrbStack auto-imports Docker Desktop's contexts, images, and volumes on first launch.
- If you keep Docker Desktop installed during a trial period, they coexist — switch with `docker context use orbstack` / `docker context use desktop-linux`.
- File mounts from `~/` work out of the box (OrbStack uses virtiofs).

---

## 2. Install Lefthook

```bash
# Mac
brew install lefthook

# Arch Linux / Arch
sudo pacman -S lefthook                     # community repo; AUR fallback otherwise

# Any platform with Node already installed
npm install -g lefthook                     # installs a prebuilt native binary

# Any platform with Go
go install github.com/evilmartian/lefthook@latest

# Inside a repo, install the git hook shims
cd /path/to/repo
lefthook install                            # writes .git/hooks/pre-commit, etc.
```

A `lefthook.yml` lives at the repo root. We'll fill it in next.

**Why a single binary matters:** unlike pre-commit, Lefthook doesn't need a Python runtime or per-hook virtualenvs. A new contributor on any OS needs only the binary + Docker — no `pip`, no `pyenv`, no version mismatches.

---

## 3. Docker-based hook configuration

Lefthook's mental model is **shell commands you orchestrate**. There's no built-in "language type" abstraction; you write the `docker run` command yourself. With digest pinning, that directness is a feature — the contract is fully visible in the file.

### Example `lefthook.yml`

```yaml
# lefthook.yml
# All hook images pinned by SHA256 digest. Update via Renovate (see section 7).
# Template vars: {root} = repo root, {staged_files} = files staged for this commit.

pre-commit:
  parallel: true
  commands:

    # --- Python: ruff (lint, auto-fix) ---
    ruff-check:
      glob: "*.py"
      run: |
        docker run --rm --user $(id -u):$(id -g) \
          -v {root}:/src -w /src \
          ghcr.io/astral-sh/ruff@sha256:REPLACE_WITH_DIGEST \
          check --fix --exit-non-zero-on-fix {staged_files}
      stage_fixed: true

    # --- Python: ruff (format) ---
    ruff-format:
      glob: "*.py"
      run: |
        docker run --rm --user $(id -u):$(id -g) \
          -v {root}:/src -w /src \
          ghcr.io/astral-sh/ruff@sha256:REPLACE_WITH_DIGEST \
          format {staged_files}
      stage_fixed: true

    # --- Dockerfile lint ---
    hadolint:
      glob: "**/Dockerfile*"
      run: |
        for f in {staged_files}; do
          docker run --rm -i ghcr.io/hadolint/hadolint@sha256:REPLACE_WITH_DIGEST < "$f" || exit 1
        done

    # --- Shell scripts ---
    shellcheck:
      glob: "*.{sh,bash}"
      run: |
        docker run --rm -v {root}:/mnt -w /mnt \
          docker.io/koalaman/shellcheck@sha256:REPLACE_WITH_DIGEST \
          {staged_files}

    # --- YAML ---
    yamllint:
      glob: "*.{yml,yaml}"
      run: |
        docker run --rm -v {root}:/code -w /code \
          docker.io/cytopia/yamllint@sha256:REPLACE_WITH_DIGEST \
          {staged_files}

    # --- Secrets detection (scans the whole tree, not just staged) ---
    trufflehog:
      run: |
        docker run --rm -v {root}:/scan -w /scan \
          ghcr.io/trufflesecurity/trufflehog@sha256:REPLACE_WITH_DIGEST \
          filesystem --no-update --fail --no-verification .

commit-msg:
  commands:
    conventional-commits:
      run: |
        docker run --rm -i \
          ghcr.io/commitizen-tools/commitizen@sha256:REPLACE_WITH_DIGEST \
          check --commit-msg-file {1}
```

**Notes on the YAML:**

- `parallel: true` runs commands in parallel — the main reason Lefthook is fast.
- `stage_fixed: true` auto-`git add`s files that a formatter modified, so the commit picks them up without a second pass.
- `glob` filters which files trigger which commands.
- `--user $(id -u):$(id -g)` keeps file ownership correct on native Linux (Arch Linux). On Mac with OrbStack it's a no-op but harmless.
- For commands that scan a single file via stdin (like hadolint), a small for-loop iterates `{staged_files}`.

### Finding the digest for an image

```bash
# Pull the tag once, then read the digest
docker pull ghcr.io/astral-sh/ruff:latest
docker inspect --format='{{index .RepoDigests 0}}' ghcr.io/astral-sh/ruff:latest
# ghcr.io/astral-sh/ruff@sha256:1a2b3c…
```

Or without pulling (uses `skopeo`):

```bash
brew install skopeo                          # Mac
sudo pacman -S skopeo                        # Arch Linux

skopeo inspect docker://ghcr.io/astral-sh/ruff:latest | jq -r '.Digest'
# sha256:1a2b3c…
```

Paste the `sha256:…` after the `@` in the image reference.

---

## 4. Initial smoke test

```bash
# From the repo root — run all pre-commit hooks against all tracked files
lefthook run pre-commit --all-files

# First run pulls every hook image — expect 30s–3min depending on bandwidth
# Subsequent runs are container-startup cost only (100–300ms per hook on OrbStack)
```

If anything fails, fix or update the args and re-run. Once green, commit `lefthook.yml`.

---

## 5. CI mirror — GitHub Actions

The CI job runs **the same `lefthook run`** as locally, using the same image digests, on a Linux runner that has Docker natively.

```yaml
# .github/workflows/lefthook.yml
name: lefthook

on:
  pull_request:
  push:
    branches: [main]

jobs:
  lefthook:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0                    # lefthook needs git history for some hooks

      - name: Install Lefthook
        run: npm install -g lefthook@1.13.0  # pin version; bump via Renovate

      - name: Run pre-commit hooks
        run: lefthook run pre-commit --all-files

      - name: Run commit-msg checks (PRs only)
        if: github.event_name == 'pull_request'
        run: |
          git log --format=%B -n 1 ${{ github.event.pull_request.head.sha }} > /tmp/commit-msg
          lefthook run commit-msg 1=/tmp/commit-msg
```

The runner already has Docker; Lefthook pulls the same digests; output matches local. If a hook is green locally and red in CI (or vice versa), the config is wrong — that divergence shouldn't happen with digest pinning.

**On caching:** GitHub-hosted runners are ephemeral, so Docker images pull fresh per job. For test-side service images (Postgres, Redis) that's normally fast enough against the CDN. If it becomes painful, options are:
- `docker/build-push-action` with `cache-from: type=gha` for built images.
- Self-hosted runners (e.g. a persistent build host) which keep the local Docker layer cache between jobs natively. Cleanest setup if commit volume justifies it.

---

## 6. Cross-machine notes

### Mac (OrbStack)

- UID/GID mapping handled by OrbStack — hooks that write files leave them owned by you, not root.
- `~/` paths mount automatically into hook containers.
- `--user $(id -u):$(id -g)` in the `docker run` is harmless but unnecessary; keep it for parity with Arch Linux.

### Arch Linux (native Linux Docker)

- Add yourself to the `docker` group once so you don't need sudo:
  ```bash
  sudo usermod -aG docker $USER
  newgrp docker                              # apply without logout
  ```
- `--user $(id -u):$(id -g)` is essential — without it, formatters that write files leave them owned by root.
- lazydocker is purely a viewer — it doesn't change the runtime. Keep using it for ad-hoc inspection.

### Remote / self-hosted Docker host

- Don't run hooks against a remote Docker host (latency + offline-commit concerns). Reserve
  remote hosts for app workloads.
- A persistent remote host is a candidate for a self-hosted GitHub Actions runner if CI
  cache reuse becomes valuable.

### CI

- `ubuntu-latest` runners include Docker. Install only Lefthook (`npm install -g lefthook@X`).
- Pin the Lefthook version explicitly. Renovate can bump it via the npm manager.

---

## 7. Keeping digests fresh — Renovate

Renovate doesn't ship a native Lefthook manager (it does for pre-commit), so digest tracking uses a `customManagers` regex. This is more setup than pre-commit's first-class support, but a one-time cost.

```json
// renovate.json (repo root)
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "customManagers": [
    {
      "customType": "regex",
      "description": "Update Docker image digests pinned in lefthook.yml",
      "fileMatch": ["^lefthook\\.yml$"],
      "matchStrings": [
        "(?<depName>(?:[a-z0-9.\\-]+(?:\\.[a-z0-9.\\-]+)*/)?[a-z0-9.\\-/]+)@(?<currentDigest>sha256:[a-f0-9]{64})"
      ],
      "datasourceTemplate": "docker"
    }
  ],
  "packageRules": [
    {
      "matchManagers": ["custom.regex"],
      "matchFileNames": ["lefthook.yml"],
      "pinDigests": true,
      "automerge": false,
      "groupName": "lefthook hook images"
    },
    {
      "matchManagers": ["npm"],
      "matchPackageNames": ["lefthook"],
      "automerge": true
    }
  ]
}
```

Renovate will open PRs that bump the SHA256 digest when each upstream image changes, plus PRs to bump Lefthook itself. CI runs the new digest; if hooks still pass, merge.

Alternative — write a small shell script (`scripts/refresh-digests.sh`) that uses `skopeo inspect` to update digests in-place, and run it weekly via a scheduled GitHub Actions workflow that opens its own PR. More code, less Renovate config.

---

## 8. Bootstrap script for new machines

Drop a `Makefile` (or `justfile`) at the repo root so new contributors run one command:

```makefile
# Makefile
.PHONY: bootstrap hooks-pull hooks-test

bootstrap: ## One-time setup for new contributors
	@command -v lefthook >/dev/null || { echo "Install lefthook first: brew install lefthook  (or pacman -S lefthook, or npm i -g lefthook)"; exit 1; }
	@command -v docker >/dev/null || { echo "Install Docker first (OrbStack on Mac, native on Linux)"; exit 1; }
	lefthook install
	$(MAKE) hooks-pull
	$(MAKE) hooks-test

hooks-pull: ## Pre-pull all hook images so first commit is fast
	@grep -oE '[a-z0-9./-]+@sha256:[a-f0-9]{64}' lefthook.yml | sort -u | while read ref; do \
		echo "Pulling $$ref"; \
		docker pull "$$ref"; \
	done

hooks-test: ## Run all hooks against all files (CI-equivalent)
	lefthook run pre-commit --all-files
```

New contributor runs `make bootstrap` once. Hooks installed, images warmed, smoke test passes.

---

## 9. Pre-commit alternative — when to choose it instead

[pre-commit](https://pre-commit.com) (the Python framework, Yelp/Anthony Sottile) is the older, larger-ecosystem alternative.

**Pick pre-commit over Lefthook if:**
- You want a rich ecosystem of pre-built hook repos (`detect-secrets`, `prettier`, `terraform-fmt`, etc., one-line imports).
- Python is already a baseline prerequisite in your stack and you don't mind another Python tool.
- Renovate's native `pre-commit` manager matters to you (no custom regex needed).

**Stick with Lefthook if:**
- Single-binary install matters (no Python prereq).
- Commit latency matters (faster startup, parallelism first-class).
- You're polyglot — Lefthook's shell-command model fits any toolchain.

Equivalent `.pre-commit-config.yaml` for the section 3 example:

```yaml
# .pre-commit-config.yaml — pre-commit equivalent
repos:
  - repo: local
    hooks:
      - id: ruff
        name: ruff (lint)
        language: docker_image
        entry: ghcr.io/astral-sh/ruff@sha256:REPLACE_WITH_DIGEST
        args: [check, --fix, --exit-non-zero-on-fix]
        types: [python]

      - id: ruff-format
        name: ruff (format)
        language: docker_image
        entry: ghcr.io/astral-sh/ruff@sha256:REPLACE_WITH_DIGEST
        args: [format]
        types: [python]

      - id: hadolint
        name: hadolint
        language: docker_image
        entry: ghcr.io/hadolint/hadolint@sha256:REPLACE_WITH_DIGEST
        files: ^(.*/)?Dockerfile(\..*)?$

      - id: shellcheck
        name: shellcheck
        language: docker_image
        entry: docker.io/koalaman/shellcheck@sha256:REPLACE_WITH_DIGEST
        types: [shell]

      - id: yamllint
        name: yamllint
        language: docker_image
        entry: docker.io/cytopia/yamllint@sha256:REPLACE_WITH_DIGEST
        types: [yaml]

      - id: trufflehog
        name: trufflehog
        language: docker_image
        entry: ghcr.io/trufflesecurity/trufflehog@sha256:REPLACE_WITH_DIGEST
        args: [filesystem, --no-update, --fail, --no-verification]
```

Install + run:

```bash
brew install pre-commit                      # Mac
sudo pacman -S pre-commit                    # Arch Linux
pre-commit install
pre-commit run --all-files
```

The CI step replaces `npm install -g lefthook` with `pip install pre-commit` and `lefthook run pre-commit` with `pre-commit run --all-files`. Everything else (digest pinning, OrbStack, cross-machine notes) is unchanged.

Both tools coexist with the rest of this guide — only the orchestration layer differs.

---

## 10. Common pitfalls

- **Tag drift** — if any hook image still uses `:latest` or a version tag instead of `@sha256:…`, your "reproducible" promise is broken. Grep for `:latest` in `lefthook.yml` before committing.
- **Image pull cost on first commit** — without the bootstrap script (section 8), the first commit pulls every image and feels slow. Always pre-pull.
- **Missing `--user` on Linux** — hooks that write files (formatters) leave files owned by root on native Linux if you forget `--user $(id -u):$(id -g)`. OrbStack hides this on Mac. Always include it.
- **Hooks needing network** — secrets scanners or vulnerability checkers may need outbound access. `docker run` allows it by default; air-gapped CI needs configuration.
- **Large repos + `--all-files`** — initial run on a large repo can take minutes. Use plain `lefthook run pre-commit` (staged only) for the actual commit-time hook; `--all-files` is for initial cleanup and CI.
- **Hook authors changing image tags** — only relevant if you didn't pin by digest. With digest pinning, this can't surprise you.
- **OrbStack vs Docker Desktop socket path** — both publish to `/var/run/docker.sock` on Mac via symlink. Tools that hard-code unusual socket paths may need updating; standard CLIs are fine.
- **Lefthook version skew** — pin the Lefthook binary version in CI and in your team's install instructions. Behaviour differences between versions are rare but real.

---

## 11. Philosophy: shift-left, pull-from-the-right

Two lenses on why this pattern exists. Both worth carrying into design discussions and interviews.

**Shift-left** — the direct technical framing. Move quality checks as close to the point of authoring as possible. The argument is the defect-cost curve: catching a problem at commit costs cents, in CI costs dollars, in production costs thousands. Lefthook and pre-commit are textbook shift-left tools.

**Pull-from-the-right** — the kanban / value-stream-mapping framing of the same dynamic. Downstream pain *creates demand* for upstream checks:

- A CI failure becomes a pre-commit rule.
- A production incident becomes a CI gate.
- A customer complaint becomes a regression test.
- A regulatory finding becomes a control in the build pipeline.

Each defect that escapes a stage should *pull* a corresponding check into the previous stage. Viewed this way, your `lefthook.yml` is a **log of what downstream stages stopped tolerating** — not a static standards document handed down from on high.

The two framings are the same dynamic from different ends of the pipe: shift-left pushes the check earlier; pull-from-the-right says the downstream failure is what should pull the check earlier in the first place.

### Lineage

| Tradition | What it contributes |
|---|---|
| **XP** (Kent Beck) | "Build quality in, don't inspect it later." Automated tests, CI, refactoring discipline. Git hooks are a direct descendant. |
| **Toyota Production System / Lean** | *jidoka* (stop the line at the source of defects), *poka-yoke* (mistake-proofing — make the wrong action impossible), *kaizen* (continuous improvement). |
| **DevOps** | Shorten feedback loops, automate everything, build–measure–learn. |
| **Software supply chain / SLSA** | Reproducibility, attestation, integrity at every stage. Digest pinning is a SLSA-aligned practice. |

### Practical implications

- **Don't design the hook config top-down** from "here are the standards we want enforced." Grow it bottom-up from incidents and CI failures. Every hook should be traceable to a defect that once escaped the previous layer.
- **Each hook is cheap; the *combination* gets expensive.** Prune aggressively — a hook that hasn't caught a real problem in 18 months might be noise rather than signal. The config should evolve in both directions.
- **Tests aren't a substitute for shift-left controls.** A test catches the problem you knew to look for; a linter catches the *class* of problem you might not have anticipated. Both belong.
- **Commit and pre-push are the right boundary — don't go further left.** It's tempting to extend the same discipline into the IDE (lint-on-save, format-on-keystroke, type-check-on-edit). Don't. Hooks at commit/push catch the same defects with much less ongoing friction; pushing checks into every keystroke turns a useful discipline into a development-loop tax and ends in process hell. IDE config a developer enables for their own ergonomics is fine — that's a personal choice, not a pattern to recommend.

---

## Quick reference

```bash
# Find a fresh digest for a hook image
skopeo inspect docker://ghcr.io/astral-sh/ruff:latest | jq -r '.Digest'

# Pre-pull all hook images
make hooks-pull

# Run hooks against staged files (what the git hook does on commit)
lefthook run pre-commit

# Run hooks against the whole tree (CI-equivalent)
lefthook run pre-commit --all-files

# Skip hooks for an emergency commit (use sparingly)
git commit --no-verify -m "wip"
# Or per-hook skip:
LEFTHOOK_EXCLUDE=ruff-check git commit -m "wip"

# Update Lefthook itself
brew upgrade lefthook                        # Mac
npm update -g lefthook                       # cross-platform
lefthook self-update                         # if installed via go

# Verify which Docker is serving the socket
docker info | grep -E "Server Version|Operating System"

# Reinstall the git hook shims (after cloning, or after editing lefthook.yml's hook list)
lefthook install
```
