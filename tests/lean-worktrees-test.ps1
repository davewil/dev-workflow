# ==============================================================================
# Regression tests for lean-worktrees.ps1 — the same four scenarios as
# tests/lean-worktrees-test.sh, so the two ports stay behaviourally in lockstep:
#
#   pwsh tests/lean-worktrees-test.ps1
#
# Self-contained: builds a throwaway origin + clone under the system temp dir,
# sets git identity locally (never touches global config), cleans up after
# itself. CI runs this on every push (see .github/workflows/checks.yml).
# ==============================================================================

function Fail($msg) { Write-Host "❌ FAIL: $msg" -ForegroundColor Red; exit 1 }
function Pass($msg) { Write-Host "✅ PASS: $msg" -ForegroundColor Green }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("wt-test-" + [guid]::NewGuid())
New-Item -ItemType Directory $work | Out-Null

# --- fixture: non-bare origin + clone ----------------------------------------
Set-Location $work
git init -q -b main origin-repo
Set-Location origin-repo
git config user.email test@example.com
git config user.name "wt test"
git commit -q --allow-empty -m init
# the test origin is non-bare; let wtpush push to its checked-out branch
git config receive.denyCurrentBranch ignore
Set-Location ..
git clone -q origin-repo feature
Set-Location feature
git config user.email test@example.com
git config user.name "wt test"

. (Join-Path $scriptDir ".." "lean-worktrees.ps1")

# --- 1. wtfix spawns a detached worktree --------------------------------------
wtfix hotfix
if ((git rev-parse --abbrev-ref HEAD) -ne "HEAD") { Fail "expected detached HEAD in new worktree" }
Pass "wtfix spawns a detached worktree"

# --- 2. wtlist: detached display ----------------------------------------------
Set-Location ../feature
$out = wtlist | Out-String
if ($out -notmatch "detached@") { Write-Host $out; Fail "wtlist did not show detached@<sha>" }
Pass "wtlist shows detached@<sha>"

# --- 3. wtback refuses committed-but-unpushed work -----------------------------
Set-Location ../hotfix
git commit -q --allow-empty -m "unpushed work"
Set-Location ../feature
wtback feature hotfix
if (-not (Test-Path ../hotfix)) { Fail "wtback removed a worktree holding unpushed commits" }
Pass "wtback refuses unpushed work"

# --- 4. after wtpush, wtback removes cleanly -----------------------------------
Set-Location ../hotfix
wtpush
Set-Location ../feature
wtback feature hotfix
if (Test-Path ../hotfix) { Fail "worktree still present after wtback" }
Pass "wtback removes cleanly after push"

Write-Host "ALL PASS"
Set-Location /
Remove-Item -Recurse -Force $work
