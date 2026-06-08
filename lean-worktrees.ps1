# ==============================================================================
# LEAN WORKTREE FUNCTIONS  (PowerShell)
# ------------------------------------------------------------------------------
# Trunk-based, single-piece-flow worktree helpers. Dot-source from your
# $PROFILE, or drop into your dotfiles repo and import it.
#
#   wtfix <name>                 spawn a clean worktree off origin/master and cd in
#   wtlist                       list worktrees with branch + age
#   wtsync                       rebase the active worktree onto origin/master
#   wtback <feature> <fix>       cd back to <feature>, remove <fix> worktree, resync
#
# Assumes the trunk branch is `master`. Set $env:LEAN_WT_TRUNK to override.
# ==============================================================================

if (-not $env:LEAN_WT_TRUNK) { $env:LEAN_WT_TRUNK = "master" }

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
    Write-Host "✅ Workspace aligned with origin/$($env:LEAN_WT_TRUNK)." -ForegroundColor Green
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
    wtsync
    Write-Host "✨ Clean room destroyed. Workspace updated. Back to work!" -ForegroundColor Green
}
