# shellcheck shell=bash
# ==============================================================================
# Regression tests for lean-worktrees.sh — run under bash AND zsh:
#
#   bash tests/lean-worktrees-test.sh
#   zsh  tests/lean-worktrees-test.sh
#
# Self-contained: builds a throwaway origin + clone in mktemp, sets git
# identity locally (never touches global config), cleans up after itself.
# CI runs this matrix-style on both shells (see .github/workflows/checks.yml);
# the zsh leg exists because zsh-only bugs are real — `local` re-declaration
# inside wtlist's loop printed name=value noise under zsh while bash stayed
# silent.
# ==============================================================================

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd) || exit 1
WORK=$(mktemp -d) || exit 1

fail() {
    echo "❌ FAIL: $1"
    exit 1
}
pass() { echo "✅ PASS: $1"; }

# --- fixture: non-bare origin + clone ----------------------------------------
cd "$WORK" || exit 1
git init -q -b main origin-repo
cd origin-repo || exit 1
git config user.email test@example.com
git config user.name "wt test"
git commit -q --allow-empty -m init
# the test origin is non-bare; let wtpush push to its checked-out branch
git config receive.denyCurrentBranch ignore
cd .. || exit 1
git clone -q origin-repo feature
cd feature || exit 1
git config user.email test@example.com
git config user.name "wt test"

# shellcheck disable=SC1091
. "$SCRIPT_DIR/../lean-worktrees.sh"

# --- 1. wtfix spawns a detached worktree --------------------------------------
wtfix hotfix >/dev/null || fail "wtfix returned non-zero"
[ "$(git rev-parse --abbrev-ref HEAD)" = "HEAD" ] || fail "expected detached HEAD in new worktree"
pass "wtfix spawns a detached worktree"

# --- 2. wtlist: detached display, no zsh local-redeclare noise -----------------
cd ../feature || exit 1
out=$(wtlist)
case $out in
    *detached@*) pass "wtlist shows detached@<sha>" ;;
    *) echo "$out"; fail "wtlist did not show detached@<sha>" ;;
esac
case $out in
    *wt_path=*) echo "$out"; fail "wtlist leaks variable noise (zsh local re-declare quirk)" ;;
    *) pass "wtlist output is clean" ;;
esac

# --- 3. wtback refuses committed-but-unpushed work -----------------------------
cd ../hotfix || exit 1
git commit -q --allow-empty -m "unpushed work"
cd ../feature || exit 1
if wtback feature hotfix >/dev/null 2>&1; then
    fail "wtback removed a worktree holding unpushed commits"
fi
[ -d ../hotfix ] || fail "worktree gone despite wtback refusing"
pass "wtback refuses unpushed work"

# --- 4. after wtpush, wtback removes cleanly -----------------------------------
cd ../hotfix || exit 1
wtpush >/dev/null 2>&1 || fail "wtpush returned non-zero"
cd ../feature || exit 1
wtback feature hotfix >/dev/null 2>&1 || fail "wtback returned non-zero after push"
[ ! -d ../hotfix ] || fail "worktree still present after wtback"
pass "wtback removes cleanly after push"

# --- 5. wtbranch spawns a worktree with a local branch and logs exception ---
cd ../feature || exit 1
wtbranch my-pr "Test PR workflow" >/dev/null 2>&1 || fail "wtbranch returned non-zero"
[ "$(git rev-parse --abbrev-ref HEAD)" = "my-pr" ] || fail "expected named branch in new worktree"
[ -f ../.tbd-exceptions.log ] || fail "missing exception log"
grep -q "Test PR workflow" ../.tbd-exceptions.log || fail "exception log missing reason"
pass "wtbranch spawns a branch and logs exception"

# --- 6. wtpr pushes the branch to remote ---
git commit -q --allow-empty -m "pr work"
wtpr >/dev/null 2>&1 || fail "wtpr returned non-zero"
[ -n "$(git rev-parse @{u} 2>/dev/null)" ] || fail "upstream tracking not set"
pass "wtpr pushes branch to remote"

# --- 7. wtdone removes worktree and local branch ---
cd ../feature || exit 1
wtdone feature my-pr >/dev/null 2>&1 || fail "wtdone returned non-zero"
[ ! -d ../my-pr ] || fail "worktree still present after wtdone"
if git branch --list | grep -q "my-pr"; then fail "local branch still present after wtdone"; fi
pass "wtdone removes cleanly"

echo "ALL PASS"
cd / && rm -rf "$WORK"
