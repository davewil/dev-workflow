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
if (-not $env:LEAN_WT_REMOTE) { $env:LEAN_WT_REMOTE = "origin" }

function Get-WtBaseDir {
    $toplevel = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($toplevel)) {
        Write-Host "❌ Error: Not inside a git repository." -ForegroundColor Red
        return $null
    }
    return (Split-Path $toplevel -Parent)
}

function wtfix {
    param([string]$name)
    if ([string]::IsNullOrEmpty($name)) {
        Write-Host "❌ Error: Please provide a hotfix name (e.g., wtfix bug-123)" -ForegroundColor Red
        return
    }
    $baseDir = Get-WtBaseDir
    if (-not $baseDir) { return }
    Write-Host "🔄 Fetching latest $($env:LEAN_WT_TRUNK)..." -ForegroundColor Cyan
    git fetch $env:LEAN_WT_REMOTE $env:LEAN_WT_TRUNK --quiet
    if ($LASTEXITCODE -ne 0) { return }
    Write-Host "📁 Spawning clean workspace in $baseDir/$name..." -ForegroundColor Cyan
    git worktree add "$baseDir/$name" "$($env:LEAN_WT_REMOTE)/$($env:LEAN_WT_TRUNK)"
    if ($LASTEXITCODE -ne 0) { return }
    Write-Host "🚀 Swapping to new workspace..." -ForegroundColor Green
    Set-Location "$baseDir/$name"
}

function wtlist {
    git worktree list | ForEach-Object {
        $parts  = $_ -split "\s+"
        $path   = $parts[0]
        $branch = git -C $path rev-parse --abbrev-ref HEAD 2>$null
        # wtfix worktrees are detached, so abbrev-ref yields the literal "HEAD" —
        # show the short SHA instead, which is at least identifying.
        if ($branch -eq "HEAD") {
            $branch = "detached@" + (git -C $path rev-parse --short HEAD 2>$null)
        }
        $age    = git -C $path log -1 --format="%cr" 2>$null
        [PSCustomObject]@{
            Branch = $branch
            Age    = $age
            Path   = $path
        }
    } | Format-Table -AutoSize
}

function wtsync {
    Write-Host "🔄 Syncing active workspace with the main trunk..." -ForegroundColor Cyan
    git fetch $env:LEAN_WT_REMOTE $env:LEAN_WT_TRUNK --quiet
    if ($LASTEXITCODE -ne 0) { return }
    git rebase "$($env:LEAN_WT_REMOTE)/$($env:LEAN_WT_TRUNK)"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Rebase hit conflicts — resolve them, then re-run." -ForegroundColor Red
        return
    }
    Write-Host "✅ Workspace aligned with $($env:LEAN_WT_REMOTE)/$($env:LEAN_WT_TRUNK)." -ForegroundColor Green
}

function wtpush {
    # Rebase onto the trunk first (the manual sync at the push boundary), then
    # push the worktree's detached HEAD straight to the trunk — no branch, no PR.
    wtsync
    if ($LASTEXITCODE -ne 0) { return }
    Write-Host "⬆️  Pushing HEAD to $($env:LEAN_WT_REMOTE)/$($env:LEAN_WT_TRUNK)..." -ForegroundColor Cyan
    git push $env:LEAN_WT_REMOTE "HEAD:$($env:LEAN_WT_TRUNK)"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Landed on $($env:LEAN_WT_REMOTE)/$($env:LEAN_WT_TRUNK)." -ForegroundColor Green
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
    $baseDir = Get-WtBaseDir
    if (-not $baseDir) { return }
    if (-not (Test-Path "$baseDir/$target")) {
        Write-Host "❌ Error: $baseDir/$target does not exist" -ForegroundColor Red
        return
    }
    Set-Location "$baseDir/$target"
    wtsync
}

function wtback {
    param([string]$target_dir, [string]$fix_dir)
    if ([string]::IsNullOrEmpty($target_dir) -or [string]::IsNullOrEmpty($fix_dir)) {
        Write-Host "❌ Error: Usage: wtback <feature-dir-name> <hotfix-dir-name>" -ForegroundColor Red
        return
    }
    $baseDir = Get-WtBaseDir
    if (-not $baseDir) { return }
    Write-Host "↩️ Returning to main feature workspace..." -ForegroundColor Cyan
    if (-not (Test-Path "$baseDir/$target_dir")) {
        Write-Host "❌ Error: $baseDir/$target_dir does not exist" -ForegroundColor Red
        return
    }
    Set-Location "$baseDir/$target_dir"
    # git worktree remove only refuses on *uncommitted* changes. Committed-but-
    # unpushed work on a detached HEAD would be silently orphaned — the worktree's
    # HEAD ref and reflog die with it — so guard against that here, explicitly.
    $unpushed = git -C "$baseDir/$fix_dir" rev-list --count "$($env:LEAN_WT_REMOTE)/$($env:LEAN_WT_TRUNK)..HEAD" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Error: Could not verify if $fix_dir has unpushed commits." -ForegroundColor Red
        return
    }
    if ([int]$unpushed -gt 0) {
        Write-Host "❌ $baseDir/$fix_dir has $unpushed unpushed commit(s) — removing it would orphan them." -ForegroundColor Red
        Write-Host "   Go back and land them (wtpush), or discard them with:" -ForegroundColor Red
        Write-Host "   git worktree remove --force $baseDir/$fix_dir" -ForegroundColor Red
        return
    }
    Write-Host "🔥 Vaporising temporary workspace..." -ForegroundColor Yellow
    git worktree remove "$baseDir/$fix_dir"
    if ($LASTEXITCODE -ne 0) {
        # git refuses on uncommitted changes — that's the safety net working.
        Write-Host "❌ Couldn't remove $baseDir/$fix_dir — it still has uncommitted work." -ForegroundColor Red
        Write-Host "   Go back and finish it (commit + wtpush), or discard it with:" -ForegroundColor Red
        Write-Host "   git worktree remove --force $baseDir/$fix_dir" -ForegroundColor Red
        return
    }
    wtsync
    if ($LASTEXITCODE -ne 0) { return }
    Write-Host "✨ Clean room destroyed. Workspace updated. Back to work!" -ForegroundColor Green
}

function wtbranch {
    param([string]$name, [string]$reason)
    if ([string]::IsNullOrEmpty($name) -or [string]::IsNullOrEmpty($reason)) {
        Write-Host "❌ Error: Usage: wtbranch <branch-name> <mandatory-reason-for-breaking-tbd>" -ForegroundColor Red
        Write-Host "   Example: wtbranch my-feature `"Need async code review from Bob`"" -ForegroundColor Red
        return
    }
    $baseDir = Get-WtBaseDir
    if (-not $baseDir) { return }
    
    Write-Host "⚠️  WARNING: You are choosing to break the Trunk-Based Development workflow." -ForegroundColor Yellow
    Write-Host "⚠️  Reason provided: $reason" -ForegroundColor Yellow
    Write-Host "⚠️  Auditing this exception and pausing for 5 seconds..." -ForegroundColor Yellow
    
    # Auditing
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $user = [Environment]::UserName
    "$timestamp | $user | Branch: $name | Reason: $reason" | Out-File -Append -FilePath "$baseDir/.tbd-exceptions.log" -Encoding utf8
    
    # Friction
    Start-Sleep -Seconds 5
    
    Write-Host "🔄 Fetching latest $($env:LEAN_WT_TRUNK)..." -ForegroundColor Cyan
    git fetch $env:LEAN_WT_REMOTE $env:LEAN_WT_TRUNK --quiet
    if ($LASTEXITCODE -ne 0) { return }
    Write-Host "📁 Spawning clean workspace with local branch '$name'..." -ForegroundColor Cyan
    git worktree add -b "$name" "$baseDir/$name" "$($env:LEAN_WT_REMOTE)/$($env:LEAN_WT_TRUNK)"
    if ($LASTEXITCODE -ne 0) { return }
    Write-Host "🚀 Swapping to new workspace..." -ForegroundColor Green
    Set-Location "$baseDir/$name"
}

function wtpr {
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    if ($branch -eq "HEAD") {
        Write-Host "❌ Error: You are on a detached HEAD. Use wtpush to push straight to trunk." -ForegroundColor Red
        return
    }
    Write-Host "⬆️  Pushing branch '$branch' to $($env:LEAN_WT_REMOTE) to open a PR..." -ForegroundColor Cyan
    git push -u $env:LEAN_WT_REMOTE $branch
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Ready for a PR!" -ForegroundColor Green
    }
}

function wtdone {
    param([string]$target_dir, [string]$feature_dir)
    if ([string]::IsNullOrEmpty($target_dir) -or [string]::IsNullOrEmpty($feature_dir)) {
        Write-Host "❌ Error: Usage: wtdone <target-dir-name> <feature-dir-name>" -ForegroundColor Red
        return
    }
    $baseDir = Get-WtBaseDir
    if (-not $baseDir) { return }
    Write-Host "↩️ Returning to target workspace..." -ForegroundColor Cyan
    if (-not (Test-Path "$baseDir/$target_dir")) {
        Write-Host "❌ Error: $baseDir/$target_dir does not exist" -ForegroundColor Red
        return
    }
    Set-Location "$baseDir/$target_dir"
    # The branch flow's version of wtback's guard: git worktree remove passes on
    # a clean tree and `branch -D` is a force delete, so committed-but-unpushed
    # branch work would be orphaned (the branch ref and its reflog go with it).
    # "Safe" means the remote has every commit — checked against the branch's
    # upstream, which also survives squash-merges (a merged-into-HEAD check
    # would false-positive there; the remote-has-it check doesn't).
    $unpushed = git rev-list --count "$($feature_dir)@{upstream}..$($feature_dir)" 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ '$feature_dir' has no upstream — its commits exist nowhere but this machine." -ForegroundColor Red
        Write-Host "   Push it first (wtpr from the worktree), or discard it with:" -ForegroundColor Red
        Write-Host "   git worktree remove --force $baseDir/$feature_dir && git branch -D $feature_dir" -ForegroundColor Red
        return
    }
    if ([int]$unpushed -gt 0) {
        Write-Host "❌ '$feature_dir' has $unpushed unpushed commit(s) — deleting it would orphan them." -ForegroundColor Red
        Write-Host "   Push them first (wtpr from the worktree), or discard with:" -ForegroundColor Red
        Write-Host "   git worktree remove --force $baseDir/$feature_dir && git branch -D $feature_dir" -ForegroundColor Red
        return
    }
    Write-Host "🔥 Vaporising worktree..." -ForegroundColor Yellow
    git worktree remove "$baseDir/$feature_dir"
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Couldn't remove $baseDir/$feature_dir — it still has uncommitted work." -ForegroundColor Red
        return
    }

    Write-Host "🧹 Deleting local branch '$feature_dir'..." -ForegroundColor Yellow
    git branch -D "$feature_dir"
    if ($LASTEXITCODE -ne 0) { return }
    
    wtsync
    if ($LASTEXITCODE -ne 0) { return }
    Write-Host "✨ Worktree and local branch destroyed. Back to work!" -ForegroundColor Green
}
