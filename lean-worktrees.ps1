# ==============================================================================
# LEAN WORKTREE FUNCTIONS  (PowerShell)
# ------------------------------------------------------------------------------
# Trunk-based, single-piece-flow worktree helpers. Dot-source from your
# $PROFILE, or drop into your dotfiles repo and import it.
#
#   wtfix <name>                 spawn a clean worktree off your main branch and cd in
#   wtlist                       list worktrees with branch + age
#   wtsync                       rebase the active worktree onto your main branch
#   wtpush                       rebase, then push the worktree's HEAD straight to trunk
#   wtback <feature> <fix>       cd back to <feature>, remove <fix> worktree, resync
#
# Lifecycle: wtfix → fix/commit → wtpush → wtback. No branch, no PR.
#
# wtfix checks out origin/<trunk> directly, so the worktree is on a detached
# HEAD — deliberate: there's no local branch to clean up afterwards. The catch
# is that pushing from detached HEAD needs `git push origin HEAD:<trunk>`,
# which is what wtpush wraps (after a rebase — sync is manual, at the push
# boundary, never in a hook).
#
# The integration branch (the one that hits prod) defaults to `main`. Set
# $env:LEAN_WT_TRUNK to whatever yours is — the name doesn't matter.
# ==============================================================================

if (-not $env:LEAN_WT_TRUNK) { $env:LEAN_WT_TRUNK = "main" }

function wtfix {
    param([string]$name)
    if ([string]::IsNullOrEmpty($name)) {
        Write-Host "❌ Error: Please provide a hotfix name (e.g., wtfix bug-123)" -ForegroundColor Red
        return
    }
    Write-Host "🔄 Fetching latest $($env:LEAN_WT_TRUNK)..." -ForegroundColor Cyan
    git fetch origin $env:LEAN_WT_TRUNK --quiet
    Write-Host "📁 Spawning clean workspace in ../$name..." -ForegroundColor Cyan
    git worktree add "../$name" "origin/$($env:LEAN_WT_TRUNK)"
    Write-Host "🚀 Swapping to new workspace..." -ForegroundColor Green
    Set-Location "../$name"
}

function wtlist {
    git worktree list | ForEach-Object {
        $parts  = $_ -split "\s+"
        $path   = $parts[0]
        $branch = git -C $path rev-parse --abbrev-ref HEAD
        $age    = git -C $path log -1 --format="%cr"
        [PSCustomObject]@{
            Branch = $branch
            Age    = $age
            Path   = $path
        }
    } | Format-Table -AutoSize
}

function wtsync {
    Write-Host "🔄 Syncing active workspace with the main trunk..." -ForegroundColor Cyan
    git fetch origin $env:LEAN_WT_TRUNK --quiet
    git rebase "origin/$($env:LEAN_WT_TRUNK)"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Rebase hit conflicts — resolve them, then re-run." -ForegroundColor Red
        return
    }
    Write-Host "✅ Workspace aligned with origin/$($env:LEAN_WT_TRUNK)." -ForegroundColor Green
}

function wtpush {
    # Rebase onto the trunk first (the manual sync at the push boundary), then
    # push the worktree's detached HEAD straight to the trunk — no branch, no PR.
    wtsync
    if ($LASTEXITCODE -ne 0) { return }
    Write-Host "⬆️  Pushing HEAD to origin/$($env:LEAN_WT_TRUNK)..." -ForegroundColor Cyan
    git push origin "HEAD:$($env:LEAN_WT_TRUNK)"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Landed on origin/$($env:LEAN_WT_TRUNK)." -ForegroundColor Green
    }
}

function wtswitch {
    # cd into a sibling worktree and fast-forward it onto the trunk in one step.
    # Refs are already shared across worktrees, so this is just the rebase.
    # wtsync refuses if the target has uncommitted changes — deliberate, so an
    # automatic rebase never clobbers work in progress.
    param([string]$target)
    if ([string]::IsNullOrEmpty($target)) {
        Write-Host "❌ Error: Usage: wtswitch <worktree-dir-name>" -ForegroundColor Red
        return
    }
    Set-Location "../$target"
    wtsync
}

function wtback {
    param([string]$target_dir, [string]$fix_dir)
    if ([string]::IsNullOrEmpty($target_dir) -or [string]::IsNullOrEmpty($fix_dir)) {
        Write-Host "❌ Error: Usage: wtback <feature-dir-name> <hotfix-dir-name>" -ForegroundColor Red
        return
    }
    Write-Host "↩️ Returning to main feature workspace..." -ForegroundColor Cyan
    Set-Location "../$target_dir"
    Write-Host "🔥 Vaporising temporary workspace..." -ForegroundColor Yellow
    git worktree remove "../$fix_dir"
    if ($LASTEXITCODE -ne 0) {
        # git refuses on uncommitted changes — that's the safety net working.
        Write-Host "❌ Couldn't remove ../$fix_dir — it still has uncommitted (or unpushed) work." -ForegroundColor Red
        Write-Host "   Go back and finish it (commit + wtpush), or discard it with:" -ForegroundColor Red
        Write-Host "   git worktree remove --force ../$fix_dir" -ForegroundColor Red
        return
    }
    wtsync
    if ($LASTEXITCODE -ne 0) { return }
    Write-Host "✨ Clean room destroyed. Workspace updated. Back to work!" -ForegroundColor Green
}
