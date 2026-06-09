# 📖 The Lean Engineering Manual: High-Velocity Single-Piece Flow

This document outlines the socio-technical architecture required to eliminate
code-inventory waste (stacked PRs) and scale parallel developer execution using
**Trunk-Based Development**, **Pushing Dark** (FunWithFlags), and **Git Worktrees**.

> **Status:** Blueprint / reference. The code, CI, and shell snippets here are
> *illustrative*. Where this doc and the live system disagree, the live system
> wins — the authoritative pipeline is your repository's CI workflow (e.g.
> `.github/workflows/ci-deploy.yml`), and the delivery philosophy this manual
> instantiates lives in your team's delivery-principles doc.
>
> **Branch name:** examples below show `master`, but the name is immaterial — it's
> whichever single branch reaches production (`main` / `master` / `trunk`). The worktree
> helpers read `$LEAN_WT_TRUNK` (default `main`); set it to whatever yours is.

---

## Section 1 — Core Philosophy & Tool Strategy

### 1. Visualizing Single-Piece Flow

Instead of building a multi-story stack of unmerged local branches, or waiting for
asynchronous code reviews to clear, code flows linearly and directly into the trunk
(`master`). When an emergency interruption occurs, a parallel workspace is spawned
*temporarily*, keeping the main feature line completely undisturbed.

```text
[Main Trunk]  ===========================================================>  (Prod)
                   ^                        ^                 ^
                   |                        |                 |
[Worktree 1]   (Task A: Expand API) -------+                 |
                                                             |
[Worktree 2]   (Emergency Hotfix) ---------------------------+  (spawned, pushed, deleted)
```

### 2. Stream Working Agreement

This agreement aligns cross-functional vertical-stream teams, developers, and
Product Owners to maintain a zero-PR delivery model.

#### A. Core Commitments

- We treat **Deployment** (moving code to production) as a technical utility, and
  **Release** (turning code on for users) as a business event.
- We integrate code to `master` multiple times a day to prevent inventory
  accumulation (Work in Progress).
- Stacked PRs are a process defect. We do not build local branches on top of
  unmerged local branches.

#### B. The Zero-PR Ticketing Lifecycle (Jira / Linear)

Our project-management states contain no async code-review bottleneck. Code is
merged and deployed *before* product validation occurs.

```text
[ To Do ] ──> [ In Progress ] ──> [ Deployed (Dark in Prod) ] ──> [ PO Acceptance ] ──> [ Done ]
                    │                       │                            │
              (Local Worktree)       (Commit to master)          (PO reviews flag)
```

- **In Progress** — Active coding, pairing, or mobbing inside an isolated local Git worktree.
- **Deployed (Dark)** — Code has passed the sub-10-minute CI pipeline and is live in
  production, hidden behind a feature flag. The code is directly on `master`.
- **PO Acceptance** — The ticket is assigned to the Product Owner. The PO logs into the
  production environment with their staff flag enabled to test and accept the live feature.
- **Done** — The PO verifies the capability and closes the ticket. (A later automated
  micro-ticket handles the **Contract** phase: delete the old path and the flag.)

#### C. Quality Control (Shift-Left)

Because we bypass traditional async PR lines, we maintain quality through
synchronous, real-time code visibility:

- **Ship** — Direct commit to `master` for all low-risk changes and Expand-phase work
  (dark database tables, new API endpoints, hidden UI components).
- **Show** — Commit directly to `master`, then post the commit link in the stream's
  channel for post-merge visibility and asynchronous learning.
- **Ask** — Reserved for complex architectural pivots. Developers pair or mob
  synchronously at the keyboard before pushing directly to `master`.

#### D. Product Owner SLA

- The PO understands that code in the **PO Acceptance** column is already running in
  production, darkly.
- The PO commits to moving tickets from **PO Acceptance** to **Done** within 24 hours.
- If a defect is found, it is **not** rolled back. It is resolved via an immediate,
  dark follow-up commit straight to `master`.

---

## Section 2 — Developer Automation & Cross-Platform Tooling

### 1. Terminal Shell Profiles (Worktree Engine)

These functions make local context switching effortless during an emergency switch
(e.g. a production bug). They spawn a clean room for the hotfix and destroy it when
finished, keeping local development frictionless.

> **The canonical implementations live alongside this doc:**
> [`lean-worktrees.sh`](./lean-worktrees.sh) (Bash/Zsh) and
> [`lean-worktrees.ps1`](./lean-worktrees.ps1) (PowerShell).
> This manual deliberately does **not** duplicate their code — an earlier revision
> embedded full copies here and they drifted stale (hardcoded `master`, missing
> `wtswitch`). One source of truth; the manual carries only the usage contract.

```bash
# ~/.zshrc / ~/.bashrc
source /path/to/dev-workflow/lean-worktrees.sh
export LEAN_WT_TRUNK=trunk      # only if your trunk isn't `main`

wtfix bug-123                   # spawn a clean worktree off origin/<trunk>, cd in
wtlist                          # list worktrees with branch + age
wtsync                          # rebase the active worktree onto origin/<trunk>
wtswitch <dir>                  # hop to a sibling worktree and resync it
wtback <feature> <fix>          # return to <feature>, remove <fix>, resync
```

PowerShell is the same contract: dot-source [`lean-worktrees.ps1`](./lean-worktrees.ps1)
from your `$PROFILE` and set `$env:LEAN_WT_TRUNK` if needed.

### 2. Local Git Pre-Commit Hook (Automated Sync) — ⚠️ NOT ADOPTED HERE

> **Caution — do not install this.** The snippet below auto-rebases onto
> `origin/master` on *every commit*. It conflicts with a repo's existing
> pre-commit hook (lint + format + fast test) and
> with the standing rule that **shift-left tooling stops at the commit/push boundary** —
> a hook that rewrites history mid-work is exactly the surprise that rule exists to
> prevent. Use `wtsync` *manually* before pushing instead. Retained here only to record
> the idea and why it was rejected.

```bash
#!/bin/bash
# .git/hooks/pre-commit  — illustrative only; see caution above
echo "🔄 Checking upstream sync..."
git fetch origin master --quiet
BEHIND_COUNT=$(git rev-list --count HEAD..origin/master)

if [ "$BEHIND_COUNT" -gt 0 ]; then
  echo "⚠️  You are $BEHIND_COUNT commits behind master."
  echo "⚡  Auto-rebasing now..."
  if git rebase origin/master; then
    echo "✅  Rebase successful."
  else
    echo "❌  Conflict detected during rebase. Fix manually via 'wtsync' and try again."
    exit 1
  fi
fi
```

### 3. AI Agent Execution Rules

Inject this specification into your AI agent rules (CLAUDE.md / `.cursorrules` /
`.clinerules`). It grants permission to use worktrees for execution while blocking
stacked-PR generation.

```markdown
# AI Agent Execution Rules: Elixir/Phoenix Single-Piece Flow

## Core Git Philosophy
1. **Trunk-Based:** Commit directly to `master` for all dark/safe changes.
2. **Zero-PR:** Do NOT suggest Pull Requests for feature expansion.
3. **Worktrees Allowed:** You are explicitly PERMITTED to use Git worktrees for
   context switching (hotfixes/experiments).
   - *Constraint:* Worktrees must be ephemeral — Create ➔ Fix ➔ Push to master ➔ Delete.

## Elixir & FunWithFlags Standards
1. **Branch by Abstraction:** When replacing logic, define a `behaviour` first.
   Implement the new logic in a fresh module.
2. **Dark Routing:** Use `FunWithFlags.enabled?(:flag_name, for: user)` to route traffic.
3. **Safety Checks:**
   - Before pushing to `master`, ALWAYS run `mix test` inside the active worktree.
   - Ensure strict compilation: `mix compile --warnings-as-errors`.

## Terminal Command Aliases
- `wtfix <name>`  — spawn a fresh environment.
- `wtback <target> <fix>` — clean up.
- `wtsync` — rebase upstream.
```

### 4. Where worktrees fit the TBD flow (and native vs hand-rolled tooling)

**Worktrees are auxiliary, not the default workspace.** The main human-in-the-loop work —
you and Claude developing features interactively — happens **directly on `master`**. Master
is the workbench where the main work happens; it is not a revered or idle base. Worktrees
exist only for work that should run *beside* the main thread without disturbing it:

- an **interrupting hotfix** while your `master` checkout is mid-WIP, or
- an **autonomous agent** working in parallel while you keep going on `master`.

They are an *optimisation* of the existing trunk-based flow — isolation + parallelism — not
a replacement for it. The rest stays exactly as-is: **no PRs** (worktrees push straight to
master), dark-ship behind FunWithFlags, tag-to-deploy, PO acceptance in prod. A worktree is
an isolation boundary, **not** an integration boundary: push to master continuously from
inside it, keep it rebased on trunk (`wtsync`), and delete it when its expand phase ships.
Dark-ship gating is what makes pushing incomplete work from a worktree safe.

#### Tooling — native vs hand-rolled

Claude Code ships native worktree support that covers most of what the shell functions
above do, verified against the Claude Code docs (worktrees / hooks reference, v2.1.x):

| Hand-rolled script | Native Claude Code equivalent |
|---|---|
| `wtfix <name>` (spawn off `origin/master`) | `claude --worktree <name>` / `-w` — branches from `origin/HEAD` by default (`worktree.baseRef: "fresh"`), i.e. exactly the trunk-based "clean off master" model |
| `wtswitch <dir>` | `EnterWorktree` tool — Claude switches worktrees mid-session |
| `wtback` (cleanup) | Auto-removed on exit if unchanged; subagent/background worktrees swept after `cleanupPeriodDays` |
| autonomous agent in its own tree | `isolation: worktree` in a subagent's frontmatter, or "use worktrees for your agents" |
| Base a worktree off in-progress (unpushed) work | `worktree.baseRef: "head"` |
| Replace creation entirely (non-git VCS, custom path) | `WorktreeCreate` / `WorktreeRemove` hooks |

Pick by who is driving the worktree:

- **Claude-driven (autonomous agent, or an in-session worktree) → native.** `claude --worktree`,
  `EnterWorktree`, and `isolation: worktree` are managed and auto-cleaned. No scripts, no hook.
- **Plain-terminal hotfix with no Claude session running → the `wt*` shell functions.** The
  one case native doesn't cover, because `--worktree` only applies when launching Claude.

#### Warming the build cache: `.worktreeinclude` (not a hook)

A fresh worktree is a clean checkout with an empty `_build`, so the cold-compile tax is
real. The native fix is a **`.worktreeinclude`** file at repo root (`.gitignore` syntax):
it copies matching **gitignored** files into every new worktree — `--worktree`, subagent
worktrees, and desktop parallel sessions alike. Because `_build`, `deps`, and the compiled
asset output are gitignored, they qualify.

```text
# .worktreeinclude
_build
deps
priv/static/assets
.env
```

> A `WorktreeCreate` hook would also work but *disables* `.worktreeinclude` (the hook owns
> creation). Use `.worktreeinclude` for warming; reserve the hook for non-git VCS or custom
> placement.

**What warming actually buys (measured on a production Phoenix app, 2026-06-08):**

| | Cold (no warming) | With `.worktreeinclude` (`_build` + `deps`) |
|---|---|---|
| `deps` (106 deps, 639 MB) | full recompile — the multi-minute part | **reused, no recompile** ✅ |
| app code (203 `.ex` files) | compile | **recompiles (~6 s)** — git checkout stamps sources with fresh mtimes, so mix sees them as stale even though content is identical |
| copy cost | — | ~6 s to copy ~844 MB |
| net first-compile | minutes | **~6 s copy + ~6 s app recompile ≈ ~12 s, then a 0.5 s no-op thereafter** |

So warming is worth it for a single hotfix tree or a small agent count — it converts a
cold start into a one-time ~12 s. **It is not a perfect no-op:** the app recompile is
unavoidable via `.worktreeinclude` alone, because mix keys on mtime and `git worktree add`
gives the checked-out sources new mtimes. Manifests use relative paths, so the copy is not
invalidated by the new worktree path.

> ⚠️ **Don't blindly warm a large fan-out.** Each warmed worktree copies ~844 MB. For a
> handful of agents that's fine; for a 30-agent `/batch` it's ~25 GB of copies and the IO
> cost outweighs the saved dep-compile. Warm Gap 1 and small agent counts; let a large
> fan-out compile cold (or share deps another way).

---

## Section 3 — Elixir / Phoenix / LiveView Implementation

This template implements **Branch by Abstraction (BBA)** using an Elixir `behaviour`,
routing execution paths dynamically at runtime via FunWithFlags.

### 1. The Contract (Abstraction Layer)

```elixir
# lib/my_app/notifications/dispatcher.ex
defmodule MyApp.Notifications.Dispatcher do
  @doc """
  Defines the strict compile-time contract for notification delivery channels.
  """
  @callback send(recipient :: struct(), title :: String.t(), body :: String.t()) ::
              {:ok, any()} | {:error, any()}
end
```

### 2. The Legacy Service Wrapper

```elixir
# lib/my_app/notifications/legacy_email.ex
defmodule MyApp.Notifications.LegacyEmail do
  @behaviour MyApp.Notifications.Dispatcher

  @impl true
  def send(recipient, title, body) do
    # Legacy transactional mail framework (e.g. Swoosh / Bamboo)
    MyApp.Mailer.deliver(recipient, title, body)
  end
end
```

### 3. The Expand-Phase Service (The Dark Code)

Written in an entirely isolated file — no structural cross-contamination with old paths.

```elixir
# lib/my_app/notifications/modern_channels.ex
defmodule MyApp.Notifications.ModernChannels do
  @behaviour MyApp.Notifications.Dispatcher

  @impl true
  def send(recipient, title, body) do
    # New capability: parallel SMS dispatching and high-performance channels
    IO.puts("[Dark Launch] Sending multi-channel alert to #{recipient.id}")
    {:ok, :sent_via_modern_channels}
  end
end
```

### 4. The Flag Routing Gateway (The PO Gate)

First, make your domain model FunWithFlags-actor scoped:

```elixir
# lib/my_app/accounts/user.ex
defimpl FunWithFlags.Actor, for: MyApp.Accounts.User do
  def id(user), do: "user:#{user.id}"
end
```

Then wire up the functional router module:

```elixir
# lib/my_app/notifications.ex
defmodule MyApp.Notifications do
  alias MyApp.Notifications.{LegacyEmail, ModernChannels}

  @doc """
  Dispatches notifications via a routed gateway backed by feature-flag targeting rules.
  """
  def send_notification(recipient, title, body) do
    if FunWithFlags.enabled?(:modern_notification_engine, for: recipient) do
      ModernChannels.send(recipient, title, body)
    else
      LegacyEmail.send(recipient, title, body)
    end
  end
end
```

### 5. The LiveView Test Panel (PO Acceptance Interface)

Lets the PO test the code live in production without leaking it to regular users.

```elixir
# lib/my_app_web/live/admin_dashboard_live.ex
defmodule MyAppWeb.AdminDashboardLive do
  use MyAppWeb, :live_view
  alias MyApp.Notifications

  @impl true
  def render(assigns) do
    ~H"""
    <div class="p-6 bg-white shadow rounded-lg">
      <h3 class="text-lg font-bold mb-2">Feature Flag Diagnostics</h3>
      <p class="text-sm mb-4">
        Active Engine State:
        <%= if FunWithFlags.enabled?(:modern_notification_engine, for: @current_user) do %>
          <span class="text-green-600 font-bold">Modern (v2 Enabled)</span>
        <% else %>
          <span class="text-gray-500">Legacy (v1 Default)</span>
        <% end %>
      </p>

      <button phx-click="test_notification" class="bg-blue-600 text-white px-4 py-2 rounded">
        Send Test Notification to My Account
      </button>
    </div>
    """
  end

  @impl true
  def handle_event("test_notification", _, socket) do
    user = socket.assigns.current_user

    case Notifications.send_notification(user, "Test Diagnostic", "Verifying the new system engine.") do
      {:ok, _} ->
        {:noreply, put_flash(socket, :info, "Notification dispatched via routed gateway!")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Execution failed.")}
    end
  end
end
```

---

## Section 4 — Illustrative GitHub Actions Pipeline

> **This is a teaching sketch, not a live pipeline.** A real pipeline (e.g. a repo's
> `.github/workflows/ci-deploy.yml`) typically adds a quality gate, release boot-check,
> deploy notifications, and deploys via its own `docker-compose.prod.yml`. The shape
> below illustrates the *gating strategy*: fast static analysis first, then a parallel
> test matrix, then deploy on tags only.

```yaml
name: CI / Deploy

on:
  push:
    branches: [master]
    tags: ["v*"]
  pull_request:
    branches: [master]

jobs:
  # GATE 1: Fast compilation and static analysis. Runs first.
  static_analysis:
    name: Static Analysis & Compilation
    runs-on: ubuntu-latest
    env:
      MIX_ENV: test
    steps:
      - uses: actions/checkout@v5

      - name: Set up Elixir
        id: setup
        uses: erlef/setup-beam@v1
        with:
          elixir-version: "1.19.2"
          otp-version: "28.1.1"

      - name: Cache deps
        uses: actions/cache@v5
        with:
          path: deps
          key: deps-${{ runner.os }}-${{ hashFiles('mix.lock') }}
          restore-keys: deps-${{ runner.os }}-

      - name: Cache build
        uses: actions/cache@v5
        with:
          path: _build
          key: build-${{ runner.os }}-${{ env.MIX_ENV }}-otp${{ steps.setup.outputs.otp-version }}-${{ hashFiles('mix.lock') }}
          restore-keys: build-${{ runner.os }}-${{ env.MIX_ENV }}-otp${{ steps.setup.outputs.otp-version }}-

      - name: Cache Dialyzer PLTs
        uses: actions/cache@v5
        with:
          path: priv/plts
          key: plts-${{ runner.os }}-otp${{ steps.setup.outputs.otp-version }}-${{ hashFiles('mix.lock') }}
          restore-keys: plts-${{ runner.os }}-otp${{ steps.setup.outputs.otp-version }}-

      - name: Install dependencies
        run: mix deps.get

      # 🛡️ BOUNDARY GATE: immediately catches forbidden domain cross-calls
      - name: Compile (warnings as errors)
        run: mix compile --warnings-as-errors

      - name: Check formatting
        run: mix format --check-formatted

      - name: Credo
        run: mix credo

      - name: Dialyzer
        run: mix dialyzer --format github

      - name: Hex audit
        run: mix hex.audit

      - name: Check unused deps
        run: mix deps.unlock --check-unused

  # GATE 2: Test execution split across parallel nodes
  test_suite:
    name: Test (${{ matrix.suite }})
    runs-on: ubuntu-latest
    needs: static_analysis # ⚡ Only boots infrastructure if compilation/boundaries pass
    strategy:
      fail-fast: false
      matrix:
        suite: [unit_integration, contract, e2e]
    env:
      MIX_ENV: test
      DATABASE_URL: ecto://postgres:postgres@localhost:5433/<app>_test
      REDIS_URL: redis://localhost:6379
    services:
      postgres:
        image: pgvector/pgvector:pg16
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: <app>_test
        ports:
          - 5433:5432
        options: >-
          --health-cmd "pg_isready -U postgres"
          --health-interval 5s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis:7-alpine
        ports:
          - 6379:6379
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 5s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v5

      - name: Set up Elixir
        id: setup
        uses: erlef/setup-beam@v1
        with:
          elixir-version: "1.19.2"
          otp-version: "28.1.1"

      - name: Restore cached deps
        uses: actions/cache@v5
        with:
          path: deps
          key: deps-${{ runner.os }}-${{ hashFiles('mix.lock') }}

      - name: Restore cached build
        uses: actions/cache@v5
        with:
          path: _build
          key: build-${{ runner.os }}-${{ env.MIX_ENV }}-otp${{ steps.setup.outputs.otp-version }}-${{ hashFiles('mix.lock') }}

      - name: Install dependencies
        run: mix deps.get

      - name: Set up database
        run: mix ecto.create --quiet && mix ecto.migrate --quiet

      - name: Run Unit/Integration Suite
        if: matrix.suite == 'unit_integration'
        run: mix test --exclude contract --exclude e2e --warnings-as-errors

      - name: Run Contract Tests
        if: matrix.suite == 'contract'
        run: mix test --only contract

      - name: Run E2E Tests
        if: matrix.suite == 'e2e'
        run: mix test --only e2e

  deploy:
    name: Deploy
    runs-on: ubuntu-latest
    needs: test_suite
    if: startsWith(github.ref, 'refs/tags/v')
    permissions:
      contents: read
      packages: write
    steps:
      - uses: actions/checkout@v5

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v4

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract version tag
        id: meta
        run: echo "version=${GITHUB_REF#refs/tags/}" >> "$GITHUB_OUTPUT"

      - name: Build and push image
        uses: docker/build-push-action@v7
        with:
          context: .
          push: true
          tags: |
            ghcr.io/<org>/<app>:latest
            ghcr.io/<org>/<app>:${{ steps.meta.outputs.version }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      # From here the mechanics are environment-specific — reach wherever prod runs
      # (SSH, cloud CLI, PaaS hook) and swap the image. Two invariants are worth
      # keeping whatever the target: run migrations as an explicit step *before*
      # the new containers come up, and deploy the exact image you just pushed.
      - name: Deploy
        run: |
          ssh deploy@your-prod-host "
            cd /srv/<app>
            docker compose pull
            docker compose run --rm app bin/<app> eval '<App>.Release.migrate()'
            docker compose up -d
          "
```
