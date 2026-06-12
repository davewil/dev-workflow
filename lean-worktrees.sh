# shellcheck shell=bash
# ==============================================================================
# LEAN WORKTREE FUNCTIONS  (Bash / Zsh)
# ------------------------------------------------------------------------------
# Trunk-based, single-piece-flow worktree helpers. Source from ~/.zshrc /
# ~/.bashrc, or drop into your dotfiles repo (e.g. dotfiles/shell/worktrees.sh)
# and `source` it.
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
# The integration branch (the one that hits prod) defaults to `main`. Set LEAN_WT_TRUNK
# to whatever yours is — main / master / trunk; the name doesn't matter.
# ==============================================================================

: "${LEAN_WT_TRUNK:=main}"
: "${LEAN_WT_REMOTE:=origin}"

# Helper to get the absolute path of the directory containing the worktrees
_wt_base_dir() {
    local toplevel
    toplevel=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -z "$toplevel" ]; then
        echo "❌ Error: Not inside a git repository." >&2
        return 1
    fi
    dirname "$toplevel"
}

wtfix() {
    local name=$1
    if [ -z "$name" ]; then
        echo "❌ Error: Please provide a hotfix name (e.g., wtfix bug-123)"
        return 1
    fi
    local base_dir
    base_dir=$(_wt_base_dir) || return 1
    echo "🔄 Fetching latest ${LEAN_WT_TRUNK}..."
    git fetch "$LEAN_WT_REMOTE" "$LEAN_WT_TRUNK" --quiet || return 1
    echo "📁 Spawning clean workspace in $base_dir/$name..."
    git worktree add "$base_dir/$name" "$LEAN_WT_REMOTE/${LEAN_WT_TRUNK}" || return 1
    echo "🚀 Swapping to new workspace..."
    cd "$base_dir/$name" || return 1
}

wtlist() {
    printf "%-25s %-15s %s\n" "BRANCH" "AGE" "PATH"
    printf "%-25s %-15s %s\n" "------" "---" "----"
    # Declare once, outside the loop: zsh's `local` *prints* name=value when
    # re-declaring an already-set variable, so per-iteration `local` leaks noise.
    local line wt_path branch age
    git worktree list | while read -r line; do
        wt_path=$(echo "$line" | awk '{print $1}')
        branch=$(git -C "$wt_path" rev-parse --abbrev-ref HEAD 2>/dev/null)
        # wtfix worktrees are detached, so abbrev-ref yields the literal "HEAD" —
        # show the short SHA instead, which is at least identifying.
        if [ "$branch" = "HEAD" ]; then
            branch="detached@$(git -C "$wt_path" rev-parse --short HEAD 2>/dev/null)"
        fi
        age=$(git -C "$wt_path" log -1 --format="%cr" 2>/dev/null)
        [ -z "$age" ] && age="N/A"
        printf "\033[32m%-25s\033[0m \033[36m%-15s\033[0m %s\n" "${branch:0:24}" "${age:0:14}" "$wt_path"
    done
}

wtsync() {
    echo "🔄 Syncing active workspace with the main trunk..."
    git fetch "$LEAN_WT_REMOTE" "$LEAN_WT_TRUNK" --quiet || return 1
    if ! git rebase "$LEAN_WT_REMOTE/${LEAN_WT_TRUNK}"; then
        echo "❌ Rebase hit conflicts — resolve them, then re-run."
        return 1
    fi
    echo "✅ Workspace aligned with $LEAN_WT_REMOTE/${LEAN_WT_TRUNK}."
}

wtpush() {
    # Rebase onto the trunk first (the manual sync at the push boundary), then
    # push the worktree's detached HEAD straight to the trunk — no branch, no PR.
    wtsync || return 1
    echo "⬆️  Pushing HEAD to $LEAN_WT_REMOTE/${LEAN_WT_TRUNK}..."
    git push "$LEAN_WT_REMOTE" "HEAD:${LEAN_WT_TRUNK}" \
        && echo "✅ Landed on $LEAN_WT_REMOTE/${LEAN_WT_TRUNK}."
}

wtswitch() {
    # cd into a sibling worktree and fast-forward it onto the trunk in one step.
    # Refs are already shared across worktrees, so this is just the rebase.
    # wtsync refuses if the target has uncommitted changes — that's deliberate:
    # you never want an automatic rebase to clobber work in progress.
    local target=$1
    if [ -z "$target" ]; then
        echo "❌ Error: Usage: wtswitch <worktree-dir-name>"
        return 1
    fi
    local base_dir
    base_dir=$(_wt_base_dir) || return 1
    if [ ! -d "$base_dir/$target" ]; then
        echo "❌ Error: $base_dir/$target does not exist"
        return 1
    fi
    cd "$base_dir/$target" || return 1
    wtsync
}

wtback() {
    local target_dir=$1
    local fix_dir=$2
    if [ -z "$target_dir" ] || [ -z "$fix_dir" ]; then
        echo "❌ Error: Usage: wtback <feature-dir-name> <hotfix-dir-name>"
        return 1
    fi
    local base_dir
    base_dir=$(_wt_base_dir) || return 1
    if [ ! -d "$base_dir/$target_dir" ]; then
        echo "❌ Error: $base_dir/$target_dir does not exist"
        return 1
    fi
    echo "↩️ Returning to main feature workspace..."
    cd "$base_dir/$target_dir" || return 1
    # git worktree remove only refuses on *uncommitted* changes. Committed-but-
    # unpushed work on a detached HEAD would be silently orphaned — the worktree's
    # HEAD ref and reflog die with it — so guard against that here, explicitly.
    local unpushed
    if ! unpushed=$(git -C "$base_dir/$fix_dir" rev-list --count "$LEAN_WT_REMOTE/${LEAN_WT_TRUNK}..HEAD" 2>/dev/null); then
        echo "❌ Error: Could not verify if $fix_dir has unpushed commits."
        return 1
    fi
    if [ -n "$unpushed" ] && [ "$unpushed" -gt 0 ]; then
        echo "❌ $base_dir/$fix_dir has $unpushed unpushed commit(s) — removing it would orphan them."
        echo "   Go back and land them (wtpush), or discard them with:"
        echo "   git worktree remove --force $base_dir/$fix_dir"
        return 1
    fi
    echo "🔥 Vaporising temporary workspace..."
    if ! git worktree remove "$base_dir/$fix_dir"; then
        # git refuses on uncommitted changes — that's the safety net working.
        echo "❌ Couldn't remove $base_dir/$fix_dir — it still has uncommitted work."
        echo "   Go back and finish it (commit + wtpush), or discard it with:"
        echo "   git worktree remove --force $base_dir/$fix_dir"
        return 1
    fi
    wtsync || return 1
    echo "✨ Clean room destroyed. Workspace updated. Back to work!"
}

wtbranch() {
    local name=$1
    local reason=$2
    if [ -z "$name" ] || [ -z "$reason" ]; then
        echo "❌ Error: Usage: wtbranch <branch-name> <mandatory-reason-for-breaking-tbd>"
        echo "   Example: wtbranch my-feature \"Need async code review from Bob\""
        return 1
    fi
    local base_dir
    base_dir=$(_wt_base_dir) || return 1
    
    echo "⚠️  WARNING: You are choosing to break the Trunk-Based Development workflow."
    echo "⚠️  Reason provided: $reason"
    echo "⚠️  Auditing this exception and pausing for 5 seconds..."
    
    # Auditing
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $(whoami) | Branch: $name | Reason: $reason" >> "$base_dir/.tbd-exceptions.log"
    
    # Friction
    sleep 5
    
    echo "🔄 Fetching latest ${LEAN_WT_TRUNK}..."
    git fetch "$LEAN_WT_REMOTE" "$LEAN_WT_TRUNK" --quiet || return 1
    echo "📁 Spawning clean workspace with local branch '$name'..."
    git worktree add -b "$name" "$base_dir/$name" "$LEAN_WT_REMOTE/${LEAN_WT_TRUNK}" || return 1
    echo "🚀 Swapping to new workspace..."
    cd "$base_dir/$name" || return 1
}

wtpr() {
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD)
    if [ "$branch" = "HEAD" ]; then
        echo "❌ Error: You are on a detached HEAD. Use wtpush to push straight to trunk."
        return 1
    fi
    echo "⬆️  Pushing branch '$branch' to $LEAN_WT_REMOTE to open a PR..."
    git push -u "$LEAN_WT_REMOTE" "$branch" && echo "✅ Ready for a PR!"
}

wtdone() {
    local target_dir=$1
    local feature_dir=$2
    if [ -z "$target_dir" ] || [ -z "$feature_dir" ]; then
        echo "❌ Error: Usage: wtdone <target-dir-name> <feature-dir-name>"
        return 1
    fi
    local base_dir
    base_dir=$(_wt_base_dir) || return 1
    if [ ! -d "$base_dir/$target_dir" ]; then
        echo "❌ Error: $base_dir/$target_dir does not exist"
        return 1
    fi
    echo "↩️ Returning to target workspace..."
    cd "$base_dir/$target_dir" || return 1
    
    echo "🔥 Vaporising worktree..."
    if ! git worktree remove "$base_dir/$feature_dir"; then
        echo "❌ Couldn't remove $base_dir/$feature_dir — it still has uncommitted work."
        return 1
    fi
    
    echo "🧹 Deleting local branch '$feature_dir'..."
    git branch -D "$feature_dir" || return 1
    
    wtsync || return 1
    echo "✨ Worktree and local branch destroyed. Back to work!"
}
