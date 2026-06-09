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

wtfix() {
    local name=$1
    if [ -z "$name" ]; then
        echo "❌ Error: Please provide a hotfix name (e.g., wtfix bug-123)"
        return 1
    fi
    echo "🔄 Fetching latest ${LEAN_WT_TRUNK}..."
    git fetch origin "$LEAN_WT_TRUNK" --quiet || return 1
    echo "📁 Spawning clean workspace in ../$name..."
    git worktree add "../$name" "origin/${LEAN_WT_TRUNK}" || return 1
    echo "🚀 Swapping to new workspace..."
    cd "../$name" || return 1
}

wtlist() {
    printf "%-25s %-15s %s\n" "BRANCH" "AGE" "PATH"
    printf "%-25s %-15s %s\n" "------" "---" "----"
    git worktree list | while read -r line; do
        local wt_path branch age
        wt_path=$(echo "$line" | awk '{print $1}')
        branch=$(git -C "$wt_path" rev-parse --abbrev-ref HEAD 2>/dev/null)
        age=$(git -C "$wt_path" log -1 --format="%cr" 2>/dev/null)
        [ -z "$age" ] && age="N/A"
        printf "\033[32m%-25s\033[0m \033[36m%-15s\033[0m %s\n" "${branch:0:24}" "${age:0:14}" "$wt_path"
    done
}

wtsync() {
    echo "🔄 Syncing active workspace with the main trunk..."
    git fetch origin "$LEAN_WT_TRUNK" --quiet && git rebase "origin/${LEAN_WT_TRUNK}" \
        && echo "✅ Workspace aligned with origin/${LEAN_WT_TRUNK}."
}

wtpush() {
    # Rebase onto the trunk first (the manual sync at the push boundary), then
    # push the worktree's detached HEAD straight to the trunk — no branch, no PR.
    wtsync || return 1
    echo "⬆️  Pushing HEAD to origin/${LEAN_WT_TRUNK}..."
    git push origin "HEAD:${LEAN_WT_TRUNK}" \
        && echo "✅ Landed on origin/${LEAN_WT_TRUNK}."
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
    cd "../$target" || return 1
    wtsync
}

wtback() {
    local target_dir=$1
    local fix_dir=$2
    if [ -z "$target_dir" ] || [ -z "$fix_dir" ]; then
        echo "❌ Error: Usage: wtback <feature-dir-name> <hotfix-dir-name>"
        return 1
    fi
    echo "↩️ Returning to main feature workspace..."
    cd "../$target_dir" || return 1
    echo "🔥 Vaporising temporary workspace..."
    if ! git worktree remove "../$fix_dir"; then
        # git refuses on uncommitted changes — that's the safety net working.
        echo "❌ Couldn't remove ../$fix_dir — it still has uncommitted (or unpushed) work."
        echo "   Go back and finish it (commit + wtpush), or discard it with:"
        echo "   git worktree remove --force ../$fix_dir"
        return 1
    fi
    wtsync || return 1
    echo "✨ Clean room destroyed. Workspace updated. Back to work!"
}
